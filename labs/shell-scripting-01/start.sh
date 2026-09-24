#!/bin/bash
# Roda localmente na workstation (o dispatcher `lab` invoca lab-remote sem
# SSH quando o próprio alvo é este host) -- diferente dos demais exercícios
# deste catálogo, não há delegação para servera/serverb aqui. Idempotente:
# sempre recria o arquivo de teste com o mesmo conteúdo fixo, nunca
# reinventa o script que o estudante escreve.
set -euo pipefail
STUDENT_HOME="/home/student"

mkdir -p "${STUDENT_HOME}/scripts"
cat > "${STUDENT_HOME}/scripts/dados-nomes.txt" <<'EOF'
Ana
Bruno
Carla
Diego
EOF
chown -R student:student "${STUDENT_HOME}/scripts" 2>/dev/null || true

echo "Ambiente pronto para 'shell-scripting-01' em $(hostname -s)."
echo "Crie ${STUDENT_HOME}/scripts/relatorio-nomes.sh e rode: lab grade shell-scripting-01"
