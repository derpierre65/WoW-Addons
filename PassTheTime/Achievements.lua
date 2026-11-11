local _, PTT = ...

local Achievements = {}
PTT.Achievements = Achievements

local CHECK_INTERVAL = 5

local function GetIdle()
	return PTT.database.idle
end

local function HighestProfessionLevel()
	local highest = 0
	for _, definition in ipairs(PTT.Idle.definitions.profession) do
		highest = math.max(highest, PTT.Idle.GetOwned("profession", definition.id))
	end
	return highest
end

local function TotalAllies()
	local total = 0
	for _, count in pairs(GetIdle().allies) do
		total = total + count
	end
	return total
end

local function HighestTile()
	local game = PTT.Game2048
	return game.board ~= nil and game.HighestTile(game.board) or 0
end

local function FormatTime(seconds)
	return PTT.FormatDuration(seconds)
end

-- value() is the current progress towards target; the achievement is earned once value >= target.
-- Name and description are achievement_<id> and achievementDesc_<id> in Localization.lua; a series fills
-- the target into its achievementSeries_<prefix> template instead (descriptionTemplate).
local function Define(id, category, points, value, target, format, descriptionTemplate)
	return {
		id = id,
		category = category,
		points = points,
		value = value,
		target = target,
		format = format,
		descriptionTemplate = descriptionTemplate,
		check = function()
			return value() >= target
		end,
	}
end

Achievements.categories = { "combat", "wealth", "clicking", "progress", "minigames" }

local SHORT_SUFFIXES = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" } }

-- Grouped by the locale's thousands separator; round millions and above are abbreviated.
local function NumberText(value)
	for _, entry in ipairs(SHORT_SUFFIXES) do
		if value >= entry[1] and value % entry[1] == 0 then
			return string.format("%d", value / entry[1]) .. entry[2]
		end
	end

	local separator = PTT.L.thousandsSeparator
	local grouped = string.format("%d", value):reverse():gsub("(%d%d%d)", "%1" .. separator):reverse()
	if grouped:sub(1, 1) == separator then
		grouped = grouped:sub(2)
	end
	return grouped
end

-- One achievement per step { target, points [, id [, true when it has its own description]] }.
local function Series(prefix, category, value, steps, format)
	local list = {}
	for _, step in ipairs(steps) do
		list[#list + 1] = Define(
			step[3] or (prefix .. string.format("%d", step[1])),
			category,
			step[2],
			value,
			step[1],
			format,
			not step[4] and ("achievementSeries_" .. prefix) or nil
		)
	end
	return list
end

local function GetUnlockedTier()
	return GetIdle().unlocked
end

local function GetLifetimeKills()
	return GetIdle().lifetimeKills
end

local function GetLifetimeGold()
	return GetIdle().lifetimeGold
end

local function GetClicks()
	return GetIdle().clicks
end

Achievements.definitions = {}

