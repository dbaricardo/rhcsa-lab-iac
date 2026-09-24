#version=RHEL10
# Kickstart 100% desassistido do box golden "rhel10-rhcsa-base".
# Renderizado por scripts/build-box.sh (envsubst) a partir de .env — os
# únicos placeholders substituídos são ${RHSM_ORG_ID}, ${RHSM_ACTIVATION_KEY},
# ${STUDENT_USER} e ${STUDENT_PASSWORD_HASH}. Tudo o mais aqui é literal.

text
eula --agreed
lang en_US.UTF-8
keyboard us
timezone UTC --utc
firstboot --disable

# Rede: só o suficiente para a instalação (o registro da subscription e o
# curl da 4a chave GPG no %post precisam de saida para a internet via a rede
# NAT padrao do libvirt usada pelo virt-install). A topologia real de estudo
# (IP fixo por VM) e aplicada depois pelo Vagrant/Ansible, nao aqui, para o
# box golden ficar independente da topologia de qualquer clone.
network --bootproto=dhcp --device=link --activate --hostname=rhcsa-lab-base

# Login root desabilitado por senha (consistente com o ambiente real de
# producao) -- acesso via student + sudo.
rootpw --lock

selinux --enforcing
firewall --enabled --service=ssh

zerombr
clearpart --all --initlabel
# Autopart cobre so o disco de instalacao. Discos extra de storage/LVM sao
# anexados DEPOIS pelo Vagrant/libvirt, sempre brutos (sem particionar aqui),
# para os proprios exercicios praticarem pvcreate/mkfs do zero.
autopart --type=lvm --fstype=xfs

user --name=${STUDENT_USER} --groups=wheel --iscrypted --password=${STUDENT_PASSWORD_HASH}

# Termina com poweroff (nao reboot) para o "virt-install --wait" de
# scripts/build-box.sh detectar o fim da instalacao de forma deterministica.
poweroff

%packages
@^minimal-environment
chrony
firewalld
NetworkManager
openssh-server
sudo
vim-enhanced
tree
%end

%post --log=/root/ks-post.log --erroronfail
set -eux

# --- Bug conhecido (ver docs/troubleshooting.md): RHEL10.0/10.x assina
# pacotes com uma 4a chave de release (pos-quantica, key ID 05707a62) que nao
# vem pre-instalada. Sem isso, dnf install/rpm-build falha com "SIGNATURE:
# NOT OK". Importar aqui resolve de saida, para ninguem redescobrir.
curl -fsSL -o /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release-4 \
  https://security.access.redhat.com/data/6afedf8f.txt
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release-4

# --- Registro da subscription (Red Hat Developer Subscription for
# Individuals, gratuita). Variaveis vem sempre de .env, nunca hardcoded.
subscription-manager register \
  --org="${RHSM_ORG_ID}" \
  --activationkey="${RHSM_ACTIVATION_KEY}" \
  --force
dnf clean all

echo "${STUDENT_USER} ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/${STUDENT_USER}"
chmod 0440 "/etc/sudoers.d/${STUDENT_USER}"

systemctl enable sshd firewalld chronyd NetworkManager

# --- Bug conhecido (ver docs/troubleshooting.md): clonar uma VM sem
# regenerar /etc/machine-id pode deixar o arquivo com contexto SELinux
# unlabeled_t apos o clone, derrubando journald -> dbus -> NetworkManager em
# cascata sem nenhum AVC visivel em ausearch (so aparece em dmesg). Zerar
# aqui forca a regeneracao correta no primeiro boot de cada clone.
truncate -s 0 /etc/machine-id

%end
