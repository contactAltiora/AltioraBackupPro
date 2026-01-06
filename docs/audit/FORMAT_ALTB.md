# FORMAT .ALTB — Altiora Backup Pro

## Vue d’ensemble
Le fichier `.altb` est une archive chiffrée, authentifiée et compressée.

## Structure logique

[ Header | Payload chiffré | Tag d’authentification ]

## Header (non chiffré, authentifié)
- Magic: ALTB
- Version: 1
- Algorithme: AES-256-GCM
- KDF: PBKDF2-HMAC-SHA256
- Itérations: 300 000
- Compression: oui/non
- Longueur métadonnées

## Payload (chiffré)
- Métadonnées (JSON)
- Données compressées

## Authentification
- Tag GCM vérifié lors de `verify` et `restore`
- Toute modification invalide le fichier

## Propriétés de sécurité
- Confidentialité
- Intégrité
- Authenticité

## Compatibilité future
- Versionnement du header
- Migration possible sans casser les backups
