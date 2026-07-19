#!/bin/bash
# =============================================================================
# Control Plane Bootstrap Script
# Injected as EC2 user_data via OpenTofu templatefile()
# Variables in $${} are bash; variables in ${} are OpenTofu template vars
# =============================================================================
set -euo pipefail

exec > >(tee /var/log/k8s-control-plane.log) 2>&1
echo "=== Control Plane Bootstrap Started: $(date) ==="

KUBE_VERSION="${kubernetes_version}"
POD_CIDR="${pod_cidr}"
CALICO_VERSION="${calico_version}"
CLUSTER_NAME="${cluster_name}"
AWS_REGION="${aws_region}"

# =============================================================================
# PHASE 1: System Prerequisites (same as every node)
# =============================================================================

echo "--- Phase 1: System prerequisites ---"

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  lsb-release \
  conntrack \
  socat \
  ebtables \
  ipset \
  jq \
  awscli

# Disable swap permanently
swapoff -a
sed -i '/\bswap\b/d' /etc/fstab
echo "Swap disabled"

# Kernel modules required by Kubernetes
cat > /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter
echo "Kernel modules loaded"

# Sysctl: enable packet forwarding and bridge netfilter
cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system
echo "Sysctl parameters applied"

# =============================================================================
# PHASE 2: containerd
# =============================================================================

echo "--- Phase 2: Install containerd ---"

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
  > /etc/apt/sources.list.d/docker.list

apt-get update -y
apt-get install -y containerd.io

# Generate default config and enable SystemdCgroup
# This MUST be true or kubelet and containerd use different cgroup drivers
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

systemctl enable --now containerd
systemctl restart containerd
echo "containerd installed and configured (SystemdCgroup = true)"

# =============================================================================
# PHASE 3: kubeadm, kubelet, kubectl
# =============================================================================

echo "--- Phase 3: Install Kubernetes components v$${KUBE_VERSION} ---"

curl -fsSL "https://pkgs.k8s.io/core:/stable:/v$${KUBE_VERSION}/deb/Release.key" \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
  https://pkgs.k8s.io/core:/stable:/v$${KUBE_VERSION}/deb/ /" \
  > /etc/apt/sources.list.d/kubernetes.list

apt-get update -y
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

systemctl enable kubelet
echo "kubeadm, kubelet, kubectl installed and held at v$${KUBE_VERSION}"

# =============================================================================
# PHASE 4: kubeadm init
# =============================================================================

echo "--- Phase 4: kubeadm init ---"

# Retrieve IPs from EC2 instance metadata service (IMDSv1)
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

echo "Private IP: $${PRIVATE_IP}"
echo "Public IP:  $${PUBLIC_IP}"

kubeadm init \
  --pod-network-cidr="$${POD_CIDR}" \
  --apiserver-advertise-address="$${PRIVATE_IP}" \
  --apiserver-cert-extra-sans="$${PUBLIC_IP}" \
  --kubernetes-version="$${KUBE_VERSION}" \
  --ignore-preflight-errors=NumCPU

echo "kubeadm init complete"

# =============================================================================
# PHASE 5: kubeconfig
# =============================================================================

echo "--- Phase 5: Configure kubeconfig ---"

# For ubuntu user (SSH access)
mkdir -p /home/ubuntu/.kube
cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config

# For root (used by this script going forward)
export KUBECONFIG=/etc/kubernetes/admin.conf

echo "kubeconfig configured for ubuntu user"

# =============================================================================
# PHASE 6: Calico CNI
# =============================================================================

echo "--- Phase 6: Install Calico $${CALICO_VERSION} ---"

# Wait for API server to be fully ready before applying manifests
echo "Waiting for API server..."
until kubectl cluster-info > /dev/null 2>&1; do
  sleep 5
done

kubectl apply -f \
  "https://raw.githubusercontent.com/projectcalico/calico/$${CALICO_VERSION}/manifests/calico.yaml"

echo "Calico applied"

# Wait for Calico pods to start
echo "Waiting for Calico pods..."
kubectl wait --for=condition=Ready pods \
  -l k8s-app=calico-node \
  -n kube-system \
  --timeout=300s

echo "Calico ready; node should be Ready shortly"

# =============================================================================
# PHASE 7: Store join command in SSM Parameter Store
# Workers will poll this parameter until it is available
# =============================================================================

echo "--- Phase 7: Store join command in SSM ---"

# Generate a fresh join command with a 24-hour token
JOIN_COMMAND=$(kubeadm token create --print-join-command)

aws ssm put-parameter \
  --name "/$${CLUSTER_NAME}/join-command" \
  --value "$${JOIN_COMMAND}" \
  --type "SecureString" \
  --overwrite \
  --region "$${AWS_REGION}"

echo "Join command stored at SSM path: /$${CLUSTER_NAME}/join-command"

# =============================================================================
# PHASE 8: Verify
# =============================================================================

echo "--- Phase 8: Cluster verification ---"

kubectl get nodes
kubectl get pods -n kube-system

echo ""
echo "=== Control Plane Bootstrap Complete: $(date) ==="
echo ""
echo "To access the cluster from your local machine:"
echo "  ssh ubuntu@$${PUBLIC_IP} 'cat ~/.kube/config' > ~/.kube/cka-aws-config"
echo "  export KUBECONFIG=~/.kube/cka-aws-config"
echo "  kubectl get nodes"
