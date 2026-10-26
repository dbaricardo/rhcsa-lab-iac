#!/bin/bash
set -u
unit_svc=$(systemctl list-units --all --type=service --no-legend 2>/dev/null | awk '{print $1}' | grep -i 'examsim15\|logger' | head -1)
unit_timer=$(systemctl list-units --all --type=timer --no-legend 2>/dev/null | awk '{print $1}' | grep -i 'examsim15\|logger' | head -1)
[ -n "$unit_timer" ] && systemctl disable --now "$unit_timer" 2>/dev/null
[ -n "$unit_svc" ] && systemctl disable --now "$unit_svc" 2>/dev/null
for f in /etc/systemd/system/*examsim15*.service /etc/systemd/system/*examsim15*.timer \
         /etc/systemd/system/*logger*.service /etc/systemd/system/*logger*.timer; do
    [ -e "$f" ] || continue
    systemctl disable --now "${f##*/}" &>/dev/null
    rm -f "$f"
done
systemctl daemon-reload 2>/dev/null
state=/var/lib/rhcsa-lab/examsim15-created-users
if [ -f "$state" ]; then
    while read -r u; do
        id "$u" &>/dev/null && userdel -r "$u" 2>/dev/null || true
    done < "$state"
    rm -f "$state"
fi
rpm -q logger &>/dev/null && dnf -y remove logger &>/dev/null
rm -f /etc/yum.repos.d/timer.repo /var/tmp/ex200 /root/lookup_directory/ex200 /var/tmp/fstab
echo "OK: item 15 limpo."
