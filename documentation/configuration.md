# Configuration Avancée ownCloud

## Configuration Système

### Optimisation PHP

Fichier: `/etc/php/8.2/apache2/php.ini`

```ini
# Mémoire et Limites
memory_limit = 512M
upload_max_filesize = 10G
post_max_size = 10G
max_execution_time = 3600
max_input_time = 3600

# OPcache
opcache.enable = 1
opcache.memory_consumption = 128
opcache.interned_strings_buffer = 8
opcache.max_accelerated_files = 10000
opcache.revalidate_freq = 1
opcache.save_comments = 1

# Session
session.save_handler = redis
session.save_path = "tcp://127.0.0.1:6379"
```

### Configuration Apache

Fichier: `/etc/apache2/sites-available/owncloud.conf`

```apache
<VirtualHost *:443>
    ServerName cloud.exemple.com
    ServerAdmin admin@exemple.com
    
    DocumentRoot /var/www/owncloud
    
    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/cloud.exemple.com/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/cloud.exemple.com/privkey.pem
    
    <Directory /var/www/owncloud/>
        Options +FollowSymlinks
        AllowOverride All
        Require all granted
        SetEnv HOME /var/www/owncloud
        SetEnv HTTP_HOME /var/www/owncloud
    </Directory>
    
    # En-têtes de sécurité
    <IfModule mod_headers.c>
        Header always set Strict-Transport-Security "max-age=15552000; includeSubDomains"
        Header always set X-Content-Type-Options "nosniff"
        Header always set X-Frame-Options "SAMEORIGIN"
        Header always set X-XSS-Protection "1; mode=block"
        Header always set Referrer-Policy "no-referrer"
    </IfModule>
</VirtualHost>
```

### Configuration MariaDB

Fichier: `/etc/mysql/mariadb.conf.d/99-owncloud.cnf`

```ini
[mysqld]
innodb_buffer_pool_size = 512M
innodb_io_capacity = 4000
max_connections = 200
query_cache_type = 1
query_cache_limit = 2M
query_cache_size = 64M
tmp_table_size = 64M
max_heap_table_size = 64M
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 1
transaction-isolation = READ-COMMITTED
binlog_format = ROW
character-set-server = utf8mb4
collation-server = utf8mb4_general_ci
```

## Configuration ownCloud

### Fichier config.php

Fichier: `/var/www/owncloud/config/config.php`

```php
<?php
$CONFIG = array(
    'instanceid' => 'xxx',
    'passwordsalt' => 'xxx',
    'secret' => 'xxx',
    'trusted_domains' => array(
        0 => 'cloud.exemple.com',
        1 => '192.168.1.100',
    ),
    'datadirectory' => '/var/owncloud-data',
    'dbtype' => 'mysql',
    'version' => '10.16.0.0',
    'overwrite.cli.url' => 'https://cloud.exemple.com',
    'dbname' => 'owncloud',
    'dbhost' => 'localhost',
    'dbport' => '',
    'dbtableprefix' => 'oc_',
    'dbuser' => 'owncloud',
    'dbpassword' => 'xxx',
    'installed' => true,
    
    // Cache et Performance
    'memcache.local' => '\OC\Memcache\APCu',
    'memcache.distributed' => '\OC\Memcache\Redis',
    'memcache.locking' => '\OC\Memcache\Redis',
    'redis' => array(
        'host' => 'localhost',
        'port' => 6379,
    ),
    
    // Journalisation
    'log_type' => 'file',
    'logfile' => '/var/www/owncloud/data/owncloud.log',
    'loglevel' => 2,
    'logdateformat' => 'F d, Y H:i:s',
    
    // Sécurité
    'htaccess.RewriteBase' => '/',
    'check_for_working_htaccess' => true,
    'forwarded_for_headers' => array('HTTP_X_FORWARDED_FOR'),
    
    // Email
    'mail_smtpmode' => 'smtp',
    'mail_smtphost' => 'smtp.gmail.com',
    'mail_smtpport' => 587,
    'mail_smtpsecure' => 'tls',
    'mail_smtpauth' => 1,
    'mail_smtpauthtype' => 'LOGIN',
    'mail_from_address' => 'noreply',
    'mail_domain' => 'exemple.com',
    'mail_smtpname' => 'votre-email@gmail.com',
    'mail_smtppassword' => 'votre-mot-de-passe',
);
```

