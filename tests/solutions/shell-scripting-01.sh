#!/bin/bash
# Solução de referência para shell-scripting-01 (host: workstation).
# Idempotente: sempre recria o script com o mesmo conteúdo.
set -euo pipefail

STUDENT_HOME="/home/student"
mkdir -p "${STUDENT_HOME}/scripts"

cat > "${STUDENT_HOME}/scripts/relatorio-nomes.sh" <<'SCRIPT'
#!/bin/bash
set -uo pipefail

if [ $# -ne 1 ]; then
  echo "Uso: $0 <arquivo>" >&2
  exit 1
fi

arquivo="$1"

if [ ! -f "$arquivo" ]; then
  echo "Erro: arquivo '${arquivo}' não existe." >&2
  exit 1
fi

total=0
while IFS= read -r nome; do
  [ -n "$nome" ] || continue
  echo "Processando: ${nome}"
  total=$((total + 1))
done < "$arquivo"

echo "Total: ${total}"
SCRIPT

chmod 0755 "${STUDENT_HOME}/scripts/relatorio-nomes.sh"
chown -R student:student "${STUDENT_HOME}/scripts" 2>/dev/null || true

echo "shell-scripting-01: solução aplicada em $(hostname -s)."
