#!/bin/bash
#########################################################################
# Script de mise à jour ownCloud
# Description: Mise à jour automatique et sécurisée d'ownCloud
# Auteur: Scripts ownCloud
# Version: 1.0.0
# Date: Mai 2024
#########################################################################

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Variables de configuration
OWNCLOUD_DIR="/var/www/owncloud"
DATA_DIR="/var/owncloud-data"
LOG_FILE="/var/log/owncloud-update.log"
BACKUP_BEFORE_UPDATE=true

# Version actuelle (sera détectée automatiquement)
CURRENT_VERSION=""
NEW_VERSION=""

#########################################################################
# Fonctions utilitaires
#########################################################################

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERREUR]${NC} $1" | tee -a "$LOG_FILE"
    cleanup_on_error
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

#########################################################################
# Détection de version
#########################################################################

detect_current_version() {
    log "Détection de la version actuelle..."
    
    if [ -f "${OWNCLOUD_DIR}/version.php" ]; then
        CURRENT_VERSION=$(sudo -u www-data php ${OWNCLOUD_DIR}/occ -V | grep -oP '\d+\.\d+\.\d+' || echo "unknown")
        log "Version actuelle: ${CURRENT_VERSION}"
    else
        error "Installation ownCloud non détectée dans ${OWNCLOUD_DIR}"
    fi
}

check_latest_version() {
    log "Vérification de la dernière version disponible..."
    
    # Obtenir la dernière version depuis le serveur ownCloud
    NEW_VERSION=$(curl -s https://download.owncloud.com/server/stable/ | grep -oP 'owncloud-\K[0-9]+\.[0-9]+\.[0-9]+(?=\.tar\.bz2)' | sort -V | tail -n1)
    
    if [ -z "$NEW_VERSION" ]; then
        error "Impossible de détecter la dernière version"
    fi
    
    log "Dernière version disponible: ${NEW_VERSION}"
}

compare_versions() {
    if [ "$CURRENT_VERSION" = "$NEW_VERSION" ]; then
        log "Vous utilisez déjà la dernière version (${CURRENT_VERSION})"
        read -p "Voulez-vous forcer la réinstallation? (o/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Oo]$ ]]; then
            log "Mise à jour annulée"
            exit 0
        fi
    elif [ "$CURRENT_VERSION" \> "$NEW_VERSION" ]; then
        warning "La version actuelle (${CURRENT_VERSION}) est plus récente que ${NEW_VERSION}"
        read -p "Voulez-vous continuer quand même? (o/N): " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Oo]$ ]]; then
            exit 0
        fi
    else
        log "Mise à jour disponible: ${CURRENT_VERSION} → ${NEW_VERSION}"
    fi
}

#########################################################################
# Sauvegarde avant mise à jour
#########################################################################

create_pre_update_backup() {
    if $BACKUP_BEFORE_UPDATE; then
        log "Création d'une sauvegarde avant mise à jour..."
        
        if [ -f "./backup.sh" ]; then
            bash ./backup.sh >> "$LOG_FILE" 2>&1
            log "Sauvegarde terminée"
        else
            warning "Script de sauvegarde non trouvé. Création d'une sauvegarde manuelle..."
            
            local backup_dir="/var/backups/owncloud-pre-update-$(date +%Y%m%d_%H%M%S)"
            mkdir -p "$backup_dir"
            
            # Sauvegarder la configuration
            cp -r "${OWNCLOUD_DIR}/config" "${backup_dir}/"
            
            # Sauvegarder la base de données
            if [ -f /root/.owncloud-db-credentials ]; then
                source /root/.owncloud-db-credentials
                mysqldump -u "${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" | gzip > "${backup_dir}/database.sql.gz"
            fi
            
            log "Sauvegarde créée dans ${backup_dir}"
        fi
    fi
}

#########################################################################
# Mode maintenance
#########################################################################

enable_maintenance_mode() {
    local mode=$1
    
    if [ "$mode" = "on" ]; then
        log "Activation du mode maintenance..."
        sudo -u www-data php ${OWNCLOUD_DIR}/occ maintenance:mode --on >> "$LOG_FILE" 2>&1
    else
        log "Désactivation du mode maintenance..."
        sudo -u www-data php ${OWNCLOUD_DIR}/occ maintenance:mode --off >> "$LOG_FILE" 2>&1
    fi
}

#########################################################################
# Mise à jour
#########################################################################

download_new_version() {
    log "Téléchargement d'ownCloud ${NEW_VERSION}..."
    
    cd /tmp
    
    local download_url="https://download.owncloud.com/server/stable/owncloud-${NEW_VERSION}.tar.bz2"
    
    wget -q --show-progress "$download_url" -O owncloud-new.tar.bz2 || error "Échec du téléchargement"
    
    # Vérifier le téléchargement
    if [ ! -f owncloud-new.tar.bz2 ]; then
        error "Fichier téléchargé introuvable"
    fi
    
    log "Téléchargement terminé"
}

extract_new_version() {
    log "Extraction de la nouvelle version..."
    
    cd /tmp
    
    # Supprimer l'ancien répertoire temporaire s'il existe
    if [ -d /tmp/owncloud ]; then
        rm -rf /tmp/owncloud
    fi
    
    tar -xjf owncloud-new.tar.bz2 >> "$LOG_FILE" 2>&1
    
    log "Extraction terminée"
}

backup_current_installation() {
    log "Sauvegarde de l'installation actuelle..."
    
    if [ -d "${OWNCLOUD_DIR}.backup" ]; then
        rm -rf "${OWNCLOUD_DIR}.backup"
    fi
    
    cp -r "$OWNCLOUD_DIR" "${OWNCLOUD_DIR}.backup"
    
    log "Installation actuelle sauvegardée dans ${OWNCLOUD_DIR}.backup"
}

