#!/bin/bash
# Ação inversa explícita, nunca reinvoca start.sh.
set -uo pipefail

systemctl stop heartbeat.timer >/dev/null 2>&1 || true
systemctl disable heartbeat.timer >/dev/null 2>&1 || true
systemctl stop heartbeat.service >/dev/null 2>&1 || true

rm -f /etc/systemd/system/heartbeat.timer
rm -f /etc/systemd/system/heartbeat.service
systemctl daemon-reload >/dev/null 2>&1 || true
rm -f /var/log/heartbeat.log

echo "Ambiente de 'systemd-services-01' limpo em $(hostname -s)."
exit 0
