#!/bin/bash
# Ação inversa explícita, nunca reinvoca start.sh. Remove só o que este
# exercício adicionou (serviço + porta) da zona padrão, sem tocar em nenhum
# outro serviço/porta que já estivesse configurado na zona.
set -uo pipefail

zone="$(firewall-cmd --get-default-zone 2>/dev/null || echo public)"

firewall-cmd --permanent --zone="$zone" --remove-service=coletor-noturno >/dev/null 2>&1 || true
firewall-cmd --permanent --zone="$zone" --remove-port=9191/tcp >/dev/null 2>&1 || true
firewall-cmd --permanent --delete-service=coletor-noturno >/dev/null 2>&1 || true
firewall-cmd --reload >/dev/null 2>&1 || true

echo "Ambiente de 'firewalld-01' limpo em $(hostname -s)."
exit 0
