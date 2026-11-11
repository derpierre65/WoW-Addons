local _, PTT = ...

local Breakout = {}
PTT.Breakout = Breakout

-- Playing field in its own units; the UI scales nothing, it draws them 1:1.
Breakout.FIELD_WIDTH = 480
Breakout.FIELD_HEIGHT = 340
Breakout.PADDLE_WIDTH = 72
Breakout.PADDLE_HEIGHT = 10
Breakout.PADDLE_TOP = Breakout.FIELD_HEIGHT - 28
Breakout.BALL_RADIUS = 6
Breakout.BRICK_WIDTH = 48
Breakout.BRICK_HEIGHT = 20
Breakout.BRICK_GAP = 4
Breakout.COLUMNS = 9
Breakout.BRICK_TOP = 36
Breakout.ITEM_SIZE = 18

Breakout.START_LIVES = 3
Breakout.MAX_LIVES = 5
Breakout.BASE_SPEED = 250
Breakout.SPEED_PER_LEVEL = 20
Breakout.MAX_SPEED = 420
Breakout.SPEED_PER_BRICK = 0.01
Breakout.MAX_BOUNCE_ANGLE = math.rad(60)
Breakout.ITEM_CHANCE = 0.12
Breakout.ITEM_FALL_SPEED = 110
Breakout.ITEM_KINDS = { "shield", "rage", "multi", "wide" }
-- Bloodlust and wide shield stack: every pickup is its own stack with its own duration, the effects add up.
Breakout.RAGE_DURATION = 10
Breakout.RAGE_SPEED_PER_STACK = 0.3
Breakout.RAGE_SCORE_PER_STACK = 1
Breakout.MAX_RAGE_STACKS = 5
Breakout.WIDE_DURATION = 15
Breakout.WIDE_WIDTH_PER_STACK = 0.5
Breakout.MAX_WIDE_STACKS = 4
Breakout.MAX_BALLS = 5
Breakout.SPLIT_ANGLE = 0.4
Breakout.BRICK_SCORE = 10
Breakout.BOSS_SCORE = 200
Breakout.LEVEL_BONUS = 100
Breakout.FLAWLESS_BONUS = 100
Breakout.MAX_STEP = 1 / 120

-- One raid per level. The colour tints the bricks; names are raid_<id> and raidBoss_<id> in Localization.lua.
Breakout.levels = {
	{ id = "zulgurub", rows = 4, color = { 0.2, 0.55, 0.25 } },
	{ id = "moltencore", rows = 5, color = { 0.75, 0.3, 0.1 } },
	{ id = "blackwing", rows = 5, color = { 0.55, 0.12, 0.12 } },
	{ id = "ahnqiraj", rows = 6, color = { 0.65, 0.55, 0.2 } },
	{ id = "naxxramas", rows = 6, color = { 0.3, 0.5, 0.7 } },
}

-- Replaced in tests. Returns a number in [0, 1).
Breakout.random = math.random

local function GetSettings()
	return PTT.database.breakout
end

function Breakout.GetName(definition)
	return PTT.L["raid_" .. definition.id]
end

function Breakout.GetBossName(level)
	return PTT.L["raidBoss_" .. level.id]
end

function Breakout.GetPaddleWidth()
	local game = Breakout.game
	local stacks = game and #game.wideTimers or 0
	return Breakout.PADDLE_WIDTH * (1 + Breakout.WIDE_WIDTH_PER_STACK * stacks)
end

-- Longest remaining time of the stacks in a list, 0 when there are none.
function Breakout.GetLongestTimer(timers)
	local longest = 0
	for _, remaining in ipairs(timers) do
		longest = math.max(longest, remaining)
	end
	return longest
end

