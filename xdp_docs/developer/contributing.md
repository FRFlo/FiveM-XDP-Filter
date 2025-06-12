# Contributing Guidelines

This document provides guidelines for contributing to the FiveM XDP filter project, including code standards, review process, development environment setup, and submission requirements.

## Contributing Overview

We welcome contributions to the FiveM XDP filter project! Whether you're fixing bugs, adding features, improving documentation, or enhancing performance, your contributions help make FiveM servers more secure and performant.

### Types of Contributions

- **Bug Fixes**: Resolving issues in existing functionality
- **Feature Enhancements**: Adding new security or performance features
- **Performance Optimizations**: Improving processing speed or resource usage
- **Documentation**: Improving or expanding documentation
- **Testing**: Adding or improving test coverage
- **Security Improvements**: Enhancing attack detection or mitigation

## Development Environment Setup

### Prerequisites

#### System Requirements
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y \
    clang \
    llvm \
    libbpf-dev \
    linux-headers-$(uname -r) \
    bpftool \
    git \
    make \
    gcc \
    python3 \
    python3-pip

# CentOS/RHEL
sudo dnf install -y \
    clang \
    llvm \
    libbpf-devel \
    kernel-headers \
    kernel-devel \
    bpftool \
    git \
    make \
    gcc \
    python3 \
    python3-pip
```

#### Development Tools
```bash
# Install additional development tools
pip3 install --user \
    black \
    flake8 \
    pytest \
    pre-commit

# Install BPF development tools
sudo apt install -y \
    linux-tools-common \
    linux-tools-$(uname -r) \
    trace-cmd
```

### Repository Setup

#### 1. Fork and Clone
```bash
# Fork the repository on GitHub
# Then clone your fork
git clone https://github.com/YOUR_USERNAME/fivem-xdp-filter.git
cd fivem-xdp-filter

# Add upstream remote
git remote add upstream https://github.com/citizenfx/fivem.git
```

#### 2. Development Branch Setup
```bash
# Create development branch
git checkout -b feature/your-feature-name

# Keep your fork updated
git fetch upstream
git rebase upstream/master
```

#### 3. Pre-commit Hooks
```bash
# Install pre-commit hooks
pre-commit install

# Test pre-commit hooks
pre-commit run --all-files
```

## Code Standards

### C Code Standards

#### 1. Coding Style
```c
// Use consistent indentation (4 spaces, no tabs)
// Follow Linux kernel coding style for BPF programs

// Good example:
static __always_inline int validate_packet(__u32 src_ip, __u16 dest_port) {
    struct server_config *config = get_server_config();
    if (!config) {
        return 0;  // Fail open if no config
    }
    
    // Check rate limits
    if (!check_rate_limit(src_ip, config->rate_limit)) {
        log_attack(src_ip, ATTACK_RATE_LIMIT);
        return 0;
    }
    
    return 1;
}

// Bad example:
static __always_inline int validate_packet(__u32 src_ip,__u16 dest_port){
struct server_config*config=get_server_config();
if(!config)return 0;
if(!check_rate_limit(src_ip,config->rate_limit)){log_attack(src_ip,ATTACK_RATE_LIMIT);return 0;}
return 1;
}
```

#### 2. Naming Conventions
```c
// Functions: snake_case
static __always_inline int validate_enet_header(void *data);

// Variables: snake_case
__u32 source_ip;
__u16 destination_port;

// Constants: UPPER_SNAKE_CASE
#define MAX_PACKET_SIZE     2400
#define ATTACK_RATE_LIMIT   1

// Structures: snake_case
struct server_config {
    __u32 server_ip;
    __u32 rate_limit;
};

// Enums: snake_case with prefix
enum attack_type {
    ATTACK_RATE_LIMIT = 1,
    ATTACK_INVALID_PROTOCOL = 2,
    ATTACK_REPLAY = 3
};
```

#### 3. Documentation Standards
```c
/**
 * validate_fivem_message_hash - Validate FiveM message hash
 * @hash: Message hash to validate
 * 
 * Validates that the provided hash matches one of the known FiveM message types.
 * This function implements the complete set of 28 known message hashes used by
 * FiveM for protocol communication.
 * 
 * Returns: 1 if hash is valid, 0 if invalid
 */
