#!/bin/bash
# Installation automatique des dépendances pour FiveM XDP Filter - Debian 12 exclusivement
# Automatic dependency installation for FiveM XDP Filter - Debian 12 exclusively

set -e

echo "🔧 Installation des dépendances pour FiveM XDP Filter (Debian 12)..."
echo "🔧 Installing dependencies for FiveM XDP Filter (Debian 12)..."

# Vérifier que nous sommes sur Debian 12
if [ -f /etc/os-release ]; then
    . /etc/os-release
    if [[ "$ID" != "debian" ]] || [[ "$VERSION_ID" != "12" ]]; then
        echo "❌ Ce script est conçu exclusivement pour Debian 12"
        echo "❌ This script is designed exclusively for Debian 12"
        echo "📋 Distribution détectée: $ID $VERSION_ID"
        echo "📋 Detected distribution: $ID $VERSION_ID"
        exit 1
    fi
else
    echo "❌ Impossible de détecter la distribution Linux"
    echo "❌ Cannot detect Linux distribution"
    exit 1
fi

echo "✅ Debian 12 détecté - Poursuite de l'installation"
echo "✅ Debian 12 detected - Continuing installation"

# Installation des paquets Debian 12
echo "🔄 Installation des paquets Debian 12..."
sudo apt update

# Installer les en-têtes du noyau spécifiques à la version courante
echo "📦 Installation des en-têtes du noyau..."
if ! sudo apt install -y linux-headers-$(uname -r) 2>/dev/null; then
    echo "⚠️  En-têtes spécifiques non disponibles, installation des en-têtes génériques..."
    sudo apt install -y \
        linux-headers-amd64 \
        linux-headers-generic \
        linux-libc-dev
fi

# Installer les dépendances de développement BPF/XDP
echo "📦 Installation des outils de développement BPF/XDP..."
sudo apt install -y \
    libbpf-dev \
    libelf-dev \
    clang \
    llvm \
    gcc \
    make \
    pkg-config \
    zlib1g-dev \
    bpftool \
    linux-tools-common \
    linux-tools-generic

# Installer les outils réseau et de monitoring
echo "📦 Installation des outils réseau et de monitoring..."
sudo apt install -y \
    iproute2 \
    ethtool \
    tcpdump \
    curl \
    jq \
    htop

# Vérifier que bpftool est disponible
if ! command -v bpftool >/dev/null 2>&1; then
    echo "❌ bpftool n'est pas disponible après l'installation"
    echo "❌ bpftool is not available after installation"
    exit 1
fi

# Vérification de l'installation / Verify installation
echo "🔍 Vérification de l'installation..."
echo "🔍 Verifying installation..."

# Vérifier les en-têtes du noyau / Check kernel headers
HEADERS_FOUND=0
for header_path in "/usr/src/linux-headers-$(uname -r)" "/lib/modules/$(uname -r)/build" "/usr/include/linux" "/usr/src/linux-headers-amd64"; do
    if [ -d "$header_path" ]; then
        echo "✅ En-têtes du noyau trouvés: $header_path"
        echo "✅ Kernel headers found: $header_path"
        HEADERS_FOUND=1
        break
    fi
done

if [ $HEADERS_FOUND -eq 0 ]; then
    echo "⚠️  En-têtes du noyau non trouvés dans les emplacements standard"
    echo "⚠️  Kernel headers not found in standard locations"
    echo "📋 Vérifiez manuellement avec: ls /usr/include/linux/"
fi

# Vérifier clang / Check clang
if command -v clang >/dev/null 2>&1; then
    echo "✅ clang installé: $(clang --version | head -n1)"
    echo "✅ clang installed: $(clang --version | head -n1)"
else
    echo "❌ clang non trouvé"
    echo "❌ clang not found"
fi

# Vérifier libbpf / Check libbpf
if pkg-config --exists libbpf 2>/dev/null; then
    echo "✅ libbpf installé: $(pkg-config --modversion libbpf)"
    echo "✅ libbpf installed: $(pkg-config --modversion libbpf)"
else
    echo "⚠️  libbpf non détecté via pkg-config"
    echo "⚠️  libbpf not detected via pkg-config"
fi

echo ""
echo "🎉 Installation des dépendances terminée!"
echo "🎉 Dependency installation completed!"
echo ""
echo "📋 Prochaines étapes:"
echo "📋 Next steps:"
echo "   1. make clean"
echo "   2. make all"
echo "   3. sudo make install INTERFACE=eth0"
echo ""
