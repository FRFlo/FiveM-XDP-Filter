# Performance Tuning Guide

This document provides comprehensive guidelines for optimizing the FiveM XDP filter performance across different server sizes and deployment scenarios.

## Performance Overview

The FiveM XDP filter is designed for high-performance packet processing with sub-microsecond latency and support for 100K+ packets per second. Performance can be optimized through configuration tuning, feature selection, and system-level optimizations.

## Performance Metrics

### Key Performance Indicators

| Metric | Target | Measurement |
|--------|--------|-------------|
| **Processing Latency** | <1μs | Per-packet processing time |
| **Throughput** | 100K+ pps | Packets processed per second |
| **CPU Utilization** | <10% | CPU overhead at target load |
| **Memory Usage** | <100MB | BPF map memory consumption |
| **Drop Rate** | <0.1% | Legitimate packets dropped |

### Monitoring Commands

```bash
# Real-time performance statistics
make stats

# Detailed performance metrics
bpftool map dump name perf_metrics_map

# CPU utilization monitoring
top -p $(pgrep -f xdp)

# Network interface statistics
ip -s link show eth0
```

## Server Size Optimization

### Small Servers (≤32 players)

**Characteristics:**
- Low packet volume (1K-5K pps)
- Security-focused requirements
- CPU resources available

**Recommended Configuration:**
```bash
make config-small SERVER_IP=YOUR_IP
```

**Optimization Settings:**
```c
.rate_limit = 500,                  // Conservative rate limiting
.global_rate_limit = 10000,
.subnet_rate_limit = 2000,
.enable_checksum_validation = 1,    // Enable for security
.strict_enet_validation = 1         // Enable strict validation
```

**Performance Expectations:**
- Processing latency: 0.5-1.0μs
- CPU overhead: 2-5%
- Memory usage: 20-50MB

### Medium Servers (32-128 players)

**Characteristics:**
- Moderate packet volume (5K-25K pps)
- Balanced security and performance
- Standard hardware resources

**Recommended Configuration:**
```bash
make config-medium SERVER_IP=YOUR_IP
```

**Optimization Settings:**
```c
.rate_limit = 1000,                 // Standard rate limiting
.global_rate_limit = 50000,
.subnet_rate_limit = 5000,
.enable_checksum_validation = 1,    // Balanced security
.strict_enet_validation = 1
```

**Performance Expectations:**
- Processing latency: 0.8-1.5μs
- CPU overhead: 5-8%
- Memory usage: 50-80MB

### Large Servers (128+ players)

**Characteristics:**
- High packet volume (25K-100K+ pps)
- Performance-critical requirements
- Dedicated hardware resources

**Recommended Configuration:**
```bash
make config-large SERVER_IP=YOUR_IP
```

**Optimization Settings:**
```c
.rate_limit = 2000,                 // Higher rate limits
.global_rate_limit = 100000,
.subnet_rate_limit = 10000,
.enable_checksum_validation = 0,    // Disabled for performance
.strict_enet_validation = 0         // Relaxed validation
```

**Performance Expectations:**
- Processing latency: 1.0-2.0μs
- CPU overhead: 8-12%
- Memory usage: 80-100MB

## Feature-Specific Optimization

### Checksum Validation (Critical Fix)

**Performance Impact:** 5-10% CPU overhead

**Optimization Options:**

1. **Disable for High Performance:**
   ```c
   .enable_checksum_validation = 0
   ```
   - **Benefit:** Significant performance improvement
   - **Trade-off:** Reduced packet integrity checking

2. **Enable for Security:**
   ```c
   .enable_checksum_validation = 1
   ```
   - **Benefit:** Enhanced security and packet validation
   - **Trade-off:** Additional CPU overhead

**Recommendation:**
- **Enable:** Small/medium servers, security-critical environments
- **Disable:** Large servers, high-performance requirements

### Rate Limiting Optimization

**Performance Impact:** Varies with packet volume and limits

**Tuning Guidelines:**

1. **Per-IP Rate Limiting:**
   ```c
   // Conservative (high security)
   .rate_limit = 500;
   
   // Balanced (standard)
   .rate_limit = 1000;
   
   // Permissive (high performance)
   .rate_limit = 2000;
   ```

2. **Global Rate Limiting:**
   ```c
   // Small servers
   .global_rate_limit = 10000;
   
   // Medium servers
   .global_rate_limit = 50000;
   
   // Large servers
   .global_rate_limit = 100000;
   ```

**Optimization Strategy:**
- Start with conservative limits
- Monitor drop rates and adjust upward
- Balance security needs with performance requirements

### Map Size Optimization

**BPF Map Sizing:**

| Map | Default Size | Small Server | Large Server |
|-----|--------------|--------------|--------------|
| `rate_limit_map` | 10,000 | 5,000 | 20,000 |
| `enhanced_token_map` | 5,000 | 2,500 | 10,000 |
| `peer_sequence_map` | 4,096 | 2,048 | 8,192 |
| `connection_state_map` | 2,048 | 1,024 | 4,096 |

**Memory Impact:**
- Larger maps: Better performance, more memory usage
- Smaller maps: Lower memory usage, potential LRU evictions

## System-Level Optimizations

### CPU Affinity

**Bind XDP processing to specific CPU cores:**

```bash
# Bind network interrupts to specific cores
echo 2 > /proc/irq/24/smp_affinity_list

# Bind XDP program to specific cores
taskset -c 0,1 ./xdp_program
```

