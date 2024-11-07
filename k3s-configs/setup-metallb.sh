#!/bin/bash

echo "Applying MetalLB manifests..."
sudo kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.7/config/manifests/metallb-native.yaml

echo "Waiting for MetalLB pods to be ready..."
sudo kubectl wait --namespace metallb-system \
                  --for=condition=ready pod \
                  --selector=app=metallb \
                  --timeout=90s

echo "Waiting for MetalLB CRDs to be established..."
sudo kubectl wait --for condition=established --timeout=60s crd/ipaddresspools.metallb.io
sudo kubectl wait --for condition=established --timeout=60s crd/l2advertisements.metallb.io

echo "Applying MetalLB configuration..."
sudo kubectl apply -f k3s-configs/metallb/metallb-config.yaml

# Prometheus and Grafana setup
echo "Setting up Prometheus and Grafana..."

# Install Helm if not already installed
if ! command -v helm &> /dev/null; then
    echo "Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
fi

# Add Prometheus and Grafana Helm repos
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Ensure the monitoring namespace is created
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Install Prometheus
echo "Installing Prometheus..."
helm install prometheus prometheus-community/prometheus \
    --namespace monitoring \
    --create-namespace \
    --set server.persistentVolume.enabled=false

# Install Grafana with LoadBalancer service and Prometheus data source
echo "Installing Grafana..."
helm install grafana grafana/grafana \
    --namespace monitoring \
    --set service.type=LoadBalancer \
    --set service.loadBalancerIP=192.168.1.250 \
    --set datasources."datasources\.yaml".apiVersion=1 \
    --set datasources."datasources\.yaml".datasources[0].name=Prometheus \
    --set datasources."datasources\.yaml".datasources[0].type=prometheus \
    --set datasources."datasources\.yaml".datasources[0].url=http://prometheus-server.monitoring.svc.cluster.local \
    --set datasources."datasources\.yaml".datasources[0].access=proxy \
    --set datasources."datasources\.yaml".datasources[0].isDefault=true

# Wait for Grafana to be ready
echo "Waiting for Grafana to be ready..."
kubectl wait --namespace monitoring \
             --for=condition=ready pod \
             --selector=app.kubernetes.io/name=grafana \
             --timeout=90s

# Retrieve Grafana admin password
echo "Retrieving Grafana admin password..."
kubectl get secret --namespace monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

# Get Grafana LoadBalancer IP
GRAFANA_IP=$(kubectl get svc -n monitoring grafana -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Grafana is accessible at http://$GRAFANA_IP"

echo "Setup complete! Please log out and log back in, or run 'source ~/.bashrc' to apply changes to your current session."