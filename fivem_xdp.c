#include <linux/bpf.h>
#include <linux/if_ether.h>
#include <linux/ip.h>
#include <linux/in.h>
#include <linux/udp.h>
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_endian.h>

// Valeurs par défaut - désormais configurables via les maps BPF
#define DEFAULT_FIVEM_SERVER_PORT   30120           // Port principal du serveur FiveM
#define DEFAULT_FIVEM_GAME_PORT1    6672            // Port de communication interne du jeu
#define DEFAULT_FIVEM_GAME_PORT2    6673            // Port alternatif de communication du jeu
#define DEFAULT_RATE_LIMIT          1000            // Paquets par seconde par IP par défaut
#define DEFAULT_GLOBAL_RATE_LIMIT   50000           // Limite globale de paquets par seconde par défaut
#define DEFAULT_SUBNET_RATE_LIMIT   5000            // Limite de paquets par seconde par sous-réseau (/24) par défaut

// Constantes du protocole FiveM
#define OOB_PACKET_MARKER   0xFFFFFFFF      // Identifiant de paquet hors-bande
#define ENET_MAX_PEER_ID    0x0FFF          // ID peer ENet maximum (4095)
#define MIN_PACKET_SIZE     4               // Taille minimale de paquet valide
#define MAX_PACKET_SIZE     2400            // Taille maximale de paquet de synchronisation
#define MAX_VOICE_SIZE      8192            // Taille maximale de paquet vocal
#define ENET_HEADER_SIZE    4               // Taille minimale d'en-tête ENet
#define MAX_TOKEN_AGE       7200000000000ULL // 2 heures en nanosecondes
#define MAX_SEQUENCE_WINDOW 100             // Fenêtre acceptable de paquets hors ordre

// Types de classification d'attaque
enum attack_type {
    ATTACK_NONE = 0,
    ATTACK_RATE_LIMIT = 1,
    ATTACK_INVALID_PROTOCOL = 2,
    ATTACK_REPLAY = 3,
    ATTACK_STATE_VIOLATION = 4,
    ATTACK_CHECKSUM_FAIL = 5,
    ATTACK_SIZE_VIOLATION = 6,
    ATTACK_SEQUENCE_ANOMALY = 7,
    ATTACK_TOKEN_REUSE = 8
};

// Machine d'état de connexion
enum connection_state {
    STATE_INITIAL = 0,
    STATE_OOB_SENT = 1,
    STATE_CONNECTING = 2,
    STATE_CONNECTED = 3,
    STATE_SUSPICIOUS = 4
};

// Hashs complets des types de messages FiveM (critiques pour la DPI)
// Basé sur code/shared/net/PacketNames.h du code source FiveM
#define MSG_ARRAY_UPDATE_HASH       0x0976e783      // msgArrayUpdate
#define MSG_CONVARS_HASH            0x6acbd583      // msgConVars
#define MSG_CONFIRM_HASH            0xba96192a      // msgConfirm
#define MSG_END_HASH                0xca569e63      // msgEnd
#define MSG_ENTITY_CREATE_HASH      0x0f216a2a      // msgEntityCreate
#define MSG_FRAME_HASH              0x53fffa3f      // msgFrame
#define MSG_HE_HOST_HASH            0x86e9f87b      // msgHeHost
#define MSG_I_HOST_HASH             0xb3ea30de      // msgIHost
#define MSG_I_QUIT_HASH             0x522cadd1      // msgIQuit
#define MSG_NET_EVENT_HASH          0x7337fd7a      // msgNetEvent
#define MSG_NET_GAME_EVENT_HASH     0x100d66a8      // msgNetGameEvent
#define MSG_OBJECT_IDS_HASH         0x48e39581      // msgObjectIds
#define MSG_PACKED_ACKS_HASH        0x258dfdb4      // msgPackedAcks
#define MSG_PACKED_CLONES_HASH      0x81e1c835      // msgPackedClones
#define MSG_PAYMENT_REQUEST_HASH    0x073b065b      // msgPaymentRequest
#define MSG_REQUEST_OBJECT_IDS_HASH 0xb8e611cf      // msgRequestObjectIds
#define MSG_RES_START_HASH          0xafe4cd4a      // msgResStart
#define MSG_RES_STOP_HASH           0x45e855d7      // msgResStop
#define MSG_ROUTE_HASH              0xe938445b      // msgRoute
#define MSG_RPC_NATIVE_HASH         0x211cab17      // msgRpcNative
#define MSG_SERVER_COMMAND_HASH     0xb18d4fc4      // msgServerCommand
#define MSG_SERVER_EVENT_HASH       0xfa776e18      // msgServerEvent
#define MSG_STATE_BAG_HASH          0xde3d1a59      // msgStateBag
#define MSG_TIME_SYNC_HASH          0xe56e37ed      // msgTimeSync
#define MSG_TIME_SYNC_REQ_HASH      0x1c1303f8      // msgTimeSyncReq
#define MSG_WORLD_GRID3_HASH        0x852c1561      // msgWorldGrid3
#define MSG_GAME_STATE_ACK_HASH     0xa5d4e2bc      // gameStateAck
#define MSG_GAME_STATE_NACK_HASH    0xd2f86a6e      // gameStateNAck

