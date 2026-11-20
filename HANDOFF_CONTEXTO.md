# HANDOFF DE CONTEXTO — `RobloxProjetoX`

> Use este arquivo ao abrir uma nova conversa ou migrar o projeto para outro Antigravity.
> Leia primeiro [`AGENTS.md`](./AGENTS.md), [`ARQUITETURA_PROJETO.md`](./ARQUITETURA_PROJETO.md), [`Blender/GDD.md`](./Blender/GDD.md) e [`Blender/PROGRESSO.md`](./Blender/PROGRESSO.md).

---

## 1. Ambiente e Ferramentas Conectadas
* **Repositório local:** `c:\Users\vieir\Documents\antigravity\RobloxProjetoX`
* **Roblox Studio:** `PlaceId: 100484375052438` | `UniverseId: 10777011549` | `CreatorId` do Place: `5565234433`
* **Open Cloud Creator UserId (conta logada no MCP):** `12009032821` *(usar `userId: "12009032821"` ao fazer upload via `open_cloud_invoke` e inserir via `insert_asset`)*.
* **Blender:** `D:\Blender\blender.exe` (versão **5.3.0**, usado em modo `--background --python ...`).
* **Sincronizador Disk-First (`src/` <-> Studio):**
  * `python scripts/sync_studio.py status` — valida se os 82 scripts em `src/` estão 100% em sync.
  * `python scripts/sync_studio.py push` — envia alterações de `src/` para o Studio.
  * `python scripts/sync_studio.py test` — roda validação do GDD (`DamageCalc` e `BattleEngine`).

---

## 2. Regras Técnicas Críticas Descobertas (NÃO REDESCOBRIR!)
1. **Texturas em `MeshPart` via Script vs FBX:**
   * No Roblox Studio, definir `SurfaceAppearance.ColorMap` dinamicamente via `execute_luau` deixa a malha cinza (não carrega/bakes).
   * **Solução definitiva:** sempre exportar `.fbx` do Blender com **`path_mode='COPY', embed_textures=True`**, fazer upload via `open_cloud_invoke` (`assetType: "Model"`) e inserir com `insert_asset`. O importador do Roblox cria automaticamente o `MeshPart.TextureID` nativo — **remover qualquer `SurfaceAppearance` filho** nas 6 partes `*_Mesh` para a textura nativa aparecer 100%.
2. **Pipeline Automático Tripo -> Roblox (`scripts/auto_rig_tripo.py`):**
   * Recebe `.zip` direto do Tripo, `.glb`, ou `.fbx` (busca automaticamente pastas `.fbm` dentro de `.zip` em `d:\Downloads` e `Desktop`).
   * Corta a malha única em T-Pose com 5 planos matemáticos (`bmesh.ops.bisect_plane`) em `Head`, `Torso`, `LeftArm`, `RightArm`, `LeftLeg`, `RightLeg`.
   * Rotaciona os braços da T-Pose (`+90°` / `-90°` Y), fecha todas as aberturas das juntas com tampas sólidas (`Caps`) usando UV real da borda e adiciona faces internas (**Double-Sided**) para nunca ficar oco no Studio.
   * Uso:
     ```powershell
     D:\Blender\blender.exe --background --python scripts/auto_rig_tripo.py -- --input "caminho.zip" --char "NomeDoPersonagem"
     ```
     *(Usar `--shoulder-height 4.577` para personagens gigantes como `BarbaBranca`; padrão é `4.303`.)*
3. **Montagem no Rig Híbrido (R6 Visual sobre Esqueleto R15):**
   * Clonar `ServerStorage.Characters.Luffy` (ou `San`), manter as 15 partes R15 invisíveis (`Transparency = 1`), soldar `Head_Mesh`, `Torso_Mesh`, `LeftArm_Mesh`, `RightArm_Mesh`, `LeftLeg_Mesh`, `RightLeg_Mesh` via `WeldConstraint` em `Head`, `UpperTorso`, `LeftUpperArm`, `RightUpperArm`, `LeftUpperLeg`, `RightUpperLeg`.
   * `BaseClient.client.luau` anima `Idle` e `Walk` proceduralmente a 60 FPS para todos os rigs I-Pose do Tripo.
   * `VfxController.luau` calcula `handPos` e `leftHandPos` diretamente pela ponta inferior de `RightArm_Mesh` / `LeftArm_Mesh` (e por `Bone.TransformedWorldCFrame` em Skinned Meshes como `Setero`).
4. **R15 Skinned Mesh (caso use Mixamo, como no `Setero`):**
   * `LowerTorso` deve ser o osso raiz da Armature (sem osso `Root` acima dele).
   * Todos os 15 ossos devem ter `tail = head + (0, 0, +dz)` e `roll = 0` no Blender para importar com **Identity Rest Rotation (`1,0,0, 0,1,0, 0,0,1`)** no Roblox.
   * Exportar em escala `0.058` no Blender (o importador FBX do Roblox multiplica por `100x` -> `5.80` studs).

---

## 3. Estado Atual dos Personagens (18/11/2026)
Consulte a planilha completa em [`Blender/Planilha_Personagens.xlsx`](./Blender/Planilha_Personagens.xlsx).

