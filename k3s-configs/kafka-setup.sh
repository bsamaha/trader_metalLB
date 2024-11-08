# Install Strimzi operator
kubectl create namespace kafka
kubectl apply -f https://strimzi.io/install/latest?namespace=kafka -n kafka

# Wait for the operator to be ready
kubectl wait deployment/strimzi-cluster-operator \
    --namespace kafka \
    --for=condition=Available=True \
    --timeout=300s

# Deploy Kafka cluster
kubectl apply -f ./k3s-configs/kafka/kafka-setup.yaml

# Function to create Kafka topic
create_kafka_topic() {
    local topic_name=$1
    local pod_name="kafka-topics-${topic_name//[.]/-}"  # Replace dots with dashes for pod name
    echo "Creating topic: $topic_name"
    kubectl -n kafka run "$pod_name" -it --rm \
        --image=quay.io/strimzi/kafka:latest-kafka-3.5.1 \
        --command -- bin/kafka-topics.sh \
        --bootstrap-server trading-cluster-kafka-bootstrap:9092 \
        --create --topic "$topic_name" --partitions 3 --replication-factor 3
}

# Create all required topics
TOPICS=(
    "market.btc.raw"
    "market.btc.candles"
    "trading.signals"
    "trading.orders"
    "trading.positions"
)

for topic in "${TOPICS[@]}"; do
    create_kafka_topic "$topic"
done

echo "All Kafka topics created successfully"