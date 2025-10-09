# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This repository provides a development environment for running k3d (Kubernetes in Docker) clusters with either Cilium or Calico CNI. It supports Docker or Podman as container runtimes and includes automation via `just` recipes for quick cluster setup and management.

## Essential Commands

All commands are executed using the `just` task runner. Key commands:

### Cluster Management
```bash
# Quick setup (recommended approaches)
just setup-cilium              # Complete Cilium cluster setup
just setup-calico              # Complete Calico cluster setup
just setup-calico-ebpf         # Calico cluster with eBPF dataplane

# Step-by-step cluster creation
just preflight                 # Check required tools
just create-cluster            # Create cluster (CNI-agnostic)
just delete-cluster            # Delete cluster

# Cluster inspection
just status                    # Show cluster and pod status
just test-connectivity         # Test network connectivity (CNI-aware)
```

### CNI-Specific Operations
```bash
# Cilium
just patch-nodes               # Mount BPF filesystem (required for Cilium)
just install-cilium            # Install Cilium CNI
just uninstall-cilium          # Remove Cilium
cilium status --wait           # Verify Cilium installation
cilium connectivity test       # Run Cilium connectivity tests
cilium hubble ui               # Access Hubble observability UI

# Calico
just install-calico            # Install Calico CNI
just uninstall-calico          # Remove Calico
just enable-calico-ebpf        # Enable eBPF dataplane
just disable-calico-ebpf       # Revert to iptables dataplane
kubectl get pods -n calico-system      # Check Calico pods
kubectl get pods -n tigera-operator    # Check Calico operator

# Supporting CRDs
just install-prometheus-crds   # Install Prometheus Operator CRDs
just install-gateway-api       # Install Gateway API CRDs
```

### Configuration Management
```bash
# Registry credentials (optional)
just decrypt-sops              # Decrypt encrypted secrets
just process-registries        # Process registry config with env vars
just cleanup-temp              # Clean up temporary decrypted files
```

## Architecture and Key Patterns

### Configuration Selection
The repository uses environment variables to determine which CNI and cluster configuration to use:

- **`CNI_TYPE`** (default: "calico"): Determines which CNI to install and which k3d config file to use
- **`CLUSTER_NAME`** (default: "uds-dev"): Name of the k3d cluster
- **`k3d_config`**: Automatically set to `infrastructure/k3d/config/${CNI_TYPE}.yaml`

Configuration priority (highest to lowest):
1. Environment variables exported in shell
2. Values in `cluster.env` file (dotenv format)
3. Default values in justfile

### Directory Structure
```
infrastructure/
├── cilium/
│   ├── values.yaml          # Cilium Helm values
│   └── default.values.yml   # Default Cilium values reference
├── k3d/
│   └── config/
│       ├── cilium.yaml      # k3d config for Cilium
│       ├── calico.yaml      # k3d config for Calico
│       └── registries.yaml  # Private registry configuration template
```

### Secret Management with SOPS
The repository supports encrypted registry credentials using SOPS:

1. Create `.secrets.enc.env` with registry credentials
2. Encrypt using: `sops -e -i .secrets.enc.env`
3. SOPS AGE key must exist at: `~/.config/sops/age/keys.txt`
4. The `create-cluster` recipe automatically:
   - Decrypts `.secrets.enc.env` → `.secrets.env`
   - Substitutes env vars in `registries.yaml` → `registries-processed.yaml`
   - Passes processed config to k3d
   - Cleans up temporary files

### CNI-Specific Requirements

#### Cilium Requirements
- **BPF Filesystem**: Must mount BPF filesystem on all nodes (use `just patch-nodes`)
- **k3s Arguments**: Requires `--disable-network-policy`, `--flannel-backend=none`, and disabled services (traefik, servicelb, metrics-server)
- **Prometheus CRDs**: Optional but recommended for ServiceMonitor support
- **Cluster CIDR**: Uses `10.42.0.0/16` for pods, `10.96.0.0/12` for services
- **Native Routing**: Configured with `ipv4NativeRoutingCIDR: "10.0.0.0/9"`

