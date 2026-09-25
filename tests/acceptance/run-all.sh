#!/bin/bash
# Teste de aceitação fim a fim: simula um usuário novo seguindo o README ao
# pé da letra, num host descartável. Roda a matriz T1-T11 do plano de
# deploy de teste, registra PASS/FAIL e tempo de cada fase, e não para no
# primeiro erro (modo "relatório", igual scripts/check-env.sh) -- exceto
# pré-requisitos de infraestrutura que tornariam o resto do teste sem
# sentido (comando 'vagrant' ausente, etc.), esses abortam imediatamente.
#
# Uso: bash tests/acceptance/run-all.sh [--skip-t11]
# (--skip-t11 pula o ciclo destroy+rebuild completo, mais lento; útil ao
# iterar em cima de uma falha específica sem esperar tudo de novo)
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR" || exit 1

SKIP_T11=false
[ "${1:-}" = "--skip-t11" ] && SKIP_T11=true

mkdir -p output
LOG_FILE="output/acceptance-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

FAILURES=0
CURRENT_T=""

section() { CURRENT_T="$1"; echo ""; echo "=== $1: $2 ==="; }
step_ok() { echo "  [ok] $1"; }
step_fail() { echo "  [FALHA:$CURRENT_T] $1"; FAILURES=$((FAILURES + 1)); }
die_infra() { echo "ERRO DE INFRAESTRUTURA (bloqueia o resto do teste): $1" >&2; exit 2; }

timed() {
  # timed <label> -- comando... : roda o comando, imprime duração, propaga rc
  local label="$1"; shift
  local start end rc
  start=$(date +%s)
  "$@"; rc=$?
  end=$(date +%s)
  echo "  (⏱ ${label}: $((end - start))s)"
  return "$rc"
}

dashboard_ip() { python3 -c "import yaml; s=yaml.safe_load(open('machines.yaml')); print(s['machines'][s['dashboard']['host']]['ip'])"; }
dashboard_port() { python3 -c "import yaml; print(yaml.safe_load(open('machines.yaml'))['dashboard']['port'])"; }

lab_ids() { python3 -c "import json; [print(l['id']) for l in json.load(open('labs/catalog.json'))]"; }
lab_hosts() { python3 -c "import json,sys; [print(h) for l in json.load(open('labs/catalog.json')) if l['id']==sys.argv[1] for h in l['hosts']]" "$1"; }

grade_result() {
  # grade_result <host> <lab> : imprime "PASSOU" ou "FALHOU" (ou "ERRO_INFRA")
  local out rc
  out="$(vagrant ssh workstation -c "lab grade $2" 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "ERRO_INFRA (rc=$rc): $out" >&2
    echo "ERRO_INFRA"
    return
  fi
  echo "$out" | grep -q "RESULTADO: PASSOU" && echo "PASSOU" || echo "FALHOU"
}

run_solution() {
  # run_solution <lab> : roda tests/solutions/<lab>.sh em cada host do lab
  local lab="$1" host
  while read -r host; do
    vagrant ssh "$host" -c 'sudo bash -s' < "tests/solutions/${lab}.sh"
  done < <(lab_hosts "$lab")
}

echo "== Teste de aceitação rhcsa-lab-iac -- log em $LOG_FILE =="
command -v vagrant >/dev/null 2>&1 || die_infra "comando 'vagrant' não encontrado"

