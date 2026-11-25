# GDD — Jogo de batalha por turnos com personagens estilo anime (Roblox)

Versão de 16/11/2026 (revisão do mapa v2). Fonte oficial do projeto. Em conflito com qualquer prompt, vale este arquivo.

## 1. Visão geral

RPG de coleção e batalha por turnos no Roblox, no formato Pokémon, com personagens originais em estilo anime no lugar dos monstros. Nome do jogo: a definir.

| Item | Definição |
| --- | --- |
| Plataforma | Roblox (PC, mobile, console) |
| Gênero | RPG de coleção, combate por turnos 1x1 com time de até 6 |
| Jogadores por servidor | 10 (cada jogador tem 1 base) |
| Modos de batalha | Jogador x NPC (torre) e jogador x jogador |
| Moedas | Gold (comum), Minério (recurso), Gemas (premium) |
| Monetização | Game Pass e produtos em Robux; parte dos benefícios também por Gemas |

**Loop principal**

1. Batalhar na torre central (ou contra outro jogador) para ganhar gold, XP e personagens.
2. Invocar personagens nas estrelas de invocação do centro.
3. Levar os personagens para a base: eles andam por lá, geram gold e podem minerar.
4. Vender o minério por gemas, com limite diário.
5. Gastar gold em poções, itens e melhorias; gastar gemas em invocações e benefícios.
6. Voltar à torre com o time mais forte e subir de dificuldade.

## 2. Escopo do protótipo (Fase 1)

**Entra:** mapa principal com torre, praça e 12 terrenos vazios; Kaen (Fogo, jogador) e Raiko (Raio, máquina); gatilho de proximidade na torre; batalha 1x1 completa (golpes, ordem por velocidade, dano, PP, status, vitória e derrota); mochila com Poção (cura 20 de HP); HUD de batalha com barras de HP, menu Lutar / Mochila / Fugir e log; animações e efeitos dos golpes.

**Fica fora:** time de 6, troca, captura, PvP, base, mineração, gemas, loja, Game Pass, dificuldades da torre, salvamento.

**Critério de aprovação:** uma batalha Kaen x Raiko roda do início ao fim sem erro, dura de 5 a 8 turnos e o dano bate com a fórmula da seção 5.

## 3. Mapa principal

Retângulo compacto, fechado por montanhas. Meta: atravessar o lado maior a pé em até 25 segundos (velocidade de caminhada 16 studs/s). De fora para dentro: montanhas, anel das bases, anel da esteira e centro.

| Área | Posição | Tamanho | Função |
| --- | --- | --- | --- |
| Montanhas | Em toda a volta | Fora da área jogável | Fecham o mapa. Parede invisível nas bordas e teto invisível: não dá para sair nem subir |
| Bases | Anel externo, encostadas nas montanhas, nos quatro lados | 10 terrenos de 40 x 40 studs | Uma por jogador: placa com o nome do dono, cerca, portão, piso, pedreira, área de passeio, luz, decoração e a caverna do Refúgio (seção 14) (as 10 iguais) |
| Esteira | Anel entre as bases e o centro | Caminho em volta de todo o retângulo | Move o jogador sozinho, sempre no mesmo sentido, com textura animada mostrando a direção; entra e sai em qualquer ponto, sem prender nem arremessar |
| Torre | Centro | Base 60 x 60 studs, pagode alto com cristal no topo | Batalhas contra NPC. Gatilho com raio de 12 studs na entrada |
| Centro de cura | Centro, em volta da torre | 20 x 20 studs | Restaura HP e PP do time |
| Loja | Centro, em volta da torre | 30 x 20 studs | Itens e venda de minério |
| Estrelas de invocação | Centro, em volta da torre | 2 estrelas grandes, iguais na forma | Flutuam e giram sempre, com brilho, partículas e luz. Amarela = Portal Comum; roxa = Portal Premium |
| Placares | Centro, em volta da torre | 2 painéis grandes | Ranking global (OrderedDataStore, atualizado a cada poucos minutos, top 3 em destaque): maior gold e maior andar da torre |
| Arenas | Fora do mapa | 10 arenas de 60 x 40 studs | Cada batalha em arena própria; dois pontos a 30 studs |

As medidas exatas ficam na planta aprovada (C:\Blender\Mapa).

**Direção de arte:** anime estilizado, cores saturadas, formas limpas. Vila de fantasia japonesa ao fim da tarde: cerejeiras, lanternas, telhados curvos, grama clara. Torre em pagode de pedra escura com detalhes dourados e cristal brilhante no topo, visível de qualquer ponto. Tudo com textura (chão, pedra, madeira, telhados, montanhas, esteira). Partículas de ambiente (pétalas, vaga-lumes, brilho no cristal), água ou lanternas animadas; tudo desliga pela opção "Efeitos do mapa".

