$ErrorActionPreference = "Stop"

$path = "C:\Dev\AltioraBackupPro\MASTER_CONTEXT_ALTIORA_BACKUP_PRO.md"

$content = @'
# MASTER CONTINUITY & CONTEXT FILE
## Projet : Altiora Backup Pro

**Auteur :** Guy Mouyémè
**Organisation :** Altiora Patrimoine
**Date :** 06 mars 2026
**Statut :** Référence officielle de continuité du projet

---

## 1 — OBJECTIF DU DOCUMENT

Ce document constitue la référence principale de continuité du projet Altiora Backup Pro.

Il permet :

- de reconstruire le contexte complet du projet
- de reprendre le développement après interruption
- de restaurer le pipeline de release
- de comprendre l’architecture et les choix de sécurité
- de redémarrer le projet même plusieurs années plus tard sans perte d’information

---

## 2 — DESCRIPTION DU PROJET

Altiora Backup Pro est un logiciel professionnel de sauvegarde chiffrée développé par Altiora Patrimoine.

### Objectif

Créer une solution de sauvegarde sécurisée destinée à une distribution commerciale professionnelle.

### Caractéristiques principales

- chiffrement AES-256-GCM
- dérivation de clé PBKDF2
- compression intégrée
- architecture fail-closed
- pipeline de release sécurisé
- signature cryptographique
- distribution EXE standalone

### Philosophie du projet

- sécurité maximale
- pipeline déterministe
- zéro perte de données
- validation cryptographique systématique

---

## 3 — ENVIRONNEMENT TECHNIQUE

### Système

Windows 10

### Shell

PowerShell 5.1

### Langage

Python 3.11

### Repo local

`C:\Dev\AltioraBackupPro`

### Environnement build

`.venv_build`

### Compilation

PyInstaller (mode onefile)

---

## 4 — STRUCTURE DU PROJET

```text
altiora.py

src/
  backup_core.py

tools/
  patch_runner.ps1
  release_build_and_backup.ps1
  release_finalize_and_state.ps1
  safe_fs.ps1

_out/
  baseline_lock.json
  releases/
  snapshots/

_release/

_fixtures/
  selftest_src/

dist/
build/