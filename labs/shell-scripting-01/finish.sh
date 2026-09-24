#!/bin/bash
# Ação inversa explícita do start.sh, nunca reinvoca start.sh. Só remove o
# que o exercício criou; rmdir sem -f preserva o diretório se o estudante
# tiver deixado outros arquivos nele.
set -uo pipefail
STUDENT_HOME="/home/student"

rm -f "${STUDENT_HOME}/scripts/relatorio-nomes.sh"
rm -f "${STUDENT_HOME}/scripts/dados-nomes.txt"
rmdir "${STUDENT_HOME}/scripts" >/dev/null 2>&1 || true

echo "Ambiente de 'shell-scripting-01' limpo em $(hostname -s)."
exit 0
