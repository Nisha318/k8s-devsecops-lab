# IAM role for all cluster nodes
# Grants two capabilities:
#   1. SSM Session Manager: passwordless shell access (no bastion needed)
#   2. SSM Parameter Store: control plane writes join command, workers read it

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "cluster_node" {
  name               = "${var.cluster_name}-node-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

# AWS managed policy: enables SSM Session Manager console access
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.cluster_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Custom policy: allows nodes to put/get the kubeadm join command
data "aws_iam_policy_document" "ssm_join_command" {
  statement {
    effect = "Allow"
    actions = [
      "ssm:PutParameter",
      "ssm:GetParameter",
      "ssm:DeleteParameter",
    ]
    resources = [
      "arn:aws:ssm:${var.aws_region}:*:parameter/${var.cluster_name}/*"
    ]
  }
}

resource "aws_iam_role_policy" "ssm_join_command" {
  name   = "${var.cluster_name}-ssm-join-command"
  role   = aws_iam_role.cluster_node.id
  policy = data.aws_iam_policy_document.ssm_join_command.json
}

resource "aws_iam_instance_profile" "cluster_node" {
  name = "${var.cluster_name}-node-profile"
  role = aws_iam_role.cluster_node.name
}
