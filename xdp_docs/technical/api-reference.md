# API Reference

This document provides detailed information about all BPF maps, data structures, and functions in the FiveM XDP filter implementation.

## BPF Maps

### Configuration Maps

#### `server_config_map`
**Type:** `BPF_MAP_TYPE_ARRAY`  
**Max Entries:** 1  
**Key:** `__u32` (always 0)  
**Value:** `struct server_config`

Primary configuration map for runtime server settings.

```c
struct server_config {
    __u32 server_ip;                    // Target server IP (0 = accept any)
    __u16 server_port;                  // Primary FiveM server port (default: 30120)
    __u16 game_port1;                   // Internal game communication port (default: 6672)
    __u16 game_port2;                   // Alternative game communication port (default: 6673)
    __u32 rate_limit;                   // Packets per second per IP
    __u32 global_rate_limit;            // Global packets per second limit
    __u32 subnet_rate_limit;            // Subnet (/24) packets per second limit
    __u8 enable_checksum_validation;    // Enable/disable checksum validation
    __u8 strict_enet_validation;        // Enable strict ENet header validation
    __u8 reserved[3];                   // Padding for future use
};
```

**Usage Example:**
```c
// Get configuration with fallback to defaults
struct server_config *config = get_server_config();
__u32 target_ip = config ? config->server_ip : 0;
```

### Rate Limiting Maps

#### `rate_limit_map`
**Type:** `BPF_MAP_TYPE_LRU_HASH`  
**Max Entries:** 10,000  
**Key:** `__u32` (Source IP address)  
**Value:** `__u64` (Last packet timestamp in nanoseconds)

Per-IP rate limiting tracking.

#### `global_rate_map`
**Type:** `BPF_MAP_TYPE_ARRAY`  
**Max Entries:** 1  
**Key:** `__u32` (always 0)  
**Value:** `struct global_rate_state`

```c
struct global_rate_state {
    __u64 packet_count;     // Packets in current window
    __u64 window_start;     // Window start timestamp
    __u32 current_limit;    // Current rate limit
};
```

#### `subnet_rate_map`
**Type:** `BPF_MAP_TYPE_LRU_HASH`  
**Max Entries:** 1,024  
**Key:** `__u32` (Subnet /24 address)  
**Value:** `struct subnet_rate_state`

```c
struct subnet_rate_state {
    __u64 packet_count;     // Packets in current window
    __u64 window_start;     // Window start timestamp
    __u32 active_ips;       // Number of active IPs in subnet
};
```

### Security Maps

#### `enhanced_token_map`
**Type:** `BPF_MAP_TYPE_LRU_HASH`  
**Max Entries:** 5,000  
**Key:** `__u32` (Connection token hash)  
**Value:** `struct connection_token_state`

```c
struct connection_token_state {
    __u32 source_ip;        // IP that first used this token
    __u64 first_seen;       // First usage timestamp
    __u32 usage_count;      // Number of times used (max 3)
    __u16 sequence_number;  // Last sequence number
};
```

#### `peer_sequence_map`
**Type:** `BPF_MAP_TYPE_LRU_HASH`  
**Max Entries:** 4,096  
**Key:** `__u64` ((src_ip << 32) | peer_id)  
**Value:** `struct peer_state`

```c
struct peer_state {
    __u16 last_sequence;        // Last valid sequence number
    __u64 last_update;          // Last update timestamp
    __u32 out_of_order_count;   // Out-of-order packet counter
};
```

#### `connection_state_map`
**Type:** `BPF_MAP_TYPE_LRU_HASH`  
**Max Entries:** 2,048  
**Key:** `__u32` (Source IP address)  
**Value:** `struct connection_context`

```c
struct connection_context {
    enum connection_state state;    // Current connection state
    __u64 state_timestamp;          // State change timestamp
    __u32 packet_count;             // Packets in this state
    __u8 violations;                // Protocol violations count
};

enum connection_state {
    STATE_INITIAL = 0,      // No packets seen
    STATE_OOB_SENT = 1,     // OOB packet sent
    STATE_CONNECTING = 2,   // Connection in progress
    STATE_CONNECTED = 3,    // Fully connected
    STATE_SUSPICIOUS = 4    // Suspicious behavior detected
};
```

### Statistics Maps

#### `enhanced_stats_map`
**Type:** `BPF_MAP_TYPE_PERCPU_ARRAY`  
**Max Entries:** 1  
**Key:** `__u32` (always 0)  
**Value:** `struct enhanced_stats`

```c
struct enhanced_stats {
    __u64 dropped;              // Packets dropped
    __u64 passed;               // Packets passed
    __u64 invalid_protocol;     // Invalid protocol packets
    __u64 rate_limited;         // Rate limited packets
    __u64 token_violations;     // Token validation failures
    __u64 sequence_violations;  // Sequence validation failures
    __u64 state_violations;     // State machine violations
    __u64 checksum_failures;    // Checksum validation failures
};
```

#### `attack_log_map`
**Type:** `BPF_MAP_TYPE_HASH`  
**Max Entries:** 1,000  
**Key:** `__u32` (Attack ID)  
**Value:** `struct attack_stats`

```c
struct attack_stats {
    __u64 count;            // Attack occurrence count
    __u64 last_seen;        // Last attack timestamp
    __u32 source_ip;        // Attacking IP address
    __u16 attack_type;      // Type of attack detected
};

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
```

#### `perf_metrics_map`
**Type:** `BPF_MAP_TYPE_PERCPU_ARRAY`  
**Max Entries:** 1  
**Key:** `__u32` (always 0)  
**Value:** `struct perf_metrics`