**Benefits:**
- Improved cache locality
- Reduced context switching
- Better performance isolation

### Network Interface Optimization

**Optimize network interface settings:**

```bash
# Increase ring buffer sizes
ethtool -G eth0 rx 4096 tx 4096

# Enable hardware offloading
ethtool -K eth0 gro on
ethtool -K eth0 gso on

# Optimize interrupt coalescing
ethtool -C eth0 rx-usecs 50 rx-frames 32
```

### Memory Optimization

**Optimize system memory settings:**

```bash
# Increase network buffer sizes
echo 'net.core.rmem_max = 134217728' >> /etc/sysctl.conf
echo 'net.core.wmem_max = 134217728' >> /etc/sysctl.conf

# Optimize BPF memory
echo 'kernel.bpf_stats_enabled = 1' >> /etc/sysctl.conf

# Apply settings
sysctl -p
```

## Performance Monitoring

### Real-time Monitoring

**Continuous performance monitoring script:**

```bash
#!/bin/bash
# performance_monitor.sh

while true; do
    echo "=== $(date) ==="
    
    # XDP filter statistics
    echo "Filter Statistics:"
    make stats | grep -E "(passed|dropped|rate_limited)"
    
    # Performance metrics
    echo "Performance Metrics:"
    bpftool map dump name perf_metrics_map | grep -E "(total_packets|processing_time)"
    
    # System resources
    echo "System Resources:"
    top -bn1 | grep -E "(Cpu|Mem)"
    
    echo ""
    sleep 5
done
```

### Performance Benchmarking

**Load testing script:**

```bash
#!/bin/bash
# load_test.sh

DURATION=60
RATE=10000

echo "Starting load test: ${RATE} pps for ${DURATION}s"

# Generate test traffic
hping3 -2 -p 30120 -i u100 -c $((RATE * DURATION)) TARGET_IP &

# Monitor performance
./performance_monitor.sh &
MONITOR_PID=$!

# Wait for test completion
sleep $DURATION

# Stop monitoring
kill $MONITOR_PID

echo "Load test completed"
```

## Troubleshooting Performance Issues

### High CPU Usage

**Symptoms:**
- CPU utilization >15%
- Increased processing latency
- System responsiveness issues

**Solutions:**
1. Disable checksum validation
2. Increase rate limits to reduce map operations
3. Optimize system-level settings
4. Consider hardware upgrade

**Diagnostic Commands:**
```bash
# Profile XDP program
perf record -g ./xdp_program
perf report

# Check map utilization
bpftool map show
```

### High Drop Rates

**Symptoms:**
- Legitimate packets being dropped
- Player connection issues
- Increased complaint reports

**Solutions:**
1. Increase rate limits
2. Disable strict validation
3. Check configuration parameters
4. Monitor attack patterns

**Diagnostic Commands:**
```bash
# Check drop statistics
make stats | grep dropped

# Analyze attack patterns
bpftool map dump name attack_log_map
```

### Memory Issues

**Symptoms:**
- Map allocation failures
- Increased memory usage
- System OOM events

**Solutions:**
1. Reduce map sizes
2. Optimize LRU eviction
3. Increase system memory
4. Monitor map utilization

**Diagnostic Commands:**
```bash
# Check memory usage
cat /proc/meminfo | grep -E "(MemTotal|MemFree|MemAvailable)"

# Monitor BPF memory
cat /proc/sys/kernel/bpf_stats_enabled
```

## Performance Best Practices

### Configuration Best Practices

1. **Start Conservative:** Begin with small server configuration
2. **Monitor Continuously:** Use automated monitoring scripts
3. **Adjust Gradually:** Make incremental configuration changes
4. **Test Thoroughly:** Validate changes in development environment
5. **Document Changes:** Keep performance tuning log

### Development Best Practices

1. **Profile Regularly:** Use perf tools for performance analysis
2. **Optimize Hot Paths:** Focus on frequently executed code
3. **Minimize Map Operations:** Reduce unnecessary map lookups
4. **Use Efficient Algorithms:** Prefer O(1) operations over O(n)
5. **Test at Scale:** Validate performance under realistic load

### Deployment Best Practices

1. **Hardware Sizing:** Ensure adequate CPU and memory resources
2. **Network Optimization:** Configure network interfaces optimally
3. **System Tuning:** Apply system-level optimizations
4. **Monitoring Setup:** Implement comprehensive monitoring
5. **Capacity Planning:** Plan for traffic growth and peak loads

## Performance Validation

### Acceptance Criteria

Before deploying to production, validate that the filter meets these criteria:

| Metric | Small Server | Medium Server | Large Server |
|--------|--------------|---------------|--------------|
| **Max Latency** | 2μs | 3μs | 5μs |
| **CPU Usage** | <5% | <8% | <12% |
| **Drop Rate** | <0.05% | <0.1% | <0.2% |
| **Memory Usage** | <50MB | <80MB | <100MB |

### Performance Testing Checklist

- [ ] Load testing at target packet rates
- [ ] Latency measurement under load
- [ ] CPU utilization monitoring
- [ ] Memory usage validation
- [ ] Drop rate analysis
- [ ] Attack simulation testing
- [ ] Configuration optimization
- [ ] System-level tuning
- [ ] Monitoring setup verification
- [ ] Documentation completion

This performance tuning guide ensures optimal FiveM XDP filter performance across all deployment scenarios while maintaining security and reliability requirements.
