# Setup some variables
CLUSTER_NAME ?= cilium
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
	@k3d cluster create $(CLUSTER_NAME) --config k3d-calico-config.yaml
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
	@echo "Installing Calico operator..."
	@kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.0/manifests/tigera-operator.yaml
	@echo "Installing Calico custom resources..."
	@kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.0/manifests/custom-resources.yaml
	@echo "Wait for Tigera operator to be ready..."
	@echo "Waiting for Calico components to be ready..."
	@sleep 10
	@kubectl wait --for=condition=Available tigerastatus --all --timeout=300s
	@echo "Enable IP forwarding..."
	@kubectl patch installation default --type=merge --patch='{"spec":{"calicoNetwork":{"containerIPForwarding":"Enabled"}}}'
	@echo "Calico installed successfully."

.PHONY: uninstall-calico
uninstall-calico: ## Uninstall Calico from the k3d cluster
	@echo "Uninstalling Calico from the k3d cluster..."
	@kubectl delete -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.3/manifests/custom-resources.yaml --ignore-not-found=true
	@kubectl delete -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.3/manifests/tigera-operator.yaml --ignore-not-found=true
	@echo "Calico uninstalled successfully."

.PHONY: enable-calico-ebpf
enable-calico-ebpf: ## Enable eBPF dataplane for Calico
	@echo "Enabling eBPF dataplane for Calico..."
	@echo "Checking kernel version..."
	@kubectl run kernel-check --image=busybox --rm -it --restart=Never -- sh -c 'uname -rv' || true
	@echo "Creating Kubernetes API server ConfigMap for eBPF..."
	@kubectl create configmap kubernetes-services-endpoint \
		--namespace tigera-operator \
		--from-literal=KUBERNETES_SERVICE_HOST=$$(kubectl get endpoints kubernetes -o jsonpath='{.subsets[0].addresses[0].ip}') \
		--from-literal=KUBERNETES_SERVICE_PORT=$$(kubectl get endpoints kubernetes -o jsonpath='{.subsets[0].ports[0].port}') \
		--dry-run=client -o yaml | kubectl apply -f -
	@echo "Disabling kube-proxy (k3s doesn't use kube-proxy, skipping)..."
	@echo "Enabling eBPF mode in Calico..."
	@kubectl patch installation.operator.tigera.io default --type merge -p '{"spec":{"calicoNetwork":{"linuxDataplane":"BPF", "hostPorts":null}}}'
	@echo "Waiting for Calico to restart with eBPF..."
	@sleep 30
	@kubectl wait --for=condition=Available tigerastatus --all --timeout=300s
	@echo "Verifying eBPF is enabled..."
	@kubectl get installation default -o jsonpath='{.spec.calicoNetwork.linuxDataplane}'
	@echo ""
	@echo "eBPF dataplane enabled successfully."
	@echo "Note: DSR mode can be enabled with: kubectl patch felixconfiguration default --type='merge' -p '{\"spec\":{\"bpfExternalServiceMode\":\"DSR\"}}'"

.PHONY: disable-calico-ebpf
disable-calico-ebpf: ## Disable eBPF dataplane for Calico (revert to iptables)
	@echo "Disabling eBPF dataplane for Calico..."
	@kubectl patch installation.operator.tigera.io default --type merge -p '{"spec":{"calicoNetwork":{"linuxDataplane":"Iptables"}}}'
	@echo "Waiting for Calico to restart with iptables dataplane..."
	@sleep 30
	@kubectl wait --for=condition=Available tigerastatus --all --timeout=300s
	@echo "eBPF dataplane disabled successfully."

.PHONY: delete-cluster
delete-cluster: ## Delete the k3d cluster
	@echo "Deleting k3d cluster $(CLUSTER_NAME)..."
	@k3d cluster delete $(CLUSTER_NAME)
	@echo "Cluster $(CLUSTER_NAME) deleted successfully."

.PHONY: delete-calico-cluster
delete-calico-cluster: ## Delete the Calico k3d cluster
	@echo "Deleting k3d cluster $(CLUSTER_NAME)..."
	@k3d cluster delete $(CLUSTER_NAME)
	@echo "Cluster $(CLUSTER_NAME) deleted successfully."