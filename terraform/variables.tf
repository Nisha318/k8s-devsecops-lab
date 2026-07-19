variable "aws_region" {
  description = "AWS region to deploy the cluster into"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name prefix applied to all resources"
  type        = string
  default     = "cka-lab"
}

variable "kubernetes_version" {
  description = "Kubernetes minor version to install (e.g. 1.31)"
  type        = string
  default     = "1.31"
}

variable "pod_cidr" {
  description = "CIDR block for pod networking (must not overlap with VPC CIDR or home network)"
  type        = string
  default     = "10.244.0.0/16"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "control_plane_instance_type" {
  description = "EC2 instance type for the control plane node (2 vCPU / 4GB minimum)"
  type        = string
  default     = "t3.medium"
}

variable "worker_instance_type" {
  description = "EC2 instance type for worker nodes"
  type        = string
  default     = "t3.small"
}

variable "worker_count" {
  description = "Number of worker nodes to provision"
  type        = number
  default     = 2
}

variable "key_name" {
  description = "Name of an existing AWS EC2 key pair for SSH access"
  type        = string
}

variable "ssh_allowed_cidr" {
  description = "CIDR allowed to SSH into nodes. Restrict to your IP: x.x.x.x/32"
  type        = string
  default     = "0.0.0.0/0"
}

variable "calico_version" {
  description = "Calico CNI version to install"
  type        = string
  default     = "v3.27.0"
}

variable "volume_size_gb" {
  description = "Root EBS volume size in GB for each node"
  type        = number
  default     = 20
}
