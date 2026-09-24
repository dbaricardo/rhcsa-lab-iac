#!/bin/bash
# Sysprep leve do box golden, rodado OFFLINE contra o disco via
# `virt-customize -a <qcow2> --run image/box-finalize.sh` (libguestfs — sem
# rede, sem boot real). Chamado por scripts/build-box.sh logo após o
# kickstart terminar (VM desligada).
set -euo pipefail

# Defesa em profundidade extra para o bug de SELinux unlabeled_t em VMs
# clonadas (ver docs/troubleshooting.md) — o kickstart já zera
# /etc/machine-id, isto garante que TODO /etc está com contexto correto
# antes mesmo do primeiro boot de qualquer clone.
restorecon -Rv /etc || true

# Remove chaves de host SSH: cada clone (workstation/servera/serverb) deve
# gerar as suas próprias no primeiro boot (cloud-init-like via
# sshd-keygen.target, presente por padrão no RHEL10).
rm -f /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub

# Limpeza de logs/histórico de build — não deve vazar nada do processo de
# instalação para as VMs finais de estudo.
rm -rf /var/log/anaconda /root/ks-post.log
: > /var/log/messages 2>/dev/null || true
rm -f /root/.bash_history /home/*/.bash_history 2>/dev/null || true

# Garantia extra (redundante com o kickstart, sem custo): machine-id vazio.
truncate -s 0 /etc/machine-id
