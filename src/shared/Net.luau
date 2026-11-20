--[[
	Net (ReplicatedStorage/Net)
	Contrato centralizado de RemoteEvents e RemoteFunctions do projeto.
	Todos os Remotes continuam em ReplicatedStorage/Remotes para 100% de compatibilidade.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes")

export type RemoteEventName =
	"StartBattle"     -- Server -> Client: inicia batalha na arena (Camera, Models, State)
	| "SubmitAction"  -- Client -> Server: envia acao do turno (Move, Switch, Item, Flee, Replace)
	| "BattleUpdate"  -- Server -> Client: envia evento do turno (Event, Await, Error)
	| "BattleEnd"     -- Server -> Client: fim da batalha (Result, Reason)
	| "ProfileUpdated"-- Server -> Client: perfil do jogador atualizado
	| "TowerOpen"     -- Server -> Client: abre UI da Torre ao entrar no gatilho
	| "TowerClose"    -- Client -> Server: fecha UI da Torre
	| "Announce"      -- Server -> All Clients: anuncio global (Lendario/Brilhante invocado)
	| "Notify"        -- Server -> Client: toast / notificacao na tela
	| "PvPInvite"     -- Server -> Client: convite de desafio PvP

export type RemoteFunctionName =
	"GetProfile"      -- Client -> Server: retorna snapshot do perfil salvo
	| "ChooseStarter" -- Client -> Server: escolhe personagem inicial
	| "SetActiveMoves"-- Client -> Server: define os 4 golpes ativos de um personagem
	| "TowerStart"    -- Client -> Server: inicia corrida na Torre (Facil/Medio/Dificil/Infinito)
	| "TowerBoard"    -- Client -> Server: consulta placar da Torre
	| "Summon"        -- Client -> Server: invoca 1 ou 10 no Portal Comum/Premium
	| "SummonBanner"  -- Client -> Server: consulta banner e taxas atuais
	| "SellDuplicate" -- Client -> Server: vende personagem repetido por gold
	| "Fuse"          -- Client -> Server: funde 3 repetidos em +1 estrela
	| "UseItem"       -- Client -> Server: usa item fora de batalha (Pocao, Reviver)
	| "BuyItem"       -- Client -> Server: compra item na loja com gold
	| "BuyBenefit"    -- Client -> Server: compra beneficio com gemas ou Robux
	| "BaseSetState"  -- Client -> Server: alterna personagem na base (Passeando / Minerando)
	| "BaseCollect"   -- Client -> Server: coleta gold e minerio acumulados na base
	| "BaseUpgrade"   -- Client -> Server: melhora vagas de mineracao da base com gold
	| "SellOre"       -- Client -> Server: converte minerio em gemas (respeitando teto diario de 50)
	| "BaseTeleport"  -- Client -> Server: teleporta jogador para sua base ou praca
	| "PvPChallenge"  -- Client -> Server: envia convite de PvP para outro jogador
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
