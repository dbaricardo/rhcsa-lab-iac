#!/bin/bash
# Teste de aceitação fim a fim: simula um usuário novo seguindo o README ao
# pé da letra, num host descartável. Roda a matriz T1-T11 do plano de
# deploy de teste, registra PASS/FAIL e tempo de cada fase, e não para no
# primeiro erro (modo "relatório", igual scripts/check-env.sh) -- exceto
# pré-requisitos de infraestrutura que tornariam o resto do teste sem
# sentido (comando 'terraform' ausente, etc.), esses abortam imediatamente.
#
# A saída completa de cada fase que falha fica em output/acceptance-tN.out
# (antes ia para /tmp e era apagada, o que obrigava a reproduzir tudo à mão).
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
rm -f output/acceptance-t*.out
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

# Exercícios avulsos (number >= 1). A prova completa e o exame dinâmico
# (number 0) têm fases próprias: T12 e T13.
lab_ids() { python3 -c "import json; [print(l['id']) for l in sorted(json.load(open('labs/catalog.json')), key=lambda l: l['number']) if l['number'] >= 1]"; }
catalog_total() { python3 -c "import json; print(len(json.load(open('labs/catalog.json'))))"; }

VMS=(workstation servera serverb)
vm_ssh() { bash scripts/lab-ssh.sh "$@"; }
domain_name() { echo "rhcsa-lab-$1"; }

# shellcheck disable=SC2317  # chamada indiretamente via timed()
wait_ssh_all() {
  # wait_ssh_all <timeout_s> : espera as 3 VMs aceitarem SSH
  local deadline=$(( $(date +%s) + $1 )) vm
  for vm in "${VMS[@]}"; do
    until vm_ssh "$vm" true >/dev/null 2>&1; do
      [ "$(date +%s)" -ge "$deadline" ] && return 1
      sleep 5
    done
  done
}

grade_result() {
  # grade_result <host> <lab> : imprime "PASSOU" ou "FALHOU" (ou "ERRO_INFRA")
  local out rc
  out="$(vm_ssh workstation "lab grade $2" 2>&1)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    echo "ERRO_INFRA (rc=$rc): $out" >&2
    echo "ERRO_INFRA"
    return
  fi
  echo "$out" | grep -q "RESULTADO: PASSOU" && echo "PASSOU" || echo "FALHOU"
}

run_solution() {
  # run_solution <lab> : aplica a solução de referência (tests/solutions/legacy.sh),
  # como root, no host da questão.
  local lab="$1" host
  host="$(bash tests/solutions/legacy.sh --host "$lab")" || return 1
  vm_ssh "$host" "sudo bash -s -- $lab" < tests/solutions/legacy.sh
}

# Seeds do exame dinâmico que, juntas, cobrem as 24 questões legadas.
DYN_SEEDS="${DYN_SEEDS:-3694 1091 47 1478 11 48 50}"

echo "== Teste de aceitação rhcsa-lab-iac -- log em $LOG_FILE =="
command -v terraform >/dev/null 2>&1 || die_infra "comando 'terraform' não encontrado"

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
    ln -s "$ROOT_DIR"/{machines.yaml,Makefile,scripts,ansible,kickstart,image,labs,terraform} .
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

# --- T2: build-image ---------------------------------------------------------
t2_build_image() {
  section T2 "make build-image"
  timed "build-image" make build-image || { step_fail "'make build-image' saiu com erro"; return; }

  local image
  image="output/$(python3 -c "import yaml;print(yaml.safe_load(open('machines.yaml'))['image'])").qcow2"
  if [ -f "$image" ] && [ ! -f "${image}.partial" ]; then
    step_ok "imagem $image gerada (sem .partial sobrando)"
  else
    step_fail "imagem $image ausente ou .partial sobrando"
  fi

  if command -v virt-ls >/dev/null 2>&1 && [ -f "$image" ]; then
    if virt-ls -a "$image" /root 2>/dev/null | grep -qE 'anaconda-ks.cfg|original-ks.cfg'; then
      step_fail "anaconda-ks.cfg/original-ks.cfg ainda presentes na imagem (senha do student vazando)"
    else
      step_ok "anaconda-ks.cfg/original-ks.cfg ausentes da imagem (image/finalize.sh funcionou)"
    fi
  else
    echo "  (pulando checagem virt-ls: virt-ls ausente ou $image não encontrada)"
  fi
}

