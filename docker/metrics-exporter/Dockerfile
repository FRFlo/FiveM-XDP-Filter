# Exportateur de métriques pour le filtre XDP FiveM - Debian 12
# Exporte les statistiques BPF au format Prometheus
FROM python:3.11-slim-bookworm

# Installer les dépendances système pour Debian 12
RUN apt-get update && apt-get install -y \
    bpftool \
    linux-tools-common \
    && rm -rf /var/lib/apt/lists/*

# Créer le répertoire de travail
WORKDIR /app

# Copier les fichiers de l'application
COPY requirements.txt ./
COPY exporter.py ./
COPY entrypoint.sh ./

# Installer les dépendances Python
RUN pip install --no-cache-dir -r requirements.txt

# Rendre le script d'entrée exécutable
RUN chmod +x entrypoint.sh

# Variables d'environnement par défaut
ENV EXPORTER_PORT=9100
ENV METRICS_INTERVAL=15
ENV LOG_LEVEL=INFO

# Exposer le port des métriques
EXPOSE 9100

# Utilisateur non-root pour la sécurité
RUN useradd -r -s /bin/false exporter
USER exporter

# Point d'entrée
ENTRYPOINT ["./entrypoint.sh"]
