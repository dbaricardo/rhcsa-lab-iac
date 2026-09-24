#!/bin/bash
# Idempotente: não cria nada, só confirma que o host está pronto.
set -euo pipefail
echo "Ambiente pronto para 'networking-nmcli-01' em $(hostname -s)."
echo "Crie o perfil de conexão 'perfil-backup' (NÃO toque na conexão real de gerenciamento/SSH)."
echo "Depois rode: lab grade networking-nmcli-01"
