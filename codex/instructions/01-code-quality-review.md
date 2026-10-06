---
description: Regra prioritária de qualidade de código. Aplicar DURANTE o desenvolvimento, não só antes do PR.
alwaysApply: true
---

# Revisão de Qualidade de Código

18 dimensões por função/módulo (ver skill `/codereview` para a lista oficial e níveis de severidade).

Antes do push: corretude? segurança? performance? contratos? financeiro? testes? padrões? env vars?
Antes do PR: executar `/deslop`. Armadilhas em `pitfalls*.md`.

## Captura de Aprendizado ao Aplicar Comentários de PR (OBRIGATÓRIO)

Ao aplicar QUALQUER comentário de review de PR (reviewer humano, bot, ou outra instância de AI), independente da skill ativa:

1. Corrigir o código.
2. Avaliar se o comentário expõe padrão reutilizável: convenção do repo, regra escondida, constraint de negócio, preferência do reviewer, gap de validação.
3. Se sim: append em `~/.agents/skills/codereview/references/learnings.md` E salvar feedback entry na memória do copilot.
4. Se afeta como reviews futuras devem checar código: atualizar também `~/.agents/skills/codereview/references/known-gotchas.md`.

Objetivo: feedback de review vira input de reviews futuras, não fix pontual. Pular este passo = repetir o mesmo erro.

## Reuso dos Aprendizados (OBRIGATÓRIO antes de escrever código)

Antes de escrever ou alterar código em qualquer repo de trabalho (com ou sem skill ativa):

- Checar `~/.agents/skills/codereview/references/known-gotchas.md` nas seções que casam com o domínio do change (input parsing, queries, financial, flags, async, provider sync).
- Scan rápido de `~/.agents/skills/codereview/references/learnings.md` por entradas do repo/serviço alvo. Entradas são indexadas por cliente e repo: não aplicar aprendizado de um cliente em outro sem checar se a convenção é a mesma.
- Consumidores formais: /feature-dev (references), /codereview (Phase 0). Fora de skill, aplicar manualmente.

Ciclo completo: comentário de PR -> fix -> captura (learnings/gotchas/memória) -> reuso no próximo dev/review.