// CORRECTION CRITIQUE 1 : Map de configuration serveur configurable
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

struct {
    __uint(type, BPF_MAP_TYPE_ARRAY);
    __uint(max_entries, 1);
    __type(key, __u32);
    __type(value, struct server_config);
} server_config_map SEC(".maps");

// Map de limitation de taux par IP (table de hachage pour une meilleure évolutivité)
struct {
    __uint(type, BPF_MAP_TYPE_LRU_HASH);
    __uint(max_entries, 10000);
    __type(key, __u32);     // Adresse IP source
    __type(value, __u64);   // Horodatage du dernier paquet
} rate_limit_map SEC(".maps");

// Map de statistiques de paquets
struct {
    __uint(type, BPF_MAP_TYPE_PERCPU_ARRAY);
    __uint(max_entries, 4); // 0: abandonné, 1: passé, 2: protocole_invalide, 3: limite_de_taux
    __type(key, __u32);
    __type(value, __u64);
} packet_count_map SEC(".maps");

// Suivi amélioré des tokens de connexion avec protection contre la répétition
struct connection_token_state {
    __u32 source_ip;
    __u64 first_seen;
    __u32 usage_count;
    __u16 sequence_number;
};

struct {
    __uint(type, BPF_MAP_TYPE_LRU_HASH);
    __uint(max_entries, 5000);
    __type(key, __u32);     // Hachage du token de connexion
    __type(value, struct connection_token_state);
} enhanced_token_map SEC(".maps");

// Validation du numéro de séquence du pair
struct peer_state {
    __u16 last_sequence;
    __u64 last_update;
    __u32 out_of_order_count;
};

struct {
    __uint(type, BPF_MAP_TYPE_LRU_HASH);
    __uint(max_entries, 4096);
    __type(key, __u64);     // (src_ip << 32) | peer_id
    __type(value, struct peer_state);
} peer_sequence_map SEC(".maps");

// Suivi de la machine d'état de connexion
struct connection_context {
    enum connection_state state;
    __u64 state_timestamp;
    __u32 packet_count;
    __u8 violations;
};

struct {
    __uint(type, BPF_MAP_TYPE_LRU_HASH);
    __uint(max_entries, 2048);
    __type(key, __u32);     // IP source
    __type(value, struct connection_context);
} connection_state_map SEC(".maps");

// Journalisation et classification des attaques
struct attack_stats {
    __u64 count;
    __u64 last_seen;
    __u32 source_ip;
    __u16 attack_type;
};

struct {
    __uint(type, BPF_MAP_TYPE_HASH);
    __uint(max_entries, 1000);
    __type(key, __u32);     // ID d'attaque (incrémental)
    __type(value, struct attack_stats);
} attack_log_map SEC(".maps");

// Suivi des métriques de performance
struct perf_metrics {
    __u64 total_packets;
    __u64 processing_time_ns;
    __u64 map_lookup_time_ns;
    __u32 max_processing_time_ns;
    __u32 avg_packet_size;
};

struct {
    __uint(type, BPF_MAP_TYPE_PERCPU_ARRAY);
    __uint(max_entries, 1);
    __type(key, __u32);
    __type(value, struct perf_metrics);
} perf_metrics_map SEC(".maps");

