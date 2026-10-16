# Como usar Rocky Linux 10 no lugar do RHEL 10 (não testado)

Use só para testar a mecânica da infraestrutura (Terraform, rede, discos,
dashboard) sem ISO RHEL. **Este caminho não é validado** pela homologação do
projeto; espere ajustar detalhes. Para estudar para o EX200, use RHEL 10
real ([por quê](../explanation/arquitetura.md#rhel-10-real-não-uma-distribuição-derivada)).

## 1. Aponte a ISO

No `.env`, `RHEL_ISO_PATH` recebe a DVD ISO x86_64 do Rocky Linux 10.
Deixe `RHSM_ORG_ID` e `RHSM_ACTIVATION_KEY` vazias.

## 2. Ajuste o `--os-variant`

Descubra a variante do Rocky no `osinfo-db` do host:

```bash
osinfo-query os | grep -i rocky
```

Troque `rhel10-unknown` pelo valor encontrado em `scripts/build-image.sh`.

## 3. Revise o `%post` do kickstart

Em `kickstart/ks.cfg.tpl`, a importação da 4ª chave GPG da Red Hat é
específica do RHEL 10. Remova ou adapte esse trecho para o Rocky. O resto
(usuário `student`, `truncate /etc/machine-id`) deve funcionar igual.

## 4. Faça o deploy em modo offline

O role `common` exige subscription fora do modo offline, e o Rocky não usa
`subscription-manager`:

```bash
make check-env
make deploy-offline
```

## 5. Confira os pacotes

Os roles (`common`, `servera`, `serverb`, `workstation`) usam nomes de
pacote do RHEL 10 (`policycoreutils-python-utils`, `setroubleshoot-server`
etc.). No Rocky devem ser iguais, mas se o Ansible falhar num `dnf`, o nome
do pacote é o primeiro suspeito.
