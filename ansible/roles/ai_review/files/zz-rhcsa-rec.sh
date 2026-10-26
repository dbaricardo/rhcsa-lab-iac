# /etc/profile.d/zz-rhcsa-rec.sh — grava sessões interativas para a revisão por IA
# do lab RHCSA (substitui o tlog, que não existe no RHEL 10). Só grava a saída do
# terminal (o que aparece na tela); senhas digitadas sem eco não entram.
# Arquivos: /var/log/rhcsa-rec/<epoch>-<usuário>-<pid>.{out,tm}; limpeza em 14 dias
# por /etc/tmpfiles.d/rhcsa-rec.conf. Desligar: touch /etc/rhcsa-rec.disabled
if [ -z "${RHCSA_REC:-}" ] && [ -x /usr/bin/script ] && [ -d /var/log/rhcsa-rec ] &&
   [ ! -e /etc/rhcsa-rec.disabled ] && [[ $- == *i* ]] && [ -t 0 ] && [ -t 1 ]; then
    # Não aninha: su -/sudo -i dentro de uma sessão já gravada limpam o ambiente,
    # então a checagem real é por um ancestral "script".
    __rr_p=$PPID __rr_nested=
    while [ "${__rr_p:-1}" -gt 1 ]; do
        [ "$(cat /proc/$__rr_p/comm 2>/dev/null)" = script ] && { __rr_nested=1; break; }
        __rr_p=$(awk '{print $4}' /proc/$__rr_p/stat 2>/dev/null)
    done
    if [ -z "$__rr_nested" ]; then
        __rr_f="/var/log/rhcsa-rec/$(date +%s.%N)-$(id -un)-$$"
        # Cria os arquivos com 0600 sem mexer no umask da sessão (os labs avaliam umask).
        if (umask 077; : > "$__rr_f.out" && : > "$__rr_f.tm") 2>/dev/null; then
            export RHCSA_REC=1
            # O filho continua sendo shell de login: ~/.bash_profile e logout funcionam
            # como sem gravação (tarefas da prova mexem nesses arquivos).
            exec /usr/bin/script -q -f -O "$__rr_f.out" -T "$__rr_f.tm" -c 'exec -l "$SHELL"'
        fi
    fi
    unset __rr_p __rr_nested __rr_f
fi