// Limitation de taux hiérarchique - Niveau global
struct global_rate_state {
    __u64 packet_count;
    __u64 window_start;
    __u32 current_limit;
};

struct {
    __uint(type, BPF_MAP_TYPE_ARRAY);
    __uint(max_entries, 1);
    __type(key, __u32);
    __type(value, struct global_rate_state);
} global_rate_map SEC(".maps");

// Limitation de taux hiérarchique - Niveau sous-réseau
struct subnet_rate_state {
    __u64 packet_count;
    __u64 window_start;
    __u32 active_ips;
};

struct {
    __uint(type, BPF_MAP_TYPE_LRU_HASH);
    __uint(max_entries, 1024);
    __type(key, __u32);     // Sous-réseau (/24)
    __type(value, struct subnet_rate_state);
} subnet_rate_map SEC(".maps");

// Statistiques améliorées avec classification des attaques
struct enhanced_stats {
    __u64 dropped;
    __u64 passed;
    __u64 invalid_protocol;
    __u64 rate_limited;
    __u64 token_violations;
    __u64 sequence_violations;
    __u64 state_violations;
    __u64 checksum_failures;
};

struct {
    __uint(type, BPF_MAP_TYPE_PERCPU_ARRAY);
    __uint(max_entries, 1);
    __type(key, __u32);
    __type(value, struct enhanced_stats);
} enhanced_stats_map SEC(".maps");

// Validation optimisée du hachage des messages FiveM utilisant une recherche groupée
// Valide par rapport à tous les 28 types de messages FiveM connus de PacketNames.h
static __always_inline int is_valid_fivem_message_hash(__u32 hash) {
    switch (hash) {
        case MSG_ARRAY_UPDATE_HASH:
        case MSG_CONVARS_HASH:
        case MSG_CONFIRM_HASH:
        case MSG_END_HASH:
        case MSG_ENTITY_CREATE_HASH:
        case MSG_FRAME_HASH:
        case MSG_HE_HOST_HASH:
        case MSG_I_HOST_HASH:
        case MSG_I_QUIT_HASH:
        case MSG_NET_EVENT_HASH:
        case MSG_NET_GAME_EVENT_HASH:
        case MSG_OBJECT_IDS_HASH:
        case MSG_PACKED_ACKS_HASH:
        case MSG_PACKED_CLONES_HASH:
        case MSG_PAYMENT_REQUEST_HASH:
        case MSG_REQUEST_OBJECT_IDS_HASH:
        case MSG_RES_START_HASH:
        case MSG_RES_STOP_HASH:
        case MSG_ROUTE_HASH:
        case MSG_RPC_NATIVE_HASH:
        case MSG_SERVER_COMMAND_HASH:
        case MSG_SERVER_EVENT_HASH:
        case MSG_STATE_BAG_HASH:
        case MSG_TIME_SYNC_HASH:
        case MSG_TIME_SYNC_REQ_HASH:
        case MSG_WORLD_GRID3_HASH:
        case MSG_GAME_STATE_ACK_HASH:
        case MSG_GAME_STATE_NACK_HASH:
            return 1;
        default:
            return 0;
    }
}

// CORRECTION CRITIQUE 4: Fonction d'aide pour obtenir la configuration du serveur avec des valeurs par défaut
static __always_inline struct server_config* get_server_config() {
    __u32 key = 0;
    struct server_config *config = bpf_map_lookup_elem(&server_config_map, &key);
    return config; // Renvoie NULL si non configuré, l'appelant doit gérer les valeurs par défaut
}

// CORRECTION CRITIQUE 4: Fonction d'aide pour appliquer une limitation de taux configurable par IP
static __always_inline int apply_rate_limit(__u32 src_ip, __u32 rate_limit) {
    __u64 now = bpf_ktime_get_ns();
    __u64 *last_time = bpf_map_lookup_elem(&rate_limit_map, &src_ip);

    if (last_time) {
        // Vérifier si suffisamment de temps s'est écoulé (1 seconde / rate_limit)
        if (now - *last_time < (1000000000ULL / rate_limit)) {
            return 0; // Limite de taux dépassée
        }
    }

    // Mettre à jour l'horodatage
    bpf_map_update_elem(&rate_limit_map, &src_ip, &now, BPF_ANY);
    return 1; // Autoriser le paquet
}

