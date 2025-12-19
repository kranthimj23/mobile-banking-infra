terraform {
  required_version = ">= 1.0"

  backend "gcs" {
    bucket = "mobile-banking-terraform-state"
    prefix = "dev"
  }
}

locals {
  environment = "dev"
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
  subnet_cidr   = "10.0.0.0/20"
  pods_cidr     = "10.1.0.0/16"
  services_cidr = "10.2.0.0/20"
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

  node_count     = 1
  min_node_count = 1
  max_node_count = 3
  machine_type   = "e2-standard-2"
  preemptible    = true

  labels = local.common_tags
}
