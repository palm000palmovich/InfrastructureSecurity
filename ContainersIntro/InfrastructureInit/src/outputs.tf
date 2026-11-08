output "vm_external_ip" {
  value       = yandex_compute_instance.hardening_vm.network_interface.0.nat_ip_address
  description = "Внешний IP ВМ для подключения Ansible по SSH"
}