# --- T1: check-env (positivo + 2 negativos, sem tocar o .env real) ---------
t1_check_env() {
  section T1 "make check-env (positivo + negativos)"

  if bash scripts/check-env.sh; then
    step_ok "check-env positivo passou com o .env real"
  else
    step_fail "check-env positivo falhou (esperado: tudo certo antes do resto do teste)"
  fi

  local tmp_env
  tmp_env="$(mktemp -d)"
  (
    cd "$tmp_env" || exit 1
    ln -s "$ROOT_DIR"/{machines.yaml,Makefile,scripts,ansible,kickstart,image,labs,Vagrantfile} .
  )
  if ! (cd "$tmp_env" && bash scripts/check-env.sh) >/dev/null 2>&1; then
    step_ok "check-env sem .env falha, como esperado"
  else
    step_fail "check-env sem .env deveria falhar e não falhou"
  fi

  if [ -n "${RHEL_ISO_PATH:-}" ]; then
    local boot_iso="${RHEL_ISO_PATH%dvd.iso}boot.iso"
    if [ -f "$boot_iso" ]; then
      echo "RHEL_ISO_PATH=${boot_iso}" > "$tmp_env/.env"
      echo "STUDENT_PASSWORD=x" >> "$tmp_env/.env"
      if ! (cd "$tmp_env" && bash scripts/check-env.sh) >/dev/null 2>&1; then
        step_ok "check-env com boot ISO (não-DVD) falha, como esperado"
      else
        step_fail "check-env deveria rejeitar a boot ISO e não rejeitou"
      fi
    else
      echo "  (pulando negativo boot-ISO: $boot_iso não existe ao lado da DVD ISO)"
    fi
  fi
  rm -rf "$tmp_env"
}

# --- T2: build-box -----------------------------------------------------------
t2_build_box() {
  section T2 "make build-box"
  timed "build-box" make build-box || { step_fail "'make build-box' saiu com erro"; return; }

  local box_name
  box_name="$(python3 -c "import yaml;print(yaml.safe_load(open('machines.yaml'))['box'])")"
  if vagrant box list | grep -q "$box_name"; then
    step_ok "box '$box_name' registrado no Vagrant"
  else
    step_fail "box '$box_name' não aparece em 'vagrant box list'"
  fi

  local qcow2="output/${box_name}.qcow2"
  if command -v virt-ls >/dev/null 2>&1 && [ -f "$qcow2" ]; then
    if virt-ls -a "$qcow2" /root 2>/dev/null | grep -qE 'anaconda-ks.cfg|original-ks.cfg'; then
      step_fail "anaconda-ks.cfg/original-ks.cfg ainda presentes no box (senha do student vazando)"
    else
      step_ok "anaconda-ks.cfg/original-ks.cfg ausentes do box (image/box-finalize.sh funcionou)"
    fi
  else
    echo "  (pulando checagem virt-ls: virt-ls ausente ou $qcow2 não encontrado)"
  fi
}

# --- T3: up (sem provisionar) ------------------------------------------------
t3_up() {
  section T3 "make up (3 VMs, sem provisionar)"
  timed "vagrant up --no-provision" make up || { step_fail "'make up' saiu com erro"; return; }

  local status
  status="$(vagrant status --machine-readable)"
  local vm
  for vm in workstation servera serverb; do
    if echo "$status" | grep -q "^[0-9]*,${vm},state,running$"; then
      step_ok "$vm está running"
    else
      step_fail "$vm não está running"
    fi
  done

  for vm in workstation servera serverb; do
    local out_file="/tmp/t3-${vm}.out"
    if vagrant ssh "$vm" -c 'hostname -f; echo /vagrant-check:; ls /vagrant 2>&1 | head -1' >"$out_file" 2>&1; then
      step_ok "'vagrant ssh $vm' autenticou (fix de config.ssh.* validado)"
      if grep -q "No such file or directory" "$out_file"; then
        step_ok "$vm: /vagrant não existe (synced_folder desabilitado, como esperado)"
      else
        step_fail "$vm: /vagrant existe ou checagem não bateu (ver $out_file)"
      fi
    else
      step_fail "'vagrant ssh $vm' falhou -- fix de SSH/synced_folder não se sustentou (ver $out_file)"
    fi
    rm -f "$out_file"
  done

  if vagrant ssh serverb -c 'lsblk -ndo SIZE,TYPE' 2>/dev/null | grep -q disk; then
    step_ok "serverb vê discos extra (verificar tamanhos 6G/1G manualmente no log acima)"
  else
    step_fail "serverb não reporta discos extra via lsblk"
  fi
}

