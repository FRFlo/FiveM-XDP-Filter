# Integration Guide

This guide provides detailed instructions for integrating the FiveM XDP filter with existing FiveM server setups, including network architecture considerations, firewall rules, and compatibility with other security tools.

## Integration Overview

The FiveM XDP filter operates at the kernel level, providing the first line of defense before packets reach the FiveM server application. This positioning allows for optimal performance while maintaining compatibility with existing security infrastructure.

```
Internet Traffic
      ↓
┌─────────────────┐
│  Network Edge   │ ← Firewall, DDoS Protection
│   (Router/FW)   │
└─────────────────┘
      ↓
┌─────────────────┐
│  XDP Filter     │ ← FiveM XDP Filter (Kernel Level)
│ (Kernel Space)  │
└─────────────────┘
      ↓
┌─────────────────┐
│   iptables      │ ← Host-based Firewall
│ (Netfilter)     │
└─────────────────┘
      ↓
┌─────────────────┐
│  FiveM Server   │ ← Application Level
│ (User Space)    │
└─────────────────┘
```

## Pre-Integration Assessment

### Current Infrastructure Analysis

Before integration, assess your current setup:

```bash
# Document current network configuration
ip addr show > current_network_config.txt
ip route show > current_routing.txt
iptables-save > current_iptables_rules.txt

# Check running services
netstat -tulpn | grep -E "(30120|6672|6673)" > fivem_ports.txt

# Document current security tools
systemctl list-units | grep -E "(fail2ban|ufw|firewalld)" > security_services.txt

# Check system resources
free -h > memory_info.txt
lscpu > cpu_info.txt
```

### Compatibility Check

```bash
# Verify kernel compatibility
./check_compatibility.sh

# Test XDP support
make verify

# Check for conflicting software
ps aux | grep -E "(ddos|firewall|security)"
```

## Network Architecture Integration

### Single Server Setup

**Simple deployment with one FiveM server:**

```
Internet → Router → Server (XDP Filter + FiveM)
```

**Configuration:**
```bash
# Install XDP filter on primary interface
sudo make install INTERFACE=eth0

# Configure for single server
make config-medium SERVER_IP=$(ip route get 8.8.8.8 | awk '{print $7}')

# Verify configuration
make stats
```

### Multi-Server Setup

**Multiple FiveM servers behind load balancer:**

```
Internet → Load Balancer → Server1 (XDP + FiveM)
                       → Server2 (XDP + FiveM)
                       → Server3 (XDP + FiveM)
```

**Configuration:**
```bash
# Configure each server for multi-server mode
for server in server1 server2 server3; do
    ssh root@$server "cd /opt/fivem-xdp && make config-medium SERVER_IP=0"
done

# Load balancer configuration (HAProxy example)
cat >> /etc/haproxy/haproxy.cfg << EOF
frontend fivem_frontend
    bind *:30120
    mode udp
    default_backend fivem_servers

backend fivem_servers
    mode udp
    balance roundrobin
    server server1 10.0.1.10:30120 check
    server server2 10.0.1.11:30120 check
    server server3 10.0.1.12:30120 check
EOF
```

### Cloud Integration

#### AWS Integration

**VPC Setup with XDP Filter:**
```bash
# Install on EC2 instance
sudo make install INTERFACE=eth0

# Configure for AWS private IP
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
make config-medium SERVER_IP=$PRIVATE_IP

# Security Group Rules (AWS CLI)
aws ec2 authorize-security-group-ingress \
    --group-id sg-xxxxxxxxx \
    --protocol udp \
    --port 30120 \
    --cidr 0.0.0.0/0

aws ec2 authorize-security-group-ingress \
    --group-id sg-xxxxxxxxx \
    --protocol udp \
    --port 6672-6673 \
    --cidr 10.0.0.0/8
```

#### Docker Integration

**Dockerfile with XDP Filter:**
```dockerfile
FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    clang llvm libbpf-dev linux-headers-generic \
    iproute2 bpftool

# Copy XDP filter
COPY fivem_xdp.c fivem_xdp_config.c Makefile /opt/fivem-xdp/
WORKDIR /opt/fivem-xdp

# Build filter
RUN make all

# Install script
COPY docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]
```

**Docker Compose with Privileged Mode:**
```yaml
version: '3.8'
services:
  fivem-server:
    build: .
    privileged: true
    network_mode: host
    environment:
      - SERVER_IP=192.168.1.100
      - CONFIG_TYPE=medium
    volumes:
      - /sys/fs/bpf:/sys/fs/bpf
      - /lib/modules:/lib/modules:ro
```

## Firewall Integration

### iptables Integration

