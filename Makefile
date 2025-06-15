# Setup some variables
CLUSTER_NAME ?= cilium


# HELP
# This will output the help for each task
.PHONY: help build test install-go-test-coverage check-coverage

# Tasks
help: ## This help.
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.DEFAULT_GOAL := help

.PHONY: preflight
preflight: ## Run preflight checks
	@echo "Running preflight checks..."
	@if ! docker info > /dev/null 2>&1; then \
		echo "Docker is not running. Please start Docker and try again."; \
		exit 1; \
	fi
	@if ! command -v k3d > /dev/null 2>&1; then \
		echo "k3d is not installed. Please install k3d and try again."; \
		exit 1; \
	fi
	@if ! command -v helm > /dev/null 2>&1; then \
		echo "Helm is not installed. Please install Helm and try again."; \
		exit 1; \
	fi
	@if ! command -v kubectl > /dev/null 2>&1; then \
		echo "kubectl is not installed. Please install kubectl and try again."; \
		exit 1; \
	fi
	@if ! command -v cilium > /dev/null 2>&1; then \
		echo "Cilium CLI is not installed. Please install Cilium CLI and try again."; \
		exit 1; \
	fi
	@echo "All preflight checks passed."

.PHONY: create-cluster
create-cluster: preflight ## Create a k3d cluster with Cilium
	@echo "Creating k3d cluster with Cilium..."
	@k3d cluster create $(CLUSTER_NAME) --config cilium-k3d-config.yaml
	@echo "Cluster $(CLUSTER_NAME) created successfully."

.PHONY: patch-nodes
patch-nodes: ## Patch nodes to mount BPF filesystem
	@echo "Patching nodes to mount BPF filesystem..."
	@if ! k3d cluster list | grep -q $(CLUSTER_NAME); then \
		echo "Cluster $(CLUSTER_NAME) does not exist. Please create the cluster first."; \
		exit 1; \
	fi
	@for node in $$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do \
		echo "Configuring mounts for $$node"; \
		docker exec -i $$node /bin/sh -c ' \
			mount bpffs -t bpf /sys/fs/bpf && \
			mount --make-shared /sys/fs/bpf && \
			mkdir -p /run/cilium/cgroupv2 && \
			mount -t cgroup2 none /run/cilium/cgroupv2 && \
			mount --make-shared /run/cilium/cgroupv2/ \
		'; \
	done
	@echo "Nodes patched successfully."

.PHONY: install-prometheus-crds
install-prometheus-crds: ## Install Prometheus CRDs
	@echo "Installing Prometheus CRDs..."
	@kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/bundle.yaml || echo "Failed to apply Prometheus CRDs. Please check the URL or your network connection."
	@echo "Prometheus CRDs installed successfully."

.PHONY: install-cilium
install-cilium: ## Install Cilium on the k3d cluster
	@echo "Installing Cilium on the k3d cluster..."
	@cilium install -f cilium-values.yaml --wait
	@echo "Cilium installed successfully."

.PHONY: uninstall-cilium
uninstall-cilium: ## Uninstall Cilium from the k3d cluster
	@echo "Uninstalling Cilium from the k3d cluster..."
	@cilium uninstall --wait
	@echo "Cilium uninstalled successfully."

.PHONY: delete-cluster
delete-cluster: ## Delete the k3d cluster
	@echo "Deleting k3d cluster $(CLUSTER_NAME)..."
	@k3d cluster delete $(CLUSTER_NAME)
	@echo "Cluster $(CLUSTER_NAME) deleted successfully."