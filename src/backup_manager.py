import json
import os
from datetime import datetime


class BackupManager:
    def __init__(self, db_file="backups.json"):
        self.db_file = db_file
        self.backups = {}
        self._load_database()

    def _load_database(self):
        """Charge la base de données depuis le fichier"""
        if os.path.exists(self.db_file):
            try:
                with open(self.db_file, "r", encoding="utf-8") as f:
                    self.backups = json.load(f)
                print(f"  → Base de données chargée ({len(self.backups)} backups)")
            except Exception as e:
                print(f"  → Nouvelle base de données créée (erreur: {str(e)[:50]})")
                self.backups = {}
        else:
            print("  → Nouvelle base de données créée")
            self.backups = {}

    def save_database(self):
        """Sauvegarde atomique de la base de données"""
        try:
            tmp_file = self.db_file + ".tmp"
            with open(tmp_file, "w", encoding="utf-8") as f:
                json.dump(self.backups, f, indent=2, ensure_ascii=False)
            os.replace(tmp_file, self.db_file)
            return True
        except Exception as e:
            print(f"❌ Erreur sauvegarde DB: {e}")
            return False

    def add_backup(self, metadata):
        """Ajoute un backup à la base de données"""
        try:
            # Récupération robuste du backup_id
            backup_id = metadata.get("backup_id") or metadata.get("id")

            if not backup_id:
                print("❌ Erreur: backup_id introuvable, backup non enregistré")
                return False

            metadata["backup_id"] = backup_id
            metadata["registered_at"] = datetime.now().isoformat()

            self.backups[backup_id] = metadata

            if self.save_database():
                print(f"  → Backup enregistré: {metadata.get('name', 'Sans nom')}")
                return True

            print("❌ Échec sauvegarde base de données")
            return False

        except Exception as e:
            print(f"❌ Erreur d'enregistrement: {e}")
            return False

    def get_backup(self, backup_id):
        """Récupère les informations d'un backup"""
        return self.backups.get(backup_id)

    def list_backups(self):
        """Liste tous les backups avec formatage"""
        backups_list = []

        for backup_id, metadata in self.backups.items():
            size_mb = metadata.get("size", 0) / (1024 * 1024)
            duration = metadata.get("duration", 0)
            speed = metadata.get("speed_bps", 0) / (1024 * 1024)

            backups_list.append({
                "id": backup_id,
                "name": metadata.get("name", "Inconnu"),
                "source": metadata.get("source", "Inconnu"),
                "size": metadata.get("size", 0),
                "size_mb": size_mb,
                "files": metadata.get("files_count", 0),
                "timestamp": metadata.get("timestamp", "Inconnu"),
                "duration": duration,
                "speed_mbps": speed,
            })

        return backups_list

    def get_stats(self):
        """Retourne les statistiques détaillées des backups"""
        try:
            total_backups = len(self.backups)
            total_size = sum(b.get("size", 0) for b in self.backups.values())
            total_files = sum(b.get("files_count", 0) for b in self.backups.values())
            total_duration = sum(b.get("duration", 0) for b in self.backups.values())

            return {
                "total_backups": total_backups,
                "total_size": total_size,
                "total_size_gb": total_size / (1024 ** 3),
                "total_files": total_files,
                "total_duration": total_duration,
                "avg_size": total_size / total_backups if total_backups else 0,
                "avg_files": total_files / total_backups if total_backups else 0,
                "avg_duration": total_duration / total_backups if total_backups else 0,
                "last_backup": max(
                    (b.get("timestamp", "") for b in self.backups.values()),
                    default="Aucun"
                ),
            }

        except Exception as e:
            print(f"❌ Erreur dans get_stats: {e}")
            return {
                "total_backups": 0,
                "total_size": 0,
                "total_size_gb": 0,
                "total_files": 0,
            }

    def clear_old_backups(self, days=30):
        """Supprime les backups plus vieux que X jours"""
        try:
            cutoff = datetime.now().timestamp() - (days * 24 * 60 * 60)
            removed = 0

            for backup_id, metadata in list(self.backups.items()):
                timestamp = metadata.get("timestamp")
                if not timestamp:
                    continue

                try:
                    dt = datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
                    if dt.timestamp() < cutoff:
                        del self.backups[backup_id]
                        removed += 1
                except Exception:
                    continue

            if removed:
                self.save_database()
                print(f"  → {removed} vieux backups supprimés (> {days} jours)")

            return removed

        except Exception as e:
            print(f"❌ Erreur nettoyage: {e}")
            return 0
