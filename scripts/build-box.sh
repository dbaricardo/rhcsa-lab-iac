#!/bin/bash
# Constrói o box golden "rhel10-rhcsa-base" via virt-install + kickstart,
# direto contra a ISO apontada em .env (RHEL_ISO_PATH) -- sem Packer.
#
# Fluxo: renderiza o kickstart -> virt-install instala desassistido num
# domínio libvirt temporário -> sysprep offline (image/box-finalize.sh) ->
# empacota o qcow2 como box vagrant-libvirt -> registra com `vagrant box add`
# -> remove o domínio temporário, mantendo só o box final.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR" || exit 1

# vagrant-libvirt e "make check-env" assumem qemu:///system; sem isto,
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

for bin in virt-install virt-customize qemu-img envsubst openssl vagrant python3 ssh-keygen; do
  command -v "$bin" >/dev/null 2>&1 || {
    echo "ERRO: '$bin' não encontrado no PATH. Rode 'make check-env' para o diagnóstico completo." >&2
    exit 1
  }
done

BOX_NAME="$(python3 -c "import yaml;print(yaml.safe_load(open('machines.yaml'))['box'])")"
STUDENT_USER="$(python3 -c "import yaml;print(yaml.safe_load(open('machines.yaml'))['student']['username'])")"

OUT_DIR="$ROOT_DIR/output"
mkdir -p "$OUT_DIR/box"
DISK="$OUT_DIR/${BOX_NAME}.qcow2"
KS_RENDERED="$OUT_DIR/ks.cfg"
DOMAIN_NAME="rhcsa-lab-build-$$"

cleanup() {
  if virsh dominfo "$DOMAIN_NAME" >/dev/null 2>&1; then
    virsh destroy "$DOMAIN_NAME" >/dev/null 2>&1 || true
    virsh undefine "$DOMAIN_NAME" --nvram >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

echo "==> Gerando par de chaves SSH do usuário '${STUDENT_USER}' (usado pelo Vagrant)"
SSH_KEY_PATH="$OUT_DIR/student_key"
if [ ! -f "$SSH_KEY_PATH" ]; then
  ssh-keygen -t ed25519 -N '' -C 'rhcsa-lab-iac-student' -f "$SSH_KEY_PATH" >/dev/null
fi
STUDENT_SSH_PUBKEY="$(cat "${SSH_KEY_PATH}.pub")"

echo "==> Renderizando kickstart"
export STUDENT_USER STUDENT_SSH_PUBKEY
STUDENT_PASSWORD_HASH="$(openssl passwd -6 "$STUDENT_PASSWORD")"
export STUDENT_PASSWORD_HASH
envsubst '${STUDENT_USER} ${STUDENT_PASSWORD_HASH} ${STUDENT_SSH_PUBKEY}' \
  < kickstart/ks.cfg.tpl > "$KS_RENDERED"

echo "==> Criando disco de build ($DISK, 20G)"
rm -f "$DISK"
qemu-img create -f qcow2 "$DISK" 20G

echo "==> Instalação desassistida via virt-install (isso demora alguns minutos)"
virt-install \
  --name "$DOMAIN_NAME" \
  --memory 2048 --vcpus 2 \
  --disk "path=$DISK,format=qcow2,bus=virtio" \
  --location "$RHEL_ISO_PATH" \
  --initrd-inject "$KS_RENDERED" \
  --extra-args "inst.ks=file:/$(basename "$KS_RENDERED") console=ttyS0,115200n8 inst.text" \
  --os-variant rhel10-unknown \
  --graphics none \
  --console pty,target_type=serial \
  --noautoconsole \
  --wait -1

echo "==> Instalação concluída (domínio desligou sozinho via 'poweroff' do kickstart)"

echo "==> Sysprep offline (image/box-finalize.sh via virt-customize)"
virt-customize -a "$DISK" --run image/box-finalize.sh

echo "==> Empacotando como box vagrant-libvirt"
cat > "$OUT_DIR/box/metadata.json" <<EOF
{
  "provider": "libvirt",
  "format": "qcow2",
  "virtual_size": 20
}
EOF
cp "$DISK" "$OUT_DIR/box/box.img"
tar -czf "$OUT_DIR/${BOX_NAME}.box" -C "$OUT_DIR/box" metadata.json box.img

echo "==> Registrando o box no Vagrant"
vagrant box add "$BOX_NAME" "$OUT_DIR/${BOX_NAME}.box" --force

echo "==> Box '$BOX_NAME' pronto. Confirme com: vagrant box list"
echo "==> Lembrete: a subscription NÃO foi registrada (nem no box, nem em"
echo "    nenhuma VM). Depois de 'make up', registre manualmente cada uma"
echo "    das 3 VMs (workstation/servera/serverb) -- ver"
echo "    docs/tutorial-fim-a-fim.md, passo 8 -- e só então rode"
echo "    'make reprovision'."