**Limites técnicos:** peças modulares reaproveitadas, até 150 mil triângulos visíveis, colisão simples, StreamingEnabled ligado, partículas de ambiente limitadas para rodar em celular.

**Zonas de encontro:** removidas do mapa principal. Selvagens e captura agora ficam no Refúgio de cada jogador (seção 14).

## 4. Personagens

Todos os personagens são originais. Personagens e técnicas de animes existentes são propriedade dos estúdios; versões reconhecíveis com nome trocado também não são usadas. A criação segue a skill `personagem-anime-roblox`.

**Padrão de modelo:** avatar em blocos do Roblox (R15 blocky), 5,5 studs. Rosto em textura plana com traço de anime, roupa pintada com contorno grosso e cel-shading, cabelo grande em degradê como peça separada, até 4 acessórios. Até 10.000 triângulos e texturas de 1024 x 1024. Cada personagem tem cor dominante ligada ao tipo, um acessório único e uma técnica assinatura com animação própria.

**Animações:** parado, andar, levar dano, desmaiar, vitória, minerar e uma animação por golpe.

**Atributos:** HP, Ataque, Defesa, Velocidade. Nível de 1 a 50; por nível +3 HP e +1 em Ataque, Defesa e Velocidade. 1 tipo e até 4 golpes ativos.

| Raridade | Multiplicador de atributos | Chance em encontro | Minério por hora |
| --- | --- | --- | --- |
| Comum | 1,00 | 60% | 10 |
| Raro | 1,10 | 28% | 18 |
| Épico | 1,20 | 10% | 30 |
| Lendário | 1,35 | 2% | 50 |
| Secreto | 1,50 | 0% (0,001% em qualquer banner a partir do Nv. 15) | 110 |

**Personagens do protótipo (nível 10)**

| | Kaen (jogador) | Raiko (máquina) |
| --- | --- | --- |
| Tipo | Fogo | Raio |
| Arquétipo | Espadachim jovem e impulsivo | Lutador de rua calmo e rápido |
| Visual | Cabelo vermelho espetado, olhos âmbar, casaco preto curto com forro laranja, faixa branca na testa, katana com lâmina incandescente | Cabelo loiro platinado preso atrás, olhos azuis, jaqueta azul-escura sem mangas, manoplas metálicas com faíscas, cachecol amarelo longo |
| Cores | Vermelho e laranja | Azul e amarelo |
| HP / Ataque / Defesa / Velocidade | 62 / 24 / 18 / 22 | 66 / 22 / 20 / 20 |
| Golpe 1 (assinatura) | Corte Flamejante: Fogo, poder 50, precisão 100, PP 20 | Descarga: Raio, poder 50, precisão 100, PP 20 |
| Golpe 2 | Investida: Neutro, poder 40, precisão 100, PP 30 | Soco Direto: Neutro, poder 40, precisão 100, PP 30 |
| Golpe 3 | Brasa Viva: Fogo, poder 35, precisão 100, PP 15, 30% de queimar | Punho de Maré: Água, poder 40, precisão 95, PP 15 |
| Golpe 4 | Postura de Combate: +1 estágio de Ataque, PP 15 | Estática: precisão 90, PP 15, paralisa o alvo |

**Variantes:** Brilhante (+10%), Prata (+3%), Ouro (+5%), Esmeralda / Rubi / Diamante (+7%), Arco-íris (+10%), Gigante (+5%). Mudam só aparência e atributos; nunca golpes.

**Genética e Treino (equivalentes a IVs e EVs):** cada personagem possui 1 valor de **Genética** (`0` a `100%`) e 1 valor de **Treino** (`0` a `100%`) para cada atributo (`HP`, `Ataque`, `Defesa`, `Velocidade`).

- **Impacto nos atributos finais:** `Genética` soma até **+40%** (`+0,4%` por ponto) e `Treino` soma até **+30%** (`+0,3%` por ponto) em cada atributo correspondente (`multiplicador = 1 + 0,40 × Gen/100 + 0,30 × Treino/100`, acumulado ao bônus de estrelas e variante). Com ambos em 100%, o atributo recebe **+70%**.
- **Distribuição da Genética (sorteio no servidor):** cada atributo é sorteado de forma independente pela curva contínua de Kumaraswamy conforme a raridade do personagem (raridades maiores puxam a média esperada para cima, porém sem garantia — valores baixos ainda podem ocorrer em Lendários e valores altos em Comuns). Além disso, há uma chance raríssima de vir **100% perfeito (100/100/100/100)** em todas as raridades:
  - Comum: média esperada ~36% · chance de 100% perfeito: **0,005%** (~1 em 20.000)
  - Raro: média esperada ~53% · chance de 100% perfeito: **0,012%** (~1 em 8.333)
  - Épico: média esperada ~65% · chance de 100% perfeito: **0,025%** (~1 em 4.000)
  - Lendário: média esperada ~74% · chance de 100% perfeito: **0,050%** (~1 em 2.000)
  - Secreto: média esperada ~77% · chance de 100% perfeito: **0,100%** (~1 em 1.000)
