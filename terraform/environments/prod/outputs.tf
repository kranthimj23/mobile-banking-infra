output "gke_cluster_name" {
  description = "GKE Cluster Name"
  value       = module.gke.cluster_name
}

output "gke_cluster_endpoint" {
  description = "GKE Cluster Endpoint"
  value       = module.gke.cluster_endpoint
  sensitive   = true
}

output "gke_kubeconfig_command" {
  description = "Command to configure kubectl for GKE"
  value       = module.gke.kubeconfig_command
}

output "vpc_name" {
  description = "VPC Name"
  value       = module.vpc_gcp.vpc_name
}
