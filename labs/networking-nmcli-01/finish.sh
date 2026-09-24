#!/bin/bash
# Ação inversa explícita, nunca reinvoca start.sh. Só remove o perfil novo
# criado pelo estudante -- nunca toca na conexão real de gerenciamento/SSH.
set -uo pipefail

nmcli connection delete perfil-backup >/dev/null 2>&1 || true

echo "Ambiente de 'networking-nmcli-01' limpo em $(hostname -s)."
exit 0
