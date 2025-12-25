# Guide de Dépannage ownCloud

## Problèmes Courants

### 1. Page Blanche / Erreur 500

#### Symptômes
- Page blanche lors de l'accès à ownCloud
- Erreur 500 Internal Server Error

#### Diagnostic
```bash
# Vérifier les logs Apache
sudo tail -f /var/log/apache2/owncloud_error.log

# Vérifier les logs ownCloud
sudo tail -f /var/www/owncloud/data/owncloud.log

# Vérifier PHP
sudo php -v
sudo systemctl status apache2
```

#### Solutions
```bash
# Vérifier les permissions
sudo chown -R www-data:www-data /var/www/owncloud
sudo chown -R www-data:www-data /var/owncloud-data
find /var/www/owncloud -type d -exec chmod 750 {} \;
find /var/www/owncloud -type f -exec chmod 640 {} \;

# Vérifier la configuration Apache
sudo apache2ctl configtest
sudo systemctl restart apache2

# Désactiver le mode maintenance si bloqué
sudo -u www-data php /var/www/owncloud/occ maintenance:mode --off
```

### 2. Problèmes de Connexion à la Base de Données

#### Symptômes
- Erreur "Can't connect to MySQL server"
- Page d'installation qui redemande les informations DB

#### Diagnostic
```bash
# Vérifier MariaDB
sudo systemctl status mariadb

# Tester la connexion
mysql -u owncloud -p
# Saisir le mot de passe

# Vérifier config.php
sudo cat /var/www/owncloud/config/config.php | grep db
```

#### Solutions
```bash
# Redémarrer MariaDB
sudo systemctl restart mariadb

# Vérifier les identifiants
sudo cat /root/.owncloud-db-credentials

# Recréer l'utilisateur si nécessaire
sudo mysql -u root -p
```
```sql
DROP USER 'owncloud'@'localhost';
CREATE USER 'owncloud'@'localhost' IDENTIFIED BY 'nouveau_mot_de_passe';
GRANT ALL PRIVILEGES ON owncloud.* TO 'owncloud'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

### 3. Erreurs d'Upload de Fichiers

#### Symptômes
- "File is too big"
- Upload bloqué à X%
- Timeout lors de l'upload

#### Diagnostic
```bash
# Vérifier les limites PHP
php -i | grep -E "(upload_max_filesize|post_max_size|max_execution_time)"

# Vérifier l'espace disque
df -h
```

#### Solutions
```bash
# Modifier PHP.ini
sudo nano /etc/php/8.2/apache2/php.ini
```

Modifier:
```ini
upload_max_filesize = 10G
post_max_size = 10G
max_execution_time = 3600
memory_limit = 512M
```

```bash
# Redémarrer Apache
sudo systemctl restart apache2

# Vérifier .htaccess
sudo -u www-data php /var/www/owncloud/occ maintenance:update:htaccess
```

### 4. Problèmes SSL/TLS

#### Symptômes
- "Your connection is not secure"
- Certificat expiré
- Mixed content warnings

#### Diagnostic
```bash
# Vérifier le certificat
sudo certbot certificates

# Vérifier la configuration SSL
sudo apache2ctl -S | grep 443

# Tester SSL
openssl s_client -connect cloud.exemple.com:443
```

#### Solutions
```bash
# Renouveler le certificat
sudo certbot renew --force-renewal

# Forcer HTTPS dans ownCloud
sudo -u www-data php /var/www/owncloud/occ config:system:set overwriteprotocol --value=https

# Redirection HTTP vers HTTPS
sudo nano /etc/apache2/sites-available/owncloud.conf
```

Ajouter:
```apache
<VirtualHost *:80>
    ServerName cloud.exemple.com
    Redirect permanent / https://cloud.exemple.com/
</VirtualHost>
```

### 5. Mode Maintenance Bloqué

#### Symptômes
- "System in maintenance mode"
- Impossible d'accéder à ownCloud

#### Solutions
```bash
# Désactiver via CLI
sudo -u www-data php /var/www/owncloud/occ maintenance:mode --off

# Ou modifier directement config.php
sudo nano /var/www/owncloud/config/config.php
```

Changer:
```php
'maintenance' => false,
```

### 6. Problèmes de Performance

#### Symptômes
- Pages lentes à charger
- Timeouts fréquents
- CPU/RAM élevé

#### Diagnostic
```bash
# Monitoring complet
cd /opt/owncloud-scripts/maintenance
sudo bash monitoring.sh

# Vérifier les processus
top -u www-data

# Analyser les logs lents
sudo tail -f /var/log/mysql/slow.log
```

#### Solutions
```bash
# Installer et configurer Redis
sudo apt install redis-server php-redis -y
sudo systemctl enable redis-server
sudo systemctl start redis-server

