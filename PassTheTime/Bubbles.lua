local _, PTT = ...

local Bubbles = {}
PTT.Bubbles = Bubbles

-- Hex grid: shifted rows sit half a bubble to the right and hold one bubble less.
Bubbles.COLUMNS = 12
Bubbles.RADIUS = 12
Bubbles.ROW_HEIGHT = Bubbles.RADIUS * math.sqrt(3)
Bubbles.MAX_ROWS = 13
Bubbles.WIDTH = Bubbles.COLUMNS * 2 * Bubbles.RADIUS
Bubbles.HEIGHT = 340
Bubbles.SHOOTER_X = Bubbles.WIDTH / 2
Bubbles.SHOOTER_Y = Bubbles.HEIGHT - Bubbles.RADIUS - 8

Bubbles.COLOR_COUNT = 6
Bubbles.SHOT_SPEED = 650
Bubbles.MAX_ANGLE = math.rad(80)
-- A bit below a full diameter so shots can slip through narrow gaps.
Bubbles.COLLISION_DISTANCE = 2 * Bubbles.RADIUS * 0.85
Bubbles.MISSES_PER_ROW = 6
Bubbles.MIN_GROUP = 3
Bubbles.POP_SCORE = 10
Bubbles.DROP_SCORE = 20
Bubbles.CLEAR_BONUS = 500

-- Short steps keep a fast shot from passing through a bubble in one frame.
local STEP_LENGTH = Bubbles.RADIUS / 3

-- Replaced in tests. Returns a number in [0, 1).
Bubbles.random = math.random

local function GetSettings()
	return PTT.database.bubbles
end

local function RandomIndex(count)
	return math.min(count, math.floor(Bubbles.random() * count) + 1)
end

function Bubbles.GetStartRows(level)
	return math.min(8, 4 + level)
end

function Bubbles.GetColorCount(level)
	return math.min(Bubbles.COLOR_COUNT, 3 + level)
end

function Bubbles.IsShifted(row)
	return (row + Bubbles.game.parity) % 2 == 0
end

function Bubbles.GetColumnCount(row)
	return Bubbles.IsShifted(row) and Bubbles.COLUMNS - 1 or Bubbles.COLUMNS
end

function Bubbles.GetCellCenter(row, column)
	local x = Bubbles.RADIUS + (column - 1) * 2 * Bubbles.RADIUS
	if Bubbles.IsShifted(row) then
		x = x + Bubbles.RADIUS
	end
	return x, Bubbles.RADIUS + (row - 1) * Bubbles.ROW_HEIGHT
end

function Bubbles.GetCell(row, column)
	local cells = Bubbles.game.grid[row]
	return cells and cells[column]
end

