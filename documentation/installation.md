# Guide d'Installation ownCloud 10.16.0

## Table des Matières

1. [Prérequis](#prérequis)
2. [Préparation du Système](#préparation-du-système)
3. [Installation des Prérequis](#installation-des-prérequis)
4. [Installation d'ownCloud](#installation-downcloud)
5. [Configuration Initiale](#configuration-initiale)
6. [Vérification](#vérification)
7. [Dépannage](#dépannage)

## Prérequis

### Matériel Recommandé

- **CPU**: 2 cœurs minimum (4+ recommandé)
- **RAM**: 2 Go minimum (4+ Go recommandé)
- **Disque**: 
  - 10 Go pour le système et ownCloud
  - Espace supplémentaire pour les données utilisateur
- **Réseau**: Connexion Internet stable

### Système d'Exploitation

- Ubuntu 22.04 LTS ou supérieur
- Debian 12 ou supérieur
- Autre distribution Linux (non testé)

### Logiciels Requis

Les scripts installeront automatiquement:
- Apache 2.4+
- MariaDB 10.6+
- PHP 8.2+
- Extensions PHP nécessaires

## Préparation du Système

### 1. Mise à Jour du Système

```bash
sudo apt update
sudo apt upgrade -y
sudo reboot
```

### 2. Configuration du Nom de Domaine

Si vous utilisez un nom de domaine:

```bash
# Vérifier la résolution DNS
nslookup votre-domaine.com

# Configurer le hostname (optionnel)
sudo hostnamectl set-hostname cloud.exemple.com
```

### 3. Configuration du Pare-feu

```bash
# Installer UFW si nécessaire
sudo apt install ufw -y

# Autoriser SSH
sudo ufw allow 22/tcp

# Autoriser HTTP et HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Activer le pare-feu
sudo ufw enable
sudo ufw status
```

## Installation des Prérequis

### Étape 1: Télécharger les Scripts

```bash
# Cloner ou télécharger le dépôt
cd /opt
sudo git clone <url-du-depot> owncloud-scripts

# Ou télécharger manuellement
sudo wget <url-archive>
sudo tar -xzf owncloud-scripts.tar.gz
```

### Étape 2: Rendre les Scripts Exécutables

```bash
cd /opt/owncloud-scripts
sudo chmod +x install/*.sh
sudo chmod +x maintenance/*.sh
```

### Étape 3: Installer les Prérequis

```bash
cd install
sudo bash 01-prerequisites.sh
```

**Ce script installe:**
- Apache2 et modules nécessaires
- MariaDB
- PHP 8.2 et extensions
- Utilitaires (wget, curl, certbot, etc.)

**Durée estimée:** 5-10 minutes

### Étape 4: Sécuriser MariaDB

```bash
sudo mysql_secure_installation
```

Répondez aux questions:
- Enter current password: `[Appuyez sur Entrée]`
- Switch to unix_socket authentication: `N`
- Change the root password: `Y` → **Saisissez un mot de passe fort**
- Remove anonymous users: `Y`
- Disallow root login remotely: `Y`
- Remove test database: `Y`
- Reload privilege tables: `Y`

**⚠️ IMPORTANT:** Notez le mot de passe root MySQL en lieu sûr!

## Installation d'ownCloud

### Étape 1: Lancer le Script d'Installation

```bash
cd /opt/owncloud-scripts/install
sudo bash 02-install-owncloud.sh
```

### Étape 2: Suivre les Instructions

Le script demandera:

1. **Nom de domaine** 
   ```
   Exemple: cloud.exemple.com
   Ou: votre-ip-publique
   ```

2. **Email administrateur**
   ```
   Exemple: admin@exemple.com
   ```

3. **Mot de passe root MySQL**
   ```
   Le mot de passe défini à l'étape précédente
   ```

4. **Configuration SSL/TLS**
   ```
   o = Oui (recommandé si domaine)
   N = Non (tests locaux)
   ```

### Étape 3: Attendre la Fin de l'Installation

**Durée estimée:** 10-15 minutes

Le script effectue automatiquement:
- Téléchargement d'ownCloud 10.16.0
- Création de la base de données
- Configuration d'Apache
- Configuration SSL/TLS (si demandé)
- Permissions et sécurité

## Configuration Initiale

### Étape 1: Accéder à l'Interface Web

Ouvrez votre navigateur:
```
https://votre-domaine.com
ou
http://votre-ip
```

### Étape 2: Créer le Compte Administrateur

1. **Nom d'utilisateur**: Choisissez un nom (ex: admin)
2. **Mot de passe**: Choisissez un mot de passe fort

### Étape 3: Configuration de la Base de Données

Le script a déjà créé la base de données. Saisissez:

- **Type de base**: MySQL/MariaDB
- **Utilisateur**: `owncloud`
- **Mot de passe**: Voir `/root/.owncloud-db-credentials`
- **Nom de la base**: `owncloud`
- **Hôte**: `localhost`

```bash
# Pour voir les identifiants
sudo cat /root/.owncloud-db-credentials
```

### Étape 4: Répertoire des Données

**Important:** Utiliser le répertoire créé par le script:
```
/var/owncloud-data
```

Ne pas changer sauf si vous savez ce que vous faites!

### Étape 5: Finaliser l'Installation

Cliquez sur "Terminer la configuration"

**Durée:** 1-2 minutes

## Configuration Post-Installation

### Optimisation PHP

```bash
sudo nano /etc/php/8.2/apache2/php.ini
```

Vérifier/ajuster:
```ini
memory_limit = 512M
upload_max_filesize = 10G
post_max_size = 10G
max_execution_time = 3600
```

Redémarrer Apache:
```bash
sudo systemctl restart apache2
```

### Configuration des Tâches en Arrière-Plan

**Recommandé: Utiliser Cron**

```bash
# Éditer la crontab pour www-data
sudo crontab -u www-data -e

# Ajouter cette ligne:
*/15 * * * * php /var/www/owncloud/occ system:cron
```

Activer Cron dans ownCloud:
```bash
sudo -u www-data php /var/www/owncloud/occ config:app:set core backgroundjobs_mode --value cron
```

### Activer les Applications Recommandées

Via l'interface web:
1. Menu → Applications
2. Activer:
   - Activity
   - Files External
   - Files Sharing
   - Gallery
   - PDF Viewer

### Configuration Email (Optionnel)

Pour les notifications par email:

1. Menu → Paramètres → Administration → Email
2. Configurer votre serveur SMTP

## Vérification

### Tester l'Installation

```bash
# Version d'ownCloud
sudo -u www-data php /var/www/owncloud/occ -V

# Status du système
sudo -u www-data php /var/www/owncloud/occ status

# Vérifier l'intégrité
sudo -u www-data php /var/www/owncloud/occ integrity:check-core
```

### Vérifier les Services

```bash
# Apache
sudo systemctl status apache2

# MariaDB
sudo systemctl status mariadb

# Monitoring complet
cd /opt/owncloud-scripts/maintenance
sudo bash monitoring.sh
```

### Tester l'Accès

1. **Interface Web**: https://votre-domaine.com
2. **Connexion**: Utilisateur créé + mot de passe
3. **Upload**: Tester l'upload d'un fichier
4. **Partage**: Créer un lien de partage

## Sécurité Post-Installation

### 1. Configurer HTTPS (si non fait)

```bash
sudo certbot --apache -d votre-domaine.com
```

### 2. Activer l'Authentification à Deux Facteurs

Interface web → Paramètres → Applications → Chercher "Two Factor"

### 3. Configurer les Sauvegardes

```bash
# Test manuel
cd /opt/owncloud-scripts/maintenance
sudo bash backup.sh

# Automatique (quotidien à 2h du matin)
sudo crontab -e
```

Ajouter:
```
0 2 * * * /opt/owncloud-scripts/maintenance/backup.sh >> /var/log/owncloud-backup.log 2>&1
```

### 4. Configurer le Monitoring

```bash
# Test manuel
sudo bash /opt/owncloud-scripts/maintenance/monitoring.sh

# Automatique (toutes les heures)
sudo crontab -e
```

Ajouter:
```
0 * * * * /opt/owncloud-scripts/maintenance/monitoring.sh >> /var/log/owncloud-monitoring.log 2>&1
```

## Dépannage

### Problème: Page Blanche après Installation

**Solution:**
```bash
# Vérifier les logs Apache
sudo tail -f /var/log/apache2/owncloud_error.log

# Vérifier les permissions
sudo chown -R www-data:www-data /var/www/owncloud
sudo chown -R www-data:www-data /var/owncloud-data
```

### Problème: Erreur Base de Données

**Solution:**
```bash
# Vérifier MariaDB
sudo systemctl status mariadb

# Tester la connexion
mysql -u owncloud -p
# Saisir le mot de passe de /root/.owncloud-db-credentials
```

### Problème: SSL/TLS ne Fonctionne Pas

**Solution:**
```bash
# Réinstaller le certificat
sudo certbot --apache -d votre-domaine.com --force-renewal

# Vérifier la configuration
sudo apache2ctl configtest
```

### Problème: Mode Maintenance Bloqué

**Solution:**
```bash
sudo -u www-data php /var/www/owncloud/occ maintenance:mode --off
```

## Prochaines Étapes

1. ✅ Installation terminée
2. ➡️ Lire [Configuration Avancée](configuration.md)
3. ➡️ Configurer [Maintenance](maintenance.md)
4. ➡️ Consulter [Sécurité](security.md)

## Support

- Documentation officielle: https://doc.owncloud.com
- Forum: https://central.owncloud.org
- Logs: `/var/log/owncloud-*.log`

---

**Version du guide:** 1.0.0  
**Dernière mise à jour:** Décembre 2025  
**ownCloud Version:** 10.16.0
