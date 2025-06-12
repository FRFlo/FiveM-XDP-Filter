# Configuration Examples

This document provides practical configuration examples for different FiveM server types and deployment scenarios, showcasing the critical compliance fixes implemented in the XDP filter.

## Quick Configuration Commands

### Standard Server Types

```bash
# Small community server (≤32 players)
make config-small SERVER_IP=192.168.1.100

# Medium popular server (32-128 players)  
make config-medium SERVER_IP=203.0.113.50

# Large high-traffic server (128+ players)
make config-large SERVER_IP=198.51.100.25

# Development/testing server
make config-dev SERVER_IP=127.0.0.1
```

## Detailed Configuration Examples

### Small Community Server

**Scenario:** Community roleplay server with 32 player slots
**Focus:** Maximum security with moderate performance requirements

```bash
# Configuration command
./fivem_xdp_config 192.168.1.100 small

# Equivalent manual configuration
./fivem_xdp_config 192.168.1.100 custom << EOF
{
    "server_ip": "192.168.1.100",
    "server_port": 30120,
    "game_port1": 6672,
    "game_port2": 6673,
    "rate_limit": 500,
    "global_rate_limit": 10000,
    "subnet_rate_limit": 2000,
    "enable_checksum_validation": true,
    "strict_enet_validation": true
}
EOF
```

**Configuration Details:**
- **Rate Limiting:** Conservative limits to prevent abuse
- **Security:** All validation features enabled
- **Performance:** Optimized for security over raw performance
- **Memory Usage:** ~30MB for maps and tracking

**Expected Performance:**
- Packet processing: 0.5-1.0μs latency
- CPU overhead: 2-5%
- Supports: 1K-5K packets per second

### Medium Popular Server

**Scenario:** Popular public server with 64-128 player slots
**Focus:** Balanced security and performance

```bash
# Configuration command
./fivem_xdp_config 203.0.113.50 medium
```

**Advanced Configuration:**
```c
struct server_config medium_config = {
    .server_ip = 0xCB007132,           // 203.0.113.50 in host byte order
    .server_port = 30120,
    .game_port1 = 6672,
    .game_port2 = 6673,
    .rate_limit = 1000,               // Standard rate limit
    .global_rate_limit = 50000,       // Balanced global limit
    .subnet_rate_limit = 5000,        // Moderate subnet protection
    .enable_checksum_validation = 1,   // Security enabled
    .strict_enet_validation = 1,       // Protocol compliance enabled
    .reserved = {0, 0, 0}
};
```

**Monitoring Setup:**
```bash
# Real-time monitoring
watch -n 5 'make stats | head -20'

# Performance tracking
while true; do
    echo "$(date): $(make stats | grep -E 'passed|dropped|rate_limited')" >> /var/log/fivem-xdp.log
    sleep 60
done
```

**Expected Performance:**
- Packet processing: 0.8-1.5μs latency
- CPU overhead: 5-8%
- Supports: 5K-25K packets per second

### Large High-Traffic Server

**Scenario:** High-capacity server with 200+ player slots
**Focus:** Maximum performance with essential security

```bash
# Configuration command
./fivem_xdp_config 198.51.100.25 large
```

**Performance-Optimized Configuration:**
```c
struct server_config large_config = {
    .server_ip = 0xC6336419,           // 198.51.100.25 in host byte order
    .server_port = 30120,
    .game_port1 = 6672,
    .game_port2 = 6673,
    .rate_limit = 2000,               // Higher per-IP limit
    .global_rate_limit = 100000,      // High global throughput
    .subnet_rate_limit = 10000,       // Relaxed subnet limits
    .enable_checksum_validation = 0,   // DISABLED for performance
    .strict_enet_validation = 0,       // RELAXED for performance
    .reserved = {0, 0, 0}
};
```

**System Optimizations:**
```bash
# CPU affinity for network interrupts
echo 2 > /proc/irq/24/smp_affinity_list

# Network interface optimizations
ethtool -G eth0 rx 4096 tx 4096
ethtool -K eth0 gro on gso on
ethtool -C eth0 rx-usecs 25 rx-frames 16

# System tuning
echo 'net.core.rmem_max = 134217728' >> /etc/sysctl.conf
echo 'net.core.wmem_max = 134217728' >> /etc/sysctl.conf
sysctl -p
```

**Expected Performance:**
- Packet processing: 1.0-2.0μs latency
- CPU overhead: 8-12%
- Supports: 25K-100K+ packets per second

### Development Server

**Scenario:** Development and testing environment
**Focus:** Permissive settings for debugging and testing

```bash
# Configuration command
./fivem_xdp_config 127.0.0.1 dev
```

**Development Configuration:**
```c
struct server_config dev_config = {
    .server_ip = 0,                   // Accept ANY IP (multi-server mode)
    .server_port = 30120,
    .game_port1 = 6672,
    .game_port2 = 6673,
    .rate_limit = 10000,              // Very high limits
    .global_rate_limit = 1000000,     // Essentially unlimited
    .subnet_rate_limit = 100000,      // Very permissive
    .enable_checksum_validation = 0,   // Disabled for testing
    .strict_enet_validation = 0,       // Disabled for compatibility
    .reserved = {0, 0, 0}
};
```

**Development Features:**
- **Multi-server support:** `server_ip = 0` accepts packets to any IP
- **Permissive limits:** High rate limits for load testing
- **Disabled validation:** Allows testing with modified clients
- **Debug-friendly:** Minimal packet rejection for troubleshooting

## Specialized Deployment Scenarios

### Multi-Server Load Balancer Setup

**Scenario:** Multiple FiveM servers behind a load balancer
**Challenge:** Filter needs to accept packets to multiple server IPs

