# Security Best Practices

This document provides comprehensive security recommendations, hardening guidelines, access control policies, and security templates for production deployment of the FiveM XDP filter.

## Security Framework Overview

The FiveM XDP filter implements a defense-in-depth security model with multiple layers of protection:

```
┌─────────────────────────────────────────────────────────────────┐
│                    Defense-in-Depth Layers                     │
│                                                                 │
│  Layer 1: Network Edge Security                                │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ • Firewall Rules    • DDoS Protection                  │   │
│  │ • Rate Limiting     • Geo-blocking                     │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                ↓                               │
│  Layer 2: XDP Filter Security                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ • Protocol Validation  • Attack Detection              │   │
│  │ • Rate Limiting        • Connection Tracking           │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                ↓                               │
│  Layer 3: Host Security                                        │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ • iptables Rules    • fail2ban                         │   │
│  │ • SELinux/AppArmor  • Intrusion Detection              │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                ↓                               │
│  Layer 4: Application Security                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ • FiveM Server Security  • Access Controls             │   │
│  │ • Logging & Monitoring   • Incident Response           │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Configuration Security

### Secure Configuration Principles

#### 1. Principle of Least Privilege
**Apply minimal necessary permissions and access:**

```bash
# Use restrictive rate limits for production
make config-small SERVER_IP=YOUR_IP  # Start conservative

# Enable all security features
./fivem_xdp_config YOUR_IP custom << EOF
{
    "server_ip": "YOUR_ACTUAL_IP",
    "rate_limit": 500,
    "global_rate_limit": 25000,
    "subnet_rate_limit": 2500,
    "enable_checksum_validation": 1,
    "strict_enet_validation": 1
}
EOF
```

#### 2. Defense in Depth
**Layer multiple security controls:**

```bash
# XDP filter (primary defense)
sudo make install INTERFACE=eth0
make config-small SERVER_IP=YOUR_IP

# iptables (secondary defense)
sudo iptables -A INPUT -p udp --dport 30120 -m limit --limit 50/sec --limit-burst 100 -j ACCEPT
sudo iptables -A INPUT -p udp --dport 30120 -j DROP

# fail2ban (tertiary defense)
sudo systemctl enable fail2ban
```

#### 3. Secure by Default
**Use security-focused default configurations:**

```c
// Production security template
struct server_config secure_config = {
    .server_ip = YOUR_SERVER_IP,        // Specific IP only
    .server_port = 30120,
    .game_port1 = 6672,
    .game_port2 = 6673,
    .rate_limit = 300,                  // Conservative limit
    .global_rate_limit = 15000,         // Low global limit
    .subnet_rate_limit = 1500,          // Strict subnet limit
    .enable_checksum_validation = 1,     // Always enabled
    .strict_enet_validation = 1,         // Always enabled
    .reserved = {0, 0, 0}
};
```

### Configuration Hardening

#### Server IP Security
```bash
# CRITICAL: Never use 0.0.0.0 in production
# BAD: Accepts packets to any IP
./fivem_xdp_config 0.0.0.0 medium

# GOOD: Specific server IP only
./fivem_xdp_config 203.0.113.50 small

# BEST: Verify IP configuration
SERVER_IP=$(ip route get 8.8.8.8 | awk '{print $7}')
./fivem_xdp_config $SERVER_IP small
```

#### Rate Limiting Security
```bash
# Production rate limiting strategy
./fivem_xdp_config YOUR_IP custom << EOF
{
    "rate_limit": 200,          # Very conservative per-IP
    "global_rate_limit": 10000, # Protect server resources
    "subnet_rate_limit": 1000   # Prevent subnet attacks
}
EOF
```

## Access Control

### Administrative Access

#### 1. Privileged User Management
```bash
# Create dedicated XDP management user
sudo useradd -r -s /bin/bash -d /opt/fivem-xdp xdp-admin
sudo usermod -aG sudo xdp-admin

