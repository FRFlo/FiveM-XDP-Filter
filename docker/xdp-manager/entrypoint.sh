#!/bin/bash
# Point d'entrée pour le gestionnaire de filtre XDP FiveM
# Gère le déploiement, la configuration et le cycle de vie du filtre

set -e

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction de logging
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✅${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ❌${NC} $1"
}

# Vérifier les privilèges root
check_privileges() {
    if [ "$(id -u)" != "0" ]; then
        log_error "Ce conteneur doit être exécuté avec des privilèges root"
        log_error "Utilisez: docker run --privileged ..."
        exit 1
    fi
}

# Vérifier la configuration requise
check_configuration() {
    if [ -z "$XDP_INTERFACE" ]; then
        log_error "XDP_INTERFACE non défini"
        log_error "Définissez la variable d'environnement XDP_INTERFACE"
        exit 1
    fi

    if [ -z "$SERVER_IP" ]; then
        log_error "SERVER_IP non défini"
        log_error "Définissez la variable d'environnement SERVER_IP"
        exit 1
    fi

    # Vérifier que l'interface réseau existe
    if ! ip link show "$XDP_INTERFACE" >/dev/null 2>&1; then
        log_error "Interface réseau '$XDP_INTERFACE' non trouvée"
        log_error "Interfaces disponibles:"
        ip link show | grep -E '^[0-9]+:' | cut -d: -f2 | sed 's/^ */  - /'
        exit 1
    fi
}

# Déployer le filtre XDP
deploy_filter() {
    log "Déploiement du filtre XDP FiveM..."
    
    # Installer le filtre XDP sur l'interface
    log "Installation du filtre sur l'interface $XDP_INTERFACE"
    if make install INTERFACE="$XDP_INTERFACE"; then
        log_success "Filtre XDP installé avec succès"
    else
        log_error "Échec de l'installation du filtre XDP"
        exit 1
    fi

    # Configurer le filtre selon la taille du serveur
    log "Configuration du filtre pour un serveur $SERVER_SIZE"
    if make "config-$SERVER_SIZE" SERVER_IP="$SERVER_IP"; then
        log_success "Configuration appliquée avec succès"
    else
        log_error "Échec de la configuration du filtre"
        exit 1
    fi
}

# Désinstaller le filtre XDP
remove_filter() {
    log "Désinstallation du filtre XDP..."
    if make uninstall INTERFACE="$XDP_INTERFACE"; then
        log_success "Filtre XDP désinstallé avec succès"
    else
        log_warning "Échec de la désinstallation (peut-être déjà désinstallé)"
    fi
}

# Afficher les statistiques
show_stats() {
    log "Statistiques du filtre XDP FiveM:"
    echo "=================================="
    make stats
}

# Surveiller le filtre (mode continu)
monitor_filter() {
    log "Démarrage de la surveillance du filtre XDP..."
    log "Interface: $XDP_INTERFACE, Serveur: $SERVER_IP ($SERVER_SIZE)"
    
    while true; do
        echo ""
        log "Statistiques à $(date)"
        make stats
        echo ""
        sleep 30
    done
}

# Gestion des signaux pour un arrêt propre
cleanup() {
    log "Réception du signal d'arrêt..."
    if [ "$AUTO_DEPLOY" = "true" ]; then
        remove_filter
    fi
    log_success "Nettoyage terminé"
    exit 0
}

trap cleanup SIGTERM SIGINT

# Fonction principale
main() {
    log "Démarrage du gestionnaire de filtre XDP FiveM"
    log "Version: $(date +%Y.%m.%d)"
    
    check_privileges
    check_configuration
    
    case "${1:-manage}" in
        "deploy")
            deploy_filter
            ;;
        "remove")
            remove_filter
            ;;
        "stats")
            show_stats
            ;;
        "monitor")
            monitor_filter
            ;;
        "manage")
            if [ "$AUTO_DEPLOY" = "true" ]; then
                deploy_filter
            fi
            monitor_filter
            ;;
        *)
            log_error "Commande inconnue: $1"
            log "Commandes disponibles: deploy, remove, stats, monitor, manage"
            exit 1
            ;;
    esac
}

# Exécuter la fonction principale avec tous les arguments
main "$@"
