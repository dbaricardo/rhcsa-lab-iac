#!/bin/bash
# Não-destrutivo: as únicas verificações "ativas" são um GET local via curl
# (o próprio propósito do serviço, sem alterar estado) e leituras de estado.
set -uo pipefail

pass=true

if [ "$(getenforce 2>/dev/null)" = "Enforcing" ]; then
  echo "OK: SELinux está enforcing"
else
  echo "FALHOU: SELinux não está enforcing (getenforce: $(getenforce 2>/dev/null || echo desconhecido))"
  pass=false
fi

if [ -f /srv/portal-noturno/index.html ] && grep -qx "Portal Noturno OK" /srv/portal-noturno/index.html; then
  echo "OK: /srv/portal-noturno/index.html existe com o conteúdo esperado"
else
  echo "FALHOU: /srv/portal-noturno/index.html não existe ou não tem o conteúdo esperado"
  pass=false
fi

ctx="$(stat -c '%C' /srv/portal-noturno 2>/dev/null | cut -d: -f3)"
if [ "$ctx" = "httpd_sys_content_t" ]; then
  echo "OK: /srv/portal-noturno tem o contexto SELinux httpd_sys_content_t"
else
  echo "FALHOU: /srv/portal-noturno não tem o contexto httpd_sys_content_t (atual: ${ctx:-desconhecido})"
  pass=false
fi

if semanage fcontext -C -l 2>/dev/null | grep -q '/srv/portal-noturno'; then
  echo "OK: regra fcontext persistente registrada para /srv/portal-noturno"
else
  echo "FALHOU: nenhuma regra fcontext persistente encontrada para /srv/portal-noturno (semanage fcontext -a, não só chcon)"
  pass=false
fi

if semanage port -C -l 2>/dev/null | awk '$1=="http_port_t"' | grep -qw '8585'; then
  echo "OK: porta 8585/tcp registrada como http_port_t no SELinux"
else
  echo "FALHOU: porta 8585/tcp não está registrada como http_port_t (semanage port -a -t http_port_t -p tcp 8585)"
  pass=false
fi

if getsebool httpd_can_network_connect 2>/dev/null | grep -q ' on$'; then
  echo "OK: boolean httpd_can_network_connect está ativo"
else
  echo "FALHOU: boolean httpd_can_network_connect não está ativo"
  pass=false
fi

if systemctl is-enabled --quiet httpd 2>/dev/null; then
  echo "OK: httpd está habilitado para o boot"
else
  echo "FALHOU: httpd não está habilitado (systemctl enable httpd)"
  pass=false
fi

if systemctl is-active --quiet httpd 2>/dev/null; then
  echo "OK: httpd está ativo"
else
  echo "FALHOU: httpd não está ativo (systemctl start httpd)"
  pass=false
fi

response="$(curl -s --max-time 5 http://127.0.0.1:8585/ 2>/dev/null || true)"
if [ "$response" = "Portal Noturno OK" ]; then
  echo "OK: http://127.0.0.1:8585/ responde com o conteúdo de portal-noturno"
else
  echo "FALHOU: http://127.0.0.1:8585/ não respondeu com o conteúdo esperado (verifique Listen/DocumentRoot/SELinux)"
  pass=false
fi

if $pass; then
  echo "RESULTADO: PASSOU"
else
  echo "RESULTADO: FALHOU"
fi
exit 0
