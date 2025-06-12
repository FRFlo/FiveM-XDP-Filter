# Incident Response Procedures

This document provides detailed procedures for responding to detected attacks, escalation workflows, forensic analysis steps, and recovery procedures for the FiveM XDP filter.

## Incident Response Framework

### Response Team Structure

```
┌─────────────────────────────────────────────────────────────────┐
│                 Incident Response Team                         │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   Incident      │  │    Technical    │  │  Communications │ │
│  │  Commander      │  │    Team         │  │     Team        │ │
│  │                 │  │                 │  │                 │ │
│  │ • Coordination  │  │ • Investigation │  │ • Stakeholder   │ │
│  │ • Decision      │  │ • Mitigation    │  │   Communication │ │
│  │   Making        │  │ • Recovery      │  │ • Documentation │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │     Legal       │  │   Management    │  │   External      │ │
│  │     Team        │  │     Team        │  │   Support       │ │
│  │                 │  │                 │  │                 │ │
│  │ • Compliance    │  │ • Business      │  │ • Vendors       │ │
│  │ • Law           │  │   Continuity    │  │ • Law           │ │
│  │   Enforcement   │  │ • Resource      │  │   Enforcement   │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### Incident Classification

#### Severity Levels

**Level 1 - Informational**
- **Indicators:** Normal security events, routine rate limiting
- **Response Time:** 24 hours
- **Escalation:** None required
- **Example:** Single IP exceeding rate limits occasionally

**Level 2 - Low**
- **Indicators:** Minor attack patterns, isolated incidents
- **Response Time:** 4 hours
- **Escalation:** Technical team notification
- **Example:** Small-scale protocol violations

**Level 3 - Medium**
- **Indicators:** Sustained attack patterns, multiple attack vectors
- **Response Time:** 1 hour
- **Escalation:** Incident commander activation
- **Example:** Coordinated attack from multiple sources

**Level 4 - High**
- **Indicators:** Service impact, performance degradation
- **Response Time:** 15 minutes
- **Escalation:** Full team activation
- **Example:** Large-scale DDoS affecting server performance

**Level 5 - Critical**
- **Indicators:** Service unavailability, security breach
- **Response Time:** Immediate
- **Escalation:** Emergency response procedures
- **Example:** Filter bypass or complete service outage

## Detection and Initial Response

### Automated Detection

#### 1. Real-time Monitoring Alerts
```bash
# Create automated detection script
sudo tee /opt/fivem-xdp/incident_detector.sh << 'EOF'
#!/bin/bash
# Automated incident detection for FiveM XDP filter

ALERT_LOG="/var/log/fivem-xdp/incidents.log"
ESCALATION_SCRIPT="/opt/fivem-xdp/escalate_incident.sh"

# Thresholds
CRITICAL_ATTACK_THRESHOLD=100
HIGH_DROP_RATE_THRESHOLD=5000
CRITICAL_LATENCY_THRESHOLD=10000000  # 10ms in nanoseconds

log_incident() {
    local severity="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$severity] $message" >> $ALERT_LOG
    
    # Trigger escalation for high/critical incidents
    if [ "$severity" = "HIGH" ] || [ "$severity" = "CRITICAL" ]; then
        $ESCALATION_SCRIPT "$severity" "$message"
    fi
}

while true; do
    # Check attack volume
    RECENT_ATTACKS=$(sudo bpftool map dump name attack_log_map | \
        awk -v cutoff=$(($(date +%s) - 300)) '$0 ~ /last_seen/ && $2 > cutoff' | wc -l)
    
    if [ $RECENT_ATTACKS -gt $CRITICAL_ATTACK_THRESHOLD ]; then
        log_incident "CRITICAL" "High attack volume: $RECENT_ATTACKS attacks in 5 minutes"
    elif [ $RECENT_ATTACKS -gt 50 ]; then
        log_incident "HIGH" "Elevated attack volume: $RECENT_ATTACKS attacks in 5 minutes"
    fi
    
    # Check drop rate
    STATS=$(make stats 2>/dev/null)
    DROPPED=$(echo "$STATS" | grep "dropped" | awk '{print $2}' || echo "0")
    
    if [ $DROPPED -gt $HIGH_DROP_RATE_THRESHOLD ]; then
        log_incident "HIGH" "High packet drop rate: $DROPPED packets dropped"
    fi
    
    # Check processing latency
    PERF=$(sudo bpftool map dump name perf_metrics_map 2>/dev/null)
    TOTAL_PACKETS=$(echo "$PERF" | grep "total_packets" | awk '{print $2}' || echo "1")
    PROCESSING_TIME=$(echo "$PERF" | grep "processing_time_ns" | awk '{print $2}' || echo "0")
    
    if [ $TOTAL_PACKETS -gt 0 ]; then
        AVG_LATENCY=$((PROCESSING_TIME / TOTAL_PACKETS))
        if [ $AVG_LATENCY -gt $CRITICAL_LATENCY_THRESHOLD ]; then
            log_incident "HIGH" "High processing latency: ${AVG_LATENCY}ns average"
        fi
    fi
    
    sleep 30
