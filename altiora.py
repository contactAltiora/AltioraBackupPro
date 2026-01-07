#!/usr/bin/env python3
"""
Altiora Backup Pro - Solution de backup chiffré professionnelle
CLI (backup / verify / restore / list / stats)
"""

import argparse
import json
import os
import sys
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
Prix: 24,90€ • Garantie: 30 jours
============================================================
"""
    _safe_print(banner)


def print_footer(ok: bool = True) -> None:
    footer = """
============================================================
✅ Succès — Support: garantie 30 jours — Prix: 24,90€
============================================================
""" if ok else """
============================================================
❌ Échec — Support: garantie 30 jours — Prix: 24,90€
============================================================
"""
    _safe_print(footer)


def check_imports() -> bool:
    _safe_print("🔍 Vérification des dépendances...")
    try:
        import uuid  # noqa: F401
        import base64  # noqa: F401
        from cryptography.hazmat.primitives.ciphers import Cipher  # noqa: F401
        from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC  # noqa: F401
        _safe_print("   ✅ Bibliothèques cryptographiques OK")
        return True
    except ImportError as e:
        _safe_print(f"   ❌ Import manquant: {e}")
        _safe_print("   ℹ️  Installez: pip install cryptography")
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
    # Mode JSON: on supprime les sorties “marketing” (bannière/footer)
    json_mode = ("--json" in sys.argv)

    if not json_mode:
        print_banner()

    if not check_imports():
        if json_mode:
            _emit_json({"ok": False, "error": "missing_dependencies"})
            return 1
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
        _safe_print("🚀 Initialisation du système...")

    try:
        try:
            from src.backup_core import BackupCore  # type: ignore
            import src.backup_core as backup_core_module  # type: ignore
        except Exception:
            from backup_core import BackupCore  # type: ignore
            import backup_core as backup_core_module  # type: ignore

        core = BackupCore()

        if not json_mode:
            _safe_print("   ✅ Système initialisé")
            _safe_print(f"📍 altiora.py: {os.path.abspath(__file__)}")
            try:
                _safe_print(f"📍 BackupCore: {backup_core_module.__file__}")
            except Exception:
                pass

        if logger:
            logger.info("BackupCore initialized file=%s", getattr(backup_core_module, "__file__", "unknown"))

    except Exception as e:
        if json_mode:
            _emit_json({"ok": False, "error": f"{type(e).__name__}: {e}"})
            return 1
        _safe_print(f"   ❌ Erreur d'initialisation: {type(e).__name__}: {e}")
        if logger:
            logger.exception("Init error")
        print_footer(ok=False)
        return 1

    parent = argparse.ArgumentParser(add_help=False)
    parent.add_argument("--verbose", "-v", action="store_true", help="Affichage détaillé")
    parent.add_argument("--json", action="store_true", help="Sortie JSON (machine-readable)")

    parser = argparse.ArgumentParser(
    description="""Altiora Backup Pro - Solution de backup chiffré (AES-256-GCM)

Chiffrement AES-256-GCM (standard industriel)
Prix: 24,90€ • Garantie: 30 jours
""",
    formatter_class=argparse.RawDescriptionHelpFormatter,
    parents=[parent],
)
    subparsers = parser.add_subparsers(dest="command", title="Commandes", help="Commande à exécuter")

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

    if len(sys.argv) == 1:
        parser.print_help()
        # pas de footer en mode help “normal”
        return 0

    try:
        args = parser.parse_args()
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
        if not args.json:
            _safe_print("➔ Backup : {}  →  {}".format(args.source, args.output))
            vprint(f"   CWD: {os.getcwd()}")
            vprint(f"   Source abs: {os.path.abspath(args.source)}")
            vprint(f"   Output abs: {os.path.abspath(args.output)}")
            _safe_print(f"   - PBKDF2: {args.iterations} itérations")
            _safe_print(f"   - Compression: {'non' if args.no_compress else 'oui'}")

        try:
            ok = bool(
                core.create_backup(
                    args.source,
                    args.output,
                    args.password,
                    iterations=args.iterations,
                    compress=(not args.no_compress),
                )
            )
            if logger:
                logger.info("backup ok=%s output=%s", ok, args.output)
        except Exception as e:
            if args.json:
                _emit_json({"ok": False, "command": "backup", "error": f"{type(e).__name__}: {e}"})
                return 1
            _safe_print(f"❌ ERREUR BACKUP: {type(e).__name__}: {e}")
            if logger:
                logger.exception("backup exception")
            print_footer(ok=False)
            return 1

        if args.json:
            _emit_json({"ok": ok, "command": "backup", "output": args.output, "elapsed_s": round(time.time() - start_time, 3)})
            return 0 if ok else 1

        print_footer(ok=ok)
        return 0 if ok else 1

    if args.command == "verify":
        if not args.json:
            _safe_print(f"➔ Verify : {args.backup}")
            vprint(f"   Backup abs: {os.path.abspath(args.backup)}")

        try:
            ok = _call_verify(core, args.backup, args.password)
        except Exception as e:
            if args.json:
                _emit_json({"ok": False, "command": "verify", "backup": args.backup, "error": f"{type(e).__name__}: {e}"})
                return 1
            _safe_print(f"❌ ERREUR VERIFY: {type(e).__name__}: {e}")
            if logger:
                logger.exception("verify exception")
            print_footer(ok=False)
            return 1

        if args.json:
            _emit_json({"ok": bool(ok), "command": "verify", "backup": args.backup})
            return 0 if ok else 1

        if ok:
            _safe_print("✅ BACKUP VALIDE (mot de passe + authentification OK)")
            print_footer(ok=True)
            return 0

        _safe_print("❌ BACKUP INVALIDE (mot de passe incorrect ou fichier corrompu)")
        print_footer(ok=False)
        return 1

    if args.command == "restore":
        if not args.json:
            _safe_print("➔ Restore : {}  →  {}".format(args.backup, args.output))

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
                _safe_print("⛔ RESTAURATION BLOQUÉE (SAFE MODE) — fichiers déjà présents :")
                for p in collisions[:20]:
                    _safe_print(f"  - {p}")
                if len(collisions) > 20:
                    _safe_print(f"  ... +{len(collisions)-20} autres")
                _safe_print("Utilisez --force pour autoriser l’écrasement.")
                print_footer(ok=False)
                return 1

        try:
            ok = bool(core.restore_backup(args.backup, args.output, args.password))
            if logger:
                logger.info("restore ok=%s output=%s", ok, args.output)
        except Exception as e:
            if args.json:
                _emit_json({"ok": False, "command": "restore", "error": f"{type(e).__name__}: {e}"})
                return 1
            _safe_print(f"❌ ERREUR RESTORE: {type(e).__name__}: {e}")
            if logger:
                logger.exception("restore exception")
            print_footer(ok=False)
            return 1

        if args.json:
            _emit_json({"ok": ok, "command": "restore", "output": args.output, "elapsed_s": round(time.time() - start_time, 3)})
            return 0 if ok else 1

        print_footer(ok=ok)
        return 0 if ok else 1

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
        print_footer(ok=True)
        return 0

    parser.print_help()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())


