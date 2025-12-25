#!/bin/bash
#########################################################################
# Script de sauvegarde automatique ownCloud
# Description: Sauvegarde complète des fichiers et de la base de données
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
OWNCLOUD_DIR="/var/www/owncloud"
DATA_DIR="/var/owncloud-data"
BACKUP_DIR="/var/backups/owncloud"
LOG_FILE="/var/log/owncloud-backup.log"
MAX_BACKUPS=7  # Nombre de sauvegardes à conserver
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Charger les identifiants DB
if [ -f /root/.owncloud-db-credentials ]; then
    source /root/.owncloud-db-credentials
else
    DB_NAME="owncloud"
    DB_USER="owncloud"
fi

#########################################################################
# Fonctions utilitaires
#########################################################################

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERREUR]${NC} $1" | tee -a "$LOG_FILE"
    enable_maintenance_mode off
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

create_backup_dir() {
    if [ ! -d "$BACKUP_DIR" ]; then
        mkdir -p "$BACKUP_DIR"
        log "Répertoire de sauvegarde créé: $BACKUP_DIR"
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
# Sauvegarde
#########################################################################

backup_database() {
    log "Sauvegarde de la base de données..."
    
    local db_backup="${BACKUP_DIR}/database_${TIMESTAMP}.sql"
    
    # Demander le mot de passe si non défini
    if [ -z "$DB_PASS" ]; then
        read -sp "Mot de passe MySQL pour ${DB_USER}: " DB_PASS
        echo ""
    fi
    
    # Dump de la base de données
    mysqldump -u "${DB_USER}" -p"${DB_PASS}" "${DB_NAME}" > "${db_backup}" 2>> "$LOG_FILE"
    
    if [ $? -eq 0 ]; then
        # Compression
        gzip "${db_backup}"
        log "Base de données sauvegardée: ${db_backup}.gz"
        echo "${db_backup}.gz"
    else
        error "Échec de la sauvegarde de la base de données"
    fi
}

backup_config() {
    log "Sauvegarde des fichiers de configuration..."
    
    local config_backup="${BACKUP_DIR}/config_${TIMESTAMP}.tar.gz"
    
    tar -czf "${config_backup}" \
        -C "${OWNCLOUD_DIR}" config/ \
        >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        log "Configuration sauvegardée: ${config_backup}"
        echo "${config_backup}"
    else
        error "Échec de la sauvegarde de la configuration"
    fi
}

backup_data() {
    log "Sauvegarde du répertoire de données..."
    
    local data_backup="${BACKUP_DIR}/data_${TIMESTAMP}.tar.gz"
    
    # Exclure les fichiers temporaires et caches
    tar -czf "${data_backup}" \
        --exclude="${DATA_DIR}/*/cache" \
        --exclude="${DATA_DIR}/*/tmp" \
        --exclude="${DATA_DIR}/*.log" \
        -C "$(dirname ${DATA_DIR})" "$(basename ${DATA_DIR})" \
        >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        log "Données sauvegardées: ${data_backup}"
        echo "${data_backup}"
    else
        warning "Échec de la sauvegarde des données (non bloquant)"
        echo ""
    fi
}

backup_installation() {
    log "Sauvegarde de l'installation ownCloud..."
    
    local install_backup="${BACKUP_DIR}/installation_${TIMESTAMP}.tar.gz"
    
    tar -czf "${install_backup}" \
        --exclude="${OWNCLOUD_DIR}/data" \
        --exclude="${OWNCLOUD_DIR}/config" \
        -C "$(dirname ${OWNCLOUD_DIR})" "$(basename ${OWNCLOUD_DIR})" \
        >> "$LOG_FILE" 2>&1
    
    if [ $? -eq 0 ]; then
        log "Installation sauvegardée: ${install_backup}"
        echo "${install_backup}"
    else
        warning "Échec de la sauvegarde de l'installation"
        echo ""
    fi
}

#########################################################################
# Gestion des anciennes sauvegardes
#########################################################################

cleanup_old_backups() {
    log "Nettoyage des anciennes sauvegardes (conservation: ${MAX_BACKUPS})..."
    
    # Compter les sauvegardes
    local backup_count=$(ls -1 ${BACKUP_DIR}/database_*.sql.gz 2>/dev/null | wc -l)
    
    if [ $backup_count -gt $MAX_BACKUPS ]; then
        # Supprimer les plus anciennes
        local to_delete=$((backup_count - MAX_BACKUPS))
        
        log "Suppression de ${to_delete} anciennes sauvegardes..."
        
        ls -1t ${BACKUP_DIR}/database_*.sql.gz | tail -n ${to_delete} | xargs rm -f
        ls -1t ${BACKUP_DIR}/config_*.tar.gz | tail -n ${to_delete} | xargs rm -f 2>/dev/null || true
        ls -1t ${BACKUP_DIR}/data_*.tar.gz | tail -n ${to_delete} | xargs rm -f 2>/dev/null || true
        ls -1t ${BACKUP_DIR}/installation_*.tar.gz | tail -n ${to_delete} | xargs rm -f 2>/dev/null || true
        
        log "Anciennes sauvegardes supprimées"
    else
        log "Nombre de sauvegardes: ${backup_count} (< ${MAX_BACKUPS})"
    fi
}

#########################################################################
# Vérification et statistiques
#########################################################################

verify_backups() {
    log "Vérification des sauvegardes..."
    
    local all_good=true
    
    # Vérifier la base de données
    if [ -f "${BACKUP_DIR}/database_${TIMESTAMP}.sql.gz" ]; then
        if gzip -t "${BACKUP_DIR}/database_${TIMESTAMP}.sql.gz" 2>/dev/null; then
            log "✓ Sauvegarde base de données: OK"
        else
            warning "✗ Sauvegarde base de données: CORROMPUE"
            all_good=false
        fi
    fi
    
    # Vérifier la configuration
    if [ -f "${BACKUP_DIR}/config_${TIMESTAMP}.tar.gz" ]; then
        if tar -tzf "${BACKUP_DIR}/config_${TIMESTAMP}.tar.gz" > /dev/null 2>&1; then
            log "✓ Sauvegarde configuration: OK"
        else
            warning "✗ Sauvegarde configuration: CORROMPUE"
            all_good=false
        fi
    fi
    
    if $all_good; then
        log "Toutes les sauvegardes sont valides"
    else
        warning "Certaines sauvegardes sont corrompues"
    fi
}

calculate_backup_size() {
    log "Calcul de la taille des sauvegardes..."
    
    local total_size=$(du -sh "$BACKUP_DIR" | cut -f1)
    local latest_backup_size=0
    
    # Taille de la dernière sauvegarde
    for file in ${BACKUP_DIR}/*_${TIMESTAMP}.*; do
        if [ -f "$file" ]; then
            latest_backup_size=$((latest_backup_size + $(stat -c%s "$file")))
        fi
    done
    
    latest_backup_size=$(echo "scale=2; $latest_backup_size / 1024 / 1024" | bc)
    
    info "Taille totale des sauvegardes: ${total_size}"
    info "Taille de cette sauvegarde: ${latest_backup_size} MB"
}

#########################################################################
# Rapport de sauvegarde
#########################################################################

create_backup_report() {
    local report_file="${BACKUP_DIR}/backup_report_${TIMESTAMP}.txt"
    
    cat > "$report_file" << EOF
========================================
Rapport de Sauvegarde ownCloud
========================================

Date: $(date)
Timestamp: ${TIMESTAMP}

Fichiers sauvegardés:
$(ls -lh ${BACKUP_DIR}/*_${TIMESTAMP}.* 2>/dev/null || echo "Aucun fichier trouvé")

Statistiques:
  - Répertoire: ${BACKUP_DIR}
  - Sauvegardes conservées: ${MAX_BACKUPS}
  - Taille totale: $(du -sh ${BACKUP_DIR} | cut -f1)

Status: Terminé avec succès

========================================
EOF
    
    log "Rapport créé: ${report_file}"
}

#########################################################################
# Notification
#########################################################################

send_notification() {
    local status=$1
    local message=$2
    
    # Vous pouvez personnaliser cette fonction pour envoyer des emails
    # ou des notifications Telegram/Slack
    
    info "Notification: ${status} - ${message}"
}

#########################################################################
# Programme principal
#########################################################################

display_summary() {
    echo ""
    echo "=========================================="
    echo "  Sauvegarde terminée"
    echo "=========================================="
    echo ""
    echo "Emplacement: ${BACKUP_DIR}"
    echo "Timestamp: ${TIMESTAMP}"
    echo ""
    echo "Fichiers créés:"
    ls -lh ${BACKUP_DIR}/*_${TIMESTAMP}.* 2>/dev/null | awk '{print "  -", $9, "("$5")"}'
    echo ""
    echo "Sauvegardes totales: $(ls -1 ${BACKUP_DIR}/database_*.sql.gz 2>/dev/null | wc -l)"
    echo "Espace utilisé: $(du -sh ${BACKUP_DIR} | cut -f1)"
    echo ""
    echo "Log: ${LOG_FILE}"
    echo "=========================================="
    echo ""
}

main() {
    echo ""
    echo "=========================================="
    echo "  Sauvegarde ownCloud"
    echo "=========================================="
    echo ""
    
    check_root
    create_backup_dir
    
    log "Démarrage de la sauvegarde..."
    
    # Activer le mode maintenance
    enable_maintenance_mode on
    
    # Effectuer les sauvegardes
    backup_database
    backup_config
    backup_data
    backup_installation
    
    # Désactiver le mode maintenance
    enable_maintenance_mode off
    
    # Maintenance
    cleanup_old_backups
    verify_backups
    calculate_backup_size
    create_backup_report
    
    log "Sauvegarde terminée avec succès!"
    
    send_notification "SUCCESS" "Sauvegarde ownCloud terminée"
    
    display_summary
}

# Gestion des signaux
trap 'error "Script interrompu"' INT TERM

# Exécuter le script principal
main "$@"
