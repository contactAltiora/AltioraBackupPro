# SECURITY MODEL — Altiora Backup Pro

## Objectif
Décrire les menaces couvertes par Altiora Backup Pro et les garanties offertes.

## Actifs protégés
- Données sauvegardées (confidentialité)
- Intégrité des sauvegardes
- Mot de passe utilisateur
- Métadonnées (noms, tailles, structure)

## Modèle d’attaquant

### A1 — Attaquant sans mot de passe
- Accès au fichier `.altb`
- Accès disque ou vol du support

➡️ Protection :
- Chiffrement AES-256-GCM
- Clé dérivée par PBKDF2 (300 000 itérations)
- Aucune donnée en clair exploitable

### A2 — Attaquant modifiant le fichier
- Flip de bits
- Corruption volontaire ou accidentelle

➡️ Protection :
- Authenticated Encryption (AES-GCM)
- Échec systématique de `verify`

### A3 — Mauvais mot de passe
➡️ Protection :
- Authentification GCM
- Aucun oracle exploitable
- Exit code ≠ 0

### A4 — Erreur utilisateur
- Mauvais mot de passe
- Écrasement accidentel

➡️ Protection :
- Vérification préalable
- Option `--force` explicite

## Menaces hors périmètre
- Mot de passe faible choisi par l’utilisateur
- Compromission de la machine (keylogger)
- Sauvegardes non testées par l’utilisateur

## Conclusion
Altiora Backup Pro protège efficacement la **confidentialité** et l’**intégrité** des données
contre un attaquant disposant du fichier ou du support de stockage.
