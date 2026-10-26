# Helpers compartilhados pelos scripts de laboratorio.
#
# Motivo de existir: a enumeracao /dev/sd* desta VM ja' inverteu duas vezes
# (31/07 e 02/08). Os scripts fixavam /dev/sdb; se a ordem inverter de novo,
# um 'wipefs -a /dev/sdb' cai no disco do sistema e destroi a serverb.
# Aqui os discos sao resolvidos por PAPEL (nunca o que carrega /) e TAMANHO.

# Caminho do disco que hospeda a raiz, seja ele sda, vda ou o que for.
disco_do_so() {
    lsblk -nsrpo NAME "$(findmnt -no SOURCE /)" | tail -1
}

# $1 = tamanho esperado em GiB. Ecoa o primeiro disco livre desse tamanho.
resolve_disco() {
    local so alvo=$1 d sz
    so=$(disco_do_so)
    for d in $(lsblk -dnpo NAME,TYPE | awk '$2=="disk"{print $1}'); do
        [ "$d" = "$so" ] && continue
        sz=$(( $(blockdev --getsize64 "$d") / 1024 / 1024 / 1024 ))
        [ "$sz" -eq "$alvo" ] && { echo "$d"; return 0; }
    done
    return 1
}

# --- Adicionado para os labs examsim-* de disco (19/20/22) ---
# wipefs sozinho pode deixar assinaturas residuais (ex: assinatura de swap
# sobrevivendo dentro de um LV recem-criado sobre o mesmo disco fisico,
# reciclado de um lab anterior). Zera inicio e fim do disco tambem.
limpa_disco_forte() {
    local disco=$1 size_mb
    wipefs -a "$disco" &>/dev/null
    dd if=/dev/zero of="$disco" bs=1M count=4 &>/dev/null
    size_mb=$(( $(blockdev --getsize64 "$disco") / 1024 / 1024 ))
    dd if=/dev/zero of="$disco" bs=1M seek=$((size_mb - 4)) count=4 &>/dev/null
    partprobe "$disco" &>/dev/null
}

# --- Adicionado para os labs examsim-* (simulado YouTube kBsMuA-DA9E) ---
# Confere se a senha atual do usuario bate com a esperada, recalculando o
# hash do /etc/shadow com o mesmo algoritmo+salt (nao precisa logar nem de
# pacotes extras — usa o modulo crypt do python3, que chama a libcrypt do
# sistema e portanto suporta yescrypt/sha512/o que for o padrao do RHEL).
verifica_senha() {
    local user=$1 senha=$2 hash
    hash=$(getent shadow "$user" 2>/dev/null | cut -d: -f2)
    case "$hash" in
        ''|'!'*|'*') return 1 ;;
    esac
    python3 - "$senha" "$hash" <<'PYEOF' 2>/dev/null
import crypt, sys
senha, hash_atual = sys.argv[1], sys.argv[2]
sys.exit(0 if crypt.crypt(senha, hash_atual) == hash_atual else 1)
PYEOF
}
