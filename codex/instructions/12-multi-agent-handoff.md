# Protocolo Multi-Agente

Vale sempre que outro agente compartilha o workspace: `/handoff`, Codex no mesmo repo,
outra instancia Claude no mesmo arquivo. Independe de cliente.

## Claim antes de escrever

Reivindicar posse antes de editar arquivo compartilhado. Revalidar o claim
imediatamente antes da PRIMEIRA escrita, nao so no bootstrap. Passa tempo entre
reivindicar e editar, e nesse intervalo o outro agente pode ter assumido.

## Perder a corrida NAO e condicao de parada

Nunca ficar ocioso, nunca desistir em silencio. Nesta ordem:

1. Reivindicar a proxima task nao reivindicada do board.
2. Sem task livre: validacao read-only da saida do dono, postar findings.
3. Nada a validar: consolidar plano/contexto em arquivo e reportar o path.

Sempre reportar qual fallback foi usado e por que. Sessao que termina com
"perdi o claim, nao fiz nada" e sessao falhada.

## Jobs em background

NUNCA iniciar job de background (watcher, reprocess, sync, deploy) que escreve em
path de outro agente. Escritor em background so opera em path proprio.
Mudou a posse, mata o job.

## Recursos compartilhados

Aplicativos, perfis de navegador e jobs de escrita têm um único dono durante a execução.
Não operar nem reiniciar recursos que outro agente está usando sem coordenar.
Decisões e evidência vão no canal de coordenação definido pelo projeto.
Se não há Radar/board configurado, declarar ownership no canal disponível.
