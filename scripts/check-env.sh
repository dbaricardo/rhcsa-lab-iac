#!/bin/bash
# Valida pré-requisitos antes de build-box/up. Roda em modo "relatório": não
# para no primeiro erro, lista tudo que falhou no final.
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR" || exit 1

FAILURES=0

fail() { echo "  [FALHA] $1"; FAILURES=$((FAILURES + 1)); }
ok()   { echo "  [ok]    $1"; }

check_bin() {
  if command -v "$1" >/dev/null 2>&1; then
    ok "$1 encontrado ($(command -v "$1"))"
  else
    fail "$1 não encontrado no PATH — $2"
  fi
}

echo "== Binários necessários =="
check_bin virt-install "pacote 'virt-install' (libvirt-client / virtinst)"
check_bin virt-customize "pacote 'libguestfs-tools'"
check_bin qemu-img "pacote 'qemu-img'"
check_bin virsh "pacote 'libvirt-client'"
check_bin vagrant "https://www.vagrantup.com/downloads"
check_bin ansible "pacote 'ansible' ou 'ansible-core'"
check_bin envsubst "pacote 'gettext'"
check_bin python3 "pacote 'python3'"
check_bin ssh-keygen "pacote 'openssh-clients'"

echo ""
echo "== Plugin vagrant-libvirt =="
if vagrant plugin list 2>/dev/null | grep -q vagrant-libvirt; then
  ok "plugin vagrant-libvirt instalado"
else
  fail "plugin vagrant-libvirt não instalado — rode: vagrant plugin install vagrant-libvirt"
fi

echo ""
echo "== Collections Ansible (ansible.posix, community.general) =="
if ansible-galaxy collection list 2>/dev/null | grep -q 'ansible\.posix'; then
  ok "collection ansible.posix instalada"
else
  fail "collection ansible.posix ausente — rode: ansible-galaxy collection install -r ansible/requirements.yml"
fi
if ansible-galaxy collection list 2>/dev/null | grep -q 'community\.general'; then
  ok "collection community.general instalada"
else
  fail "collection community.general ausente — rode: ansible-galaxy collection install -r ansible/requirements.yml"
fi

echo ""
echo "== Virtualização aninhada / KVM =="
if [ -e /dev/kvm ]; then
  ok "/dev/kvm presente"
else
  fail "/dev/kvm ausente — verifique se a virtualização (VT-x/AMD-V) está habilitada"
fi

echo ""
echo "== Acesso ao libvirtd =="
if virsh -c qemu:///system list >/dev/null 2>&1; then
  ok "conexão qemu:///system funcionando (usuário no grupo libvirt?)"
else
  fail "sem acesso a qemu:///system — adicione seu usuário ao grupo 'libvirt' e reabra a sessão"
fi

echo ""
echo "== .env =="
if [ -f .env ]; then
  ok ".env encontrado"
  # shellcheck disable=SC1091
  source .env
  for var in RHEL_ISO_PATH STUDENT_PASSWORD; do
    if [ -n "${!var:-}" ]; then
      ok "$var definido"
    else
      fail "$var não definido em .env"
    fi
  done
  if [ -n "${RHEL_ISO_PATH:-}" ]; then
    if [ -f "$RHEL_ISO_PATH" ]; then
      ok "RHEL_ISO_PATH existe ($RHEL_ISO_PATH)"
    else
      fail "RHEL_ISO_PATH não existe no disco: $RHEL_ISO_PATH"
    fi
  fi
else
  fail ".env não encontrado — rode: cp .env.example .env"
fi

echo ""
if [ "$FAILURES" -eq 0 ]; then
  echo "Tudo certo. Pode seguir com 'make build-box'."
  exit 0
else
  echo "$FAILURES verificação(ões) falharam. Corrija antes de continuar" \
       "(ver docs/tutorial-fim-a-fim.md)."
  exit 1
fi
