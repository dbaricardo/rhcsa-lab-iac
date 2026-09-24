#!/bin/bash
# Idempotente: não cria nada, só confirma que o host está pronto para o
# estudante criar o grupo e os usuários solicitados no enunciado.
set -euo pipefail
echo "Ambiente pronto para 'users-groups-01' em $(hostname -s)."
echo "Crie o grupo e os usuários solicitados, depois rode: lab grade users-groups-01"
