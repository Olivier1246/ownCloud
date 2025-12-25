#!/bin/bash
#########################################################################
# Script de monitoring ownCloud
# Description: Surveillance système et état d'ownCloud
# Auteur: Scripts ownCloud
# Version: 1.0.0
# Date: Décembre 2025
#########################################################################

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Variables de configuration
OWNCLOUD_DIR="/var/www/owncloud"
DATA_DIR="/var/owncloud-data"
LOG_FILE="/var/log/owncloud-monitoring.log"

# Seuils d'alerte
CPU_THRESHOLD=80
MEMORY_THRESHOLD=85
DISK_THRESHOLD=90
LOAD_THRESHOLD=4.0

#########################################################################
# Fonctions utilitaires
#########################################################################

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

print_header() {
    local title=$1
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN} $title${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
}

print_ok() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

#########################################################################
# Informations système
#########################################################################

check_system_info() {
    print_header "Informations Système"
    
    # Hostname
    echo -n "Serveur: "
    echo -e "${GREEN}$(hostname)${NC}"
    
    # OS
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo -n "OS: "
        echo -e "${GREEN}$PRETTY_NAME${NC}"
    fi
    
    # Kernel
    echo -n "Kernel: "
    echo -e "${GREEN}$(uname -r)${NC}"
    
    # Uptime
    echo -n "Uptime: "
    echo -e "${GREEN}$(uptime -p)${NC}"
    
    # Date
    echo -n "Date: "
    echo -e "${GREEN}$(date '+%Y-%m-%d %H:%M:%S')${NC}"
}

#########################################################################
# Monitoring ressources
#########################################################################

check_cpu() {
    print_header "CPU"
    
    # Utilisation CPU
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    echo -n "Utilisation: "
    
    if (( $(echo "$cpu_usage > $CPU_THRESHOLD" | bc -l) )); then
        echo -e "${RED}${cpu_usage}%${NC} (Seuil: ${CPU_THRESHOLD}%)"
        log "ALERTE: CPU à ${cpu_usage}%"
    elif (( $(echo "$cpu_usage > $((CPU_THRESHOLD - 20))" | bc -l) )); then
        echo -e "${YELLOW}${cpu_usage}%${NC} (Seuil: ${CPU_THRESHOLD}%)"
    else
        echo -e "${GREEN}${cpu_usage}%${NC} (Seuil: ${CPU_THRESHOLD}%)"
    fi
    
    # Load average
    local load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    echo -n "Load Average (1min): "
    
    if (( $(echo "$load > $LOAD_THRESHOLD" | bc -l) )); then
        echo -e "${RED}${load}${NC} (Seuil: ${LOAD_THRESHOLD})"
    else
        echo -e "${GREEN}${load}${NC} (Seuil: ${LOAD_THRESHOLD})"
    fi
    
    # Nombre de processeurs
    local cpus=$(nproc)
    print_info "Processeurs: ${cpus}"
    
    # Top 5 processus CPU
    echo ""
    print_info "Top 5 processus CPU:"
    ps aux --sort=-%cpu | head -n 6 | tail -n 5 | awk '{printf "  %-10s %5s%%  %s\n", $1, $3, $11}'
}

check_memory() {
    print_header "Mémoire"
    
    # Mémoire totale et utilisée
    local total_mem=$(free -m | awk 'NR==2{print $2}')
    local used_mem=$(free -m | awk 'NR==2{print $3}')
    local free_mem=$(free -m | awk 'NR==2{print $4}')
    local mem_percent=$(echo "scale=2; $used_mem * 100 / $total_mem" | bc)
    
    echo "Totale: ${total_mem} MB"
    echo "Utilisée: ${used_mem} MB"
    echo "Libre: ${free_mem} MB"
    
    echo -n "Utilisation: "
    if (( $(echo "$mem_percent > $MEMORY_THRESHOLD" | bc -l) )); then
        echo -e "${RED}${mem_percent}%${NC} (Seuil: ${MEMORY_THRESHOLD}%)"
        log "ALERTE: Mémoire à ${mem_percent}%"
    elif (( $(echo "$mem_percent > $((MEMORY_THRESHOLD - 15))" | bc -l) )); then
        echo -e "${YELLOW}${mem_percent}%${NC} (Seuil: ${MEMORY_THRESHOLD}%)"
    else
        echo -e "${GREEN}${mem_percent}%${NC} (Seuil: ${MEMORY_THRESHOLD}%)"
    fi
    
    # Swap
    local swap_total=$(free -m | awk 'NR==3{print $2}')
    local swap_used=$(free -m | awk 'NR==3{print $3}')
    
    if [ $swap_total -gt 0 ]; then
        local swap_percent=$(echo "scale=2; $swap_used * 100 / $swap_total" | bc)
        echo -n "Swap: ${swap_used}/${swap_total} MB ("
        
        if (( $(echo "$swap_percent > 50" | bc -l) )); then
            echo -e "${RED}${swap_percent}%${NC})"
        else
            echo -e "${GREEN}${swap_percent}%${NC})"
        fi
    fi
    
    # Top 5 processus mémoire
    echo ""
    print_info "Top 5 processus mémoire:"
    ps aux --sort=-%mem | head -n 6 | tail -n 5 | awk '{printf "  %-10s %5s%%  %s\n", $1, $4, $11}'
}

