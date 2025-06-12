#!/usr/bin/env python3
"""
Exportateur de métriques pour le filtre XDP FiveM
Lit les cartes BPF et expose les métriques au format Prometheus
"""

import json
import logging
import os
import subprocess
import time
from typing import Dict, Any, Optional

from prometheus_client import start_http_server, Gauge, Counter, Histogram, Info

# Configuration du logging
logging.basicConfig(
    level=getattr(logging, os.getenv('LOG_LEVEL', 'INFO')),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('fivem-xdp-exporter')

class FiveMXDPExporter:
    """Exportateur de métriques pour le filtre XDP FiveM"""
    
    def __init__(self):
        self.metrics_interval = int(os.getenv('METRICS_INTERVAL', '15'))
        self.port = int(os.getenv('EXPORTER_PORT', '9100'))
        
        # Métriques Prometheus
        self.setup_metrics()
        
        logger.info(f"Exportateur initialisé - Port: {self.port}, Intervalle: {self.metrics_interval}s")
    
    def setup_metrics(self):
        """Initialise les métriques Prometheus"""
        
        # Informations sur le filtre
        self.filter_info = Info('fivem_xdp_filter_info', 'Informations sur le filtre XDP FiveM')
        
        # Statistiques de base
        self.packets_total = Counter('fivem_xdp_packets_total', 'Total des paquets traités', ['action'])
        self.packets_passed = Gauge('fivem_xdp_packets_passed', 'Paquets autorisés')
        self.packets_dropped = Gauge('fivem_xdp_packets_dropped', 'Paquets rejetés')
        self.packets_rate_limited = Gauge('fivem_xdp_packets_rate_limited', 'Paquets limités par débit')
        self.packets_invalid_protocol = Gauge('fivem_xdp_packets_invalid_protocol', 'Paquets avec protocole invalide')
        
        # Statistiques avancées
        self.sequence_violations = Gauge('fivem_xdp_sequence_violations', 'Violations de séquence détectées')
        self.state_violations = Gauge('fivem_xdp_state_violations', 'Violations d\'état détectées')
        self.checksum_failures = Gauge('fivem_xdp_checksum_failures', 'Échecs de somme de contrôle')
        
        # Métriques de performance
        self.processing_time_ns = Histogram('fivem_xdp_processing_time_nanoseconds', 
                                          'Temps de traitement des paquets en nanosecondes')
        self.avg_processing_time = Gauge('fivem_xdp_avg_processing_time_ns', 
                                       'Temps de traitement moyen en nanosecondes')
        
        # Métriques d'attaque
        self.attacks_detected = Counter('fivem_xdp_attacks_detected_total', 
                                      'Total des attaques détectées', ['type'])
        self.attack_sources = Gauge('fivem_xdp_attack_sources', 
                                  'Nombre de sources d\'attaque uniques')
        
        # État du système
        self.filter_active = Gauge('fivem_xdp_filter_active', 'État du filtre (1=actif, 0=inactif)')
        self.last_update = Gauge('fivem_xdp_last_update_timestamp', 'Timestamp de la dernière mise à jour')
    
    def run_bpftool_command(self, command: str) -> Optional[str]:
        """Exécute une commande bpftool et retourne la sortie"""
        try:
            result = subprocess.run(
                f"bpftool {command}",
                shell=True,
                capture_output=True,
                text=True,
                timeout=10
            )
            if result.returncode == 0:
                return result.stdout.strip()
            else:
                logger.warning(f"Commande bpftool échouée: {command} - {result.stderr}")
                return None
        except subprocess.TimeoutExpired:
            logger.error(f"Timeout lors de l'exécution de: {command}")
            return None
        except Exception as e:
            logger.error(f"Erreur lors de l'exécution de bpftool: {e}")
            return None
    
    def parse_bpf_map_output(self, output: str) -> Dict[str, Any]:
        """Parse la sortie d'une carte BPF"""
        if not output:
            return {}
        
        try:
            # Essayer de parser comme JSON
            return json.loads(output)
        except json.JSONDecodeError:
            # Parser le format texte de bpftool
            data = {}
            for line in output.split('\n'):
                if ':' in line:
                    key, value = line.split(':', 1)
                    key = key.strip()
                    value = value.strip()
                    try:
                        # Essayer de convertir en nombre
                        data[key] = int(value)
                    except ValueError:
                        data[key] = value
            return data
    
    def collect_basic_stats(self):
        """Collecte les statistiques de base"""
        # Statistiques améliorées
        enhanced_stats_output = self.run_bpftool_command("map dump name enhanced_stats_map")
        if enhanced_stats_output:
            stats = self.parse_bpf_map_output(enhanced_stats_output)
            
            # Extraire les valeurs des statistiques
            passed = stats.get('packets_passed', 0)
            dropped = stats.get('packets_dropped', 0)
            rate_limited = stats.get('packets_rate_limited', 0)
            invalid_protocol = stats.get('packets_invalid_protocol', 0)
            
            # Mettre à jour les métriques
            self.packets_passed.set(passed)
            self.packets_dropped.set(dropped)
            self.packets_rate_limited.set(rate_limited)
            self.packets_invalid_protocol.set(invalid_protocol)
            
            # Compteurs totaux
            self.packets_total.labels(action='passed')._value._value = passed
            self.packets_total.labels(action='dropped')._value._value = dropped
            self.packets_total.labels(action='rate_limited')._value._value = rate_limited
            
            # Statistiques avancées
            self.sequence_violations.set(stats.get('sequence_violations', 0))
            self.state_violations.set(stats.get('state_violations', 0))
            self.checksum_failures.set(stats.get('checksum_failures', 0))
            
            logger.debug(f"Statistiques collectées: {stats}")
    
    def collect_performance_metrics(self):
        """Collecte les métriques de performance"""
        perf_output = self.run_bpftool_command("map dump name perf_metrics_map")
        if perf_output:
            perf_data = self.parse_bpf_map_output(perf_output)
            
            avg_time = perf_data.get('avg_processing_time_ns', 0)
            self.avg_processing_time.set(avg_time)
            
            logger.debug(f"Métriques de performance: temps moyen = {avg_time}ns")
    
    def collect_attack_metrics(self):
        """Collecte les métriques d'attaque"""
        attack_output = self.run_bpftool_command("map dump name attack_log_map")
        if attack_output:
            # Compter les types d'attaques
            attack_types = {}
            unique_sources = set()
            
            # Parser les logs d'attaque (format dépend de l'implémentation)
            lines = attack_output.split('\n')
            for line in lines:
                if 'attack_type' in line and 'source_ip' in line:
                    # Extraire le type d'attaque et l'IP source
                    # Format attendu: quelque chose comme "attack_type: 1, source_ip: 192.168.1.100"
                    parts = line.split(',')
                    for part in parts:
                        if 'attack_type' in part:
                            attack_type = part.split(':')[1].strip()
                            attack_types[attack_type] = attack_types.get(attack_type, 0) + 1
                        elif 'source_ip' in part:
                            source_ip = part.split(':')[1].strip()
                            unique_sources.add(source_ip)
            
            # Mettre à jour les métriques d'attaque
            for attack_type, count in attack_types.items():
                self.attacks_detected.labels(type=attack_type)._value._value = count
            
            self.attack_sources.set(len(unique_sources))
            
            logger.debug(f"Attaques détectées: {attack_types}, Sources uniques: {len(unique_sources)}")
    
    def check_filter_status(self):
        """Vérifie l'état du filtre XDP"""
        # Vérifier si le programme XDP est chargé
        prog_output = self.run_bpftool_command("prog list")
        if prog_output and 'xdp_fivem_advanced' in prog_output:
            self.filter_active.set(1)
            logger.debug("Filtre XDP actif")
        else:
            self.filter_active.set(0)
            logger.warning("Filtre XDP inactif ou non trouvé")
    
    def collect_all_metrics(self):
        """Collecte toutes les métriques"""
        try:
            logger.debug("Collecte des métriques...")
            
            self.collect_basic_stats()
            self.collect_performance_metrics()
            self.collect_attack_metrics()
            self.check_filter_status()
            
            # Mettre à jour le timestamp
            self.last_update.set(time.time())
            
            logger.debug("Collecte des métriques terminée")
            
        except Exception as e:
            logger.error(f"Erreur lors de la collecte des métriques: {e}")
    
    def run(self):
        """Lance l'exportateur de métriques"""
        logger.info(f"Démarrage du serveur HTTP sur le port {self.port}")
        start_http_server(self.port)
        
        # Définir les informations du filtre
        self.filter_info.info({
            'version': '1.0.0',
            'type': 'fivem_xdp_filter',
            'exporter_version': '1.0.0'
        })
        
        logger.info("Exportateur de métriques démarré")
        
        try:
            while True:
                self.collect_all_metrics()
                time.sleep(self.metrics_interval)
        except KeyboardInterrupt:
            logger.info("Arrêt de l'exportateur de métriques")
        except Exception as e:
            logger.error(f"Erreur fatale: {e}")
            raise

if __name__ == '__main__':
    exporter = FiveMXDPExporter()
    exporter.run()
