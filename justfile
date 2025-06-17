set shell := ["zsh", "-cu"]
set export := true
set ignore-comments := true
set quiet := true
set dotenv-load := true

# Variables with defaults
cluster_name := env_var_or_default("CLUSTER_NAME", "calico")
k3d_config := env_var_or_default("K3D_CONFIG", "infrastructure/k3d/calico-config.yaml")

# Default recipe - show help
default:
    @just --list

# Run preflight checks
preflight:
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

# Create a k3d cluster (use K3D_CONFIG env var to specify config file)
create-cluster: preflight
    @echo "Creating k3d cluster with config: {{k3d_config}}..."
    @k3d cluster create {{cluster_name}} --config {{k3d_config}}
    @echo "Cluster {{cluster_name}} created successfully."

# Patch nodes to mount BPF filesystem
patch-nodes:
    @echo "Patching nodes to mount BPF filesystem..."
    @if ! k3d cluster list | grep -q {{cluster_name}}; then \
        echo "Cluster {{cluster_name}} does not exist. Please create the cluster first."; \
        exit 1; \
    fi
    @for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do \
        echo "Configuring mounts for $node"; \
        docker exec -i $node /bin/sh -c ' \
            mount bpffs -t bpf /sys/fs/bpf && \
            mount --make-shared /sys/fs/bpf && \
            mkdir -p /run/cilium/cgroupv2 && \
            mount -t cgroup2 none /run/cilium/cgroupv2 && \
            mount --make-shared /run/cilium/cgroupv2/ \
        '; \
    done
    @echo "Nodes patched successfully."

# Install Prometheus CRDs
install-prometheus-crds:
    @echo "Installing Prometheus CRDs..."
    @kubectl apply -f https://raw.githubusercontent.com/prometheus-community/helm-charts/refs/heads/main/charts/kube-prometheus-stack/charts/crds/crds/crd-alertmanagerconfigs.yaml --server-side
    @kubectl apply -f https://raw.githubusercontent.com/prometheus-community/helm-charts/refs/heads/main/charts/kube-prometheus-stack/charts/crds/crds/crd-alertmanagers.yaml --server-side
    @kubectl apply -f https://raw.githubusercontent.com/prometheus-community/helm-charts/refs/heads/main/charts/kube-prometheus-stack/charts/crds/crds/crd-podmonitors.yaml --server-side
    @kubectl apply -f https://raw.githubusercontent.com/prometheus-community/helm-charts/refs/heads/main/charts/kube-prometheus-stack/charts/crds/crds/crd-probes.yaml --server-side
    @kubectl apply -f https://raw.githubusercontent.com/prometheus-community/helm-charts/refs/heads/main/charts/kube-prometheus-stack/charts/crds/crds/crd-prometheusagents.yaml --server-side
    @kubectl apply -f https://raw.githubusercontent.com/prometheus-community/helm-charts/refs/heads/main/charts/kube-prometheus-stack/charts/crds/crds/crd-prometheuses.yaml --server-side
    @kubectl apply -f https://raw.githubusercontent.com/prometheus-community/helm-charts/refs/heads/main/charts/kube-prometheus-stack/charts/crds/crds/crd-prometheusrules.yaml --server-side
    @kubectl apply -f https://raw.githubusercontent.com/prometheus-community/helm-charts/refs/heads/main/charts/kube-prometheus-stack/charts/crds/crds/crd-scrapeconfigs.yaml --server-side
    @kubectl apply -f https://raw.githubusercontent.com/prometheus-community/helm-charts/refs/heads/main/charts/kube-prometheus-stack/charts/crds/crds/crd-servicemonitors.yaml --server-side
    @kubectl apply -f https://raw.githubusercontent.com/prometheus-community/helm-charts/refs/heads/main/charts/kube-prometheus-stack/charts/crds/crds/crd-thanosrulers.yaml --server-side
    @echo "Prometheus CRDs installed successfully."

# Install Gateway API CRDs
install-gateway-api:
    @echo "Installing Gateway API CRDs..."
    @kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/experimental-install.yaml --server-side
    @echo "Gateway API CRDs installed successfully."

# Install Cilium on the k3d cluster
install-cilium:
    @echo "Installing Cilium on the k3d cluster..."
    @cilium install -f infrastructure/cilium/values.yaml --wait
    @echo "Cilium installed successfully."

# Uninstall Cilium from the k3d cluster
uninstall-cilium:
    @echo "Uninstalling Cilium from the k3d cluster..."
    @cilium uninstall --wait
    @echo "Cilium uninstalled successfully."