- **Treino inicial:** todo personagem obtido pelo jogador (inicial, invocação, captura no Refúgio/selvagens e chefe da Torre) sempre começa com **Treino 0%** nos 4 atributos (métodos de evolução de Treino entrarão em atualização futura).

**Elenco por Anime:**
- **One Piece:** Comum (`Nami`, `Usopp`), Raro (`Zoro`, `Sanji`), Épico (`Luffy`), Lendário (`Barba Branca`).
- **Naruto:** Comum (`Sakura`, `Shikamaru`), Raro (`Kakashi`, `Sasuke`), Épico (`Naruto`), Lendário (`Sarutobi`).
- **Bleach:** Comum (`Chad`, `Uryu`), Raro (`Rukia`, `Renji`), Épico (`Ichigo`), Lendário (`Byakuya`).
- **Dragon Ball / Jujutsu Kaisen / Genéricos:** `San` (Lendário), `Setero` (Lendário), `Sukuna` (**Secreto**, cor preta, BST 162), `Kaen`, `Raiko`, `Yomogi`.

## 5. Combate por turnos

Batalha 1x1 em campo, com time de até 6 por lado; vence quem derrubar todos os personagens do adversário.

**Fluxo de um turno**

1. Cada lado escolhe: Lutar (1 dos 4 golpes), Mochila, Time (trocar) ou Fugir.
2. Troca e item primeiro; depois golpes, do mais veloz ao mais lento. Empate sorteado.
3. Cada golpe checa precisão, aplica dano e efeito e gasta 1 PP.
4. Fim do turno: queimadura, veneno, contagem de sono.
5. HP 0 desmaia; o dono escolhe o próximo. Sem personagens de pé, a batalha acaba.

**Fórmula de dano**

```
Dano = ( ((2 × Nivel / 5 + 2) × Poder × Ataque / Defesa) / 50 + 2 ) × Bonus × Tipo × Critico × Sorte
```

- Bonus: 1,5 quando o golpe é do mesmo tipo do personagem; senão 1.
- Tipo: 2 com vantagem, 0,5 com desvantagem, 1 neutro.
- Critico: 1,5 com 6,25% de chance; senão 1.
- Sorte: aleatório entre 0,85 e 1,00.
- Conferência: Corte Flamejante de Kaen em Raiko causa de 12 a 14; Descarga de Raiko em Kaen, de 12 a 14. A luta dura de 5 a 8 turnos.

**Tipos**

| Tipo do golpe | Causa dano x2 em | Causa dano x0,5 em |
| --- | --- | --- |
| Fogo | Natureza | Água |
| Água | Fogo | Natureza, Raio |
| Natureza | Água, Raio | Fogo |
| Raio | Água | Natureza |
| Luz | Trevas | Luz |
| Trevas | Luz | Trevas |
| Neutro | Nenhum | Nenhum |

Qualquer combinação fora da tabela causa dano normal (x1).

**Status (1 por personagem de cada vez)**

| Status | Efeito |
| --- | --- |
| Queimadura | Perde 1/16 do HP máximo por turno; Ataque pela metade |
| Veneno | Perde 1/8 do HP máximo por turno |
| Paralisia | 25% de chance de não agir; Velocidade pela metade |
| Sono | Não age por 1 a 3 turnos |
| Congelamento | Não age; 20% de chance de descongelar por turno |

**Estágios:** golpes de suporte mudam Ataque, Defesa, Velocidade ou Precisão de -6 a +6. Cada estágio positivo soma 50% do valor base; trocar de personagem zera.

**Fuga:** bloqueada na torre e no PvP (lá existe Desistir, que conta como derrota). Contra selvagens seria permitida quando a captura voltar.

**IA da máquina**

| Nível | Comportamento |
| --- | --- |
| Fácil | Golpe aleatório entre os que têm PP |
| Médio | 70% o golpe de maior dano esperado; 30% aleatório |
| Difícil | Sempre o maior dano esperado; usa status se o alvo estiver sem status; troca em desvantagem de tipo |

O protótipo usa a IA Médio.

**PvP:** desafio por proximidade na praça, aceite dos dois lados, níveis igualados em 50, 30 segundos por turno, itens desativados.

**Apresentação:** câmera fixa em diagonal atrás do personagem do jogador. Cada golpe toca a animação do personagem, o efeito sincronizado por marcadores (Charge, Release, Impact), o número de dano e a barra de HP descendo. Técnica assinatura de Épico e Lendário tem aproximação de câmera e o nome do golpe na tela.

