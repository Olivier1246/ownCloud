#!/bin/bash
#########################################################################
# Script d'installation des prérequis pour ownCloud 10.16.0
# Description: Installe Apache, MariaDB, PHP et toutes les dépendances
# Auteur: Scripts ownCloud
# Version: 1.0.0
# Date: Décembre 2025
#########################################################################

set -e  # Arrêter en cas d'erreur

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Variables
LOG_FILE="/var/log/owncloud-prerequisites.log"
PHP_VERSION="7.4"

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

check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "Ce script doit être exécuté en tant que root (sudo)"
    fi
}

check_os() {
    log "Vérification du système d'exploitation..."
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
        log "Système détecté: $OS $VERSION"
        
        if [[ "$OS" != "ubuntu" && "$OS" != "debian" ]]; then
            warning "Ce script est optimisé pour Ubuntu/Debian"
            read -p "Voulez-vous continuer quand même? (o/N) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Oo]$ ]]; then
                exit 1
            fi
        fi
    else
        error "Impossible de détecter le système d'exploitation"
    fi
}

#########################################################################
# Installation des paquets
#########################################################################

update_system() {
    log "Mise à jour du système..."
    apt-get update >> "$LOG_FILE" 2>&1
    apt-get upgrade -y >> "$LOG_FILE" 2>&1
    log "Système mis à jour avec succès"
}

install_apache() {
    log "Installation d'Apache2..."
    
    apt-get install -y apache2 apache2-utils >> "$LOG_FILE" 2>&1
    
    # Activer les modules nécessaires
    log "Activation des modules Apache..."
    a2enmod rewrite headers env dir mime ssl >> "$LOG_FILE" 2>&1
    
    systemctl enable apache2 >> "$LOG_FILE" 2>&1
    systemctl start apache2 >> "$LOG_FILE" 2>&1
    
    log "Apache2 installé et configuré"
}

install_mariadb() {
    log "Installation de MariaDB..."
    
    apt-get install -y mariadb-server mariadb-client >> "$LOG_FILE" 2>&1
    
    systemctl enable mariadb >> "$LOG_FILE" 2>&1
    systemctl start mariadb >> "$LOG_FILE" 2>&1
    
    log "MariaDB installé et démarré"
    warning "N'oubliez pas d'exécuter 'mysql_secure_installation' après l'installation"
}

install_php() {
    log "Suppression de toutes les versions PHP existantes..."
    
    # Arrêter Apache si en cours d'exécution
    systemctl stop apache2 >> "$LOG_FILE" 2>&1 || true
    
    # Purger toutes les versions de PHP
    apt-get purge -y 'php*' >> "$LOG_FILE" 2>&1 || true
    apt-get autoremove -y >> "$LOG_FILE" 2>&1
    apt-get autoclean >> "$LOG_FILE" 2>&1
    
    log "Toutes les versions PHP ont été supprimées"
    log "Installation de PHP ${PHP_VERSION}..."
    
    # Ajouter le repository PHP si nécessaire
    apt-get install -y software-properties-common >> "$LOG_FILE" 2>&1
    add-apt-repository -y ppa:ondrej/php >> "$LOG_FILE" 2>&1 || true
    apt-get update >> "$LOG_FILE" 2>&1
    
    # Installation de PHP et des extensions requises
    apt-get install -y \
        php${PHP_VERSION} \
        php${PHP_VERSION}-cli \
        php${PHP_VERSION}-common \
        php${PHP_VERSION}-mysql \
        php${PHP_VERSION}-zip \
        php${PHP_VERSION}-gd \
        php${PHP_VERSION}-mbstring \
        php${PHP_VERSION}-curl \
        php${PHP_VERSION}-xml \
        php${PHP_VERSION}-bcmath \
        php${PHP_VERSION}-intl \
        php${PHP_VERSION}-imagick \
        php${PHP_VERSION}-apcu \
        php${PHP_VERSION}-redis \
        php${PHP_VERSION}-ldap \
        php${PHP_VERSION}-imap \
        php${PHP_VERSION}-bz2 \
        php${PHP_VERSION}-gmp \
        libapache2-mod-php${PHP_VERSION} \
        >> "$LOG_FILE" 2>&1
    
    # Redémarrer Apache
    systemctl start apache2 >> "$LOG_FILE" 2>&1
    
    log "PHP ${PHP_VERSION} et extensions installés"
}

