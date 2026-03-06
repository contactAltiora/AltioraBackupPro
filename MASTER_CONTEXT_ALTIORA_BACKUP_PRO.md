\# MASTER CONTINUITY \& CONTEXT FILE

\## Projet : Altiora Backup Pro



\*\*Auteur :\*\* Guy Mouyémè  

\*\*Organisation :\*\* Altiora Patrimoine  

\*\*Date :\*\* 06 mars 2026  

\*\*Statut :\*\* Référence officielle de continuité du projet



---



\## 1 — OBJECTIF DU DOCUMENT



Ce document constitue la référence principale de continuité du projet \*\*Altiora Backup Pro\*\*.



Il permet :



\- de reconstruire le contexte complet du projet

\- de reprendre le développement après interruption

\- de restaurer le pipeline de release

\- de comprendre l’architecture et les choix de sécurité

\- de redémarrer le projet même plusieurs années plus tard sans perte d’information



---



\## 2 — DESCRIPTION DU PROJET



\*\*Altiora Backup Pro\*\* est un logiciel professionnel de sauvegarde chiffrée développé par \*\*Altiora Patrimoine\*\*.



\### Objectif



Créer une solution de sauvegarde sécurisée destinée à une distribution commerciale professionnelle.



\### Caractéristiques principales



\- chiffrement AES-256-GCM

\- dérivation de clé PBKDF2

\- compression intégrée

\- architecture fail-closed

\- pipeline de release sécurisé

\- signature cryptographique

\- distribution EXE standalone



\### Philosophie du projet



\- sécurité maximale

\- pipeline déterministe

\- zéro perte de données

\- validation cryptographique systématique



---



\## 3 — ENVIRONNEMENT TECHNIQUE



\### Système



Windows 10



\### Shell



PowerShell 5.1



\### Langage



Python 3.11



\### Repo local



`C:\\Dev\\AltioraBackupPro`



\### Environnement build



`.venv\_build`



\### Compilation



PyInstaller (mode onefile)



---



\## 4 — STRUCTURE DU PROJET



```text

altiora.py



src/

&nbsp; backup\_core.py



tools/

&nbsp; patch\_runner.ps1

&nbsp; release\_build\_and\_backup.ps1

&nbsp; release\_finalize\_and\_state.ps1

&nbsp; safe\_fs.ps1



\_out/

&nbsp; baseline\_lock.json

&nbsp; releases/

&nbsp; snapshots/



\_release/



\_fixtures/

&nbsp; selftest\_src/



dist/

build/

