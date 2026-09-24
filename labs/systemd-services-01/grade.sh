#!/bin/bash
# Executar heartbeat.service (oneshot) aqui é intencional e não-destrutivo:
# ele só faz uma coisa idempotente e sem efeito colateral de risco (grava
# mais uma linha de log), o mesmo padrão já usado em nfs-autofs-01 para
# disparar a automontagem via um 'ls'.
set -uo pipefail

pass=true

if [ -f /etc/systemd/system/heartbeat.service ]; then
  echo "OK: unit heartbeat.service existe"
else
  echo "FALHOU: unit heartbeat.service não existe em /etc/systemd/system/"
  pass=false
fi

if [ -f /etc/systemd/system/heartbeat.timer ]; then
  echo "OK: unit heartbeat.timer existe"
else
  echo "FALHOU: unit heartbeat.timer não existe em /etc/systemd/system/"
  pass=false
fi

if systemctl is-enabled --quiet heartbeat.timer 2>/dev/null; then
  echo "OK: heartbeat.timer está habilitado para o boot"
else
  echo "FALHOU: heartbeat.timer não está habilitado (systemctl enable heartbeat.timer)"
  pass=false
fi

if systemctl is-active --quiet heartbeat.timer 2>/dev/null; then
  echo "OK: heartbeat.timer está ativo"
else
  echo "FALHOU: heartbeat.timer não está ativo (systemctl start heartbeat.timer)"
  pass=false
fi

before_lines="$(wc -l < /var/log/heartbeat.log 2>/dev/null || echo 0)"
if systemctl start heartbeat.service >/dev/null 2>&1; then
  sleep 1
  after_lines="$(wc -l < /var/log/heartbeat.log 2>/dev/null || echo 0)"
  if [ -f /var/log/heartbeat.log ] && [ "$after_lines" -gt "$before_lines" ]; then
    echo "OK: heartbeat.service grava uma linha em /var/log/heartbeat.log quando executado"
  else
    echo "FALHOU: /var/log/heartbeat.log não recebeu uma nova linha após executar heartbeat.service"
    pass=false
  fi
else
  echo "FALHOU: não foi possível executar heartbeat.service (systemctl start falhou)"
  pass=false
fi

if $pass; then
  echo "RESULTADO: PASSOU"
else
  echo "RESULTADO: FALHOU"
fi
exit 0
