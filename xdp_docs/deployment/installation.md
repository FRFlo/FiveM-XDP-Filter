# Installation Guide

This guide provides step-by-step instructions for installing and deploying the FiveM XDP filter with all critical compliance fixes.

## Prerequisites

### System Requirements

**Minimum Requirements:**
- Linux kernel 4.18+ (5.4+ recommended)
- 2+ CPU cores
- 4GB RAM
- Network interface with XDP support

**Recommended Requirements:**
- Linux kernel 5.10+ (latest stable)
- 4+ CPU cores
- 8GB RAM
- Dedicated network interface
- SSD storage for logs

### Software Dependencies

**Required Packages:**
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y \
    clang \
    llvm \
    libbpf-dev \
    linux-headers-$(uname -r) \
    build-essential \
    pkg-config

# CentOS/RHEL/Fedora
sudo dnf install -y \
    clang \
    llvm \
    libbpf-devel \
    kernel-headers \
    kernel-devel \
    gcc \
    make \
    pkg-config
```

**BPF Tools (Recommended):**
```bash
# Ubuntu/Debian
sudo apt install -y bpftool

# CentOS/RHEL/Fedora
sudo dnf install -y bpftool

# Or build from source
git clone https://github.com/libbpf/bpftool.git
cd bpftool/src
make && sudo make install
```

### Kernel Configuration Verification

**Check kernel support:**
```bash
# Verify XDP support
grep CONFIG_XDP /boot/config-$(uname -r)

# Check BPF support
grep CONFIG_BPF /boot/config-$(uname -r)

# Verify required features
zgrep -E "(CONFIG_XDP|CONFIG_BPF|CONFIG_NET_CLS_BPF)" /proc/config.gz
```

**Required kernel options:**
```
CONFIG_BPF=y
CONFIG_BPF_SYSCALL=y
CONFIG_XDP_SOCKETS=y
CONFIG_NET_CLS_BPF=y
CONFIG_NET_ACT_BPF=y
CONFIG_BPF_JIT=y
```

## Installation Steps

### Step 1: Download and Prepare

**Clone or download the FiveM XDP filter:**
```bash
# If using git
git clone <repository-url> fivem-xdp-filter
cd fivem-xdp-filter

# Or extract from archive
tar -xzf fivem-xdp-filter.tar.gz
cd fivem-xdp-filter
```

**Verify file integrity:**
```bash
# Check that all required files are present
ls -la fivem_xdp.c fivem_xdp_config.c Makefile

# Verify compliance fixes are implemented
grep -q "CRITICAL FIX" fivem_xdp.c && echo "✅ Compliance fixes present"
```

### Step 2: Build the Filter

**Compile the XDP filter and configuration tools:**
```bash
# Build everything
make all

# Verify successful compilation
ls -la fivem_xdp.o fivem_xdp_config
```

**Verify XDP program:**
```bash
# Test program loading (optional)
make verify
```

**Expected output:**
```
Building FiveM XDP filter with compliance fixes...
✅ XDP filter compiled successfully
Building configuration tool...
✅ Configuration tool compiled successfully
```

### Step 3: Network Interface Preparation

**Identify target network interface:**
```bash
# List available interfaces
ip link show

# Check interface capabilities
ethtool -i eth0
```

**Optimize interface settings (recommended):**
```bash
# Increase ring buffer sizes
sudo ethtool -G eth0 rx 4096 tx 4096

# Enable hardware offloading
sudo ethtool -K eth0 gro on gso on

# Optimize interrupt coalescing
sudo ethtool -C eth0 rx-usecs 50 rx-frames 32
```

### Step 4: Install XDP Filter

**Install the XDP filter on the network interface:**
```bash
# Install on primary interface (replace eth0 with your interface)
sudo make install INTERFACE=eth0
```

**Verify installation:**
```bash
# Check XDP program is loaded
ip link show eth0 | grep xdp

# Verify BPF maps are created
sudo bpftool map list | grep fivem
```

**Expected output:**
```
Installing XDP program...
✅ XDP filter installed on interface eth0

# Verification should show:
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 xdpgeneric qdisc fq state UP
```

### Step 5: Configure the Filter

**Configure for your server type and IP:**

**Small Server (≤32 players):**
```bash
make config-small SERVER_IP=192.168.1.100
```

**Medium Server (32-128 players):**
```bash
make config-medium SERVER_IP=203.0.113.50
```

**Large Server (128+ players):**
```bash
make config-large SERVER_IP=198.51.100.25
```

**Development Server:**
```bash
make config-dev SERVER_IP=127.0.0.1
```

**Verify configuration:**
```bash
# Check configuration is applied
sudo bpftool map dump name server_config_map
```

### Step 6: Verify Operation

**Check filter statistics:**
```bash
# View real-time statistics
make stats

# Monitor for a few minutes to ensure proper operation
watch -n 5 'make stats'
```

**Test with sample traffic:**
```bash
# Generate test traffic to your server
ping -c 10 YOUR_SERVER_IP

