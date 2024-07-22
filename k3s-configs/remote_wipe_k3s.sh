#!/bin/bash

# Define the IP addresses and SSH user
MASTER_IPS=("192.168.1.110" "192.168.1.111" "192.168.1.112")
SSH_USER="bs"

# Function to execute commands on a remote machine
remote_exec() {
    local ip=$1
    echo "Executing on $ip:"
    ssh $SSH_USER@$ip sudo bash << EOF
set -e
# Stop K3s and remove processes
systemctl stop k3s || true
killall k3s-server 2>/dev/null || true
killall k3s-agent 2>/dev/null || true
killall k3s 2>/dev/null || true

# Uninstall K3s
if [ -f /usr/local/bin/k3s-uninstall.sh ]; then
    /usr/local/bin/k3s-uninstall.sh
else
    echo 'K3s uninstall script not found. K3s may not be installed.'
fi

# Remove Rancher directories
rm -rf /etc/rancher
rm -rf /var/lib/rancher

# Remove K3s binaries
rm -f /usr/local/bin/k3s
rm -f /usr/local/bin/k3s-killall.sh
rm -f /usr/local/bin/k3s-uninstall.sh

# Remove kubeconfig
rm -rf ~/.kube
rm -rf /root/.kube
rm -rf /home/$SSH_USER/.kube  # Add this line to remove the .kube directory for the SSH user

# Unset KUBECONFIG
unset KUBECONFIG
sed -i '/export KUBECONFIG/d' ~/.bashrc ~/.bash_profile ~/.profile
sed -i '/export KUBECONFIG/d' /root/.bashrc /root/.bash_profile /root/.profile

echo 'K3s clean wipe completed on this node.'
EOF
}

# Main execution
main() {
    for ip in "${MASTER_IPS[@]}"; do
        echo "Wiping K3s from $ip..."
        remote_exec $ip
    done
    echo "K3s cluster wipe completed on all nodes."
}

# Run the main function
main