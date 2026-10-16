# Biblioteca comum das tarefas portadas do exame dinamico.
# O orquestrador envia "_lib.sh + <tarefa>.sh" ao host como argumento de bash -c;
# a tarefa define do_start/do_grade/do_finish e termina com: run "$@"
set -u
ST=/root/.examsim-dyn
mkdir -p "$ST"; chmod 700 "$ST"
FAIL=0
check() { if [ "$1" -eq 0 ]; then echo "OK: $2"; else echo "FALHOU: $2"; FAIL=1; fi; }
run() {
    case "${1:-}" in
        start)  do_start ;;
        grade)  do_grade
                [ "$FAIL" -eq 0 ] && echo "RESULTADO: PASSOU" || echo "RESULTADO: FALHOU"
                exit "$FAIL" ;;
        finish) do_finish ;;
        server-start)  do_server_start ;;
        server-finish) do_server_finish ;;
        *)      echo "Uso: <tarefa> start|grade|finish|server-start|server-finish" >&2; exit 1 ;;
    esac
}
# Guarda o arquivo original (ou o fato de ele nao existir) so' na primeira vez.
conf_save() {  # conf_save <arquivo> <chave>
    [ -e "$ST/$2.saved" ] && return 0
    if [ -e "$1" ]; then cp -p "$1" "$ST/$2.orig"; else : > "$ST/$2.absent"; fi
    : > "$ST/$2.saved"
}
conf_restore() {  # conf_restore <arquivo> <chave>
    if [ -e "$ST/$2.orig" ]; then cp -p "$ST/$2.orig" "$1"; restorecon "$1" 2>/dev/null
    elif [ -e "$ST/$2.absent" ]; then rm -f "$1"; fi
    rm -f "$ST/$2.orig" "$ST/$2.absent" "$ST/$2.saved"
}
# Drop-ins do journald: lembra os existentes e remove os criados pelo aluno.
JD=/etc/systemd/journald.conf.d
dropins_save() {  # dropins_save <chave>
    [ -e "$ST/$1.dropins" ] && return 0
    { ls -1 "$JD" 2>/dev/null; true; } > "$ST/$1.dropins"
    [ -d "$JD" ] || : > "$ST/$1.nodir"   # o diretorio nem existia: remove-o se ficar vazio
}
dropins_restore() {  # dropins_restore <chave>
    local f
    for f in "$JD"/*.conf; do
        [ -e "$f" ] || continue
        grep -qxF "${f##*/}" "$ST/$1.dropins" 2>/dev/null || rm -f "$f"
    done
    [ -e "$ST/$1.nodir" ] && rmdir "$JD" 2>/dev/null
    rm -f "$ST/$1.dropins" "$ST/$1.nodir"
}
# O systemd limita reinicios seguidos do journald; limpa o contador antes.
journal_restart() { systemctl reset-failed systemd-journald 2>/dev/null; systemctl restart systemd-journald; }
# Garante a secao [Journal] e insere uma linha logo abaixo dela.
journal_set() {
    grep -q '^\[Journal\]' /etc/systemd/journald.conf || echo '[Journal]' >> /etc/systemd/journald.conf
    sed -i "/^\[Journal\]/a $1" /etc/systemd/journald.conf
}
# Valor efetivo (a ultima ocorrencia vence) de uma chave do journald, com drop-ins.
journal_value() {
    systemd-analyze cat-config systemd/journald.conf 2>/dev/null | grep -E "^$1=" | tail -1 | cut -d= -f2
}

# ---- discos de pratica (Fase 2, dominio 4) -------------------------------------
# Os discos de 2 e 3 GiB sao achados pelo TAMANHO exato (o nome sdX pode mudar entre
# boots) e nunca pode ser o disco do SO.
disk_by_size() {  # <bytes> -> /dev/sdX
    local want=$1 name size
    while read -r name size; do
        [ "$size" = "$want" ] || continue
        lsblk -nro MOUNTPOINT "/dev/$name" | grep -qE '^(/|/boot|/boot/efi)$' && continue
        echo "/dev/$name"; return 0
    done < <(lsblk -bdnro NAME,SIZE -e 7,11)
    return 1
}
need_disk() {  # need_disk <bytes> -> imprime o disco; sem ele, erro claro em stderr e rc 1
    local d
    d=$(disk_by_size "$1") || { echo "ERRO: nao achei o disco de pratica de $1 bytes neste host" >&2; return 1; }
    echo "$d"
}
disk_part() { case "$1" in *[0-9]) echo "${1}p$2" ;; *) echo "$1$2" ;; esac; }
settle() { partprobe "$@" 2>/dev/null; udevadm settle 2>/dev/null; }