## 6. Torre

| Modo | Batalhas | Personagens por NPC | Nível dos inimigos | IA | Recompensa |
| --- | --- | --- | --- | --- | --- |
| Fácil | 3 | 2 | 5 a 10 | Fácil | 150 gold |
| Médio | 5 | 4 | 15 a 25 | Médio | 500 gold, 1 item |
| Difícil | 7 | 6 | 30 a 45 | Difícil | 1.500 gold, 2 itens, 5 gemas (1 vez por dia) |
| Infinito | Sem fim | 6 | 10 + 2 por andar | Difícil | 100 gold por andar, bônus a cada 5 andares |

- Sem cura entre batalhas no Fácil, Médio e Difícil.
- Infinito: recupera 30% do HP entre andares; chefe a cada 5 andares com atributos 20% maiores; a partir do andar 20, +4% de atributos por andar.
- Derrota encerra a corrida; o gold ganho fica.
- Placar do servidor e global com o andar mais alto do Infinito.
- Desbloqueio em sequência: Fácil, Médio, Difícil, Infinito.
- Chefes do Infinito podem entregar um personagem: 5% no andar 5, +1 ponto por chefe, até 15%.
- **Atributos PvE da Torre:** todos os inimigos NPCs da Torre possuem **Genética = 70%** e **Treino = 100%** em todos os 4 atributos (equivalente a `+58%` nos atributos base, acumulados ao escalonamento de andar/chefe no Infinito). Quando um chefe se junta ao jogador, seus atributos individuais são sorteados normalmente (curva da raridade e Treino 0%).

## 7. Coleção, time e inventário

Até 6 personagens no time; o resto fica na base.

**Como conseguir personagens:** inicial (1 entre 3 comuns de Fogo, Água e Natureza), invocação nas estrelas (fonte principal, seção 13), chefes do Infinito e captura de selvagens no Refúgio (seção 14), com a fórmula abaixo.

**Chance de captura**

```
Chance = Taxa × (1 − 0,7 × HP_atual / HP_max) × Selo × Status
```

- Taxa: Comum 0,60; Raro 0,40; Épico 0,20; Lendário 0,08.
- Selo: 1 (Selo de Contrato) ou 1,5 (Selo Superior).
- Status: 1,5 se o alvo tiver status; senão 1.

**Evolução:** XP por vitória; golpes novos nos níveis 5, 10, 18, 26, 35 e 45; o jogador escolhe os 4 ativos.

| Item | Efeito | Preço (gold) |
| --- | --- | --- |
| Poção | Cura 20 de HP | 50 |
| Superpoção | Cura 50 de HP | 150 |
| Hiperpoção | Cura 120 de HP | 400 |
| Cura-Status | Remove qualquer status | 100 |
| Éter | Restaura 10 PP de um golpe | 200 |
| Reviver | Levanta desmaiado com 50% do HP | 500 |
| Selo de Contrato | Tenta capturar | 100 |
| Selo Superior | Captura com bônus 1,5 | 300 |

Usar item em batalha gasta o turno. Mochila de 30 espaços, pilhas de 99. Poções e Reviver também fora de batalha. Itens não são trocáveis.

## 8. Base, mineração e economia

Terreno de 40 x 40 studs por jogador; até 6 personagens ativos na base, cada um Passeando (gold) ou Minerando (minério bruto + 50% do Gold/h + minérios de atributo).

- Vagas de mineração: 2 no início; melhorias em gold liberam até 6 (5.000, 15.000, 40.000 e 100.000 gold).
- Produção acumula até 8 horas com o jogador fora.
- Quem minera fica na pedreira com a animação de minerar e também gera **Gold** (50% da taxa de Passeio) além dos minérios.

| Raridade | Gold/h (Passeando) | Gold/h (Minerando) | Minério bruto/h (Minerando) |
| --- | --- | --- | --- |
| Comum | 20 | 10 | 10 |
| Raro | 30 | 15 | 18 |
| Épico | 45 | 22,5 | 30 |
| Lendário | 70 | 35 | 50 |

**Nível da Mineração (Nv. 1 a 10) e os 4 Minérios de Treino:** cada ciclo de mineração (1 min por minerador Comum, escalando até 5× para Lendário) rola independentemente a chance de encontrar os minérios de atributo desbloqueados (podendo vir mais de um tipo e múltiplas unidades por achado). Subir o nível da Mineração (em Gold, `500` até `200.000`) desbloqueia minérios mais raros e equilibra as chances e quantidades:

