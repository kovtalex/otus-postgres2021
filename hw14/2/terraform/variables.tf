variable "project" {
  description = "Project ID"
}

variable "public_key_path" {
  description = "Path to the public key used for ssh access"
}

variable "region" {
  description = "Region"
  default     = "europe-north1"
}

variable "zone" {
  description = "Zone"
  default     = "europe-north1-a"
}

variable "machine_type" {
  description = "Machine type"
  default     = "e2-medium"
}

variable "disk_size" {
  description = "Instance disk size in GB"
  default     = "25"
}

variable "disk_type" {
  description = "Instance disk type"
  default     = "pd-ssd"
}

variable "tags" {
  description = "Tags"
  default     = ["instance"]
}

variable "labels" {
  description = "Instance labels"
  type        = map(string)

  default = {
    name = "instance"
  }
}

variable "image_family" {
  description = "OS image family"  
  default     = "ubuntu-2004-lts"
}

variable "image_project" {
  description = "OS image project"
  default     = "ubuntu-os-cloud"
}

variable "instance_name" {
  description = "Instance name"
  default     = "instance"
}

variable "instance_count" {
  description = "Instance count"
  default     = 3
}

variable "network_name" {
  default = "otus-vpc"
}
