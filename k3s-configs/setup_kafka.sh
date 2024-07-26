#!/bin/bash

# Check if helm and kubectl are installed
if ! command -v helm &> /dev/null || ! command -v kubectl &> /dev/null; then
    echo "Error: helm and kubectl are required. Please install them first."
    exit 1
fi

# Add Bitnami repo (for Kafka chart)
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Install Kafka
echo "Installing Kafka..."
helm install kafka bitnami/kafka -f k3s-configs/kafka/kafka-values.yaml --namespace kafka --create-namespace

# Wait for Kafka to be ready
echo "Waiting for Kafka to be ready..."
kubectl wait --namespace kafka \
             --for=condition=ready pod \
             --selector=app.kubernetes.io/name=kafka \
             --timeout=300s

# Install Kafdrop
echo "Installing Kafdrop..."
kubectl apply -f k3s-configs/kafka/kafdrop-deployment.yaml
kubectl apply -f k3s-configs/kafka/kafdrop-service.yaml

echo "Kafka and Kafdrop setup complete!"
echo "Kafdrop will be accessible via LoadBalancer. Run 'kubectl get svc -n kafka' to find the external IP."