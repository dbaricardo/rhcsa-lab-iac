# Como testar o lab sem subscription (modo offline)

Use quando quiser validar a infraestrutura sem conta Red Hat ou sem gastar
vagas da subscription gratuita (CI, host descartável). Não serve para
estudar com o sistema atualizado: não há updates nem erratas.

Requisito: `RHEL_ISO_PATH` apontando para a **DVD ISO** (não a boot ISO).
`RHSM_*` podem ficar vazias.

## Deploy completo offline

```bash
make check-env
make deploy-offline
```

## Só reaplicar o Ansible em modo offline

Com as VMs já no ar:

```bash
make provision-offline
```

## Encerrar

```bash
make offline-repo-stop   # para o HTTP e desmonta a ISO
```

`make destroy` também chama `offline-repo-stop`.

## Voltar ao modo com subscription

1. Preencha `RHSM_ORG_ID` e `RHSM_ACTIVATION_KEY` no `.env`.
2. Reaplique o Ansible (o lockdown do deploy offline já removeu os repos
   da ISO; este registra cada VM e volta a desligar os repos no fim):

   ```bash
   make provision
   ```

Como funciona por dentro: [Arquitetura](../explanation/arquitetura.md#subscription-e-modo-offline).
