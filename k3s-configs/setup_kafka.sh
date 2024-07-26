#!/bin/bash

# Check if helm and kubectl are installed
if ! command -v helm &> /dev/null || ! command -v kubectl &> /dev/null; then
    echo "Error: helm and kubectl are required. Please install them first."
    exit 1
fi

# Add Bitnami repo (for Kafka chart)
helm repo add bitnami https://charts.bitnami.com/bitnami
# Add Kafdrop repo
helm repo add kafdrop https://obsidiandynamics.github.io/kafdrop
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

# Get Kafka password
KAFKA_PASSWORD=$(kubectl get secret kafka-user-passwords --namespace kafka -o jsonpath='{.data.client-passwords}' | base64 -d | cut -d , -f 1)

# Install Kafdrop using Helm
echo "Installing Kafdrop..."
helm upgrade -i kafdrop kafdrop/kafdrop \
    --namespace kafka \
    --set kafka.brokerConnect="kafka-broker-0.kafka-broker-headless.kafka.svc.cluster.local:9092,kafka-broker-1.kafka-broker-headless.kafka.svc.cluster.local:9092,kafka-broker-2.kafka-broker-headless.kafka.svc.cluster.local:9092" \
    --set kafka.properties="security.protocol=SASL_PLAINTEXT\nsasl.mechanism=PLAIN\nsasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username=\"user1\" password=\"$KAFKA_PASSWORD\";" \
    --set server.servlet.contextPath="/" \
    --set cmdArgs="--message.format=DEFAULT --topic.deleteEnabled=false --topic.createEnabled=false" \
    --set jvm.opts="-Xms32M -Xmx64M" \
    --set service.type=LoadBalancer \
    --set service.port=80 \
    --set resources.requests.cpu=100m \
    --set resources.requests.memory=128Mi \
    --set resources.limits.cpu=500m \
    --set resources.limits.memory=512Mi

echo "Kafka and Kafdrop setup complete!"
echo "Kafdrop will be accessible via LoadBalancer. Run 'kubectl get svc -n kafka' to find the external IP."