# Troubleshooting Guide

This guide provides comprehensive solutions for common deployment issues, error messages, and runtime problems with the FiveM XDP filter.

## Quick Diagnostic Commands

Before diving into specific issues, run these diagnostic commands to gather system information:

```bash
# System information
uname -r                                    # Kernel version
lsb_release -a                             # OS version
ip link show                               # Network interfaces
lsmod | grep bpf                           # BPF modules loaded

# XDP filter status
ip link show | grep xdp                    # XDP programs loaded
sudo bpftool prog list | grep xdp          # BPF programs
sudo bpftool map list | grep fivem         # BPF maps
make stats                                 # Filter statistics
```

## Installation Issues

### Issue 1: XDP Program Load Failure

**Symptoms:**
```
Error: Failed to load XDP program
RTNETLINK answers: Invalid argument
```

**Diagnosis:**
```bash
# Check kernel support
grep CONFIG_XDP /boot/config-$(uname -r)
grep CONFIG_BPF /boot/config-$(uname -r)

# Check interface capabilities
ethtool -i eth0 | grep driver
```

**Solutions:**

#### Solution 1A: Missing Kernel Support
```bash
# Install kernel with XDP support
sudo apt update
sudo apt install linux-image-generic linux-headers-generic

# Reboot to new kernel
sudo reboot

# Verify support after reboot
grep CONFIG_XDP /boot/config-$(uname -r)
```

#### Solution 1B: Interface Doesn't Support XDP
```bash
# Try generic XDP mode (software fallback)
sudo ip link set dev eth0 xdpgeneric obj fivem_xdp.o sec xdp_fivem_advanced

# Or use different interface
ip link show | grep -E "(eth|ens|enp)"
sudo make install INTERFACE=ens33
```

#### Solution 1C: BPF Verifier Rejection
```bash
# Enable BPF debugging
echo 1 > /sys/kernel/debug/tracing/events/bpf/enable

# Check verifier logs
dmesg | grep -i bpf | tail -20

# Rebuild with debug information
make clean
make CFLAGS="-g -O0 -DDEBUG" all
```

### Issue 2: Permission Denied Errors

**Symptoms:**
```
Permission denied
Operation not permitted
```

**Diagnosis:**
```bash
# Check user privileges
id
sudo -l

# Check file permissions
ls -la fivem_xdp.o fivem_xdp_config
```

**Solutions:**

#### Solution 2A: Insufficient Privileges
```bash
# Use sudo for installation
sudo make install INTERFACE=eth0

# Or switch to root
sudo -i
cd /path/to/fivem-xdp-filter
make install INTERFACE=eth0
```

#### Solution 2B: SELinux/AppArmor Restrictions
```bash
# Check SELinux status
sestatus

# Temporarily disable SELinux (if needed)
sudo setenforce 0

# Check AppArmor
sudo aa-status

# Create SELinux policy (if needed)
sudo setsebool -P domain_can_mmap_files 1
```

### Issue 3: BPF Map Creation Failure

**Symptoms:**
```
Failed to create BPF map
Cannot allocate memory
```

**Diagnosis:**
```bash
# Check memory limits
ulimit -l
cat /proc/sys/kernel/bpf_stats_enabled

# Check available memory
free -h
cat /proc/meminfo | grep -E "(MemTotal|MemFree)"
```

**Solutions:**

#### Solution 3A: Increase Memory Limits
```bash
# Increase locked memory limit
ulimit -l unlimited

# Make permanent
echo "* soft memlock unlimited" >> /etc/security/limits.conf
echo "* hard memlock unlimited" >> /etc/security/limits.conf

# Enable BPF statistics
echo 1 > /proc/sys/kernel/bpf_stats_enabled
```

#### Solution 3B: Mount BPF Filesystem
```bash
# Check if BPF filesystem is mounted
mount | grep bpf

# Mount BPF filesystem
sudo mkdir -p /sys/fs/bpf
sudo mount -t bpf bpf /sys/fs/bpf

# Make permanent
echo "bpf /sys/fs/bpf bpf defaults 0 0" >> /etc/fstab
```

## Configuration Issues

### Issue 4: Configuration Not Applied

**Symptoms:**
- Configuration changes don't take effect
- Filter uses default values instead of configured values

**Diagnosis:**
```bash
# Check configuration map
sudo bpftool map dump name server_config_map

# Verify configuration tool
./fivem_xdp_config --help
ls -la fivem_xdp_config

# Check map permissions
sudo bpftool map list | grep server_config
```

**Solutions:**

#### Solution 4A: Configuration Tool Issues
```bash
# Rebuild configuration tool
make clean
make fivem_xdp_config

# Set executable permissions
chmod +x fivem_xdp_config

# Run with sudo if needed
sudo ./fivem_xdp_config 192.168.1.100 medium
```