# Desfaz TUDO nos discos dados (inclusive o que o aluno criou): desmonta, swapoff,
# tira do fstab, remove VGs e zera os discos. Recusa o disco do SO e VG que tenha
# PV fora dos discos informados.
disk_clean() {  # disk_clean <disco> [<disco>...]
    local d devs="" mnts="" vgs="" extras="" vg pv lv dev u dm s m
    for d in "$@"; do
        [ -b "$d" ] || { echo "ERRO: $d nao e um disco"; return 1; }
        if lsblk -nro MOUNTPOINT "$d" | grep -qE '^(/|/boot|/boot/efi)$'; then
            echo "ERRO: $d e o disco do SO; nada foi apagado"; return 1
        fi
        devs="$devs $(lsblk -nrpo NAME "$d" | tr '\n' ' ')"
    done
    for vg in $(pvs --noheadings -o pv_name,vg_name 2>/dev/null | awk -v l="$devs " 'index(l, $1" ") && $2!=""{print $2}' | sort -u); do
        for pv in $(pvs --noheadings -o pv_name -S vg_name="$vg" 2>/dev/null); do
            case " $devs " in *" $pv "*) ;; *) echo "ERRO: VG $vg tem PV $pv fora dos discos; nada foi apagado"; return 1 ;; esac
        done
        vgs="$vgs $vg"
        for lv in $(lvs --noheadings -o lv_name "$vg" 2>/dev/null); do extras="$extras /dev/$vg/$lv /dev/mapper/$vg-$lv"; done
    done
    for dev in $devs $extras; do
        mnts="$mnts $(findmnt -nro TARGET -S "$dev" 2>/dev/null)"
        swapoff "$dev" 2>/dev/null
        u=$(blkid -s UUID -o value "$dev" 2>/dev/null); [ -n "$u" ] && extras="$extras UUID=$u"
        u=$(blkid -s PARTUUID -o value "$dev" 2>/dev/null); [ -n "$u" ] && extras="$extras PARTUUID=$u"
    done
    for m in $(printf '%s\n' $mnts | sort -r); do umount "$m" 2>/dev/null || umount -l "$m"; done
    awk -v l=" $devs $extras $mnts " '
        /^[[:space:]]*#/ || NF < 2 {print; next}
        $2=="/" || $2=="/boot" || $2=="/boot/efi" {print; next}
        index(l, " "$1" ") || index(l, " "$2" ") {next}
        {print}' /etc/fstab > "$ST/fstab.novo" && cat "$ST/fstab.novo" > /etc/fstab
    rm -f "$ST/fstab.novo"
    for vg in $vgs; do vgremove -ff -y "$vg" &>/dev/null; done
    for dev in $devs; do pvremove -ff -y "$dev" &>/dev/null; done
    # LV orfao (metadado ja apagado) segura o disco e quebra o pvcreate seguinte.
    for dm in /sys/block/dm-*; do
        [ -d "$dm/slaves" ] || continue
        for s in "$dm"/slaves/*; do
            case " $devs " in *" /dev/${s##*/} "*) dmsetup remove -f "$(cat "$dm/dm/name")" &>/dev/null; break ;; esac
        done
    done
    for d in "$@"; do
        local sz; sz=$(blockdev --getsz "$d")
        for dev in $(lsblk -nrpo NAME "$d" | tac); do wipefs -a "$dev" &>/dev/null; done
        dd if=/dev/zero of="$d" bs=1M count=4 conv=notrunc status=none
        dd if=/dev/zero of="$d" bs=512 seek=$((sz - 8192)) count=8192 conv=notrunc status=none
        settle "$d"
    done
    systemctl daemon-reload
    for m in $mnts; do rmdir "$m" 2>/dev/null; done
    return 0
}
# GPT com particoes: disk_gpt <disco> <fim1MiB>... cria uma particao por fim informado (MiB)
disk_gpt() {  # disk_gpt <disco> <fim_MiB> [<fim_MiB>...]
    local d=$1 start=1 end; shift
    parted -s "$d" mklabel gpt || return 1
    for end in "$@"; do
        parted -s "$d" mkpart primary "${start}MiB" "${end}MiB" || return 1
        start=$end
    done
    settle "$d"
}
# Aguarda o no de dispositivo aparecer (udev e' assincrono).
wait_dev() { local i; for i in $(seq 1 25); do [ -b "$1" ] && return 0; sleep 0.2; done; return 1; }
# Extrai o UUID de um dispositivo.
dev_uuid() { blkid -s UUID -o value "$1" 2>/dev/null; }
# Linha do fstab que referencia o ponto de montagem (ignora comentarios).
fstab_line() {  # fstab_line <mountpoint>
    awk -v m="$1" '$1 !~ /^#/ && $2==m {$1=$1; print; exit}' /etc/fstab   # $1=$1: normaliza tabs/espacos
}

