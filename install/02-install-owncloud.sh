#!/bin/bash
#########################################################################
# Script d'installation d'ownCloud 10.16.0
# Description: Installation et configuration complète d'ownCloud
# Auteur: Scripts ownCloud
# Version: 1.0.0
# Date: Décembre 2025
#########################################################################

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Variables de configuration
OWNCLOUD_VERSION="10.16.0"
OWNCLOUD_URL="https://download.owncloud.com/server/stable/owncloud-${OWNCLOUD_VERSION}.tar.bz2"
INSTALL_DIR="/var/www/owncloud"
DATA_DIR="/var/owncloud-data"
LOG_FILE="/var/log/owncloud-install.log"
APACHE_CONF="/etc/apache2/sites-available/owncloud.conf"

# Variables base de données
DB_NAME="owncloud"
DB_USER="owncloud"
DB_ROOT_PASS=""
DB_USER_PASS=""

#########################################################################
# Fonctions utilitaires
#########################################################################

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERREUR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

warning() {
    echo -e "${YELLOW}[ATTENTION]${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "Ce script doit être exécuté en tant que root (sudo)"
    fi
}

generate_password() {
    tr -dc 'A-Za-z0-9!@#$%^&*' < /dev/urandom | head -c 32
}

#########################################################################
# Configuration interactive
#########################################################################

configure_installation() {
    echo ""
    echo "=========================================="
    echo "  Configuration de l'installation"
    echo "=========================================="
    echo ""
    
    # Nom de domaine
    read -p "Nom de domaine (ex: cloud.exemple.com): " DOMAIN_NAME
    if [ -z "$DOMAIN_NAME" ]; then
        error "Le nom de domaine est requis"
    fi
    
    # Email administrateur
    read -p "Email administrateur: " ADMIN_EMAIL
    if [ -z "$ADMIN_EMAIL" ]; then
        warning "Aucun email fourni, utilisation de admin@${DOMAIN_NAME}"
        ADMIN_EMAIL="admin@${DOMAIN_NAME}"
    fi
    
    # Mot de passe MySQL root
    while true; do
        read -sp "Mot de passe root MySQL: " DB_ROOT_PASS
        echo ""
        if [ ! -z "$DB_ROOT_PASS" ]; then
            break
        fi
        echo "Le mot de passe ne peut pas être vide"
    done
    
    # Générer mot de passe utilisateur DB
    DB_USER_PASS=$(generate_password)
    
    # SSL/TLS
    read -p "Configurer SSL/TLS avec Let's Encrypt? (o/N): " -n 1 -r SETUP_SSL
    echo ""
    
    # Confirmation
    echo ""
    echo "Résumé de la configuration:"
    echo "  - Domaine: $DOMAIN_NAME"
    echo "  - Email: $ADMIN_EMAIL"
    echo "  - SSL/TLS: $([ "$SETUP_SSL" = "o" ] || [ "$SETUP_SSL" = "O" ] && echo "Oui" || echo "Non")"
    echo "  - Répertoire: $INSTALL_DIR"
    echo "  - Données: $DATA_DIR"
    echo ""
    read -p "Continuer l'installation? (o/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Oo]$ ]]; then
        log "Installation annulée par l'utilisateur"
        exit 0
    fi
}

#########################################################################
# Base de données
#########################################################################

create_database() {
    log "Création de la base de données..."
    
    mysql -u root -p"${DB_ROOT_PASS}" <<EOF >> "$LOG_FILE" 2>&1
CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_USER_PASS}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF
    
    if [ $? -eq 0 ]; then
        log "Base de données créée avec succès"
        
        # Sauvegarder les credentials
        cat > /root/.owncloud-db-credentials << EOF
DB_NAME=${DB_NAME}
DB_USER=${DB_USER}
DB_PASS=${DB_USER_PASS}
EOF
        chmod 600 /root/.owncloud-db-credentials
        log "Identifiants sauvegardés dans /root/.owncloud-db-credentials"
    else
        error "Échec de la création de la base de données"
    fi
}

