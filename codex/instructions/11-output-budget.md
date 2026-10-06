# Output Budget

## File-First (regra dura)

Qualquer entregável com mais de ~15 linhas vai para arquivo, nunca para o chat.
A resposta carrega o path + no maximo 3 bullets.

NUNCA colar inline: documentos, catalogos, tabelas longas, auditorias, planos,
relatorios de investigacao, listas de leads, findings de review, diffs completos.

Destinos:

| Tipo | Destino |
|---|---|
| Trabalho de cliente | o que a camada de contexto do cliente declarar |
| Repo pessoal | `docs/` do proprio repo |
| Analise descartavel | scratchpad da sessao |

Cada cliente declara o proprio destino em `project AGENTS.md`.
Sem destino declarado, perguntar antes de gravar em pasta compartilhada.

**Nunca gravar artefato de um cliente na pasta de outro.** Trabalhando em mais de uma
empresa, isso deixa de ser desorganizacao e vira vazamento.

## Por que

Output longo inline estoura o teto de output da API no meio da renderizacao.
O turno inteiro vira erro, nao truncamento: o trabalho se perde. Arquivo sobrevive.
Isso ja custou mais de 10 sessoes inteiras.

## Fan-out para subagente

Exploracao, auditoria e varredura multi-arquivo rodam em subagente (modelo pela regra 07).
O subagente escreve o artefato em disco e devolve apenas path + 3 bullets.
Output verboso de ferramenta nunca entra no contexto principal.

Gatilhos de fan-out: "audita", "cataloga", "mapeia", "levanta tudo sobre", varredura
de mais de ~5 arquivos, qualquer coisa que produza tabela grande.

## Formato da resposta

- Status primeiro, uma linha.
- Bullets no lugar de prosa.
- Sem recapitular o que acabou de ser lido.
- Sem apendice de "proximos passos" salvo se pedido.
- Codigo no chat: so o trecho que mudou, nunca o arquivo inteiro.
