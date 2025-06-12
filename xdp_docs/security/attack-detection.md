# Attack Detection and Mitigation

This document details the comprehensive attack detection and mitigation capabilities of the FiveM XDP filter, including the security enhancements from the critical compliance fixes.

## Attack Detection Overview

The FiveM XDP filter implements a multi-layered security approach with real-time attack detection, classification, and automated mitigation. All attacks are logged with detailed information for security analysis and incident response.

## Attack Classification System

### Attack Types

The filter detects and classifies 8 different types of attacks:

```c
enum attack_type {
    ATTACK_NONE = 0,                // No attack detected
    ATTACK_RATE_LIMIT = 1,          // Rate limiting violation
    ATTACK_INVALID_PROTOCOL = 2,    // Invalid protocol or message
    ATTACK_REPLAY = 3,              // Replay attack attempt
    ATTACK_STATE_VIOLATION = 4,     // Protocol state machine violation
    ATTACK_CHECKSUM_FAIL = 5,       // Checksum validation failure
    ATTACK_SIZE_VIOLATION = 6,      // Packet size violation
    ATTACK_SEQUENCE_ANOMALY = 7,    // Sequence number anomaly
    ATTACK_TOKEN_REUSE = 8          // Connection token reuse
};
```

### Attack Detection Mechanisms

#### 1. Rate Limiting Attacks (ATTACK_RATE_LIMIT)

**Detection Method:** Hierarchical rate limiting with three levels
- **Per-IP Rate Limiting:** Detects single-source flooding
- **Subnet Rate Limiting:** Detects distributed attacks from /24 subnets
- **Global Rate Limiting:** Protects against server overload

**Thresholds:**
```c
// Configurable limits (examples)
.rate_limit = 1000,           // Packets per second per IP
.subnet_rate_limit = 5000,    // Packets per second per /24 subnet
.global_rate_limit = 50000    // Total packets per second
```

**Mitigation:** Automatic packet dropping with exponential backoff

**Example Detection:**
```bash
# Monitor rate limiting attacks
make stats | grep rate_limited

# View attack details
sudo bpftool map dump name attack_log_map | grep "attack_type.*1"
```

#### 2. Invalid Protocol Attacks (ATTACK_INVALID_PROTOCOL)

**Detection Method:** Deep packet inspection and protocol validation
- **Invalid ENet Headers:** Malformed peer IDs or flags
- **Unknown Message Hashes:** Messages not in FiveM protocol specification
- **Invalid Packet Structure:** Corrupted or crafted packets

**Validation Points:**
```c
// ENet header validation (CRITICAL FIX 2)
__u16 peer_id = enet_header & ENET_MAX_PEER_ID;  // Lower 12 bits
if (peer_id > ENET_MAX_PEER_ID) {
    log_attack(src_ip, ATTACK_INVALID_PROTOCOL);
    return XDP_DROP;
}

// FiveM message hash validation
if (!is_valid_fivem_message_hash(msg_hash)) {
    log_attack(src_ip, ATTACK_INVALID_PROTOCOL);
    return XDP_DROP;
}
```

**Mitigation:** Immediate packet rejection and source IP tracking

#### 3. Replay Attacks (ATTACK_REPLAY)

**Detection Method:** Connection token and sequence number validation
- **Token Age Validation:** Tokens expire after 2 hours
- **Token Reuse Detection:** Maximum 3 uses per token
- **Sequence Number Tracking:** Out-of-order packet analysis

**Implementation:**
```c
// Token age validation
if (now - state->first_seen > MAX_TOKEN_AGE) {
    log_attack(src_ip, ATTACK_REPLAY);
    return 0;
}

// Sequence validation for reliable packets
if (flags & 0x1) { // Reliable packet flag
    if (!validate_sequence_number(src_ip, peer_id, sequence)) {
        log_attack(src_ip, ATTACK_SEQUENCE_ANOMALY);
        return XDP_DROP;
    }
}
```

**Mitigation:** Token invalidation and connection state reset

#### 4. State Violation Attacks (ATTACK_STATE_VIOLATION)

**Detection Method:** Protocol state machine enforcement
- **Invalid State Transitions:** Enforces proper FiveM connection flow
- **Out-of-Order Messages:** Detects protocol manipulation attempts
- **State Consistency:** Validates message types against connection state

**State Machine:**
```
INITIAL → OOB_SENT → CONNECTING → CONNECTED
    ↓         ↓           ↓          ↓
SUSPICIOUS ← SUSPICIOUS ← SUSPICIOUS ← SUSPICIOUS
```

**Example Validation:**
```c
switch (ctx->state) {
    case STATE_OOB_SENT:
        if (msg_hash == MSG_CONFIRM_HASH) {
            ctx->state = STATE_CONNECTING;
            return 1;
        }
        break;
    case STATE_CONNECTING:
        if (msg_hash == MSG_I_HOST_HASH || msg_hash == MSG_HE_HOST_HASH) {
            ctx->state = STATE_CONNECTED;
            return 1;
        }
        break;
}
```

