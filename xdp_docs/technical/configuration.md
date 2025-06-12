# Configuration Reference

This document details all configuration parameters and their effects on FiveM XDP filter behavior.

## Configuration Overview

The FiveM XDP filter uses a runtime configuration system that allows zero-downtime updates through BPF maps. Configuration is managed through the `server_config` structure and can be updated using the provided configuration tools.

## Configuration Structure

```c
struct server_config {
    __u32 server_ip;                    // Target server IP (0 = accept any)
    __u16 server_port;                  // Primary FiveM server port
    __u16 game_port1;                   // Internal game communication port
    __u16 game_port2;                   // Alternative game communication port
    __u32 rate_limit;                   // Packets per second per IP
    __u32 global_rate_limit;            // Global packets per second limit
    __u32 subnet_rate_limit;            // Subnet (/24) packets per second limit
    __u8 enable_checksum_validation;    // Enable/disable checksum validation
    __u8 strict_enet_validation;        // Enable strict ENet header validation
    __u8 reserved[3];                   // Reserved for future use
};
```

## Configuration Parameters

### Network Configuration

#### `server_ip` (Critical Fix)
**Type:** `__u32`  
**Default:** 0 (accept any IP)  
**Range:** Any valid IPv4 address or 0

**Description:** Target server IP address in host byte order.

**Values:**
- `0` - Accept packets to any IP (multi-server mode)
- `IP_ADDRESS` - Only accept packets to specific server IP

**Example:**
```c
config.server_ip = 0;                    // Multi-server mode
config.server_ip = 0xC0A80164;          // 192.168.1.100
```

**Impact:**
- **Security:** Prevents packet processing for unintended servers
- **Performance:** Early packet rejection for non-target traffic
- **Deployment:** Enables multi-server and load balancer setups

#### `server_port`
**Type:** `__u16`  
**Default:** 30120  
**Range:** 1-65535

**Description:** Primary FiveM server port for main game communication.

**Common Values:**
- `30120` - Standard FiveM server port
- `30121-30130` - Alternative server ports

#### `game_port1` / `game_port2`
**Type:** `__u16`  
**Default:** 6672 / 6673  
**Range:** 1-65535

**Description:** Internal game communication ports for voice and data.

**Usage:**
- Voice communication
- Internal game data synchronization
- Alternative communication channels

### Rate Limiting Configuration

#### `rate_limit` (Per-IP)
**Type:** `__u32`  
**Default:** 1000  
**Range:** 1-100000  
**Unit:** Packets per second

**Description:** Maximum packets per second allowed from a single IP address.

**Recommended Values:**
- **Small servers (≤32 players):** 500-1000
- **Medium servers (32-128 players):** 1000-1500
- **Large servers (128+ players):** 1500-2000
- **Development:** 10000+

**Impact:**
- **Security:** Prevents single-IP flooding attacks
- **Performance:** Reduces processing load from abusive clients
- **Gameplay:** May affect legitimate high-activity players if too low

#### `global_rate_limit`
**Type:** `__u32`  
**Default:** 50000  
**Range:** 1000-1000000  
**Unit:** Packets per second

**Description:** Maximum total packets per second processed by the filter.

**Recommended Values:**
- **Small servers:** 10000-25000
- **Medium servers:** 25000-75000
- **Large servers:** 75000-150000
- **Development:** 1000000

**Impact:**
- **Security:** Prevents server overload from distributed attacks
- **Performance:** Protects server resources during traffic spikes
- **Availability:** May drop legitimate traffic if set too low

#### `subnet_rate_limit`
**Type:** `__u32`  
**Default:** 5000  
**Range:** 100-50000  
**Unit:** Packets per second per /24 subnet

**Description:** Maximum packets per second allowed from a /24 subnet.

**Recommended Values:**
- **Small servers:** 2000-5000
- **Medium servers:** 5000-10000
- **Large servers:** 10000-20000
- **Development:** 100000

**Impact:**
- **Security:** Prevents subnet-based distributed attacks
- **Performance:** Limits impact from compromised network segments
- **Accessibility:** May affect legitimate users from shared networks

### Validation Configuration

#### `enable_checksum_validation` (Performance Fix)
**Type:** `__u8`  
**Default:** 1 (enabled)  
**Values:** 0 (disabled) / 1 (enabled)

**Description:** Enable or disable packet checksum validation using optimized FNV-1a hash.

**When to Enable:**
- Security-focused deployments
- Small to medium servers with CPU headroom
- Networks with potential packet corruption

**When to Disable:**
- High-performance requirements
- Large servers with CPU constraints
- Trusted network environments

**Impact:**
- **Security:** Detects corrupted or malicious packets
- **Performance:** ~5-10% CPU overhead when enabled
- **Reliability:** Improves packet integrity validation

#### `strict_enet_validation`
**Type:** `__u8`  
**Default:** 1 (enabled)  
**Values:** 0 (disabled) / 1 (enabled)

**Description:** Enable strict ENet header validation and sequence checking.

