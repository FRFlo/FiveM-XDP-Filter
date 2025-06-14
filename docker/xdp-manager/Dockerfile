# FiveM XDP Filter Manager Container - Debian 12
# Manages XDP filter deployment, configuration, and lifecycle
FROM debian:12-slim

# Éviter les prompts interactifs pendant l'installation
ENV DEBIAN_FRONTEND=noninteractive

# Installer les dépendances système requises pour Debian 12
RUN apt-get update && apt-get install -y \
    clang \
    gcc \
    libbpf-dev \
    linux-headers-amd64 \
    bpftool \
    linux-tools-common \
    iproute2 \
    make \
    curl \
    jq \
    pkg-config \
    libelf-dev \
    && rm -rf /var/lib/apt/lists/*

# Créer le répertoire de travail
WORKDIR /opt/fivem-xdp

# Copier les fichiers source du filtre XDP
COPY ../../fivem_xdp.c ./
COPY ../../fivem_xdp_config.c ./
COPY ../../Makefile ./
COPY entrypoint.sh ./
COPY deploy-filter.sh ./

# Rendre les scripts exécutables
RUN chmod +x entrypoint.sh deploy-filter.sh

# Compiler le filtre XDP et l'outil de configuration
RUN make all

# Variables d'environnement par défaut
ENV XDP_INTERFACE=""
ENV SERVER_IP=""
ENV SERVER_SIZE="medium"
ENV AUTO_DEPLOY="false"
ENV METRICS_ENABLED="true"

# Exposer le port pour les métriques (si activées)
EXPOSE 9100

# Point d'entrée du conteneur
ENTRYPOINT ["./entrypoint.sh"]
CMD ["manage"]
