#!/usr/bin/env python3
"""
Altiora Backup Pro - CLI
Version propre (réparation indentation).
"""

import argparse
import sys
import os

from backup_core import BackupCore
from backup_manager import BackupManager


class AltioraCLI:
    def __init__(self):
        self.core = BackupCore()
        self.manager = BackupManager()

    def build_parser(self) -> argparse.ArgumentParser:
        parser = argparse.ArgumentParser(
            prog="altiora",
            description="Altiora Backup Pro - Solution de backup chiffre (AES-256-GCM)",
        )

        parser.add_argument(
            "--version",
            action="version",
            version="Altiora Backup Pro v1.0.10",
        )
        parser.add_argument("--verbose", "-v", action="store_true", help="Affichage detaille")
        parser.add_argument("--json", action="store_true", help="Sortie JSON (machine-readable)")

        subparsers = parser.add_subparsers(dest="command", help="Commandes")

        # backup
        p_backup = subparsers.add_parser("backup", help="Creer une sauvegarde chiffre")
        p_backup.add_argument("source", help="Dossier source a sauvegarder")
        p_backup.add_argument("output", help="Fichier de sortie (.altb)")
        p_backup.add_argument("-p", "--password", required=True, help="Mot de passe de chiffrement")

        # restore
        p_restore = subparsers.add_parser("restore", help="Restaurer une sauvegarde")
        p_restore.add_argument("backup_file", help="Fichier backup (.altb)")
        p_restore.add_argument("destination", help="Dossier de destination")
        p_restore.add_argument("-p", "--password", required=True, help="Mot de passe de chiffrement")

        # verify
        p_verify = subparsers.add_parser("verify", help="Verifier mot de passe + integrite (sans restaurer)")
        p_verify.add_argument("backup_file", help="Fichier backup (.altb)")
        p_verify.add_argument("-p", "--password", required=True, help="Mot de passe de chiffrement")

        # list
        subparsers.add_parser("list", help="Lister tous les backups")

        # stats
        subparsers.add_parser("stats", help="Afficher les statistiques")

        return parser

    def run(self, argv=None) -> int:
        parser = self.build_parser()
        args = parser.parse_args(argv)

        if not args.command:
            parser.print_help()
            return 0

        # Dispatch
        if args.command == "backup":
            return int(self.core.backup(args.source, args.output, args.password))

        if args.command == "restore":
            return int(self.core.restore(args.backup_file, args.destination, args.password))

        if args.command == "verify":
            return int(self.core.verify(args.backup_file, args.password))

        if args.command == "list":
            backups = self.manager.list_backups()
            for b in backups:
                name = b.get("name", "")
                date = b.get("date", "")
                print(f"- {name} - {date}")
            return 0

        if args.command == "stats":
            stats = self.manager.get_statistics()
            total = stats.get("total", 0)
            last_backup = stats.get("last_backup", "Aucun")
            total_size = stats.get("total_size_mb", 0)
            print("Statistiques:")
            print(f"- Backups totaux: {total}")
            print(f"- Dernier backup: {last_backup}")
            print(f"- Taille totale: {total_size:.2f} MB")
            return 0

        # fallback
        parser.print_help()
        return 2


def main() -> int:
    return AltioraCLI().run()


if __name__ == "__main__":
    raise SystemExit(main())