#!/bin/bash
# Solução de referência para networking-nmcli-01 (host: servera). Idempotente.
# Nunca ativa o perfil (nmcli connection up) -- o exercício pede só a
# configuração, para não arriscar a sessão SSH de gerenciamento atual.
set -euo pipefail

PROFILE="perfil-backup"

nmcli -g NAME connection show | grep -qx "$PROFILE" \
  || nmcli connection add type ethernet ifname eth1 con-name "$PROFILE"

nmcli connection modify "$PROFILE" \
  ipv4.method manual \
  ipv4.addresses 192.168.100.50/24 \
  ipv4.gateway 192.168.100.1 \
  ipv4.dns 192.168.100.1

echo "networking-nmcli-01: solução aplicada em $(hostname -s) (perfil '$PROFILE' criado/atualizado, NÃO ativado)."
