# Architecture Overview

This document provides a comprehensive overview of the FiveM XDP filter architecture, design decisions, and implementation details, including the critical compliance fixes.

## System Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Network Interface                        │
│                           (eth0)                               │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                     XDP Hook Point                             │
│                  (Kernel Space)                                │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                  FiveM XDP Filter                              │
│                   (fivem_xdp.c)                                │
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │   Packet        │  │   Security      │  │  Performance    │ │
│  │  Processing     │  │   Validation    │  │   Monitoring    │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                     BPF Maps                                   │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌───────────┐ │
│  │   Config    │ │ Rate Limit  │ │  Security   │ │   Stats   │ │
│  │    Maps     │ │    Maps     │ │    Maps     │ │   Maps    │ │
│  └─────────────┘ └─────────────┘ └─────────────┘ └───────────┘ │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                   User Space Tools                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │  Configuration  │  │   Monitoring    │  │     Build       │ │
│  │     Tools       │  │     Tools       │  │    System       │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### Core Components

#### 1. XDP Filter Core (`fivem_xdp.c`)
**Purpose:** Main packet processing logic with security validation and performance optimization.

**Key Features:**
- Single-pass packet processing
- Multi-layer security validation
- Configurable rate limiting
- Real-time attack detection
- Performance metrics collection

#### 2. Configuration System (Critical Fix 1)
**Purpose:** Runtime configuration management through BPF maps.

**Components:**
- `server_config_map`: Primary configuration storage
- `fivem_xdp_config.c`: Configuration management tool
- Predefined configuration templates
- Zero-downtime configuration updates

#### 3. Security Subsystem
**Purpose:** Comprehensive attack detection and mitigation.

**Components:**
- Protocol validation (Critical Fix 2)
- Checksum validation (Critical Fix 3)
- Rate limiting (Critical Fix 4)
- Attack classification and logging
- Connection state machine

#### 4. Performance Monitoring
**Purpose:** Real-time performance tracking and optimization.

**Components:**
- Packet processing metrics
- Map operation statistics
- Attack detection statistics
- System resource monitoring

## Design Principles

### 1. Performance First
**Principle:** Optimize for minimal latency and maximum throughput.

**Implementation:**
- Single-pass header parsing
- Early packet rejection
- Optimized algorithms (FNV-1a vs CRC32)
- Optional features for performance tuning
- LRU maps for automatic memory management

**Example:**
```c
// Single-pass header parsing (performance optimization)
struct ethhdr *eth = data;
struct iphdr *ip = (void*)eth + sizeof(*eth);
struct udphdr *udp = (void*)ip + (ip->ihl * 4);

// Combined bounds checking
if ((void *)(eth + 1) > data_end ||
    (void *)(ip + 1) > data_end ||
    (void *)(udp + 1) > data_end ||
    ip->ihl < 5) {
    return XDP_ABORTED;
}
```

### 2. Security by Design
**Principle:** Implement defense-in-depth with multiple validation layers.

**Implementation:**
- Hierarchical rate limiting
- Protocol state machine enforcement
- Deep packet inspection
- Attack classification and logging
- Replay attack prevention

**Example:**
```c
// Multi-layer validation
if (!hierarchical_rate_limit(src_ip, config)) return XDP_DROP;
if (!validate_protocol_state(src_ip, first_word, msg_hash)) return XDP_DROP;
if (!validate_enet_checksum(payload, payload_len, data_end, enable_checksum)) return XDP_DROP;
```

### 3. Configuration Flexibility (Critical Fix 4)
**Principle:** Support diverse deployment scenarios through runtime configuration.

**Implementation:**
- BPF map-based configuration
- Predefined server type configurations
- Graceful fallback to defaults
- Zero-downtime configuration updates

**Example:**
```c
// Configurable parameters with fallbacks
__u32 rate_limit = config ? config->rate_limit : DEFAULT_RATE_LIMIT;
__u32 target_ip = config ? config->server_ip : 0; // 0 = accept any IP
```

### 4. Observability
**Principle:** Provide comprehensive monitoring and debugging capabilities.

**Implementation:**
- Real-time statistics collection
- Attack logging with classification
- Performance metrics tracking
- Detailed error reporting

## Critical Compliance Fixes Architecture