done
EOF

sudo chmod +x /opt/fivem-xdp/incident_detector.sh
```

#### 2. Escalation Script
```bash
# Create incident escalation script
sudo tee /opt/fivem-xdp/escalate_incident.sh << 'EOF'
#!/bin/bash
# Incident escalation for FiveM XDP filter

SEVERITY="$1"
MESSAGE="$2"
INCIDENT_ID="INC-$(date +%Y%m%d%H%M%S)"

# Notification contacts
ADMIN_EMAIL="admin@example.com"
SECURITY_EMAIL="security@example.com"
SLACK_WEBHOOK="https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"

# Log incident
echo "$(date '+%Y-%m-%d %H:%M:%S') [$INCIDENT_ID] [$SEVERITY] $MESSAGE" >> /var/log/fivem-xdp/escalations.log

# Send notifications based on severity
case $SEVERITY in
    "CRITICAL")
        # Immediate notifications
        echo "CRITICAL INCIDENT [$INCIDENT_ID]: $MESSAGE" | \
            mail -s "CRITICAL: FiveM XDP Security Incident" $ADMIN_EMAIL $SECURITY_EMAIL
        
        # Slack notification
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"🚨 CRITICAL INCIDENT [$INCIDENT_ID]: $MESSAGE\"}" \
            $SLACK_WEBHOOK
        
        # SMS notification (if configured)
        # echo "$MESSAGE" | sms_send.sh +1234567890
        
        # Trigger emergency response
        /opt/fivem-xdp/emergency_response.sh "$INCIDENT_ID"
        ;;
        
    "HIGH")
        # Email notification
        echo "HIGH SEVERITY INCIDENT [$INCIDENT_ID]: $MESSAGE" | \
            mail -s "HIGH: FiveM XDP Security Incident" $ADMIN_EMAIL
        
        # Slack notification
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"⚠️ HIGH INCIDENT [$INCIDENT_ID]: $MESSAGE\"}" \
            $SLACK_WEBHOOK
        ;;
esac

echo "Incident $INCIDENT_ID escalated with severity $SEVERITY"
EOF

sudo chmod +x /opt/fivem-xdp/escalate_incident.sh
```

### Manual Incident Reporting

#### 1. Incident Report Template
```bash
# Create incident reporting template
sudo tee /opt/fivem-xdp/report_incident.sh << 'EOF'
#!/bin/bash
# Manual incident reporting tool

echo "=== FiveM XDP Incident Report ==="
echo "Incident ID: INC-$(date +%Y%m%d%H%M%S)"
echo "Report Time: $(date)"
echo "Reporter: $(whoami)"
echo ""

read -p "Incident Severity (1-5): " SEVERITY
read -p "Brief Description: " DESCRIPTION
read -p "Affected Systems: " SYSTEMS
read -p "Business Impact: " IMPACT

echo ""
echo "=== System Status ==="
echo "XDP Filter Status: $(ip link show | grep -q xdp && echo "ACTIVE" || echo "INACTIVE")"
echo "Current Statistics:"
make stats | head -10

echo ""
echo "=== Recent Attacks ==="
sudo bpftool map dump name attack_log_map | tail -5

echo ""
echo "=== System Resources ==="
echo "CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}')"
echo "Memory Usage: $(free | grep Mem | awk '{printf "%.1f%%", $3/$2 * 100.0}')"

