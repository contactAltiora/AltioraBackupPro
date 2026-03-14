# ABP_ASCII_OUTPUT_V3
# ABP_ITER_AUTO_V49C: applied (no-op, --iterations already present)  # ABP_REMOVE_PRICE_BANNER_V59
# ABP_ITER_AUTO_V49B: applied
# ABP_SYS_PATH_V47B: applied
# ABP_SYS_PATH_V47: applied
# ABP_JSON_ONLY_V44B: applied
# ABP: disable last global help/return v24
# ABP: fix dispatch remove global help/return v22d
# ABP: fix subparsers dest command v21
# ABP: force args.json when json_mode v15c
#!/usr/bin/env python3
"""
Altiora Backup Pro - Solution de backup chiffré professionnelle
CLI (backup / verify / restore / list / stats)
"""

import argparse
import json
import os

def find_backup_drive(label: str):
    import subprocess

    cmd = [
        "powershell",
        "-Command",
        f"(Get-Volume | Where-Object {{$_.FileSystemLabel -eq '{label}'}}).DriveLetter"
    ]

    result = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        shell=False,
    )

    letter = result.stdout.strip()
    if letter:
        return f"{letter}:\\"
    return None


# --- RUNTIME PROTECTION HOOK (fail-closed) ---
def _abp_runtime_verify_or_die():
    import os, sys, hashlib

    if os.environ.get('ALTIORA_PROTECTED','0') != '1':
        return
    # Selftest mode bypass for release pipeline only
    if os.environ.get('ABP_SELFTEST_MODE','0') == '1':
        return

    # Determine application root (supports PyInstaller onefile EXE)
    if getattr(sys, 'frozen', False):
        root = os.path.dirname(os.path.abspath(sys.executable))
    else:
        root = os.path.dirname(os.path.abspath(__file__))

    pub_pem  = os.path.join(root, 'keys', 'altiora_public_key.pem')
    state    = os.path.join(root, 'STATE.md')
    state_sig= os.path.join(root, 'STATE.md.sig')
    state_h  = os.path.join(root, 'STATE.md.sha256')

    if (not os.path.exists(pub_pem)) or (not os.path.exists(state)) or (not os.path.exists(state_sig)):
        print('FATAL: protected mode requires keys/altiora_public_key.pem + STATE.md + STATE.md.sig')
        sys.exit(101)

    def _sha256_file(p):
        h = hashlib.sha256()
        with open(p, 'rb') as f:
            for chunk in iter(lambda: f.read(1024*1024), b''):
                h.update(chunk)
        return h.hexdigest().upper()

    def _read_expected_sha(p):
        # accept "HASH  filename" or just "HASH"
        s = open(p, 'r', encoding='utf-8').read().strip()
        if not s:
            return ""
        return s.split()[0].upper()

    def _verify_ed25519(pub_pem_path, file_path, sig_path):
        # inline verify: avoids subprocess recursion in PyInstaller EXE
        from cryptography.hazmat.primitives import serialization
        from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PublicKey

        pub_bytes = open(pub_pem_path, 'rb').read()
        pub = serialization.load_pem_public_key(pub_bytes)
        if not isinstance(pub, Ed25519PublicKey):
            raise ValueError("Public key is not Ed25519")

        data = open(file_path, 'rb').read()
        sig  = open(sig_path, 'rb').read()
        pub.verify(sig, data)
        return True

    # 1) Signature verification of STATE.md
    try:
        _verify_ed25519(pub_pem, state, state_sig)
    except Exception as e:
        print('FATAL: signature verification failed for STATE.md')
        try:
            print(str(e))
        except Exception:
            pass
        sys.exit(102)

    # 2) SHA256 verification of STATE.md (if STATE.md.sha256 exists)
    if os.path.exists(state_h):
        expected = _read_expected_sha(state_h)
        got = _sha256_file(state)
        if expected and got != expected:
            print('FATAL: STATE.md sha256 mismatch')
            print('EXPECTED:', expected)
            print('GOT     :', got)
            sys.exit(103)

    # 3) Release ZIP sha256 verification (if release sha exists)
    def _abp_get_version_safe():
        try:
            v = globals().get('__version__')
            if isinstance(v, str) and v.strip():
                return v.strip()
        except Exception:
            pass
        return None

    ver = _abp_get_version_safe()
    if ver:
        rel_sha = os.path.join(root, '_out', 'releases', f'AltioraBackupPro_v{ver}_release.sha256')
        rel_zip = os.path.join(root, '_out', 'releases', f'AltioraBackupPro_v{ver}_release.zip')
        if os.path.exists(rel_sha) and os.path.exists(rel_zip):
            expected = _read_expected_sha(rel_sha)
            got = _sha256_file(rel_zip)
            if expected and got != expected:
                print('FATAL: release ZIP sha256 mismatch')
                print('EXPECTED:', expected)
                print('GOT     :', got)
                sys.exit(104)

