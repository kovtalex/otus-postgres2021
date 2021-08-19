provider "google" {
  project = var.project
  region  = var.region
  zone    = var.zone
}

module "network" {
  source  = "terraform-google-modules/network/google"
  version = "3.3.0"

  project_id   = var.project
  network_name = var.network_name

    subnets = [
        {
            subnet_name   = "otus-subn-eu-n1"
            subnet_ip     = "10.0.10.0/24"
            subnet_region = "europe-north1"
            subnet_private_access = "true"
        },
        {
            subnet_name   = "otus-subn-us-e1"
            subnet_ip     = "10.0.20.0/24"
            subnet_region = "us-east1"
            subnet_private_access = "true"
        },              
        {
            subnet_name   = "otus-subn-asia-e1"
            subnet_ip     = "10.0.30.0/24"
            subnet_region = "asia-east1"
            subnet_private_access = "true"
        }
    ]
}

resource "google_compute_instance" "europe" {
 
  zone         = "europe-north1-a"
  count        = var.instance_count
  name         = "cockdb-${count.index}-eu"
  machine_type = var.machine_type
  tags         = var.tags
  labels       = var.labels
  metadata = {
    ssh-keys = "kovtalex:${file(var.public_key_path)}"
  }
  boot_disk {
    initialize_params {
      image = "${var.image_project}/${var.image_family}"
      size  = var.disk_size
      type  = var.disk_type      
    }
  }
  network_interface {
    network = var.network_name
    subnetwork = module.network.subnets["europe-north1/otus-subn-eu-n1"].self_link
  }
}

resource "google_compute_instance" "asia" {

  zone         = "asia-east1-a"  
  count        = var.instance_count
  name         = "cockdb-${count.index}-asia"
  machine_type = var.machine_type
  tags         = var.tags
  labels       = var.labels
  metadata = {
    ssh-keys = "kovtalex:${file(var.public_key_path)}"
  }
  boot_disk {
    initialize_params {
      image = "${var.image_project}/${var.image_family}"
      size  = var.disk_size
      type  = var.disk_type      
    }
  }
  network_interface {
    network = var.network_name
    subnetwork = module.network.subnets["asia-east1/otus-subn-asia-e1"].self_link
  }
}

resource "google_compute_instance" "america" {

  zone         = "us-east1-b"
  count        = var.instance_count
  name         = "cockdb-${count.index}-us"
  machine_type = var.machine_type
  tags         = var.tags
  labels       = var.labels
  metadata = {
    ssh-keys = "kovtalex:${file(var.public_key_path)}"
  }
  boot_disk {
    initialize_params {
      image = "${var.image_project}/${var.image_family}"
      size  = var.disk_size
      type  = var.disk_type      
    }
  }
  network_interface {
    network = var.network_name
    subnetwork = module.network.subnets["us-east1/otus-subn-us-e1"].self_link
  }
}

resource "google_compute_instance" "vm-bastion" {

  name         = "vm-bastion"
  machine_type = var.machine_type
  tags         = var.tags
  labels       = var.labels
  metadata = {
    ssh-keys = "kovtalex:${file(var.public_key_path)}"
  }
  boot_disk {
    initialize_params {
      image = "${var.image_project}/${var.image_family}"
    }
  }
  network_interface {
    network = var.network_name
    subnetwork = module.network.subnets["europe-north1/otus-subn-eu-n1"].self_link
    access_config {
       nat_ip = google_compute_address.vm-bastion.address
    }
  }
}

resource "google_compute_address" "vm-bastion" {
  name  = "vm-bastion"
}

resource "google_compute_firewall" "rules" {
  name        = "vpc-firewall-rule"
  network     = var.network_name

  allow {
    protocol  = "all"
  }

  target_tags = var.tags
}
