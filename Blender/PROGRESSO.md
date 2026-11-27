# PROGRESSO DO PROJETO

Atualizado a cada prompt concluído. Status: Pendente, Em andamento, Concluído.

## Fases

| Fase | Conteúdo | Status |
| --- | --- | --- |
| 1. Protótipo | Mapa, Kaen, Raiko, batalha 1x1, sistema de efeitos | Em andamento (falta sistema de efeitos e técnicas assinatura) |
| 2. Time completo | Time de 6, troca, todos os status, elenco de 12 | Em andamento (time, troca e status concluídos; falta elenco de 12) |
| 3. Progressão, torre e coleção | Salvamento, níveis, torre, invocação, captura | Em andamento (salvamento, níveis, torre e captura no Refúgio concluídos) |
| 4. Base e economia | Mochila, loja, cura, base, mineração, gemas | Concluída (16/11/2026) |
| 5. Monetização e PvP | Passes, pacotes, Portal Premium, PvP | Concluída (16/11/2026; falta só criar os IDs no painel do Roblox) |
| 6. Lançamento | Retenção, polimento, segurança, teste final | Em andamento (retenção concluída em 16/11/2026) |

## Prompts

| Nº | Prompt | Status |
| --- | --- | --- |
| 1 | Preparação | Concluído (arquivos de controle criados em 16/11/2026) |
| 2 | Mapa | Refeito no prompt 19 (mapa v2, 16/11/2026): 10 bases, 10 arenas; o antigo está em ServerStorage/_MapaV1 |
| 3 | Combate 1x1 | Concluído (verificado no Studio; critério do GDD: 89% das lutas Kaen x Raiko entre 5 e 8 turnos, dano 12 a 14) |
| 4 | Sistema de efeitos | Pendente |
| 5 | Kaen | Em andamento: modelo e 7 animações no Studio (ServerStorage/Characters/Kaen); falta técnica assinatura com efeito e animação Minerar |
| 6 | Raiko | Em andamento: modelo e 7 animações no Studio (ServerStorage/Characters/Raiko), faíscas nas manoplas; falta técnica assinatura com efeito e animação Minerar |
| 7 | Time de 6 | Concluído em 16/11/2026 (ver detalhes abaixo) |
| 8 | Elenco inicial (5 lotes) | Em andamento: Yomogi (Natureza) concluído em 16/11/2026; o usuário dispensou o par de Água deste lote |
| 9 | Salvamento e níveis | Concluído em 16/11/2026 (ver detalhes abaixo) |
| 10 | Torre | Concluído em 16/11/2026 (ver detalhes abaixo) |
| 11 | Invocação | Em andamento: Portal Comum, fusão, venda e Álbum concluídos em 16/11/2026; Portal Premium fica para o prompt 15 |
| 12 | Encontros e captura | Zonas removidas no prompt 19; captura voltou no Refúgio (prompt 20, 16/11/2026) |
| 13 | Mochila, loja e cura | Concluído em 16/11/2026 (ver detalhes abaixo) |
| 14 | Base e mineração | Concluído em 16/11/2026 (ver detalhes abaixo) |
| 15 | Monetização | Concluído em 16/11/2026 (falta criar os IDs no painel) |
| 16 | PvP | Concluído em 16/11/2026 (ver detalhes abaixo) |
| 17 | Retenção | Concluído em 16/11/2026 (ver detalhes abaixo) |
| 18 | Polimento e segurança | Em andamento: revisão das telas no celular, auditoria dos RemoteEvents e desempenho com 12 jogadores feitas em 17/11/2026 |
| 19 | Teste final | Pendente |

## Prompt 7 - Time de 6 (16/11/2026)

**Feito**
- BattleService: time de até 6 por lado, 1 em campo. Estados WaitingForInput, Resolving, WaitingForReplacement, Ended.
- Troca (Time) gasta o turno e age antes dos golpes, junto com itens. Estágios de quem sai voltam a zero.
- Desmaio: o jogador escolhe o próximo (tela do time abre sozinha, sem Voltar); a máquina escolhe na hora. Sem ninguém de pé, a batalha acaba.
- 5 status do GDD: Queimadura (1/16 e Ataque pela metade), Veneno (1/8), Paralisia (25% sem agir e Velocidade pela metade), Sono (1 a 3 turnos, contado no fim do turno), Congelamento (20% de descongelar a cada tentativa de agir). 1 status por vez; desmaio limpa o status.
- Tabela de tipos completa (TypeChart já tinha as 7 linhas do GDD).
- Fugir conforme a seção 5: BattleConfig.Mode = "Wild" permite fugir; "Tower" e "PvP" trocam por Desistir (derrota, com toque de confirmação).
- Poção pode ser usada em qualquer membro de pé do time.
- AIController: ChooseReplacement; IA Difícil troca em desvantagem de tipo (Fácil e Médio não trocam).
- BattleGui: menu Lutar / Mochila / Time / Fugir (ou Desistir), lista do time com HP, nível e status, bolinhas do time nos cartões, ícones dos 5 status, alvo da Poção.

**Testado (Play, 16/11/2026)**
- Simulação no servidor: 3x3 com Postura (+1 Ataque) e troca (estágio zerou, troca agiu antes do golpe inimigo), escolha do próximo após desmaio do jogador e da máquina, batalha até o fim (vencedor por desmaio de todos).
- Cada status aplicado ao menos uma vez: Queimadura pela Brasa Viva, Paralisia pela Estática, Veneno, Sono e Congelamento aplicados pelo motor (ver decisões). Efeitos medidos: queimadura 4 de dano e Ataque 22->11; veneno 8 de dano; paralisia Velocidade 22->11 e 2 turnos perdidos em 8; sono 2 turnos e acordou; congelamento 21,2% de descongelar em 910 tentativas.
- Tipos: Punho de Maré (Água) em Raiko x0,5 (3 de dano) e em Kaen x2.
- Fugir: selvagem foge sem derrota; torre conta como desistência.
- Tela no Play: menu Time, troca Kaen -> Raiko, desmaio do Raiko, escolha do Kaen, Desistir, volta à praça. Console sem erros do jogo.

## Prompt 8 - Elenco: Yomogi (16/11/2026)

**Feito**
- Yomogi (Natureza, Comum, meio-fera da floresta), original. O usuário mandou uma referência do Hashirama (Naruto) com o nome "Hashinda"; não foi copiado (nome e visual reconhecíveis). Da imagem usei só o formato (blocos, armadura pintada, cabelo separado).
- Modelo no Blender (rig do Raiko como base, textura nova 1024, cabelo, chifres de galho, manto de folhas; cerca de 650 triângulos). No Studio: ServerStorage/Characters/Yomogi (o pivô do ombro foi movido para a ponta do braço só neste modelo).
- 10 animações publicadas (parado, andar, dano, desmaiar, vitória, minerar e 4 golpes com marcadores Charge, Release, Impact).
- Dados: Characters.Yomogi (64/21/23/19), Moves GaiolaDeEspinhos, Arranhao, SementeToxica (30% veneno), CascaDeCarvalho (+1 Defesa), com Anim, Vfx e Timing.
- Sistema de efeitos no cliente: ReplicatedStorage/VfxController (marcadores, pool, luz de impacto, tremor 0,15 s, flash de crítico, qualidade baixa com metade das partículas) e ReplicatedStorage/Vfx (1 modelo por golpe).
- BattleService (genérico, sem nome de personagem): golpes com Anim/Vfx não tocam animação nem partícula no servidor; o servidor espera o Impact antes de mandar o dano.
- Variantes: ReplicatedStorage/VariantController (Brilhante com textura de outono, Prata, Ouro, Esmeralda, Rubi, Diamante, Arco-íris, Gigante) e Characters.VariantBonus.
- BattleConfig: time do jogador = Yomogi, Kaen, Raiko.

**Testado**
- Simulação: os 4 golpes (Gaiola x2 no Raiko, 24 de dano; Semente envenenou; Casca subiu a Defesa).
- Play: batalha com os 4 golpes, animação e efeito sincronizados pelos marcadores (Charge, Release, Impact disparados nos tempos certos), console sem erros.
- Variantes aplicadas no Edit, todas funcionando.

## Prompt 9 - Salvamento e níveis (16/11/2026)

**Feito**
- ServerScriptService/Data/PlayerDataService: DataStore PlayerData_v1 (chave u_<UserId>) com trava de sessão. Campos da seção 10: coleção, time, mochila, gold, minério, gemas, benefícios, torre, gemas vendidas no dia, missões, login diário, garantia de invocação (mais StarterChosen e NextUid).
- Salvamento automático a cada 60 s, ao sair e no fechamento do servidor (BindToClose).
- Proteção: UpdateAsync com até 4 tentativas e espera crescente; trava renovada a cada salvamento; outro servidor espera a trava (5 x 4 s) e depois a assume; o servidor que perdeu a trava não sobrescreve e expulsa o jogador; falha ao carregar expulsa com aviso (nunca joga com perfil vazio); números validados antes de salvar; cópia de segurança (PlayerDataBackup_v1) a cada saída, usada se o registro vier corrompido; campos novos preenchidos sem apagar os antigos (reconcile + Version).
- ServerScriptService/Data/ProgressionService: escolha do inicial, XP por vitória, níveis 1 a 50, golpes pelo Learnset, 4 golpes ativos (validados no servidor), time salvo usado na batalha. DataMain liga tudo.
- ReplicatedStorage/Data/Progression (curva de XP) e Learnset em Characters (Kaen, Raiko, Yomogi).
- BattleService: ganchos genéricos TeamFor e OnFinished; marca quem entrou em campo; mensagens de XP no log da batalha.
- StarterGui/HudGui: gold, gemas, botão Time; tela de escolha do inicial; menu Time com nível, XP, atributos e escolha dos golpes ativos.
- Remotes novos: ProfileUpdated, GetProfile, ChooseStarter, SetActiveMoves.
- Só no Studio: ServerStorage/_DevData (BindableFunction) para testes pela barra de comando.

**Testado (Play, 16/11/2026)**
- Primeira entrada abriu a escolha do inicial; Kaen escolhido (nível 5, 3 golpes).
- Batalha vencida: Kaen ganhou 9 de XP (3 x nível 3 do Raiko). Mais 450 de XP pela ponte de teste: subiu até o nível 11 e aprendeu Corte Flamejante no 10. Golpes ativos trocados pelo menu Time.
- Saiu e entrou: perfil inteiro igual, campo por campo (nível 11, XP 9, golpes ativos, time, todos os campos).
- Trava: com a trava de outro servidor, o salvamento foi recusado e o gold alterado (999) não foi gravado; na entrada seguinte o servidor esperou 5 vezes, assumiu a trava e carregou os dados certos.

## Prompt 10 - Torre (16/11/2026)

**Feito**
- ReplicatedStorage/Data/Tower: valores da tabela da seção 6 (batalhas, tamanho do time, níveis, IA, recompensas, regras do Infinito).
- ServerScriptService/Tower/TowerService: corrida de batalhas em sequência com o time salvo; HP, status e PP passam de uma batalha para a outra (sem cura no Fácil, Médio e Difícil); Infinito recupera 30% do HP entre andares; times de NPC sorteados do elenco (Kaen, Raiko, Yomogi); IA por modo; chefe a cada 5 andares (+20% de atributos), +4% por andar a partir do 20; personagem do chefe com 5% no andar 5, +1 ponto por chefe, até 15%; gold por andar e bônus a cada 5; recompensas do Fácil, Médio e Difícil; gemas do Difícil 1 vez por dia (dia UTC); desbloqueio em sequência; derrota encerra a corrida e o gold fica; placar do Infinito do servidor (jogadores presentes) e global (OrderedDataStore InfiniteBestFloor_v1, top 10, cache de 60 s).
- StarterGui/TowerGui: tela com os 4 modos (bloqueado/entrar, regras e recompensas) e placar Servidor/Global com o recorde do jogador. Abre no gatilho da entrada da torre (BattleMain).
- BattleService (genérico): StartBattle com times, IA, intro e callbacks (OnEnd, OnClosed), KeepPlayer para batalhas em sequência, ReturnToPlaza, StatMultiplier/Hp/Status/PP herdados, entra em campo o primeiro de pé. BattleConfig.TimeScale (1 = normal).
- VfxController: efeito não quebra se o modelo some no meio (troca, desmaio, fim da batalha).

**Testado (Play, 16/11/2026)**
- Infinito bloqueado recusado ("Conclua o modo anterior").
- Time de teste (6 personagens nível 45, injetado pela ponte do Studio): Fácil concluído (3 vitórias, +150 gold, Médio desbloqueado). Infinito liberado pela ponte de teste; andares 1 a 5 vencidos (+100 por andar, chefe no 5 com +600), chegou ao andar 6 e desistiu: "A corrida terminou no andar 6. Gold ganho: 1000". Recorde 5 no placar do servidor e no global. Saiu e entrou: gold 1150, recorde e desbloqueio voltaram salvos.
- Depois do teste o perfil do usuário foi restaurado (Kaen nível 11) e a entrada de teste foi removida do placar global.

## Prompt 11 - Portal Comum, fusão, venda e Álbum (16/11/2026)

**Feito**
- Modelo do portal no Blender: C:\Blender\Mapa\PortalComum.blend, PortalComum.fbx, PortalComum_render.png (anel de pedra com detalhes dourados, colunas, telhado vermelho, núcleo; cerca de 1.700 triângulos). No Studio: Workspace/Map/Portals/PortalComum, na praça a oeste da torre (-56, 0, -18), virado para o centro, com ProximityPrompt "Invocar".
- ReplicatedStorage/Data/Summon: custo 300 gold (10 por 2.700), chances 70/23/6/1, garantia de Lendário na 200ª seguida sem Lendário, Brilhante 1%, estrelas (3 iguais = +1, até 5, +5% cada), venda (50/150/500/3.000), prêmio do Álbum, cores do raio (cinza, azul, roxo, dourado).
- ServerScriptService/Economy/SummonService: sorteio só no servidor, cobra gold, guarda a garantia no perfil (SummonPity.Comum), Brilhante, anúncio no chat de Lendário e Brilhante (Remotes.Announce -> RBXGeneral), fusão e venda de repetidos (cópias do time não são usadas), salva na hora.
- ServerScriptService/Data/AlbumService: registra personagens e variantes obtidos (venda e fusão não apagam), paga cada tipo e cada raridade completos uma vez; perfis antigos recebem o que já têm (Backfill).
- Estrelas e variante entram nos atributos de batalha (StatMultiplier no time).
- StarterGui/SummonGui: chances sempre visíveis, contador da garantia, animação no cliente (núcleo escurece, raio sobe na cor da raridade, faíscas), cartas com raridade/tipo/Brilhante/NOVO, Álbum (obtidos, variantes, metas por tipo e raridade) e Repetidos (fundir e vender).
- Correção: o evento Loaded do PlayerDataService copia tabelas; agora quem ouve usa Get(player).

**Testado (16/11/2026)**
- 10.000 invocações simuladas no servidor (Summon.Roll com garantia): Comum 6.985 (69,85%), Raro 2.314 (23,14%), Épico 599 (5,99%), Lendário 102 (1,02%); qui-quadrado 0,16 (3 graus de liberdade, limite de 5% = 7,81): bate com a tabela. Brilhante 105 (1,05%). Garantia acionada 17 vezes; maior sequência sem Lendário = 200.
- 10 invocações reais pela interface (Invocar 10, 2.700 gold de teste dados pela ponte do Studio): 4 Kaen, 3 Yomogi, 3 Raiko; 1 Lendário sorteado entregou Raiko (elenco sem Lendário). Álbum pagou tipo Raio, tipo Natureza e raridade Comum (Fogo já pago ao carregar). Fusão Kaen (+1 estrela) e venda de 1 Raiko (+50) pela tela Repetidos. Saiu e entrou: tudo voltou igual. Anúncio do chat disparado em teste. Console sem erros.

## Prompt 12 - Zonas de encontro e captura (16/11/2026)

**Feito**
- Workspace/Map/EncounterZones: 4 zonas entre a praça e as bases, nos vãos entre os caminhos (raio 24, a 140 studs do centro): Campo das Libélulas (leste, nível 3 a 6), Bosque das Lanternas (sul, 6 a 10), Vale da Névoa (oeste, 10 a 15), Colina dos Ventos (norte, 15 a 20). Grama alta, pedras na borda e placa com nome e níveis.
- ReplicatedStorage/Data/Encounters (zonas e níveis) e Characters.Rarities com CaptureRate e Characters.CaptureChance (fórmula da seção 7: Taxa x (1 - 0,7 x HP/HPmax) x Selo x Status, limitada a 100%).
- ServerScriptService/World/EncounterService + EncounterMain: 3 selvagens visíveis por zona, raridade pela chance em encontro da seção 4 (60/28/10/2), nome/nível/raridade em cima, ProximityPrompt "Enfrentar"; batalha 1x1 modo Wild (fuga permitida, IA Fácil) com a mochila salva do jogador (o que é gasto sai do perfil); capturado entra no time (se houver vaga) ou na coleção, Álbum atualizado, perfil salvo na hora; selvagem vencido ou capturado reaparece em 20 s; depois de fugir ou perder ele volta à zona; o jogador volta para onde estava.
- BattleService: Selos (Kind Capture) só no modo Wild; captura encerra a batalha como vitória (EndReason Captured, XP normal); o selvagem capturado some da arena.
- StarterPlayerScripts/WildClient: animação parada dos selvagens no cliente.

**Testado (16/11/2026)**
- Fórmula: Comum com HP cheio e Selo de Contrato = 18%; metade do HP = 39%; 1 HP + status + Selo Superior = 100% (limite). 10.000 sorteios de raridade de encontro: 5.956 / 2.852 / 1.007 / 185 (tabela 60/28/10/2).
- Selo recusado na torre ("Selos só funcionam contra personagens selvagens") e aceito no selvagem.
- Play: Kaen selvagem nível 3 no Campo das Libélulas capturado com Selo Superior; entrou na coleção (c23, foi para a base porque o time estava cheio), Selo Superior 3 -> 2 no perfil, gravado no DataStore. Fuga de outro encontro: "Você fugiu da batalha", selvagem voltou à zona. Saiu e entrou: o Kaen capturado e a mochila voltaram iguais. Console sem erros.

## Prompt 13 - Mochila, loja e centro de cura (16/11/2026)

**Feito**
- Data/Items: os 8 itens e preços da seção 7, com descrição, ordem, OutsideBattle (Poções e Reviver) e funções de espaço (30 espaços, pilhas de 99).
- HP, status e PP agora ficam salvos por personagem (perfil: Hp nil = cheio, Status, StatusTurns, Pp só dos golpes gastos). Toda batalha começa com o estado salvo e grava de volta no fim (ProgressionService.WriteBack), inclusive se for cancelada. Time todo desmaiado não batalha ("cure no centro de cura ou use um Reviver").
- Mochila salva usada em todas as batalhas (torre, encontros e avulsa); o que é gasto sai do perfil.
- Batalha: Cura-Status, Éter (10 PP no golpe com mais PP faltando) e Reviver (50% do HP, também em quem está desmaiado no banco) funcionando, além de Poções e Selos; a tela de alvo filtra quem pode receber cada item.
- Fora de batalha: Poção, Superpoção, Hiperpoção e Reviver pela Mochila do HUD (StarterGui/BagGui), escolhendo o personagem (time e base).
- Loja (StarterGui/ShopGui): prompt "Abrir loja" na loja da praça; compra 1 ou 10; o servidor valida gold, pilha de 99 e 30 espaços.
- Centro de cura: prompt "Curar time" no centro de cura da praça; restaura HP, PP e status de todos os personagens, de graça; aviso na tela (HUD).
- ServerScriptService/Economy/InventoryService; Remotes BuyItem, UseItem, Notify; ReplicatedStorage/UIKit (peças de interface).
- Torre: HP/status/PP/mochila agora vêm do perfil (sem cura no Fácil, Médio e Difícil; Infinito cura 30% do HP salvo entre andares).
- HUD: botão Mochila, avisos, HP e status no menu Time.
- Correção: Progression.VictoryXp tinha ficado com funções no meio (edição anterior); arrumado.

**Testado (16/11/2026)**
- Compra de 1 de cada item pela loja: gold 2.050 -> 250 (soma 1.800 = tabela). 1.000 gold de teste vieram da ponte do Studio.
- Fora de batalha: Poção no Kaen (10 -> 30), Superpoção no Kaen (30 -> 72, cheio), Hiperpoção no Yomogi (30 -> cheio), Reviver no Kaen desmaiado (0 -> 23 = 50%).
- Em batalha (encontro): Cura-Status tirou o veneno do Yomogi no banco, Éter devolveu 10 PP ao Arranhão (5 -> 15), Selo de Contrato falhou, Selo Superior capturou um Raiko.
- Centro de cura: tudo cheio depois. Saiu e entrou: gold 250, mochila (10 Contrato, 2 Superior) e estados iguais. Torre Fácil iniciou normal com o estado salvo. Console sem erros.

## Prompt 14 - Base, mineração e venda de minério (16/11/2026)

**Feito**
- Data/Base: valores da seção 8 (6 ativos, 2 vagas de mineração no início até 6 por 5.000/15.000/40.000/100.000 gold, 8 h de acúmulo fora, 100 minério = 1 gema, teto de 50 gemas/dia, depósito de 10.000) e taxas por raridade (gold 20/30/45/70, minério 10/18/30/50). Benefícios da seção 9 já entram no cálculo (Gold em Dobro x2, VIP +10%, Minerador Extra +2 vagas) para o prompt 15.
- Perfil: campo Base { Active[uid] = Walk/Mine, MiningSlots, Pending { Gold, Ore }, LastTick }.
- ServerScriptService/Economy/BaseService: ao entrar o jogador recebe o primeiro terreno livre (Plots, OwnerUserId; placa "Base de <nome>" no portão), liberado ao sair. Personagens da base aparecem no terreno: Passeando andam entre pontos aleatórios (longe da pedreira) e param; Minerando ficam em arco na pedreira, virados para ela. Produção calculada no servidor por tempo (a cada 10 s online; ao entrar, o tempo fora com limite de 8 h) e fica pendente até coletar. Coleta: gold vai para o perfil; minério vai para o depósito até 10.000 e o excedente fica pendente na base. Venda de minério na loja com teto diário (dia UTC). Vendidos/fundidos saem da base sozinhos.
- Remotes BaseSetState, BaseCollect, BaseUpgrade, SellOre, BaseTeleport (todos validados no servidor).
- StarterGui/BaseGui (botão Base no HUD): personagens da coleção com Passear / Minerar / Tirar, produção por hora, vagas, depósito, pendente, Coletar, Nova vaga e "Ir para a base".
- Loja: linha "Vender minério" com depósito e gemas vendidas no dia.
- StarterPlayerScripts/BaseClient: animações Idle/Walk/Mine dos personagens da base só no cliente.
- Kaen e Raiko ganharam a animação Mine (a mesma do Yomogi; rig R15 com as mesmas juntas).
- Ponte de teste do Studio: "clock" (adianta o relógio como se o jogador estivesse fora) e "base" (chama as ações direto). Só funciona no Studio.

**Testado (16/11/2026)**
- Terreno Plot01 atribuído ao entrar; 4 passeando e 2 minerando apareceram e se movem (captura de tela).
- 3º minerador com 2 vagas: recusado. 7º ativo: recusado.
- Relógio +10 h: contou só 8 h (640 gold e 160 minério, = 80 gold/h e 20 minério/h x 8). Coleta ok.
- Vaga sem gold: recusada. Com gold de teste: 3 -> 6 vagas (160.000 gold), 5ª compra recusada (máximo).
- 6 mineradores, 22 x (relógio +8 h e coleta): depósito parou em 10.000, 720 de minério ficou pendente com aviso.
- Venda pelo cliente: 5.000 minério -> 50 gemas (50/50); 2ª e 3ª venda bloqueadas ("Teto de 50 gemas por dia atingido"); bloqueio também visto na loja pela interface. Relógio +24 h: nova venda de 50 liberada e bloqueada de novo.
- Parar e iniciar o Play: vagas, depósito, gemas, vendas do dia e base voltaram iguais; personagens reapareceram no terreno. Console sem erros.
- Depois do teste o perfil foi restaurado ao estado anterior (gold 150, gemas 40, minério 0, 2 vagas, base vazia).

## Prompt 15 - Monetização e Portal Premium (16/11/2026)

**Feito**
- Data/ProductIds: ÚNICO módulo com os IDs do painel (9 Game Passes e 3 Developer Products), todos 0 (vazio). Com 0 o botão de Robux avisa "ainda não foi criado no painel"; as gemas funcionam normalmente.
- Data/Benefits: os 9 benefícios da seção 9 (nome, efeito, preço em Robux, preço em gemas só para Mochila Ampliada, Gold em Dobro e Cura Automática) e os 3 pacotes de gemas.
- ServerScriptService/Economy/MonetizationService:
  - Game Pass conferido a cada entrada (UserOwnsGamePassAsync) e ao comprar (PromptGamePassPurchaseFinished); perfil Benefits[id] = "Pass". Passe que o jogador não tem mais sai na entrada.
  - Benefício por gemas (remote BuyBenefit): valida preço, se já tem e se é só Robux; perfil Benefits[id] = "Gems".
  - Pacotes de gemas por ProcessReceipt: entrega 1 vez por PurchaseId (perfil Receipts, últimos 100), só confirma PurchaseGranted depois de salvar; jogador fora, perfil não carregado, produto desconhecido ou falha ao salvar = NotProcessedYet.
  - PolicyService: atributo PaidRandomRestricted no jogador (sem resposta = restrito).
- Efeitos dos benefícios: Mochila Ampliada (+20 espaços na loja/mochila), Gold em Dobro e VIP +10% (base), Minerador Extra (+2 vagas), Cura Automática (time curado ao fim de toda batalha fora da torre), XP em Dobro, VIP (tag [VIP] dourada no chat, placa e cerca/portão dourados na base), Invocação Rápida (botão Invocar 3 e sem animação), Sorte em Dobro (Épico 12% e Lendário 2% no Portal Comum, tirado do Comum), Depósito Ampliado (+50 vagas de personagens).
- Limite de personagens: 100 (150 com Depósito Ampliado). Cheio: invocação recusada antes de cobrar, Selos recusados na batalha, chefe do Infinito não entra (aviso).
- Portal Premium (Map/Portals/PortalPremium, cópia recolorida do Portal Comum, ao lado dele): 25 gemas (10 por 225), Raro 72% / Épico 25% / Lendário 3%, garantia de Lendário na 60ª, Brilhante 1%, chances na tela. Banner da semana (troca segunda 00:00 UTC): o Lendário em destaque leva metade da chance de Lendário; carta mostra "DESTAQUE".
- Bloqueio: onde ArePaidRandomItemsRestricted (ou sem resposta da PolicyService) o servidor recusa o Portal Premium e o cliente esconde o portal; fica só o Portal Comum.
- Loja com abas Itens (e Vender Minério), Benefícios (Robux ou gemas, "Ativo ✓") e Gemas (pacotes). Botão Loja no HUD.
- Ponte de teste do Studio: "setid" (ID temporário só na sessão), "monet" (ProcessReceipt, OnPassPurchased, BuyWithGems) e "policy".

**Testado (16/11/2026)**
- Pacote (compra simulada pelo ProcessReceipt, ID temporário): 1.500 gemas entregues (40 -> 1.540); mesmo PurchaseId de novo = PurchaseGranted sem entregar de novo; produto desconhecido e jogador fora = NotProcessedYet.
- Compra por gemas: Mochila Ampliada por 1.500 (1.540 -> 40); de novo = "já tem"; XP em Dobro por gemas recusado (só Robux); Cura Automática sem gemas recusada; pela interface, Gold em Dobro sem gemas mostrou "Gemas insuficientes".
- Passe (compra simulada pelo PromptGamePassPurchaseFinished): cancelado não entrega; VIP comprado -> Benefits.VIP = "Pass", tag VIP ligada, placa "★ VIP ★" e cerca dourada. Invocação Rápida por passe: Invocar 3 no Portal Comum funcionou (sem o passe, recusado).
- Portal Premium: 1 invocação por 25 gemas (40 -> 15), garantia 1/60 na tela. Região restrita simulada: servidor recusou e o portal sumiu no cliente.
- Botões de Robux com ID vazio mostram o aviso. Console sem erros (só o aviso esperado do produto desconhecido do teste).
- Perfil restaurado ao estado anterior depois do teste (gemas 40, gold 150, 12 personagens, sem benefícios).

## Prompt 16 - PvP (16/11/2026)

**Feito**
- Desafio por proximidade na praça (StarterGui/PvPGui/PvPClient): perto de outro jogador aparece "Desafiar (PvP)" (prompt só do cliente, tecla F, 12 studs, só com os dois dentro do raio de 80 da praça e fora de batalha).
- ServerScriptService/Battle/PvPService: confere praça, distância, batalha/torre e time; quem desafia já aceitou; o desafiado tem 20 s para Aceitar/Recusar (janela com contagem); quem desafiou pode Cancelar; tudo conferido de novo no aceite. Remotes PvPChallenge, PvPRespond, PvPCancel, PvPInvite.
- Times: o time salvo de cada um, todos no nível 50, HP/PP cheios, sem status; estrelas e variante continuam. São cópias: o perfil não muda (sem XP, sem gravar HP).
- BattleService: lado Enemy humano (EnemyHuman). Os dois escolhem; o turno resolve quando os dois escolheram. 30 s por turno (BattleConfig.PvPTurnTime) com relógio na tela; ao estourar, ação automática (golpe aleatório com PP) e escolha automática do próximo depois de desmaio, com aviso no log. Itens desativados (servidor recusa; botão Mochila apagado). Desistir vale na hora e conta como derrota. Saída do jogo ou renascer no meio = derrota de quem saiu; o outro vê "O adversário desconectou" e Vitória. Cada jogador vê a batalha do seu lado (eventos, câmera e modelos espelhados).
- Valores novos em BattleConfig: PvPTurnTime 30, PvPLevel 50, PvPChallengeDistance 12, PvPInviteTime 20, PlazaRadius 80.

**Testado (16/11/2026, servidor local do Studio com 2 jogadores)**
- Desafio Player1 -> Player2 e aceite pela janela; os dois foram para a arena, cada um com a sua câmera e o seu lado (Kaen x Yomogi, nível 50).
- Mochila: "Itens desativados no PvP". Turno 1: Player1 escolheu, Player2 não; aos 30 s o servidor fez a ação automática e o turno resolveu.
- Batalha completa (escolhas automáticas dos dois clientes): Player1 venceu por desmaio; Player1 viu Vitória e Player2 Derrota; arena liberada, os dois de volta à praça, perfis sem mudança (nível 10, HP cheio).
- Desconexão: nova batalha, Player2 saiu no meio do turno 2 (Kick pelo servidor, mesmo caminho de sair do jogo): Player1 recebeu Vitória "O adversário saiu", arena liberada, Player1 de volta à praça.
- Terceiro jogador: desafio pelo prompt real (clique e segurar em "Desafiar (PvP)"), aceite, e Desistir com dois toques: Player1 Derrota "Você desistiu", Player3 Vitória "O adversário desistiu".
- Regressão: batalha da torre Fácil (contra a máquina) continua normal no Play solo. Console do servidor sem erros.
- Perfil do usuário restaurado depois do teste da torre (gold 150, gemas 40, 12 personagens).

## Prompt 17 - Retenção (16/11/2026)

**Feito**
- ReplicatedStorage/Data/Retention: calendário UTC (dia, semana a partir de segunda, temporada = mês), valores do login, baús, missões, faixas da temporada e evento de fim de semana.
- ServerScriptService/Data/Clock: relógio das mecânicas de retorno; adiantável só no Studio (atributo RetentionOffset para o cliente).
- ServerScriptService/Data/RetentionService (tudo no servidor, remote Rewards com trava por pedido):
  - Login diário de 7 dias: 100, 200, 300, 400, 500, 600 gold; dia 7 = 1 invocação Premium grátis. Uma vez por dia; pular um dia volta ao dia 1; depois do dia 7 recomeça no 1.
  - Baús por tempo online no dia: 5 min 100 gold; 15 min 2 Poções; 30 min 2 Selos de Contrato; 60 min 300 gold + 1 Selo Superior. Cada um 1 vez por dia; conferem espaço na mochila antes de abrir.
  - 3 missões diárias sorteadas por dia (pool: vencer 3 batalhas, vencer 3 na torre, invocar 3, capturar 1, coletar a base 2, comprar 5 itens): cada uma 200 gold + 50 XP para cada personagem do time; as 3 = 5 gemas. Entregues ao completar.
  - 5 missões semanais (vencer 25, invocar 15, capturar 5, vencer 15 na torre, completar 10 diárias): as 5 = 1 invocação Premium grátis.
  - Temporada do Infinito: placar por mês (OrderedDataStore InfiniteSeason_AAAA-MM). Na virada do mês: gemas pela faixa do melhor andar (5+ 10, 10+ 25, 20+ 50, 30+ 100) e conferência do top 100 do placar global; quem ficou entre os 100 ganha a aparência "Top 100 do Infinito" (título em cima da cabeça e tag no chat).
  - Evento de fim de semana (sábado e domingo UTC), sem custo: alterna 2x gold e 2x XP a cada semana. 2x gold na torre (conclusão e andares) e na produção da base; 2x XP no XP de vitória.
  - Códigos em ServerStorage/Codes (o cliente não vê): LANCAMENTO (500 gold + 1 invocação Comum), BEMVINDO (300 gold), PORTAL3 (3 invocações Comuns). 1 vez por jogador, aceita minúsculas e espaços, validade opcional (Expires), limite de 10 tentativas por minuto.
- Invocações grátis (perfil Tickets): usadas primeiro no "Invocar 1" do portal; o botão mostra "GRÁTIS (n)". Onde o Portal Premium é bloqueado (PolicyService), a invocação Premium de recompensa vira 25 gemas.
- Perfil: campos novos Session, Tickets, Codes, Cosmetics, Season e Missions.AllDone/WeeklyDone (perfis antigos recebem pelo reconcile).
- Ganchos: ProgressionService.Listeners (vitória, torre, captura), SummonService (invocação), BaseService (coleta), InventoryService (compra). Torre: placar Servidor/Global agora é da temporada; a tela mostra temporada, dias para zerar, melhor andar da temporada e recorde geral.
- StarterGui/RewardsGui: botão Recompensas (ponto vermelho quando há algo para receber) com abas Login, Baús, Missões, Temporada e Códigos; abre sozinho no Login quando a recompensa do dia está pendente; aviso "Fim de semana: 2x gold/XP" no HUD. VipTagClient mostra a tag e o título da temporada.
- Ponte de teste do Studio: "retclock" (adianta o relógio do retorno), "playtime" (soma tempo online), "ret" (chama o RetentionService) e "checktop".

**Testado (16/11/2026, Play com o relógio adiantado pela ponte do Studio)**
- Login: dias 1 a 7 seguidos = 100+200+300+400+500+600 gold e 1 invocação Premium; 2º pedido no mesmo dia recusado; dia 8 voltou ao dia 1; depois de pular um dia voltou ao dia 1. Gold conferido (150 -> 2.650). Recebido também pelo botão da tela.
- Baús: antes de 5 min recusado; 5 min = +100 gold; repetido recusado; 15/30/60 min = +2 Poções, +2 Selos de Contrato, +300 gold e +1 Selo Superior; no dia seguinte zeraram.
- Diárias (sexta 27/11): Invocar 3 (1 Premium com a invocação grátis, sem gastar gemas, e 2 Comuns), Vencer 3 na torre (corrida real do Fácil) e Capturar 1: cada uma +200 gold e +50 XP no time; as 3 = +5 gemas. No dia seguinte vieram 3 missões novas e as semanais continuaram.
- Semanais: completas com região restrita simulada = +25 gemas no lugar da invocação Premium; na semana seguinte zeraram e, sem restrição, deram 1 invocação Premium; completar de novo não pagou de novo.
- Sábado 28/11 (2x XP): XP de vitória dobrado (inimigos 6+5 = 66 XP, 10+10 = 120, 7+8 = 90). Sábado 05/12 (2x gold): torre Fácil pagou 300 gold e a base 40 gold/h com um Comum passeando.
- Temporada: andar 12 em novembro entrou no placar InfiniteSeason_2026-11; na virada para dezembro: +25 gemas, 1º lugar, aparência Top 100 liberada (título visto na tela); placar de dezembro vazio na torre.
- Códigos pela remote: LANCAMENTO com espaços e minúsculas aceito; repetido, inexistente e vazio recusados; 11ª tentativa no minuto bloqueada. Invocação Comum grátis usada sem gastar gold.
- Console sem erros. Perfil do usuário restaurado depois do teste (gold 150, gemas 15, 13 personagens) e a entrada de teste removida do placar de novembro. Place salvo (versão 52).