### Commandes de Configuration

```bash
# Définir les domaines de confiance
sudo -u www-data php /var/www/owncloud/occ config:system:set trusted_domains 0 --value=cloud.exemple.com

# Activer le cache Redis
sudo -u www-data php /var/www/owncloud/occ config:system:set memcache.local --value='\OC\Memcache\APCu'
sudo -u www-data php /var/www/owncloud/occ config:system:set memcache.distributed --value='\OC\Memcache\Redis'

# Configurer les tâches en arrière-plan (cron)
sudo -u www-data php /var/www/owncloud/occ config:app:set core backgroundjobs_mode --value cron

# Définir le niveau de log
sudo -u www-data php /var/www/owncloud/occ config:system:set loglevel --value=2

# Activer HTTPS strict
sudo -u www-data php /var/www/owncloud/occ config:system:set overwriteprotocol --value=https
```

## Applications

### Applications Recommandées

```bash
# Activer les applications
sudo -u www-data php /var/www/owncloud/occ app:enable activity
sudo -u www-data php /var/www/owncloud/occ app:enable files_external
sudo -u www-data php /var/www/owncloud/occ app:enable gallery
sudo -u www-data php /var/www/owncloud/occ app:enable files_pdfviewer

# Lister les applications
sudo -u www-data php /var/www/owncloud/occ app:list
```

### Quotas Utilisateur

```bash
# Définir un quota par défaut (10GB)
sudo -u www-data php /var/www/owncloud/occ config:app:set files default_quota --value='10GB'

# Définir un quota pour un utilisateur
sudo -u www-data php /var/www/owncloud/occ user:setting username files quota 50GB
```

## Partage

### Configuration du Partage

```bash
# Activer le partage public
sudo -u www-data php /var/www/owncloud/occ config:app:set core shareapi_allow_links --value=yes

# Durée de vie des liens (jours)
sudo -u www-data php /var/www/owncloud/occ config:app:set core shareapi_default_expire_date --value=yes
sudo -u www-data php /var/www/owncloud/occ config:app:set core shareapi_expire_after_n_days --value=7

# Forcer le mot de passe sur les liens
sudo -u www-data php /var/www/owncloud/occ config:app:set core shareapi_enforce_links_password --value=yes
```

## Sauvegardes Automatiques

### Configuration Cron

```bash
# Éditer crontab root
sudo crontab -e
```

Ajouter:
```cron
# Sauvegarde quotidienne à 2h du matin
0 2 * * * /opt/owncloud-scripts/maintenance/backup.sh >> /var/log/owncloud-backup.log 2>&1

# Monitoring toutes les heures
0 * * * * /opt/owncloud-scripts/maintenance/monitoring.sh >> /var/log/owncloud-monitoring.log 2>&1
```

## Performance

### Redis pour le Cache

```bash
# Installer Redis
sudo apt install redis-server php-redis -y

# Démarrer Redis
sudo systemctl enable redis-server
sudo systemctl start redis-server

# Configurer ownCloud
sudo -u www-data php /var/www/owncloud/occ config:system:set redis host --value=localhost
sudo -u www-data php /var/www/owncloud/occ config:system:set redis port --value=6379
```

### Prévisualisation des Fichiers

```bash
# Désactiver pour les gros fichiers
sudo -u www-data php /var/www/owncloud/occ config:system:set preview_max_x --value=2048
sudo -u www-data php /var/www/owncloud/occ config:system:set preview_max_y --value=2048
sudo -u www-data php /var/www/owncloud/occ config:system:set preview_max_scale_factor --value=2
```

---

**Version:** 1.0.0  
**Dernière mise à jour:** Décembre 2025
