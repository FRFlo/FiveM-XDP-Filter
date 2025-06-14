#!/bin/bash
# Script de déploiement automatisé pour les filtres XDP FiveM
# Déploie et configure automatiquement les filtres XDP avec surveillance

set -e

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration par défaut
DEFAULT_INTERFACE="eth0"
DEFAULT_SERVER_SIZE="medium"
DEFAULT_MONITORING_PORT="3000"
DEFAULT_PROMETHEUS_PORT="9090"

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

log_info() {
    echo -e "${PURPLE}[$(date +'%Y-%m-%d %H:%M:%S')] ℹ️${NC} $1"
}

# Afficher le banner
show_banner() {
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    FiveM XDP Filter                          ║"
    echo "║              Déploiement Automatisé v1.0                    ║"
    echo "║                                                              ║"
    echo "║  🛡️  Protection DDoS avancée pour serveurs FiveM            ║"
    echo "║  📊  Surveillance en temps réel avec Grafana                ║"
    echo "║  🐳  Déploiement containerisé                               ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Afficher l'aide
show_help() {
    echo "Usage: $0 [OPTIONS] COMMAND"
    echo ""
    echo "COMMANDES:"
    echo "  deploy          Déployer un nouveau serveur avec filtre XDP"
    echo "  monitoring      Déployer uniquement la stack de surveillance"
    echo "  remove          Supprimer un serveur et son filtre"
    echo "  list            Lister les serveurs déployés"
    echo "  status          Afficher l'état des services"
    echo "  logs            Afficher les logs des services"
    echo "  update          Mettre à jour les filtres existants"
    echo ""
    echo "OPTIONS:"
    echo "  -s, --server-ip IP        Adresse IP du serveur FiveM (requis pour deploy)"
    echo "  -i, --interface IFACE     Interface réseau (défaut: $DEFAULT_INTERFACE)"
    echo "  -z, --size SIZE           Taille du serveur: small|medium|large (défaut: $DEFAULT_SERVER_SIZE)"
    echo "  -n, --name NAME           Nom du serveur (défaut: auto-généré)"
    echo "  -p, --port PORT           Port du serveur FiveM (défaut: 30120)"
    echo "  -m, --monitoring-port     Port Grafana (défaut: $DEFAULT_MONITORING_PORT)"
    echo "  --prometheus-port         Port Prometheus (défaut: $DEFAULT_PROMETHEUS_PORT)"
    echo "  --no-monitoring           Ne pas déployer la surveillance"
    echo "  --force                   Forcer le déploiement (écraser existant)"
    echo "  -h, --help                Afficher cette aide"
    echo ""
    echo "EXEMPLES:"
    echo "  $0 deploy -s 192.168.1.100 -n main-server"
    echo "  $0 deploy -s 10.0.0.50 -z large -i ens3"
    echo "  $0 monitoring"
    echo "  $0 status"
    echo "  $0 remove -n main-server"
}

# Vérifier les prérequis
check_prerequisites() {
    log "Vérification des prérequis..."
    
    # Vérifier les privilèges root
    if [ "$(id -u)" != "0" ]; then
        log_error "Ce script doit être exécuté avec des privilèges root"
        log_error "Utilisez: sudo $0"
        exit 1
    fi
    
    # Vérifier Docker
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker n'est pas installé"
        log_error "Installez Docker: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    # Vérifier Docker Compose
    if ! docker compose version >/dev/null 2>&1; then
        log_error "Docker Compose n'est pas installé ou n'est pas la version moderne"
        log_error "Installez Docker Compose v2: https://docs.docker.com/compose/install/"
        log_error "Ou utilisez: apt-get install docker-compose-plugin"
        exit 1
    fi
    
    # Vérifier les outils BPF pour Debian 12
    if ! command -v bpftool >/dev/null 2>&1; then
        log_warning "bpftool n'est pas installé, installation pour Debian 12..."
        apt-get update && apt-get install -y linux-tools-common bpftool
    fi
    
    # Vérifier le support XDP du kernel
    if [ ! -d "/sys/fs/bpf" ]; then
        log_error "Le système de fichiers BPF n'est pas monté"
        log_error "Montez-le avec: mount -t bpf bpf /sys/fs/bpf"
        exit 1
    fi
    
    log_success "Prérequis vérifiés"
}

# Valider une adresse IP
validate_ip() {
    local ip="$1"
    if [[ ! $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 1
    fi

    IFS='.' read -ra ADDR <<< "$ip"
    for i in "${ADDR[@]}"; do
        if [[ $i -gt 255 ]]; then
            return 1
        fi
    done
    return 0
}

# Valider un nom de serveur
validate_server_name() {
    local name="$1"
    if [[ ! $name =~ ^[a-zA-Z0-9_-]+$ ]]; then
        return 1
    fi
    if [[ ${#name} -lt 3 || ${#name} -gt 50 ]]; then
        return 1
    fi
    return 0
}

# Valider une taille de serveur
validate_server_size() {
    local size="$1"
    case "$size" in
        small|medium|large|dev)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Valider un port
validate_port() {
    local port="$1"
    if [[ ! $port =~ ^[0-9]+$ ]] || [[ $port -lt 1 || $port -gt 65535 ]]; then
        return 1
    fi
    return 0
}

# Créer la configuration pour un serveur
create_server_config() {
    local server_name="$1"
    local server_ip="$2"
    local server_port="$3"
    local server_size="$4"
    local interface="$5"

    # Validation des paramètres
    if ! validate_server_name "$server_name"; then
        log_error "Nom de serveur invalide: $server_name"
        log_error "Le nom doit contenir uniquement des lettres, chiffres, _ et - (3-50 caractères)"
        exit 1
    fi

    if ! validate_ip "$server_ip"; then
        log_error "Adresse IP invalide: $server_ip"
        exit 1
    fi

    if ! validate_port "$server_port"; then
        log_error "Port invalide: $server_port"
        exit 1
    fi

    if ! validate_server_size "$server_size"; then
        log_error "Taille de serveur invalide: $server_size"
        log_error "Tailles supportées: small, medium, large, dev"
        exit 1
    fi

    local config_dir="config/servers/$server_name"
    mkdir -p "$config_dir" || {
        log_error "Impossible de créer le répertoire de configuration: $config_dir"
        exit 1
    }
    
    cat > "$config_dir/server.env" <<EOF
# Configuration pour le serveur $server_name
SERVER_NAME=$server_name
SERVER_IP=$server_ip
SERVER_PORT=$server_port
SERVER_SIZE=$server_size
XDP_INTERFACE=$interface
AUTO_DEPLOY=true
METRICS_ENABLED=true
EXPORTER_PORT=9100
CREATED_AT=$(date -Iseconds)
EOF
    
    log_success "Configuration créée pour $server_name"
}

# Fonction de nettoyage en cas d'échec
cleanup_failed_deployment() {
    local server_name="$1"
    log_warning "Nettoyage du déploiement échoué pour $server_name..."

    # Arrêter et supprimer les conteneurs
    docker stop "fivem-xdp-$server_name" 2>/dev/null || true
    docker rm "fivem-xdp-$server_name" 2>/dev/null || true
    docker stop "fivem-metrics-$server_name" 2>/dev/null || true
    docker rm "fivem-metrics-$server_name" 2>/dev/null || true

    # Supprimer la configuration si elle a été créée
    rm -rf "config/servers/$server_name" 2>/dev/null || true

    log_warning "Nettoyage terminé"
}

# Attendre qu'un conteneur soit prêt avec timeout
wait_for_container() {
    local container_name="$1"
    local timeout="${2:-30}"
    local counter=0

    log "Attente du démarrage de $container_name (timeout: ${timeout}s)..."

    while [ $counter -lt $timeout ]; do
        if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
            if docker exec "$container_name" echo "test" >/dev/null 2>&1; then
                log_success "$container_name est prêt"
                return 0
            fi
        fi
        sleep 1
        counter=$((counter + 1))
    done

    log_error "Timeout: $container_name n'est pas prêt après ${timeout}s"
    return 1
}

# Déployer un serveur
deploy_server() {
    local server_name="$1"
    local server_ip="$2"
    local server_port="$3"
    local server_size="$4"
    local interface="$5"
    local force="$6"

    log "Déploiement du serveur $server_name..."

    # Configurer le nettoyage automatique en cas d'échec
    trap "cleanup_failed_deployment '$server_name'" ERR

    # Vérifier si le serveur existe déjà
    if [ -f "config/servers/$server_name/server.env" ] && [ "$force" != "true" ]; then
        log_error "Le serveur $server_name existe déjà"
        log_error "Utilisez --force pour écraser ou choisissez un autre nom"
        exit 1
    fi
    
    # Créer la configuration
    create_server_config "$server_name" "$server_ip" "$server_port" "$server_size" "$interface"
    
    # Construire l'image du gestionnaire XDP
    log "Construction de l'image du gestionnaire XDP..."
    if ! timeout 300 docker build -t fivem-xdp-manager:latest docker/xdp-manager/; then
        log_error "Échec de la construction de l'image XDP manager"
        exit 1
    fi

    # Construire l'image de l'exportateur de métriques
    log "Construction de l'image de l'exportateur de métriques..."
    if ! timeout 300 docker build -t fivem-metrics-exporter:latest docker/metrics-exporter/; then
        log_error "Échec de la construction de l'image metrics exporter"
        exit 1
    fi

    # Nettoyer les conteneurs existants si force est activé
    if [ "$force" = "true" ]; then
        log "Nettoyage des conteneurs existants..."
        docker stop "fivem-xdp-$server_name" 2>/dev/null || true
        docker rm "fivem-xdp-$server_name" 2>/dev/null || true
        docker stop "fivem-metrics-$server_name" 2>/dev/null || true
        docker rm "fivem-metrics-$server_name" 2>/dev/null || true
    fi

    # Déployer le gestionnaire XDP
    log "Déploiement du gestionnaire XDP pour $server_name..."
    if ! docker run -d \
        --name "fivem-xdp-$server_name" \
        --privileged \
        --network host \
        --pid host \
        --env-file "config/servers/$server_name/server.env" \
        -v /sys/fs/bpf:/sys/fs/bpf:shared \
        -v /proc:/host/proc:ro \
        -v /sys:/host/sys:ro \
        --restart unless-stopped \
        fivem-xdp-manager:latest; then
        log_error "Échec du déploiement du gestionnaire XDP"
        exit 1
    fi

    # Attendre que le gestionnaire XDP soit prêt
    if ! wait_for_container "fivem-xdp-$server_name" 30; then
        log_error "Le gestionnaire XDP n'a pas démarré correctement"
        exit 1
    fi

    # Déployer l'exportateur de métriques
    log "Déploiement de l'exportateur de métriques pour $server_name..."
    if ! docker run -d \
        --name "fivem-metrics-$server_name" \
        --network host \
        --pid host \
        --env-file "config/servers/$server_name/server.env" \
        -v /sys/fs/bpf:/sys/fs/bpf:ro \
        --restart unless-stopped \
        fivem-metrics-exporter:latest; then
        log_error "Échec du déploiement de l'exportateur de métriques"
        exit 1
    fi

    # Attendre que l'exportateur soit prêt
    if ! wait_for_container "fivem-metrics-$server_name" 30; then
        log_error "L'exportateur de métriques n'a pas démarré correctement"
        exit 1
    fi

    # Vérifier que les services fonctionnent
    log "Vérification du fonctionnement des services..."
    sleep 5

    # Test de santé des conteneurs
    if ! docker exec "fivem-xdp-$server_name" echo "health check" >/dev/null 2>&1; then
        log_error "Le gestionnaire XDP ne répond pas"
        exit 1
    fi

    if ! docker exec "fivem-metrics-$server_name" echo "health check" >/dev/null 2>&1; then
        log_error "L'exportateur de métriques ne répond pas"
        exit 1
    fi

    # Test de l'endpoint des métriques
    if ! timeout 10 curl -s http://localhost:9100/metrics >/dev/null; then
        log_warning "L'endpoint des métriques n'est pas encore disponible (normal au démarrage)"
    fi

    # Désactiver le trap de nettoyage (déploiement réussi)
    trap - ERR

    log_success "Serveur $server_name déployé avec succès"
    log_info "Filtre XDP: Interface $interface, IP $server_ip:$server_port"
    log_info "Métriques disponibles sur: http://localhost:9100/metrics"
}

# Déployer la stack de surveillance
deploy_monitoring() {
    log "Déploiement de la stack de surveillance..."
    
    cd docker/monitoring
    
    # Créer le fichier d'environnement pour Grafana
    cat > .env <<EOF
GRAFANA_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD:-admin123}
EOF
    
    # Déployer avec Docker Compose
    docker compose up -d
    
    cd ../..
    
    # Attendre que les services démarrent
    sleep 10
    
    # Vérifier le déploiement
    if curl -s http://localhost:3000 >/dev/null && curl -s http://localhost:9090 >/dev/null; then
        log_success "Stack de surveillance déployée avec succès"
        log_info "Grafana: http://localhost:3000 (admin/admin123)"
        log_info "Prometheus: http://localhost:9090"
        log_info "AlertManager: http://localhost:9093"
    else
        log_error "Échec du déploiement de la surveillance"
        exit 1
    fi
}

# Supprimer un serveur
remove_server() {
    local server_name="$1"

    if [ -z "$server_name" ]; then
        log_error "Nom de serveur requis pour la suppression"
        log_error "Utilisez: $0 remove -n <nom-serveur>"
        exit 1
    fi

    log "Suppression du serveur $server_name..."

    # Vérifier que le serveur existe
    if [ ! -f "config/servers/$server_name/server.env" ]; then
        log_error "Le serveur $server_name n'existe pas"
        exit 1
    fi

    # Arrêter et supprimer les conteneurs
    log "Arrêt des conteneurs..."
    docker stop "fivem-xdp-$server_name" 2>/dev/null || log_warning "Conteneur XDP déjà arrêté"
    docker stop "fivem-metrics-$server_name" 2>/dev/null || log_warning "Conteneur metrics déjà arrêté"

    log "Suppression des conteneurs..."
    docker rm "fivem-xdp-$server_name" 2>/dev/null || log_warning "Conteneur XDP déjà supprimé"
    docker rm "fivem-metrics-$server_name" 2>/dev/null || log_warning "Conteneur metrics déjà supprimé"

    # Supprimer la configuration
    log "Suppression de la configuration..."
    rm -rf "config/servers/$server_name"

    log_success "Serveur $server_name supprimé avec succès"
}

# Lister les serveurs déployés
list_servers() {
    log "Serveurs FiveM XDP déployés:"
    echo "============================"

    if [ ! -d "config/servers" ] || [ -z "$(ls -A config/servers 2>/dev/null)" ]; then
        echo "Aucun serveur déployé"
        return 0
    fi

    for server_dir in config/servers/*/; do
        if [ -d "$server_dir" ]; then
            server_name=$(basename "$server_dir")
            if [ -f "$server_dir/server.env" ]; then
                echo ""
                echo "📊 Serveur: $server_name"

                # Lire la configuration
                source "$server_dir/server.env"
                echo "   IP: $SERVER_IP"
                echo "   Port: $SERVER_PORT"
                echo "   Taille: $SERVER_SIZE"
                echo "   Interface: $XDP_INTERFACE"
                echo "   Créé: $CREATED_AT"

                # Vérifier l'état des conteneurs
                if docker ps | grep -q "fivem-xdp-$server_name"; then
                    echo "   État XDP: ✅ Actif"
                else
                    echo "   État XDP: ❌ Inactif"
                fi

                if docker ps | grep -q "fivem-metrics-$server_name"; then
                    echo "   État Metrics: ✅ Actif"
                else
                    echo "   État Metrics: ❌ Inactif"
                fi
            fi
        fi
    done
}

# Afficher l'état des services
show_status() {
    log "État des services FiveM XDP Filter:"
    echo "===================================="

    # État de la stack de monitoring
    echo ""
    echo "📊 Stack de Monitoring:"

    services=("fivem-prometheus" "fivem-grafana" "fivem-alertmanager" "fivem-node-exporter" "fivem-cadvisor")
    for service in "${services[@]}"; do
        if docker ps | grep -q "$service"; then
            echo "   $service: ✅ Actif"
        else
            echo "   $service: ❌ Inactif"
        fi
    done

    # État des serveurs FiveM
    echo ""
    echo "🛡️ Serveurs FiveM:"

    if [ ! -d "config/servers" ] || [ -z "$(ls -A config/servers 2>/dev/null)" ]; then
        echo "   Aucun serveur déployé"
    else
        for server_dir in config/servers/*/; do
            if [ -d "$server_dir" ]; then
                server_name=$(basename "$server_dir")
                if docker ps | grep -q "fivem-xdp-$server_name"; then
                    echo "   $server_name: ✅ Actif"
                else
                    echo "   $server_name: ❌ Inactif"
                fi
            fi
        done
    fi

    # URLs d'accès
    echo ""
    echo "🌐 URLs d'accès:"
    echo "   Grafana: http://localhost:3000"
    echo "   Prometheus: http://localhost:9090"
    echo "   AlertManager: http://localhost:9093"
    echo "   Métriques: http://localhost:9100/metrics"
}

# Variables par défaut
SERVER_IP=""
INTERFACE="$DEFAULT_INTERFACE"
SERVER_SIZE="$DEFAULT_SERVER_SIZE"
SERVER_NAME=""
SERVER_PORT="30120"
MONITORING_PORT="$DEFAULT_MONITORING_PORT"
PROMETHEUS_PORT="$DEFAULT_PROMETHEUS_PORT"
NO_MONITORING="false"
FORCE="false"
COMMAND=""

# Parser les arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--server-ip)
            SERVER_IP="$2"
            shift 2
            ;;
        -i|--interface)
            INTERFACE="$2"
            shift 2
            ;;
        -z|--size)
            SERVER_SIZE="$2"
            shift 2
            ;;
        -n|--name)
            SERVER_NAME="$2"
            shift 2
            ;;
        -p|--port)
            SERVER_PORT="$2"
            shift 2
            ;;
        -m|--monitoring-port)
            MONITORING_PORT="$2"
            shift 2
            ;;
        --prometheus-port)
            PROMETHEUS_PORT="$2"
            shift 2
            ;;
        --no-monitoring)
            NO_MONITORING="true"
            shift
            ;;
        --force)
            FORCE="true"
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        deploy|monitoring|remove|list|status|logs|update)
            COMMAND="$1"
            shift
            ;;
        *)
            log_error "Option inconnue: $1"
            show_help
            exit 1
            ;;
    esac
