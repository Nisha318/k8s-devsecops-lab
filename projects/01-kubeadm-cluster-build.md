# Project: 3-Node Kubernetes Cluster Build on ESXi

## Overview

Designed and deployed a production-like Kubernetes lab environment from scratch
on a bare metal ESXi server using kubeadm. The build covers the full stack from
VM provisioning through cluster initialization and workload deployment.

## Problem Statement

Transitioning from cybersecurity compliance into DevSecOps engineering requires
hands-on Kubernetes experience beyond what managed services like EKS provide.
A self-managed kubeadm cluster forces engagement with every layer of the
platform, from the container runtime up through the control plane components.

## Architecture

```
ESXi Host (bare metal)
  kmaster   192.168.86.58    Control Plane   Ubuntu 24.04   2 vCPU / 4GB
  kworker1  192.168.86.213   Worker          Ubuntu 24.04   2 vCPU / 2GB
  kworker2  192.168.86.248   Worker          Ubuntu 24.04   2 vCPU / 2GB

Network: 192.168.86.0/24 (bridged to home network via ESXi vSwitch)
Pod CIDR: 192.168.0.0/16 (Calico CNI)
Service CIDR: 10.96.0.0/12 (kubeadm default)
```

## Technology Stack

| Layer | Technology | Version |
|---|---|---|
| Hypervisor | VMware ESXi | Type 1 |
| Operating System | Ubuntu Server | 24.04 LTS |
| Container Runtime | containerd | Latest |
| Cluster Bootstrap | kubeadm | v1.31.14 |
| CNI Plugin | Calico | v3.27.0 |
| kubectl | kubectl | v1.31.14 |

## Skills Demonstrated

### Infrastructure
- Bare metal hypervisor configuration (ESXi vSwitch, port groups, datastore)
- VM provisioning and OS installation at scale
- Static IP assignment via netplan (Ubuntu 24.04)
- SSH key-based access configuration

### Linux Administration
- Kernel module management (overlay, br_netfilter)
- sysctl parameter configuration for container networking
- Swap management and permanent disable via fstab
- systemd service management (containerd, kubelet)

### Kubernetes
- kubeadm cluster initialization with custom CIDR and API server address
- PKI certificate generation (CA, API server, etcd, service accounts)
- CNI plugin deployment and pod network configuration
- Worker node join and cluster verification

### Security Engineering
- Version pinning to prevent uncontrolled upgrades (apt-mark hold)
- Disabled swap to prevent sensitive memory exposure to disk
- Static node IPs for deterministic infrastructure
- Default control plane taint enforces workload isolation
- containerd SystemdCgroup enabled for consistent cgroup hierarchy

## Challenges and Resolutions

| Challenge | Resolution |
|---|---|
| conntrack missing on Ubuntu 24.04 | apt-get install conntrack before kubeadm init |
| netplan YAML indentation error | Fixed route block indentation; documented YAML spacing rules |
| netplan permissions warning | chmod 600 on netplan config file |

## Compliance Connections

This build maps directly to NIST 800-53 controls relevant to container platforms:

| Control | Implementation |
|---|---|
| CM-7 Least Functionality | NoSchedule taint on control plane prevents workload co-location |
| CM-6 Configuration Settings | kubeadm-config stored in ConfigMap, all settings documented |
| SC-28 Protection at Rest | Swap disabled prevents container memory exposure to disk |
| SI-2 Flaw Remediation | Version pinning supports controlled, tested upgrades |

## Next Steps

- Deploy first workload and verify pod scheduling across workers
- Practice etcd backup and restore
- Implement RBAC policies
- Add metrics-server for resource monitoring
- Practice cluster upgrade from v1.31 to v1.32
