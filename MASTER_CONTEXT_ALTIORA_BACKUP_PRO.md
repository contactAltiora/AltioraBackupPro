# MASTER CONTINUITY & CONTEXT FILE
## Projet : Altiora Backup Pro

Auteur : Guy Mouyeme
Organisation : Altiora Patrimoine
Date : 06 mars 2026
Statut : Reference officielle de continuite du projet

---

## 1 - OBJECTIF DU DOCUMENT

Ce document constitue la reference principale de continuite du projet Altiora Backup Pro.

Il permet :

- de reconstruire le contexte complet du projet
- de reprendre le developpement apres interruption
- de restaurer le pipeline de release
- de comprendre l architecture et les choix de securite
- de redemarrer le projet meme plusieurs annees plus tard sans perte d information

---

## 2 - DESCRIPTION DU PROJET

Altiora Backup Pro est un logiciel professionnel de sauvegarde chiffree developpe par Altiora Patrimoine.

### Objectif

Creer une solution de sauvegarde securisee destinee a une distribution commerciale professionnelle.

### Caracteristiques principales

- chiffrement AES-256-GCM
- derivation de cle PBKDF2
- compression integree
- architecture fail-closed
- pipeline de release securise
- signature cryptographique
- distribution EXE standalone

### Philosophie du projet

- securite maximale
- pipeline deterministe
- zero perte de donnees
- validation cryptographique systematique

---

## 3 - ENVIRONNEMENT TECHNIQUE

### Systeme

Windows 10

### Shell

PowerShell 5.1

### Langage

Python 3.11

### Repo local

C:\Dev\AltioraBackupPro

### Environnement build

.venv_build

### Compilation

PyInstaller (mode onefile)

---

## 4 - STRUCTURE DU PROJET

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

---

## 5 - ARCHITECTURE CRYPTOGRAPHIQUE

### Algorithme

AES-256-GCM

### Proprietes

- chiffrement authentifie
- protection contre modification des donnees

### Derivation de cle

PBKDF2

### Parametres

iterations = 300000

### Objectif

Resistance renforcee aux attaques par force brute.

---

## 6 - SELFTEST CRYPTOGRAPHIQUE

### Emplacement

_fixtures/selftest_src

### Test execute

RUN SELFTEST (ULTRA STRICT)
N=10 backups

### Verifications

- unicite des NONCE
- validite du chiffrement
- restauration correcte

### Resultat

SELFTEST OK

---

## 7 - PIPELINE DE RELEASE

### Script principal

tools/release_build_and_backup.ps1

### Etapes du pipeline

1. selftest cryptographique
2. build EXE
3. smoke tests
4. creation du dossier release
5. creation de l archive ZIP
6. generation SHA256
7. signature cryptographique
8. verification de signature
9. sauvegarde sur disques externes
10. mise a jour de STATE.md
11. signature de STATE.md

---

## 8 - RELEASE ACTUELLE

### Version

v1.0.17

### Artefacts

dist/AltioraBackupPro.exe

_release/v1.0.17/

_out/releases/
  AltioraBackupPro_v1.0.17_release.zip
  AltioraBackupPro_v1.0.17_release.zip.sig
  AltioraBackupPro_v1.0.17_release.sha256

### SHA256

36575043EC81EA3C7C441D61811C6E4D41CD339BC977940DFAA573F508191067

### Signature

VALID

---

## 9 - HISTORIQUE DES RELEASES

v1.0.12
v1.0.13
v1.0.14
v1.0.15
v1.0.16
v1.0.17p1
v1.0.17

---

## 10 - SNAPSHOTS REPOSITORY

### Dossier

_out/snapshots

### Exemple

ABP_C_20260218_230630_21eb648.zip

### Sauvegardes physiques

- F:\ABP_SNAPSHOTS
- H:\ABP_SNAPSHOTS

---

## 11 - SAUVEGARDES RELEASE

### Double sauvegarde officielle

- F:\ABP_RELEASES
- H:\ABP_RELEASES

### Contenu sauvegarde

ZIP
ZIP.sig
ZIP.sha256
STATE.md
STATE.md.sig

---

## 12 - FICHIERS CRITIQUES

altiora.py
src/backup_core.py
tools/release_build_and_backup.ps1
tools/release_finalize_and_state.ps1
tools/safe_fs.ps1
tools/patch_runner.ps1
STATE.md
_out/baseline_lock.json
MASTER_CONTEXT_ALTIORA_BACKUP_PRO.md

---

## 13 - GIT SNAPSHOT

### Branche

dev_v1.0.17

### HEAD commit

