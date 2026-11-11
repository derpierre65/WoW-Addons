local addonName, PTT = ...

PassTheTime = PTT

local GetMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
PTT.version = GetMetadata and GetMetadata(addonName, "Version")

local DEFAULTS = {
	setupDone = false,
	window = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0, entry = "idle:monster", modelZoom = 1.4, bossZoom = 1 },
	minimap = { angle = 200, hidden = false },
	settings = { miniWidget = false, closeInCombat = true, realmLeaderboard = true, gameSounds = true },
	miniWidget = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 250 },
	game2048 = { score = 0, best = 0, wonShown = false, played = 0, highestTile = 0 },
	hangman = { language = "auto", category = "all", difficulty = "medium", played = 0, won = 0, streak = 0, bestStreak = 0 },
	idle = {
		gold = 0, runGold = 0, lifetimeGold = 0, runTime = 0, totalTime = 0,
		clicks = 0, renown = 0, renownEarned = 0, prestiges = 0,
		unlocked = 1, tierKills = {}, kills = 0, bossKills = 0, groupBossKills = 0, guildBossKills = 0, monsterIndex = 1, monsterDamage = 0,
		allies = {}, upgrades = {}, spells = {}, heroesRevealed = 1, professions = {}, buffs = {},
		buyAmount = 1, autoAdvance = false, lifetimeKills = 0, eventsClaimed = 0,
		goldSpent = 0, bestReward = 0, highestEnemy = 1, sessions = 0, longestSession = 0, worldBonuses = 0,
	},
	minesweeper = { difficulty = "elwynn", played = 0, won = 0, streak = 0, bestStreak = 0, flaglessWins = 0, bestTimes = {}, wonBy = {} },
	memory = { difficulty = "easy", played = 0, won = 0, perfectWins = 0, bestTimes = {}, bestMoves = {}, wonBy = {} },
	sudoku = { difficulty = "easy", played = 0, won = 0, flawlessWins = 0, pureWins = 0, bestTimes = {}, wonBy = {} },
	yahtzee = { completed = 0, highScore = 0, yahtzees = 0, bonuses = 0, played = 0 },
	breakout = { played = 0, highScore = 0, bestLevel = 0, bossesKilled = 0, raidsCleared = 0, flawlessClears = 0 },
	snake = { played = 0, highScore = 0, longest = 0, foodEaten = 0 },
	blocks = { played = 0, highScore = 0, mostLines = 0, linesCleared = 0, fourLineClears = 0, bestLevel = 0 },
	bubbles = { played = 0, highScore = 0, bestLevel = 0, bubblesPopped = 0, biggestDrop = 0 },
	achievements = {},
	guildRanking = {},
	realmRanking = {},
	guildBoss = { week = 0, damage = 0, health = 0, claimed = false, contributions = {} },
}

local function CopyDefaults(target, defaults)
	for key, value in pairs(defaults) do
		if type(value) == "table" then
			if type(target[key]) ~= "table" then
				target[key] = {}
			end
			CopyDefaults(target[key], value)
		elseif target[key] == nil then
			target[key] = value
		end
	end
end

PTT.views = {}
PTT.viewOrder = {}

function PTT.RegisterView(definition)
	PTT.views[definition.id] = definition
	table.insert(PTT.viewOrder, definition.id)
end

local initializeCallbacks = {}

function PTT.OnInitialize(callback)
	table.insert(initializeCallbacks, callback)
end

local loadFrame = CreateFrame("Frame")
loadFrame:RegisterEvent("ADDON_LOADED")
loadFrame:SetScript("OnEvent", function(self, event, loadedAddon)
	if loadedAddon ~= addonName then
		return
	end

	self:UnregisterEvent("ADDON_LOADED")
	-- Only checkable before the defaults fill the database.
	PTT.isNewInstall = PassTheTimeDB == nil
	PassTheTimeDB = PassTheTimeDB or {}
	CopyDefaults(PassTheTimeDB, DEFAULTS)
	PTT.database = PassTheTimeDB

	-- Earlier defaults, replaced by the per-type zoom.
	if PassTheTimeDB.window.modelZoom == 1.8 or PassTheTimeDB.window.modelZoom == 0.9 then
		PassTheTimeDB.window.modelZoom = 1.4
	end

	for _, callback in ipairs(initializeCallbacks) do
		callback()
	end
end)
