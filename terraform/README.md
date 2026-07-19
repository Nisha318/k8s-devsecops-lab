# CKA Lab: kubeadm on AWS (OpenTofu)

Provisions the same 3-node kubeadm cluster as the ESXi lab, but on AWS EC2
using OpenTofu (Terraform-compatible). Fully automated: no manual steps after
`tofu apply`.

## Architecture

```
AWS Region (us-east-1)
  VPC 10.0.0.0/16
    Public Subnet 10.0.1.0/24
      cka-lab-control-plane   t3.medium   Ubuntu 24.04   kube-apiserver, etcd, scheduler, controller-manager
      cka-lab-worker-1        t3.small    Ubuntu 24.04   kubelet, kube-proxy, containerd
      cka-lab-worker-2        t3.small    Ubuntu 24.04   kubelet, kube-proxy, containerd
    Internet Gateway
    Security Group (ports 22, 6443, 30000-32767 + all intra-cluster)

Pod CIDR:     192.168.0.0/16  (Calico)
Service CIDR: 10.96.0.0/12    (kubeadm default)
CNI:          Calico v3.27.0
Runtime:      containerd (SystemdCgroup = true)
```

## How Bootstrap Works

1. `tofu apply` provisions VPC, security group, IAM role, and 3 EC2 instances
2. Control plane `user_data` script runs automatically on first boot:
   - Disables swap, loads kernel modules, sets sysctl
   - Installs containerd with SystemdCgroup = true
   - Installs kubeadm, kubelet, kubectl (held at specified version)
   - Runs `kubeadm init` with your pod CIDR and public IP as SAN
   - Installs Calico CNI
   - Writes the `kubeadm join` command to AWS SSM Parameter Store
3. Worker `user_data` scripts run on boot and poll SSM every 20 seconds
   until the join command is available, then join the cluster automatically

Total bootstrap time: approximately 5-8 minutes after `tofu apply`.

## Prerequisites

- OpenTofu >= 1.6.0 installed (`brew install opentofu` or https://opentofu.org)
- AWS CLI configured (`aws configure`)
- An existing EC2 key pair in the target region
- IAM permissions: EC2, VPC, IAM, SSM

## Usage

```bash
# 1. Clone and enter the directory
cd tofu/

# 2. Create your variables file
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars (set your key_name and ssh_allowed_cidr at minimum)

# 3. Initialize OpenTofu
tofu init

# 4. Preview what will be created
tofu plan

# 5. Apply (cluster builds itself in ~5-8 minutes)
tofu apply

# 6. Watch control plane bootstrap
ssh -i ~/.ssh/cka-lab-key.pem ubuntu@<control_plane_public_ip> \
  'sudo tail -f /var/log/k8s-control-plane.log'

# 7. Get kubeconfig once control plane is ready
ssh -i ~/.ssh/cka-lab-key.pem ubuntu@<control_plane_public_ip> \
  'cat ~/.kube/config' > ~/.kube/cka-aws-config

export KUBECONFIG=~/.kube/cka-aws-config

# 8. Verify cluster
kubectl get nodes
kubectl get pods -n kube-system
```

## Outputs After Apply

```
control_plane_public_ip      = "x.x.x.x"
worker_public_ips            = ["x.x.x.x", "x.x.x.x"]
ssh_control_plane            = "ssh -i ~/.ssh/<key>.pem ubuntu@x.x.x.x"
get_kubeconfig               = "ssh ... 'cat ~/.kube/config' > ~/.kube/cka-aws-config && export ..."
check_bootstrap_log          = "ssh ... 'sudo tail -f /var/log/k8s-control-plane.log'"
get_join_command_from_ssm    = "aws ssm get-parameter ..."
cost_warning                 = "~$0.14/hr (~$3.30/day) ..."
```

## Cost Estimate

| Resource              | Type       | Hourly   | Daily    |
|-----------------------|------------|----------|----------|
| Control plane         | t3.medium  | $0.0416  | $1.00    |
| Worker x2             | t3.small   | $0.0416  | $1.00    |
| EBS volumes x3 (20GB) | gp3        | $0.0050  | $0.12    |
| Data transfer         | minimal    | ~$0.01   | ~$0.10   |
| **Total**             |            | **~$0.14** | **~$3.30** |

**Always run `tofu destroy` when the cluster is not in use.**

## Destroy

```bash
# Tear down all resources (costs stop immediately)
tofu destroy
```

## Differences vs ESXi Lab

| Aspect              | ESXi Lab                     | AWS (this module)              |
|---------------------|------------------------------|--------------------------------|
| Hypervisor          | Bare metal ESXi              | AWS managed (invisible)        |
| VM provisioning     | Manual in ESXi console       | Automated by OpenTofu          |
| Network config      | netplan YAML, static IPs     | VPC, DHCP, EIP                 |
| SSH access          | VS Code Remote SSH           | SSH via public IP or SSM       |
| Bootstrap           | Manual, step by step         | Fully automated user_data      |
| Cost                | Sunk cost (your hardware)    | ~$3.30/day when running        |
| IaC practice        | No                           | Yes (Terraform/OpenTofu HCL)   |
| kubeadm, containerd | Identical                    | Identical                      |
| Kubernetes version  | v1.31.14                     | Configurable (default v1.31)   |
| CNI                 | Calico v3.27.0               | Calico v3.27.0                 |
| CKA relevance       | Full (cluster architecture)  | Full + IaC portfolio addition  |

## Troubleshooting

**Nodes not Ready after 10 minutes:**
```bash
# Check control plane bootstrap log
ssh ubuntu@<cp-ip> 'sudo cat /var/log/k8s-control-plane.log'

# Check worker bootstrap log
ssh ubuntu@<worker-ip> 'sudo cat /var/log/k8s-worker.log'
```

**Workers did not join:**
```bash
# Check if join command made it to SSM
aws ssm get-parameter --name /cka-lab/join-command --with-decryption \
  --region us-east-1 --query Parameter.Value --output text

# If missing, kubeadm init may have failed; check control plane log
```

**containerd issues:**
```bash
ssh ubuntu@<node-ip> 'sudo systemctl status containerd'
ssh ubuntu@<node-ip> 'sudo grep SystemdCgroup /etc/containerd/config.toml'
# Must show: SystemdCgroup = true
```

**API server unreachable from local kubectl:**
```bash
# Confirm port 6443 is open in security group and cluster is actually running
ssh ubuntu@<cp-ip> 'kubectl get nodes'
```

## Connecting to ESXi Lab Context

This module builds the same cluster you built manually on ESXi. The difference
is everything in this module is repeatable, version-controlled, and
destroyable. Use both:

- ESXi lab for hands-on CKA practice (break things, fix them, repeat)
- This module for IaC portfolio work and practicing cloud-native workflows
