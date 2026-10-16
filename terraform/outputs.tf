output "vms" {
  description = "Domínios libvirt e IPs do lab."
  value = {
    for name, d in libvirt_domain.vm : name => {
      domain = d.name
      ip     = local.machines[name].ip
    }
  }
}

output "dashboard_url" {
  description = "URL do dashboard web (serviço na workstation)."
  value       = "http://${local.machines[local.spec.dashboard.host].ip}:${local.spec.dashboard.port}"
}

output "inventory" {
  description = "Inventário do Ansible gerado."
  value       = local_file.inventory.filename
}
