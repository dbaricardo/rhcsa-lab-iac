#!/bin/bash
# Questao 25 (treino cronometrado): swap + LVM + systemd timer em ate 10 min.
# Pontos fracos da prova de 2026-09-23. O disco de 6 GiB e' entregue SEM
# tabela de particoes, para o aluno escolher o label (gpt) no cfdisk/parted.
# O relogio comeca aqui e o grade mostra o tempo decorrido.
set -u
source /usr/local/lib/lab-common.sh
DISCO=$(resolve_disco 6) || { echo "ERRO: disco de 6GB nao encontrado"; exit 1; }
MNT=/treino
ESTADO=/var/lib/rhcsa-treino
SCRIPT=/usr/local/bin/treino-marca.sh

# Mesma limpeza do finish: timer, montagem, swap, VG e fstab do disco.
systemctl disable --now treino-marca.timer &>/dev/null
rm -f /etc/systemd/system/treino-marca.timer /etc/systemd/system/treino-marca.service
umount "$MNT" 2>/dev/null
for p in $(lsblk -nrpo NAME,TYPE "$DISCO" | awk '$2=="part"{print $1}'); do
    u=$(blkid -s UUID -o value "$p" 2>/dev/null)
    swapoff "$p" 2>/dev/null
    [ -n "$u" ] && sed -i "\#UUID=$u#d" /etc/fstab
    sed -i "\#^${p}[[:space:]]#d" /etc/fstab
done
sed -i '\#[[:space:]]/treino[[:space:]]#d; \#vgtreino#d' /etc/fstab
vgremove -ff vgtreino &>/dev/null
limpa_disco_forte "$DISCO"
systemctl daemon-reload
rm -rf "$MNT"

# Script que o timer deve executar (o foco e' a unit, nao o script).
cat > "$SCRIPT" <<'EOF'
#!/bin/bash
date '+%F %T' >> /treino/marca.log
EOF
chmod 0755 "$SCRIPT"

mkdir -p "$ESTADO"
date +%s > "$ESTADO/inicio"

cat <<EOF
OK: questao 25 pronta -- CRONOMETRO INICIADO ($(date '+%H:%M:%S')). Meta: 10 minutos.
Disco de pratica: $DISCO (6 GiB, sem tabela de particoes).
  1) Particao de 512 MiB como swap, ativa e persistente no /etc/fstab.
  2) Particao de 1 GiB -> VG vgtreino com PE de 16 MiB -> LV lvtreino com 20 extents,
     ext4, montado em /treino de forma persistente.
  3) treino-marca.service executando $SCRIPT e treino-marca.timer
     a cada 5 minutos (OnCalendar), habilitado e ativo.
Consulte so o man. Rode 'lab grade examsim-treino-storage' na workstation ao terminar.
EOF
