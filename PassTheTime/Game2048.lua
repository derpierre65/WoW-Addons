local _, PTT = ...

local SIZE = 4
local WIN_TILE = 2048

local Game = {}
PTT.Game2048 = Game

-- Cell indices per line, ordered from the edge the tiles slide towards.
local LINES = { left = {}, right = {}, up = {}, down = {} }
for line = 1, SIZE do
	LINES.left[line], LINES.right[line], LINES.up[line], LINES.down[line] = {}, {}, {}, {}
	for step = 1, SIZE do
		LINES.left[line][step] = (line - 1) * SIZE + step
		LINES.right[line][step] = (line - 1) * SIZE + (SIZE + 1 - step)
		LINES.up[line][step] = (step - 1) * SIZE + line
		LINES.down[line][step] = (SIZE - step) * SIZE + line
	end
end

function Game.NewBoard()
	local board = {}
	for index = 1, SIZE * SIZE do
		board[index] = 0
	end
	return board
end

function Game.AddRandomTile(board, random)
	random = random or math.random
	local empty = {}
	for index = 1, SIZE * SIZE do
		if board[index] == 0 then
			empty[#empty + 1] = index
		end
	end

	if #empty == 0 then
		return false
	end

	board[empty[random(#empty)]] = random() < 0.9 and 2 or 4
	return true
end

local function SlideLine(values)
	local compact = {}
	for _, value in ipairs(values) do
		if value ~= 0 then
			compact[#compact + 1] = value
		end
	end

	local result, gained, position = {}, 0, 1
	while position <= #compact do
		local value = compact[position]
		if compact[position + 1] == value then
			value = value * 2
			gained = gained + value
			position = position + 1
		end
		result[#result + 1] = value
		position = position + 1
	end

	for index = #result + 1, SIZE do
		result[index] = 0
	end

	return result, gained
end

-- Returns a new board, whether anything moved and the points gained.
function Game.Slide(board, direction)
	local lines = LINES[direction]
	local result, moved, totalGained = {}, false, 0

	for _, indices in ipairs(lines) do
		local values = {}
		for step, cell in ipairs(indices) do
			values[step] = board[cell]
		end

		local slid, gained = SlideLine(values)
		totalGained = totalGained + gained

		for step, cell in ipairs(indices) do
			result[cell] = slid[step]
			if slid[step] ~= board[cell] then
				moved = true
			end
		end
	end

	return result, moved, totalGained
end

function Game.CanMove(board)
	for direction in pairs(LINES) do
		local _, moved = Game.Slide(board, direction)
		if moved then
			return true
		end
	end
	return false
end

function Game.HighestTile(board)
	local highest = 0
	for index = 1, SIZE * SIZE do
		highest = math.max(highest, board[index])
	end
	return highest
end

local function SaveState()
	PTT.database.game2048.board = Game.board
	PTT.database.game2048.score = Game.score
	PTT.database.game2048.best = Game.best
	local settings = PTT.database.game2048
	settings.highestTile = math.max(settings.highestTile or 0, Game.HighestTile(Game.board))
end

function Game.Reset(random)
	-- A game counts once it has been played, whether finished or abandoned.
	if (Game.score or 0) > 0 then
		PTT.database.game2048.played = (PTT.database.game2048.played or 0) + 1
	end

	Game.board = Game.NewBoard()
	Game.score = 0
	Game.over = false
	Game.won = false
	Game.AddRandomTile(Game.board, random)
	Game.AddRandomTile(Game.board, random)
	PTT.database.game2048.wonShown = false
	SaveState()
end

function Game.Load()
	local saved = PTT.database.game2048
	Game.best = saved.best or 0

	local valid = type(saved.board) == "table" and #saved.board == SIZE * SIZE
	if not valid then
		Game.Reset()
		return
	end

	Game.board = saved.board
	Game.score = saved.score or 0
	Game.over = not Game.CanMove(Game.board)
	Game.won = Game.HighestTile(Game.board) >= WIN_TILE
	saved.highestTile = math.max(saved.highestTile or 0, Game.HighestTile(Game.board))
end

-- Returns true when the board changed.
function Game.Move(direction, random)
	if Game.over then
		return false
	end

	local board, moved, gained = Game.Slide(Game.board, direction)
	if not moved then
		return false
	end

	Game.AddRandomTile(board, random)
	Game.board = board
	Game.score = Game.score + gained
	Game.best = math.max(Game.best, Game.score)
	Game.over = not Game.CanMove(board)

	if not Game.won and Game.HighestTile(board) >= WIN_TILE then
		Game.won = true
	end

	SaveState()
	return true
end

PTT.OnInitialize(Game.Load)
