-- Run from the workspace root: lua __tests__/PassTheTime/world_events_test.lua
local currentTime = 100
function GetTime() return currentTime end
function UnitGUID() return "player-guid" end
time = os.time

local PTT = { L =setmetatable({}, { __index = function(_, key) return key end }) }
function PTT.OnInitialize() end
for _, file in ipairs({ "Idle", "World", "Events", "Achievements", "Game2048" }) do
	assert(loadfile("PassTheTime/" .. file .. ".lua"))("PassTheTime", PTT)
end

PTT.database = {
	idle = {
		gold = 0, runGold = 0, lifetimeGold = 0, runTime = 0, totalTime = 0,
		clicks = 0, renown = 0, renownEarned = 0, prestiges = 0, unlocked = 1, tierKills = {}, kills = 0, bossKills = 0, groupBossKills = 0, guildBossKills = 0, monsterIndex = 1, monsterDamage = 0,
		allies = {}, upgrades = {}, professions = {}, buffs = {},
		buyAmount = 1, lifetimeKills = 0, eventsClaimed = 0,
	},
	achievements = {},
	hangman = { won = 0, played = 0 },
	minesweeper = { won = 0, flaglessWins = 0, bestTimes = {}, wonBy = {} },
	memory = { won = 0, wonBy = {}, perfectWins = 0, bestTimes = {} },
	sudoku = { won = 0, wonBy = {}, flawlessWins = 0, pureWins = 0 },
	breakout = { bossesKilled = 0, bestLevel = 0, flawlessClears = 0, highScore = 0, raidsCleared = 0 },
}
local state = PTT.database.idle

local failures = 0
local function Check(condition, message)
	if not condition then
		failures = failures + 1
		print("FAIL: " .. message)
	end
end

-- World bonus: a visible damage buff that stacks and fades
local World = PTT.World
state.allies.scout = 100
local baseDamage = PTT.Idle.GetDamagePerSecond()

World.Credit("kill")
Check(state.buffs.world ~= nil and World.last.kind == "kill", "an action creates the world buff")
Check(math.abs(state.buffs.world.multiplier - (1 + 0.5 * World.BONUS_PER_STACK)) < 1e-9, "a kill adds half a stack")
Check(PTT.Idle.GetDamagePerSecond() > baseDamage, "the world buff raises damage")
Check(state.buffs.world.remaining == World.DURATION, "the buff lasts the configured time")

World.Credit("quest")
Check(math.abs(World.GetBonus() - 5.5 * World.BONUS_PER_STACK) < 1e-9, "stacks add up")

for _ = 1, 10 do World.Credit("level") end
Check(World.stacks == World.MAX_STACKS, "stacks are capped")
Check(math.abs(PTT.Idle.GetDamagePerSecond() - baseDamage * (1 + World.MAX_STACKS * World.BONUS_PER_STACK)) < 1e-6, "the cap limits the bonus to 10%")

World.Tick()
Check(World.stacks == World.MAX_STACKS, "stacks stay while the buff is active")
PTT.Idle.Tick(World.DURATION + 1)
PTT.Idle.Tick(World.DURATION + 1)
for _ = 1, 20 do PTT.Idle.Tick(5) end
World.Tick()
Check(state.buffs.world == nil and World.stacks == 0, "stacks reset when the buff has expired")

World.Credit("loot")
Check(state.buffs.world ~= nil and math.abs(World.GetBonus() - World.BONUS_PER_STACK) < 1e-9, "a new action starts fresh")
World.GrantLevelBuff(5)
Check(state.buffs.levelUp ~= nil and state.buffs.levelUp.remaining == 5 * 60, "a level-up buff lasts one minute per level")
Check(state.buffs.levelUp.multiplier == World.LEVEL_BUFF_MULTIPLIER and state.buffs.levelUp.nameKey == "buffLevelUp", "level buff is shown by name")
World.GrantLevelBuff(10)
Check(state.buffs.levelUp.remaining == 10 * 60, "a higher level extends the buff")
World.GrantLevelBuff(3)
Check(state.buffs.levelUp.remaining == 10 * 60, "a lower level never shortens the buff")
state.buffs.levelUp = nil