```c
struct perf_metrics {
    __u64 total_packets;            // Total packets processed
    __u64 processing_time_ns;       // Total processing time
    __u64 map_lookup_time_ns;       // Time spent in map lookups
    __u32 max_processing_time_ns;   // Maximum processing time
    __u32 avg_packet_size;          // Average packet size
};
```

## Core Functions

### Configuration Functions

#### `get_server_config()`
```c
static __always_inline struct server_config* get_server_config()
```
**Returns:** Pointer to server configuration or NULL if not configured.  
**Usage:** Get runtime configuration with fallback to defaults.

### Rate Limiting Functions

#### `apply_rate_limit()`
```c
static __always_inline int apply_rate_limit(__u32 src_ip, __u32 rate_limit)
```
**Parameters:**
- `src_ip`: Source IP address
- `rate_limit`: Packets per second limit

**Returns:** 1 if packet allowed, 0 if rate limited.

#### `hierarchical_rate_limit()`
```c
static __always_inline int hierarchical_rate_limit(__u32 src_ip, struct server_config *config)
```
**Parameters:**
- `src_ip`: Source IP address
- `config`: Server configuration

**Returns:** 1 if packet allowed, 0 if rate limited.  
**Description:** Applies global, subnet, and per-IP rate limiting.

### Validation Functions

#### `is_valid_fivem_message_hash()`
```c
static __always_inline int is_valid_fivem_message_hash(__u32 hash)
```
**Parameters:**
- `hash`: Message type hash to validate

**Returns:** 1 if valid FiveM message hash, 0 otherwise.  
**Description:** Validates against 28 known FiveM message types.

#### `validate_connection_token()`
```c
static __always_inline int validate_connection_token(__u32 token_hash, __u32 src_ip)
```
**Parameters:**
- `token_hash`: Connection token hash
- `src_ip`: Source IP address

**Returns:** 1 if token valid, 0 if invalid.  
**Description:** Validates connection tokens with replay protection.

#### `validate_sequence_number()`
```c
static __always_inline int validate_sequence_number(__u32 src_ip, __u16 peer_id, __u16 sequence)
```
**Parameters:**
- `src_ip`: Source IP address
- `peer_id`: ENet peer ID
- `sequence`: Sequence number

**Returns:** 1 if sequence valid, 0 if invalid.  
**Description:** Prevents replay attacks with sequence validation.

#### `validate_protocol_state()`
```c
static __always_inline int validate_protocol_state(__u32 src_ip, __u32 first_word, __u32 msg_hash)
```
**Parameters:**
- `src_ip`: Source IP address
- `first_word`: First word of packet
- `msg_hash`: Message hash

**Returns:** 1 if state transition valid, 0 if invalid.  
**Description:** Enforces FiveM connection state machine.

### Checksum Functions

#### `calculate_simple_hash()`
```c
static __always_inline __u32 calculate_simple_hash(__u8 *data, __u32 len)
```
**Parameters:**
- `data`: Data to hash
- `len`: Data length

**Returns:** FNV-1a hash value.  
**Description:** Optimized hash function for checksum validation.

#### `validate_enet_checksum()`
```c
static __always_inline int validate_enet_checksum(void *payload, __u32 len, void *data_end, __u8 enable_validation)
```
**Parameters:**
- `payload`: Packet payload
- `len`: Payload length
- `data_end`: End of packet data
- `enable_validation`: Enable/disable flag

**Returns:** 1 if checksum valid, 0 if invalid.  
**Description:** Optional ENet checksum validation.

### Utility Functions

#### `update_stats()`
```c
static __always_inline void update_stats(__u32 stat_type)
```
**Parameters:**
- `stat_type`: Statistics type to update

**Description:** Updates packet statistics counters.

#### `log_attack()`
```c
static __always_inline void log_attack(__u32 src_ip, enum attack_type type)
```
**Parameters:**
- `src_ip`: Attacking IP address
- `type`: Type of attack detected

**Description:** Logs detected attacks for analysis.

#### `update_perf_metrics()`
```c
static __always_inline void update_perf_metrics(__u64 start_time, __u32 packet_size)
```
**Parameters:**
- `start_time`: Processing start timestamp
- `packet_size`: Size of processed packet

**Description:** Updates performance metrics.

## Constants

### FiveM Protocol Constants
```c
#define OOB_PACKET_MARKER   0xFFFFFFFF      // Out-of-band packet identifier
#define ENET_MAX_PEER_ID    0x0FFF          // Maximum ENet peer ID (4095)
#define MIN_PACKET_SIZE     4               // Minimum valid packet size
#define MAX_PACKET_SIZE     2400            // Maximum sync packet size
#define MAX_VOICE_SIZE      8192            // Maximum voice packet size
#define ENET_HEADER_SIZE    4               // Minimum ENet header size
#define MAX_TOKEN_AGE       7200000000000ULL // 2 hours in nanoseconds
#define MAX_SEQUENCE_WINDOW 100             // Acceptable out-of-order packet window
```

### Default Configuration Values
```c
#define DEFAULT_FIVEM_SERVER_PORT   30120   // Primary FiveM server port
#define DEFAULT_FIVEM_GAME_PORT1    6672    // Internal game communication port
#define DEFAULT_FIVEM_GAME_PORT2    6673    // Alternative game communication port
#define DEFAULT_RATE_LIMIT          1000    // Default packets per second per IP
#define DEFAULT_GLOBAL_RATE_LIMIT   50000   // Default global packets per second limit
#define DEFAULT_SUBNET_RATE_LIMIT   5000    // Default subnet (/24) packets per second limit
```

## Message Hash Constants

The filter validates against 28 known FiveM message types. See the source code for the complete list of message hash constants (MSG_*_HASH defines).
