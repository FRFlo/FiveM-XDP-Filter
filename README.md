# 🛡️ FiveM XDP Filter - Protection DDoS Avancée (Debian 12)

Ce système de filtrage XDP protège les serveurs FiveM contre les attaques DDoS et le trafic malveillant. Optimisé exclusivement pour **Debian 12 (Bookworm)** avec déploiement automatisé et surveillance en temps réel via Grafana.

## 🚀 Installation en Une Commande

**Installation complète automatisée :**
```bash
sudo ./install.sh -s 192.168.1.100
```

**Installation avec options avancées :**
```bash
sudo ./install.sh -s 192.168.1.100 -i eth0 -z medium -n mon-serveur
```

**Accès aux interfaces après installation :**
- 📊 **Grafana** : http://localhost:3000 (admin/admin123)
- 🔍 **Prometheus** : http://localhost:9090
- 🚨 **AlertManager** : http://localhost:9093
- 📈 **Métriques** : http://localhost:9100/metrics

## 📋 Prérequis Système

- **OS :** Debian 12 (Bookworm) **EXCLUSIVEMENT**
- **Kernel :** Version 5.10+ avec support XDP/eBPF complet
- **Privilèges :** Accès root (sudo) requis
- **Connexion :** Internet pour téléchargement des dépendances
- **Ressources :** 2GB RAM minimum, 10GB espace disque

## 🎯 Fonctionnalités

- ✅ **Protection DDoS avancée** avec filtrage XDP haute performance
- ✅ **Installation en une commande** - Zéro configuration manuelle
- ✅ **Optimisé pour Debian 12** - Performance et stabilité maximales
- ✅ **Surveillance complète** avec Prometheus + Grafana
- ✅ **Alertes intelligentes** via AlertManager
- ✅ **Configuration flexible** (small/medium/large/dev servers)
- ✅ **Containerisation complète** avec Docker natif
- ✅ **Validation système automatique** - Détection d'erreurs précoce

## 📖 Documentation Complète

- 🚀 **[Guide de Démarrage Rapide](QUICK_START.md)** - Déploiement en 5 minutes
- 🐳 **[Documentation Docker](docker/README.md)** - Containerisation et monitoring
- 📊 **[Solution de Déploiement](DEPLOYMENT_SOLUTION.md)** - Architecture complète
- 📋 **[Rapport de Validation](VALIDATION_REPORT.md)** - Tests et validation
- 📚 **[Documentation Technique](xdp_docs/README.md)** - Détails techniques

## 🛠️ Options d'Installation

### Installation Rapide (Recommandée)
```bash
# Installation basique avec monitoring complet
sudo ./install.sh -s 192.168.1.100

# Installation pour serveur de production
sudo ./install.sh -s 192.168.1.100 -i eth0 -z large -n prod-server

# Installation pour développement (sans monitoring)
sudo ./install.sh -s 127.0.0.1 -z dev --no-monitoring
```

### Options Disponibles
```bash
sudo ./install.sh [OPTIONS]

OPTIONS:
  -s, --server-ip IP      Adresse IP du serveur FiveM (REQUIS)
  -i, --interface IFACE   Interface réseau (défaut: eth0)
  -z, --size SIZE         Taille: small|medium|large|dev (défaut: medium)
  -n, --name NAME         Nom du serveur (défaut: auto-généré)
  -p, --port PORT         Port FiveM (défaut: 30120)
  --no-monitoring         Désactiver la surveillance
  --force                 Forcer la réinstallation
  -h, --help              Afficher l'aide complète
```

### Installation Manuelle (Experts)

Si vous préférez une installation étape par étape :

```bash
# 1. Installer les dépendances
sudo ./install-dependencies.sh

# 2. Compiler le filtre XDP
make all

# 3. Déployer avec Docker
sudo ./deploy.sh deploy -s 192.168.1.100 -n mon-serveur

# 4. Vérifier le fonctionnement
make stats
```

### Gestion Post-Installation

```bash
# Voir l'état des services
sudo ./deploy.sh status

# Voir les logs en temps réel
sudo ./deploy.sh logs -n mon-serveur

# Voir les statistiques du filtre
make stats

# Arrêter un serveur
sudo ./deploy.sh remove -n mon-serveur
```

## 🔧 Dépannage Rapide

### Problèmes Courants

**Erreur "Distribution non supportée"**
```bash
# Vérifier la version de Debian
cat /etc/os-release
# Doit afficher: ID=debian, VERSION_ID="12"
```

**Docker non disponible**
```bash
# Le script install.sh installe Docker automatiquement
# Si problème, installer manuellement:
sudo apt update && sudo apt install docker.io docker-compose-plugin
```

**Interface réseau introuvable**
```bash
# Lister les interfaces disponibles
ip link show
# Utiliser le bon nom avec -i
sudo ./install.sh -s 192.168.1.100 -i ens18
```

### Support et Logs

```bash
# Logs détaillés du système
journalctl -u docker -f

# Logs des conteneurs FiveM XDP
docker logs fivem-xdp-mon-serveur

# Vérification de l'état XDP
sudo bpftool prog show
```

## 📚 Documentation Technique

- 🚀 **[Guide de Démarrage Rapide](xdp_docs/QUICK_START.md)** - Installation en 5 minutes
- 🐳 **[Documentation Docker](docker/README.md)** - Containerisation et monitoring
- 📊 **[Solution de Déploiement](xdp_docs/DEPLOYMENT_SOLUTION.md)** - Architecture complète
- 📋 **[Rapport de Validation](xdp_docs/VALIDATION_REPORT.md)** - Tests et validation
- 📚 **[Documentation Technique](xdp_docs/README.md)** - Détails techniques avancés

## 📄 Licence

Ce programme XDP est publié sous licence MIT. Voir le fichier LICENSE pour plus d'informations.

---

**🎯 Optimisé pour Debian 12 | 🛡️ Protection DDoS Avancée | 🚀 Installation en Une Commande**
