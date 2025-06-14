#!/bin/bash
# Script de validation de l'installation FiveM XDP Filter - Debian 12
# Installation validation script for FiveM XDP Filter - Debian 12

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

# Compteurs de validation
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Fonction de test
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    log "Test: $test_name"
    
    if eval "$test_command" >/dev/null 2>&1; then
        log_success "✅ $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_error "❌ $test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Validation du système
validate_system() {
    log "🔍 Validation du système Debian 12..."
    
    # Vérifier Debian 12
    run_test "Distribution Debian 12" "[ -f /etc/os-release ] && . /etc/os-release && [ \"\$ID\" = \"debian\" ] && [ \"\$VERSION_ID\" = \"12\" ]"
    
    # Vérifier les privilèges root
    run_test "Privilèges root" "[ \$(id -u) -eq 0 ]"
    
    # Vérifier le kernel
    run_test "Version du kernel (≥5.10)" "[ \$(uname -r | cut -d. -f1) -ge 5 ] && [ \$(uname -r | cut -d. -f2) -ge 10 ]"
    
    # Vérifier le support BPF
    run_test "Support BPF du kernel" "[ -d /sys/fs/bpf ]"
}

# Validation des dépendances
validate_dependencies() {
    log "🔧 Validation des dépendances..."
    
    # Outils de compilation
    run_test "Clang installé" "command -v clang"
    run_test "GCC installé" "command -v gcc"
    run_test "Make installé" "command -v make"
    
    # Outils BPF
    run_test "bpftool installé" "command -v bpftool"
    run_test "libbpf-dev disponible" "dpkg -l | grep -q libbpf-dev"
    run_test "libelf-dev disponible" "dpkg -l | grep -q libelf-dev"
    
    # Outils réseau
    run_test "iproute2 installé" "command -v ip"
    run_test "curl installé" "command -v curl"
    run_test "jq installé" "command -v jq"
}

# Validation de Docker
validate_docker() {
    log "🐳 Validation de Docker..."
    
    run_test "Docker installé" "command -v docker"
    run_test "Docker actif" "systemctl is-active docker"
    run_test "Docker Compose disponible" "docker compose version"
    run_test "Accès Docker sans sudo" "docker ps"
}

# Validation de la compilation
validate_compilation() {
    log "⚙️ Validation de la compilation..."
    
    # Vérifier les fichiers sources
    run_test "Fichier source XDP présent" "[ -f fivem_xdp.c ]"
    run_test "Fichier config présent" "[ -f fivem_xdp_config.c ]"
    run_test "Makefile présent" "[ -f Makefile ]"
    
    # Tenter la compilation
    if [ -f Makefile ]; then
        run_test "Compilation XDP réussie" "make clean && make all"
        run_test "Binaire XDP généré" "[ -f fivem_xdp.o ]"
        run_test "Outil de config généré" "[ -f fivem_xdp_config ]"
    fi
}

# Validation des conteneurs
validate_containers() {
    log "📦 Validation des conteneurs..."
    
    # Vérifier les Dockerfiles
    run_test "Dockerfile XDP Manager" "[ -f docker/xdp-manager/Dockerfile ]"
    run_test "Dockerfile Metrics Exporter" "[ -f docker/metrics-exporter/Dockerfile ]"
    
    # Tenter la construction des images
    if command -v docker >/dev/null 2>&1; then
        run_test "Construction image XDP Manager" "docker build -t fivem-xdp-manager:test docker/xdp-manager/"
        run_test "Construction image Metrics Exporter" "docker build -t fivem-metrics-exporter:test docker/metrics-exporter/"
        
        # Nettoyer les images de test
        docker rmi fivem-xdp-manager:test fivem-metrics-exporter:test >/dev/null 2>&1 || true
    fi
}

# Validation des scripts
validate_scripts() {
    log "📜 Validation des scripts..."
    
    run_test "Script install.sh présent" "[ -f install.sh ]"
    run_test "Script install.sh exécutable" "[ -x install.sh ]"
    run_test "Script deploy.sh présent" "[ -f deploy.sh ]"
    run_test "Script deploy.sh exécutable" "[ -x deploy.sh ]"
    run_test "Script install-dependencies.sh présent" "[ -f install-dependencies.sh ]"
    run_test "Script install-dependencies.sh exécutable" "[ -x install-dependencies.sh ]"
}

# Validation de la documentation
validate_documentation() {
    log "📚 Validation de la documentation..."
    
    run_test "README.md présent" "[ -f README.md ]"
    run_test "Documentation technique présente" "[ -d xdp_docs ]"
    run_test "Guide de démarrage rapide" "[ -f xdp_docs/QUICK_START.md ]"
    run_test "Documentation Docker" "[ -f docker/README.md ]"
}

# Afficher le résumé
show_summary() {
    echo ""
    echo "🏁 RÉSUMÉ DE LA VALIDATION"
    echo "=========================="
    echo "Tests réussis: $TESTS_PASSED"
    echo "Tests échoués: $TESTS_FAILED"
    echo "Total: $TESTS_TOTAL"
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        log_success "🎉 Tous les tests sont passés! L'installation est prête."
        echo ""
        echo "🚀 PROCHAINES ÉTAPES:"
        echo "===================="
        echo "1. Lancez l'installation: sudo ./install.sh -s <IP_SERVEUR>"
        echo "2. Vérifiez le déploiement: sudo ./deploy.sh status"
        echo "3. Accédez à Grafana: http://localhost:3000"
        return 0
    else
        log_error "❌ $TESTS_FAILED test(s) ont échoué. Veuillez corriger les problèmes."
        echo ""
        echo "🔧 ACTIONS RECOMMANDÉES:"
        echo "======================="
        echo "1. Vérifiez que vous êtes sur Debian 12"
        echo "2. Exécutez avec sudo si nécessaire"
        echo "3. Installez les dépendances manquantes"
        echo "4. Relancez la validation"
        return 1
    fi
}

# Fonction principale
main() {
    echo "🛡️ FiveM XDP Filter - Validation de l'Installation (Debian 12)"
    echo "=============================================================="
    echo ""
    
    validate_system
    validate_dependencies
    validate_docker
    validate_compilation
    validate_containers
    validate_scripts
    validate_documentation
    
    show_summary
}

# Vérifier si on est dans le bon répertoire
if [ ! -f "install.sh" ] || [ ! -f "fivem_xdp.c" ]; then
    log_error "Ce script doit être exécuté depuis le répertoire racine du projet FiveM-XDP-Filter"
    exit 1
fi

# Lancer la validation
main
