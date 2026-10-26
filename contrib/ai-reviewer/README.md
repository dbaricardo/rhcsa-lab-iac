# Revisor por IA (lado do revisor)

Opcional. Só é usado com `AI_REVIEW_ENABLED=true` no `.env`. Esta parte roda num
host **fora do lab** que tenha o [Claude Code CLI](https://docs.claude.com/en/docs/claude-code)
instalado e já autenticado (`claude -p "oi"` precisa funcionar sem pedir nada).

Como funciona: no `lab finish`, a workstation abre um SSH com uma chave dedicada
e envia o JSON da tentativa no stdin. No revisor, essa chave só consegue rodar
`rhcsa-ai-review` (forced command), que chama `claude -p` **sem ferramentas** e
devolve Markdown no stdout.

## Instalação no host revisor

1. Copie `rhcsa-ai-review` para `~/.local/bin/rhcsa-ai-review` (modo 0755) do
   usuário que tem o Claude CLI logado.
2. Rode `make provision` com `AI_REVIEW_ENABLED=true`. O role `ai_review`
   gera a chave `~student/.ssh/rhcsa_ai_review` na workstation e mostra a
   chave pública.
3. No revisor, em `~/.ssh/authorized_keys`, adicione **uma linha** com essa chave:

   ```
   from="<IP de origem da workstation>",command="$HOME/.local/bin/rhcsa-ai-review",restrict ssh-ed25519 AAAA... student@workstation
   ```

   Troque `$HOME` pelo caminho absoluto. A rede do lab usa NAT, então o IP de
   origem é o do host libvirt na sua rede, não `192.168.56.10`.
4. No `.env` do repositório, preencha `AI_REVIEWER=usuario@host` (e, se quiser,
   `AI_REVIEW_TIMEOUT`, padrão 780 s) e rode `make provision` de novo.

## Variáveis opcionais no revisor

| Variável | Padrão | Uso |
|---|---|---|
| `RHCSA_REVIEW_CLAUDE` | `claude` no PATH ou em `~/.local/bin` | caminho do CLI |
| `RHCSA_REVIEW_MODEL` | `sonnet` | modelo passado a `--model` |
| `RHCSA_REVIEW_FALLBACK` | vazio | executável de reserva: recebe o prompt no stdin e o prompt de sistema em `RHCSA_REVIEW_SYSTEM` |

O forced command roda com o ambiente do login SSH. Para definir essas variáveis,
use `command="env RHCSA_REVIEW_MODEL=... /caminho/rhcsa-ai-review"`.

## Teste rápido

Na workstation, como `student`:

```bash
echo '{"task":{"id":"examsim-cron","title":"teste"},"events":[],"transcripts":[]}' \
  | ssh -i ~/.ssh/rhcsa_ai_review usuario@host review
```

Pedidos e respostas ficam em `~/.local/share/rhcsa-ai-review/` no revisor por 30 dias.

## Principais Conclusões

- É opcional. Com tudo desligado, o `lab finish` funciona igual, só sem revisão.
- A chave só executa o revisor (`command=` + `restrict`), e o Claude roda sem ferramentas.
- Desligar uma execução: `RHCSA_AI_REVIEW=0 lab finish <id>`. Desligar a gravação num host: `touch /etc/rhcsa-rec.disabled`.
