#!/bin/bash
# SSH como 'student' numa VM do lab, com a chave gerada por build-image.sh e
# o IP de machines.yaml. Sem comando, abre um shell interativo.
#
# Uso: bash scripts/lab-ssh.sh <workstation|servera|serverb> [comando...]
#      bash scripts/lab-ssh.sh servera 'sudo bash -s' < script.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="${1:?uso: $0 <workstation|servera|serverb> [comando...]}"
shift

read -r IP USER_NAME < <(python3 - "$ROOT_DIR/machines.yaml" "$HOST" <<'PY'
import sys, yaml
spec = yaml.safe_load(open(sys.argv[1]))
m = spec["machines"].get(sys.argv[2])
if m is None:
    sys.exit(f"host desconhecido: {sys.argv[2]} (veja machines.yaml)")
print(m["ip"], spec["student"]["username"])
PY
)

# As VMs são recriadas a cada deploy, com chaves de host novas: guardar
# known_hosts só geraria alerta de "host key changed" no próximo ciclo.
SSH_OPTS=(-i "$ROOT_DIR/output/student_key"
  -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
  -o LogLevel=ERROR -o ConnectTimeout=10)

if [ "$#" -eq 0 ]; then
  exec ssh -t "${SSH_OPTS[@]}" "${USER_NAME}@${IP}"
fi
exec ssh "${SSH_OPTS[@]}" "${USER_NAME}@${IP}" "$@"