| Minério | Atributo | Raridade | Desbloqueio | Chance / Qtd (Inicial → Nv. 10) |
| --- | --- | --- | --- | --- |
| Minério Vital | HP | Comum | Nv. 1 | 55% (1–2) → 44% (2–4) |
| Minério Férreo | Defesa | Raro | Nv. 2 | 18% (1) → 42% (2–3) |
| Minério Veloz | Velocidade | Épico | Nv. 4 | 14% (1) → 39% (2–3) |
| Minério Rubro | Ataque | Lendário (mais raro) | Nv. 6 | 10% (1) → 34% (1–3) |

**Máquina de Treinamento (Cúpula de Vidro na Base):** cápsula física instalada no terreno de cada jogador (acessível pelo painel na Base ou no menu Base) para evoluir os atributos de **Treino** (`0%` a `100%`).

- **Regras de crafting e seleção:** evolução estritamente de **20 em 20** (`+20`, `+40`...) gastando o minério correspondente a cada atributo escolhido (`Vital/HP = 8`, `Férreo/DEF = 6`, `Veloz/VEL = 5`, `Rubro/ATQ = 4` base por `+20`). Enquanto treina, o personagem permanece visível levitando dentro da cúpula de vidro e não pode minerar, passear, lutar no time ou ser fundido/vendido (cancelar devolve 50% dos minérios).
- **Raridade e multi-atributo:** personagens mais raros custam mais minério (`1,00×` Comum, `1,50×` Raro, `2,25×` Épico, `3,50×` Lendário, `4,50×` Secreto) e levam um pouco mais de tempo (`1,00×`, `1,20×`, `1,40×`, `1,65×`, `1,90×`). Treinar vários atributos na mesma sessão executa em paralelo (economizando tempo, `+20%` por passo adicional) porém encarece o crafting (`+25%` com 2, `+50%` com 3, `+80%` com 4 atributos).
- **Eficiência (Níveis 1 a 10 em Gold):** no nível 1, subir 1 atributo uma vez (`+20`) num Comum leva **1 minuto (`60s`)**. Melhorar a Máquina com Gold (`500` até `220.000`) eleva a eficiência de `1,00×` até **`4,00×`** (`15s` por `+20` básico no nível 10).

**Conversão e teto:** 100 de minério = 1 gema. Teto de venda: 50 gemas por dia por jogador; excedente fica guardado (máximo 10.000). Outras fontes grátis: 5 gemas da torre Difícil e 5 das missões diárias. Máximo grátis: 60 gemas por dia.

| Perfil | Mineração | Gemas por dia (só mineração) |
| --- | --- | --- |
| Iniciante | 2 Comuns | Cerca de 5 |
| Intermediário | 4 Raros | Cerca de 17 |
| Avançado | 6 Épicos | Cerca de 43 |
| Topo | 6 Lendários | 50 (teto) |

Os três benefícios compráveis com gemas somam 14.500 gemas: cerca de 242 dias para quem está no teto.

| Moeda | Vem de | Serve para |
| --- | --- | --- |
| Gold | Batalhas, torre, personagens passeando, venda de repetidos | Itens, melhorias, Portal Comum |
| Minério | Personagens minerando | Vender por gemas |
| Gemas | Minério, torre Difícil, missões, compra em Robux | Portal Premium, benefícios, aparências, continuar corrida no Infinito (20 gemas, 1 vez por corrida) |

## 9. Monetização

Game Pass de verdade só é vendido em Robux. As gemas liberam o mesmo benefício dentro do jogo, salvo nos dados do jogador.

| Benefício | Efeito | Robux | Gemas |
| --- | --- | --- | --- |
| Mochila Ampliada | +20 espaços | 99 | 1.500 |
| Gold em Dobro | 2x gold dos personagens passeando | 249 | 4.000 |
| Cura Automática | Time curado após cada batalha fora da torre | 399 | 9.000 |
| XP em Dobro | 2x XP | 299 | Só Robux |
| VIP | Tag, aparência de base, +10% de gold | 349 | Só Robux |
| Minerador Extra | +2 vagas de mineração (teto de gemas não muda) | 499 | Só Robux |
| Invocação Rápida | Invoca 3 de uma vez e pula animação | 199 | Só Robux |
| Sorte em Dobro | Dobra Épico e Lendário no Portal Comum | 399 | Só Robux |
| Depósito Ampliado | +50 vagas de personagens | 149 | Só Robux |

| Pacote de gemas | Robux |
| --- | --- |
| 500 gemas | 49 |
| 1.500 gemas | 129 |
| 5.000 gemas | 399 |

Regras: comprar o benefício em Robux é sempre mais barato que comprar gemas para trocá-lo; nenhum pago aumenta dano, HP ou captura; nenhum aumenta o teto diário de gemas; preços revistos com dados de venda.

## 10. Interface e requisitos técnicos

Toda lógica de batalha e economia roda no servidor; o cliente envia escolhas e mostra resultados.

