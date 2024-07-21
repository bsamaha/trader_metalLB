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
k3sup install --ip ${MASTER_IPS[0]} --user $SSH_USER --cluster --tls-san $LOAD_BALANCER_IP

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
EOF
done

echo "Installation complete. Please log out and log back in for the changes to take effect."