#!/bin/bash
# Liga a revisão por IA usando o PRÓPRIO host do libvirt como revisor
# (alvo `make ai-reviewer`). Faz, em ordem:
#   1. instala contrib/ai-reviewer/* em ~/.local/bin e grava a config do revisor
#   2. liga RHCSA_RECORDING_ENABLED/AI_REVIEW_ENABLED e AI_REVIEWER no .env
#   3. reaplica o Ansible (gera a chave do student na workstation)
#   4. autoriza essa chave no ~/.ssh/authorized_keys deste host (forced command)
#   5. faz uma revisão de teste a partir da workstation
#
# Motor: o Claude Code CLI deste usuário, se estiver instalado e logado;
# senão (ou como reserva) uma API compatível com OpenAI definida no .env
# (AI_REVIEW_OPENAI_URL + AI_REVIEW_OPENAI_MODEL).
#
# Uso: bash scripts/setup-ai-reviewer.sh [online|offline]
#      (padrão: offline se RHSM_ORG_ID estiver vazio no .env)
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
ENV_FILE="$ROOT_DIR/.env"
BIN_DIR="$HOME/.local/bin"
CONF_DIR="$HOME/.config/rhcsa-ai-review"
KEY_TAG="workstation-rhcsa-ai-review"   # comentário da chave gerada pelo role ai_review

die() { echo "ERRO: $*" >&2; exit 1; }
step() { echo; echo "== $* =="; }

[ -f "$ENV_FILE" ] || die ".env não encontrado -- rode 'cp .env.example .env' e 'make deploy' antes."
[ -f output/inventory.yml ] || die "lab não está no ar (sem output/inventory.yml) -- rode 'make deploy' antes."
set -a
# shellcheck source=/dev/null
. "$ENV_FILE"
set +a

MODE="${1:-}"
if [ -z "$MODE" ]; then
  if [ -n "${RHSM_ORG_ID:-}" ]; then MODE=online; else MODE=offline; fi
fi
case "$MODE" in online|offline) ;; *) die "modo inválido '$MODE' (use online ou offline)";; esac

read -r GATEWAY WS_IP < <(python3 - <<'PY'
import yaml
spec = yaml.safe_load(open('machines.yaml'))
print(spec['network']['gateway'], spec['machines']['workstation']['ip'])
PY
)

step "Motor da revisão"
CLAUDE_BIN="$(PATH="$BIN_DIR:/usr/local/bin:$PATH" command -v claude || true)"
OPENAI_URL="${AI_REVIEW_OPENAI_URL:-}"
OPENAI_MODEL="${AI_REVIEW_OPENAI_MODEL:-}"
if [ -n "$CLAUDE_BIN" ]; then
  echo "  Claude Code CLI: $CLAUDE_BIN"
  if ! timeout 90 "$CLAUDE_BIN" -p "Responda apenas: OK" </dev/null >/dev/null 2>&1; then
    die "o Claude CLI não respondeu a 'claude -p'. Rode 'claude' uma vez neste usuário e faça o login."
  fi
  echo "  Claude respondeu (login OK)"
fi
if [ -n "$OPENAI_URL" ] || [ -n "$OPENAI_MODEL" ]; then
  [ -n "$OPENAI_URL" ] && [ -n "$OPENAI_MODEL" ] || die "defina AI_REVIEW_OPENAI_URL e AI_REVIEW_OPENAI_MODEL juntos no .env."
  echo "  API compatível com OpenAI: $OPENAI_URL (modelo $OPENAI_MODEL)$([ -n "$CLAUDE_BIN" ] && echo ' -- usada como reserva')"
fi
[ -n "$CLAUDE_BIN" ] || [ -n "$OPENAI_URL" ] || die "nenhum motor: instale e logue o Claude Code CLI ou defina AI_REVIEW_OPENAI_URL/AI_REVIEW_OPENAI_MODEL no .env (ver docs/how-to/ativar-revisao-ia.md)."

