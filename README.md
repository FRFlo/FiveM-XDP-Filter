# 🛡️ FiveM XDP Filter - Protection DDoS Avancée

Ce système de filtrage XDP protège les serveurs FiveM contre les attaques DDoS et le trafic malveillant. Il inclut un déploiement automatisé avec surveillance en temps réel via Grafana.

## 🚀 Démarrage Rapide

**Déploiement en une commande :**
```bash
sudo ./deploy.sh deploy -s 192.168.1.100 -n mon-serveur
```

**Accès aux interfaces :**
- 📊 **Grafana** : http://localhost:3000 (admin/admin123)
- 🔍 **Prometheus** : http://localhost:9090
- 🚨 **AlertManager** : http://localhost:9093

## 📋 Prérequis

- **OS :** Linux avec support XDP (Ubuntu 20.04+ recommandé)
- **Kernel :** Version 4.18+ avec support XDP/eBPF
- **Docker :** Version 20.10+
- **Docker Compose :** Version 2.0+ (syntaxe moderne)
- **Privilèges :** Accès root requis
- **Outils :** clang, gcc, bpftool (installés automatiquement)

## 🎯 Fonctionnalités

- ✅ **Protection DDoS avancée** avec filtrage XDP haute performance
- ✅ **Déploiement automatisé** pour multiple serveurs FiveM
- ✅ **Surveillance complète** avec Prometheus + Grafana
- ✅ **Alertes intelligentes** via AlertManager
- ✅ **Configuration flexible** (small/medium/large servers)
- ✅ **Containerisation complète** pour faciliter la gestion

## 📖 Documentation Complète

- 🚀 **[Guide de Démarrage Rapide](QUICK_START.md)** - Déploiement en 5 minutes
- 🐳 **[Documentation Docker](docker/README.md)** - Containerisation et monitoring
- 📊 **[Solution de Déploiement](DEPLOYMENT_SOLUTION.md)** - Architecture complète
- 📋 **[Rapport de Validation](VALIDATION_REPORT.md)** - Tests et validation
- 📚 **[Documentation Technique](xdp_docs/README.md)** - Détails techniques

## 🛠️ Installation Manuelle (Avancée)

Si vous préférez une installation manuelle sans Docker :

### Étape 1 : Compilation
```bash
# Compiler le filtre XDP et les outils
make all
```

### Étape 2 : Installation
```bash
# Installer le filtre sur l'interface réseau
sudo make install INTERFACE=eth0
```

### Étape 3 : Configuration
```bash
# Configurer pour votre serveur (remplacez l'IP)
make config-medium SERVER_IP=192.168.1.100
```

### Étape 4 : Vérification
```bash
# Vérifier le fonctionnement
make stats
```

### Step 3: Load the XDP Program

Load the compiled XDP program into the network interface that your FiveM server uses. Replace `<interface>` with the name of your network interface (e.g., `eth0`):

```bash 
ip link set dev <interface> xdp obj xdp_program.o sec xdp_program
```

### Step 4: Verify the XDP Program

Test the XDP program by generating traffic to your FiveM server on the configured port (default: 30120). Ensure that non-FiveM traffic is being dropped and legitimate FiveM traffic is allowed to pass through.

You can use packet-capturing tools like tcpdump to verify traffic behavior:

```bash
tcpdump -i <interface>
```

### Step 5: Monitor Packet Counts

The program includes logging for tracking how many packets are dropped or passed. Use bpftool to check the statistics:

```bash
bpftool map dump name packet_count_map
```

## Unloading the XDP Program

If you need to unload the XDP program from the interface, run the following command:

```bash
ip link set dev <interface> xdp off
```

## License

This XDP program is released under the MIT license. See the LICENSE file for more information.
