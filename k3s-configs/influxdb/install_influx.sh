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
READ_USER="readuser"
READ_PASSWORD=$(openssl rand -base64 20)
WRITE_USER="writeuser"
WRITE_PASSWORD=$(openssl rand -base64 20)

# Create secret for InfluxDB credentials
kubectl create secret generic influxdb-auth \
  --from-literal=admin-username=$ADMIN_USERNAME \
  --from-literal=admin-password=$ADMIN_PASSWORD \
  --from-literal=read-username=$READ_USER \
  --from-literal=read-password=$READ_PASSWORD \
  --from-literal=write-username=$WRITE_USER \
  --from-literal=write-password=$WRITE_PASSWORD \
  --dry-run=client -o yaml | kubectl apply -f -

# Add InfluxData Helm repo
echo "Adding InfluxData Helm repo..."
helm repo add influxdata https://helm.influxdata.com/
helm repo update

helm install $RELEASE_NAME influxdata/influxdb \
  --set persistence.enabled=true \
  --set persistence.size=$STORAGE_SIZE \
  --set resources.requests.memory=$MEMORY_REQUEST \
  --set resources.requests.cpu=$CPU_REQUEST \
  --set resources.limits.memory=$MEMORY_LIMIT \
  --set resources.limits.cpu=$CPU_LIMIT \
  --set auth.enabled=true \
  --set auth.existingSecret=influxdb-auth \
  --set auth.admin.username=admin-username \
  --set auth.admin.password=admin-password \
  --set auth.user.username=read-username \
  --set auth.user.password=read-password \
  --set service.type=ClusterIP \
  --set livenessProbe.enabled=true \
  --set persistence.storageClass=longhorn \
  --set persistence.size=$STORAGE_SIZE

# Wait for InfluxDB to be ready
echo "Waiting for InfluxDB to be ready..."
kubectl wait --for=condition=ready pod \
             --selector=app.kubernetes.io/name=influxdb \
             --timeout=300s

# Deploy InfluxDB and Chronograf
echo "Deploying InfluxDB and Chronograf..."
kubectl apply -f k3s-configs/influxdb/influx-deployment.yaml

# Wait for InfluxDB and Chronograf to be ready
echo "Waiting for InfluxDB and Chronograf to be ready..."
kubectl wait --for=condition=ready pod \
             --selector=app.kubernetes.io/name=influxdb \
             --timeout=300s
kubectl wait --for=condition=ready pod \
             --selector=app=chronograf \
             --timeout=300s

# Get InfluxDB and Chronograf service details
INFLUXDB_IP=$(kubectl get svc influxdb-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
INFLUXDB_PORT=$(kubectl get svc influxdb-lb -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)
CHRONOGRAF_IP=$(kubectl get svc chronograf -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
CHRONOGRAF_PORT=$(kubectl get svc chronograf -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)

if [ -z "$INFLUXDB_IP" ]; then
  echo "Warning: InfluxDB LoadBalancer IP not yet assigned. Please check the service status."
else
  echo "InfluxDB is accessible at http://$INFLUXDB_IP:$INFLUXDB_PORT"
fi

if [ -z "$CHRONOGRAF_IP" ]; then
  echo "Warning: Chronograf LoadBalancer IP not yet assigned. Please check the service status."
else
  echo "Chronograf UI is accessible at http://$CHRONOGRAF_IP:$CHRONOGRAF_PORT"
fi

echo "Admin username: admin"
echo "Admin password: $ADMIN_PASSWORD"
echo "Please save this password securely. It will not be shown again."