| Tela | Conteúdo |
| --- | --- |
| HUD do mapa | Gold (com taxa `+X/s` ao vivo), gemas, minério, botões Equipe, Mochila, Base, Loja, Prêmios, Álbum, Configurações, Trilha Inicial (7 passos) e selo circular minimalista de Bônus de Fim de Semana no canto inferior direito (`2x de Moedas` / `2x de XP` no hover/toque) |
| Barra do Time e Nível | 6 cartões 3D do time na faixa inferior central + barra minimalista de Nível da Conta logo embaixo (`[ Nv. X ] [=== XP / Meta XP ===]`, alinhada exatamente à largura da `TeamBar`) |
| Recompensas de Nível | Janela aberta ao apertar `E` nos baús de ouro embaixo da grande árvore perto da Torre (`RECOMPENSAS DE NÍVEL`), listando recompensas de todos os níveis (1..50+, marcos Épicos a cada 5 e Lendários a cada 10) e botão `RESGATAR TUDO` |
| Configurações | Música (liga/desliga e volume), efeitos sonoros (liga/desliga e volume), efeitos do mapa e auras dos personagens (`CharacterAuras`); salvas nos dados do jogador |
| Batalha | Nome, nível, HP e status dos dois lados (`1x1` ou `2x2`); menu Lutar / Mochila / Time / Fugir; log |
| Lutar | 4 golpes com classe (cor e ícone), poder e PP |
| Time / Equipe | 6 personagens com HP, nível e status; grade 3D com busca por nome, filtros de Anime/Raridade/Classe e ordenação por Status |
| Torre | Abas Torre (`1x1` e `2x2`), Ginásios de Anime (Porta-Insígnias + 3 Ginásios) e Treino (simulador `1x1`/`2x2`), recompensas e placar |
| Invocação | Palco 3D ao vivo estilo Anime Vanguards, trilho de banners por anime, chances visíveis, garantia centralizada, botões `INVOCAR 1` / `INVOCAR 10` com ícone e preço centralizados, animação 3D de revelação |
| Base | Personagens Passeando / Minerando, taxas `g/s` ao vivo, nível da mineração, faixa dos 4 minérios e acesso à Cápsula de Treino |
| Loja | Itens (gold), Vender Minério, Benefícios (Robux ou gemas) e Pacotes de Gemas |
| Álbum | Todos os personagens, obtidos, variantes, metas por Classe e Raridade |
| Atributos (Radar) | Retrato 3D, rank de Genética, gráfico de radar de 4 eixos (`HP`, `ATQ`, `DEF`, `VEL` de 0–100% com camadas `Ambos` / `Genética` / `Treino`) e detalhamento Base / Final |

**Padrão visual da interface (`UITheme` + `UI`):** paleta anime azul-noturno profundo (`panel` `#273066 -> #161B3D`, `slot` `#191E42 -> #0F122B`, `header` `#3B9EFF -> #1B64D8`, contorno `#0B0E22`), textura diagonal de luz de 3 bandas a 38° (`UI.sheen`), afundamento físico 3D ao clicar nos botões, fonte `FredokaOne` com contorno `Bevel` e **100% ícones personalizados (`UI.Icons`)** — proibido usar emojis ou símbolos Unicode (`★`, `✦`, `✓`, `→`, `■`, `—`) nos textos da interface. Botões grandes para celular (`>= 44x44 px`); batalha funciona só com toque.

| Local | Conteúdo |
| --- | --- |
| ReplicatedStorage/Data | Characters, Moves, TypeChart, Items |
| ReplicatedStorage/Vfx | Um modelo de efeito por golpe |
| ReplicatedStorage/Remotes | StartBattle, SubmitAction, BattleUpdate, BattleEnd |
| ServerScriptService/Battle | BattleService, DamageCalc, AIController |
| ServerScriptService/Economy | BaseService, MiningService, ShopService, SummonService |
| ServerScriptService/Data | DataStore com trava de sessão |
| ServerStorage/Characters | Modelos dos personagens |
| StarterPlayerScripts | VfxController e controladores de interface |
| StarterGui | BattleGui, HudGui, ShopGui, SummonGui |
| Workspace | Map, Tower, Plots (10), Arenas (10) |
| SoundService | SoundGroups separados: Musica e Efeitos |

Regras técnicas: servidor valida toda ação (golpe existe, tem PP, é a vez); dano, captura, sorteios e recompensas só no servidor; personagens e golpes só em dados; compras por MarketplaceService com ProcessReceipt; dados salvos: coleção, time, mochila, gold, minério, gemas, benefícios, torre, gemas vendidas no dia, missões, login diário, garantia de invocação, configurações.

**Som:** uma faixa tema para o mapa e outra para a batalha, com transição suave ao entrar e sair da batalha. Efeitos de interface: clique, abrir tela, compra, recompensa.

