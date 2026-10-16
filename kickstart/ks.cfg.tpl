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
# Autopart cobre so o disco de instalacao. Discos extra de storage/LVM sao
# anexados DEPOIS pelo Terraform/libvirt, sempre brutos (sem particionar aqui),
# para os proprios exercicios praticarem pvcreate/mkfs do zero.
autopart --type=lvm --fstype=xfs

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
tree
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

# --- Bug conhecido (ver docs/explanation/problemas-conhecidos.md): clonar uma VM sem
# regenerar /etc/machine-id pode deixar o arquivo com contexto SELinux
# unlabeled_t apos o clone, derrubando journald -> dbus -> NetworkManager em
# cascata sem nenhum AVC visivel em ausearch (so aparece em dmesg). Zerar
# aqui forca a regeneracao correta no primeiro boot de cada clone.
truncate -s 0 /etc/machine-id

%end
