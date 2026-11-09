local _, PTT = ...

local Minesweeper = {}
PTT.Minesweeper = Minesweeper

Minesweeper.difficulties = {
	{ id = "elwynn", width = 9, height = 9, mines = 10 },
	{ id = "dustwallow", width = 12, height = 12, mines = 24 },
	{ id = "ungoro", width = 16, height = 12, mines = 36 },
}

-- Replaced in tests.
Minesweeper.random = math.random

local function GetSettings()
	return PTT.database.minesweeper
end

function Minesweeper.GetDifficulty(id)
	for _, difficulty in ipairs(Minesweeper.difficulties) do
		if difficulty.id == id then
			return difficulty
		end
	end
	return Minesweeper.difficulties[1]
end

function Minesweeper.GetName(difficulty)
	return PTT.L["zone_" .. difficulty.id]
end

-- Cell indices run row by row, starting at 1 in the top left corner.
function Minesweeper.GetNeighbors(game, index)
	local neighbors = {}
	local row, column = math.floor((index - 1) / game.width), (index - 1) % game.width
	for rowOffset = -1, 1 do
		for columnOffset = -1, 1 do
			local neighborRow, neighborColumn = row + rowOffset, column + columnOffset
			if (rowOffset ~= 0 or columnOffset ~= 0)
				and neighborRow >= 0 and neighborRow < game.height
				and neighborColumn >= 0 and neighborColumn < game.width then
				neighbors[#neighbors + 1] = neighborRow * game.width + neighborColumn + 1
			end
		end
	end
	return neighbors
end

function Minesweeper.NewGame(difficultyId)
	local settings = GetSettings()
	local difficulty = Minesweeper.GetDifficulty(difficultyId or settings.difficulty)
	settings.difficulty = difficulty.id

	Minesweeper.game = {
		difficulty = difficulty,
		width = difficulty.width,
		height = difficulty.height,
		mines = difficulty.mines,
		mine = {},
		adjacent = {},
		revealed = {},
		flagged = {},
		state = "ready",
		revealedCount = 0,
		flagCount = 0,
		usedFlag = false,
		elapsed = 0,
	}
	return Minesweeper.game
end

function Minesweeper.Load()
	Minesweeper.NewGame()
end

-- The first click and its surroundings stay free, as long as the field is big enough for that.
local function PlaceMines(game, safeIndex)
	local total = game.width * game.height
	local blocked = { [safeIndex] = true }
	for _, neighbor in ipairs(Minesweeper.GetNeighbors(game, safeIndex)) do
		blocked[neighbor] = true
	end

	local candidates = {}
	for index = 1, total do
		if not blocked[index] then
			candidates[#candidates + 1] = index
		end
	end
	if #candidates < game.mines then
		candidates = {}
		for index = 1, total do
			if index ~= safeIndex then
				candidates[#candidates + 1] = index
			end
		end
	end

	for placed = 1, game.mines do
		local pick = placed + Minesweeper.random(#candidates - placed + 1) - 1
		candidates[placed], candidates[pick] = candidates[pick], candidates[placed]
		game.mine[candidates[placed]] = true
	end

	for index = 1, total do
		local count = 0
		for _, neighbor in ipairs(Minesweeper.GetNeighbors(game, index)) do
			if game.mine[neighbor] then
				count = count + 1
			end
		end
		game.adjacent[index] = count
	end
end

local function Lose(game, index)
	local settings = GetSettings()
	game.state = "lost"
	game.hitIndex = index
	settings.streak = 0
end

local function Win(game)
	local settings = GetSettings()
	local id = game.difficulty.id
	local seconds = math.max(1, math.floor(game.elapsed))

	game.state = "won"
	settings.won = settings.won + 1
	settings.streak = settings.streak + 1
	settings.bestStreak = math.max(settings.bestStreak, settings.streak)
	settings.wonBy[id] = (settings.wonBy[id] or 0) + 1
	if not game.usedFlag then
		settings.flaglessWins = settings.flaglessWins + 1
	end
	if not settings.bestTimes[id] or seconds < settings.bestTimes[id] then
		settings.bestTimes[id] = seconds
	end
end

-- Opens one cell and every connected empty area. Returns false when a mine was hit.
local function Open(game, startIndex)
	local stack = { startIndex }
	while #stack > 0 do
		local index = table.remove(stack)
		if not game.revealed[index] and not game.flagged[index] then
			if game.mine[index] then
				Lose(game, index)
				return false
			end

			game.revealed[index] = true
			game.revealedCount = game.revealedCount + 1
			if game.adjacent[index] == 0 then
				for _, neighbor in ipairs(Minesweeper.GetNeighbors(game, index)) do
					if not game.revealed[neighbor] then
						stack[#stack + 1] = neighbor
					end
				end
			end
		end
	end
	return true
end

-- A revealed number with enough banners around it opens all other neighbours.
local function Chord(game, index)
	local flags = 0
	for _, neighbor in ipairs(Minesweeper.GetNeighbors(game, index)) do
		if game.flagged[neighbor] then
			flags = flags + 1
		end
	end
	if game.adjacent[index] == 0 or flags ~= game.adjacent[index] then
		return false
	end

	for _, neighbor in ipairs(Minesweeper.GetNeighbors(game, index)) do
		if not game.flagged[neighbor] and not Open(game, neighbor) then
			return true
		end
	end
	return true
end

-- Returns true when something changed.
function Minesweeper.Reveal(index)
	local game = Minesweeper.game
	if game.state ~= "ready" and game.state ~= "playing" then
		return false
	end

	if game.revealed[index] then
		if not Chord(game, index) then
			return false
		end
	else
		if game.flagged[index] then
			return false
		end

		if game.state == "ready" then
			PlaceMines(game, index)
			game.state = "playing"
			GetSettings().played = GetSettings().played + 1
		end
		Open(game, index)
	end

	if game.state == "playing" and game.revealedCount == game.width * game.height - game.mines then
		Win(game)
	end
	return true
end

function Minesweeper.ToggleFlag(index)
	local game = Minesweeper.game
	if (game.state ~= "ready" and game.state ~= "playing") or game.revealed[index] then
		return false
	end

	if game.flagged[index] then
		game.flagged[index] = nil
		game.flagCount = game.flagCount - 1
	else
		game.flagged[index] = true
		game.flagCount = game.flagCount + 1
		game.usedFlag = true
	end
	return true
end

function Minesweeper.Tick(deltaSeconds)
	local game = Minesweeper.game
	if game.state == "playing" then
		game.elapsed = game.elapsed + deltaSeconds
	end
end

function Minesweeper.GetMinesLeft()
	local game = Minesweeper.game
	return game.mines - game.flagCount
end

PTT.OnInitialize(Minesweeper.Load)
