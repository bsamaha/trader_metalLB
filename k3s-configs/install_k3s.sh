#!/bin/bash

# Define the IP addresses and SSH user
MASTER_IPS=("192.168.1.110" "192.168.1.111" "192.168.1.112")
SSH_USER="bs"
LOAD_BALANCER_IP="192.168.1.240"

# Initialize the cluster on the first master node
echo "Installing k3s on the first master node ${MASTER_IPS[0]}"
k3sup install --ip ${MASTER_IPS[0]} --user $SSH_USER --cluster --tls-san $LOAD_BALANCER_IP --no-extras --k3s-extra-args "--disable servicelb --disable traefik"

# Join subsequent master nodes to the cluster
for (( i=1; i<${#MASTER_IPS[@]}; i++ )); do
  echo "Joining k3s on master node ${MASTER_IPS[$i]} to the cluster at ${MASTER_IPS[0]}"
  k3sup join --ip ${MASTER_IPS[$i]} --user $SSH_USER --server-user $SSH_USER --server-ip ${MASTER_IPS[0]} --server --no-extras --tls-san $LOAD_BALANCER_IP
done

echo "K3s cluster setup complete."