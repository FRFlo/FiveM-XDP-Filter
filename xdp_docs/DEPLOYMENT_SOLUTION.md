# 🚀 Solution de Déploiement Automatisé FiveM XDP Filter

## 📋 Vue d'Ensemble

Cette solution complète permet le déploiement automatisé de filtres XDP pour la protection de serveurs FiveM avec surveillance en temps réel via Grafana. Tout est containerisé et peut être déployé en une seule commande.

## 🎯 Fonctionnalités Principales

### ✅ Déploiement Automatisé
- **Script unique** : `./deploy.sh` pour tout déployer
- **Multi-serveurs** : Support de plusieurs serveurs FiveM
- **Configuration flexible** : Différentes tailles de serveurs (small/medium/large)
- **Interface personnalisable** : Choix de l'interface réseau

### ✅ Containerisation Complète
- **XDP Manager** : Conteneur privilégié pour gérer les filtres XDP
- **Metrics Exporter** : Service d'export des métriques BPF vers Prometheus
- **Stack de surveillance** : Prometheus + Grafana + AlertManager
- **Monitoring système** : Node Exporter + cAdvisor

### ✅ Surveillance Avancée
- **Dashboards Grafana** : Visualisation en temps réel des métriques
- **Alertes intelligentes** : Notifications automatiques des incidents
- **Métriques complètes** : Performance, sécurité, système
- **Historique** : Rétention des données sur 30 jours

## 🏗️ Architecture de la Solution

```
┌─────────────────────────────────────────────────────────────────┐
│                        HOST SYSTEM                              │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │   FiveM Server  │  │   FiveM Server  │  │   FiveM Server  │  │
│  │      #1         │  │      #2         │  │      #3         │  │
│  │                 │  │                 │  │                 │  │
│  │ ┌─────────────┐ │  │ ┌─────────────┐ │  │ ┌─────────────┐ │  │
│  │ │XDP Filter   │ │  │ │XDP Filter   │ │  │ │XDP Filter   │ │  │
│  │ │(Privileged  │ │  │ │(Privileged  │ │  │ │(Privileged  │ │  │
│  │ │Container)   │ │  │ │Container)   │ │  │ │Container)   │ │  │
│  │ └─────────────┘ │  │ └─────────────┘ │  │ └─────────────┘ │  │
│  │ ┌─────────────┐ │  │ ┌─────────────┐ │  │ ┌─────────────┐ │  │
│  │ │Metrics      │ │  │ │Metrics      │ │  │ │Metrics      │ │  │
│  │ │Exporter     │ │  │ │Exporter     │ │  │ │Exporter     │ │  │
│  │ └─────────────┘ │  │ └─────────────┘ │  │ └─────────────┘ │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│           │                     │                     │         │
└───────────┼─────────────────────┼─────────────────────┼─────────┘
            │                     │                     │
            └─────────────────────┼─────────────────────┘
                                  │
                     ┌─────────────────────┐
                     │   MONITORING STACK  │
                     │    (Containers)     │
                     │                     │
                     │ ┌─────────────────┐ │
                     │ │   Prometheus    │ │ :9090
                     │ │  (Metrics DB)   │ │
                     │ └─────────────────┘ │
                     │ ┌─────────────────┐ │
                     │ │    Grafana      │ │ :3000
                     │ │ (Visualization) │ │
                     │ └─────────────────┘ │
                     │ ┌─────────────────┐ │
                     │ │  AlertManager   │ │ :9093
                     │ │   (Alerting)    │ │
                     │ └─────────────────┘ │
                     │ ┌─────────────────┐ │
                     │ │ Node Exporter   │ │ :9101
                     │ │ (Host Metrics)  │ │
                     │ └─────────────────┘ │
                     └─────────────────────┘
```

## 📁 Structure des Fichiers

```
FiveM-XDP-Filter/
├── deploy.sh                          # Script de déploiement principal
├── docker-compose.yml                 # Déploiement complet
├── QUICK_START.md                     # Guide de démarrage rapide
├── DEPLOYMENT_SOLUTION.md            # Ce document
│
├── docker/                           # Conteneurs Docker
│   ├── xdp-manager/                  # Gestionnaire de filtres XDP
│   │   ├── Dockerfile
│   │   └── entrypoint.sh
│   ├── metrics-exporter/             # Exportateur de métriques
│   │   ├── Dockerfile
│   │   ├── exporter.py
│   │   ├── requirements.txt
│   │   └── entrypoint.sh
│   ├── monitoring/                   # Stack de surveillance
│   │   ├── docker-compose.yml
│   │   ├── prometheus/
│   │   │   ├── prometheus.yml
│   │   │   └── rules/
│   │   │       └── fivem-xdp-alerts.yml
│   │   ├── grafana/
│   │   │   ├── provisioning/
│   │   │   └── dashboards/
│   │   │       └── fivem-xdp-overview.json
│   │   └── alertmanager/
│   │       └── alertmanager.yml
│   └── README.md                     # Documentation Docker
│
├── config/                           # Configuration et exemples
│   └── examples/
│       └── multi-server-setup.sh    # Exemple multi-serveurs
│
├── fivem_xdp.c                      # Code source du filtre XDP
├── fivem_xdp_config.c               # Outil de configuration
├── Makefile                         # Build system
└── xdp_docs/                        # Documentation technique
```