## 11. Efeitos visuais

- Cada golpe: animação própria + efeito em 3 fases (preparação, impacto, dissipação), sincronizados por marcadores Charge, Release, Impact.
- Efeito em 3 camadas: núcleo claro, corpo na cor do tipo, resíduos.
- PointLight de impacto na cor do tipo, brilho animado; tremor de câmera de 0,15 s; flash só em crítico.
- Arena: iluminação Future, ambiente levemente escuro, Bloom suave, ColorCorrection. Se pesar em celular, trocar para ShadowMap.
- Otimização: até 150 partículas por efeito (200 na técnica assinatura), 2 PointLights sem sombra, texturas de partícula até 256 x 256, Emit() com quantidade fixa, pool de efeitos, modo de qualidade baixa com metade das partículas e sem Bloom.

## 12. Roadmap e decisões pendentes

1. **Protótipo:** mapa, Kaen, Raiko, batalha 1x1, efeitos.
2. **Time completo:** 6 por lado, troca, todos os status, elenco de 12.
3. **Progressão, torre e coleção:** salvamento, níveis, torre, Portal Comum, fusão, álbum (captura adiada).
4. **Base e economia:** mochila, loja, cura, base, mineração, venda com teto.
5. **Monetização e PvP:** passes, pacotes, Portal Premium, PvP.
6. **Lançamento:** login diário, missões, eventos, códigos, polimento, segurança, teste em celular.

Decisões em aberto: nome do jogo; troca de personagens entre jogadores; validar preços em Robux e teto de gemas após testes.

## 13. Invocação e retenção

| | Portal Comum (estrela amarela) | Portal Premium (estrela roxa) |
| --- | --- | --- |
| Custo | 300 gold (10 por 2.700) | 25 gemas (10 por 225) |
| Comum | 70% | 0% |
| Raro | 23% | 72% |
| Épico | 6% | 25% |
| Lendário | 1% | 3% |
| Secreto (cor preta, Nv. 15+ da conta) | 0,001% (global em qualquer banner) | 0,001% (global em qualquer banner) |
| Garantia | Lendário na 200ª seguida sem Lendário | Lendário na 60ª |

- Variante Brilhante: 1% em toda invocação; outras variantes por evento.
- **Painéis de Seleção de Anime na Estrela:** a tela dos Portais exibe cartões ilustrados (`Todos os Animes`, `Naruto`, `One Piece`) para escolher qual pool/estrela roletar; o servidor valida o painel selecionado e filtra os sorteios por anime mantendo integralmente as chances de raridade e a garantia (*pity*) do portal.
- **Animação e Som ao Roletar:** além do raio no portal do mapa, o cliente exibe na frente da tela um palco de destaque rápido (`~1,45–1,85s`, pulável com `PULAR` e ignorado por `Invocação Rápida`) com o personagem 3D completo girando sob raios radiais na cor da raridade, clarão/partículas, badge de raridade/anime e efeitos sonoros estimulantes (`summon_charge`, `summon_shimmer`, `summon_reveal`, `summon_epic`, `summon_legendary`), seguidos pela grade de cartas com prévias 3D. Lendário e Brilhante continuam anunciados no chat do servidor.
- Chances sempre visíveis na tela.
- Banner da semana: 1 Lendário em destaque fica com metade da chance de Lendário do Portal Premium.
- Repetidos: 3 iguais viram +1 estrela (até 5, +5% de atributos cada); sobras vendidas por gold (Comum 50, Raro 150, Épico 500, Lendário 3.000, Secreto 12.000).
- Álbum: completar cada tipo e cada raridade paga gold e gemas uma vez.

| Mecânica | Como funciona | Recompensa |
| --- | --- | --- |
| Login diário | 7 dias, reinicia se pular um | Gold crescente; dia 7: 1 invocação Premium |
| Tempo de sessão | Baús aos 5, 15, 30 e 60 minutos | Gold, poções, Selos |
| Missões diárias | 3 por dia | Gold e XP; completar as 3: 5 gemas |
| Missões semanais | 5 por semana | 1 invocação Premium |
| Temporada do Infinito | Placar zera todo mês | Aparência para os 100 primeiros; gemas por faixa |
| Eventos de fim de semana | 2x gold ou 2x XP (ícone circular minimalista no canto inferior direito com tooltip no hover/toque) | Sem custo |
| Códigos | Divulgados em atualizações | Gold e invocações comuns |
| Nível da Conta (`AccountLevel`) | Nível permanente da conta (nunca diminui; curva $\text{XP}(L) = \lfloor 100 + 25 \cdot L^{1,55} \rfloor$), alimentado por batalhas, torre, ginásios, invocações, coleta da base, cápsula de treino, missões, trilha inicial, refúgio e PvP | Recompensa em cada nível (Gold, Poções, Doces, Selos, Gemas e Tickets nos marcos Épicos a cada 5 níveis e Lendários a cada 10 níveis), resgatada nos baús de ouro sob a grande árvore (`RECOMPENSAS DE NÍVEL`) perto da Torre |

