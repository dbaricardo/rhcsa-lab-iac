# Topologia do lab RHCSA (3 VMs + rede privada) sobre libvirt/KVM.
# machines.yaml é a única fonte de verdade: hostnames, IPs, MACs, specs e
# discos extra vêm de lá; este arquivo só traduz aquilo para recursos libvirt.

locals {
  spec     = yamldecode(file("${path.module}/../machines.yaml"))
  machines = local.spec.machines

  base_image = abspath("${path.module}/../output/${local.spec.image}.qcow2")
  ssh_key    = abspath("${path.module}/../output/student_key")

  # Discos extra achatados num mapa "<host>-<label>" => spec, para for_each
  # dos volumes. A ORDEM de anexação não sai daqui (mapa = ordem alfabética
  # das chaves): o bloco dynamic "disk" do domínio percorre a LISTA de
  # machines.yaml, que é o que define sdb/sdc e vda/vdb dentro da VM.
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

  hosts_ip = { for name, m in local.machines : name => m.ip }
}

# Rede NAT: dá saída para a internet (subscription, Flathub para o mirror
# flatpak do classroom) e IP fixo por VM via reserva DHCP do dnsmasq do
# libvirt (casada pelo MAC fixo de machines.yaml) -- é com esse IP que o
# Ansible entra no 1o boot. Depois o role `common` grava um perfil NM
# estático "ens18" com o MESMO IP (igual ao homelab), sem trocar o endereço.
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

  # 1a NIC = gerência (ens18): reserva DHCP hostname/IP pelo MAC fixo.
  # Demais NICs (servera: ens19) na MESMA rede, sem reserva nem IP -- igual
  # ao homelab, onde a 2a NIC está na mesma LAN do gateway.
  dynamic "network_interface" {
    for_each = each.value.nics
    content {
      network_id = libvirt_network.lab.id
      mac        = lower(network_interface.value.mac)
      hostname   = network_interface.key == 0 ? each.key : null
      addresses  = network_interface.key == 0 ? [each.value.ip] : null
    }
  }

  # Disco do SO em SCSI (virtio-scsi; o provider cria o controlador quando
  # há disco com scsi = true) -> /dev/sda dentro da VM, igual ao homelab
  # (scsi0 + scsihw virtio-scsi-pci no Proxmox). A imagem golden também é
  # instalada num disco SCSI (scripts/build-image.sh), então o initramfs
  # hostonly já traz virtio_scsi/sd_mod -- ver kickstart/ks.cfg.tpl.
  disk {
    volume_id = libvirt_volume.root[each.key].id
    scsi      = true
  }

  # Discos extra na ordem da LISTA de machines.yaml: SCSI viram sdb, sdc...
  # (unidades seguintes do mesmo controlador) e virtio viram vda, vdb... --
  # mesmos nomes do `lsblk` do homelab. Mesmo assim, os roles e os
  # exercícios resolvem discos por TAMANHO, nunca pelo nome (a ordem já
  # inverteu entre boots em produção real).
  dynamic "disk" {
    for_each = try(each.value.extra_disks, [])
    content {
      volume_id = libvirt_volume.extra["${each.key}-${disk.value.label}"].id
      scsi      = try(disk.value.bus, "virtio") == "scsi" ? true : null
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
# variáveis que os roles esperam (group_vars/all.yml tem os mesmos valores
# como fallback para quem rodar o playbook com outro inventário).
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
        lab_gateway_ip               = local.spec.network.gateway
        lab_hosts_ip                 = local.hosts_ip
        classroom_host               = local.spec.classroom.host
        classroom_ip                 = local.machines[local.spec.classroom.host].ip
        classroom_port               = local.spec.classroom.port
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
