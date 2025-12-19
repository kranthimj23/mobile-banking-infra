output "vpc_id" {
  description = "VPC ID"
  value       = google_compute_network.vpc.id
}

output "vpc_name" {
  description = "VPC Name"
  value       = google_compute_network.vpc.name
}

output "subnet_id" {
  description = "Subnet ID"
  value       = google_compute_subnetwork.subnet.id
}

output "subnet_name" {
  description = "Subnet Name"
  value       = google_compute_subnetwork.subnet.name
}

output "pods_range_name" {
  description = "Pods secondary range name"
  value       = "pods"
}

output "services_range_name" {
  description = "Services secondary range name"
  value       = "services"
}