echo ""
echo "Incident report completed. Please save this output for documentation."
EOF

sudo chmod +x /opt/fivem-xdp/report_incident.sh
```

## Investigation Procedures

### Forensic Data Collection

#### 1. Evidence Collection Script
```bash
# Create evidence collection script
sudo tee /opt/fivem-xdp/collect_evidence.sh << 'EOF'
#!/bin/bash
# Forensic evidence collection for FiveM XDP incidents

INCIDENT_ID="$1"
EVIDENCE_DIR="/var/lib/fivem-xdp/evidence/$INCIDENT_ID"

if [ -z "$INCIDENT_ID" ]; then
    echo "Usage: $0 <incident_id>"
    exit 1
fi

echo "Collecting evidence for incident $INCIDENT_ID..."
mkdir -p $EVIDENCE_DIR

# System information
echo "Collecting system information..."
uname -a > $EVIDENCE_DIR/system_info.txt
date > $EVIDENCE_DIR/collection_time.txt
uptime > $EVIDENCE_DIR/uptime.txt
ps aux > $EVIDENCE_DIR/processes.txt

# Network configuration
echo "Collecting network configuration..."
ip link show > $EVIDENCE_DIR/network_interfaces.txt
ip addr show > $EVIDENCE_DIR/ip_addresses.txt
ip route show > $EVIDENCE_DIR/routing_table.txt
netstat -tulpn > $EVIDENCE_DIR/network_connections.txt

# XDP filter status
echo "Collecting XDP filter status..."
ip link show | grep xdp > $EVIDENCE_DIR/xdp_status.txt
sudo bpftool prog list > $EVIDENCE_DIR/bpf_programs.txt
sudo bpftool map list > $EVIDENCE_DIR/bpf_maps.txt

# Filter statistics
echo "Collecting filter statistics..."
make stats > $EVIDENCE_DIR/filter_stats.txt
sudo bpftool map dump name enhanced_stats_map > $EVIDENCE_DIR/enhanced_stats.txt
sudo bpftool map dump name perf_metrics_map > $EVIDENCE_DIR/performance_metrics.txt

# Attack data
echo "Collecting attack data..."
sudo bpftool map dump name attack_log_map > $EVIDENCE_DIR/attack_log.txt
sudo bpftool map dump name connection_state_map > $EVIDENCE_DIR/connection_states.txt

# Configuration
echo "Collecting configuration..."
sudo bpftool map dump name server_config_map > $EVIDENCE_DIR/current_config.txt

# System logs
echo "Collecting system logs..."
journalctl -u fivem-xdp.service --since "1 hour ago" > $EVIDENCE_DIR/service_logs.txt
dmesg | grep -i -E "(xdp|bpf)" > $EVIDENCE_DIR/kernel_messages.txt

# Network traffic sample (if tcpdump available)
if command -v tcpdump >/dev/null 2>&1; then
    echo "Collecting network traffic sample..."
    timeout 30 tcpdump -i eth0 -w $EVIDENCE_DIR/traffic_sample.pcap udp port 30120 &
fi

# Create evidence archive
echo "Creating evidence archive..."
tar -czf $EVIDENCE_DIR.tar.gz -C $(dirname $EVIDENCE_DIR) $(basename $EVIDENCE_DIR)
chmod 600 $EVIDENCE_DIR.tar.gz

echo "Evidence collection completed: $EVIDENCE_DIR.tar.gz"
echo "Evidence hash: $(sha256sum $EVIDENCE_DIR.tar.gz | awk '{print $1}')"
EOF

sudo chmod +x /opt/fivem-xdp/collect_evidence.sh
```

#### 2. Attack Analysis Tools
```bash
# Create attack analysis script
sudo tee /opt/fivem-xdp/analyze_attacks.sh << 'EOF'
#!/bin/bash
# Attack pattern analysis for FiveM XDP filter

INCIDENT_ID="$1"
ANALYSIS_DIR="/var/lib/fivem-xdp/analysis/$INCIDENT_ID"

mkdir -p $ANALYSIS_DIR

echo "=== Attack Pattern Analysis for $INCIDENT_ID ==="

# Extract attack data
sudo bpftool map dump name attack_log_map > $ANALYSIS_DIR/raw_attacks.txt

