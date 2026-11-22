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
