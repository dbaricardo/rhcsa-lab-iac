#!/bin/bash
# Valida pré-requisitos antes de build-image/deploy. Roda em modo "relatório": não
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
check_bin virt-customize "pacote 'guestfs-tools' no RHEL/Rocky/Fedora (dnf) -- em Debian/Ubuntu (apt) o nome ainda é 'libguestfs-tools'"
check_bin qemu-img "pacote 'qemu-img'"
check_bin virsh "pacote 'libvirt-client'"
check_bin terraform "https://developer.hashicorp.com/terraform/install"
check_bin ansible "pacote 'ansible' ou 'ansible-core'"
check_bin envsubst "pacote 'gettext'"
check_bin python3 "pacote 'python3'"
check_bin ssh-keygen "pacote 'openssh-clients'"
check_bin xorriso "pacote 'xorriso' (usado para validar RHEL_ISO_PATH abaixo)"

echo ""
echo "== Collections Ansible (ansible.posix) =="
if ansible-galaxy collection list 2>/dev/null | grep -q 'ansible\.posix'; then
  ok "collection ansible.posix instalada"
else
  fail "collection ansible.posix ausente — rode: ansible-galaxy collection install -r ansible/requirements.yml"
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
# terraform/variables.tf usa o pool "default" (padrão de toda instalação do
# libvirt), mas em hosts recém-instalados ele às vezes nem foi criado.
if virsh -c qemu:///system pool-info default >/dev/null 2>&1; then
  ok "storage pool 'default' existe"
else
  fail "storage pool 'default' não existe — rode: sudo virsh pool-define-as default dir --target /var/lib/libvirt/images && sudo virsh pool-build default && sudo virsh pool-start default && sudo virsh pool-autostart default"
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
      # A "boot ISO" (netinstall) não traz /BaseOS nem /AppStream -- só a
      # DVD ISO completa tem os pacotes que o kickstart (%packages) e os
      # roles Ansible (dnf install) precisam. Erro comum: baixar a boot ISO
      # por engano, achando que "instala do mesmo jeito" (só que sem rede
      # de saída para os repos da Red Hat, que é exatamente o caso deste
      # projeto, o instalador trava/falha silenciosamente bem mais adiante).
      if command -v xorriso >/dev/null 2>&1; then
        if xorriso -indev "$RHEL_ISO_PATH" -find /BaseOS/repodata -type d \
             2>/dev/null | grep -q repodata \
           && xorriso -indev "$RHEL_ISO_PATH" -find /AppStream/repodata -type d \
             2>/dev/null | grep -q repodata; then
          ok "RHEL_ISO_PATH é a DVD ISO completa (BaseOS/ e AppStream/ presentes)"
        else
          fail "RHEL_ISO_PATH não parece ser a DVD ISO completa (sem /BaseOS/repodata ou /AppStream/repodata) — baixe a 'DVD ISO' na sua conta Red Hat Developer, não a 'boot ISO'"
        fi
      fi
    else
      fail "RHEL_ISO_PATH não existe no disco: $RHEL_ISO_PATH"
    fi
  fi
else
  fail ".env não encontrado — rode: cp .env.example .env"
fi

# qemu:///system roda os domínios como o usuário de sistema 'qemu' (não
# root), mesmo quando virt-install/build-image.sh são executados como root --
# esse usuário precisa de permissão de busca (x) em TODO diretório pai até
# o repositório e até a ISO, senão virt-install só falha bem no final da
# instalação ("Cannot access storage file... Permission denied"), depois de
# já ter gastado minutos baixando vmlinuz/initrd. Bug real: `/root` (e em
# alguns distros o próprio $HOME) vem com modo 0700 por padrão, o que
# bloqueia isso silenciosamente.
is_world_executable() {
  local mode
  mode="$(stat -c '%a' "$1" 2>/dev/null)" || return 1
  local other="${mode: -1}"
  (( other & 1 ))
}

# ACL (setfacl -m u:qemu:--x, a correção que esta checagem recomenda) não
# aparece em `stat %a` -- é uma camada de controle de acesso adicional, não
# refletida no modo octal tradicional. Sem checar isso aqui também, esta
# função reportaria FALHOU pra sempre, mesmo depois do usuário já ter
# aplicado exatamente o fix sugerido (bug já visto ao testar este script).
acl_concede_busca_qemu() {
  command -v getfacl >/dev/null 2>&1 || return 1
  getfacl -p "$1" 2>/dev/null | grep -Eq '^user:qemu:..x'
}

check_qemu_pode_alcancar() {
  local target="$1" label="$2" path dir
  path="$(readlink -f "$target" 2>/dev/null)" || return 0
  dir="$(dirname "$path")"
  while true; do
    if ! is_world_executable "$dir" && ! acl_concede_busca_qemu "$dir"; then
      fail "$label: '$dir' não tem permissão de busca (x) para 'outros' -- o processo qemu (usuário não-root de qemu:///system) não vai conseguir abrir '$target'. Rode: setfacl -m u:qemu:--x '$dir' (ver docs/troubleshooting.md)"
      return
    fi
    [ "$dir" = "/" ] && break
    dir="$(dirname "$dir")"
  done
  ok "$label: caminho até '$target' é atravessável pelo usuário 'qemu'"
}

echo ""
echo "== Acesso do usuário 'qemu' aos caminhos do build =="
check_qemu_pode_alcancar "$ROOT_DIR" "repositório (output/ da imagem golden nasce aqui)"
[ -n "${RHEL_ISO_PATH:-}" ] && [ -f "${RHEL_ISO_PATH:-}" ] \
  && check_qemu_pode_alcancar "$RHEL_ISO_PATH" "RHEL_ISO_PATH"

echo ""
if [ "$FAILURES" -eq 0 ]; then
  echo "Tudo certo. Pode seguir com 'make deploy' (ou 'make deploy-offline')."
  exit 0
else
  echo "$FAILURES verificação(ões) falharam. Corrija antes de continuar" \
       "(ver docs/tutorial-fim-a-fim.md)."
  exit 1
fi
