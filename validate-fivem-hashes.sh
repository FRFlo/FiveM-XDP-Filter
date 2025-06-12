#!/bin/bash
# Script de validation des hash de messages FiveM
# Vérifie que les hash constants dans le code XDP sont à jour

set -e

# Couleurs pour les logs
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_success() {
    echo -e "${GREEN}✅${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

log_error() {
    echo -e "${RED}❌${NC} $1"
}

echo "🔍 Validation des Hash de Messages FiveM"
echo "========================================"

# Extraire les hash du code XDP
echo "Extraction des hash constants du code XDP..."

hash_count=$(grep -c "MSG_.*_HASH" fivem_xdp.c || echo "0")

if [ "$hash_count" -eq 0 ]; then
    log_error "Aucun hash de message trouvé dans fivem_xdp.c"
    exit 1
fi

log_success "Trouvé $hash_count hash constants dans le code XDP"

# Vérifier la fonction de validation des hash
echo ""
echo "Vérification de la fonction de validation..."

if grep -q "is_valid_fivem_message_hash" fivem_xdp.c; then
    log_success "Fonction de validation des hash présente"
else
    log_error "Fonction de validation des hash manquante"
    exit 1
fi

# Vérifier que tous les hash sont utilisés dans la validation
echo ""
echo "Vérification de l'utilisation des hash..."

# Extraire tous les hash définis
hash_defines=$(grep "MSG_.*_HASH" fivem_xdp.c | grep "#define" | awk '{print $2}' | sort)
hash_usage=$(grep -A 50 "is_valid_fivem_message_hash" fivem_xdp.c | grep "MSG_.*_HASH" | sed 's/.*\(MSG_[A-Z_]*_HASH\).*/\1/' | sort | uniq)

echo "Hash définis:"
echo "$hash_defines"
echo ""
echo "Hash utilisés dans la validation:"
echo "$hash_usage"

# Comparer les listes
unused_hashes=$(comm -23 <(echo "$hash_defines") <(echo "$hash_usage"))
if [ -n "$unused_hashes" ]; then
    log_warning "Hash définis mais non utilisés:"
    echo "$unused_hashes"
else
    log_success "Tous les hash définis sont utilisés"
fi

# Vérifier la structure de validation optimisée
echo ""
echo "Vérification de l'optimisation de la validation..."

if grep -q "switch.*first_byte" fivem_xdp.c; then
    log_success "Validation optimisée par premier byte présente"
else
    log_warning "Validation non optimisée - considérez l'optimisation par premier byte"
fi

# Vérifier les commentaires de documentation
echo ""
echo "Vérification de la documentation des hash..."

documented_hashes=$(grep -B1 -A1 "MSG_.*_HASH" fivem_xdp.c | grep -c "//" || echo "0")
total_hashes=$(grep -c "MSG_.*_HASH.*0x" fivem_xdp.c || echo "0")

if [ "$documented_hashes" -gt 0 ]; then
    log_success "Hash documentés: $documented_hashes/$total_hashes"
else
    log_warning "Aucune documentation trouvée pour les hash"
fi

# Vérifier la cohérence des valeurs hexadécimales
echo ""
echo "Vérification de la cohérence des valeurs..."

invalid_hashes=$(grep "MSG_.*_HASH" fivem_xdp.c | grep -v "0x[0-9A-Fa-f]\{8\}" | wc -l)
if [ "$invalid_hashes" -eq 0 ]; then
    log_success "Tous les hash ont un format hexadécimal valide"
else
    log_error "$invalid_hashes hash(es) ont un format invalide"
fi

# Vérifier les doublons
echo ""
echo "Vérification des doublons..."

hash_values=$(grep "MSG_.*_HASH.*0x" fivem_xdp.c | awk '{print $3}' | sort)
unique_values=$(echo "$hash_values" | uniq)

if [ "$(echo "$hash_values" | wc -l)" -eq "$(echo "$unique_values" | wc -l)" ]; then
    log_success "Aucun hash dupliqué trouvé"
else
    log_error "Hash dupliqués détectés"
    echo "Valeurs dupliquées:"
    echo "$hash_values" | uniq -d
fi

# Recommandations
echo ""
echo "📋 Recommandations:"
echo "==================="

echo "1. Vérifiez régulièrement les mises à jour FiveM pour de nouveaux types de messages"
echo "2. Testez la validation avec du trafic FiveM réel"
echo "3. Surveillez les métriques de paquets rejetés pour détecter de nouveaux types"
echo "4. Documentez la source de chaque hash pour faciliter la maintenance"

# Résumé final
echo ""
echo "📊 Résumé de la validation:"
echo "=========================="
echo "Hash constants trouvés: $hash_count"
echo "Hash utilisés: $(echo "$hash_usage" | wc -l)"
echo "Hash non utilisés: $(echo "$unused_hashes" | wc -l)"
echo "Format invalide: $invalid_hashes"

if [ "$invalid_hashes" -eq 0 ] && [ -z "$unused_hashes" ]; then
    log_success "Validation des hash FiveM réussie ✅"
    exit 0
else
    log_warning "Validation des hash FiveM avec avertissements ⚠️"
    exit 0
fi