done

# Fonction principale
main() {
    show_banner
    
    if [ -z "$COMMAND" ]; then
        log_error "Aucune commande spécifiée"
        show_help
        exit 1
    fi
    
    check_prerequisites
    
    case "$COMMAND" in
        "deploy")
            if [ -z "$SERVER_IP" ]; then
                log_error "L'adresse IP du serveur est requise pour le déploiement"
                log_error "Utilisez: $0 deploy -s <IP_SERVEUR>"
                exit 1
            fi
            
            # Générer un nom de serveur si non spécifié
            if [ -z "$SERVER_NAME" ]; then
                SERVER_NAME="server-$(echo $SERVER_IP | tr '.' '-')"
            fi
            
            deploy_server "$SERVER_NAME" "$SERVER_IP" "$SERVER_PORT" "$SERVER_SIZE" "$INTERFACE" "$FORCE"
            
            if [ "$NO_MONITORING" != "true" ]; then
                deploy_monitoring
            fi
            ;;
        "monitoring")
            deploy_monitoring
            ;;
        "remove")
            remove_server "$SERVER_NAME"
            ;;
        "list")
            list_servers
            ;;
        "status")
            show_status
            ;;
        "logs")
            if [ -z "$SERVER_NAME" ]; then
                log_error "Nom de serveur requis pour afficher les logs"
                log_error "Utilisez: $0 logs -n <nom-serveur>"
                exit 1
            fi
            echo "=== Logs XDP Manager ==="
            docker logs "fivem-xdp-$SERVER_NAME" 2>&1 | tail -50
            echo ""
            echo "=== Logs Metrics Exporter ==="
            docker logs "fivem-metrics-$SERVER_NAME" 2>&1 | tail -50
            ;;
        "update")
            log "Mise à jour des images Docker..."
            docker pull prom/prometheus:v2.47.0
            docker pull grafana/grafana:10.1.0
            docker pull prom/alertmanager:v0.26.0
            docker pull prom/node-exporter:v1.6.1
            docker pull gcr.io/cadvisor/cadvisor:v0.47.0
            log_success "Images mises à jour"
            ;;
        *)
            log_error "Commande non implémentée: $COMMAND"
            log_error "Commandes disponibles: deploy, monitoring, remove, list, status, logs, update"
            exit 1
            ;;
    esac
    
    log_success "Déploiement terminé avec succès!"
}

# Exécuter la fonction principale
main "$@"
