terraform {
  required_version = ">= 1.5"

  required_providers {
    # 0.8.x: schema estável e amplamente usado. A linha 0.9.x reescreveu o
    # provider inteiro (schema espelhando o XML do libvirt) e quebra tudo
    # que existe para 0.8 -- fixado de propósito até alguém migrar e testar.
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.8.3"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
  }
}

provider "libvirt" {
  uri = var.libvirt_uri
}