# Install Calico on the k3d cluster
install-calico:
    @echo "Installing Calico on the k3d cluster..."
    @echo "Installing Calico operator..."
    @kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.0/manifests/tigera-operator.yaml
    @echo "Installing Calico custom resources..."
    @kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.0/manifests/custom-resources.yaml
    @echo "Wait for Tigera operator to be ready..."
    @echo "Waiting for Calico components to be ready..."
    @sleep 10
    @kubectl wait --for=condition=Available tigerastatus --all --timeout=300s
    @echo "Enable IP forwarding..."
    @kubectl patch installation default --type=merge --patch='{"spec":{"calicoNetwork":{"containerIPForwarding":"Enabled"}}}'
    @echo "Calico installed successfully."

# Uninstall Calico from the k3d cluster
uninstall-calico:
    @echo "Uninstalling Calico from the k3d cluster..."
    @kubectl delete -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.0/manifests/custom-resources.yaml --ignore-not-found=true
    @kubectl delete -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.0/manifests/tigera-operator.yaml --ignore-not-found=true
    @echo "Calico uninstalled successfully."

# Enable eBPF dataplane for Calico
enable-calico-ebpf:
    @echo "Enabling eBPF dataplane for Calico..."
    @echo "Checking kernel version..."
    @kubectl run kernel-check --image=busybox --rm -it --restart=Never -- sh -c 'uname -rv' || true
    @echo "Creating Kubernetes API server ConfigMap for eBPF..."
    @kubectl create configmap kubernetes-services-endpoint \
        --namespace tigera-operator \
        --from-literal=KUBERNETES_SERVICE_HOST=$(kubectl get endpoints kubernetes -o jsonpath='{.subsets[0].addresses[0].ip}') \
        --from-literal=KUBERNETES_SERVICE_PORT=$(kubectl get endpoints kubernetes -o jsonpath='{.subsets[0].ports[0].port}') \
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

# Disable eBPF dataplane for Calico (revert to iptables)
disable-calico-ebpf:
    @echo "Disabling eBPF dataplane for Calico..."
    @kubectl patch installation.operator.tigera.io default --type merge -p '{"spec":{"calicoNetwork":{"linuxDataplane":"Iptables"}}}'
    @echo "Waiting for Calico to restart with iptables dataplane..."
    @sleep 30
    @kubectl wait --for=condition=Available tigerastatus --all --timeout=300s
    @echo "eBPF dataplane disabled successfully."

# Delete the k3d cluster
delete-cluster:
    @echo "Deleting k3d cluster {{cluster_name}}..."
    @k3d cluster delete {{cluster_name}}
    @echo "Cluster {{cluster_name}} deleted successfully."

# Delete the Calico k3d cluster (alias for delete-cluster)
delete-calico-cluster: delete-cluster

# Quick start recipes for common workflows

# Create and setup a Cilium cluster
setup-cilium: create-cluster patch-nodes install-prometheus-crds install-gateway-api install-cilium
    @echo "Cilium cluster setup complete!"
    @echo "Run 'cilium status --wait' to verify installation."

# Create and setup a Calico cluster
setup-calico: create-cluster install-calico
    @echo "Calico cluster setup complete!"
    @echo "Run 'kubectl get pods -n kube-system | grep calico' to verify installation."

# Create and setup a Calico cluster with eBPF
setup-calico-ebpf: create-cluster install-calico enable-calico-ebpf
    @echo "Calico cluster with eBPF setup complete!"

# Show cluster status
status:
    @echo "=== k3d clusters ==="
    @k3d cluster list
    @echo ""
    @if k3d cluster list | grep -q {{cluster_name}}; then \
        echo "=== Nodes in {{cluster_name}} cluster ==="; \
        kubectl get nodes; \
        echo ""; \
        echo "=== System pods ==="; \
        kubectl get pods -n kube-system; \
    else \
        echo "Cluster {{cluster_name}} not found."; \
    fi

# Test connectivity (works for both Cilium and Calico)
test-connectivity:
    @if command -v cilium > /dev/null 2>&1 && kubectl get ns | grep -q cilium; then \
        echo "Running Cilium connectivity test..."; \
        cilium connectivity test; \
    else \
        echo "Running basic connectivity test..."; \
        kubectl create deployment nginx --image=nginx --replicas=2 || true; \
        kubectl wait --for=condition=available --timeout=60s deployment/nginx; \
        kubectl expose deployment nginx --port=80 --type=ClusterIP || true; \
        kubectl run test-pod --image=busybox --rm -it --restart=Never -- wget -O- http://nginx; \
    fi