#!/bin/bash
set -u
sed -i '\#/ourhome/remoteuser2#d' /etc/exports 2>/dev/null
exportfs -ra
id remoteuser2 &>/dev/null && userdel -r remoteuser2 2>/dev/null
rm -rf /ourhome/remoteuser2
state=/var/lib/rhcsa-lab/examsim12-workstation-state
if [ -f "$state" ]; then
    nfs_enabled=$(sed -n '1p' "$state")
    nfs_active=$(sed -n '2p' "$state")
    if [ "$nfs_enabled" = nfs-enabled ]; then systemctl enable nfs-server &>/dev/null || true; else systemctl disable nfs-server &>/dev/null || true; fi
    if [ "$nfs_active" = nfs-active ]; then systemctl start nfs-server &>/dev/null || true; else systemctl stop nfs-server &>/dev/null || true; fi
    for svc in nfs rpc-bind mountd; do
        grep -qx "firewall-$svc" "$state" || firewall-cmd --permanent --remove-service="$svc" &>/dev/null || true
    done
    firewall-cmd --reload &>/dev/null || true
    rm -f "$state"
fi
echo "OK: item 12 limpo em workstation (estado anterior restaurado)."
