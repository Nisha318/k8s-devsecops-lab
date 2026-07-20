# Lab Project: kubeadm Cluster Build

This document covers the setup, configuration, and verification of the
three-node kubeadm lab cluster used for CKA domain practice. It is a record
of how the lab is built, not a CKA exam objective.

---

## Cluster Topology

| Node | Role | IP | Specs | OS |
|---|---|---|---|---|
| kmaster | Control plane | 192.168.86.58 | 2 vCPU / 4GB RAM | Ubuntu 24.04 |
| kworker1 | Worker | 192.168.86.213 | 2 vCPU / 2GB RAM | Ubuntu 24.04 |
| kworker2 | Worker | 192.168.86.248 | 2 vCPU / 2GB RAM | Ubuntu 24.04 |

| Setting | Value |
|---|---|
| Kubernetes version | v1.31.14 (kubeadm) |
| Pod CIDR | 192.168.0.0/16 (Calico) |
| Service CIDR | 10.96.0.0/12 (kubeadm default) |
| CNI | Calico v3.27.0 |
| Container runtime | containerd (SystemdCgroup = true) |
| Hypervisor | ESXi (bare metal, 3 VMs) |

---

## Layer Stack

Each layer builds on the one below it.

| Layer | What | Why |
|---|---|---|
| 1 | ESXi | Creates 3 VMs on one physical server |
| 2 | Ubuntu 24.04 | OS for each VM. Swap disabled, kernel modules loaded, ip_forward enabled |
| 3 | containerd | Container runtime. SystemdCgroup = true required or pods crashloop |
| 4 | kubeadm + Kubernetes | Bootstraps control plane and registers workers |
| 5 | Calico CNI | Assigns pod IPs and routes inter-pod traffic. Required for nodes to reach Ready state |
| 6 | CoreDNS | DNS for service discovery inside the cluster. Installed automatically by kubeadm |

---

## Build Process

### 01: ESXi VMs Running

ESXi web UI showing all 3 VMs powered on.

![ESXi VMs Running](../assets/01-esxi-vms-running.png)

---

### 02: Ubuntu First Boot

First boot console on kmaster showing hostname and cloud-init completion.

![Ubuntu First Boot](../assets/02-ubuntu-first-boot.png)

---

### 03: Static IPs Confirmed

`ip addr show` on each node confirming IP assignment. Netplan is configured
with `dhcp4: false` on interface `ens160`. Ubuntu 24.04 may label the
address as `dynamic` in kernel output even with a static netplan config.
Stability is confirmed by consistent IPs across reboots.

![Static IPs](../assets/03-static-ips.png)

---

### 04: Swap Disabled

Output of `free -h` on all 3 nodes confirming `Swap: 0B 0B 0B`.

kubelet requires swap to be disabled. If swap is re-enabled on reboot,
kubelet will refuse to start. See Troubleshooting section below.

![Swap Disabled](../assets/04-swap-disabled.png)

---

### 05: containerd Active

`systemctl status containerd` showing `active (running)` with SystemdCgroup enabled.

![containerd Active](../assets/05-containerd-active.png)

---

### 06: kubeadm Version

`kubeadm version` confirming v1.31.14 across all nodes.

![kubeadm Version](../assets/06-kubeadm-version.png)

---

### 07: kubeadm init Success

Full output of `kubeadm init` on kmaster ending with control-plane
initialization confirmed.

![kubeadm Init](../assets/07-kubeadm-init-success.png)

---

### 08: Calico CNI Installed

`kubectl get nodes` showing kmaster in `Ready` state after Calico
installation. Nodes remain in `NotReady` until a CNI plugin is installed.

![Calico CNI](../assets/08-calico-installed.png)

---

### 09: Workers Joined

`kubeadm join` output on kworker1 and kworker2 completing successfully.

![Workers Joined](../assets/09-workers-joined.png)

---

## Cluster Verification

Screenshots 10 through 14 are the primary evidence of a functioning cluster.

### 10: All Nodes Ready

`kubectl get nodes` confirming all 3 nodes in `Ready` state at v1.31.14.

![All Nodes Ready](../assets/10-all-nodes-ready.png)

---

### 11: Control Plane Pods Running

