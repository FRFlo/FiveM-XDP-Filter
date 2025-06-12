# Program Flow

This document provides a detailed explanation of the XDP program flow and packet processing logic in the FiveM XDP filter.

## Overview

The FiveM XDP filter processes packets in a single pass through multiple validation stages, implementing a defense-in-depth approach with early packet rejection for performance optimization.

## Main Program Flow

```
Packet Arrival
      ↓
[1] Configuration Loading
      ↓
[2] Basic Header Validation
      ↓
[3] Protocol Filtering
      ↓
[4] Port Validation
      ↓
[5] Hierarchical Rate Limiting
      ↓
[6] Packet Size Validation
      ↓
[7] OOB Packet Processing
      ↓
[8] ENet Packet Processing
      ↓
[9] Performance Metrics Update
      ↓
Decision: XDP_PASS / XDP_DROP
```

## Detailed Processing Stages

### Stage 1: Configuration Loading

```c
// Get runtime configuration with fallback to defaults
struct server_config *config = get_server_config();
__u32 target_server_ip = config ? config->server_ip : 0;
__u16 server_port = config ? config->server_port : DEFAULT_FIVEM_SERVER_PORT;
// ... other configuration parameters
```

**Purpose:** Load runtime configuration from BPF maps with fallback to compile-time defaults.

**Key Features:**
- Zero-downtime configuration updates
- Graceful fallback to defaults if configuration is missing
- Support for multi-server deployments (target_server_ip = 0)

### Stage 2: Basic Header Validation

```c
// Early packet size check
__u32 packet_size = data_end - data;
if (packet_size < 42) return XDP_ABORTED; // Eth+IP+UDP minimum

// Parse headers in single pass
struct ethhdr *eth = data;
struct iphdr *ip = (void*)eth + sizeof(*eth);
struct udphdr *udp = (void*)ip + (ip->ihl * 4);

// Bounds checking for all headers at once
if ((void *)(eth + 1) > data_end ||
    (void *)(ip + 1) > data_end ||
    (void *)(udp + 1) > data_end ||
    ip->ihl < 5) {
    return XDP_ABORTED;
}
```

**Purpose:** Validate basic packet structure and prevent buffer overflows.

**Optimizations:**
- Single-pass header parsing
- Combined bounds checking
- Early rejection of malformed packets

### Stage 3: Protocol Filtering

```c
// Configurable server IP validation
if (eth->h_proto != bpf_htons(ETH_P_IP) ||
    ip->protocol != IPPROTO_UDP ||
    (target_server_ip != 0 && ip->daddr != bpf_htonl(target_server_ip))) {
    return XDP_PASS;
}
```

**Purpose:** Filter for UDP packets destined to configured FiveM server.

**Key Features:**
- **CRITICAL FIX:** Configurable server IP (no hardcoded localhost)
- Support for multi-server setups (target_server_ip = 0)
- Early rejection of non-FiveM traffic

### Stage 4: Port Validation

```c
__u16 dest_port = bpf_ntohs(udp->dest);

// Check if it's one of our target ports using configured values
if (dest_port != server_port &&
    dest_port != game_port1 &&
    dest_port != game_port2) {
    return XDP_PASS;
}
```

**Purpose:** Validate destination ports against configured FiveM ports.

**Supported Ports:**
- Primary server port (default: 30120)
- Game communication port 1 (default: 6672)
- Game communication port 2 (default: 6673)

### Stage 5: Hierarchical Rate Limiting

```c
if (!hierarchical_rate_limit(src_ip, config)) {
    update_stats(3); // rate_limited
    update_perf_metrics(start_time, packet_size);
    return XDP_DROP;
}
```

**Purpose:** Apply multi-layer rate limiting for DDoS protection.

**Rate Limiting Hierarchy:**

1. **Global Rate Limiting**
   - Prevents server overload
   - Configurable global packet limit per second
   - Sliding window implementation

2. **Subnet Rate Limiting**
   - Prevents subnet-based attacks
   - /24 subnet aggregation
   - Tracks active IPs per subnet

3. **Per-IP Rate Limiting**
   - Individual IP protection
   - Configurable per-IP packet limit
   - LRU cache for scalability

### Stage 6: Packet Size Validation

```c
// Validate packet size constraints
if (payload_len < MIN_PACKET_SIZE) {
    update_stats(2); // invalid_protocol
    log_attack(src_ip, ATTACK_SIZE_VIOLATION);
    return XDP_DROP;
}

// Different size limits for different ports
__u32 max_size = (dest_port == server_port) ? MAX_PACKET_SIZE : MAX_VOICE_SIZE;
if (payload_len > max_size) {
    update_stats(2); // invalid_protocol
    log_attack(src_ip, ATTACK_SIZE_VIOLATION);
    return XDP_DROP;
}
```

**Purpose:** Validate packet sizes against FiveM protocol limits.

