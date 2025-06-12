# 🚀 FiveM XDP Filter - Déploiement Automatisé

Cette solution fournit un déploiement automatisé complet pour les filtres XDP FiveM avec surveillance en temps réel via Grafana.

## 🎯 Fonctionnalités

- **Déploiement automatisé** : Un script unique pour déployer des filtres XDP sur plusieurs serveurs
- **Surveillance complète** : Stack Prometheus + Grafana + AlertManager
- **Containerisation** : Tous les services de surveillance sont containerisés
- **Tableaux de bord** : Dashboards Grafana pré-configurés pour la visualisation
- **Alertes intelligentes** : Système d'alertes automatiques pour les attaques et problèmes
- **Multi-serveurs** : Support pour la protection de plusieurs serveurs FiveM

## 📋 Prérequis

- **Système d'exploitation** : Linux avec support XDP (Ubuntu 20.04+ recommandé)
- **Privilèges** : Accès root requis
- **Docker** : Version 20.10+
- **Docker Compose** : Version 2.0+ (syntaxe moderne `docker compose`)
- **Kernel Linux** : Version 4.18+ avec support XDP/eBPF
- **Outils BPF** : bpftool, clang, gcc

## 🛠️ Installation Rapide

### 1. Cloner le projet
```bash
git clone <votre-repo>
cd FiveM-XDP-Filter
```

### 2. Déployer un serveur avec surveillance
```bash
# Déploiement complet (filtre + surveillance)
sudo ./deploy.sh deploy -s 192.168.1.100 -n main-server

# Déploiement pour un gros serveur
sudo ./deploy.sh deploy -s 10.0.0.50 -z large -n big-server -i ens3
```

### 3. Accéder aux interfaces
- **Grafana** : http://localhost:3000 (admin/admin123)
- **Prometheus** : http://localhost:9090
- **AlertManager** : http://localhost:9093

## 📊 Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   FiveM Server  │    │   FiveM Server  │    │   FiveM Server  │
│                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │ XDP Filter  │ │    │ │ XDP Filter  │ │    │ │ XDP Filter  │ │
│ │ (Container) │ │    │ │ (Container) │ │    │ │ (Container) │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │  Metrics    │ │    │ │  Metrics    │ │    │ │  Metrics    │ │
│ │  Exporter   │ │    │ │  Exporter   │ │    │ │  Exporter   │ │
│ └─────────────┘ │    │ └─────────────┘ │    │ └─────────────┘ │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │   Monitoring    │
                    │     Stack       │
                    │                 │
                    │ ┌─────────────┐ │
                    │ │ Prometheus  │ │
                    │ └─────────────┘ │
                    │ ┌─────────────┐ │
                    │ │   Grafana   │ │
                    │ └─────────────┘ │
                    │ ┌─────────────┐ │
                    │ │AlertManager │ │
                    │ └─────────────┘ │
                    └─────────────────┘
```

## 🔧 Utilisation Détaillée

### Commandes Principales

```bash
# Déployer un nouveau serveur
sudo ./deploy.sh deploy -s <IP_SERVEUR> [OPTIONS]

# Déployer uniquement la surveillance
sudo ./deploy.sh monitoring

# Lister les serveurs déployés
sudo ./deploy.sh list

# Afficher l'état des services
sudo ./deploy.sh status

# Supprimer un serveur
sudo ./deploy.sh remove -n <NOM_SERVEUR>
```

### Options Disponibles

| Option | Description | Défaut |
|--------|-------------|---------|
| `-s, --server-ip` | Adresse IP du serveur FiveM | Requis |
| `-i, --interface` | Interface réseau | eth0 |
| `-z, --size` | Taille du serveur (small/medium/large) | medium |
| `-n, --name` | Nom du serveur | auto-généré |
| `-p, --port` | Port du serveur FiveM | 30120 |
| `--no-monitoring` | Ne pas déployer la surveillance | false |
| `--force` | Forcer le déploiement | false |

### Exemples d'Utilisation

```bash
# Serveur principal avec surveillance complète
sudo ./deploy.sh deploy -s 192.168.1.100 -n main-server -z large

# Serveur de test sans surveillance
sudo ./deploy.sh deploy -s 10.0.0.10 -n test-server -z small --no-monitoring

# Déploiement sur interface spécifique
sudo ./deploy.sh deploy -s 172.16.1.50 -i ens3 -n server-2

# Forcer le redéploiement d'un serveur existant
sudo ./deploy.sh deploy -s 192.168.1.100 -n main-server --force
```

## 📈 Surveillance et Métriques

### Métriques Collectées

- **Paquets traités** : Taux de paquets passés/rejetés/limités
- **Performance** : Temps de traitement, latence
- **Sécurité** : Attaques détectées, violations de protocole
- **Système** : CPU, mémoire, réseau de l'hôte

### Dashboards Grafana

1. **Vue d'ensemble** : Statistiques globales de tous les serveurs
2. **Détails par serveur** : Métriques spécifiques à chaque serveur
3. **Sécurité** : Alertes et événements de sécurité
4. **Performance** : Métriques de performance et optimisation

### Alertes Configurées

- **Filtre inactif** : Alerte critique si le filtre XDP s'arrête
- **Attaques détectées** : Notification immédiate des attaques
- **Performance dégradée** : Alerte si le temps de traitement augmente
- **Taux de rejet élevé** : Possible attaque DDoS

## 🔒 Sécurité

### Bonnes Pratiques

1. **Isolation** : Chaque serveur a son propre filtre XDP
2. **Privilèges minimaux** : Les conteneurs n'ont que les privilèges nécessaires
3. **Surveillance** : Monitoring continu des métriques de sécurité
4. **Alertes** : Notifications automatiques des incidents

### Configuration Sécurisée

```bash
# Changer le mot de passe Grafana par défaut
export GRAFANA_ADMIN_PASSWORD="votre-mot-de-passe-fort"
sudo ./deploy.sh monitoring

# Configurer les alertes email
# Éditer docker/monitoring/alertmanager/alertmanager.yml
```

## 🚨 Dépannage

### Problèmes Courants

1. **Filtre XDP ne se charge pas**
   ```bash
   # Vérifier le support XDP
   sudo bpftool prog list
   
   # Vérifier les logs
   docker logs fivem-xdp-<nom-serveur>
   ```

2. **Métriques non disponibles**
   ```bash
   # Vérifier l'exportateur
   curl http://localhost:9100/metrics
   
   # Vérifier les logs
   docker logs fivem-metrics-<nom-serveur>
   ```

3. **Grafana inaccessible**
   ```bash
   # Vérifier les services
   docker ps | grep grafana

   # Redémarrer si nécessaire
   cd docker/monitoring && docker compose restart grafana
   ```

### Logs et Diagnostic

```bash
# Logs du filtre XDP
docker logs fivem-xdp-<nom-serveur>

# Logs de l'exportateur de métriques
docker logs fivem-metrics-<nom-serveur>

# Statistiques en temps réel
sudo make stats

# État des programmes BPF
sudo bpftool prog list
sudo bpftool map list
```

## 🔄 Mise à Jour

```bash
# Mettre à jour les images Docker
sudo ./deploy.sh update

# Redéployer un serveur spécifique
sudo ./deploy.sh deploy -n <nom-serveur> --force
```

## 📞 Support

Pour obtenir de l'aide :

1. Vérifiez les logs des conteneurs
2. Consultez la documentation dans `xdp_docs/`
3. Vérifiez les issues GitHub
4. Contactez l'équipe de support

## 📄 Licence

Ce projet est sous licence MIT. Voir le fichier LICENSE pour plus de détails.