static __always_inline int validate_fivem_message_hash(__u32 hash) {
    // Implementation...
}

/**
 * BPF Map Definitions
 * 
 * server_config_map: Stores runtime configuration parameters
 * - Key: __u32 (always 0)
 * - Value: struct server_config
 * - Max entries: 1
 */
struct {
    __uint(type, BPF_MAP_TYPE_ARRAY);
    __uint(max_entries, 1);
    __type(key, __u32);
    __type(value, struct server_config);
} server_config_map SEC(".maps");
```

### Performance Requirements

#### 1. Processing Efficiency
```c
// Always use __always_inline for hot path functions
static __always_inline int hot_path_function(void) {
    // Keep hot path functions under 50 lines
    // Minimize map lookups
    // Use early returns for common cases
}

// Optimize for common cases first
if (likely(common_condition)) {
    // Fast path
    return handle_common_case();
}

// Handle edge cases
return handle_edge_case();
```

#### 2. Memory Efficiency
```c
// Use appropriate data types
__u8  small_values;     // 0-255
__u16 medium_values;    // 0-65535
__u32 large_values;     // 0-4294967295

// Pack structures efficiently
struct __attribute__((packed)) efficient_struct {
    __u8  flags;        // 1 byte
    __u16 port;         // 2 bytes
    __u32 ip_address;   // 4 bytes
    // Total: 7 bytes instead of 8-12 with padding
};
```

### Security Requirements

#### 1. Input Validation
```c
// Always validate packet bounds
if ((void *)(eth + 1) > data_end ||
    (void *)(ip + 1) > data_end ||
    (void *)(udp + 1) > data_end) {
    return XDP_ABORTED;  // Malformed packet
}

// Validate data ranges
if (peer_id > ENET_MAX_PEER_ID) {
    log_attack(src_ip, ATTACK_INVALID_PROTOCOL);
    return XDP_DROP;
}
```

#### 2. Error Handling
```c
// Fail securely
struct server_config *config = get_server_config();
if (!config) {
    // Use secure defaults when configuration unavailable
    return apply_default_security_policy(src_ip);
}

// Log security events
static __always_inline void log_security_event(__u32 src_ip, __u8 event_type) {
    struct attack_log entry = {
        .source_ip = src_ip,
        .attack_type = event_type,
        .timestamp = bpf_ktime_get_ns(),
        .count = 1
    };
    
    bpf_map_update_elem(&attack_log_map, &src_ip, &entry, BPF_ANY);
}
```

## Testing Requirements

### Unit Testing

#### 1. Test Coverage Requirements
```bash
# All new functions must have unit tests
# Minimum 80% code coverage for new code
# Critical security functions require 100% coverage

# Example test structure
test_new_feature() {
    echo "Testing new feature..."
    
    # Test normal cases
    test_normal_input
    
    # Test edge cases
    test_edge_cases
    
    # Test error conditions
    test_error_conditions
    
    # Test security implications
    test_security_aspects
}
```

#### 2. Performance Testing
```bash
# Performance tests required for:
# - New packet processing functions
# - Modified hot path code
# - New BPF map operations

benchmark_new_feature() {
    echo "Benchmarking new feature..."
    
    # Measure latency impact
    measure_latency_impact
    
    # Measure throughput impact
    measure_throughput_impact
    
    # Verify no performance regression
    verify_no_regression
}
```

### Integration Testing

#### 1. Protocol Compliance
```bash
# Test with real FiveM traffic
test_fivem_compatibility() {
    # Test with different FiveM client versions
    # Test with various server configurations
    # Verify protocol compliance
}
```

#### 2. Security Testing
```bash
# Security validation required
test_security_features() {
    # Test attack detection
    # Test mitigation effectiveness
    # Verify no bypass methods
}
```

## Submission Process

### Pull Request Guidelines

#### 1. PR Preparation
```bash
# Before submitting PR:
# 1. Ensure all tests pass
make test