optimize_mariadb() {
    log "Optimisation de MariaDB pour ownCloud..."
    
    MARIADB_CONF="/etc/mysql/mariadb.conf.d/99-owncloud.cnf"
    
    cat > "$MARIADB_CONF" << 'EOF'
[mysqld]
# ownCloud optimizations
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

# Transaction isolation
transaction-isolation = READ-COMMITTED
binlog_format = ROW

# Character set
character-set-server = utf8mb4
collation-server = utf8mb4_general_ci
EOF
    
    systemctl restart mariadb >> "$LOG_FILE" 2>&1
    log "MariaDB optimisé et redémarré"
}

#########################################################################
# Installation d'ownCloud
#########################################################################

download_owncloud() {
    log "Téléchargement d'ownCloud ${OWNCLOUD_VERSION}..."
    
    cd /tmp
    
    # Télécharger l'archive
    wget -q --show-progress "$OWNCLOUD_URL" -O owncloud.tar.bz2 || error "Échec du téléchargement"
    
    # Vérifier le téléchargement
    if [ ! -f owncloud.tar.bz2 ]; then
        error "Fichier téléchargé introuvable"
    fi
    
    log "Téléchargement terminé"
}

extract_owncloud() {
    log "Extraction d'ownCloud..."
    
    cd /tmp
    tar -xjf owncloud.tar.bz2 >> "$LOG_FILE" 2>&1
    
    # Déplacer vers le répertoire d'installation
    if [ -d "$INSTALL_DIR" ]; then
        warning "Le répertoire $INSTALL_DIR existe déjà. Création d'une sauvegarde..."
        mv "$INSTALL_DIR" "${INSTALL_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    mv owncloud "$INSTALL_DIR"
    
    log "ownCloud extrait dans $INSTALL_DIR"
}

create_data_directory() {
    log "Création du répertoire de données..."
    
    if [ ! -d "$DATA_DIR" ]; then
        mkdir -p "$DATA_DIR"
    fi
    
    # Permissions
    chown -R www-data:www-data "$DATA_DIR"
    chmod 0770 "$DATA_DIR"
    
    log "Répertoire de données créé: $DATA_DIR"
}

set_permissions() {
    log "Configuration des permissions..."
    
    chown -R www-data:www-data "$INSTALL_DIR"
    
    # Répertoires configurables
    find "$INSTALL_DIR" -type d -exec chmod 750 {} \;
    find "$INSTALL_DIR" -type f -exec chmod 640 {} \;
    
    log "Permissions configurées"
}

#########################################################################
# Configuration Apache
#########################################################################

configure_apache() {
    log "Configuration d'Apache pour ownCloud..."
    
    # Créer le VirtualHost
    cat > "$APACHE_CONF" << EOF
<VirtualHost *:80>
    ServerName ${DOMAIN_NAME}
    ServerAdmin ${ADMIN_EMAIL}
    
    DocumentRoot ${INSTALL_DIR}
    
    <Directory ${INSTALL_DIR}/>
        Options +FollowSymlinks
        AllowOverride All
        Require all granted
        
        <IfModule mod_dav.c>
            Dav off
        </IfModule>
        
        SetEnv HOME ${INSTALL_DIR}
        SetEnv HTTP_HOME ${INSTALL_DIR}
    </Directory>
    
    # Logs
    ErrorLog \${APACHE_LOG_DIR}/owncloud_error.log
    CustomLog \${APACHE_LOG_DIR}/owncloud_access.log combined
    
    # Security headers
    <IfModule mod_headers.c>
        Header always set Strict-Transport-Security "max-age=15552000; includeSubDomains"
        Header always set X-Content-Type-Options "nosniff"
        Header always set X-Frame-Options "SAMEORIGIN"
        Header always set X-XSS-Protection "1; mode=block"
        Header always set Referrer-Policy "no-referrer"
    </IfModule>
</VirtualHost>
EOF
    
    # Activer le site
    a2ensite owncloud.conf >> "$LOG_FILE" 2>&1
    
    # Désactiver le site par défaut
    a2dissite 000-default.conf >> "$LOG_FILE" 2>&1 || true
    
    # Recharger Apache
    systemctl reload apache2 >> "$LOG_FILE" 2>&1
    
    log "Apache configuré pour ownCloud"
}