function Bubbles.GetNeighbors(row, column)
	local left = Bubbles.IsShifted(row) and column or column - 1
	local candidates = {
		{ row, column - 1 }, { row, column + 1 },
		{ row - 1, left }, { row - 1, left + 1 },
		{ row + 1, left }, { row + 1, left + 1 },
	}
	local neighbors = {}
	for _, cell in ipairs(candidates) do
		if cell[1] >= 1 and cell[1] <= Bubbles.MAX_ROWS + 1 and cell[2] >= 1 and cell[2] <= Bubbles.GetColumnCount(cell[1]) then
			neighbors[#neighbors + 1] = cell
		end
	end
	return neighbors
end

-- Whether a shot at x, y hits a bubble on the board.
function Bubbles.Touches(x, y)
	local limit = Bubbles.COLLISION_DISTANCE * Bubbles.COLLISION_DISTANCE
	for row = 1, Bubbles.MAX_ROWS + 1 do
		for column = 1, Bubbles.GetColumnCount(row) do
			if Bubbles.GetCell(row, column) then
				local cellX, cellY = Bubbles.GetCellCenter(row, column)
				if (cellX - x) ^ 2 + (cellY - y) ^ 2 < limit then
					return true
				end
			end
		end
	end
	return false
end

local function GetPresentColors(game)
	local present, list = {}, {}
	for row = 1, Bubbles.MAX_ROWS + 1 do
		for _, color in pairs(game.grid[row]) do
			if not present[color] then
				present[color] = true
				list[#list + 1] = color
			end
		end
	end
	table.sort(list)
	return present, list
end

-- Only colors still on the board, so every shot can make a match.
local function PickColor(game)
	local _, list = GetPresentColors(game)
	if #list == 0 then
		return RandomIndex(Bubbles.GetColorCount(game.level))
	end
	return list[RandomIndex(#list)]
end

local function AdvanceAmmo(game)
	local present = GetPresentColors(game)
	game.current = present[game.next] and game.next or PickColor(game)
	game.next = PickColor(game)
end

local function FillRow(game, row)
	local cells = {}
	local colorCount = Bubbles.GetColorCount(game.level)
	for column = 1, Bubbles.GetColumnCount(row) do
		cells[column] = RandomIndex(colorCount)
	end
	return cells
end

local function NewBoard(game)
	game.parity = 0
	game.grid = {}
	game.misses = 0
	for row = 1, Bubbles.MAX_ROWS + 1 do
		game.grid[row] = row <= Bubbles.GetStartRows(game.level) and FillRow(game, row) or {}
	end
	game.next = PickColor(game)
	AdvanceAmmo(game)
end

local function IsBoardEmpty(game)
	for row = 1, Bubbles.MAX_ROWS + 1 do
		if next(game.grid[row]) then
			return false
		end
	end
	return true
end

local function HasBubblesBelowLimit(game)
	return next(game.grid[Bubbles.MAX_ROWS + 1]) ~= nil
end

local function Finish(game)
	game.state = "lost"
	game.shot = nil
	game.effects[#game.effects + 1] = { kind = "lost" }
end

-- Pushes the board down by one new row.
local function AddRow(game)
	game.effects[#game.effects + 1] = { kind = "row" }
	game.parity = 1 - game.parity
	table.insert(game.grid, 1, FillRow(game, 1))
	table.remove(game.grid)
	if HasBubblesBelowLimit(game) then
		Finish(game)
	end
end

local function FindGroup(game, row, column)
	local color = Bubbles.GetCell(row, column)
	local group, visited, queue = {}, {}, { { row, column } }
	visited[row * 100 + column] = true
	while #queue > 0 do
		local cell = table.remove(queue)
		group[#group + 1] = cell
		for _, neighbor in ipairs(Bubbles.GetNeighbors(cell[1], cell[2])) do
			local key = neighbor[1] * 100 + neighbor[2]
			if not visited[key] and Bubbles.GetCell(neighbor[1], neighbor[2]) == color then
				visited[key] = true
				queue[#queue + 1] = neighbor
			end
		end
	end
	return group
end

-- Removes bubbles no longer connected to the top row and returns their count.
-- Every removed bubble is reported in game.effects for the UI animations.
local function DropFloating(game)
	local attached, queue = {}, {}
	for column in pairs(game.grid[1]) do
		attached[100 + column] = true
		queue[#queue + 1] = { 1, column }
	end
	while #queue > 0 do
		local cell = table.remove(queue)
		for _, neighbor in ipairs(Bubbles.GetNeighbors(cell[1], cell[2])) do
			local key = neighbor[1] * 100 + neighbor[2]
			if not attached[key] and Bubbles.GetCell(neighbor[1], neighbor[2]) then
				attached[key] = true
				queue[#queue + 1] = neighbor
			end
		end
	end

	local dropped = 0
	for row = 1, Bubbles.MAX_ROWS + 1 do
		for column in pairs(game.grid[row]) do
			if not attached[row * 100 + column] then
				local x, y = Bubbles.GetCellCenter(row, column)
				game.effects[#game.effects + 1] = { kind = "drop", x = x, y = y, color = game.grid[row][column] }
				game.grid[row][column] = nil
				dropped = dropped + 1
			end
		end
	end
	return dropped
end

-- Nearest free cell that hangs from the top or touches a bubble.
local function FindSnapCell(game, x, y)
	local bestRow, bestColumn, bestDistance
	for row = 1, Bubbles.MAX_ROWS + 1 do
		for column = 1, Bubbles.GetColumnCount(row) do
			if not Bubbles.GetCell(row, column) then
				local attached = row == 1
				if not attached then
					for _, neighbor in ipairs(Bubbles.GetNeighbors(row, column)) do
						if Bubbles.GetCell(neighbor[1], neighbor[2]) then
							attached = true
							break
						end
					end
				end
				if attached then
					local cellX, cellY = Bubbles.GetCellCenter(row, column)
					local distance = (cellX - x) ^ 2 + (cellY - y) ^ 2
					if not bestDistance or distance < bestDistance then
						bestRow, bestColumn, bestDistance = row, column, distance
					end
				end
			end
		end
	end
	return bestRow, bestColumn
end

local function Resolve(game, row, column, color)
	game.grid[row][column] = color
	game.revision = game.revision + 1
	local settings = GetSettings()

	local group = FindGroup(game, row, column)
	if #group >= Bubbles.MIN_GROUP then
		local impactX, impactY = Bubbles.GetCellCenter(row, column)
		for _, cell in ipairs(group) do
			local x, y = Bubbles.GetCellCenter(cell[1], cell[2])
			game.effects[#game.effects + 1] = {
				kind = "pop", x = x, y = y, color = color,
				distance = math.sqrt((x - impactX) ^ 2 + (y - impactY) ^ 2),
			}
			game.grid[cell[1]][cell[2]] = nil
		end
		local dropped = DropFloating(game)
		local points = #group * Bubbles.POP_SCORE + dropped * Bubbles.DROP_SCORE
		game.score = game.score + points
		game.effects[#game.effects + 1] = { kind = "score", x = impactX, y = impactY, points = points }
		settings.bubblesPopped = settings.bubblesPopped + #group + dropped
		settings.biggestDrop = math.max(settings.biggestDrop, dropped)
	elseif HasBubblesBelowLimit(game) then
		Finish(game)
	else
		game.effects[#game.effects + 1] = { kind = "land" }
		game.misses = game.misses + 1
		if game.misses >= Bubbles.MISSES_PER_ROW then
			game.misses = 0
			AddRow(game)
		end
	end

	if game.state ~= "lost" then
		if IsBoardEmpty(game) then
			local bonus = Bubbles.CLEAR_BONUS * game.level
			game.score = game.score + bonus
			game.level = game.level + 1
			game.effects[#game.effects + 1] = { kind = "level", level = game.level, points = bonus }
			settings.bestLevel = math.max(settings.bestLevel, game.level)
			NewBoard(game)
		else
			AdvanceAmmo(game)
		end
	end
	settings.highScore = math.max(settings.highScore, game.score)
end

function Bubbles.NewGame()
	Bubbles.game = {
		level = 1,
		score = 0,
		angle = 0,
		state = "ready",
		counted = false,
		revision = 0,
		-- Consumed and cleared by the UI.
		effects = {},
	}
	NewBoard(Bubbles.game)
end

function Bubbles.Load()
	Bubbles.NewGame()
end

function Bubbles.Aim(angle)
	Bubbles.game.angle = math.max(-Bubbles.MAX_ANGLE, math.min(Bubbles.MAX_ANGLE, angle))
end

function Bubbles.Shoot()
	local game = Bubbles.game
	if game.state == "lost" or game.shot then
		return false
	end

	if not game.counted then
		game.counted = true
		local settings = GetSettings()
		settings.played = settings.played + 1
		settings.bestLevel = math.max(settings.bestLevel, game.level)
	end
	game.state = "playing"

	game.shot = {
		x = Bubbles.SHOOTER_X,
		y = Bubbles.SHOOTER_Y,
		directionX = math.sin(game.angle),
		directionY = -math.cos(game.angle),
		color = game.current,
	}
	game.current = nil
	return true
end

function Bubbles.Swap()
	local game = Bubbles.game
	if game.state == "lost" or game.shot then
		return false
	end
	game.current, game.next = game.next, game.current
	return true
end

-- Returns true while a shot is in flight, so the UI redraws it.
function Bubbles.Update(deltaSeconds)
	local game = Bubbles.game
	local shot = game.shot
	if not shot or game.state ~= "playing" then
		return false
	end

	local left, right = Bubbles.RADIUS, Bubbles.WIDTH - Bubbles.RADIUS
	local distance = Bubbles.SHOT_SPEED * deltaSeconds
	while distance > 0 and game.shot do
		local step = math.min(distance, STEP_LENGTH)
		distance = distance - step
		shot.x = shot.x + shot.directionX * step
		shot.y = shot.y + shot.directionY * step

		if shot.x < left or shot.x > right then
			local wall = shot.x < left and left or right
			shot.x = 2 * wall - shot.x
			shot.directionX = -shot.directionX
			game.effects[#game.effects + 1] = { kind = "bounce" }
		end

		if shot.y <= Bubbles.RADIUS or Bubbles.Touches(shot.x, shot.y) then
			game.shot = nil
			local row, column = FindSnapCell(game, shot.x, shot.y)
			if row then
				Resolve(game, row, column, shot.color)
			else
				AdvanceAmmo(game)
			end
		end
	end
	return true
end

PTT.OnInitialize(Bubbles.Load)
