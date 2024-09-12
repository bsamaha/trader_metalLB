#!/bin/bash

# Configurable parameters
RELEASE_NAME="influxdb"
STORAGE_SIZE="20Gi"
MEMORY_REQUEST="1Gi"
MEMORY_LIMIT="2Gi"
CPU_REQUEST="500m"
CPU_LIMIT="1"
ADMIN_USERNAME="admin"
ADMIN_PASSWORD=$(openssl rand -base64 20)
ADMIN_TOKEN=$(openssl rand -hex 32)

# Create secret for InfluxDB credentials
kubectl create secret generic influxdb-auth \
  --from-literal=admin-username=$ADMIN_USERNAME \
  --from-literal=admin-password=$ADMIN_PASSWORD \
  --from-literal=admin-token=$ADMIN_TOKEN \
  --dry-run=client -o yaml | kubectl apply -f -

# Add InfluxData Helm repo
echo "Adding InfluxData Helm repo..."
helm repo add influxdata https://helm.influxdata.com/
helm repo update

# Install InfluxDB v2
echo "Installing InfluxDB v2..."
helm upgrade --install $RELEASE_NAME influxdata/influxdb2 \
  --set persistence.enabled=true \
  --set persistence.size=$STORAGE_SIZE \
  --set persistence.storageClass=longhorn \
  --set resources.requests.memory=$MEMORY_REQUEST \
  --set resources.requests.cpu=$CPU_REQUEST \
  --set resources.limits.memory=$MEMORY_LIMIT \
  --set resources.limits.cpu=$CPU_LIMIT \
  --set adminUser.existingSecret=influxdb-auth \
  --set adminUser.organization="my-org" \
  --set adminUser.bucket="my-bucket" \
  --set service.type=LoadBalancer \
  --set livenessProbe.enabled=true

# Wait for InfluxDB to be ready
echo "Waiting for InfluxDB to be ready..."
kubectl wait --for=condition=ready pod \
             --selector=app.kubernetes.io/name=influxdb2 \
             --timeout=300s

# Get InfluxDB service details
INFLUXDB_IP=$(kubectl get svc $RELEASE_NAME-influxdb2 -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
INFLUXDB_PORT=$(kubectl get svc $RELEASE_NAME-influxdb2 -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)

if [ -z "$INFLUXDB_IP" ]; then
  echo "Warning: InfluxDB LoadBalancer IP not yet assigned. Please check the service status."
else
  echo "InfluxDB is accessible at http://$INFLUXDB_IP:$INFLUXDB_PORT"
fi

echo "Admin username: $ADMIN_USERNAME"
echo "Admin password: $ADMIN_PASSWORD"
echo "Admin token: $ADMIN_TOKEN"
echo "Please save these credentials securely. They will not be shown again."