setup_ssl() {
    if [[ "$SETUP_SSL" =~ ^[Oo]$ ]]; then
        log "Configuration de SSL/TLS avec Let's Encrypt..."
        
        certbot --apache -d "$DOMAIN_NAME" --non-interactive --agree-tos -m "$ADMIN_EMAIL" >> "$LOG_FILE" 2>&1
        
        if [ $? -eq 0 ]; then
            log "SSL/TLS configuré avec succès"
            
            # Renouvellement automatique
            (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet") | crontab -
            log "Renouvellement automatique configuré"
        else
            warning "Échec de la configuration SSL/TLS. Vous pouvez le configurer manuellement plus tard"
        fi
    fi
}

#########################################################################
# Finalisation
#########################################################################

create_installation_info() {
    log "Création du fichier d'informations..."
    
    INFO_FILE="/root/owncloud-installation-info.txt"
    
    cat > "$INFO_FILE" << EOF
========================================
ownCloud Installation Information
========================================

Date d'installation: $(date)
Version: ${OWNCLOUD_VERSION}

Configuration:
  - URL: http${SETUP_SSL:+s}://${DOMAIN_NAME}
  - Répertoire: ${INSTALL_DIR}
  - Données: ${DATA_DIR}
  - Email admin: ${ADMIN_EMAIL}

Base de données:
  - Nom: ${DB_NAME}
  - Utilisateur: ${DB_USER}
  - Mot de passe: ${DB_USER_PASS}
  
IMPORTANT:
  - Identifiants DB sauvegardés dans: /root/.owncloud-db-credentials
  - Complétez l'installation via l'interface web: http${SETUP_SSL:+s}://${DOMAIN_NAME}
  - Utilisez le répertoire de données: ${DATA_DIR}
  
Prochaines étapes:
  1. Accéder à l'interface web
  2. Créer le compte administrateur
  3. Configurer les applications
  4. Planifier les sauvegardes (voir /maintenance/backup.sh)

Logs:
  - Installation: ${LOG_FILE}
  - Apache: /var/log/apache2/owncloud_*.log
  - ownCloud: ${INSTALL_DIR}/data/owncloud.log

========================================
EOF
    
    chmod 600 "$INFO_FILE"
    log "Informations sauvegardées dans $INFO_FILE"
}

display_final_summary() {
    echo ""
    echo "=========================================="
    echo "  Installation terminée avec succès!"
    echo "=========================================="
    echo ""
    echo "ownCloud ${OWNCLOUD_VERSION} est maintenant installé"
    echo ""
    echo "Accès:"
    echo "  URL: ${GREEN}http${SETUP_SSL:+s}://${DOMAIN_NAME}${NC}"
    echo ""
    echo "Base de données:"
    echo "  Nom: ${DB_NAME}"
    echo "  Utilisateur: ${DB_USER}"
    echo ""
    echo "Prochaines étapes:"
    echo "  1. Accédez à l'URL ci-dessus"
    echo "  2. Créez le compte administrateur"
    echo "  3. Utilisez le répertoire de données: ${DATA_DIR}"
    echo "  4. Configurez les sauvegardes automatiques"
    echo ""
    echo "Documentation:"
    echo "  - Info complète: /root/owncloud-installation-info.txt"
    echo "  - Identifiants DB: /root/.owncloud-db-credentials"
    echo "  - Logs: ${LOG_FILE}"
    echo ""
    echo "Maintenance:"
    echo "  - Sauvegarde: cd /maintenance && sudo bash backup.sh"
    echo "  - Mise à jour: cd /maintenance && sudo bash update.sh"
    echo "  - Monitoring: cd /maintenance && sudo bash monitoring.sh"
    echo ""
    echo "=========================================="
    echo ""
}

#########################################################################
# Programme principal
#########################################################################

main() {
    echo ""
    echo "=========================================="
    echo "  Installation ownCloud ${OWNCLOUD_VERSION}"
    echo "=========================================="
    echo ""
    
    check_root
    
    # Configuration
    configure_installation
    
    log "Démarrage de l'installation..."
    
    # Base de données
    create_database
    optimize_mariadb
    
    # Installation ownCloud
    download_owncloud
    extract_owncloud
    create_data_directory
    set_permissions
    
    # Configuration serveur web
    configure_apache
    setup_ssl
    
    # Finalisation
    create_installation_info
    
    log "Installation terminée!"
    
    display_final_summary
}

# Exécuter le script principal
main "$@"
