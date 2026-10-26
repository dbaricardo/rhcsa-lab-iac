# Como operar o lab no dia a dia

Tarefas comuns depois do primeiro deploy. Lista completa de alvos em
[Referência do Makefile](../reference/makefile.md).

## Ver o estado e a URL do dashboard

```bash
make status
```

## Entrar numa VM

```bash
make ssh-workstation      # ou ssh-servera / ssh-serverb
```

Para rodar um comando sem abrir shell:

```bash
bash scripts/lab-ssh.sh servera 'sudo systemctl status sshd'
```

## Reaplicar a configuração (Ansible)

Depois de mudar um role, um exercício em `labs/` ou o `.env`:

```bash
make provision            # ou make provision-offline
```

É idempotente: só altera o que estiver diferente.

## Mudar a topologia (RAM, CPU, IPs, discos)

1. Edite `machines.yaml`.
2. Aplique a infraestrutura e depois a configuração:

   ```bash
   make infra
   make provision
   ```

Mudanças em disco ou rede podem recriar a VM — trate como deploy novo.

## Reconstruir a imagem golden

Necessário depois de mudar `kickstart/ks.cfg.tpl`, `image/finalize.sh` ou a
ISO:

```bash
make build-image          # sempre reconstrói (~10 min)
make destroy && make deploy
```

`make deploy` sozinho **não** reconstrói uma imagem que já existe.

## Destruir e recriar o lab

1. (Opcional, recomendado com subscription) Libere as vagas na Red Hat:

   ```bash
   for h in workstation servera serverb; do
     bash scripts/lab-ssh.sh "$h" 'sudo subscription-manager unregister' || true
   done
   ```

2. Destrua VMs, discos e rede (a imagem golden fica):

   ```bash
   make destroy
   ```

3. Para voltar a estudar: `make deploy` (pula o build da imagem).

## Recomeçar um exercício do zero

Na `workstation`:

```bash
lab finish <id>
lab start <id>
```

## Validar o projeto depois de alterações

```bash
make lint
make test-dashboard
bash tests/acceptance/run-all.sh   # só em host de teste: destrói e recria o lab
```

Detalhes da matriz em [Testes de aceitação](../reference/testes-aceitacao.md).
