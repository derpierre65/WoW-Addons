local _, PTT = ...

local Blocks = {}
PTT.Blocks = Blocks

-- Grid in cells; ROWS * CELL_SIZE matches the Snake field height.
Blocks.COLUMNS = 10
Blocks.ROWS = 20
Blocks.CELL_SIZE = 17
-- Rows above the field a piece may reach while rotating at the top.
Blocks.HIDDEN_ROWS = 2

Blocks.START_INTERVAL = 0.8
Blocks.SPEED_FACTOR = 0.85
Blocks.MIN_INTERVAL = 0.05
Blocks.LINES_PER_LEVEL = 10
Blocks.LOCK_DELAY = 0.5
-- Stops endless sliding on the ground.
Blocks.MAX_LOCK_RESETS = 15
Blocks.LINE_SCORES = { 100, 300, 500, 800 }
Blocks.SOFT_DROP_SCORE = 1
Blocks.HARD_DROP_SCORE = 2

-- Cells inside a size x size box, rotated clockwise around the box center.
Blocks.PIECES = {
	I = { size = 4, cells = { { 0, 1 }, { 1, 1 }, { 2, 1 }, { 3, 1 } } },
	O = { size = 2, cells = { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } } },
	T = { size = 3, cells = { { 1, 0 }, { 0, 1 }, { 1, 1 }, { 2, 1 } } },
	S = { size = 3, cells = { { 1, 0 }, { 2, 0 }, { 0, 1 }, { 1, 1 } } },
	Z = { size = 3, cells = { { 0, 0 }, { 1, 0 }, { 1, 1 }, { 2, 1 } } },
	J = { size = 3, cells = { { 0, 0 }, { 0, 1 }, { 1, 1 }, { 2, 1 } } },
	L = { size = 3, cells = { { 2, 0 }, { 0, 1 }, { 1, 1 }, { 2, 1 } } },
}
Blocks.KINDS = { "I", "O", "T", "S", "Z", "J", "L" }

local ROTATION_KICKS = { { 0, 0 }, { -1, 0 }, { 1, 0 }, { -2, 0 }, { 2, 0 }, { 0, -1 } }

-- Replaced in tests. Returns a number in [0, 1).
Blocks.random = math.random

local function GetSettings()
	return PTT.database.blocks
end

function Blocks.GetInterval()
	return math.max(Blocks.MIN_INTERVAL, Blocks.START_INTERVAL * Blocks.SPEED_FACTOR ^ (Blocks.game.level - 1))
end

function Blocks.GetCells(kind, rotation, x, y)
	local piece = Blocks.PIECES[kind]
	local last = piece.size - 1
	local cells = {}
	for index, cell in ipairs(piece.cells) do
		local cellX, cellY = cell[1], cell[2]
		for _ = 1, rotation % 4 do
			cellX, cellY = last - cellY, cellX
		end
		cells[index] = { x = x + cellX, y = y + cellY }
	end
	return cells
end

function Blocks.GetPieceCells(piece)
	return Blocks.GetCells(piece.kind, piece.rotation, piece.x, piece.y)
end

function Blocks.CanPlace(kind, rotation, x, y)
	local board = Blocks.game.board
	for _, cell in ipairs(Blocks.GetCells(kind, rotation, x, y)) do
		if cell.x < 1 or cell.x > Blocks.COLUMNS or cell.y > Blocks.ROWS or cell.y < 1 - Blocks.HIDDEN_ROWS then
			return false
		end
		if cell.y >= 1 and board[cell.y][cell.x] then
			return false
		end
	end
	return true
end

local function IsGrounded(game)
	local piece = game.piece
	return not Blocks.CanPlace(piece.kind, piece.rotation, piece.x, piece.y + 1)
end

-- Lowest row the current piece would land on, for the ghost preview.
function Blocks.GetDropY()
	local piece = Blocks.game.piece
	local y = piece.y
	while Blocks.CanPlace(piece.kind, piece.rotation, piece.x, y + 1) do
		y = y + 1
	end
	return y
end

local function DrawKind(game)
	if #game.bag == 0 then
		local bag = {}
		for index, kind in ipairs(Blocks.KINDS) do
			bag[index] = kind
		end
		for index = #bag, 2, -1 do
			local swap = math.min(index, math.floor(Blocks.random() * index) + 1)
			bag[index], bag[swap] = bag[swap], bag[index]
		end
		game.bag = bag
	end
	return table.remove(game.bag)
end

local function Finish(game)
	game.state = "lost"
	local settings = GetSettings()
	settings.highScore = math.max(settings.highScore, game.score)
end

local function SpawnPiece(game, kind)
	local piece = Blocks.PIECES[kind]
	local top = piece.size
	for _, cell in ipairs(piece.cells) do
		top = math.min(top, cell[2])
	end

	game.piece = {
		kind = kind,
		rotation = 0,
		x = math.floor((Blocks.COLUMNS - piece.size) / 2) + 1,
		y = 1 - top,
	}
	game.timer = 0
	game.lockTimer = 0
	game.lockResets = 0

	if not Blocks.CanPlace(kind, 0, game.piece.x, game.piece.y) then
		Finish(game)
	end
end

