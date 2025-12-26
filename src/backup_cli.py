#!/usr/bin/env python3
"""
Script CLI Altiora Backup Pro.
Interface ligne de commande complète.
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
    
    def run(self):
        parser = argparse.ArgumentParser(
            description="Altiora Backup Pro v1.0 - Solution de backup chiffré",
            prog="altiora"
        )
        
        subparsers = parser.add_subparsers(dest="command", help="Commandes disponibles")
        
        # Backup command
        backup_parser = subparsers.add_parser("backup", help="Créer un backup chiffré")
        backup_parser.add_argument("source", help="Dossier source à sauvegarder")
        backup_parser.add_argument("output", help="Fichier de sortie (.altb)")
        backup_parser.add_argument("-p", "--password", required=True, help="Mot de passe de chiffrement")
        
        # Restore command
        restore_parser = subparsers.add_parser("restore", help="Restaurer un backup")
        restore_parser.add_argument("backup_file", help="Fichier backup (.altb)")
        restore_parser.add_argument("destination", help="Dossier de destination")
        restore_parser.add_argument("-p", "--password", required=True, help="Mot de passe de chiffrement")
        
        # List command
        list_parser = subparsers.add_parser("list", help="Lister tous les backups")
        
        # Stats command
        stats_parser = subparsers.add_parser("stats", help="Afficher les statistiques")
        
        # Parse arguments
        args = parser.parse_args()
        
        if not args.command:
            parser.print_help()
            return 0
        
        if args.command == "backup":
            print(f"📦 Backup de {args.source} vers {args.output}")
            # Ici, ajouter la logique de backup réelle
            return 0
            
        elif args.command == "restore":
            print(f"🔄 Restauration de {args.backup_file} vers {args.destination}")
            # Ici, ajouter la logique de restauration réelle
            return 0
            
        elif args.command == "list":
            print("📋 Liste des backups:")
            backups = self.manager.list_backups()
            for backup in backups:
                print(f"  • {backup['name']} - {backup['date']}")
            return 0
            
       elif args.command == "stats":
    stats = self.manager.get_statistics()
    print(f"📊 Statistiques:")
    
    # Version robuste qui gère les clés manquantes
    total = stats.get('total', 0)
    last_backup = stats.get('last_backup', 'Aucun')
    total_size = stats.get('total_size_mb', 0)
    
    print(f" • Backups totaux: {stats.get('total', 0)}")
    print(f"  • Dernier backup: {last_backup}")
    print(f"  • Taille totale: {total_size:.2f} MB")
    return 0
            print(f"  • Dernier backup: {stats['last_backup']}")
            print(f"  • Taille totale: {stats['total_size_mb']:.2f} MB")
            return 0
        
        return 0

def main():
    """Point d'entrée pour la CLI."""
    cli = AltioraCLI()
    return cli.run()

if __name__ == "__main__":
    sys.exit(main())