# ---- NFS / autofs (Fase 2) ---------------------------------------------------
NFS_SERVER=workstation.lab.example.com
NFS_SERVER_IP=192.168.56.10
# Servidor (roda na workstation): exporta <dir> com um arquivo de teste; lembra se o
# nfs-server estava parado para devolve-lo ao estado original.
nfs_export_add() {  # nfs_export_add <chave> <dir> [subdir...]
    local key=$1 dir=$2 sub; shift 2
    mkdir -p "$dir"; chmod 755 "$dir"
    echo "conteudo-dyn-$key" > "$dir/hello.txt"
    for sub in "$@"; do mkdir -p "$dir/$sub"; echo "conteudo-dyn-$key-$sub" > "$dir/$sub/hello.txt"; done
    mkdir -p /etc/exports.d
    printf '%s *(rw,sync,no_root_squash)\n' "$dir" > "/etc/exports.d/dyn-$key.exports"
    if [ ! -e "$ST/nfs-server.was" ]; then
        systemctl is-active --quiet nfs-server && echo active > "$ST/nfs-server.was" || echo inactive > "$ST/nfs-server.was"
    fi
    systemctl is-active --quiet nfs-server || systemctl start nfs-server
    exportfs -ra
}
nfs_export_del() {  # nfs_export_del <chave> <dir>
    rm -f "/etc/exports.d/dyn-$1.exports"
    exportfs -ra 2>/dev/null
    case "$2" in /exports/?*) rm -rf "$2" ;; *) echo "AVISO: export fora de /exports ignorado: $2" ;; esac
    rmdir /exports 2>/dev/null   # so' some se a tarefa a criou e ficou vazia
    if ! ls /etc/exports.d/dyn-*.exports &>/dev/null; then   # foi o ultimo export da prova
        [ "$(cat "$ST/nfs-server.was" 2>/dev/null)" = inactive ] && systemctl stop nfs-server 2>/dev/null
        rm -f "${ST:?}/nfs-server.was"
    fi
}
# Origem de um mount NFS casa com <export>, aceitando o nome ou o IP do servidor.
nfs_src_ok() {  # nfs_src_ok <source> <export>
    [ "$1" = "$NFS_SERVER:$2" ] || [ "$1" = "$NFS_SERVER_IP:$2" ]
}
# Guarda e restaura a configuracao do autofs do cliente (sem tocar no que ja existia).
autofs_save() {  # autofs_save <chave>
    [ -e "$ST/$1.autofs.list" ] && return 0
    { ls -1d /etc/auto.* /etc/auto.master.d/* 2>/dev/null; true; } > "$ST/$1.autofs.list"
    [ -s "$ST/$1.autofs.list" ] && tar cf "$ST/$1.autofs.tar" -T "$ST/$1.autofs.list" 2>/dev/null
    { systemctl is-enabled autofs 2>/dev/null || echo disabled; systemctl is-active autofs 2>/dev/null || echo inactive; } > "$ST/$1.autofs.state"
}
autofs_restore() {  # autofs_restore <chave>
    local f en act
    [ -e "$ST/$1.autofs.list" ] || return 0
    systemctl stop autofs 2>/dev/null
    systemctl reset-failed autofs 2>/dev/null
    for f in /etc/auto.* /etc/auto.master.d/*; do
        [ -e "$f" ] || continue
        grep -qxF "$f" "$ST/$1.autofs.list" && continue
        case "$f" in /etc/auto.?*) rm -rf "$f" ;; esac
    done
    [ -e "$ST/$1.autofs.tar" ] && tar xf "$ST/$1.autofs.tar" -C / && restorecon -R /etc/auto.master /etc/auto.misc /etc/auto.net /etc/auto.smb /etc/auto.master.d 2>/dev/null
    { read -r en; read -r act; } < "$ST/$1.autofs.state"
    [ "$en" = enabled ] || systemctl disable autofs &>/dev/null
    [ "$act" = active ] && systemctl start autofs
    systemctl reset-failed autofs 2>/dev/null
    rm -f "$ST/$1".autofs.*
}

# ---- usuarios, grupos, arquivos, cron (Fase 3: dominios 3 e 8) ---------------------
# Remocao recursiva so' sob areas de pratica conhecidas.
safe_rm() {  # safe_rm <caminho>
    case "$1" in /tmp/?*|/srv/?*|/shared/?*|/var/data/?*|/usr/local/bin/?*|/etc/cron.d/?*|/etc/cron.daily/?*|/etc/cron.hourly/?*|/etc/cron.weekly/?*|/home/?*|/opt/?*|/var/www/?*|/var/log/dyn?*|/etc/dyn?*) rm -rf -- "$1" ;; *) echo "AVISO: remocao fora das areas de pratica ignorada: $1" ;; esac
}
# Cria o usuario (apagando antes qualquer sobra) com senha de exercicio aleatoria.
user_mk() {  # user_mk <usuario> [args do useradd...]
    local u=$1; shift
    user_purge "$u"
    useradd "$@" "$u" || return 1
    echo "$u:$(openssl rand -base64 18)" | chpasswd
}
user_purge() {  # user_purge <usuario>: tira usuario, home, spool de cron e correio
    local u=$1
    id "$u" &>/dev/null && { crontab -r -u "$u" 2>/dev/null; userdel -r -f "$u" 2>/dev/null; }
    getent passwd "$u" &>/dev/null && userdel -f "$u" 2>/dev/null
    case "$u" in [a-z_]?*) safe_rm "/home/${u:?}" ;; esac
    rm -f "/var/spool/mail/${u:?}"
    return 0
}
# Garante um grupo e registra que foi a tarefa quem o criou (so' esses sao removidos no fim).
grp_mk() {  # grp_mk <grupo> [gid]
    getent group "$1" &>/dev/null && return 0
    groupadd ${2:+-g "$2"} "$1" && echo "$1" >> "$ST/$ID.groups"
}
grp_purge() {  # remove os grupos que a tarefa criou
    local g
    [ -f "$ST/$ID.groups" ] || return 0
    while read -r g; do [ -n "$g" ] && groupdel "$g" 2>/dev/null; done < "$ST/$ID.groups"
    rm -f "${ST:?}/${ID:?}.groups"
}
# Campo do /etc/passwd e do /etc/shadow de um usuario.
pw_field() { getent passwd "$1" | cut -d: -f"$2"; }
sh_field() { getent shadow "$1" | cut -d: -f"$2"; }

# Guarda/restaura o crontab de um usuario (inclusive a ausencia dele).
cron_save() {  # cron_save <chave> <usuario>
    [ -e "$ST/$1.cron.saved" ] && return 0
    crontab -l -u "$2" > "$ST/$1.cron" 2>/dev/null || : > "$ST/$1.cron.none"
    : > "$ST/$1.cron.saved"
}
cron_restore() {  # cron_restore <chave> <usuario>
    if [ -e "$ST/$1.cron.none" ]; then crontab -r -u "$2" 2>/dev/null
    elif [ -f "$ST/$1.cron" ]; then crontab -u "$2" "$ST/$1.cron"; fi
    rm -f "${ST:?}/$1.cron" "${ST:?}/$1.cron.none" "${ST:?}/$1.cron.saved"
}
squeeze() { sed -e 's/[[:space:]]\+/ /g' -e 's/^ //' -e 's/ $//'; }
# Cheque comum de scripts: existe, shebang do bash, executavel, sintaxe.
script_checks() {  # script_checks <caminho>
    local f=$1
    [ -f "$f" ]; check $? "o script $f existe"
    head -1 "$f" 2>/dev/null | grep -Eq '^#!(/usr)?/bin/bash|^#!/usr/bin/env bash'; check $? "o script comeca com o shebang do bash"
    [ -x "$f" ]; check $? "o script e executavel"
    bash -n "$f" 2>/dev/null; check $? "o script tem sintaxe valida (bash -n)"
}
# Roda um comando (com timeout) guardando stdout em $OUT, stderr em $ERR e o codigo em $RC.
run_script() {
    OUT=$(timeout 10 "$@" 2>"$ST/.stderr" </dev/null); RC=$?
    ERR=$(cat "$ST/.stderr" 2>/dev/null)
}

# ---- unidades de laboratorio (Fase 4: dominio 6) -----------------------------------
# Servicos e timers de laboratorio (lab*/dyn*) no lugar de servicos reais: nunca se mexe em
# sshd, firewalld etc. Nomes sempre comecam com lab ou dyn.
unit_ok() { case "$1" in lab?*|dyn?*) return 0 ;; *) echo "ERRO: unidade fora do prefixo lab/dyn: $1" >&2; return 1 ;; esac; }
# As unidades de servico ficam em /usr/lib/systemd/system, como as do fornecedor: assim
# "systemctl mask" funciona (ele nao consegue mascarar um arquivo real em /etc/systemd/system)
# e "systemctl edit" cria o drop-in em /etc, exatamente como num servico de verdade.
UNIT_DIR=/usr/lib/systemd/system
unit_mk() {  # unit_mk <nome> <ExecStart> [linha extra da secao [Service]...]  (UNIT_EXTRA = linhas da secao [Unit])
    local n=$1 exec=$2; shift 2
    unit_ok "$n" || return 1
    { printf '[Unit]\nDescription=Servico de laboratorio %s\n' "$n"
      [ -n "${UNIT_EXTRA:-}" ] && printf '%b\n' "$UNIT_EXTRA"
      printf '\n[Service]\nExecStart=%s\n' "$exec"
      local l; for l in "$@"; do printf '%s\n' "$l"; done
      printf '\n[Install]\nWantedBy=multi-user.target\n'; } > "$UNIT_DIR/$n.service"
    systemctl daemon-reload
}
unit_purge() {  # unit_purge <nome>: para, desabilita, desmascara e apaga service/timer/drop-ins
    local n=$1
    unit_ok "$n" || return 1
    systemctl disable --now "$n.timer" 2>/dev/null
    systemctl disable --now "$n.service" 2>/dev/null
    systemctl unmask "$n.service" "$n.timer" 2>/dev/null
    rm -f "/etc/systemd/system/$n.service" "/etc/systemd/system/$n.timer" "$UNIT_DIR/$n.service"
    rm -rf "/etc/systemd/system/${n:?}.service.d" "/etc/systemd/system/${n:?}.timer.d"
    systemctl daemon-reload
    systemctl reset-failed "$n.service" "$n.timer" 2>/dev/null
    return 0
}
# Valor normalizado de uma expressao OnCalendar (aceita formas equivalentes).
cal_norm() { systemd-analyze calendar "$1" 2>/dev/null | awk -F': +' '/Normalized form/{print $2; exit}'; }
# Duracao em microssegundos (aceita 5min, 300s, 5m...).
span_us() { systemd-analyze timespan "$1" 2>/dev/null | awk '/Μs:|μs:/{print $2; exit}'; }
# Valor de uma chave de um arquivo de unidade.
unit_key() {  # unit_key <arquivo> <Chave>
    awk -v k="$2" '{ i=index($0,"="); if (i==0) next; n=substr($0,1,i-1); gsub(/^[ \t]+|[ \t]+$/,"",n); if (n==k) { v=substr($0,i+1); sub(/^[ \t]+/,"",v); print v; exit } }' "$1" 2>/dev/null
}