`kubectl get pods -n kube-system` showing all system pods in `Running`
state with 0 restarts.

![kube-system Pods](../assets/11-kube-system-pods.png)

---

### 12: Cluster Info

`kubectl cluster-info` showing API server endpoint at
`https://192.168.86.58:6443`.

![Cluster Info](../assets/12-cluster-info.png)

---

### 13: First Workload with Correct Pod CIDR

`kubectl get pods -o wide` showing nginx pods distributed across worker
nodes with IPs in the `10.244.x.x` range, confirming the correct pod
CIDR is active.

![First Workload](../assets/13-first-workload.png)

---

### 14: Rolling Update

`kubectl rollout status` output confirming zero-downtime rolling update
from nginx 1.30.4 to 1.31.3.

![Rolling Update](../assets/14-rolling-update.png)

---

## Troubleshooting Evidence

Real errors encountered and resolved during the lab build. Full root cause
analysis and fix in `docs/03-troubleshooting-logs/lab-build-errors.md`.

### Error 5A: kubelet Crash Loop

`systemctl status kubelet` showing activating (auto-restart) with
exit-code failure after swap re-enabled on reboot.

![kubelet crash loop](../assets/error5-A-kubelet-status-crashloop.png)

---

### Error 5B: API Server Unreachable

`kubectl get nodes` returning connection refused while kubelet was down.

![kubectl connection refused](../assets/error5-B-kubectl-connection-refused.png)

---

### Error 5C: All Containers Exited

`crictl ps -a` showing all control plane containers in Exited state.

![containers all exited](../assets/error5-C-containers-all-exited.png)

---

### Error 5D: Root Cause Confirmed

`journalctl -u kubelet` showing swap detected, kubelet refuses to start.

![journalctl swap error](../assets/error5-D-journalctl-swap-error.png)

Full root cause analysis and fix in `docs/03-troubleshooting-logs/lab-build-errors.md`.

---

## Tool Installation

### etcdctl and etcdutl

Both tools ship inside the etcd container image but are not installed on the
host by default when etcd runs as a static pod. They must be installed
manually on the control plane node.

This procedure was used to install both tools in this lab. Whether the CKA
exam cluster has them pre-installed is not explicitly documented by the Linux
Foundation. Always verify with `which etcdctl && which etcdutl` on the exam
control plane node before starting any etcd task. If either is missing, use
this procedure with the etcd version matching the exam cluster.

**Check the etcd version running in the cluster:**

```bash
kubectl exec etcd-kmaster -n kube-system -- etcd --version
```

**Install both binaries from the official etcd release tarball:**

```bash
ETCD_VER=v3.5.24   # match to your cluster's etcd version

curl -L https://github.com/etcd-io/etcd/releases/download/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz \
  -o /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz

tar xzf /tmp/etcd-${ETCD_VER}-linux-amd64.tar.gz \
  -C /tmp \
  etcd-${ETCD_VER}-linux-amd64/etcdctl \
  etcd-${ETCD_VER}-linux-amd64/etcdutl

sudo mv /tmp/etcd-${ETCD_VER}-linux-amd64/etcdctl /usr/local/bin/etcdctl
sudo mv /tmp/etcd-${ETCD_VER}-linux-amd64/etcdutl /usr/local/bin/etcdutl
sudo chmod +x /usr/local/bin/etcdctl /usr/local/bin/etcdutl
```

**Verify both are available:**

```bash
etcdctl version
etcdutl version
```

**Why kubectl cp does not work for extracting binaries from the etcd container:**

The etcd container image is distroless. It contains only the etcd, etcdctl,
and etcdutl binaries with no shell, no tar, and no cat. The kubectl cp
command uses tar internally and fails with "executable file not found."
The tarball approach above is the correct method.

---

## Lab Notes

- ESXi VM snapshots should be taken before any phase that intentionally
  breaks the cluster (etcd restore practice, cluster upgrade drills).
- The control plane node has a NoSchedule taint. Workload pods deploy to
  kworker1 and kworker2 only unless tolerations are explicitly set.
- containerd requires SystemdCgroup = true. Without it pods enter
  CrashLoopBackOff even when all other configuration looks correct.
- etcdctl and etcdutl are installed at /usr/local/bin/ on kmaster.
