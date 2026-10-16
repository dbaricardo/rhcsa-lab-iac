#!/bin/bash
# Smoke test fim a fim: roda depois de "make deploy" para confirmar que a
# infraestrutura está de pé e o ciclo lab start/grade/finish funciona.
#
# NÃO valida se o exercício foi resolvido corretamente -- só confirma que os
# três comandos executam sem falha de INFRAESTRUTURA (SSH, dispatcher,
# dashboard). Código de saída 2 == falha real de conectividade/infra,
# refletindo o mesmo contrato do dispatcher `lab` (ver docs/explanation/arquitetura.md).
#
# Seguro de rodar múltiplas vezes: o start do examsim-grupos é idempotente
# (contrato de docs/reference/contrato-exercicios.md) e finish.sh sempre roda no
# final, deixando o exercício limpo.
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR" || exit 1

EXAMPLE_LAB="examsim-grupos"
FAILURES=0

# Diretório temporário isolado por execução -- evita colidir com uma outra
# execução concorrente (ou anterior, interrompida) e não deixa lixo em /tmp.
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/rhcsa-lab-smoke.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

info() { echo "==> $1"; }
ok()   { echo "  [ok]    $1"; }
fail() { echo "  [FALHA] $1" >&2; FAILURES=$((FAILURES + 1)); }

die_infra() {
  echo "ERRO DE INFRAESTRUTURA: $1" >&2
  exit 2
}

# --- 1. virsh: confirma as 3 VMs "running" ---------------------------------
info "estado das VMs (virsh)"

command -v virsh >/dev/null 2>&1 || die_infra "comando 'virsh' não encontrado no PATH"

for vm in workstation servera serverb; do
  if [ "$(virsh -c qemu:///system domstate "rhcsa-lab-${vm}" 2>/dev/null)" = "running" ]; then
    ok "$vm está running"
  else
    fail "$vm não está running"
  fi
done

if [ "$FAILURES" -gt 0 ]; then
  die_infra "uma ou mais VMs não estão no estado 'running' -- rode 'make deploy' primeiro"
fi

# --- 2. dashboard /healthz --------------------------------------------------
info "dashboard /healthz"

DASHBOARD_IP="$(python3 -c "
import yaml
spec = yaml.safe_load(open('machines.yaml'))
host = spec['dashboard']['host']
print(spec['machines'][host]['ip'])
")" || die_infra "não foi possível ler o IP do dashboard em machines.yaml"

DASHBOARD_PORT="$(python3 -c "
import yaml
print(yaml.safe_load(open('machines.yaml'))['dashboard']['port'])
")" || die_infra "não foi possível ler a porta do dashboard em machines.yaml"

HEALTHZ_URL="http://${DASHBOARD_IP}:${DASHBOARD_PORT}/healthz"

if curl -fsS --max-time 10 "$HEALTHZ_URL" >/dev/null; then
  ok "GET $HEALTHZ_URL respondeu 2xx"
else
  die_infra "GET $HEALTHZ_URL falhou (dashboard fora do ar ou firewalld bloqueando a origem configurada em machines.yaml -> dashboard.allowed_source)"
fi

# --- 3. lab list via SSH na workstation -------------------------------------
info "workstation: lab list"

LIST_OUT="$WORK_DIR/list.out"
if ! bash scripts/lab-ssh.sh workstation 'lab list' >"$LIST_OUT" 2>&1; then
  cat "$LIST_OUT" >&2
  die_infra "'lab list' falhou dentro da workstation"
fi
ok "'lab list' executou com sucesso"

if ! grep -q "$EXAMPLE_LAB" "$LIST_OUT"; then
  die_infra "'lab list' não listou o exercício de exemplo '$EXAMPLE_LAB' -- catalog.json desatualizado? rode 'make catalog'"
fi
ok "'$EXAMPLE_LAB' aparece no catálogo"

# --- 4. ciclo start/grade/finish do exercício de exemplo --------------------
# Só confirma que o ciclo completo roda sem erro de infraestrutura -- não
# resolve o exercício de verdade, então "lab grade" deve reportar FALHOU (é
# esperado) e ainda assim sair com código 0, por contrato do grade.sh (ver
# docs/reference/contrato-exercicios.md). Um código de saída diferente de 0 aqui
# indica falha de infra (ex.: SSH para o host do exercício não funcionou),
# não o resultado do exercício em si.
for action in start grade finish; do
  info "workstation: lab $action $EXAMPLE_LAB"
  ACTION_OUT="$WORK_DIR/${action}.out"
  if bash scripts/lab-ssh.sh workstation "lab $action $EXAMPLE_LAB" >"$ACTION_OUT" 2>&1; then
    ok "'lab $action $EXAMPLE_LAB' executou com sucesso (código 0)"
  else
    RC=$?
    cat "$ACTION_OUT" >&2
    die_infra "'lab $action $EXAMPLE_LAB' saiu com código $RC (esperado 0 -- ver saída acima)"
  fi
done

echo ""
echo "Smoke test concluído: infraestrutura e ciclo lab start/grade/finish OK."
exit 0
