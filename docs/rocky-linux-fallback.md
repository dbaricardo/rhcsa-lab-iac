# Fallback com Rocky Linux 10 (não é o caminho testado)

Este projeto foi desenhado e testado contra o **RHEL 10 real**, registrado
via Red Hat Developer Subscription for Individuals (gratuita), porque o
objetivo é praticar para um exame (RHCSA/EX200) aplicado sobre RHEL de
verdade — inclusive comportamentos que só existem por causa do registro da
subscription (repositórios, `insights-client`, o bug de GPG da 4ª chave de
release, etc.).

Ainda assim, como `servera`/`serverb`/`workstation` rodam praticamente
qualquer coisa compatível com RHEL na prática (usuários, storage, systemd,
SELinux, firewalld, NFS), é razoável querer usar **Rocky Linux 10** como
substituto quando não se tem (ou não se quer usar) uma ISO RHEL — por
exemplo, para testar a infraestrutura sem consumir um dos slots da
subscription gratuita.

## Aviso

**Este caminho não é mantido com o mesmo rigor do RHEL10 real.** Não há
pipeline de validação rodando contra Rocky, e o restante desta documentação
(troubleshooting, tutorial) assume RHEL10. Use por sua conta e risco e
espere ajustar detalhes.

## O que precisa mudar

1. **`.env` / `RHEL_ISO_PATH`**: apontar para uma ISO do Rocky Linux 10
   (x86_64, DVD) em vez da ISO RHEL. `RHSM_ORG_ID` e `RHSM_ACTIVATION_KEY`
   deixam de fazer sentido, já que Rocky não usa `subscription-manager`.

2. **`kickstart/ks.cfg.tpl`**: o bloco `%post` de
   `subscription-manager register --org=... --activationkey=...` precisa
   ser **pulado inteiramente** — Rocky não tem (nem precisa de) registro de
   subscription. O restante do `%post` (importação da 4ª chave GPG, criação
   do usuário `student`, `truncate /etc/machine-id`) é específico do RHEL10
   e pode não se aplicar da mesma forma ao Rocky 10 — revise antes de usar.

3. **`--os-variant`** em `scripts/build-box.sh`: `rhel10-unknown` deve ser
   troncado para a variante correta do Rocky no `osinfo-db` do seu host
   (verifique com `osinfo-query os | grep -i rocky`).

4. **Nomes de pacotes**: os roles Ansible (`common`, `servera`, `serverb`,
   `workstation`) assumem os nomes de pacote do RHEL10
   (`policycoreutils-python-utils`, `setroubleshoot-server`, etc.) — no
   Rocky 10 eles devem ter os mesmos nomes (é um rebuild binário do RHEL),
   mas isso não foi validado neste projeto.

## Recomendação

Se o objetivo final é praticar para o EX200, use RHEL10 real — é gratuito
via Red Hat Developer Subscription for Individuals e elimina qualquer
divergência de comportamento entre distribuições. Use Rocky apenas para
testar a mecânica da infraestrutura (Vagrant, rede, discos extra, dashboard)
sem gastar um slot de sistema registrado.
