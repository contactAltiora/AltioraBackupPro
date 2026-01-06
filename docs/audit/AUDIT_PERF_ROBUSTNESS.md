# AUDIT PERFORMANCE & ROBUSTESSE — Altiora Backup Pro

## Scripts
- tests/performance_benchmark.ps1
- tests/robustness_edge_cases.ps1
- tests/security_tamper_test.ps1 (déjà en place)

## Ce que l’on mesure
- Temps de backup/verify/restore sur tailles 1MB, 50MB, 200MB
- Vérification intégrité AES-GCM (tamper)
- Comportement sur mauvais mot de passe, fichier inexistant, args manquants

## Fichiers de preuve
- artifacts/audit/perf_benchmark.csv

## Critères de validation
- Verify échoue si fichier modifié ou mauvais mot de passe
- Restore échoue si verify échoue
- Exit codes non nuls sur erreur d’entrée
- Pas de crash / stacktrace brut utilisateur (si possible)

## À compléter
Copier ici les résultats du CSV et une note “OK / KO” par test.
