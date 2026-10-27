data "yandex_vpc_network" "develop" {
  name = "default"
}

data "yandex_vpc_subnet" "develop" {
  name = "default-${var.default_zone}"
}

data "yandex_compute_image" "vm_image" {
  family = var.vm_yandex_compute_image_family
}

resource "yandex_vpc_security_group" "hardening_vm_sg" {
  name       = "${var.project_name}-hardening-vm-sg"
  network_id = data.yandex_vpc_network.develop.id

  ingress {
    protocol       = "TCP"
    description    = "SSH"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    description    = "Web"
    port           = var.web_port
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    description    = "Any outbound"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_compute_instance" "hardening_vm" {
  name        = "${var.project_name}-hardening-vm"
  platform_id = var.vm_platform_id
  zone        = var.default_zone

  resources {
    cores         = var.vm_cores
    memory        = var.vm_memory
    core_fraction = var.vm_core_fraction
  }

  scheduling_policy {
    preemptible = true
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.vm_image.id
      size     = var.vm_boot_disk_size
      type     = var.vm_boot_disk_type
    }
  }

  network_interface {
    subnet_id          = data.yandex_vpc_subnet.develop.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.hardening_vm_sg.id]
  }

  metadata = var.vms_metadata
}