$ErrorActionPreference = "Stop"

$path = "C:\Dev\AltioraBackupPro\MASTER_CONTEXT_ALTIORA_BACKUP_PRO.md"

$content = @'
# MASTER CONTINUITY & CONTEXT FILE
## Projet : Altiora Backup Pro

Auteur : Guy Mouyémè
Organisation : Altiora Patrimoine
Date : 06 mars 2026
Statut : Référence officielle de continuité du projet

---

## 1 — OBJECTIF DU DOCUMENT

Ce document constitue la référence principale de continuité du projet Altiora Backup Pro.

Il permet :

- de reconstruire le contexte complet du projet
- de reprendre le développement après interruption
- de restaurer le pipeline de release
- de comprendre l’architecture et les choix de sécurité
- de redémarrer le projet même plusieurs années plus tard sans perte d’information
'@

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

[System.IO.File]::WriteAllText($path, $content, $utf8NoBom)

Write-Host "OK: MASTER_CONTEXT_ALTIORA_BACKUP_PRO.md rewritten in UTF-8"