# --- T3: infra (Terraform, sem Ansible) --------------------------------------
t3_infra() {
  section T3 "make infra (Terraform: rede + discos + 3 VMs, sem Ansible)"
  timed "terraform apply" make infra > output/acceptance-t3.out 2>&1 \
    || { step_fail "'make infra' saiu com erro (ver output/acceptance-t3.out)"; return; }

  local vm
  for vm in "${VMS[@]}"; do
    if [ "$(virsh -c qemu:///system domstate "$(domain_name "$vm")" 2>/dev/null)" = "running" ]; then
      step_ok "$vm está running"
    else
      step_fail "$vm não está running"
    fi
  done

  if timed "boot + SSH" wait_ssh_all 300; then
    step_ok "as 3 VMs aceitam SSH com output/student_key no IP de machines.yaml"
  else
    step_fail "SSH não respondeu em 300s em pelo menos uma VM (IP fixo via DHCP ou chave do kickstart?)"
    return
  fi

  local disks
  disks="$(vm_ssh serverb 'lsblk -ndo SIZE,TYPE' 2>/dev/null | awk '$2 == "disk" {print $1}' | sort | tr '\n' ' ')"
  if echo " $disks" | grep -q " 1G " && echo " $disks" | grep -q " 6G "; then
    step_ok "serverb vê os discos extra de 6G e 1G (discos: $disks)"
  else
    step_fail "serverb não mostra os discos extra de 6G e 1G (discos: ${disks:-nenhum})"
  fi

  if [ "$(terraform -chdir=terraform plan -detailed-exitcode -input=false >/dev/null 2>&1; echo $?)" = "0" ]; then
    step_ok "terraform plan logo após o apply não mostra mudanças (estado estável)"
  else
    step_fail "terraform plan mostra mudanças logo após o apply (drift/recurso instável)"
  fi
}

# --- T4: provision sem registro/offline -> deve falhar cedo -----------------
t4_provision_sem_subscription() {
  section T4 "make provision (sem RHSM_*, sem offline) -- deve FALHAR cedo"
  # RHSM_* vazias na linha de comando sobrepõem as do .env: o teste é sobre
  # o caminho "ninguém registrou", mesmo que o .env de quem roda tenha chave.
  if make provision RHSM_ORG_ID= RHSM_ACTIVATION_KEY= > output/acceptance-t4.out 2>&1; then
    step_fail "'make provision' sem subscription deveria falhar e passou (ver output/acceptance-t4.out)"
  elif grep -q "não está registrado na Red Hat subscription" output/acceptance-t4.out; then
    step_ok "assert de subscription disparou com a mensagem esperada"
  else
    step_fail "'make provision' falhou, mas não pela subscription (ver output/acceptance-t4.out)"
  fi
}

# --- T5/T6: provision-offline (2x, checando idempotência) -------------------
t5_t6_provision_offline() {
  section T5 "make provision-offline (1a vez)"
  timed "provision-offline (1a vez)" make provision-offline > output/acceptance-t5.out 2>&1
  local rc=$?
  if [ "$rc" -eq 0 ] && ! grep -qE "failed=[1-9]" output/acceptance-t5.out; then
    step_ok "1a execução: failed=0 nos 3 hosts"
  else
    step_fail "1a execução falhou ou reportou failed>0 (ver output/acceptance-t5.out, rc=$rc)"
  fi

  section T6 "make provision-offline (2a vez -- idempotência)"
  timed "provision-offline (2a vez)" make provision-offline > output/acceptance-t6.out 2>&1
  rc=$?
  if [ "$rc" -eq 0 ] && ! grep -qE "failed=[1-9]" output/acceptance-t6.out; then
    step_ok "2a execução: failed=0 nos 3 hosts"
  else
    step_fail "2a execução falhou ou reportou failed>0 (ver output/acceptance-t6.out, rc=$rc)"
  fi
  echo "  (changed= por host na 2a execução, revisar manualmente para 'changed' inesperado):"
  grep -E "^(workstation|servera|serverb) " output/acceptance-t6.out | grep "changed=" || true
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

  local n_labs n_total
  n_labs="$(lab_ids | wc -l)"; n_total="$(catalog_total)"
  if [ "$n_total" -eq 27 ] && [ "$n_labs" -eq 25 ]; then
    step_ok "catalog.json tem as 27 entradas do homelab (25 exercícios + prova completa + dinâmico)"
  else
    step_fail "catalog.json deveria ter 27 entradas / 25 exercícios (tem $n_total / $n_labs)"
  fi

  if curl -fsS --max-time 10 "${url}/api/state" | python3 -c "import json,sys; d=json.load(sys.stdin); assert len(d['tasks'])==27" 2>/dev/null; then
    step_ok "GET ${url}/api/state lista as 27 tarefas"
  else
    step_fail "GET ${url}/api/state não lista as 27 tarefas"
  fi

  if curl -fsS --max-time 10 "${url}/" 2>/dev/null | grep -q "lab"; then
    step_ok "GET ${url}/ devolve a página do dashboard"
  else
    step_fail "GET ${url}/ não devolveu a página do dashboard"
  fi
}

