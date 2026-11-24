# AGENTS.md — Regras de Arquitetura e Operação para Agentes de IA (`RobloxProjetoX`)

Este arquivo é lido automaticamente por qualquer Agente de IA que trabalhe neste repositório. **Toda modificação de código, modelo 3D, UI, VFX ou mapa deve obedecer estritamente a estas regras.**

---

## 1. Fontes da Verdade e Sincronização Colaborativa (2 Devs + Disk-First + GitHub)

> **ATENÇÃO AGENTES DE IA (REGRA DE OURO DE COLABORAÇÃO):**
> Este jogo é desenvolvido simultaneamente por **2 desenvolvedores no mesmo Place (TeamCreate) e no mesmo repositório GitHub (`https://github.com/celin1221/RobloxProject`)**.
> Para que a IA de um desenvolvedor **NUNCA apague, reverta ou sobrescreva** o que o outro desenvolvedor fez:
> 1. **ANTES de iniciar qualquer tarefa:** execute obrigatoriamente **`git pull --rebase origin main`** para baixar os commits mais recentes do parceiro e releia `AGENTS.md` e `Blender/PROGRESSO.md`.
> 2. **ANTES de rodar `sync_studio.py push`:** execute **`python scripts/sync_studio.py status`**. Se algum script estiver `MODIFIED` no Studio e você ainda não o editou localmente, verifique se foi atualizado no GitHub (`git pull`) antes de sobrescrever.
> 3. **AO CONCLUIR qualquer tarefa:** atualize `src/` e a documentação (`Blender/GDD.md`, `Blender/PROGRESSO.md`, `ARQUITETURA_PROJETO.md`, `HANDOFF_CONTEXTO.md`), faça **`git add` + `git commit` + `git push origin main`** imediatamente para que o contexto da IA do parceiro fique 100% atualizado.

1. **`Blender/GDD.md` é a Lei de Design:** Em caso de conflito entre qualquer prompt e o GDD, prevalece [`Blender/GDD.md`](./Blender/GDD.md) (versão atualizada com Mapa V2, 10 bases, Esteira, Estrelas de Invocação, Palco 3D, Classes de Combate, Ginásios, Batalhas 2x2, Nível da Conta, Bônus Minimalista, Tema Midnight-Blue Anime e Seção 14 - Refúgio).
2. **`Blender/REGRAS.md` e `Blender/PROGRESSO.md` são os Registros de Controle:**
   * Antes de iniciar uma tarefa, consulte [`Blender/REGRAS.md`](./Blender/REGRAS.md) e [`Blender/PROGRESSO.md`](./Blender/PROGRESSO.md).
   * Arquivos de modelos 3D, texturas, animações e ícones ficam em `Blender/` (nunca sobrescrever versões anteriores: usar sufixo `_v2`, `_v3`).
   * Ao concluir uma entrega, atualizar `Blender/PROGRESSO.md` com o que foi feito, testado e pendências.
3. **`ARQUITETURA_PROJETO.md` é a Lei de Engenharia:** Consulte [`ARQUITETURA_PROJETO.md`](./ARQUITETURA_PROJETO.md) para entender o papel de cada módulo e camada.
4. **`src/` no Disco + GitHub (`origin/main`) é a Fonte da Verdade do Código:**
   * **PROIBIDO** editar código diretamente no Roblox Studio sem atualizar o arquivo correspondente em `src/` e fazer `git push`.
   * Fluxo obrigatório para qualquer alteração de código:
     1. Executar `git pull --rebase origin main`.
     2. Editar o arquivo `.luau` em `src/`.
     3. Executar `python scripts/sync_studio.py push` para enviar ao Roblox Studio.
     4. Executar `python scripts/sync_studio.py status` (deve reportar `All 92 scripts in src/ are 100% in sync`).
     5. Executar `python scripts/sync_studio.py test` para rodar a suíte de validação rápida no Studio.
     6. Executar `git add`, `git commit` e `git push origin main`.

---

## 2. Mapa das 4 Camadas e Fronteiras de Escrita (Write Boundaries)

Cada subagente ou tarefa deve respeitar o isolamento de camadas:

| Camada | Pasta no Disco (`src/`) | Destino no Studio | O que PODE fazer | O que é PROIBIDO |
| :--- | :--- | :--- | :--- | :--- |
| **1. Data** | `src/shared/Data/*.luau` | `ReplicatedStorage/Data` | Declarar tabelas estáticas de personagens, golpes, tipos, itens, lojas, drops e taxas. | Usar estado mutável, chamar `RemoteEvent` ou `ServerScriptService`. |
| **2. Core** | `src/shared/Core/*.luau` | `ReplicatedStorage/Core` | Lógica matemática pura e máquina de estados (`BattleEngine`, `DamageCalc`, `AIController`). | Tocar em `Workspace`, `Players`, `RemoteEvent`, `TweenService` ou `task.wait`. |
| **3. Server** | `src/server/**/*.luau` | `ServerScriptService` | Validar inputs de clientes, gerenciar sessões/arenas (`ArenaManager`, `BattleService`), salvar dados (`PlayerDataService`), gerar RNG e recompensas. | Construir `ScreenGui` ou confiar em valores calculados pelo cliente. |
| **4. Client** | `src/client/**/*.luau` e `src/shared/UI*.luau` | `StarterGui` / `StarterPlayerScripts` | Renderizar janelas usando `ReplicatedStorage.UI`, tocar sons/VFX (`VfxController`) e enviar escolhas via `ReplicatedStorage.Net`. | Decidir dano, alterar gold/gemas localmente ou validar compras. |