# ---- SELinux (Fase 4: dominio 7) ----------------------------------------------------
# Remove as regras locais de fcontext que casam com um diretorio.
fcontext_clear() {  # fcontext_clear <diretorio>
    local pat
    semanage fcontext -l -C 2>/dev/null | awk -v d="$1" 'index($1, d)==1 {print $1}' | while read -r pat; do
        semanage fcontext -d "$pat" &>/dev/null
    done
    return 0
}
# Tipo SELinux de um caminho (campo 3 do contexto) e o que a politica define para ele.
ctx_type() { stat -c %C "$1" 2>/dev/null | cut -d: -f3; }
pol_type() { matchpathcon -n "$1" 2>/dev/null | cut -d: -f3; }
# Todos os itens sob o diretorio tem o tipo esperado?
tree_type_ok() {  # tree_type_ok <dir> <tipo>
    [ -d "$1" ] || return 1
    [ "$(find "$1" -exec stat -c %C {} \; 2>/dev/null | cut -d: -f3 | sort -u)" = "$2" ]
}
# Cenario de arquivos: diretorio com 2 arquivos e tipo errado. Lembra o pai se foi a tarefa que o criou.
tree_mk() {  # tree_mk <dir> <tipo errado>
    [ -d "$(dirname "$1")" ] || dirname "$1" > "$ST/$ID.parent"
    mkdir -p "$1"; echo a > "$1/index.html"; echo b > "$1/dados.txt"
    chcon -R -t "$2" "$1"
}
tree_rm() {  # tree_rm <dir>: remove o cenario e o diretorio pai que a tarefa criou (so' se ficou vazio)
    safe_rm "$1"
    if [ -s "$ST/$ID.parent" ]; then rmdir "$(cat "$ST/$ID.parent")" 2>/dev/null; rm -f "${ST:?}/${ID:?}.parent"; fi
}