### Fix 1: Configurable Server IP Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Configuration Layer                         │
│                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────┐ │
│  │  User Space     │    │   BPF Map       │    │   XDP       │ │
│  │  Config Tool    │───▶│ server_config   │───▶│  Filter     │ │
│  │                 │    │     _map        │    │             │ │
│  └─────────────────┘    └─────────────────┘    └─────────────┘ │
│                                                                 │
│  Features:                                                      │
│  • Runtime configuration updates                               │
│  • Multi-server support (IP = 0)                              │
│  • Predefined server type configs                             │
│  • Graceful fallback to defaults                              │
└─────────────────────────────────────────────────────────────────┘
```

### Fix 2: ENet Header Parsing Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                   ENet Packet Processing                       │
│                                                                 │
│  Packet Structure:                                              │
│  ┌─────────────┬─────────────┬─────────────┬─────────────────┐ │
│  │   Peer ID   │    Flags    │  Sequence   │      Data       │ │
│  │ (12 bits)   │  (4 bits)   │ (16 bits)   │   (variable)    │ │
│  └─────────────┴─────────────┴─────────────┴─────────────────┘ │
│                                                                 │
│  Processing Logic:                                              │
│  1. Extract peer_id = header & 0x0FFF                         │
│  2. Extract flags = (header >> 12) & 0xF                      │
│  3. Validate sequence only for reliable packets (flags & 0x1)  │
│  4. Enforce peer ID limits (0-4095)                           │
└─────────────────────────────────────────────────────────────────┘
```

### Fix 3: Optimized Checksum Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                 Checksum Validation System                     │
│                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────┐ │
│  │   Configuration │    │   FNV-1a Hash   │    │  Optional   │ │
│  │   Check         │───▶│   Calculation   │───▶│ Validation  │ │
│  │                 │    │                 │    │             │ │
│  └─────────────────┘    └─────────────────┘    └─────────────┘ │
│                                                                 │
│  Performance Optimizations:                                    │
│  • Single loop instead of nested loops                        │
│  • Limited to 32 bytes processing                             │
│  • Optional validation (configurable)                         │
│  • FNV-1a algorithm for speed and quality                     │
└─────────────────────────────────────────────────────────────────┘
```

### Fix 4: Configuration Flexibility Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                Configuration Management System                 │
│                                                                 │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────┐ │
│  │   Predefined    │    │   Runtime       │    │   Dynamic   │ │
│  │ Configurations  │───▶│ Configuration   │───▶│ Parameter   │ │
│  │                 │    │    Loading      │    │ Application │ │
│  └─────────────────┘    └─────────────────┘    └─────────────┘ │
│                                                                 │
│  Configuration Types:                                          │
│  • Small server (security-focused)                            │
│  • Medium server (balanced)                                   │
│  • Large server (performance-focused)                         │
│  • Development (permissive)                                   │
│  • Custom (user-defined)                                      │
└─────────────────────────────────────────────────────────────────┘
```

## Data Flow Architecture

### Packet Processing Pipeline

```
Network Packet
      ↓
┌─────────────────┐
│ Header Parsing  │ ← Single-pass optimization
└─────────────────┘
      ↓
┌─────────────────┐
│ Configuration   │ ← Critical Fix 1: Configurable IP
│ Loading         │
└─────────────────┘
      ↓
┌─────────────────┐
│ Protocol        │ ← Early rejection optimization
│ Filtering       │
└─────────────────┘
      ↓
┌─────────────────┐
│ Rate Limiting   │ ← Critical Fix 4: Configurable limits
└─────────────────┘
      ↓
┌─────────────────┐
│ ENet Parsing    │ ← Critical Fix 2: Correct parsing
└─────────────────┘
      ↓
┌─────────────────┐
│ Checksum        │ ← Critical Fix 3: Optimized validation
│ Validation      │
└─────────────────┘
      ↓
┌─────────────────┐
│ Security        │ ← Attack detection and logging
│ Validation      │
└─────────────────┘
      ↓
┌─────────────────┐
│ Decision:       │
│ XDP_PASS or     │
│ XDP_DROP        │
└─────────────────┘
```

## Memory Architecture

### BPF Map Organization