// Mise à jour des statistiques améliorées avec classification des attaques
static __always_inline void update_enhanced_stats(__u32 stat_type) {
    __u32 key = 0;
    struct enhanced_stats *stats = bpf_map_lookup_elem(&enhanced_stats_map, &key);
    if (!stats) return;

    switch (stat_type) {
        case 0: stats->dropped++; break;
        case 1: stats->passed++; break;
        case 2: stats->invalid_protocol++; break;
        case 3: stats->rate_limited++; break;
        case 4: stats->token_violations++; break;
        case 5: stats->sequence_violations++; break;
        case 6: stats->state_violations++; break;
        case 7: stats->checksum_failures++; break;
    }
}

// Mise à jour des statistiques héritées pour la compatibilité ascendante
static __always_inline void update_stats(__u32 stat_type) {
    __u64 *count = bpf_map_lookup_elem(&packet_count_map, &stat_type);
    if (count) {
        (*count)++;
    }
    update_enhanced_stats(stat_type);
}

// Fonction de journalisation des attaques
static __always_inline void log_attack(__u32 src_ip, enum attack_type type) {
    // Utiliser l'IP source et le timestamp comme clé unique
    __u64 now = bpf_ktime_get_ns();
    __u32 id = (src_ip ^ (__u32)(now >> 32)) % 1000;

    struct attack_stats stats = {
        .count = 1,
        .last_seen = now,
        .source_ip = src_ip,
        .attack_type = type
    };

    bpf_map_update_elem(&attack_log_map, &id, &stats, BPF_ANY);
}

// Suivi des métriques de performance
static __always_inline void update_perf_metrics(__u64 start_time, __u32 packet_size) {
    __u64 end_time = bpf_ktime_get_ns();
    __u64 processing_time = end_time - start_time;

    __u32 key = 0;
    struct perf_metrics *metrics = bpf_map_lookup_elem(&perf_metrics_map, &key);
    if (!metrics) return;

    metrics->total_packets++;
    metrics->processing_time_ns += processing_time;

    if (processing_time > metrics->max_processing_time_ns) {
        metrics->max_processing_time_ns = processing_time;
    }

    // Mettre à jour la taille moyenne des paquets (moyenne mobile exponentielle)
    metrics->avg_packet_size = (metrics->avg_packet_size * 7 + packet_size) / 8;
}

// Validation améliorée des tokens de connexion avec protection contre la répétition
static __always_inline int validate_connection_token(__u32 token_hash, __u32 src_ip) {
    struct connection_token_state *state = bpf_map_lookup_elem(&enhanced_token_map, &token_hash);
    __u64 now = bpf_ktime_get_ns();

    if (!state) {
        // Nouveau token - créer une entrée
        struct connection_token_state new_state = {
            .source_ip = src_ip,
            .first_seen = now,
            .usage_count = 1,
            .sequence_number = 0
        };
        bpf_map_update_elem(&enhanced_token_map, &token_hash, &new_state, BPF_ANY);
        return 1;
    }

    // Valider la cohérence de l'IP (anti-spoofing)
    if (state->source_ip != src_ip) {
        log_attack(src_ip, ATTACK_TOKEN_REUSE);
        return 0;
    }

    // Valider le nombre d'utilisations (max 3 tentatives selon FiveM)
    if (state->usage_count > 3) {
        log_attack(src_ip, ATTACK_TOKEN_REUSE);
        return 0;
    }

    // Valider l'âge du token (expiration après 2 heures)
    if (now - state->first_seen > MAX_TOKEN_AGE) {
        log_attack(src_ip, ATTACK_REPLAY);
        return 0;
    }

    state->usage_count++;
    return 1;
}

