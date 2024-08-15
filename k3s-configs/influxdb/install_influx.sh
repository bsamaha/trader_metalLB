#!/bin/bash

# Configurable parameters
NAMESPACE="influxdb"
RELEASE_NAME="influxdb"
STORAGE_SIZE="20Gi"
MEMORY_REQUEST="1Gi"
MEMORY_LIMIT="2Gi"
CPU_REQUEST="500m"
CPU_LIMIT="1"
ADMIN_PASSWORD=$(openssl rand -base64 20)

# Create namespace
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Create secret for admin password
kubectl create secret generic influxdb-admin-secret \
  --from-literal=admin-password=$ADMIN_PASSWORD \
  --namespace $NAMESPACE \
  --dry-run=client -o yaml | kubectl apply -f -

# Add InfluxData Helm repo
echo "Adding InfluxData Helm repo..."
helm repo add influxdata https://helm.influxdata.com/
helm repo update

# Install InfluxDB
echo "Installing InfluxDB..."
helm install $RELEASE_NAME influxdata/influxdb \
  --namespace $NAMESPACE \
  --set persistence.enabled=true \
  --set persistence.size=$STORAGE_SIZE \
  --set resources.requests.memory=$MEMORY_REQUEST \
  --set resources.requests.cpu=$CPU_REQUEST \
  --set resources.limits.memory=$MEMORY_LIMIT \
  --set resources.limits.cpu=$CPU_LIMIT \
  --set adminUser.existingSecret=influxdb-admin-secret \
  --set adminUser.passwordKey=admin-password \
  --set service.type=ClusterIP \
  --set livenessProbe.enabled=true \
  --set persistence.storageClass=longhorn \
  --set persistence.size=$STORAGE_SIZE \

# Wait for InfluxDB to be ready
echo "Waiting for InfluxDB to be ready..."
kubectl wait --namespace $NAMESPACE \
             --for=condition=ready pod \
             --selector=app.kubernetes.io/name=influxdb \
             --timeout=300s

# Create LoadBalancer Service for InfluxDB
echo "Creating LoadBalancer Service for InfluxDB..."
sed "s/\$NAMESPACE/$NAMESPACE/g" k3s-configs/influxdb/influx-service.yaml | kubectl apply -f -

# Get InfluxDB service details
INFLUXDB_SERVICE=$(kubectl get svc -n $NAMESPACE influxdb-lb -o jsonpath='{.metadata.name}' 2>/dev/null)
INFLUXDB_IP=$(kubectl get svc -n $NAMESPACE influxdb-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
INFLUXDB_PORT=$(kubectl get svc -n $NAMESPACE influxdb-lb -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)

if [ -z "$INFLUXDB_IP" ]; then
  echo "Warning: LoadBalancer IP not yet assigned. Please check the service status."
  echo "You can use 'kubectl get svc -n $NAMESPACE' to check the status."
else
  echo "InfluxDB is installed and accessible at http://$INFLUXDB_IP:$INFLUXDB_PORT"
fi

echo "Admin username: admin"
echo "Admin password: $ADMIN_PASSWORD"
echo "Please save this password securely. It will not be shown again."