# AGENTS.md — Regras de Arquitetura e Operação para Agentes de IA (`RobloxProjetoX`)

Este arquivo é lido automaticamente por qualquer Agente de IA que trabalhe neste repositório. **Toda modificação de código, modelo 3D, UI, VFX ou mapa deve obedecer estritamente a estas regras.**

---

## 1. Fontes da Verdade e Sincronização (Disk-First)

1. **`Blender/GDD.md` é a Lei de Design:** Em caso de conflito entre qualquer prompt e o GDD, prevalece [`Blender/GDD.md`](./Blender/GDD.md) (versão atualizada com Mapa V2, 10 bases, Esteira, Estrelas de Invocação, Doces de XP e Seção 14 - Refúgio).
2. **`Blender/REGRAS.md` e `Blender/PROGRESSO.md` são os Registros de Controle:**
   * Antes de iniciar uma tarefa, consulte [`Blender/REGRAS.md`](./Blender/REGRAS.md) e [`Blender/PROGRESSO.md`](./Blender/PROGRESSO.md).
   * Arquivos de modelos 3D, texturas, animações e ícones ficam em `Blender/` (nunca sobrescrever versões anteriores: usar sufixo `_v2`, `_v3`).
   * Ao concluir uma entrega, atualizar `Blender/PROGRESSO.md` com o que foi feito, testado e pendências.
3. **`ARQUITETURA_PROJETO.md` é a Lei de Engenharia:** Consulte [`ARQUITETURA_PROJETO.md`](./ARQUITETURA_PROJETO.md) para entender o papel de cada módulo e camada.
4. **`src/` no Disco é a Fonte da Verdade do Código:**
   * **PROIBIDO** editar código diretamente no Roblox Studio sem atualizar o arquivo correspondente em `src/`.
   * Fluxo obrigatório para qualquer alteração de código:
     1. Editar o arquivo `.luau` em `src/`.
     2. Executar `python scripts/sync_studio.py push` para enviar ao Roblox Studio.
     3. Executar `python scripts/sync_studio.py status` (deve reportar `100% in sync`).
     4. Executar `python scripts/sync_studio.py test` para rodar a suíte de validação rápida no Studio.

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
  * `python scripts/sync_studio.py status` — Verifica se todos os 74 scripts de `src/` estão idênticos ao Studio.
  * `python scripts/sync_studio.py push` — Atualiza o Studio com as mudanças feitas em `src/`.
  * `python scripts/sync_studio.py test` — Executa os testes de validação do GDD (fórmula de dano e simulação de batalha).