check_disk() {
    print_header "Espace Disque"
    
    # Partition principale
    local disk_usage=$(df -h / | awk 'NR==2{print $5}' | sed 's/%//')
    local disk_total=$(df -h / | awk 'NR==2{print $2}')
    local disk_used=$(df -h / | awk 'NR==2{print $3}')
    local disk_free=$(df -h / | awk 'NR==2{print $4}')
    
    echo "Partition racine (/):"
    echo "  Taille: ${disk_total}"
    echo "  Utilisé: ${disk_used}"
    echo "  Disponible: ${disk_free}"
    echo -n "  Utilisation: "
    
    if [ $disk_usage -gt $DISK_THRESHOLD ]; then
        echo -e "${RED}${disk_usage}%${NC} (Seuil: ${DISK_THRESHOLD}%)"
        log "ALERTE: Disque à ${disk_usage}%"
    elif [ $disk_usage -gt $((DISK_THRESHOLD - 10)) ]; then
        echo -e "${YELLOW}${disk_usage}%${NC} (Seuil: ${DISK_THRESHOLD}%)"
    else
        echo -e "${GREEN}${disk_usage}%${NC} (Seuil: ${DISK_THRESHOLD}%)"
    fi
    
    # Répertoire de données ownCloud
    if [ -d "$DATA_DIR" ]; then
        echo ""
        echo "Données ownCloud (${DATA_DIR}):"
        local data_size=$(du -sh "$DATA_DIR" 2>/dev/null | cut -f1)
        echo "  Taille: ${data_size}"
    fi
    
    # Toutes les partitions
    echo ""
    print_info "Toutes les partitions:"
    df -h | grep -E '^/dev/' | awk '{printf "  %-20s %6s / %-6s (%s)\n", $1, $3, $2, $5}'
}

check_inodes() {
    print_header "Inodes"
    
    local inode_usage=$(df -i / | awk 'NR==2{print $5}' | sed 's/%//')
    local inode_total=$(df -i / | awk 'NR==2{print $2}')
    local inode_used=$(df -i / | awk 'NR==2{print $3}')
    
    echo "Partition racine (/):"
    echo "  Total: ${inode_total}"
    echo "  Utilisés: ${inode_used}"
    echo -n "  Utilisation: "
    
    if [ $inode_usage -gt 90 ]; then
        echo -e "${RED}${inode_usage}%${NC}"
        log "ALERTE: Inodes à ${inode_usage}%"
    elif [ $inode_usage -gt 80 ]; then
        echo -e "${YELLOW}${inode_usage}%${NC}"
    else
        echo -e "${GREEN}${inode_usage}%${NC}"
    fi
}

#########################################################################
# Services
#########################################################################

check_services() {
    print_header "Services"
    
    # Apache
    echo -n "Apache2: "
    if systemctl is-active --quiet apache2; then
        print_ok "Actif"
    else
        print_error "Inactif"
        log "ALERTE: Apache2 n'est pas actif"
    fi
    
    # MariaDB
    echo -n "MariaDB: "
    if systemctl is-active --quiet mariadb; then
        print_ok "Actif"
    else
        print_error "Inactif"
        log "ALERTE: MariaDB n'est pas actif"
    fi
    
    # Cron
    echo -n "Cron: "
    if systemctl is-active --quiet cron; then
        print_ok "Actif"
    else
        print_warning "Inactif"
    fi
}

#########################################################################
# ownCloud spécifique
#########################################################################

