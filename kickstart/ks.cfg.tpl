#version=RHEL10
# Kickstart 100% desassistido da imagem golden "rhel10-rhcsa-base".
# Renderizado por scripts/build-image.sh (envsubst) a partir de .env e de uma
# chave SSH gerada localmente — os únicos placeholders substituídos são
# ${STUDENT_USER}, ${STUDENT_PASSWORD_HASH} e ${STUDENT_SSH_PUBKEY}. Tudo o
# mais aqui é literal.
#
# A subscription (Red Hat Developer Subscription for Individuals) NÃO é
# registrada aqui: cada VM clonada desta imagem precisa do seu próprio registro
# (registrar 1x na imagem golden faria as 3 VMs clonadas compartilharem o mesmo
# consumer ID na Red Hat, o que já deu conflito real). Ver
# docs/explanation/arquitetura.md, seção "Subscription e modo offline".

text
eula --agreed
lang en_US.UTF-8
keyboard us
timezone UTC --utc
firstboot --disable

# Rede: só o suficiente para a instalação (o curl da 4a chave GPG no %post
# precisa de saida para a internet via a rede NAT padrao do libvirt usada
# pelo virt-install). A topologia real de estudo (IP fixo por VM) e aplicada
# depois pelo Terraform/Ansible, nao aqui, para a imagem golden ficar
# independente da topologia de qualquer clone.
#
# --device=link (escolhe "o primeiro dispositivo com link up") falha de
# forma real sob nested KVM: o parser de kickstart do dracut roda cedo
# demais no boot, antes do virtio-net terminar de negociar o link, e
# desiste silenciosamente ("WARNING: No device with link found for
# --device=link") -- sem --device, a Anaconda usa o primeiro dispositivo
# de rede encontrado, sem depender do link já estar up nesse ponto do boot.
network --bootproto=dhcp --activate --hostname=rhcsa-lab-base

# Login root desabilitado por senha (consistente com o ambiente real de
# producao) -- acesso via student + sudo.
rootpw --lock

selinux --enforcing
firewall --enabled --service=ssh

zerombr
clearpart --all --initlabel
# Layout explícito (não autopart) para bater com o `lsblk` das VMs do homelab
# byte a byte: sda1 biosboot 1 MiB, sda2 /boot 1 GiB, sda3 PV com VG "rhel"
# (swap 2 GiB + root no resto). Nenhuma linha cita o nome do disco (sem
# ignoredisk/--ondisk): o domínio de build tem um único disco, seja ele
# sda ou vda, então a imagem não depende do barramento -- ver
# scripts/build-image.sh e docs/explanation/problemas-conhecidos.md.
# Discos extra de storage/LVM são anexados DEPOIS pelo Terraform/libvirt,
# sempre brutos (sem particionar aqui), para os próprios exercícios
# praticarem pvcreate/mkfs do zero.
part biosboot --fstype=biosboot --size=1
part /boot --fstype=xfs --size=1024
part pv.01 --size=1 --grow
volgroup rhel pv.01
logvol swap --vgname=rhel --name=swap --size=2048
logvol / --vgname=rhel --name=root --fstype=xfs --size=1 --grow

user --name=${STUDENT_USER} --groups=wheel --iscrypted --password=${STUDENT_PASSWORD_HASH}

# Termina com poweroff (nao reboot) para o "virt-install --wait" de
# scripts/build-image.sh detectar o fim da instalacao de forma deterministica.
poweroff

%packages
@^minimal-environment
chrony
firewalld
NetworkManager
openssh-server
sudo
vim-enhanced
%end

%post --log=/root/ks-post.log --erroronfail
set -eux