---

## 3. Ferramentas Conectadas (Roblox Studio MCP + Blender)

* **Roblox Studio MCP (`studio_mcp.py`):**
  * Caminho do cliente direto: `python roblox-ai-skills-main/skills/create-roblox-game/scripts/studio_mcp.py`
  * Sempre use `--dm Edit` ao inspecionar ou sincronizar fora do modo Play.
* **Blender (`D:\Blender\blender.exe`):**
  * Versão instalada: **Blender 5.3.0** (`D:\Blender\blender.exe`).
  * Usado em modo headless (`--background --python ...`) pelas skills `roblox-3d-model`, `roblox-animation` e `roblox-vfx`.
* **Sincronizador Oficial do Projeto (`scripts/sync_studio.py`):**
  * `python scripts/sync_studio.py status` — Verifica se todos os 92 scripts de `src/` estão idênticos ao Studio.
  * `python scripts/sync_studio.py push` — Atualiza o Studio com as mudanças feitas em `src/`.
  * `python scripts/sync_studio.py test` — Executa os testes de validação do GDD (fórmula de dano, 1x1, 2x2, Classes, Ginásios, Treino, Progressão e `AccountLevel`).

---

## 4. Sistemas e Decisões Visuais Protegidos (PROIBIDO REMOVER OU REVERTER)

Qualquer Agente de IA trabalhando neste projeto **DEVE preservar integralmente** as seguintes decisões de design já implementadas e aprovadas:

1. **Barra de Experiência / Nível da Conta (`AccountLevelBar` em `src/client/Gui/TeamBarGui/TeamBarClient.client.luau`):**
   * A barra de XP e Nível da Conta fica **obrigatoriamente embaixo da `TeamBar`** (barra de personagens do jogador na parte inferior central da tela), alinhada exatamente com as bordas esquerda e direita da `TeamBar` (`L:+0, R:+0`).
   * Formato aprovado (estilo *Anime Vanguards* / `roblox-ui`): pílula esquerda `LevelPill` (`"Nv. X"`) + barra direita `XpTrack` (`"X / Y XP"`), sem estrelas ou baús pendurados na barra.
   * **PROIBIDO** remover a `AccountLevelBar` de `TeamBarClient.client.luau` ou movê-la para o canto superior direito do `HudClient.client.luau`.
2. **Santuário 3D e HUD de Recompensas de Nível (`LevelRewardsShrine` + `LevelRewardsGui` + `AccountLevel` + `AccountLevelService`):**
   * No mapa (`Workspace.Map.LevelRewardsShrine`, perto da Torre em `(40, 8.3, 31.5)`): grande árvore sagrada com 3 baús de ouro (`LevelRewardsPrompt`, tecla `E`) e letreiro flutuante `"RECOMPENSAS DE NÍVEL"` (sem placa de madeira física e sem estrelas no texto).
   * Ao interagir com `E`, abre `StarterGui.LevelRewardsGui.LevelRewardsClient` com recompensas de todos os níveis (1..50+, marcos Épicos a cada 5 e Lendários a cada 10) e botão `RESGATAR TUDO`.
3. **Bônus de Fim de Semana Minimalista (`src/client/Gui/HudGui/HudClient.client.luau` + `RewardsClient.client.luau`):**
   * O evento de fim de semana fica **obrigatoriamente no canto inferior direito da tela** como um selo circular discreto (`Badge` com ícone `coin` ou `sparkle`) que exibe a pílula de tooltip `"2x de Moedas"` ou `"2x de XP"` apenas quando o jogador passa o mouse por cima (`MouseEnter`) ou toca no celular.
   * **PROIBIDO** voltar com o banner grande de evento no topo da tela.
4. **Interface `Midnight-Blue Anime` + Zero Emojis / 100% Ícones Personalizados (`UITheme.luau`, `UI.luau`, `TeamCards.luau`, `SummonClient.client.luau`):**
   * Paleta azul-noturno profundo (`panel` `#273066 -> #161B3D`, `panelAlt` `#36428A -> #212859`, `slot` `#191E42 -> #0F122B`, `header` `#3B9EFF -> #1B64D8`, `Outline` `#0B0E22`).
   * Brilho diagonal de 3 bandas a 38° (`UI.sheen`), afundamento físico 3D nos botões (`pressFace`), contorno de texto `Bevel` e centralização matemática dinâmica (`TextBounds.X`) de `[Moeda + Preço]` dentro dos botões `INVOCAR 1` e `INVOCAR 10` (e `Icon.ZIndex = baseZ + 3` em `UI.pill`).
   * **PROIBIDO usar emojis ou símbolos Unicode (`★`, `✦`, `✓`, `→`, `■`, `—`)** em textos de UI: usar sempre os ícones personalizados de `UI.Icons`.
5. **Auras 3D dos Personagens (`AuraVfx` / `CharacterAuraClient`):**
   * **PROIBIDO** colocar círculos, discos ou vórtices de aura no chão/pé dos personagens (`San`, `Setero`, `BarbaBranca` e futuros personagens).
