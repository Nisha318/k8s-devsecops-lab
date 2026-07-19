# ── Control Plane ─────────────────────────────────────────────────────────────

resource "aws_instance" "control_plane" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.control_plane_instance_type
  subnet_id              = aws_subnet.main.id
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.cluster_node.name
  vpc_security_group_ids = [aws_security_group.cluster.id]

  root_block_device {
    volume_size = var.volume_size_gb
    volume_type = "gp3"
    encrypted   = true
  }

  # Passes cluster variables into the bootstrap script at launch time
  user_data = templatefile("${path.module}/scripts/control_plane.sh", {
    kubernetes_version = var.kubernetes_version
    pod_cidr           = var.pod_cidr
    calico_version     = var.calico_version
    cluster_name       = var.cluster_name
    aws_region         = var.aws_region
  })

  tags = {
    Name = "${var.cluster_name}-control-plane"
    Role = "control-plane"
  }
}

# ── Worker Nodes ──────────────────────────────────────────────────────────────

resource "aws_instance" "worker" {
  count                  = var.worker_count
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.worker_instance_type
  subnet_id              = aws_subnet.main.id
  key_name               = var.key_name
  iam_instance_profile   = aws_iam_instance_profile.cluster_node.name
  vpc_security_group_ids = [aws_security_group.cluster.id]

  root_block_device {
    volume_size = var.volume_size_gb
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = templatefile("${path.module}/scripts/worker.sh", {
    kubernetes_version = var.kubernetes_version
    cluster_name       = var.cluster_name
    aws_region         = var.aws_region
  })

  tags = {
    Name = "${var.cluster_name}-worker-${count.index + 1}"
    Role = "worker"
  }

  # Workers launch after control plane to improve SSM join command availability
  # Note: user_data on the worker polls SSM and waits; the depends_on just
  # prevents the race from being worse than it needs to be.
  depends_on = [aws_instance.control_plane]
}

# ── SSM Parameter Cleanup ─────────────────────────────────────────────────────
# The join command stored in SSM is only needed during bootstrap.
# It is cleaned up by the last worker script after joining, but this
# null resource documents the lifecycle intent.
# For production: rotate the bootstrap token after workers join.
