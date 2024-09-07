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
helm install kafka bitnami/kafka -f k3s-configs/kafka/kafka-values.yaml

# Wait for Kafka to be ready
echo "Waiting for Kafka to be ready..."
kubectl wait \
             --for=condition=ready pod \
             --selector=app.kubernetes.io/name=kafka \
             --timeout=300s

# Get Kafka password
KAFKA_PASSWORD=$(kubectl get secret kafka-user-passwords -o jsonpath='{.data.client-passwords}' | base64 -d | cut -d , -f 1)

# Install Redpanda Console
echo "Installing Redpanda Console..."
export KAFKA_PASSWORD
envsubst < k3s-configs/kafka/redpanda-console.yaml | kubectl apply -f -

unset KAFKA_PASSWORD

echo "Kafka and Redpanda Console setup complete!"
echo "Redpanda Console will be accessible via LoadBalancer. Run 'kubectl get svc' to find the external IP."