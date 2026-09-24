# Como escrever um novo exercício em `labs/`

Cada exercício é um diretório `labs/<slug>/` com 4 arquivos:

```
labs/<slug>/
├── meta.json   # metadados consumidos pelo dashboard e pelo dispatcher `lab`
├── start.sh    # prepara o ambiente (idempotente)
├── grade.sh    # avalia, sem alterar nada (não-destrutivo)
└── finish.sh   # limpa (ação inversa explícita do start)
```

Depois de criar/editar um exercício, rode `make catalog` (ou `python3
scripts/build-catalog.py`) para regerar `labs/catalog.json` — é isso que o
dashboard e o `lab` da workstation efetivamente leem.

## `meta.json`

Ver `labs/catalog.schema.json` para o schema completo. Campos obrigatórios:
`id` (igual ao nome do diretório), `number` (único, define a ordem),
`title`, `domain`, `hosts` (lista com `workstation`/`servera`/`serverb`),
`description`, `instructions` (lista de strings). Campos recomendados para
uma boa experiência no dashboard: `warning`, `solve_target`, `solve_method`
(`ssh` ou `console`), `solve_command`, `solve_note`.

## O contrato de saída do `grade.sh` (IMPORTANTE)

O dashboard (`ansible/roles/dashboard/files/backend.py`) faz *parsing* da
saída de texto do `grade.sh` com um formato fixo — sem seguir isso à risca,
o painel mostra "erro de infraestrutura" mesmo com o exercício certo.

- Cada critério avaliado deve ser uma linha própria começando com `OK: ` ou
  `FALHOU: `, seguida da descrição do critério:
  ```
  OK: usuário natasha existe
  FALHOU: grupo sysadmin não contém harry
  ```
- Ao final, exatamente uma linha `RESULTADO: PASSOU` ou `RESULTADO: FALHOU`
  (maiúsculas, sem pontuação extra).
- `grade.sh` deve sair com código 0 tanto se passou quanto se falhou —
  código de saída é sobre a *execução* do grader, não sobre o resultado do
  exercício. Só saia com código != 0 se o próprio grader quebrou (ex.: SSH
  para outro host falhou dentro do multi-host).
- **Exercícios multi-host** (mais de um item em `hosts`): o dispatcher
  `/usr/local/bin/lab` na workstation já imprime, para cada host, uma linha
  `==> lab grade <id> (host)` antes de rodar o grade daquele host — é essa
  linha que reseta o parser do dashboard entre um host e outro. Você não
  precisa (nem deve) imprimir esse banner dentro do seu `grade.sh` — ele já
  roda uma vez por host automaticamente. Só garanta que CADA host emita seu
  próprio conjunto de `OK:`/`FALHOU:` + uma linha `RESULTADO:` própria.

`start.sh` e `finish.sh` não precisam desse formato — só precisam sair com
código 0 em sucesso. `finish.sh` pode opcionalmente reportar um
`RESULTADO:` se fizer sentido reavaliar após a limpeza, mas normalmente só
limpa e sai 0.

## Regras não-negociáveis (bugs já descobertos em produção real)

1. **`finish.sh` nunca reinvoca `start.sh`** para "limpar". `start.sh` é
   idempotente e pode *recriar* o estado em vez de removê-lo — isso já
   causou contaminação cruzada entre exercícios 3 vezes. `finish.sh` precisa
   ser a ação inversa explícita (ex.: se `start.sh` cria um usuário,
   `finish.sh` remove esse usuário — não chama `start.sh` de novo).
2. **Nunca referencie `/dev/sdb`/`/dev/sdc` (ou qualquer nome de disco
   fixo)**. A ordem de enumeração já inverteu entre boots em produção real.
   Se seu exercício precisa de um disco extra, faça
   `source /usr/local/lib/lab-common.sh` e use `resolve_disco <tamanho_gb>`.
3. **Se seu exercício toca uma porta/config compartilhada** (o exemplo
   clássico é `httpd.conf`, usado por vários exercícios de rede/SELinux),
   `finish.sh` precisa reverter explicitamente essa configuração — nunca
   deixe o próximo exercício herdar estado de sujeira do anterior.
4. **`start.sh` deve ser idempotente**: rodar `lab start <id>` duas vezes
   seguidas não deve quebrar nada (o estudante pode reiniciar a tentativa).
5. **Nunca inclua o texto do livro RH199** (nem enunciado nem solução
   literal) — ver `docs/copyright-notice.md`. Escreva cenários e descrições
   com suas próprias palavras, cobrindo o mesmo domínio público do blueprint
   EX200.

## Redação de senhas/segredos na saída

O dashboard redige automaticamente linhas com `senha`/`password`/`token`/
`private key` antes de persistir no banco — mas evite de qualquer forma
imprimir segredos reais no `grade.sh`; prefira comparar hashes ou apenas
confirmar existência/propriedades do objeto (usuário existe, grupo correto,
etc.) sem ecoar a senha em si.

## Exemplos de referência

- `labs/users-groups-01/` — exercício simples, single-host (`servera`).
- `labs/nfs-autofs-01/` — exercício multi-host (`servera` exporta,
  `serverb` automonta), mostra como estruturar hosts múltiplos.
