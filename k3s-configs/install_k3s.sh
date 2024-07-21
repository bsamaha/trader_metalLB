#!/bin/bash

# Define the IP addresses and SSH user
MASTER_IPS=("192.168.1.110" "192.168.1.111" "192.168.1.112")
SSH_USER="bs"
KUBECONFIG_PATH="/etc/rancher/k3s/k3s.yaml"
LOCAL_KUBECONFIG_PATH="/home/$SSH_USER/.kube/config"
LOAD_BALANCER_IP="192.168.1.240"

# Function to set kubeconfig permissions
set_kubeconfig_permissions() {
  local ip=$1
  ssh $SSH_USER@$ip <<EOF
    sudo mkdir -p /home/$SSH_USER/.kube
    sudo cp $KUBECONFIG_PATH $LOCAL_KUBECONFIG_PATH
    sudo chown $SSH_USER:$SSH_USER $LOCAL_KUBECONFIG_PATH
    sudo chmod 600 $LOCAL_KUBECONFIG_PATH
    sudo usermod -aG k3s-admin $SSH_USER
EOF
}

# Initialize the cluster on the first master node
echo "Installing k3s on the first master node ${MASTER_IPS[0]}"
k3sup install --ip ${MASTER_IPS[0]} --user $SSH_USER --cluster --tls-san $LOAD_BALANCER_IP --no-extras --k3s-extra-args "--disable servicelb --disable traefik"

# Set kubeconfig permissions on the first master node
set_kubeconfig_permissions ${MASTER_IPS[0]}

# Join subsequent master nodes to the cluster
for (( i=1; i<${#MASTER_IPS[@]}; i++ )); do
  echo "Joining k3s on master node ${MASTER_IPS[$i]} to the cluster at ${MASTER_IPS[0]}"
  k3sup join --ip ${MASTER_IPS[$i]} --user $SSH_USER --server-user $SSH_USER --server-ip ${MASTER_IPS[0]} --server --no-extras --tls-san $LOAD_BALANCER_IP

  # Set kubeconfig permissions on the subsequent master nodes
  set_kubeconfig_permissions ${MASTER_IPS[$i]}
done

# Ensure KUBECONFIG environment variable is set and adjust permissions
for ip in "${MASTER_IPS[@]}"; do
  ssh $SSH_USER@$ip <<EOF
    echo 'export KUBECONFIG=$LOCAL_KUBECONFIG_PATH' >> /home/$SSH_USER/.bashrc
    sudo sh -c 'echo "%k3s-admin ALL=(ALL) NOPASSWD: /usr/local/bin/kubectl, /usr/local/bin/k3s" > /etc/sudoers.d/k3s-admin'
    sudo chmod 0440 /etc/sudoers.d/k3s-admin
    sudo chmod 644 $KUBECONFIG_PATH
    sudo chown $SSH_USER:$SSH_USER $LOCAL_KUBECONFIG_PATH
EOF
done

# Set up local kubeconfig
echo "Setting up local kubeconfig..."
mkdir -p $HOME/.kube
scp $SSH_USER@${MASTER_IPS[0]}:$LOCAL_KUBECONFIG_PATH $HOME/.kube/config
chmod 600 $HOME/.kube/config

# Set KUBECONFIG environment variable locally
echo "export KUBECONFIG=$HOME/.kube/config" >> $HOME/.bashrc
export KUBECONFIG=$HOME/.kube/config

echo "Installation complete. KUBECONFIG has been set to $KUBECONFIG"
echo "Please run 'source $HOME/.bashrc' or start a new terminal session for the changes to take effect."

# Install MetalLB
echo "Installing MetalLB..."
ssh $SSH_USER@${MASTER_IPS[0]} <<EOF
  kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.7/config/manifests/metallb-native.yaml
  kubectl wait --namespace metallb-system --for=condition=ready pod --selector=app=metallb --timeout=90s
  kubectl apply -f k3s-configs/metallb/metallb-config.yaml
  kubectl apply -f k3s-configs/metallb/metallb-service.yaml
EOF

# Wait for the LoadBalancer IP to be assigned
echo "Waiting for LoadBalancer IP to be assigned..."
ssh $SSH_USER@${MASTER_IPS[0]} <<EOF
  kubectl wait --namespace=kube-system \
    --for=condition=Ready service/k3s-api-server \
    --timeout=90s
EOF

# Update kubeconfig on all nodes with the new LoadBalancer IP
for ip in "${MASTER_IPS[@]}"; do
  echo "Updating kubeconfig on node $ip"
  ssh $SSH_USER@$ip <<EOF
    sudo sed -i "s/server: https:\/\/[0-9.]\+:/server: https:\/\/$LOAD_BALANCER_IP:/" $KUBECONFIG_PATH
    sudo sed -i "s/server: https:\/\/[0-9.]\+:/server: https:\/\/$LOAD_BALANCER_IP:/" $LOCAL_KUBECONFIG_PATH
EOF
done

echo "K3s cluster with MetalLB has been set up successfully."