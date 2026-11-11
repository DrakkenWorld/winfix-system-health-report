# WinFix — Rapport de santé du système

Un inventaire Windows en lecture seule, avec rapports HTML et JSON conservés sur votre ordinateur.

1. Téléchargez **WinFix-SystemHealthReport-v1.0.0.zip** dans les [versions GitHub](https://github.com/DrakkenWorld/winfix-system-health-report/releases/latest).
2. Extrayez tous les fichiers, puis double-cliquez sur **Start-FR.cmd**.
3. Consultez le rapport HTML dans le navigateur. Retrouvez les deux fichiers dans **WinFix-Reports**, à côté du lanceur.

Le lanceur utilise Windows PowerShell 5.1, inclus dans Windows 10 et 11. Sa stratégie d’exécution ne s’applique qu’au processus qu’il ouvre. Vérifiez le code téléchargé avant de l’exécuter.

## Utilisation avec PowerShell

```powershell
.\script\WinFix-SystemHealthReport.ps1 -Language fr -OutputDirectory .\WinFix-Reports -EventDays 7
```

Lancez la commande depuis le dossier extrait avec Windows PowerShell 5.1 ou PowerShell 7. Ajoutez `-OpenReport` pour ouvrir le rapport. La période des événements va de 1 à 30 jours. Chaque exécution crée un dossier distinct. Le code 0 indique une collecte complète, le code 2 un rapport partiel et le code 1 un échec.

## Contenu et confidentialité

Le rapport rassemble l’édition et le démarrage de Windows, le modèle du PC, la mémoire, le processeur, les volumes fixes et les pilotes. Les journaux Système et Application sont résumés séparément. Chaque résumé compte au plus les 1 000 événements critiques, erreurs et avertissements les plus récents dans la période choisie. Le rapport signale un résultat tronqué ou un journal inaccessible. Ces comptes donnent un contexte pour le dépannage.

La collecte se fait localement et peut s’effectuer sans droits administrateur. Les droits Windows peuvent limiter certaines sources. Le rapport exclut les messages détaillés des événements, noms de machine et d’utilisateur, numéros de série et adresses IP. Vérifiez les modèles matériels et les messages d’erreur avant de partager le rapport.

Le code est sous [licence MIT](LICENSE). Les [résultats des tests](docs/VALIDATION.md) et le [guide anglais](README.md) sont inclus.