# Call protection hook as early as possible
_abp_runtime_verify_or_die()
# ABP_SELFTEST_MODE: bypass protected-mode tripwire during selftests (deterministic patch)
if os.environ.get("ABP_SELFTEST_MODE") == "1":
    os.environ["ALTIORA_PROTECTED"] = "0"

import sys

# ABP_ITER_AUTO_V49B: header-based iterations autodetect (legacy backups)
def _abp_read_iter_from_altb_header(path: str) -> int:
    try:
        with open(path, "rb") as f:
            h = f.read(12)
        if len(h) < 12:
            return 0
        if h[0:8] != b"ALTBKUP1":
            return 0
        return int.from_bytes(h[10:12], "big", signed=False)
    except Exception:
        return 0


# ABP_SYS_PATH_V47: ensure src/ is on sys.path so 'import backup_core' always works
try:
    from pathlib import Path as _ABP_Path
    _ABP_ROOT = _ABP_Path(__file__).resolve().parent
    _ABP_SRC  = _ABP_ROOT / 'src'
    _ABP_SRC_S = str(_ABP_SRC)
    if _ABP_SRC_S not in sys.path:
        sys.path.append(_ABP_SRC_S)  # ABP_SYS_PATH_V47B: append to avoid shadowing stdlib (e.g., logging)
except Exception:
    pass


# ABP_JSON_ONLY_V44B: JSON-only mode (stdout filter + logging off) + --version --json

# Altiora Backup Pro - single source of truth for CLI version
VERSION_STR = "Altiora Backup Pro v1.0.17-dev"
__version__ = "1.0.17-dev"
ABP_JSON_MODE_EARLY = ('--json' in sys.argv)
if ABP_JSON_MODE_EARLY:
    # 1) Disable logging noise in JSON mode
    import logging as _abp_logging
    _abp_logging.disable(_abp_logging.CRITICAL)

    # 2) Keep ONLY JSON objects/arrays on stdout (anything else dropped)
    _abp__stdout_write = sys.stdout.write
    def _abp_json_only_write(s):
        t = str(s)
        u = t.lstrip()
        if u.startswith('{') or u.startswith('['):
            return _abp__stdout_write(t)
        return 0
    sys.stdout.write = _abp_json_only_write  # type: ignore

    # 3) Special-case: --version --json => emit pure JSON and exit early
    if ('--version' in sys.argv) or ('-V' in sys.argv):
        sys.stdout.write('{"ok": true, "version": "Altiora Backup Pro v1.0.17-dev"}\n')
        raise SystemExit(0)

# ABP_EARLY_VERSION_V10C2: --version/-V without banner/init (non-JSON)
if (('--version' in sys.argv) or ('-V' in sys.argv)) and ('--json' not in sys.argv):
    sys.stdout.write(VERSION_STR + "\n")
    raise SystemExit(0)

import time
from typing import Any, Dict, List


# --- Console: éviter UnicodeEncodeError sur Windows (cp1252) ---
def _configure_stdout_utf8() -> None:
    try:
        if hasattr(sys.stdout, "reconfigure"):
            sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        if hasattr(sys.stderr, "reconfigure"):
            sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass


def _safe_print(text: str = "") -> None:
    try:
        print(text)
    except UnicodeEncodeError:
        encoded = text.encode("utf-8", errors="replace").decode("utf-8", errors="replace")
        print(encoded)


def _emit_json(payload: Dict[str, Any]) -> None:
    # Sortie strictement JSON (sans bannière/footer)
    sys.stdout.write(json.dumps(payload, ensure_ascii=False) + "\n")


_configure_stdout_utf8()

# Ajouter le répertoire du projet au chemin (permet src.*)
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))


def print_banner() -> None:
    banner = """
============================================================
ALTIORA BACKUP PRO
Chiffrement AES-256-GCM (standard industriel)

============================================================
"""
    _safe_print(banner)


