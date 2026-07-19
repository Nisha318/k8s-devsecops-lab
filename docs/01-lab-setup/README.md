# Lab Setup: 3-Node kubeadm Cluster on ESXi

## Overview

This documents the end-to-end build of a 3-node Kubernetes cluster on a bare metal
ESXi server using kubeadm. 

## Prerequisites

- ESXi host with at least 8GB RAM and 120GB storage available
- Ubuntu Server 24.04 LTS ISO
- Internet access from ESXi VMs

---

## Phase 1: VM Provisioning (ESXi)

### VM Specifications

| VM Name | vCPU | RAM | Disk | Role | IP |
|---|---|---|---|---|---|
| kmaster | 2 | 4GB | 40GB | Control Plane | 192.168.86.58 |
| kworker1 | 2 | 2GB | 40GB | Worker | 192.168.86.213 |
| kworker2 | 2 | 2GB | 40GB | Worker | 192.168.86.248 |

### ESXi VM Creation Steps

1. Upload Ubuntu ISO to ESXi datastore
2. Create each VM: Guest OS = Ubuntu Linux 64-bit, Network = VM Network
3. Boot and install Ubuntu Server, enable OpenSSH during install

---

## Phase 2: Static IP Configuration (All Nodes)

> **Lab Note:** Always run `ip link show` before editing netplan to confirm
> the correct interface name. On these VMs the interface is `ens160`, not
> `ens192`. Interface names vary by VMware adapter type and Ubuntu version.

```bash
# Check your interface name first
ip link show

sudo nano /etc/netplan/00-installer-config.yaml
```

```yaml
network:
  version: 2
  ethernets:
    ens160:
      dhcp4: false
      addresses:
        - 192.168.86.58/24       # change per node
      routes:
        - to: default
          via: 192.168.86.1
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
```

```bash
sudo chmod 600 /etc/netplan/00-installer-config.yaml
sudo netplan apply
```

---

## Phase 3: Hostnames and /etc/hosts (All Nodes)

```bash
# Set hostname (run on each node with its own name)
sudo hostnamectl set-hostname kmaster

# Add to /etc/hosts on all nodes
sudo nano /etc/hosts
```

```
192.168.86.58   kmaster
192.168.86.213  kworker1
192.168.86.248  kworker2
```

---

## Phase 4: Kernel Prerequisites (All Nodes)

```bash
# Disable swap permanently -- both commands required
# swapoff -a disables swap for the current session only
# sed removes the fstab entry so swap does not return on reboot
sudo swapoff -a
sudo sed -i '/swap/d' /etc/fstab

# Load required kernel modules
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Set sysctl parameters
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system
```

**Why swap is disabled:** Kubernetes enforces hard memory limits per container.
Swap makes memory unpredictable and breaks the scheduler's resource accounting.
From a security perspective, swap can write sensitive container memory to disk unencrypted.

---

## Phase 5: containerd Installation (All Nodes)

```bash
sudo apt-get update
sudo apt-get install -y containerd

sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

# Critical: enable SystemdCgroup or pods will crashloop
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

sudo systemctl restart containerd
sudo systemctl enable containerd
```

**Verify:**
```bash
grep SystemdCgroup /etc/containerd/config.toml
# Expected: SystemdCgroup = true

sudo systemctl status containerd
# Expected: active (running)
```

---

## Phase 6: kubeadm, kubelet, kubectl Installation (All Nodes)

```bash
sudo apt-get install -y apt-transport-https ca-certificates curl gpg conntrack

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /' | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl

# Pin versions -- prevents uncontrolled upgrades
sudo apt-mark hold kubelet kubeadm kubectl
```

**Verify:**
```bash
kubeadm version
kubectl version --client
```

---

## Phase 7: Cluster Initialization (kmaster only)

> **Lab Note:** The pod CIDR must not overlap with your physical network.
> This lab uses `10.244.0.0/16` which does not conflict with the home network
> at `192.168.86.0/24`. The pod CIDR cannot be changed after init without
> rebuilding the cluster.

```bash
sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=192.168.86.58
```

**Set up kubectl access:**
```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

**Save the join command** from the kubeadm init output. You need it for Phase 9.
To regenerate it later:
```bash
kubeadm token create --print-join-command
```

---

## Phase 8: CNI Plugin Installation (kmaster only)

> **Lab Note:** Calico's default pod CIDR is `192.168.0.0/16`. This lab uses
> `10.244.0.0/16` instead. In this environment Calico's IP-in-IP encapsulation
> means overlap with the physical network does not cause failures, but
> non-overlapping ranges are correct network design practice. The pod CIDR
> cannot be changed after init without rebuilding the cluster.

```bash
# Download the manifest
curl -O https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml

# Patch the pod CIDR to match kubeadm init
sed -i 's|192.168.0.0/16|10.244.0.0/16|g' calico.yaml

# Verify the patch applied
grep "10.244.0.0" calico.yaml

# Apply Calico
kubectl apply -f calico.yaml
```

**Verify kmaster is Ready:**
```bash
watch kubectl get nodes
# Wait for Ready status -- takes 60-90 seconds
```

---

## Phase 9: Join Worker Nodes (kworker1 and kworker2)

Run on each worker node:

```bash
sudo kubeadm join 192.168.86.58:6443 --token <token> \
  --discovery-token-ca-cert-hash sha256:<hash>
```

---

## Phase 10: Cluster Verification (kmaster)

```bash
kubectl get nodes
kubectl get pods -n kube-system
kubectl cluster-info
```

**Expected node output:**
```
NAME       STATUS   ROLES           AGE   VERSION
kmaster    Ready    control-plane   5m    v1.31.14
kworker1   Ready    <none>          3m    v1.31.14
kworker2   Ready    <none>          3m    v1.31.14
```

---

## Security Decisions Made During Build

| Decision | Reason |
|---|---|
| Version pinned with apt-mark hold | Prevents uncontrolled upgrades, supports change management |
| Swap disabled permanently (swapoff + fstab) | Prevents sensitive memory spilling to disk, required by kubelet |
| Static IPs on all nodes | Deterministic infrastructure, no surprise IP changes on reboot |
| Separate control plane VM | Workloads cannot run on control plane by default (NoSchedule taint) |
| containerd SystemdCgroup enabled | Consistent cgroup management, prevents kubelet/container conflicts |
| Pod CIDR set to 10.244.0.0/16 | Non-overlapping with physical network per network design best practice |
| Calico manifest patched before apply | Required when pod CIDR differs from Calico default of 192.168.0.0/16 |
