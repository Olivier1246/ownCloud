# Guide de Maintenance ownCloud

## Tâches de Maintenance Régulières

### Quotidiennes

#### Vérification du Statut
```bash
cd /opt/owncloud-scripts/maintenance
sudo bash monitoring.sh
```

#### Vérification des Logs
```bash
# Logs ownCloud
sudo tail -f /var/www/owncloud/data/owncloud.log

# Logs Apache
sudo tail -f /var/log/apache2/owncloud_error.log
```

### Hebdomadaires

#### Sauvegarde Manuelle
```bash
cd /opt/owncloud-scripts/maintenance
sudo bash backup.sh
```

#### Nettoyage des Fichiers Temporaires
```bash
sudo -u www-data php /var/www/owncloud/occ files:cleanup
```

#### Vérification de l'Intégrité
```bash
sudo -u www-data php /var/www/owncloud/occ integrity:check-core
```

### Mensuelles

#### Mise à Jour
```bash
cd /opt/owncloud-scripts/maintenance
sudo bash update.sh
```

#### Optimisation de la Base de Données
```bash
sudo -u www-data php /var/www/owncloud/occ db:add-missing-indices
sudo -u www-data php /var/www/owncloud/occ db:add-missing-columns
sudo -u www-data php /var/www/owncloud/occ db:convert-filecache-bigint
```

#### Analyse de l'Espace Disque
```bash
# Taille de la base de données
sudo mysql -u root -p -e "SELECT table_schema AS 'Database', ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)' FROM information_schema.TABLES GROUP BY table_schema;"

# Taille des données
sudo du -sh /var/owncloud-data

# Fichiers orphelins
sudo -u www-data php /var/www/owncloud/occ files:scan --all
```

## Sauvegardes

### Sauvegarde Manuelle

#### Sauvegarde Complète
```bash
#!/bin/bash
# Sauvegarde complète manuelle

BACKUP_DIR="/var/backups/owncloud-manual-$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

# Mode maintenance ON
sudo -u www-data php /var/www/owncloud/occ maintenance:mode --on

# Base de données
sudo mysqldump -u owncloud -p owncloud | gzip > "$BACKUP_DIR/database.sql.gz"

# Configuration
sudo tar -czf "$BACKUP_DIR/config.tar.gz" -C /var/www/owncloud config/

# Données
sudo tar -czf "$BACKUP_DIR/data.tar.gz" -C /var/owncloud-data .

# Mode maintenance OFF
sudo -u www-data php /var/www/owncloud/occ maintenance:mode --off

echo "Sauvegarde terminée: $BACKUP_DIR"
```

### Restauration

#### Restaurer à partir d'une Sauvegarde
```bash
#!/bin/bash
# ATTENTION: Arrête ownCloud pendant la restauration

BACKUP_DIR="/var/backups/owncloud/backup-20251225"

# Mode maintenance ON
sudo -u www-data php /var/www/owncloud/occ maintenance:mode --on

# Restaurer la base de données
gunzip < "$BACKUP_DIR/database.sql.gz" | sudo mysql -u owncloud -p owncloud

# Restaurer la configuration
sudo tar -xzf "$BACKUP_DIR/config.tar.gz" -C /var/www/owncloud/

# Restaurer les données
sudo tar -xzf "$BACKUP_DIR/data.tar.gz" -C /var/owncloud-data/

# Permissions
sudo chown -R www-data:www-data /var/www/owncloud
sudo chown -R www-data:www-data /var/owncloud-data

# Mode maintenance OFF
sudo -u www-data php /var/www/owncloud/occ maintenance:mode --off

echo "Restauration terminée"
```

## Maintenance de la Base de Données

### Optimisation
```bash
# Optimiser toutes les tables
sudo mysqlcheck -u root -p --optimize owncloud

# Réparer les tables
sudo mysqlcheck -u root -p --repair owncloud

# Analyser les tables
sudo mysqlcheck -u root -p --analyze owncloud
```

### Vérification
```bash
# État des tables
sudo mysql -u root -p -e "USE owncloud; SHOW TABLE STATUS;"

# Taille par table
sudo mysql -u root -p owncloud -e "SELECT table_name AS 'Table', ROUND(((data_length + index_length) / 1024 / 1024), 2) AS 'Size (MB)' FROM information_schema.TABLES WHERE table_schema = 'owncloud' ORDER BY (data_length + index_length) DESC;"
```

## Logs

### Rotation des Logs

#### Configuration Logrotate
```bash
sudo nano /etc/logrotate.d/owncloud
```

Contenu:
```
/var/www/owncloud/data/owncloud.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 www-data www-data
    sharedscripts
    postrotate
        sudo -u www-data php /var/www/owncloud/occ log:manage --backend=file
    endscript
}
```