**Coordinated iptables and XDP rules:**
```bash
# XDP filter handles initial filtering
sudo make install INTERFACE=eth0
make config-medium SERVER_IP=YOUR_IP

# iptables for additional protection
sudo iptables -A INPUT -p udp --dport 30120 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A INPUT -p udp --dport 30120 -m recent --name fivem --set
sudo iptables -A INPUT -p udp --dport 30120 -m recent --name fivem --rcheck --seconds 60 --hitcount 20 -j DROP
sudo iptables -A INPUT -p udp --dport 30120 -j ACCEPT

# Voice ports (internal network only)
sudo iptables -A INPUT -p udp --dport 6672:6673 -s 10.0.0.0/8 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 6672:6673 -s 172.16.0.0/12 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 6672:6673 -s 192.168.0.0/16 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 6672:6673 -j DROP

# Save rules
sudo iptables-save > /etc/iptables/rules.v4
```

### UFW Integration

**Ubuntu Firewall (UFW) configuration:**
```bash
# Install XDP filter first
sudo make install INTERFACE=eth0
make config-medium SERVER_IP=YOUR_IP

# Configure UFW
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow FiveM ports
sudo ufw allow 30120/udp comment "FiveM Server"
sudo ufw allow from 10.0.0.0/8 to any port 6672:6673 proto udp comment "FiveM Voice Internal"

# Enable UFW
sudo ufw --force enable

# Verify rules
sudo ufw status verbose
```

### firewalld Integration

**CentOS/RHEL firewalld configuration:**
```bash
# Install XDP filter
sudo make install INTERFACE=eth0
make config-medium SERVER_IP=YOUR_IP

# Configure firewalld
sudo firewall-cmd --permanent --new-service=fivem
sudo firewall-cmd --permanent --service=fivem --set-description="FiveM Game Server"
sudo firewall-cmd --permanent --service=fivem --add-port=30120/udp
sudo firewall-cmd --permanent --service=fivem --add-port=6672-6673/udp

# Apply configuration
sudo firewall-cmd --permanent --add-service=fivem
sudo firewall-cmd --reload

# Verify configuration
sudo firewall-cmd --list-all
```

## Security Tool Integration

### fail2ban Integration

**Configure fail2ban to work with XDP filter:**

```bash
# Create fail2ban filter for XDP logs
sudo tee /etc/fail2ban/filter.d/fivem-xdp.conf << EOF
[Definition]
failregex = Attack detected from <HOST>: type=\d+ count=\d+
            Rate limit exceeded from <HOST>
            Protocol violation from <HOST>
ignoreregex =
EOF

# Create fail2ban jail
sudo tee /etc/fail2ban/jail.d/fivem-xdp.conf << EOF
[fivem-xdp]
enabled = true
filter = fivem-xdp
logpath = /var/log/fivem-xdp.log
maxretry = 5
bantime = 3600
findtime = 600
action = iptables-multiport[name=fivem-xdp, port="30120,6672,6673"]
EOF

# Restart fail2ban
sudo systemctl restart fail2ban
sudo fail2ban-client status fivem-xdp
```

### Suricata Integration

**Network IDS integration:**
```bash
# Configure Suricata to monitor FiveM traffic
sudo tee -a /etc/suricata/suricata.yaml << EOF
# FiveM monitoring rules
rule-files:
  - fivem.rules

# Log XDP filter events
outputs:
  - eve-log:
      enabled: yes
      filetype: regular
      filename: fivem-security.json
      types:
        - alert
        - drop
EOF

# Create FiveM-specific rules
sudo tee /etc/suricata/rules/fivem.rules << EOF
# FiveM DDoS detection
drop udp any any -> any 30120 (msg:"FiveM potential DDoS"; threshold: type both, track by_src, count 100, seconds 10; sid:1000001;)

# FiveM protocol anomalies
alert udp any any -> any 30120 (msg:"FiveM malformed packet"; content:"|FF FF FF FF|"; offset:0; depth:4; sid:1000002;)
EOF

# Restart Suricata
sudo systemctl restart suricata
```

### OSSEC Integration

**Host-based IDS integration:**
```bash
# Configure OSSEC to monitor XDP filter logs
sudo tee -a /var/ossec/etc/ossec.conf << EOF
<localfile>
  <log_format>syslog</log_format>
  <location>/var/log/fivem-xdp.log</location>
</localfile>

<rule>
  <id>100001</id>
  <level>10</level>
  <match>Attack detected</match>
  <description>FiveM XDP Filter: Attack detected</description>
  <group>fivem,attack</group>
</rule>

<rule>
  <id>100002</id>
  <level>8</level>
  <match>Rate limit exceeded</match>
  <description>FiveM XDP Filter: Rate limit exceeded</description>
  <group>fivem,rate_limit</group>
</rule>
EOF

# Restart OSSEC
sudo systemctl restart ossec
```

## Monitoring Integration

### Prometheus Integration

**Export XDP filter metrics to Prometheus:**