def print_footer(ok: bool = True) -> None:
    footer = """
============================================================
OK OK -- Support inclus : 30 jours
============================================================
""" if ok else """
============================================================
ERROR ERROR -- Support inclus : 30 jours
============================================================
"""
    _safe_print(footer)


def check_imports() -> bool:
    _safe_print("SEARCH Vérification des dépendances...")
    try:
        import uuid  # noqa: F401
        import base64  # noqa: F401
        from cryptography.hazmat.primitives.ciphers import Cipher  # noqa: F401
        from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC  # noqa: F401
        _safe_print("   OK Bibliothèques cryptographiques OK")
        return True
    except ImportError as e:
        _safe_print(f"   ERROR Import manquant: {e}")
        _safe_print("   ℹ  Installez: pip install cryptography")
        return False


def _format_size(size_bytes: int) -> str:
    size_bytes = int(size_bytes or 0)
    size_mb = size_bytes / (1024 * 1024)
    if size_mb >= 1:
        return f"{size_mb:.1f} MB"
    return f"{size_bytes/1024:.0f} KB"


def _backup_size_bytes(backup: Dict[str, Any]) -> int:
    if backup.get("size_bytes") is not None:
        return int(backup.get("size_bytes") or 0)
    if backup.get("size") is not None:
        return int(backup.get("size") or 0)
    if backup.get("size_mb") is not None:
        try:
            return int(float(backup.get("size_mb") or 0) * 1024 * 1024)
        except Exception:
            return 0
    return 0


def _backup_files_count(backup: Dict[str, Any]) -> int:
    for k in ("files", "files_count", "file_count", "nb_files", "total_files"):
        if backup.get(k) is not None:
            try:
                return int(backup.get(k) or 0)
            except Exception:
                return 0
    return 0


def _backup_id(backup: Dict[str, Any]) -> str:
    for k in ("id", "backup_id", "uuid"):
        v = backup.get(k)
        if v:
            return str(v)
    return ""


def _backup_source(backup: Dict[str, Any]) -> str:
    for k in ("source", "src", "path"):
        v = backup.get(k)
        if v:
            return str(v)
    return ""


def _backup_timestamp(backup: Dict[str, Any]) -> str:
    for k in ("timestamp", "date", "created_at", "created", "time"):
        v = backup.get(k)
        if v:
            return str(v)
    return ""


def _compute_stats_from_backups(backups: List[Dict[str, Any]]) -> Dict[str, Any]:
    total = len(backups)
    total_size = sum(_backup_size_bytes(b) for b in backups)
    total_files = sum(_backup_files_count(b) for b in backups)

    durations: List[float] = []
    for b in backups:
        for k in ("duration", "duration_s", "elapsed", "elapsed_s"):
            if b.get(k) is not None:
                try:
                    durations.append(float(b.get(k)))
                except Exception:
                    pass
                break

    last_ts = ""
    ts_list = [(_backup_timestamp(b), b) for b in backups if _backup_timestamp(b)]
    if ts_list:
        last_ts = sorted(ts_list, key=lambda x: x[0])[-1][0]

    avg_size = (total_size / total) if total else 0
    avg_files = (total_files / total) if total else 0
    avg_duration = (sum(durations) / len(durations)) if durations else 0
    total_duration = sum(durations) if durations else 0

    return {
        "total_backups": total,
        "total_size_gb": total_size / (1024**3),
        "total_files": total_files,
        "total_duration": total_duration,
        "avg_size": avg_size,
        "avg_files": avg_files,
        "avg_duration": avg_duration,
        "last_backup": last_ts or "Aucun",
    }


def _call_verify(core: Any, backup_path: str, password: str) -> bool:
    """
    Fallback intelligent selon la version de BackupCore:
    - verify_backup(path, password)
    - verify(path, password)
    - verify_file(path, password)
    - verify_integrity(path, password)
    """
    for name in ("verify_backup", "verify", "verify_file", "verify_integrity"):
        fn = getattr(core, name, None)
        if callable(fn):
            return bool(fn(backup_path, password))
    raise AttributeError(
        "BackupCore n'expose aucune méthode de vérification "
        "(verify/verify_backup/verify_file/verify_integrity)."
    )


