# CRYPTO POLICY — Altiora Backup Pro

## Algorithmes utilisés
- Chiffrement: AES-256-GCM
- KDF: PBKDF2-HMAC-SHA256
- Compression: zlib

## Justifications

### AES-256-GCM
- Standard industriel (NIST)
- Confidentialité + intégrité
- Performance élevée
- Large support matériel

### PBKDF2
- Résistant au brute-force
- Paramétrable
- Standard éprouvé

Paramètres actuels:
- 300 000 itérations
- Salt aléatoire

## Limites connues
- PBKDF2 moins résistant que Argon2 face aux GPU
- Dépend de la force du mot de passe utilisateur

## Évolutions prévues
- Support Argon2id
- Politique de rotation KDF
- Version 2 du format .altb

## Conformité
- Conforme aux bonnes pratiques OWASP
- Conforme aux recommandations NIST (SP 800-132)