```
┌─────────────────────────────────────────────────────────────────┐
│                        BPF Maps Layout                         │
│                                                                 │
│  Configuration Maps:                                            │
│  ┌─────────────────┐                                           │
│  │server_config_map│ ← Critical Fix 1: Runtime configuration   │
│  │   (1 entry)     │                                           │
│  └─────────────────┘                                           │
│                                                                 │
│  Rate Limiting Maps:                                            │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐  │
│  │ rate_limit_map  │ │ global_rate_map │ │subnet_rate_map  │  │
│  │  (10K entries)  │ │   (1 entry)     │ │ (1K entries)    │  │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘  │
│                                                                 │
│  Security Maps:                                                 │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐  │
│  │enhanced_token   │ │peer_sequence    │ │connection_state │  │
│  │_map (5K entries)│ │_map (4K entries)│ │_map (2K entries)│  │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘  │
│                                                                 │
│  Statistics Maps:                                               │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐  │
│  │enhanced_stats   │ │ attack_log_map  │ │perf_metrics_map │  │
│  │_map (1 entry)   │ │ (1K entries)    │ │   (1 entry)     │  │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Memory Usage Optimization

**LRU Maps for Scalability:**
- Automatic eviction of old entries
- Bounded memory usage
- Optimal cache locality

**Per-CPU Maps for Performance:**
- Eliminates lock contention
- Scales with CPU cores
- Aggregated statistics collection

## Error Handling Architecture

### Graceful Degradation Strategy

```
┌─────────────────────────────────────────────────────────────────┐
│                    Error Handling Hierarchy                    │
│                                                                 │
│  Level 1: Configuration Errors                                 │
│  ┌─────────────────┐                                           │
│  │ Missing Config  │ ──→ Use Default Values                    │
│  │ Invalid Config  │ ──→ Fallback to Safe Defaults            │
│  └─────────────────┘                                           │
│                                                                 │
│  Level 2: Runtime Errors                                       │
│  ┌─────────────────┐                                           │
│  │ Map Lookup Fail │ ──→ Allow Packet (Fail Open)             │
│  │ Memory Pressure │ ──→ Disable Optional Features            │
│  └─────────────────┘                                           │
│                                                                 │
│  Level 3: Packet Errors                                        │
│  ┌─────────────────┐                                           │
│  │ Malformed Packet│ ──→ XDP_ABORTED                          │
│  │ Security Violation ──→ XDP_DROP + Logging                  │
│  └─────────────────┘                                           │
└─────────────────────────────────────────────────────────────────┘
```

## Performance Architecture

### Optimization Strategies

**1. Early Rejection:**
- Validate basic headers first
- Reject non-FiveM traffic immediately
- Minimize processing for invalid packets

**2. Single-Pass Processing:**
- Parse all headers in one pass
- Combined validation checks
- Minimize memory accesses

**3. Configurable Features:**
- Optional checksum validation
- Configurable rate limits
- Performance vs security trade-offs

**4. Efficient Algorithms:**
- FNV-1a hash instead of CRC32
- Bit operations for flag extraction
- Optimized map lookups

## Extensibility Architecture

### Plugin Architecture (Future Enhancement)

```
┌─────────────────────────────────────────────────────────────────┐
│                    Extensibility Framework                     │
│                                                                 │
│  Core Filter:                                                   │
│  ┌─────────────────┐                                           │
│  │   Base XDP      │                                           │
│  │   Filter        │                                           │
│  └─────────────────┘                                           │
│           │                                                     │
│           ▼                                                     │
│  Extension Points:                                              │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐  │
│  │   Custom        │ │   Additional    │ │   Enhanced      │  │
│  │  Validation     │ │   Protocols     │ │   Monitoring    │  │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## Build System Architecture

### Compilation Pipeline

```
Source Files
     ↓
┌─────────────────┐
│ Clang/LLVM      │ ← BPF target compilation
│ Compilation     │
└─────────────────┘
     ↓
┌─────────────────┐
│ BPF Bytecode    │ ← Optimized bytecode generation
│ Generation      │
└─────────────────┘
     ↓
┌─────────────────┐
│ Verification    │ ← BPF verifier validation
└─────────────────┘
     ↓
┌─────────────────┐
│ Deployment      │ ← XDP program loading
└─────────────────┘
```

This architecture provides a solid foundation for high-performance, secure, and maintainable FiveM server protection with all critical compliance fixes properly implemented.