# Restrict sudo access to XDP commands only
sudo tee /etc/sudoers.d/xdp-admin << EOF
xdp-admin ALL=(root) NOPASSWD: /usr/bin/make install INTERFACE=*
xdp-admin ALL=(root) NOPASSWD: /usr/bin/make uninstall INTERFACE=*
xdp-admin ALL=(root) NOPASSWD: /usr/sbin/bpftool
xdp-admin ALL=(root) NOPASSWD: /usr/sbin/ip link set dev * xdp*
EOF
```

#### 2. SSH Security
```bash
# Secure SSH configuration
sudo tee -a /etc/ssh/sshd_config << EOF
# XDP Filter Management Security
AllowUsers xdp-admin
PasswordAuthentication no
PubkeyAuthentication yes
PermitRootLogin no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
EOF

sudo systemctl restart sshd
```

#### 3. File System Permissions
```bash
# Secure XDP filter files
sudo chown -R xdp-admin:xdp-admin /opt/fivem-xdp
sudo chmod 750 /opt/fivem-xdp
sudo chmod 640 /opt/fivem-xdp/*.c
sudo chmod 750 /opt/fivem-xdp/fivem_xdp_config
sudo chmod 644 /opt/fivem-xdp/fivem_xdp.o

# Secure BPF filesystem
sudo chmod 755 /sys/fs/bpf
sudo chown root:xdp-admin /sys/fs/bpf
```

### Network Access Control

#### 1. Source IP Restrictions
```bash
# Restrict management access by IP
sudo iptables -A INPUT -p tcp --dport 22 -s 203.0.113.0/24 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 22 -j DROP

# Allow FiveM traffic from specific regions only
sudo iptables -A INPUT -p udp --dport 30120 -m geoip --src-cc US,CA,GB -j ACCEPT
sudo iptables -A INPUT -p udp --dport 30120 -j DROP
```

#### 2. Port Security
```bash
# Minimize exposed ports
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Only allow necessary ports
sudo ufw allow from 203.0.113.0/24 to any port 22 proto tcp  # SSH (restricted)
sudo ufw allow 30120/udp                                      # FiveM (public)
sudo ufw allow from 10.0.0.0/8 to any port 6672:6673 proto udp  # Voice (internal)

sudo ufw --force enable
```

## Monitoring and Logging

### Security Logging

#### 1. Comprehensive Logging Setup
```bash
# Create dedicated log directory
sudo mkdir -p /var/log/fivem-xdp
sudo chown xdp-admin:adm /var/log/fivem-xdp
sudo chmod 750 /var/log/fivem-xdp

# Configure rsyslog for XDP filter
sudo tee /etc/rsyslog.d/50-fivem-xdp.conf << EOF
# FiveM XDP Filter Logging
local0.*    /var/log/fivem-xdp/security.log
local1.*    /var/log/fivem-xdp/performance.log
local2.*    /var/log/fivem-xdp/attacks.log

# Rotate logs daily
\$WorkDirectory /var/spool/rsyslog
\$ActionFileDefaultTemplate RSYSLOG_TraditionalFileFormat
EOF

sudo systemctl restart rsyslog
```

#### 2. Security Event Monitoring
```bash
# Create security monitoring script
sudo tee /opt/fivem-xdp/security_monitor.sh << 'EOF'
#!/bin/bash
# Security monitoring for FiveM XDP filter

LOG_FILE="/var/log/fivem-xdp/security.log"
ALERT_THRESHOLD=100

while true; do
    # Check attack statistics
    ATTACKS=$(sudo bpftool map dump name attack_log_map | wc -l)
    
    if [ $ATTACKS -gt $ALERT_THRESHOLD ]; then
        logger -p local2.warning "High attack volume detected: $ATTACKS attacks"
        
        # Send alert email
        echo "High attack volume detected on FiveM server: $ATTACKS attacks" | \
            mail -s "FiveM Security Alert" admin@example.com
    fi
    
    # Log current statistics
    STATS=$(make stats 2>/dev/null)
    logger -p local0.info "XDP Stats: $STATS"
    
    sleep 60
done
EOF

sudo chmod +x /opt/fivem-xdp/security_monitor.sh
```

#### 3. Log Rotation and Retention
```bash
# Configure logrotate for XDP logs
sudo tee /etc/logrotate.d/fivem-xdp << EOF
/var/log/fivem-xdp/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 640 xdp-admin adm
    postrotate
        systemctl reload rsyslog
    endscript
}
EOF
```

### Real-time Monitoring

#### 1. Security Dashboard
```bash
# Create real-time security dashboard
sudo tee /opt/fivem-xdp/security_dashboard.sh << 'EOF'
#!/bin/bash
# Real-time security dashboard

while true; do
    clear
    echo "=== FiveM XDP Security Dashboard ==="
    echo "Time: $(date)"
    echo ""
    
    # Filter status
    if ip link show | grep -q xdp; then
        echo "✅ XDP Filter: ACTIVE"
    else
        echo "❌ XDP Filter: INACTIVE"
    fi
    
    # Statistics
    echo ""
    echo "=== Traffic Statistics ==="
    make stats | head -10
    
    # Recent attacks
    echo ""
    echo "=== Recent Attacks ==="
    sudo bpftool map dump name attack_log_map | tail -5
    
    # System resources
    echo ""
    echo "=== System Resources ==="
    echo "CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"
    echo "Memory: $(free | grep Mem | awk '{printf "%.1f%%", $3/$2 * 100.0}')"
    
    sleep 5
done
EOF

sudo chmod +x /opt/fivem-xdp/security_dashboard.sh
```

## Incident Response

### Security Incident Classification

#### Level 1: Low Severity
- **Indicators:** Occasional rate limiting, minor protocol violations
- **Response:** Monitor and log, no immediate action required
- **Example:** Single IP exceeding rate limits

#### Level 2: Medium Severity
- **Indicators:** Sustained attack patterns, multiple attack types
- **Response:** Investigate source, consider IP blocking
- **Example:** Coordinated attack from multiple IPs

#### Level 3: High Severity
- **Indicators:** Server performance impact, service degradation
- **Response:** Immediate mitigation, emergency procedures
- **Example:** Large-scale DDoS attack

#### Level 4: Critical Severity
- **Indicators:** Service unavailability, security breach
- **Response:** Emergency response team activation
- **Example:** Filter bypass or system compromise

### Automated Response Procedures

#### 1. Automatic IP Blocking
```bash
# Create automatic blocking script
sudo tee /opt/fivem-xdp/auto_block.sh << 'EOF'
#!/bin/bash
# Automatic IP blocking based on attack patterns

BLOCK_THRESHOLD=50
BLOCK_DURATION=3600  # 1 hour

# Check attack log
sudo bpftool map dump name attack_log_map | \
while read line; do
    IP=$(echo $line | grep -o 'source_ip [0-9]*' | awk '{print $2}')
    COUNT=$(echo $line | grep -o 'count [0-9]*' | awk '{print $2}')
    
    if [ $COUNT -gt $BLOCK_THRESHOLD ]; then
        # Convert to dotted decimal
        IP_ADDR=$(printf "%d.%d.%d.%d" \
            $((IP & 0xFF)) \
            $(((IP >> 8) & 0xFF)) \
            $(((IP >> 16) & 0xFF)) \
            $(((IP >> 24) & 0xFF)))
        
        # Block IP
        sudo iptables -I INPUT -s $IP_ADDR -j DROP
        
        # Schedule unblock
        echo "sudo iptables -D INPUT -s $IP_ADDR -j DROP" | \
            at now + $BLOCK_DURATION seconds
        
        logger -p local2.warning "Auto-blocked IP $IP_ADDR for $BLOCK_DURATION seconds"
    fi
done
EOF

sudo chmod +x /opt/fivem-xdp/auto_block.sh
```

#### 2. Emergency Response Script
```bash
# Create emergency response script
sudo tee /opt/fivem-xdp/emergency_response.sh << 'EOF'
#!/bin/bash
# Emergency response for critical security incidents

echo "=== EMERGENCY RESPONSE ACTIVATED ==="
echo "Time: $(date)"

# 1. Increase security level
echo "Switching to maximum security configuration..."
./fivem_xdp_config $SERVER_IP custom << EOF
{
    "rate_limit": 100,
    "global_rate_limit": 5000,
    "subnet_rate_limit": 500,
    "enable_checksum_validation": 1,
    "strict_enet_validation": 1
}
EOF

# 2. Block suspicious traffic
echo "Implementing emergency firewall rules..."
sudo iptables -I INPUT -p udp --dport 30120 -m limit --limit 10/sec -j ACCEPT
sudo iptables -I INPUT -p udp --dport 30120 -j DROP

# 3. Alert administrators
echo "Sending emergency alerts..."
echo "EMERGENCY: FiveM server under attack - emergency response activated" | \
    mail -s "CRITICAL: FiveM Security Emergency" admin@example.com

# 4. Log incident
logger -p local2.crit "Emergency response activated - server under attack"

echo "Emergency response completed."
EOF

sudo chmod +x /opt/fivem-xdp/emergency_response.sh
```

## Security Auditing

### Regular Security Checks

#### 1. Configuration Audit
```bash
# Create configuration audit script
sudo tee /opt/fivem-xdp/security_audit.sh << 'EOF'
#!/bin/bash
# Security configuration audit

echo "=== FiveM XDP Security Audit ==="
echo "Date: $(date)"
echo ""

# Check XDP filter status
echo "1. XDP Filter Status:"
if ip link show | grep -q xdp; then
    echo "   ✅ XDP filter is loaded"
else
    echo "   ❌ XDP filter is NOT loaded"
fi

# Check configuration security
echo ""
echo "2. Configuration Security:"
CONFIG=$(sudo bpftool map dump name server_config_map)

if echo "$CONFIG" | grep -q "server_ip.*0"; then
    echo "   ⚠️  WARNING: Server IP set to accept any (0.0.0.0)"
else
    echo "   ✅ Server IP properly configured"
fi

if echo "$CONFIG" | grep -q "enable_checksum_validation.*1"; then
    echo "   ✅ Checksum validation enabled"
else
    echo "   ⚠️  WARNING: Checksum validation disabled"
fi

# Check file permissions
echo ""
echo "3. File Permissions:"
if [ "$(stat -c %a /opt/fivem-xdp)" = "750" ]; then
    echo "   ✅ Directory permissions correct"
else
    echo "   ❌ Directory permissions incorrect"
fi

# Check for recent attacks
echo ""
echo "4. Recent Security Events:"
ATTACKS=$(sudo bpftool map dump name attack_log_map | wc -l)
echo "   Total attacks logged: $ATTACKS"

if [ $ATTACKS -gt 100 ]; then
    echo "   ⚠️  WARNING: High attack volume detected"
else
    echo "   ✅ Attack volume within normal range"
fi

echo ""
echo "Audit completed."
EOF

sudo chmod +x /opt/fivem-xdp/security_audit.sh
```

#### 2. Automated Security Scanning
```bash
# Schedule regular security audits
sudo tee /etc/cron.d/fivem-xdp-audit << EOF
# FiveM XDP Security Audit
0 2 * * * xdp-admin /opt/fivem-xdp/security_audit.sh >> /var/log/fivem-xdp/audit.log 2>&1
EOF
```

## Security Policy Templates

### Organizational Security Policy

```markdown
# FiveM XDP Filter Security Policy

## 1. Purpose
This policy establishes security requirements for the deployment and operation of FiveM XDP filters.

## 2. Scope
Applies to all FiveM server deployments using XDP filtering technology.

## 3. Security Requirements

### 3.1 Configuration Security
- Server IP must be explicitly configured (no wildcard IPs)
- Rate limits must be set according to server capacity
- All validation features must be enabled in production
- Configuration changes require approval and logging

### 3.2 Access Control
- Administrative access limited to authorized personnel
- Multi-factor authentication required for critical operations
- Regular access review and privilege auditing
- Separation of duties for security-critical functions

### 3.3 Monitoring and Logging
- Continuous monitoring of filter performance and security events
- Real-time alerting for security incidents
- Log retention for minimum 90 days
- Regular security audit and compliance checks

### 3.4 Incident Response
- Defined escalation procedures for security incidents
- Automated response capabilities for common attack patterns
- Regular testing of incident response procedures
- Post-incident analysis and improvement processes

## 4. Compliance
All deployments must comply with this policy and undergo regular security assessments.
```

This comprehensive security best practices guide provides the foundation for secure deployment and operation of the FiveM XDP filter in production environments.
