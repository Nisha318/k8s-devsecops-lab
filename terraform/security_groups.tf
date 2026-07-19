resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "Security group for all Kubernetes cluster nodes"
  vpc_id      = aws_vpc.main.id

  # ── Inbound ──────────────────────────────────────────────────────────────────

  # SSH from your machine
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  # Kubernetes API server (accessed from anywhere via kubectl from your laptop)
  ingress {
    description = "Kubernetes API Server"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All traffic between nodes in this security group
  # Covers: etcd (2379-2380), kubelet (10250), kube-proxy, NodePort range
  ingress {
    description = "Inter-node: all protocols within cluster"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # Calico IP-in-IP encapsulation (protocol 4) between nodes
  ingress {
    description = "Calico IP-in-IP encapsulation"
    from_port   = 0
    to_port     = 0
    protocol    = "4"
    self        = true
  }

  # Pod CIDR traffic inbound (pods on different nodes communicating)
  ingress {
    description = "Pod network CIDR"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.pod_cidr]
  }

  # Calico BGP between nodes (port 179)
  ingress {
    description = "Calico BGP"
    from_port   = 179
    to_port     = 179
    protocol    = "tcp"
    self        = true
  }

  # NodePort range (allows external access to NodePort services)
  ingress {
    description = "NodePort service range"
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ── Outbound ─────────────────────────────────────────────────────────────────

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-cluster-sg"
  }
}
