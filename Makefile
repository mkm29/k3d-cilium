# Setup some variables
CLUSTER_NAME ?= cilium
CALICO_CLUSTER_NAME ?= calico
K3D_CONFIG ?= k3d-cilium-config.yaml


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
	@if ! command -v calicoctl > /dev/null 2>&1; then \
		echo "Warning: calicoctl is not installed. You may need it for advanced Calico operations."; \
	fi
	@echo "All preflight checks passed."

.PHONY: create-cluster
create-cluster: preflight ## Create a k3d cluster (use K3D_CONFIG to specify config file)
	@echo "Creating k3d cluster with config: $(K3D_CONFIG)..."
	@k3d cluster create $(CLUSTER_NAME) --config $(K3D_CONFIG)
	@echo "Cluster $(CLUSTER_NAME) created successfully."

.PHONY: create-calico-cluster
create-calico-cluster: preflight ## Create a k3d cluster with Calico
	@echo "Creating k3d cluster with Calico..."
	@k3d cluster create $(CALICO_CLUSTER_NAME) --config calico-k3d-config.yaml
	@echo "Cluster $(CALICO_CLUSTER_NAME) created successfully."

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
	@kubectl apply -f https://raw.githubusercontent.com/prometheus-community/helm-charts/refs/heads/main/charts/kube-prometheus-stack/charts/crds/crds/crd-alertmanagerconfigs.yaml
	@kubectl apply -f https://raw.githubusercontent.com/prometheus-community/helm-charts/refs/heads/main/charts/kube-prometheus-stack/charts/crds/crds/crd-alertmanagers.yaml
	@kubectl apply -f https://raw.githubusercontent.com/prometheus-community/helm-charts/refs/heads/main/charts/kube-prometheus-stack/charts/crds/crds/crd-podmonitors.yaml
	@kubectl apply -f https://raw.githubusercontent.com/prometheus-community/helm-charts/refs/heads/main/charts/kube-prometheus-stack/charts/crds/crds/crd-probes.yaml
	@kubectl apply -f https://raw.githubusercontent.com/prometheus-community/helm-charts/refs/heads/main/charts/kube-prometheus-stack/charts/crds/crds/crd-prometheusagents.yaml
	@kubectl apply -f https://raw.githubusercontent.com/prometheus-community/helm-charts/refs/heads/main/charts/kube-prometheus-stack/charts/crds/crds/crd-prometheuses.yaml
	@kubectl apply -f https://raw.githubusercontent.com/prometheus-community/helm-charts/refs/heads/main/charts/kube-prometheus-stack/charts/crds/crds/crd-prometheusrules.yaml
	@kubectl apply -f https://raw.githubusercontent.com/prometheus-community/helm-charts/refs/heads/main/charts/kube-prometheus-stack/charts/crds/crds/crd-scrapeconfigs.yaml
	@kubectl apply -f https://raw.githubusercontent.com/prometheus-community/helm-charts/refs/heads/main/charts/kube-prometheus-stack/charts/crds/crds/crd-servicemonitors.yaml
	@kubectl apply -f https://raw.githubusercontent.com/prometheus-community/helm-charts/refs/heads/main/charts/kube-prometheus-stack/charts/crds/crds/crd-thanosrulers.yaml
	@echo "Prometheus CRDs installed successfully."

.PHONY: install-gateway-api
install-gateway-api: ## Install Gateway API CRDs
	@echo "Installing Gateway API CRDs..."
	@kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/experimental-install.yaml
	@echo "Gateway API CRDs installed successfully."

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

.PHONY: install-calico
install-calico: ## Install Calico on the k3d cluster
	@echo "Installing Calico on the k3d cluster..."
	@echo "Waiting for cluster to be ready..."
	@kubectl wait --for=condition=Ready nodes --all --timeout=300s
	@echo "Installing Tigera Calico operator..."
	@kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.3/manifests/tigera-operator.yaml
	@echo "Waiting for Tigera operator to be ready..."
	@kubectl rollout status -n tigera-operator deployment/tigera-operator
	@echo "Downloading and customizing Calico configuration..."
	@curl -s https://raw.githubusercontent.com/projectcalico/calico/v3.30.3/manifests/custom-resources.yaml | \
		sed 's/cidr: 192\.168\.0\.0\/16/cidr: 192.168.0.0\/16/' | \
		kubectl create -f -
	@echo "Waiting for Calico to be ready..."
	@kubectl wait --for=condition=Ready pods -n calico-system --all --timeout=300s
	@echo "Calico installed successfully."

.PHONY: uninstall-calico
uninstall-calico: ## Uninstall Calico from the k3d cluster
	@echo "Uninstalling Calico from the k3d cluster..."
	@kubectl delete -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.3/manifests/custom-resources.yaml --ignore-not-found=true
	@kubectl delete -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.3/manifests/tigera-operator.yaml --ignore-not-found=true
	@echo "Calico uninstalled successfully."

.PHONY: delete-cluster
delete-cluster: ## Delete the k3d cluster
	@echo "Deleting k3d cluster $(CLUSTER_NAME)..."
	@k3d cluster delete $(CLUSTER_NAME)
	@echo "Cluster $(CLUSTER_NAME) deleted successfully."

.PHONY: delete-calico-cluster
delete-calico-cluster: ## Delete the Calico k3d cluster
	@echo "Deleting k3d cluster $(CALICO_CLUSTER_NAME)..."
	@k3d cluster delete $(CALICO_CLUSTER_NAME)
	@echo "Cluster $(CALICO_CLUSTER_NAME) deleted successfully."