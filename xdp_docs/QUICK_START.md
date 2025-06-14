# 🚀 Guide de Démarrage Rapide - FiveM XDP Filter (Debian 12)

Ce guide vous permet de déployer rapidement un filtre XDP pour votre serveur FiveM avec surveillance complète en moins de 5 minutes sur **Debian 12 exclusivement**.

## ⚡ Installation Ultra-Rapide (1 commande)

```bash
# Remplacez 192.168.1.100 par l'IP de votre serveur FiveM
sudo ./install.sh -s 192.168.1.100
```

**C'est tout !** Votre serveur est maintenant protégé et surveillé avec installation complète automatisée.

## 🎯 Accès aux Interfaces

Après l'installation, accédez à :

- **📊 Grafana** : http://localhost:3000
  - Utilisateur : `admin`
  - Mot de passe : `admin123`

- **🔍 Prometheus** : http://localhost:9090
- **🚨 AlertManager** : http://localhost:9093
- **📈 Métriques** : http://localhost:9100/metrics

## 📋 Prérequis (Vérification Automatique)

Le script `install.sh` vérifie et installe automatiquement sur **Debian 12** :
- Validation de la distribution (Debian 12 uniquement)
- Docker & Docker Compose (installation automatique)
- Outils BPF optimisés pour Debian 12 (bpftool, clang, libbpf-dev)
- Support XDP du kernel avec validation complète

## 🛠️ Exemples d'Installation

### Installation Basique (Recommandée)
```bash
# Installation complète avec monitoring
sudo ./install.sh -s 192.168.1.100
```

### Serveur Principal (Production)
```bash
# Installation optimisée pour gros serveur
sudo ./install.sh -s 192.168.1.100 -z large -n main-server -i eth0
```

### Serveur de Test
```bash
# Installation légère pour tests
sudo ./install.sh -s 10.0.0.50 -z small -n test-server
```

### Serveur de Développement
```bash
# Installation sans monitoring pour développement
sudo ./install.sh -s 127.0.0.1 -z dev --no-monitoring
```

### Installation avec Interface Spécifique
```bash
# Pour serveurs avec interfaces réseau personnalisées
sudo ./install.sh -s 172.16.1.10 -i ens18 -n server-2
```

## 📊 Que Surveiller dans Grafana

### Dashboard Principal : "FiveM XDP Filter - Vue d'ensemble"

1. **État des Filtres** : Vérifiez que tous vos filtres sont actifs (vert)
2. **Taux de Paquets** : Surveillez le trafic entrant/sortant
3. **Temps de Traitement** : Performance du filtre (doit être < 10µs)
4. **Attaques Détectées** : Alertes de sécurité en temps réel

### Métriques Importantes

- **Paquets Passés** : Trafic légitime autorisé
- **Paquets Rejetés** : Trafic malveillant bloqué
- **Rate Limiting** : Limitation de débit activée
- **Violations de Protocole** : Tentatives d'exploitation

## 🚨 Alertes Automatiques

Le système vous alertera automatiquement pour :

- ❌ **Filtre XDP inactif** (critique)
- 🛡️ **Attaques détectées** (sécurité)
- ⚡ **Performance dégradée** (avertissement)
- 📈 **Taux de rejet élevé** (possible DDoS)

## 🔧 Commandes Utiles

### Vérifier l'État
```bash
# État des services
sudo ./deploy.sh status

# Statistiques en temps réel
sudo make stats

# Logs du filtre
docker logs fivem-xdp-mon-serveur
```

### Gestion des Serveurs
```bash
# Lister les serveurs
sudo ./deploy.sh list

# Supprimer un serveur
sudo ./deploy.sh remove -n mon-serveur

# Mettre à jour
sudo ./deploy.sh update
```

## 🎛️ Configuration Avancée

### Tailles de Serveur

| Taille | Joueurs | Rate Limit | Usage |
|--------|---------|------------|-------|
| `small` | ≤ 32 | Conservateur | Test/Dev |
| `medium` | 32-128 | Équilibré | Production |
| `large` | 128+ | Agressif | Gros serveurs |

### Personnalisation

```bash
# Port personnalisé
sudo ./deploy.sh deploy -s 192.168.1.100 -p 30121

# Sans surveillance (filtre uniquement)
sudo ./deploy.sh deploy -s 192.168.1.100 --no-monitoring

# Forcer le redéploiement
sudo ./deploy.sh deploy -s 192.168.1.100 --force
```

## 🔒 Sécurité

### Changement du Mot de Passe Grafana
```bash
export GRAFANA_ADMIN_PASSWORD="votre-mot-de-passe-fort"
sudo ./deploy.sh monitoring
```

### Configuration des Alertes Email
Éditez `docker/monitoring/alertmanager/alertmanager.yml` :
```yaml
global:
  smtp_smarthost: 'votre-smtp:587'
  smtp_from: 'alerts@votre-domaine.com'
```

## 🚨 Dépannage Rapide

### Problème : Filtre ne se charge pas
```bash
# Vérifier le support XDP
sudo bpftool prog list

# Vérifier les logs
docker logs fivem-xdp-mon-serveur
```

### Problème : Grafana inaccessible
```bash
# Redémarrer Grafana
cd docker/monitoring
docker compose restart grafana
```

### Problème : Pas de métriques
```bash
# Tester l'exportateur
curl http://localhost:9100/metrics

# Vérifier les logs
docker logs fivem-metrics-mon-serveur
```

## 📞 Support Rapide

1. **Logs** : `docker logs <nom-conteneur>`
2. **État BPF** : `sudo bpftool prog list`
3. **Statistiques** : `sudo make stats`
4. **Redémarrage** : `sudo ./deploy.sh deploy --force`

## 🎉 Félicitations !

Votre serveur FiveM est maintenant protégé par un filtre XDP avancé avec surveillance complète !

**Prochaines étapes :**
1. Explorez les dashboards Grafana
2. Configurez les alertes email
3. Ajoutez d'autres serveurs si nécessaire
4. Surveillez les métriques de performance

---

**💡 Astuce :** Ajoutez cette page aux favoris pour un accès rapide aux commandes essentielles !
