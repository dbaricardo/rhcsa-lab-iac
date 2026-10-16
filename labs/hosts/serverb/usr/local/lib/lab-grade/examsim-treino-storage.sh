#!/bin/bash
set -u
source /usr/local/lib/lab-common.sh
FAIL=0
check() { if [ "$1" -eq 0 ]; then echo "OK: $2"; else echo "FALHOU: $2"; FAIL=1; fi; }
MNT=/treino
ESTADO=/var/lib/rhcsa-treino
META=600

# Tempo antes de qualquer checagem, para nao contar a duracao do proprio grade.
AGORA=$(date +%s)
INICIO=$(cat "$ESTADO/inicio" 2>/dev/null)
DISCO=$(resolve_disco 6) || DISCO=""

# --- 1. swap ---
SWAP_PART=""
SWAP_BYTES=0
while read -r nome bytes; do
    case "$nome" in "$DISCO"?*) SWAP_PART=$nome; SWAP_BYTES=$bytes ;; esac
done < <(swapon --show=NAME,SIZE --bytes --noheadings 2>/dev/null)
[ -n "$DISCO" ] && [ -n "$SWAP_PART" ]
check $? "particao de swap do disco ${DISCO:-?} ativa (swapon --show: ${SWAP_PART:-nenhuma})"
SWAP_MIB=$((SWAP_BYTES / 1048576))
[ "$SWAP_MIB" -ge 500 ] && [ "$SWAP_MIB" -le 530 ]
check $? "swap com ~512 MiB (atual: ${SWAP_MIB} MiB)"
SWAP_FSTAB=1
if [ -n "$SWAP_PART" ]; then
    u=$(blkid -s UUID -o value "$SWAP_PART" 2>/dev/null)
    awk -v u="UUID=$u" -v p="$SWAP_PART" '$1!~/^#/ && $3=="swap" && ($1==u || $1==p){f=1} END{exit !f}' /etc/fstab
    SWAP_FSTAB=$?
fi
check $SWAP_FSTAB "swap persistente no /etc/fstab (UUID ou caminho, tipo swap)"

# --- 2. LVM ---
vgs vgtreino &>/dev/null; check $? "VG vgtreino existe"
PV=$(pvs --noheadings -o pv_name -S vg_name=vgtreino 2>/dev/null | tr -d ' ' | head -1)
case "$PV" in "$DISCO"?*) r=0 ;; *) r=1 ;; esac
[ -n "$DISCO" ] || r=1
check $r "PV de vgtreino e' uma particao de $DISCO (atual: ${PV:-nenhum})"
PE=$(vgs --noheadings --units m --nosuffix -o vg_extent_size vgtreino 2>/dev/null | tr -d ' ')
[ "${PE%.*}" = "16" ]; check $? "tamanho do PE de vgtreino = 16 MiB (atual: ${PE:-?}M)"
EXT=$(lvs --noheadings -o seg_size_pe vgtreino/lvtreino 2>/dev/null | tr -d ' ')
[ "$EXT" = "20" ]; check $? "LV lvtreino com 20 extents (atual: ${EXT:-?})"
FSTYPE=$(blkid -s TYPE -o value /dev/vgtreino/lvtreino 2>/dev/null)
[ "$FSTYPE" = "ext4" ]; check $? "lvtreino formatado em ext4 (atual: ${FSTYPE:-nenhum})"
SOURCE=$(findmnt -no SOURCE "$MNT" 2>/dev/null)
[ "$SOURCE" = "/dev/mapper/vgtreino-lvtreino" ]; check $? "$MNT montado a partir de vgtreino/lvtreino (origem: ${SOURCE:-nenhuma})"
UUID=$(blkid -s UUID -o value /dev/vgtreino/lvtreino 2>/dev/null)
awk -v u="UUID=$UUID" -v m="$MNT" '$1!~/^#/ && $2==m && ($1=="/dev/mapper/vgtreino-lvtreino" || $1=="/dev/vgtreino/lvtreino" || ($1==u && u!="UUID=")){f=1} END{exit !f}' /etc/fstab
check $? "/etc/fstab monta vgtreino/lvtreino em $MNT"
# O que derruba a prova na correcao pos-reboot: fstab com erro.
findmnt --verify &>/dev/null; check $? "findmnt --verify sem erros (fstab sobrevive ao reboot)"

# --- 3. timer ---
systemctl cat treino-marca.service 2>/dev/null | grep -Eq '^[[:space:]]*ExecStart[[:space:]]*=.*/usr/local/bin/treino-marca\.sh'
check $? "treino-marca.service executa /usr/local/bin/treino-marca.sh"
systemctl is-enabled treino-marca.timer &>/dev/null; check $? "treino-marca.timer habilitado (enable)"
systemctl is-active treino-marca.timer &>/dev/null; check $? "treino-marca.timer ativo (start)"
CAL=$(systemctl cat treino-marca.timer 2>/dev/null | sed -n 's/^[[:space:]]*OnCalendar[[:space:]]*=[[:space:]]*//p' | head -1)
NORM=$(systemd-analyze calendar "$CAL" 2>/dev/null | awk -F': ' '/Normalized form/{print $2}')
[ "$NORM" = "*-*-* *:00/5:00" ]; check $? "OnCalendar a cada 5 minutos (atual: '${CAL:-nenhum}' -> '${NORM:-invalido}')"
# Dispara o servico para provar que a cadeia timer -> service -> script funciona.
rm -f "$MNT/marca.log" 2>/dev/null
systemctl start treino-marca.service &>/dev/null
# Com Type=simple o start volta antes do script terminar.
for _ in 1 2 3 4 5 6; do [ -s "$MNT/marca.log" ] && break; sleep 0.5; done
[ -s "$MNT/marca.log" ]; check $? "servico executado grava $MNT/marca.log"

# --- tempo ---
if [ -n "$INICIO" ]; then
    DECORRIDO=$((AGORA - INICIO))
    TEMPO=$(printf '%02d:%02d' $((DECORRIDO / 60)) $((DECORRIDO % 60)))
    [ "$DECORRIDO" -le "$META" ] && SITU="DENTRO da meta" || SITU="FORA da meta"
    echo "TEMPO: $TEMPO desde o lab start (meta 10:00) -- $SITU"
    if [ "$FAIL" -eq 0 ]; then
        echo "$(date '+%F %T') $TEMPO" >> "$ESTADO/historico"
        MELHOR=$(awk '{print $3}' "$ESTADO/historico" | sort | head -1)
        echo "HISTORICO: $(wc -l < "$ESTADO/historico") conclusao(oes); melhor tempo $MELHOR"
        # Grade repetido nao registra o mesmo treino de novo.
        rm -f "$ESTADO/inicio"
    fi
else
    echo "TEMPO: cronometro nao iniciado (rode lab start) ou treino ja registrado"
fi

[ "$FAIL" -eq 0 ] && echo "RESULTADO: PASSOU" || echo "RESULTADO: FALHOU"
exit $FAIL
