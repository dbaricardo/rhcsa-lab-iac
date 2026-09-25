#!/bin/bash
# Solução de referência para firewalld-01 (host: servera). Idempotente.
set -euo pipefail

systemctl is-active --quiet firewalld || systemctl start firewalld

zone="$(firewall-cmd --get-default-zone)"

firewall-cmd --permanent --get-services | tr ' ' '\n' | grep -qx coletor-noturno \
  || firewall-cmd --permanent --new-service=coletor-noturno
firewall-cmd --permanent --service=coletor-noturno --get-ports | grep -qw '9090/tcp' \
  || firewall-cmd --permanent --service=coletor-noturno --add-port=9090/tcp

firewall-cmd --permanent --zone="$zone" --list-services | tr ' ' '\n' | grep -qx coletor-noturno \
  || firewall-cmd --permanent --zone="$zone" --add-service=coletor-noturno
firewall-cmd --permanent --zone="$zone" --list-ports | tr ' ' '\n' | grep -qx '9191/tcp' \
  || firewall-cmd --permanent --zone="$zone" --add-port=9191/tcp

firewall-cmd --reload

echo "firewalld-01: solução aplicada em $(hostname -s)."