# Configuration ownCloud pour Redis
sudo -u www-data php /var/www/owncloud/occ config:system:set memcache.local --value='\OC\Memcache\APCu'
sudo -u www-data php /var/www/owncloud/occ config:system:set memcache.distributed --value='\OC\Memcache\Redis'
sudo -u www-data php /var/www/owncloud/occ config:system:set redis host --value=localhost
sudo -u www-data php /var/www/owncloud/occ config:system:set redis port --value=6379

# Optimiser la base de données
sudo -u www-data php /var/www/owncloud/occ db:add-missing-indices
sudo mysqlcheck -u root -p --optimize owncloud

# Activer opcache PHP
sudo nano /etc/php/8.2/apache2/php.ini
```

Vérifier:
```ini
opcache.enable=1
opcache.memory_consumption=128
opcache.max_accelerated_files=10000
```

### 7. Erreurs de Synchronisation Desktop Client

#### Symptômes
- "Sync paused"
- Fichiers non synchronisés
- Erreurs de conflit

#### Solutions
```bash
# Côté serveur: Rescanner les fichiers
sudo -u www-data php /var/www/owncloud/occ files:scan --all

# Vérifier les permissions
sudo chown -R www-data:www-data /var/owncloud-data

# Vérifier les locks
sudo -u www-data php /var/www/owncloud/occ files:scan --all --repair
```

Côté client:
1. Supprimer le cache local: `~/.local/share/data/ownCloud/`
2. Reconfigurer le compte
3. Resynchroniser

### 8. Problèmes d'Authentification LDAP/AD

#### Symptômes
- Impossible de se connecter avec LDAP
- Erreur "Invalid credentials"

#### Solutions
```bash
# Tester la connexion LDAP
sudo -u www-data php /var/www/owncloud/occ ldap:test-config s01

# Vérifier la configuration
sudo -u www-data php /var/www/owncloud/occ ldap:show-config s01

# Réinitialiser le cache
sudo -u www-data php /var/www/owncloud/occ ldap:reset-group s01
sudo -u www-data php /var/www/owncloud/occ ldap:reset-user s01
```

## Commandes de Diagnostic

### État Général
```bash
# Status ownCloud
sudo -u www-data php /var/www/owncloud/occ status

# Version
sudo -u www-data php /var/www/owncloud/occ -V

# Vérifier l'intégrité
sudo -u www-data php /var/www/owncloud/occ integrity:check-core

# Liste des applications
sudo -u www-data php /var/www/owncloud/occ app:list
```

### Logs
```bash
# Logs ownCloud (dernières 50 lignes)
sudo tail -n 50 /var/www/owncloud/data/owncloud.log

# Logs Apache
sudo tail -n 50 /var/log/apache2/owncloud_error.log
sudo tail -n 50 /var/log/apache2/owncloud_access.log

# Logs système
sudo journalctl -u apache2 -n 50
sudo journalctl -u mariadb -n 50
```

### Services
```bash
# Vérifier tous les services
systemctl status apache2
systemctl status mariadb
systemctl status redis-server
systemctl status cron
```

## Récupération d'Urgence

### Backup de Secours
```bash
# Si ownCloud est cassé, sauvegarder immédiatement
sudo cp -r /var/www/owncloud /var/backups/owncloud-emergency-$(date +%Y%m%d)
sudo mysqldump -u root -p owncloud > /var/backups/owncloud-db-emergency-$(date +%Y%m%d).sql
```

### Réinstallation Propre
```bash
# ATTENTION: Sauvegardez d'abord!

# 1. Sauvegarder
sudo cp -r /var/www/owncloud/config /tmp/owncloud-config-backup
sudo mysqldump -u owncloud -p owncloud > /tmp/owncloud-db-backup.sql

# 2. Supprimer l'installation
sudo rm -rf /var/www/owncloud

# 3. Réinstaller
cd /opt/owncloud-scripts/install
sudo bash 02-install-owncloud.sh

# 4. Restaurer config et DB
sudo cp -r /tmp/owncloud-config-backup/* /var/www/owncloud/config/
mysql -u owncloud -p owncloud < /tmp/owncloud-db-backup.sql

# 5. Upgrade si nécessaire
sudo -u www-data php /var/www/owncloud/occ upgrade
```

## Support et Ressources

### Documentation Officielle
- https://doc.owncloud.com
- https://doc.owncloud.com/server/admin_manual/

### Forums et Communauté
- Forum: https://central.owncloud.org
- GitHub: https://github.com/owncloud/core

### Logs Utiles
- ownCloud: `/var/www/owncloud/data/owncloud.log`
- Apache: `/var/log/apache2/owncloud_*.log`
- MariaDB: `/var/log/mysql/error.log`
- Installation: `/var/log/owncloud-install.log`
- Backup: `/var/log/owncloud-backup.log`

---

**Version:** 1.0.0  
**Dernière mise à jour:** Décembre 2025
