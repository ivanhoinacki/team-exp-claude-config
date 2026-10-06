---
description: Todos os diagramas usam PlantUML, nunca Mermaid ou ASCII
alwaysApply: true
---

# Diagramas

Somente PlantUML. Todo doc com mudanca de fluxo/arquitetura/dados DEVE ter diagramas.
Obsidian: blocos ` ```plantuml `, nunca PNG. GitHub: codificar via `plantuml_encode.py`. Sempre EN.
Base: `!theme plain`, `skinparam shadowing false`.

NUNCA declarar `skinparam backgroundColor`. O plugin do Obsidian troca para o endpoint
`/dsvg/` no tema escuro: ele inverte o desenho mas respeita o background fixo, e sobra
traco claro em fundo branco. Sem a linha, o fundo acompanha o tema nos dois lados
(medido em 31/08/2026).
