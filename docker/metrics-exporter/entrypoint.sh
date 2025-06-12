#!/bin/bash
# Point d'entrée pour l'exportateur de métriques FiveM XDP

set -e

# Couleurs pour les logs
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✅${NC} $1"
}

# Vérifier que bpftool est disponible
if ! command -v bpftool >/dev/null 2>&1; then
    echo "❌ bpftool n'est pas disponible dans ce conteneur"
    echo "Assurez-vous que le conteneur a accès aux outils BPF"
    exit 1
fi

log "Démarrage de l'exportateur de métriques FiveM XDP"
log "Port: ${EXPORTER_PORT:-9100}"
log "Intervalle: ${METRICS_INTERVAL:-15}s"
log "Niveau de log: ${LOG_LEVEL:-INFO}"

# Démarrer l'exportateur Python
log_success "Exportateur de métriques prêt"
exec python3 exporter.py
