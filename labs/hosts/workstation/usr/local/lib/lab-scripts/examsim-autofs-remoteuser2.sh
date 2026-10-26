#!/bin/bash
# Item 12, servidor: workstation exporta /ourhome/remoteuser2 para servera.
set -u
state=/var/lib/rhcsa-lab/examsim12-workstation-state
mkdir -p "$(dirname "$state")"
if [ ! -f "$state" ]; then
    {
        if systemctl is-enabled --quiet nfs-server 2>/dev/null; then echo nfs-enabled; else echo nfs-disabled; fi
        if systemctl is-active --quiet nfs-server 2>/dev/null; then echo nfs-active; else echo nfs-inactive; fi
        for svc in nfs rpc-bind mountd; do
            if firewall-cmd --permanent --query-service="$svc" &>/dev/null; then echo "firewall-$svc"; fi
        done
    } > "$state"
fi
dnf install -y nfs-utils &>/dev/null
id remoteuser2 &>/dev/null && userdel -r remoteuser2 2>/dev/null
useradd -u 2212 -M -d /ourhome/remoteuser2 remoteuser2
mkdir -p /ourhome/remoteuser2
chown remoteuser2:remoteuser2 /ourhome/remoteuser2
sed -i '\#/ourhome/remoteuser2#d' /etc/exports
echo '/ourhome/remoteuser2 192.168.56.20(rw,sync)' >> /etc/exports
exportfs -ra
systemctl enable --now nfs-server &>/dev/null
firewall-cmd --add-service=nfs --permanent &>/dev/null
firewall-cmd --add-service=rpc-bind --permanent &>/dev/null
firewall-cmd --add-service=mountd --permanent &>/dev/null
firewall-cmd --reload &>/dev/null
echo "OK: workstation exportando /ourhome/remoteuser2 para servera (UID 2212) -- item 12."