-- Returns the number of cleared rows.
local function ClearRows(game)
	local kept = {}
	for y = Blocks.ROWS, 1, -1 do
		local row = game.board[y]
		local filled = 0
		for x = 1, Blocks.COLUMNS do
			if row[x] then
				filled = filled + 1
			end
		end
		if filled < Blocks.COLUMNS then
			kept[#kept + 1] = row
		end
	end

	local cleared = Blocks.ROWS - #kept
	for index = 1, Blocks.ROWS do
		game.board[Blocks.ROWS - index + 1] = kept[index] or {}
	end
	return cleared
end

local function Lock(game)
	for _, cell in ipairs(Blocks.GetPieceCells(game.piece)) do
		if cell.y < 1 then
			Finish(game)
			return
		end
		game.board[cell.y][cell.x] = game.piece.kind
	end

	local cleared = ClearRows(game)
	if cleared > 0 then
		game.score = game.score + Blocks.LINE_SCORES[cleared] * game.level
		game.lines = game.lines + cleared
		game.level = math.floor(game.lines / Blocks.LINES_PER_LEVEL) + 1

		local settings = GetSettings()
		settings.linesCleared = settings.linesCleared + cleared
		settings.mostLines = math.max(settings.mostLines, game.lines)
		settings.bestLevel = math.max(settings.bestLevel, game.level)
		if cleared == 4 then
			settings.fourLineClears = settings.fourLineClears + 1
		end
	end

	SpawnPiece(game, game.next)
	game.next = DrawKind(game)
end

local function ResetLock(game)
	if game.lockResets < Blocks.MAX_LOCK_RESETS then
		game.lockResets = game.lockResets + 1
		game.lockTimer = 0
	end
end

function Blocks.NewGame()
	local board = {}
	for y = 1, Blocks.ROWS do
		board[y] = {}
	end

	Blocks.game = {
		board = board,
		bag = {},
		score = 0,
		lines = 0,
		level = 1,
		state = "ready",
		counted = false,
	}
	SpawnPiece(Blocks.game, DrawKind(Blocks.game))
	Blocks.game.next = DrawKind(Blocks.game)
end

function Blocks.Load()
	Blocks.NewGame()
end

function Blocks.Move(offset)
	local game = Blocks.game
	local piece = game.piece
	if game.state ~= "playing" or not Blocks.CanPlace(piece.kind, piece.rotation, piece.x + offset, piece.y) then
		return false
	end
	piece.x = piece.x + offset
	ResetLock(game)
	return true
end

function Blocks.Rotate()
	local game = Blocks.game
	local piece = game.piece
	if game.state ~= "playing" then
		return false
	end

	local rotation = (piece.rotation + 1) % 4
	for _, kick in ipairs(ROTATION_KICKS) do
		local x, y = piece.x + kick[1], piece.y + kick[2]
		if Blocks.CanPlace(piece.kind, rotation, x, y) then
			piece.rotation, piece.x, piece.y = rotation, x, y
			ResetLock(game)
			return true
		end
	end
	return false
end

-- On the ground a soft drop locks the piece at once.
function Blocks.SoftDrop()
	local game = Blocks.game
	if game.state ~= "playing" then
		return false
	end
	if IsGrounded(game) then
		Lock(game)
		return true
	end
	game.piece.y = game.piece.y + 1
	game.score = game.score + Blocks.SOFT_DROP_SCORE
	game.timer = 0
	return true
end

function Blocks.HardDrop()
	local game = Blocks.game
	if game.state ~= "playing" then
		return false
	end
	local dropY = Blocks.GetDropY()
	game.score = game.score + (dropY - game.piece.y) * Blocks.HARD_DROP_SCORE
	game.piece.y = dropY
	Lock(game)
	return true
end

function Blocks.Pause()
	local game = Blocks.game
	if game.state ~= "playing" then
		return false
	end
	game.state = "paused"
	return true
end

function Blocks.TogglePause()
	local game = Blocks.game
	if game.state == "paused" then
		game.state = "playing"
		return true
	end
	return Blocks.Pause()
end

-- Any action key starts the round or resumes a pause instead of acting.
function Blocks.Input(action)
	local game = Blocks.game
	if game.state == "lost" then
		return false
	end
	if action == "pause" then
		return Blocks.TogglePause()
	end

	if game.state == "ready" or game.state == "paused" then
		if not game.counted then
			game.counted = true
			local settings = GetSettings()
			settings.played = settings.played + 1
		end
		game.state = "playing"
		return true
	end

	if action == "left" then
		return Blocks.Move(-1)
	elseif action == "right" then
		return Blocks.Move(1)
	elseif action == "rotate" then
		return Blocks.Rotate()
	elseif action == "down" then
		return Blocks.SoftDrop()
	elseif action == "drop" then
		return Blocks.HardDrop()
	end
	return false
end

-- Returns true when the field changed, so the UI only redraws then.
function Blocks.Update(deltaSeconds)
	local game = Blocks.game
	if game.state ~= "playing" then
		return false
	end

	if IsGrounded(game) then
		game.timer = 0
		game.lockTimer = game.lockTimer + deltaSeconds
		if game.lockTimer < Blocks.LOCK_DELAY then
			return false
		end
		Lock(game)
		return true
	end

	game.lockTimer = 0
	game.timer = game.timer + deltaSeconds
	local moved = false
	while game.timer >= Blocks.GetInterval() and not IsGrounded(game) do
		game.timer = game.timer - Blocks.GetInterval()
		game.piece.y = game.piece.y + 1
		moved = true
	end
	return moved
end

PTT.OnInitialize(Blocks.Load)
