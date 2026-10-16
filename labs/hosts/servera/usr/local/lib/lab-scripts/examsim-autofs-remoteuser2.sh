#!/bin/bash
# Item 12, cliente: servera automonta o home NFS de remoteuser2.
set -u
state=/var/lib/rhcsa-lab/examsim12-servera-state
mkdir -p "$(dirname "$state")"
if [ ! -f "$state" ]; then
    {
        if systemctl is-enabled --quiet autofs 2>/dev/null; then echo enabled; else echo disabled; fi
        if systemctl is-active --quiet autofs 2>/dev/null; then echo active; else echo inactive; fi
    } > "$state"
fi
dnf install -y autofs &>/dev/null
id remoteuser2 &>/dev/null && userdel -r remoteuser2 2>/dev/null
useradd -u 2212 -M -d /home/remoteuser2 remoteuser2
rm -f /etc/auto.master.d/examsim12.autofs /etc/auto.examsim12
# Mapas criados pelo aluno (qualquer nome) que citam remoteuser2, e as entradas
# do master que apontam para eles; sem isso a questao comeca resolvida.
for m in $(grep -ls remoteuser2 /etc/auto.* 2>/dev/null); do
    case "$m" in /etc/auto.master|/etc/auto.master.d) continue ;; esac
    for e in $(grep -lsF "$m" /etc/auto.master.d/*.autofs 2>/dev/null); do rm -f "$e"; done
    sed -i "\\#[[:space:]]$m\\([[:space:]]\\|\$\\)#d" /etc/auto.master
    rm -f "$m"
done
for e in $(grep -ls remoteuser2 /etc/auto.master.d/*.autofs 2>/dev/null); do rm -f "$e"; done
systemctl restart autofs 2>/dev/null
echo "OK: servera pronta para configurar autofs e remoteuser2 (UID 2212) -- item 12."
