#!/bin/bash
set -u
if [ -f /etc/chrony.conf.examsim9-orig ]; then
    mv /etc/chrony.conf.examsim9-orig /etc/chrony.conf
fi
systemctl restart chronyd 2>/dev/null
echo "OK: item 9 limpo (chrony.conf revertido)."
