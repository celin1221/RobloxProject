# REGRAS DO PROJETO

Valem para todo chat que trabalhar neste jogo. Ler antes de qualquer tarefa.

## Antes de começar

1. Executar **`git pull --rebase origin main`** para garantir que o repositório local está sincronizado com os commits mais recentes do parceiro no GitHub (`https://github.com/celin1221/RobloxProject`).
2. Ler `AGENTS.md`, `Blender/GDD.md`, `Blender/REGRAS.md` e `Blender/PROGRESSO.md`.
3. Inspecionar o estado atual do Roblox Studio (`python scripts/sync_studio.py status`) e da pasta `Blender/`. Nunca assumir; verificar.
4. Confirmar que Roblox Studio e Blender respondem pelo MCP. Se algum falhar, parar e avisar.

## Durante o trabalho

- Fazer só o que o prompt pede. **Não refazer, não reverter nem apagar o que já funciona ou o que o parceiro implementou.**
- **Decisões de UI e Mecânicas Protegidas (NUNCA remover):**
  - **Barra de XP / Nível da Conta (`AccountLevelBar` em `TeamBarClient.client.luau`):** fica **obrigatoriamente embaixo da `TeamBar`** (`[ Nv. X ] [=== XP / Meta XP ===]`), alinhada com a largura da barra do time. Nunca mover para o canto direito nem remover.
  - **Recompensas de Nível (`LevelRewardsShrine` perto da Torre + `LevelRewardsGui` + `AccountLevel` + `AccountLevelService`):** árvore sagrada com baús de ouro (`E`) e letreiro flutuante `"RECOMPENSAS DE NÍVEL"` (sem placa de madeira e sem estrelas no texto).
  - **Bônus de Fim de Semana Minimalista (`HudClient.client.luau`):** selo circular discreto no **canto inferior direito** com tooltip `"2x de Moedas"` / `"2x de XP"` ao passar o mouse (`MouseEnter`) ou tocar. Nunca voltar com o banner gigante no topo.
  - **UI `Midnight-Blue Anime` (`UITheme.luau`, `UI.luau`, `TeamCards.luau`, `SummonClient.client.luau`):** paleta azul-noturno profundo, brilho diagonal `UI.sheen` a 38°, afundamento físico 3D nos botões, `[Moeda + Preço]` centralizados em `INVOCAR 1` / `INVOCAR 10` e **zero emojis / zero símbolos Unicode (`★`, `✦`, `✓`, `→`, `■`, `—`)** (usar apenas ícones personalizados de `UI.Icons`).
  - **Auras de Personagens (Minimalismo Permanente):** toda aura deve ser **bonita e minimalista**, sem poluir a tela (sem fitas/orbes/halos exagerados) e **nunca** colocar círculo/disco/vórtice de aura no chão embaixo do pé dos personagens.
  - **Ataques Básicos Compartilhados de Espadachim:** os 2 ataques básicos `CorteBasico` (*Corte Rápido*) e `CorteCruzado` (*Corte Cruzado*) possuem animações e VFX **idênticos para todos os espadachins** (`CombatAnimator.luau` + `VfxController.luau`); cada espadachim adiciona suas 2 habilidades especiais próprias (ex.: Byakuya = `Senbonzakura` e `SenbonzakuraKageyoshi`).
- Valores (dano, preços, chances, atributos) vêm do GDD. Não inventar; se faltar, usar o mais simples e registrar em PROGRESSO.md.
- Todo cálculo de batalha, economia, sorteio e recompensa roda no servidor, com validação de tudo que vem do cliente.
- Efeitos visuais e animações rodam só no cliente.
- Personagens, golpes e itens são definidos só em tabelas de dados (ReplicatedStorage/Data). Adicionar personagem não altera o BattleService.
- **Planilha de Personagens e Ataques obrigatória:** Sempre que adicionar, remover ou alterar qualquer personagem ou ataque/golpe no jogo (`src/shared/Data/Characters.luau` / `Moves.luau`), atualizar todas as tabelas (`Personagens`, `Ataques`, `Golpes` e `Resumo`) rodando `python scripts/update_characters_sheet.py` (sincroniza `Blender/Planilha_Personagens.xlsx` e `Planilha_Personagens.xlsx`).
- Scripts referenciam personagens pelo nome, para o modelo poder ser trocado.
- Personagens sempre originais. Nunca criar personagem ou técnica de anime existente, nem versão reconhecível com nome trocado.
- Para criar personagem, usar a skill `personagem-anime-roblox`.
- Arquivos de personagem e de arte ficam em `C:\Blender`. Nunca sobrescrever: nova versão leva sufixo `_v2`, `_v3`.
- Pensar em celular: interface legível no toque, efeitos dentro dos limites de partículas e luzes.

## Ao terminar

1. Sincronizar com `python scripts/sync_studio.py push`, validar `python scripts/sync_studio.py status` (`100% in sync`) e rodar `python scripts/sync_studio.py test` (`PASS`).
2. Testar no Play e ler o console até não haver erro.
3. Salvar o place.
4. Atualizar `Blender/PROGRESSO.md` (e `Blender/GDD.md` se houver mudança de design): o que foi feito, testado e o que ficou pendente.
5. Fazer **`git add` + `git commit` + `git push origin main`** para que o parceiro e a IA dele já recebam todas as alterações no GitHub.
6. Relatório curto: feito, testado, pendente, o que o usuário precisa fazer.

## Se der errado

- Se algo falhar duas vezes seguidas, parar e relatar em vez de tentar contornar.
- Registrar o erro em "Decisões e pendências" no PROGRESSO.md.
