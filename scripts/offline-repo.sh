#!/bin/bash
# Serve BaseOS/AppStream da DVD ISO (RHEL_ISO_PATH) via HTTP simples, para o
# modo TESTE/aceitação sem subscription real (ver docs/troubleshooting.md,
# seção "Modo offline via ISO"). Usado por `make reprovision-offline`.
#
# Não é um espelho de produção: sem updates/erratas, só o conteúdo
# congelado da ISO no momento do download. Serve apenas na rede privada do
# lab (192.168.56.0/24), nunca na LAN real.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

[ -f .env ] && source .env

MNT_DIR="$ROOT_DIR/output/iso-mnt"
PID_FILE="$ROOT_DIR/output/offline-repo.pid"
BIND_IP="192.168.56.1"
PORT="8080"

usage() {
  echo "Uso: $0 start|stop" >&2
  exit 1
}

start() {
  : "${RHEL_ISO_PATH:?defina RHEL_ISO_PATH no .env (ver .env.example)}"
  [ -f "$RHEL_ISO_PATH" ] || {
    echo "ERRO: RHEL_ISO_PATH '$RHEL_ISO_PATH' não existe." >&2
    exit 1
  }

  if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "==> offline-repo já está rodando (PID $(cat "$PID_FILE"))."
    exit 0
  fi

  mkdir -p "$MNT_DIR"
  if ! mountpoint -q "$MNT_DIR"; then
    echo "==> Montando ${RHEL_ISO_PATH} (somente leitura) em ${MNT_DIR}"
    sudo mount -o loop,ro "$RHEL_ISO_PATH" "$MNT_DIR"
  fi

  for dir in BaseOS AppStream; do
    [ -d "$MNT_DIR/$dir/repodata" ] || {
      echo "ERRO: '$dir/repodata' não encontrado em $MNT_DIR." \
        "RHEL_ISO_PATH aponta para a DVD ISO completa (não a boot ISO)?" >&2
      exit 1
    }
  done

  echo "==> Servindo ${MNT_DIR} em http://${BIND_IP}:${PORT} (rede do lab)"
  (cd "$MNT_DIR" && nohup python3 -m http.server "$PORT" --bind "$BIND_IP" \
    >"$ROOT_DIR/output/offline-repo.log" 2>&1 &
    echo $! >"$PID_FILE")
  sleep 1
  kill -0 "$(cat "$PID_FILE")" 2>/dev/null || {
    echo "ERRO: servidor HTTP não subiu, ver output/offline-repo.log" >&2
    exit 1
  }

  if command -v firewall-cmd >/dev/null 2>&1 && sudo firewall-cmd --state >/dev/null 2>&1; then
    sudo firewall-cmd --zone=libvirt --add-port="${PORT}/tcp" --permanent >/dev/null 2>&1 || true
    sudo firewall-cmd --reload >/dev/null 2>&1 || true
  fi

  echo "==> offline-repo no ar (PID $(cat "$PID_FILE"))."
  echo "    LAB_OFFLINE_REPO_URL=http://${BIND_IP}:${PORT}"
}

stop() {
  if [ -f "$PID_FILE" ]; then
    kill "$(cat "$PID_FILE")" >/dev/null 2>&1 || true
    rm -f "$PID_FILE"
  fi
  if mountpoint -q "$MNT_DIR" 2>/dev/null; then
    sudo umount "$MNT_DIR"
  fi
  echo "==> offline-repo parado."
}

case "${1:-}" in
  start) start ;;
  stop) stop ;;
  *) usage ;;
esac