local function AddAll(list)
	for _, definition in ipairs(list) do
		Achievements.definitions[#Achievements.definitions + 1] = definition
	end
end

AddAll(Series("kills", "combat", GetLifetimeKills, {
	{ 1, 5, "kills1", true },
	{ 100, 10 },
	{ 500, 10 },
	{ 1000, 25 },
	{ 2500, 25 },
	{ 5000, 25 },
	{ 10000, 50 },
	{ 100000, 75 },
	{ 250000, 100 },
	{ 500000, 150 },
	{ 1000000, 250 },
}))

AddAll(Series("tier", "combat", GetUnlockedTier, {
	{ 10, 10 },
	{ 20, 10 },
	{ 30, 25 },
	{ 40, 25 },
	{ 50, 25 },
	{ 60, 50 },
	{ 70, 50 },
}))

AddAll(Series("gold", "wealth", GetLifetimeGold, {
	{ 1e3, 5, "gold1k" },
	{ 1e4, 5 },
	{ 2.5e4, 10 },
	{ 5e4, 10 },
	{ 1e5, 10 },
	{ 2.5e5, 25 },
	{ 5e5, 25 },
	{ 1e6, 25, "gold1m" },
	{ 1e7, 50 },
	{ 1e8, 50 },
	{ 1e9, 75, "gold1b" },
	{ 1e12, 100, "gold1t" },
}, PTT.FormatNumber))

AddAll(Series("clicks", "clicking", GetClicks, {
	{ 100, 5 },
	{ 500, 5 },
	{ 1000, 10 },
	{ 5000, 10 },
	{ 10000, 25 },
	{ 25000, 25 },
	{ 50000, 50 },
	{ 100000, 75 },
}))

AddAll({
	Define("allies50", "progress", 10, TotalAllies, 50),
	Define("allies250", "progress", 25, TotalAllies, 250),
	Define("grandmaster", "progress", 25, HighestProfessionLevel, PTT.Idle.PROFESSION_MAX_LEVEL),
	Define("prestige1", "progress", 10, function() return GetIdle().prestiges end, 1),
	Define("prestige5", "progress", 25, function() return GetIdle().prestiges end, 5),
	Define("events10", "progress", 10, function() return GetIdle().eventsClaimed end, 10),
	Define("time1h", "progress", 10, function() return GetIdle().totalTime end, 3600, FormatTime),
	Define("time10h", "progress", 25, function() return GetIdle().totalTime end, 36000, FormatTime),
	Define("group", "progress", 10, function() return PTT.Idle.groupBonus > 0 and 1 or 0 end, 1),

	Define("tile256", "minigames", 5, HighestTile, 256),
	Define("tile512", "minigames", 10, HighestTile, 512),
	Define("tile1024", "minigames", 15, HighestTile, 1024),
	Define("tile2048", "minigames", 25, function() return PTT.Game2048.won == true and 1 or 0 end, 1),
	Define("hangman1", "minigames", 5, function() return PTT.database.hangman.won end, 1),
	Define("hangman10", "minigames", 10, function() return PTT.database.hangman.won end, 10),

	Define("mines1", "minigames", 5, function() return PTT.database.minesweeper.won end, 1),
	Define("mines10", "minigames", 10, function() return PTT.database.minesweeper.won end, 10),
	Define("minesFlagless", "minigames", 15, function() return PTT.database.minesweeper.flaglessWins end, 1),
	Define("minesUngoro", "minigames", 15, function() return PTT.database.minesweeper.wonBy.ungoro or 0 end, 1),
	Define("minesSpeed", "minigames", 15, function()
		local bestTime = PTT.database.minesweeper.bestTimes.elwynn
		return bestTime and bestTime <= 30 and 1 or 0
	end, 1),

	Define("memory1", "minigames", 5, function() return PTT.database.memory.won end, 1),
	Define("memory10", "minigames", 10, function() return PTT.database.memory.won end, 10),
	Define("memoryHard", "minigames", 15, function() return PTT.database.memory.wonBy.hard or 0 end, 1),
	Define("memoryPerfect", "minigames", 15, function() return PTT.database.memory.perfectWins end, 1),
	Define("memorySpeed", "minigames", 10, function()
		local bestTime = PTT.database.memory.bestTimes.medium
		return bestTime and bestTime <= 120 and 1 or 0
	end, 1),

	Define("sudoku1", "minigames", 5, function() return PTT.database.sudoku.won end, 1),
	Define("sudoku10", "minigames", 10, function() return PTT.database.sudoku.won end, 10),
	Define("sudokuHard", "minigames", 15, function() return PTT.database.sudoku.wonBy.hard or 0 end, 1),
	Define("sudokuExpert", "minigames", 25, function() return PTT.database.sudoku.wonBy.expert or 0 end, 1),
	Define("sudokuFlawless", "minigames", 15, function() return PTT.database.sudoku.flawlessWins end, 1),
	Define("sudokuPure", "minigames", 15, function() return PTT.database.sudoku.pureWins end, 1),

	Define("yahtzee1", "minigames", 10, function() return PTT.database.yahtzee.yahtzees end, 1),
	Define("yahtzeeGames10", "minigames", 10, function() return PTT.database.yahtzee.completed end, 10),
	Define("yahtzeeBonus", "minigames", 10, function() return PTT.database.yahtzee.bonuses end, 1),
	Define("yahtzeeScore200", "minigames", 15, function() return PTT.database.yahtzee.highScore end, 200),
	Define("yahtzeeScore300", "minigames", 25, function() return PTT.database.yahtzee.highScore end, 300),

	Define("breakoutBoss1", "minigames", 5, function() return PTT.database.breakout.bossesKilled end, 1),
	Define("breakoutBoss25", "minigames", 15, function() return PTT.database.breakout.bossesKilled end, 25),
	Define("breakoutRaid3", "minigames", 10, function() return PTT.database.breakout.bestLevel end, 3),
	Define("breakoutFlawless", "minigames", 15, function() return PTT.database.breakout.flawlessClears end, 1),
	Define("breakoutScore", "minigames", 10, function() return PTT.database.breakout.highScore end, 5000),
	Define("breakoutClear", "minigames", 25, function() return PTT.database.breakout.raidsCleared end, 1),

	Define("snake1", "minigames", 5, function() return PTT.database.snake.played end, 1),
	Define("snakeLength25", "minigames", 10, function() return PTT.database.snake.longest end, 25),
	Define("snakeScore500", "minigames", 15, function() return PTT.database.snake.highScore end, 500),

	Define("blocks1", "minigames", 5, function() return PTT.database.blocks.played end, 1),
	Define("blocksFourLines", "minigames", 10, function() return PTT.database.blocks.fourLineClears end, 1),
	Define("blocksScore10000", "minigames", 15, function() return PTT.database.blocks.highScore end, 10000),

	Define("bubbles1", "minigames", 5, function() return PTT.database.bubbles.played end, 1),
	Define("bubblesDrop10", "minigames", 10, function() return PTT.database.bubbles.biggestDrop end, 10),
	Define("bubblesLevel3", "minigames", 15, function() return PTT.database.bubbles.bestLevel end, 3),
})

-- Per hero: one spell bought, and all of its spells bought. Name and description are templates filled with the hero name.
local function HeroSpellAchievements()
	local list = {}
	for _, hero in ipairs(PTT.Idle.definitions.ally) do
		local function GetSpellCount()
			return PTT.Idle.GetSpellCount(hero.id)
		end

		local first = Define("heroSpell_" .. hero.id, "progress", 5, GetSpellCount, 1)
		first.nameTemplate = "achievementHeroSpellFirst"
		first.descriptionTemplate = "achievementHeroSpellFirstDesc"

		local all = Define("heroSpellAll_" .. hero.id, "progress", 10, GetSpellCount, #PTT.Idle.spells[hero.id])
		all.nameTemplate = "achievementHeroSpellAll"
		all.descriptionTemplate = "achievementHeroSpellAllDesc"

		for _, definition in ipairs({ first, all }) do
			definition.textArgument = function()
				return PTT.L[hero.nameKey]
			end
			list[#list + 1] = definition
		end
	end
	return list
end

AddAll(HeroSpellAchievements())

local unlockListeners = {}

function Achievements.OnUnlock(listener)
	unlockListeners[#unlockListeners + 1] = listener
end

function Achievements.GetName(definition)
	if definition.nameTemplate then
		return string.format(PTT.L[definition.nameTemplate], definition.textArgument())
	end
	return PTT.L["achievement_" .. definition.id]
end

function Achievements.GetDescription(definition)
	if definition.textArgument then
		return string.format(PTT.L[definition.descriptionTemplate], definition.textArgument())
	end
	if definition.descriptionTemplate then
		return string.format(PTT.L[definition.descriptionTemplate], NumberText(definition.target))
	end
	return PTT.L["achievementDesc_" .. definition.id]
end

function Achievements.IsUnlocked(definition)
	return PTT.database.achievements[definition.id] ~= nil
end

-- Unlock time as stored by Check(), or nil.
function Achievements.GetUnlockTime(definition)
	return PTT.database.achievements[definition.id]
end

-- Returns the capped current value and the target.
function Achievements.GetProgress(definition)
	return math.min(definition.value(), definition.target), definition.target
end

function Achievements.CountUnlocked()
	local count = 0
	for _, definition in ipairs(Achievements.definitions) do
		if Achievements.IsUnlocked(definition) then
			count = count + 1
		end
	end
	return count
end

function Achievements.GetPoints()
	local earned, total = 0, 0
	for _, definition in ipairs(Achievements.definitions) do
		total = total + definition.points
		if Achievements.IsUnlocked(definition) then
			earned = earned + definition.points
		end
	end
	return earned, total
end

function Achievements.Check()
	for _, definition in ipairs(Achievements.definitions) do
		if not Achievements.IsUnlocked(definition) and definition.check() then
			PTT.database.achievements[definition.id] = time()
			for _, listener in ipairs(unlockListeners) do
				listener(definition)
			end
		end
	end
end

local elapsed = 0

function Achievements.Tick(dt)
	elapsed = elapsed + dt
	if elapsed >= CHECK_INTERVAL then
		elapsed = 0
		Achievements.Check()
	end
end
