# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2025-01-18

### Added

- **Multi-CNI Support**: Complete support for both Calico and Cilium CNI with dedicated configuration files
- **Docker Support**: Added Docker as a recommended container runtime option, especially for macOS users
- **Dynamic Configuration**: k3d config file now automatically selected based on `CNI_TYPE` variable
- **SOPS Integration**: Encrypted registry credentials using SOPS with AGE encryption
  - Automatic environment variable substitution in registries.yaml
  - New justfile recipes for SOPS operations (`decrypt-sops`, `process-registries`, `cleanup-temp`)
  - Support for `.secrets.enc.env` encrypted credential files
  - Automatic cleanup of temporary sensitive files
- **Enhanced Observability**:
  - Service monitor support for Hubble and Prometheus in Cilium values.yaml
  - Prometheus metrics integration for both CNIs
  - Complete monitoring configuration for production readiness
- **eBPF Support**: 
  - Full eBPF dataplane support for both Calico and Cilium
  - Dedicated recipes for enabling/disabling eBPF mode
  - Comprehensive eBPF documentation and troubleshooting
- **Advanced Networking Features**:
  - BGP support for Calico
  - Network policies for both CNIs
  - Gateway API support
  - Multiple IP pool management
- **Production-Ready Configurations**:
  - Consistent subnet configuration across CNIs
  - Updated to Calico v3.30.1 and latest Cilium
  - k3s v1.31.5+ support
- **Comprehensive Documentation**:
  - Architecture diagrams using Mermaid
  - Detailed setup guides for both Docker and Podman
  - Troubleshooting section with common issues and solutions
  - Advanced topics covering performance tuning and custom configurations
- **Automation**:
  - Complete k3d cluster automation with justfile
  - Quick setup recipes for both CNIs
  - Preflight checks for all required tools
  - Cross-platform support with justfile

### Changed

- **Variable Naming**: Renamed `cluster_type` to `cni_type` for clarity
- **Configuration Path**: k3d config now uses dynamic path `infrastructure/k3d/config/${CNI_TYPE}.yaml`
- **Default Values**: 
  - Default cluster name changed to "uds-dev"
  - Default CNI type is "calico"
- **Documentation Structure**:
  - Split README into main README.md and README-CILIUM.md
  - Updated all examples to show both Docker and Podman options
  - Added warnings about Podman limitations on macOS
- **Repository References**: Updated from k3d-podman to k3d-cilium throughout
- **Shell Configuration**: Updated justfile from `-cu` to `-c` for better compatibility
- **Resource Management**: Using server-side apply for CRDs

### Fixed

- Shell parameter errors when using justfile with strict zsh configurations
- SSH_CONNECTION parameter not set error in justfile execution
- k3d cluster creation failure due to smart quotes in cluster-cidr configuration
- Connectivity test race condition where CNI policies weren't fully applied before testing
- Test output verbosity - connectivity test now only checks for HTTP 200 status
- Calico installation process to use `kubectl create` instead of `apply` for initial resources
- Container IP forwarding automatically enabled for Calico

### Security

- Added encrypted credential storage using SOPS with AGE encryption
- Automatic cleanup of decrypted credential files
- Enhanced .gitignore patterns for sensitive data protection
- Implemented secure defaults for network policies
- Registry authentication properly handled through encrypted environment files

## Contributors

- [@mkm29](https://github.com/mkm29) - Project maintainer and primary contributor

## Links

- [Project Repository](https://github.com/mkm29/k3d-cilium)
- [Issue Tracker](https://github.com/mkm29/k3d-cilium/issues)
- [Documentation](https://github.com/mkm29/k3d-cilium/blob/main/README.md)

[Unreleased]: https://github.com/mkm29/k3d-cilium/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/mkm29/k3d-cilium/releases/tag/v0.1.0