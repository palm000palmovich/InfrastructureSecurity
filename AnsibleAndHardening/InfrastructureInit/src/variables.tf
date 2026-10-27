variable "cloud_id" {
  type        = string
  description = "https://cloud.yandex.ru/docs/resource-manager/operations/cloud/get-id"
}

variable "folder_id" {
  type        = string
  description = "https://cloud.yandex.ru/docs/resource-manager/operations/folder/get-id"
}

variable "vpc_name" {
  type        = string
  default     = "develop"
  description = "VPC network & subnet name"
}

variable "vm_yandex_compute_image_family" {
  type    = string
  default = "ubuntu-2204-lts"
}

variable "web_port" {
  type        = number
  default     = 8080
  description = "Нестандартный порт веб-сервера (должен совпадать с web_port в Ansible group_vars/hardening.yml)"
}

variable "default_zone" {
  type        = string
  default     = "ru-central1-e"
  description = "https://cloud.yandex.ru/docs/overview/concepts/geo-scope"
}

variable "project_name" {
  type        = string
  default     = "netology"
  description = "Префикс имени проекта, используется при генерации имён ресурсов"
}

variable "token" {
  type        = string
  description = "OAuth-token; https://cloud.yandex.ru/docs/iam/concepts/authorization/oauth-token"
}

variable "vms_metadata" {
  type        = map(string)
  default     = {}
  description = "Metadata ВМ (ssh-keys, serial-port-enable и т.п.)"
}

variable "vm_cores" {
  type        = number
  default     = 2
  description = "Количество vCPU "
}

variable "vm_memory" {
  type        = number
  default     = 1
  description = "Объём RAM, ГБ"
}

variable "vm_core_fraction" {
  type        = number
  default     = 20
  description = "Гарантированная доля vCPU, % (5 — минимальная, самая дешёвая)"
}

variable "vm_platform_id" {
  type        = string
  default     = "standard-v3"
  description = "Платформа ВМ (standard-v3 доступна в зоне ru-central1-e)"
}

variable "vm_boot_disk_size" {
  type        = number
  default     = 10
  description = "Размер загрузочного диска, ГБ"
}

variable "vm_boot_disk_type" {
  type        = string
  default     = "network-hdd"
  description = "Тип загрузочного диска (network-hdd — самый дешёвый)"
}