```bash
# Create metrics exporter script
sudo tee /opt/fivem-xdp/prometheus_exporter.sh << 'EOF'
#!/bin/bash
# Prometheus metrics exporter for FiveM XDP filter

METRICS_FILE="/var/lib/prometheus/node-exporter/fivem_xdp.prom"

while true; do
    # Get statistics
    STATS=$(make stats 2>/dev/null)
    
    # Extract metrics
    PASSED=$(echo "$STATS" | grep "passed" | awk '{print $2}')
    DROPPED=$(echo "$STATS" | grep "dropped" | awk '{print $2}')
    RATE_LIMITED=$(echo "$STATS" | grep "rate_limited" | awk '{print $2}')
    
    # Write Prometheus metrics
    cat > "$METRICS_FILE" << METRICS
# HELP fivem_xdp_packets_total Total packets processed by FiveM XDP filter
# TYPE fivem_xdp_packets_total counter
fivem_xdp_packets_passed_total $PASSED
fivem_xdp_packets_dropped_total $DROPPED
fivem_xdp_packets_rate_limited_total $RATE_LIMITED

# HELP fivem_xdp_filter_status FiveM XDP filter status (1=active, 0=inactive)
# TYPE fivem_xdp_filter_status gauge
fivem_xdp_filter_status 1
METRICS
    
    sleep 30
done
EOF

sudo chmod +x /opt/fivem-xdp/prometheus_exporter.sh

# Create systemd service
sudo tee /etc/systemd/system/fivem-xdp-exporter.service << EOF
[Unit]
Description=FiveM XDP Prometheus Exporter
After=fivem-xdp.service

[Service]
Type=simple
ExecStart=/opt/fivem-xdp/prometheus_exporter.sh
Restart=always
User=prometheus

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable fivem-xdp-exporter.service
sudo systemctl start fivem-xdp-exporter.service
```

### Grafana Dashboard

**Import Grafana dashboard configuration:**
```json
{
  "dashboard": {
    "title": "FiveM XDP Filter",
    "panels": [
      {
        "title": "Packet Processing Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(fivem_xdp_packets_passed_total[5m])",
            "legendFormat": "Passed"
          },
          {
            "expr": "rate(fivem_xdp_packets_dropped_total[5m])",
            "legendFormat": "Dropped"
          }
        ]
      }
    ]
  }
}
```

## Performance Optimization

### Network Interface Optimization

```bash
# Optimize network interface for XDP
sudo ethtool -G eth0 rx 4096 tx 4096
sudo ethtool -K eth0 gro on gso on lro on
sudo ethtool -C eth0 rx-usecs 50 rx-frames 32

# CPU affinity for network interrupts
echo 2 > /proc/irq/$(grep eth0 /proc/interrupts | cut -d: -f1)/smp_affinity_list

# NUMA optimization
numactl --cpubind=0 --membind=0 make install INTERFACE=eth0
```

### System Tuning

```bash
# Network buffer optimization
echo 'net.core.rmem_max = 134217728' >> /etc/sysctl.conf
echo 'net.core.wmem_max = 134217728' >> /etc/sysctl.conf
echo 'net.core.netdev_max_backlog = 5000' >> /etc/sysctl.conf

# BPF optimization
echo 'kernel.bpf_stats_enabled = 1' >> /etc/sysctl.conf
echo 'net.core.bpf_jit_enable = 1' >> /etc/sysctl.conf

# Apply settings
sudo sysctl -p
```

## Testing Integration

### Integration Test Script

```bash
#!/bin/bash
# integration_test.sh - Test XDP filter integration

echo "=== FiveM XDP Filter Integration Test ==="

# Test 1: XDP filter loading
echo "Testing XDP filter loading..."
if ip link show | grep -q xdp; then
    echo "✅ XDP filter loaded"
else
    echo "❌ XDP filter not loaded"
    exit 1
fi

# Test 2: Configuration applied
echo "Testing configuration..."
if sudo bpftool map dump name server_config_map | grep -q server_ip; then
    echo "✅ Configuration applied"
else
    echo "❌ Configuration not applied"
    exit 1
fi

# Test 3: Statistics collection
echo "Testing statistics..."
if make stats | grep -q passed; then
    echo "✅ Statistics working"
else
    echo "❌ Statistics not working"
    exit 1
fi

# Test 4: FiveM server connectivity
echo "Testing FiveM server connectivity..."
if timeout 5 bash -c "</dev/tcp/$SERVER_IP/30120"; then
    echo "✅ FiveM server reachable"
else
    echo "❌ FiveM server not reachable"
    exit 1
fi

echo "✅ Integration test completed successfully"
```

## Rollback Procedures

### Emergency Rollback

```bash
#!/bin/bash
# emergency_rollback.sh - Emergency XDP filter removal

echo "Performing emergency rollback..."

# Remove XDP filter
sudo make uninstall INTERFACE=eth0

# Clean up BPF maps
sudo rm -f /sys/fs/bpf/fivem_*

# Restart networking
sudo systemctl restart networking

# Verify removal
if ! ip link show | grep -q xdp; then
    echo "✅ XDP filter successfully removed"
else
    echo "❌ XDP filter removal failed"
fi
```

This integration guide provides comprehensive instructions for deploying the FiveM XDP filter in various environments while maintaining compatibility with existing security infrastructure and monitoring systems.
