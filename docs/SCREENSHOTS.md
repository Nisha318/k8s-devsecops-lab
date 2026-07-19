# Lab Verification Screenshots

Visual evidence of cluster build and verification steps. Screenshots are stored in `assets/`.

> Screenshots 01 through 09 cover the initial build process. Screenshots 10 through 14 show verified cluster state and are the primary evidence of a functioning cluster.

---

## Build Process

### 01 ESXi VMs Running
ESXi web UI showing all 3 VMs powered on.

![ESXi VMs Running](../assets/01-esxi-vms-running.png)

---

### 02 Ubuntu First Boot
First boot console on kmaster showing hostname and cloud-init completion.

![Ubuntu First Boot](../assets/02-ubuntu-first-boot.png)

---

### 03 Static IPs Confirmed
`ip addr show` on each node confirming IP assignment. Netplan is configured
with `dhcp4: false` on interface `ens160`. Ubuntu 24.04 may label the
address as `dynamic` in kernel output even with a static netplan config.
Stability is confirmed by consistent IPs across reboots.

![Static IPs](../assets/03-static-ips.png)

---

### 04 Swap Disabled
Output of `free -h` on all 3 nodes confirming `Swap: 0B 0B 0B`.

![Swap Disabled](../assets/04-swap-disabled.png)

---

### 05 containerd Active
`systemctl status containerd` showing `active (running)` with SystemdCgroup enabled.

![containerd Active](../assets/05-containerd-active.png)

---

### 06 kubeadm Version
`kubeadm version` confirming v1.31.14 across all nodes.

![kubeadm Version](../assets/06-kubeadm-version.png)

---

### 07 kubeadm init Success
Full output of `kubeadm init` on kmaster ending with control-plane initialization confirmed.

![kubeadm Init](../assets/07-kubeadm-init-success.png)

---

### 08 Calico CNI Installed
`kubectl get nodes` showing kmaster in `Ready` state after Calico installation.

![Calico CNI](../assets/08-calico-installed.png)

---

### 09 Workers Joined
`kubeadm join` output on kworker1 and kworker2 completing successfully.

![Workers Joined](../assets/09-workers-joined.png)

---

## Cluster Verification

### 10 All Nodes Ready
`kubectl get nodes` confirming all 3 nodes in `Ready` state at v1.31.14.

![All Nodes Ready](../assets/10-all-nodes-ready.png)

---

### 11 Control Plane Pods Running
`kubectl get pods -n kube-system` showing all system pods in `Running` state with 0 restarts.

![kube-system Pods](../assets/11-kube-system-pods.png)

---

### 12 Cluster Info
`kubectl cluster-info` showing API server endpoint at `https://192.168.86.58:6443`.

![Cluster Info](../assets/12-cluster-info.png)

---

### 13 First Workload with Correct Pod CIDR
`kubectl get pods -o wide` showing nginx pods distributed across worker nodes with IPs in the `10.244.x.x` range, confirming the correct pod CIDR is active.

![First Workload](../assets/13-first-workload.png)

---

### 14 Rolling Update
`kubectl rollout status` output confirming zero-downtime rolling update from nginx 1.30.4 to 1.31.3.

![Rolling Update](../assets/14-rolling-update.png)

---

## Troubleshooting Evidence

Screenshots documenting real errors encountered and resolved during the lab build.
Full root cause analysis and fix in `docs/03-troubleshooting-logs/lab-build-errors.md`.

---

### Error 5A: kubelet Crash Loop
`systemctl status kubelet` showing activating (auto-restart) with exit-code failure after swap re-enabled on reboot.

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

Full root cause analysis and fix documented in `docs/03-troubleshooting-logs/lab-build-errors.md`.
