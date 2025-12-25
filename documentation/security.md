# Guide de Sécurité ownCloud

## Checklist de Sécurité

### ✅ Configuration de Base

- [ ] HTTPS activé (Let's Encrypt)
- [ ] Certificat SSL valide
- [ ] Pare-feu configuré (UFW)
- [ ] Mots de passe forts partout
- [ ] Base de données sécurisée
- [ ] Permissions fichiers correctes
- [ ] Sauvegardes automatiques actives
- [ ] Monitoring en place

### ✅ Sécurité Avancée

- [ ] Authentification à deux facteurs (2FA)
- [ ] Limitation de tentatives de connexion
- [ ] Politique de mot de passe stricte
- [ ] En-têtes de sécurité HTTP
- [ ] Protection contre les injections SQL
- [ ] Rate limiting activé
- [ ] Logs d'audit activés
- [ ] Chiffrement des données au repos

## HTTPS et SSL/TLS

### Configuration SSL avec Let's Encrypt

```bash
# Installation
sudo apt install certbot python3-certbot-apache -y

# Obtenir un certificat
sudo certbot --apache -d cloud.exemple.com

# Renouvellement automatique
sudo certbot renew --dry-run

# Cron de renouvellement
(crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet") | crontab -
```

### Configuration Apache SSL

Fichier: `/etc/apache2/sites-available/owncloud-le-ssl.conf`

```apache
<IfModule mod_ssl.c>
<VirtualHost *:443>
    ServerName cloud.exemple.com
    
    # SSL Configuration
    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/cloud.exemple.com/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/cloud.exemple.com/privkey.pem
    
    # SSL Protocols et Ciphers (A+ sur SSLLabs)
    SSLProtocol all -SSLv2 -SSLv3 -TLSv1 -TLSv1.1
    SSLCipherSuite ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384
    SSLHonorCipherOrder on
    SSLCompression off
    
    # HSTS (15768000 seconds = 6 months)
    Header always set Strict-Transport-Security "max-age=15768000; includeSubDomains; preload"
    
    # Security Headers
    Header always set X-Content-Type-Options "nosniff"
    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set X-XSS-Protection "1; mode=block"
    Header always set Referrer-Policy "no-referrer"
    Header always set Permissions-Policy "geolocation=(), microphone=(), camera=()"
    
    DocumentRoot /var/www/owncloud
    
    <Directory /var/www/owncloud/>
        Options +FollowSymlinks
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
</IfModule>
```

## Pare-feu

### Configuration UFW

```bash
# Installer UFW
sudo apt install ufw -y

# Politique par défaut
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Autoriser SSH (IMPORTANT!)
sudo ufw allow 22/tcp

# Autoriser HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Activer UFW
sudo ufw enable

# Vérifier le statut
sudo ufw status verbose
```

### Limitation des Connexions (Optional)

```bash
# Limiter les connexions SSH
sudo ufw limit 22/tcp

# Règles avancées
sudo ufw allow from 192.168.1.0/24 to any port 80
```

## Authentification

### Politique de Mot de Passe

Configuration dans ownCloud:

```bash
# Longueur minimale
sudo -u www-data php /var/www/owncloud/occ config:app:set password_policy minLength --value=12

# Complexité
sudo -u www-data php /var/www/owncloud/occ config:app:set password_policy enforceUpperLowerCase --value=true
sudo -u www-data php /var/www/owncloud/occ config:app:set password_policy enforceNumericCharacters --value=true
sudo -u www-data php /var/www/owncloud/occ config:app:set password_policy enforceSpecialCharacters --value=true

# Expiration (90 jours)
sudo -u www-data php /var/www/owncloud/occ config:app:set password_policy expiration --value=90
```

### Authentification à Deux Facteurs (2FA)

```bash
# Activer l'application TOTP
sudo -u www-data php /var/www/owncloud/occ app:enable twofactor_totp

# Forcer 2FA pour un groupe
sudo -u www-data php /var/www/owncloud/occ twofactor:enforce:group admin
```

Configuration utilisateur:
1. Paramètres → Sécurité
2. Activer l'authentification TOTP
3. Scanner le QR code avec Google Authenticator/Authy

### Limitation des Tentatives de Connexion

```bash
# Installer Fail2ban
sudo apt install fail2ban -y

# Créer un filtre ownCloud
sudo nano /etc/fail2ban/filter.d/owncloud.conf
```

Contenu:
```ini
[Definition]
failregex = ^.*Login failed: '.*' \(Remote IP: '<HOST>'\).*$
            ^.*Login failed: .* \(Remote IP: '<HOST>'\).*$
ignoreregex =
```

```bash
# Configuration jail
sudo nano /etc/fail2ban/jail.local
```

Contenu:
```ini
[owncloud]
enabled = true
port = http,https
filter = owncloud
logpath = /var/www/owncloud/data/owncloud.log
maxretry = 3
bantime = 3600
findtime = 600
```

```bash
# Redémarrer Fail2ban
sudo systemctl restart fail2ban

# Vérifier le statut
sudo fail2ban-client status owncloud
```

## Permissions et Propriété

### Permissions Correctes

```bash
# Propriétaire
sudo chown -R www-data:www-data /var/www/owncloud
sudo chown -R www-data:www-data /var/owncloud-data

# Permissions des répertoires
find /var/www/owncloud -type d -exec chmod 750 {} \;
find /var/www/owncloud -type f -exec chmod 640 {} \;

# Permissions des données
chmod 770 /var/owncloud-data

# Fichiers sensibles
chmod 640 /var/www/owncloud/config/config.php
```

### SELinux (si applicable)

```bash
# Sur CentOS/RHEL
sudo semanage fcontext -a -t httpd_sys_rw_content_t "/var/www/owncloud(/.*)?"
sudo restorecon -Rv /var/www/owncloud
```

## Base de Données

### Sécurisation MariaDB

```bash
# Connexion sécurisée uniquement localhost
sudo nano /etc/mysql/mariadb.conf.d/50-server.cnf
```

Vérifier:
```ini
bind-address = 127.0.0.1
```

### Mots de Passe Forts

```bash
# Générer un mot de passe fort
openssl rand -base64 32

# Changer le mot de passe DB
mysql -u root -p
```

```sql
ALTER USER 'owncloud'@'localhost' IDENTIFIED BY 'nouveau_mot_de_passe_fort';
FLUSH PRIVILEGES;
```

Mettre à jour `config.php`:
```bash
sudo nano /var/www/owncloud/config/config.php
```

### Backup Chiffré

```bash
# Backup avec chiffrement GPG
mysqldump -u owncloud -p owncloud | gzip | gpg --symmetric --cipher-algo AES256 > backup.sql.gz.gpg

# Restaurer
gpg --decrypt backup.sql.gz.gpg | gunzip | mysql -u owncloud -p owncloud
```

## Chiffrement

### Chiffrement au Repos

```bash
# Activer le chiffrement
sudo -u www-data php /var/www/owncloud/occ encryption:enable

# Activer le chiffrement par défaut
sudo -u www-data php /var/www/owncloud/occ encryption:enable-master-key

# Chiffrer tous les fichiers existants
sudo -u www-data php /var/www/owncloud/occ encryption:encrypt-all
```

### LUKS pour le Répertoire de Données

```bash
# Créer une partition chiffrée
sudo cryptsetup luksFormat /dev/sdb1
sudo cryptsetup luksOpen /dev/sdb1 owncloud-data
sudo mkfs.ext4 /dev/mapper/owncloud-data

# Monter automatiquement
sudo nano /etc/crypttab
```

Ajouter:
```
owncloud-data /dev/sdb1 none luks
```

## Logs et Audit

### Configuration des Logs

```bash
# Niveau de log (0=Debug, 1=Info, 2=Warning, 3=Error, 4=Fatal)
sudo -u www-data php /var/www/owncloud/occ config:system:set loglevel --value=2

# Rotation automatique
sudo -u www-data php /var/www/owncloud/occ config:system:set log_rotate_size --value=104857600
```

### Logs d'Audit

```bash
# Activer l'audit
sudo -u www-data php /var/www/owncloud/occ app:enable admin_audit

# Configuration
sudo -u www-data php /var/www/owncloud/occ config:app:set admin_audit logfile --value=/var/log/owncloud-audit.log
```

### Monitoring des Logs

```bash
# Créer un script de surveillance
sudo nano /usr/local/bin/owncloud-security-monitor.sh
```

Contenu:
```bash
#!/bin/bash

# Vérifier les tentatives de connexion échouées
FAILED_LOGINS=$(grep "Login failed" /var/www/owncloud/data/owncloud.log | wc -l)
if [ $FAILED_LOGINS -gt 10 ]; then
    echo "ALERTE: $FAILED_LOGINS tentatives de connexion échouées"
    # Envoyer une notification
fi

# Vérifier les modifications de fichiers sensibles
if [ -f /var/www/owncloud/config/config.php ]; then
    md5sum /var/www/owncloud/config/config.php | md5sum -c /tmp/config.md5 || echo "ALERTE: config.php modifié"
fi
```

## Rate Limiting

### Apache mod_ratelimit

```bash
# Activer le module
sudo a2enmod ratelimit

# Configuration
sudo nano /etc/apache2/sites-available/owncloud-le-ssl.conf
```

Ajouter:
```apache
<Location /remote.php/dav>
    SetOutputFilter RATE_LIMIT
    SetEnv rate-limit 1024
</Location>
```

### Limitation par IP (mod_evasive)

```bash
# Installer
sudo apt install libapache2-mod-evasive -y

# Configuration
sudo nano /etc/apache2/mods-available/evasive.conf
```

Contenu:
```apache
<IfModule mod_evasive20.c>
    DOSHashTableSize 3097
    DOSPageCount 5
    DOSSiteCount 100
    DOSPageInterval 1
    DOSSiteInterval 1
    DOSBlockingPeriod 60
    DOSEmailNotify admin@exemple.com
    DOSLogDir "/var/log/mod_evasive"
</IfModule>
```

## Sauvegarde Sécurisée

### Chiffrement des Sauvegardes

```bash
# Script de sauvegarde chiffré
#!/bin/bash

BACKUP_DIR="/var/backups/owncloud-encrypted"
DATE=$(date +%Y%m%d_%H%M%S)
GPG_KEY="admin@exemple.com"

# Backup DB chiffré
mysqldump -u owncloud -p owncloud | gzip | gpg --encrypt --recipient $GPG_KEY > "$BACKUP_DIR/db_$DATE.sql.gz.gpg"

# Backup fichiers chiffré
tar -czf - /var/www/owncloud/config | gpg --encrypt --recipient $GPG_KEY > "$BACKUP_DIR/config_$DATE.tar.gz.gpg"
```

### Stockage Distant Sécurisé

```bash
# Rsync sur SSH
rsync -avz --delete -e "ssh -i /root/.ssh/backup-key" \
    /var/backups/owncloud/ \
    backup@remote-server:/backups/owncloud/
```

## Mises à Jour de Sécurité

### Automatiser les Mises à Jour

```bash
# Installer unattended-upgrades
sudo apt install unattended-upgrades -y

# Configuration
sudo dpkg-reconfigure -plow unattended-upgrades

# Personnaliser
sudo nano /etc/apt/apt.conf.d/50unattended-upgrades
```

### Vérifications Hebdomadaires

```bash
# Créer un script de vérification
sudo nano /usr/local/bin/security-check.sh
```

Contenu:
```bash
#!/bin/bash

echo "=== Vérification de Sécurité ownCloud ==="

# Mises à jour disponibles
echo "Mises à jour système:"
apt list --upgradable

# Certificat SSL
echo -e "\nCertificat SSL:"
certbot certificates

# Vérifier l'intégrité
echo -e "\nIntégrité ownCloud:"
sudo -u www-data php /var/www/owncloud/occ integrity:check-core

# Permissions
echo -e "\nPermissions sensibles:"
ls -la /var/www/owncloud/config/config.php
ls -la /var/owncloud-data/

# Fail2ban
echo -e "\nFail2ban status:"
sudo fail2ban-client status owncloud

echo "=== Fin de la vérification ==="
```

## Checklist Post-Installation

1. ✅ Changer tous les mots de passe par défaut
2. ✅ Activer HTTPS
3. ✅ Configurer le pare-feu
4. ✅ Installer Fail2ban
5. ✅ Activer l'authentification à deux facteurs
6. ✅ Configurer les sauvegardes chiffrées
7. ✅ Activer les logs d'audit
8. ✅ Définir une politique de mot de passe
9. ✅ Configurer les en-têtes de sécurité
10. ✅ Planifier les mises à jour automatiques

---

**Version:** 1.0.0  
**Dernière mise à jour:** Décembre 2025
