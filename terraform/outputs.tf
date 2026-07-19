output "control_plane_public_ip" {
  description = "Public IP of the control plane node"
  value       = aws_instance.control_plane.public_ip
}

output "control_plane_private_ip" {
  description = "Private IP of the control plane node"
  value       = aws_instance.control_plane.private_ip
}

output "worker_public_ips" {
  description = "Public IPs of worker nodes"
  value       = aws_instance.worker[*].public_ip
}

output "worker_private_ips" {
  description = "Private IPs of worker nodes"
  value       = aws_instance.worker[*].private_ip
}

output "ssh_control_plane" {
  description = "SSH command to reach the control plane"
  value       = "ssh -i ~/.ssh/<your-key>.pem ubuntu@${aws_instance.control_plane.public_ip}"
}

output "ssh_workers" {
  description = "SSH commands for each worker node"
  value = [
    for i, w in aws_instance.worker :
    "ssh -i ~/.ssh/<your-key>.pem ubuntu@${w.public_ip}  # worker-${i + 1}"
  ]
}

output "get_kubeconfig" {
  description = "Fetch kubeconfig from control plane after bootstrap completes (~5 min)"
  value       = "ssh -i ~/.ssh/<your-key>.pem ubuntu@${aws_instance.control_plane.public_ip} 'cat ~/.kube/config' > ~/.kube/cka-aws-config && export KUBECONFIG=~/.kube/cka-aws-config"
}

output "check_bootstrap_log" {
  description = "Tail bootstrap log on control plane to watch cluster init progress"
  value       = "ssh -i ~/.ssh/<your-key>.pem ubuntu@${aws_instance.control_plane.public_ip} 'sudo tail -f /var/log/k8s-control-plane.log'"
}

output "get_join_command_from_ssm" {
  description = "Retrieve the kubeadm join command from SSM Parameter Store"
  value       = "aws ssm get-parameter --name /${var.cluster_name}/join-command --with-decryption --region ${var.aws_region} --query Parameter.Value --output text"
}

output "cost_warning" {
  description = "Estimated cost (DESTROY when not in use)"
  value       = "~$0.14/hr (~$3.30/day) for 1x t3.medium + 2x t3.small. Run: tofu destroy"
}
