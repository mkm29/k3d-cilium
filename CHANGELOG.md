# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- SOPS integration for encrypted registry credentials
- Automatic environment variable substitution in registries.yaml
- New justfile recipes for SOPS operations (`decrypt-sops`, `process-registries`, `cleanup-temp`)
- Support for `.secrets.enc.env` encrypted credential files
- Automatic cleanup of temporary sensitive files
- Enhanced preflight checks for SOPS and envsubst tools
- Service monitor support for Hubble and Prometheus in Cilium values.yaml
- Enhanced observability configuration for Cilium
- Complete k3d cluster automation with justfile
- Support for both Calico and Cilium CNI configurations
- Comprehensive documentation with architecture diagrams
- eBPF dataplane support for both Calico and Cilium
- Production-ready configurations for development environments
- Multi-CNI support with dedicated configuration files
- Advanced networking features including BGP and network policies
- Prometheus metrics integration
- Gateway API support
- Comprehensive troubleshooting documentation
- Initial project setup with basic k3d and Podman integration
- Basic Calico CNI support
- Fundamental documentation and setup guides
- Core networking configuration

### Changed

- Updated shell configuration in justfile from `-cu` to `-c` for better compatibility
- Modified `create-cluster` recipe to automatically handle SOPS decryption and registry processing
- Updated `delete-cluster` recipe to include automatic cleanup of temporary files
- Enhanced .gitignore to exclude sensitive temporary files
- Updated Cilium configuration with improved monitoring capabilities
- Migrated from Makefile to justfile for better cross-platform support
- Updated to use Calico v3.30.0 and Cilium latest versions
- Enhanced cluster configuration with consistent subnet and image versions
- Improved documentation structure with detailed setup guides

### Fixed

- Shell parameter errors when using justfile with strict zsh configurations
- SSH_CONNECTION parameter not set error in justfile execution
- Server-side apply configurations for better resource management
- Subnet consistency across different CNI configurations
- Image version alignment for reliable deployments
- k3d cluster creation failure due to smart quotes in cluster-cidr configuration
- Connectivity test race condition where CNI policies weren't fully applied before testing
- Test output verbosity - connectivity test now only checks for HTTP 200 status instead of printing full response

### Security

- Added encrypted credential storage using SOPS with AGE encryption
- Automatic cleanup of decrypted credential files
- Enhanced .gitignore patterns for sensitive data protection
- Implemented secure defaults for network policies
- Enhanced security configurations for production readiness

## Contributors

- [@mkm29](https://github.com/mkm29) - Project maintainer and primary contributor

## Links

- [Project Repository](https://github.com/mkm29/k3d-cilium)
- [Issue Tracker](https://github.com/mkm29/k3d-cilium/issues)
- [Documentation](https://github.com/mkm29/k3d-cilium/blob/main/README.md)