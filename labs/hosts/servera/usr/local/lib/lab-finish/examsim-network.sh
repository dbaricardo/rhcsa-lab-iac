#!/bin/bash
# Item 2: remove integralmente o trabalho do aluno em ens19.
set -euo pipefail
source /usr/local/lib/lab-network-reset.sh
reset_examsim_network
echo "OK: item 2 limpo: hostname original, perfis anteriores removidos por UUID e ens19 sem IP."
