# Create namespace
kubectl create namespace trading

kubectl apply -f ./k3s-configs/timescaledb/timescale-setup.yaml

# Create secrets
kubectl -n trading create secret generic timescaledb-secrets \
  --from-literal=password=$(openssl rand -base64 32)

# Get Coinbase credentials from environment variables or prompt user
API_KEY=${COINBASE_API_KEY:-""}
API_SECRET=${COINBASE_API_SECRET:-""}
PASSPHRASE=${COINBASE_PASSPHRASE:-""}

# Validate credentials
if [[ -z "$API_KEY" || "$API_KEY" == "your-api-key" ]]; then
    echo "Error: Please set COINBASE_API_KEY environment variable"
    exit 1
fi

if [[ -z "$API_SECRET" || "$API_SECRET" == "your-api-secret" ]]; then
    echo "Error: Please set COINBASE_API_SECRET environment variable"
    exit 1
fi

if [[ -z "$PASSPHRASE" || "$PASSPHRASE" == "your-passphrase" ]]; then
    echo "Error: Please set COINBASE_PASSPHRASE environment variable"
    exit 1
fi

# Create secrets for Coinbase API
echo "Creating Coinbase API secrets..."
kubectl -n trading create secret generic coinbase-secrets \
  --from-literal=api-key="$API_KEY" \
  --from-literal=api-secret="$API_SECRET" \
  --from-literal=passphrase="$PASSPHRASE"

# Forward TimescaleDB port
kubectl port-forward -n trading svc/timescaledb 5432:5432 &

# Get password
PGPASSWORD=$(kubectl get secret -n trading timescaledb-secrets -o jsonpath="{.data.password}" | base64 --decode)

# Apply schema
PGPASSWORD=$PGPASSWORD psql -h localhost -U postgres -f timescaledb/schema.sql