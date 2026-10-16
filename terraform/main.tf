# Topologia do lab RHCSA (3 VMs + rede privada) sobre libvirt/KVM.
# machines.yaml é a única fonte de verdade: hostnames, IPs, specs e discos
# extra vêm de lá; este arquivo só traduz aquilo para recursos libvirt.

locals {
  spec     = yamldecode(file("${path.module}/../machines.yaml"))
  machines = local.spec.machines

  base_image = abspath("${path.module}/../output/${local.spec.image}.qcow2")
  ssh_key    = abspath("${path.module}/../output/student_key")

  # Discos extra achatados num mapa "<host>-<label>" => spec, para for_each.
  extra_disks = {
    for d in flatten([
      for host, m in local.machines : [
        for disk in try(m.extra_disks, []) : {
          key     = "${host}-${disk.label}"
          host    = host
          size_gb = disk.size_gb
        }
      ]
    ]) : d.key => d
  }
}

# Rede NAT: dá saída para a internet (subscription, repositórios da Red Hat)
# e IP fixo por VM via reserva DHCP do dnsmasq do libvirt -- a imagem golden
# vem com 'network --bootproto=dhcp', então nada precisa ser configurado
# dentro da VM para o IP de machines.yaml valer.
resource "libvirt_network" "lab" {
  name      = local.spec.network.libvirt_name
  mode      = "nat"
  domain    = local.spec.domain
  addresses = [local.spec.network.cidr]
  autostart = true

  dhcp {
    enabled = true
  }

  dns {
    enabled    = true
    local_only = true
  }
}

# Imagem golden gerada por scripts/build-image.sh, copiada uma vez para o
# pool. Os discos raiz das VMs são clones copy-on-write dela.
resource "libvirt_volume" "base" {
  name   = "${var.name_prefix}-base.qcow2"
  pool   = var.storage_pool
  source = local.base_image
  format = "qcow2"
}

resource "libvirt_volume" "root" {
  for_each = local.machines

  name           = "${var.name_prefix}-${each.key}-root.qcow2"
  pool           = var.storage_pool
  base_volume_id = libvirt_volume.base.id
  format         = "qcow2"
}

resource "libvirt_volume" "extra" {
  for_each = local.extra_disks

  name   = "${var.name_prefix}-${each.key}.qcow2"
  pool   = var.storage_pool
  size   = each.value.size_gb * 1024 * 1024 * 1024
  format = "qcow2"
}

resource "libvirt_domain" "vm" {
  for_each = local.machines

  name   = "${var.name_prefix}-${each.key}"
  memory = each.value.memory_mb
  vcpu   = each.value.cpus
  # O provider usa "pc" (i440fx) por padrão, que o QEMU do RHEL/Rocky 10
  # marca como deprecated. q35 é o padrão atual do virt-install.
  machine = "q35"

  cpu {
    mode = "host-passthrough"
  }

  network_interface {
    network_id = libvirt_network.lab.id
    hostname   = each.key
    addresses  = [each.value.ip]
  }

  disk {
    volume_id = libvirt_volume.root[each.key].id
  }

  # O tamanho é a única forma confiável de identificar um disco extra depois
  # (a ordem vdb/vdc já inverteu entre boots em produção real) -- por isso
  # os roles Ansible resolvem discos por tamanho via lab-common.sh, nunca
  # pelo nome do dispositivo.
  dynamic "disk" {
    for_each = [for k, d in local.extra_disks : k if d.host == each.key]
    content {
      volume_id = libvirt_volume.extra[disk.value].id
    }
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type        = "vnc"
    listen_type = "address"
  }

  # libvirt/QEMU do RHEL/Rocky 10 não aceitam mais o modelo 'cirrus'.
  video {
    type = "virtio"
  }
}

# Inventário do Ansible gerado a partir do mesmo machines.yaml, com as
# variáveis que os roles esperam .
resource "local_file" "inventory" {
  filename        = abspath("${path.module}/../output/inventory.yml")
  file_permission = "0644"
  content = yamlencode({
    all = {
      vars = {
        ansible_user                 = local.spec.student.username
        ansible_ssh_private_key_file = local.ssh_key
        lab_domain                   = local.spec.domain
        lab_student_user             = local.spec.student.username
        lab_network_cidr             = local.spec.network.cidr
        dashboard_host               = local.spec.dashboard.host
        dashboard_port               = local.spec.dashboard.port
        dashboard_allowed_source     = local.spec.dashboard.allowed_source
        workstation_ip               = local.machines.workstation.ip
        servera_ip                   = local.machines.servera.ip
        serverb_ip                   = local.machines.serverb.ip
      }
      children = merge(
        {
          for name, m in local.machines : name => {
            hosts = { (name) = { ansible_host = m.ip } }
          }
        },
        {
          lab_hosts = {
            children = { for name, m in local.machines : name => {} if m.role == "server" }
          }
        }
      )
    }
  })

  depends_on = [libvirt_domain.vm]
}