# ---- firewalld (Fase 4: dominio 7) ----------------------------------------------------
# Guarda toda a configuracao do firewalld e o estado do servico; restaura ao final.
fw_save() {  # fw_save <chave>
    [ -e "$ST/$1.fw.state" ] && return 0
    tar cf "$ST/$1.fw.tar" -C / etc/firewalld
    { systemctl is-enabled firewalld 2>/dev/null || echo disabled; systemctl is-active firewalld 2>/dev/null || echo inactive; } > "$ST/$1.fw.state"
}
fw_restore() {  # fw_restore <chave>
    local en act
    [ -e "$ST/$1.fw.state" ] || return 0
    systemctl stop firewalld 2>/dev/null
    rm -rf /etc/firewalld
    tar xf "$ST/$1.fw.tar" -C /
    restorecon -R /etc/firewalld   # o tar nao guarda o rotulo SELinux: sem isso o firewalld (confinado) nao grava a config
    { read -r en; read -r act; } < "$ST/$1.fw.state"
    [ "$en" = enabled ] && systemctl enable firewalld &>/dev/null || systemctl disable firewalld &>/dev/null
    [ "$act" = active ] && systemctl start firewalld
    rm -f "${ST:?}/$1.fw.tar" "${ST:?}/$1.fw.state"
    return 0
}

