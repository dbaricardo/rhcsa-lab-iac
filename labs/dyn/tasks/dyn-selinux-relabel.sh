# Dominio 7 / selinux: agendar o relabel completo no proximo boot. Sem params
ID=dyn-selinux-relabel
do_start() { rm -f /.autorelabel; echo "/.autorelabel nao existe."; }
do_grade() { [ -e /.autorelabel ]; check $? "o arquivo /.autorelabel existe (relabel completo agendado para o proximo boot)"; }
# O arquivo dispara um relabel de TODO o sistema no proximo boot: precisa sumir na limpeza.
do_finish() { rm -f /.autorelabel; echo "limpeza: /.autorelabel removido (nenhum relabel sera disparado)."; }
run "$@"
