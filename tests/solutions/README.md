# tests/solutions/

Uma solução de referência por exercício em `labs/`, usada **só** pelo
[teste de aceitação](../acceptance/run-all.sh) para validar que o próprio
`grade.sh` de cada exercício reconhece um ambiente corretamente resolvido
(hoje só é validado o caminho FALHOU, com o ambiente intocado).

Não fazem parte do fluxo normal de um estudante -- resolver o exercício é o
propósito do curso. Cada `<lab>.sh` aqui é idempotente e roda como root no(s)
host(s) do exercício (`meta.json` -> `hosts`), por exemplo:

```bash
vagrant ssh servera -c 'sudo bash -s' < tests/solutions/users-groups-01.sh
```

Exercícios com mais de um host (`nfs-autofs-01`) esperam ser chamados uma vez
por host, na ordem `servera` depois `serverb` -- o script detecta o host via
`hostname -s`, igual ao próprio `start.sh`/`grade.sh` do exercício.