**Regras obrigatórias:** o Portal Premium conta como item aleatório pago; mostrar chances e bloquear por PolicyService (ArePaidRandomItemsRestricted) onde for restrito, deixando só o Portal Comum (estrela amarela). Sem contagem regressiva de oferta e sem pop-up de compra ao perder batalha.

## 14. Refúgio

Área privada de cada jogador, fora do mapa, onde surgem personagens selvagens para batalhar e capturar.

**Entrada e área**

- Cada base tem uma caverna pequena com entrada brilhante. Só o dono entra; o prompt leva ao seu Refúgio.
- 10 áreas fora do mapa, cerca de 80 x 80 studs, cercadas de montanhas, com árvores, plantas, flores, partículas e luz próprias. Parede e teto invisíveis. Uma saída devolve à base.
- Dentro: a Forja, o Baú e o campo onde os selvagens aparecem e andam. Efeitos decorativos obedecem a "Efeitos do mapa".

**Selvagens**

- Surgem um a cada intervalo, até o máximo simultâneo da Forja. O contador continua com o jogador fora, até o máximo.
- Tocar ou clicar num selvagem abre batalha na arena normal, com as regras de selvagem: pode fugir e capturar com Selo de Contrato ou Selo Superior (fórmula da seção 7).
- Derrotar dá gold e XP; capturar põe o personagem na coleção. Raridade, nível e **Genética** sorteados no servidor (mesma curva probabilística por raridade usada no Gacha; Treino inicia em 0%).

| Forja | Comum | Raro | Épico | Lendário | Nível do selvagem | Máximo | Intervalo |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 80% | 18% | 2% | 0% | 3 a 8 | 2 | 4 min |
| 2 | 75% | 22% | 3% | 0% | 6 a 12 | 2 | 4 min |
| 3 | 70% | 25% | 5% | 0% | 10 a 16 | 3 | 3 min 30 s |
| 4 | 65% | 28% | 6,5% | 0,5% | 14 a 20 | 3 | 3 min 30 s |
| 5 | 60% | 30% | 9% | 1% | 18 a 25 | 3 | 3 min |
| 6 | 55% | 32% | 11,5% | 1,5% | 22 a 30 | 4 | 3 min |
| 7 | 50% | 34% | 14% | 2% | 27 a 35 | 4 | 2 min 30 s |
| 8 | 46% | 35% | 16,5% | 2,5% | 32 a 40 | 4 | 2 min 30 s |
| 9 | 43% | 36% | 18% | 3% | 36 a 45 | 5 | 2 min |
| 10 | 40% | 37% | 19% | 4% | 40 a 50 | 5 | 2 min |

**Melhoria da Forja** (gemas + todos os requisitos)

| Para o nível | Gemas | Requisitos |
| --- | --- | --- |
| 2 | 50 | Vencer a torre Fácil; derrotar 10 selvagens |
| 3 | 100 | 3 personagens no nível 10; capturar 5 |
| 4 | 200 | Vencer a torre Médio; derrotar 40 selvagens |
| 5 | 350 | 3 personagens no nível 20; capturar 15 |
| 6 | 500 | Vencer a torre Difícil; derrotar 100 selvagens |
| 7 | 750 | Andar 10 do Infinito; 6 personagens no nível 25 |
| 8 | 1.000 | Andar 20 do Infinito; 1 personagem com 3 estrelas |
| 9 | 1.500 | Andar 30 do Infinito; 6 personagens no nível 40; capturar 80 |
| 10 | 2.000 | Andar 50 do Infinito; 1 Lendário no nível 50; capturar 150 |

**Tela da Forja:** nível atual, chances atuais e do próximo nível lado a lado (sempre visíveis), custo, requisitos com progresso (ex.: 23/40) e marca de feito. O botão Melhorar só fica ativo com tudo cumprido. O modelo da Forja muda nos níveis 4, 7 e 10, com efeito e som na melhoria.

**Baú:** cada selvagem derrotado ou capturado tem 30% de chance de deixar um item: Poção, Superpoção, Cura-Status, Selo de Contrato ou minério (20 a 50). A partir da Forja 6 também Selo Superior e Éter. Capacidade 10 + 2 por nível da Forja; cheio, não recebe até coletar. Brilha quando tem itens; tela simples "Coletar tudo".

**Regras:** tudo no servidor; o cliente nunca informa progresso. Salvos: nível da Forja, contadores (selvagens derrotados e capturas), conteúdo do Baú, selvagens pendentes e hora do último surgimento.