#### Solution 4B: Map Access Issues
```bash
# Check map pinning
ls -la /sys/fs/bpf/

# Manually update configuration
sudo bpftool map update name server_config_map key 0 value \
    hex 64 00 a8 c0 78 75 10 1a 11 1a e8 03 00 00 c3 50 00 00 88 13 00 00 01 01 00
```

### Issue 5: Invalid Server IP Configuration

**Symptoms:**
- All packets being dropped
- No traffic reaching FiveM server

**Diagnosis:**
```bash
# Check current configuration
sudo bpftool map dump name server_config_map

# Check server IP
ip addr show | grep inet

# Test connectivity
ping YOUR_SERVER_IP
```

**Solutions:**

#### Solution 5A: Correct Server IP
```bash
# Get correct server IP
SERVER_IP=$(ip route get 8.8.8.8 | awk '{print $7}' | head -1)

# Reconfigure with correct IP
make config-medium SERVER_IP=$SERVER_IP

# Or use multi-server mode (accept any IP)
./fivem_xdp_config 0.0.0.0 medium
```

## Runtime Issues

### Issue 6: High Packet Drop Rate

**Symptoms:**
- Legitimate players can't connect
- High drop rate in statistics

**Diagnosis:**
```bash
# Check statistics
make stats | grep -E "(dropped|rate_limited)"

# Check attack log
sudo bpftool map dump name attack_log_map | tail -10

# Monitor real-time
watch -n 1 'make stats'
```

**Solutions:**

#### Solution 6A: Rate Limits Too Restrictive
```bash
# Increase rate limits temporarily
./fivem_xdp_config YOUR_SERVER_IP dev

# Monitor and adjust
make stats

# Apply appropriate configuration
make config-large SERVER_IP=YOUR_SERVER_IP
```

#### Solution 6B: Disable Strict Validation
```bash
# Create custom configuration with relaxed validation
./fivem_xdp_config YOUR_SERVER_IP custom << EOF
{
    "server_ip": "YOUR_SERVER_IP",
    "rate_limit": 2000,
    "global_rate_limit": 100000,
    "enable_checksum_validation": 0,
    "strict_enet_validation": 0
}
EOF
```

### Issue 7: Performance Problems

**Symptoms:**
- High CPU usage
- Increased latency
- Server performance degradation

**Diagnosis:**
```bash
# Check CPU usage
top -p $(pgrep -f xdp)

# Check performance metrics
sudo bpftool map dump name perf_metrics_map

# Monitor processing time
watch -n 1 'sudo bpftool map dump name perf_metrics_map | grep processing_time'
```

**Solutions:**

#### Solution 7A: Optimize Configuration
```bash
# Use performance-optimized configuration
make config-large SERVER_IP=YOUR_SERVER_IP

# Disable expensive features
./fivem_xdp_config YOUR_SERVER_IP custom << EOF
{
    "enable_checksum_validation": 0,
    "strict_enet_validation": 0,
    "rate_limit": 5000
}
EOF
```

#### Solution 7B: System-Level Optimizations
```bash
# CPU affinity for network interrupts
echo 2 > /proc/irq/24/smp_affinity_list

# Network interface optimizations
sudo ethtool -G eth0 rx 4096 tx 4096
sudo ethtool -K eth0 gro on gso on

# System tuning
echo 'net.core.rmem_max = 134217728' >> /etc/sysctl.conf
echo 'net.core.wmem_max = 134217728' >> /etc/sysctl.conf
sudo sysctl -p
```

## Network Issues

### Issue 8: FiveM Server Connection Problems

**Symptoms:**
- Players can't connect to FiveM server
- Connection timeouts
- Intermittent connectivity

**Diagnosis:**
```bash
# Check FiveM server status
netstat -tulpn | grep :30120

# Test direct connectivity
telnet YOUR_SERVER_IP 30120

# Check XDP filter statistics
make stats | grep passed
```

**Solutions:**

#### Solution 8A: Port Configuration
```bash
# Verify port configuration
sudo bpftool map dump name server_config_map | grep -E "(server_port|game_port)"

# Update port configuration if needed
./fivem_xdp_config YOUR_SERVER_IP custom << EOF
{
    "server_port": 30120,
    "game_port1": 6672,
    "game_port2": 6673
}
EOF
```

#### Solution 8B: Firewall Integration
```bash
# Check iptables rules
sudo iptables -L -n

# Ensure XDP filter doesn't conflict with iptables
sudo iptables -I INPUT -p udp --dport 30120 -j ACCEPT
sudo iptables -I INPUT -p udp --dport 6672:6673 -j ACCEPT
```

## Monitoring and Logging Issues

### Issue 9: No Statistics Available

**Symptoms:**
- `make stats` shows no data
- BPF maps appear empty

**Diagnosis:**
```bash
# Check if XDP program is loaded
ip link show | grep xdp

# Check BPF maps
sudo bpftool map list | grep fivem

# Check map contents
sudo bpftool map dump name enhanced_stats_map
```

**Solutions:**