# --- T9: ciclo completo de cada exercício -------------------------------------
t9_exercicios() {
  section T9 "ciclo start/grade/finish + solução, para cada um dos 25 exercícios"
  local lab res
  while read -r lab; do
    echo "--- $lab ---"
    vm_ssh workstation "lab start $lab" >"output/acceptance-t9-${lab}.out" 2>&1 \
      || { step_fail "$lab: 'lab start' falhou (ver output/acceptance-t9-${lab}.out)"; continue; }

    res="$(grade_result workstation "$lab")"
    if [ "$res" = "FALHOU" ]; then
      step_ok "$lab: grade antes da solução reporta FALHOU (esperado)"
    else
      step_fail "$lab: grade antes da solução deveria ser FALHOU (foi: $res)"
    fi

    run_solution "$lab" >>"output/acceptance-t9-${lab}.out" 2>&1 \
      || { step_fail "$lab: solução de referência falhou ao aplicar (ver output/acceptance-t9-${lab}.out)"; continue; }

    res="$(grade_result workstation "$lab")"
    if [ "$res" = "PASSOU" ]; then
      step_ok "$lab: grade depois da solução reporta PASSOU"
    else
      step_fail "$lab: grade depois da solução NÃO reportou PASSOU (foi: $res) -- solução ou grade.sh com bug"
    fi

    vm_ssh workstation "lab finish $lab" >>"output/acceptance-t9-${lab}.out" 2>&1 \
      || step_fail "$lab: 'lab finish' falhou"

    # Reuso: start de novo depois do finish precisa funcionar (bug de
    # disco_por_tamanho() vs resolve_disco() já visto em storage-lvm-01).
    if vm_ssh workstation "lab start $lab" >>"output/acceptance-t9-${lab}.out" 2>&1; then
      step_ok "$lab: 'lab start' funciona de novo após 'lab finish' (sem resíduo)"
    else
      step_fail "$lab: 'lab start' falhou após 'lab finish' -- ambiente não foi limpo corretamente"
    fi
    vm_ssh workstation "lab finish $lab" >/dev/null 2>&1 || true
    grep -q "FALHA\|ERRO" "output/acceptance-t9-${lab}.out" || rm -f "output/acceptance-t9-${lab}.out"
  done < <(lab_ids)
}

# --- T10: reboot das 3 VMs ----------------------------------------------------
t10_reboot() {
  section T10 "reboot das 3 VMs (serviços e config sobrevivem)"
  local vm
  for vm in "${VMS[@]}"; do
    virsh -c qemu:///system reboot "$(domain_name "$vm")" >/dev/null \
      || step_fail "virsh reboot $vm falhou"
  done
  sleep 15
  timed "reboot + SSH" wait_ssh_all 300 || { step_fail "VMs não voltaram a aceitar SSH em 300s"; return; }

  local ip port
  ip="$(dashboard_ip)"; port="$(dashboard_port)"
  sleep 5
  if curl -fsS --max-time 15 "http://${ip}:${port}/healthz" >/dev/null; then
    step_ok "dashboard volta sozinho após reboot"
  else
    step_fail "dashboard não respondeu após reboot"
  fi

  if [ "$(vm_ssh servera 'hostname -f' 2>/dev/null)" = "servera.$(python3 -c "import yaml;print(yaml.safe_load(open('machines.yaml'))['domain'])")" ]; then
    step_ok "hostname FQDN persiste após reboot"
  else
    step_fail "hostname FQDN não persistiu após reboot"
  fi

  local res
  res="$(grade_result workstation examsim-grupos)"
  if [ "$res" != "ERRO_INFRA" ]; then
    step_ok "'lab grade' funciona após reboot"
  else
    step_fail "'lab grade' com erro de infra após reboot"
  fi
}

# --- T12: prova completa (examsim-full) ---------------------------------------
t12_prova_completa() {
  section T12 "examsim-full: start, grade recusado, finish corrige e limpa"
  local out="output/acceptance-t12.out"
  timed "examsim-full start" vm_ssh workstation "lab start examsim-full" >"$out" 2>&1 \
    || { step_fail "'lab start examsim-full' falhou (ver $out)"; return; }
  step_ok "'lab start examsim-full' preparou as 24 questões"

  if vm_ssh workstation "lab grade examsim-full" >>"$out" 2>&1; then
    step_fail "'lab grade examsim-full' deveria ser recusado (correção só no finish)"
  else
    step_ok "'lab grade examsim-full' recusado, como no homelab"
  fi

  timed "examsim-full finish" vm_ssh workstation "lab finish examsim-full" >>"$out" 2>&1 \
    || { step_fail "'lab finish examsim-full' falhou (ver $out)"; return; }
  if grep -Eq "Nota [0-9]+/24" "$out"; then
    step_ok "finish corrigiu a prova ($(grep -Eo 'Nota [0-9]+/24' "$out" | tail -1), sem solução aplicada)"
  else
    step_fail "finish não mostrou a nota X/24 (ver $out)"
  fi

  # Depois do finish, um exercício avulso precisa funcionar de novo.
  if vm_ssh workstation "lab start examsim-grupos" >>"$out" 2>&1 \
     && vm_ssh workstation "lab finish examsim-grupos" >>"$out" 2>&1; then
    step_ok "ambiente utilizável depois do finish da prova completa"
  else
    step_fail "ambiente sujo depois do finish da prova completa (ver $out)"
  fi
}