**Size Limits:**
- Minimum packet size: 4 bytes
- Maximum sync packet size: 2400 bytes
- Maximum voice packet size: 8192 bytes

### Stage 7: OOB Packet Processing

```c
__u32 first_word = *(__u32*)payload;

if (first_word == OOB_PACKET_MARKER) {
    // Out-of-band packet processing
    if (payload_len >= 8) {
        __u32 connection_token = *(__u32*)((char*)payload + 4);
        if (!validate_connection_token(connection_token, src_ip)) {
            update_enhanced_stats(4); // token_violations
            return XDP_DROP;
        }
    }
    
    // Protocol state validation
    if (!validate_protocol_state(src_ip, first_word, 0)) {
        update_enhanced_stats(6); // state_violations
        return XDP_DROP;
    }
    
    update_stats(1); // passed
    update_perf_metrics(start_time, packet_size);
    return XDP_PASS;
}
```

**Purpose:** Handle FiveM out-of-band packets with connection token validation.

**Features:**
- Connection token validation with replay protection
- Protocol state machine enforcement
- IP consistency checking

### Stage 8: ENet Packet Processing

```c
// CRITICAL FIX: Corrected ENet packet parsing
__u16 enet_header = *(__u16*)payload;
__u16 peer_id = enet_header & ENET_MAX_PEER_ID;  // Lower 12 bits
__u16 flags = (enet_header >> 12) & 0xF;         // Upper 4 bits

// Validate peer ID range
if (peer_id > ENET_MAX_PEER_ID) {
    update_stats(2); // invalid_protocol
    log_attack(src_ip, ATTACK_INVALID_PROTOCOL);
    return XDP_DROP;
}

// Sequence validation for reliable packets only
if (flags & 0x1) { // Reliable packet flag
    if (!validate_sequence_number(src_ip, peer_id, sequence)) {
        update_enhanced_stats(5); // sequence_violations
        return XDP_DROP;
    }
}
```

**Purpose:** Process ENet packets with proper header parsing and validation.

**Key Features:**
- **CRITICAL FIX:** Correct bit extraction (peer ID: lower 12 bits, flags: upper 4 bits)
- Sequence validation only for reliable packets
- Replay attack prevention

### Stage 9: Advanced Validation

```c
// Optional checksum validation
__u8 enable_checksum = config ? config->enable_checksum_validation : 1;
if (payload_len >= 12 && !validate_enet_checksum(payload, payload_len, data_end, enable_checksum)) {
    update_enhanced_stats(7); // checksum_failures
    log_attack(src_ip, ATTACK_CHECKSUM_FAIL);
    return XDP_DROP;
}

// Message hash validation for server port
if (dest_port == server_port && !is_valid_fivem_message_hash(msg_hash)) {
    update_stats(2); // invalid_protocol
    log_attack(src_ip, ATTACK_INVALID_PROTOCOL);
    return XDP_DROP;
}
```

**Purpose:** Advanced packet validation with configurable features.

**Features:**
- **CRITICAL FIX:** Optional checksum validation using optimized FNV-1a hash
- FiveM message hash validation against 28 known message types
- Configurable validation for performance tuning

## Performance Optimizations

### Single-Pass Processing
- All header parsing done in one pass
- Combined bounds checking
- Early packet rejection

### Optimized Algorithms
- **CRITICAL FIX:** FNV-1a hash instead of nested CRC32 loops
- Grouped message hash lookup by first byte
- LRU maps for automatic memory management

### Configurable Features
- Optional checksum validation
- Configurable rate limits
- Selective validation based on packet type

## Error Handling

### Packet Rejection Reasons
1. **XDP_ABORTED** - Malformed packets, bounds check failures
2. **XDP_DROP** - Security violations, rate limiting, invalid protocol
3. **XDP_PASS** - Non-FiveM traffic, valid FiveM packets

### Attack Detection
- Comprehensive logging with attack classification
- Real-time statistics updates
- Performance metrics tracking

### Graceful Degradation
- Fallback to defaults if configuration missing
- Optional features can be disabled for performance
- Robust error handling prevents filter crashes

## State Management

### Connection State Machine
```
INITIAL → OOB_SENT → CONNECTING → CONNECTED
    ↓         ↓           ↓          ↓
SUSPICIOUS ← SUSPICIOUS ← SUSPICIOUS ← SUSPICIOUS
```

### Token Lifecycle
1. **First Use** - Create new token state
2. **Validation** - Check IP consistency, usage count, age
3. **Expiration** - Automatic cleanup after 2 hours

### Sequence Tracking
- Per-peer sequence number validation
- Out-of-order packet tolerance (window of 100)
- Anomaly detection for excessive out-of-order packets

## Monitoring Integration

### Real-time Metrics
- Packet processing time
- Map lookup performance
- Attack detection statistics

### Statistics Export
- Per-CPU statistics aggregation
- Attack log with timestamps
- Performance metrics for tuning

This program flow ensures comprehensive security while maintaining high performance through optimized algorithms and configurable features.