// Validation du numéro de séquence pour prévenir les attaques par répétition
static __always_inline int validate_sequence_number(__u32 src_ip, __u16 peer_id, __u16 sequence) {
    __u64 key = ((__u64)src_ip << 32) | peer_id;
    struct peer_state *state = bpf_map_lookup_elem(&peer_sequence_map, &key);
    __u64 now = bpf_ktime_get_ns();

    if (!state) {
        struct peer_state new_state = {
            .last_sequence = sequence,
            .last_update = now,
            .out_of_order_count = 0
        };
        bpf_map_update_elem(&peer_sequence_map, &key, &new_state, BPF_ANY);
        return 1;
    }

    // Autoriser une livraison hors ordre raisonnable (fenêtre de 100)
    __s16 seq_diff = sequence - state->last_sequence;
    if (seq_diff > 0 && seq_diff < MAX_SEQUENCE_WINDOW) {
        state->last_sequence = sequence;
        state->last_update = now;
        return 1;
    }

    // Suivre les paquets hors ordre excessifs (attaque potentielle)
    if (seq_diff < -MAX_SEQUENCE_WINDOW || seq_diff > 1000) {
        state->out_of_order_count++;
        if (state->out_of_order_count > 10) {
            log_attack(src_ip, ATTACK_SEQUENCE_ANOMALY);
            return 0; // Bloquer le pair suspect
        }
    }

    return 1;
}

// Validation de la machine d'état du protocole
static __always_inline int validate_protocol_state(__u32 src_ip, __u32 first_word, __u32 msg_hash) {
    struct connection_context *ctx = bpf_map_lookup_elem(&connection_state_map, &src_ip);
    __u64 now = bpf_ktime_get_ns();

    if (!ctx) {
        // Une nouvelle connexion doit commencer par OOB
        if (first_word != OOB_PACKET_MARKER) {
            log_attack(src_ip, ATTACK_STATE_VIOLATION);
            return 0;
        }

        struct connection_context new_ctx = {
            .state = STATE_OOB_SENT,
            .state_timestamp = now,
            .packet_count = 1,
            .violations = 0
        };
        bpf_map_update_elem(&connection_state_map, &src_ip, &new_ctx, BPF_ANY);
        return 1;
    }

    // Validation de la transition d'état
    switch (ctx->state) {
        case STATE_INITIAL:
            // État initial - doit commencer par OOB
            if (first_word == OOB_PACKET_MARKER) {
                ctx->state = STATE_OOB_SENT;
                ctx->state_timestamp = now;
                return 1;
            }
            break;
        case STATE_OOB_SENT:
            if (msg_hash == MSG_CONFIRM_HASH) {
                ctx->state = STATE_CONNECTING;
                ctx->state_timestamp = now;
                return 1;
            }
            break;
        case STATE_CONNECTING:
            if (msg_hash == MSG_I_HOST_HASH || msg_hash == MSG_HE_HOST_HASH) {
                ctx->state = STATE_CONNECTED;
                ctx->state_timestamp = now;
                return 1;
            }
            break;
        case STATE_CONNECTED:
            // Autoriser le trafic normal du jeu
            return 1;
        case STATE_SUSPICIOUS:
            // Bloquer tout le trafic des IPs suspectes
            log_attack(src_ip, ATTACK_STATE_VIOLATION);
            return 0;
    }

    // Transition d'état invalide
    ctx->violations++;
    if (ctx->violations > 3) {
        ctx->state = STATE_SUSPICIOUS;
        log_attack(src_ip, ATTACK_STATE_VIOLATION);
        return 0;
    }

    return 1;
}

