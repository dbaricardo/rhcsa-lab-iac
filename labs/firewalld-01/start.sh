#!/bin/bash
# Idempotente: não cria nada, só confirma que o host está pronto.
set -euo pipefail
echo "Ambiente pronto para 'firewalld-01' em $(hostname -s)."
echo "Crie o serviço 'coletor-noturno' (porta 9090/tcp) e libere a porta 9191/tcp, ambos permanentes na zona padrão."
echo "Depois rode: lab grade firewalld-01"
