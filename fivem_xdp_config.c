/*
 * Assistant de configuration du filtre XDP FiveM
 *
 * Ce fichier fournit des utilitaires pour configurer le filtre XDP FiveM
 * avec les bons paramètres serveur, en adressant les problèmes critiques de conformité.
 *
 * CORRECTIONS CRITIQUES IMPLÉMENTÉES :
 * 1. IP serveur configurable (plus d'IP localhost codée en dur)
 * 2. Limites de débit configurables selon la taille du serveur
 * 3. Validation de checksum optionnelle pour l'optimisation des performances
 * 4. Configuration flexible des ports pour les environnements multi-serveurs
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <arpa/inet.h>
#include <linux/bpf.h>
#include <bpf/bpf.h>
#include <bpf/libbpf.h>

// Structure de configuration serveur (doit correspondre à celle de fivem_xdp.c)
struct server_config {
    __u32 server_ip;                    // IP du serveur cible (configurable)
    __u16 server_port;                  // Port principal du serveur FiveM
    __u16 game_port1;                   // Port de communication interne du jeu
    __u16 game_port2;                   // Port alternatif de communication du jeu
    __u32 rate_limit;                   // Paquets par seconde par IP
    __u32 global_rate_limit;            // Limite globale de paquets par seconde
    __u32 subnet_rate_limit;            // Limite de paquets par seconde par sous-réseau (/24)
    __u8 enable_checksum_validation;    // Activer/désactiver la validation CRC32
    __u8 strict_enet_validation;        // Activer la validation stricte de l'en-tête ENet
    __u8 reserved[3];                   // Remplissage pour usage futur
};

// Configurations prédéfinies pour différents types de serveurs
struct server_config get_small_server_config(const char* server_ip_str) {
    struct server_config config = {0};
    
    // Conversion de l'IP en format réseau
    inet_pton(AF_INET, server_ip_str, &config.server_ip);
    config.server_ip = ntohl(config.server_ip); // Conversion en format hôte pour BPF
    
    // Configuration pour petit serveur (jusqu'à 32 joueurs)
    config.server_port = 30120;
    config.game_port1 = 6672;
    config.game_port2 = 6673;
    config.rate_limit = 500;                    // Limite de débit conservatrice
    config.global_rate_limit = 10000;           // Limite globale basse
    config.subnet_rate_limit = 2000;            // Limite de sous-réseau basse
    config.enable_checksum_validation = 1;      // Activé pour la sécurité
    config.strict_enet_validation = 1;          // Validation stricte activée
    
    return config;
}

struct server_config get_medium_server_config(const char* server_ip_str) {
    struct server_config config = {0};
    
    inet_pton(AF_INET, server_ip_str, &config.server_ip);
    config.server_ip = ntohl(config.server_ip);
    
    // Configuration pour serveur moyen (32-128 joueurs)
    config.server_port = 30120;
    config.game_port1 = 6672;
    config.game_port2 = 6673;
    config.rate_limit = 1000;                   // Limite de débit par défaut
    config.global_rate_limit = 50000;           // Limite globale par défaut
    config.subnet_rate_limit = 5000;            // Limite de sous-réseau par défaut
    config.enable_checksum_validation = 1;      // Activé pour la sécurité
    config.strict_enet_validation = 1;          // Validation stricte activée
    
    return config;
}

struct server_config get_large_server_config(const char* server_ip_str) {
    struct server_config config = {0};
    
    inet_pton(AF_INET, server_ip_str, &config.server_ip);
    config.server_ip = ntohl(config.server_ip);
    
    // Configuration pour grand serveur (128+ joueurs)
    config.server_port = 30120;
    config.game_port1 = 6672;
    config.game_port2 = 6673;
    config.rate_limit = 2000;                   // Limite de débit plus élevée pour serveurs chargés
    config.global_rate_limit = 100000;          // Limite globale plus élevée
    config.subnet_rate_limit = 10000;           // Limite de sous-réseau plus élevée
    config.enable_checksum_validation = 0;      // Désactivé pour la performance
    config.strict_enet_validation = 0;          // Validation relâchée pour la performance
    
    return config;
}

struct server_config get_development_config(const char* server_ip_str) {
    struct server_config config = {0};
    
    inet_pton(AF_INET, server_ip_str, &config.server_ip);
    config.server_ip = ntohl(config.server_ip);
    
    // Configuration pour développement (permissive pour les tests)
    config.server_port = 30120;
    config.game_port1 = 6672;
    config.game_port2 = 6673;
    config.rate_limit = 10000;                  // Limite de débit très élevée
    config.global_rate_limit = 1000000;         // Limite globale très élevée
    config.subnet_rate_limit = 100000;          // Limite de sous-réseau très élevée
    config.enable_checksum_validation = 0;      // Désactivé pour le développement
    config.strict_enet_validation = 0;          // Désactivé pour le développement
    
    return config;
}

// Fonction pour configurer le filtre XDP
int configure_fivem_xdp(const char* bpf_map_path, struct server_config* config) {
    int map_fd;
    __u32 key = 0;
    int ret;
    
    // Ouvrir la carte de configuration du serveur
    map_fd = bpf_obj_get(bpf_map_path);
    if (map_fd < 0) {
        fprintf(stderr, "Échec de l'ouverture de la carte BPF : %s\n", strerror(errno));
        return -1;
    }
    
    // Mettre à jour la configuration
    ret = bpf_map_update_elem(map_fd, &key, config, BPF_ANY);
    if (ret < 0) {
        fprintf(stderr, "Échec de la mise à jour de la carte BPF : %s\n", strerror(errno));
        close(map_fd);
        return -1;
    }
    
    close(map_fd);
    
    printf("Filtre XDP FiveM configuré avec succès :\n");
    printf("  IP du serveur : %s\n", inet_ntoa((struct in_addr){htonl(config->server_ip)}));
    printf("  Port du serveur : %u\n", config->server_port);
    printf("  Ports du jeu : %u, %u\n", config->game_port1, config->game_port2);
    printf("  Limites de débit : IP=%u, Sous-réseau=%u, Global=%u\n", 
           config->rate_limit, config->subnet_rate_limit, config->global_rate_limit);
    printf("  Validation de checksum : %s\n", config->enable_checksum_validation ? "Activée" : "Désactivée");
    printf("  Validation stricte ENet : %s\n", config->strict_enet_validation ? "Activée" : "Désactivée");
    
    return 0;
}

// Fonction d'utilisation exemple
void print_usage(const char* program_name) {
    printf("Utilisation : %s <server_ip> <config_type> [bpf_map_path]\n", program_name);
    printf("Types de configuration :\n");
    printf("  small  - Petit serveur (jusqu'à 32 joueurs)\n");
    printf("  medium - Serveur moyen (32-128 joueurs)\n");
    printf("  large  - Grand serveur (128+ joueurs)\n");
    printf("  dev    - Serveur de développement (permissif)\n");
    printf("\nExemple :\n");
    printf("  %s 192.168.1.100 medium /sys/fs/bpf/server_config_map\n", program_name);
}

int main(int argc, char* argv[]) {
    if (argc < 3) {
        print_usage(argv[0]);
        return 1;
    }
    
    const char* server_ip = argv[1];
    const char* config_type = argv[2];
    const char* map_path = argc > 3 ? argv[3] : "/sys/fs/bpf/server_config_map";
    
    struct server_config config;
    
    // Sélectionner la configuration en fonction du type
    if (strcmp(config_type, "small") == 0) {
        config = get_small_server_config(server_ip);
    } else if (strcmp(config_type, "medium") == 0) {
        config = get_medium_server_config(server_ip);
    } else if (strcmp(config_type, "large") == 0) {
        config = get_large_server_config(server_ip);
    } else if (strcmp(config_type, "dev") == 0) {
        config = get_development_config(server_ip);
    } else {
        fprintf(stderr, "Type de configuration inconnu : %s\n", config_type);
        print_usage(argv[0]);
        return 1;
    }
    
    // Configurer le filtre XDP
    if (configure_fivem_xdp(map_path, &config) < 0) {
        return 1;
    }
    
    return 0;
}