**When to Enable:**
- Security-critical environments
- Servers experiencing protocol attacks
- Production deployments

**When to Disable:**
- Development environments
- High-performance requirements
- Compatibility with modified clients

**Impact:**
- **Security:** Enhanced protocol compliance checking
- **Performance:** Minimal overhead (~1-2%)
- **Compatibility:** May reject non-standard ENet implementations

## Predefined Configurations

### Small Server Configuration
**Target:** ≤32 players  
**Focus:** Security and stability

```c
struct server_config small_config = {
    .server_ip = SERVER_IP,             // Configured IP
    .server_port = 30120,
    .game_port1 = 6672,
    .game_port2 = 6673,
    .rate_limit = 500,                  // Conservative limit
    .global_rate_limit = 10000,
    .subnet_rate_limit = 2000,
    .enable_checksum_validation = 1,    // Security enabled
    .strict_enet_validation = 1
};
```

### Medium Server Configuration
**Target:** 32-128 players  
**Focus:** Balanced security and performance

```c
struct server_config medium_config = {
    .server_ip = SERVER_IP,
    .server_port = 30120,
    .game_port1 = 6672,
    .game_port2 = 6673,
    .rate_limit = 1000,                 // Standard limit
    .global_rate_limit = 50000,
    .subnet_rate_limit = 5000,
    .enable_checksum_validation = 1,
    .strict_enet_validation = 1
};
```

### Large Server Configuration
**Target:** 128+ players  
**Focus:** Maximum performance

```c
struct server_config large_config = {
    .server_ip = SERVER_IP,
    .server_port = 30120,
    .game_port1 = 6672,
    .game_port2 = 6673,
    .rate_limit = 2000,                 // Higher limit
    .global_rate_limit = 100000,
    .subnet_rate_limit = 10000,
    .enable_checksum_validation = 0,    // Performance optimized
    .strict_enet_validation = 0
};
```

### Development Configuration
**Target:** Testing and development  
**Focus:** Permissive settings

```c
struct server_config dev_config = {
    .server_ip = 0,                     // Accept any IP
    .server_port = 30120,
    .game_port1 = 6672,
    .game_port2 = 6673,
    .rate_limit = 10000,                // Very high limits
    .global_rate_limit = 1000000,
    .subnet_rate_limit = 100000,
    .enable_checksum_validation = 0,    // Disabled for testing
    .strict_enet_validation = 0
};
```

## Configuration Management

### Runtime Updates
Configuration can be updated at runtime without restarting the XDP filter:

```bash
# Update configuration using the helper tool
./fivem_xdp_config 192.168.1.100 medium

# Or use custom configuration
./fivem_xdp_config 192.168.1.100 custom /path/to/custom/config
```

### Configuration Validation
The filter validates configuration parameters and falls back to defaults for invalid values:

```c
// Example fallback logic
__u32 rate_limit = config ? config->rate_limit : DEFAULT_RATE_LIMIT;
if (rate_limit == 0 || rate_limit > 100000) {
    rate_limit = DEFAULT_RATE_LIMIT;
}
```

### Configuration Monitoring
Monitor current configuration through BPF map inspection:

```bash
# View current configuration
bpftool map dump name server_config_map

# Monitor configuration changes
watch -n 1 'bpftool map dump name server_config_map'
```

## Performance Impact

### Rate Limiting Impact
| Parameter | Low Setting | High Setting | Performance Impact |
|-----------|-------------|--------------|-------------------|
| `rate_limit` | 100-500 | 2000+ | Minimal |
| `global_rate_limit` | 1K-10K | 100K+ | Low |
| `subnet_rate_limit` | 500-2K | 20K+ | Minimal |

### Validation Impact
| Feature | Enabled | Disabled | CPU Overhead |
|---------|---------|----------|--------------|
| `enable_checksum_validation` | Security++ | Performance++ | 5-10% |
| `strict_enet_validation` | Security+ | Performance+ | 1-2% |

## Troubleshooting Configuration

### Common Issues

#### Packets Being Dropped
**Symptoms:** Legitimate traffic being blocked  
**Solutions:**
- Increase rate limits
- Disable strict validation
- Check server IP configuration

#### Poor Performance
**Symptoms:** High CPU usage, packet processing delays  
**Solutions:**
- Disable checksum validation
- Increase rate limits to reduce map operations
- Use large server configuration

#### Security Concerns
**Symptoms:** Attacks not being detected  
**Solutions:**
- Enable all validation features
- Decrease rate limits
- Use small server configuration

### Configuration Testing
```bash
# Test configuration with monitoring
make config-test SERVER_IP=192.168.1.100
make stats

# Load test with different configurations
./load_test.sh --config small
./load_test.sh --config large
```

## Best Practices

1. **Start Conservative:** Begin with small server configuration and adjust based on monitoring
2. **Monitor Performance:** Use `make stats` to track filter performance
3. **Test Changes:** Validate configuration changes in development environment first
4. **Document Settings:** Keep record of configuration changes and their impact
5. **Regular Review:** Periodically review and optimize configuration based on server growth
