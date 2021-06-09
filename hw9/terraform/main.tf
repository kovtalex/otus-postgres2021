provider "google" {
  project = var.project
  region  = var.region
  zone    = var.zone
}

resource "google_compute_instance" "default" {
  count        = var.instance_count
  name         = "${var.instance_name}${count.index + 1}"
  machine_type = var.machine_type
  tags         = var.tags
  labels       = var.labels
  metadata = {
    ssh-keys = "kovtalex:${file(var.public_key_path)}"
  }
  boot_disk {
    initialize_params {
      image = var.image
    }
  }
  network_interface {
    network = "default"
    access_config {
      nat_ip = element(google_compute_address.default[*].address, count.index)
    }
  }
}

resource "google_compute_address" "default" {
  name  = "${var.instance_name}${count.index + 1}"
  count = var.instance_count
}
