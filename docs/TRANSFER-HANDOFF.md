# Handoff da atualização temporária

Pedido: atualizar skills, rules e suporte para baixar na máquina da empresa, sem nova versão.

## Entrega

- Branch: `transfer/company-config-20261005`.
- Rules: 9 no pacote anterior, 16 atuais; os 2 nomes substituídos são arquivados na instalação.
- Skills no repositório: 16 anteriores, 18 agora. O modo portátil instala as 8 ativas.
- Agents: 4 antes e depois, atualizados e alinhados ao mapeamento de modelos.
- Instalação portátil: `scripts/install-config.py`, sem alteração de settings, MCPs ou credenciais.
- Wrappers: `setup.sh` e `setup-wsl.sh` aceitam `--config-only`; update segue a branch atual.
- Suporte: README, rules/README, UPDATE-PROMPT, verify-setup, testes e guia COMPANY-MACHINE.
- Skills atualizadas: commit, create-pr, deslop, feature-dev, codereview e thinking-partner.
- Skills adicionadas: investigation e handoff; investigation-case delega à investigação atual.
- Codereview deduplicado: a fonte tinha 2 blocos completos; o pacote contém 1, preservando o rodapé.
- Chrome DevTools permanece padrão. O setup completo não adiciona Playwright MCP genérico.

## Evidência

```text
python3 -m unittest discover -s tests -v
Ran 5 tests ... OK
bash scripts/test-setup.sh
macOS (setup.sh): PASS 179, FAIL 0, Total 179
TEAM_CONFIG_TEST_PLATFORM=linux bash scripts/test-setup.sh
Linux (setup-wsl.sh): PASS 175, FAIL 0, Total 175
scripts/verify-setup.sh em destino isolado:
Verified: 16 rules, 8 active skills, 4 agents (34 instruction files).
bash -n nos scripts/hooks: Shell syntax: passed
Git diff --check: sem saída, exit 0
```

O teste do wrapper Linux foi executado em isolamento no Mac, não em Windows/WSL físico.
Os testes preservaram settings/MCPs e learnings existentes, testaram backup e detectaram drift.

## Limites

Não foram exportados settings privados, credenciais, memória, contextos de clientes ou learnings locais.
A instalação portátil usa apenas instruções reutilizáveis. O conteúdo histórico de LE já público
permanece no repositório; seus dossiês e integrações não são aplicados pelo modo portátil.
Não houve edição na configuração viva ~/.claude, tag, release, merge no main ou deploy de workshops.
O checkout original com 14 arquivos alterados foi preservado.
Na máquina da empresa, resta executar a instalação e abrir uma sessão Claude Code para conferir descoberta.

## Coordenação

Sala: `20261001-220836-iot-c43b`. Pedido e autorização: seqs 253 e 255.
Evidência e revisão: seqs 264, 266, 267, 268 e 270.
Instruções de download, instalação e recuperação: `docs/COMPANY-MACHINE.md`.
