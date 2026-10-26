
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
