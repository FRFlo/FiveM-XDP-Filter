#!/bin/bash
# Script de test pour valider le déploiement du système FiveM XDP Filter
# Effectue des tests complets de fonctionnement

set -e

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration de test
TEST_SERVER_IP="127.0.0.1"
TEST_SERVER_NAME="test-server-$(date +%s)"
TEST_INTERFACE="lo"

# Compteurs de tests
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Fonction de logging
log() {
    echo -e "${BLUE}[TEST $(date +'%H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[TEST $(date +'%H:%M:%S')] ✅${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

log_error() {
    echo -e "${RED}[TEST $(date +'%H:%M:%S')] ❌${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

log_warning() {
    echo -e "${YELLOW}[TEST $(date +'%H:%M:%S')] ⚠️${NC} $1"
}

# Fonction de test générique
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    log "Test: $test_name"
    
    if eval "$test_command"; then
        log_success "$test_name"
        return 0
    else
        log_error "$test_name"
        return 1
    fi
}

# Nettoyage en fin de test
cleanup_test() {
    log "Nettoyage des ressources de test..."
    
    # Supprimer le serveur de test
    ./deploy.sh remove -n "$TEST_SERVER_NAME" 2>/dev/null || true
    
    # Nettoyer les conteneurs de test
    docker stop "$TEST_SERVER_NAME" 2>/dev/null || true
    docker rm "$TEST_SERVER_NAME" 2>/dev/null || true
    
    # Supprimer la configuration de test
    rm -rf "config/servers/$TEST_SERVER_NAME" 2>/dev/null || true
    
    log "Nettoyage terminé"
}

# Configurer le nettoyage automatique
trap cleanup_test EXIT

# Tests de prérequis
test_prerequisites() {
    log "=== Tests des Prérequis ==="
    
    run_test "Docker installé" "command -v docker >/dev/null"
    run_test "Docker Compose installé" "docker compose version >/dev/null"
    run_test "Privilèges root" "[ \$(id -u) = 0 ]"
    run_test "Support BPF" "[ -d /sys/fs/bpf ]"
    run_test "Interface de test disponible" "ip link show $TEST_INTERFACE >/dev/null"
}

# Tests de compilation
test_compilation() {
    log "=== Tests de Compilation ==="
    
    run_test "Compilation du filtre XDP" "make clean && make fivem_xdp.o"
    run_test "Compilation de l'outil de config" "make fivem_xdp_config"
    run_test "Vérification du programme XDP" "make verify"
}

# Tests de validation des entrées
test_input_validation() {
    log "=== Tests de Validation des Entrées ==="
    
    # Test d'IP invalide
    run_test "Rejet IP invalide" "! ./deploy.sh deploy -s 999.999.999.999 -n test 2>/dev/null"
    
    # Test de nom de serveur invalide
    run_test "Rejet nom serveur invalide" "! ./deploy.sh deploy -s 127.0.0.1 -n 'invalid name!' 2>/dev/null"
    
    # Test de taille de serveur invalide
    run_test "Rejet taille serveur invalide" "! ./deploy.sh deploy -s 127.0.0.1 -n test -z invalid 2>/dev/null"
}

# Tests de déploiement
test_deployment() {
    log "=== Tests de Déploiement ==="
    
    # Test de déploiement complet
    run_test "Déploiement serveur de test" \
        "./deploy.sh deploy -s $TEST_SERVER_IP -n $TEST_SERVER_NAME -z small -i $TEST_INTERFACE --no-monitoring"
    
    # Attendre que les services démarrent
    sleep 10
    
    # Vérifier que les conteneurs sont en cours d'exécution
    run_test "Conteneur XDP manager actif" \
        "docker ps | grep -q fivem-xdp-$TEST_SERVER_NAME"
    
    run_test "Conteneur metrics exporter actif" \
        "docker ps | grep -q fivem-metrics-$TEST_SERVER_NAME"
    
    # Vérifier les logs des conteneurs
    run_test "Logs XDP manager sans erreur" \
        "! docker logs fivem-xdp-$TEST_SERVER_NAME 2>&1 | grep -i error"
    
    run_test "Logs metrics exporter sans erreur" \
        "! docker logs fivem-metrics-$TEST_SERVER_NAME 2>&1 | grep -i error"
}

# Tests de monitoring
test_monitoring() {
    log "=== Tests de Monitoring ==="
    
    # Déployer la stack de monitoring
    run_test "Déploiement stack monitoring" \
        "./deploy.sh monitoring"
    
    # Attendre que les services démarrent
    sleep 15
    
    # Tester les endpoints
    run_test "Prometheus accessible" \
        "timeout 10 curl -s http://localhost:9090/-/healthy >/dev/null"
    
    run_test "Grafana accessible" \
        "timeout 10 curl -s http://localhost:3000/api/health >/dev/null"
    
    run_test "AlertManager accessible" \
        "timeout 10 curl -s http://localhost:9093/-/healthy >/dev/null"
    
    # Tester l'endpoint des métriques (si disponible)
    if timeout 5 curl -s http://localhost:9100/metrics >/dev/null 2>&1; then
        run_test "Métriques XDP disponibles" \
            "curl -s http://localhost:9100/metrics | grep -q fivem_xdp"
    else
        log_warning "Endpoint métriques non disponible (normal si pas de serveur actif)"
    fi
}

# Tests de configuration
test_configuration() {
    log "=== Tests de Configuration ==="
    
    # Vérifier que la configuration a été créée
    run_test "Fichier de configuration créé" \
        "[ -f config/servers/$TEST_SERVER_NAME/server.env ]"
    
    # Vérifier le contenu de la configuration
    run_test "Configuration contient l'IP du serveur" \
        "grep -q SERVER_IP=$TEST_SERVER_IP config/servers/$TEST_SERVER_NAME/server.env"
    
    run_test "Configuration contient le nom du serveur" \
        "grep -q SERVER_NAME=$TEST_SERVER_NAME config/servers/$TEST_SERVER_NAME/server.env"
}

# Tests de nettoyage
test_cleanup() {
    log "=== Tests de Nettoyage ==="
    
    # Test de suppression de serveur
    run_test "Suppression du serveur de test" \
        "./deploy.sh remove -n $TEST_SERVER_NAME"
    
    # Vérifier que les conteneurs ont été supprimés
    run_test "Conteneurs supprimés" \
        "! docker ps -a | grep -q $TEST_SERVER_NAME"
    
    # Vérifier que la configuration a été supprimée
    run_test "Configuration supprimée" \
        "! [ -f config/servers/$TEST_SERVER_NAME/server.env ]"
}

# Tests de robustesse
test_robustness() {
    log "=== Tests de Robustesse ==="
    
    # Test de déploiement avec force
    run_test "Redéploiement avec --force" \
        "./deploy.sh deploy -s $TEST_SERVER_IP -n $TEST_SERVER_NAME -z small --force --no-monitoring"
    
    # Test de gestion des erreurs Docker
    run_test "Gestion erreur conteneur inexistant" \
        "! docker stop conteneur-inexistant 2>/dev/null"
}

# Afficher le rapport final
show_report() {
    echo ""
    echo "========================================"
    echo "         RAPPORT DE TEST FINAL"
    echo "========================================"
    echo "Tests exécutés: $TESTS_TOTAL"
    echo "Tests réussis:  $TESTS_PASSED"
    echo "Tests échoués:  $TESTS_FAILED"
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        log_success "Tous les tests sont passés ! ✅"
        echo "Le système FiveM XDP Filter est prêt pour la production."
        exit 0
    else
        log_error "$TESTS_FAILED test(s) ont échoué ❌"
        echo "Veuillez corriger les problèmes avant le déploiement en production."
        exit 1
    fi
}

# Fonction principale
main() {
    echo "🧪 Tests de Validation du Système FiveM XDP Filter"
    echo "=================================================="
    echo ""
    
    # Vérifier les privilèges
    if [ "$(id -u)" != "0" ]; then
        log_error "Ce script doit être exécuté avec des privilèges root"
        exit 1
    fi
    
    # Exécuter tous les tests
    test_prerequisites
    test_compilation
    test_input_validation
    test_deployment
    test_configuration
    test_monitoring
    test_robustness
    test_cleanup
    
    # Afficher le rapport final
    show_report
}

# Exécuter les tests
main "$@"
