#!/bin/bash
# Script de sauvegarde pour le système FiveM XDP Filter
# Sauvegarde les configurations, données de monitoring et logs

set -e

# Configuration
BACKUP_DIR="/opt/fivem-xdp-backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="fivem-xdp-backup-$TIMESTAMP"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"

# Couleurs pour les logs
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✅${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️${NC} $1"
}

# Créer le répertoire de sauvegarde
create_backup_dir() {
    log "Création du répertoire de sauvegarde..."
    mkdir -p "$BACKUP_PATH"
    log_success "Répertoire créé: $BACKUP_PATH"
}

# Sauvegarder les configurations des serveurs
backup_server_configs() {
    log "Sauvegarde des configurations des serveurs..."
    
    if [ -d "config/servers" ]; then
        cp -r config/servers "$BACKUP_PATH/"
        log_success "Configurations des serveurs sauvegardées"
    else
        log_warning "Aucune configuration de serveur trouvée"
    fi
}

# Sauvegarder les données Grafana
backup_grafana_data() {
    log "Sauvegarde des données Grafana..."
    
    if docker volume ls | grep -q "fivem-grafana-data"; then
        docker run --rm \
            -v fivem-grafana-data:/data \
            -v "$BACKUP_PATH":/backup \
            alpine tar czf /backup/grafana-data.tar.gz -C /data .
        log_success "Données Grafana sauvegardées"
    else
        log_warning "Volume Grafana non trouvé"
    fi
}

# Sauvegarder les données Prometheus
backup_prometheus_data() {
    log "Sauvegarde des données Prometheus..."
    
    if docker volume ls | grep -q "fivem-prometheus-data"; then
        docker run --rm \
            -v fivem-prometheus-data:/data \
            -v "$BACKUP_PATH":/backup \
            alpine tar czf /backup/prometheus-data.tar.gz -C /data .
        log_success "Données Prometheus sauvegardées"
    else
        log_warning "Volume Prometheus non trouvé"
    fi
}

# Sauvegarder les données AlertManager
backup_alertmanager_data() {
    log "Sauvegarde des données AlertManager..."
    
    if docker volume ls | grep -q "fivem-alertmanager-data"; then
        docker run --rm \
            -v fivem-alertmanager-data:/data \
            -v "$BACKUP_PATH":/backup \
            alpine tar czf /backup/alertmanager-data.tar.gz -C /data .
        log_success "Données AlertManager sauvegardées"
    else
        log_warning "Volume AlertManager non trouvé"
    fi
}