# Check that packets are being processed
make stats | grep -E "(passed|dropped)"
```

## Post-Installation Configuration

### System Service Setup (Recommended)

**Create systemd service for automatic startup:**

```bash
sudo tee /etc/systemd/system/fivem-xdp.service > /dev/null <<EOF
[Unit]
Description=FiveM XDP Filter
After=network.target
Wants=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/opt/fivem-xdp-filter
ExecStart=/usr/bin/make install INTERFACE=eth0
ExecStartPost=/usr/bin/make config-medium SERVER_IP=YOUR_SERVER_IP
ExecStop=/usr/bin/make uninstall INTERFACE=eth0
User=root

[Install]
WantedBy=multi-user.target
EOF
```

**Enable and start the service:**
```bash
# Reload systemd configuration
sudo systemctl daemon-reload

# Enable automatic startup
sudo systemctl enable fivem-xdp.service

# Start the service
sudo systemctl start fivem-xdp.service

# Check service status
sudo systemctl status fivem-xdp.service
```

### Monitoring Setup

**Install monitoring script:**
```bash
# Create monitoring directory
sudo mkdir -p /opt/fivem-xdp-monitor

# Install monitoring script
sudo tee /opt/fivem-xdp-monitor/monitor.sh > /dev/null <<'EOF'
#!/bin/bash
LOGFILE="/var/log/fivem-xdp.log"
while true; do
    echo "$(date): $(make stats | grep -E '(passed|dropped|rate_limited)')" >> $LOGFILE
    sleep 60
done
EOF

sudo chmod +x /opt/fivem-xdp-monitor/monitor.sh
```

**Create monitoring service:**
```bash
sudo tee /etc/systemd/system/fivem-xdp-monitor.service > /dev/null <<EOF
[Unit]
Description=FiveM XDP Filter Monitor
After=fivem-xdp.service
Requires=fivem-xdp.service

[Service]
Type=simple
ExecStart=/opt/fivem-xdp-monitor/monitor.sh
WorkingDirectory=/opt/fivem-xdp-filter
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable fivem-xdp-monitor.service
sudo systemctl start fivem-xdp-monitor.service
```

### Log Rotation Setup

**Configure log rotation:**
```bash
sudo tee /etc/logrotate.d/fivem-xdp > /dev/null <<EOF
/var/log/fivem-xdp.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
    postrotate
        systemctl reload fivem-xdp-monitor.service
    endscript
}
EOF
```

## Verification Checklist

After installation, verify the following:

- [ ] **XDP program loaded:** `ip link show | grep xdp`
- [ ] **BPF maps created:** `sudo bpftool map list | grep fivem`
- [ ] **Configuration applied:** `sudo bpftool map dump name server_config_map`
- [ ] **Statistics updating:** `make stats` shows non-zero values
- [ ] **No error messages:** Check system logs for errors
- [ ] **Service enabled:** `sudo systemctl is-enabled fivem-xdp.service`
- [ ] **Monitoring active:** `sudo systemctl is-active fivem-xdp-monitor.service`
- [ ] **Logs rotating:** Check `/var/log/fivem-xdp.log` exists

## Troubleshooting Installation Issues

### Common Issues

#### XDP Program Load Failure
**Error:** "Failed to load XDP program"
**Solutions:**
```bash
# Check kernel support
uname -r
grep CONFIG_XDP /boot/config-$(uname -r)

# Verify interface supports XDP
ethtool -i eth0 | grep driver

# Try generic XDP mode
sudo ip link set dev eth0 xdpgeneric obj fivem_xdp.o sec xdp_fivem_advanced
```

#### BPF Map Creation Failure
**Error:** "Failed to create BPF map"
**Solutions:**
```bash
# Check BPF filesystem
mount | grep bpf

# Mount BPF filesystem if missing
sudo mount -t bpf bpf /sys/fs/bpf

# Check memory limits
ulimit -l
sudo sysctl kernel.bpf_stats_enabled=1
```

#### Permission Denied
**Error:** "Permission denied" during installation
**Solutions:**
```bash
# Ensure running as root
sudo -i

# Check file permissions
chmod +x fivem_xdp_config
ls -la fivem_xdp.o

# Verify sudo configuration
sudo -l
```

#### Configuration Not Applied
**Error:** Configuration changes not taking effect
**Solutions:**
```bash
# Check map permissions
sudo bpftool map list | grep server_config

# Verify configuration tool
./fivem_xdp_config --help

# Manual configuration update
sudo bpftool map update name server_config_map key 0 value ...
```

### Getting Help

If you encounter issues not covered in this guide:

1. **Check system logs:**
   ```bash
   sudo journalctl -u fivem-xdp.service
   sudo dmesg | grep -i xdp
   ```

2. **Verify prerequisites:**
   ```bash
   ./check_prerequisites.sh
   ```

3. **Review troubleshooting guide:**
   See [troubleshooting.md](troubleshooting.md) for detailed solutions

4. **Collect diagnostic information:**
   ```bash
   ./collect_diagnostics.sh
   ```

## Next Steps

After successful installation:

1. **Configure for your server type:** See [configuration-examples.md](configuration-examples.md)
2. **Set up monitoring:** See [../security/monitoring.md](../security/monitoring.md)
3. **Integrate with FiveM:** See [integration.md](integration.md)
4. **Optimize performance:** See [../technical/performance-tuning.md](../technical/performance-tuning.md)

The FiveM XDP filter is now installed and ready to protect your server with all critical compliance fixes implemented.