# Analyze attack sources
echo "Top attacking IP addresses:"
grep -o 'source_ip [0-9]*' $ANALYSIS_DIR/raw_attacks.txt | \
    awk '{print $2}' | sort | uniq -c | sort -nr | head -10 | \
    while read count ip_int; do
        ip_addr=$(printf "%d.%d.%d.%d" \
            $((ip_int & 0xFF)) \
            $(((ip_int >> 8) & 0xFF)) \
            $(((ip_int >> 16) & 0xFF)) \
            $(((ip_int >> 24) & 0xFF)))
        echo "  $count attacks from $ip_addr"
    done > $ANALYSIS_DIR/top_attackers.txt

# Analyze attack types
echo "Attack type distribution:"
grep -o 'attack_type [0-9]*' $ANALYSIS_DIR/raw_attacks.txt | \
    awk '{print $2}' | sort | uniq -c | sort -nr | \
    while read count type; do
        case $type in
            1) type_name="Rate Limit" ;;
            2) type_name="Invalid Protocol" ;;
            3) type_name="Replay Attack" ;;
            4) type_name="State Violation" ;;
            5) type_name="Checksum Fail" ;;
            6) type_name="Size Violation" ;;
            7) type_name="Sequence Anomaly" ;;
            8) type_name="Token Reuse" ;;
            *) type_name="Unknown" ;;
        esac
        echo "  $count $type_name attacks"
    done > $ANALYSIS_DIR/attack_types.txt

# Timeline analysis
echo "Attack timeline (last 24 hours):"
current_time=$(date +%s)
for hour in {23..0}; do
    hour_start=$((current_time - hour * 3600))
    hour_end=$((hour_start + 3600))
    
    attack_count=$(awk -v start=$hour_start -v end=$hour_end \
        '$0 ~ /last_seen/ && $2 >= start && $2 < end' \
        $ANALYSIS_DIR/raw_attacks.txt | wc -l)
    
    hour_label=$(date -d "@$hour_start" "+%H:00")
    echo "  $hour_label: $attack_count attacks"
done > $ANALYSIS_DIR/attack_timeline.txt

# Geolocation analysis (if geoip tools available)
if command -v geoiplookup >/dev/null 2>&1; then
    echo "Geographic distribution:"
    grep -o 'source_ip [0-9]*' $ANALYSIS_DIR/raw_attacks.txt | \
        awk '{print $2}' | sort | uniq | head -20 | \
        while read ip_int; do
            ip_addr=$(printf "%d.%d.%d.%d" \
                $((ip_int & 0xFF)) \
                $(((ip_int >> 8) & 0xFF)) \
                $(((ip_int >> 16) & 0xFF)) \
                $(((ip_int >> 24) & 0xFF)))
            country=$(geoiplookup $ip_addr | cut -d: -f2 | cut -d, -f1)
            echo "  $ip_addr: $country"
        done > $ANALYSIS_DIR/geographic_distribution.txt
fi

echo "Analysis completed. Results saved in $ANALYSIS_DIR/"
EOF

sudo chmod +x /opt/fivem-xdp/analyze_attacks.sh
```

## Containment and Mitigation

### Immediate Response Actions

#### 1. Emergency Containment
```bash
# Create emergency containment script
sudo tee /opt/fivem-xdp/emergency_containment.sh << 'EOF'
#!/bin/bash
# Emergency containment procedures

INCIDENT_ID="$1"
CONTAINMENT_LOG="/var/log/fivem-xdp/containment.log"

log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$INCIDENT_ID] $1" >> $CONTAINMENT_LOG
}

echo "=== EMERGENCY CONTAINMENT ACTIVATED ==="
echo "Incident ID: $INCIDENT_ID"
echo "Time: $(date)"

log_action "Emergency containment initiated"

# 1. Switch to maximum security configuration
echo "Applying maximum security configuration..."
./fivem_xdp_config $SERVER_IP custom << EOF
{
    "server_ip": "$SERVER_IP",
    "rate_limit": 50,
    "global_rate_limit": 2000,
    "subnet_rate_limit": 200,
    "enable_checksum_validation": 1,
    "strict_enet_validation": 1
}
EOF
log_action "Applied maximum security configuration"

