#!/bin/bash
# Item 9: configurar chrony como cliente NTP de classroom.example.com.
set -u
if [ ! -e /etc/chrony.conf.examsim9-orig ]; then
    cp -p /etc/chrony.conf /etc/chrony.conf.examsim9-orig 2>/dev/null
fi
sed -i '/^server \\|^pool /d' /etc/chrony.conf
systemctl restart chronyd
echo "OK: /etc/chrony.conf sem fontes NTP -- item 9 pronto (aponte pra classroom.example.com)."
