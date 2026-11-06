# WinFix — Rapport de santé du système

Version 0.1.0 : aperçu local, pas encore de version stable publiée.

Inventaire Windows en lecture seule, avec rapports HTML et JSON locaux. Compatible Windows PowerShell 5.1 et PowerShell 7, sans dépendance supplémentaire ni obligation de droits administrateur. Les sources inaccessibles sont signalées.

```powershell
powershell.exe -NoProfile -File ./script/WinFix-SystemHealthReport.ps1 -OutputDirectory ./WinFix-Reports -Language fr -EventDays 7
```

Avec PowerShell 7, remplacez powershell.exe par pwsh.exe. Vérifiez le code et respectez votre stratégie d’exécution. Ouvrez report.html dans le dossier affiché. Chaque exécution crée un dossier distinct.

Le rapport rassemble Windows et le dernier démarrage, fabricant/modèle/mémoire, processeur, volumes fixes, pilotes et nombres d’événements critiques/erreurs/avertissements des journaux System et Application. La période va de 1 à 30 jours (7 par défaut). Maximum : les 1 000 événements correspondants les plus récents par journal. LimitReached signale une éventuelle troncature. Les noms des champs techniques restent identiques en français et en anglais.

Aucune réparation, suppression, modification de services, télémétrie ou requête réseau volontaire. Aucun score de santé : ces informations ne suffisent pas à diagnostiquer une panne. Les messages détaillés des événements, noms d’utilisateur, adresses IP et numéros de série ne sont pas collectés volontairement. Les modèles matériels et messages d’erreur peuvent toutefois être privés : relisez avant partage.

Codes de sortie : 0 collecte complète ; 2 rapport créé avec sources indisponibles ; 1 erreur fatale (un dossier partiel peut rester). La collecte est synchrone, sans annulation interactive ni délai global ; chaque requête CIM demande un délai de 15 secondes. L’inventaire des pilotes peut être volumineux. Les dates et octets du JSON ne dépendent pas de la langue.

Tests : `powershell.exe -NoProfile -File tests/Run-Tests.ps1`, puis avec `pwsh.exe`. La validation manuelle sur Windows 11 reste à effectuer. Licence MIT ; voir LICENSE. Plus de détails dans [le guide anglais](README.md).
