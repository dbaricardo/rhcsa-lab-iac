#!/bin/bash
# Solução de referência para systemd-services-01 (host: servera). Idempotente.
set -euo pipefail

cat > /etc/systemd/system/heartbeat.service <<'EOF'
[Unit]
Description=Heartbeat de teste (rhcsa-lab-iac)

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo "heartbeat $(date -Is)" >> /var/log/heartbeat.log'
EOF

cat > /etc/systemd/system/heartbeat.timer <<'EOF'
[Unit]
Description=Dispara heartbeat.service periodicamente

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
EOF

touch /var/log/heartbeat.log
systemctl daemon-reload
systemctl enable --now heartbeat.timer

echo "systemd-services-01: solução aplicada em $(hostname -s)."