# Sauvegarder les logs des conteneurs
backup_container_logs() {
    log "Sauvegarde des logs des conteneurs..."
    
    mkdir -p "$BACKUP_PATH/logs"
    
    # Logs de la stack de monitoring
    for container in fivem-prometheus fivem-grafana fivem-alertmanager fivem-node-exporter fivem-cadvisor; do
        if docker ps -a --format '{{.Names}}' | grep -q "^$container$"; then
            docker logs "$container" > "$BACKUP_PATH/logs/$container.log" 2>&1
            log "Logs de $container sauvegardés"
        fi
    done
    
    # Logs des serveurs FiveM
    if [ -d "config/servers" ]; then
        for server_dir in config/servers/*/; do
            if [ -d "$server_dir" ]; then
                server_name=$(basename "$server_dir")
                
                for container in "fivem-xdp-$server_name" "fivem-metrics-$server_name"; do
                    if docker ps -a --format '{{.Names}}' | grep -q "^$container$"; then
                        docker logs "$container" > "$BACKUP_PATH/logs/$container.log" 2>&1
                        log "Logs de $container sauvegardés"
                    fi
                done
            fi
        done
    fi
    
    log_success "Logs des conteneurs sauvegardés"
}

# Sauvegarder les fichiers de configuration Docker
backup_docker_configs() {
    log "Sauvegarde des configurations Docker..."
    
    mkdir -p "$BACKUP_PATH/docker-configs"
    
    # Copier les fichiers de configuration
    cp docker-compose.yml "$BACKUP_PATH/docker-configs/" 2>/dev/null || true
    cp -r docker/ "$BACKUP_PATH/docker-configs/" 2>/dev/null || true
    
    log_success "Configurations Docker sauvegardées"
}

# Sauvegarder les scripts et documentation
backup_scripts() {
    log "Sauvegarde des scripts et documentation..."
    
    mkdir -p "$BACKUP_PATH/scripts"
    
    # Scripts principaux
    cp deploy.sh "$BACKUP_PATH/scripts/" 2>/dev/null || true
    cp test-deployment.sh "$BACKUP_PATH/scripts/" 2>/dev/null || true
    cp validate-fivem-hashes.sh "$BACKUP_PATH/scripts/" 2>/dev/null || true
    cp backup-system.sh "$BACKUP_PATH/scripts/" 2>/dev/null || true
    
    # Documentation
    cp *.md "$BACKUP_PATH/scripts/" 2>/dev/null || true
    
    # Code source
    cp fivem_xdp.c "$BACKUP_PATH/scripts/" 2>/dev/null || true
    cp fivem_xdp_config.c "$BACKUP_PATH/scripts/" 2>/dev/null || true
    cp Makefile "$BACKUP_PATH/scripts/" 2>/dev/null || true
    
    log_success "Scripts et documentation sauvegardés"
}

# Créer un manifeste de sauvegarde
create_manifest() {
    log "Création du manifeste de sauvegarde..."
    
    cat > "$BACKUP_PATH/MANIFEST.txt" <<EOF
FiveM XDP Filter - Sauvegarde
=============================

Date de création: $(date)
Version: 1.0.0
Nom de la sauvegarde: $BACKUP_NAME

Contenu de la sauvegarde:
========================

1. Configurations des serveurs (config/servers/)
2. Données Grafana (grafana-data.tar.gz)
3. Données Prometheus (prometheus-data.tar.gz)
4. Données AlertManager (alertmanager-data.tar.gz)
5. Logs des conteneurs (logs/)
6. Configurations Docker (docker-configs/)
7. Scripts et documentation (scripts/)

Instructions de restauration:
============================

1. Arrêter tous les services:
   docker compose down

2. Restaurer les volumes Docker:
   docker run --rm -v fivem-grafana-data:/data -v $(pwd):/backup alpine tar xzf /backup/grafana-data.tar.gz -C /data
   docker run --rm -v fivem-prometheus-data:/data -v $(pwd):/backup alpine tar xzf /backup/prometheus-data.tar.gz -C /data
   docker run --rm -v fivem-alertmanager-data:/data -v $(pwd):/backup alpine tar xzf /backup/alertmanager-data.tar.gz -C /data

3. Restaurer les configurations:
   cp -r servers/ ../config/
   cp -r docker-configs/* ../

4. Redémarrer les services:
   docker compose up -d

Informations système:
====================

Hostname: $(hostname)
Kernel: $(uname -r)
Docker version: $(docker --version)
Espace disque utilisé: $(du -sh "$BACKUP_PATH" | cut -f1)

EOF

    log_success "Manifeste créé"
}

# Compresser la sauvegarde
compress_backup() {
    log "Compression de la sauvegarde..."
    
    cd "$BACKUP_DIR"
    tar czf "$BACKUP_NAME.tar.gz" "$BACKUP_NAME"
    rm -rf "$BACKUP_NAME"
    
    local backup_size=$(du -sh "$BACKUP_NAME.tar.gz" | cut -f1)
    log_success "Sauvegarde compressée: $BACKUP_NAME.tar.gz ($backup_size)"
}

# Nettoyer les anciennes sauvegardes
cleanup_old_backups() {
    log "Nettoyage des anciennes sauvegardes..."
    
    # Garder seulement les 7 dernières sauvegardes
    cd "$BACKUP_DIR"
    ls -t fivem-xdp-backup-*.tar.gz 2>/dev/null | tail -n +8 | xargs rm -f 2>/dev/null || true
    
    local remaining=$(ls -1 fivem-xdp-backup-*.tar.gz 2>/dev/null | wc -l)
    log_success "Nettoyage terminé ($remaining sauvegardes conservées)"
}

# Afficher l'aide
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "OPTIONS:"
    echo "  --backup-dir DIR    Répertoire de sauvegarde (défaut: $BACKUP_DIR)"
    echo "  --no-compress       Ne pas compresser la sauvegarde"
    echo "  --no-cleanup        Ne pas nettoyer les anciennes sauvegardes"
    echo "  -h, --help          Afficher cette aide"
    echo ""
    echo "EXEMPLES:"
    echo "  $0                                    # Sauvegarde complète"
    echo "  $0 --backup-dir /tmp/backups         # Répertoire personnalisé"
    echo "  $0 --no-compress --no-cleanup        # Sans compression ni nettoyage"
}

# Variables par défaut
COMPRESS=true
CLEANUP=true

# Parser les arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --backup-dir)
            BACKUP_DIR="$2"
            BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"
            shift 2
            ;;
        --no-compress)
            COMPRESS=false
            shift
            ;;
        --no-cleanup)
            CLEANUP=false
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Option inconnue: $1"
            show_help
            exit 1
            ;;
    esac
done

# Fonction principale
main() {
    echo "💾 Sauvegarde du Système FiveM XDP Filter"
    echo "========================================"
    echo "Sauvegarde: $BACKUP_NAME"
    echo "Destination: $BACKUP_PATH"
    echo ""
    
    # Vérifier les privilèges
    if [ "$(id -u)" != "0" ]; then
        echo "⚠️ Ce script doit être exécuté avec des privilèges root pour accéder aux volumes Docker"
        exit 1
    fi
    
    # Créer la sauvegarde
    create_backup_dir
    backup_server_configs
    backup_grafana_data
    backup_prometheus_data
    backup_alertmanager_data
    backup_container_logs
    backup_docker_configs
    backup_scripts
    create_manifest
    
    if [ "$COMPRESS" = true ]; then
        compress_backup
    fi
    
    if [ "$CLEANUP" = true ]; then
        cleanup_old_backups
    fi
    
    echo ""
    log_success "Sauvegarde terminée avec succès!"
    
    if [ "$COMPRESS" = true ]; then
        echo "📁 Fichier de sauvegarde: $BACKUP_DIR/$BACKUP_NAME.tar.gz"
    else
        echo "📁 Répertoire de sauvegarde: $BACKUP_PATH"
    fi
}

# Exécuter la sauvegarde
main "$@"
