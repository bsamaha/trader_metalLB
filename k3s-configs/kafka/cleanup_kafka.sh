#!/bin/bash

# Uninstall Kafka Helm release
echo "Uninstalling Kafka..."
helm uninstall kafka

# Delete Redpanda Console resources
echo "Deleting Redpanda Console resources..."
kubectl delete -f k3s-configs/kafka/redpanda-console.yaml

# Delete Kafka test producer
echo "Deleting Kafka test producer..."
kubectl delete -f k3s-configs/kafka/kafka-test-producer.yaml

# Delete Kafka-related PVCs
echo "Deleting Kafka-related PVCs..."
kubectl delete pvc -l app.kubernetes.io/name=kafka

# Delete Kafka-related secrets
echo "Deleting Kafka-related secrets..."
kubectl delete secret kafka-user-passwords

# Delete any remaining Kafka-related resources
echo "Deleting any remaining Kafka-related resources..."
kubectl delete all,configmap,pvc,serviceaccount,rolebinding,clusterrolebinding -l app.kubernetes.io/name=kafka

echo "Kafka cleanup completed."