# --- T13: exame dinâmico, ciclo real com seeds fixas --------------------------
t13_exame_dinamico() {
  section T13 "examsim-dinamico: 24 questões sorteadas, resolvidas e corrigidas (seeds: $DYN_SEEDS)"
  local seed out dyn=/usr/local/lib/lab-dyn
  for seed in $DYN_SEEDS; do
    out="output/acceptance-t13-${seed}.out"
    echo "--- seed $seed ---"
    timed "dinâmico start (seed $seed)" vm_ssh workstation "LAB_SEED=$seed lab start examsim-dinamico" >"$out" 2>&1 \
      || { step_fail "seed $seed: 'lab start examsim-dinamico' falhou (ver $out)"; continue; }

    vm_ssh workstation "$dyn/qa/solve-exam.sh </dev/null" >>"$out" 2>&1 \
      || step_fail "seed $seed: qa/solve-exam.sh falhou (ver $out)"
    vm_ssh workstation "$dyn/qa/solve-legacy.sh </dev/null" >>"$out" 2>&1 \
      || step_fail "seed $seed: qa/solve-legacy.sh falhou (ver $out)"

    timed "dinâmico finish (seed $seed)" vm_ssh workstation "lab finish examsim-dinamico" >>"$out" 2>&1 \
      || { step_fail "seed $seed: 'lab finish examsim-dinamico' falhou (ver $out)"; continue; }

    if grep -q "Nota 24/24" "$out"; then
      step_ok "seed $seed: 24/24, aprovado"
      rm -f "$out"
    else
      step_fail "seed $seed: nota diferente de 24/24 ($(grep -Eo 'Nota [0-9]+/24' "$out" | tail -1)) -- ver $out"
    fi
  done

  if vm_ssh workstation "test ! -e ~/examsim-dinamico/.aberta"; then
    step_ok "nenhuma prova dinâmica ficou aberta"
  else
    step_fail "prova dinâmica ficou aberta (~/examsim-dinamico/.aberta)"
  fi
}

# --- T11: ciclo limpo do zero (destroy + deploy em um comando) ---------------
t11_ciclo_limpo() {
  section T11 "make destroy && make deploy-offline && smoke (ciclo limpo, um comando)"
  if $SKIP_T11; then
    echo "  (pulado: --skip-t11)"
    return
  fi
  timed "destroy" make destroy > output/acceptance-t11.out 2>&1 \
    || { step_fail "'make destroy' falhou (ver output/acceptance-t11.out)"; return; }
  if virsh -c qemu:///system list --all --name | grep -q '^rhcsa-lab-' \
     || virsh -c qemu:///system vol-list default | grep -q 'rhcsa-lab-'; then
    step_fail "'make destroy' deixou domínios ou volumes rhcsa-lab-* para trás"
  else
    step_ok "'make destroy' não deixou domínios nem volumes para trás"
  fi
  if timed "deploy-offline" make deploy-offline >> output/acceptance-t11.out 2>&1 \
      && ! grep -qE "failed=[1-9]" output/acceptance-t11.out; then
    step_ok "ciclo limpo: 'make deploy-offline' com failed=0"
  else
    step_fail "ciclo limpo: 'make deploy-offline' falhou (ver output/acceptance-t11.out)"
  fi
  if bash tests/smoke/e2e-check.sh >> output/acceptance-t11.out 2>&1; then
    step_ok "ciclo limpo: smoke test passou"
  else
    step_fail "ciclo limpo: smoke test falhou (ver output/acceptance-t11.out)"
  fi
}

t1_check_env
t2_build_image
t3_infra
t4_provision_sem_subscription
t5_t6_provision_offline
t7_smoke
t8_dashboard
t9_exercicios
t12_prova_completa
t13_exame_dinamico
t10_reboot
t11_ciclo_limpo
make offline-repo-stop >/dev/null 2>&1 || true

echo ""
echo "=== Resultado final ==="
if [ "$FAILURES" -eq 0 ]; then
  echo "TODOS OS TESTES PASSARAM. Log completo: $LOG_FILE"
  exit 0
else
  echo "$FAILURES verificação(ões) falharam. Log completo: $LOG_FILE"
  exit 1
fi
