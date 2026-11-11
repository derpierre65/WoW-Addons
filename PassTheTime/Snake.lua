local _, PTT = ...

local Snake = {}
PTT.Snake = Snake

-- Grid in cells; the UI draws CELL_SIZE pixels per cell, the same field size as Breakout.
Snake.COLUMNS = 24
Snake.ROWS = 17
Snake.CELL_SIZE = 20

Snake.START_LENGTH = 3
Snake.FOOD_SCORE = 10
Snake.START_INTERVAL = 0.16
Snake.INTERVAL_PER_FOOD = 0.003
Snake.MIN_INTERVAL = 0.06
-- Lets a quick double turn (e.g. up then left) land on two consecutive steps.
Snake.MAX_QUEUED_TURNS = 2

Snake.DIRECTIONS = {
	up = { 0, -1 },
	down = { 0, 1 },
	left = { -1, 0 },
	right = { 1, 0 },
}
local OPPOSITE = { up = "down", down = "up", left = "right", right = "left" }

-- Replaced in tests. Returns a number in [0, 1).
Snake.random = math.random

local function GetSettings()
	return PTT.database.snake
end

function Snake.GetInterval()
	return math.max(Snake.MIN_INTERVAL, Snake.START_INTERVAL - Snake.INTERVAL_PER_FOOD * Snake.game.eaten)
end

function Snake.IsOccupied(x, y)
	for _, segment in ipairs(Snake.game.segments) do
		if segment.x == x and segment.y == y then
			return true
		end
	end
	return false
end

-- Returns false when no cell is free.
local function PlaceFood(game)
	local free = {}
	for y = 1, Snake.ROWS do
		for x = 1, Snake.COLUMNS do
			if not Snake.IsOccupied(x, y) then
				free[#free + 1] = { x = x, y = y }
			end
		end
	end

	if #free == 0 then
		game.food = nil
		return false
	end
	game.food = free[math.min(#free, math.floor(Snake.random() * #free) + 1)]
	return true
end

function Snake.NewGame()
	local headX, headY = math.floor(Snake.COLUMNS / 2) + 1, math.floor(Snake.ROWS / 2) + 1
	local segments = {}
	for index = 1, Snake.START_LENGTH do
		segments[index] = { x = headX - index + 1, y = headY }
	end

	Snake.game = {
		segments = segments,
		direction = "right",
		queue = {},
		score = 0,
		eaten = 0,
		timer = 0,
		moves = 0,
		state = "ready",
		counted = false,
	}
	PlaceFood(Snake.game)
end

function Snake.Load()
	Snake.NewGame()
end

local function Finish(game, state)
	game.state = state
	game.queue = {}
	local settings = GetSettings()
	settings.highScore = math.max(settings.highScore, game.score)
end

-- A direction key starts the round, resumes a pause and queues the turn.
function Snake.Steer(name)
	local game = Snake.game
	if not Snake.DIRECTIONS[name] or game.state == "lost" or game.state == "won" then
		return false
	end

	local last = game.queue[#game.queue] or game.direction
	if name == OPPOSITE[last] and game.state ~= "paused" then
		return false
	end

	if game.state == "ready" and not game.counted then
		game.counted = true
		local settings = GetSettings()
		settings.played = settings.played + 1
	end
	game.state = "playing"

	if name ~= last and name ~= OPPOSITE[last] and #game.queue < Snake.MAX_QUEUED_TURNS then
		game.queue[#game.queue + 1] = name
	end
	return true
end

function Snake.Pause()
	local game = Snake.game
	if game.state ~= "playing" then
		return false
	end
	game.state = "paused"
	return true
end

function Snake.TogglePause()
	local game = Snake.game
	if game.state == "paused" then
		game.state = "playing"
		return true
	end
	return Snake.Pause()
end

local function Step(game)
	local turn = table.remove(game.queue, 1)
	if turn then
		game.direction = turn
	end

	local head = game.segments[1]
	local offset = Snake.DIRECTIONS[game.direction]
	local x, y = head.x + offset[1], head.y + offset[2]

	if x < 1 or x > Snake.COLUMNS or y < 1 or y > Snake.ROWS then
		Finish(game, "lost")
		return
	end

	local eats = game.food and game.food.x == x and game.food.y == y
	-- The tail moves out of the way unless the snake grows this step.
	local checked = eats and #game.segments or #game.segments - 1
	for index = 1, checked do
		local segment = game.segments[index]
		if segment.x == x and segment.y == y then
			Finish(game, "lost")
			return
		end
	end

	table.insert(game.segments, 1, { x = x, y = y })
	game.moves = game.moves + 1

	if not eats then
		table.remove(game.segments)
		return
	end

	game.score = game.score + Snake.FOOD_SCORE
	game.eaten = game.eaten + 1
	local settings = GetSettings()
	settings.foodEaten = settings.foodEaten + 1
	settings.longest = math.max(settings.longest, #game.segments)

	if not PlaceFood(game) then
		Finish(game, "won")
	end
end

-- Returns true when the snake moved, so the UI only redraws then.
function Snake.Update(deltaSeconds)
	local game = Snake.game
	if game.state ~= "playing" then
		return false
	end

	game.timer = game.timer + deltaSeconds
	local moved = false
	while game.state == "playing" and game.timer >= Snake.GetInterval() do
		game.timer = game.timer - Snake.GetInterval()
		Step(game)
		moved = true
	end
	return moved
end

PTT.OnInitialize(Snake.Load)