state.buffs.world = nil
World.Tick()
state.allies = {}
state.gold = 0

-- Events
local Events = PTT.Events
local spawned, finished, claimed = 0, 0, 0
Events.On("spawn", function() spawned = spawned + 1 end)
Events.On("finish", function() finished = finished + 1 end)
Events.On("claim", function() claimed = claimed + 1 end)

local fixedRandom = function(minimum, maximum) return minimum or 0.5 end
Events.Tick(1, fixedRandom)
Check(Events.countdown == Events.MIN_DELAY - 1, "countdown scheduled")
Check(Events.active == nil, "nothing active yet")

Events.Tick(Events.MIN_DELAY, fixedRandom)
Check(Events.active ~= nil and spawned == 1, "event spawns when countdown ends")

Events.Tick(Events.ACTIVE_SECONDS + 1, fixedRandom)
Check(Events.active == nil and finished == 1, "event expires")

state.allies.scout = 10
state.gold = 0
Events.Spawn(function(first) return 1 end)
Check(Events.active.definition.id == "merchant", "forced merchant")
local message = Events.Claim(function(minimum) return minimum or 1 end)
Check(message ~= nil and state.gold >= 60 * PTT.Idle.GetIncome() - 1e-6, "merchant pays at least min seconds")
Check(state.eventsClaimed == 1 and claimed == 1 and Events.active == nil, "claim bookkeeping")
Check(Events.Claim() == nil, "nothing to claim twice")

Events.Spawn(function() return 3 end)
Check(Events.active.definition.id == "goblin", "forced goblin")
Events.Claim()
Check(state.buffs.event_goblin ~= nil and state.buffs.event_goblin.multiplier == 7, "goblin gives buff")

state.allies = {}
state.gold = 0
Events.Spawn(function() return 1 end)
Events.Claim(function(minimum) return minimum end)
Check(state.gold >= Events.MINIMUM_REWARD, "minimum reward without income")

-- Achievements
local unlocked = {}
PTT.Achievements.OnUnlock(function(definition) unlocked[#unlocked + 1] = definition.id end)
state.lifetimeGold = 2e6
state.clicks = 150
PTT.Achievements.Check()
Check(PTT.database.achievements.gold1k and PTT.database.achievements.gold1m, "gold achievements unlock")
Check(PTT.database.achievements.clicks100 and not PTT.database.achievements.clicks1000, "click achievements")
local count = #unlocked
PTT.Achievements.Check()
Check(#unlocked == count, "achievements unlock only once")
Check(PTT.Achievements.CountUnlocked() == count, "count matches")

PTT.Idle.groupBonus = 0.1
PTT.Achievements.Check()
Check(PTT.database.achievements.group ~= nil, "group achievement")

-- Every achievement has a name and description in each language; the L stub above would hide gaps.
for _, locale in ipairs({ "enUS", "deDE" }) do
	function GetLocale() return locale end
	local localised = {}
	assert(loadfile("PassTheTime/Localization.lua"))("PassTheTime", localised)
	local realPTT = PTT.L
	PTT.L = localised.L
	for _, definition in ipairs(PTT.Achievements.definitions) do
		local name, description = PTT.Achievements.GetName(definition), PTT.Achievements.GetDescription(definition)
		Check(name ~= "achievement_" .. definition.id and description ~= "achievementDesc_" .. definition.id, definition.id .. " localised in " .. locale)
	end
	PTT.L = realPTT
end
GetLocale = nil

print(failures == 0 and "WORLD/EVENTS OK" or (failures .. " FAILURES"))
os.exit(failures == 0 and 0 or 1)
