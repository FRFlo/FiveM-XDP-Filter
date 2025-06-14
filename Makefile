# FiveM XDP Filter Makefile
# Builds the compliance-fixed XDP filter and configuration tools

# Compiler settings
CLANG ?= clang
GCC ?= gcc
CFLAGS := -O2 -Wall -Wextra
# Détection automatique des chemins d'en-têtes
KERNEL_HEADERS := $(shell find /usr/src -name "linux-headers*" -type d 2>/dev/null | head -1)
ifeq ($(KERNEL_HEADERS),)
    KERNEL_HEADERS := /usr/include
endif

BPF_CFLAGS := -O2 -target bpf -D__TARGET_ARCH_x86 \
    -I$(KERNEL_HEADERS)/include \
    -I$(KERNEL_HEADERS)/arch/x86/include \
    -I/usr/include \
    -I/usr/include/x86_64-linux-gnu
LDFLAGS := -lbpf

# Source files
XDP_SOURCE := fivem_xdp.c
CONFIG_SOURCE := fivem_xdp_config.c
XDP_OBJECT := fivem_xdp.o
CONFIG_BINARY := fivem_xdp_config

# Default target
all: $(XDP_OBJECT) $(CONFIG_BINARY)

# Build XDP program
$(XDP_OBJECT): $(XDP_SOURCE)
	@echo "Building FiveM XDP filter with compliance fixes..."
	$(CLANG) $(BPF_CFLAGS) -c $< -o $@
	@echo "✅ XDP filter compiled successfully"

# Build configuration tool
$(CONFIG_BINARY): $(CONFIG_SOURCE)
	@echo "Building configuration tool..."
	$(GCC) $(CFLAGS) $< -o $@ $(LDFLAGS)
	@echo "✅ Configuration tool compiled successfully"

# Install XDP program (requires root)
install: $(XDP_OBJECT)
	@echo "Installing XDP program..."
	@if [ "$(INTERFACE)" = "" ]; then \
		echo "❌ Error: INTERFACE not specified"; \
		echo "Usage: make install INTERFACE=eth0"; \
		exit 1; \
	fi
	@if [ "$$(id -u)" != "0" ]; then \
		echo "❌ Error: Installation requires root privileges"; \
		echo "Usage: sudo make install INTERFACE=eth0"; \
		exit 1; \
	fi
	ip link set dev $(INTERFACE) xdp obj $(XDP_OBJECT) sec xdp_fivem_advanced
	@echo "✅ XDP filter installed on interface $(INTERFACE)"

# Uninstall XDP program (requires root)
uninstall:
	@echo "Uninstalling XDP program..."
	@if [ "$(INTERFACE)" = "" ]; then \
		echo "❌ Error: INTERFACE not specified"; \
		echo "Usage: make uninstall INTERFACE=eth0"; \
		exit 1; \
	fi
	@if [ "$$(id -u)" != "0" ]; then \
		echo "❌ Error: Uninstallation requires root privileges"; \
		echo "Usage: sudo make uninstall INTERFACE=eth0"; \
		exit 1; \
	fi
	ip link set dev $(INTERFACE) xdp off
	@echo "✅ XDP filter uninstalled from interface $(INTERFACE)"

# Configure for small server
config-small: $(CONFIG_BINARY)
	@echo "Configuring for small server..."
	@if [ "$(SERVER_IP)" = "" ]; then \
		echo "❌ Error: SERVER_IP not specified"; \
		echo "Usage: make config-small SERVER_IP=192.168.1.100"; \
		exit 1; \
	fi
	./$(CONFIG_BINARY) $(SERVER_IP) small
	@echo "✅ Small server configuration applied"

# Configure for medium server
config-medium: $(CONFIG_BINARY)
	@echo "Configuring for medium server..."
	@if [ "$(SERVER_IP)" = "" ]; then \
		echo "❌ Error: SERVER_IP not specified"; \
		echo "Usage: make config-medium SERVER_IP=192.168.1.100"; \
		exit 1; \
	fi
	./$(CONFIG_BINARY) $(SERVER_IP) medium
	@echo "✅ Medium server configuration applied"

