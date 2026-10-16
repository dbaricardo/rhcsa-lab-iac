#!/bin/bash
# Parte serverb da prova completa (examsim-full). Chamado pelo orquestrador da
# workstation como root@serverb. Os labs avulsos 19/20/22 disputam o mesmo
# disco de 1 GiB e o mesmo VG myvg; aqui cada um ganha espaco proprio:
#   disco 1 GiB : p1 250 MiB -> questao 19 (swap)
#   disco 6 GiB : p1 1 GiB -> vg_home/home (questao 22)
#                 p2 400 MiB -> vg_data/lv_data (questao 24)
#                 restante livre -> myvg (questao 20) e o PV novo da questao 24
# Uso: examsim-full-serverb.sh storage-start|storage-finish|rootpw-start|rootpw-finish
set -u
source /usr/local/lib/lab-common.sh
ESTADO=/root/.examsim-full
mkdir -p "$ESTADO"; chmod 700 "$ESTADO"

particao() {  # particao <disco> <n>
    case "$1" in *[0-9]) echo "${1}p$2" ;; *) echo "$1$2" ;; esac
}

# Desfaz TUDO que existir nos discos de pratica (inclusive o que o aluno criou):
# desmonta, swapoff, tira do fstab, remove VGs e zera os discos.
limpa_discos_pratica() {
    local so d dev vg pv devs="" mnts="" vgs="" extras=""
    so=$(disco_do_so)
    for d in "$D1" "$D6"; do
        [ "$d" = "$so" ] && { echo "ERRO: disco de pratica $d e o disco do SO"; return 1; }
        devs="$devs $(lsblk -nrpo NAME "$d" | tr "\n" " ")"
    done
    for vg in $(pvs --noheadings -o pv_name,vg_name 2>/dev/null | awk -v l="$devs " 'index(l, $1" ") && $2!=""{print $2}' | sort -u); do
        for pv in $(pvs --noheadings -o pv_name -S vg_name="$vg" 2>/dev/null); do
            case " $devs " in *" $pv "*) ;; *) echo "ERRO: VG $vg tem PV $pv fora dos discos de pratica; nada foi apagado"; return 1 ;; esac
        done
        vgs="$vgs $vg"
        for lv in $(lvs --noheadings -o lv_name "$vg" 2>/dev/null); do extras="$extras /dev/$vg/$lv"; done
    done
    for dev in $devs; do
        mnts="$mnts $(findmnt -nro TARGET -S "$dev" 2>/dev/null)"
        swapoff "$dev" 2>/dev/null
        extras="$extras $(blkid -s UUID -o value "$dev" 2>/dev/null | sed 's/^/UUID=/') $(blkid -s PARTUUID -o value "$dev" 2>/dev/null | sed 's/^/PARTUUID=/')"
    done
    # Swap no fstab apontando para UUID que nao existe mais (sobra de lab antigo
    # cujo disco foi zerado): o dispositivo sumiu, entao a busca acima nao o acha.
    for u in $(awk '$1!~/^#/ && $3=="swap" && $1~/^UUID=/{print substr($1,6)}' /etc/fstab); do
        blkid -U "$u" &>/dev/null || extras="$extras UUID=$u"
    done
    for m in $(printf '%s\n' $mnts | sort -r); do umount "$m" 2>/dev/null || umount -l "$m"; done
    cp -p /etc/fstab "$ESTADO/fstab.$(date +%Y%m%dT%H%M%S)"
    awk -v l=" $devs $extras $mnts /mnt/examsim-home /mnt/examsim-data /database " '
        /^[[:space:]]*#/ || NF < 2 {print; next}
        $2=="/" || $2=="/boot" || $2=="/boot/efi" {print; next}
        index(l, " "$1" ") || index(l, " "$2" ") {next}
        $1 ~ "^/dev/(mapper/)?(myvg|vg_home|vg_data)[-/]" {next}
        {print}' /etc/fstab > "$ESTADO/fstab.novo" && cat "$ESTADO/fstab.novo" > /etc/fstab
    rm -f "$ESTADO/fstab.novo"
    for vg in $vgs; do vgremove -ff -y "$vg" &>/dev/null; done
    for dev in $devs; do pvremove -ff -y "$dev" &>/dev/null; done
    # Mapeamento DM orfao (LV cujo metadado ja foi apagado do disco): o vgs nao
    # o enxerga, mas ele segura o disco e o pvcreate seguinte falha.
    for dm in /sys/block/dm-*; do
        [ -d "$dm/slaves" ] || continue
        for s in "$dm"/slaves/*; do
            case " $devs " in *" /dev/${s##*/} "*)
                dmsetup remove -f "$(cat "$dm/dm/name")" &>/dev/null; break ;;
            esac
        done
    done
    limpa_disco_forte "$D1"; limpa_disco_forte "$D6"
    udevadm settle 2>/dev/null
    systemctl daemon-reload
    rmdir /mnt/examsim-home /mnt/examsim-data /database 2>/dev/null
    return 0
}

