#version=RHEL10
# Kickstart 100% desassistido do box golden "rhel10-rhcsa-base".
# Renderizado por scripts/build-box.sh (envsubst) a partir de .env e de uma
# chave SSH gerada localmente — os únicos placeholders substituídos são
# ${STUDENT_USER}, ${STUDENT_PASSWORD_HASH} e ${STUDENT_SSH_PUBKEY}. Tudo o
# mais aqui é literal.
#
# A subscription (Red Hat Developer Subscription for Individuals) NÃO é
# registrada aqui: cada VM clonada deste box precisa do seu próprio registro
# (registrar 1x no box golden faria as 3 VMs clonadas compartilharem o mesmo
# consumer ID na Red Hat, o que já deu conflito real). Ver
# docs/tutorial-fim-a-fim.md, passo 8, para o comando manual pós-boot.

text
eula --agreed
lang en_US.UTF-8
keyboard us
timezone UTC --utc
firstboot --disable

# Rede: só o suficiente para a instalação (o curl da 4a chave GPG no %post
# precisa de saida para a internet via a rede NAT padrao do libvirt usada
# pelo virt-install). A topologia real de estudo (IP fixo por VM) e aplicada
# depois pelo Vagrant/Ansible, nao aqui, para o box golden ficar
# independente da topologia de qualquer clone.
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

echo "${STUDENT_USER} ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/${STUDENT_USER}"
chmod 0440 "/etc/sudoers.d/${STUDENT_USER}"

# --- Chave pública SSH gerada por scripts/build-box.sh (par fica em
# output/, nunca commitado, ver .gitignore). Sem usuário "vagrant" nem a
# chave insegura padrão neste box, isto é o único jeito de o 1o
# "vagrant up" conseguir autenticar -- ver config.ssh.* no Vagrantfile.
install -d -m 0700 -o "${STUDENT_USER}" -g "${STUDENT_USER}" "/home/${STUDENT_USER}/.ssh"
echo "${STUDENT_SSH_PUBKEY}" > "/home/${STUDENT_USER}/.ssh/authorized_keys"
chmod 0600 "/home/${STUDENT_USER}/.ssh/authorized_keys"
chown "${STUDENT_USER}:${STUDENT_USER}" "/home/${STUDENT_USER}/.ssh/authorized_keys"

systemctl enable sshd firewalld chronyd NetworkManager

# --- Bug conhecido (ver docs/troubleshooting.md): clonar uma VM sem
# regenerar /etc/machine-id pode deixar o arquivo com contexto SELinux
# unlabeled_t apos o clone, derrubando journald -> dbus -> NetworkManager em
# cascata sem nenhum AVC visivel em ausearch (so aparece em dmesg). Zerar
# aqui forca a regeneracao correta no primeiro boot de cada clone.
truncate -s 0 /etc/machine-id

%end