check_owncloud() {
    print_header "ownCloud"
    
    if [ ! -d "$OWNCLOUD_DIR" ]; then
        print_error "Installation non trouvée"
        return
    fi
    
    # Version
    local version=$(sudo -u www-data php ${OWNCLOUD_DIR}/occ -V 2>/dev/null | grep -oP '\d+\.\d+\.\d+' || echo "Inconnu")
    echo "Version: ${version}"
    
    # Mode maintenance
    local maintenance=$(sudo -u www-data php ${OWNCLOUD_DIR}/occ config:system:get maintenance 2>/dev/null || echo "false")
    echo -n "Mode maintenance: "
    if [ "$maintenance" = "true" ]; then
        print_warning "Activé"
    else
        print_ok "Désactivé"
    fi
    
    # Nombre d'utilisateurs
    local users=$(sudo -u www-data php ${OWNCLOUD_DIR}/occ user:list 2>/dev/null | wc -l)
    print_info "Utilisateurs: ${users}"
    
    # Vérifier les mises à jour
    echo -n "Mises à jour: "
    local update_check=$(sudo -u www-data php ${OWNCLOUD_DIR}/occ update:check 2>/dev/null | grep -i "update available" || echo "")
    if [ -z "$update_check" ]; then
        print_ok "À jour"
    else
        print_warning "Disponible"
    fi
    
    # Tâches en arrière-plan
    echo -n "Background jobs: "
    local bg_mode=$(sudo -u www-data php ${OWNCLOUD_DIR}/occ config:app:get core backgroundjobs_mode 2>/dev/null || echo "ajax")
    case $bg_mode in
        "cron")
            print_ok "Cron (recommandé)"
            ;;
        "webcron")
            print_warning "Webcron"
            ;;
        "ajax")
            print_warning "AJAX (non recommandé)"
            ;;
    esac
}

check_owncloud_logs() {
    print_header "Logs ownCloud (dernières erreurs)"
    
    local oc_log="${OWNCLOUD_DIR}/data/owncloud.log"
    
    if [ -f "$oc_log" ]; then
        local errors=$(tail -n 50 "$oc_log" | grep -i "error" | wc -l)
        local warnings=$(tail -n 50 "$oc_log" | grep -i "warning" | wc -l)
        
        echo "Dernières 50 lignes:"
        echo "  Erreurs: ${errors}"
        echo "  Avertissements: ${warnings}"
        
        if [ $errors -gt 0 ]; then
            echo ""
            print_info "Dernières erreurs:"
            tail -n 50 "$oc_log" | grep -i "error" | tail -n 3 | sed 's/^/  /'
        fi
    else
        print_warning "Fichier de log non trouvé"
    fi
}

#########################################################################
# Base de données
#########################################################################

check_database() {
    print_header "Base de Données"
    
    if [ -f /root/.owncloud-db-credentials ]; then
        source /root/.owncloud-db-credentials
        
        # Taille de la base
        local db_size=$(mysql -u "${DB_USER}" -p"${DB_PASS}" -e "SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)' FROM information_schema.TABLES WHERE table_schema = '${DB_NAME}';" 2>/dev/null | tail -n 1)
        
        if [ ! -z "$db_size" ]; then
            echo "Base: ${DB_NAME}"
            echo "Taille: ${db_size} MB"
            
            # Nombre de tables
            local table_count=$(mysql -u "${DB_USER}" -p"${DB_PASS}" -e "SELECT COUNT(*) FROM information_schema.TABLES WHERE table_schema = '${DB_NAME}';" 2>/dev/null | tail -n 1)
            print_info "Tables: ${table_count}"
            
            # Connexions actives
            local connections=$(mysql -u "${DB_USER}" -p"${DB_PASS}" -e "SHOW PROCESSLIST;" 2>/dev/null | wc -l)
            print_info "Connexions actives: ${connections}"
        else
            print_warning "Impossible d'accéder à la base de données"
        fi
    else
        print_warning "Identifiants non trouvés"
    fi
}

#########################################################################
# Réseau
#########################################################################

check_network() {
    print_header "Réseau"
    
    # Interfaces
    print_info "Interfaces réseau:"
    ip -br addr | grep -v "lo" | awk '{printf "  %-10s %s\n", $1, $3}'
    
    # Connexions actives
    echo ""
    local connections=$(ss -tun | grep ESTAB | wc -l)
    print_info "Connexions établies: ${connections}"
    
    # Ports en écoute
    echo ""
    print_info "Ports en écoute:"
    ss -tlnp | grep LISTEN | awk '{printf "  Port %-6s %s\n", $4, $7}' | sort -u
}

