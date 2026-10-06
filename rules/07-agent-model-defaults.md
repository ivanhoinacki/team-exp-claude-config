---
description: Modelo padrão para toda chamada do Agent tool
alwaysApply: true
---

# Padrões de Modelo para Agentes

TODA chamada do Agent tool DEVE incluir o parâmetro `model`. Sem exceções.

## Mapeamento de tipo de subagente

| subagent_type | model |
|---|---|
| Explore, researcher, reviewer, general-purpose, claude-code-guide, copilot, (vazio) | **haiku** |
| implementer, Plan | **sonnet** |
| qualquer (quando usuário solicita opus explicitamente) | **opus** |
| qualquer (quando usuário solicita fable explicitamente) | **fable** |

Padrão = haiku. Model ausente = bug. Hook `agent-model-guard.sh` garante isso como rede de segurança, mas nunca deveria disparar.

## Quando usar Fable

Fable 5 e otimizado para tarefas complexas e de longa duracao. Indicado para:
- Investigations profundas com muitos arquivos
- Feature-dev com contexto extenso
- Reviews pesados (muitos diffs)
- Refactors que tocam muitos modulos

NAO usar automaticamente. Apenas quando __USER_NAME__ solicitar explicitamente ou trocar via `/model fable`.

## Mapeamento de modelo por skill

Skills definem seu modelo via campo `model:` no frontmatter. Isso muda o modelo da sessão quando a skill é invocada.

| Modelo | Skills |
|---|---|
| **haiku** (2) | commit, create-pr |
| **sonnet** (3) | codereview, feature-dev, handoff |
| **opus** (3) | deslop, investigation, thinking-partner |
| **fable** | (nenhuma por padrao, disponivel sob demanda) |

Atualizada em 28/08/2026 (itens 2.2 e 4.1 do plano): removidas 6 skills que nao existem
mais no disco e incluidas handoff e investigation com modelo declarado. A skill de daily
saiu por decisao D2. Nomes sem crase de proposito: o lint acusa referencia em crase a
skill morta.
