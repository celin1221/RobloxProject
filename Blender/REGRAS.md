# REGRAS DO PROJETO

Valem para todo chat que trabalhar neste jogo. Ler antes de qualquer tarefa.

## Antes de começar

1. Ler `C:\Blender\GDD.md`, `C:\Blender\REGRAS.md` e `C:\Blender\PROGRESSO.md`.
2. Inspecionar o estado atual do Roblox Studio (pastas, scripts, modelos) e da pasta `C:\Blender`. Nunca assumir; verificar.
3. Confirmar que Roblox Studio e Blender respondem pelo MCP. Se algum falhar, parar e avisar.

## Durante o trabalho

- Fazer só o que o prompt pede. Não refazer nem apagar o que já funciona.
- Valores (dano, preços, chances, atributos) vêm do GDD. Não inventar; se faltar, usar o mais simples e registrar em PROGRESSO.md.
- Todo cálculo de batalha, economia, sorteio e recompensa roda no servidor, com validação de tudo que vem do cliente.
- Efeitos visuais e animações rodam só no cliente.
- Personagens, golpes e itens são definidos só em tabelas de dados (ReplicatedStorage/Data). Adicionar personagem não altera o BattleService.
- Scripts referenciam personagens pelo nome, para o modelo poder ser trocado.
- Personagens sempre originais. Nunca criar personagem ou técnica de anime existente, nem versão reconhecível com nome trocado.
- Para criar personagem, usar a skill `personagem-anime-roblox`.
- Arquivos de personagem e de arte ficam em `C:\Blender`. Nunca sobrescrever: nova versão leva sufixo `_v2`, `_v3`.
- Pensar em celular: interface legível no toque, efeitos dentro dos limites de partículas e luzes.

## Ao terminar

1. Testar no Play e ler o console até não haver erro.
2. Salvar o place.
3. Atualizar `PROGRESSO.md`: o que foi feito, testado e o que ficou pendente.
4. Relatório curto: feito, testado, pendente, o que o usuário precisa fazer.

## Se der errado

- Se algo falhar duas vezes seguidas, parar e relatar em vez de tentar contornar.
- Registrar o erro em "Decisões e pendências" no PROGRESSO.md.