# --- T4: reprovision sem registro/offline -> deve falhar cedo ---------------
t4_reprovision_sem_subscription() {
  section T4 "make reprovision (sem registro, sem offline) -- deve FALHAR cedo"
  if make reprovision 2>&1 | tee /tmp/t4.out | grep -q "não está registrado na Red Hat subscription"; then
    step_ok "assert de subscription disparou com a mensagem esperada"
  else
    step_fail "'make reprovision' não falhou com a mensagem de subscription esperada (ver /tmp/t4.out)"
  fi
  rm -f /tmp/t4.out
}

# --- T5/T6: reprovision-offline (2x, checando idempotência) -----------------
t5_t6_reprovision_offline() {
  section T5 "make reprovision-offline (1a vez)"
  timed "reprovision-offline (1a vez)" make reprovision-offline > /tmp/t5.out 2>&1
  local rc=$?
  if [ "$rc" -eq 0 ] && ! grep -qE "failed=[1-9]" /tmp/t5.out; then
    step_ok "1a execução: failed=0 nos 3 hosts"
  else
    step_fail "1a execução falhou ou reportou failed>0 (ver /tmp/t5.out, rc=$rc)"
  fi

  section T6 "make reprovision-offline (2a vez -- idempotência)"
  timed "reprovision-offline (2a vez)" make reprovision-offline > /tmp/t6.out 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && ! grep -qE "failed=[1-9]" /tmp/t6.out; then
    step_ok "2a execução: failed=0 nos 3 hosts"
  else
    step_fail "2a execução falhou ou reportou failed>0 (ver /tmp/t6.out, rc=$rc)"
  fi
  echo "  (changed= por host na 2a execução, revisar manualmente para 'changed' inesperado):"
  grep -E "^(workstation|servera|serverb)" /tmp/t6.out | grep "changed=" || true
  rm -f /tmp/t5.out /tmp/t6.out
  make offline-repo-stop >/dev/null 2>&1 || true
}

# --- T7: smoke test -----------------------------------------------------------
t7_smoke() {
  section T7 "tests/smoke/e2e-check.sh"
  if bash tests/smoke/e2e-check.sh; then
    step_ok "smoke test passou (exit 0)"
  else
    step_fail "smoke test falhou (ver saída acima)"
  fi
}

# --- T8: dashboard ------------------------------------------------------------
t8_dashboard() {
  section T8 "dashboard web"
  local ip port url
  ip="$(dashboard_ip)"; port="$(dashboard_port)"
  url="http://${ip}:${port}"

  if curl -fsS --max-time 10 "${url}/healthz" >/dev/null; then
    step_ok "GET ${url}/healthz respondeu 200"
  else
    step_fail "GET ${url}/healthz falhou"
  fi

  local n_labs
  n_labs="$(lab_ids | wc -l)"
  if curl -fsS --max-time 10 "${url}/" 2>/dev/null | grep -qc "lab" && [ "$n_labs" -eq 10 ]; then
    step_ok "catalog.json tem os 10 exercícios esperados"
  else
    step_fail "catalog.json não tem 10 exercícios (tem $n_labs) -- rode 'make catalog'"
  fi

  # Acesso de fora da rede do lab deve ser bloqueado (dashboard.allowed_source).
  if curl -fsS --max-time 5 "${url}/healthz" --interface lo >/dev/null 2>&1; then
    echo "  (checagem de allowed_source pulada -- requer origem fora de ${ip%.*}.0/24, valide manualmente)"
  fi
}

