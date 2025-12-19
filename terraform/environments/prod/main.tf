terraform {
  required_version = ">= 1.0"

  backend "gcs" {
    bucket = "mobile-banking-terraform-state"
    prefix = "prod"
  }
}

locals {
  environment = "prod"
  project_id  = var.gcp_project_id
  region      = var.gcp_region

  common_tags = {
    Environment = local.environment
    Project     = "mobile-banking"
    ManagedBy   = "terraform"
  }
}

module "vpc_gcp" {
  source = "../../modules/vpc-gcp"

  project_id    = local.project_id
  region        = local.region
  vpc_name      = "mobile-banking-${local.environment}"
  subnet_cidr   = "10.10.0.0/20"
  pods_cidr     = "10.11.0.0/16"
  services_cidr = "10.12.0.0/20"
}

module "gke" {
  source = "../../modules/gke"

  project_id          = local.project_id
  region              = local.region
  cluster_name        = "mobile-banking-${local.environment}"
  vpc_name            = module.vpc_gcp.vpc_name
  subnet_name         = module.vpc_gcp.subnet_name
  pods_range_name     = module.vpc_gcp.pods_range_name
  services_range_name = module.vpc_gcp.services_range_name

  node_count     = 3
  min_node_count = 3
  max_node_count = 10
  machine_type   = "e2-standard-4"
  preemptible    = false

  enable_spot_nodes   = true
  spot_node_count     = 0
  spot_min_node_count = 0
  spot_max_node_count = 5
  spot_machine_type   = "e2-standard-2"

  release_channel = "STABLE"

  labels = local.common_tags
}
