variable "project" {
  description = "The project ID to host the cluster in"
}

variable "region" {
  description = "The region to host the cluster in"
  default     = "europe-north1"
}

variable "network" {
  description = "The VPC network to host the cluster in"
  default     = "default"
}

variable "subnetwork" {
  description = "The subnetwork to host the cluster in"
  default     = ""
}

variable "ip_range_pods" {
  description = "The secondary ip range to use for pods"
  default     = ""  
}

variable "ip_range_services" {
  description = "The secondary ip range to use for services"
  default     = ""  
}

variable "cluster_name" {
  description = "The cluster name"
  default     = "cluster1"  
}