-- A full list refreshes its oldest stack instead of adding one.
local function AddStack(timers, duration, maximum)
	if #timers < maximum then
		timers[#timers + 1] = duration
		return
	end

	local oldest = 1
	for index, remaining in ipairs(timers) do
		if remaining < timers[oldest] then
			oldest = index
		end
	end
	timers[oldest] = duration
end

local function TickTimers(timers, step)
	for index = #timers, 1, -1 do
		timers[index] = timers[index] - step
		if timers[index] <= 0 then
			table.remove(timers, index)
		end
	end
end

local function BuildBricks(levelIndex)
	local level = Breakout.levels[levelIndex]
	local width, height, gap = Breakout.BRICK_WIDTH, Breakout.BRICK_HEIGHT, Breakout.BRICK_GAP
	local left = math.floor((Breakout.FIELD_WIDTH - (Breakout.COLUMNS * (width + gap) - gap)) / 2)
	local bricks = {}

	for row = 1, level.rows do
		local health = 1
			+ ((levelIndex >= 2 and row <= 2) and 1 or 0)
			+ ((levelIndex >= 4 and row <= 1) and 1 or 0)
		local column = 1
		while column <= Breakout.COLUMNS do
			local isBoss = row == 1 and column == 4
			local span = isBoss and 3 or 1
			local brickHealth = isBoss and (4 + levelIndex * 2) or health
			bricks[#bricks + 1] = {
				x = left + (column - 1) * (width + gap),
				y = Breakout.BRICK_TOP + (row - 1) * (height + gap),
				width = span * (width + gap) - gap,
				height = height,
				health = brickHealth,
				maxHealth = brickHealth,
				boss = isBoss,
				row = row,
			}
			column = column + span
		end
	end
	return bricks
end

function Breakout.GetSpeed()
	local game = Breakout.game
	local base = Breakout.BASE_SPEED + (game.level - 1) * Breakout.SPEED_PER_LEVEL
	local speed = math.min(Breakout.MAX_SPEED, base * (1 + Breakout.SPEED_PER_BRICK * game.destroyed))
	return speed * (1 + Breakout.RAGE_SPEED_PER_STACK * #game.rageTimers)
end

-- One ball resting on the paddle, waiting for the launch.
local function PlaceBallOnPaddle(game)
	game.balls = { { x = game.paddleX, y = Breakout.PADDLE_TOP - Breakout.BALL_RADIUS, velocityX = 0, velocityY = 0 } }
end

function Breakout.StartLevel(levelIndex)
	local game = Breakout.game
	game.level = levelIndex
	game.bricks = BuildBricks(levelIndex)
	game.aliveBricks = #game.bricks
	game.destroyed = 0
	game.items = {}
	game.rageTimers = {}
	game.wideTimers = {}
	game.lostLife = false
	game.state = "ready"
	PlaceBallOnPaddle(game)

	local settings = GetSettings()
	settings.bestLevel = math.max(settings.bestLevel, levelIndex)
end

function Breakout.NewGame()
	Breakout.game = {
		score = 0,
		lives = Breakout.START_LIVES,
		paddleX = Breakout.FIELD_WIDTH / 2,
		balls = {},
		rageTimers = {},
		wideTimers = {},
		effects = {},
		counted = false,
	}
	Breakout.StartLevel(1)
end

function Breakout.Load()
	Breakout.NewGame()
end

-- Reported in game.effects for the UI sounds.
local function Emit(game, kind)
	game.effects[#game.effects + 1] = kind
end

local function Finish(game, state)
	game.state = state
	Emit(game, state)
	local settings = GetSettings()
	settings.highScore = math.max(settings.highScore, game.score)
end

local function ClampPaddle(game, centerX)
	local half = Breakout.GetPaddleWidth() / 2
	return math.max(half, math.min(Breakout.FIELD_WIDTH - half, centerX))
end

function Breakout.MovePaddle(centerX)
	local game = Breakout.game
	game.paddleX = ClampPaddle(game, centerX)
	if game.state == "ready" then
		PlaceBallOnPaddle(game)
	end
end

function Breakout.Launch()
	local game = Breakout.game
	if game.state ~= "ready" then
		return false
	end

	local settings = GetSettings()
	if not game.counted then
		game.counted = true
		settings.played = settings.played + 1
	end

	game.state = "playing"
	Emit(game, "launch")
	local ball = game.balls[1]
	local angle = (Breakout.random() - 0.5) * 0.6
	local speed = Breakout.GetSpeed()
	ball.velocityX = speed * math.sin(angle)
	ball.velocityY = -speed * math.cos(angle)
	return true
end

local function SpawnItem(game, brick)
	if Breakout.random() >= Breakout.ITEM_CHANCE then
		return
	end

	local kinds = Breakout.ITEM_KINDS
	game.items[#game.items + 1] = {
		x = brick.x + brick.width / 2,
		y = brick.y + brick.height / 2,
		kind = kinds[math.min(#kinds, math.floor(Breakout.random() * #kinds) + 1)],
	}
end

-- Every ball spawns two copies fanned out to both sides, as far as the ball limit allows.
local function SplitBalls(game)
	local originals = {}
	for _, ball in ipairs(game.balls) do
		originals[#originals + 1] = ball
	end

	for _, ball in ipairs(originals) do
		for _, direction in ipairs({ 1, -1 }) do
			if #game.balls < Breakout.MAX_BALLS then
				local angle = direction * Breakout.SPLIT_ANGLE
				local cosine, sine = math.cos(angle), math.sin(angle)
				game.balls[#game.balls + 1] = {
					x = ball.x,
					y = ball.y,
					velocityX = ball.velocityX * cosine - ball.velocityY * sine,
					velocityY = ball.velocityX * sine + ball.velocityY * cosine,
				}
			end
		end
	end
end

local function ApplyItem(game, kind)
	if kind == "shield" then
		game.lives = math.min(Breakout.MAX_LIVES, game.lives + 1)
	elseif kind == "rage" then
		AddStack(game.rageTimers, Breakout.RAGE_DURATION, Breakout.MAX_RAGE_STACKS)
	elseif kind == "wide" then
		AddStack(game.wideTimers, Breakout.WIDE_DURATION, Breakout.MAX_WIDE_STACKS)
	elseif kind == "multi" and game.state == "playing" then
		SplitBalls(game)
	end
end

local function ClearLevel(game)
	game.score = game.score + Breakout.LEVEL_BONUS
	local settings = GetSettings()
	if not game.lostLife then
		game.score = game.score + Breakout.FLAWLESS_BONUS
		settings.flawlessClears = settings.flawlessClears + 1
	end

	if game.level >= #Breakout.levels then
		settings.raidsCleared = settings.raidsCleared + 1
		Finish(game, "won")
	else
		Emit(game, "level")
		Breakout.StartLevel(game.level + 1)
	end
end

local function DestroyBrick(game, brick)
	game.aliveBricks = game.aliveBricks - 1
	game.destroyed = game.destroyed + 1

	local factor = 1 + Breakout.RAGE_SCORE_PER_STACK * #game.rageTimers
	game.score = game.score + (brick.boss and Breakout.BOSS_SCORE or Breakout.BRICK_SCORE) * factor

	if brick.boss then
		GetSettings().bossesKilled = GetSettings().bossesKilled + 1
	else
		SpawnItem(game, brick)
	end

	if game.aliveBricks <= 0 then
		ClearLevel(game)
	end
end

local function HitBricks(game, ball)
	local radius = Breakout.BALL_RADIUS
	for _, brick in ipairs(game.bricks) do
		if brick.health > 0 then
			local nearestX = math.max(brick.x, math.min(ball.x, brick.x + brick.width))
			local nearestY = math.max(brick.y, math.min(ball.y, brick.y + brick.height))
			local deltaX, deltaY = ball.x - nearestX, ball.y - nearestY

			if deltaX * deltaX + deltaY * deltaY < radius * radius then
				if deltaX == 0 and deltaY == 0 then
					ball.velocityY = -ball.velocityY
				elseif math.abs(deltaX) > math.abs(deltaY) then
					ball.velocityX = deltaX > 0 and math.abs(ball.velocityX) or -math.abs(ball.velocityX)
					ball.x = nearestX + (deltaX > 0 and radius or -radius)
				else
					ball.velocityY = deltaY > 0 and math.abs(ball.velocityY) or -math.abs(ball.velocityY)
					ball.y = nearestY + (deltaY > 0 and radius or -radius)
				end

				brick.health = brick.health - 1
				if brick.health <= 0 then
					Emit(game, brick.boss and "boss" or "break")
					DestroyBrick(game, brick)
				else
					Emit(game, brick.boss and "bossHit" or "hit")
				end
				return
			end
		end
	end
end

local function HitPaddle(game, ball)
	local radius = Breakout.BALL_RADIUS
	local top = Breakout.PADDLE_TOP
	if ball.velocityY <= 0 then
		return
	end

	local half = Breakout.GetPaddleWidth() / 2
	if ball.y + radius >= top and ball.y - radius <= top + Breakout.PADDLE_HEIGHT
		and math.abs(ball.x - game.paddleX) <= half + radius then
		local offset = math.max(-1, math.min(1, (ball.x - game.paddleX) / half))
		local angle = offset * Breakout.MAX_BOUNCE_ANGLE
		local speed = Breakout.GetSpeed()
		ball.velocityX = speed * math.sin(angle)
		ball.velocityY = -speed * math.cos(angle)
		ball.y = top - radius
		Emit(game, "paddle")
	end
end

local function LoseLife(game)
	game.lives = game.lives - 1
	game.lostLife = true
	game.rageTimers = {}
	game.wideTimers = {}
	game.items = {}

	if game.lives <= 0 then
		Finish(game, "lost")
	else
		Emit(game, "ballLost")
		game.state = "ready"
		game.paddleX = ClampPaddle(game, game.paddleX)
		PlaceBallOnPaddle(game)
	end
end

local function UpdateItems(game, step)
	local half = Breakout.GetPaddleWidth() / 2
	for index = #game.items, 1, -1 do
		local item = game.items[index]
		item.y = item.y + Breakout.ITEM_FALL_SPEED * step

		local caught = item.y + Breakout.ITEM_SIZE / 2 >= Breakout.PADDLE_TOP
			and item.y - Breakout.ITEM_SIZE / 2 <= Breakout.PADDLE_TOP + Breakout.PADDLE_HEIGHT
			and math.abs(item.x - game.paddleX) <= half + Breakout.ITEM_SIZE / 2

		if caught then
			table.remove(game.items, index)
			Emit(game, item.kind)
			ApplyItem(game, item.kind)
		elseif item.y - Breakout.ITEM_SIZE / 2 > Breakout.FIELD_HEIGHT then
			table.remove(game.items, index)
		end
	end
end

-- Returns false once the ball has fallen out of the field.
local function StepBall(game, ball, step)
	local radius = Breakout.BALL_RADIUS
	ball.x = ball.x + ball.velocityX * step
	ball.y = ball.y + ball.velocityY * step

	if ball.x - radius < 0 then
		ball.x = radius
		ball.velocityX = math.abs(ball.velocityX)
		Emit(game, "wall")
	elseif ball.x + radius > Breakout.FIELD_WIDTH then
		ball.x = Breakout.FIELD_WIDTH - radius
		ball.velocityX = -math.abs(ball.velocityX)
		Emit(game, "wall")
	end
	if ball.y - radius < 0 then
		ball.y = radius
		ball.velocityY = math.abs(ball.velocityY)
		Emit(game, "wall")
	end

	if ball.y - radius > Breakout.FIELD_HEIGHT then
		return false
	end

	HitPaddle(game, ball)
	HitBricks(game, ball)

	-- Keep the speed in line with level, bricks destroyed and battle rage, and never let the ball crawl sideways.
	if game.state == "playing" then
		local speed = Breakout.GetSpeed()
		local length = math.sqrt(ball.velocityX ^ 2 + ball.velocityY ^ 2)
		if length > 0 then
			ball.velocityX, ball.velocityY = ball.velocityX / length * speed, ball.velocityY / length * speed
		end
		local minimum = speed * 0.25
		if math.abs(ball.velocityY) < minimum then
			ball.velocityY = (ball.velocityY < 0 and -1 or 1) * minimum
		end
	end
	return true
end

local function Step(game, step)
	TickTimers(game.rageTimers, step)
	TickTimers(game.wideTimers, step)
	if #game.wideTimers > 0 then
		game.paddleX = ClampPaddle(game, game.paddleX)
	end
	UpdateItems(game, step)

	if game.state ~= "playing" then
		return
	end

	for index = #game.balls, 1, -1 do
		if not StepBall(game, game.balls[index], step) then
			table.remove(game.balls, index)
		end
		-- Clearing the level or ending the run replaces the balls.
		if game.state ~= "playing" then
			return
		end
	end

	if #game.balls == 0 then
		LoseLife(game)
	end
end

-- Moves everything by deltaSeconds, in small steps so fast balls cannot pass through bricks.
function Breakout.Update(deltaSeconds)
	local game = Breakout.game
	local steps = math.max(1, math.ceil(deltaSeconds / Breakout.MAX_STEP))
	for _ = 1, steps do
		Step(game, deltaSeconds / steps)
	end
end

PTT.OnInitialize(Breakout.Load)
