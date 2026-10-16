# Como criar um exercício novo

Passo a passo para adicionar um exercício em `labs/`. As regras completas
(campos do `meta.json`, formato da saída do `grade.sh`, helpers de disco)
estão em [Contrato dos exercícios](../reference/contrato-exercicios.md).

## 1. Copie um exercício parecido

```bash
cp -r labs/users-groups-01 labs/meu-exercicio-01     # um host
# ou
cp -r labs/nfs-autofs-01   labs/meu-exercicio-01     # mais de um host
```

## 2. Edite o `meta.json`

- `id` igual ao nome do diretório (`meu-exercicio-01`).
- `number` ainda não usado (veja `lab list` ou
  [o catálogo](../reference/catalogo-exercicios.md)).
- `hosts` na ordem em que `start`/`grade` devem rodar.
- `instructions`: o enunciado, **escrito com suas palavras** — nunca texto
  do RH199 ([por quê](../explanation/direitos-autorais.md)).

## 3. Escreva o `start.sh`

- Prepare só o que o estudante precisa encontrar pronto.
- Faça o script idempotente: teste com `lab start` duas vezes seguidas.
- Precisa de um disco extra? Nunca use `/dev/sdb`:

  ```bash
  source /usr/local/lib/lab-common.sh
  DISCO="$(resolve_disco 6)" || { echo "disco de 6 GB livre não encontrado" >&2; exit 1; }
  ```

## 4. Escreva o `grade.sh`

- Só consulte o estado, nunca altere.
- Uma linha `OK: ...` ou `FALHOU: ...` por critério.
- Termine com exatamente `RESULTADO: PASSOU` ou `RESULTADO: FALHOU`.
- Saia com `0` nos dois casos.
- Não imprima senhas: confira existência e propriedades, não o segredo.

## 5. Escreva o `finish.sh`

- Desfaça explicitamente o que o `start.sh` criou **e** o que o estudante
  pode ter criado (usuários, partições, portas, booleans…).
- Nunca chame o `start.sh` para "limpar".
- Reverta qualquer configuração compartilhada (`httpd.conf`, portas do
  firewall, contextos SELinux).
- Disco que o estudante particionou: use `disco_por_tamanho`, não
  `resolve_disco`, e rode `wipefs -a` nas partições e no disco.

## 6. Escreva a solução de referência

Crie `tests/solutions/meu-exercicio-01.sh`: resolve o exercício como root,
de forma idempotente. É usada só pelo teste de aceitação.

## 7. Gere o catálogo e instale nas VMs

```bash
make catalog
make provision          # ou make provision-offline
```

## 8. Teste o ciclo completo

Na `workstation` (`make ssh-workstation`):

```bash
lab start meu-exercicio-01
lab grade meu-exercicio-01      # deve dar RESULTADO: FALHOU
```

Do host, aplique a solução de referência:

```bash
bash scripts/lab-ssh.sh servera 'sudo bash -s' < tests/solutions/meu-exercicio-01.sh
```

De volta na `workstation`:

```bash
lab grade meu-exercicio-01      # deve dar RESULTADO: PASSOU
lab finish meu-exercicio-01
lab start meu-exercicio-01      # deve funcionar de novo, do zero
```

## 9. Rode o lint

```bash
make lint
```

Antes de publicar, rode a matriz completa num host de teste
([Testes de aceitação](../reference/testes-aceitacao.md)): o T9 testa todos
os exercícios do catálogo.