### Analyse des Logs
```bash
# Erreurs récentes
sudo grep -i error /var/www/owncloud/data/owncloud.log | tail -n 20

# Avertissements
sudo grep -i warning /var/www/owncloud/data/owncloud.log | tail -n 20

# Par utilisateur
sudo grep "user123" /var/www/owncloud/data/owncloud.log
```

## Gestion des Utilisateurs

### Commandes Utilisateur
```bash
# Créer un utilisateur
sudo -u www-data php /var/www/owncloud/occ user:add --display-name="Jean Dupont" --group="users" jean.dupont

# Lister les utilisateurs
sudo -u www-data php /var/www/owncloud/occ user:list

# Réinitialiser le mot de passe
sudo -u www-data php /var/www/owncloud/occ user:resetpassword jean.dupont

# Désactiver un utilisateur
sudo -u www-data php /var/www/owncloud/occ user:disable jean.dupont

# Supprimer un utilisateur
sudo -u www-data php /var/www/owncloud/occ user:delete jean.dupont

# Informations utilisateur
sudo -u www-data php /var/www/owncloud/occ user:info jean.dupont
```

### Gestion des Groupes
```bash
# Créer un groupe
sudo -u www-data php /var/www/owncloud/occ group:add "Développeurs"

# Ajouter un utilisateur à un groupe
sudo -u www-data php /var/www/owncloud/occ group:adduser "Développeurs" jean.dupont

# Lister les groupes
sudo -u www-data php /var/www/owncloud/occ group:list
```

## Performance

### Scan des Fichiers
```bash
# Scanner tous les fichiers
sudo -u www-data php /var/www/owncloud/occ files:scan --all

# Scanner un utilisateur spécifique
sudo -u www-data php /var/www/owncloud/occ files:scan jean.dupont

# Scan en arrière-plan
sudo -u www-data php /var/www/owncloud/occ files:scan --all --background
```

### Cache
```bash
# Vider le cache
sudo -u www-data php /var/www/owncloud/occ cache:clear

# Rebuilder le cache
sudo -u www-data php /var/www/owncloud/occ cache:rebuild
```

## Mises à Jour

### Vérifier les Mises à Jour
```bash
# Vérifier les mises à jour ownCloud
sudo -u www-data php /var/www/owncloud/occ update:check

# Vérifier les mises à jour système
sudo apt update
sudo apt list --upgradable
```

### Mise à Jour Automatique
```bash
cd /opt/owncloud-scripts/maintenance
sudo bash update.sh
```

### Mise à Jour Manuelle
```bash
# Mode maintenance
sudo -u www-data php /var/www/owncloud/occ maintenance:mode --on

# Télécharger nouvelle version
cd /tmp
wget https://download.owncloud.com/server/stable/owncloud-x.x.x.tar.bz2

# Sauvegarder config
cp -r /var/www/owncloud/config /tmp/owncloud-config-backup

# Remplacer les fichiers
sudo rm -rf /var/www/owncloud/*
sudo tar -xjf owncloud-x.x.x.tar.bz2 -C /var/www/

# Restaurer config
sudo rm -rf /var/www/owncloud/config
sudo mv /tmp/owncloud-config-backup /var/www/owncloud/config

# Permissions
sudo chown -R www-data:www-data /var/www/owncloud

# Mise à jour ownCloud
sudo -u www-data php /var/www/owncloud/occ upgrade

# Mode maintenance OFF
sudo -u www-data php /var/www/owncloud/occ maintenance:mode --off
```

## Monitoring Automatique

### Script de Monitoring
```bash
# Créer un script de monitoring personnalisé
sudo nano /usr/local/bin/owncloud-health-check.sh
```

Contenu:
```bash
#!/bin/bash

# Vérifier les services
systemctl is-active --quiet apache2 || echo "ALERTE: Apache down"
systemctl is-active --quiet mariadb || echo "ALERTE: MariaDB down"

# Vérifier l'espace disque
DISK_USAGE=$(df -h / | awk 'NR==2{print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 90 ]; then
    echo "ALERTE: Disque à ${DISK_USAGE}%"
fi

# Vérifier ownCloud
sudo -u www-data php /var/www/owncloud/occ status || echo "ALERTE: ownCloud problème"
```

### Cron de Monitoring
```bash
# Ajouter au crontab
sudo crontab -e
```

Ajouter:
```cron
*/30 * * * * /usr/local/bin/owncloud-health-check.sh | mail -s "ownCloud Health Check" admin@exemple.com
```

---

**Version:** 1.0.0  
**Dernière mise à jour:** Décembre 2025
