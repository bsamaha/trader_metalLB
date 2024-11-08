# Create namespace
kubectl create namespace trading

kubectl apply -f timescaledb/timescale-setup.yaml

# Create secrets
kubectl -n trading create secret generic timescaledb-secrets \
  --from-literal=password=$(openssl rand -base64 32)

# Create secrets for Coinbase API (you'll need to replace these values)
kubectl -n trading create secret generic coinbase-secrets \
  --from-literal=api-key=your-api-key \
  --from-literal=api-secret=your-api-secret \
  --from-literal=passphrase=your-passphrase

  # Forward TimescaleDB port
kubectl port-forward -n trading svc/timescaledb 5432:5432 &

# Get password
PGPASSWORD=$(kubectl get secret -n trading timescaledb-secrets -o jsonpath="{.data.password}" | base64 --decode)

# Apply schema
PGPASSWORD=$PGPASSWORD psql -h localhost -U postgres -f timescaledb/schema.sql