local _, PTT = ...

local Memory = {}
PTT.Memory = Memory

Memory.MISMATCH_DELAY = 0.9

Memory.difficulties = {
	{ id = "easy", pairs = 9 },
	{ id = "medium", pairs = 16 },
	{ id = "hard", pairs = 24 },
}

local function Icons(prefix, list)
	local icons = {}
	for _, name in ipairs(list) do
		icons[#icons + 1] = "Interface\\Icons\\" .. prefix .. name
	end
	return icons
end

local CLASS_ICONS = Icons("ClassIcon_", { "Warrior", "Paladin", "Hunter", "Rogue", "Priest", "Shaman", "Mage", "Warlock", "Druid" })

local PROFESSION_ICONS = Icons("", {
	"Trade_Alchemy", "Trade_BlackSmithing", "Trade_Engraving", "Trade_Engineering", "Trade_Herbalism", "Trade_Mining",
	"INV_Misc_Pelt_Wolf_01", "Trade_Tailoring", "INV_Misc_ArmorKit_17", "INV_Misc_Food_15", "Spell_Holy_SealOfSacrifice", "Trade_Fishing",
})

local SPELL_ICONS = Icons("", {
	"Spell_Fire_FlameBolt", "Spell_Frost_FrostBolt02", "Spell_Nature_Lightning", "Spell_Shadow_ShadowBolt",
	"Spell_Holy_HolyBolt", "Spell_Nature_HealingTouch", "Spell_Holy_PowerWordShield", "Spell_Frost_FrostNova",
	"Spell_Nature_Polymorph", "Spell_Arcane_StarFire", "Spell_Nature_Rejuvenation", "Ability_Stealth",
	"Spell_Nature_WispSplode",
})

local function Combine(...)
	local combined = {}
	for _, list in ipairs({ ... }) do
		for _, icon in ipairs(list) do
			combined[#combined + 1] = icon
		end
	end
	return combined
end

-- Every symbol is used for one pair at most, so the biggest board needs fewer pairs than there are symbols.
Memory.symbols = Combine(CLASS_ICONS, PROFESSION_ICONS, SPELL_ICONS)

-- Different file names can show the same picture, so symbols are compared by what the game loads for them.
local function ResolveIcon(path)
	if not Memory.probe and UIParent and UIParent.CreateTexture then
		Memory.probe = UIParent:CreateTexture()
	end
	if not Memory.probe then
		return path
	end

	Memory.probe:SetTexture(path)
	return Memory.probe:GetTexture() or path
end

Memory.ResolveIcon = ResolveIcon

-- The symbols without any that look like an earlier one.
function Memory.GetUniqueSymbols()
	if not Memory.uniqueSymbols then
		local seen, list = {}, {}
		for _, symbol in ipairs(Memory.symbols) do
			local picture = ResolveIcon(symbol)
			if not seen[picture] then
				seen[picture] = true
				list[#list + 1] = symbol
			end
		end
		Memory.uniqueSymbols = list
	end
	return Memory.uniqueSymbols
end

-- Replaced in tests. Takes the size of the range and returns an index in it.
Memory.random = math.random

local function GetSettings()
	return PTT.database.memory
end

local function Find(list, id)
	for _, entry in ipairs(list) do
		if entry.id == id then
			return entry
		end
	end
	return list[1]
end

function Memory.GetDifficulty(id)
	return Find(Memory.difficulties, id)
end

function Memory.GetName(definition)
	return PTT.L["difficulty_" .. definition.id]
end

-- Small boards sit in six columns, big ones in eight.
function Memory.GetColumns(cardCount)
	return cardCount <= 20 and 6 or 8
end

local function Shuffle(list)
	for index = #list, 2, -1 do
		local other = Memory.random(index)
		list[index], list[other] = list[other], list[index]
	end
	return list
end

function Memory.NewGame(difficultyId)
	local settings = GetSettings()
	local difficulty = Memory.GetDifficulty(difficultyId or settings.difficulty)
	settings.difficulty = difficulty.id

	local pool = {}
	for _, symbol in ipairs(Memory.GetUniqueSymbols()) do
		pool[#pool + 1] = symbol
	end
	Shuffle(pool)

	local pairCount = math.min(difficulty.pairs, #pool)
	local symbols = {}
	for index = 1, pairCount do
		symbols[#symbols + 1] = pool[index]
		symbols[#symbols + 1] = pool[index]
	end
	Shuffle(symbols)

	Memory.game = {
		difficulty = difficulty,
		pairs = pairCount,
		symbols = symbols,
		columns = Memory.GetColumns(#symbols),
		faceUp = {},
		matched = {},
		state = "ready",
		moves = 0,
		mismatches = 0,
		pairsFound = 0,
		elapsed = 0,
	}
	return Memory.game
end

function Memory.Load()
	Memory.NewGame()
end

local function ResolvePending(game)
	if game.pending then
		game.faceUp[game.pending[1]] = nil
		game.faceUp[game.pending[2]] = nil
		game.pending = nil
	end
end

local function Win(game)
	local settings = GetSettings()
	local id = game.difficulty.id
	local seconds = math.max(1, math.floor(game.elapsed))

	game.state = "won"
	settings.won = settings.won + 1
	settings.wonBy[id] = (settings.wonBy[id] or 0) + 1
	if game.mismatches == 0 then
		settings.perfectWins = settings.perfectWins + 1
	end
	if not settings.bestTimes[id] or seconds < settings.bestTimes[id] then
		settings.bestTimes[id] = seconds
	end
	if not settings.bestMoves[id] or game.moves < settings.bestMoves[id] then
		settings.bestMoves[id] = game.moves
	end
end

-- Returns true when the card was turned. Turning a card while a wrong pair is still showing hides that pair first.
function Memory.Flip(index)
	local game = Memory.game
	if game.state == "won" or game.matched[index] or game.faceUp[index] then
		return false
	end
	ResolvePending(game)

	game.faceUp[index] = true
	if game.state == "ready" then
		game.state = "playing"
		GetSettings().played = GetSettings().played + 1
	end

	if not game.firstPick then
		game.firstPick = index
		return true
	end

	local first = game.firstPick
	game.firstPick = nil
	game.moves = game.moves + 1

	if game.symbols[first] == game.symbols[index] then
		game.matched[first], game.matched[index] = true, true
		game.pairsFound = game.pairsFound + 1
		if game.pairsFound == game.pairs then
			Win(game)
		end
	else
		game.mismatches = game.mismatches + 1
		game.pending = { first, index }
		game.pendingTimer = Memory.MISMATCH_DELAY
	end
	return true
end

function Memory.Tick(deltaSeconds)
	local game = Memory.game
	if game.state ~= "playing" then
		return
	end

	game.elapsed = game.elapsed + deltaSeconds
	if game.pending then
		game.pendingTimer = game.pendingTimer - deltaSeconds
		if game.pendingTimer <= 0 then
			ResolvePending(game)
		end
	end
end

PTT.OnInitialize(Memory.Load)
