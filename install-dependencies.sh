#!/bin/bash
# Installation automatique des dépendances pour FiveM XDP Filter
# Automatic dependency installation for FiveM XDP Filter

set -e

echo "🔧 Installation des dépendances pour FiveM XDP Filter..."
echo "🔧 Installing dependencies for FiveM XDP Filter..."

# Détecter la distribution / Detect distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
elif type lsb_release >/dev/null 2>&1; then
    OS=$(lsb_release -si)
    VER=$(lsb_release -sr)
else
    echo "❌ Impossible de détecter la distribution Linux"
    echo "❌ Cannot detect Linux distribution"
    exit 1
fi

echo "📋 Distribution détectée: $OS $VER"
echo "📋 Detected distribution: $OS $VER"

# Installation selon la distribution / Install based on distribution
case $OS in
    *Ubuntu*|*Debian*)
        echo "🔄 Installation des paquets Ubuntu/Debian..."
        sudo apt update

        # Essayer d'installer les en-têtes spécifiques au noyau
        if ! sudo apt install -y linux-headers-$(uname -r) 2>/dev/null; then
            echo "⚠️  En-têtes spécifiques non disponibles, installation des en-têtes génériques..."
            sudo apt install -y \
                linux-headers-amd64 \
                linux-headers-generic \
                linux-libc-dev
        fi

        # Installer les autres dépendances
        sudo apt install -y \
            libbpf-dev \
            libelf-dev \
            clang \
            llvm \
            gcc \
            make \
            pkg-config \
            zlib1g-dev

        # Essayer d'installer bpftool (peut ne pas être disponible sur toutes les versions)
        sudo apt install -y bpftool 2>/dev/null || echo "⚠️  bpftool non disponible dans les dépôts"
        ;;
    *CentOS*|*"Red Hat"*|*Rocky*)
        echo "🔄 Installation des paquets CentOS/RHEL/Rocky..."
        if command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y \
                kernel-devel \
                kernel-headers \
                libbpf-devel \
                clang \
                llvm \
                bpftool \
                gcc \
                make \
                pkgconfig
        else
            sudo yum install -y \
                kernel-devel \
                kernel-headers \
                libbpf-devel \
                clang \
                llvm \
                gcc \
                make \
                pkgconfig
        fi
        ;;
    *Fedora*)
        echo "🔄 Installation des paquets Fedora..."
        sudo dnf install -y \
            kernel-devel \
            kernel-headers \
            libbpf-devel \
            clang \
            llvm \
            bpftool \
            gcc \
            make \
            pkgconfig
        ;;
    *Arch*)
        echo "🔄 Installation des paquets Arch Linux..."
        sudo pacman -S --noconfirm \
            linux-headers \
            libbpf \
            clang \
            llvm \
            bpf \
            gcc \
            make \
            pkgconfig
        ;;
    *)
        echo "❌ Distribution non supportée: $OS"
        echo "❌ Unsupported distribution: $OS"
        echo "📋 Veuillez installer manuellement:"
        echo "📋 Please install manually:"
        echo "   - kernel-headers/linux-headers"
        echo "   - libbpf-dev/libbpf-devel"
        echo "   - clang, llvm, gcc, make"
        exit 1
        ;;
esac

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
