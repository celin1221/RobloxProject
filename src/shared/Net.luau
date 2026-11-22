--[[
	Net (ReplicatedStorage/Net)
	Contrato centralizado de RemoteEvents e RemoteFunctions do projeto.
	Todos os Remotes continuam em ReplicatedStorage/Remotes para 100% de compatibilidade.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes")

export type RemoteEventName =
	"StartBattle"     -- Server -> Client: inicia batalha na arena (Camera, Models, SlotModels, State)
	| "SubmitAction"  -- Client -> Server: envia acao do turno (Move, Switch, Item, Flee, Replace, Double)
	| "BattleUpdate"  -- Server -> Client: envia evento do turno (Event, Await, Error)
	| "BattleEnd"     -- Server -> Client: fim da batalha (Result, Reason)
	| "ProfileUpdated"-- Server -> Client: perfil do jogador atualizado
	| "TowerOpen"     -- Server -> Client: abre UI da Torre ao entrar no gatilho
	| "TowerClose"    -- Client -> Server: fecha UI da Torre
	| "Announce"      -- Server -> All Clients: anuncio global (Lendario/Brilhante invocado)
	| "Notify"        -- Server -> Client: toast / notificacao na tela
	| "PvPInvite"     -- Server -> Client: convite de desafio PvP (inclui Format: "1x1" | "2x2")
	| "TrainingOpen"  -- Server -> Client: abre tela da Maquina de Treinamento pela capsula 3D

export type RemoteFunctionName =
	"GetProfile"      -- Client -> Server: retorna snapshot do perfil salvo
	| "ChooseStarter" -- Client -> Server: escolhe personagem inicial
	| "SetActiveMoves"-- Client -> Server: define os 4 golpes ativos de um personagem
	| "TowerStart"    -- Client -> Server: inicia corrida na Torre (1x1/2x2), Ginasio de Anime ou Modo Treino
	| "TowerBoard"    -- Client -> Server: consulta placar da Torre (format: "1x1" | "2x2") e status dos Ginasios
	| "Summon"        -- Client -> Server: invoca 1, 3 ou 10 no Portal Comum/Premium com painel (bannerId)
	| "SummonBanner"  -- Client -> Server: consulta destaque e elenco do painel (portalId, bannerId)
	| "SellDuplicate" -- Client -> Server: vende personagem repetido por gold
	| "Fuse"          -- Client -> Server: funde 3 repetidos em +1 estrela
	| "UseItem"       -- Client -> Server: usa item fora de batalha (Pocao, Reviver)
	| "BuyItem"       -- Client -> Server: compra item na loja com gold
	| "BuyBenefit"    -- Client -> Server: compra beneficio com gemas ou Robux
	| "BaseSetState"  -- Client -> Server: alterna personagem na base (Passeando / Minerando)
	| "BaseCollect"   -- Client -> Server: coleta gold e minerio acumulados na base
	| "BaseUpgrade"   -- Client -> Server: melhora vagas de mineracao da base com gold
	| "BaseUpgradeMining" -- Client -> Server: sobe nivel da Mineracao (libera minerios de treino)
	| "TrainingStart" -- Client -> Server: inicia sessao de treino na capsula
	| "TrainingClaim" -- Client -> Server: conclui e aplica ganho de treino quando terminado
	| "TrainingCancel"-- Client -> Server: cancela treino ativo na capsula com reembolso parcial
	| "TrainingUpgrade" -- Client -> Server: melhora eficiencia da Maquina de Treinamento com gold
	| "SellOre"       -- Client -> Server: converte minerio em gemas (respeitando teto diario de 50)
	| "BaseTeleport"  -- Client -> Server: teleporta jogador para sua base ou praca
	| "PvPChallenge"  -- Client -> Server: envia convite de PvP para outro jogador (targetUserId, format: "1x1" | "2x2")
	| "PvPRespond"    -- Client -> Server: aceita ou recusa convite de PvP
	| "PvPCancel"     -- Client -> Server: cancela convite de PvP
	| "Rewards"       -- Client -> Server: coleta login diario, bau de tempo, missoes ou codigos
	| "SaveSettings"  -- Client -> Server: salva configuracoes do cliente (som, qualidade baixa, etc.)

local Net = {}
Net.Folder = RemotesFolder

function Net.Event(name: RemoteEventName): RemoteEvent
	return RemotesFolder:WaitForChild(name) :: RemoteEvent
end

function Net.Function(name: RemoteFunctionName): RemoteFunction
	return RemotesFolder:WaitForChild(name) :: RemoteFunction
end

return Net