21eb648

### Remote

origin/dev_v1.0.17

### Repo root

C:\Dev\AltioraBackupPro

### Etat attendu du repo

git status --porcelain
(empty)

---

## 14 - PATCHES RECENTS IMPORTANTS

### Correctifs realises

- bootstrap SAFE_FS
- correction fallback Safe-GetChildItem
- correction parsing version release
- correction du scope d execution des patches

### Patches importants

patch_release_safe_fs_bootstrap_fix_v4_SAFE.ps1
patch_fix_release_finalize_parse_version_v2_SAFE.ps1
patch_runner scope correction

---

## 15 - PROCEDURE DE REPRISE COMPLETE

### Etape 1 - Restaurer le snapshot repository

Source principale :
_out/snapshots

Backups physiques :
- F:\ABP_SNAPSHOTS
- H:\ABP_SNAPSHOTS

### Etape 2 - Verifier la baseline

_out/baseline_lock.json

### Etape 3 - Verifier les releases existantes

_out/releases

### Etape 4 - Verifier les fichiers critiques

- altiora.py
- src/backup_core.py
- tools/release_build_and_backup.ps1
- tools/release_finalize_and_state.ps1
- tools/safe_fs.ps1
- tools/patch_runner.ps1
- STATE.md
- MASTER_CONTEXT_ALTIORA_BACKUP_PRO.md

### Etape 5 - Rebuild complet si necessaire

tools/release_build_and_backup.ps1

### Etape 6 - Verifier integrite et signature

- SHA256
- signature ZIP
- signature STATE
- coherence avec les backups F: et H:

---

## 16 - ROADMAP TECHNIQUE

### Prochaine etape immediate

CLIENT BUNDLE

Nom cible :
AltioraBackupPro_ClientBundle_v1

### Structure prevue

AltioraBackupPro_ClientBundle_v1/
  AltioraBackupPro.exe
  README.txt
  LICENSE.txt
  restore_example.ps1
  checksum.sha256
  signature.sig

### Objectif

Creer une distribution client simple, testable et securisee.

---

## 17 - ROADMAP PRODUIT

Etapes futures :

1. distribution publique
2. installer MSI
3. interface GUI
4. licence automatique
5. API cloud backup
6. monitoring backup

---

## 18 - MODELE ECONOMIQUE

### FREE

Limite de restauration :
1 GB

### PRO

Abonnement :
49,99 EUR / mois

### Licence lifetime

A definir ulterieurement.

---

## 19 - INTEGRATION A L ECOSYSTEME ALTIORA

A terme, Altiora Backup Pro doit s integrer dans :

- Altiora IA Agentique
- Altiora Box Conformite
- Altiora CRM
- Altiora Data Vault

---

## 20 - OBJECTIF STRATEGIQUE

Construire une solution :

- hautement securisee
- professionnelle
- commercialisable
- integree a l ecosysteme Altiora

---

## 21 - REGLES DE CONTINUITE DU PROJET

Toute modification doit respecter :

- architecture fail-closed
- pipeline deterministe
- validation cryptographique
- zero perte de donnees
- compatibilite avec les sauvegardes existantes
- priorite a la stabilite avant l ajout de nouvelles couches produit

---

## 22 - PROTOCOLE DE REPRISE DANS UN NOUVEAU CHAT

Pour reprendre le projet dans un nouveau chat, utiliser cette phrase :

Nova, reprends le projet Altiora Backup Pro a partir du MASTER CONTINUITY & CONTEXT FILE ci-dessous.

Puis coller ce document.

---

## 23 - SAUVEGARDE RECOMMANDEE DU PRESENT DOCUMENT

Ce fichier doit etre conserve :

1. a la racine du repo
   C:\Dev\AltioraBackupPro\MASTER_CONTEXT_ALTIORA_BACKUP_PRO.md

2. dans les snapshots
   C:\Dev\AltioraBackupPro\_out\snapshots\MASTER_CONTEXT_ALTIORA_BACKUP_PRO.md

3. sur les supports externes
   F:\ABP_SNAPSHOTS
   H:\ABP_SNAPSHOTS

4. idealement dans les futures releases ou bundles de continuite

---

## 24 - MEMO STRATEGIQUE FUTUR

Apres finalisation du produit, objectifs differes deja decides :

- construire un modele de commercialisation permettant d atteindre environ 100 000 EUR / an de revenus recurrents
- ajouter au moment opportun 3 securites techniques supplementaires avancees
- integrer Altiora Backup Pro dans la feuille de route plus large de l ecosysteme Altiora

# FIN DU DOCUMENT