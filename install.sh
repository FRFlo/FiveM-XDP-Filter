#!/bin/bash
# Installation complète en une commande pour FiveM XDP Filter - Debian 12 exclusivement
# Complete single-command installation for FiveM XDP Filter - Debian 12 exclusively

set -e

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonctions de logging
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Afficher l'aide
show_help() {
    cat << EOF
🛡️ FiveM XDP Filter - Installation Complète (Debian 12)

UTILISATION:
    sudo ./install.sh [OPTIONS]

OPTIONS:
    -s, --server-ip IP      Adresse IP du serveur FiveM (requis)
    -i, --interface IFACE   Interface réseau (défaut: eth0)
    -z, --size SIZE         Taille du serveur: small|medium|large|dev (défaut: medium)
    -n, --name NAME         Nom du serveur (défaut: auto-généré)
    -p, --port PORT         Port du serveur FiveM (défaut: 30120)
    --no-monitoring         Désactiver la stack de monitoring
    --force                 Forcer l'installation même si déjà installé
    -h, --help              Afficher cette aide

EXEMPLES:
    # Installation basique
    sudo ./install.sh -s 192.168.1.100

    # Installation complète avec monitoring
    sudo ./install.sh -s 192.168.1.100 -i eth0 -z medium -n mon-serveur

    # Installation pour développement
    sudo ./install.sh -s 127.0.0.1 -z dev --no-monitoring

PRÉREQUIS:
    - Debian 12 (Bookworm)
    - Privilèges root (sudo)
    - Connexion Internet

APRÈS INSTALLATION:
    - Grafana: http://localhost:3000 (admin/admin123)
    - Prometheus: http://localhost:9090
    - Métriques: http://localhost:9100/metrics

EOF
}

# Vérifier les prérequis système
check_system_requirements() {
    log "Vérification des prérequis système..."

    # Vérifier que nous sommes sur Debian 12
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID" != "debian" ]] || [[ "$VERSION_ID" != "12" ]]; then
            log_error "Ce script est conçu exclusivement pour Debian 12"
            log_error "Distribution détectée: $ID $VERSION_ID"
            exit 1
        fi
    else
        log_error "Impossible de détecter la distribution Linux"
        exit 1
    fi

    # Vérifier les privilèges root
    if [ "$(id -u)" != "0" ]; then
        log_error "Ce script doit être exécuté avec des privilèges root"
        log_error "Utilisez: sudo $0"
        exit 1
    fi

    # Vérifier la connexion Internet
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        log_error "Connexion Internet requise pour l'installation"
        exit 1
    fi

    log_success "Prérequis système vérifiés (Debian 12)"
}

# Installer les dépendances
install_dependencies() {
    log "Installation des dépendances..."
    
    # Exécuter le script d'installation des dépendances
    if [ -f "./install-dependencies.sh" ]; then
        chmod +x ./install-dependencies.sh
        ./install-dependencies.sh
    else
        log_error "Script install-dependencies.sh non trouvé"
        exit 1
    fi
    
    log_success "Dépendances installées"
}

# Installer Docker si nécessaire
install_docker() {
    if command -v docker >/dev/null 2>&1; then
        log "Docker déjà installé"
        return 0
    fi

    log "Installation de Docker..."
    
    # Installer les prérequis
    apt-get update
    apt-get install -y ca-certificates curl gnupg lsb-release

    # Ajouter la clé GPG officielle de Docker
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    # Ajouter le dépôt Docker
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Installer Docker
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

    # Démarrer et activer Docker
    systemctl start docker
    systemctl enable docker

    log_success "Docker installé et configuré"
}

# Compiler le filtre XDP
compile_xdp_filter() {
    log "Compilation du filtre XDP..."
    
    if [ -f "./Makefile" ]; then
        make clean
        make all
        log_success "Filtre XDP compilé avec succès"
    else
        log_error "Makefile non trouvé"
        exit 1
    fi
}

# Déployer le système
deploy_system() {
    local server_ip="$1"
    local interface="$2"
    local server_size="$3"
    local server_name="$4"
    local server_port="$5"
    local no_monitoring="$6"
    local force="$7"

    log "Déploiement du système FiveM XDP Filter..."

    # Construire la commande de déploiement
    local deploy_cmd="./deploy.sh deploy -s $server_ip -i $interface -z $server_size -p $server_port"
    
    if [ -n "$server_name" ]; then
        deploy_cmd="$deploy_cmd -n $server_name"
    fi
    
    if [ "$no_monitoring" = "true" ]; then
        deploy_cmd="$deploy_cmd --no-monitoring"
    fi
    
    if [ "$force" = "true" ]; then
        deploy_cmd="$deploy_cmd --force"
    fi

    # Exécuter le déploiement
    if [ -f "./deploy.sh" ]; then
        chmod +x ./deploy.sh
        eval $deploy_cmd
        log_success "Système déployé avec succès"
    else
        log_error "Script deploy.sh non trouvé"
        exit 1
    fi
}

# Afficher le résumé final
show_final_summary() {
    local server_ip="$1"
    local interface="$2"
    local server_name="$3"
    local no_monitoring="$4"

    log_success "🎉 Installation terminée avec succès!"
    echo ""
    echo "📊 RÉSUMÉ DE L'INSTALLATION:"
    echo "============================"
    echo "• Serveur FiveM: $server_ip"
    echo "• Interface réseau: $interface"
    echo "• Nom du serveur: ${server_name:-auto-généré}"
    echo "• Filtre XDP: ✅ Actif"
    echo ""
    
    if [ "$no_monitoring" != "true" ]; then
        echo "🌐 INTERFACES WEB:"
        echo "=================="
        echo "• Grafana: http://localhost:3000 (admin/admin123)"
        echo "• Prometheus: http://localhost:9090"
        echo "• AlertManager: http://localhost:9093"
        echo "• Métriques: http://localhost:9100/metrics"
        echo ""
    fi
    
    echo "🔧 COMMANDES UTILES:"
    echo "==================="
    echo "• Voir les logs: ./deploy.sh logs -n ${server_name:-server-name}"
    echo "• Voir l'état: ./deploy.sh status"
    echo "• Voir les stats: make stats"
    echo ""
    
    log_success "FiveM XDP Filter est maintenant opérationnel!"
}

# Variables par défaut
SERVER_IP=""
INTERFACE="eth0"
SERVER_SIZE="medium"
SERVER_NAME=""
SERVER_PORT="30120"
NO_MONITORING="false"
FORCE="false"

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
        *)
            log_error "Option inconnue: $1"
            show_help
            exit 1
            ;;
    esac
done

# Vérifier que l'IP du serveur est fournie
if [ -z "$SERVER_IP" ]; then
    log_error "L'adresse IP du serveur est requise"
    log_error "Utilisez: sudo $0 -s <IP_SERVEUR>"
    show_help
    exit 1
fi

# Exécution principale
main() {
    echo "🛡️ FiveM XDP Filter - Installation Complète (Debian 12)"
    echo "========================================================"
    echo ""
    
    check_system_requirements
    install_dependencies
    install_docker
    compile_xdp_filter
    deploy_system "$SERVER_IP" "$INTERFACE" "$SERVER_SIZE" "$SERVER_NAME" "$SERVER_PORT" "$NO_MONITORING" "$FORCE"
    show_final_summary "$SERVER_IP" "$INTERFACE" "$SERVER_NAME" "$NO_MONITORING"
}

# Lancer l'installation
main