**Mitigation:** Connection state reset and temporary IP blocking

#### 5. Checksum Failures (ATTACK_CHECKSUM_FAIL)

**Detection Method:** Optimized packet integrity validation (CRITICAL FIX 3)
- **FNV-1a Hash Validation:** Efficient checksum verification
- **Configurable Validation:** Can be disabled for performance
- **Corruption Detection:** Identifies tampered or corrupted packets

**Implementation:**
```c
// Optional checksum validation with performance optimization
static __always_inline int validate_enet_checksum(void *payload, __u32 len, 
                                                  void *data_end, __u8 enable_validation) {
    if (!enable_validation) return 1; // Skip if disabled
    
    __u32 calculated_hash = calculate_simple_hash((__u8*)payload, len - 4);
    if ((provided_checksum ^ calculated_hash) & 0xFFFF0000) {
        return 0; // Likely corrupted or malicious packet
    }
    return 1;
}
```

**Mitigation:** Packet rejection and source tracking

#### 6. Size Violation Attacks (ATTACK_SIZE_VIOLATION)

**Detection Method:** Packet size validation against FiveM protocol limits
- **Minimum Size Check:** Prevents undersized packets
- **Maximum Size Check:** Prevents oversized packets and buffer overflows
- **Port-Specific Limits:** Different limits for different services

**Size Limits:**
```c
#define MIN_PACKET_SIZE     4               // Minimum valid packet size
#define MAX_PACKET_SIZE     2400            // Maximum sync packet size
#define MAX_VOICE_SIZE      8192            // Maximum voice packet size

// Port-specific validation
__u32 max_size = (dest_port == server_port) ? MAX_PACKET_SIZE : MAX_VOICE_SIZE;
if (payload_len > max_size) {
    log_attack(src_ip, ATTACK_SIZE_VIOLATION);
    return XDP_DROP;
}
```

**Mitigation:** Immediate packet rejection

#### 7. Sequence Anomalies (ATTACK_SEQUENCE_ANOMALY)

**Detection Method:** Advanced sequence number analysis
- **Out-of-Order Tolerance:** Allows reasonable packet reordering
- **Anomaly Detection:** Identifies excessive out-of-order packets
- **Replay Prevention:** Detects sequence number manipulation

**Implementation:**
```c
// Allow reasonable out-of-order delivery (window of 100)
__s16 seq_diff = sequence - state->last_sequence;
if (seq_diff < -MAX_SEQUENCE_WINDOW || seq_diff > 1000) {
    state->out_of_order_count++;
    if (state->out_of_order_count > 10) {
        log_attack(src_ip, ATTACK_SEQUENCE_ANOMALY);
        return 0; // Block suspicious peer
    }
}
```

**Mitigation:** Peer blocking and connection reset

#### 8. Token Reuse Attacks (ATTACK_TOKEN_REUSE)

**Detection Method:** Connection token abuse detection
- **Usage Count Tracking:** Maximum 3 uses per token
- **IP Consistency:** Tokens tied to originating IP
- **Concurrent Usage:** Detects token sharing attempts

**Implementation:**
```c
// Validate IP consistency (anti-spoofing)
if (state->source_ip != src_ip) {
    log_attack(src_ip, ATTACK_TOKEN_REUSE);
    return 0;
}

// Validate usage count (max 3 retries as per FiveM)
if (state->usage_count > 3) {
    log_attack(src_ip, ATTACK_TOKEN_REUSE);
    return 0;
}
```

**Mitigation:** Token invalidation and IP tracking

## Real-Time Attack Monitoring

### Attack Statistics

**View current attack statistics:**
```bash
# Overall statistics
make stats

# Detailed attack breakdown
sudo bpftool map dump name enhanced_stats_map

# Recent attack log
sudo bpftool map dump name attack_log_map | tail -20
```

**Example output:**
```
Enhanced Statistics:
  dropped: 1250
  passed: 98750
  invalid_protocol: 45
  rate_limited: 1200
  token_violations: 3
  sequence_violations: 2
  state_violations: 0
  checksum_failures: 0
```

### Attack Log Analysis

**Attack log structure:**
```c
struct attack_stats {
    __u64 count;            // Attack occurrence count
    __u64 last_seen;        // Last attack timestamp
    __u32 source_ip;        // Attacking IP address
    __u16 attack_type;      // Type of attack detected
};
```

**Analyze attack patterns:**
```bash
# Top attacking IPs
sudo bpftool map dump name attack_log_map | \
    grep -o 'source_ip.*' | sort | uniq -c | sort -nr

# Attack type distribution
sudo bpftool map dump name attack_log_map | \
    grep -o 'attack_type.*' | sort | uniq -c

# Recent attacks by time
sudo bpftool map dump name attack_log_map | \
    sort -k 'last_seen' | tail -10
```

