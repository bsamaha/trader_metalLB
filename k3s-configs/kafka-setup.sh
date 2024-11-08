# Install Strimzi operator
kubectl create namespace kafka
kubectl apply -f https://strimzi.io/install/latest?namespace=kafka -n kafka

# Wait for the operator to be ready
kubectl wait deployment/strimzi-cluster-operator --for=condition=ready --timeout=300s -n kafka

# Deploy Kafka cluster
kubectl apply -f kafka/kafka-setup.yaml