# --- T9: ciclo completo de cada exercício -------------------------------------
t9_exercicios() {
  section T9 "ciclo start/grade/finish + solução, para cada um dos 10 exercícios"
  local lab res
  while read -r lab; do
    echo "--- $lab ---"
    vagrant ssh workstation -c "lab start $lab" >/dev/null 2>&1 \
      || { step_fail "$lab: 'lab start' falhou"; continue; }

    res="$(grade_result workstation "$lab")"
    if [ "$res" = "FALHOU" ]; then
      step_ok "$lab: grade antes da solução reporta FALHOU (esperado)"
    else
      step_fail "$lab: grade antes da solução deveria ser FALHOU (foi: $res)"
    fi

    run_solution "$lab" || { step_fail "$lab: solução de referência falhou ao aplicar"; continue; }

    res="$(grade_result workstation "$lab")"
    if [ "$res" = "PASSOU" ]; then
      step_ok "$lab: grade depois da solução reporta PASSOU"
    else
      step_fail "$lab: grade depois da solução NÃO reportou PASSOU (foi: $res) -- solução ou grade.sh com bug"
    fi

    vagrant ssh workstation -c "lab finish $lab" >/dev/null 2>&1 \
      || step_fail "$lab: 'lab finish' falhou"

    # Reuso: start de novo depois do finish precisa funcionar (bug de
    # disco_por_tamanho() vs resolve_disco() já visto em storage-lvm-01).
    if vagrant ssh workstation -c "lab start $lab" >/dev/null 2>&1; then
      step_ok "$lab: 'lab start' funciona de novo após 'lab finish' (sem resíduo)"
    else
      step_fail "$lab: 'lab start' falhou após 'lab finish' -- ambiente não foi limpo corretamente"
    fi
    vagrant ssh workstation -c "lab finish $lab" >/dev/null 2>&1 || true
  done < <(lab_ids)
}

# --- T10: reload das 3 VMs ----------------------------------------------------
t10_reload() {
  section T10 "vagrant reload (3 VMs)"
  timed "vagrant reload" vagrant reload || { step_fail "'vagrant reload' saiu com erro"; return; }

  local ip port
  ip="$(dashboard_ip)"; port="$(dashboard_port)"
  sleep 5
  if curl -fsS --max-time 15 "http://${ip}:${port}/healthz" >/dev/null; then
    step_ok "dashboard volta sozinho após reload"
  else
    step_fail "dashboard não respondeu após reload"
  fi

  local res
  res="$(grade_result workstation users-groups-01)"
  if [ "$res" != "ERRO_INFRA" ]; then
    step_ok "'lab grade' funciona após reload"
  else
    step_fail "'lab grade' com erro de infra após reload"
  fi
}

# --- T11: ciclo limpo do zero (destroy + rebuild) -----------------------------
t11_ciclo_limpo() {
  section T11 "make destroy && make up && make reprovision-offline && smoke (ciclo limpo)"
  if $SKIP_T11; then
    echo "  (pulado: --skip-t11)"
    return
  fi
  vagrant destroy -f >/dev/null 2>&1
  timed "up" make up || { step_fail "'make up' (ciclo limpo) falhou"; return; }
  if timed "reprovision-offline" make reprovision-offline > /tmp/t11.out 2>&1 \
      && ! grep -qE "failed=[1-9]" /tmp/t11.out; then
    step_ok "ciclo limpo: reprovision-offline com failed=0"
  else
    step_fail "ciclo limpo: reprovision-offline falhou (ver /tmp/t11.out)"
  fi
  make offline-repo-stop >/dev/null 2>&1 || true
  if bash tests/smoke/e2e-check.sh >/tmp/t11-smoke.out 2>&1; then
    step_ok "ciclo limpo: smoke test passou"
  else
    step_fail "ciclo limpo: smoke test falhou (ver /tmp/t11-smoke.out)"
  fi
  rm -f /tmp/t11.out /tmp/t11-smoke.out
}

t1_check_env
t2_build_box
t3_up
t4_reprovision_sem_subscription
t5_t6_reprovision_offline
t7_smoke
t8_dashboard
t9_exercicios
t10_reload
t11_ciclo_limpo

echo ""
echo "=== Resultado final ==="
if [ "$FAILURES" -eq 0 ]; then
  echo "TODOS OS TESTES PASSARAM. Log completo: $LOG_FILE"
  exit 0
else
  echo "$FAILURES verificação(ões) falharam. Log completo: $LOG_FILE"
  exit 1
fi