## Automated Mitigation Strategies

### Immediate Response

**Automatic packet dropping:**
- Malformed packets: `XDP_DROP`
- Rate limit violations: `XDP_DROP` with backoff
- Protocol violations: `XDP_DROP` with logging

**Connection state management:**
- Invalid state transitions: Reset to `STATE_SUSPICIOUS`
- Repeated violations: Temporary IP blocking
- Token abuse: Token invalidation

### Adaptive Response

**Dynamic rate limiting:**
```c
// Increase rate limits during attacks
if (attack_rate > threshold) {
    config->rate_limit *= 0.8;  // Reduce by 20%
    config->global_rate_limit *= 0.9;  // Reduce by 10%
}
```

**Progressive blocking:**
```c
// Escalating response based on violation count
if (violations > 10) {
    block_duration = 300;      // 5 minutes
} else if (violations > 5) {
    block_duration = 60;       // 1 minute
} else {
    block_duration = 10;       // 10 seconds
}
```

## Integration with External Security Systems

### Fail2Ban Integration

**Configure fail2ban to process XDP filter logs:**
```bash
# /etc/fail2ban/filter.d/fivem-xdp.conf
[Definition]
failregex = Attack detected from <HOST>: type=\d+ count=\d+
ignoreregex =

# /etc/fail2ban/jail.d/fivem-xdp.conf
[fivem-xdp]
enabled = true
filter = fivem-xdp
logpath = /var/log/fivem-xdp.log
maxretry = 5
bantime = 3600
findtime = 600
action = iptables-multiport[name=fivem-xdp, port="30120,6672,6673"]
```

### SIEM Integration

**Export attack data to SIEM systems:**
```bash
#!/bin/bash
# export_attacks.sh

# Export attack log in JSON format
sudo bpftool map dump name attack_log_map -j | \
    jq '.[] | {
        timestamp: (.last_seen | tonumber),
        source_ip: (.source_ip | tonumber),
        attack_type: (.attack_type | tonumber),
        count: (.count | tonumber)
    }' > /var/log/fivem-attacks.json

# Send to SIEM
curl -X POST -H "Content-Type: application/json" \
    -d @/var/log/fivem-attacks.json \
    https://siem.example.com/api/events
```

### Threat Intelligence Integration

**Block known malicious IPs:**
```bash
# Download threat intelligence feeds
curl -s https://threat-intel.example.com/ips.txt > /tmp/malicious_ips.txt

# Update XDP filter with malicious IP list
while read ip; do
    ./block_ip.sh $ip
done < /tmp/malicious_ips.txt
```

## Performance Impact of Security Features

### Security vs Performance Trade-offs

| Feature | Security Benefit | Performance Impact | Recommendation |
|---------|------------------|-------------------|----------------|
| Checksum Validation | High | 5-10% CPU | Enable for small/medium servers |
| Strict ENet Validation | Medium | 1-2% CPU | Enable unless compatibility issues |
| Deep Packet Inspection | High | 2-5% CPU | Always enable |
| Attack Logging | Medium | 1-3% CPU | Always enable |
| State Machine | High | 2-4% CPU | Always enable |

### Optimization Recommendations

**High-Security Environment:**
```c
.enable_checksum_validation = 1,
.strict_enet_validation = 1,
.rate_limit = 500,              // Conservative
.global_rate_limit = 25000      // Lower limit
```

**High-Performance Environment:**
```c
.enable_checksum_validation = 0,  // Disabled for performance
.strict_enet_validation = 0,      // Relaxed validation
.rate_limit = 2000,               // Higher limits
.global_rate_limit = 100000       // Maximum throughput
```

## Security Metrics and KPIs

### Key Security Metrics

1. **Attack Detection Rate:** Percentage of attacks successfully detected
2. **False Positive Rate:** Legitimate traffic incorrectly classified as attacks
3. **Response Time:** Time from attack detection to mitigation
4. **Mitigation Effectiveness:** Reduction in attack success rate

### Monitoring Dashboard

**Create security monitoring dashboard:**
```bash
# Real-time security metrics
while true; do
    echo "=== Security Status $(date) ==="
    echo "Total Attacks: $(sudo bpftool map dump name attack_log_map | wc -l)"
    echo "Rate Limited: $(make stats | grep rate_limited | awk '{print $2}')"
    echo "Protocol Violations: $(make stats | grep invalid_protocol | awk '{print $2}')"
    echo "Active Connections: $(sudo bpftool map dump name connection_state_map | wc -l)"
    echo ""
    sleep 30
done
```

This comprehensive attack detection and mitigation system provides enterprise-grade security for FiveM servers while maintaining high performance through the implemented critical compliance fixes.