# Configure for large server
config-large: $(CONFIG_BINARY)
	@echo "Configuring for large server..."
	@if [ "$(SERVER_IP)" = "" ]; then \
		echo "❌ Error: SERVER_IP not specified"; \
		echo "Usage: make config-large SERVER_IP=192.168.1.100"; \
		exit 1; \
	fi
	./$(CONFIG_BINARY) $(SERVER_IP) large
	@echo "✅ Large server configuration applied"

# Configure for development
config-dev: $(CONFIG_BINARY)
	@echo "Configuring for development..."
	@if [ "$(SERVER_IP)" = "" ]; then \
		echo "❌ Error: SERVER_IP not specified"; \
		echo "Usage: make config-dev SERVER_IP=127.0.0.1"; \
		exit 1; \
	fi
	./$(CONFIG_BINARY) $(SERVER_IP) dev
	@echo "✅ Development configuration applied"

# Show statistics
stats:
	@echo "FiveM XDP Filter Statistics:"
	@echo "============================"
	@if command -v bpftool >/dev/null 2>&1; then \
		echo "Enhanced Statistics:"; \
		bpftool map dump name enhanced_stats_map 2>/dev/null || echo "Map not found or no data"; \
		echo ""; \
		echo "Performance Metrics:"; \
		bpftool map dump name perf_metrics_map 2>/dev/null || echo "Map not found or no data"; \
		echo ""; \
		echo "Attack Log (last 10 entries):"; \
		bpftool map dump name attack_log_map 2>/dev/null | tail -20 || echo "Map not found or no data"; \
	else \
		echo "❌ bpftool not found. Install bpftool to view statistics."; \
	fi

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -f $(XDP_OBJECT) $(CONFIG_BINARY)
	@echo "✅ Clean complete"

# Verify XDP program
verify: $(XDP_OBJECT)
	@echo "Verifying XDP program..."
	@if command -v bpftool >/dev/null 2>&1; then \
		bpftool prog load $(XDP_OBJECT) /sys/fs/bpf/test_prog type xdp && \
		echo "✅ XDP program verification successful" && \
		rm -f /sys/fs/bpf/test_prog; \
	else \
		echo "❌ bpftool not found. Cannot verify program."; \
	fi

# Show help
help:
	@echo "FiveM XDP Filter Build System"
	@echo "============================="
	@echo ""
	@echo "Build targets:"
	@echo "  all              - Build XDP filter and configuration tool"
	@echo "  fivem_xdp.o      - Build XDP filter only"
	@echo "  fivem_xdp_config - Build configuration tool only"
	@echo ""
	@echo "Installation targets (require root):"
	@echo "  install INTERFACE=eth0    - Install XDP filter on network interface"
	@echo "  uninstall INTERFACE=eth0  - Remove XDP filter from network interface"
	@echo ""
	@echo "Configuration targets:"
	@echo "  config-small SERVER_IP=x.x.x.x   - Configure for small server (≤32 players)"
	@echo "  config-medium SERVER_IP=x.x.x.x  - Configure for medium server (32-128 players)"
	@echo "  config-large SERVER_IP=x.x.x.x   - Configure for large server (128+ players)"
	@echo "  config-dev SERVER_IP=x.x.x.x     - Configure for development (permissive)"
	@echo ""
	@echo "Monitoring targets:"
	@echo "  stats            - Show filter statistics and performance metrics"
	@echo "  verify           - Verify XDP program can be loaded"
	@echo ""
	@echo "Utility targets:"
	@echo "  clean            - Remove build artifacts"
	@echo "  help             - Show this help message"
	@echo ""
	@echo "Example workflow:"
	@echo "  1. make all"
	@echo "  2. sudo make install INTERFACE=eth0"
	@echo "  3. make config-medium SERVER_IP=192.168.1.100"
	@echo "  4. make stats"
	@echo ""
	@echo "Critical fixes implemented:"
	@echo "  ✅ Configurable server IP (no more localhost hardcoding)"
	@echo "  ✅ Corrected ENet packet parsing"
	@echo "  ✅ Optimized checksum validation"
	@echo "  ✅ Flexible configuration system"

# Declare phony targets
.PHONY: all install uninstall config-small config-medium config-large config-dev stats clean verify help

# Default help if no target specified
.DEFAULT_GOAL := help