# 2. Implement emergency firewall rules
echo "Implementing emergency firewall rules..."
sudo iptables -I INPUT -p udp --dport 30120 -m limit --limit 5/sec --limit-burst 10 -j ACCEPT
sudo iptables -I INPUT -p udp --dport 30120 -j DROP
log_action "Emergency firewall rules implemented"

# 3. Block top attacking IPs
echo "Blocking top attacking IPs..."
sudo bpftool map dump name attack_log_map | \
    grep -o 'source_ip [0-9]*' | awk '{print $2}' | sort | uniq -c | sort -nr | head -10 | \
    while read count ip_int; do
        if [ $count -gt 20 ]; then
            ip_addr=$(printf "%d.%d.%d.%d" \
                $((ip_int & 0xFF)) \
                $(((ip_int >> 8) & 0xFF)) \
                $(((ip_int >> 16) & 0xFF)) \
                $(((ip_int >> 24) & 0xFF)))
            sudo iptables -I INPUT -s $ip_addr -j DROP
            log_action "Blocked attacking IP: $ip_addr ($count attacks)"
        fi
    done

# 4. Notify stakeholders
echo "Sending emergency notifications..."
echo "EMERGENCY CONTAINMENT ACTIVATED for incident $INCIDENT_ID" | \
    mail -s "EMERGENCY: FiveM XDP Containment" admin@example.com

log_action "Emergency containment completed"
echo "Emergency containment completed."
EOF

sudo chmod +x /opt/fivem-xdp/emergency_containment.sh
```

#### 2. Graduated Response
```bash
# Create graduated response script
sudo tee /opt/fivem-xdp/graduated_response.sh << 'EOF'
#!/bin/bash
# Graduated response based on incident severity

SEVERITY="$1"
INCIDENT_ID="$2"

case $SEVERITY in
    "1"|"2")
        echo "Low severity incident - monitoring only"
        # Increase monitoring frequency
        ;;
    
    "3")
        echo "Medium severity - implementing protective measures"
        # Reduce rate limits by 25%
        CURRENT_LIMIT=$(sudo bpftool map dump name server_config_map | grep rate_limit | awk '{print $2}')
        NEW_LIMIT=$((CURRENT_LIMIT * 3 / 4))
        ./fivem_xdp_config $SERVER_IP custom << EOF
{
    "rate_limit": $NEW_LIMIT
}
EOF
        ;;
    
    "4")
        echo "High severity - implementing strict controls"
        # Switch to small server configuration
        make config-small SERVER_IP=$SERVER_IP
        ;;
    
    "5")
        echo "Critical severity - emergency containment"
        /opt/fivem-xdp/emergency_containment.sh $INCIDENT_ID
        ;;
esac
EOF

sudo chmod +x /opt/fivem-xdp/graduated_response.sh
```

## Recovery Procedures

### Service Recovery

#### 1. Recovery Checklist
```bash
# Create recovery checklist script
sudo tee /opt/fivem-xdp/recovery_checklist.sh << 'EOF'
#!/bin/bash
# Post-incident recovery checklist

INCIDENT_ID="$1"
RECOVERY_LOG="/var/log/fivem-xdp/recovery.log"

log_step() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$INCIDENT_ID] $1" >> $RECOVERY_LOG
    echo "✓ $1"
}

echo "=== POST-INCIDENT RECOVERY CHECKLIST ==="
echo "Incident ID: $INCIDENT_ID"
echo ""

# 1. Verify XDP filter status
if ip link show | grep -q xdp; then
    log_step "XDP filter is active"
else
    echo "❌ XDP filter not active - reinstalling..."
    sudo make install INTERFACE=eth0
    log_step "XDP filter reinstalled"
fi

# 2. Restore normal configuration
echo "Restoring normal configuration..."
make config-medium SERVER_IP=$SERVER_IP
log_step "Normal configuration restored"

# 3. Remove emergency firewall rules
echo "Removing emergency firewall rules..."
sudo iptables -D INPUT -p udp --dport 30120 -m limit --limit 5/sec --limit-burst 10 -j ACCEPT 2>/dev/null
sudo iptables -D INPUT -p udp --dport 30120 -j DROP 2>/dev/null
log_step "Emergency firewall rules removed"