## Prompt 18 - Redesenho da interface (16/11/2026)

**Feito**
- Pesquisa de referências (jogos de anime e coleção do Roblox) com resumo entregue na conversa; usadas só como inspiração de estilo.
- Tema: C:\Blender\UI\tema.json e UITheme.lua -> ReplicatedStorage/UITheme. Fonte FredokaOne; contorno #1A1233; cantos arredondados; degradês; sombra embaixo de botões. Moedas: gold #FFD447, gemas #FF4FA3, minério #E07B2C. Raridades: Comum cinza #9AA3B5, Raro azul #3D8BFF, Épico roxo #A855F7, Lendário dourado #FFB020.
- Kit novo ReplicatedStorage/UI (cliente): telas em escala relativa + UIAspectRatioConstraint + teto de tamanho (MaxSize) para telas grandes; nenhuma posição fixa em pixels. ScreenInsets CoreUISafeInsets (fora da barra do Roblox e do entalhe). Botão afunda ao tocar e volta com quique; janelas crescem/deslizam ao abrir; números de moeda sobem contando; brilho passando em itens raros, Lendário e no melhor pacote.
- Ícones: 32 desenhados pela skill roblox-ui (C:\Blender\UI\icones, folha em icones_folha.png; picareta refeita em pickaxe_v2.png) e enviados ao Roblox; IDs na tabela UI.Icons.
- Sons (skill roblox-sfx; busca pela loja do Roblox e conferência no Studio de carregamento e duração): clique 127036696152728, abrir tela 78897892629188 (fechar = mesmo som, tom mais grave), compra 10066947742, recompensa 96102213526905, moeda 607665037, erro 87519554692663.
- Telas refeitas (lógica e RemoteEvents iguais aos de antes): HUD (moedas, menu 3x2, ponto vermelho de Prêmios, aviso de evento, avisos curtos), Time, Mochila, Base, Loja (Itens + vender minério, Benefícios, Gemas), Prêmios (Login, Baús, Missões, Temporada, Códigos), Invocação (Portal, Álbum, Repetidos, Resultado), Torre, caixa de desafio PvP e Batalha.
- Batalha no estilo Pokémon: câmera nova (Arena01/CameraPoint, FOV 50 durante a batalha e o anterior devolvido no fim); cartão do inimigo no alto à direita, o do jogador embaixo à esquerda; comandos e golpes no canto inferior direito, sem cobrir o personagem; controles de toque do Roblox desligados durante a batalha.
- Telas coordenadas pelo módulo UI (UI.open/UI.onOpen) e atributos do PlayerGui: InBattle, RewardsBadge, WeekendEvent.
- Aviso do baú agora diz "Abra em Prêmios" (nome do botão novo).

**Testado (16/11/2026, Play)**
- Cada tela e cada aba em 3 tamanhos emulados (celular pequeno 667x375, celular grande 932x430 com entalhe, tablet 1024x768; a barra do Roblox descontada): verificação automática sem nada fora da tela, nenhum botão de toque abaixo de 44 px e nenhum texto abaixo de 9 px. HUD fora das zonas do analógico e do pulo.
- Batalha da torre Fácil: comandos, golpes e um turno completo (dano nos dois lados) funcionando com a tela nova. Invocação de 10 com a tela de resultado. Torre aberta pelo servidor; desafio PvP recebido e recusado; a caixa some quando a batalha começa.
- Console sem erros. Perfil do usuário restaurado depois do teste (gold 250; a invocação de teste foi desfeita). Place salvo (versão 61).
- Capturas no tamanho de celular em C:\Blender\UI\capturas (uma por tela e aba; batalha também em celular grande e tablet; folha com todas: _todas_celular_pequeno.png).

## Prompt 19 - Mapa v2 (16/11/2026)

**Feito**
- Etapa 0: GDD atualizado (backup em GDD_antes_mapa_v2.md): 10 jogadores, 10 bases e 10 arenas, seção 3 nova, zonas de encontro removidas, estrelas, tela Configurações. Missões de captura tiradas do sorteio; EncounterMain e WildClient desligados (código guardado); Map/EncounterZones em ServerStorage/_Desativado.
- Etapa 1: ajustes do kit de interface (UI.clampHeight, fillBetween, keepScroll, slider) e ícones novos (selos, engrenagem, música, alto-falante, brilho).
- Etapa 2: tela Configurações (engrenagem no HUD): Música e Efeitos sonoros (volume + liga/desliga) e Efeitos do mapa. Salvo no perfil (Settings) pelo SettingsService; SoundService.Musica e SoundService.Efeitos; AudioClient troca a música do mapa e da batalha com transição.
- Etapa 3 (planta aprovada): C:\Blender\Mapa\planta_mapa_v2.png. Mapa construído:
  - Área jogável 380 x 300 (x ±190, z ±150), chão em y = 8. Montanhas de terreno em volta (304 bolas: pé verde, rocha, picos com neve). Paredes invisíveis de 200 de altura e teto invisível em y = 188 (Map/Bounds).
  - Esteira: anel com borda externa x ±142 / z ±102, 12 de largura, 16 studs/s, sentido horário, cantos na diagonal; peças com AssemblyLinearVelocity, 0,45 acima do chão, sem paredes; textura animada (98725942911595) rolando no cliente.
  - Torre nova (pagode com cristal, 60,7 x 129,7 x 69,5) no centro, entrada para +Z; Tower/EntrancePoint em (0, 9, 42), raio 12, anel brilhante e brasas na entrada.
  - Loja (90, 0) e Centro de cura (−90, 0) com InteractPoint; praça de pedra, caminhos de pedra com borda, praça do spawn (0, 75), lago com carpas e vitórias-régias ao norte da torre.
  - Estrelas: amarela (−50, 52) = PortalComum, roxa (50, 52) = PortalPremium; base de pedra com aro dourado e runa, estrela flutuando e girando (cliente), halo, luz, brilhos, partículas subindo e feixe de luz; Core/Glow/PromptPoint/SummonPrompt como antes.
  - Placares: Mais Gold (−99, 59) e Maior andar da torre (99, 59), virados para o spawn.
  - 10 bases 40 x 40 (Plots/Plot01..10): piso de madeira, borda de pedra, cerca, portão torii, placa de madeira com o nome do dono (SurfaceGui; "Base livre" sem dono), pedreira (Ground, MinePoint), caverna do Refúgio, lanternas de papel e de pedra com luz, arbustos, varanda até a esteira.
  - Jardins nos 4 cantos (pavilhão, cerejeiras, pinheiros, lanternas) e decoração nos vãos entre bases.
  - Iluminação fim de tarde (ClockTime 17,55, Atmosphere, ColorCorrection, Bloom, SunRays); DepthOfField desligado.
  - 10 arenas (Arena01..10 em x = 1500, a cada 100 em z).
- Modelos 3D (Kiln, rota hard-surface da skill roblox-3d-model; o Space de IA orgânica estava fora do ar e o Blender MCP não respondeu): 22 modelos em C:\Blender\Mapa\modelos_v2 (fonte em fonte_kiln) e ServerStorage/MapaV2Kit. IDs: Torre 83502182823559, Loja 138878650230815, Cura 119507154037129, Placar 96926471868480, Portão 101721954115744, Cerca 94679767453895, Lanterna de pedra 98356419796684, Lanterna de papel 75033228957606, Placa 137960255215848, Pavilhão 76060994202361, Pedreira 96605199321811, Cerejeira 132733398181489, Pinheiro 71442235015306, Arbusto 103082444714713, Pedra 129361656004478, Estrela 117501837172290, Caverna 94845593371616, Baú 70796170745849, Forja1 78300600894039, Forja4 132914980408887, Forja7 114950173484498, Forja10 79294177007608.
- Texturas: materiais gerados (MaterialService/AssistantMaterials): PedraPraca, CaminhoPedra, PisoBase, PedraMuralha; materiais do Roblox nos modelos (telhado, madeira, gesso, ardósia, metal). Partículas em C:\Blender\Mapa\efeitos_v2: pétala 130564513029602, brilho 135255086148920, faísca 117703775594396, brasa 93633042519778, chama 71087557580907, anel 106813072869220, esteira 98725942911595.
- Efeitos (tudo com a tag MapFx; desliga em "Efeitos do mapa"): pétalas e vaga-lumes perto da câmera, brilho no cristal da torre, estrelas, lanternas piscando, carpas nadando, brilho das cavernas. Script StarterPlayerScripts/MapFxClient. ClientSettings agora também desliga BillboardGui/SurfaceGui e Decals da tag.
- Etapa 4 (religação): LeaderboardMain (OrderedDataStore Ranking_Gold_v1 e Ranking_Torre_v1, a cada 3 min, top 10, top 3 em destaque); BaseService.setSign escreve na placa nova; praça do PvP = retângulo dentro da esteira (|x| ≤ 130, |z| ≤ 90) no PvPClient e PvPService; servidor com 10 vagas (serverSize = 10 pelo Open Cloud).
- Mapa antigo, Tower e Plots antigos em ServerStorage/_MapaV1 (com cópia do terreno TerrenoV1).

**Testado (Play, 16/11/2026)**
- Spawn na praça (0, 11, 74). Esteira: volta completa em 60 s parado sobre ela, sem sair do anel nem ser arremessado. Lado maior a pé: 380 / 16 = 23,8 s.
- Torre: gatilho abriu a tela; batalha Fácil começou na arena e a música trocou para a de batalha (Musica_Battle).
- Estrelas: prompt da amarela abriu a tela; invocação nos dois portais pelo servidor (Comum e Premium) funcionando.
- Loja e cura pelos prompts novos; ida à base pelo botão; placa mostrou "Base de Jhoniz" e as outras "Base livre".
- Configurações: Música, Efeitos sonoros e Efeitos do mapa desligados e religados; volumes e 105 de 107 efeitos do mapa seguiram a opção (os 2 que faltavam eram emissores locais; corrigido para ler o atributo do PlayerGui); salvo no perfil.
- Fuga: empurrando e pulando nas 4 bordas e num canto, ninguém saiu de x ±190 / z ±150; lançado para cima, parou em y 180 (teto em 188).
- Desempenho (Studio, câmera na praça): só o mapa 57,9 mil triângulos; com 9 jogadores simulados andando + 54 personagens nas bases: 141 mil (efeitos ligados) e 154 mil (desligados, ângulo diferente), 197 / 172 draw calls, 86 / 42 emissores ativos. Servidor: 60 Hz, heartbeat 0,19 ms sem carga e 0,35 ms com carga, física 60. O FPS do cliente no Studio ficou travado em 15 nos dois casos (janela do Studio sem foco limita o FPS), então não serve como medida real.
- Capturas em C:\Blender\Mapa\referencias. Console sem erros. Place salvo (versão 76).

## Prompt 20 - Refúgio (16/11/2026)

**Feito**
- GDD: seção 14 Refúgio (backup em GDD_antes_refugio.md); seções 3 e 7 dizem que a captura voltou pelo Refúgio.
- Dados: ReplicatedStorage/Data/Refuge (tabela da Forja, melhorias, Baú, modelo por nível).
- Servidor: ServerScriptService/World/RefugeService (iniciado no DataMain). Surgimento pela tabela (raridade, personagem e nível sorteados no servidor), contador com o jogador fora até o máximo, selvagens andando no campo, batalha Wild na arena normal (fugir, Selo de Contrato, Selo Superior), gold + XP na derrota, captura na coleção, contadores, Baú 30%, melhoria da Forja com gemas e todos os requisitos, coleta do Baú, guarda que tira qualquer um do Refúgio de outro jogador.
- Perfil: Refuge = { Forja, WildDefeated, Captures, Bau, Pending, LastSpawn, NextId } (salvo e validado no sanitize).
- Mundo: 10 Refúgios em workspace/Refugios (x = −1400, a cada 160 em z), 80 x 80 com montanhas de terreno, laguinho, cerejeiras, pinheiros, flores, lanternas com luz, pétalas e vaga-lumes, paredes e teto invisíveis, saída (caverna) que volta à base. Caverna em cada base com o prompt "Entrar no Refúgio".
- Forja: modelo troca nos níveis 4, 7 e 10 (Forja1/4/7/10), fogo com luz e brasas; na melhoria, explosão de brilhos e brasas, luz e som (só para o dono).
- Telas (kit de interface): Forja (nível, campo e próximo selvagem, chances atuais e do próximo nível lado a lado, custo, requisitos com progresso e marca, Melhorar só com tudo cumprido) e Baú (itens x/capacidade, Coletar tudo). Baú brilha quando tem itens.
- Captura reativada: Capture1 voltou ao sorteio das diárias.

**Testado (Play, 16/11/2026)**
- Entrada pela caverna da base 1 -> Refúgio 1 com 2 selvagens andando; batalha pelo prompt do selvagem; captura com Selo Superior (1 falha + 1 sucesso), volta ao Refúgio; derrota de outro selvagem: +18 XP e +30 gold; Baú: 12 itens (cheio, parou de receber), coletou tudo; saída volta à base.
- 10.000 surgimentos por nível (raridade sorteada) contra a tabela, maior desvio 0,93 ponto percentual; níveis sempre dentro da faixa:

| Nv | Comum | Raro | Épico | Lendário | Nível |
| --- | --- | --- | --- | --- | --- |
| 1 | 79,65 | 18,15 | 2,20 | 0,00 | 3-8 |
| 2 | 75,46 | 21,67 | 2,87 | 0,00 | 6-12 |
| 3 | 70,49 | 24,24 | 5,27 | 0,00 | 10-16 |
| 4 | 64,78 | 28,25 | 6,49 | 0,48 | 14-20 |
| 5 | 59,46 | 30,47 | 9,04 | 1,03 | 18-25 |
| 6 | 54,16 | 32,13 | 12,29 | 1,42 | 22-30 |
| 7 | 50,06 | 33,89 | 13,94 | 2,11 | 27-35 |
| 8 | 45,80 | 35,01 | 16,94 | 2,25 | 32-40 |
| 9 | 43,93 | 35,76 | 17,55 | 2,76 | 36-45 |
| 10 | 40,06 | 36,97 | 18,85 | 4,12 | 40-50 |

- Melhoria sem requisitos recusada ("Falta: Vencer a torre Fácil"). Com cada requisito forçado no teste, Forja subiu de 1 a 10 (modelo trocou em 4, 7 e 10; capacidade do Baú 12 -> 30); no 10 também recusou além do máximo. No nível 10 o Baú recebeu Selo Superior e Éter.
- Refúgio de outro jogador: prompt da caverna da base 2 recusado; teleporte direto para o Refúgio 2 devolveu à base em menos de 1,5 s.
- Sair e voltar (parar e iniciar o Play): Forja, contadores, Baú, pendentes e hora do último surgimento mantidos; relógio de teste +1 h encheu o campo até o máximo.
- Telas da Forja e do Baú em 667x375, 932x430 e 1024x768 sem nada fora da tela, botões ≥ 44 px, texto ≥ 9 px; no celular pequeno a lista de requisitos mostra 1,5 linha e rola.
- Perfil de teste restaurado ao fim (gold 350, gemas 15, minério 85, Forja 1, selos e poções como antes; personagens de teste removidos). Console sem erros. Place salvo.

**Valores que o GDD não define (escolhido o mais simples)**
- Gold por selvagem derrotado = 5 x nível. XP pela regra de vitória já existente (também na captura).
- Primeiro acesso já tem 1 selvagem no campo.
- "Derrotar N selvagens" conta só vitórias; capturas contam à parte.
- "Vencer a torre X" = o modo seguinte já está liberado no perfil (Tower.Unlocked).
- Baú: cada drop ocupa 1 espaço (minério 20-50 conta como 1); itens com a mesma chance; o que não cabe na mochila ou no depósito fica no Baú.
- IA dos selvagens = a mesma dos encontros antigos (Encounters.AI). Selvagem sem variante Brilhante.
- A semana continua com 5 missões; Capture5 segue guardada em Retention.DisabledMissions.
- Grama decorativa do terreno desligada (atravessava os pisos e pesa no celular).

**Pendências**
- IMPORTANTE: o elenco só tem Comuns. A raridade sorteada segue a tabela, mas o personagem entregue cai para a raridade mais próxima que existe (hoje sempre Comum). E o requisito do nível 10 (1 Lendário no nível 50) só pode ser cumprido quando existir um Lendário.
- Antes de publicar: apagar ReplicatedStorage/_UITestKit (a ponte _DevData e o gancho _UITest só existem no Studio).
- Teste com 2 jogadores reais no Refúgio (o bloqueio foi testado pelo servidor com 1 jogador).
- FPS real precisa ser medido num celular ou no cliente do Roblox (o Studio limita a 15 FPS com a janela sem foco).

## Correções do mapa v2 e do Refúgio (17/11/2026)

**Feito**
- Causa dos objetos tortos: os modelos importados tinham um giro de 35° no ponto de giro. Agora o kit inteiro usa a orientação real das peças. Torre, loja, cura, placares, estrelas, bases e Refúgios foram remontados alinhados (ServerStorage/_ConstrutorMapaV2).
- Modelos v2/v3 em C:\Blender\Mapa\modelos_v2: torre_v2 (74028982024992), loja_v2 com frascos e livros (108428759868732), arbusto_v2 com flores rente à folhagem (99674999364921), estrela_v3 lapidada dos dois lados, sem a peça branca (108741971821313).
- Torre:
  - sem pilastra no meio da porta;
  - telhados fechados por baixo;
  - placa "TORRE · BATALHA" sobre a porta;
  - gatilho da batalha na porta, raio 6, em (0, 16,9, 18,3).
- Estrelas: amarela toda amarela com "INVOCAÇÃO" em cima; roxa toda roxa com "PREMIUM"; giram em volta do próprio centro, retas; feixe e brilho mais finos.
- Bases:
  - cerca esticada para fechar;
  - postes nos 4 cantos e ao lado do portão;
  - portão, placa e caverna alinhados com a base.
- Grama 3D só no Refúgio (o chão do mapa principal virou LeafyGrass, que não recebe grama).
- Decoração só onde não encosta em esteira, caminho, praça, piso de base nem prédio (134 itens colocados).
- Esteira: animação no sentido do movimento; cantos com textura própria de seta diagonal (87988057101959).
- Loja: sem as lajes cinzas soltas; frascos de poção e livros no lugar dos blocos.
- Refúgio:
  - caminho reto da saída até a Forja;
  - a Forja fica de frente para quem chega, com o Baú ao lado;
  - sem planta em cima do caminho;
  - campo dos selvagens ao lado.
- Interface:
  - fundo escuro das telas cobre a tela toda;
  - "!" nas abas Login e Baús quando há recompensa;
  - ícone da música com as hastes atrás da barra (95544281526372).
- Nascimento: o jogador nasce dentro da própria base ao entrar e ao renascer.
- Luz: 17h30, mais escuro e com mais contraste (Brightness 1,9, exposição −0,25, contraste 0,15, bloom 0,85).

**Testado (Play):** nascimento na base 1 (dentro do piso); gatilho da torre não abre a 11 studs e abre na porta; estrela no centro e girando; textura da esteira andando; entrada no Refúgio com 2 selvagens e grama; console sem erros. Place salvo (versão 84).

**Observação:** "Missões" não ganhou "!" porque as missões pagam sozinhas ao completar (não há o que coletar).

## Doces de XP, torre e cantos da esteira (17/11/2026)

**Feito**
- Doces de XP:
  - Data/Items: DoceComum (+25% do XP do nível atual), DoceRaro (+1 nível) e DoceEpico (+3 níveis), Kind XpCandy, sem preço (fora da loja); Items.Candies com as chances 1% / 4% / 12%.
  - Sorteio no RefugeService, separado do item do Baú (os dois podem cair), no máximo 1 doce, do mais raro para o mais comum; vai para o Baú e ocupa espaço.
  - Uso pelo InventoryService (servidor): só fora de batalha e de corrida da torre, não no nível 50, e aprende golpes normalmente.
  - Menu Time: 3 botões de doce ao lado de SALVAR. Mochila e Baú mostram os doces; na batalha eles não aparecem.
  - Ícones em C:\Blender\UI\icones (doce_comum 135488822674293, doce_raro 132697637242766, doce_epico 140556027915418).
  - Efeito ao usar: brilhos e luz na cor do doce; o Épico tem mais partículas e anéis de luz; som cada vez mais grave e mais alto.
  - GDD: doces na tabela de itens (seção 7) e na seção 14.
- Torre v3 (86815076626655): beiral do telhado fechado embaixo (o perfil liga a casca de dentro à de fora) e forro inteiro sob cada telhado.
- Cantos da esteira: fundo parado com o mesmo chão e trilho dourado contínuo nas bordas de fora; setas iguais às da reta, apontando na diagonal da curva e andando na diagonal (texturas 110972069413902 e 132710023201167).

**Testado (Play)**
- 10.000 selvagens simulados: Épico 1,12% (1%), Raro 3,95% (4%), Comum 11,83% (12%), nenhum 83,10% (83%).
- Doce Comum no Kaen nível 14 (precisa de 140): +35 XP. Doce Raro: 14 -> 15 (+140). Doce Épico: 15 -> 18 (+480), XP do nível mantido.
- Recusados: doce em personagem nível 50 ("já está no nível máximo", o doce fica); durante a corrida da torre; na batalha (não aparece na mochila e o servidor recusa); sem o doce na mochila.
- Baú com doces coletado para a mochila. Menu Time em 667x375, 932x430 e 1024x768 sem sobreposição.
- Perfil de teste restaurado (níveis e golpes como antes, doces de teste removidos). Console sem erros. Place salvo.

## Personagens criados

| Nome | Tipo | Raridade | Arquétipo | Técnica assinatura | Pasta |
| --- | --- | --- | --- | --- | --- |
| Kaen | Fogo | Comum | Espadachim | Corte Flamejante | C:\Blender\Kaen |
| Raiko | Raio | Comum | Lutador de punho | Descarga | C:\Blender\Raiko |
| Yomogi | Natureza | Comum | Meio-fera da floresta | Gaiola de Espinhos | C:\Blender\Yomogi |

**Assets no Roblox (conta 5565234433)**
- Modelos: Kaen_Model 117657408739525, Raiko_Model 78113326921423 (cópias limpas em ServerStorage/Imported; usados em ServerStorage/Characters; provisórios em ServerStorage/_Provisorios).
- Animações Kaen: Parado 88420942400276, AtaqueEspada 99884602094930, LevarDano 131740669911517, Desmaiar 139425834905860, Andar 86922792134020, EspecialFogo 124938766679149, Vitoria 75519764514852.
- Animações Raiko: Parado 129793155417934, Soco 98054814666910, LevarDano 90948656598007, Desmaiar 87859867349833, Andar 88586219652073, EspecialRaio 117238114573517, Vitoria 84256418552203.

## Arquivos existentes em C:\Blender (16/11/2026)

- Kaen: Kaen.blend, Kaen_Model.fbx, Kaen_Tex.png, 7 animações FBX (Parado, Andar, AtaqueEspada, EspecialFogo, LevarDano, Desmaiar, Vitoria) e as mesmas em RobloxAnims (.rbxmx). Falta animação Minerar.
- Raiko: Raiko.blend, Raiko_Model.fbx, Raiko_Tex.png, 7 animações FBX (Parado, Andar, Soco, EspecialRaio, LevarDano, Desmaiar, Vitoria) e as mesmas em RobloxAnims (.rbxmx). Falta animação Minerar.
- Os arquivos estão soltos na pasta do personagem; o padrão da skill usa subpastas (modelo, texturas, animacoes, efeitos, referencias). Não mover os existentes; usar o padrão daqui em diante.

## Decisões e pendências

- Mochila/cura, decisões (GDD não define): Éter vai para o golpe com mais PP faltando; Reviver também limpa status; centro de cura é de graça e cura todos os personagens (time e base); compra em lotes de 1 ou 10; subir de nível não cura (o HP salvo continua o mesmo).
- Ponte de teste do Studio ganhou "setstate" (HP/status/PP) e "additem"; só existe no Studio.
- Pendente: venda de minério na loja (prompt 14); Cura Automática (passe, prompt 15).

- Encontros, valores que o GDD não define: níveis por zona (3-6, 6-10, 10-15, 15-20); 3 selvagens por zona; reaparecimento em 20 s; IA Fácil; selvagem aparece visível na zona (não por passo na grama); o capturado vem no nível em que estava; XP também na captura; selvagem sem variante Brilhante.
- Como o elenco só tem Comuns, Raro/Épico/Lendário sorteados viram Comum (mesma regra do portal).
- Selos de teste: o perfil do usuário recebeu 10 Selos de Contrato e 3 Selos Superiores pela ponte do Studio (ainda não há loja; prompt 13). Sobraram 10 + 2.
- Uma cerejeira do mapa fica dentro do Campo das Libélulas (decoração antiga; não atrapalha os selvagens).

- Invocação, valores que o GDD não define: nível do invocado = 5; prêmio do Álbum = 1.000 gold + 10 gemas por grupo; fusão mantém a melhor cópia e consome 2 cópias fora do time; venda só de repetidos (precisa sobrar outra cópia) e fora do time; personagem invocado entra no time se houver vaga.
- IMPORTANTE: o elenco só tem Comuns. Quando sai Raro, Épico ou Lendário, vem um personagem da raridade abaixo mais próxima (Comum), e a carta avisa. Some quando o elenco tiver essas raridades. O anúncio no chat usa a raridade entregue.
- Brilhante de Kaen e Raiko fica só nos dados (eles ainda não têm textura Brilhante/VariantPresets).
- Perfil de teste do usuário: recebeu 2.700 gold pela ponte do Studio para as 10 invocações; o resultado ficou salvo (gold 4.050, gemas 40, Kaen 1 estrela).
- Pendente: Portal Premium e PolicyService (prompt 15); Sorte em Dobro e Invocação Rápida (prompt 15); limite de vagas da coleção (Depósito Ampliado).

- Torre, valores que o GDD não define: item do Médio = 1 Superpoção; itens do Difícil = 1 Hiperpoção + 1 Reviver; bônus do Infinito a cada 5 andares = 500 gold; recorde = maior andar vencido; o personagem do chefe vem no nível do chefe (vai para o time se houver vaga); a cura de 30% entre andares vale também para quem desmaiou; status e PP não são recuperados entre andares; nível dos inimigos limitado a 50.
- Pendente torre: só 1 arena (1 corrida por vez no servidor); mochila da corrida ainda é BattleConfig.StartingBag (prompt 13); temporada mensal do placar e aparências do top 100 (prompt 17); com só 3 personagens no elenco os times de NPC repetem personagens. O adversário avulso do BattleConfig (Raiko nível 3) não é mais usado pelo gatilho da torre.

- Valores que o GDD não define (prompt 9): XP para subir do nível N = 10 x N; XP por vitória = 3 x soma dos níveis dos inimigos, para cada personagem que entrou em campo (só na vitória); XP em Dobro multiplica por 2 (Benefits.XpEmDobro); inicial começa no nível 5; perfil novo com gold, gemas e mochila zerados; golpes iniciais no nível 1 e golpes novos nos níveis 5 e 10.
- Pendente: golpes dos níveis 18, 26, 35 e 45 não existem ainda (entram com o elenco). Personagem inicial de Água não existe (dispensado no lote); a tela mostra só Kaen e Yomogi até ele ser criado (basta Starter = true nos dados).
- Adversário da torre provisório: 1 Raiko nível 3 com IA Fácil, até o prompt 10 (com 2 inimigos nível 5 o inicial sozinho perdia). A batalha ainda usa BattleConfig.StartingBag, não a mochila salva (prompt 13). HP não persiste entre batalhas (cura, prompt 13).
- O Studio precisa de "Acesso do Studio aos serviços de API" ligado (ativado pelo usuário em 16/11/2026).

- Yomogi: valores escolhidos (GDD não define): golpes, atributos 64/21/23/19 dentro da faixa da skill. Capturas do Studio não foram salvas em C:\Blender\Yomogi\referencias (só os renders do Blender); as do teste ficaram na conversa.
- Kaen e Raiko ainda usam animação no servidor; migrar os golpes deles para Anim/Vfx no cliente quando o prompt 4 for feito.
- Personagem de Água do lote: dispensado pelo usuário em 16/11/2026.

- Veneno, Sono e Congelamento: nenhum golpe do GDD aplica esses status. O motor aceita os 5 pelo campo Effect dos golpes e por Battle:ApplyStatus; no teste foram aplicados pelo motor. Golpes que os apliquem entram com o elenco de 12 (prompt 8).
- Times da torre em BattleConfig repetem Kaen e Raiko (3x3) até existir o elenco de 12.
- Valores que o GDD não define (escolhido o mais simples): estágios negativos espelham os positivos (-1 = x2/3 ... -6 = x1/4); sono conta no fim do turno e o congelamento sorteia os 20% ao tentar agir; desmaio limpa o status; a máquina (Fácil e Médio) manda o próximo na ordem do time; Poção pode mirar membro da reserva; Mochila do protótipo com 1 Poção; golpe reserva Esforço (poder 30, Neutro) só quando todos os golpes estão sem PP; tipo de Postura de Combate = Neutro e de Estática = Raio (só cor do botão).
- Pendente (REGRAS): animações dos personagens e partículas de impacto ainda são disparadas no servidor (BattleService/CharacterLibrary). Mover para o cliente no prompt 4 (Sistema de efeitos), com marcadores Charge, Release, Impact.
- Pendente: só existe 1 das 12 arenas (Arenas/Arena01); com mais de 1 jogador em batalha ao mesmo tempo, o segundo espera a arena liberar.
- Pendências do GDD (seção 12): nome do jogo, troca entre jogadores, validação de preços e teto de gemas.
- Base (prompt 14, valores não definidos no GDD, escolhido o mais simples): "excedente fica guardado" = minério que não cabe no depósito de 10.000 fica pendente na base até ter espaço; o teto de 50 gemas é por dia UTC; produção fracionada fica acumulada (só inteiros são coletados); personagem pode estar no time de batalha e na base ao mesmo tempo; com mais de 12 jogadores no servidor não há terreno (12 terrenos).
- Base: Kaen e Raiko usam a animação de mineração do Yomogi (mesmo rig); trocar por uma própria quando os modelos finais forem feitos.
- Monetização (prompt 15, valores que o GDD não define, escolhido o mais simples): limite de personagens = 100 (Depósito Ampliado +50); Sorte em Dobro tira o extra do Comum (Comum 63%); Invocação Rápida custa 3x o preço de 1 e vale nos dois portais; Cura Automática cura HP, status e PP só do time; VIP "aparência de base" = cerca e portão dourados e placa com a tag; banner troca toda segunda 00:00 UTC, rodízio pela lista Banner.Rotation (vazia = Lendários do elenco em ordem alfabética).
- Pendente: o elenco não tem Lendário, então o Portal Premium mostra "sem destaque" e o que sai Raro/Épico/Lendário vira Comum (mesma regra do Portal Comum). Portal Premium é cópia recolorida do Comum (sem arquivo novo em C:\Blender\Mapa).
- Pendente (usuário): criar os 9 passes e 3 produtos no painel do Roblox e colar os IDs em ReplicatedStorage/Data/ProductIds. Compra real em Robux só pode ser testada depois disso (no Studio é compra de teste, sem cobrança).
- Passe com ID 0 que já está no perfil como "Pass" não é reconferido (só passes com ID são conferidos na entrada).
- PvP (prompt 16, valores que o GDD não define, escolhido o mais simples): sem prêmio e sem XP no PvP; estrelas e variante valem no PvP; golpes ativos são os salvos (não ganham os golpes do nível 50); distância do desafio 12 studs; 20 s para aceitar; ação automática = golpe aleatório com PP.
- Pendente PvP: só 1 arena (um PvP ou batalha por vez no servidor); o placar/ranking de PvP não existe (GDD não pede).
- Teste em servidor local: os clientes de teste mostram um aviso do motor "ContentId rbxassetid://134973377891827 failed" (asset sem permissão para os jogadores de teste); não vem dos scripts.
- Teste local deixa as contas de teste Player1/2/3 (UserId -1, -2, -3) salvas no DataStore do Studio; não afetam jogadores reais.
- Interface (prompt 18, valores que o GDD não define): tamanhos de teste = 667x375, 932x430 e 1024x768; barra do Roblox = 58 px; menor texto = 9 px. Ponte de teste só do Studio: PlayerGui._UITest (abre telas e aciona botões) e atributo DeviceEmu no PlayerGui (simula o tamanho do aparelho).
- Backup dos clientes antigos da interface em ServerStorage/_UIBackup (desativados; não vão para o jogador). O módulo antigo UIKit não é mais usado. Apagar os dois quando a interface nova for aprovada.
- Pendente interface: a aba Repetidos não teve captura nova depois do último ajuste (testada sem erros); o Portal Premium usa a mesma tela do Comum em dourado.

## Telas no celular, segurança e desempenho (17/11/2026)

**Telas (seção 10) em 667x375, 932x430 e 1024x768**
- Verificação automática em todas as telas e abas: HUD, Time, Mochila, Base, Loja (3 abas), Prêmios (5 abas), Invocação (Portal, Álbum, Repetidos, Resultado), Configurações, Torre, Forja, Baú, Batalha (menu, Lutar, Mochila, Time, cronômetro) e caixa de desafio PvP. Agora também confere texto cortado (TextFits), além de fora da tela, botão < 44 px e texto < 9 px.
- Corrigido:
  - Forja: chances em grade 2 x 2 (no celular pequeno as 4 linhas tinham 7 px de altura e o texto vazava); título "AGORA/PRÓXIMO" cabia cortado.
  - Torre: textos do Difícil ("1500 gold, Hiperpoção, Reviver, 5 gemas/dia") e do Infinito cortados; botão ENTRAR mais estreito, área de texto maior, placar 34% da largura; "Temporada: X · Recorde: Y".
  - Prêmios: dia 7 mostrava só "1 invocação" (agora 2 linhas com "Premium").
  - Mochila: cartão do Doce Comum e do Reviver com texto curto (campo Short em Data/Items; o texto completo segue no painel do item).
  - PvP: caixa de desafio um pouco à direita para não cobrir os botões Base e Álbum do HUD.
- Batalha, Loja, Time, Base, Configurações, Invocação e Baú: sem problema nos 3 tamanhos (menor texto 11 px).

**Segurança: 37 remotes (25 RemoteFunction, 12 RemoteEvent)**
- Do cliente para o servidor (todos conferidos): SubmitAction, TowerStart, TowerBoard, TowerClose, GetProfile, ChooseStarter, SetActiveMoves, SaveSettings, Rewards, Summon, SummonBanner, Fuse, SellDuplicate, BuyItem, UseItem, BaseSetState, BaseCollect, BaseUpgrade, SellOre, BaseTeleport, BuyBenefit, PvPChallenge, PvPRespond, PvPCancel, RefugeState, RefugeUpgrade, RefugeCollect. Só do servidor para o cliente (o servidor não escuta): Announce, BattleEnd, BattleUpdate, Notify, ProfileUpdated, PvPInvite, StartBattle, TowerOpen, CandyFx, RefugeFx.
- Prova (Play, chamadas falsas feitas pelo cliente): 50 pedidos com quantidade negativa, NaN, 1e9, fracionada, ids e uids falsos, tabelas no lugar de texto, portal/benefício/baú/código inexistentes, compra sem gold/gemas, starter de novo, golpe de outro personagem, 5 golpes, torre trancada, PvP consigo mesmo, convite falso, coleta/venda repetida e 12 códigos seguidos: todos recusados. Gold, gemas e personagens só mudaram pelas ações legítimas (coleta da base e venda de minério), desfeitas no fim.
- Corrigido:
  - TowerStart: só vale com a tela aberta pela porta da torre (antes dava para entrar na torre de qualquer lugar, até do Refúgio).
  - Passe comprado: o servidor confere a posse no Roblox (UserOwnsGamePassAsync) antes de dar o benefício; passe falso com "comprado = true" foi recusado no teste.
  - Pacote de gemas: se o salvamento falhar, as gemas e o recibo ficam no perfil e o Roblox tenta de novo sem entregar duas vezes (antes desfazia; com gasto no meio e o saldo negativo zerado no salvamento, dava gemas extras). Teste: recibo repetido não somou gemas.
  - SubmitAction: no máximo 1 pedido a cada 0,15 s por jogador.
  - BaseTeleport: recusado durante batalha ou corrida da torre.
  - BaseSetState: personagem vendido ou fundido sai da base na hora (não ocupa vaga até a próxima entrada).