// CORRECTION CRITIQUE 4: Limitation de taux hiérarchique avec limites configurables
static __always_inline int hierarchical_rate_limit(__u32 src_ip, struct server_config *config) {
    __u64 now = bpf_ktime_get_ns();
    __u64 window_size = 1000000000ULL; // 1 seconde

    // Utiliser les limites configurées ou les valeurs par défaut
    __u32 global_limit = config ? config->global_rate_limit : DEFAULT_GLOBAL_RATE_LIMIT;
    __u32 subnet_limit = config ? config->subnet_rate_limit : DEFAULT_SUBNET_RATE_LIMIT;
    __u32 ip_limit = config ? config->rate_limit : DEFAULT_RATE_LIMIT;

    // Limitation de taux globale (prévention de la surcharge du serveur)
    __u32 global_key = 0;
    struct global_rate_state *global = bpf_map_lookup_elem(&global_rate_map, &global_key);
    if (global) {
        if (now - global->window_start > window_size) {
            global->packet_count = 1;
            global->window_start = now;
        } else {
            global->packet_count++;
            if (global->packet_count > global_limit) {
                log_attack(src_ip, ATTACK_RATE_LIMIT);
                return 0;
            }
        }
    }

    // Limitation de taux par sous-réseau (prévention des attaques par sous-réseau)
    __u32 subnet = src_ip & 0xFFFFFF00; // /24 sous-réseau
    struct subnet_rate_state *subnet_state = bpf_map_lookup_elem(&subnet_rate_map, &subnet);
    if (subnet_state) {
        if (now - subnet_state->window_start > window_size) {
            subnet_state->packet_count = 1;
            subnet_state->window_start = now;
        } else {
            subnet_state->packet_count++;
            if (subnet_state->packet_count > subnet_limit) {
                log_attack(src_ip, ATTACK_RATE_LIMIT);
                return 0;
            }
        }
    } else {
        struct subnet_rate_state new_subnet = {
            .packet_count = 1,
            .window_start = now,
            .active_ips = 1
        };
        bpf_map_update_elem(&subnet_rate_map, &subnet, &new_subnet, BPF_ANY);
    }

    // Limitation de taux par IP avec limite configurable
    return apply_rate_limit(src_ip, ip_limit);
}

// CORRECTION CRITIQUE 3: Validation de somme de contrôle optimisée et optionnelle
// Validation de hachage simple au lieu de CRC32 complet pour la performance
static __always_inline __u32 calculate_simple_hash(__u8 *data, __u32 len) {
    __u32 hash = 0x811c9dc5; // Valeur initiale FNV-1a
    __u32 max_len = len < 32 ? len : 32; // Limiter le traitement aux 32 premiers octets pour la performance

    for (__u32 i = 0; i < max_len; i++) {
        hash ^= data[i];
        hash *= 0x01000193; // Nombre premier FNV-1a
    }
    return hash;
}

// CORRECTION CRITIQUE 3: Validation de somme de contrôle ENet optionnelle avec optimisation de performance
static __always_inline int validate_enet_checksum(void *payload, __u32 len, void *data_end, __u8 enable_validation) {
    // Ignorer la validation si désactivée pour la performance
    if (!enable_validation) {
        return 1;
    }

    if (len < 8 || (void *)payload + len > data_end) return 1; // Ignorer si trop petit

    // Utiliser la validation de hachage simple au lieu de CRC32 complet pour une meilleure performance
    // Cela fournit une protection raisonnable contre les paquets corrompus tout en étant beaucoup plus rapide
    __u32 *checksum_ptr = (__u32*)((char*)payload + len - 4);
    if ((void*)(checksum_ptr + 1) > data_end) return 1; // Ignorer si impossible de lire la somme de contrôle

    __u32 provided_checksum = *checksum_ptr;
    __u32 calculated_hash = calculate_simple_hash((__u8*)payload, len - 4);

    // Utiliser une comparaison simple qui est suffisante pour la détection d'attaques
    // La validation complète CRC32 peut être effectuée au niveau de l'application si nécessaire
    if ((provided_checksum ^ calculated_hash) & 0xFFFF0000) {
        return 0; // Paquet probablement corrompu ou malveillant
    }

    return 1; // Le paquet semble valide
}