#########################################################################
# Sécurité
#########################################################################

check_security() {
    print_header "Sécurité"
    
    # Firewall
    echo -n "Firewall (UFW): "
    if command -v ufw &> /dev/null; then
        if ufw status | grep -q "Status: active"; then
            print_ok "Actif"
        else
            print_warning "Inactif"
        fi
    else
        print_info "Non installé"
    fi
    
    # Fail2ban
    echo -n "Fail2ban: "
    if systemctl is-active --quiet fail2ban 2>/dev/null; then
        print_ok "Actif"
    else
        print_info "Non actif"
    fi
    
    # SSL/TLS
    echo -n "Certificat SSL: "
    if [ -d "/etc/letsencrypt/live" ]; then
        local cert_count=$(ls -1 /etc/letsencrypt/live | wc -l)
        if [ $cert_count -gt 0 ]; then
            print_ok "Configuré (${cert_count} domaine(s))"
        else
            print_warning "Non configuré"
        fi
    else
        print_warning "Let's Encrypt non configuré"
    fi
}

#########################################################################
# Sauvegardes
#########################################################################

check_backups() {
    print_header "Sauvegardes"
    
    local backup_dir="/var/backups/owncloud"
    
    if [ -d "$backup_dir" ]; then
        local backup_count=$(ls -1 ${backup_dir}/database_*.sql.gz 2>/dev/null | wc -l)
        
        if [ $backup_count -gt 0 ]; then
            print_ok "${backup_count} sauvegarde(s) disponible(s)"
            
            # Dernière sauvegarde
            local last_backup=$(ls -1t ${backup_dir}/database_*.sql.gz 2>/dev/null | head -n 1)
            if [ ! -z "$last_backup" ]; then
                local last_backup_date=$(stat -c %y "$last_backup" | cut -d' ' -f1,2)
                echo "Dernière sauvegarde: ${last_backup_date}"
                
                # Vérifier si < 24h
                local backup_age=$(( ($(date +%s) - $(stat -c %Y "$last_backup")) / 3600 ))
                if [ $backup_age -gt 24 ]; then
                    print_warning "Dernière sauvegarde il y a ${backup_age}h"
                fi
            fi
            
            # Taille totale
            local total_size=$(du -sh "$backup_dir" | cut -f1)
            print_info "Espace utilisé: ${total_size}"
        else
            print_warning "Aucune sauvegarde trouvée"
        fi
    else
        print_error "Répertoire de sauvegarde non trouvé"
    fi
}

#########################################################################
# Résumé des alertes
#########################################################################

show_alerts_summary() {
    print_header "Résumé des Alertes"
    
    local alerts=0
    
    # Vérifier les alertes récentes dans le log
    if [ -f "$LOG_FILE" ]; then
        local recent_alerts=$(grep "ALERTE" "$LOG_FILE" | tail -n 10 | wc -l)
        
        if [ $recent_alerts -gt 0 ]; then
            print_warning "${recent_alerts} alerte(s) dans le log"
            alerts=$((alerts + recent_alerts))
            
            echo ""
            print_info "Dernières alertes:"
            grep "ALERTE" "$LOG_FILE" | tail -n 5 | sed 's/^/  /'
        else
            print_ok "Aucune alerte récente"
        fi
    fi
    
    echo ""
    if [ $alerts -eq 0 ]; then
        print_ok "Système en bon état"
    else
        print_warning "Attention requise"
    fi
}

#########################################################################
# Programme principal
#########################################################################

main() {
    clear
    
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════╗"
    echo "║   Monitoring ownCloud - Dashboard      ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Vérifier si root (pour certaines commandes)
    if [ "$EUID" -ne 0 ]; then
        print_warning "Certaines informations nécessitent les droits root"
        echo ""
    fi
    
    # Monitoring
    check_system_info
    check_cpu
    check_memory
    check_disk
    check_inodes
    check_services
    check_owncloud
    check_owncloud_logs
    check_database
    check_network
    check_security
    check_backups
    show_alerts_summary
    
    # Footer
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN} Log: ${LOG_FILE}${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo ""
}

# Exécuter le script principal
main "$@"
