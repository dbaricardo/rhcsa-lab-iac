# Dominio 1 / packages: remover pacote com dnf. Params: PKG
ID=dyn-pkg-remove
do_start() {
    yumrepo_save "$ID"; lab_mirror_on
    pkg_orig_save "$ID" "$PKG"
    rpm -q "$PKG" &>/dev/null || dnf -y -q install "$PKG" &>/dev/null
    if ! rpm -q "$PKG" &>/dev/null; then echo "ERRO: nao consegui instalar $PKG antes da tarefa"; return 1; fi
    echo "pacote $PKG instalado."
}
do_grade() {
    ! rpm -q "$PKG" &>/dev/null; check $? "o pacote $PKG foi removido (rpm -q nao o encontra)"
}
do_finish() {
    lab_mirror_on
    pkg_orig_restore "$ID" "$PKG"
    rm -f "$RD/dyn-lab-mirror.repo"
    yumrepo_restore "$ID"
    echo "limpeza: estado original de $PKG e dos repositorios restaurado."
}
run "$@"
