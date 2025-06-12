# Monitoring Setup

This document provides complete setup instructions for real-time monitoring, alerting systems, dashboard configuration, and integration with SIEM/logging platforms for the FiveM XDP filter.

## Monitoring Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Monitoring Architecture                     │
│                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────┐ │
│  │   XDP Filter    │───▶│   Data Export   │───▶│   Storage   │ │
│  │   (BPF Maps)    │    │   (Exporters)   │    │ (Time Series│ │
│  └─────────────────┘    └─────────────────┘    └─────────────┘ │
│                                 │                               │
│                                 ▼                               │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────┐ │
│  │   Alerting      │    │   Dashboards    │    │    SIEM     │ │
│  │ (AlertManager)  │    │   (Grafana)     │    │ (ELK Stack) │ │
│  └─────────────────┘    └─────────────────┘    └─────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Real-time Statistics Collection

### Basic Statistics Monitoring

#### 1. Statistics Collection Script
```bash
# Create statistics collector
sudo tee /opt/fivem-xdp/stats_collector.sh << 'EOF'
#!/bin/bash
# Real-time statistics collection for FiveM XDP filter

STATS_DIR="/var/lib/fivem-xdp/stats"
INTERVAL=30

# Create stats directory
mkdir -p $STATS_DIR

while true; do
    TIMESTAMP=$(date +%s)
    
    # Collect basic statistics
    STATS=$(make stats 2>/dev/null)
    
    # Parse statistics
    PASSED=$(echo "$STATS" | grep "passed" | awk '{print $2}' || echo "0")
    DROPPED=$(echo "$STATS" | grep "dropped" | awk '{print $2}' || echo "0")
    RATE_LIMITED=$(echo "$STATS" | grep "rate_limited" | awk '{print $2}' || echo "0")
    INVALID_PROTOCOL=$(echo "$STATS" | grep "invalid_protocol" | awk '{print $2}' || echo "0")
    
    # Collect performance metrics
    PERF=$(sudo bpftool map dump name perf_metrics_map 2>/dev/null)
    TOTAL_PACKETS=$(echo "$PERF" | grep "total_packets" | awk '{print $2}' || echo "0")
    PROCESSING_TIME=$(echo "$PERF" | grep "processing_time_ns" | awk '{print $2}' || echo "0")
    
    # Write to stats file
    echo "$TIMESTAMP,$PASSED,$DROPPED,$RATE_LIMITED,$INVALID_PROTOCOL,$TOTAL_PACKETS,$PROCESSING_TIME" >> $STATS_DIR/stats.csv
    
    # Rotate stats file daily
    if [ $(wc -l < $STATS_DIR/stats.csv) -gt 2880 ]; then  # 24 hours * 60 minutes / 30 seconds
        mv $STATS_DIR/stats.csv $STATS_DIR/stats-$(date +%Y%m%d).csv
        gzip $STATS_DIR/stats-$(date +%Y%m%d).csv
    fi
    
    sleep $INTERVAL
done
EOF

sudo chmod +x /opt/fivem-xdp/stats_collector.sh
```

#### 2. Statistics Service
```bash
# Create systemd service for statistics collection
sudo tee /etc/systemd/system/fivem-xdp-stats.service << EOF
[Unit]
Description=FiveM XDP Statistics Collector
After=fivem-xdp.service
Requires=fivem-xdp.service

[Service]
Type=simple
ExecStart=/opt/fivem-xdp/stats_collector.sh
Restart=always
RestartSec=10
User=xdp-admin
Group=xdp-admin

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable fivem-xdp-stats.service
sudo systemctl start fivem-xdp-stats.service
```

### Advanced Metrics Collection

#### 1. Prometheus Exporter
```bash
# Create Prometheus metrics exporter
sudo tee /opt/fivem-xdp/prometheus_exporter.py << 'EOF'
#!/usr/bin/env python3
"""
Prometheus exporter for FiveM XDP filter metrics
"""

import time
import subprocess
import json
import re
from http.server import HTTPServer, BaseHTTPRequestHandler

class MetricsHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/metrics':
            metrics = self.collect_metrics()
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain')
            self.end_headers()
            self.wfile.write(metrics.encode())
        else:
            self.send_response(404)
            self.end_headers()
    
    def collect_metrics(self):
        metrics = []
        
        try:
            # Get basic statistics
            stats_output = subprocess.check_output(['make', 'stats'], 
                                                 cwd='/opt/fivem-xdp',
                                                 stderr=subprocess.DEVNULL).decode()
            
            # Parse statistics
            for line in stats_output.split('\n'):
                if ':' in line:
                    key, value = line.split(':', 1)
                    key = key.strip().replace(' ', '_').lower()
                    value = value.strip()
                    
                    if value.isdigit():
                        metrics.append(f'fivem_xdp_{key} {value}')
            
            # Get performance metrics
            perf_output = subprocess.check_output([
                'sudo', 'bpftool', 'map', 'dump', 'name', 'perf_metrics_map'
            ], stderr=subprocess.DEVNULL).decode()
            
            # Parse performance metrics
            for line in perf_output.split('\n'):
                if 'total_packets' in line:
                    value = re.search(r'(\d+)', line)
                    if value:
                        metrics.append(f'fivem_xdp_total_packets {value.group(1)}')
                elif 'processing_time_ns' in line:
                    value = re.search(r'(\d+)', line)
                    if value:
                        metrics.append(f'fivem_xdp_processing_time_ns {value.group(1)}')
            
            # Get attack statistics
            attack_output = subprocess.check_output([
                'sudo', 'bpftool', 'map', 'dump', 'name', 'attack_log_map'
            ], stderr=subprocess.DEVNULL).decode()
            
            attack_count = len([line for line in attack_output.split('\n') if 'source_ip' in line])
            metrics.append(f'fivem_xdp_total_attacks {attack_count}')
            
        except Exception as e:
            metrics.append(f'# Error collecting metrics: {e}')
        
        # Add metadata
        metrics.insert(0, '# HELP fivem_xdp_packets_total Total packets processed')
        metrics.insert(1, '# TYPE fivem_xdp_packets_total counter')
        
        return '\n'.join(metrics) + '\n'

if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', 9100), MetricsHandler)
    print("Prometheus exporter listening on port 9100")
    server.serve_forever()
EOF

sudo chmod +x /opt/fivem-xdp/prometheus_exporter.py

# Create service for Prometheus exporter
sudo tee /etc/systemd/system/fivem-xdp-prometheus.service << EOF
[Unit]
Description=FiveM XDP Prometheus Exporter
After=fivem-xdp.service

[Service]
Type=simple
ExecStart=/opt/fivem-xdp/prometheus_exporter.py
Restart=always
User=xdp-admin
Group=xdp-admin

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable fivem-xdp-prometheus.service
sudo systemctl start fivem-xdp-prometheus.service
```

## Dashboard Configuration

### Grafana Dashboard Setup

#### 1. Grafana Installation
```bash
# Install Grafana
sudo apt-get install -y software-properties-common
sudo add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
sudo apt-get update
sudo apt-get install grafana

# Start Grafana
sudo systemctl enable grafana-server
sudo systemctl start grafana-server
```

#### 2. FiveM XDP Dashboard Configuration
```json
{
  "dashboard": {
    "id": null,
    "title": "FiveM XDP Filter Dashboard",
    "tags": ["fivem", "xdp", "security"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "Packet Processing Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(fivem_xdp_passed[5m])",
            "legendFormat": "Passed/sec",
            "refId": "A"
          },
          {
            "expr": "rate(fivem_xdp_dropped[5m])",
            "legendFormat": "Dropped/sec",
            "refId": "B"
          }
        ],
        "yAxes": [
          {
            "label": "Packets/sec",
            "min": 0
          }
        ],
        "gridPos": {
          "h": 8,
          "w": 12,
          "x": 0,
          "y": 0
        }
      },
      {
        "id": 2,
        "title": "Attack Detection",
        "type": "stat",
        "targets": [
          {
            "expr": "fivem_xdp_total_attacks",
            "legendFormat": "Total Attacks"
          }
        ],
        "gridPos": {
          "h": 4,
          "w": 6,
          "x": 12,
          "y": 0
        }
      },
      {
        "id": 3,
        "title": "Processing Latency",
        "type": "graph",
        "targets": [
          {
            "expr": "fivem_xdp_processing_time_ns / fivem_xdp_total_packets",
            "legendFormat": "Avg Latency (ns)"
          }
        ],
        "yAxes": [
          {
            "label": "Nanoseconds",
            "min": 0
          }
        ],
        "gridPos": {
          "h": 8,
          "w": 12,
          "x": 0,
          "y": 8
        }
      },
      {
        "id": 4,
        "title": "Rate Limiting Events",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(fivem_xdp_rate_limited[5m])",
            "legendFormat": "Rate Limited/sec"
          }
        ],
        "gridPos": {
          "h": 8,
          "w": 12,
          "x": 12,
          "y": 8
        }
      }
    ],
    "time": {
      "from": "now-1h",
      "to": "now"
    },
    "refresh": "5s"
  }
}
```

#### 3. Dashboard Import Script
```bash
# Create dashboard import script
sudo tee /opt/fivem-xdp/import_dashboard.sh << 'EOF'
#!/bin/bash
# Import FiveM XDP dashboard to Grafana

GRAFANA_URL="http://localhost:3000"
GRAFANA_USER="admin"
GRAFANA_PASS="admin"

# Create dashboard JSON
cat > /tmp/fivem-xdp-dashboard.json << 'DASHBOARD'
{
  "dashboard": {
    "title": "FiveM XDP Filter",
    "panels": [
      {
        "title": "Packet Statistics",
        "type": "graph",
        "targets": [
          {"expr": "fivem_xdp_passed", "legendFormat": "Passed"},
          {"expr": "fivem_xdp_dropped", "legendFormat": "Dropped"}
        ]
      }
    ]
  }
}
DASHBOARD

# Import dashboard
curl -X POST \
  -H "Content-Type: application/json" \
  -d @/tmp/fivem-xdp-dashboard.json \
  -u $GRAFANA_USER:$GRAFANA_PASS \
  $GRAFANA_URL/api/dashboards/db

echo "Dashboard imported successfully"
EOF

sudo chmod +x /opt/fivem-xdp/import_dashboard.sh
```

## Alerting System

### AlertManager Configuration

#### 1. AlertManager Setup
```bash
# Install AlertManager
wget https://github.com/prometheus/alertmanager/releases/download/v0.24.0/alertmanager-0.24.0.linux-amd64.tar.gz
tar xzf alertmanager-0.24.0.linux-amd64.tar.gz
sudo mv alertmanager-0.24.0.linux-amd64 /opt/alertmanager
sudo chown -R xdp-admin:xdp-admin /opt/alertmanager

# Create AlertManager configuration
sudo tee /opt/alertmanager/alertmanager.yml << EOF
global:
  smtp_smarthost: 'localhost:587'
  smtp_from: 'alerts@example.com'

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'web.hook'

receivers:
- name: 'web.hook'
  email_configs:
  - to: 'admin@example.com'
    subject: 'FiveM XDP Alert: {{ .GroupLabels.alertname }}'
    body: |
      {{ range .Alerts }}
      Alert: {{ .Annotations.summary }}
      Description: {{ .Annotations.description }}
      {{ end }}

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'dev', 'instance']
EOF
```

#### 2. Alert Rules
```bash
# Create Prometheus alert rules
sudo tee /opt/fivem-xdp/alert_rules.yml << EOF
groups:
- name: fivem_xdp_alerts
  rules:
  - alert: HighDropRate
    expr: rate(fivem_xdp_dropped[5m]) > 100
    for: 2m
    labels:
      severity: warning
    annotations:
      summary: "High packet drop rate detected"
      description: "FiveM XDP filter is dropping {{ \$value }} packets/sec"

  - alert: AttackDetected
    expr: increase(fivem_xdp_total_attacks[5m]) > 10
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "Multiple attacks detected"
      description: "{{ \$value }} attacks detected in the last 5 minutes"

  - alert: HighLatency
    expr: fivem_xdp_processing_time_ns / fivem_xdp_total_packets > 1000000
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High processing latency"
      description: "Average processing latency is {{ \$value }}ns"

  - alert: FilterDown
    expr: up{job="fivem-xdp"} == 0
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "FiveM XDP filter is down"
      description: "The FiveM XDP filter is not responding"
EOF
```

### Custom Alert Scripts

#### 1. Email Alerting
```bash
# Create email alert script
sudo tee /opt/fivem-xdp/email_alerts.sh << 'EOF'
#!/bin/bash
# Email alerting for FiveM XDP filter

ADMIN_EMAIL="admin@example.com"
THRESHOLD_ATTACKS=50
THRESHOLD_DROP_RATE=1000

# Check attack count
ATTACKS=$(sudo bpftool map dump name attack_log_map | wc -l)
if [ $ATTACKS -gt $THRESHOLD_ATTACKS ]; then
    echo "High attack volume detected: $ATTACKS attacks" | \
        mail -s "FiveM XDP Alert: High Attack Volume" $ADMIN_EMAIL
fi

# Check drop rate
STATS=$(make stats)
DROPPED=$(echo "$STATS" | grep "dropped" | awk '{print $2}')
if [ $DROPPED -gt $THRESHOLD_DROP_RATE ]; then
    echo "High drop rate detected: $DROPPED packets dropped" | \
        mail -s "FiveM XDP Alert: High Drop Rate" $ADMIN_EMAIL
fi
EOF

sudo chmod +x /opt/fivem-xdp/email_alerts.sh

# Schedule email alerts
echo "*/5 * * * * /opt/fivem-xdp/email_alerts.sh" | sudo crontab -u xdp-admin -
```

#### 2. Slack Integration
```bash
# Create Slack alert script
sudo tee /opt/fivem-xdp/slack_alerts.sh << 'EOF'
#!/bin/bash
# Slack alerting for FiveM XDP filter

SLACK_WEBHOOK="https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"

send_slack_alert() {
    local message="$1"
    local severity="$2"
    
    curl -X POST -H 'Content-type: application/json' \
        --data "{\"text\":\"🚨 FiveM XDP Alert [$severity]: $message\"}" \
        $SLACK_WEBHOOK
}

# Monitor for critical events
while true; do
    # Check for new attacks
    RECENT_ATTACKS=$(sudo bpftool map dump name attack_log_map | \
        awk -v cutoff=$(($(date +%s) - 300)) '$0 ~ /last_seen/ && $2 > cutoff' | wc -l)
    
    if [ $RECENT_ATTACKS -gt 10 ]; then
        send_slack_alert "High attack volume: $RECENT_ATTACKS attacks in last 5 minutes" "CRITICAL"
    fi
    
    sleep 60
done
EOF

sudo chmod +x /opt/fivem-xdp/slack_alerts.sh
```

## SIEM Integration

### ELK Stack Integration

#### 1. Logstash Configuration
```bash
# Create Logstash configuration for XDP logs
sudo tee /etc/logstash/conf.d/fivem-xdp.conf << EOF
input {
  file {
    path => "/var/log/fivem-xdp/*.log"
    start_position => "beginning"
    tags => ["fivem-xdp"]
  }
}

filter {
  if "fivem-xdp" in [tags] {
    grok {
      match => { 
        "message" => "%{TIMESTAMP_ISO8601:timestamp} %{WORD:severity} %{GREEDYDATA:message_text}"
      }
    }
    
    if "Attack detected" in [message_text] {
      grok {
        match => {
          "message_text" => "Attack detected from %{IP:source_ip}: type=%{NUMBER:attack_type} count=%{NUMBER:attack_count}"
        }
      }
      mutate {
        add_tag => ["attack"]
      }
    }
    
    date {
      match => [ "timestamp", "ISO8601" ]
    }
  }
}

output {
  if "fivem-xdp" in [tags] {
    elasticsearch {
      hosts => ["localhost:9200"]
      index => "fivem-xdp-%{+YYYY.MM.dd}"
    }
  }
}
EOF
```

#### 2. Elasticsearch Index Template
```bash
# Create Elasticsearch index template
curl -X PUT "localhost:9200/_template/fivem-xdp" -H 'Content-Type: application/json' -d'
{
  "index_patterns": ["fivem-xdp-*"],
  "settings": {
    "number_of_shards": 1,
    "number_of_replicas": 0
  },
  "mappings": {
    "properties": {
      "@timestamp": {"type": "date"},
      "source_ip": {"type": "ip"},
      "attack_type": {"type": "integer"},
      "attack_count": {"type": "integer"},
      "severity": {"type": "keyword"},
      "message_text": {"type": "text"}
    }
  }
}
'
```

### Splunk Integration

#### 1. Splunk Forwarder Configuration
```bash
# Configure Splunk Universal Forwarder
sudo tee /opt/splunkforwarder/etc/system/local/inputs.conf << EOF
[monitor:///var/log/fivem-xdp/*.log]
disabled = false
index = fivem_xdp
sourcetype = fivem_xdp_log

[monitor:///var/lib/fivem-xdp/stats/*.csv]
disabled = false
index = fivem_xdp_stats
sourcetype = fivem_xdp_stats
EOF

# Restart Splunk forwarder
sudo /opt/splunkforwarder/bin/splunk restart
```

#### 2. Splunk Search Queries
```splunk
# Top attacking IPs
index=fivem_xdp sourcetype=fivem_xdp_log "Attack detected"
| rex field=_raw "from (?<src_ip>\d+\.\d+\.\d+\.\d+)"
| stats count by src_ip
| sort -count

# Attack timeline
index=fivem_xdp sourcetype=fivem_xdp_log "Attack detected"
| timechart span=5m count by attack_type

# Performance metrics
index=fivem_xdp_stats sourcetype=fivem_xdp_stats
| eval processing_latency=processing_time_ns/total_packets
| timechart avg(processing_latency) as avg_latency
```

## Health Monitoring

### Service Health Checks

```bash
# Create health check script
sudo tee /opt/fivem-xdp/health_check.sh << 'EOF'
#!/bin/bash
# Health check for FiveM XDP filter

EXIT_CODE=0

# Check if XDP program is loaded
if ! ip link show | grep -q xdp; then
    echo "CRITICAL: XDP program not loaded"
    EXIT_CODE=2
fi

# Check if statistics are updating
STATS_FILE="/var/lib/fivem-xdp/stats/stats.csv"
if [ -f "$STATS_FILE" ]; then
    LAST_UPDATE=$(stat -c %Y "$STATS_FILE")
    CURRENT_TIME=$(date +%s)
    AGE=$((CURRENT_TIME - LAST_UPDATE))
    
    if [ $AGE -gt 120 ]; then  # 2 minutes
        echo "WARNING: Statistics not updating (last update: ${AGE}s ago)"
        EXIT_CODE=1
    fi
else
    echo "CRITICAL: Statistics file not found"
    EXIT_CODE=2
fi

# Check system resources
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
if (( $(echo "$CPU_USAGE > 80" | bc -l) )); then
    echo "WARNING: High CPU usage: ${CPU_USAGE}%"
    EXIT_CODE=1
fi

if [ $EXIT_CODE -eq 0 ]; then
    echo "OK: FiveM XDP filter healthy"
fi

exit $EXIT_CODE
EOF

sudo chmod +x /opt/fivem-xdp/health_check.sh
```

This comprehensive monitoring setup provides real-time visibility into the FiveM XDP filter's performance, security events, and system health, enabling proactive management and rapid incident response.
