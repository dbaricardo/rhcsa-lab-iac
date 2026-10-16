#!/bin/bash
# Constrói a imagem golden "rhel10-rhcsa-base" (qcow2) via virt-install +
# kickstart, direto contra a ISO apontada em .env (RHEL_ISO_PATH) -- sem
# Packer.
#
# Fluxo: renderiza o kickstart -> virt-install instala desassistido num
# domínio libvirt temporário -> sysprep offline (image/finalize.sh) ->
# publica output/<imagem>.qcow2, que o Terraform usa como disco base das
# 3 VMs. O domínio temporário é sempre removido.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR" || exit 1

# Terraform e "make check-env" assumem qemu:///system; sem isto,
# virt-install/virsh rodando como usuário comum pode cair em
# qemu:///session (rede/pool "default" diferentes, já causou confusão real).
export LIBVIRT_DEFAULT_URI="qemu:///system"

# shellcheck disable=SC1091
[ -f .env ] && source .env

: "${RHEL_ISO_PATH:?defina RHEL_ISO_PATH no .env (ver .env.example)}"
: "${STUDENT_PASSWORD:?defina STUDENT_PASSWORD no .env}"

if [ ! -f "$RHEL_ISO_PATH" ]; then
  echo "ERRO: RHEL_ISO_PATH '$RHEL_ISO_PATH' não existe. Baixe a ISO RHEL 10" \
       "da sua conta Red Hat Developer e ajuste o .env." >&2
  exit 1
fi

for bin in virt-install virt-customize qemu-img envsubst openssl python3 ssh-keygen; do
  command -v "$bin" >/dev/null 2>&1 || {
    echo "ERRO: '$bin' não encontrado no PATH. Rode 'make check-env' para o diagnóstico completo." >&2
    exit 1
  }
done

IMAGE_NAME="$(python3 -c "import yaml;print(yaml.safe_load(open('machines.yaml'))['image'])")"
STUDENT_USER="$(python3 -c "import yaml;print(yaml.safe_load(open('machines.yaml'))['student']['username'])")"

OUT_DIR="$ROOT_DIR/output"
mkdir -p "$OUT_DIR"
IMAGE="$OUT_DIR/${IMAGE_NAME}.qcow2"
# Instala num arquivo temporário e só renomeia no fim: um build interrompido
# nunca deixa um qcow2 pela metade com o nome final (o Makefile usa a
# existência desse arquivo para decidir se precisa reconstruir).
DISK="${IMAGE}.partial"
KS_RENDERED="$OUT_DIR/ks.cfg"
DOMAIN_NAME="rhcsa-lab-build-$$"

cleanup() {
  if virsh dominfo "$DOMAIN_NAME" >/dev/null 2>&1; then
    virsh destroy "$DOMAIN_NAME" >/dev/null 2>&1 || true
    virsh undefine "$DOMAIN_NAME" --nvram >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

echo "==> Gerando par de chaves SSH do usuário '${STUDENT_USER}' (usado pelo Ansible)"
SSH_KEY_PATH="$OUT_DIR/student_key"
if [ ! -f "$SSH_KEY_PATH" ]; then
  ssh-keygen -t ed25519 -N '' -C 'rhcsa-lab-iac-student' -f "$SSH_KEY_PATH" >/dev/null
fi
STUDENT_SSH_PUBKEY="$(cat "${SSH_KEY_PATH}.pub")"

echo "==> Renderizando kickstart"
export STUDENT_USER STUDENT_SSH_PUBKEY
STUDENT_PASSWORD_HASH="$(openssl passwd -6 "$STUDENT_PASSWORD")"
export STUDENT_PASSWORD_HASH
# shellcheck disable=SC2016  # literais de propósito: lista de variáveis do envsubst
envsubst '${STUDENT_USER} ${STUDENT_PASSWORD_HASH} ${STUDENT_SSH_PUBKEY}' \
  < kickstart/ks.cfg.tpl > "$KS_RENDERED"

echo "==> Criando disco de build ($DISK, 20G)"
rm -f "$DISK"
qemu-img create -f qcow2 "$DISK" 20G

echo "==> Instalação desassistida via virt-install (isso demora alguns minutos)"
# q35 + BIOS (SeaBIOS), igual ao domínio que o Terraform cria: a imagem
# precisa nascer com partição biosboot, não ESP. BIOS vem de NÃO passar
# --boot: "--boot firmware=bios" exige um descritor JSON de firmware BIOS,
# que o seabios do RHEL/Rocky 10 não instala ("Unable to find 'bios'
# firmware", visto em produção) -- sem <os firmware=...> o libvirt usa o
# SeaBIOS embutido do QEMU em qualquer distro.
#
# Disco em SCSI (virtio-scsi), o MESMO barramento do disco do SO nas VMs
# (Terraform: disk { scsi = true } -> /dev/sda, igual ao homelab): o
# initramfs hostonly que a Anaconda gera já nasce com virtio_scsi/sd_mod.
# O kickstart não cita nome de disco (sem ignoredisk/--ondisk) e ainda
# força os drivers SCSI e virtio-blk via dracut.conf.d, então trocar o bus
# aqui de volta para virtio não quebraria o boot das VMs.
virt-install \
  --name "$DOMAIN_NAME" \
  --memory 2048 --vcpus 2 \
  --controller type=scsi,model=virtio-scsi \
  --disk "path=$DISK,format=qcow2,bus=scsi" \
  --location "$RHEL_ISO_PATH" \
  --initrd-inject "$KS_RENDERED" \
  --extra-args "inst.ks=file:/$(basename "$KS_RENDERED") console=ttyS0,115200n8 inst.text" \
  --os-variant rhel10-unknown \
  --machine q35 \
  --graphics none \
  --console pty,target_type=serial \
  --noautoconsole \
  --noreboot \
  --wait -1

echo "==> Instalação concluída (domínio desligou sozinho via 'poweroff' do kickstart)"

# --noreboot acima evita a corrida real já vista em produção: sem ele, o
# virt-install reinicia sozinho o domínio depois do poweroff do kickstart
# (comportamento padrão, presumindo que o usuário quer "usar" a VM
# instalada) -- e esse domínio recém-reiniciado ainda pode estar retendo o
# lock do qcow2 no instante exato em que a linha abaixo chama
# virt-customize, fazendo "qemu-img info" falhar por disco ocupado.
# Undefine explícito aqui, mesmo com --noreboot, é defesa em profundidade
# para o domínio de instalação nunca vazar para o próximo "make build-image".
virsh --connect qemu:///system destroy "$DOMAIN_NAME" >/dev/null 2>&1 || true
virsh --connect qemu:///system undefine "$DOMAIN_NAME" --nvram >/dev/null 2>&1 || true

echo "==> Sysprep offline (image/finalize.sh via virt-customize)"
virt-customize -a "$DISK" --run image/finalize.sh

mv -f "$DISK" "$IMAGE"

echo "==> Imagem pronta: $IMAGE"
echo "==> Próximo passo: 'make deploy' (ou 'make deploy-offline' sem subscription)."
