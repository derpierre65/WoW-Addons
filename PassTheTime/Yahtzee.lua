local _, PTT = ...

local Yahtzee = {}
PTT.Yahtzee = Yahtzee

Yahtzee.DICE_COUNT = 5
Yahtzee.MAX_ROLLS = 3
Yahtzee.BONUS_THRESHOLD = 63
Yahtzee.BONUS = 35

-- Upper categories score the sum of their face value, the lower ones follow the rules in Score().
Yahtzee.categories = {
	{ id = "ones", face = 1 },
	{ id = "twos", face = 2 },
	{ id = "threes", face = 3 },
	{ id = "fours", face = 4 },
	{ id = "fives", face = 5 },
	{ id = "sixes", face = 6 },
	{ id = "threeKind", lower = true },
	{ id = "fourKind", lower = true },
	{ id = "fullHouse", lower = true },
	{ id = "smallStraight", lower = true },
	{ id = "largeStraight", lower = true },
	{ id = "yahtzee", lower = true },
	{ id = "chance", lower = true },
}

-- Replaced in tests. Takes the size of the range and returns an index in it.
Yahtzee.random = math.random

local function GetSettings()
	return PTT.database.yahtzee
end

local function Find(id)
	for _, category in ipairs(Yahtzee.categories) do
		if category.id == id then
			return category
		end
	end
end

function Yahtzee.GetName(category)
	return PTT.L["yahtzee_" .. category.id]
end

local function CountFaces(dice)
	local counts = { 0, 0, 0, 0, 0, 0 }
	for _, value in ipairs(dice) do
		counts[value] = counts[value] + 1
	end
	return counts
end

local function Sum(dice)
	local total = 0
	for _, value in ipairs(dice) do
		total = total + value
	end
	return total
end

local function HasRun(counts, length)
	local run = 0
	for face = 1, 6 do
		run = counts[face] > 0 and run + 1 or 0
		if run >= length then
			return true
		end
	end
	return false
end

-- Points the dice are worth in a category, whether or not it is still free.
function Yahtzee.Score(categoryId, dice)
	local category = Find(categoryId)
	local counts = CountFaces(dice)

	if category.face then
		return counts[category.face] * category.face
	end

	local highest, hasPair, hasTriple = 0, false, false
	for face = 1, 6 do
		highest = math.max(highest, counts[face])
		hasPair = hasPair or counts[face] == 2
		hasTriple = hasTriple or counts[face] == 3
	end

	if categoryId == "threeKind" then
		return highest >= 3 and Sum(dice) or 0
	elseif categoryId == "fourKind" then
		return highest >= 4 and Sum(dice) or 0
	elseif categoryId == "fullHouse" then
		return hasPair and hasTriple and 25 or 0
	elseif categoryId == "smallStraight" then
		return HasRun(counts, 4) and 30 or 0
	elseif categoryId == "largeStraight" then
		return HasRun(counts, 5) and 40 or 0
	elseif categoryId == "yahtzee" then
		return highest == Yahtzee.DICE_COUNT and 50 or 0
	end
	return Sum(dice)
end

function Yahtzee.NewGame()
	Yahtzee.game = {
		dice = {},
		held = {},
		scores = {},
		rollsLeft = Yahtzee.MAX_ROLLS,
		turn = 1,
		state = "ready",
	}
	return Yahtzee.game
end

function Yahtzee.Load()
	Yahtzee.NewGame()
end

function Yahtzee.HasRolled()
	return Yahtzee.game.rollsLeft < Yahtzee.MAX_ROLLS
end

function Yahtzee.GetUpperSum()
	local total = 0
	for _, category in ipairs(Yahtzee.categories) do
		if category.face then
			total = total + (Yahtzee.game.scores[category.id] or 0)
		end
	end
	return total
end

function Yahtzee.GetBonus()
	return Yahtzee.GetUpperSum() >= Yahtzee.BONUS_THRESHOLD and Yahtzee.BONUS or 0
end

function Yahtzee.GetTotal()
	local total = Yahtzee.GetBonus()
	for _, points in pairs(Yahtzee.game.scores) do
		total = total + points
	end
	return total
end

-- Returns true when the dice were thrown. The first throw of a turn throws all five.
function Yahtzee.Roll()
	local game = Yahtzee.game
	if game.state == "over" or game.rollsLeft == 0 then
		return false
	end

	if game.state == "ready" then
		game.state = "playing"
		GetSettings().played = GetSettings().played + 1
	end

	for index = 1, Yahtzee.DICE_COUNT do
		if not game.held[index] then
			game.dice[index] = Yahtzee.random(6)
		end
	end
	game.rollsLeft = game.rollsLeft - 1
	return true
end

function Yahtzee.ToggleHold(index)
	local game = Yahtzee.game
	if game.state == "over" or not Yahtzee.HasRolled() or game.rollsLeft == 0 or not game.dice[index] then
		return false
	end
	game.held[index] = not game.held[index] or nil
	return true
end

local function Finish(game)
	local settings = GetSettings()
	local total = Yahtzee.GetTotal()

	game.state = "over"
	game.total = total
	settings.completed = settings.completed + 1
	settings.highScore = math.max(settings.highScore, total)
	if Yahtzee.GetBonus() > 0 then
		settings.bonuses = settings.bonuses + 1
	end
end

-- Returns true when the points were written down. Needs a throw first, and a category that is still free.
function Yahtzee.Choose(categoryId)
	local game = Yahtzee.game
	if game.state ~= "playing" or not Yahtzee.HasRolled() or game.scores[categoryId] or not Find(categoryId) then
		return false
	end

	local points = Yahtzee.Score(categoryId, game.dice)
	game.scores[categoryId] = points
	if categoryId == "yahtzee" and points > 0 then
		GetSettings().yahtzees = GetSettings().yahtzees + 1
	end

	if game.turn == #Yahtzee.categories then
		Finish(game)
	else
		game.turn = game.turn + 1
		game.dice, game.held = {}, {}
		game.rollsLeft = Yahtzee.MAX_ROLLS
	end
	return true
end

PTT.OnInitialize(Yahtzee.Load)