# 2. Run performance benchmarks
make benchmark

# 3. Update documentation
# Update relevant .md files in xdp_docs/

# 4. Run code formatting
clang-format -i *.c
black *.py

# 5. Commit with descriptive message
git commit -m "feat: add enhanced rate limiting for subnet attacks

- Implement subnet-based rate limiting
- Add configuration option for subnet limits
- Include comprehensive testing
- Update documentation

Fixes #123"
```

#### 2. PR Template
```markdown
## Description
Brief description of changes and motivation.

## Type of Change
- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Performance improvement
- [ ] Documentation update

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests pass
- [ ] Performance tests pass
- [ ] Security tests pass

## Performance Impact
- Latency impact: +/- X μs
- Throughput impact: +/- X PPS
- Memory impact: +/- X MB

## Security Impact
- [ ] No security implications
- [ ] Enhances security
- [ ] Requires security review

## Documentation
- [ ] Code comments updated
- [ ] Documentation updated
- [ ] README updated if needed

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Tests added for new functionality
- [ ] All tests pass
- [ ] Documentation updated
```

### Code Review Process

#### 1. Review Criteria
- **Functionality**: Does the code work as intended?
- **Performance**: Does it meet performance requirements?
- **Security**: Are there any security implications?
- **Style**: Does it follow coding standards?
- **Testing**: Is test coverage adequate?
- **Documentation**: Is documentation complete and accurate?

#### 2. Review Timeline
- **Initial Review**: Within 48 hours
- **Follow-up Reviews**: Within 24 hours
- **Final Approval**: Within 72 hours of submission

### Merge Requirements

#### 1. Approval Requirements
- At least 2 approvals from maintainers
- All CI/CD checks must pass
- No unresolved review comments
- Documentation updated as needed

#### 2. Merge Process
```bash
# Maintainer merge process:
# 1. Verify all requirements met
# 2. Rebase on latest master
git rebase upstream/master

# 3. Run final tests
make test-all

# 4. Merge with descriptive commit
git merge --no-ff feature-branch
```

## Communication Guidelines

### Issue Reporting

#### 1. Bug Reports
```markdown
**Bug Description**
Clear description of the bug.

**Environment**
- OS: Ubuntu 22.04
- Kernel: 5.15.0
- FiveM Version: 2944
- XDP Filter Version: 1.0.0

**Steps to Reproduce**
1. Step one
2. Step two
3. Step three

**Expected Behavior**
What should happen.

**Actual Behavior**
What actually happens.

**Additional Context**
Any additional information.
```

#### 2. Feature Requests
```markdown
**Feature Description**
Clear description of the requested feature.

**Use Case**
Why is this feature needed?

**Proposed Implementation**
How should this be implemented?

**Alternatives Considered**
What alternatives were considered?
```

### Community Guidelines

#### 1. Code of Conduct
- Be respectful and inclusive
- Focus on constructive feedback
- Help others learn and improve
- Maintain professional communication

#### 2. Getting Help
- Check existing documentation first
- Search existing issues
- Ask questions in discussions
- Provide detailed context when asking for help

## Release Process

### Version Management

#### 1. Semantic Versioning
- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

#### 2. Release Checklist
- [ ] All tests pass
- [ ] Performance benchmarks meet requirements
- [ ] Documentation updated
- [ ] Security review completed
- [ ] Changelog updated
- [ ] Version numbers updated

### Maintenance

#### 1. Long-term Support
- Critical security fixes backported
- Performance improvements considered
- Documentation kept current

#### 2. Deprecation Policy
- 6-month notice for breaking changes
- Migration guides provided
- Legacy support maintained during transition

## Recognition

Contributors are recognized through:
- GitHub contributor statistics
- Release notes acknowledgments
- Community recognition
- Maintainer nominations for significant contributions

Thank you for contributing to the FiveM XDP filter project! Your contributions help make FiveM servers more secure and performant for the entire community.