#### Calico Requirements
- **k3s Arguments**: Requires `--flannel-backend=none`, `--disable-network-policy`
- **Operator-based**: Uses Tigera operator for installation
- **Container IP Forwarding**: Automatically enabled via Installation patch
- **Dataplane Modes**: Supports standard (iptables) and eBPF dataplanes
- **Cluster CIDR**: Uses `10.42.0.0/16` for pods, `10.96.0.0/12` for services

## Key Configuration Files

### Cilium Values (`infrastructure/cilium/values.yaml`)
Notable settings:
- **BPF masquerading**: Enabled for pod-to-pod communication
- **kube-proxy replacement**: Fully replaces kube-proxy with eBPF
- **Hubble**: Observability with metrics, relay, and UI enabled
- **Encryption**: WireGuard with node-to-node encryption
- **SPIRE**: mTLS support with automatic installation
- **Clustermesh**: Configured for multi-cluster support (ports 32379, 32380)
- **ServiceMonitors**: Disabled by default (requires Prometheus Operator)

### k3d Configuration Files
Both CNI configs share common patterns:
- **k3s version**: `rancher/k3s:v1.32.5-k3s1`
- **Topology**: 1 server node, 2 agent nodes
- **Disabled services**: Traefik (both), servicelb (Cilium), metrics-server (Cilium)
- **Network isolation**: Flannel and network policy disabled for CNI replacement

Key differences:
- **Cilium**: Subnet `10.0.0.0/9`, no load balancer ports exposed by default
- **Calico**: Subnet `10.42.0.0/16`, ports 8080:80 and 6443:6443 exposed, worker role labels on agents

## Workflow Patterns

### Creating a New Cluster
```bash
# 1. (Optional) Configure environment
echo "CNI_TYPE=cilium" > cluster.env
echo "CLUSTER_NAME=dev-cluster" >> cluster.env

# 2. (Optional) Set up encrypted registry credentials
cat > .secrets.enc.env <<EOF
DOCKER_HUB_USERNAME=myuser
DOCKER_HUB_PASSWORD=mypass
EOF
sops -e -i .secrets.enc.env

# 3. Create cluster
just setup-cilium  # or just setup-calico

# 4. Verify
kubectl get nodes
kubectl get pods -A
```

### Switching Between CNIs
To switch CNIs, you must delete and recreate the cluster:
```bash
# Delete existing cluster
just delete-cluster

# Change CNI type
export CNI_TYPE=calico  # or CNI_TYPE=cilium

# Create new cluster
just setup-calico  # or just setup-cilium
```

### Enabling Calico eBPF Mode
```bash
# After creating Calico cluster
just enable-calico-ebpf

# Verify
kubectl get installation default -o jsonpath='{.spec.calicoNetwork.linuxDataplane}'
# Should output: BPF

# To revert
just disable-calico-ebpf
```

## Important Notes

- **macOS + Podman**: Docker Desktop is recommended over Podman on macOS due to reliability issues
- **BPF Filesystem**: Cilium requires `just patch-nodes` after cluster creation to mount BPF filesystem
- **Calico Installation**: Uses operator-based installation (Tigera operator), requires waiting for `tigerastatus` conditions
- **Clean State**: Always run `just delete-cluster` before recreating a cluster with different CNI
- **SOPS Key**: Ensure SOPS AGE key exists at `~/.config/sops/age/keys.txt` before using encrypted secrets
- **Typo in Cilium values**: `cluster.name` is misspelled as "clsuter-1" (line 5)
- **Clustermesh typo**: First cluster name is "clister-1" instead of "cluster-1" (line 129)

## Troubleshooting Common Issues

### Cilium BPF Mount Failures
```bash
# Verify BPF mounts
for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
    docker exec $node mount | grep bpf
done

# Remount if needed
just patch-nodes
```

### Calico Connectivity Issues
```bash
# Check Calico components
kubectl get pods -n calico-system -o wide
kubectl get pods -n tigera-operator

# Check IP pools
kubectl get ippools -o wide

# Verify container IP forwarding is enabled
kubectl get installation default -o jsonpath='{.spec.calicoNetwork.containerIPForwarding}'
# Should output: Enabled
```

### Registry Authentication Failures
```bash
# Verify SOPS decryption
just decrypt-sops
cat .secrets.env  # Should show unencrypted credentials

# Check processed registries config
just process-registries
cat infrastructure/k3d/config/registries-processed.yaml

# Clean up and retry
just cleanup-temp
just create-cluster
```
