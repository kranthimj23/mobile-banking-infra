variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
}

variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
}

variable "subnet_name" {
  description = "Name of the subnet"
  type        = string
}

variable "pods_range_name" {
  description = "Name of the pods secondary range"
  type        = string
}

variable "services_range_name" {
  description = "Name of the services secondary range"
  type        = string
}

variable "master_cidr" {
  description = "CIDR range for the master"
  type        = string
  default     = "172.16.0.0/28"
}

variable "authorized_networks" {
  description = "List of authorized networks"
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = [
    {
      cidr_block   = "0.0.0.0/0"
      display_name = "all"
    }
  ]
}

variable "node_count" {
  description = "Number of nodes per zone"
  type        = number
  default     = 1
}

variable "min_node_count" {
  description = "Minimum number of nodes per zone"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum number of nodes per zone"
  type        = number
  default     = 5
}

variable "machine_type" {
  description = "Machine type for nodes"
  type        = string
  default     = "e2-standard-4"
}

variable "disk_size_gb" {
  description = "Disk size in GB"
  type        = number
  default     = 100
}

variable "preemptible" {
  description = "Use preemptible nodes"
  type        = bool
  default     = false
}

variable "enable_spot_nodes" {
  description = "Enable spot node pool"
  type        = bool
  default     = false
}

variable "spot_node_count" {
  description = "Number of spot nodes"
  type        = number
  default     = 0
}

variable "spot_min_node_count" {
  description = "Minimum number of spot nodes"
  type        = number
  default     = 0
}

variable "spot_max_node_count" {
  description = "Maximum number of spot nodes"
  type        = number
  default     = 3
}

variable "spot_machine_type" {
  description = "Machine type for spot nodes"
  type        = string
  default     = "e2-standard-2"
}

variable "release_channel" {
  description = "Release channel for GKE"
  type        = string
  default     = "REGULAR"
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}