step "Instalando o revisor em $BIN_DIR"
install -Dm755 contrib/ai-reviewer/rhcsa-ai-review "$BIN_DIR/rhcsa-ai-review"
install -Dm755 contrib/ai-reviewer/rhcsa-ai-review-openai "$BIN_DIR/rhcsa-ai-review-openai"
install -d -m700 "$CONF_DIR"
umask 077
{
  echo "# Gerado por scripts/setup-ai-reviewer.sh -- lido por rhcsa-ai-review."
  [ -n "${AI_REVIEW_MODEL:-}" ] && echo "RHCSA_REVIEW_MODEL=$AI_REVIEW_MODEL"
  if [ -n "$OPENAI_URL" ]; then
    echo "RHCSA_REVIEW_FALLBACK=$BIN_DIR/rhcsa-ai-review-openai"
    echo "RHCSA_REVIEW_FALLBACK_URL=$OPENAI_URL"
    echo "RHCSA_REVIEW_FALLBACK_MODEL=$OPENAI_MODEL"
    [ -n "${AI_REVIEW_OPENAI_API_KEY:-}" ] && echo "RHCSA_REVIEW_FALLBACK_API_KEY=$AI_REVIEW_OPENAI_API_KEY"
  fi
  true
} > "$CONF_DIR/env"
umask 022
echo "  config: $CONF_DIR/env (modo 600)"

step "Conferindo o sshd deste host"
systemctl is-active --quiet sshd 2>/dev/null || systemctl is-active --quiet ssh 2>/dev/null \
  || die "sshd não está rodando -- 'sudo systemctl enable --now sshd' (Debian/Ubuntu: pacote openssh-server, serviço ssh)."
if command -v firewall-cmd >/dev/null 2>&1 && sudo -n firewall-cmd --state >/dev/null 2>&1; then
  if ! sudo -n firewall-cmd --zone=libvirt --query-service=ssh >/dev/null 2>&1; then
    sudo -n firewall-cmd --zone=libvirt --add-service=ssh --permanent >/dev/null
    sudo -n firewall-cmd --reload >/dev/null
    echo "  firewalld: ssh liberado na zona libvirt"
  fi
fi
echo "  ok"

step "Ligando a revisão no .env (revisor = $USER@$GATEWAY)"
set_env() {  # set_env CHAVE VALOR -- substitui a linha ou acrescenta no fim
  if grep -q "^$1=" "$ENV_FILE"; then
    sed -i "s|^$1=.*|$1=$2|" "$ENV_FILE"
  else
    echo "$1=$2" >> "$ENV_FILE"
  fi
}
set_env RHCSA_RECORDING_ENABLED true
set_env AI_REVIEW_ENABLED true
set_env AI_REVIEWER "$USER@$GATEWAY"
grep -E '^(RHCSA_RECORDING_ENABLED|AI_REVIEW_ENABLED|AI_REVIEWER)=' "$ENV_FILE" | sed 's/^/  /'

step "Reaplicando o Ansible (make provision$([ "$MODE" = offline ] && echo -offline))"
if [ "$MODE" = offline ]; then make --no-print-directory provision-offline; else make --no-print-directory provision; fi

step "Autorizando a chave da workstation em ~/.ssh/authorized_keys"
PUBKEY="$(bash scripts/lab-ssh.sh workstation 'cat ~/.ssh/rhcsa_ai_review.pub')"
case "$PUBKEY" in ssh-ed25519\ *"$KEY_TAG") ;; *) die "chave inesperada lida da workstation: '$PUBKEY'";; esac
install -d -m700 "$HOME/.ssh"
touch "$HOME/.ssh/authorized_keys"
chmod 600 "$HOME/.ssh/authorized_keys"
# Cada deploy recria a workstation com chave nova: troca a linha anterior.
tmp="$(mktemp)"
grep -v -- "$KEY_TAG" "$HOME/.ssh/authorized_keys" > "$tmp" || true
echo "from=\"$WS_IP\",command=\"$BIN_DIR/rhcsa-ai-review\",restrict $PUBKEY" >> "$tmp"
cat "$tmp" > "$HOME/.ssh/authorized_keys"
rm -f "$tmp"
command -v restorecon >/dev/null 2>&1 && restorecon -R "$HOME/.ssh" 2>/dev/null || true
echo "  ok (from=\"$WS_IP\", forced command rhcsa-ai-review)"

step "Teste: revisão de exemplo pedida pela workstation (pode levar 1-2 min)"
TEST_JSON='{"task":{"id":"examsim-cron","title":"teste do make ai-reviewer"},"events":[],"transcripts":[]}'
if out="$(bash scripts/lab-ssh.sh workstation \
      "echo '$TEST_JSON' | ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i ~/.ssh/rhcsa_ai_review $USER@$GATEWAY review" 2>&1)"; then
  echo "$out" | head -15 | sed 's/^/  | /'
  echo
  echo "Revisão por IA ativa. Todo 'lab finish <examsim-...>' termina com a revisão."
  echo "Pular numa execução: RHCSA_AI_REVIEW=0 lab finish <id>"
else
  echo "$out" | tail -5 | sed 's/^/  | /'
  die "o teste falhou -- ver docs/how-to/ativar-revisao-ia.md (seção 'Se der errado')."
fi