configure_php() {
    log "Configuration de PHP..."
    
    PHP_INI="/etc/php/${PHP_VERSION}/apache2/php.ini"
    
    if [ -f "$PHP_INI" ]; then
        # Backup du fichier original
        cp "$PHP_INI" "${PHP_INI}.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Modifications recommandées pour ownCloud
        sed -i 's/memory_limit = .*/memory_limit = 512M/' "$PHP_INI"
        sed -i 's/upload_max_filesize = .*/upload_max_filesize = 10G/' "$PHP_INI"
        sed -i 's/post_max_size = .*/post_max_size = 10G/' "$PHP_INI"
        sed -i 's/max_execution_time = .*/max_execution_time = 3600/' "$PHP_INI"
        sed -i 's/max_input_time = .*/max_input_time = 3600/' "$PHP_INI"
        sed -i 's/;date.timezone =.*/date.timezone = Europe\/Paris/' "$PHP_INI"
        sed -i 's/;opcache.enable=.*/opcache.enable=1/' "$PHP_INI"
        sed -i 's/;opcache.memory_consumption=.*/opcache.memory_consumption=128/' "$PHP_INI"
        sed -i 's/;opcache.interned_strings_buffer=.*/opcache.interned_strings_buffer=8/' "$PHP_INI"
        sed -i 's/;opcache.max_accelerated_files=.*/opcache.max_accelerated_files=10000/' "$PHP_INI"
        sed -i 's/;opcache.revalidate_freq=.*/opcache.revalidate_freq=1/' "$PHP_INI"
        sed -i 's/;opcache.save_comments=.*/opcache.save_comments=1/' "$PHP_INI"
        
        log "PHP configuré pour ownCloud"
    else
        warning "Fichier PHP.ini non trouvé à $PHP_INI"
    fi
}

install_utilities() {
    log "Installation des utilitaires..."
    
    apt-get install -y \
        wget \
        curl \
        unzip \
        bzip2 \
        rsync \
        cron \
        certbot \
        python3-certbot-apache \
        >> "$LOG_FILE" 2>&1
    
    log "Utilitaires installés"
}

#########################################################################
# Vérifications finales
#########################################################################

verify_installation() {
    log "Vérification de l'installation..."
    
    # Vérifier Apache
    if systemctl is-active --quiet apache2; then
        log "✓ Apache2 est actif"
    else
        error "Apache2 n'est pas actif"
    fi
    
    # Vérifier MariaDB
    if systemctl is-active --quiet mariadb; then
        log "✓ MariaDB est actif"
    else
        error "MariaDB n'est pas actif"
    fi
    
    # Vérifier PHP
    PHP_INSTALLED=$(php -v | head -n 1)
    if [ $? -eq 0 ]; then
        log "✓ PHP installé: $PHP_INSTALLED"
    else
        error "PHP n'est pas correctement installé"
    fi
    
    # Vérifier les modules Apache
    log "Vérification des modules Apache..."
    a2query -m rewrite > /dev/null 2>&1 && log "✓ Module rewrite activé" || warning "Module rewrite non activé"
    a2query -m headers > /dev/null 2>&1 && log "✓ Module headers activé" || warning "Module headers non activé"
    a2query -m ssl > /dev/null 2>&1 && log "✓ Module ssl activé" || warning "Module ssl non activé"
}

display_summary() {
    echo ""
    echo "=========================================="
    echo "  Installation des prérequis terminée"
    echo "=========================================="
    echo ""
    echo "Versions installées:"
    echo "  - Apache: $(apache2 -v | head -n 1 | cut -d' ' -f3)"
    echo "  - MariaDB: $(mysql --version | awk '{print $5}' | sed 's/,//')"
    echo "  - PHP: $(php -v | head -n 1 | cut -d' ' -f2)"
    echo ""
    echo "Prochaines étapes:"
    echo "  1. Exécuter: sudo mysql_secure_installation"
    echo "  2. Lancer: sudo bash 02-install-owncloud.sh"
    echo ""
    echo "Log complet: $LOG_FILE"
    echo "=========================================="
    echo ""
}

#########################################################################
# Programme principal
#########################################################################

main() {
    echo ""
    echo "=========================================="
    echo "  ownCloud 10.16.0 - Prérequis"
    echo "=========================================="
    echo ""
    
    check_root
    check_os
    
    log "Démarrage de l'installation des prérequis..."
    
    update_system
    install_apache
    install_mariadb
    install_php
    configure_php
    install_utilities
    
    verify_installation
    
    # Redémarrer Apache pour appliquer les changements
    log "Redémarrage d'Apache..."
    systemctl restart apache2
    
    log "Installation des prérequis terminée avec succès!"
    
    display_summary
}

# Exécuter le script principal
main "$@"