resolve_discos() {
    D1=$(resolve_disco 1) || { echo "ERRO: disco de 1GB nao encontrado"; exit 1; }
    D6=$(resolve_disco 6) || { echo "ERRO: disco de 6GB nao encontrado"; exit 1; }
}

case "${1:-}" in
    storage-start)
        resolve_discos
        limpa_discos_pratica || exit 1
        bash /usr/local/lib/lab-scripts/examsim-swap.sh || exit 1
        parted -s "$D6" mklabel gpt mkpart home 1MiB 1025MiB mkpart data 1025MiB 1425MiB
        partprobe "$D6" 2>/dev/null; udevadm settle 2>/dev/null
        P1=$(particao "$D6" 1); P2=$(particao "$D6" 2)
        [ -b "$P1" ] && [ -b "$P2" ] || { echo "ERRO: particoes de $D6 nao apareceram"; exit 1; }
        pvcreate -ff -y "$P1" &>/dev/null
        vgcreate vg_home "$P1" &>/dev/null || { echo "ERRO: vgcreate vg_home falhou"; exit 1; }
        lvcreate -y -l 15 -n home vg_home &>/dev/null || { echo "ERRO: lvcreate vg_home/home falhou"; exit 1; }
        mkfs.ext4 -q /dev/vg_home/home
        mkdir -p /mnt/examsim-home
        # Com fstab (o avulso nao tem) para sobreviver ao reboot da questao 16.
        echo "/dev/mapper/vg_home-home /mnt/examsim-home ext4 defaults 0 0" >> /etc/fstab
        systemctl daemon-reload
        mount /mnt/examsim-home || { echo "ERRO: nao consegui montar /mnt/examsim-home"; exit 1; }
        echo "arquivo de teste -- deve sobreviver ao resize" > /mnt/examsim-home/teste-examsim22.txt
        EXAMSIM_VGDATA_PART=$P2 bash /usr/local/lib/lab-scripts/examsim-vgextend.sh || exit 1
        echo "DISCO1=$D1"
        echo "DISCO6=$D6"
        ;;
    storage-finish)
        resolve_discos
        limpa_discos_pratica || exit 1
        echo "limpeza: discos de pratica $D1 e $D6 zerados; fstab anterior salvo em $ESTADO/"
        ;;
    rootpw-start)
        # Guarda o hash so' na primeira vez: um start repetido sem finish nao
        # pode sobrescrever o original com a senha aleatoria.
        [ -s "$ESTADO/root.hash" ] || { getent shadow root | cut -d: -f2 > "$ESTADO/root.hash"; chmod 600 "$ESTADO/root.hash"; }
        echo "root:$(openssl rand -base64 24)" | chpasswd || exit 1
        echo "root do serverb com credencial desconhecida -- questao 16 pronta (recupere pelo console)."
        ;;
    rootpw-finish)
        if [ -s "$ESTADO/root.hash" ]; then
            usermod -p "$(cat "$ESTADO/root.hash")" root && rm -f "$ESTADO/root.hash"
            echo "limpeza: credencial original de root do serverb restaurada."
        else
            echo "limpeza: nada a restaurar para root (sem hash guardado)."
        fi
        ;;
    *)
        echo "Uso: $0 storage-start|storage-finish|rootpw-start|rootpw-finish" >&2
        exit 1
        ;;
esac