#### Solution 9A: Reload XDP Program
```bash
# Uninstall and reinstall
sudo make uninstall INTERFACE=eth0
sudo make install INTERFACE=eth0

# Reconfigure
make config-medium SERVER_IP=YOUR_SERVER_IP
```

#### Solution 9B: Generate Test Traffic
```bash
# Generate test traffic to populate statistics
ping -c 10 YOUR_SERVER_IP

# Check if statistics update
make stats
```

## Advanced Troubleshooting

### Diagnostic Script

Create a comprehensive diagnostic script:

```bash
#!/bin/bash
# diagnose.sh - FiveM XDP Filter Diagnostic Script

echo "=== FiveM XDP Filter Diagnostics ==="
echo "Date: $(date)"
echo ""

echo "=== System Information ==="
echo "Kernel: $(uname -r)"
echo "OS: $(lsb_release -d | cut -f2)"
echo "Architecture: $(uname -m)"
echo ""

echo "=== Kernel Support ==="
echo "XDP Support: $(grep -q CONFIG_XDP=y /boot/config-$(uname -r) && echo "YES" || echo "NO")"
echo "BPF Support: $(grep -q CONFIG_BPF=y /boot/config-$(uname -r) && echo "YES" || echo "NO")"
echo ""

echo "=== Network Interfaces ==="
ip link show | grep -E "(eth|ens|enp)"
echo ""

echo "=== XDP Programs ==="
ip link show | grep xdp || echo "No XDP programs loaded"
echo ""

echo "=== BPF Maps ==="
sudo bpftool map list | grep fivem || echo "No FiveM BPF maps found"
echo ""

echo "=== Filter Statistics ==="
make stats 2>/dev/null || echo "Unable to retrieve statistics"
echo ""

echo "=== Recent Kernel Messages ==="
dmesg | grep -i -E "(xdp|bpf)" | tail -5
echo ""

echo "=== Memory Information ==="
echo "Memory Limit: $(ulimit -l)"
echo "Available Memory: $(free -h | grep Mem | awk '{print $7}')"
echo ""

echo "=== Diagnostic Complete ==="
```

### Log Collection Script

```bash
#!/bin/bash
# collect_logs.sh - Collect diagnostic information

LOGDIR="/tmp/fivem-xdp-diagnostics-$(date +%Y%m%d-%H%M%S)"
mkdir -p $LOGDIR

echo "Collecting diagnostic information in $LOGDIR..."

# System information
uname -a > $LOGDIR/system_info.txt
lsb_release -a > $LOGDIR/os_info.txt 2>/dev/null
cat /proc/version > $LOGDIR/kernel_info.txt

# Network configuration
ip link show > $LOGDIR/network_interfaces.txt
ip addr show > $LOGDIR/ip_addresses.txt
ip route show > $LOGDIR/routing_table.txt

# XDP and BPF information
ip link show | grep xdp > $LOGDIR/xdp_programs.txt
sudo bpftool prog list > $LOGDIR/bpf_programs.txt 2>/dev/null
sudo bpftool map list > $LOGDIR/bpf_maps.txt 2>/dev/null

# Filter statistics
make stats > $LOGDIR/filter_stats.txt 2>&1

# System logs
dmesg | grep -i -E "(xdp|bpf)" > $LOGDIR/kernel_messages.txt
journalctl -u fivem-xdp.service > $LOGDIR/service_logs.txt 2>/dev/null

# Configuration
sudo bpftool map dump name server_config_map > $LOGDIR/current_config.txt 2>/dev/null

echo "Diagnostic information collected in $LOGDIR"
echo "Please include this directory when reporting issues."
```

## Getting Help

### Before Reporting Issues

1. **Run diagnostic script:** `./diagnose.sh`
2. **Collect logs:** `./collect_logs.sh`
3. **Check documentation:** Review relevant sections
4. **Search existing issues:** Check if problem is already known

### Reporting Issues

When reporting issues, include:

- **System information:** OS, kernel version, hardware
- **Error messages:** Complete error output
- **Configuration:** Current filter configuration
- **Steps to reproduce:** Detailed reproduction steps
- **Diagnostic output:** Results from diagnostic scripts

### Emergency Procedures

#### Complete Filter Removal
```bash
# Remove XDP filter completely
sudo make uninstall INTERFACE=eth0

# Clean up BPF maps
sudo rm -f /sys/fs/bpf/fivem_*

# Restart networking
sudo systemctl restart networking
```

#### Fallback to Iptables
```bash
# Disable XDP filter
sudo make uninstall INTERFACE=eth0

# Implement basic iptables protection
sudo iptables -A INPUT -p udp --dport 30120 -m limit --limit 100/sec -j ACCEPT
sudo iptables -A INPUT -p udp --dport 30120 -j DROP
```

This troubleshooting guide covers the most common issues encountered during deployment and operation of the FiveM XDP filter. For additional support, refer to the other documentation sections or contact the development team.