# --- Bug conhecido (ver docs/explanation/problemas-conhecidos.md): RHEL10.0/10.x assina
# pacotes com uma 4a chave de release (pos-quantica, key ID 05707a62) que nao
# vem pre-instalada. Sem isso, dnf install/rpm-build falha com "SIGNATURE:
# NOT OK". Importar aqui resolve de saida, para ninguem redescobrir.
#
# NÃO fatal de propósito (ao contrário do resto deste %post, que usa
# --erroronfail + set -e): a rede de saída do domínio de BUILD depende do
# ambiente onde `make build-image` roda (proxy, firewall, NAT aninhado em
# testes) e já foi vista falhando/travando aqui em produção real -- sem o
# --max-time, um curl sem rede que apenas trava (em vez de falhar rápido)
# deixa a instalação inteira pendurada num prompt de erro que
# --noautoconsole nunca mostra, sem nenhum sinal do que aconteceu. O role
# Ansible `common` já reimporta essa mesma chave, com o mesmo
# `failed_when: false`, como defesa em profundidade em toda VM antes de
# qualquer dnf install -- este bloco aqui é só uma otimização de "resolver
# de saída", não a única linha de defesa.
if curl -fsSL --max-time 20 -o /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release-4 \
     https://security.access.redhat.com/data/6afedf8f.txt \
   && rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release-4; then
  echo "4a chave de release do RHEL10 importada com sucesso."
else
  echo "AVISO: não foi possível importar a 4a chave de release do RHEL10" \
       "durante o build (sem rede de saída no domínio de build?)." \
       "O role Ansible 'common' reimporta essa chave em toda VM antes de" \
       "qualquer dnf install -- ver docs/explanation/problemas-conhecidos.md." >&2
fi

echo "${STUDENT_USER} ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/${STUDENT_USER}"
chmod 0440 "/etc/sudoers.d/${STUDENT_USER}"

# --- Chave pública SSH gerada por scripts/build-image.sh (par fica em
# output/, nunca commitado, ver .gitignore). É a chave com que o Ansible
# entra nas VMs (ansible_ssh_private_key_file no inventário gerado pelo
# Terraform) -- sem ela o 1o provisionamento não autentica.
install -d -m 0700 -o "${STUDENT_USER}" -g "${STUDENT_USER}" "/home/${STUDENT_USER}/.ssh"
echo "${STUDENT_SSH_PUBKEY}" > "/home/${STUDENT_USER}/.ssh/authorized_keys"
chmod 0600 "/home/${STUDENT_USER}/.ssh/authorized_keys"
chown "${STUDENT_USER}:${STUDENT_USER}" "/home/${STUDENT_USER}/.ssh/authorized_keys"

systemctl enable sshd firewalld chronyd NetworkManager

# --- Disco do SO em SCSI nas VMs (Terraform: disk { scsi = true }) e o build
# também roda num disco SCSI (scripts/build-image.sh), então o initramfs
# hostonly gerado pela Anaconda já traz virtio_scsi + sd_mod. Este drop-in
# é defesa em profundidade: garante os dois drivers (SCSI e virtio-blk) em
# TODO initramfs futuro (kernel novo, dracut -f do aluno), para a imagem
# dar boot em qualquer um dos barramentos sem depender de hostonly=no
# (initramfs genérico, bem maior). Regenera agora pelo mesmo motivo.
cat > /etc/dracut.conf.d/90-rhcsa-lab-disk-drivers.conf <<'DRACUT'
# rhcsa-lab-iac: disco do SO pode ser SCSI (sda) ou virtio-blk (vda).
add_drivers+=" virtio_scsi sd_mod virtio_blk "
DRACUT
dracut -f --regenerate-all

# --- PermitRootLogin yes, igual às VMs do homelab (gerado pela Anaconda
# delas): o dispatcher da workstation entra como root@servera/serverb/
# localhost por CHAVE (role ssh_crosshost). A conta root continua sem senha
# (rootpw --lock), então nada entra por senha.
cat > /etc/ssh/sshd_config.d/01-permitrootlogin.conf <<'SSHD'
# This file has been generated by the Anaconda Installer.
# Allow root to log in using ssh. Remove this file to opt-out.
PermitRootLogin yes
SSHD
chmod 0600 /etc/ssh/sshd_config.d/01-permitrootlogin.conf

# --- Bug conhecido (ver docs/explanation/problemas-conhecidos.md): clonar uma VM sem
# regenerar /etc/machine-id pode deixar o arquivo com contexto SELinux
# unlabeled_t apos o clone, derrubando journald -> dbus -> NetworkManager em
# cascata sem nenhum AVC visivel em ausearch (so aparece em dmesg). Zerar
# aqui forca a regeneracao correta no primeiro boot de cada clone.
truncate -s 0 /etc/machine-id

%end