| ID | Tag (`Anime`) | Raridade | Estágio | Observações |
| :--- | :--- | :--- | :--- | :--- |
| `BarbaBranca` | `OnePiece` | Lendário | **Concluído (100%)** | Modelo substituído pelo Tripo (`111259172785579`), Capa (`Coat_Acc` + `Coat_JollyRoger`) e Bisento (`Murakumogiri_Acc`, 49 peças) preservados em `Marineford3D`. 4 golpes exclusivos testados em Play Mode (PASS). |
| `San` | `DragonBall` | Lendário | **Concluído (100%)** | Modelo Goku R6-on-R15 sólido v2 (`111883369706058`). 4 golpes exclusivos + 2 Cut-Ins. |
| `Setero` | `JujutsuKaisen` | Lendário | **Concluído (100%)** | Skinned Mesh R15 de `gojoFinal.fbx` (`84606453436136`). `Atracao` e `TudoRoxo` (Cut-In). |
| `Yomogi` | `Generico` | Comum | **Concluído (100%)** | R15 completo + 4 golpes exclusivos + 10 animações. |
| `Luffy` | `OnePiece` | Épico | **Em Andamento** | Modelo Tripo implementado (`71578599746074`). Faltam golpes, animações e VFX exclusivos. |
| `Zoro` | `OnePiece` | Raro | **Em Andamento** | Modelo Tripo implementado (`109146576955083`). Faltam katanas, golpes, animações e VFX. |
| `Sanji` | `OnePiece` | Raro | **Em Andamento** | Modelo Tripo implementado (`117184318457931`). Faltam golpes (chutes), animações e VFX. |
| `Nami` | `OnePiece` | Comum | **Em Andamento** | Modelo Tripo implementado (`90585959059032`). Faltam Clima-Tact, golpes, animações e VFX. |
| `Usopp` | `OnePiece` | Comum | **Em Andamento** | Modelo Tripo implementado (`138631614692730`). Faltam estilingue, golpes, animações e VFX. |
| `Kaen` / `Raiko` | `Generico` | Comum | Protótipo Base | Modelos R15 no jogo; golpes simples sem Anim/Vfx/Signature. |
| `ProtoRaro` / `ProtoEpico` | `Generico` | Raro / Épico | Teste (`Prototype=true`) | Remover antes de publicar. |

---

## 4. Códigos de Dev (Aba `Prêmios -> Códigos` no Jogo)
Configurados em [`src/server_storage/Codes.luau`](./src/server_storage/Codes.luau) e [`src/server/Data/RetentionService.luau`](./src/server/Data/RetentionService.luau) com `Repeatable = true`:
* Individuais: `LUFFY`, `NAMI`, `USOPP`, `ZORO`, `SANJI`, `BARBABRANCA`, `SAN`/`GOKU`, `SETERO`/`GOJO`, `KAEN`, `RAIKO`, `YOMOGI` (também aceitam prefixo `DEV`, ex: `DEVLUFFY`).
* Em lote: `ONEPIECE` (todos os 6 de One Piece) e `DEVALL` (todos os 11 personagens jogáveis).

---

## 5. Atualizações Recentes (19–20/11/2026 · Place v228)
Consulte o detalhamento completo em [`Blender/PROGRESSO.md`](./Blender/PROGRESSO.md).

* **Genética (IVs), Treino (EVs) & Gráfico de Radar:** `src/shared/Data/Genetics.luau`, `src/shared/RadarChart.luau` e `CharacterDetailGui` (aberta via Barra do Time `STATUS`, `Equipe` ou `Mochila`). Inimigos PvE da Torre usam `Genética = 70` e `Treino = 100`; Refúgio segue a mesma distribuição do Gacha.
* **Máquina de Treino (Cúpula de Vidro) & 4 Minérios:** `src/shared/Data/Training.luau`, `TrainingService.luau`, `TrainingClient.client.luau` + 4 minérios (`HP`, `Defesa`, `Velocidade`, `Ataque`) com ícones próprios (`ore_hp` `98190850262557`, `ore_def` `81379071551950`, `ore_vel` `131534143692832`, `ore_atq` `94276779585364`).
* **Polimento da Base (`Plot01..Plot10`):** Pedreira escalonada para `0,58×`, Cápsula de Treino no canto frontal direito (`floor * (14.5, 0.3, -14.2)`), personagens em `BaseCharacters` totalmente intangíveis (`CollisionGroup = "BaseNPC"` + `EvaluateStateMachine = false`), ícones reduzidos em `BagGui > Itens` e `TrainingGui`.
* **Estrela do Gacha — Painéis de Anime, Elenco Naruto Provisório & Destaque 3D:**
  * 6 personagens de `Naruto` cadastrados em `Characters.luau` sem modelo próprio ainda (fallback colorido via `CharacterLibrary.CloneSource` + `ProtoRaro`) e ataques padrão: `Sakura`, `Shikamaru` (Comum), `Kakashi`, `Sasuke` (Raro), `Naruto` (Épico), `Sarutobi` (Lendário).
  * Painéis selecionáveis na estrela (`Todos`, `Naruto`, `OnePiece` em `Summon.Banners`), palco `SummonShowcase` com personagem 3D completo girando na frente da tela + sons em `UI.Sounds` (`summon_charge`, `summon_shimmer`, `summon_reveal`, `summon_epic`, `summon_legendary`) e cartas 3D em grade `5x2` (`RevealWindow`).

---

## 6. Próximos Passos Sugeridos
1. Criar golpes exclusivos (`Moves.luau`), animações e VFX/Cut-In (`VfxController.luau`) para o elenco de **One Piece** em andamento (`Luffy`, `Zoro`, `Sanji`, `Nami`, `Usopp`).
2. Criar os modelos 3D definitivos e golpes exclusivos para os **6 personagens de Naruto** (`Sakura`, `Shikamaru`, `Kakashi`, `Sasuke`, `Naruto`, `Sarutobi`) — atualmente usando `CloneSource` provisório.
3. Antes de publicar: remover `ProtoRaro`, `ProtoEpico` e `ReplicatedStorage/_UITestKit`, e desativar/restringir os códigos de Dev em `Codes.luau`.
