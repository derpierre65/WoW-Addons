-- Run from the workspace root: lua __tests__/PassTheTime/minigames_test.lua
local PTT = {}
local initializeCallbacks = {}

function PTT.OnInitialize(callback)
	initializeCallbacks[#initializeCallbacks + 1] = callback
end

local function Load(path)
	assert(loadfile(path))("PassTheTime", PTT)
end

Load("PassTheTime/Minesweeper.lua")
Load("PassTheTime/Breakout.lua")
Load("PassTheTime/Snake.lua")
Load("PassTheTime/Memory.lua")
Load("PassTheTime/Sudoku.lua")
Load("PassTheTime/Yahtzee.lua")

local function FreshDatabase()
	PTT.database = {
		minesweeper = { difficulty = "elwynn", played = 0, won = 0, streak = 0, bestStreak = 0, flaglessWins = 0, bestTimes = {}, wonBy = {} },
		breakout = { played = 0, highScore = 0, bestLevel = 0, bossesKilled = 0, raidsCleared = 0, flawlessClears = 0 },
		snake = { played = 0, highScore = 0, longest = 0, foodEaten = 0 },
		memory = { difficulty = "easy", played = 0, won = 0, perfectWins = 0, bestTimes = {}, bestMoves = {}, wonBy = {} },
		sudoku = { difficulty = "easy", played = 0, won = 0, flawlessWins = 0, pureWins = 0, bestTimes = {}, wonBy = {} },
		yahtzee = { completed = 0, highScore = 0, yahtzees = 0, bonuses = 0, played = 0 },
	}
end
FreshDatabase()
for _, callback in ipairs(initializeCallbacks) do
	callback()
end

local failures = 0
local function Check(condition, message)
	if not condition then
		failures = failures + 1
		print("FAIL: " .. message)
	end
end

---------------------------------------------------------------------------
-- Minesweeper
---------------------------------------------------------------------------

local Minesweeper = PTT.Minesweeper
-- Seeded generator, so the mine layout is spread out but the same on every run.
local seed = 12345
Minesweeper.random = function(range)
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed % range + 1
end

local function RevealAllSafeCells(game)
	for index = 1, game.width * game.height do
		if not game.mine[index] then
			Minesweeper.Reveal(index)
		end
	end
end

local game = Minesweeper.NewGame("elwynn")
Check(game.width == 9 and game.height == 9 and game.mines == 10 and game.state == "ready", "new game uses the zone size")
Check(#Minesweeper.GetNeighbors(game, 1) == 3 and #Minesweeper.GetNeighbors(game, 5) == 5 and #Minesweeper.GetNeighbors(game, 41) == 8, "neighbour counts at corner, edge and centre")

Check(Minesweeper.Reveal(81), "first reveal works")
local mineCount = 0
for index = 1, 81 do
	mineCount = mineCount + (game.mine[index] and 1 or 0)
end
Check(mineCount == 10, "exactly the configured number of mines")
Check(not game.mine[81] and not game.mine[80] and not game.mine[72] and not game.mine[71], "first click and its surroundings are safe")
Check(game.state == "playing" and PTT.database.minesweeper.played == 1, "game starts and is counted")
Check(game.revealed[81] and game.revealedCount > 1, "empty area opens up")

Check(Minesweeper.ToggleFlag(1) and game.flagged[1] and game.usedFlag and Minesweeper.GetMinesLeft() == 9, "flag placed")
Check(not Minesweeper.Reveal(1), "flagged cells cannot be revealed")
Check(Minesweeper.ToggleFlag(1) and not game.flagged[1] and Minesweeper.GetMinesLeft() == 10, "flag removed")

Minesweeper.Tick(12.4)
RevealAllSafeCells(game)
local settings = PTT.database.minesweeper
Check(game.state == "won" and settings.won == 1 and settings.streak == 1, "win detected")
Check(settings.bestTimes.elwynn == 12 and settings.wonBy.elwynn == 1, "best time and wins per zone stored")
Check(settings.flaglessWins == 0, "a win with a flag is not flagless")
Check(not Minesweeper.Reveal(1) and not Minesweeper.ToggleFlag(1), "no input after the game ended")

game = Minesweeper.NewGame()
Minesweeper.Reveal(81)
Minesweeper.Tick(30)
RevealAllSafeCells(game)
Check(settings.flaglessWins == 1 and settings.streak == 2 and settings.bestTimes.elwynn == 12, "flagless win counted, slower time keeps the record")

game = Minesweeper.NewGame()
Minesweeper.Reveal(81)
local mineIndex
for index = 1, 81 do
	if game.mine[index] then
		mineIndex = index
		break
	end
end
Minesweeper.Reveal(mineIndex)
Check(game.state == "lost" and game.hitIndex == mineIndex and settings.streak == 0 and settings.bestStreak == 2, "mine ends the game and resets the streak")

-- Chording on a hand-made board with one mine in the corner
game = Minesweeper.NewGame()
game.state = "playing"
game.mines = 1
game.mine[1] = true
for index = 1, 81 do
	game.adjacent[index] = 0
end
game.adjacent[2], game.adjacent[10], game.adjacent[11] = 1, 1, 1
game.revealed[2], game.revealedCount = true, 1
game.flagged[1], game.flagCount = true, 1
Check(Minesweeper.Reveal(2) and game.revealed[3] and game.state == "won", "chord opens the neighbours and can win")

game = Minesweeper.NewGame()
game.state = "playing"
game.mine[1] = true
for index = 1, 81 do
	game.adjacent[index] = 0
end
game.adjacent[2], game.adjacent[10], game.adjacent[11] = 1, 1, 1
game.revealed[2], game.revealedCount = true, 1
game.flagged[3], game.flagCount = true, 1
Check(Minesweeper.Reveal(2) and game.state == "lost", "chord with a wrong banner hits the mine")

game = Minesweeper.NewGame("ungoro")
Check(game.width * game.height - game.mines > 0 and Minesweeper.GetDifficulty("nothing").id == "elwynn", "zones resolve, unknown falls back")

---------------------------------------------------------------------------
-- Breakout
---------------------------------------------------------------------------

local Breakout = PTT.Breakout
Breakout.random = function() return 0.5 end
Breakout.NewGame()
local run = Breakout.game
local stats = PTT.database.breakout

Check(run.state == "ready" and run.lives == 3 and run.level == 1, "new run starts ready on level 1")
Check(#run.bricks == 34 and run.aliveBricks == 34, "level 1 brick layout")
local bosses = 0
for _, brick in ipairs(run.bricks) do
	if brick.boss then
		bosses = bosses + 1
		Check(brick.health == 6, "boss health grows with the level")
	end
end
Check(bosses == 1, "one boss per level")
Check(stats.bestLevel == 1, "level reached is recorded")

Breakout.MovePaddle(-50)
Check(run.paddleX == Breakout.PADDLE_WIDTH / 2, "paddle stops at the left wall")
Breakout.MovePaddle(9999)
Check(run.paddleX == Breakout.FIELD_WIDTH - Breakout.PADDLE_WIDTH / 2, "paddle stops at the right wall")
Breakout.MovePaddle(200)
Check(run.balls[1].x == 200, "ball rides on the paddle before launch")

Check(Breakout.Launch() and run.state == "playing" and stats.played == 1, "launch starts the round and counts the game")
Check(run.balls[1].velocityY < 0 and math.abs(run.balls[1].velocityX) < 1e-9, "straight launch with a neutral random value")
Check(not Breakout.Launch(), "cannot launch twice")

-- Ceiling and side walls
run.balls[1].x, run.balls[1].y, run.balls[1].velocityX, run.balls[1].velocityY = 200, 8, 0, -250
Breakout.Update(0.05)
Check(run.balls[1].velocityY > 0, "ball bounces off the ceiling")
run.balls[1].x, run.balls[1].y, run.balls[1].velocityX, run.balls[1].velocityY = 4, 200, -250, 100
Breakout.Update(0.02)
Check(run.balls[1].velocityX > 0, "ball bounces off the left wall")

-- Paddle
Breakout.MovePaddle(240)
run.balls[1].x, run.balls[1].y, run.balls[1].velocityX, run.balls[1].velocityY = 240, Breakout.PADDLE_TOP - Breakout.BALL_RADIUS - 1, 0, 200
Breakout.Update(0.02)
Check(run.balls[1].velocityY < 0 and math.abs(run.balls[1].velocityX) < 1, "centre of the paddle sends the ball straight up")
run.balls[1].x, run.balls[1].y, run.balls[1].velocityX, run.balls[1].velocityY = 240 + 34, Breakout.PADDLE_TOP - Breakout.BALL_RADIUS - 1, 0, 200
Breakout.Update(0.02)
Check(run.balls[1].velocityX > 100 and run.balls[1].velocityY < 0, "edge of the paddle sends the ball sideways")

-- Brick hit from below
local lowest = run.bricks[#run.bricks]
run.balls[1].x = lowest.x + lowest.width / 2
run.balls[1].y = lowest.y + lowest.height + Breakout.BALL_RADIUS + 1
run.balls[1].velocityX, run.balls[1].velocityY = 0, -250
local scoreBefore = run.score
Breakout.Update(0.02)
Check(lowest.health == 0 and run.aliveBricks == 33 and run.score == scoreBefore + Breakout.BRICK_SCORE, "brick destroyed and scored")
Check(run.balls[1].velocityY > 0, "ball bounces off the brick")

-- Multi-hit bricks survive the first hit
Breakout.NewGame()
run = Breakout.game
run.level = 2
Breakout.StartLevel(2)
local sturdy = run.bricks[2]
Check(sturdy.maxHealth == 2, "level 2 top rows have two hit points")
run.state = "playing"
run.balls[1].x, run.balls[1].y = sturdy.x + sturdy.width / 2, sturdy.y + sturdy.height + Breakout.BALL_RADIUS + 1
run.balls[1].velocityX, run.balls[1].velocityY = 0, -250
-- Remove the bricks below so the ball reaches this one
for _, brick in ipairs(run.bricks) do
	if brick.row > sturdy.row then
		brick.health = 0
	end
end
Breakout.Update(0.02)
Check(sturdy.health == 1 and run.aliveBricks == #run.bricks, "sturdy brick takes two hits")

-- Losing lives
Breakout.NewGame()
run = Breakout.game
Breakout.Launch()
run.balls[1].x, run.balls[1].y, run.balls[1].velocityX, run.balls[1].velocityY = 200, Breakout.FIELD_HEIGHT + 20, 0, 100
Breakout.Update(0.02)
Check(run.lives == 2 and run.state == "ready" and run.lostLife, "falling out costs a life and resets the ball")
run.score = 750
run.lives = 1
Breakout.Launch()
run.balls[1].x, run.balls[1].y, run.balls[1].velocityX, run.balls[1].velocityY = 200, Breakout.FIELD_HEIGHT + 20, 0, 100
Breakout.Update(0.02)
Check(run.state == "lost" and stats.highScore == 750, "last life ends the run and stores the high score")

-- Clearing a level
local function LeaveOneBrick(brickIndex)
	for index, brick in ipairs(run.bricks) do
		brick.health = index == brickIndex and 1 or 0
	end
	run.aliveBricks = 1
	local last = run.bricks[brickIndex]
	run.state = "playing"
	run.balls[1].x = last.x + last.width / 2
	run.balls[1].y = last.y + last.height + Breakout.BALL_RADIUS + 1
	run.balls[1].velocityX, run.balls[1].velocityY = 0, -250
	Breakout.Update(0.02)
end

Breakout.NewGame()
run = Breakout.game
LeaveOneBrick(#run.bricks)
Check(run.level == 2 and run.state == "ready", "next raid after clearing a level")
Check(run.score == Breakout.BRICK_SCORE + Breakout.LEVEL_BONUS + Breakout.FLAWLESS_BONUS, "level and flawless bonus added")
Check(stats.flawlessClears == 1 and stats.bestLevel == 2, "flawless clear and level reached stored")

run.lostLife = true
LeaveOneBrick(#run.bricks)
Check(run.level == 3 and stats.flawlessClears == 1, "no flawless bonus after losing a life")

-- Boss kill and final clear
Breakout.NewGame()
run = Breakout.game
Breakout.StartLevel(#Breakout.levels)
local bossBrick
for _, brick in ipairs(run.bricks) do
	if brick.boss then
		bossBrick = brick
	end
end
local bossIndex
for index, brick in ipairs(run.bricks) do
	if brick == bossBrick then
		bossIndex = index
	end
end
LeaveOneBrick(bossIndex)
Check(stats.bossesKilled == 1, "boss kill counted")
Check(run.state == "won" and stats.raidsCleared == 1, "last raid cleared wins the run")

-- Items
Breakout.NewGame()
run = Breakout.game
run.state = "playing"
run.balls[1].x, run.balls[1].y, run.balls[1].velocityX, run.balls[1].velocityY = 20, 100, 0, -50
Breakout.MovePaddle(240)
run.items = { { x = 240, y = Breakout.PADDLE_TOP - 4, kind = "shield" }, { x = 240, y = Breakout.PADDLE_TOP - 4, kind = "rage" } }
Breakout.Update(0.05)
Check(run.lives == 4 and #run.rageTimers == 1 and #run.items == 0, "shield gives a life, rage starts a stack")
local normalSpeed = Breakout.BASE_SPEED
Check(Breakout.GetSpeed() > normalSpeed, "battle rage speeds the ball up")
run.lives = Breakout.MAX_LIVES
run.items = { { x = 240, y = Breakout.PADDLE_TOP - 4, kind = "shield" } }
Breakout.Update(0.05)
Check(run.lives == Breakout.MAX_LIVES, "lives are capped")
run.items = { { x = 20, y = Breakout.FIELD_HEIGHT + 30, kind = "shield" } }
Breakout.Update(0.02)
Check(#run.items == 0, "missed items disappear")

run.rageTimers = { Breakout.RAGE_DURATION }
Breakout.Update(Breakout.RAGE_DURATION + 1)
Check(#run.rageTimers == 0, "rage ends")

-- Multi-shot and wide shield
Breakout.NewGame()
run = Breakout.game
Breakout.MovePaddle(240)
Breakout.Launch()
run.balls[1].x, run.balls[1].y, run.balls[1].velocityX, run.balls[1].velocityY = 100, 150, 0, -250
run.items = { { x = 240, y = Breakout.PADDLE_TOP - 4, kind = "multi" } }
Breakout.Update(0.05)
Check(#run.balls == 3, "multi-shot adds two balls")
local speeds = {}
for _, ball in ipairs(run.balls) do
	speeds[#speeds + 1] = math.sqrt(ball.velocityX ^ 2 + ball.velocityY ^ 2)
end
Check(math.abs(speeds[1] - speeds[2]) < 1e-6 and math.abs(speeds[1] - speeds[3]) < 1e-6, "extra balls keep the speed")
Check(run.balls[1].velocityX ~= run.balls[2].velocityX, "extra balls fan out")

run.items = { { x = 240, y = Breakout.PADDLE_TOP - 4, kind = "multi" } }
Breakout.Update(0.05)
Check(#run.balls == Breakout.MAX_BALLS, "ball count is capped")

run.balls[1].y = Breakout.FIELD_HEIGHT + 20
run.balls[1].velocityY = 100
Breakout.Update(0.02)
Check(#run.balls == Breakout.MAX_BALLS - 1 and run.lives == 3 and run.state == "playing", "losing one of several balls costs no life")
for _, ball in ipairs(run.balls) do
	ball.y, ball.velocityY = Breakout.FIELD_HEIGHT + 20, 100
end
Breakout.Update(0.02)
Check(#run.balls == 1 and run.lives == 2 and run.state == "ready", "losing the last ball costs a life and gives one new ball")

Breakout.NewGame()
run = Breakout.game
Breakout.MovePaddle(240)
Check(Breakout.GetPaddleWidth() == Breakout.PADDLE_WIDTH, "normal paddle width")
Breakout.Launch()
run.balls[1].x, run.balls[1].y, run.balls[1].velocityX, run.balls[1].velocityY = 100, 150, 0, -250
run.items = { { x = 240, y = Breakout.PADDLE_TOP - 4, kind = "wide" } }
Breakout.Update(0.05)
Check(Breakout.GetPaddleWidth() == Breakout.PADDLE_WIDTH * (1 + Breakout.WIDE_WIDTH_PER_STACK) and #run.wideTimers == 1, "wide shield")
Breakout.MovePaddle(0)
Check(run.paddleX == Breakout.GetPaddleWidth() / 2, "wide shield stops at the wall with its larger half width")
-- No ball movement from here on, so only the timers run
run.state = "ready"
Breakout.Update(Breakout.WIDE_DURATION + 1)
Check(#run.wideTimers == 0 and Breakout.GetPaddleWidth() == Breakout.PADDLE_WIDTH, "wide shield wears off")

-- Stacking: every pickup is a stack with its own timer, the effects add up
local function Near(actual, expected)
	return math.abs(actual - expected) < 1e-6
end

local function Pickup(kind)
	run.items = { { x = run.paddleX, y = Breakout.PADDLE_TOP - 4, kind = kind } }
	Breakout.Update(0.001)
end

Breakout.NewGame()
run = Breakout.game
run.state = "ready"
Breakout.MovePaddle(240)
local baseSpeed = Breakout.GetSpeed()
Pickup("rage")
Check(Near(Breakout.GetSpeed(), baseSpeed * 1.3), "one bloodlust stack: +30% speed")
Breakout.Update(5)
Pickup("rage")
Check(#run.rageTimers == 2 and Near(Breakout.GetSpeed(), baseSpeed * 1.6), "second pickup stacks on top")
Breakout.Update(5.1)
Check(#run.rageTimers == 1 and Near(Breakout.GetSpeed(), baseSpeed * 1.3), "the first stack expires on its own")
Breakout.Update(5)
Check(#run.rageTimers == 0 and Near(Breakout.GetSpeed(), baseSpeed), "the last stack expires, no boost left")

for _ = 1, Breakout.MAX_RAGE_STACKS + 2 do
	Pickup("rage")
	Breakout.Update(1)
end
Check(#run.rageTimers == Breakout.MAX_RAGE_STACKS, "bloodlust stacks are capped")
Check(Breakout.GetLongestTimer(run.rageTimers) > Breakout.RAGE_DURATION - 1.5, "a full list refreshes its oldest stack")

run.rageTimers = {}
Breakout.NewGame()
run = Breakout.game
run.state = "ready"
Breakout.MovePaddle(240)
Pickup("wide")
Pickup("wide")
Check(#run.wideTimers == 2 and Near(Breakout.GetPaddleWidth(), Breakout.PADDLE_WIDTH * 2), "wide shield stacks add up")
Breakout.Update(Breakout.WIDE_DURATION - 1)
Pickup("wide")
Check(#run.wideTimers == 3 and Near(Breakout.GetPaddleWidth(), Breakout.PADDLE_WIDTH * 2.5), "a later pickup joins the remaining stacks")
Breakout.Update(2)
Check(#run.wideTimers == 1 and Near(Breakout.GetPaddleWidth(), Breakout.PADDLE_WIDTH * 1.5), "older stacks expire first")

-- Every power-up kind can drop
local seen = {}
Breakout.random = (function()
	-- Pairs of chance roll (always a drop) and kind roll
	local values = { 0, 0, 0, 0.3, 0, 0.6, 0, 0.9 }
	local position = 0
	return function()
		position = position + 1
		return values[(position - 1) % #values + 1]
	end
end)()
Breakout.NewGame()
run = Breakout.game
for _ = 1, 4 do
	run.items = {}
	local brick = { x = 100, y = 100, width = 48, height = 20, health = 1, maxHealth = 1 }
	run.bricks[#run.bricks + 1] = brick
	run.aliveBricks = run.aliveBricks + 1
	run.balls[1].x, run.balls[1].y = brick.x + 24, brick.y + 20 + Breakout.BALL_RADIUS - 1
	run.balls[1].velocityX, run.balls[1].velocityY = 0, -250
	run.state = "playing"
	Breakout.Update(0.001)
	for _, item in ipairs(run.items) do
		seen[item.kind] = true
	end
end
Check(seen.shield and seen.rage and seen.multi and seen.wide, "all four power-ups can drop")
Breakout.random = function() return 0.5 end

---------------------------------------------------------------------------
-- Memory
---------------------------------------------------------------------------

local Memory = PTT.Memory
local seedMemory = 99
Memory.random = function(range)
	seedMemory = (seedMemory * 1103515245 + 12345) % 2147483648
	return seedMemory % range + 1
end
local memorySettings = PTT.database.memory

local function CountSymbols(cards)
	local counts, distinct = {}, 0
	for _, symbol in ipairs(cards.symbols) do
		if not counts[symbol] then
			distinct = distinct + 1
		end
		counts[symbol] = (counts[symbol] or 0) + 1
	end
	return counts, distinct
end

-- Every symbol appears on exactly one pair, never twice on a board
local function CheckUniquePairs(game, pairCount, cardCount, columns, label)
	local counts, distinct = CountSymbols(game)
	local everyPair = true
	for _, count in pairs(counts) do
		everyPair = everyPair and count == 2
	end
	Check(#game.symbols == cardCount and distinct == pairCount and everyPair and game.columns == columns, label)
end

local cardGame = Memory.NewGame("easy")
CheckUniquePairs(cardGame, 9, 18, 6, "easy board: nine pairs in six columns, all symbols different")
for _ = 1, 20 do
	CheckUniquePairs(Memory.NewGame("medium"), 16, 32, 8, "medium board: sixteen pairs in eight columns, all symbols different")
	CheckUniquePairs(Memory.NewGame("hard"), 24, 48, 8, "hard board: 24 pairs in eight columns, all symbols different")
end
Check(memorySettings.difficulty == "hard", "last difficulty is remembered")

local seen = {}
for _, icon in ipairs(Memory.symbols) do
	Check(icon:find("^Interface\\Icons\\") ~= nil, "icon path " .. icon)
	Check(not seen[icon], "symbol listed once: " .. icon)
	seen[icon] = true
end
Check(#Memory.symbols >= 24, "the symbol pool covers the biggest board")

-- Two file names for the same picture must never end up on one board
local aliased = { [Memory.symbols[1]] = 1000, [Memory.symbols[2]] = 1000, [Memory.symbols[20]] = 1001, [Memory.symbols[21]] = 1001 }
local loaded
Memory.probe = {
	SetTexture = function(_, path) loaded = path end,
	GetTexture = function() return aliased[loaded] or loaded end,
}
Memory.uniqueSymbols = nil
Check(#Memory.GetUniqueSymbols() == #Memory.symbols - 2, "aliased pictures are listed once")
for _ = 1, 20 do
	local board = Memory.NewGame("hard")
	local pictures, clash = {}, false
	for _, symbol in ipairs(board.symbols) do
		local picture = aliased[symbol] or symbol
		if pictures[picture] and pictures[picture] ~= symbol then
			clash = true
		end
		pictures[picture] = symbol
	end
	Check(not clash, "no two different file names show the same picture on a board")
end
Memory.probe, Memory.uniqueSymbols = nil, nil

cardGame = Memory.NewGame("easy")
local function FindPair()
	for first = 1, #cardGame.symbols do
		for second = first + 1, #cardGame.symbols do
			if cardGame.symbols[first] == cardGame.symbols[second] then
				return first, second
			end
		end
	end
end
local function FindMismatch(skip)
	for first = 1, #cardGame.symbols do
		for second = first + 1, #cardGame.symbols do
			if cardGame.symbols[first] ~= cardGame.symbols[second] and not cardGame.matched[first] and not cardGame.matched[second]
				and first ~= skip and second ~= skip then
				return first, second
			end
		end
	end
end

local playedBefore = memorySettings.played
local pairFirst, pairSecond = FindPair()
Check(Memory.Flip(pairFirst) and cardGame.state == "playing" and memorySettings.played == playedBefore + 1, "first flip starts and counts the game")
Check(not Memory.Flip(pairFirst), "a turned card cannot be turned again")
Check(Memory.Flip(pairSecond) and cardGame.matched[pairFirst] and cardGame.matched[pairSecond] and cardGame.pairsFound == 1 and cardGame.moves == 1, "a pair stays open")
Check(not Memory.Flip(pairFirst), "matched cards cannot be turned")

local wrongFirst, wrongSecond = FindMismatch()
Memory.Flip(wrongFirst)
Memory.Flip(wrongSecond)
Check(cardGame.pending and cardGame.faceUp[wrongFirst] and cardGame.faceUp[wrongSecond] and cardGame.mismatches == 1, "a wrong pair stays visible for a moment")
Memory.Tick(Memory.MISMATCH_DELAY / 2)
Check(cardGame.faceUp[wrongFirst], "still visible before the delay is over")
Memory.Tick(Memory.MISMATCH_DELAY)
Check(not cardGame.faceUp[wrongFirst] and not cardGame.faceUp[wrongSecond] and not cardGame.pending, "wrong pair turns back")

Memory.Flip(wrongFirst)
Memory.Flip(wrongSecond)
local thirdCard
for index = 1, #cardGame.symbols do
	if not cardGame.matched[index] and index ~= wrongFirst and index ~= wrongSecond then
		thirdCard = index
		break
	end
end
Memory.Flip(thirdCard)
Check(not cardGame.faceUp[wrongFirst] and not cardGame.faceUp[wrongSecond] and cardGame.faceUp[thirdCard] and not cardGame.pending, "turning another card hides the wrong pair at once")

-- Finish the board without any more mistakes
cardGame.faceUp = {}
cardGame.firstPick = nil
Memory.Tick(23)
for first = 1, #cardGame.symbols do
	if not cardGame.matched[first] then
		for second = first + 1, #cardGame.symbols do
			if not cardGame.matched[second] and cardGame.symbols[first] == cardGame.symbols[second] then
				Memory.Flip(first)
				Memory.Flip(second)
				break
			end
		end
	end
end
Check(cardGame.state == "won" and memorySettings.won == 1 and memorySettings.wonBy.easy == 1, "win detected")
Check(memorySettings.bestTimes.easy ~= nil and memorySettings.bestMoves.easy == cardGame.moves, "best time and moves stored")
Check(memorySettings.perfectWins == 0, "a game with a wrong pair is not perfect")
Check(not Memory.Flip(1), "no flips after the game ended")

cardGame = Memory.NewGame("easy")
for first = 1, #cardGame.symbols do
	if not cardGame.matched[first] then
		for second = first + 1, #cardGame.symbols do
			if not cardGame.matched[second] and cardGame.symbols[first] == cardGame.symbols[second] then
				Memory.Flip(first)
				Memory.Flip(second)
				break
			end
		end
	end
end
Check(cardGame.state == "won" and memorySettings.perfectWins == 1 and memorySettings.bestMoves.easy == 9, "perfect game counted, best moves is the pair count")

---------------------------------------------------------------------------
-- Sudoku
---------------------------------------------------------------------------

local Sudoku = PTT.Sudoku
local seedSudoku = 4711
Sudoku.random = function(range)
	seedSudoku = (seedSudoku * 1103515245 + 12345) % 2147483648
	return seedSudoku % range + 1
end
local sudokuSettings = PTT.database.sudoku

local function IsCompleteGrid(grid)
	for group = 1, 9 do
		local row, column, box = {}, {}, {}
		for position = 1, 9 do
			local rowDigit = grid[(group - 1) * 9 + position]
			local columnDigit = grid[(position - 1) * 9 + group]
			local boxRow = math.floor((group - 1) / 3) * 3 + math.floor((position - 1) / 3)
			local boxColumn = ((group - 1) % 3) * 3 + (position - 1) % 3
			local boxDigit = grid[boxRow * 9 + boxColumn + 1]
			row[rowDigit], column[columnDigit], box[boxDigit] = true, true, true
		end
		for digit = 1, 9 do
			if not (row[digit] and column[digit] and box[digit]) then
				return false
			end
		end
	end
	return true
end

local solved = Sudoku.GenerateSolution()
Check(#solved == 81 and IsCompleteGrid(solved), "generated solution is a valid grid")

for _, difficulty in ipairs(Sudoku.difficulties) do
	local puzzle, solution = Sudoku.GeneratePuzzle(difficulty.clues)
	local clues, matches = 0, true
	for index = 1, 81 do
		if puzzle[index] ~= 0 then
			clues = clues + 1
			matches = matches and puzzle[index] == solution[index]
		end
	end
	Check(IsCompleteGrid(solution) and matches, difficulty.id .. ": clues belong to the solution")
	Check(Sudoku.CountSolutions(puzzle, 2) == 1, difficulty.id .. ": exactly one solution")
	Check(clues >= difficulty.clues and clues <= difficulty.clues + 4, difficulty.id .. ": about the wanted number of clues (" .. clues .. ")")
end

-- An empty grid is not unique, a contradictory one has no solution
local blank = {}
for index = 1, 81 do
	blank[index] = 0
end
Check(Sudoku.CountSolutions(blank, 2) == 2, "an empty grid has many solutions")
blank[1], blank[2] = 5, 5
Check(Sudoku.CountSolutions(blank, 2) == 0, "a contradiction has none")

local sudoku = Sudoku.NewGame("medium")
Check(sudokuSettings.difficulty == "medium" and sudokuSettings.game == sudoku and sudoku.state == "ready", "new game is stored in the saved data")

local emptyCell, givenCell
for index = 1, 81 do
	if sudoku.givens[index] == 0 and not emptyCell then
		emptyCell = index
	elseif sudoku.givens[index] ~= 0 and not givenCell then
		givenCell = index
	end
end
local wrongDigit = sudoku.solution[emptyCell] % 9 + 1

Check(not Sudoku.SetNumber(givenCell, 1) and not Sudoku.ClearCell(givenCell) and not Sudoku.ToggleNote(givenCell, 1), "given cells are locked")
Check(Sudoku.SetNumber(emptyCell, wrongDigit) and sudoku.mistakes == 0 and not Sudoku.IsWrong(emptyCell), "a wrong number is neither counted nor marked while playing")
Check(sudokuSettings.played == 1 and sudoku.state == "playing", "first entry starts the game")
Check(not Sudoku.SetNumber(emptyCell, wrongDigit) and sudoku.mistakes == 0, "the same number again changes nothing")
Check(Sudoku.ClearCell(emptyCell) and Sudoku.GetValue(emptyCell) == 0, "a cell can be cleared")

Check(Sudoku.ToggleNote(emptyCell, 3) and Sudoku.GetNotes(emptyCell)[3], "note set")
Check(Sudoku.ToggleNote(emptyCell, 3) and Sudoku.GetNotes(emptyCell) == nil, "note removed, empty notes disappear")
Sudoku.ToggleNote(emptyCell, 3)
local neighbour = Sudoku.GetPeers(emptyCell)[1]
local neighbourOpen = sudoku.givens[neighbour] == 0
if neighbourOpen then
	Sudoku.ToggleNote(neighbour, sudoku.solution[emptyCell])
end
Check(Sudoku.SetNumber(emptyCell, sudoku.solution[emptyCell]) and sudoku.mistakes == 0 and not Sudoku.IsWrong(emptyCell), "entering numbers never counts a mistake")
Check(Sudoku.GetNotes(emptyCell) == nil, "notes of a filled cell are gone")
Check(not neighbourOpen or Sudoku.GetNotes(neighbour) == nil, "the same note disappears from the neighbours")
Check(not Sudoku.ToggleNote(emptyCell, 2), "no notes in a filled cell")
Check(Sudoku.CountDigit(sudoku.solution[emptyCell]) >= 1, "digits are counted")

Sudoku.Tick(65)
local hintCell
for index = 1, 81 do
	if sudoku.givens[index] == 0 and sudoku.entries[index] == 0 then
		hintCell = index
		break
	end
end
Check(Sudoku.Hint(hintCell) and sudoku.hints == 1 and Sudoku.GetValue(hintCell) == sudoku.solution[hintCell], "hint fills the right number")

-- Fill the board, one cell wrong on purpose
Check(select(2, Sudoku.Verify()) == "incomplete" and sudoku.mistakes == 0, "an unfinished board cannot be verified")
local openCells = {}
for index = 1, 81 do
	if sudoku.givens[index] == 0 then
		openCells[#openCells + 1] = index
		Sudoku.SetNumber(index, sudoku.solution[index])
	end
end
local mistakeCell = openCells[1]
Sudoku.SetNumber(mistakeCell, sudoku.solution[mistakeCell] % 9 + 1)
Check(Sudoku.IsComplete() and sudoku.state == "playing", "a full board is not a win by itself")

local solvedNow, reason, wrongCount = Sudoku.Verify()
Check(not solvedNow and reason == "wrong" and wrongCount == 1 and sudoku.mistakes == 1 and Sudoku.IsWrong(mistakeCell) and sudoku.state == "playing", "verify counts the wrong cell and marks it")
Check(not Sudoku.IsWrong(openCells[2]), "correct cells are not marked")
Sudoku.Verify()
Check(sudoku.mistakes == 2, "verifying a wrong board again counts again")

Sudoku.SetNumber(mistakeCell, sudoku.solution[mistakeCell])
Check(not Sudoku.IsWrong(mistakeCell), "changing a cell removes its mark")
Check(Sudoku.Verify() and sudoku.state == "won" and sudokuSettings.won == 1 and sudokuSettings.wonBy.medium == 1, "a correct board verifies as won")
Check(sudokuSettings.bestTimes.medium == 65 and sudokuSettings.flawlessWins == 0 and sudokuSettings.pureWins == 0, "best time stored, mistake and hint spoil the flawless counters")
Check(not Sudoku.SetNumber(emptyCell, 1) and not Sudoku.Hint(emptyCell) and not Sudoku.Verify(), "no input after the win")

sudoku = Sudoku.NewGame("easy")
Sudoku.Tick(100)
for index = 1, 81 do
	if sudoku.givens[index] == 0 then
		Sudoku.SetNumber(index, sudoku.solution[index])
	end
end
Check(sudoku.state == "playing", "filling in the right numbers does not finish the game by itself")
Check(Sudoku.Verify() and sudoku.state == "won" and sudokuSettings.flawlessWins == 1 and sudokuSettings.pureWins == 1, "a clean game counts as flawless and pure")

-- A saved game is picked up again after a reload
sudoku = Sudoku.NewGame("hard")
Sudoku.game = nil
Sudoku.Load()
Check(Sudoku.game == sudoku and Sudoku.game.difficulty == "hard", "saved game is restored")
sudokuSettings.game = { givens = {} }
Sudoku.Load()
Check(#Sudoku.game.givens == 81, "a broken save is replaced by a new puzzle")

---------------------------------------------------------------------------
-- Yahtzee
---------------------------------------------------------------------------

local Yahtzee = PTT.Yahtzee
local yahtzeeSettings = PTT.database.yahtzee

local function Points(categoryId, ...)
	return Yahtzee.Score(categoryId, { ... })
end

Check(Points("threes", 3, 3, 1, 3, 6) == 9, "upper category sums its face")
Check(Points("threeKind", 2, 2, 2, 5, 6) == 17 and Points("threeKind", 2, 2, 3, 5, 6) == 0, "three of a kind sums all dice")
Check(Points("fourKind", 4, 4, 4, 4, 1) == 17 and Points("fourKind", 4, 4, 4, 1, 1) == 0, "four of a kind sums all dice")
Check(Points("fullHouse", 2, 2, 5, 5, 5) == 25 and Points("fullHouse", 2, 2, 2, 2, 2) == 0 and Points("fullHouse", 2, 2, 5, 5, 6) == 0, "full house needs a pair and a triple")
Check(Points("smallStraight", 1, 2, 3, 4, 4) == 30 and Points("smallStraight", 2, 3, 4, 5, 5) == 30 and Points("smallStraight", 1, 2, 3, 5, 6) == 0, "small straight")
Check(Points("largeStraight", 2, 3, 4, 5, 6) == 40 and Points("largeStraight", 1, 2, 3, 4, 6) == 0, "large straight")
Check(Points("yahtzee", 6, 6, 6, 6, 6) == 50 and Points("yahtzee", 6, 6, 6, 6, 5) == 0, "yahtzee")
Check(Points("chance", 1, 2, 3, 4, 6) == 16, "chance sums all dice")

local seedYahtzee = 7
Yahtzee.random = function(range)
	seedYahtzee = (seedYahtzee * 1103515245 + 12345) % 2147483648
	return seedYahtzee % range + 1
end

local yahtzeeGame = Yahtzee.NewGame()
Check(not Yahtzee.Choose("chance") and not Yahtzee.ToggleHold(1), "nothing to score or hold before the first roll")
Check(Yahtzee.Roll() and yahtzeeGame.rollsLeft == 2 and yahtzeeSettings.played == 1, "first roll counts the game")
for index = 1, 5 do
	Check(yahtzeeGame.dice[index] >= 1 and yahtzeeGame.dice[index] <= 6, "die " .. index .. " shows a face")
end

local keptValue = yahtzeeGame.dice[1]
Check(Yahtzee.ToggleHold(1) and yahtzeeGame.held[1], "a die can be kept")
for _ = 1, 20 do
	yahtzeeGame.rollsLeft = 2
	Yahtzee.Roll()
	if yahtzeeGame.dice[1] ~= keptValue then
		Check(false, "a kept die stays")
		break
	end
end
yahtzeeGame.rollsLeft = 1
Yahtzee.Roll()
Check(yahtzeeGame.rollsLeft == 0 and not Yahtzee.Roll() and not Yahtzee.ToggleHold(2), "no more rolls or holds after the third roll")

yahtzeeGame.dice = { 5, 5, 5, 5, 5 }
Check(Yahtzee.Choose("yahtzee") and yahtzeeGame.scores.yahtzee == 50 and yahtzeeSettings.yahtzees == 1, "a yahtzee is written down and counted")
Check(yahtzeeGame.turn == 2 and yahtzeeGame.rollsLeft == 3 and next(yahtzeeGame.held) == nil and #yahtzeeGame.dice == 0, "the next turn starts fresh")
Yahtzee.Roll()
Check(not Yahtzee.Choose("yahtzee"), "a used category cannot be taken again")

-- Upper bonus and the end of the game
Yahtzee.NewGame()
local order = { "ones", "twos", "threes", "fours", "fives", "sixes", "threeKind", "fourKind", "fullHouse", "smallStraight", "largeStraight", "yahtzee", "chance" }
for turn, categoryId in ipairs(order) do
	Yahtzee.Roll()
	local face = turn <= 6 and turn or 1
	Yahtzee.game.dice = { face, face, face, face, face }
	if turn == 13 then
		Check(Yahtzee.Choose(categoryId) and Yahtzee.game.state == "over", "the last row ends the game")
	else
		Check(Yahtzee.Choose(categoryId), "row " .. categoryId .. " accepted")
	end
end
Check(Yahtzee.GetUpperSum() == 5 + 10 + 15 + 20 + 25 + 30 and Yahtzee.GetBonus() == 35, "upper sum 105 earns the bonus")
Check(Yahtzee.game.total == Yahtzee.GetTotal() and yahtzeeSettings.completed == 1 and yahtzeeSettings.bonuses == 1, "a finished game is counted")
Check(yahtzeeSettings.highScore == Yahtzee.GetTotal(), "high score stored")
Check(not Yahtzee.Roll() and not Yahtzee.Choose("chance"), "no input after the game")

Yahtzee.NewGame()
Yahtzee.Roll()
Yahtzee.game.dice = { 1, 1, 1, 1, 1 }
Yahtzee.Choose("ones")
Check(Yahtzee.GetBonus() == 0 and Yahtzee.GetTotal() == 5, "no bonus below the threshold")

-- Snake
local Snake = PTT.Snake
local snakeSettings = PTT.database.snake
Snake.random = function() return 0 end
Snake.NewGame()
local snake = Snake.game
local head = snake.segments[1]
Check(#snake.segments == Snake.START_LENGTH and snake.state == "ready", "snake waits for the first key")
Check(snake.food and not Snake.IsOccupied(snake.food.x, snake.food.y), "food lies on a free cell")
Check(not Snake.Update(1) and snake.segments[1] == head, "snake does not move before the start")
Check(not Snake.Steer("left"), "cannot start backwards into the body")
Check(Snake.Steer("right") and snake.state == "playing" and snakeSettings.played == 1, "a direction key starts and counts the game")
Check(#snake.queue == 0, "same direction is not queued")
Check(Snake.Update(Snake.START_INTERVAL) and snake.segments[1].x == head.x + 1 and #snake.segments == Snake.START_LENGTH, "snake moves one cell per interval")

Check(Snake.Steer("up") and Snake.Steer("left") and #snake.queue == 2, "two quick turns are queued")
Check(not Snake.Steer("right"), "turn back into the last queued direction is ignored")
Snake.Update(Snake.START_INTERVAL)
Snake.Update(Snake.START_INTERVAL)
Check(snake.direction == "left" and #snake.queue == 0, "queued turns are applied step by step")

-- Eating
Snake.NewGame()
snake = Snake.game
head = snake.segments[1]
snake.food = { x = head.x + 1, y = head.y }
Snake.Steer("up")
snake.queue = {}
snake.direction = "right"
Snake.Update(Snake.START_INTERVAL)
Check(#snake.segments == Snake.START_LENGTH + 1 and snake.score == Snake.FOOD_SCORE, "eating grows the snake and scores")
Check(snakeSettings.longest == Snake.START_LENGTH + 1 and snakeSettings.foodEaten == 1, "longest snake and food stored")
Check(not (snake.food.x == head.x + 1 and snake.food.y == head.y) and not Snake.IsOccupied(snake.food.x, snake.food.y), "new food on a free cell")
Check(Snake.GetInterval() < Snake.START_INTERVAL, "snake speeds up after eating")
snake.eaten = 1000
Check(Snake.GetInterval() == Snake.MIN_INTERVAL, "speed is capped")

-- Pause
Snake.NewGame()
snake = Snake.game
Check(not Snake.Pause(), "cannot pause before the start")
Snake.Steer("up")
Check(Snake.Pause() and snake.state == "paused", "pause")
head = snake.segments[1]
Check(not Snake.Update(1) and snake.segments[1] == head, "paused snake does not move")
Check(Snake.Steer("down") and snake.state == "playing" and #snake.queue == 1, "any direction resumes, a reverse turn is dropped")
Check(Snake.TogglePause() and snake.state == "paused" and Snake.TogglePause() and snake.state == "playing", "space toggles the pause")
Check(snakeSettings.played == 3, "a resumed game is not counted twice")

-- Wall
Snake.NewGame()
snake = Snake.game
snake.score = 70
snake.food = { x = 1, y = 1 }
Snake.Steer("right")
for _ = 1, Snake.COLUMNS do
	Snake.Update(Snake.START_INTERVAL)
end
Check(snake.state == "lost" and snake.segments[1].x == Snake.COLUMNS, "hitting the wall ends the game")
Check(snakeSettings.highScore == 70, "high score stored")
Check(not Snake.Steer("up") and not Snake.Update(1), "no input after the game")

-- Self
Snake.NewGame()
snake = Snake.game
snake.food = { x = 1, y = 1 }
snake.segments = { { x = 5, y = 5 }, { x = 6, y = 5 }, { x = 6, y = 6 }, { x = 5, y = 6 }, { x = 4, y = 6 } }
snake.direction = "up"
Snake.Steer("left")
snake.queue = { "down" }
snake.direction = "left"
Snake.Update(Snake.START_INTERVAL)
Check(snake.state == "lost", "biting itself ends the game")

-- Chasing the tail is allowed, the tail moves away in the same step
Snake.NewGame()
snake = Snake.game
snake.food = { x = 1, y = 1 }
snake.segments = { { x = 5, y = 5 }, { x = 6, y = 5 }, { x = 6, y = 6 }, { x = 5, y = 6 } }
Snake.Steer("up")
snake.queue = {}
snake.direction = "down"
Snake.Update(Snake.START_INTERVAL)
Check(snake.state == "playing" and snake.segments[1].x == 5 and snake.segments[1].y == 6, "snake may move into its tail cell")

-- Full field
Snake.NewGame()
snake = Snake.game
snake.segments = {}
for y = 1, Snake.ROWS do
	for x = 1, Snake.COLUMNS do
		if not (x == 1 and y == 1) and not (x == 2 and y == 1) then
			snake.segments[#snake.segments + 1] = { x = x, y = y }
		end
	end
end
table.insert(snake.segments, 1, { x = 2, y = 1 })
snake.food = { x = 1, y = 1 }
snake.direction = "left"
snake.state = "playing"
Snake.Update(Snake.START_INTERVAL)
Check(snake.state == "won" and snake.food == nil, "filling the field wins")

print(failures == 0 and "MINIGAMES OK" or (failures .. " FAILURES"))
os.exit(failures == 0 and 0 or 1)
