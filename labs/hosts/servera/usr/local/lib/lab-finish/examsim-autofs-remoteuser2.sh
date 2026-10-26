#!/bin/bash
set -u
umount -l /home/remoteuser2 2>/dev/null
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
state=/var/lib/rhcsa-lab/examsim12-servera-state
if [ -f "$state" ]; then
    enabled=$(sed -n '1p' "$state")
    active=$(sed -n '2p' "$state")
    if [ "$enabled" = enabled ]; then systemctl enable autofs &>/dev/null || true; else systemctl disable autofs &>/dev/null || true; fi
    if [ "$active" = active ]; then systemctl start autofs &>/dev/null || true; else systemctl stop autofs &>/dev/null || true; fi
    rm -f "$state"
else
    systemctl restart autofs 2>/dev/null || true
fi
echo "OK: item 12 limpo em servera."
