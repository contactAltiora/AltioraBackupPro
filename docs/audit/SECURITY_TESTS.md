# SECURITY TESTS — Altiora Backup Pro

## Tests automatisés

### CI Smoke Test
- Backup / Verify / Restore
- Exit codes contrôlés
- Exécuté à chaque push

### Tamper Test
- Modification volontaire du fichier
- `verify` doit échouer
- Test automatisé PowerShell

### Mauvais mot de passe
- Vérification échoue
- Aucun crash
- Message explicite

## Résultats attendus
- Aucune restauration possible sans intégrité valide
- Aucune information divulguée

## Intégration CI
- GitHub Actions
- Windows latest
- Python 3.11