# Verificacoes comuns dos timers: arquivos, habilitado, ativo e ExecStart.
timer_files_ok() {  # timer_files_ok <nome> <comando esperado>
    local n=$1 cmd=$2 svc="/etc/systemd/system/$1.service" tmr="/etc/systemd/system/$1.timer"
    [ -f "$svc" ]; check $? "o arquivo $svc existe"
    [ -f "$tmr" ]; check $? "o arquivo $tmr existe"
    [ "$(unit_key "$svc" ExecStart)" = "$cmd" ]; check $? "o ExecStart do servico e: $cmd (atual: $(unit_key "$svc" ExecStart))"
}
timer_state_ok() {  # timer_state_ok <nome>
    [ "$(systemctl is-enabled "$1.timer" 2>/dev/null)" = enabled ]; check $? "o timer $1.timer esta habilitado"
    [ "$(systemctl is-active "$1.timer" 2>/dev/null)" = active ]; check $? "o timer $1.timer esta ativo"
}

# ---- Fase 5: pacotes, repositorios, flatpak e rede -----------------------------
MIRROR=http://content.example.com:8091
RD=/etc/yum.repos.d
# Guarda e restaura os arquivos .repo (remove os criados pelo aluno).
yumrepo_save() {  # yumrepo_save <chave>
    [ -e "$ST/$1.repos.list" ] && return 0
    { ls -1 "$RD"/*.repo 2>/dev/null; true; } > "$ST/$1.repos.list"
    [ -s "$ST/$1.repos.list" ] && tar cf "$ST/$1.repos.tar" -T "$ST/$1.repos.list" 2>/dev/null
    return 0
}
yumrepo_restore() {  # yumrepo_restore <chave>
    local f
    [ -e "$ST/$1.repos.list" ] || return 0
    for f in "$RD"/*.repo; do
        [ -e "$f" ] || continue
        grep -qxF "$f" "$ST/$1.repos.list" || rm -f "$f"
    done
    # o tar nao guarda o rotulo SELinux: restorecon logo em seguida
    [ -e "$ST/$1.repos.tar" ] && tar xf "$ST/$1.repos.tar" -C / && restorecon -R "$RD" 2>/dev/null
    rm -f "$ST/$1.repos.list" "$ST/$1.repos.tar"
    return 0
}
# Repositorio de laboratorio (BaseOS + AppStream do mirror da sala): o servera nao tem
# nenhum repositorio, entao as tarefas de pacote o criam no start e o finish o remove.
lab_mirror_on() {
    cat > "$RD/dyn-lab-mirror.repo" <<REPO
[dyn-lab-baseos]
name=Lab mirror BaseOS
baseurl=$MIRROR/rhel10.0/x86_64/dvd/BaseOS
enabled=1
gpgcheck=0
[dyn-lab-appstream]
name=Lab mirror AppStream
baseurl=$MIRROR/rhel10.0/x86_64/dvd/AppStream
enabled=1
gpgcheck=0
REPO
    restorecon "$RD/dyn-lab-mirror.repo" 2>/dev/null
}
# Valor de uma chave na secao [<id>] de qualquer .repo (a ultima ocorrencia vence).
repo_val() {  # repo_val <id> <chave>
    awk -v id="$1" -v k="$2" '
        FNR==1 {insec=0}
        /^\[/ {insec=($0 == "[" id "]"); next}
        insec && $0 ~ "^[[:space:]]*" k "[[:space:]]*=" {sub(/^[^=]*=[[:space:]]*/, ""); sub(/[[:space:]]+$/, ""); v=$0}
        END {print v}' "$RD"/*.repo 2>/dev/null
}
# Remove a secao [<id>] (e arquivos que ficarem sem nenhuma secao) antes da tarefa.
repo_forget() {  # repo_forget <id>
    local f
    for f in "$RD"/*.repo; do
        [ -e "$f" ] || continue
        grep -qxF "[$1]" "$f" || continue
        awk -v id="$1" '/^\[/ {skip=($0 == "[" id "]")} !skip' "$f" > "$ST/repo.tmp" && cat "$ST/repo.tmp" > "$f"
        rm -f "$ST/repo.tmp"
        grep -q '^\[' "$f" || rm -f "$f"
    done
}
repo_listed() {  # repo_listed <id> [--enabled|--all] : o dnf enxerga o repositorio?
    dnf -q repolist "${2:---enabled}" 2>/dev/null | awk -v id="$1" '$1 == id {f=1} END {exit !f}'
}
repo_works() {  # repo_works <id> : o repositorio responde e tem pacotes
    [ -n "$(dnf -q --disablerepo='*' --enablerepo="$1" list available 2>/dev/null | head -3)" ]
}
# Presenca de um pacote no inicio da tarefa; o finish devolve o estado original.
pkg_orig_save() {  # pkg_orig_save <chave> <pacote>
    [ -e "$ST/$1.pkg" ] && return 0
    { rpm -q "$2" &>/dev/null && echo present || echo absent; } > "$ST/$1.pkg"
}
pkg_orig_restore() {  # pkg_orig_restore <chave> <pacote>  (precisa do repo de laboratorio ligado)
    local o; o=$(cat "$ST/$1.pkg" 2>/dev/null) || return 0
    if [ "$o" = present ]; then rpm -q "$2" &>/dev/null || dnf -y -q install "$2" &>/dev/null
    else ! rpm -q "$2" &>/dev/null || dnf -y -q remove "$2" &>/dev/null; fi
    rm -f "$ST/$1.pkg"
    return 0
}

# Flatpak (so' o servera tem flatpak).
FP_URL=http://flatpak.lab.example.com:8091/myrepo.flatpakrepo
fp_refs() { flatpak list --system --columns=ref 2>/dev/null | sort; }
fp_remote_names() { flatpak remotes --system --columns=name 2>/dev/null | sort; }
fp_remote_has() { fp_remote_names | grep -qxF "$1"; }
# Desfaz o que a tarefa instalou: remove as refs que nao existiam no inicio.
fp_undo() {  # fp_undo <chave> <remote>
    local ref
    if [ -e "$ST/$1.fprefs" ]; then
        for ref in $(fp_refs | comm -13 "$ST/$1.fprefs" -); do
            flatpak uninstall --system -y --noninteractive "$ref" &>/dev/null
        done
        flatpak uninstall --system -y --noninteractive --unused &>/dev/null
    fi
    if [ -e "$ST/$1.fpremote.new" ]; then flatpak remote-delete --system --force "$2" &>/dev/null; fi
    rm -f "$ST/$1.fprefs" "$ST/$1.fpremote.new"
}

# Rede: tudo acontece na interface virtual dyn0 (dummy); a ens18 de gerencia nunca e'
# tocada. Nenhum perfil recebe gateway padrao (so' rotas estaticas), para nao derrubar o SSH.
NETIF=dyn0
net_wipe() {  # remove todo perfil e a interface virtual
    local u
    while read -r u; do [ -n "$u" ] && nmcli con delete uuid "$u" &>/dev/null; done \
        < <(nmcli -g UUID,DEVICE,TYPE con show 2>/dev/null | awk -F: '$2 ~ /^dyn/ || $3 == "dummy" {print $1}')
    for u in $(ip -o link show type dummy 2>/dev/null | awk -F': ' '{print $2}' | grep '^dyn'); do ip link del "$u" &>/dev/null; done
    return 0
}
net_prof() {  # net_prof <perfil> <campo> : valor de um campo do perfil
    nmcli -g "$2" con show "$1" 2>/dev/null | sed 's/\\:/:/g'   # o nmcli escapa os ":" (IPv6)
}
# Cria o perfil de cenario na dyn0: net_mkprof <nome> <manual|auto> <endereco|-> <autoconnect yes|no> <ativar 0|1>
net_mkprof() {
    local a=(ipv4.method "$2" ipv4.never-default yes ipv6.method ignore connection.autoconnect "$4")
    [ "$3" != - ] && a+=(ipv4.addresses "$3")
    nmcli con add type dummy ifname "$NETIF" con-name "$1" "${a[@]}" &>/dev/null || return 1
    [ "$5" = 1 ] && { nmcli con up "$1" &>/dev/null || return 1; }
    return 0
}
net_has_addr() { ip -4 -o addr show dev "$NETIF" 2>/dev/null | grep -q "inet $1 "; }   # net_has_addr <ip/prefixo>
net_is_up() { [ "$(nmcli -g GENERAL.STATE con show "$1" 2>/dev/null)" = activated ]; }

# ---- Fase 6: boot, recuperacao e journal ---------------------------------------
# Nenhuma tarefa reinicia a VM: o grade olha a configuracao (grubby, grub.cfg, fstab...).
# Tudo que toca o carregador de boot e' guardado e devolvido no finish.
BOOTF="/etc/default/grub /boot/grub2/grub.cfg /boot/grub2/grubenv /etc/kernel/cmdline /boot/loader/entries"
boot_save() {  # boot_save <chave>
    [ -e "$ST/$1.boot.tar" ] && return 0
    tar --xattrs --selinux -cf "$ST/$1.boot.tar" $BOOTF 2>/dev/null
    return 0
}
boot_restore() {  # boot_restore <chave>
    [ -e "$ST/$1.boot.tar" ] || return 0
    tar --xattrs --selinux -xf "$ST/$1.boot.tar" -C / 2>/dev/null
    # o tar nao garante o rotulo SELinux: restorecon logo em seguida
    restorecon -R /boot/loader /boot/grub2 /etc/default/grub /etc/kernel 2>/dev/null
    rm -f "$ST/$1.boot.tar"
    return 0
}
kargs() { grubby --info=DEFAULT 2>/dev/null | sed -n 's/^args="\(.*\)"$/\1/p'; }   # argumentos do kernel padrao
karg_has() { case " $(kargs) " in *" $1 "*) return 0 ;; esac; return 1; }
grub_timeout_cfg() { grep -m1 -E '^[[:space:]]*set timeout=' /boot/grub2/grub.cfg 2>/dev/null | sed 's/.*=//'; }
grub_timeout_default() {  # valor efetivo de GRUB_TIMEOUT em /etc/default/grub (a ultima linha ativa vence)
    grep -E '^[[:space:]]*GRUB_TIMEOUT=' /etc/default/grub 2>/dev/null | tail -1 | sed 's/.*=//; s/"//g'
}
grub_regen() { grub2-mkconfig -o /boot/grub2/grub.cfg &>/dev/null; restorecon /boot/grub2/grub.cfg 2>/dev/null; }
# Alvo padrao do systemd: guarda o original e o devolve no finish.
target_save() {  # target_save <chave>
    [ -e "$ST/$1.target" ] || systemctl get-default > "$ST/$1.target"
}
target_restore() {  # target_restore <chave>
    [ -s "$ST/$1.target" ] && systemctl set-default "$(cat "$ST/$1.target")" &>/dev/null
    rm -f "$ST/$1.target"
    return 0
}
# fstab: o finish remove so' as linhas do ponto de montagem da tarefa (outras tarefas podem ter
# linhas proprias), inclusive as que o aluno tenha comentado.
fstab_drop() {  # fstab_drop <ponto-de-montagem> [<dispositivo>]
    awk -v m="$1" -v d="${2:-}" '
        /^[[:space:]]*#/ { if (d != "" && index($0, d)) next; if (index($0, " " m " ")) next; print; next }
        $2 == m { next }
        { print }' /etc/fstab > "$ST/fstab.drop" && cat "$ST/fstab.drop" > /etc/fstab
    rm -f "$ST/fstab.drop"
    systemctl daemon-reload
}
fstab_entry() {  # fstab_entry <ponto-de-montagem> : a linha ativa do ponto (vazio se nao ha)
    awk -v m="$1" '$1 !~ /^#/ && $2 == m {print; exit}' /etc/fstab
}
fstab_has_nofail() {  # fstab_has_nofail <ponto-de-montagem>
    fstab_entry "$1" | awk '{n=split($4, o, ","); for (i = 1; i <= n; i++) if (o[i] == "nofail") f = 1} END {exit !f}'
}
