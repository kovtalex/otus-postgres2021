variable "project" {
  description = "Project ID"
}

variable "public_key_path" {
  description = "Path to the public key used for ssh access"
}

variable "region" {
  description = "Region"
  default     = "europe-west1"
}

variable "zone" {
  description = "Zone"
  default     = "europe-west1-b"
}

variable "machine_type" {
  description = "Machine type"
  default     = "e2-medium"
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

variable "image" {
  description = "OS image"
  default     = "ubuntu-os-cloud/ubuntu-2004-lts"
}

variable "instance_name" {
  description = "Instance name"
  default     = "instance"
}

variable "instance_count" {
  description = "Instance count"
  default     = 1
}
