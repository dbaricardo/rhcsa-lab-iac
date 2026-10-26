#!/bin/bash
# Item 2: prepara ens19 (NIC dedicada) sem tocar em ens18/.20.
set -euo pipefail
source /usr/local/lib/lab-network-reset.sh
reset_examsim_network
echo "OK: item 2 preparado: hostname original e ens19 sem IP, com perfil-base inativo. Configure 192.168.56.91/24, gateway 192.168.56.1 e DNS."