```bash
# Configure for multi-server mode (accepts any destination IP)
./fivem_xdp_config 0.0.0.0 medium

# Or use custom configuration
./fivem_xdp_config_custom << EOF
{
    "server_ip": 0,                   // Accept packets to ANY IP
    "server_port": 30120,
    "game_port1": 6672,
    "game_port2": 6673,
    "rate_limit": 1500,               // Higher limit for multiple servers
    "global_rate_limit": 75000,       // Increased global capacity
    "subnet_rate_limit": 7500,
    "enable_checksum_validation": 1,
    "strict_enet_validation": 1
}
EOF
```

**Load Balancer Integration:**
```bash
# Configure on each backend server
for server in 10.0.1.10 10.0.1.11 10.0.1.12; do
    ssh root@$server "cd /opt/fivem-xdp && make config-medium SERVER_IP=0"
done
```

### Cloud Deployment (AWS/GCP/Azure)

**Scenario:** FiveM server deployed in cloud environment
**Considerations:** Dynamic IPs, cloud networking, security groups

```bash
# Get instance metadata for IP configuration
INSTANCE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

# Configure for cloud deployment
./fivem_xdp_config $INSTANCE_IP medium

# Alternative: Accept both private and public IPs
./fivem_xdp_config 0 medium  # Accept any IP
```

**Cloud-Specific Optimizations:**
```bash
# Enhanced network performance for cloud instances
ethtool -K eth0 sg on tso on gso on gro on lro on
echo 'net.core.default_qdisc = fq' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_congestion_control = bbr' >> /etc/sysctl.conf
```

### High-Security Environment

**Scenario:** Server requiring maximum security (government, enterprise)
**Focus:** All security features enabled with conservative limits

```bash
# Ultra-secure configuration
./fivem_xdp_config_secure 192.168.100.50 << EOF
{
    "server_ip": "192.168.100.50",
    "server_port": 30120,
    "game_port1": 6672,
    "game_port2": 6673,
    "rate_limit": 200,                // Very conservative
    "global_rate_limit": 5000,        // Low global limit
    "subnet_rate_limit": 1000,        // Strict subnet limits
    "enable_checksum_validation": 1,   // REQUIRED
    "strict_enet_validation": 1,       // REQUIRED
    "enable_geo_blocking": 1,          // Custom extension
    "enable_deep_inspection": 1        // Custom extension
}
EOF
```

**Additional Security Measures:**
```bash
# Enable comprehensive logging
echo 'kernel.bpf_stats_enabled = 1' >> /etc/sysctl.conf

# Set up real-time alerting
./setup_security_monitoring.sh

# Configure fail2ban integration
./configure_fail2ban.sh
```

## Configuration Validation

### Verify Configuration Applied

```bash
# Check current configuration
sudo bpftool map dump name server_config_map

# Verify specific settings
sudo bpftool map lookup name server_config_map key 0 | grep -E "(server_ip|rate_limit)"

# Test configuration with sample traffic
ping -c 10 YOUR_SERVER_IP
make stats | grep passed
```

### Configuration Testing

```bash
# Test rate limiting
./test_rate_limits.sh YOUR_SERVER_IP

# Test security features
./test_security_features.sh YOUR_SERVER_IP

# Performance validation
./performance_test.sh YOUR_SERVER_IP
```

## Dynamic Configuration Updates

### Runtime Configuration Changes

```bash
# Update rate limits without restart
./fivem_xdp_config YOUR_SERVER_IP custom << EOF
{
    "rate_limit": 1500,               // Increased limit
    "global_rate_limit": 60000,       // Increased global limit
    "enable_checksum_validation": 0    // Disabled for performance
}
EOF

# Verify changes applied
make stats
```

### Automated Configuration Management

```bash
# Configuration management script
#!/bin/bash
# auto_config.sh

CURRENT_HOUR=$(date +%H)
PLAYER_COUNT=$(get_player_count.sh)

if [ $CURRENT_HOUR -ge 18 ] && [ $CURRENT_HOUR -le 23 ]; then
    # Peak hours - higher limits
    ./fivem_xdp_config $SERVER_IP large
elif [ $PLAYER_COUNT -lt 20 ]; then
    # Low activity - security focused
    ./fivem_xdp_config $SERVER_IP small
else
    # Normal operation
    ./fivem_xdp_config $SERVER_IP medium
fi
```

## Troubleshooting Configuration Issues

### Common Configuration Problems

#### Configuration Not Applied
```bash
# Check if configuration tool has permissions
ls -la fivem_xdp_config
sudo ./fivem_xdp_config YOUR_SERVER_IP medium

# Verify BPF map exists
sudo bpftool map list | grep server_config
```

#### Performance Issues After Configuration
```bash
# Check if limits are too restrictive
make stats | grep rate_limited

# Temporarily increase limits
./fivem_xdp_config YOUR_SERVER_IP dev

# Monitor and adjust
watch -n 5 'make stats'
```

#### Security Features Not Working
```bash
# Verify security features are enabled
sudo bpftool map dump name server_config_map | grep validation

# Check attack detection
sudo bpftool map dump name attack_log_map

# Enable debug logging
echo 1 > /sys/kernel/debug/tracing/events/xdp/enable
```

## Best Practices

1. **Start Conservative:** Begin with small server configuration and adjust based on monitoring
2. **Monitor Continuously:** Use automated monitoring to track performance and security
3. **Test Changes:** Validate configuration changes in development environment first
4. **Document Settings:** Keep record of configuration changes and their impact
5. **Regular Review:** Periodically review and optimize configuration based on server growth

These configuration examples demonstrate the flexibility and power of the FiveM XDP filter with all critical compliance fixes implemented, enabling secure and high-performance FiveM server protection.