**Desempenho (Studio, 1 jogador real + 11 simulados andando, 10 bases com 6 personagens, 10 Refúgios com 2-3 selvagens)**
- Antes: servidor 60 Hz, trabalho por quadro 0,63 ms, física 0,06 ms, envio 31-35 KB/s por jogador. Cliente na praça: 235 mil triângulos, 333 draw calls, 74 luzes, 72 emissores.
- O que pesava: os personagens das bases e os selvagens andavam com Tween no servidor, que manda a posição todo quadro (cerca de 28 KB/s por jogador, 90% do envio).
- Corrigido:
  - Passeio das bases e do Refúgio: o servidor manda só o passo (atributos WalkFrom, WalkTo, WalkT0, WalkDur) e acerta a posição 2 vezes por segundo; o novo StarterPlayerScripts/NpcWalkClient anda liso no cliente (só até 300 studs da câmera).
  - MapFxClient: na arena e no Refúgio nada do mapa é animado; lanternas só piscam a até 150 studs da câmera (eram 110 luzes mudando 10 vezes por segundo).
- Depois: trabalho por quadro 0,17 ms, envio 4,8 KB/s por jogador (−86%). Movimento no cliente sem salto (maior passo 0,6 stud por quadro a 15 FPS).
- O resto não pesa: luzes sem sombra (144, alcance médio 13), 92 personagens = 64 mil triângulos, laços do servidor a cada 0,2-10 s.

**Valores escolhidos (o GDD não define):** intervalo mínimo de 0,15 s entre ações de batalha; acerto de posição 2x/s; animação de lanterna até 150 studs.

**Pendente**
- O servidor tem 10 vagas (serverSize 10); o teste usou 12 como carga extra. Os jogadores 11 e 12 ficariam sem terreno (10 bases).
- FPS real precisa ser medido num celular (o Studio sem foco trava em 15 FPS).
- Antes de publicar: apagar ReplicatedStorage/_UITestKit.
- Time: o GDD pede "trocar ordem" do time; não existe remote para isso hoje (não foi mexido).

**Testado:** console sem erros e sem avisos; perfil de teste restaurado (gold 722, gemas 15, minério 249, 12 personagens). Place salvo (versão 93).

## Reestruturação Disk-First + Substituição Hikari -> Satoru (17/11/2026)

**Feito**
- Arquitetura Disk-First (`src/` + `default.project.json` + `scripts/sync_studio.py` + `ARQUITETURA_PROJETO.md` + `AGENTS.md`):
  - Todos os 74 scripts extraídos e sincronizados em `src/`.
  - `BattleService` (1.724 linhas) desacoplado em `ReplicatedStorage/Core/BattleEngine`, `ReplicatedStorage/Core/DamageCalc`, `ReplicatedStorage/Core/AIController`, `ServerScriptService/Battle/ArenaManager` e `ServerScriptService/Battle/BattleService`.
- Substituição do `Setero` pelo `gojoFinal.fbx` (Rig Mixamo convertido para R15 Skinned Mesh, 17/11/2026):
  - `src/` sincronizado previamente com as mudanças do Studio (`Setero`, golpes `Atracao` e `TudoRoxo`, `VfxController` com Cut-In).
  - `d:\Downloads\gojoFinal.fbx` (`4.786` triângulos, `2.393` vértices, 22 grupos de pesos do Mixamo) processado no Blender 5.3.0:
    - Limpeza da Action do Mixamo que rotacionava o quadril em -90° X e alinhamento da malha/esqueleto em pé (+Z up no Blender / +Y up no Roblox), centralizado na origem com a sola dos pés em Z=0 e escala nativa de 5,80 studs (`4,78 x 5,80 x 1,94` studs).
    - Pose dos braços convertida da T-pose para a A-pose de 50° do padrão R15 do projeto usando os próprios pesos do Mixamo.
    - Remapeamento dos 22 grupos de vértices do Mixamo para os 15 ossos oficiais do R15 (`LowerTorso`, `UpperTorso`, `Head`, `LeftUpperArm`, `LeftLowerArm`, `LeftHand`, `RightUpperArm`, `RightLowerArm`, `RightHand`, `LeftUpperLeg`, `LeftLowerLeg`, `LeftFoot`, `RightUpperLeg`, `RightLowerLeg`, `RightFoot`), todos com orientação de repouso identidade (`1, 0, 0, 0, 1, 0, 0, 0, 1`) para compatibilidade total com as 9 animações R15 publicadas do `Setero`.
  - Arquivos gerados em `Blender/Setero/`: `modelo/Setero_R15.blend`, `modelo/Setero_R15.fbx` (Asset ID `84606453436136`), `texturas/Setero_Tex.png` (`rbxassetid://119041359331012`) e `texturas/Setero_Tex_Brilhante.png` (`rbxassetid://126096172218731`).
  - `ServerStorage/Characters/Setero` e `ReplicatedStorage/CharacterPreviews/Setero` atualizados; `VfxController.luau` atualizado para ler `Bone.TransformedWorldCFrame.Position` de `LeftHand`/`RightHand` durante os efeitos de `Atracao` e `TudoRoxo`.
- Montagem do modelo 3D de `San` a partir de `c:\Users\vieir\Documents\goku.fbx` (18/11/2026):
  - Sincronização prévia do Studio para `src/` (`Characters.luau`, `Moves.luau`, `VfxController.luau` incluindo `San` e `BarbaBranca`).
  - `goku.fbx` (`4.712` triângulos divididos nas 6 partes `Head`, `Torso`, `LeftArm`, `RightArm`, `LeftLeg`, `RightLeg` + textura `1024x1024` embutida) processado no Blender 5.3.0:
    - Braços rotacionados da T-pose (+90°/-90° Y) para a pose vertical de descanso do rig R6/R15, alinhados aos ombros e tronco; sola dos pés em Z=0 e escala calibrada para `4,303` studs até o ombro (`6,41` studs até o topo do cabelo).
    - Arquivos salvos em `Blender/Goku/modelo/San_Goku_R6_v2.blend`, `Blender/Goku/modelo/San_Goku_R6_v2.fbx` (Asset ID `111883369706058`, com fechamento sólido de todas as bordas abertas das juntas, devolução dos 251 triângulos da calça para as pernas e faces duplas para eliminar qualquer efeito oco), `Blender/Goku/texturas/Goku_Tex.png` (textura nativa embutida `rbxassetid://72285574416924`) e `Blender/Goku/texturas/Goku_Tex_Brilhante.png` (`rbxassetid://119066022873724`).
  - Montado em `ServerStorage/Characters/San` e `ReplicatedStorage/CharacterPreviews/San` soldando `Head_Mesh`, `Torso_Mesh`, `LeftArm_Mesh`, `RightArm_Mesh`, `LeftLeg_Mesh`, `RightLeg_Mesh` às partes correspondentes do esqueleto R15 invisível (`Head`, `UpperTorso`, `LeftUpperArm`, `RightUpperArm`, `LeftUpperLeg`, `RightUpperLeg`), preservando 100% das 12 animações publicadas de `San` (`Kamehameha`, `GenkiDama`, `ComboMarcial`, `CargaDeKi`, `Idle`, `Walk`, etc.).
- Animação padrão universal de caminhada (`Walk`) + respiração/vida (`Idle`) e Acompanhante da Party (`PartyFollower`, 18/11/2026):
  - Geradas e publicadas as animações padrão `Padrao_Idle` (`Blender/AnimacoesPadrao/Padrao_Idle.rbxm`, Asset ID `82392963584557`) e `Padrao_Walk` (`Blender/AnimacoesPadrao/Padrao_Walk.rbxm`, Asset ID `113228340758956`), registradas em `Characters.DefaultAnimations` e aplicadas em `San`, `BarbaBranca` e `Luffy`.
  - `src/client/PlayerScripts/BaseClient.client.luau`: motor procedural universal a 60 FPS (`Motor6D.Transform` e `Bone.Transform`) para todas as tags (`PartyFollower`, `BaseCharacter`, `RefugeWild` e `BattleCharacter`), combinando o ciclo contínuo de vida/respiração do `Idle` (expansão do tronco, leve balanço vertical, movimento vivo de cabeça/olhar e abertura suave dos braços) com a caminhada limpa do `Walk` ("apenas andar": passada alternada das pernas `±27°`, balanço oposto dos braços `∓24°`, quique de passo e contra-rotação de quadril/tronco, com transição suave `walkAlpha`), adaptando-se automaticamente a rigs em I-Pose (`San`, `BarbaBranca`, `Luffy`) e A-Pose (`Kaen`, `Raiko`, `Yomogi`, `Setero`, `Proto*`).
  - `src/server/World/PartyFollowerService.luau` + `src/client/PlayerScripts/NpcWalkClient.client.luau`: o primeiro personagem com vida positiva (`HP > 0`) da party (`data.Team`) acompanha o jogador pelo mundo a 60 FPS, alternando automaticamente entre `Walk` em movimento e `Idle` ao parar ao lado do jogador, trocando para o próximo membro vivo se o 1º desmaiar e ocultando-se durante batalhas na Arena.

## Pipeline Automático Tripo + Criação do Personagem `Luffy` [EM ANDAMENTO] (18/11/2026)

**Feito (Etapa 1 — Modelo 3D, Rig e Códigos de Dev)**
- Criado o pipeline automático `scripts/auto_rig_tripo.py` (corte matemático por 5 planos `bisect_plane`, extração automática de `.fbm`/`.zip`, rotação automática de braços da T-Pose, fechamento sólido de juntas e faces duplas em ~6 segundos).
- **`Luffy` adicionado ao jogo (Status: EM ANDAMENTO):**
  - Processado `tripo_convert_3d5b6b4b-617c-4b06-bdcf-448e15a220b2.fbx` via `scripts/auto_rig_tripo.py --char Luffy`:
    - Arquivos gerados em `Blender/Luffy/`: `modelo/Luffy_R6_Auto.blend`, `modelo/Luffy_R6_Auto.fbx` (Asset ID `71578599746074`, textura nativa `rbxassetid://112013281559536`), `texturas/Luffy_Tex.png`, `texturas/Luffy_Tex_Brilhante.png`, `referencias/Luffy_preview_front.png` e `referencias/Luffy_preview_34.png`.
  - Montado em `ServerStorage/Characters/Luffy` e `ReplicatedStorage/CharacterPreviews/Luffy` e registrado em `src/shared/Data/Characters.luau` (Lendário, Fogo, com golpes e animações provisórias funcionais).
- **Códigos de Dev para resgate de personagens na aba `Prêmios -> Códigos` (`src/server_storage/Codes.luau` + `src/server/Data/RetentionService.luau`):**
  - Suporte a `Character`, `Characters` e `Repeatable = true` (podem ser resgatados quantas vezes o dev quiser):
    - `LUFFY` ou `DEVLUFFY` -> +1 **Luffy** (Nv. 10)
    - `SAN`, `GOKU` ou `DEVSAN` -> +1 **San** (Nv. 10)
    - `SETERO`, `GOJO` ou `DEVSETERO` -> +1 **Setero** (Nv. 10)
    - `BARBABRANCA` ou `DEVBARBABRANCA` -> +1 **Barba Branca** (Nv. 10)
    - `KAEN` ou `DEVKAEN` -> +1 **Kaen** (Nv. 10)
    - `RAIKO` ou `DEVRAIKO` -> +1 **Raiko** (Nv. 10)
    - `YOMOGI` ou `DEVYOMOGI` -> +1 **Yomogi** (Nv. 10)
    - `DEVALL` -> Recebe todos os 7 personagens principais (Nv. 10) de uma vez.

**Pendente para concluir o `Luffy` (Em Andamento)**
- Criar golpes exclusivos personalizados do `Luffy` em `src/shared/Data/Moves.luau`.
- Criar animações exclusivas dos golpes do `Luffy`.
- Criar VFX exclusivos e Cut-In do `Luffy` em `src/shared/VfxController.luau`.

## Lote One Piece (`Nami`, `Usopp`, `Zoro`, `Sanji` + Novo `BarbaBranca`) [EM ANDAMENTO] (18/11/2026)

