variable "libvirt_uri" {
  description = "URI do libvirt onde as VMs do lab são criadas."
  type        = string
  default     = "qemu:///system"
}

variable "storage_pool" {
  description = "Storage pool do libvirt para os discos das VMs (precisa existir; 'default' vem em toda instalação padrão do libvirt)."
  type        = string
  default     = "default"
}

variable "name_prefix" {
  description = "Prefixo dos domínios, volumes e da rede no libvirt -- evita colisão com outras VMs do host."
  type        = string
  default     = "rhcsa-lab"
}