def main() -> int:
    # Mode JSON: on supprime les sorties "marketing" (bannière/footer)
    json_mode = ("--json" in sys.argv)

    if not json_mode:
        print_banner()

    if not check_imports():
        if json_mode:
            _emit_json({"ok": False, "error": "missing_dependencies"})
            return 1
        if not json_mode and not getattr(args,"json",False):
            print_footer(ok=False)
        return 1

    # Logging (optionnel)
    logger = None
    try:
        try:
            from src.logging import setup_logging  # type: ignore
        except Exception:
            setup_logging = None  # type: ignore

        if setup_logging:
            logger = setup_logging("altiora_cli")
            logger.info("CLI started")
    except Exception:
        logger = None

    if not json_mode:
        _safe_print("RUN Initialisation du système...")

    try:
        try:
            from src.backup_core import BackupCore  # type: ignore
            import src.backup_core as backup_core_module  # type: ignore
        except Exception:
            from backup_core import BackupCore  # type: ignore
            import backup_core as backup_core_module  # type: ignore

        core = BackupCore()

        if not json_mode:
            _safe_print("   OK Système initialisé")
            _safe_print(f"PATH altiora.py: {os.path.abspath(__file__)}")
            try:
                _safe_print(f"PATH BackupCore: {backup_core_module.__file__}")
            except Exception:
                pass

            # --- Edition diagnostics (requested / effective / reason) ---
            requested = getattr(backup_core_module, "EDITION_REQUESTED", (os.getenv("ALTIORA_EDITION") or "FREE").strip().upper())
            effective = getattr(backup_core_module, "EDITION", "FREE")
            reason = getattr(backup_core_module, "EDITION_REASON", getattr(backup_core_module, "EDITION_EFFECTIVE_REASON", "UNKNOWN"))

            _show = ((os.getenv("ALTIORA_EDITION") or "").strip().upper() == "PRO") or bool(getattr(locals().get("args", None), "verbose", False))
            if _show and not json_mode:
                _safe_print(f"🧾 Edition: demandée={requested} * effective={effective} * raison={reason}")

            if logger:
                logger.info("Edition diag requested=%s effective=%s reason=%s", requested, effective, reason)
            # --- end edition diagnostics ---
        if logger:
            logger.info("BackupCore initialized file=%s", getattr(backup_core_module, "__file__", "unknown"))

    except Exception as e:
        if json_mode:
            _emit_json({"ok": False, "error": f"{type(e).__name__}: {e}"})
            return 1
        _safe_print(f"   ERROR Erreur d'initialisation: {type(e).__name__}: {e}")
        if logger:
            logger.exception("Init error")
        if not json_mode and not getattr(args,"json",False):
            print_footer(ok=False)
        return 1

    parent = argparse.ArgumentParser(add_help=False)

    parent.add_argument(
        "--version", "-V",
        action="version",
        version=VERSION_STR
    )
    parent.add_argument("--verbose", "-v", action="store_true", help="Affichage détaillé")
    parent.add_argument("--json", action="store_true", help="Sortie JSON (machine-readable)")

    parser = argparse.ArgumentParser(
    description="""Altiora Backup Pro - Solution de backup chiffré (AES-256-GCM)

Chiffrement AES-256-GCM (standard industriel)

""",
    formatter_class=argparse.RawDescriptionHelpFormatter,
    parents=[parent],
)
    subparsers = parser.add_subparsers(dest="command", title="Commandes", help="Commande à exécuter", required=True)
    # masterkey
    p_mk = subparsers.add_parser("masterkey", help="Gerer la Master Key")
    mk_sub = p_mk.add_subparsers(dest="mk_command", help="Actions Master Key")

    mk_sub.add_parser("status", help="Verifier si la Master Key est initialisee")
    mk_init = mk_sub.add_parser("init", help="Initialiser la Master Key (creer master_key.json)")
    mk_init.add_argument("-p", "--password", required=True, help="Mot de passe Master Key")

    mk_rot = mk_sub.add_parser("rotate", help="Changer le mot de passe (re-chiffre la master key)")
    mk_rot.add_argument("--old", required=True, help="Ancien mot de passe")
    mk_rot.add_argument("--new", required=True, help="Nouveau mot de passe")
    # backup
    p_backup = subparsers.add_parser("backup", help="Créer une sauvegarde chiffrée", parents=[parent])
    p_backup.add_argument("source", help="Fichier ou dossier à sauvegarder")
    p_backup.add_argument("output", help="Fichier de sauvegarde (.altb)")
    p_backup.add_argument("-p", "--password", required=True, help="Mot de passe de chiffrement")
    p_backup.add_argument("--iterations", type=int, default=300000, help="Itérations PBKDF2 (défaut: 300000)")
    p_backup.add_argument("--no-compress", action="store_true", help="Désactiver la compression (tar sans gzip)")

    # restore
    p_restore = subparsers.add_parser("restore", help="Restaurer une sauvegarde", parents=[parent])
    p_restore.add_argument("backup", help="Fichier de sauvegarde (.altb)")
    p_restore.add_argument("output", help="Dossier de destination")
    p_restore.add_argument("-p", "--password", required=True, help="Mot de passe de chiffrement")
    p_restore.add_argument("--force", action="store_true", help="Autoriser l'écrasement des fichiers existants")

    # verify
    p_verify = subparsers.add_parser("verify", help="Vérifier mot de passe + intégrité (sans restaurer)", parents=[parent])
    p_verify.add_argument("backup", help="Fichier de sauvegarde (.altb)")
    p_verify.add_argument("-p", "--password", required=True, help="Mot de passe de chiffrement")

    # list / stats
    subparsers.add_parser("list", help="Lister toutes les sauvegardes", parents=[parent])
    subparsers.add_parser("stats", help="Afficher les statistiques", parents=[parent])
    subparsers.add_parser("system-info", help="Afficher les informations systeme", parents=[parent])
    subparsers.add_parser("license-info", help="Afficher les informations licence", parents=[parent])

    if len(sys.argv) == 1:
        parser.print_help()
        return 0


    try:
        args = None
        args = parser.parse_args()
        # ABP v15c: en mode JSON (détecté via sys.argv), on force args.json=True
        # afin que les branches 'if args.json:' dispatchent correctement.
        if json_mode:
            try:
                setattr(args, "json", True)
            except Exception:
                pass
        if args.command == "masterkey":
            try:
                from src.master_key import MasterKeyManager, MasterKeyError
            except Exception:
                from master_key import MasterKeyManager, MasterKeyError  # type: ignore

            mgr = MasterKeyManager()

            if getattr(args, "mk_command", None) == "status":
                print("OK" if mgr.exists() else "NOT_INITIALIZED")
                return 0

            if args.mk_command == "init":
                try:
                    p = mgr.init(args.password)
                    print(str(p))
                    return 0
                except MasterKeyError as e:
                    print(f"ERROR: {e}")
                    return 2

            if args.mk_command == "rotate":
                try:
                    mgr.rotate(args.old, args.new)
                    print("OK")
                    return 0
                except MasterKeyError as e:
                    print(f"ERROR: {e}")
                    return 2

            parser.print_help()
            return 2


        # ABP: fix dispatch remove global help/return v22d
        # ABP v22d: suppression du help/return global prématuré (dispatch continue)

        # ABP: disable last global help/return v24
        # pas de footer en mode help "normal"
        # ABP v24: (ancien: return 0/2) -> dispatch continue


    except SystemExit as e:
        # argparse => SystemExit(0) pour --help ; sinon souvent SystemExit(2) pour erreurs CLI
        raw = getattr(e, "code", 0)
        try:
            code = int(raw) if raw is not None else 0
        except Exception:
            code = 1

        if code == 0:
            return 0

        if not json_mode:
            if not json_mode and not getattr(args,"json",False):
                print_footer(ok=False)
        return code

    start_time = time.time()

    def vprint(msg: str) -> None:
        if getattr(args, "verbose", False) and not getattr(args, "json", False):
            _safe_print(msg)

    # ----------------------
    # COMMANDES
    # ----------------------
    if args.command == "backup":
        requested_output = args.output
        requested_name = os.path.basename(os.path.normpath(requested_output))
        if not requested_name:
            requested_name = "backup.altb"

        raw_destinations = []
        for _label in ("ALTIORA_BACKUP_1", "ALTIORA_BACKUP_2"):
            _drive = find_backup_drive(_label)
            if _drive:
                raw_destinations.append((_label, os.path.join(_drive, requested_name)))

        destinations = []
        seen_outputs = set()
        for _label, _dest in raw_destinations:
            _norm = os.path.normcase(os.path.abspath(_dest))
            if _norm not in seen_outputs:
                seen_outputs.add(_norm)
                destinations.append((_label, _dest))

        if not destinations:
            destinations = [("args.output", requested_output)]

        if not args.json:
            _safe_print("-> Backup : {}  ->  {}".format(args.source, requested_output))
            vprint(f"   CWD: {os.getcwd()}")
            vprint(f"   Source abs: {os.path.abspath(args.source)}")
            vprint(f"   Output abs: {os.path.abspath(requested_output)}")
            _safe_print(f"   - PBKDF2: {args.iterations} itérations")
            _safe_print(f"   - Compression: {'non' if args.no_compress else 'oui'}")
            if destinations and destinations[0][0] != "args.output":
                _safe_print("   - Destinations auto détectées :")
                for _label, _dest in destinations:
                    _safe_print(f"     * {_label} -> {_dest}")
            else:
                _safe_print("   - Destination fallback args.output")

        backup_results = []
        all_ok = True

        try:
            for _label, _dest in destinations:
                _backup_ok = bool(
                    core.create_backup(
                        args.source,
                        _dest,
                        args.password,
                        iterations=args.iterations,
                        compress=(not args.no_compress),
                    )
                )

                _verify_ok = False
                if _backup_ok:
                    _verify_ok = bool(_call_verify(core, _dest, args.password))

                backup_results.append({
                    "label": _label,
                    "output": _dest,
                    "backup_ok": bool(_backup_ok),
                    "verify_ok": bool(_verify_ok),
                })

                if logger:
                    logger.info(
                        "backup target=%s output=%s backup_ok=%s verify_ok=%s",
                        _label, _dest, _backup_ok, _verify_ok
                    )

                if (not _backup_ok) or (not _verify_ok):
                    all_ok = False

        except Exception as e:
            if args.json:
                _emit_json({
                    "ok": False,
                    "command": "backup",
                    "error": f"{type(e).__name__}: {e}",
                    "requested_output": requested_output,
                    "results": backup_results,
                })
                return 1
            _safe_print(f"ERROR ERREUR BACKUP: {type(e).__name__}: {e}")
            if logger:
                logger.exception("backup exception")
            if not json_mode and not getattr(args,"json",False):
                print_footer(ok=False)
            return 1

        if args.json:
            _emit_json({
                "ok": bool(all_ok),
                "command": "backup",
                "requested_output": requested_output,
                "outputs": [x["output"] for x in backup_results],
                "results": backup_results,
                "elapsed_s": round(time.time() - start_time, 3),
            })
            return 0 if all_ok else 1

        if backup_results:
            for _r in backup_results:
                _safe_print(
                    f"   -> {_r['label']} | backup={'OK' if _r['backup_ok'] else 'ERROR'} | "
                    f"verify={'OK' if _r['verify_ok'] else 'ERROR'} | {_r['output']}"
                )

        print_footer(ok=all_ok)
        return 0 if all_ok else 1
    if args.command == "verify":
        if not args.json:
            _safe_print(f"-> Verify : {args.backup}")
            vprint(f"   Backup abs: {os.path.abspath(args.backup)}")

        try:
            ok = _call_verify(core, args.backup, args.password)
        except Exception as e:
            if args.json:
                _emit_json({"ok": False, "command": "verify", "backup": args.backup, "error": f"{type(e).__name__}: {e}"})
                return 1
            _safe_print(f"ERROR ERREUR VERIFY: {type(e).__name__}: {e}")
            if logger:
                logger.exception("verify exception")
            if not json_mode and not getattr(args,"json",False):
                print_footer(ok=False)
            return 1

        if args.json:
            _emit_json({"ok": bool(ok), "command": "verify", "backup": args.backup})
            return 0 if ok else 1

        if ok:
            _safe_print("OK BACKUP VALIDE (mot de passe + authentification OK)")
            if not json_mode and not getattr(args,"json",False):
                print_footer(ok=True)
            return 0

        _safe_print("ERROR BACKUP INVALIDE (mot de passe incorrect ou fichier corrompu)")
        if not json_mode and not getattr(args,"json",False):
            print_footer(ok=False)
        return 1

    if args.command == "restore":
        if not args.json:
            _safe_print("-> Restore : {}  ->  {}".format(args.backup, args.output))

        if not args.force:
            if not args.json:
                _safe_print("   Mode SAFE actif : aucun fichier existant ne sera écrasé.")
            try:
                collisions = core.check_restore_collisions(args.backup, args.output)
            except Exception:
                collisions = []

            if collisions:
                if args.json:
                    _emit_json({"ok": False, "command": "restore", "error": "collisions", "count": len(collisions), "samples": collisions[:20]})
                    return 1
                _safe_print("⛔ RESTAURATION BLOQUÉE (SAFE MODE) -- fichiers déjà présents :")
                for p in collisions[:20]:
                    _safe_print(f"  - {p}")
                if len(collisions) > 20:
                    _safe_print(f"  ... +{len(collisions)-20} autres")
                _safe_print("Utilisez --force pour autoriser l'écrasement.")
                if not json_mode and not getattr(args,"json",False):
                    print_footer(ok=False)
                return 1

        try:
            ok = bool(core.restore_backup(args.backup, args.output, args.password))
            exit_code = 0 if ok else int(getattr(core, "last_exit_code", 1) or 1)

            if logger:
                logger.info("restore ok=%s output=%s", ok, args.output)
        except Exception as e:
            if args.json:
                _emit_json({"ok": False, "command": "restore", "error": f"{type(e).__name__}: {e}"})
                return 1
            _safe_print(f"ERROR ERREUR RESTORE: {type(e).__name__}: {e}")
            if logger:
                logger.exception("restore exception")
            if not json_mode and not getattr(args,"json",False):
                print_footer(ok=False)
            return 1

        if args.json:
            _emit_json({"ok": ok, "command": "restore", "output": args.output, "elapsed_s": round(time.time() - start_time, 3)})
            return exit_code
        print_footer(ok=ok)
        return exit_code
    if args.command == "list":
        backups = core.manager.list_backups() or []
        if args.json:
            _emit_json({"ok": True, "command": "list", "count": len(backups), "items": backups})
            return 0

        _safe_print("📋 LISTE DES SAUVEGARDES")
        if not backups:
            _safe_print("   Aucune sauvegarde enregistrée")
        else:
            for i, backup in enumerate(backups, 1):
                name = backup.get("name", "Inconnu")
                size_str = _format_size(_backup_size_bytes(backup))
                files_count = _backup_files_count(backup)
                line = f"   {i}. {name} - {size_str} - {files_count} fichiers"
                if getattr(args, "verbose", False):
                    bid = _backup_id(backup)
                    src = _backup_source(backup)
                    ts = _backup_timestamp(backup)
                    line += f" | id={bid} | source={src} | date={ts}"
                _safe_print(line)
        if not json_mode and not getattr(args,"json",False):
            print_footer(ok=True)
        return 0

    if args.command == "stats":
        backups = core.manager.list_backups() or []
        try:
            stats = core.manager.get_stats() or {}
        except Exception:
            stats = {}

        if stats.get("total_backups") is None or (backups and int(stats.get("total_files", 0)) == 0):
            stats = _compute_stats_from_backups(backups)

        if args.json:
            _emit_json({"ok": True, "command": "stats", "stats": stats})
            return 0

        _safe_print("📊 STATISTIQUES DES SAUVEGARDES")
        if int(stats.get("total_backups", 0)) == 0:
            _safe_print("   Aucune statistique disponible")
        else:
            _safe_print(f"   Sauvegardes totales: {stats.get('total_backups', 0)}")
            _safe_print(f"   Taille totale: {stats.get('total_size_gb', 0):.2f} GB")
            _safe_print(f"   Fichiers totaux: {stats.get('total_files', 0):,}")
            _safe_print(f"   Durée totale: {stats.get('total_duration', 0):.0f}s")
            _safe_print(f"   Taille moyenne: {stats.get('avg_size', 0)/1024/1024:.2f} MB")
            _safe_print(f"   Fichiers moyens: {stats.get('avg_files', 0):.0f}")
            _safe_print(f"   Durée moyenne: {stats.get('avg_duration', 0):.1f}s")
            _safe_print(f"   Dernière sauvegarde: {stats.get('last_backup', 'Aucun')}")
        if not json_mode and not getattr(args,"json",False):
            print_footer(ok=True)
        return 0

    if args.command == "system-info":
        from src.system_info import show_system_info
        show_system_info()
        return 0

    if args.command == "license-info":
        from src.license_info import show_license_info
        show_license_info()
        return 0

if __name__ == "__main__":
    raise SystemExit(main())






