# 4. Verify service functionality
echo "Testing service functionality..."
if timeout 5 bash -c "</dev/tcp/$SERVER_IP/30120"; then
    log_step "FiveM server connectivity verified"
else
    echo "❌ FiveM server not reachable"
fi

# 5. Monitor for 30 minutes
echo "Monitoring system for 30 minutes..."
for i in {1..6}; do
    sleep 300  # 5 minutes
    STATS=$(make stats)
    PASSED=$(echo "$STATS" | grep "passed" | awk '{print $2}')
    DROPPED=$(echo "$STATS" | grep "dropped" | awk '{print $2}')
    echo "  $(date '+%H:%M'): $PASSED passed, $DROPPED dropped"
done
log_step "30-minute monitoring completed"

# 6. Generate recovery report
echo "Generating recovery report..."
/opt/fivem-xdp/generate_recovery_report.sh $INCIDENT_ID
log_step "Recovery report generated"

echo ""
echo "Recovery checklist completed for incident $INCIDENT_ID"
EOF

sudo chmod +x /opt/fivem-xdp/recovery_checklist.sh
```

## Post-Incident Activities

### Lessons Learned

#### 1. Post-Incident Review Template
```bash
# Create post-incident review template
sudo tee /opt/fivem-xdp/post_incident_review.sh << 'EOF'
#!/bin/bash
# Post-incident review and lessons learned

INCIDENT_ID="$1"
REVIEW_DIR="/var/lib/fivem-xdp/reviews/$INCIDENT_ID"

mkdir -p $REVIEW_DIR

echo "=== POST-INCIDENT REVIEW ==="
echo "Incident ID: $INCIDENT_ID"
echo "Review Date: $(date)"
echo ""

# Timeline reconstruction
echo "=== INCIDENT TIMELINE ==="
grep "$INCIDENT_ID" /var/log/fivem-xdp/*.log | sort > $REVIEW_DIR/timeline.txt
cat $REVIEW_DIR/timeline.txt

echo ""
echo "=== IMPACT ASSESSMENT ==="
read -p "Service downtime (minutes): " DOWNTIME
read -p "Players affected: " PLAYERS_AFFECTED
read -p "Business impact (1-5): " BUSINESS_IMPACT

echo ""
echo "=== ROOT CAUSE ANALYSIS ==="
read -p "Primary root cause: " ROOT_CAUSE
read -p "Contributing factors: " CONTRIBUTING_FACTORS

echo ""
echo "=== RESPONSE EFFECTIVENESS ==="
read -p "Detection time (minutes): " DETECTION_TIME
read -p "Response time (minutes): " RESPONSE_TIME
read -p "Resolution time (minutes): " RESOLUTION_TIME

echo ""
echo "=== LESSONS LEARNED ==="
read -p "What worked well: " WHAT_WORKED
read -p "What could be improved: " IMPROVEMENTS
read -p "Action items: " ACTION_ITEMS

# Generate report
cat > $REVIEW_DIR/review_report.txt << EOF
Post-Incident Review Report
Incident ID: $INCIDENT_ID
Review Date: $(date)

INCIDENT SUMMARY:
- Service downtime: $DOWNTIME minutes
- Players affected: $PLAYERS_AFFECTED
- Business impact: $BUSINESS_IMPACT/5

ROOT CAUSE:
$ROOT_CAUSE

CONTRIBUTING FACTORS:
$CONTRIBUTING_FACTORS

RESPONSE METRICS:
- Detection time: $DETECTION_TIME minutes
- Response time: $RESPONSE_TIME minutes
- Resolution time: $RESOLUTION_TIME minutes

LESSONS LEARNED:
What worked well: $WHAT_WORKED
Improvements needed: $IMPROVEMENTS
Action items: $ACTION_ITEMS
EOF

echo "Post-incident review completed. Report saved to $REVIEW_DIR/review_report.txt"
EOF

sudo chmod +x /opt/fivem-xdp/post_incident_review.sh
```

This comprehensive incident response framework provides structured procedures for detecting, investigating, containing, and recovering from security incidents affecting the FiveM XDP filter, ensuring rapid and effective response to protect server availability and security.