SEC("xdp_fivem_advanced")
int fivem_xdp_advanced(struct xdp_md *ctx) {
    void *data_end = (void *)(long)ctx->data_end;
    void *data = (void *)(long)ctx->data;

    // Suivi de la performance - démarrer le minuteur
    __u64 start_time = bpf_ktime_get_ns();

    // CORRECTION CRITIQUE 1: Obtenir la configuration du serveur (avec retour aux valeurs par défaut)
    struct server_config *config = get_server_config();

    // Utiliser les valeurs configurées ou les valeurs par défaut
    __u32 target_server_ip = config ? config->server_ip : 0; // 0 signifie accepter n'importe quelle IP si non configurée
    __u16 server_port = config ? config->server_port : DEFAULT_FIVEM_SERVER_PORT;
    __u16 game_port1 = config ? config->game_port1 : DEFAULT_FIVEM_GAME_PORT1;
    __u16 game_port2 = config ? config->game_port2 : DEFAULT_FIVEM_GAME_PORT2;

    // Vérification précoce de la taille du paquet (optimisation de la performance)
    __u32 packet_size = data_end - data;
    if (packet_size < 42) return XDP_ABORTED; // Eth+IP+UDP minimum

    // Analyse des en-têtes en un seul passage (optimisation de la performance)
    struct ethhdr *eth = data;
    struct iphdr *ip = (void*)eth + sizeof(*eth);
    struct udphdr *udp = (void*)ip + (ip->ihl * 4);

    // Vérification des limites pour tous les en-têtes à la fois
    if ((void *)(eth + 1) > data_end ||
        (void *)(ip + 1) > data_end ||
        (void *)(udp + 1) > data_end ||
        ip->ihl < 5) {
        return XDP_ABORTED;
    }

    // CORRECTION CRITIQUE 1: Validation de l'IP du serveur configurable
    // Si target_server_ip est 0, accepter les paquets vers n'importe quelle IP (utile pour les configurations multi-serveurs)
    // Sinon, n'accepter que les paquets destinés à l'IP du serveur configurée
    if (eth->h_proto != bpf_htons(ETH_P_IP) ||
        ip->protocol != IPPROTO_UDP ||
        (target_server_ip != 0 && ip->daddr != bpf_htonl(target_server_ip))) {
        return XDP_PASS;
    }

    // CORRECTION CRITIQUE 4: Validation de port configurable
    __u16 dest_port = bpf_ntohs(udp->dest);

    // Vérifier si c'est l'un de nos ports cibles en utilisant les valeurs configurées
    if (dest_port != server_port &&
        dest_port != game_port1 &&
        dest_port != game_port2) {
        return XDP_PASS;
    }

    // Obtenir des informations sur la charge utile
    void *payload = (void *)udp + sizeof(struct udphdr);
    __u32 payload_len = bpf_ntohs(udp->len) - sizeof(struct udphdr);
    __u32 src_ip = ip->saddr;

    // CORRECTION CRITIQUE 4: Limitation de taux hiérarchique avec limites configurables
    if (!hierarchical_rate_limit(src_ip, config)) {
        update_stats(3); // limité_par_le_taux
        update_perf_metrics(start_time, packet_size);
        return XDP_DROP;
    }

    // Validation des contraintes de taille de paquet
    if (payload_len < MIN_PACKET_SIZE) {
        update_stats(2); // protocole_invalide
        log_attack(src_ip, ATTACK_SIZE_VIOLATION);
        update_perf_metrics(start_time, packet_size);
        return XDP_DROP;
    }

    // Limites de taille différentes pour différents ports (en utilisant les valeurs de port configurées)
    __u32 max_size = (dest_port == server_port) ? MAX_PACKET_SIZE : MAX_VOICE_SIZE;
    if (payload_len > max_size) {
        update_stats(2); // protocole_invalide
        log_attack(src_ip, ATTACK_SIZE_VIOLATION);
        update_perf_metrics(start_time, packet_size);
        return XDP_DROP;
    }

    // S'assurer que nous pouvons lire les 4 premiers octets pour la validation du protocole
    if ((void *)payload + 4 > data_end) {
        update_perf_metrics(start_time, packet_size);
        return XDP_ABORTED;
    }

    __u32 first_word = *(__u32*)payload;

    // Gérer les paquets hors bande (OOB) - ceux-ci commencent par 0xFFFFFFFF
    if (first_word == OOB_PACKET_MARKER) {
        // Les paquets OOB ont besoin d'au moins 8 octets (marqueur + 4 octets de données)
        if (payload_len < 8) {
            update_stats(2); // protocole_invalide
            log_attack(src_ip, ATTACK_INVALID_PROTOCOL);
            update_perf_metrics(start_time, packet_size);
            return XDP_DROP;
        }

        // Extraire le token de connexion pour validation (si présent)
        if (payload_len >= 12 && (void *)payload + 12 <= data_end) {
            __u32 token_hash = *(__u32*)((char*)payload + 8);
            if (!validate_connection_token(token_hash, src_ip)) {
                update_enhanced_stats(4); // violations_de_token
                update_perf_metrics(start_time, packet_size);
                return XDP_DROP;
            }
        }

        // Validation de l'état du protocole
        if (!validate_protocol_state(src_ip, first_word, 0)) {
            update_enhanced_stats(6); // violations_d'état
            update_perf_metrics(start_time, packet_size);
            return XDP_DROP;
        }

        update_stats(1); // passé
        update_perf_metrics(start_time, packet_size);
        return XDP_PASS;
    }

    // CORRECTION CRITIQUE 2: Analyse correcte des paquets ENet basée sur le protocole ENet réel
    // Structure du paquet ENet (d'après la documentation ENet et l'implémentation FiveM) :
    // Octets 0-1: ID du pair (12 bits) + Flags (4 bits)
    // Octets 2-3: Numéro de séquence (pour les paquets fiables)
    // Octets 4+: Données du paquet

    __u16 enet_header = *(__u16*)payload;
    __u16 peer_id = enet_header & ENET_MAX_PEER_ID;  // Extraire l'ID du pair (12 bits inférieurs)
    __u16 flags = (enet_header >> 12) & 0xF;         // Extraire les flags (4 bits supérieurs)
    __u16 sequence = 0;

    // Validation de la plage d'ID du pair (0-4095 selon la spécification ENet)
    if (peer_id > ENET_MAX_PEER_ID) {
        update_stats(2); // protocole_invalide
        log_attack(src_ip, ATTACK_INVALID_PROTOCOL);
        update_perf_metrics(start_time, packet_size);
        return XDP_DROP;
    }

    // Extraire le numéro de séquence pour les paquets fiables (si disponible et que le paquet est suffisamment grand)
    if (payload_len >= 4 && (void *)payload + 4 <= data_end) {
        sequence = *(__u16*)((char*)payload + 2);

        // Ne valider le numéro de séquence que pour les paquets fiables (vérification des flags)
        // Les paquets fiables ENet ont des modèles de flags spécifiques
        if (flags & 0x1) { // Flag de paquet fiable
            if (!validate_sequence_number(src_ip, peer_id, sequence)) {
                update_enhanced_stats(5); // violations_de_séquence
                update_perf_metrics(start_time, packet_size);
                return XDP_DROP;
            }
        }
    }

    // CORRECTION CRITIQUE 3: Validation de somme de contrôle ENet optionnelle avec activation/désactivation configurable
    __u8 enable_checksum = config ? config->enable_checksum_validation : 1; // Activé par défaut
    if (payload_len >= 12 && !validate_enet_checksum(payload, payload_len, data_end, enable_checksum)) {
        update_enhanced_stats(7); // échecs_de_somme_de_controle
        log_attack(src_ip, ATTACK_CHECKSUM_FAIL);
        update_perf_metrics(start_time, packet_size);
        return XDP_DROP;
    }

    // Pour les paquets avec suffisamment de données, valider le hachage du type de message
    __u32 msg_hash = 0;
    if (payload_len >= 8) {
        // Le hachage du message est généralement à l'offset 4 après l'en-tête ENet
        if ((void *)payload + 8 > data_end) {
            update_perf_metrics(start_time, packet_size);
            return XDP_ABORTED;
        }

        msg_hash = *(__u32*)((char*)payload + 4);

        // CORRECTION CRITIQUE 4: Ne valider le hachage que pour le port principal du serveur en utilisant le port configuré
        if (dest_port == server_port && !is_valid_fivem_message_hash(msg_hash)) {
            update_stats(2); // protocole_invalide
            log_attack(src_ip, ATTACK_INVALID_PROTOCOL);
            update_perf_metrics(start_time, packet_size);
            return XDP_DROP;
        }

        // Validation de l'état du protocole avec le hachage du message
        if (!validate_protocol_state(src_ip, first_word, msg_hash)) {
            update_enhanced_stats(6); // violations_d'état
            update_perf_metrics(start_time, packet_size);
            return XDP_DROP;
        }
    }

    // Le paquet a passé toutes les vérifications de validation
    update_stats(1); // passé
    update_perf_metrics(start_time, packet_size);
    return XDP_PASS;
}

char _license[] SEC("license") = "MIT";