**Feito**
- Melhorias no [auto_rig_tripo.py](file:///c:/Users/vieir/Documents/antigravity/RobloxProjetoX/scripts/auto_rig_tripo.py):
  - Adicionado parâmetro `--shoulder-height` (padrão `4.303`, `4.577` para o colosso `BarbaBranca`).
  - Cálculo de `W_core` usando `min(+X, -X)` na faixa das canelas (`6%..22%`) e detecção de `arm_zs` nas pontas externas dos braços (`|X| > 1.90 * W_core`) sem teto artificial de `0.72*H` — garantindo corte limpo tanto em personagens sem chapéu (`Zoro`, `Sanji`) quanto em personagens com bolsa lateral (`Usopp`).
- Processados os 5 modelos da pasta `C:\Users\vieir\Desktop\Tripo` (com extração automática das texturas `.fbm` de `d:\Downloads\*.zip`):
  - **`Nami`** (`Comum`, `Raio`, `Anime = "OnePiece"`, Asset `90585959059032`, tex `97963439106095`) — *Em Andamento* (modelo/rig prontos; faltam golpes/anims/VFX exclusivos).
  - **`Usopp`** (`Comum`, `Natureza`, `Anime = "OnePiece"`, Asset `138631614692730`, tex `134510959711457`) — *Em Andamento* (modelo/rig prontos; faltam golpes/anims/VFX exclusivos).
  - **`Zoro`** (`Raro`, `Trevas`, `Anime = "OnePiece"`, Asset `109146576955083`, tex `91845586938167`) — *Em Andamento* (modelo/rig prontos; faltam golpes/anims/VFX exclusivos + katanas).
  - **`Sanji`** (`Raro`, `Fogo`, `Anime = "OnePiece"`, Asset `117184318457931`, tex `137388931945248`) — *Em Andamento* (modelo/rig prontos; faltam golpes/anims/VFX exclusivos).
  - **`Luffy`**: Raridade atualizada para **`Épico`** (`Rarity = "Epico"`, `Anime = "OnePiece"`).
  - **`BarbaBranca`** (`Lendário`, `Água`, `Anime = "OnePiece"`, Asset `111259172785579`, tex `117972934142844`):
    - Modelo antigo substituído pelo novo modelo do Tripo (backup do modelo anterior mantido em `ServerStorage/Imported/BarbaBranca_OldBackup`).
    - Acessórios preservados e ressoudados em `Marineford3D`: **Capa (`Coat_Acc` + `Coat_JollyRoger`)** descendo até o fim das pernas e **Bisento (`Murakumogiri_Acc`)** nas costas (compatível com `setBackBisentoHidden` em `CorteMurakumo`).
    - Adaptação dos braços (`LeftArm_Mesh` / `RightArm_Mesh` calibrados para `1.08 x 2.16 x 1.08` alcançando `Y = 19.02` junto aos ossos `LeftHand`/`RightHand` em `Y = 19.04`) e reforço nos testes de todas as animações exclusivas (`SocoSismico`, `CeuETerra`, `CorteMurakumo`, `HakiDoConquistador` + `Idle`/`Walk`).
- Códigos de Dev adicionados em `src/server_storage/Codes.luau`: `NAMI`, `USOPP`, `ZORO`, `SANJI`, `ONEPIECE` (entrega os 6 personagens de One Piece) e `DEVALL` atualizado.


## Categorização por Anime e Filtros na Equipe e Mochila (18/11/2026)

**Feito**
- `src/shared/Data/Characters.luau`: adicionadas `Characters.AnimeOrder` e `Characters.Animes` (`DragonBall`, `OnePiece`, `JujutsuKaisen`, `Generico` com `Generic = true`), campo `Anime` em todos os personagens (`San` -> `DragonBall`; `BarbaBranca` e `Luffy` -> `OnePiece`; `Setero` -> `JujutsuKaisen`; provisórios `Kaen`, `Raiko`, `Yomogi`, `ProtoRaro` e `ProtoEpico` -> `Generico`) e helpers puros (`AnimeOf`, `AnimeInfo`, `AnimeDisplay`, `IsGeneric`, `ByAnime`). A tag não é exibida diretamente nos cartões/modelos do jogo.
- `src/server/CharacterLibrary.luau`: `Characters.Spawn` passa a marcar os atributos não visuais `Anime` e `GenericCharacter` nos modelos instanciados no servidor.
- `src/shared/CharacterFilter.luau`: módulo compartilhado para normalização de busca por nome (sem distinção de maiúsculas/acentos), filtragem por anime/raridade/tipo e ordenação (`Raridade`, `Geral`, `HP`, `Attack`, `Defense`, `Speed`, `Nivel`, `Recente`).
- `src/shared/UI.luau`: adicionado o componente `UI.searchBox` com botão limpar (`44x44` px mínimos de toque) integrado ao tema e ao kit de teste `_UITestKit`.
- `src/client/Gui/EquipeGui/EquipeClient.client.luau`: integrada a barra de filtros com pesquisa por nome, filtro por Anime, Raridade, Tipo e ordenação por Status Geral e Status individuais (`HP`, `ATQ`, `DEF`, `VEL`), além de `Nível`, `Raridade` e `Recente`, com layout responsivo em 1 ou 2 linhas.
- `src/client/Gui/BagGui/BagClient.client.luau`: janela `MOCHILA` organizada em abas `ITENS` (preservando uso de Poções/Reviver) e `PERSONAGENS` (grade filtrável com busca por nome, Anime, Raridade, Tipo, ordenação por Status Geral/individual e exibição dos atributos finais de cada personagem).

**Testado (Play & Audit, 18/11/2026)**
- Validados `Characters.AnimeOf`, `IsGeneric`, `ByAnime` (excluindo/incluindo `Prototype`) e atributos em `CharacterLibrary.Spawn` no servidor.
- Validados filtros interativos, limpeza da pesquisa (`Clear`), filtragem por cada Anime (incluindo `Genérico`) e ordenações de status em `EquipeGui` e `BagGui`.
- Auditoria responsiva (`_UITestKit.audit` + `TextFits`) sem erros nas resoluções `667x375`, `932x430` e `1024x768`, console limpo, `sync_studio.py status` (`76/76` em sincronia), `sync_studio.py test` (`PASS`) e `save_place` salvo na versão `189`.

## Intangibilidade do Acompanhante da Party (`PartyFollower`, 18/11/2026)

**Feito**
- `src/server/World/PartyFollowerService.luau`: registrado grupo de colisão `PartyFollower` no `PhysicsService` com colisão desativada contra todos os grupos (incluindo `Default` e o próprio `PartyFollower`), desativado `Humanoid.EvaluateStateMachine = false` para impedir a máquina de estados do Humanoid de reativar `CanCollide = true` nos 14 membros a cada passo físico, e aplicadas as propriedades `CanCollide = false`, `CanQuery = false`, `CanTouch = false`, `Massless = true` e `CollisionGroup = "PartyFollower"` em todos os `BasePart`s (atuais e futuros via `DescendantAdded`).
- `src/client/PlayerScripts/NpcWalkClient.client.luau`: reforçada no cliente a intangibilidade (`CanCollide = false`, `CanQuery = false`, `CanTouch = false`, `Massless = true` e `Humanoid.EvaluateStateMachine = false`) ao receber cada `PartyFollower` via tag ou `DescendantAdded`.

**Testado (Play, 18/11/2026)**
- Validado no servidor e no cliente que todas as 74 partes de `Follower_celinn1221` permanecem com `CanCollide = false`, `CanQuery = false`, `CanTouch = false`, `Massless = true`, `CollisionGroup = "PartyFollower"` e `EvaluateStateMachine = false`.
- Validados `PhysicsService:CollisionGroupsAreCollidable("Default", "PartyFollower") == false`, `CollisionGroupsAreCollidable("PartyFollower", "PartyFollower") == false`, raycast e `GetPartBoundsInBox` atravessando o modelo sem detecção, caminhada do jogador atravessando o espaço do acompanhante sem travar/colidir e animações procedurais do `BaseClient` ativas normalmente, console sem erros.

## Fundo de Raridade nos Cartões, Picareta/Distância na Mineração e Iluminação em Batalha (18/11/2026)

**Feito**
- `src/shared/TeamCards.luau`: alterado o fundo interno (`innerFill`) de todos os cartões 3D (barra do time e grade/slots de Equipe) para usar um degradê vibrante na cor da raridade do personagem (`Comum`, `Raro`, `Epico`, `Lendario`), mantendo o roxo escuro do HUD apenas nos espaços vazios e reforçando o gradiente escuro da base para preservar leitura do nome.
- `src/server/Economy/BaseService.luau`: atualizada a função `minePoint` (com `quarrySurfaceRadius`) para calcular dinamicamente o alcance horizontal da pedra/vagoneta na direção de cada minerador, somar o raio da bounding box do personagem (`+1.6` studs de folga, sem ativar colisão) e distribuir os 1..6 mineradores em arco simétrico no lado aberto da pedreira dentro dos limites locais do `Floor`.
- `src/client/PlayerScripts/BaseClient.client.luau`: adicionado construtor estilizado de picareta (`MiningPickaxe`) acoplado à mão direita durante `BaseState == "Mine"` (com `Weld` por `C0` relativo para rigs I-Pose `RightArm_Mesh` e R15 `RightHand`, e atualização `RenderStepped` via `Bone.TransformedWorldCFrame` para Skinned Meshes como `Setero`), além de ciclo procedural polido a 60 FPS (preparação overhead com giro de tronco, golpe rápido, recuo de impacto com faíscas e retorno) substituindo a track estática antiga.
- `src/client/Gui/BattleGui/BattleClient.client.luau` + `src/shared/VfxController.luau`: ajustada a iluminação ao entrar em batalha (`setInBattle`) limitando `Lighting.Brightness` para `0.85`, `ExposureCompensation` para `-0.55`, suavizando o `BloomEffect` (`Intensity = 0.16`, `Size = 14`, `Threshold = 2.35`), desligando `SunRays` (com restauração automática ao sair), e reduzidos os picos de flash (`impactFrame` e `CritFlash` para `0.08`) e o teto de `pulseLight` (`4.0`) para evitar tela estourada/clara em excesso.

**Testado (Play & Capturas visuais, 18/11/2026)**
- Verificados visualmente em captura no Studio os cartões com fundos diferenciados por raridade na `TeamBarGui` e na `EquipeGui` (`Comum`, `Raro`, `Épico`, `Lendário`).
- Testados 5 mineradores ativos simultaneamente na base (`BarbaBranca`, `Luffy`, `San`, `Setero`, `Kaen`) fora da pedra (`11,19` a `13,21` studs do centro, `CanCollide = false`), com `MiningPickaxe` rígida e conectada à mão (`diff` entre `1.04` e `1.60` studs) e animação procedural ativa a 60 FPS.
- Verificada batalha na Torre (`Arena08`) com captura visual confirmando nitidez sem halo branco estourado (`Brightness = 0.85`, `Exposure = -0.55`, `Bloom = 0.16/2.35`, `SunRays = false`).
- `sync_studio.py status` (`76/76` em sincronia), `sync_studio.py test` (`PASS`) e Place salvo na versão `199`.


## Armas dos Mugiwara: Estilingue do Usopp, Clima-Tact da Nami e 3 Katanas do Zoro (18/11/2026)

**Feito**
- `scripts/build_onepiece_weapons.py`: gerador procedural em Blender (`5.3.0`) criando os 3 assets estilizados com texturas atlas empacotadas e geometria limpa (sem z-fighting nem interseções entre partes):
  - **Estilingue do Usopp (`Usopp_Slingshot`)**: salvo em `Blender/Usopp/assets/Usopp_Slingshot.{blend,fbx}` + textura `Usopp_Slingshot_Tex.png` (`6576 tris`, arco em C verde vibrante com spline contínua, ponteiras esféricas com pinos dourados, faixa branca enrolada no cabo e elástico marrom com bolsa). Model Asset ID `128117434407417`, Image Asset ID `124260365265708`.
  - **Bastão Clima-Tact da Nami (`Nami_ClimaTact`)**: salvo em `Blender/Nami/assets/Nami_ClimaTact.{blend,fbx}` + textura `Nami_ClimaTact_Tex.png` (`1924 tris`, 3 estágios telescópicos azul celeste/cobalto, boca oca alargada no topo e pinos claros laterais). Model Asset ID `71795664726246`, Image Asset ID `74537249516138`.
  - **3 Katanas do Zoro (`Zoro_Katanas`)**: salvo em `Blender/Zoro/assets/Zoro_Katanas.{blend,fbx}` + textura `Zoro_Katanas_Tex.png` (`3260 tris`, conjunto único embainhado de `Wado Ichimonji` branca com guarda redonda, `Yubashiri` preta com guarda em cruz e `Sandai Kitetsu` vinho/dourada com guarda em trevo, escalonadas e divergindo suavemente sem cruzar pontas ou guardas). Model Asset ID `81581775068263`, Image Asset ID `129469883534803`.
- Inseridos os modelos originais em `ServerStorage/Weapons` (sem colisão, `CanQuery = false`, `CanTouch = false`, `Massless = true`) e soldados via `Weld` com escala e `C0` validados em `ServerStorage/Characters`:
  - `Usopp_Slingshot_Acc` -> `Usopp.RightArm_Mesh` (escala `0.76`, segurando pelo cabo branco à frente da mão).
  - `Nami_ClimaTact_Acc` -> `Nami.RightArm_Mesh` (escala `0.96`, inclinado diagonalmente ao lado direito sem cruzar o ombro/braço).
  - `Zoro_Katanas_Acc` -> `Zoro.Torso_Mesh` (escala `0.95`, empunhadura diagonal lateral no quadril direito/Haramaki com as 3 bainhas limpas atrás da perna direita).
- `src/client/PlayerScripts/BaseClient.client.luau`: adicionada `setHandAccessoriesHidden` para ocultar temporariamente acessórios `_Acc` soldados na mão direita (`Usopp_Slingshot_Acc` e `Nami_ClimaTact_Acc`) enquanto a picareta de mineração (`MiningPickaxe`) estiver equipada, preservando acessórios de cintura como `Zoro_Katanas_Acc`.

**Testado (Blender + Studio Play, 18/11/2026)**
- Pré-visualização 3D completa nos rigs `*_R6_Auto.blend` (frente, 3/4, perfil direito e costas) e sondagem por raycast no Roblox Studio confirmando encaixe sem atravessar braços, tronco ou pernas.
- Teste no Server em modo Play (`CharacterLibrary.Spawn` + `Idle`/`Walk` + `ReplicatedStorage.CharacterPreviews`): todos os 3 modelos replicados e soldados (`Weld` íntegro, `posDiff = 0.0000`, `CanCollide = false`, `CanQuery = false`, `CanTouch = false`, `Massless = true`).
- Teste no Client em modo Play (`BaseCharacter` alternando `Mine` -> `Wait`): `Usopp_Slingshot_Acc` e `Nami_ClimaTact_Acc` ocultos (`Transparency = 1.0`) durante mineração com `MiningPickaxe` e restaurados ao sair (`0.0`); `Zoro_Katanas_Acc` visível durante todo o ciclo (`0.0`), zero erros nos scripts no Console.
- `sync_studio.py status` (`76/76` 100% em sincronia), `sync_studio.py test` (`PASS`) e Place salvo na versão `204` (`TeamCreate`).


## Correção V2: Cores/Permissões Multi-MeshPart, Katanas Mais Verticais e Nó da Bandana do Zoro (18/11/2026)

**Feito**
- **Diagnóstico & correção de texturas/permissões:** as imagens `Image` anteriores enviadas pela conta `12009032821` falhavam em `ContentProvider:PreloadAsync` no Place (`CreatorId = 5565234433`) antes da concessão explícita de permissões, deixando as armas cinza. As armas foram reconstruídas em `scripts/build_onepiece_weapons.py` com sufixo `_v2` separadas em múltiplas `MeshPart`s coloridas por material nativo do Roblox (`Color` + `Material` `SmoothPlastic`/`Metal`/`Fabric`, sem dependência de PNG externa) E todas as 18 `MeshId`s e 4 `Model`s receberam permissão `Use` via Open Cloud (`/asset-permissions-api/v1/assets/permissions`) para o Universo `10777011549`, Usuário `5565234433` e `All`:
  - **`Usopp_Slingshot_v2`** (`Model` `137232088939322`, 5 partes: `Usopp_GreenFrame`, `Usopp_WhiteWrap`, `Usopp_WrapSeam`, `Usopp_GoldPins`, `Usopp_BrownElastic`).
  - **`Nami_ClimaTact_v2`** (`Model` `106151620510926`, 4 partes: `Nami_SkyBlueBarrels`, `Nami_DarkCobalt`, `Nami_CreamRings`, `Nami_DarkDots`).
  - **`Zoro_Katanas_v2`** (`Model` `75452726718470`, 7 partes: `Zoro_WadoWhite`, `Zoro_YubashiriBlk`, `Zoro_SandaiRed`, `Zoro_SandaiIto`, `Zoro_DarkSamegawa`, `Zoro_TanSamegawa`, `Zoro_GoldHardware`) — reorientadas **mais verticalmente** (~`63°` acima da horizontal, menos inclinadas para trás e limpas do braço direito e das pernas).
- **Correção estrutural do nó da bandana do Zoro (`scripts/fix_zoro_bandana.py`):**
  - Separados os `166` vértices (`324` faces, `X > 0.009` no Blender) das duas ilhas do nó da bandana de dentro de `Zoro.Head` e fundidos diretamente em `Zoro.LeftArm`, preservando o UV map para `Zoro_Tex.png` (`rbxassetid://91845586938167`).
  - Exportado `Blender/Zoro/modelo/Zoro_R6_Auto_v2.blend` e `Zoro_Head_LeftArm_v2.fbx` (`Model` `126804073095470`), substituindo `Zoro.Head_Mesh` (`1.636 x 1.349 x 1.347`, centralizado em `X = 0.00`) e `Zoro.LeftArm_Mesh` (`0.927 x 2.075 x 0.971`, soldado em `LeftUpperArm` para acompanhar o braço e não mais a cabeça).
- `src/client/PlayerScripts/BaseClient.client.luau`: `setHandAccessoriesHidden` atualizado para suportar também acessórios em `Model` (`_Acc` com múltiplas `MeshPart`s), ocultando todas as sub-partes durante mineração (`Mine`) e restaurando em `Wait`.

**Testado (Blender + Studio Edit/Play, 18/11/2026)**
- Pré-visualização `v2` no Blender (`Usopp_v2`, `Nami_v2`, `Zoro_v2`) + sondagem por `Workspace:Raycast` no Studio: `knotHitsOnHead == 0`, `knotHitsOnLeftArm == 6`, 3 katanas mais verticais livres de colisão visual com `RightArm` e `RightLeg`.
- `ContentProvider:PreloadAsync` em `Edit` (`20/20` partes/texturas `Success`) e em `Client` Play Mode (`58/58` `MeshPart`s de `Usopp`, `Nami`, `Zoro` em `CharacterPreviews` -> `Success`, `fail = 0`).
- Simulação `Server` em Play (`CharacterLibrary.Spawn`, `Idle`/`Walk`, giro de `Neck` e `LeftShoulder` no Zoro): `posDiff = 0.0000`, `LA_MovedWithArm = true`, todas as partes não colidíveis.
- Simulação `Client` em Play (`BaseCharacter` `Mine` -> `Wait`): todas as sub-partes de `Usopp_Slingshot_Acc` (5/5) e `Nami_ClimaTact_Acc` (4/4) alternaram `1.0 -> 0.0` corretamente e `Zoro_Katanas_Acc` (7/7) permaneceu em `0.0`.
- `sync_studio.py status` (`76/76` em sincronia), `sync_studio.py test` (`PASS`) e Place salvo na versão `207` (`TeamCreate`).


## Autorecuperação dos Mineradores após Retornar do Refúgio/Batalha (`StreamingEnabled`, 18/11/2026)

**Feito**
- **Causa encontrada:** ao entrar no Refúgio (área distante sob `StreamingEnabled = true`), as partes raiz (`HumanoidRootPart`) dos personagens da base eram descarregadas da memória do cliente, fazendo `BaseClient` remover a picareta (`removePickaxe`) e apagar `rigs[model] = nil`; ao retornar para a Base, `GetInstanceAddedSignal("BaseCharacter")` nem sempre disparava novamente no `Model` reutilizado, deixando os mineradores estáticos e sem picareta.
- `src/server/Economy/BaseService.luau`: definido `model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic` nos personagens instanciados em `BaseCharacters` (`syncNPCs`) para que modelo inteiro, juntas `Motor6D` e acessórios sempre entrem e saiam de streaming juntos.
- `src/client/PlayerScripts/BaseClient.client.luau`: adicionados watchdog de autorrecuperação periódico (`0.35s`) em `RunService.Stepped` para reregistrar modelos com tag ainda presentes/recarregados no `Workspace` sem registro em `rigs`, guarda contra concorrência em `setup` (`settingUp`), limpeza de eventuais picaretas órfãs em `ensurePickaxe`, e `DescendantAdded` (`dirtyRig`) para reescanear juntas recém-carregadas.
- `src/client/PlayerScripts/NpcWalkClient.client.luau`: adicionada deduplicação `watched` (tabela fraca) em `watchNpc` para evitar conexões repetidas ao reentrar via streaming.

**Testado (Play, 18/11/2026)**
- Teste no `Server` e `Client` em modo Play: simulado stream-out parcial (`HumanoidRootPart.Parent = nil`) e stream-out completo (`model.Parent = nil`) + retorno à Workspace, e também viagem real do jogador a `-4500` studs ida e volta aos mineradores ativos da base (`Kaen`, `Luffy`, `Barba Branca`): `ModelStreamingMode == Enum.ModelStreamingMode.Atomic`, todos recuperaram `MiningPickaxe` e movimento ativo de `RightShoulder.Transform` (`animDelta` entre `0.067` e `0.143`), console limpo.
- `sync_studio.py status` (`76/76` 100% em sincronia), `sync_studio.py test` (`PASS`) e Place salvo na versão `208` (`TeamCreate`).






## Genética, Treino, Regras PvE/Forja e HUD com Gráfico de Radar (19/11/2026)

**Feito**
- `src/shared/Data/Genetics.luau` (novo) & `src/shared/Data/Progression.luau`: implementado sistema de **Genética** (IVs) e **Treino** (EVs) em escala `0..100` (`%`) para `HP`, `Attack`, `Defense` e `Speed`:
  - Bônus nos atributos finais por stat: até **+40%** de Genética e até **+30%** de Treino (`1 + 0,40×Gen/100 + 0,30×Trn/100`), aplicados individualmente por atributo junto ao multiplicador de estrelas/variante (`Progression.MemberMultipliers` e `Progression.StatBreakdown`).
  - Distribuição probabilística de Genética via inversa da CDF de **Kumaraswamy** ajustada por raridade (`Comum ~36%`, `Raro ~53%`, `Epico ~65%`, `Lendario ~74%`, sempre aleatória e sem garantia) + evento raro de **Prodígio 100%** (`100/100/100/100` de `0,005%` no Comum até `0,050%` no Lendário).
  - Treino sempre inicializado em `0` nos 4 atributos para personagens do jogador.
- `src/shared/Core/BattleEngine.luau`: suporte a `StatMultipliers` por atributo (`Genetics` + `Training`), preservando `Genetics` no evento `Captured` e mantendo `0/0` em `1,00x` (teste do GDD preservado).
- Camada Servidor:
  - `PlayerDataService.luau`: migração/higienização automática preenchendo `Genetics` (sorteada por raridade) e `Training` zerado em personagens já salvos e selvagens pendentes no Refúgio.
  - `ProgressionService.luau`, `PvPService.luau`, `SummonService.luau`: criação com Genética por raridade + Treino `0`, envio de `StatMultipliers` para batalha/PvP, e desempate em `Fuse`/`SellDuplicate` preservando a melhor Genética.
  - `TowerService.luau`: inimigos PvE da Torre recebem **`Genética = 70` e `Treino = 100`** em todos os 4 atributos (`1,58x` + multiplicadores de andar/chefe); chefes capturados/obtidos continuam entrando na coleção com rolagem normal do jogador e Treino `0`.
  - `RefugeService.luau` ("Forja pessoal") & `EncounterService.luau`: selvagens geram `Genetics` pela mesma função/probabilidades do Gacha (`Genetics.Roll`), lutam com esses atributos e mantêm exatamente a Genética sorteada ao serem capturados (com Treino `0`).
- Interface & Gráfico de Radar:
  - `src/shared/RadarChart.luau` (novo): componente gráfico de radar 4 eixos (`HP`, `ATQ`, `DEF`, `VEL`) com anéis (`25%..100%`), preenchimento geométrico por quadrante (`UIGradient` alinhado por `atan2` em pixel space), arestas, vértices luminosos e camadas alternáveis (`AMBOS`, `GENÉTICA`, `TREINO`).
  - `src/client/Gui/CharacterDetailGui/CharacterDetailClient.client.luau` (novo): modal responsivo empilhado (`UI.open("CharacterDetail", uid)`) com retrato 3D, badge de rank (`S+..D`), médias de Genética/Treino, gráfico de radar e detalhamento `Base → Final` com barras de progresso por atributo.
  - Pontos de acesso integrados na Barra do Time (`TeamBarClient`: botão `STATUS`), na tela de `Equipe` (`InspectSlot` + alternador `VER INFO`) e em `Mochila > Personagens` (`BagClient`: linha clicável com resumo `GEN % / TRN %`); `HudClient` (`GOLPES`) atualizado para exibir `Progression.MemberStats`.
- Documentação atualizada em `Blender/GDD.md` (Seções 4, 6, 10 e 14) e `ARQUITETURA_PROJETO.md`.

**Testado (Edit Mode + Play Mode + Captura Visual, 19/11/2026)**
- Teste unitário em `Edit Mode`: médias reais de `500` rolagens por raridade (`Comum = 36,4%`, `Raro = 52,9%`, `Epico = 65,1%`, `Lendario = 74,1%`), multiplicadores `1.00x / 1.58x (Torre) / 1.70x (Máx)`, batalha de chefe Infinito (`BossAtk = 42`) e preservação de Genética em captura selvagem (`PASS`).
- Teste em `Play Mode` (`Server` + `Client`): migração validada nos `14` personagens existentes, criação de novo personagem com `Treino = 0/0/0/0`, sorteio da Forja Pessoal, abertura via `Mochila > Personagens`, `Equipe` (`VER INFO`) e Barra do Time, auditoria completa via `_UITestKit` nas resoluções Desktop, `667x375`, `932x430` e `1024x768` sem erros reais (`OUT`/`SMALL`/`TINY` limpos), e captura visual (`screen_capture`) em Desktop e `667x375` confirmando alinhamento exato do polígono no Radar e console limpo.
- `sync_studio.py status` (`79/79` scripts `100% in sync`) e `sync_studio.py test` (`PASS`).


## Máquina de Treinamento (Cúpula de Vidro), 4 Minérios e Níveis de Mineração (19/11/2026)

**Feito**
- `src/shared/Data/Training.luau` (novo) & `src/shared/Data/Base.luau`:
  - Criados os **4 minérios específicos por atributo** separados em raridades: **Minério Vital** (`HP`, Comum, Nv. 1), **Minério Férreo** (`Defesa`, Raro, Nv. 2), **Minério Veloz** (`Velocidade`, Épico, Nv. 4) e **Minério Rubro** (`Ataque`, Lendário / mais raro, Nv. 6).
  - Atualizada a **Mineração da Base (Nv. 1 a 10)** em `Base.MiningDropTable` e `Base.Rates`: agora quem minera gera **Gold (`50%` da taxa de Passeio) + Minério bruto + rolagens independentes dos 4 minérios de treino** (permitindo vir múltiplos tipos e múltiplas quantidades num mesmo achado, equilibrando porcentagens e quantidades ao subir de nível em Gold).
  - Regras de treino implementadas em `Training.luau`: incrementos exclusivamente de **20 em 20** até `100%`, suporte a múltiplos atributos simultâneos com taxa de crafting (`1,00× / 1,25× / 1,50× / 1,80×`), multiplicadores de custo e tempo por raridade (`Comum` `+20` em Nv. 1 = `60s`, até `Lendário` `99s`), e **10 níveis de eficiência** da máquina em Gold (`1,00×` até `4,00×`, reduzindo o `+20` básico para `15s`).
- `src/server/Economy/TrainingService.luau` (novo), `BaseService.luau`, `PlayerDataService.luau`, `TeamService.luau`, `SummonService.luau`, `DataMain.server.luau`, `src/shared/Net.luau`:
  - Construída fisicamente a **`TrainingCapsule`** (cúpula de vidro translúcida com base metálica, anéis neon, console frontal com `ProximityPrompt`, etiqueta flutuante e emissor de bolhas de energia) em todos os **10 terrenos (`Plots/Plot01..Plot10`)**.
  - Modelo 3D do personagem em treino fica suspenso dentro da cúpula (`CapsuleCharacter`), protegido contra entrar no time, minerar/passear, fusão ou venda; resgatar conclui e aplica os atributos ao personagem; cancelar devolve `50%` dos minérios.
- Interface & Animação (`BaseClient.client.luau`, `BaseUiClient.client.luau`, `TrainingGui/TrainingClient.client.luau`):
  - `BaseClient`: adicionada pose animada a 60 FPS de flutuação em gravidade zero para modelos marcados com `CapsuleCharacter`.
  - `BaseUiClient`: exibidos nível da mineração, botão de upgrade da mineração em Gold, faixa ao vivo dos 4 minérios (`%` de participação e pendentes), botão **`TREINO`** e selo **`CÁPSULA`**.
  - `TrainingClient`: janela responsiva (`IdleView` com grade 2×2 de passos `-`/`+` de 20 em 20 + `ActiveView` com retrato 3D, barra de progresso em tempo real e botões `Resgatar` / `Cancelar`), com upgrade da eficiência em Gold no cabeçalho.
- Documentação atualizada em `Blender/GDD.md` (Seção 8) e `ARQUITETURA_PROJETO.md`.

**Testado (Edit Mode + Play Mode + Captura Visual, 19/11/2026)**
- Testes unitários em `Edit Mode`: validação de múltiplos de 20 (rejeição de `15`), `60s` no `+20` Comum Nv. 1, `99s` Lendário, `15s` Comum Nv. 10, custos por raridade e multi-atributo, progressão de equilíbrio da tabela de drop (`Nv. 1 -> 10`) e geração combinada de Gold + Minério na mineração (`PASS`).
- Testes em `Play Mode` (`Server` + `Client`): acúmulo e coleta de drops do Nv. 1 ao Nv. 6 (`HP=460, DEF=260, VEL=190, ATQ=47` + `Gold=67,5`), upgrade da Mineração (`1 -> 6`) e da Máquina (`1 -> 2`), bloqueio em `SetTeam` durante treino, reembolso de `50%` em `TrainingCancel`, `Barba Branca` levitando completo dentro da cúpula física em `Plot01` sem cortar o teto, resgate confirmando `HP=20% e DEF=20%`, auditoria `_UITestKit` limpa (`BaseGui` e `TrainingGui` Idle/Active em Desktop, `667x375`, `932x430`, `1024x768`), capturas visuais limpas (`capsule_edit_v1`, `training_idle_desktop_v1`, `training_active_desktop_v1`, `capsule_with_barba_branca_play`) e console sem erros.
- `sync_studio.py status` (`82/82` scripts `100% in sync`) e `sync_studio.py test` (`PASS`).


## Polimento Visual: Ícones de Minérios, Intangibilidade e Layout da Base (20/11/2026)

**Feito**
- **4 Ícones dos Minérios de Atributo:** gerados via `scripts/build_ore_icons.py` (`Blender/UI/icones/ore_hp.png`, `ore_def.png`, `ore_vel.png`, `ore_atq.png`, 256×256 RGBA no estilo contorno `#1A1233`) e enviados com permissões (`Universe 10777011549` e `User 5565234433`): `ore_hp` (`98190850262557`), `ore_def` (`81379071551950`), `ore_vel` (`131534143692832`) e `ore_atq` (`94276779585364`).
- `src/shared/UI.luau`, `src/shared/Data/Training.luau`, `src/client/Gui/BaseGui/BaseUiClient.client.luau` e `src/client/Gui/TrainingGui/TrainingClient.client.luau`: adicionados `UI.Icons.ore_*` e `Icon` em `Training.Ores`, integrados nos cards/faixa superior de `TrainingGui` e na faixa de minérios de `BaseGui`; reduzidos os ícones internos de `TrainingGui` (`Header.Icon` e `StartTraining.Face.Icon`).
- `src/client/Gui/BagGui/BagClient.client.luau`: reduzido o ícone dos cards na aba **Itens** (`Size = (0.32, 0.32)`, `Position = (0.5, 0.14)`, `ItemName` em `Y = 0.56` e `Desc` em `Y = 0.79`).
- `src/server/Economy/BaseService.luau` & `src/client/PlayerScripts/NpcWalkClient.client.luau`: personagens em `BaseCharacters` totalmente intangíveis (`CollisionGroup = "BaseNPC"` sem colisão com outros grupos, `CanCollide/CanQuery/CanTouch = false`, `Massless = true`, `Humanoid.EvaluateStateMachine = false` + `DescendantAdded` no servidor e no cliente).
- **Pedreira menor & Cápsula no canto (`Plots/Plot01..Plot10`):**
  - Em todos os 10 terrenos em `Edit`: `Quarry` escalonada para `0,58×` ancorada em `(-17, floorTop, 17)` (`ScaleVersion = 2`; rocha `Rock_7A7F8C` de `15,1×8,9×14,1` para `8,8×5,2×8,2`), com distâncias ajustadas em `BaseService.luau` (`randomWalkPoint > 7`, `quarrySurfaceRadius` padrão `4,5`, `minePoint` mínimo `5,5 + charRadius + 1,0`).
  - `src/server/Economy/TrainingService.luau` & 10 terrenos em `Edit`: `TrainingCapsule` compactada (`LowerRim` `7,0`) e movida para o canto frontal direito (`floor.CFrame * CFrame.new(14.5, floor.Size.Y * 0.5, -14.2)`), com o `Arbusto` frontal direito em `Decor` deslocado para `Z = -9,2` (`MovedForCapsule = true`).

**Testado (Edit Mode + Play Mode + Capturas Visuais, 20/11/2026)**
- `ContentProvider:PreloadAsync`: `4/4` `Enum.AssetFetchStatus.Success` em `Edit` e em `Client` Play Mode (`98190850262557`, `81379071551950`, `131534143692832`, `94276779585364`).
- `Play Mode` (`Plot01`): os 3 mineradores (`Kaen`, `Barba Branca`, `Luffy`) confirmados em Servidor e Cliente com `EvaluateStateMachine = false`, `canCollideParts = 0` e `CollisionGroup = "BaseNPC"`, posicionados fora da rocha menor (`distRock` entre `7,97` e `8,84` studs); teste físico de caminhada atravessando o centro de `Barba Branca` (`minDistThroughCenter = 0,30` studs, destino alcançado a `0,73` studs).
- Auditoria `_UITestKit.audit()` limpa (apenas `Scrim` fora da tela padrão) em `TrainingGui`, `BaseGui` e `BagGui` (Desktop, `667x375`, `932x430`, `1024x768`), capturas visuais em Play Mode (`ScreenCapture_PlayCourtyard`, `ScreenCapture_PlayCorner`, `ScreenCapture_TrainingGui` com `TopOre_*` 17×17 / `OreIcon` 20×20 / `StartTraining.Icon` 21×21, `ScreenCapture_BaseGui`, e `ScreenCapture_BagGui` com cards `234×187` e ícones `59×59`) e console sem erros de runtime.
- `sync_studio.py status` (`82/82` `100% in sync`) e `sync_studio.py test` (`PASS`).


## Painéis de Seleção de Anime na Estrela do Gacha, Elenco Naruto Provisório e Animação/Som de Destaque 3D (20/11/2026)

**Feito**
- **Artes dos Painéis de Seleção de Anime & Efeito Sunburst:** gerados em 800×360 (`Blender/UI/banners/`) e 512×512 (`summon_sunburst.png`), enviados para o Roblox com permissões (`Universe 10777011549` e `User 5565234433`):
  - `Blender/UI/banners/banner_todos.png` (`80124787437807`), `banner_naruto.png` (`90282977605958`), `banner_onepiece.png` (`88088550646321`) e `summon_sunburst.png` (`139837721546408`).
- **6 Personagens de Naruto (sem modelo próprio ainda / ataques padrão):**
  - `src/shared/Data/Characters.luau`: adicionado `"Naruto"` em `AnimeOrder`/`Animes` e cadastrados `Sakura` (`Comum`, Natureza), `Shikamaru` (`Comum`, Trevas), `Kakashi` (`Raro`, Raio), `Sasuke` (`Raro`, Fogo), `Naruto` (`Epico`, Luz) e `Sarutobi` (`Lendario`, Fogo) com ataques padrão existentes, animações padrão compartilhadas e paletas provisórias (`PlaceholderColors`).
  - `src/server/CharacterLibrary.luau` & `src/server/CharacterPreviews.server.luau`: implementado `CloneSource` com fallback automático para `ProtoRaro` (sem `Acc_Visor`, colorido por `PlaceholderColors`) quando `ServerStorage/Characters/<ModelName>` ainda não existe, além de fallback de animação em `Characters.Play` e geração automática das prévias em `ReplicatedStorage/CharacterPreviews` — trocável apenas adicionando os modelos finais depois.
- **Painéis de Estrela no Servidor e Cliente:**
  - `src/shared/Data/Summon.luau` & `src/shared/Net.luau`: definidos `Summon.BannerOrder` (`Todos`, `Naruto`, `OnePiece`), `Summon.Banners` e contrato `Summon`/`SummonBanner` com `bannerId`.
  - `src/server/Economy/SummonService.luau`: seleção validada no servidor filtrando sorteios e destaques semanais (`BannerOf`) pelo anime escolhido (`Naruto`, `OnePiece`, ou `Todos`), preservando chances e garantia (*pity*) do portal.
- **Animação 3D Girando na Frente da Tela + Sons Estimulantes + Cartas 3D (`SummonClient` + `UI.luau`):**
  - `src/shared/UI.luau`: adicionados ícones de banners/sunburst e 5 efeitos sonoros verificados para gacha em `UI.Sounds` (`summon_charge` `12222200`, `summon_shimmer` `9116394545`, `summon_reveal` `9126073001`, `summon_epic` `1844692556`, `summon_legendary` `1845411858`).
  - `src/client/Gui/SummonGui/SummonClient.client.luau`: faixa inferior `BannerStrip` com os 3 painéis ilustrados clicáveis (`TODOS`, `NARUTO`, `ONE PIECE`), palco em tela cheia `SummonShowcase` (carga rápida `0,40s` → explosão com raios radiais rotativos, partículas, personagem 3D completo girando na frente da tela `~1,45–1,85s`, botão `PULAR` e fanfarra por raridade) e grade `5x2` `RevealWindow` com prévias 3D frontais e atualização imediata de `ViewportFrame`.
- Documentação atualizada em `Blender/GDD.md` (Seções 4 e 13).

**Testado (Edit Mode + Play Mode + Capturas Visuais, 20/11/2026)**
- `ContentProvider:PreloadAsync`: 4/4 imagens novas (`Enum.AssetFetchStatus.Success`) e 5/5 áudios novos (`IsLoaded = true`) conferidos em `Edit` e `Client` Play Mode.
- `Server` Play Mode: todos os 6 modelos provisórios de Naruto em `ReplicatedStorage/CharacterPreviews` (`MissingPrev = vazio`), `CharacterLibrary.Spawn` verificado nos 6 personagens (`anims = 12`, sem visor), `SummonService.BannerOf("Premium", "Naruto") == "Sarutobi"`, `SummonService.BannerOf("Premium", "OnePiece") == "BarbaBranca"`, e turnos simulados em `BattleEngine` (`SarutobivSakura`, `NarutovSasuke`, `KakashivShikamaru` -> `dmgEvs = 2` cada).
- `Client` Play Mode: abertura pelo `SummonPrompt` de `PortalComum` (tecla `E`), seleção visual das estrelas `Todos`, `Naruto` e `One Piece`, roleta `Summon1` em `One Piece` (`Usopp`) e `Summon10` em `Naruto` (`Sakura`, `Shikamaru`, `Kakashi` em grade `5x2` com todos os 10 `ViewportFrame`s visíveis de imediato e sem truncamento), auditoria `_UITestKit.audit()` limpa (apenas `Scrim`) em `SummonWindow` e `RevealWindow` nas resoluções Desktop, `667x375`, `932x430` e `1024x768`, perfil do jogador restaurado (`1.002.219` gold, `14` personagens) e console sem erros de execução do jogo.
- `sync_studio.py status` (`82/82` `100% in sync`) e `sync_studio.py test` (`PASS`).


## Sincronização do Place v248 (Studio → Disco) (20/11/2026)

**Feito**
- Extraídos do Roblox Studio (`PlaceVersion = 248`) para `src/` os **8 scripts modificados** e **4 novos scripts** produzidos após a `v228`:
  - **Auras dos personagens (`CharacterAuras`):** novo `src/client/PlayerScripts/CharacterAuraClient.client.luau` + configuração persistida em `SettingsClient.client.luau`, `SettingsService.luau`, `PlayerDataService.luau`, `ClientSettings.luau` e `Data/Audio.luau`.
  - **Palco 3D ao vivo de Invocação & Selos dos Portais:** novos `src/shared/SummonBannerStage.luau` e `src/shared/Data/SummonStageThemes.luau` + atualizações em `SummonClient.client.luau`, `CharacterPreviews.server.luau` (`ReplicatedStorage/SummonShowcaseModels`) e `MapFxClient.client.luau` (`PortalSeal`).
  - **Arenas Santuário Malevolente:** novo `src/server_storage/_ConstrutorArenasSukuna.luau` (v5).
- Atualizados `default.project.json`, `ARQUITETURA_PROJETO.md` e `HANDOFF_CONTEXTO.md` para refletir o estado **Place v248 / 86 scripts**.

**Testado (20/11/2026)**
- `python scripts/sync_studio.py status`: `All 86 scripts in src/ are 100% in sync with Roblox Studio.`
- `python scripts/sync_studio.py test`: `PASS` (`GDD Damage [12..14] verified & Kaen vs Raiko completed in 6 turns`).


## Correção dos HUDs de Lista de Personagens com Muitos Personagens (20/11/2026)

**Causa identificada**
1. **Explosão exponencial de `CanvasSize` em `UI.scroll` (`src/shared/UI.luau`):** `UIPadding` (`PaddingTop = 0.015`, `PaddingBottom = 0.03`) e `UIListLayout.Padding` (`Gap = 0.02` / `0.015`) usavam `Scale` vertical dentro de `ScrollingFrame`. No Roblox, `Scale` vertical dentro de `ScrollingFrame` multiplica `CanvasSize.Y` (e não `AbsoluteSize.Y`): com 50+ personagens (perfil real com 68 personagens), o espaçamento ultrapassava `100%` do canvas e disparava um loop exponencial (`BaseGui` explodindo para `613.704 px`, `BagGui > Targets` para `10.555.389 px`, `TrainingGui` para `400.835 px` e `BagGui > Personagens` para `104.387 px`), jogando os itens para fora da tela.
2. **Altura preguiçosa de linhas fora da tela, perda de rolagem e vazamento em `UI.luau`:** linhas fora da viewport dentro de `ScrollingFrame` tinham `AbsoluteSize` adiado pelo Roblox; `canvases` guardava referências fortes a `Strokes`/`Texts`/`Shadows` destruídos a cada reconstrução; `BaseGui`/`TrainingGui`/`BagGui`/`SummonGui > Repetidos` reconstruíam listas inteiras ou voltavam a rolagem ao topo durante ticks de `ProfileUpdated` ou cliques.
3. **Cartões 3D em branco / textura antiga em `EquipeGui` (`EquipeClient`, `TeamCards`, `CharacterPreviews`):** com muitos personagens, `EquipeGui` abria até 46 `ViewportFrame`s simultâneos redimensionados durante o tween `UIScale` da janela, reutilizando a mesma instância de `ViewportFrame` (gerando cartões em branco e textura antiga misturada ao rolar) com clones de até 275 descendentes por retrato.

**Feito**
- `src/shared/UI.luau`:
  - `UI.scroll`: migrados `UIPadding` e `UIListLayout.Padding` para pixels (`Offset`) calculados a partir de `AbsoluteSize` normalizado por `UIScale` (`UI.unscaledSize`), atualizando a altura (`_RowAspect`/`_RowMax`) de todas as linhas (visíveis e fora da tela) em `fitMetrics()` e calculando `CanvasSize` sem loop.
  - `UI.screen`: tabelas de métricas (`Strokes`, `Texts`, `Shadows`) convertidas para chaves fracas (`__mode = "k"`).
  - `UI.keepScroll`: restauração garantida com clamp para `AbsoluteCanvasSize.Y - AbsoluteWindowSize.Y`.
- `src/client/Gui/BaseGui/BaseUiClient.client.luau`, `BagGui/BagClient.client.luau`, `TrainingGui/TrainingClient.client.luau`, `SummonGui/SummonClient.client.luau`:
  - Aplicados `UI.keepScroll`, `UI.unscaledSize`, ordem de abertura `win.Open()` → `layout()` → `refresh()`, e assinatura de lista (`lastListKey`/`lastCharListKey` + troca instantânea de seleção em `TrainingGui`) para evitar reconstrução desnecessária a cada tick de 10 s.
- `src/client/Gui/EquipeGui/EquipeClient.client.luau`, `src/shared/TeamCards.luau`, `src/server/CharacterPreviews.server.luau`:
  - Virtualização estrita apenas das linhas visíveis (`cols <= 7`, ~20 `ViewportFrame`s simultâneos) e layout normalizado por `UI.unscaledSize` sem redimensionamento durante tween.
  - `TeamCards`: recriação limpa do `ViewportFrame` ao trocar personagem (eliminando cache/textura antiga e liberando `ViewportFrame`s de cartões vazios/reciclados).
  - `CharacterPreviews.server.luau`: limpeza de `Attachment` (preservando `Bone`), `JointInstance`, `WeldConstraint`, `Animator`, `VariantPresets` e partes invisíveis nas prévias 2D (`Luffy` `168 → 24`, `BarbaBranca` `275 → 78` descendentes).

**Testado (Play Mode + Capturas Visuais + Estresse 150 personagens, 20/11/2026)**
- Perfil real (68 personagens): `BaseGui.List` (`4.777 px`, `gap = 6 px`, último item `INTEIRO`), `BagGui.Targets` (`5.323 px`, `INTEIRO`), `BagGui.Characters` (`4.509 px`, `INTEIRO`), `TrainingGui.Characters` (`4.509 px`, `INTEIRO`, clique no item #15 manteve rolagem em `600 px`), `SummonGui.DupesList` (`833 px`, `INTEIRO`), `EquipeGui` (`20/20` retratos 3D nítidos no topo e após rolagem para o meio, zero mistura de textura).
- Teste de estresse com 150 personagens simulados em memória (teto máximo com Depósito Ampliado): `BaseGui` (`10.517 px`), `BagGui.Characters` (`9.921 px`), `TrainingGui` (`9.921 px`), todos estáveis e com o último item `INTEIRO`.
- Auditoria `_UITestKit.audit()` limpa (`0` problemas reais em `16/16` combinações: `Desktop`, `667x375`, `932x430`, `1024x768` × `Base`, `Bag`, `Training`, `Equipe`) e console sem erros.
- `python scripts/sync_studio.py status` (`86/86` `100% in sync`), `python scripts/sync_studio.py test` (`PASS`) e Place salvo no Studio.


## Seletor Visual Unificado via HUD da Equipe (`UI.pickCharacter`) para Treino, Base e Mochila (20/11/2026)

**Feito**
- `src/shared/UI.luau`: adicionados `UI.onPickCharacter` e `UI.pickCharacter` (roteamento direto em Luau para preservar callbacks `OnPick`, `GetBadge`, `IsEligible`, `SubtitleFn`, `FormatSelected` e `OnCancel` sem serialização de `BindableEvent`).
- `src/shared/TeamCards.luau`: adicionados `card.SetBadge(text, color)` (selos contextuais no cartão 3D: `TRN 60%`, `MINERANDO`, `PASSEANDO`, `CÁPSULA`, `63/111`, `CHEIO`, `DESMAIADO`, `NO TIME`) e `card.SetDimmed(on)` (destaque visual entre elegíveis e inelegíveis).
- `src/client/Gui/EquipeGui/EquipeClient.client.luau`: adicionado o **Modo Seletor** reaproveitando toda a grade 3D virtualizada e a barra completa de filtros (`Buscar nome...`, `Anime`, `Raridade`, `Tipo`, `Ordenação`, `VER INFO`), com cabeçalho dinâmico (título/cor/ícone da função), barra contextual (`VOLTAR`, resumo do personagem/vagas, botão de ação da função + duplo toque para confirmar) e retorno automático para a tela chamadora; modo `Equipe` padrão preservado 100%.
- `src/client/Gui/TrainingGui/TrainingClient.client.luau`: substituída a lista textual esquerda por retrato 3D (`TeamCards`) do personagem selecionado + resumo `GEN/TRN` + botão `TROCAR` (e clique no retrato) abrindo `ESCOLHER PARA TREINO`.
- `src/client/Gui/BaseGui/BaseUiClient.client.luau`: lista da Base simplificada para os botões `+ ESCOLHER PASSEIO` / `+ ESCOLHER MINA` (abrindo o seletor visual com contadores ao vivo `Ativos` / `Vagas Mina` e selos `MINERANDO`/`PASSEANDO`/`CÁPSULA`) + apenas os personagens ativos/na cápsula abaixo.
- `src/client/Gui/BagGui/BagClient.client.luau`: aba `Itens` atualizada com botão `ESCOLHER NA COLEÇÃO` abrindo o seletor visual `USAR <ITEM>` (para Poções, Reviver e Doces de XP, destacando alvos feridos/desmaiados) + atalho rápido para os até 6 personagens do time ativo.

**Testado (Play Mode + 6 Capturas Visuais + Auditoria 4 Resoluções, 20/11/2026)**
- Fluxos completos verificados em Play Mode com os 68 personagens reais:
  - `TrainingGui` (retrato 3D `Barba Branca`) → `ESCOLHER PARA TREINO` → filtro `ONE PIECE` → confirmação `TREINAR ESTE` retornando para `TrainingGui`.
  - `BaseGui` (4 linhas: barra de botões + 3 mineradores ativos) → `COLOCAR PARA MINERAR` (`Ativos 3/6 · Vagas Mina 3/3`, selos `MINERANDO`) → `VOLTAR` retornando para `BaseGui`.
  - `BagGui > Itens` (`Poção`) → `ESCOLHER NA COLEÇÃO` → `USAR POÇÃO` (`Restam x6`, destaque verde `63/111` / `29/85` nos feridos vs `CHEIO` escurecido).
  - Regressão: abertura normal de `Equipe` restaurando cabeçalho azul `EQUIPE`, 6 slots do time e ocultando `PickerBar`.
- Auditoria `_UITestKit.audit()` limpa (`0` problemas em `20/20` combinações: `Desktop`, `667x375`, `932x430`, `1024x768` × `Training`, `EquipePicker`, `Base`, `Bag`, `EquipeNormal`) e console sem erros.
- `python scripts/sync_studio.py status` (`86/86` `100% in sync`), `python scripts/sync_studio.py test` (`PASS`) e Place salvo no Studio.


## Batalha 2x2 Estilo Pokémon (Foco em PvP 2x2 e 1x1) (20/11/2026)

**Feito**
- **Camada 1 (`Data` / `Net`):**
  - `src/shared/Data/Moves.luau`: adicionado campo `Target` (`"AllEnemies"` em `BrasaViva`, `Descarga`, `GaiolaDeEspinhos`, `TudoRoxo`, `GenkiDama` e `CeuETerra`) e helper `Moves.TargetMode(move)` (`"Single" | "AllEnemies" | "AllOthers" | "AllAllies" | "Self"`), preservando 100% o comportamento 1x1.
  - `src/shared/Net.luau`: atualizados os contratos de `StartBattle`, `SubmitAction`, `PvPChallenge` e `PvPInvite` para incluir formato (`"1x1" | "2x2"`), `SlotModels` e ações `Double`.
- **Camada 2 (`Core` — lógica pura):**
  - `src/shared/Core/DamageCalc.luau`: adicionado `SPREAD_MULTIPLIER = 0.75` (regra oficial Pokémon 2x2 ao atingir 2+ alvos; `1.0x` quando resta só 1 alvo) em `Compute` e `ExpectedDamage`.
  - `src/shared/Core/AIController.luau`: adicionados `exclude` em `ChooseReplacement` (evita duplicatas em substituição dupla) e `ChooseActionsDouble` (IA 2x2 e ações automáticas por timeout no PvP 2x2).
  - `src/shared/Core/BattleEngine.luau`: generalizada a máquina de estados para `Format = "1x1" | "2x2"` (`SlotsPerSide`, `ActiveSlots`, `ActiveAt`, `FieldSlotOf`, `AliveFieldSlots`, `BenchAliveIndices`), fila de prioridade/Velocidade com até 4 lutadores simultâneos, escolha de alvo relativo (`"Enemy"` / `"Ally"`), redirecionamento automático quando o alvo inimigo desmaia no meio do turno, precisão e efeitos por alvo, `ClearSlot` para continuação 2x1 quando o banco acaba, substituição dupla sem duplicatas e `Snapshot(view)` com arrays densos (`0` = slot vazio, imune a buracos em `RemoteEvent`).
- **Camada 3 (`Server`):**
  - `src/server/Battle/ArenaManager.luau`: adicionados `DOUBLE_LATERAL = 5.2`, `SlotCFrame`, `BattleCamera(arena, format)` (câmera 2x2 simétrica para `MirroredCamera` no PvP espelhado), `SpawnActive(..., fieldSlot)`, `ClearSlot` e `PlaceViewer(..., isDouble)`.
  - `src/server/Battle/BattleService.luau`: rastreamento de modelos por slot (`SlotModels`), espelhamento de eventos `2x2` (`TargetSide`, `Targets`), sanitização estrita de ações `Double`/`Replace` no servidor (`sanitizeAction`), apresentação de VFX/animações/impactos secundários em área por slot exato, vitória nos 2 modelos ativos e suporte a `Format = "2x2"` em `StartPvP` e `StartBattle`.
  - `src/server/Battle/PvPService.luau`: `Challenge(player, targetUserId, format)` aceitando `"1x1"` e `"2x2"`, validando mínimo de 2 personagens no time de ambos os jogadores no `2x2`, enviando `Format` no convite `PvPInvite` e iniciando `BattleService.StartPvP(..., { Format = inv.Format })`.
- **Camada 4 (`Client`):**
  - `src/client/Gui/PvPGui/PvPClient.client.luau`: ao acionar `Desafiar (PvP)` (tecla `F`), abre o seletor de formato **`2x2 EM DUPLA`** vs **`1x1 CLÁSSICO`**; convites recebidos/enviados exibem o selo de formato em destaque (`2x2 EM DUPLA` / `1x1 INDIVIDUAL`).
  - `src/client/Gui/BattleGui/BattleClient.client.luau`: HUD 2x2 completo com 2 cartões inimigos escalonados no topo à direita (alinhados esquerda→direita com o 3D), 2 cartões aliados embaixo à esquerda com borda dourada no lutador escolhendo, fluxo sequencial Slot 1 → Slot 2 com botão `VOLTAR`, seletor de alvo com indicador de efetividade (`2x SUPER!`, `0.5x RESISTE`, `1x NORMAL`) + opção secundária de atingir aliado, selo `ÁREA`/`SI` nos golpes, substituição dupla e suporte a `ClearSlot` (2x1), mantendo o 1x1 100% idêntico.
- **Testes automatizados (`scripts/sync_studio.py`):**
  - Atualizado `cmd_test` com sandbox de recarga limpa (`_TestSandbox`) e 5 baterias de validação cobrindo fórmula GDD 1x1 `[12..14]`, spread `0.75x`/`1.0x`, redirecionamento mid-turn, `ClearSlot` 2x1, rejeição de troca/substituição duplicada, substituição dupla e simulação completa de PvP 2x2.

**Testado (Edit Mode + Play Mode + Capturas Visuais + Auditoria UI, 20/11/2026)**
- `python scripts/sync_studio.py status`: `All 86 scripts in src/ are 100% in sync with Roblox Studio.`
- `python scripts/sync_studio.py test`: `PASS: 1x1 GDD [12..14] (6 turns) & 2x2 Doubles (spread 0.75/1.0, redirect, 2v1 ClearSlot, double replace, PvP sim 11 turns, Winner=Player)`.
- **Play Mode ao vivo (`Barba Branca` + `Setero` + `San` + `Yomogi` vs `San` + `Yomogi` + `Kaen` + `Raiko`):**
  - Capturas inspecionadas de `PvPGui` (convite `2x2 EM DUPLA` + seletor de formato `2x2 EM DUPLA` / `1x1 CLÁSSICO`), arena 2x2 com 4 lutadores enquadrados, cartões duplos com borda dourada ativa, golpes com selos `ÁREA`/`SI`, seletor de alvo (`0.5x RESISTE` / `1x NORMAL` + aliado), botão `VOLTAR` no passo 2/2, troca em campo (`Setero` → `San`), nocaute duplo com substituição dupla do adversário (`Kaen` + `Raiko`), continuação `2x1` via `ClearSlot` e retorno limpo à praça após vitória.
  - Teste de regressão `1x1` (`Kaen` vs `Raiko`): cartões extras e cabeçalho de dupla ocultos (`E2=false, P2=false, actorChip=false`).
  - `_UITestKit.audit()` limpo (`0` problemas) e console sem erros de execução do jogo.
- Place salvo no Roblox Studio na **versão 259** (`TeamCreate`).

**Pendências**
- Testar o fluxo de desafio PvP 2x2 entre **2 clientes reais** (Local Server com 2 jogadores no Studio ou 2 contas) para validar em tempo real o convite ponta-a-ponta e a câmera espelhada do Jogador B.
- Opcional (caso o usuário queira depois): adicionar modo de treino solo 2x2 ou Torre 2x2 usando o mesmo `BattleService.StartBattle(..., { Format = "2x2" })`, e futuros golpes táticos exclusivos de dupla (ex.: *Proteção*, *Ajudar Aliado*, *Vento em Cauda*).


## Classes de Combate, Ginásios de Anime (Banners Trancados + Insígnias), Torre 2x2 e Modo Treino (21/11/2026)

**Feito**
- **8 Artes Visuais Personalizadas (geradas, recortadas em RGBA limpo, enviadas e liberadas via Open Cloud para `Universe 10777011549` e `User 5565234433`):**
  - Selos de Classe (`Blender/UI/icones/`, 256×256 RGBA): `classe_espadachim.png` (`107664037444284`), `classe_lutador.png` (`116069555686683`), `classe_mago.png` (`139698755747879`), `classe_atirador.png` (`123518987490984`).
  - Insígnias dos Ginásios (`Blender/UI/icones/`, 256×256 RGBA): `insignia_naruto.png` (`78965692677391`), `insignia_onepiece.png` (`112911216601734`), `insignia_bleach.png` (`102949134179674`).
  - Banner Bleach (`Blender/UI/banners/banner_bleach.png`, 800×350): `77274797232236`.
- **Camada 1 (`Data` / `Shared`):**
  - `src/shared/Data/TypeChart.luau`: migrado de tipos elementais estilo Pokémon para **Classes de Combate** (`Espadachim`, `Lutador`, `Mago`, `Atirador`, extensível + `Universal`), sem multiplicador de vantagem/desvantagem (`Multiplier` sempre `1x`, mantendo afinidade STAB `1.5x` e identidade de golpes/animações por classe).
  - `src/shared/Data/Moves.luau`: adicionados 16 golpes genéricos de classe (`Moves.ClassDefaults`, 4 por classe), animações padrão por classe (`Moves.ClassDefaultAnimations`), helper `Moves.ClassKit(classId, signatureMoveId)` e suporte opcional a `CritChance`; todos os golpes existentes tiveram `.Type` migrado preservando os IDs originais.
  - `src/shared/Data/Characters.luau`: adicionado o anime **Bleach** com 6 personagens (`Chad`, `Uryu`, `Rukia`, `Renji`, `Ichigo`, `Byakuya`) herdando kits genéricos via `Moves.ClassKit`; todos os personagens migrados para as 4 Classes; iniciais atualizados exclusivamente para **`Luffy`, `Naruto` e `Ichigo`**.
  - `src/shared/Data/Gyms.luau` (**NOVO**): 3 Ginásios de Anime (`Naruto` — *Ginásio de Konoha*, `OnePiece` — *Ginásio da Grand Line*, `Bleach` — *Ginásio da Soul Society*), cada um com mini-trilha de 3 lutas (`2 → 4 → 6` personagens, `Facil → Medio → Dificil`), metadados da Insígnia, prêmios de 1ª vitória/revanche e mapeamento `Gyms.ForBanner`.
  - `src/shared/Data/Summon.luau` & `SummonStageThemes.luau`: adicionado banner `Bleach` (e palco 3D temático da Soul Society com `Byakuya`, `Ichigo` e `Renji`) e ícones de insígnia nos banners.
  - `src/shared/UI.luau`, `UITheme.luau`, `CharacterFilter.luau`, `TeamCards.luau`, `Net.luau`: registrados os 8 novos ativos, paleta/ícones das 4 Classes e filtro `"CLASSE: TODAS"`.
- **Camada 2 (`Core`):**
  - `src/shared/Core/DamageCalc.luau`: suporte a `move.CritChance` em `Compute` e `ExpectedDamage`.
  - `src/shared/Core/BattleEngine.luau`: guarda defensiva em `ActiveAt` quando `side` não existe na tabela `Sides` (ex.: `"None"` ao fugir).
- **Camada 3 (`Server`):**
  - `src/server/Data/PlayerDataService.luau`: adicionados `Tower2x2`, `Season2x2`, `UnlockedBanners` e `GymsCleared` no perfil padrão e na sanitização (preservando personagens já obtidos em perfis antigos).
  - `src/server/Data/ProgressionService.luau`: `ChooseStarter` desbloqueia automaticamente o banner do anime do inicial escolhido (deixando o Ginásio livre para conquistar a Insígnia + prêmio); `OnBattleFinished` ignora escrita no perfil quando `battle.Mode == "Practice"`.
  - `src/server/Data/RetentionService.luau` & `AlbumService.luau`: placar de temporada do Infinito separado para `1x1` e `2x2` (`SeasonStore(..., format)`) e grupos do Álbum migrados para `"Classe:"`.
  - `src/server/Battle/BattleService.luau`: suporte a `opts.NoWriteBack` e `opts.CanFlee`, cor neutra de queimadura no `ImpactBurst`, e correção crítica em `playVictoryModels` (ignorar `winnerSide == "None"` ao fugir para nunca travar antes do `cleanup` de retorno à praça).
  - `src/server/CharacterLibrary.luau`: modelos provisórios (`CloneSource`) vinculam automaticamente `Moves.ClassDefaultAnimations[def.Type]`.
  - `src/server/Economy/SummonService.luau`: validação autoritativa `IsBannerUnlocked(data, bannerId)` bloqueando banners de anime antes de vencer o respectivo Ginásio, e banner `"Todos"` sorteando exclusivamente personagens de animes já desbloqueados (com fallback para `Generico`).
  - `src/server/Tower/TowerService.luau`: unifica **Torre 1x1 e Torre 2x2** (progresso e placares independentes), **Ginásios de Anime** (mini-trilha de 3 lutas em 1x1 ou 2x2 concedendo Insígnia, desbloqueio do banner e recompensa) e **Modo Treino** (1x1 ou 2x2, IA Fácil/Médio/Difícil, Nível 50 igualado ou Nível Real, cópia limpa do time sem gasto de HP/PP/itens nem alteração no perfil).
- **Camada 4 (`Client`):**
  - `src/client/Gui/TowerGui/TowerClient.client.luau`: janela reorganizada em 3 abas (`TORRE` com seletor `1x1`/`2x2` + placar separado, `GINÁSIOS` com Porta-Insígnias + seletor `1x1`/`2x2` + 3 cards de Ginásio, `TREINO` com simulador configurável e barra `INICIAR TREINO` fixada no rodapé).
  - `src/client/Gui/SummonGui/SummonClient.client.luau`: trilho esquerdo com rolagem responsiva para 4+ banners, selo `TRANCADO` e prévia 3D livre dos banners bloqueados com aviso do Ginásio necessário no lugar dos botões de invocação; aba Álbum atualizada para `CLASSES`.
  - `src/client/Gui/HudGui/HudClient.client.luau`: cartões de seleção inicial (`Luffy`, `Naruto`, `Ichigo`) exibindo Anime, Classe com ícone e aviso `"Libera Banner <Anime>"`.
  - `src/client/Gui/BattleGui/BattleClient.client.luau`: seletor de alvo 2x2 atualizado para selos de classe/tática (`ALVO · ATQ`, `CRÍTICO+`, `EFEITO`, `STATUS`) e `MOCHILA` desativada também no Modo Treino.
  - `src/client/Gui/EquipeGui/EquipeClient.client.luau`: botão de filtro atualizado para `CLASSE: TODAS` com ícone de classe.

**Testado (Edit Mode + Play Mode + Capturas Visuais + Auditoria UI, 21/11/2026)**
- `python scripts/sync_studio.py status`: `All 87 scripts in src/ are 100% in sync with Roblox Studio.`
- `python scripts/sync_studio.py test`: `PASS: 1x1 GDD [12..14] (7 turns), 2x2 Doubles (sim 8 turns), Classes 1x + Kits + Bleach (6) + 3 Starters + 3 Gyms + Practice 2x2`.
- **Play Mode ao vivo:**
  - `ContentProvider:PreloadAsync`: 8/8 novos ativos com `Success` (e `GET /assets/v1/assets/{id}` `Approved` + `Use` para `Universe 10777011549` e `User 5565234433`).
  - `TowerGui`: capturas das 3 abas (`TORRE`, `GINÁSIOS` com Porta-Insígnias e 3 Ginásios, `TREINO` com barra `INICIAR TREINO` fixada) e `_UITestKit.audit()` com `0` problemas nas 12 combinações (`3 abas × Desktop / 667x375 / 932x430 / 1024x768`).
  - `Modo Treino 2x2`: batalha iniciada com times igualados em Nv. 50, selos de classe (`ESPADACHIM`/`LUTADOR`), `MOCHILA` desativada, seletor de alvo (`ALVO · ATQ`), fuga livre (`FUGIR`) retornando limpo à praça sem erro de console e sem alterar Gold/HP/XP do perfil salvo.
  - `Ginásio de Konoha (2x2)`: Etapa 1 iniciada via botão `DESAFIAR` com `Shikamaru` (Nv. 12 `MAGO`) e `Sakura` (Nv. 12 `LUTADOR`), `MOCHILA` ativa e `DESISTIR`.
  - `SummonGui`: todos os 4 banners (`TODOS`, `ONE PIECE`, `NARUTO`, `BLEACH`) encaixados no trilho, selo `TRANCADO`, palco 3D do Bleach (`Byakuya`, `Ichigo`, `Renji`), bloqueio client + server (`Banner trancado! Vença o Ginásio da Soul Society na Torre para desbloquear.`) e Álbum com `CLASSES`.
- Place salvo no Roblox Studio na **versão 278** (`TeamCreate`).

**Pendências**
- Substituir futuramente os modelos provisórios dos 6 personagens de Bleach (`Chad`, `Uryu`, `Rukia`, `Renji`, `Ichigo`, `Byakuya`) por modelos 3D dedicados no Blender conforme o ritmo de produção.
- Gravar animações dedicadas por arma/classe (ex.: corte de espada, rajada de arco/disparo, conjuração de mago) e preencher seus AssetIds em `Moves.ClassDefaultAnimations` em `src/shared/Data/Moves.luau`.
- Atualizar `Blender/GDD.md` se desejar formalizar a seção de Classes/Ginásios/Treino no documento de design; `git push` pendente (incluindo commit anterior `931dad7` e estas alterações quando o usuário solicitar commit/push).


## Rebalanceamento Completo da Progressão, Gold Ao Vivo por Segundo, Trilha Inicial e Ranking PvP 2x2 (22/11/2026)

**Feito**
- **1. Fechamento de Vazamento de Banners Trancados:**
  - `src/server/World/RefugeService.luau`: `RefugeService.Roll` agora filtra selvagens por `data.UnlockedBanners` (sempre permitindo `Generico`), impedindo capturar personagens de Ginásios ainda trancados; no 1º acesso à caverna, já surgem 2 selvagens imediatos.
  - `src/server/Tower/TowerService.luau`: `BossDrop` do Infinito respeita `data.UnlockedBanners` (se o chefe for de anime ainda trancado, entrega `+300 gold` bônus + dica do Ginásio necessário).
- **2. Curva Justa de NPCs (Fim do Paredão `+58%` no Início):**
  - `src/shared/Data/Genetics.luau` e `src/server/Tower/TowerService.luau`: `Genetics.TowerEnemyPreset(modeId)` escalado (`Facil = 25/0` `1.10x`, `Medio = 45/35` `1.285x`, `Dificil = 60/75` `1.465x`, `Infinito = 70/100` `1.58x`) e `Genetics.GymEnemyPreset(tier)` (`Konoha 35/15`, `Grand Line 50/45`, `Soul Society 65/75`).
- **3. Gold da Base Ao Vivo (A Cada 1 Segundo Online) + Economia Rebalanceada (Mantendo Gemas Raras):**
  - `src/shared/Data/Base.luau`: nova taxa `Base.GoldPerSecond` (`Comum 0.40/s`, `Raro 0.65/s`, `Epico 1.00/s`, `Lendario 1.60/s`) escalando `+4%/nível` e `+15%/estrela` (`Base.MemberGoldPerSecond`); minério/gemas (`OrePerHour`, `OrePerGem = 100`, `DailyGemCap = 50`) preservados para manter gemas difíceis e valiosas.
  - `src/server/Economy/BaseService.luau`: loop `LIVE_TICK = 1s` credita Gold fracionário (`Base.GoldCarry`) direto em `data.Gold` enquanto online e publica atributos leves `LiveGold` / `LiveGoldRate`; ganhos offline (até 8h) e minérios continuam em `Pending` para coleta.
  - `src/client/Gui/HudGui/HudClient.client.luau` e `BaseUiClient.client.luau`: contador de Gold no HUD sobe ao vivo todo segundo com indicador `+X/s` logo abaixo da pílula; `BaseGui` exibe taxas individuais em `g/s` e produção online direta.
  - `src/shared/Data/Tower.luau` e `Gyms.luau`: Gold da Torre e Ginásios rebalanceado (`Fácil 300g + Doce Comum`, `Médio 1.200g + Superpoção + Doce Raro`, `Difícil 3.500g + Hiperpoção + Reviver + Doce Épico + 5 gemas/dia`, `Infinito 250g/andar + 1.200g/5 andares`; Ginásios `1.000/1.800/2.800g` + Doces + `3/3/4 gemas` enxutas na 1ª vitória).
- **4. Primeiros 15 Minutos + XP Compartilhado + Forja Integrada ao 2x2 e Insígnias:**
  - `src/shared/Data/Progression.luau` e `src/server/Data/ProgressionService.luau`: `StarterKit` (`600 gold`, `3x Poção`, `3x Selo de Contrato`, sem gemas) ao escolher o inicial + `BenchXpRatio = 0.40` (40% do XP compartilhado para o banco vivo).
  - `src/shared/Data/Refuge.luau` e `src/server/World/RefugeService.luau`: intervalos iniciais do Refúgio reduzidos (`240s → 90s`, `Max = 3`, `GoldPerLevel = 12`), requisitos da Forja aceitando Torre `1x1` OU `2x2` + `GymBadges` (`1`, `2`, `3` Insígnias nos Nvs. 3, 5 e 7), mantendo intactos os custos exigentes de Gemas (`50 → 2.000`).
- **5. Trilha de Objetivos Iniciais (`StarterTrack`, 7 Passos no HUD):**
  - `src/shared/Data/StarterTrack.luau` (**NOVO**), `src/server/Data/RetentionService.luau` (`ClaimStarterStep` via `Remotes.Rewards`), `src/server/Data/PlayerDataService.luau` e `src/client/Gui/HudGui/HudClient.client.luau`: card compacto no canto superior direito guiando do passo `1/7` (*Ative sua Base*) ao `7/7` (*1ª Insígnia de Ginásio*), com resgate em 1 toque e desaparecimento automático ao concluir.
- **6. Progressão Competitiva no PvP 2x2 (Ranking ELO, Patentes e Bônus Diário Anti-Farm):**
  - `src/shared/Data/PvPRank.luau` (**NOVO**), `src/server/Battle/PvPService.luau`, `src/client/Gui/PvPGui/PvPClient.client.luau` e `src/client/Gui/TowerGui/TowerClient.client.luau`: 6 patentes (`Bronze` → `Lenda`), ELO com peso maior no `2x2` (`K=32` vs `K=24`), bônus diário em Gold/Doce (`3 vitórias/dia`: `+450g + Doce Comum` no 2x2, `+300g` no 1x1, `+100g` participação) com trava anti-farm de 1 partida ranqueada/premiada por oponente ao dia, placar global `PvPRank_v1` e aba `PVP` integrada no placar da Torre.

**Testado (Edit Mode + Play Mode ao vivo + Auditoria UI, 22/11/2026)**
- `python scripts/sync_studio.py status`: `All 89 scripts in src/ are 100% in sync with Roblox Studio.`
- `python scripts/sync_studio.py test`: `PASS: 1x1 GDD [12..14] (7 turns), 2x2 Doubles (8 turns), Classes/Gyms/Practice + Progression Rebalance (Live Gold/s, StarterTrack 7, PvP Elo, Scaled NPCs)`.
- **Play Mode ao vivo:**
  - `LiveGold` medido subindo ao vivo na carteira (`990819 → 990831`, `+12` em `3.5s` a `+4.1/s` com evento 2x Gold), badge `+4.1/s` renderizando limpo abaixo da pílula de Gold.
  - Card `GUIA 1/7 · Ative sua Base` visível e funcional: resgate via servidor confirmou `+300 gold` e avançou para `GUIA 2/7 · 1ª Invocação`.
  - Selos das 4 Classes (`classe_espadachim`, `classe_lutador`, `classe_mago`, `classe_atirador`) renderizados nítidos na `TeamBar` (`IsLoaded=true`).
  - `BaseGui` exibindo `+2/s` (base), taxas individuais em `g/s` e `Online: +2/s direto`.
  - `TowerGui` exibindo novas recompensas (`300 gold, Doce Comum`, `1200 gold, Superpoção, Doce Raro`) e aba `PVP` no placar (`Ranking PvP · Bronze (1000 ELO)` + `Bônus hoje: 0/3`).
  - `_UITestKit.audit()` limpo (`0` problemas reais em `HudGui` e `TowerGui` × `Desktop / 667x375 / 932x430 / 1024x768`) e `get_console_output` 100% limpo (zero erros/avisos).
- Place salvo no Roblox Studio na **versão 282** (`TeamCreate`).


## Auditoria Completa de HUDs + Correção do Nível da Conta e Recompensas de Nível (22/11/2026)

**Feito**
- **1. Restauração & Integração Disk-First do Nível da Conta e Recompensas de Nível (92 scripts sincronizados):**
  - Trazidos para `src/` (antes existiam apenas no Studio, por isso `sync_studio.py` havia desconectado o backend):
    - `src/shared/Data/AccountLevel.luau` (**NOVO no disco**): adicionadas fontes `GymWin = 180`, `PvPWin = 90` e `StarterStep = 60` à tabela `XpSources`.
    - `src/server/Data/AccountLevelService.luau` (**NOVO no disco**): corrigido `canFitItems` para usar `Benefits.BagSlots(data, Items.BagSlots)` (em vez de `Items.BagSlots` fixo), aplicado `PaidRandomRestricted` na entrega de `Tickets.Premium` (converte para `Retention.PremiumTicketGems` gemas quando restrito) e atualizado atributo `LiveGold` ao creditar Gold.
    - `src/client/Gui/LevelRewardsGui/LevelRewardsClient.client.luau` (**NOVO no disco**): corrigido espaçamento de `Tick`/`Lock` vs `Label` em `ClaimedTag` e `LockedTag`.
    - `src/shared/Net.luau`: documentados os remotes `AccountXpGain` e `ClaimLevelReward`.
  - `src/server/Data/PlayerDataService.luau`: adicionado campo `Account = { Level = 1, Xp = 0, TotalXp = 0, Claimed = {} }` em `defaultProfile()` e sanitização em `sanitize(data)` preservando progresso salvo.
  - `src/server/Data/DataMain.server.luau`: inicializado `AccountLevelService.Init()` logo após `PlayerDataService.Init()` (restaurando `Remotes.ClaimLevelReward.OnServerInvoke`) e adicionado comando de teste `addaccxp` em `_DevData`.
  - **Todas as 8 fontes de XP da Conta reconectadas no servidor:** `ProgressionService` (vitórias em batalha), `TowerService` (conclusão de modos, andares/chefes do Infinito e Ginásios), `SummonService` (invocações Comum/Premium), `BaseService` (coleta da Base), `TrainingService` (conclusão na Cápsula), `RetentionService` (missões diárias/semanais e passos da Trilha Inicial), `RefugeService` (captura e vitória sobre selvagens) e `PvPService` (vitórias PvP ranqueadas dentro do limite diário anti-farm).
  - `src/client/Gui/HudGui/HudClient.client.luau`: restaurado o cartão **`AccountLevelCard`** no canto superior direito (medalha `NV. X`, barra de XP azul, badge vermelho de recompensas pendentes, flash `+X XP` via `Remotes.AccountXpGain` e clique direto para abrir `RECOMPENSAS DE NÍVEL`), com pilha responsiva (`layoutRightStack`) acima da `StarterTrack`.
- **2. Auditoria e Correção Geométrica de Todas as 15 HUDs (Desktop + Celular `667x375`):**
  - `src/shared/UI.luau`: corrigido `UI.button` com `Layout = "row"` (`Icon` `0.05..0.33` vs `Label` `0.35..0.96`), eliminando sobreposição de ícone e texto em botões estreitos de todo o jogo (`ClaimAll`, `ClaimBtn`, `StartPractice`, etc.).
  - `src/client/Gui/HudGui/HudClient.client.luau`: reescalado `Top` (`0.50`, padding `0.045`) e `Event` (`X=0.895`) sem colisão em `667x375`; `TeamWindow` (Golpes) ganhou `BottomBar` com `UI.clampHeight` e `layoutTeamDetail` para `Use_Doce*` e `SaveMoves` nunca vazarem da moldura.
  - `src/client/Gui/RefugeGui/RefugeClient.client.luau`: na Forja, separados `Level` (`0.02..0.26`) e `Field` (`0.27..0.74`), `Chances` reposicionado dinamicamente abaixo do `Top` (`layoutForge`), pílulas de raridade (`Name 0.05..0.57` vs `Value 0.59..0.95`) e requisitos (`Text 0.03..0.63` vs `Progress 0.66..0.87`); no Baú, separados `Capacity` (`0.03..0.37`) e `Hint` (`0.39..0.97`).
  - `src/client/Gui/BagGui/BagClient.client.luau`: separados verticalmente `Count` (`Y=0.04..0.21`) e `Icon` (`Y=0.22..0.54`) nos cartões de item.
  - `src/client/Gui/TrainingGui/TrainingClient.client.luau`: `StatGrid` convertido em `ScrollingFrame` adaptativo com altura exata sem colidir com `Footer` e preservando botões `-`/`+` `>= 44x44px` no celular `667x375`.
  - `src/client/Gui/CharacterDetailGui/CharacterDetailClient.client.luau`: corrigida sobreposição `Top` (`0.52`) vs `Final` (`0.54..1.00`) nas 4 linhas de atributos e atualizado texto do rodapé sobre a Cápsula de Treino.
  - `src/client/Gui/RewardsGui/RewardsClient.client.luau`: botão `Open` dos Baús de Tempo ancorado na base (`AnchorPoint=(0,1), Y=0.96`) sem estourar o cartão no celular.
  - `src/client/Gui/SummonGui/SummonClient.client.luau`: `TopBar` clamped (`48..60px`) com `layoutBannerRails`, `BannerTab` sem encolher abaixo de `44px` (`Scale=1.0`), `RatesRail` (`Name 0.06..0.56` vs `Value 0.58..0.94`), `Album` ocultando `Variants` em cartas bloqueadas (`Lock` em `Y=0.78`), `BottomDock` (`clampHeight 82..134`) e `SlotPlate_*` (`clampHeight 40..68`/`46..82`) sem sobreposição de `RarityBar` e sem overflow de `Summon1`/`Summon10`.
  - `src/client/Gui/TowerGui/TowerClient.client.luau`: ocultado `Label` em modos trancados da Torre (evitando sobreposição com `Lock`) e ajustadas linhas de opção da aba `Treino` (`Aspect=8.5, RowMax=60`, `Choices 0.88`) para caber `Tabs` sem overflow no celular.

**Testado (Edit Mode + Play Mode ao vivo + Auditoria Geométrica em todas as 15 GUIs, 22/11/2026)**
- `python scripts/sync_studio.py status`: `All 92 scripts in src/ are 100% in sync with Roblox Studio.`
- `python scripts/sync_studio.py test`: `PASS: 1x1 GDD [12..14] (7 turns), 2x2 Doubles (8 turns), Classes/Gyms/Practice + Progression Rebalance + AccountLevel` (inclui Teste 8 validando curva de XP, marcos, `BattleVictoryXp` e contagem de pendentes).
- **Play Mode ao vivo (com backup/restore do DataStore para manter perfil intacto):**
  - `AccountLevelCard` exibido no HUD (`NV. 2`, `34/176`, badge `1`) e clique abrindo `RECOMPENSAS DE NÍVEL`.
  - `ClaimLevelReward:InvokeServer(2)` retornou `true` (`Nível 2 resgatado: +190 gold, +3x Poção!`), limpou badge e bloqueou resgate duplicado.
  - `addaccxp(+200)` subiu a conta ao vivo para `NV. 3` (`58/231`), atualizou o cartão via `AccountXpGain` e `ClaimLevelReward:InvokeServer("All")` resgatou o Nível 3 (`+230 gold, +2 itens`).
  - Auditor geométrico automatizado rodado em **todas as 15 GUIs** (Desktop + `667x375`): **0 sobreposições reais e 0 overflows reais**; `get_console_output` 100% limpo.
- Place salvo no Roblox Studio na **versão 287** (`TeamCreate`).


## Respiro Global das HUDs, Novo Estilo de Cards, Álbum 3D com Silhuetas e Correção "Vença" (22/11/2026)

**Feito**
- **1. Respiro sistêmico no kit de UI e eliminação de cortes/colisões (`src/shared/UI.luau`):**
  - Sombra dos painéis/botões afinada (`shadowPxFor`: `2..6 px` conforme a altura da tela) para remover blocos pesados que colidiam com elementos abaixo.
  - `UI.panel` agora aceita `StrokeMult` (eliminando `UIStroke` duplicado em cards com borda colorida).
  - `UI.scroll` recalculado com margens seguras (`leftPx`/`topPx >= stroke + 4`, `rightPx >= stroke + ScrollBarThickness + 6`, `botPx >= shadow + stroke + 6`) e espaçamentos `gapX`/`gapY` (modo `Flat` opcional para listas limpas) — corrigindo o corte lateral em `Mochila > Itens` e a colisão de sombras/bordas em todas as listas e grades.
  - `UI.fillBetween` agora compensa automaticamente sombra + contorno de abas/cabeçalhos (incluindo escala `UIScale` durante animação de abertura) e `UI.tabs` ganhou maior folga horizontal quando há até 3 abas.
- **2. Novo visual de cards limpos e espaçamento nas HUDs:**
  - `src/client/Gui/TowerGui/TowerClient.client.luau`: abas `TORRE`, `GINÁSIOS` e `TREINO` com cards planos de contorno único, barra vertical de destaque por modo, separação limpa entre abas/seletores `1x1`/`2x2` e botões centralizados com folga interna.
  - `src/client/Gui/BagGui/BagClient.client.luau`: folga segura abaixo das abas `ITENS`/`PERSONAGENS` e dos filtros, grade `ITENS` sem corte na borda esquerda e com destaque dourado no item selecionado, e lista `PERSONAGENS` com linhas espaçadas.
  - `src/client/Gui/SummonGui/SummonClient.client.luau`: aba `REPETIDOS` com respiro abaixo das abas, cards com barra lateral de raridade + contorno único e botões `FUNDIR +1`/vender centralizados verticalmente com folga.
  - `src/client/Gui/BaseGui/BaseUiClient.client.luau`, `src/client/Gui/RewardsGui/RewardsClient.client.luau`, `src/client/Gui/ShopGui/ShopClient.client.luau` e `src/client/Gui/LevelRewardsGui/LevelRewardsClient.client.luau`: padronização dos cards de lista (contorno único, `Shadow = false`, `Flat = true` e botões centralizados).
- **3. Álbum com retratos 3D dos personagens + silhueta/sombra para não obtidos:**
  - `src/shared/TeamCards.luau`: adicionado `card.SetAlbum(charId, opts)` com o mesmo visual de cartões 3D da `Equipe`. Personagens ainda não obtidos exibem a **silhueta/sombra 3D escura** (`ViewportFrame` com `ImageColor3 = (0,0,0)` e `ImageTransparency = 0.14` sobre fundo azul-noturno contrastante), nome `???`, ícone de cadeado no canto superior esquerdo e ícone de classe suavizado.
  - `src/client/Gui/SummonGui/SummonClient.client.luau`: aba `ÁLBUM` convertida para grade virtualizada de `TeamCards` (3–4 colunas responsivas, pool reutilizável e liberação automática dos `ViewportFrame`s ao trocar de aba/fechar) e contador `COLEÇÃO: X/23`.
- **4. Correção de português `"Venza"` → `"Vença"`:**
  - Corrigidas todas as 3 ocorrências no projeto: `src/shared/Data/StarterTrack.luau` (passos 5/7 e 7/7) e `src/server/Tower/TowerService.luau` (mensagem de chefe da Torre).

**Testado (Edit Mode + Play Mode ao vivo + Auditoria Multi-Dispositivo, 22/11/2026)**
- Auditoria `_UITestKit.audit()` passou **44/44 combinações** (`Desktop`, `667x375`, `932x430`, `1024x768`) e `get_console_output` sem erros de jogo. Place salvo na **versão 290** (`TeamCreate`).


## Atualização da Planilha de Personagens + Regra Permanente (23/11/2026)

**Feito**
- Criado o gerador automático `scripts/update_characters_sheet.py`, que lê diretamente `src/shared/Data/Characters.luau`, `src/shared/Data/Moves.luau` e `src/server_storage/Codes.luau`.
- Atualizadas de forma idêntica `Blender/Planilha_Personagens.xlsx` e `Planilha_Personagens.xlsx` com **3 abas** (`Personagens`, `Golpes`, `Resumo`).
- Regra permanente registrada em `AGENTS.md` e `Blender/REGRAS.md` obrigando a rodar `python scripts/update_characters_sheet.py` sempre que personagens forem adicionados ou alterados.


## Implementação dos 12 Modelos 3D de Bleach e Naruto + Auras Lendárias (Byakuya e Sarutobi) (23/11/2026)

**Feito**
- **1. Processamento 3D Automático (`scripts/auto_rig_tripo.py`) com Proteção para Cabelos, Faixas e Ombreiras:**
  - Processados todos os **12 personagens** (com texturas embutidas `.fbm` dos `.zip` originais do Tripo, caps fechados e malha double-sided sólida) e enviados ao Roblox via Open Cloud:
    - **Bleach (6):** `Ichigo` (`95123860255731`), `Rukia` (`79398104974321`), `Uryu` (`118195426363266`), `Renji` (`134772458566956`), `Chad` (`122224205258720`), `Byakuya` (`126112514814264`).
    - **Naruto (6):** `Kakashi` (`117912890574491`), `Naruto` (`101443069651309`), `Sakura` (`89672702033715`), `Sasuke` (`139821214576744`), `Shikamaru` (`104194114824445`), `Sarutobi` (`84615025884468`).
- **2. Montagem R6-on-R15 em `ServerStorage/Characters`:**
  - Todos os 12 modelos montados sobre o esqueleto R15 invisível padrão (`FloorDelta = 3.1897`, rotação normalizada para `-Z`, `TextureID` nativo preservado nos 6 `*_Mesh`, pasta `Animations` sincronizada com animações base + classe).
- **3. Dados, Códigos Dev e Replicação de Auras Atualizados:**
  - `src/client/PlayerScripts/CharacterAuraClient.client.luau`: adicionada escuta `folder.DescendantAdded` com re-escaneamento incremental (`populateEntry`).
  - `src/shared/Data/Characters.luau`: atualizado `KeepTextureParts = { "Head", "Head_Mesh" }` e removidos os blocos `PlaceholderColors` de todos os 12 personagens de Bleach e Naruto.
  - `src/server_storage/Codes.luau`: adicionados códigos Dev repetíveis individuais para todos os 12 personagens, lotes `KONOHA`/`DEVKONOHA` e `BLEACH`/`DEVBLEACH`, e `DEVALL` atualizado para todos os 23 personagens.
- Place salvo no Roblox Studio na **versão 297** (`TeamCreate`).


## Reformulação Completa da UI (Midnight-Blue Anime), Barra de Nível Embaixo da TeamBar e Bônus Minimalista (23/11/2026)

**Feito**
- **1. Paleta Midnight-Blue Anime & Motor Visual `UI` (`src/shared/UITheme.luau`, `Blender/UI/tema.json`, `Blender/UI/UITheme.lua`, `src/shared/UI.luau`, `src/shared/TeamCards.luau`):**
  - Nova paleta azul-noturno profundo inspirada em *Anime Vanguards / Anime Fighters* (`Outline` `#0B0E22`, `panel` `#273066 -> #161B3D`, `panelAlt` `#36428A -> #212859`, `slot` `#191E42 -> #0F122B`, `header` `#3B9EFF -> #1B64D8`, `track` `#0B0E22`, `inkSoft` `#B8C2F0`), preservando as cores das 4 Classes de Combate (`Espadachim`, `Lutador`, `Mago`, `Atirador`, `Universal`).
  - Camada de brilho diagonal de 3 bandas a 38° (`UI.sheen`) integrada automaticamente em `UI.panel`, `UI.bar` e `TeamCards`, com remoção automática quando `UIGridStyleLayout` é inserido na `face`.
  - Afundamento físico 3D (`pressFace` deslocando `face` em `+2px` Y ao clicar/tocar), contornos de texto com `Enum.LineJoinMode.Bevel`, suporte a ícones personalizados em `UI.tabs` (`DEFAULT_TAB_ICONS`) e `UI.chip` (`p.Icon`), e correção de `ZIndex` do ícone da moeda em `UI.pill` (`baseZ + 3` acima da `face`).
- **2. Barra de Nível da Conta Embaixo da `TeamBar` (`src/client/Gui/TeamBarGui/TeamBarClient.client.luau` & `src/client/Gui/HudGui/HudClient.client.luau`):**
  - Posicionada a `AccountLevelBar` diretamente embaixo da `TeamBar` (alinhada `L:+0, R:+0` com a largura exata dos 6 slots do time), composta pela pílula esquerda `LevelPill` (`"Nv. X"`) + trilha direita `XpTrack` (`"X / Y XP"`), animação de ganho `+X XP` (`spawnXpPop`) e banner de subida de nível (`AccountLevelUpBanner`).
  - Removido o cartão duplicado `AccountLevelCard` do canto superior direito do `HudClient`, mantendo o card `StarterTrack` (Guia 1/7..7/7) posicionado logo abaixo do botão de Configurações.
- **3. Bônus de Fim de Semana Minimalista no Canto Inferior Direito (`src/client/Gui/HudGui/HudClient.client.luau` & `src/client/Gui/RewardsGui/RewardsClient.client.luau`):**
  - Substituída a faixa grande superior do evento de fim de semana por um selo circular minimalista (`Badge`, `44x44..54x54 px`) no canto inferior direito da tela com o ícone da moeda (`coin`) ou XP (`sparkle`), exibindo a pílula de tooltip (`"2x de Moedas"` ou `"2x de XP"`) ao passar o mouse (`MouseEnter`) ou tocar no celular.
- **4. Zero Emojis / 100% Ícones Personalizados & Correções do Banner de Invocação (`SummonClient`, `ShopClient`, `CharacterDetailClient`, `TrainingClient`, `RefugeClient`, `TowerClient`, `LevelRewardsClient`):**
  - Removidos 100% dos símbolos Unicode (`★`, `✦`, `✓`, `→`, `■`, `—`) de todas as 16 GUIs em `src/client/Gui/`, substituídos por ícones reais de `UI.Icons` (`star`, `sparkle`, `tick`, `trophy`, `portal`, `book`, `swap`, `gift`, `pickaxe`, `ore_*`, `classe_*`).
  - `SummonClient.client.luau`: mantidas intactas as artes dos banners (`Artwork`) e o bloqueio de Ginásios (`LockedTag` / `LockedBannerDock`), com centralização matemática dinâmica (`TextBounds.X`) do conjunto `[Moeda + Preço]` dentro dos botões `INVOCAR 1` e `INVOCAR 10`, placas `SlotPlate_1..3` contidas dentro das margens da `BottomDock` e moeda da carteira (`HudWallet`) sempre visível na frente da pílula.
  - `default.project.json`: registrado `LevelRewardsGui` em `StarterGui` completando as 16 `ScreenGui`s do projeto.


## Byakuya (Aura Minimalista, Fix de Cabelo, Shikai/Bankai), Ataques Compartilhados de Espadachim e Arena Carmesim Escuro (24/11/2026)

**Feito**
- **1. Aura Minimalista + Correção do Cabelo do Byakuya (`ServerStorage/Characters/Byakuya`):**
  - Substituída a aura antiga poluída (backup salvo em `ServerStorage/_ByakuyaOldAuraBackup`) por aura minimalista `Senbonzakura`: 1 `AuraVolume` compacto com `SenbonzakuraPetals` (`Rate = 7`), `SilverBladeGlints` (`Rate = 2.6`), `AuraLight` suave (`Brightness = 0.72`, `Range = 8.5`, `Shadows = false`) e contorno fino `AnimeOutline3D` (`FillTransparency = 0.96`), com **zero discos/vórtices no chão**.
  - Corrigida a divisão/fresta branca no cabelo traseiro do Byakuya: `Head_Mesh` rebaixado `-0.09` studs + `HairSeamBridge` preto fosco na nuca + atributo `LockNeckHair = true` respeitado por `BaseClient.client.luau` e `CombatAnimator.luau` (impede o cabelo superior e inferior de abrir/fechar durante Idle, Walk ou combate).
- **2. Motor de Combate 60 FPS & 2 Ataques Básicos Compartilhados de Espadachim (`src/shared/CombatAnimator.luau`, `src/shared/Data/Moves.luau`, `src/shared/VfxController.luau`, `ReplicatedStorage/Vfx/CorteBasico` e `CorteCruzado`):**
  - Novo `CombatAnimator.luau` procedural 60 FPS compatível com rigs Híbridos R6-em-R15 e R15/Skinned, com katana acoplada à mão direita (paletas personalizadas por espadachim + `BladeTrail`) e suporte a **Hitstop** real.
  - `CorteBasico` (*Corte Rápido*) e `CorteCruzado` (*Corte Cruzado*) configurados como os **2 ataques básicos idênticos compartilhados por todos os Espadachins** (`Byakuya`, `Zoro`, `Ichigo`, `Renji`, `Sasuke`, etc.).
- **3. Técnicas Assinatura do Byakuya (`Senbonzakura` & `SenbonzakuraKageyoshi`):**
  - `Senbonzakura` (Shikai, `Power = 58`, `CutIn = true`): lâmina erguida verticalmente se dissolve em pétalas → fita espiral de cerejeira + 4 cortes neon em cascata + Impact Frame rosado.
  - `SenbonzakuraKageyoshi` (Bankai, `Power = 72`, `Target = "AllEnemies"`, `Signature = true`, `CutIn = true`): katana afunda verticalmente no chão → 6 lâminas espectrais gigantes sobem nas laterais e estilhaçam → torrente ciclônica de pétalas + anéis giratórios + Impact Frame 2D + Hitstop + Spring Camera Shake + FOV Punch + 6 cortes luminosos + pétalas de resíduo.
- **4. Arena Carmesim Escuro (`workspace.Arenas/Arena01..10` & `src/server_storage/_ConstrutorArenasSukuna.luau`):**
  - Escurecido o espelho d'água (`InfiniteMirrorWater` `#440A10`, `PinkWaterRipples` `#76161E`), panorama de nuvens (`#94262C`), reflexos e VFX ambiente de rosa brilhante para **vermelho carmesim escuro**, reduzindo `SkyIllum` (`2.15 → 0.90`), `WaterPinkFill` (`1.15 → 0.42`) e `CenterBattleLight` (`1.75 → 1.15`).
- **5. Regras Permanentes Atualizadas (`AGENTS.md` & `Blender/REGRAS.md`):**
  - Registradas permanentemente as regras de `git pull` prévio, auras minimalistas (sem círculos no chão), os 2 ataques básicos compartilhados de Espadachim e atualização obrigatória da planilha de personagens.

**Testado (Play Mode ao vivo + Capturas Visuais)**
- Validados ao vivo na `Arena01`: aura minimalista, cabelo traseiro sem fresta branca, nova Arena vermelho carmesim escuro e todos os 4 golpes (`CorteBasico` no Ichigo; `CorteCruzado`, `Senbonzakura` e `SenbonzakuraKageyoshi` no Byakuya) com **0 erros no console**. Place salvo na **versão 307** (`TeamCreate`).


## Ajuste de Opacidade das Auras + Aura Rosa Suave no Byakuya (24/11/2026)

**Feito**
- **1. Byakuya (`ServerStorage/Characters/Byakuya/AuraVfx`):**
  - Mantidas intactas as pétalas (`SenbonzakuraPetals`), brilhos metálicos (`SilverBladeGlints`) e luz suave (`AuraLight`).
  - Adicionados `SakuraAuraVeil` (`rbxassetid://104537118545021`, `Grid4x4 OneShot`, `Transparency` `0.70..0.82`, `Rate = 18`, `ZOffset = -0.35`, rosa-sakura suave) e `SakuraBackMist` (`rbxassetid://83184852649242`, `Transparency` `0.86`, `Rate = 3`, `ZOffset = -0.70`) para dar um detalhe espiritual rosa de opacidade bem baixa por trás das pétalas sem poluir a silhueta.
  - Contorno `AnimeOutline3D` suavizado (`FillTransparency = 0.97`, `OutlineTransparency = 0.62`).
- **2. Redução de Opacidade em Todas as Outras Auras (`BarbaBranca`, `San`, `Sarutobi`, `Setero`):**
  - Reduzida a opacidade e o brilho de todas as camadas (`ParticleEmitter` de chamas/energia para transparência `0.71..0.85`, faíscas/raios/estilhaços para `0.58..0.76`, `Beam` helicoidais para `0.66..0.95`, `SurfaceGui` de halos traseiros para `ImageTransparency 0.69..0.73`, orbes neon de `Sarutobi`/`Setero` para `Transparency = 0.46` e trilhas para `0.62+`, `PointLight` para `Brightness <= 0.88`, `AnimeOutline3D` para `FillTransparency = 0.975` / `OutlineTransparency = 0.66`, além de `BarbaBranca.UpperTorso.YonkoPresence`).
  - Removidos os discos/vórtices de chão remanescentes em `San` e `Sarutobi` (`GroundGlow`, `GroundVortexOuter`, `GroundVortexInner`, `GroundShockAnchor`), garantindo **zero círculos no chão** em 100% dos personagens (conforme `AGENTS.md` §4.5).
- **3. Respeito à Transparência Base do Contorno (`src/client/PlayerScripts/CharacterAuraClient.client.luau`):**
  - Adicionado `baseOutlineT` em `AuraEntry` para pulsar o `AnimeOutline3D.OutlineTransparency` suavemente a partir do valor configurado em cada personagem (`math.clamp(entry.baseOutlineT + 0.10 * (1 - energy), 0, 0.96)`), eliminando a sobrescrita fixa em `0.36`.

**Testado (Play Mode ao vivo + Capturas Visuais + Suíte GDD)**
- Validados visualmente ao vivo no Play Mode todos os 5 personagens (`Byakuya`, `BarbaBranca`, `San`, `Sarutobi`, `Setero`), com **0 erros no console**.
- `python scripts/sync_studio.py status` → `All 93 scripts in src/ are 100% in sync with Roblox Studio.`
- `python scripts/sync_studio.py test` → `PASS`.
- Place salvo no Roblox Studio na **versão 312** (`TeamCreate`).


## Nova Câmera 3/4 Elevada para Batalhas 2x2 (`ArenaManager.BattleCamera`) (24/11/2026)

**Feito**
- Testadas 7 angulações de câmera ao vivo em batalha 2x2 real com a HUD completa (`Byakuya + San` e `Byakuya + BarbaBranca` vs `Uryu + Ichigo`) em `Workspace.Arenas`.
- Atualizada `ArenaManager.BattleCamera` em `src/server/Battle/ArenaManager.luau` para o modo `"2x2"` (mantendo o `CameraPoint` do `1x1` intacto):
  - Antes: `camPos = pp.CFrame * CFrame.new(13.5, 5.8, 15.5)` olhando para `center + (0, 0.5, 0)` (causava sobreposição direta do aliado da direita sobre o inimigo esquerdo).
  - Depois: `camPos = pp.CFrame * CFrame.new(21.5, 10.2, 14.5)` olhando para `center + pp.CFrame.RightVector * 3.2 + Vector3.new(0, -0.3, 0)` — ângulo 3/4 elevado e lateralizado que separa os 4 lutadores horizontalmente (`u ≈ 0.20 / 0.35 / 0.51 / 0.62`) e verticalmente, mantém os pés dos aliados acima dos cartões de HP inferiores, os inimigos livres dos cartões/botões direitos, o Grande Portão do Santuário centralizado no topo e simetria completa no PvP 2x2 (`MirroredCamera`).

**Testado (Play Mode ao vivo + Suíte GDD)**
- Validado ao vivo em 2x2 com `Byakuya + San` e `Byakuya + BarbaBranca` (personagem mais alto do jogo + bisento) sem nenhuma sobreposição entre lutadores ou HUD e `0` erros de script.
- `python scripts/sync_studio.py status` (`100% in sync`) e `python scripts/sync_studio.py test` (`PASS`).
- Place salvo no Roblox Studio na **versão 313** (`TeamCreate`).


## Escudos/Altares de Chão Individuais para Batalhas 2x2 (`ArenaManager.ConfigureAltars`) (24/11/2026)

**Feito**
- Implementado `ArenaManager.ConfigureAltars(arena, isDouble)` em `src/server/Battle/ArenaManager.luau`:
  - No modo **1x1**, mantém os 2 altares originais (`DomainDecor.AltaresPersonagens`) centralizados em `PlayerPoint` e `EnemyPoint`.
  - No modo **2x2**, gera sob demanda (com cache em `ServerStorage/_ArenaAltarsCache/<Arena>`) a pasta `AltaresPersonagens2x2` com **4 escudos/altares individuais** (`AltarCombate_Player_1/2` e `AltarCombate_Enemy_1/2`) centralizados exatamente nos 4 slots 2x2 (`±5.2` studs), escalados em XZ (`0.78x`, diâmetro `6.08` studs, mantendo a altura exata do piso `floorY` e ~`2.3` studs de água carmesim livre entre escudos vizinhos, além de reposicionar os `AltarApoio` para o ponto 2x2 do treinador).
  - Integrado em `src/server/Battle/BattleService.luau` (`StartBattle`, `StartPvP` e restauração automática para `1x1` em `cleanup`).

**Testado (Play Mode ao vivo + Suíte GDD)**
- Validado ao vivo em batalha 2x2 (`Byakuya + San` vs `Uryu + Ichigo`): os 4 lutadores ficam centralizados cada um no seu próprio escudo/altar com zero sobreposição e alternância limpa `1x1 ↔ 2x2`.
- `python scripts/sync_studio.py status` (`100% in sync`) e `python scripts/sync_studio.py test` (`PASS`).
- Place salvo no Roblox Studio na **versão 314** (`TeamCreate`).


## Indicadores de Alteração de Atributos na HUD de Batalha (`BattleClient`) (24/11/2026)

**Feito**
- Adicionada faixa `StagesBar` em todos os cartões de batalha (`PlayerCard1/2` acima do cartão; `EnemyCard1/2` abaixo do cartão) em `src/client/Gui/BattleGui/BattleClient.client.luau`:
  - Exibe pílulas coloridas por atributo alterado (`ATQ`, `DEF`, `VEL`, `PRE`) usando `DamageCalc.StageMultiplier` para mostrar o valor exato em porcentagem (**verde** para aumentos como `ATQ +50%`, `ATQ +100%`; **vermelho** para reduções como `DEF -33%`, `DEF -50%`), sem emojis/símbolos Unicode (`Midnight-Blue Anime`).
  - No modo `2x2`, quando `EnemyCard2` tem atributos alterados, `EnemyCard1` desliza suavemente para baixo (`Y = 0.238`) evitando qualquer sobreposição com `EnemyCard2` ou com o chip `ActorChip` abaixo.
  - Adicionado tratamento em tempo real do evento `StatStage` em `BattleUpdate.OnClientEvent`: atualiza a pílula na hora com animação de `PopScale` (`1.28 → 1.0`), exibe texto flutuante 3D (`popNumber`) sobre o personagem e limpa os badges automaticamente ao trocar ou desmaiar.

**Testado (Play Mode ao vivo + Suíte GDD)**
- Validado ao vivo em batalha 2x2 real com `Postura da Lâmina` (`ATQ +50%` → empilhado `ATQ +100%`) e `Carga de Ki` (`ATQ +50%` → `ATQ +100%`), além de stress test visual simultâneo com 1, 2, 3 e 4 badges verdes/vermelhos nos 4 cartões sem cortes nem sobreposições (`0` erros de script).
- `python scripts/sync_studio.py status` (`100% in sync`) e `python scripts/sync_studio.py test` (`PASS`).
- Place salvo no Roblox Studio na **versão 315** (`TeamCreate`).


## Bolinhas do Time Fora dos Cartões (Lateral Vertical) + Remoção dos Cilindros de Impacto nos Golpes (24/11/2026)

**Feito**
- **1. Bolinhas do time fora dos cartões (`src/client/Gui/BattleGui/BattleClient.client.luau`):**
  - Removidas as bolinhas (`Pips`) de dentro dos cartões dos personagens, deixando a linha inferior limpa (`Status` à esquerda e `HpText` alinhado à direita sob a barra de HP).
  - Criadas duas barras verticais externas no tema *Midnight-Blue Anime* (`PlayerTeamPips` na lateral esquerda externa junto ao `PlayerCard1` e `EnemyTeamPips` na lateral direita externa junto aos cartões inimigos), exibindo até 6 bolinhas empilhadas verticalmente (verde = de pé, vermelho = desmaiado) com espaçamento limpo em **1x1** e **2x2**.
- **2. Remoção dos cilindros verticais ao final dos golpes (`src/shared/VfxController.luau` & `ReplicatedStorage/Vfx`):**
  - Removidos os cilindros neon verticais de impacto de todos os golpes implementados que os utilizavam: `GenkiDama.SkyPillar`, `CeuETerra.QuakeGeyserCore` (Barba Branca) e `SenbonzakuraKageyoshi.StormPillarCore` / `StormPillarOuter` (Byakuya), preservando intactos todos os demais efeitos (domos, ondas de choque, partículas, cortes neon, câmeras e som).

**Testado (Play Mode ao vivo + Suíte GDD)**
- Validados ao vivo no Play Mode: HUD 2x2 com `PlayerTeamPips` e `EnemyTeamPips` verticais fora dos cartões sem sobreposição, e execução completa dos VFX de `GenkiDama`, `CeuETerra` e `SenbonzakuraKageyoshi` com `0` erros e `0` cilindros residuais.
- `python scripts/sync_studio.py status` (`100% in sync`) e `python scripts/sync_studio.py test` (`PASS`).
- Place salvo no Roblox Studio na **versão 316** (`TeamCreate`).


## Nova Aba Completa de Ataques na Planilha + Regra Permanente Reforçada (24/11/2026)

**Feito**
- Expandido `scripts/update_characters_sheet.py` para gerar **4 abas** em `Blender/Planilha_Personagens.xlsx` e `Planilha_Personagens.xlsx`:
  - **`Personagens`** (23 ativos + 2 protótipos),
  - **`Ataques`** (nova tabela catálogo única com **todos os ataques** de `src/shared/Data/Moves.luau`: ID, Nome, Origem, Classe, Categoria, Poder, Precisão, PP, Crítico, Alvo 2x2, Efeito/Buff/Status detalhado, Assinatura, Cut-In, Animação 3D, VFX 3D, Status de Dev, Timing `C/R/I/Total`, Qtd. Usuários e lista de Personagens que usam),
  - **`Kit por Personagem`** (vínculo `Personagem × Ataque` enriquecido com Crítico e Efeito, renomeado de `Golpes`),
  - **`Resumo`** (KPIs e tabelas dinâmicas de **Personagens** e de **Ataques** lado a lado).
- Regra permanente atualizada em `AGENTS.md` e `Blender/REGRAS.md` garantindo atualização obrigatória de todas as abas (`Personagens`, `Ataques`, `Kit por Personagem`, `Resumo`) sempre que personagens ou ataques forem criados/modificados.


## Grande Pacote de Ataques Genéricos por Classe + Mecânicas Táticas no Motor de Combate (24/11/2026)

**Feito**
- **1. Motor de Batalha e IA (`src/shared/Core/DamageCalc.luau`, `BattleEngine.luau`, `AIController.luau`):**
  - Implementado suporte completo guiado por dados (zero hardcode de nomes de golpes) para:
    - **Prioridade (`Priority`)**: `Flee` (+10) > `Switch`/`Item` (+6) > `Proteger` (+4) > `Guarda Ampla` (+3) > ataques rápidos (+1) > normal (0).
    - **`Protect` e `WideProtect`** (com decaimento consecutivo `1 / 2^streak`, reset em golpe comum/troca) + golpes perfurantes **`BreaksProtect`**.
    - **Entry `Hazards`** (`Spikes` até 3 camadas: 1/8, 1/6, 1/4 HP; `ToxicSpikes` até 2 camadas: Veneno / Veneno + 1/16 HP; `StickyWeb`: -1 Velocidade) aplicados na troca/substituição com proteção contra KO em entrada + **`ClearHazards`** (`Own` / `All`, com bônus de atributo opcional).
    - **Efeitos de Campo por Lado (`SideEffects`)**: `Barrier` (5 turnos, reduz dano não-crítico para 0.67x no 1x1 e 0.75x no 2x2) e `Tailwind` (4 turnos, dobra Velocidade do time).
    - **`Heal`** (próprio ou `AllAllies`), **`Cleanse`** (purifica status próprio ou `AllAllies`), **`MultiStat`** (múltiplos atributos num só golpe), **`Drain`** (dreno de HP) e **`Recoil`** (dano de recuo).
    - Espelhamento completo no PvP (`Snapshot("Enemy")` com `Hazards` e `SideEffects`) e IA atualizada (`AIController`: evita spam consecutivo de `Protect`/`WideProtect` e usa `Heal`/`Cleanse` na IA Difícil).
- **2. Catálogo Expandido de Ataques Genéricos (`src/shared/Data/Moves.luau`):**
  - Adicionados **55 novos ataques genéricos** (totalizando **71 ataques genéricos** e **93 ataques** no catálogo completo), todos com `Generic = true` e escada de progressão `LearnLevel` (Nv. 1 → 38), mais helper `Moves.GenericsByClass(classId, includeUniversal)` pronto para gerar Learnsets por nível:
    - **Espadachim (15 genéricos):** STAB básico/médio/forte, prioridade (`EstocadaVeloz`), certeiro (`CorteCerteiro`), `MultiStat` (`LaminaAfiada`), dreno (`CorteDrenante`), quebra-proteção (`QuebraLamina`), veneno (`FioVenenoso`), `+2 ATQ` (`DancaDasEspadas`), hazard `Spikes` (`LaminasNoChao`), AoE avançado (`TempestadeDeCortes`) e recuo (`InvestidaCortante`).
    - **Lutador (15 genéricos):** STAB prioridade (`SocoRelampago`), controle de velocidade (`Rasteira`), `MultiStat` (`CorpoDeFerro`), dreno (`SocoDrenante`), quebra-proteção (`PunhoDemolidor`), AoE (`OndaDeImpacto`), buff de time 2x2 (`GritoDeGuerra`), queimadura (`PunhoArdente`), limpeza de hazards + Velocidade (`GiroVarredor`), cura (`FocoInterior`) e recuo (`ImpactoTotal`).
    - **Mago (16 genéricos):** STAB prioridade (`PulsoVeloz`), congelamento (`RaioCongelante`), queimadura garantida (`FogoFatuo`), `MultiStat` (`MenteCalma`), dreno (`SifaoArcano`), sono (`NevoaDoSono`), `Barrier` (`BarreiraArcana`), `ToxicSpikes` (`RunasToxicas`), cura em área (`CuraLuminosa`), purificação em área (`Purificacao`), AoE (`ExplosaoAstral`) e nuke com queda de ATQ (`MeteoroArcano`).
    - **Atirador (15 genéricos):** STAB prioridade (`TiroRapido`), veneno (`DardoVenenoso`), `MultiStat` (`FocoDePrecisao`), `StickyWeb` (`DisparoDeRede`), controle de velocidade AoE (`TiroDeSupressao`), quebra-proteção (`DisparoRompeEscudo`), debuff de precisão AoE (`BombaDeFumaca`), `Spikes` (`MinaDeEstrepes`), paralisia (`DardoEletrico`), AoE (`RajadaTatica`) e alto crítico (`DisparoDeElite`).
    - **Universal (10 genéricos táticos):** `AtaqueRapido`, `Proteger`, `OlharIntimidador`, `GuardaAmpla`, `VenenoPuro`, `Agilidade`, `Desobstruir`, `VentoAFavor`, `MuralhaDeFerro`, `Recuperacao`.
- **3. HUD de Batalha e Planilha (`BattleClient`, `BattleService`, `scripts/update_characters_sheet.py`):**
  - `BattleClient` exibe badges ativos de campo (`ESPINHOS xN`, `TÓXICO xN`, `REDE`, `BARREIRA Nt`, `VENTO Nt`), popup 3D `"Protegido!"` (com burst turquesa em `BattleService`) e chips claros nos botões de golpe (`PROT.`, `CAMPO`, `TIME`, `ÁREA`, `RÁPIDO`, `SI`).
  - Planilha atualizada em `Blender/Planilha_Personagens.xlsx` e `Planilha_Personagens.xlsx` (93 ataques únicos na aba `Ataques` com novas colunas `Nível Sugerido` e `Prioridade`, ordenados por classe e nível de progressão).

**Testado (Studio Edit + Suíte GDD)**
- `python scripts/sync_studio.py status` (`100% in sync` nos 93 scripts) e `python scripts/sync_studio.py test` (`PASS`).
- Suíte dedicada no Studio validou todas as novas mecânicas (`93` golpes, `71` genéricos, `Priority`, `Protect`/`WideProtect`/`BreaksProtect`, `Spikes`/`ToxicSpikes`/`StickyWeb` + `ClearHazards` inclusive com KO em entrada, `Barrier`, `Tailwind`, `Drain`, `Recoil`, `Heal`, `Cleanse`, `MultiStat`, espelhamento PvP e stress test de IA `Facil`/`Medio`/`Dificil` em 2x2) sem nenhum erro.
- Place salvo no Roblox Studio na **versão 317** (`TeamCreate`).


## Progressão Completa de Ataques por Nível (Nv. 1 → 50) + Especiais Lendários nos Últimos Níveis (24/11/2026)

**Feito**
- **1. Learnsets Nv. 1 → 50 em Todos os Personagens (`src/shared/Data/Characters.luau` & `Moves.luau`):**
  - Expandido `Moves.ClassDefaults` para 12 golpes por classe (Nv. 1 → 42) e criados Learnsets individuais temáticos de **11 a 14 golpes (Nv. 1 → 50)** para todos os **23 personagens ativos**, distribuindo **100% dos 71 ataques genéricos** (e todos os 92 ataques jogáveis do catálogo — `0` ataques sem uso).
  - **Ataques especiais e assinaturas dos Lendários nos últimos níveis (Nv. 42–50):**
    - `Byakuya`: Nv. 42 `Senbonzakura` (Cut-In), Nv. 50 `Senbonzakura Kageyoshi` (Assinatura Cut-In).
    - `Barba Branca`: Nv. 34 `Corte Murakumo`, Nv. 38 `Haki do Conquistador`, Nv. 44 `Soco Sísmico` (Cut-In), Nv. 50 `Abalo do Céu e da Terra` (Assinatura Cut-In).
    - `San`: Nv. 36 `Carga de Ki`, Nv. 42 `Kamehameha` (Cut-In), Nv. 50 `Genki Dama` (Assinatura Cut-In).
    - `Setero`: Nv. 42 `Atração`, Nv. 50 `Tudo Roxo` (Assinatura Cut-In).
    - `Sarutobi`: Nv. 44 `Explosão Astral`, Nv. 50 `Meteoro Arcano` (pronto para receber suas futuras assinaturas de 5 Elementos).
  - Adicionados `Characters.LearnLevelOf(id, moveId)`, `Characters.UpcomingMoves(id, level)` e salvaguarda em `Characters.DefaultActive(id, level)` garantindo ao menos 1 golpe de dano.
- **2. Migração Automática de Saves + Mensagens de Desbloqueio (`PlayerDataService.luau` & `ProgressionService.luau`):**
  - Adicionada migração `LEARNSET_VERSION = 2` em `PlayerDataService.luau` (`syncMemberLearnset`): recalcula `m.Learned` e `m.Active` conforme o nível atual do personagem em perfis antigos (ex.: Lendários Nv. 10 passam a desbloquear suas ultimates no Nv. 42–50), mantendo golpes ativos válidos e limpando PP obsoleto.
  - `ProgressionService.AddXp` destaca o desbloqueio de ataques especiais/assinaturas ao subir de nível.
- **3. Tela `GOLPES` com Progressão Visual (`src/client/Gui/HudGui/HudClient.client.luau`):**
  - Exibe todos os golpes aprendidos (clicáveis para equipar até 4, com tags de Poder / `+1` prioridade / `SUP` / `PROT` / `HZD` / `CAMPO` / `CURA`) seguidos pelos **próximos golpes bloqueados** com ícone de cadeado (`lock`), nível de desbloqueio (`Nv. 12` .. `Nv. 50`), borda e texto dourados nos especiais/assinaturas e aviso de desbloqueio ao clicar (`"Técnica Assinatura: desbloqueia no Nível 50."`).
- **4. Planilha Excel e Testes (`scripts/update_characters_sheet.py` & `scripts/sync_studio.py`):**
  - Aba `Kit por Personagem` atualizada com os **269 vínculos Nv. 1 → 50** e novas colunas `Nível` (destaque por faixa de nível) e `Prioridade`, sincronizada em `Blender/Planilha_Personagens.xlsx` e `Planilha_Personagens.xlsx`.
  - Adicionado **Test 10 (Learnsets Nv. 1 → 50 e Especiais Lendários)** em `scripts/sync_studio.py`.

**Testado (Play Mode ao vivo + Suíte GDD)**
- Validado ao vivo no Play Mode com migração real de perfil salvo (`LearnsetVersion=2` em `Byakuya`, `San`, `Sarutobi`, `Setero`, `Luffy`), abertura da janela `GOLPES` exibindo golpes aprendidos + bloqueados até `Senbonzakura (Nv. 42)` e `Senbonzakura Kageyoshi (Nv. 50)` com bordas douradas, clique de aviso e `0` erros no Console.
- `python scripts/sync_studio.py status` (`100% in sync` nos 93 scripts) e `python scripts/sync_studio.py test` (`PASS`).
- Place salvo no Roblox Studio na **versão 319** (`TeamCreate`).


## Nova Aba `GOLPES` Estilo Pokémon + Retratos 3D + Acesso pela Aba Info (24/11/2026)

**Feito**
- **1. Acesso pela Tela Info (`src/client/Gui/CharacterDetailGui/CharacterDetailClient.client.luau`):**
  - Adicionado botão **`GOLPES`** (azul com ícone de espada) na base do painel esquerdo de `ATRIBUTOS DO PERSONAGEM`, fechando o modal empilhado e abrindo a tela `GOLPES` já focada no `uid` inspecionado (inclusive para personagens da coleção fora do time ativo).
- **2. Descrições e Metadados de Golpes (`src/shared/Data/Moves.luau`):**
  - Adicionados `Moves.Describe(move)` (descrições claras em português para todos os 93 golpes do jogo — incluindo descrições exclusivas para Assinaturas/Cut-Ins e geração automática para `Protect`, `WideProtect`, `Hazards`, `ClearHazards`, `Barrier`, `Tailwind`, `Drain`, `Recoil`, `BreaksProtect`, `Priority`, `Heal`, `Cleanse`, `MultiStat`, buffs/debuffs e status) e `Moves.TargetDisplay(move)`.
- **3. Retratos 3D Compactos (`src/shared/TeamCards.luau`):**
  - Adicionada opção `CompactPortrait = true` em `TeamCards.new`, renderizando o busto 3D limpo com moldura de raridade, emblema de classe e brilho sem texto redundante sobreposto.
- **4. Aba `GOLPES` Estilo Pokémon (`src/client/Gui/HudGui/HudClient.client.luau`):**
  - **Lista lateral com foto 3D (`TeamCards`)** ao lado de nome, nível, barra de HP e XP (exibindo personagens da coleção no topo quando aberto via Info), com cache de chave (`computeListKey`) para evitar piscar em atualizações de fundo do perfil.
  - **Modo Principal (`4 Golpes Ativos`):** grade 2×2 com os 4 ataques equipados (clique destaca o golpe selecionado) + **Card de Detalhes estilo Pokémon** embaixo exibindo Nome, Classe, Categoria (`DANO`/`STATUS`), Alvo, **Poder**, **Precisão**, **PP**, **Prioridade**, **Crítico** e **Descrição completa**, mais Doces de XP e botão **`TROCAR GOLPES`** no rodapé.
  - **Modo `TROCAR GOLPES`:** lista rolável com todos os golpes aprendidos (marcar/desmarcar até 4) + próximos golpes bloqueados com cadeado e nível (`Nv. 12` → `Nv. 50`, destaque dourado nos especiais dos Lendários); clicar em qualquer golpe (aprendido **ou** bloqueado) já atualiza o Card de Detalhes embaixo na hora. Rodapé com **`VOLTAR`** e **`SALVAR`**.

**Testado (Play Mode ao vivo + Suíte GDD)**
- Validado ao vivo no Play Mode com inspeção visual completa: tela Info (`Byakuya Nv. 10`) com botão `GOLPES` → clique abrindo `GOLPES` com retratos 3D, seleção dos 4 ataques (`Corte Rápido`, `Estocada Veloz`) atualizando o Card de Detalhes → `TROCAR GOLPES` inspecionando `Senbonzakura Kageyoshi (Nv. 50)` bloqueado com descrição completa sem cortes nem sobreposição e `0` erros no Console.
- `python scripts/sync_studio.py status` (`100% in sync` nos 93 scripts) e `python scripts/sync_studio.py test` (`PASS`).
- Place salvo no Roblox Studio na **versão 322** (`TeamCreate`).


## Notificação Global do Servidor ao Conseguir Lendário / Brilhante (24/11/2026)

**Feito**
- **1. Anúncio Global Centralizado no Servidor (`src/server/Data/ProgressionService.luau` + todas as fontes de aquisição):**
  - Criada função central `ProgressionService.AnnounceRareDrop(player, characterId, variant, sourceKey)` e integrada automaticamente em `ProgressionService.AddCharacter(..., announceOpts)` para disparar `Remotes.Announce:FireAllClients(text, meta)` sempre que qualquer jogador obtiver um personagem `Lendario` (ou variante `Brilhante`), ignorando protótipos (`Prototype == true`) e entregas em massa silenciosas (`Silent == true`).
  - Todas as origens conectadas com frase contextualizada:
    - **Invocação (`SummonService.luau`):** `"<jogador> invocou <personagem> na Invocação!"` (removido `announce()` duplicado local).
    - **Refúgio (`RefugeService.luau`):** `"<jogador> capturou <personagem> no Refúgio!"`.
    - **Captura em batalha (`EncounterService.luau`):** `"<jogador> capturou <personagem> em batalha!"`.
    - **Torre Infinita (`TowerService.luau`):** `"<jogador> recrutou <personagem> na Torre Infinita!"`.
    - **Códigos / Recompensas (`RetentionService.luau`):** `"<jogador> conseguiu <personagem>!"` (com proteção anti-flood `Silent = #charList > 6` para códigos dev de elenco completo como `DEVALL`, mantendo anúncio normal em códigos individuais).
- **2. Banner Animado Global + Mensagem no Chat do Sistema (`src/client/Gui/HudGui/HudClient.client.luau` e `SummonClient.client.luau`):**
  - Removido listener duplicado em `SummonClient.client.luau`; todo anúncio passa por `HudClient.client.luau`.
  - **Overlay dedicado (`ServerAnnounceOverlay`, `DisplayOrder = 25`):** flutua limpo acima de todas as telas (Praça, Batalha, Loja, Info, Equipe, Invocação) sem cobrir moedas, menu lateral, configurações ou TeamBar (`X = 0.5, Y = 0.13` na praça / `0.145` em batalha).
  - **Banner visual `Midnight-Blue Anime`:** borda dourada para `LENDÁRIO NO SERVIDOR` (ícone `star`) e ciano para `LENDÁRIO BRILHANTE NO SERVIDOR` / `BRILHANTE NO SERVIDOR` (ícone `sparkle`, zero emojis), brilho animado `UI.shine`, retrato 3D animado com rotação suave (`TeamCards` `CompactPortrait = true`), fila de anúncios (`4.8s` cada), som celebratório (`UI.play("reward")`) e atraso anti-spoiler de `3.8s` apenas para o jogador que está assistindo à própria revelação 3D da Invocação.
  - **Chat do Sistema (`TextChatService.TextChannels.RBXGeneral:DisplaySystemMessage` + fallback `SetCore`):** envia mensagem formatada em RichText (`[LENDÁRIO]`, `[LENDÁRIO BRILHANTE]`, `[BRILHANTE]`) para todos os jogadores do servidor.

**Testado (Play Mode ao vivo + Suíte GDD)**
- Validado ao vivo no Play Mode com inspeção visual e console (`0` erros):
  - Personagem `Comum` (`Kaen`) **não** dispara anúncio.
  - `Byakuya` (`Refuge`), `San` (`Capture`) e `Barba Branca Brilhante` (`Tower`) dispararam fila de banners com retrato 3D nítido girando suavemente, borda dourada/ciano, zero sobreposição com qualquer elemento do HUD e mensagem no chat do sistema.
- `python scripts/sync_studio.py status` (`100% in sync` nos 93 scripts) e `python scripts/sync_studio.py test` (`PASS`).
- Place salvo no Roblox Studio na **versão 325** (`TeamCreate`).


## Animações 3D e VFX Procedurais em 100% dos Golpes do Jogo (93/93) (24/11/2026)

**Feito**
- **1. 26 Novas Animações Procedurais 60 FPS (`src/shared/CombatAnimator.luau` — total 30 animações):**
  - Compatíveis com os 3 tipos de rig do projeto (**Híbrido R6-em-R15 I-Pose**, **R15 Motor6D** e **R15 Skinned Bone**), sem dependência de permissões de `AnimationId`, com katana procedural acoplada e paletas adicionadas para `BarbaBranca` e `Kakashi` (preservando integralmente `CorteBasico`, `CorteCruzado`, `Senbonzakura` e `SenbonzakuraKageyoshi`):
    - **Espadachim (6):** `SwordThrust`, `SwordSpin` (giro 360° em passos SLERP), `SwordHeavyCleave`, `SwordDashSlash`, `SwordStance`, `SwordGroundPlant`.
    - **Lutador (7):** `PunchJab`, `PunchHeavy`, `LowSweepKick` (rasteira 360°), `GroundSlam`, `ShoulderRush`, `FighterFlex`, `MeditateFocus`.
    - **Mago (6):** `MagicCastOrb`, `MagicWaveCast`, `MagicSkyCall`, `MagicHexSeal`, `MagicAuraChannel`, `MagicBarrierCast`.
    - **Atirador (4):** `RangedSnapShot`, `RangedSnipeShot`, `RangedVolley`, `RangedThrowGadget`.
    - **Universal / Tático (3):** `GuardBrace`, `IntimidateGlare`, `WindSweep`.
- **2. Motor Procedural de VFX com 12 Arquétipos + Paleta Individual por Golpe (`src/shared/VfxController.luau`):**
  - Criados 12 arquétipos procedurais leves (sem cilindros verticais finais, reaproveitando texturas e SFX verificados de `ReplicatedStorage/Vfx`, com suporte a múltiplos alvos no 2x2 e auto-limpeza garantida): `GenSlash`, `GenMelee`, `GenGroundWave`, `GenProjectile`, `GenVolley`, `GenSkyStrike`, `GenHex`, `GenBuff`, `GenShield`, `GenHazard`, `GenHeal` e `GenWind`.
  - Tabela `GENERIC_STYLES` personalizando cores, texturas, pitch e mecânicas visuais de todos os **75 golpes** restantes (orbes de drenagem retornando ao atacante em golpes `Drain`, estilhaçamento de escudo ciano em `BreaksProtect`, 3 lâminas orbitantes em `DancaDasEspadas`, raios celestes em `Descarga`, meteoro em `MeteoroArcano`, domo/muralha em `Proteger`/`GuardaAmpla`/`BarreiraArcana`, espinhos/runas/rede no chão inimigo em `Hazards`, etc.).
  - Fallback procedural seguro em `VfxController.PlayMove` caso um modelo legado não possua a track específica (ex.: `ComboMarcial`), além de `VfxController.HasVfx`.
- **3. Cobertura 100% em `Moves.luau` + Suporte Multi-Alvo 2x2 no `BattleClient` (`src/shared/Data/Moves.luau`, `src/client/Gui/BattleGui/BattleClient.client.luau`):**
  - Vinculados `Anim`, `Vfx` e `Timing` (`Charge`, `Release`, `Impact`, `Length`) em todos os **75 golpes** que ainda não tinham animação (todos os 69 genéricos restantes + 6 clássicos + `Esforco`), atingindo **93/93 golpes animados** (18 exclusivos/assinatura preservados + 75 procedurais).
  - `BattleClient` passou a repassar `TargetModels` para `VfxController.PlayMove` para que golpes em área (`AllEnemies`/`AllAllies`) atinjam visualmente todos os alvos no 2x2.
- **4. Planilha Excel e Suíte de Validação (`scripts/update_characters_sheet.py`, `scripts/sync_studio.py`):**
  - Planilha sincronizada em `Blender/Planilha_Personagens.xlsx` e `Planilha_Personagens.xlsx` com todos os 93 golpes atualizados (`0` pendentes).
  - Adicionado **Test 11 (`93/93 Animated Moves`)** em `scripts/sync_studio.py` garantindo que nenhum golpe novo fique sem `Anim`, `Vfx` ou `Timing` registrados.

**Testado (Play Mode ao vivo + Suíte GDD)**
- Auditoria completa no Play Mode ao vivo nos 3 tipos de rig (`Ichigo` I-Pose, `Kaen` R15 Motor6D, `Setero` Skinned Bone, `Uryu` I-Pose):
  - **78/78** testes de animação (26 animações × 3 rigs) com movimentação real de juntas, spawn/limpeza de `BattleKatana` e `0` falhas.
  - **75/75** golpes procedurais executados por completo (`Charge` → `Release` → `Impact` → expiração natural) com **`0` erros no Console** e **`0` vazamentos** (`BattleVfx=0`, `Katana/Attr=0`).
- `python scripts/sync_studio.py status` (`100% in sync` nos 93 scripts) e `python scripts/sync_studio.py test` (`PASS: ... 93/93 Animated Moves + UI Guardrails`).
- Place salvo no Roblox Studio na **versão 326** (`TeamCreate`).


## Rebalanceamento de Economia (Gold/Gemas/Gacha), Curva de XP Nv. 1–50, Blindagem da Coleta e Fim dos Avisos Idle/Walk (24/11/2026)

**Feito**
- **1. Economia de Gold — Base moderada + Combate Ativo valorizado (`Base.luau`, `Tower.luau`, `Gyms.luau`, `Refuge.luau`, `Retention.luau`, `PvPRank.luau`, `AccountLevel.luau`):**
  - **Base (`Base.luau`):** `GoldPerSecond` reduzido moderadamente para `{ Comum = 0.20, Raro = 0.35, Epico = 0.55, Lendario = 0.90 }` (`720 / 1.260 / 1.980 / 3.240 gold/h`), `LevelGoldBonus = 0.025`, `StarGoldBonus = 0.10` — ainda permite roletar com boa frequência sem esmagar o combate ativo.
  - **Torre (`Tower.luau`):** `Fácil = 900`, `Médio = 3.200`, `Difícil = 9.000` (+ `DailyGems = 8`), `Infinito = 650/andar + 3.000 bônus` a cada 5 andares.
  - **Ginásios (`Gyms.luau`):** 1ª vitória `2.500 / 4.500 / 7.500 gold` + `8 / 12 / 15 gemas`; repetição `1.200 / 2.200 / 3.500 gold`.
  - **Refúgio, Retenção, PvP e Nível da Conta:** `Refuge.GoldPerLevel = 25`; `Login` `300..2.500 gold`; `Chests` `300 / 400 / 600 / 1.200 gold` + itens; `Daily` `600 gold + 120 XP` (`AllReward = 10 gemas`); `PvP` `1.500` (2x2) / `1.000` (1x1) / `350` (participação); `AccountLevel.RewardFor` escalado (~2× no Gold, Nv. 1 = `300 gold`, Marcos Épicos `1.000 + lv*75`, Marcos Lendários `2.500 + tier*1.500`).
- **2. Taxas e Pity de Invocação preparados para alta rotação e futura categoria Mítico/Secreto (`Summon.luau`):**
  - **Portal Comum (`300` / `2.700` gold):** `Comum 74,5%`, `Raro 21,5%`, `Épico 3,5%`, `Lendário 0,5%`, `PityAt = 300` (`SorteEmDobro` → `Épico 7%`, `Lendário 1%`).
  - **Portal Premium (`25` / `225` gemas):** `Raro 78%`, `Épico 20%`, `Lendário 2%`, `PityAt = 75`.
  - **Venda de duplicados (`SellPrice`):** `{ Comum = 50, Raro = 150, Epico = 600, Lendario = 4000 }`.
  - **`San` (`DragonBall`) e `Setero` (`JujutsuKaisen`) mantidos bloqueados** (aguardando banners dedicados).
- **3. Economia de Gemas saudável para F2P (`Base.luau`, `Characters.luau`, `Refuge.luau`, `Benefits.luau`):**
  - `OrePerHour` elevado para `{ Comum = 15, Raro = 28, Epico = 45, Lendario = 75 }` (alinhado em `Base.luau` e `Characters.Rarities`).
  - Forja do Refúgio (`Refuge.Upgrades`) reescalada para `25..800 gemas` (total `2.705` vs `6.450` antes).
  - Benefícios em Gemas (`Benefits.List`) ajustados para `MochilaAmpliada = 500`, `GoldEmDobro = 1.600`, `CuraAutomatica = 2.500` (total `4.600` vs `14.500` antes; preços em Robux preservados).
- **4. Curva de XP de Personagens Nv. 1–50 (`Progression.luau`):**
  - Curva em 2 fases: Nv. `1..15` mantém `10 * L` (início ágil); Nv. `16..49` usa `math.floor(10 * L + 1.8 * (L - 15)^2)` (`Nv. 49 -> 50 = 2.570 XP`, total `Nv. 5 -> 50 = 36.769 XP`), dando peso real ao desbloqueio dos golpes finais dos Lendários (Nv. 42–50).
- **5. Blindagem Anti-Exploit da Coleta da Base (`BaseService.luau`, `PlayerDataService.luau`, `AccountLevel.luau`):**
  - Removido o piso artificial de `10 XP` em coletas minúsculas e adicionado cooldown persistente `data.Base.LastCollectXpAt` (`BaseCollectCooldown = 120s`, `BaseCollectMin = 5`, `BaseCollectGoldDivisor = 25`, imune até a reconexão). Coletar recursos e missões de coleta seguem funcionando normalmente, mas spam de cliques rende `0 XP` de conta.
- **6. Fim dos Avisos de Permissão das Animações `Idle` (`82392963584557`) e `Walk` (`113228340758956`):**
  - Substituídos em `Characters.luau` (`DefaultAnimations` e os 19 personagens) e nas **42 instâncias `Animation`** em `ServerStorage`/`Workspace` no Studio pelos IDs autorizados da experiência (`Idle = 95978454415689`, `Walk = 81539047602340`).
  - `BattleClient.client.luau` (`preloadModel`) passa a ignorar `Idle`/`Walk`/`Mine` e animações procedurais do `CombatAnimator`; `CharacterLibrary.luau` (`Play`) evita sobrepor `Idle`/`Walk` em modelos já animados proceduralmente a 60 FPS pelo `BaseClient`.
- **7. Suíte de Validação (`scripts/sync_studio.py`):**
  - Adicionado **Test 12** cobrindo a curva quadrática de XP, taxas/pity de Invocação, prêmios rebalanceados da Torre/Refúgio/Benefícios/Retenção/PvP, `BaseCollectCooldown = 120` e garantia de `0` ocorrências dos IDs `82392963584557` / `113228340758956` em `ServerStorage/Characters`.

**Testado (Play Mode ao vivo + Suíte GDD)**
- `python scripts/sync_studio.py status` (`100% in sync` nos 93 scripts) e `python scripts/sync_studio.py test` (`PASS`).
- Validado ao vivo no Play Mode:
  - Coleta da Base ao vivo (`LiveRate = 3.78/s`, coleta legítima creditando XP e gravando `LastCollectXpAt`; segunda coleta imediata e coletas minúsculas rendendo `0 XP` de conta).
  - Preload e execução de todas as `232` instâncias de `Animation` (`44` IDs únicos nos `25` modelos) e `121` animações no Workspace com **`0` avisos de permissão** no Console.
- Place salvo no Roblox Studio na **versão 327** (`TeamCreate`).


## Sarutobi: Aura 100% Partículas Puras + 4 Ataques Elementais Fluidos (Terra, Fogo, Água e Vento) (25/11/2026)

**Feito**
- **1. Nova Aura 100% Partículas Puras (`ServerStorage.Characters.Sarutobi.AuraVfx`, backup em `_SarutobiOldAuraBackup`):**
  - Removidas todas as imagens/stickers (`SurfaceGui`, `ImageLabel`, estrelas chapadas e orbes sólidos orbitais).
  - Reconstruída em 5 camadas leves e limpas de partículas fluidas: `ChakraFlowFlame` (`fire_main.dds`, fluxo dourado-âmbar orgânico subindo ao redor do corpo), `ChakraBackHalo` (brilho suave de fundo), `HokageGoldenMotes` + `FourElementMotes` (partículas luminosas douradas + 4 elementos Terra/Fogo/Água/Vento), `RisingChakraWisps` (filamentos finos subindo na base sem disco no chão), `AuraLight` e contorno dourado `AnimeOutline3D`.
- **2. 4 Golpes Elementais Exclusivos (`src/shared/Data/Moves.luau`, `Characters.luau`, `Codes.luau`):**
  - `DotonMuralhaTerrestre` (*Doton: Dragão de Terra*, Nv. 34), `KatonDragaoDeFogo` (*Katon: Dragão de Fogo*, Nv. 40), `SuitonDragaoDeAgua` (*Suiton: Dragão de Água*, Nv. 45, `AllEnemies`) e `FutonTempestadeCeleste` (*Futon: Tempestade Celeste*, Nv. 50, `Signature`, `AllEnemies`).
  - Learnset Nv. 1–50 do `Sarutobi` atualizado em `Characters.luau` e códigos dev `SARUTOBI50` / `DEVSARUTOBI50` adicionados em `Codes.luau`.
  - Planilhas `Blender/Planilha_Personagens.xlsx` e `Planilha_Personagens.xlsx` regeneradas via `scripts/update_characters_sheet.py` (`97` golpes únicos, `269` vínculos).
- **3. 4 Animações Ninja Próprias + VFX 100% Fluidos (`CombatAnimator.luau`, `VfxController.luau`, `ReplicatedStorage/Vfx`):**
  - Criadas as animações `SarutobiDoton`, `SarutobiKaton`, `SarutobiSuiton` e `SarutobiFuton`.
  - Reconstruídos os 4 VFX com **zero cones, zero cubos e zero círculos planos engessados**: enxames 3D em hélice (`runHelixSwarm` com `Swarm1..3`), vórtices orbitais 3D ao redor dos alvos (`runVortexOrbiters` com `Orbiter1..3`), rastros `Trail`, múltiplas ondas de partículas, `Hitstop`, `animeImpactFrame`, `springShake`, `fovPunch` e suporte multi-alvo `2x2`.
- **4. Documentação Atualizada (`AGENTS.md`, `Blender/REGRAS.md`, `Blender/PROGRESSO.md`):**
  - Registradas permanentemente as regras de auras 100% partículas puras (zero stickers/imagens/discos no chão) e VFX fluidos (zero cones/cubos/círculos duros).

**Testado (Play Mode ao vivo + Suíte GDD)**
- `python scripts/sync_studio.py status` (`100% in sync` nos 93 scripts) e `python scripts/sync_studio.py test` (`PASS: ... 97/93 Animated Moves + UI Guardrails`).
- Validado ao vivo no Play Mode (aura pura visível e limpa + 4 golpes elementais rodando sem erros no console) e aprovado pelo usuário.
- Place salvo no Roblox Studio na **versão 336** (`TeamCreate`).


## Animações Padrão Completas das 4 Classes + Motor de VFX Genérico 100% Fluido em Partículas (25/11/2026)

**Feito**
- **1. Auditoria Completa de Animações Padrão (Personagens + Classes):**
  - Verificadas todas as 7 animações padrão (`Idle`, `Walk`, `Attack`, `Hit`, `Faint`, `Victory`, `Mine`) nos `25` modelos em `ServerStorage/Characters`: **`0` faltando**.
  - Identificadas as lacunas de animações básicas dedicadas por classe em `CombatAnimator.luau` (notadamente `ComboMarcial` que não tinha animação procedural e caía no fallback `PunchHeavy`, além dos pares básicos Nv. 1 de `Lutador`, `Mago` e `Atirador` que compartilhavam animações genéricas).
- **2. 6 Novas Animações Básicas Dedicadas por Classe (`src/shared/CombatAnimator.luau` — total 40 animações procedurais 60 FPS):**
  - Agora **todas as 4 classes** seguem o mesmo padrão aprovado de `Espadachim` (`CorteBasico` + `CorteCruzado`), com 2 ataques básicos padrão dedicados (compatíveis com I-Pose, R15 Motor6D e R15 Skinned Bone):
    - **Lutador:** `SocoDireto` (guarda marcial → arrancada com giro de quadril e direto seco) e `ComboMarcial` (combo fluido de 3 golpes: Jab Esquerdo → Cruzado Direito → Chute Giratório 360° finalizador).
    - **Mago:** `EsferaArcana` (canalização circular com duas mãos + leve levitação → projeção frontal) e `ChamaMistica` (abertura ampla evocando chamas → varredura dupla frontal).
    - **Atirador:** `DisparoPreciso` (passo lateral ágil → puxada limpa de mira → disparo com snap de ombro) e `TiroPerfurante` (base agachada concentrada → disparo de alta potência com coice).
  - Vinculadas diretamente em `src/shared/Data/Moves.luau` com timings sincronizados e planilhas `Blender/Planilha_Personagens.xlsx` / `Planilha_Personagens.xlsx` regeneradas (`97` ataques únicos, `269` vínculos).
- **3. Refatoração 100% Fluida do `ComboMarcial` + Todos os 12 Arquétipos `PROC_HANDLERS.Gen*` (`src/shared/VfxController.luau`):**
  - Removidos **100%** dos discos planos de decal (`genShockDisc`), blocos retangulares neon e esferas sólidas dos golpes padrão/genéricos (zero cones, zero cubos/blocos rígidos e zero círculos engessados).
  - Criadas primitivas 100% fluidas em partículas (`genFluidRing`, `genFluidSwarm`, `genFluidVortex`) combinando âncoras invisíveis em hélices/vórtices 3D, `Trail`s sedosos, partículas nativas `fire_main.dds`/`smoke_main.dds` e orbes suaves `SoftGlow` (`83184852649242`), aplicadas em `ComboMarcial` (3 impactos sincronizados) e em todos os 12 arquétipos `GenSlash`, `GenMelee`, `GenGroundWave`, `GenProjectile`, `GenVolley`, `GenSkyStrike`, `GenHex`, `GenBuff`, `GenShield`, `GenHazard`, `GenHeal` e `GenWind`.

**Testado (Play Mode ao vivo + Suíte GDD)**
- `python scripts/sync_studio.py status` (`100% in sync` nos 93 scripts) e `python scripts/sync_studio.py test` (`PASS: ... 97/93 Animated Moves + UI Guardrails`).
- Validado ao vivo no Play Mode em todos os 3 tipos de rig (`Luffy` I-Pose, `Setero` Skinned Bone, `Uryu` I-Pose, `Kaen` R15 Motor6D): **`22/22` golpes testados (`6` básicos novos + todos os `12` arquétipos fluidos), `0` falhas, `0` vazamentos (`BattleVfx=0`, `Katana=0`) e `0` erros no Console**.
- Place salvo no Roblox Studio na **versão 337** (`TeamCreate`).


## Sistema de Passivas (20 Passivas), Crafting de Despertar (Nv. 35+) e Gruta Secreta na Floresta (25/11/2026)

**Feito**
- **1. Camada Data (`src/shared/Data/Passives.luau`, `Awakening.luau`, `Characters.luau`, `Progression.luau`, `Net.luau`):**
  - **`Passives.luau` (20 passivas declarativas estilo Pokémon, escaláveis):**
    - **12 Passivas Genéricas** atribuídas por espécie a Comuns, Raros e Épicos base (`OlhoDeAguia`, `Intimidacao`, `Firmeza`, `EspiritoGuerreiro`, `ChamaInterior`, `SedeDeVitoria`, `MenteTatica`, `Regeneracao`, `PassosVelozes`, `GolpeCerteiro`, `EscudoNatural`, `ContraEspinhos`).
    - **5 Passivas Únicas (Lendários):** `PetalasInfinitas` (Byakuya), `TremorDosMares` (Barba Branca), `MestreDosElementos` (Sarutobi), `InstintoZenkai` (San) e `InfinitoAbsoluto` (Setero).
    - **3 Passivas Secretas Únicas (Épicos Iniciais Despertos):** `VontadeDeD` (Luffy), `MantoDaRaposa` (Naruto) e `DespertarHollow` (Ichigo).
  - **`Awakening.luau` (Sistema Híbrido Combinado de Materiais + Receitas Nv. 35+):**
    - 8 Materiais em `data.Materials` (não ocupam os 30 slots da mochila de batalha): `EssenciaLamina`, `EssenciaPunho`, `EssenciaArcana`, `EssenciaPrecisao`, `FragmentoFolha`, `FragmentoMares`, `FragmentoAlmas` e `NucleoDespertar`.
    - Receitas de `Luffy`, `Naruto` e `Ichigo`: **Nv. 35+** + **8 Essências de Classe** (Naruto combina `6 Punho + 2 Arcana`) + **5 Fragmentos do Anime** + **2 Núcleos do Despertar** + **10.000 Gold** → desbloqueia Passiva Secreta Única + selo `DESPERTO` + aura 3D minimalista em partículas + **`+10%` nos atributos finais** (`Progression.MemberMultiplier`).
- **2. Motor de Combate 1x1 e 2x2 (`DamageCalc.luau`, `BattleEngine.luau`, `BattleConfig.luau`, `ArenaManager.luau`):**
  - Todos os gatilhos integrados de forma pura: entrada no turno 1 e em trocas (`Intimidacao`), imunidade a debuffs (`OlhoDeAguia`, `InfinitoAbsoluto`), imunidade a status (`VontadeDeD`, `MantoDaRaposa`), bônus de precisão/crítico/velocidade/classe/HP baixo/HP alto/agir por último (`MenteTatica`), `Firmeza` (sobrevive com 1 HP), `TremorDosMares` (ignora penalidade de spread 2x2), `PetalasInfinitas` (ignora buffs positivos de Defesa), `MestreDosElementos` (dobra chance secundária), limiares de HP (`InstintoZenkai`, `VontadeDeD`), reflexo de contato (`ContraEspinhos`), bônus de nocaute (`SedeDeVitoria`, `DespertarHollow`), redução de hazards/DoT (`EscudoNatural`) e cura de fim de turno (`Regeneracao`, `MantoDaRaposa`).
  - Evento `Kind = "Passive"` enviado ao cliente (espelhado corretamente no PvP) e atributo `Awakened` propagado para modelos 3D em batalha, base e acompanhante.
- **3. Servidor & Drops Integrados (`AwakeningService.luau`, `PlayerDataService.luau`, `ProgressionService.luau`, `PvPService.luau`, `SummonService.luau`, `TowerService.luau`, `RefugeService.luau`, `PartyFollowerService.luau`, `BaseService.luau`, `RetentionService.luau`, `DataMain.server.luau`, `Codes.luau`):**
  - Drops distribuídos por pilar: **Ginásios** garantem Fragmento do Anime (`2×` 1ª vez / `1×` repetições) + Essência; **Torre** e **selvagens do Refúgio (`28%`)** dropam Essências de Classe; **Torre Difícil**, **Chefes do Infinito** e **Forja Nv. 6+ (`12%`)** dropam `NucleoDespertar`.
  - Blindagem em `SummonService.Fuse` e `SellDuplicate`: personagens Despertos têm prioridade absoluta na fusão e nunca podem ser consumidos nem vendidos.
  - Códigos Dev `DESPERTAR` / `DEVDESPERTAR` adicionados em `Codes.luau` para teste rápido.
- **4. Gruta e Máquina Secreta no Mapa (`Workspace.Map.SecretAwakeningAltar` + `StarterGui/AwakeningGui`):**
  - Construída gruta rochosa camuflada por pedras e pinheiros na floresta Norte-Oeste atrás do Lago (`(-125, 8, -132)`, 52 partes, `AwakeningPrompt` tecla `E`, placa discreta visível só de perto com `MaxDistance = 24`, núcleo flutuante animado).
- **5. Interface e Aura Minimalista (`AwakeningClient`, `CharacterDetailClient`, `BattleClient`, `BagClient`, `TeamCards`, `CharacterAuraClient`):**
  - **Info (`CharacterDetailClient`):** novo Card de Passiva exibindo nome/tier/descrição + selo trancado `"Passiva Secreta: ??? — Desbloqueie no Nv. 35 em um altar oculto na floresta..."` em Épicos ainda não despertos.
  - **Batalha (`BattleClient`):** banner rápido estilo Pokémon (`PassiveCallout`) + pop-up colorido sobre o lutador sempre que uma passiva ativa.
  - **Mochila (`BagClient`):** nova aba **`MATERIAIS`** exibindo todos os 8 materiais, quantidades e origem de cada drop.
  - **Altar Secreto (`AwakeningClient`):** UI completa `Midnight-Blue Anime` (zero emojis) com lista de personagens despertáveis, prévia da Passiva Secreta, checklist de Nível/Gold/Materiais e confirmação sonora.
  - **Aura Desperto (`CharacterAuraClient` + `TeamCards`):** aura 100% partículas puras minimalistas (`AwakenedWisps` + `AwakenedSparks`, zero discos no chão/billboards/stickers) no `PartyFollower`, `BaseCharacter` e `BattleCharacter`, com brilho violeta-dourado nos cards.
- **6. Planilha Excel e Testes (`scripts/update_characters_sheet.py`, `scripts/sync_studio.py`):**
  - `Blender/Planilha_Personagens.xlsx` e `Planilha_Personagens.xlsx` regeneradas com 4 novas colunas em `Personagens` (`Passiva Base`, `Tipo Passiva`, `Passiva Secreta (Despertar)`, `Receita de Despertar`), nova aba **`Passivas`** (todas as 20 passivas e receitas) e bloco de resumo dinâmico na aba **`Resumo`**.
  - Adicionado **Test 13** em `scripts/sync_studio.py` testando todas as 20 passivas, gatilhos de combate (`Firmeza`, `Intimidacao` vs `InfinitoAbsoluto`, imunidade `VontadeDeD`, spread `1.0x` do `TremorDosMares`), validação de receitas Nv. 35+, `+10%` de atributos e existência do `SecretAwakeningAltar` + `AwakeningGui`.

**Testado (Play Mode ao vivo + Suíte GDD)**
- `python scripts/sync_studio.py status` (`100% in sync` nos 97 scripts) e `python scripts/sync_studio.py test` (`PASS`).
- Validado ao vivo no Play Mode (com backup e restauração limpa do perfil): abertura remota do `AwakeningGui` pelo servidor, 5 linhas de requisitos, despertar real de `Luffy` (`Vontade de D`, `-10.000 Gold`, `-8/-5/-2` materiais, rejeição de despertar duplicado) e `Ichigo` (`Despertar Hollow`), `PartyFollower` exibindo `AwakenedAuraAttachment` no `UpperTorso` com 2 `ParticleEmitter`s puros (`0` decals/discos) e **`0` erros/avisos no Console**.
- Place salvo no Roblox Studio na **versão 340** (`TeamCreate`).


## Sistema Completo de VFX AAA — "Vazio Roxo" (`HollowPurple` — `Setero` / Gojo Satoru) (25/11/2026)

**Feito**
- **1. Arquitetura Modular Completa de 9 Scripts em `--!strict` (`src/shared/HollowPurple/*`, `HollowPurpleServer`, `HollowPurpleClient`):**
  - `ReplicatedStorage/HollowPurple/Config.luau`: tempos exatos das 5 fases, cores RGB, escalas, velocidade (`140 studs/s`), alcance (`350 studs`), hitbox, tecla `R`, culling e tabela opcional `Config.Assets` (`""` com fallbacks procedurais nativos — zero assets quebrados).
  - `ReplicatedStorage/HollowPurple/Janitor.luau`: gerenciamento de instâncias, conexões, tweens, threads (`task.delay`/`task.spawn`) e callbacks com limpeza reversa garantida.
  - `ReplicatedStorage/HollowPurple/LightningModule.luau`: raios 3D jagged via *midpoint displacement* recursivo com núcleo branco + casca `Neon`, ramificações e fade-out suave.
  - `ReplicatedStorage/HollowPurple/DebrisModule.luau`: amostragem de cor e material reais do piso/terreno via `Raycast`, pedras de sucção (Fase 1), anel levitante de 20 pedras arremessado no disparo (Fases 3–4), *Ground Carving* contínuo com fissuras violetas ardentes de `3s` + fumaça/pedras laterais (Fase 4) e cratera radial gigante (Fase 5).
  - `ReplicatedStorage/HollowPurple/CameraEffects.luau`: shake com `Trauma^2` + Perlin Noise (`math.noise`), recuo direcional em mola amortecida, `FOV Punch` suave, atenuação por distância e restauração segura de `Camera.FieldOfView` multi-sessão.
  - `ReplicatedStorage/HollowPurple/LightingEffects.luau`: Impact Frame mangá P&B/invertido (`0.07s`, `Saturation = -1`, `Contrast = 2.8`, `Bloom = 3.5`) + flash violeta (`0.08s`), mini Impact Frame na detonação e restauração exata do `Lighting` por contagem de sessões.
  - `ReplicatedStorage/HollowPurple/HollowPurpleVFX.luau`: coreografia completa das **5 Fases** (`0.00s–9.00s`: Lapso Azul à esquerda → Reversão Vermelho à direita → Órbita Espiral + Impact Frame + Esfera Vazio Roxo de 5 camadas → Disparo com anéis de Mach, tripla hélice e rasgo no chão → Implosão + Cataclismo Roxo com Pilar Celestial, cratera e brasas), além de poses procedurais estilo Gojo e modo compacto para batalhas por turnos (`PlayBattleUltimate`).
  - `ServerScriptService/HollowPurpleServer.server.luau` & `StarterPlayerScripts/HollowPurpleClient.client.luau`: input `R` (ignorando chat e `BattleGui`), validação de cooldown no servidor, sincronização autoritativa `StartCast` / `LaunchSync` / `HitTarget`, hitbox segura `Spherecast` + `GetPartBoundsInRadius` (zero `.Touched`), knockback `LinearVelocity`, proteção total a seguidores/bases/arenas do RPG e Dummy de teste automático no Studio (`Workspace.HollowPurpleDummy`).
- **2. Integração Direta com `Setero` (`TudoRoxo` / *Vazio Roxo*) + Planilhas e Testes:**
  - Ultimate Nv. 50 `TudoRoxo` (*Vazio Roxo*) do `Setero` atualizada em `Moves.luau`, `CombatAnimator.luau` (`TudoRoxo`) e `VfxController.luau` (`HANDLERS.TudoRoxo` delegando para `HollowPurpleVFX.PlayBattleUltimate`), mais códigos dev `SETERO50` / `GOJO50` / `DEVSETERO50` em `Codes.luau`.
  - Planilhas `Blender/Planilha_Personagens.xlsx` e `Planilha_Personagens.xlsx` regeneradas e **Test 14** adicionado em `scripts/sync_studio.py`.

**Testado (Play Mode ao vivo + Stress Test 50x + Suíte GDD)**
- `python scripts/sync_studio.py status` (`100% in sync` nos **106 scripts**) e `python scripts/sync_studio.py test` (`PASS`).
- Validado ao vivo no Play Mode:
  - Fluxo completo em tempo real (`CastRequest` → 5 Fases): pico de `500` instâncias procedurais na singularidade, dano real + knockback de `45.4 studs` no `HollowPurpleDummy` e limpeza final **`0` instâncias em `workspace.HollowPurpleVFX`**.
  - Ultimate `TudoRoxo` do `Setero` executada com sucesso (`ok = true`, `0` sobras).
  - **Stress test de 50 disparos consecutivos/sobrepostos:** `Children = 0`, `Desc = 0`, `Lighting` 100% limpo (`CC=false`, `Bloom=false`, `Blur=false`), `FinalFOV = 70.00` e **`0` erros/avisos no Console**.
- Place salvo no Roblox Studio na **versão 343** (`TeamCreate`).


## Nova Raridade `Secreto` (Preto, `0,001%` a partir do Nv. 15) + Sukuna Completo (Modelo 3D, Aura Pura, 4 Golpes, Passiva e Códigos Dev) (25/11/2026)

**Feito**
- **1. Modelo 3D & Rig R6-on-R15 + Aura Minimalista 100% Partículas (`Blender/Sukuna/`, `ServerStorage/Characters/Sukuna`):**
  - Processado `sukuna.fbx` + textura (`d:\Downloads\sukuna.zip`) via `scripts/auto_rig_tripo.py --char Sukuna --max-tris 7500` → `Blender/Sukuna/modelo/Sukuna_R6_Auto.{blend,fbx}` e texturas `Sukuna_Tex{,_Brilhante}.png`, validado visualmente nas 5 prévias (cortes limpos, sem ocos, sem fragmentos).
  - Enviado via Open Cloud (**Asset ID `124539709567438`**), importado em `ServerStorage.Imported.Sukuna_R6_Import` e montado em `ServerStorage.Characters.Sukuna` (`Tex=6/6`, animações autorizadas do Place).
  - Criada aura `AuraVfx` (tag `CharacterAura`) minimalista em **100% partículas puras** (névoa obsidiana-carmesim + brilhos de maldição ascendentes + `AuraLight` + `AnimeOutline3D` obsidiana/carmesim; zero discos/círculos no chão, zero decals/SurfaceGui/BillboardGui/orbes sólidos).
- **2. Nova Raridade `Secreto` (Cor Preta `#101016`, Global `0,001%` no Nv. 15+, BST Superior aos Lendários):**
  - `UITheme.luau`, `TeamCards.luau`, `CharacterFilter.luau`, `SummonStageThemes.luau`, `BagClient`, `CharacterDetailClient`, `RefugeClient`, `TeamBarClient`: cor preta (`Color3.fromRGB(16, 16, 22)`), borda obsidiana/prata, filtros e ordenação `Secreto` (tier 5, acima de Lendário).
  - `Characters.luau`, `Base.luau`, `Genetics.luau`, `Training.luau`: `Characters.Rarities.Secreto` (`StatMultiplier = 1.50` vs `1.35` dos Lendários, `OrePerHour = 110`, `GoldPerSecond = 1.40` / `5040/h`, Genética curva média `~77%` / 100% perfeito `0,100%`, Treino `4,50×` custo / `1,90×` tempo).
  - `Summon.luau`, `SummonService.luau`, `SummonClient.client.luau`: chance independente de **`0,001%` (`0.00001`)** em **qualquer banner** (Portal Comum e Portal Premium, ignorando `animeFilter` e Ginásios) desde que `Account.Level >= 15` (`0` abaixo do Nv. 15, preservando integralmente as taxas normais e a garantia de Lendário). Painel `RatesRail` exibe `SECRETO 0.001%` (ou `Nv.15+` abaixo do nível 15), com animação de revelação preta/carmesim.
  - `ProgressionService.luau` & `HudClient.client.luau`: anúncio global no servidor (`SECRETO NO SERVIDOR` / `[SECRETO]`) sempre que um jogador obtém um Secreto.
- **3. Personagem `Sukuna` (`JujutsuKaisen`, `Mago`, `Secreto`), Passiva Única, 4 Golpes Exclusivos e Códigos Dev:**
  - Atributos base **`78 HP / 31 ATQ / 26 DEF / 27 VEL`** (**BST `162`**, acima de todos os Lendários `134–144`) + multiplicador `1,50×` da raridade `Secreto`.
  - Passiva única **`ReiDasMaldicoes`** (`Passives.luau`, 21ª passiva): `+18%` dano em golpes de `Mago`, `+10%` chance de crítico e ignora bônus positivos de Defesa do alvo.
  - 4 golpes exclusivos em `Moves.luau` + 4 animações 60 FPS em `CombatAnimator.luau` + 4 VFX 100% fluidos em partículas puras em `VfxController.luau`:
    - `Fortificacao` (*Fortificação*, Nv. 34): `+1` Ataque e `+1` Defesa (`MultiStat`).
    - `Desmantelar` (*Desmantelar*, Nv. 40): Poder `58`, Crítico `18%`, rajada de cortes invisíveis com Cut-In.
    - `Clivar` (*Clivar*, Nv. 45): Poder `68`, `BreaksProtect = true`, `45%` de `-1` Defesa, corte adaptativo com Cut-In.
    - `SantuarioMalevolente` (*Santuário Malevolente*, Nv. 50, `Signature`, `Target = "AllEnemies"`, `BreaksProtect = true`): Poder `82`, expansão de domínio com selo Enmaten, chuva de cortes em área 1x1/2x2 e Cut-In.
  - Códigos Dev em `src/server_storage/Codes.luau`: **`SUKUNA` / `DEVSUKUNA`** (Nv. 10) e **`SUKUNA50` / `SUKUNAMAX` / `DEVSUKUNA50`** (Nv. 50 — nível máximo com os 4 golpes já equipados), além da inclusão no `DEVALL`.
- **4. Planilhas Excel & Suíte de Validação (`scripts/update_characters_sheet.py`, `scripts/sync_studio.py`):**
  - `Blender/Planilha_Personagens.xlsx` e `Planilha_Personagens.xlsx` regeneradas com estilo preto para `Secreto` (**24 personagens ativos + 2 protótipos | 101 ataques únicos | 21 passivas | 282 vínculos**).
  - Adicionado **Test 15 (`Secreto/Sukuna`)** em `scripts/sync_studio.py` validando BST > todos os Lendários, trava Nv. 15+, taxa `0,001%` no Comum e Premium, cor preta, os 4 golpes, aura 100% partículas, códigos Dev e execução no `BattleEngine` (`Fortificacao` + `Clivar` quebrando `Proteger`).

**Testado (Play Mode ao vivo + Suíte GDD)**
- `python scripts/sync_studio.py status` (`100% in sync` nos **106 scripts**) e `python scripts/sync_studio.py test` (`PASS: ... 21 Passives + Awakening + HollowPurple + Secreto/Sukuna + 101 Animated Moves + UI Guardrails`).
- Validado ao vivo no Play Mode:
  - `CharacterPreviews` (`26`, Sukuna `HeadMesh=true`, `NoAura=true`) e `SummonShowcaseModels` (`24`, Sukuna `Aura=true`, `Outline=true`).
  - Inspeção visual em tempo real do modelo `Sukuna` + aura obsidiana-carmesim pulsando (`AuraLight`), todos os 4 golpes disparados ao vivo (`Fortificacao=true, Desmantelar=true, Clivar=true, SantuarioMalevolente=true`, `BattleVfxLeftover=0`), linha `Rate_Secreto` alinhada sem sobreposição na `SummonGui` e **`0` erros/avisos no Console**.
- Place salvo no Roblox Studio na **versão 345** (`TeamCreate`).


## Novo Banner Jujutsu Kaisen (6 Personagens + Substituição do Gojo) & Passagem Secreta nos Montes para o Santuário de Evolução (25/11/2026)

**Feito**
- **1. Elenco Completo Jujutsu Kaisen — 6 Modelos Tripo Auto-Rigged & Validados Visualmente (`Blender/{Nobara,Itadori,Fushiguro,Todo,Nanami,Gojo}/`):**
  - Processados todos os 6 `.zip` do Tripo (`nobara`, `itadori`, `fushiguro`, `todo`, `nanami`, `gojo`) via `scripts/auto_rig_tripo.py --max-tris 7500` e inspecionados nas 5 prévias (cortes limpos, sem fragmentos e sem partes ocas).
  - Enviados via Open Cloud e montados em `ServerStorage.Characters` (`Tex=6/6`, animações autorizadas R6-on-R15):
    - **Comum:** `Nobara` (`Atirador`, Asset `115047396782159`, `GolpeCerteiro`) e `Itadori` (`Lutador`, Asset `109882137693693`, `EspiritoGuerreiro`).
    - **Raro:** `Fushiguro` (`Mago`, Asset `71327504850621`, `MenteTatica`) e `Todo` (`Lutador`, Asset `108331811669347`, `ContraEspinhos`).
    - **Épico:** `Nanami` (`Espadachim`, Asset `111479277003006`, `GolpeCerteiro`).
    - **Lendário (Substituição):** **`Gojo`** (ID `Setero`, `Name = "Gojo"`, Asset **`84694141738157`**) — modelo anterior substituído integralmente pelo novo modelo Tripo R6-on-R15 + nova **Aura Limitless / Seis Olhos** (`AuraVfx`, tag `CharacterAura`) **100% partículas puras** azul-ciano e violeta (zero `SurfaceGui`/`BillboardGui`/`Decal`/orbes sólidos).
  - Adicionada animação procedural 60 FPS `CombatAnimator.ANIMATIONS.Atracao` e corrigido bug latente em `VfxController.HANDLERS.Atracao.Impact` (chamada órfã `setBackBisentoHidden` removida), garantindo `Atracao` e `TudoRoxo` (`HollowPurpleVFX`) 100% fluidos e sem erros no novo modelo do Gojo.
- **2. Novo Banner `JujutsuKaisen`, 4º Ginásio de Anime (`Ginásio Jujutsu de Tóquio`) e Artes Customizadas:**
  - Geradas e aprovadas no Open Cloud as artes customizadas [`Blender/UI/banners/banner_jujutsu.png`](./UI/banners/banner_jujutsu.png) (**Image ID `140680943806077`**) e [`Blender/UI/icones/insignia_jujutsu.png`](./UI/icones/insignia_jujutsu.png) (**Image ID `82094936324685`**), registradas em `src/shared/UI.luau`.
  - Registrado `JujutsuKaisen` em `Summon.BannerOrder`/`Summon.Banners`, `SummonStageThemes.luau` (Palco 3D destacando **Gojo** no centro + **Nanami** e **Fushiguro** nas laterais), **4º Ginásio** (`Gyms.luau`, Tier 4, Nv. 24–28, `Insígnia Amaldiçoada`, `Genetics.GymPresets[4] = 70/85`), `TowerClient.client.luau` (porta-insígnias dinâmico para 4 insígnias) e códigos Dev em `Codes.luau` (`NOBARA`, `ITADORI`, `FUSHIGURO`, `TODO`, `NANAMI`, `GOJO`/`DEVGOJO`/`GOJO50`/`DEVGOJO50`, lote `JUJUTSU`/`DEVJUJUTSU` e `DEVALL`).
- **3. Relocação do Santuário Secreto de Evolução (`SecretAwakeningAltar`) para Passagem Secreta nos Montes (Zero Invasão de Base):**
  - Removido completamente o antigo `SecretAwakeningAltar` que invadia `Plot01` (`(-125, -132)`).
  - Esculpida passagem secreta real dentro das **montanhas do canto Noroeste** (`X = -172, Z = -148..-196`, atrás do `Pavilhao (-164, -122)` — **`78,8` studs distante** da base mais próxima, **`PlotOverlaps = 0`**):
    - `Map.Bounds.ParedeN` dividida exatamente na fenda oculta (`X = -176.5..-167.5`) + paredes invisíveis protetoras ao redor da caverna (impossível escapar para fora do mapa).
    - Entrada camuflada entre rochas musgosas, cortina de folhagem atravessável (`CanCollide = false`) e fragmento rúnico sutil (`EntranceRuneShard`).
    - Túnel de pedra serpenteante (`Z = -150 -> -174`) com piso contínuo de ardósia (`Y = 8.0`), arcos de pedra e cristais luminosos levando à **Caverna Secreta do Santuário de Evolução** (`(-172, 8.3, -186)`, teto rochoso natural de `40..72` studs acima) com o `SecretAwakeningAltar` e `AwakeningPrompt` intactos.
  - Dica atualizada em `Awakening.luau` (`"Desbloqueie no Nv. 35 em uma passagem secreta nos montes..."`).
- **4. Planilhas Excel & Suíte de Testes (`scripts/update_characters_sheet.py`, `scripts/sync_studio.py`):**
  - `Blender/Planilha_Personagens.xlsx` e `Planilha_Personagens.xlsx` regeneradas (**29 personagens ativos + 2 protótipos | 101 ataques únicos | 21 passivas | 337 vínculos**).
  - Adicionado **Test 16** em `scripts/sync_studio.py` validando Banner/Ginásio Jujutsu, os 6 modelos R6-on-R15, aura pura do Gojo, códigos Dev e **zero sobreposição** do `SecretAwakeningAltar` com todas as 10 bases (`Plot01..Plot10`).

**Testado (Play Mode ao vivo + Suíte GDD)**
- `python scripts/sync_studio.py status` (`100% in sync` nos **106 scripts**) e `python scripts/sync_studio.py test` (`PASS`).
- Validado ao vivo no Play Mode:
  - `CharacterPreviews` (`31`) e `SummonShowcaseModels` (`29`) gerados para todos os 6 de Jujutsu (`Head_Mesh=true`, `Setero` com `AuraVfx=true` pulsando `1.056 -> 0.864`).
  - Golpes do novo Gojo testados ao vivo (`Atracao=true`, `TudoRoxo=true`, `BattleVfxLeft=0`, `HollowPurpleLeft=0`) com **`0` erros de jogo/VFX no Console**.
  - `SummonGui.BannerTab_JujutsuKaisen=true`, `JujutsuStageFeatured=Nanami, Gojo, Fushiguro`, `TowerGui.Gym_JujutsuKaisen=true`.
  - Avatar do jogador caminhou ao vivo de fora (`Z=-141`) atravessando toda a passagem secreta até o altar na caverna (`FinalDistToAltarPedestal=8.3 <= 12`, zero bloqueios/travamentos).
- Place salvo no Roblox Studio na **versão 349** (`TeamCreate`).


## Sistema Completo de Regras, Domínio, `Fuga`, VFX/Câmera/SFX AAA do `Sukuna` & Correção de Corte de VFX nas Arenas (25/11/2026)

**Feito**
- **1. Auditoria e Regras Autoritativas de Gameplay do `Sukuna` (`Characters.luau`, `Moves.luau`, `BattleEngine.luau`, `AIController.luau`, `ProgressionService.luau`, `BattleService.luau`, `BattleClient.client.luau`):**
  - Moveset padrão Nv. 50 ordenado exatamente em **`1. Desmantelar`, `2. Clivar`, `3. Fortificação`, `4. Santuário Malevolente`** (`DefaultOrder`).
  - `SantuarioMalevolente` configurado com **`PP = 1`** e **`OncePerBattle = true`**, bloqueando recarga por itens `RestorePP` (`Éter`) durante toda a partida e iniciando sempre em `1/1 PP` a cada nova batalha.
  - Estado autoritativo de Domínio (`SideEffects.MalevolentShrine = 2` + chip `SANTUÁRIO Xt` na HUD): permanece ativo por **exatamente 2 rodadas completas** após a invocação (ou encerra antes se o Sukuna desmaiar/sair de campo sem outro Sukuna ativo).
  - Sangramento/cortes automáticos (`_ApplyDomainSlash`): causa **15% do HP Máximo** nos oponentes ativos imediatamente na invocação e ao final de cada uma das **2 rodadas ativas** (`DomainStart`, `DomainSlash`, `DomainEnd`).
  - Troca exclusiva de moveset no Domínio (`_SetSukunaDomainMoves`): enquanto o Santuário estiver ativo, os 4 golpes padrão ficam bloqueados/ocultos e o Sukuna passa a ter **apenas `Fuga`** (`Power = 98`, `Target = "AllEnemies"`, `BreaksProtect = true`, centralizado na HUD). Ao fim das 2 rodadas, os 4 golpes padrão retornam com `Santuário Malevolente` travado em `0/1 PP`.
- **2. Camada Audiovisual Modular AAA (`src/shared/Sukuna/*.luau` → `ReplicatedStorage/Sukuna/*`, `--!strict`, Zero Cones/Esferas/Cilindros):**
  - `Config.luau`: tabela `Config.Assets` organizada para vozes (*Ryōiki Tenkai*, *Fukuma Mizushi*, *Fuga*), `AnimationId`s e flipbooks/texturas, com fallbacks nativos imediatos e paletas térmicas reais.
  - `Janitor.luau`: limpeza determinística de instâncias, conexões, tweens, threads e restauração integral de `Camera`, `Lighting`, `Sky` e `Atmosphere`.
  - `CinematicCamera.luau`: close-ups (`FOV 48`), 3 cortes secos de anime no *Clivar*, contra-plongée orbital na *Fortificação*, *crane shot* épico no *Santuário*, plano *over-the-shoulder* de arqueiro (`FOV 70 -> 46`) + *tracking shot* supersônico + plano aberto termobárico no *Fuga* e *Perlin Trauma Shake*.
  - `SoundManager.luau`: abafamento low-pass (`EqualizerSoundEffect`), SFX multicamadas e vozes sincronizadas com legendas cinematográficas estilizadas (**"Ryōiki Tenkai..."**, **"Fukuma Mizushi"**, **"Fuga"**).
  - `AnimatorModule.luau` (+ ponte em `CombatAnimator.luau`): suporte a `AnimationId` customizado com fallback procedural 60 FPS em `Motor6D` nos 5 golpes (incluindo avanço físico com *afterimage* escura no *Clivar*, selo *Enmaten* no *Santuário* e postura de arqueiro com recuo no *Fuga*).
  - `MalevolentShrineEnv.luau` & `SukunaVFX.luau` (+ ponte em `VfxController.luau`): céu vermelho-sangue, piso escuro reflexivo opaco com névoa, arquitetura 3D monumental do **Santuário Malevolente** (telhados curvos de pagode, pilares carmesim, mandíbulas/presas, crânios e chifres), cortes 3D no espaço e arco/flecha + pilar termobárico volumétrico do **Fuga** 100% em `ParticleEmitter`s, `Beam`s e `Trail`s.
- **3. Investigação e Correção Definitiva do Corte Horizontal de VFX nas Arenas (`Workspace.Arenas.Arena01..Arena10`, `_ConstrutorArenasSukuna.luau`, `ArenaManager.luau`):**
  - Diagnosticada e corrigida a falha de Z-sorting do motor do Roblox onde `AbyssVignetteDecal` em `InfiniteAbyssVignette` (`Transparency = 1`, `358.8 x 358.8`) e `LiquidReflectionDecal` em `WaterSurfaceReflection` (`Transparency = 1`) ordenavam na frente das partículas do lado inimigo, cortando auras e efeitos na linha do horizonte.
  - Aplicada a vinheta (`ZIndex = 2`) diretamente sobre o piso opaco `InfiniteMirrorWater` (`Transparency = 0`, G-buffer) nas 10 arenas existentes, no construtor `_ConstrutorArenasSukuna.luau` e na proteção automática `sanitizeArenaFloorDecals` em `ArenaManager.luau`.
- **4. Códigos Dev Nv. 50 Adicionais, Planilhas Excel e `Test 17`:**
  - Adicionados códigos `BYAKUYA50` / `DEVBYAKUYA50`, `SAN50` / `GOKU50` / `DEVSAN50` e `BARBABRANCA50` / `DEVBARBABRANCA50` em `src/server_storage/Codes.luau`.
  - `Blender/Planilha_Personagens.xlsx` e `Planilha_Personagens.xlsx` atualizadas (**29 personagens ativos + 2 protótipos | 102 ataques únicos | 21 passivas | 337 vínculos**).
  - Adicionado **Test 17** em `scripts/sync_studio.py` validando todas as 6 regras do Sukuna, `Fuga` e os 7 módulos AAA sem primitivos proibidos.

**Testado (Play Mode ao vivo + Captura Visual Antes/Depois + Suíte GDD)**
- `python scripts/sync_studio.py status` (`100% in sync` nos **113 scripts**) e `python scripts/sync_studio.py test` (`PASS: ... Domain/Fuga + JujutsuBanner + 102 Animated Moves + UI Guardrails`).
- Verificado visualmente por captura de câmera nas arenas que o corte horizontal nas partículas desapareceu 100%, e validado em Play Mode pelo usuário (`0` erros de script no Console).


## Rework Completo Nível AAA — Ataque `Fuga` (Chama Divina / Flecha de Fogo do Sukuna) (26/11/2026)

**Feito**
- **1. Módulo Dedicado `src/shared/Sukuna/FugaVFX.luau` (`--!strict`, Zero Cones/Esferas/Cilindros de Neon):**
  - Empilhamento térmico real em **4 camadas** (`createThermalStack`) em todas as fontes de fogo: Camada 1 Núcleo Incandescente (`ZOffset = 2`, `LightEmission = 1`, `RGB 255,255,235 -> 255,220,90`), Camada 2 Corpo da Chama (`ZOffset = 1`, `LightEmission = 0.75`, `RGB 255,115,10 -> 210,25,5`), Camada 3 Fumaça Piroclástica Densa (`ZOffset = -1`, `LightEmission = 0`, `RGB 28,22,22 -> 10,8,10`) e Camada 4 Brasas Esticadas (`VelocityParallel`, `Squash` alto, `Drag`).
  - `PointLight` com flicker procedural em tempo real via `math.noise(t * 14, seed, 0)` variando brilho e alcance.
  - Coreografia completa em **6 fases (`0.00s` a `8.80s`)** em `RunService.RenderStepped` (`dt`): abertura da fornalha entre as palmas -> postura de arqueiro `~75°` com Arco Flamejante curvo, Corda de Plasma em `"V"`, Flecha Divina de 3 `Beam`s entrelaçados e Vórtice de Sucção Térmica de `20 studs` -> disparo supersônico com 4 `Trail`s, anéis sônicos a cada `0.035s` e rastro queimado via `Raycast` -> Hitstop `0.12s` + implosão de vácuo + Duplo Impact Frame (`Contrast = 3.2` P&B -> `RGB 255,110,40`) -> Pilar Colossal de Fogo Termobárico (`~165 studs`, 7 nós verticais, 4 `Beam`s turbulentos, cogumelo piroclástico, 4 orbiters espirais, ondas 360° e destroços copiando material do piso) -> extinção gradual e chuva de cinzas/brasas por `2.5s` com limpeza total via `Janitor`.
- **2. Animação, Câmera, Áudio/Legenda, Servidor e `Config.Assets.Fuga`:**
  - `Config.luau`: adicionados `Config.Assets.Fuga` (slots limpos `""` para `VoiceId`, `AnimationId`, flipbooks e SFX) e `Config.FugaTimeline`.
  - `AnimatorModule.luau` & `CombatAnimator.luau`: animação de 6 fases em `Motor6D` com micro-tremor muscular procedural (`2.70s..3.30s`), pausa no ápice (`0.10s`), recuo explosivo e vibração residual do arco no braço esquerdo.
  - `CinematicCamera.luau`: driver atualizado para `RenderStepped` (`dt`) com os 6 planos do `Fuga` (*Dutch Angle*, *Over-The-Shoulder* `FOV 62 -> 40`, coice `FOV 40 -> 90` e *Wide Low-Angle Crane Shot* olhando o pilar de `165 studs`).
  - `SoundManager.luau`: legenda `「 竈  ·  FUGA 」` com tremor térmico, Doppler no voo, silêncio súbito na implosão e detonação termobárica em 4 camadas.
  - `Moves.luau`, `BattleService.luau`, `VfxController.luau` e planilhas `Planilha_Personagens.xlsx` sincronizados (`Impact = 4.05`, `Length = 8.80`, `PostImpactHold = 3.10`), preservando 100% das regras de combate do Sukuna.

**Testado**
- `python scripts/sync_studio.py status` (`100% in sync` nos **114 scripts**) e `python scripts/sync_studio.py test` (`PASS`, incluindo smoke test de `FugaVFX` no `Test 17`).
- Ciclo completo de `8.80s` executado nas 6 fases sobre o modelo real de `Sukuna` (`Done_AutoCleanup=0`, zero erros e restauração integral de `Lighting`).


## Remoção do Dummy de Teste do `Vazio Roxo` na Praça e `Workspace.Setero` Legado (26/11/2026)

**Feito**
- Desativado `Config.SpawnStudioTestDummy = false` em `src/shared/HollowPurple/Config.luau` e removido o bloco automático de criação do `HollowPurpleDummy` (`"Alvo Vazio Roxo [R]"`, `CFrame.new(0, 11.5, 42)` em frente à Torre) em `src/server/HollowPurpleServer.server.luau`.
- Removida a sobra legada `Workspace.Setero` (modelo antigo skinned 1 peça em `(120.5, 14.2, -279.2)` sem referências em scripts), preservando integralmente o modelo ativo em `ServerStorage/Characters/Setero`.

**Testado (Play Mode ao vivo + Suíte GDD)**
- `python scripts/sync_studio.py status` (`100% in sync` nos **114 scripts**) e `python scripts/sync_studio.py test` (`PASS`).
- Validado ao vivo no Play Mode: `HollowPurpleDummyExists = false`, `WorkspaceSeteroExists = false`, `PreviewSeteroOk = true`, `ShowcaseSeteroOk = true`, `HollowPurpleRemoteOk = true` e **`0` erros/avisos no Console**.
- Place salvo no Roblox Studio na **versão 359** (`TeamCreate`).


## Novo Banner Dragon Ball (5 Novos Personagens + San Lendário + 5º Ginásio Guerreiros Z) (26/11/2026)

**Feito**
- **1. Elenco Completo Dragon Ball — 5 Novos Modelos Tripo Auto-Rigged + `San` Lendário (`Blender/{Piccolo,Kuririn,Vegeta,Gohan,Freeza}/`):**
  - Processados os 5 `.zip` do Tripo (`piccolo`, `kuririn`, `vegeta`, `gohan`, `freeza`) via `scripts/auto_rig_tripo.py --max-tris 7500` e inspecionados visualmente nas 5 prévias (cortes limpos, sem fragmentos e sem ocos).
  - **Correção cirúrgica da cauda do `Freeza` (`Freeza_R6_Auto_v2.{blend,fbx}`):** na inspeção da prévia explodida, a cauda enrolada atrás das pernas estava dividida entre `LeftLeg` e `RightLeg`; os componentes desconexos da cauda (`560 + 380` faces) foram movidos integralmente para `Torso`, deixando as pernas 100% livres para andar/chutar enquanto a cauda permanece unificada no torso (e centralização horizontal feita via `Head + LeftLeg + RightLeg`).
  - Enviados via Open Cloud e montados em `ServerStorage.Characters` (`Tex=6/6`, animações autorizadas R6-on-R15):
    - **Comum:** `Piccolo` (`Mago`, Asset `88105734468434`, `Regeneracao`) e `Kuririn` (`Atirador`, Asset `107828832775927`, `OlhoDeAguia`).
    - **Raro:** `Vegeta` (`Lutador`, Asset `129049896512415`, `SedeDeVitoria`) e `Gohan` (`Lutador`, Asset `121108312568844`, `ChamaInterior`).
    - **Épico:** `Freeza` (`Mago`, Asset `102335809689960` v2, `Intimidacao`).
    - **Lendário (já implementado):** `San` (`Lutador`, `InstintoZenkai`, aura Ki dourado/ciano e 4 golpes exclusivos completos).
- **2. Novo Banner `DragonBall`, 5º Ginásio de Anime (`Ginásio dos Guerreiros Z`), Artes Customizadas e Códigos Dev:**
  - Geradas e aprovadas no Open Cloud as artes customizadas [`Blender/UI/banners/banner_dragonball.png`](./UI/banners/banner_dragonball.png) (**Image ID `86187786633555`**) e [`Blender/UI/icones/insignia_dragonball.png`](./UI/icones/insignia_dragonball.png) (**Image ID `118201028417794`**), registradas em `src/shared/UI.luau`.
  - Registrado `DragonBall` em `Summon.BannerOrder`/`Summon.Banners`, `SummonStageThemes.luau` (`PREFERRED_ORDER` destacando **San** no centro + **Freeza** e **Vegeta** nas laterais sobre o preset `Planalto do Ki Dourado`), **5º Ginásio** (`Gyms.luau`, Tier 5, Nv. 28–32, `Insígnia Guerreiros Z`, `Genetics.GymPresets[5] = 72/95`), `TowerClient.client.luau` (porta-insígnias ajustado para 5 insígnias) e códigos Dev em `Codes.luau` (`PICCOLO`, `KURIRIN`, `VEGETA`, `GOHAN`, `FREEZA`, `SAN`/`GOKU`/`SAN50`/`GOKU50`, lote **`DRAGONBALL`** / **`DEVDRAGONBALL`** / **`DBZ`** e `DEVALL`).
- **3. Planilhas Excel & Suíte de Testes (`scripts/update_characters_sheet.py`, `scripts/sync_studio.py`):**
  - `Blender/Planilha_Personagens.xlsx` e `Planilha_Personagens.xlsx` regeneradas (**34 personagens ativos + 2 protótipos | 102 ataques únicos | 21 passivas | 392 vínculos**).
  - Atualizado `Test 6` (`#Gyms.Order == 5`) e adicionado **Test 18 (`DragonBallBanner`)** em `scripts/sync_studio.py` validando Banner, Ginásio Tier 5, os 6 modelos R6-on-R15 e os códigos Dev.

**Testado (Play Mode ao vivo + Suíte GDD)**
- `python scripts/sync_studio.py status` (`100% in sync` nos **114 scripts**) e `python scripts/sync_studio.py test` (`PASS`).
- Validado ao vivo no Play Mode:
  - `CharacterPreviews` (`36`) e `SummonShowcaseModels` (`34`) gerados para todos os 6 de Dragon Ball (`Head_Mesh=true`, `San` com `AuraVfx=true`).
  - `SummonGui.BannerTab_DragonBall=true`, `DragonBallStageFeatured=Freeza, San, Vegeta`, `TowerGui.Gym_DragonBall=true`, `BadgesRowCount=5`.
  - Golpes de classe executados ao vivo nos 5 novos modelos (`Piccolo:EsferaArcana`, `Kuririn:DisparoPreciso`, `Vegeta:ComboMarcial`, `Gohan:SocoDireto`, `Freeza:ChamaMistica`, `BattleVfxLeft=0`) com **`0` erros de jogo/VFX no Console**.
- Place salvo no Roblox Studio na **versão 362** (`TeamCreate`).

### Revisão do Modelo 3D do `Freeza` (`v3` — Ombreiras Horizontais + Cauda Completa no `Torso`, 26/11/2026)
- Recortado diretamente da malha T-Pose original (`freeza.fbx`) com planos diagonais na costura branca das ombreiras (`Z = 0,650 + 0,54·(|X| − 0,150)`), preservando **ambas as ombreiras horizontais da armadura Saiyajin** e a **cauda inteira contínua** unificadas no `Torso`, além do corte refinado do pescoço (`Z = 0,718` no colarinho) mantendo queixo e boca 100% em `Head`.
- Braços (`LeftArm`, `RightArm`) 100% livres das ombreiras, rotacionados verticalmente encaixados sob as ombreiras com tampas sólidas e faces duplas (`Freeza_R6_Auto_v3.{blend,fbx}`).
- Enviado via Open Cloud (**Asset ID `111673771796864`**, `Approved`), montado em `ServerStorage/Characters/Freeza` (`Tex=6/6`, `TorsoSz=(4.47, 4.06, 2.12)`, `ArmWidth=(0.69, 0.69)`, `FootY=-3.188`), planilhas regeneradas, `sync_studio.py status/test` `PASS` e Place salvo na **versão 363**.


## Evento Global de Raid Cooperativa 4×1 (Estilo Pokémon Raid) & Selos no Login Diário (26/11/2026)

**Feito**
- **1. Camada Data (`src/shared/Data/Raids.luau`, `Retention.luau`, `Net.luau`):**
  - Relógio global determinístico via UTC (`:00` UTC a cada **1 hora**, janela de **15 minutos** aberta sincronizada em todos os servidores).
  - Rotação global com dificuldade/estrela sorteada por hora (`3★` 40% Nv. 25, `4★` 33% Nv. 35, `5★` Lendário 22% Nv. 45, `6★` Secreto `Sukuna` 5% Nv. 50 — entrada livre para qualquer nível com aviso de nível recomendado).
  - Economia protegida: recompensas garantidas de **Gold**, **XP de Conta**, **XP de Personagem**, **Minérios de Treino** e **Bônus MVP (+25% Gold/XP)** — **sem Gemas e sem Materiais de Despertar/Núcleos** (mantidos exclusivos da Torre/Ginásios/Refúgio).
  - Captura Pós-Raid usando exclusivamente Selos reais da mochila (sem Selo grátis): `3★`/`4★` aceitam `SeloContrato` (`35%`/`25%`) ou `SeloSuperior` (`52,5%`/`37,5%`); **`5★` Lendário (`8%`) e `6★` Sukuna (`1%` exato) exigem exclusivamente `SeloSuperior`**.
  - Selos adicionados no Login Diário (`Retention.Login`): `SeloContrato` nos dias **2, 4 e 6** e `SeloSuperior` nos dias **5 e 7** (UI ajustada em `RewardsClient.client.luau`).
  - Remotes documentados e criados em `ReplicatedStorage/Remotes`: `RaidState` (`RemoteEvent`) e `RaidAction` (`RemoteFunction`).
- **2. Camada Core (`src/shared/Core/RaidEngine.luau`):**
  - Máquina de estados pura 4×1 (100% determinística, zero dependências de `Workspace`/`Players`/`task.wait`): 1–4 jogadores humanos + Aliados NPCs completando 4 lutadores (NPCs não consomem vidas humanas), 1 personagem por jogador, **2 vidas individuais** com **2 turnos** para reviver automaticamente, somente os 4 golpes (sem Mochila/Torcida), limite de **10 turnos** e conversão automática para IA em caso de desconexão.
  - Mecânicas completas do Boss: escala gigante, **Escudo de Fase** aos `65%` e `30%` HP (dano reduzido a `35%`, Super Efetivo/Crítico quebra `2` barras, quebra de escudo atordoa + `-2 DEF` + burst de `4%` HP), **Pulso de Anulação** e **2 ações por turno** (`1` alvo único + `1` golpe em área).
- **3. Mundo 3D & Camada Server (`Workspace`, `RaidService.luau`, `PlayerDataService.luau`, `ProgressionService.luau`, `BattleService.luau`, `DataMain.server.luau`):**
  - Construído **Monólito / Fenda de Raid 3D** em `Workspace.Map.RaidMonolith` (`(-40, 8.0, 30)`, espelho simétrico do `LevelRewardsShrine`) com pilar de energia em partículas puras na cor da estrela ativa e `RaidPrompt` (`E`).
  - Construídas **3 Arenas de Raid dedicadas** (`Workspace.Arenas.RaidArena01..03` em `X = 3100`, piso opaco `Transparency = 0` respeitando regra de Z-sorting, `4` altares em arco `AllyPoint1..4`, `1` altar colossal `BossPoint`, `TrainerPoint1..4` e `RaidCameraPoint` sem conflito com `Arena01..10`).
  - `RaidService.luau`: sincronia horária, anúncio global na abertura (`HudClient` `RaidOpen`), lobbies de 1–4 jogadores (contagem de `30s` ou `"Iniciar Agora"`), trava `AwaitingInput` + timer de `20s`, persistência anti-exploit `data.Raid.ClaimedSlots[slotKey]` (1 recompensa/captura por hora UTC), verificação de capacidade `Benefits.CollectionMax` antes de consumir Selo, e ponte Dev `_DevData("raid", p, "open", stars, bossId)`.
- **4. Camada Client (`StarterGui/RaidGui/RaidClient.client.luau`, `HudClient.client.luau`, `RewardsClient.client.luau`):**
  - Tema `Midnight-Blue Anime` (zero emojis, 100% `UI.Icons`): banner compacto no topo do HUD com timer/teleporte, janela de Lobby com preview 3D do Boss + seletor de lutador + aviso de Selo, HUD de combate 4×1 com segmentos do Escudo de Fase + cards dos 4 aliados (`Vidas 2/2`, `Volta 2t`) + VFX/animações reais via `VfxController.PlayMove`, e tela final com Ranking de Dano/MVP + Captura Pós-Raid.
- **5. Suíte de Validação (`scripts/sync_studio.py` — `Test 19`):**
  - Adicionado **Test 19 (`GlobalRaid4x1`)** validando relógio determinístico UTC, regras de captura (`5★`/`6★` `SuperiorOnly`, `Sukuna = 1%`), ausência de Gemas/Despertar, bônus MVP `+25%`, Selos no Login Diário, simulação completa de `RaidEngine` (Escudo, Pulso, 2 ações/turno, 2 vidas + revive em 2 turnos) e integridade do Monólito/3 Arenas dedicadas.

**Testado (Play Mode ao vivo + Suíte GDD)**
- `python scripts/sync_studio.py status` (`100% in sync` nos **118 scripts**) e `python scripts/sync_studio.py test` (`PASS`).
- Validado ao vivo no Play Mode (com backup e restauração limpa do perfil): abertura `6★ Sukuna` no Monólito (`RAID 6 ESTRELAS: SUKUNA`), batalha completa `3★ Freeza` 4×1 vencida em `5` turnos (`29,9s`, `MovesAccepted = 5`, MVP `+1.875 Gold | +75 XP Conta | +225 XP Lutador | +4 Minérios de cada`, `0` Gemas adicionadas), proteção de capacidade de coleção no fluxo de captura, liberação limpa da `RaidArena01` (`InUse = false`, `InBattle = false`) e **`0` erros/avisos no Console**.
- Place salvo no Roblox Studio na **versão 368** (`TeamCreate`).


## Filas PvP Competitiva & Casual (1x1/2x2), Matchmaking Global Híbrido, Revisão de BSTs Estilo Pokémon & Quadro 3D de Ranking (26/11/2026)

**Feito**
- **1. Revisão Completa dos BSTs (34 Personagens) + Crescimento Proporcional + Escala de Coleções (`src/shared/Data/Characters.luau`, `Progression.luau`, `BattleEngine.luau`):**
  - Substituído o crescimento plano por crescimento proporcional (`levelFactor = 0.55 + 0.045 * level`: Nv. 1 = `0.595×`, Nv. 10 = `1.000×`, Nv. 50 = `2.800×`), preservando 100% os arquétipos extremos até o Nv. 50.
  - Revisados os 4 atributos base dos **34 personagens ativos** na régua `Comum = 125`, `Raro = 138`, `Épico = 152`, `Lendário = 170`, `Secreto = 190` com contrastes reais estilo Pokémon (`Kuririn` Comum VEL `38` supera `Setero` `37`; `Chad` Comum DEF `35` supera `Setero` `25`; `Vegeta` Raro ATQ `40` empata/supera Lendários; `BarbaBranca` lidera HP `80`).
  - Aplicada escala progressiva de **`+5%` por coleção/geração** no PvE e no Casual (`Generico/Naruto 1.00×`, `OnePiece 1.05×`, `Bleach 1.10×`, `JujutsuKaisen 1.15×`, `DragonBall 1.20×`), enquanto na **Ranqueada (`Ranked = true`)** todas as coleções são normalizadas para **`1.00×`** e `Secreto` é nivelado ao teto de `Lendário` (`170`).
  - Planilhas `Blender/Planilha_Personagens.xlsx` e `Planilha_Personagens.xlsx` regeneradas via `python scripts/update_characters_sheet.py`.
- **2. Regras VGC, ELO Separado 1x1/2x2, Matchmaking Global Híbrido & Temporada Mensal (`src/shared/Data/PvPRank.luau`, `Net.luau`, `PlayerDataService.luau`, `BattleService.luau`, `PvPService.luau`, `TowerService.luau`, `DataMain.server.luau`):**
  - Remotes criados e documentados: `PvPQueue` (`RemoteFunction`) e `PvPQueueState` (`RemoteEvent`).
  - **Competitivo (`Ranked2x2`, `Ranked1x1`):** Nv. 50, BST normalizado (`1.00×`), Estrelas/Variantes/`+10%` do Despertar puramente cosméticos, **Genética (IVs), Treino da Cápsula (EVs) e Passiva Secreta (se Desperto) mantidos ativos**, Species Clause (sem repetidos) e Limite de Elite (máx. `1 Secreto` e `2 Lendários`).
  - **Casual (`Casual2x2`, `Casual1x1`) e Duelo Amistoso por proximidade:** poder real não normalizado ("vale tudo"), sem alteração de ELO.
  - **Matchmaking Híbrido:** pareamento instantâneo local no mesmo servidor (zero tela de carregamento) combinado com matchmaking global entre servidores via `MemoryStoreService` (`SortedMap`) + `TeleportService:ReserveServer` (janelas de ELO expansivas `±100 -> ±250 -> ±500 -> Global`, nunca pareando com bots na Ranqueada).
  - **ELO & Placares Separados + `leaderstats` Nativo:** `Mode1x1` (`PvPRank1x1_v1`) e `Mode2x2` (`PvPRank2x2_v1`) independentes; `player.leaderstats` criado com `ELO` (`IntValue` como 1º filho → PlayerList nativa do Roblox ordena automaticamente por ELO!) e `Patente` (`StringValue`).
  - **Temporada Mensal Competitiva:** premia Gemas enxutas pela melhor Patente (`Prata 15`, `Ouro 30`, `Platina 50`, `Diamante 75`, `Lenda 110`) + títulos exclusivos `[Lenda PvP]` / `[Top 100 PvP]` em `VipTagClient.client.luau`.
- **3. Monumento 3D de Ranking na Praça + Hub Arena PvP & Botão no HUD (`Workspace.Map.PvPBoardMonument`, `PvPClient.client.luau`, `HudClient.client.luau`, `TowerClient.client.luau`):**
  - Construído `Workspace.Map.PvPBoardMonument` em `(-38, 8.32, 33)` (espelho simétrico do `LevelRewardsShrine`, voltado para o Spawn) com `SurfaceGui` de alta resolução (`Top 10 Global 2x2` e `Top 10 Global 1x1` atualizados automaticamente pelo servidor) e `PvPBoardPrompt` (`E`).
  - Adicionado botão discreto `PVP` no canto superior direito do `HudClient` (ao lado da engrenagem, preservando `AccountLevelBar` embaixo da `TeamBar` e o selo minimalista do Bônus de Fim de Semana).
  - Reformulado `PvPClient.client.luau` (tema `Midnight-Blue Anime`, zero emojis, 100% `UI.Icons`) com **Hub Arena PvP** (abas `FILAS PVP` e `RANKING GLOBAL`), barra flutuante de busca de partida no topo e modal de Duelo Amistoso.
- **4. Suíte Automatizada (`scripts/sync_studio.py` — `Test 20`):**
  - Adicionado **Test 20 (`PvPQueues/PokemonBSTs`)** validando BSTs exatos dos 34 personagens, preservação de extremos no Nv. 50 (`Kuririn`, `Chad`, `Vegeta`, `BarbaBranca`), escala `+5%`/coleção vs igualdade `1.00×` Ranqueada (`Freeza` vs `Naruto`, `Sukuna` vs `San`), `Progression.RankedMemberStats`, validação VGC (`PvPRank.ValidateRankedTeam`), stores separados `1x1`/`2x2`, janelas de ELO, remotes e `Workspace.Map.PvPBoardMonument`.

**Testado (Play Mode ao vivo + Suíte GDD)**
- `python scripts/sync_studio.py status` (`100% in sync` nos **118 scripts**) e `python scripts/sync_studio.py test` (`PASS`, `Test 1..20`).
- Validado ao vivo no Play Mode (com backup e restauração do perfil): `leaderstats` (`1:ELO`, `2:Patente`) atualizando dinamicamente com ELO separado `2x2` (`1480 Platina`) vs `1x1` (`1000 Bronze`), Quadro 3D `PvPBoardMonument` exibindo ambas as colunas ao vivo, entrada/saída nas filas (`PvPQueueBanner` sem sobreposições em Desktop e `667x375`), `PvPButton` sem sobreposições e **`0` erros de jogo no Console**.
- **Polimento Visual da Janela `ARENA PVP` e Topo do HUD (`PvPClient`, `HudClient`, `RaidClient`):** removidos chips redundantes e rodapé longo nos cards de fila (trocado por botão discreto `REGRAS` com modal próprio na faixa de resumo de 1 linha), separação estrita em 2 colunas nos 4 cards (texto `0.055..0.615` / botão `ENTRAR` `0.64..0.96`), e realinhamento de `Top`, `RaidHudBanner`, `PvPButton` e `SettingsButton` com `HUD_OVERLAPS=NONE`, `SUMMARY_OVERLAPS=NONE` e `CARD_OVERLAPS=NONE` em Desktop (`1350x576`) e Mobile (`667x375`).
- Place salvo no Roblox Studio na **versão 375** (`TeamCreate`).
