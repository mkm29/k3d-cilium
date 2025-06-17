# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This repository demonstrates how to run Kubernetes clusters using k3d (Kubernetes in Docker) with advanced CNI solutions - either Calico or Cilium. It provides production-ready configurations for development and testing environments using Podman as the container runtime.

## Essential Commands

### Build and Development Commands

#### Justfile Commands
```bash
# Show all available commands
just --list

# Verify required tools are installed
just preflight

# Create k3d cluster
just create-cluster  # Uses default or env vars
K3D_CONFIG=infrastructure/k3d/cilium-config.yaml just create-cluster  # For Cilium
K3D_CONFIG=infrastructure/k3d/calico-config.yaml just create-cluster  # For Calico

# Quick setup recipes (recommended)
just setup-cilium        # Complete Cilium cluster setup
just setup-calico        # Complete Calico cluster setup
just setup-calico-ebpf   # Calico cluster with eBPF dataplane

# Individual operations
just install-cilium      # Install Cilium
just install-calico      # Install Calico
just enable-calico-ebpf  # Enable eBPF dataplane for Calico
just patch-nodes         # Mount BPF filesystem (required for Cilium)

# Utilities
just status              # Show cluster and pod status
just test-connectivity   # Run connectivity tests

# Cleanup
just delete-cluster
```

#### Environment Variables
- `CLUSTER_NAME`: k3d cluster name (default: "calico")
- `K3D_CONFIG`: Path to k3d config file (default: "infrastructure/k3d/calico-config.yaml")

#### Just Configuration
The justfile has the following settings configured:
- Uses `zsh` shell with error handling (`-cu` flags)
- Automatically exports all variables as environment variables
- Loads `.env` files if present
- Runs in quiet mode (use `just --verbose` to see commands)
- Ignores comments in `.env` files

### Testing and Validation
```bash
# Verify Cilium installation
cilium status --wait
cilium connectivity test

# Verify Calico installation
calicoctl get nodes
kubectl get pods -n kube-system | grep calico
```

## Architecture and Key Patterns

### Project Structure
- `infrastructure/cilium/values.yaml` - Cilium Helm chart configuration with production settings
- `infrastructure/k3d/` - k3d cluster configurations for different CNI setups
- `justfile` - Build automation using just command runner

### High-Level Architecture
1. **Container Runtime**: Podman (running in a VM on macOS)
2. **Kubernetes Distribution**: k3s via k3d
3. **CNI Options**:
   - **Calico**: Traditional networking with optional eBPF dataplane
   - **Cilium**: eBPF-native networking with advanced observability

### Key Configuration Patterns

#### k3d Configurations
Both CNI configurations disable k3s default networking and expose necessary ports:
- API server: 6445
- HTTP: 8080
- HTTPS: 8443

#### Cilium Configuration
Located in `infrastructure/cilium/values.yaml`:
- eBPF-based kube-proxy replacement
- Hubble observability enabled
- BGP control plane support
- Gateway API integration
- Production-ready security policies

#### Calico Configuration
- Supports both iptables and eBPF dataplanes
- Felix configuration for advanced networking
- Prometheus metrics integration

## Important Notes

- Always run `make preflight` before starting to ensure all tools are available
- The default k3d cluster name is "cilium" - use K3D_CLUSTER env var to override
- BPF filesystem mounting (`make patch-nodes`) is critical for Cilium operation
- When switching between CNIs, always delete the cluster and start fresh
- The project assumes Podman is properly configured with adequate resources (CPU: 4+, Memory: 8GB+)