#!/bin/bash
# Idempotente: não cria nada, só confirma que o host está pronto.
set -euo pipefail
echo "Ambiente pronto para 'systemd-services-01' em $(hostname -s)."
echo "Crie heartbeat.service + heartbeat.timer em /etc/systemd/system/, habilite e inicie o timer."
echo "Depois rode: lab grade systemd-services-01"
