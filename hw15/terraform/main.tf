provider "google" {
  project = var.project    
  region  = var.region
}

module "gke" {
  source                             = "terraform-google-modules/kubernetes-engine/google"    
  
  # required variables
  project_id                         = var.project
  name                               = var.cluster_name
  region                             = var.region
  network                            = var.network
  subnetwork                         = var.subnetwork
  ip_range_pods                      = var.ip_range_pods
  ip_range_services                  = var.ip_range_services

  # optional variables
  create_service_account             = false
  remove_default_node_pool           = true  
  enable_resource_consumption_export = false

  # addons  
  network_policy                     = false
  horizontal_pod_autoscaling         = false
  http_load_balancing                = false  


  node_pools = [
    {
      name                           = "default-node-pool"
      machine_type                   = "e2-medium"
      min_count                      = 1      
      max_count                      = 1
      disk_size_gb                   = 20
      disk_type                      = "pd-standard"
      auto_repair                    = true
      auto_upgrade                   = true
      initial_node_count             = 1      
      preemptible                    = false      
      tags                           = "postgres"
    },
  ]
}