## 🚀 Déploiement en 3 Étapes

### 1. Déploiement Simple (1 serveur)
```bash
sudo ./deploy.sh deploy -s 192.168.1.100 -n main-server
```

### 2. Déploiement Multi-Serveurs
```bash
sudo config/examples/multi-server-setup.sh
```

### 3. Déploiement avec Docker Compose
```bash
docker compose up -d
```

## 📊 Métriques et Surveillance

### Métriques Collectées
- **Trafic réseau** : Paquets passés/rejetés/limités par seconde
- **Performance** : Temps de traitement moyen en nanosecondes
- **Sécurité** : Attaques détectées, violations de protocole
- **Système** : CPU, mémoire, réseau de l'hôte
- **Conteneurs** : Métriques des conteneurs Docker

### Dashboards Grafana
1. **Vue d'ensemble** : Métriques globales de tous les serveurs
2. **Détails par serveur** : Métriques spécifiques à chaque serveur
3. **Sécurité** : Événements de sécurité et attaques
4. **Performance** : Optimisation et tuning

### Alertes Configurées
- **Filtre XDP inactif** : Alerte critique immédiate
- **Attaques détectées** : Notification de sécurité
- **Performance dégradée** : Avertissement de performance
- **Taux de rejet élevé** : Possible attaque DDoS
- **Système surchargé** : CPU/mémoire élevés

## 🔧 Configuration Avancée

### Tailles de Serveur
| Taille | Joueurs | Rate Limit | CPU | Mémoire |
|--------|---------|------------|-----|---------|
| small  | ≤ 32    | 1000 pps   | 1 core | 512MB |
| medium | 32-128  | 5000 pps   | 2 cores | 1GB |
| large  | 128+    | 10000 pps  | 4 cores | 2GB |

### Variables d'Environnement
```bash
# Configuration Grafana
export GRAFANA_ADMIN_PASSWORD="mot-de-passe-fort"

# Configuration des alertes
export ALERT_EMAIL="admin@votre-domaine.com"
export SLACK_WEBHOOK="https://hooks.slack.com/..."
```

## 🔒 Sécurité

### Isolation des Conteneurs
- Chaque serveur FiveM a son propre filtre XDP isolé
- Conteneurs avec privilèges minimaux nécessaires
- Réseau Docker séparé pour la surveillance

### Monitoring de Sécurité
- Détection d'attaques en temps réel
- Logs d'audit complets
- Alertes automatiques sur incidents

## 🚨 Dépannage

### Commandes de Diagnostic
```bash
# État général
sudo ./deploy.sh status

# Logs des services
docker logs fivem-xdp-<nom-serveur>
docker logs fivem-metrics-<nom-serveur>

# Statistiques BPF
sudo make stats
sudo bpftool prog list
sudo bpftool map list

# Test des métriques
curl http://localhost:9100/metrics
```

### Problèmes Courants
1. **Filtre ne se charge pas** → Vérifier support XDP du kernel
2. **Pas de métriques** → Vérifier l'exportateur de métriques
3. **Grafana inaccessible** → Redémarrer le conteneur Grafana
4. **Alertes non reçues** → Vérifier la configuration AlertManager

## 📈 Avantages de cette Solution

### ✅ Simplicité
- **Déploiement en 1 commande** pour la plupart des cas
- **Configuration automatique** selon la taille du serveur
- **Gestion centralisée** via Grafana

### ✅ Scalabilité
- **Support multi-serveurs** natif
- **Ajout/suppression** de serveurs à chaud
- **Monitoring centralisé** de tous les serveurs

### ✅ Robustesse
- **Conteneurs avec restart automatique**
- **Surveillance continue** des services
- **Alertes proactives** sur les problèmes

### ✅ Observabilité
- **Métriques détaillées** en temps réel
- **Dashboards visuels** intuitifs
- **Historique complet** des événements

## 🎯 Cas d'Usage

### Hébergeur de Serveurs FiveM
- Déploiement automatisé pour tous les clients
- Surveillance centralisée de tous les serveurs
- Alertes proactives sur les attaques

### Serveur FiveM Unique
- Protection DDoS avancée
- Monitoring des performances
- Alertes sur les incidents

### Environnement de Développement
- Test des configurations de sécurité
- Validation des performances
- Debugging des problèmes réseau

## 🔄 Maintenance

### Mises à Jour
```bash
# Mettre à jour tous les services
sudo ./deploy.sh update

# Redéployer un serveur spécifique
sudo ./deploy.sh deploy -n <nom-serveur> --force
```

### Sauvegarde
```bash
# Sauvegarder les données Grafana
docker run --rm -v fivem-grafana-data:/data -v $(pwd):/backup alpine tar czf /backup/grafana-backup.tar.gz -C /data .

# Sauvegarder les données Prometheus
docker run --rm -v fivem-prometheus-data:/data -v $(pwd):/backup alpine tar czf /backup/prometheus-backup.tar.gz -C /data .
```

## 📞 Support

Cette solution est conçue pour être autonome et facile à utiliser. En cas de problème :

1. Consultez les logs des conteneurs
2. Vérifiez les métriques dans Grafana
3. Utilisez les commandes de diagnostic
4. Consultez la documentation technique dans `xdp_docs/`

---

**🎉 Félicitations !** Vous disposez maintenant d'une solution complète de protection et surveillance pour vos serveurs FiveM !