copy_new_files() {
    log "Copie des nouveaux fichiers..."
    
    # Sauvegarder config et data
    mv "${OWNCLOUD_DIR}/config" "/tmp/owncloud-config-backup"
    
    # Supprimer l'ancienne installation (sauf data)
    rm -rf "${OWNCLOUD_DIR}"/*
    
    # Copier les nouveaux fichiers
    cp -r /tmp/owncloud/* "${OWNCLOUD_DIR}/"
    
    # Restaurer config
    rm -rf "${OWNCLOUD_DIR}/config"
    mv "/tmp/owncloud-config-backup" "${OWNCLOUD_DIR}/config"
    
    log "Nouveaux fichiers copiés"
}

set_permissions() {
    log "Configuration des permissions..."
    
    chown -R www-data:www-data "$OWNCLOUD_DIR"
    
    find "$OWNCLOUD_DIR" -type d -exec chmod 750 {} \;
    find "$OWNCLOUD_DIR" -type f -exec chmod 640 {} \;
    
    log "Permissions configurées"
}

run_upgrade_command() {
    log "Exécution de la mise à jour ownCloud..."
    
    sudo -u www-data php ${OWNCLOUD_DIR}/occ upgrade >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        log "Mise à jour ownCloud terminée"
    else
        error "Échec de la mise à jour ownCloud"
    fi
}

update_database() {
    log "Mise à jour de la base de données..."
    
    sudo -u www-data php ${OWNCLOUD_DIR}/occ db:add-missing-indices >> "$LOG_FILE" 2>&1
    sudo -u www-data php ${OWNCLOUD_DIR}/occ db:add-missing-columns >> "$LOG_FILE" 2>&1
    sudo -u www-data php ${OWNCLOUD_DIR}/occ db:add-missing-primary-keys >> "$LOG_FILE" 2>&1
    
    log "Base de données mise à jour"
}

#########################################################################
# Vérifications post-mise à jour
#########################################################################

verify_update() {
    log "Vérification de la mise à jour..."
    
    # Vérifier la version
    local installed_version=$(sudo -u www-data php ${OWNCLOUD_DIR}/occ -V | grep -oP '\d+\.\d+\.\d+')
    
    if [ "$installed_version" = "$NEW_VERSION" ]; then
        log "✓ Version installée: ${installed_version}"
    else
        error "La version installée (${installed_version}) ne correspond pas à ${NEW_VERSION}"
    fi
    
    # Vérifier l'intégrité
    sudo -u www-data php ${OWNCLOUD_DIR}/occ integrity:check-core >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        log "✓ Vérification d'intégrité: OK"
    else
        warning "Problèmes d'intégrité détectés (voir le log)"
    fi
}

cleanup_temp_files() {
    log "Nettoyage des fichiers temporaires..."
    
    rm -f /tmp/owncloud-new.tar.bz2
    rm -rf /tmp/owncloud
    
    log "Fichiers temporaires supprimés"
}

#########################################################################
# Gestion des erreurs
#########################################################################

cleanup_on_error() {
    warning "Nettoyage suite à une erreur..."
    
    # Désactiver le mode maintenance
    enable_maintenance_mode off
    
    # Restaurer l'ancienne version si disponible
    if [ -d "${OWNCLOUD_DIR}.backup" ]; then
        warning "Restauration de l'ancienne version..."
        rm -rf "$OWNCLOUD_DIR"
        mv "${OWNCLOUD_DIR}.backup" "$OWNCLOUD_DIR"
        warning "Ancienne version restaurée"
    fi
}

#########################################################################
# Programme principal
#########################################################################

display_summary() {
    echo ""
    echo "=========================================="
    echo "  Mise à jour terminée"
    echo "=========================================="
    echo ""
    echo "Version précédente: ${CURRENT_VERSION}"
    echo "Version actuelle: ${NEW_VERSION}"
    echo ""
    echo "Installation: ${OWNCLOUD_DIR}"
    echo "Sauvegarde: ${OWNCLOUD_DIR}.backup"
    echo ""
    echo "Prochaines étapes:"
    echo "  1. Vérifier que tout fonctionne correctement"
    echo "  2. Supprimer la sauvegarde: rm -rf ${OWNCLOUD_DIR}.backup"
    echo "  3. Tester les fonctionnalités critiques"
    echo ""
    echo "Log: ${LOG_FILE}"
    echo "=========================================="
    echo ""
}

main() {
    echo ""
    echo "=========================================="
    echo "  Mise à jour ownCloud"
    echo "=========================================="
    echo ""
    
    check_root
    
    # Détection des versions
    detect_current_version
    check_latest_version
    compare_versions
    
    # Confirmation
    echo ""
    read -p "Continuer la mise à jour ${CURRENT_VERSION} → ${NEW_VERSION}? (o/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Oo]$ ]]; then
        log "Mise à jour annulée"
        exit 0
    fi
    
    log "Démarrage de la mise à jour..."
    
    # Sauvegarde
    create_pre_update_backup
    
    # Mode maintenance
    enable_maintenance_mode on
    
    # Téléchargement et extraction
    download_new_version
    extract_new_version
    
    # Sauvegarde et copie
    backup_current_installation
    copy_new_files
    set_permissions
    
    # Mise à jour
    run_upgrade_command
    update_database
    
    # Vérifications
    verify_update
    
    # Mode maintenance
    enable_maintenance_mode off
    
    # Nettoyage
    cleanup_temp_files
    
    log "Mise à jour terminée avec succès!"
    
    display_summary
}

# Gestion des signaux
trap 'cleanup_on_error' INT TERM ERR

# Exécuter le script principal
main "$@"
