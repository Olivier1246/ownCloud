# Scripts d'Installation ownCloud 10.16.0

Suite complète de scripts d'installation, de maintenance et de monitoring pour ownCloud Server 10.16.0.

## 📋 Prérequis

- Ubuntu 22.04 LTS / Debian 12 ou supérieur
- Accès root ou sudo
- Connexion Internet
- Minimum 2 Go de RAM
- Minimum 10 Go d'espace disque

## 🚀 Installation Rapide

```bash
# 1. Installer les prérequis
cd install
sudo bash 01-prerequisites.sh

# 2. Lancer l'installation principale
sudo bash 02-install-owncloud.sh
```

## 📁 Structure du Projet

```
.
├── README.md                          # Ce fichier
├── .gitignore                         # Fichiers à ignorer
├── install/                           # Scripts d'installation
│   ├── 01-prerequisites.sh           # Installation des prérequis
│   └── 02-install-owncloud.sh        # Installation principale
├── maintenance/                       # Scripts de maintenance
│   ├── backup.sh                     # Sauvegarde automatique
│   ├── update.sh                     # Mise à jour
│   └── monitoring.sh                 # Monitoring système
└── documentation/                     # Documentation complète
    ├── installation.md               # Guide d'installation
    ├── configuration.md              # Configuration post-install
    ├── maintenance.md                # Guide de maintenance
    ├── troubleshooting.md            # Résolution de problèmes
    └── security.md                   # Recommandations sécurité
```

## 📖 Documentation

Consultez le dossier `documentation/` pour des guides détaillés :

- [Guide d'Installation](documentation/installation.md)
- [Configuration](documentation/configuration.md)
- [Maintenance](documentation/maintenance.md)
- [Dépannage](documentation/troubleshooting.md)
- [Sécurité](documentation/security.md)

## 🔒 Sécurité

- **Toujours** sauvegarder avant une mise à jour
- Utiliser HTTPS en production
- Modifier les mots de passe par défaut
- Activer l'authentification à deux facteurs
- Consulter [security.md](documentation/security.md)

## 🛠️ Maintenance

### Sauvegarde
```bash
cd maintenance
sudo bash backup.sh
```

### Mise à jour
```bash
cd maintenance
sudo bash update.sh
```

### Monitoring
```bash
cd maintenance
sudo bash monitoring.sh
```

## 📊 Fonctionnalités

- ✅ Installation automatisée complète
- ✅ Configuration Apache/MariaDB optimisée
- ✅ SSL/TLS avec Let's Encrypt (optionnel)
- ✅ Sauvegardes automatiques
- ✅ Monitoring système
- ✅ Mises à jour facilitées
- ✅ Logs détaillés

## 🔧 Configuration Post-Installation

1. Accédez à `https://votre-domaine.com`
2. Créez le compte administrateur
3. Configurez les applications
4. Configurez les sauvegardes automatiques
5. Activez les notifications

## 📝 Logs

Les logs sont stockés dans :
- Installation : `/var/log/owncloud-install.log`
- Apache : `/var/log/apache2/`
- ownCloud : `/var/www/owncloud/data/owncloud.log`
- Sauvegardes : `/var/log/owncloud-backup.log`

## 🆘 Support

En cas de problème :
1. Consultez [troubleshooting.md](documentation/troubleshooting.md)
2. Vérifiez les logs
3. Consultez la documentation officielle : https://doc.owncloud.com

## 📜 Licence

Ces scripts sont fournis "tels quels" sans garantie.
ownCloud est distribué sous licence AGPLv3.

## ✨ Auteur

Scripts créés pour faciliter le déploiement d'ownCloud Server.

## 🔄 Version

- **Version des scripts** : 1.0.0
- **ownCloud Server** : 10.16.0
- **Dernière mise à jour** : Décembre 2025
