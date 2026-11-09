-- Run from the workspace root: lua __tests__/PassTheTime/idle_test.lua [simulate]
local PTT = {}
assert(loadfile("PassTheTime/Localization.lua"))("PassTheTime", PTT)
assert(loadfile("PassTheTime/Idle.lua"))("PassTheTime", PTT)

-- Each click happens 0.1 s after the previous one, far below the click limit.
local clockTime = 0
PTT.Idle.clock = function()
	clockTime = clockTime + 0.1
	return clockTime
end

local function FreshDatabase()
	PTT.database = {
		idle = {
			gold = 0, runGold = 0, lifetimeGold = 0, runTime = 0, totalTime = 0,
			clicks = 0, renown = 0, renownEarned = 0, prestiges = 0,
			unlocked = 1, tierKills = {}, kills = 0, bossKills = 0, groupBossKills = 0, guildBossKills = 0, monsterIndex = 1, monsterDamage = 0,
			allies = {}, upgrades = {}, professions = {}, buffs = {},
			buyAmount = 1, lifetimeKills = 0, eventsClaimed = 0,
		},
		achievements = {},
		hangman = { won = 0, played = 0 },
	}
	PTT.Idle.groupBonus = 0
	PTT.Idle.ResetClickLimit()
end

local Idle = PTT.Idle
Idle.random = function() return 0.5 end
local failures = 0
local function Check(condition, message)
	if not condition then
		failures = failures + 1
		print("FAIL: " .. message)
	end
end

local function Near(actual, expected, message)
	Check(math.abs(actual - expected) <= math.max(1e-9, math.abs(expected) * 1e-9), message .. " (got " .. actual .. ", expected " .. expected .. ")")
end

local recruit = Idle.definitions.ally[1]
local scout = Idle.definitions.ally[2]
local click = Idle.definitions.upgrade[1]

-- Costs and buying
FreshDatabase()
Near(Idle.GetCost("ally", recruit, 1), 15, "first recruit costs base")
Near(Idle.GetCost("ally", recruit, 2), 15 + 15 * 1.07, "two recruits")
PTT.database.idle.allies.recruit = 3
Near(Idle.GetCost("ally", recruit, 1), 15 * 1.07 ^ 3, "cost grows with owned")

FreshDatabase()
Check(Idle.Buy("ally", recruit, 1) == 0, "cannot buy without gold")
PTT.database.idle.gold = 100
Check(Idle.Buy("ally", recruit, 1) == 1, "buy one")
Near(PTT.database.idle.gold, 85, "gold deducted")
Check(Idle.GetOwned("ally", "recruit") == 1, "owned increased")
Check(Idle.Buy("upgrade", click, 1) == 1 and Idle.GetOwned("upgrade", "click") == 1, "click upgrade can be bought")

FreshDatabase()
PTT.database.idle.gold = 1000
local affordable = Idle.GetMaxAffordable("ally", recruit)
Check(Idle.GetCost("ally", recruit, affordable) <= 1000, "max affordable fits budget")
Check(Idle.GetCost("ally", recruit, affordable + 1) > 1000, "max affordable is maximal")
Check(Idle.Buy("ally", recruit, "max") == affordable, "buy max")
Check(Idle.Buy("ally", recruit, 10) == 0, "partial amounts are refused")

FreshDatabase()
Check(Idle.GetMaxAffordable("ally", recruit) == 0, "nothing affordable at zero gold")

-- Professions
FreshDatabase()
PTT.database.idle.gold = 1e30
local alchemy = Idle.definitions.profession[4]
Check(Idle.Buy("profession", alchemy, 1) == 0 and PTT.database.idle.gold == 1e30, "professions cannot be bought with gold")
PTT.database.idle.renown = 5
Check(Idle.GetMaxAffordable("profession", alchemy) == 2, "max affordable uses souls")
Check(Idle.Buy("profession", alchemy, "max") == 2 and PTT.database.idle.renown == 1, "profession costs souls per level")
Check(PTT.database.idle.gold == 1e30, "gold untouched by profession purchase")
PTT.database.idle.renown = 1e9
Check(Idle.Buy("profession", alchemy, "max") == Idle.PROFESSION_MAX_LEVEL - 2, "profession capped at max level")
Check(Idle.Buy("profession", alchemy, 1) == 0, "no levels beyond cap")

PTT.database.idle.professions = {}
Check(Idle.GetCost("profession", alchemy, 25) == 25 * 2, "first 25 levels cost the base")
Check(Idle.GetCost("profession", alchemy, 75) == 25 * (2 + 3 + 4), "one more soul every 25 levels")
PTT.database.idle.professions.alchemy = 24
Check(Idle.GetCost("profession", alchemy, 2) == 2 + 3, "price rises at level 25")
PTT.database.idle.renown = 4
Check(Idle.GetMaxAffordable("profession", alchemy) == 1, "max affordable respects the higher price")

-- Damage and multipliers
FreshDatabase()
PTT.database.idle.allies.scout = 10
Near(Idle.GetDamagePerSecond(), 10 * scout.damage, "damage from scouts")
PTT.database.idle.renown = 2
Near(Idle.GetDamagePerSecond(), 10 * scout.damage, "renown gives no damage bonus")
PTT.database.idle.unlocked = 11
Near(Idle.GetDamagePerSecond(), 10 * scout.damage * 1.3, "unlocked-tier multiplier")
Idle.groupBonus = 0.2
Near(Idle.GetDamagePerSecond(), 10 * scout.damage * 1.3 * 1.2, "group bonus")
Idle.AddBuff("test", "x", 2, 10)
Near(Idle.GetDamagePerSecond(), 10 * scout.damage * 1.3 * 1.2 * 2, "buff multiplier")

FreshDatabase()
local professions = {}
for _, definition in ipairs(Idle.definitions.profession) do
	professions[definition.id] = definition
end
local function ClearProfessions()
	PTT.database.idle.professions = {}
end

PTT.database.idle.allies.scout = 10
PTT.database.idle.professions.blacksmithing = 10
Near(Idle.GetDamagePerSecond(), 10 * scout.damage * (1 + 10 * professions.blacksmithing.perLevel), "blacksmithing adds damage")
Near(Idle.GetGoldMultiplier(), 1, "blacksmithing adds no gold")
ClearProfessions()
PTT.database.idle.professions.mining = 20
Near(Idle.GetDamagePerSecond(), 10 * scout.damage, "mining adds no damage")
Near(Idle.GetGoldMultiplier(), 1 + 20 * professions.mining.perLevel, "mining adds gold")

-- Click damage, boss time, buff duration and hero cost
ClearProfessions()
local clickBefore = Idle.GetClickDamage()
PTT.database.idle.professions.skinning = 10
Near(Idle.GetClickDamage(), clickBefore * (1 + 10 * professions.skinning.perLevel), "skinning adds click damage")
Near(Idle.GetDamagePerSecond(), 10 * scout.damage, "skinning adds no passive damage")

ClearProfessions()
Check(Idle.GetBossTimeLimit() == Idle.BOSS_TIME_LIMIT, "no boss time bonus without enchanting")
PTT.database.idle.professions.enchanting = 1
Check(Idle.GetBossTimeLimit() == Idle.BOSS_TIME_LIMIT + 2, "+2s per level")
PTT.database.idle.professions.enchanting = 75
Check(Idle.GetBossTimeLimit() == Idle.BOSS_TIME_LIMIT + 150, "+150s at max level")

ClearProfessions()
PTT.database.idle.buffs = {}
Idle.AddBuff("duration", "x", 2, 10)
Near(PTT.database.idle.buffs.duration.remaining, 10, "buff duration unchanged without alchemy")
PTT.database.idle.buffs = {}
PTT.database.idle.professions.alchemy = 25
Idle.AddBuff("duration", "x", 2, 10)
Near(PTT.database.idle.buffs.duration.remaining, 10 * (1 + 25 * professions.alchemy.perLevel), "alchemy extends buffs")
PTT.database.idle.buffs = {}

ClearProfessions()
local costBefore = Idle.GetCost("ally", scout, 5)
local clickCostBefore = Idle.GetCost("upgrade", click, 5)
PTT.database.idle.professions.herbalism = 20
Near(Idle.GetCost("ally", scout, 5), costBefore * (1 - 20 * professions.herbalism.perLevel), "herbalism discounts heroes")
Near(Idle.GetCost("upgrade", click, 5), clickCostBefore, "herbalism does not discount weapon training")
PTT.database.idle.gold = Idle.GetCost("ally", scout, 7)
Check(Idle.GetMaxAffordable("ally", scout) == 7, "max affordable respects the discount")
PTT.database.idle.professions.herbalism = 75
Near(Idle.GetCostFactor("ally"), 1 - 75 * professions.herbalism.perLevel, "full discount below the cap")
ClearProfessions()

FreshDatabase()
Near(Idle.GetClickDamage(), 1, "base click damage")
PTT.database.idle.upgrades.click = 10
Near(Idle.GetClickDamage(), 1 + 10 * (1 + 10 * 0.05), "click upgrade")

-- Monsters
FreshDatabase()
local first, second = Idle.GetMonster(1), Idle.GetMonster(2)
Near(first.health, Idle.MONSTER_BASE_HEALTH, "first monster health")
Check(second.health > first.health, "health grows per tier")
Check(second.gold > first.gold, "higher tiers pay more gold per kill")
Check(Idle.GetMonster(5).boss and not Idle.GetMonster(4).boss, "bosses are flagged")
Check(Idle.GetMonster(5).gold > Idle.GetMonster(4).gold * 5, "bosses pay much more gold than the enemy before")
Check(Idle.GetMonsterCount() > 60 and Idle.GetMonster(Idle.GetMonsterCount()).boss, "raid bosses end the list")
for index = 1, Idle.GetMonsterCount() do
	local monster = Idle.GetMonster(index)
	Check(PTT.L[monster.nameKey] ~= monster.nameKey and monster.health > 0, "monster " .. index .. " valid")
end
for kind, list in pairs(Idle.definitions) do
	for _, definition in ipairs(list) do
		Check(PTT.L[definition.nameKey] ~= definition.nameKey, kind .. " " .. definition.id .. " named")
	end
end

Check(not Idle.IsUnlocked(2), "tier 2 locked at the start")
Check(not Idle.SelectMonster(2), "cannot select locked monster")
PTT.database.idle.unlocked = 3
Check(Idle.IsUnlocked(3) and not Idle.IsUnlocked(4), "unlock follows the unlocked tier")
PTT.database.idle.monsterDamage = 3
Check(Idle.SelectMonster(3) and PTT.database.idle.monsterIndex == 3 and PTT.database.idle.monsterDamage == 0, "select resets damage")
Check(not Idle.SelectMonster(3), "reselecting the same monster does nothing")
Check(not Idle.SelectMonster(0) and not Idle.SelectMonster(9999), "out of range ignored")

-- Clicking
FreshDatabase()
local kills, unlockedTiers = 0, {}
Idle.OnKill(function() kills = kills + 1 end)
Idle.OnUnlock(function(index) unlockedTiers[#unlockedTiers + 1] = index end)
for _ = 1, 9 do Idle.Click() end
Check(kills == 0 and PTT.database.idle.gold == 0, "nine clicks do not kill a 10 hp monster")
Idle.Click()
Check(kills == 1, "tenth click kills")
Near(PTT.database.idle.gold, 1, "the first enemy pays 1 gold")
Check(PTT.database.idle.kills == 1 and PTT.database.idle.lifetimeKills == 1, "kill counted")
Check(Idle.Click() > 0, "the next enemy can be attacked immediately")
Near(PTT.database.idle.monsterDamage, 1, "the next enemy starts with full health")

-- Click limit: never more than 20 accepted clicks within any second
FreshDatabase()
PTT.database.idle.unlocked = 5
PTT.database.idle.monsterIndex = 5
local realClock = Idle.clock
local limitTime = 50
Idle.clock = function() return limitTime end
local accepted = 0
for _ = 1, 100 do
	if Idle.Click() > 0 then accepted = accepted + 1 end
end
Check(accepted == Idle.MAX_CLICKS_PER_SECOND, "only 20 clicks pass within one second")
Check(PTT.database.idle.clicks == 20, "rejected clicks are not counted")

limitTime = 50.99
Check(Idle.Click() == 0, "still limited just before a second has passed")
limitTime = 51
Check(Idle.Click() > 0, "clicks work again once the second is over")

-- A sliding window: the limit holds across second boundaries too.
Idle.ResetClickLimit()
accepted = 0
for step = 0, 199 do
	limitTime = 100 + step * 0.01
	if Idle.Click() > 0 then accepted = accepted + 1 end
end
Check(accepted <= 2 * Idle.MAX_CLICKS_PER_SECOND, "no burst beyond 20 per second over two seconds")
Idle.clock = realClock

-- Stat counters
FreshDatabase()
local statState = PTT.database.idle
statState.gold = 1000
local recruit = Idle.definitions.ally[1]
Idle.Buy("ally", recruit, 2)
Near(statState.goldSpent, Idle.GetCost("ally", { id = "none", cost = recruit.cost }, 0) + recruit.cost * (1 + 1.07), "gold spent is tracked")
Idle.AddGold(5)
Idle.AddGold(3)
Check(statState.bestReward == 5, "best reward keeps the highest single amount")
Idle.StartSession()
Idle.StartSession()
Check(statState.sessions == 2, "sessions are counted")
Idle.Tick(3)
Idle.Tick(2)
Near(statState.longestSession, 5, "longest session follows the session time")
Idle.StartSession()
Idle.Tick(1)
Near(statState.longestSession, 5, "a shorter session keeps the record")
statState.unlocked = 4
Idle.Tick(1)
Check(statState.highestEnemy == 4, "highest enemy is remembered")
statState.unlocked = 1
Idle.Tick(1)
Check(statState.highestEnemy == 4, "highest enemy survives a reset")

-- Unlocking: ten kills of the highest unlocked enemy open the next one
FreshDatabase()
PTT.database.idle.upgrades.click = 100
unlockedTiers = {}
for _ = 1, Idle.KILLS_TO_UNLOCK - 1 do Idle.Click() end
Check(PTT.database.idle.unlocked == 1 and Idle.GetTierKills(1) == Idle.KILLS_TO_UNLOCK - 1, "nine kills are not enough")
Check(not Idle.IsUnlocked(2), "next enemy still locked after nine kills")
Idle.Click()
Check(PTT.database.idle.unlocked == 2 and Idle.IsUnlocked(2) and unlockedTiers[1] == 2, "tenth kill unlocks the next enemy")
Check(Idle.SelectMonster(2), "the unlocked enemy can be selected")

-- Farming an older enemy does not unlock anything
FreshDatabase()
PTT.database.idle.unlocked = 3
PTT.database.idle.upgrades.click = 100
for _ = 1, 25 do Idle.Click() end
Check(PTT.database.idle.unlocked == 3, "kills of a lower tier do not unlock the next one")
Check(Idle.GetTierKills(1) == 25, "kills are counted per tier")

-- Boss kills are counted separately
FreshDatabase()
PTT.database.idle.unlocked = 5
PTT.database.idle.allies.scout = 5000
Idle.SelectMonster(5)
Idle.Tick(1)
Check(PTT.database.idle.bossKills >= 1 and PTT.database.idle.lifetimeKills >= PTT.database.idle.bossKills, "boss kills counted")

-- Last tier stays unlocked at the end of the list
FreshDatabase()
PTT.database.idle.unlocked = Idle.GetMonsterCount()
PTT.database.idle.monsterIndex = Idle.GetMonsterCount()
PTT.database.idle.allies.scout = 1e9
Idle.Tick(1)
Check(PTT.database.idle.unlocked == Idle.GetMonsterCount(), "unlocked tier never exceeds the list")

-- Migration from saves that stored a level
FreshDatabase()
PTT.database.idle.level = 6
Idle.Migrate()
Check(PTT.database.idle.unlocked == 6, "old level becomes the unlocked tier")
Idle.Migrate()
Check(PTT.database.idle.unlocked == 6, "migration is stable")

-- Auto damage
FreshDatabase()
PTT.database.idle.allies.scout = 20
Idle.Tick(1)
Near(PTT.database.idle.runTime, 1, "tick adds time")
Check(PTT.database.idle.kills >= 1, "allies kill monsters automatically")
Idle.Tick(1000)
Near(PTT.database.idle.runTime, 1 + Idle.MAX_TICK, "tick is clamped")

FreshDatabase()
PTT.database.idle.allies.scout = 1
Idle.Tick(0.5)
Near(PTT.database.idle.monsterDamage, 0.5 * scout.damage, "damage accumulates between ticks")
Check(PTT.database.idle.kills == 0, "no kill yet")

FreshDatabase()
PTT.database.idle.allies.scout = 1e6
Idle.Tick(Idle.MAX_TICK)
Check(PTT.database.idle.kills > 0 and PTT.database.idle.kills <= 200, "huge damage cannot loop forever (" .. PTT.database.idle.kills .. " kills)")

for index = 1, Idle.GetMonsterCount() do
	Check(type(Idle.GetMonster(index).npc) == "number", "monster " .. index .. " has a model id")
end

FreshDatabase()
Idle.AddBuff("test", "x", 2, 3)
Idle.Tick(4)
Check(next(PTT.database.idle.buffs) == nil, "buff expires")

-- Income estimate used by events, bosses and the world bonus
FreshDatabase()
PTT.database.idle.allies.scout = 10
local monster = Idle.GetMonster(1)
Near(Idle.GetIncome(), 10 * scout.damage * monster.gold / monster.health, "income is damage times gold per health")

-- Enemy health curve: first enemy 10, first boss around 800
FreshDatabase()
Near(Idle.GetMonster(1).health, 10, "first enemy has 10 health")
Check(Idle.GetMonster(5).boss and Idle.GetMonster(5).health == 977, "first boss has 977 health like in Clicker Heroes (" .. Idle.GetMonster(5).health .. ")")
Check(Idle.GetMonster(5).health > Idle.GetMonster(4).health * 10, "bosses have far more health than normal enemies")

local expectedHealth = { 10, 26, 45, 68, 977, 140, 199 }
for index, expected in ipairs(expectedHealth) do
	Check(Idle.GetMonster(index).health == expected, "enemy " .. index .. " has " .. expected .. " health (got " .. Idle.GetMonster(index).health .. ")")
end

-- Gold per kill: about a fifteenth of the enemy's health, a bit random
FreshDatabase()
local seventeen = Idle.GetMonster(17)
Check(math.abs(seventeen.gold - seventeen.health / 15) < 1, "gold is health divided by 15 (" .. seventeen.gold .. " vs " .. seventeen.health .. ")")
Check(seventeen.gold > 600 and seventeen.gold < 1000, "a level 17 enemy pays around 750 gold")

local function GoldForRoll(roll)
	FreshDatabase()
	PTT.database.idle.unlocked = 17
	PTT.database.idle.monsterIndex = 17
	PTT.database.idle.monsterDamage = seventeen.health - 1
	local previous = Idle.random
	Idle.random = function() return roll end
	Idle.Click()
	Idle.random = previous
	return PTT.database.idle.gold
end
local low, middle, high = GoldForRoll(0), GoldForRoll(0.5), GoldForRoll(1)
Check(low < middle and middle < high, "gold varies with the roll (" .. low .. " < " .. middle .. " < " .. high .. ")")
Check(math.abs(low - seventeen.gold * 0.75) <= 1 and math.abs(high - seventeen.gold * 1.25) <= 1, "variation is plus or minus 25%")
Check(math.abs(middle - seventeen.gold) <= 1, "average roll pays the average gold")

-- Boss time limit
FreshDatabase()
local failedBosses = {}
Idle.OnBossFailed(function(boss) failedBosses[#failedBosses + 1] = boss.index end)
PTT.database.idle.unlocked = 5
Check(Idle.GetBossTimeLeft() == nil, "no timer against a normal enemy")
Check(Idle.SelectMonster(5), "select the first boss")
Near(Idle.GetBossTimeLeft(), Idle.BOSS_TIME_LIMIT, "timer starts at the limit")
Idle.Tick(5)
Near(Idle.GetBossTimeLeft(), Idle.BOSS_TIME_LIMIT - 5, "timer counts down")
for _ = 1, 4 do Idle.Tick(5) end
Check(#failedBosses == 0, "boss still there before the limit")
Idle.Tick(5)
Check(#failedBosses == 1 and failedBosses[1] == 5, "boss escapes after the limit")
Check(PTT.database.idle.monsterIndex == 4 and PTT.database.idle.monsterDamage == 0, "fight drops back to the previous enemy")
Check(Idle.GetBossTimeLeft() == nil, "timer gone after dropping back")

-- A boss killed in time pays out and starts a fresh timer
FreshDatabase()
PTT.database.idle.unlocked = 5
PTT.database.idle.allies.scout = 1000
Idle.SelectMonster(5)
local goldBefore = PTT.database.idle.gold
for _ = 1, 3 do Idle.Tick(2) end
Check(PTT.database.idle.lifetimeKills >= 1 and PTT.database.idle.gold > goldBefore, "strong damage kills the boss within the limit")
Check(PTT.database.idle.monsterIndex == 5, "stays on the boss after killing it")
Check(Idle.GetKillsToUnlock(5) == 5 and Idle.GetKillsToUnlock(1) == Idle.KILLS_TO_UNLOCK, "a boss needs five kills, other enemies ten")

-- Prestige
FreshDatabase()
Check(not Idle.Prestige(), "prestige locked early")
PTT.database.idle.gold = 5
PTT.database.idle.allies.recruit = 5000
PTT.database.idle.allies.scout = 2000
PTT.database.idle.professions.mining = 4
PTT.database.idle.unlocked = Idle.PRESTIGE_UNLOCK_LEVEL - 1
PTT.database.idle.monsterIndex = 4
PTT.database.idle.lifetimeGold = 4e6
PTT.database.idle.renown = 1
Check(not Idle.Prestige(), "prestige locked below the unlock level")
PTT.database.idle.unlocked = Idle.PRESTIGE_UNLOCK_LEVEL
Check(Idle.GetPrestigeGain() == 3, "one soul per 2000 hero levels")
PTT.database.idle.allies.scout = 1999
Check(Idle.GetPrestigeGain() == 3, "levels are summed before dividing")
PTT.database.idle.allies.scout = 1000
Check(Idle.GetPrestigeGain() == 3, "3 souls at 6000 levels")
PTT.database.idle.allies.scout = 999
Check(Idle.GetPrestigeGain() == 2, "rounds down")
PTT.database.idle.allies.scout = 2000
Check(Idle.Prestige(), "prestige works")
local state = PTT.database.idle
Check(state.renown == 4 and state.renownEarned == 3 and state.gold == 0 and next(state.allies) == nil and state.unlocked == 1 and next(state.tierKills) == nil and state.monsterIndex == 1, "prestige resets run")
Check(state.professions.mining == 4, "professions kept")
Check(state.lifetimeGold == 4e6, "lifetime kept")

-- Spells
FreshDatabase()
local function Spell(id, index)
	return Idle.spells[id][index]
end

local clickSpell = Spell("click", 1)
Check(clickSpell.level == 10 and clickSpell.click == 0.5, "first click spell is level 10")
PTT.database.idle.gold = 1e12
Check(not Idle.IsSpellVisible(clickSpell) and not Idle.CanBuySpell(clickSpell), "spells stay hidden until the hero is level 1")
PTT.database.idle.upgrades.click = 1
Check(Idle.IsSpellVisible(clickSpell) and Idle.CanBuySpell(clickSpell), "first spell is buyable at hero level 1")
Check(not Idle.IsSpellVisible(Spell("click", 2)), "second spell hidden below its level")
local clickBeforeSpell = Idle.GetClickDamage()
Check(Idle.BuySpell(clickSpell), "first spell bought")
Near(Idle.GetClickDamage(), clickBeforeSpell * 1.5, "click spell adds 50% click damage")
Check(Idle.IsSpellVisible(Spell("click", 2)) and Idle.CanBuySpell(Spell("click", 2)), "buying a spell shows and unlocks the next")
Check(not Idle.BuySpell(clickSpell), "a bought spell cannot be bought again")
Check(not Idle.IsSpellVisible(Spell("click", 3)), "third spell still hidden")
Check(Spell("click", 2).cost > clickSpell.cost, "later spells cost more")
PTT.database.idle.upgrades.click = 50
Check(Idle.CanBuySpell(Spell("click", 3)), "a spell is buyable once the hero reaches its level, without the previous one")
Check(Idle.BuySpell(Spell("click", 3)) and not Idle.IsSpellBought(Spell("click", 2)), "spells can be bought out of order")
PTT.database.idle.spells = { click = 2 }
Check(Idle.IsSpellBought(Spell("click", 2)) and Idle.GetSpellCount("click") == 2, "old saves with a spell count still load")

FreshDatabase()
PTT.database.idle.gold = 1e30
PTT.database.idle.allies.recruit = 25
PTT.database.idle.allies.mage = 25
local damageBefore = Idle.GetDamagePerSecond()
Check(Idle.BuySpell(Spell("recruit", 1)), "warrior spell 1")
Near(Idle.GetAllyDamage(recruit), 25 * recruit.damage * 1.25, "own spell raises own damage by 25%")
Check(Idle.BuySpell(Spell("recruit", 2)), "warrior spell 2 at level 25")
Check(Idle.CanBuySpell(Spell("recruit", 3)), "bought previous spell makes the next one buyable")
Check(Idle.BuySpell(Spell("mage", 1)), "mage spell 1")
Check(Idle.BuySpell(Spell("mage", 2)), "mage spell 2 boosts all heroes")
local mage = Idle.definitions.ally[5]
Near(Idle.GetAllyDamage(mage), 25 * mage.damage * 1.6 * 1.1, "mage spells: own and all-heroes bonus")
Near(Idle.GetAllyDamage(recruit), 25 * recruit.damage * 1.75 * 1.1, "all-heroes bonus applies to other heroes")
Check(Idle.GetDamagePerSecond() > damageBefore, "spells raise total damage")

FreshDatabase()
local seenAll = false
for _, spell in ipairs(Idle.spells.recruit) do
	seenAll = seenAll or spell.all ~= nil
end
Check(not seenAll, "cheap heroes only boost themselves")
Check(#Idle.spells.slayer == 5 and Idle.spells.slayer[5].level == 100, "five spells up to level 100")
Check(#Idle.spells.click == 6 and Idle.spells.click[6].level == 150 and Idle.spells.click[6].click == 2, "weapon training has a sixth, strongest spell")

-- Gold and click-share spells
FreshDatabase()
PTT.database.idle.gold = 1e30
PTT.database.idle.allies.scout = 25
PTT.database.idle.allies.hunter = 50
Idle.BuySpell(Spell("scout", 1))
local goldBefore = Idle.GetGoldMultiplier()
Idle.BuySpell(Spell("scout", 2))
Near(Idle.GetGoldMultiplier(), goldBefore + 0.1, "scout spell adds gold")
for index = 1, 3 do Idle.BuySpell(Spell("hunter", index)) end
local hunterDamage = Idle.GetBaseDamagePerSecond()
Near(Idle.GetClickDamage(), (1 + hunterDamage * 0.005) * Idle.GetDamageMultiplier(), "hunter spell raises the click share of total damage")
FreshDatabase()
PTT.database.idle.allies.hunter = 50
Near(Idle.GetClickDamage(), 1 * Idle.GetDamageMultiplier(), "heroes add no click damage without the spell")

FreshDatabase()
PTT.database.idle.gold = 1e30
PTT.database.idle.upgrades.click = 10
Idle.BuySpell(Spell("click", 1))
PTT.database.idle.unlocked = Idle.PRESTIGE_UNLOCK_LEVEL
Idle.Prestige()
Check(Idle.GetSpellCount("click") == 0, "prestige resets spells")

-- Heroes are revealed one by one
FreshDatabase()
Check(Idle.UpdateRevealedHeroes() == 1, "only the first hero at the start")
PTT.database.idle.gold = 14
Check(Idle.UpdateRevealedHeroes() == 1, "next hero stays hidden below the price of the last visible one")
PTT.database.idle.gold = 15
Check(Idle.UpdateRevealedHeroes() == 2, "next hero shows when the last visible one is affordable")
PTT.database.idle.gold = 0
Check(Idle.UpdateRevealedHeroes() == 2, "revealed heroes stay visible")
PTT.database.idle.allies.scout = 1
Check(Idle.UpdateRevealedHeroes() == 3, "owning a hero reveals the next")
PTT.database.idle.gold = 1e30
Check(Idle.UpdateRevealedHeroes() == #Idle.definitions.ally, "capped at the last hero")

-- Number formatting
Check(PTT.FormatNumber(0) == "0", "format 0")
Check(PTT.FormatNumber(999) == "999", "format 999")
Check(PTT.FormatNumber(1500) == "1,500", "below 100k is written out")
Check(PTT.FormatNumber(5000) == "5,000", "no abbreviation for 5000")
Check(PTT.FormatNumber(99999) == "99,999", "99999 written out")
Check(PTT.FormatNumber(100000) == "100K", "100k abbreviated without decimals")
Check(PTT.FormatNumber(123456) == "123.46K", "format K")
Check(PTT.FormatNumber(1.5e6) == "1.5M", "trailing zero trimmed")
Check(PTT.FormatNumber(2e6) == "2M", "no decimals when round")
Check(PTT.FormatNumber(999999.9) == "1M", "rounding carries to the next suffix")
local english = PTT.L
PTT.L = { thousandsSeparator = ".", decimalSeparator = "," }
Check(PTT.FormatNumber(5000) == "5.000" and PTT.FormatNumber(1.5e6) == "1,5M", "German separators")
PTT.L = english
Check(PTT.FormatNumber(1e100):find("e") ~= nil, "huge numbers use scientific notation")
Check(PTT.FormatDuration(3725) == "1:02:05", "duration hours")
Check(PTT.FormatDuration(65) == "1:05", "duration minutes")

print(failures == 0 and "IDLE OK" or (failures .. " FAILURES"))

-- Balance simulation: a greedy player over one prestige period.
if arg and arg[1] == "simulate" then
	FreshDatabase()
	state = PTT.database.idle

	local CLICKS_PER_SECOND = 4

	-- The best purchase by payback time, counting click damage at the bot's click rate.
	local function BestPurchase()
		local best
		for _, definition in ipairs(Idle.definitions.ally) do
			local gain = Idle.GetAllyUnitDamage(definition) * Idle.GetDamageMultiplier()
			local score = Idle.GetCost("ally", definition, 1) / gain
			if not best or score < best.score then
				best = { kind = "ally", definition = definition, score = score }
			end
		end

		local before = Idle.GetClickDamage()
		state.upgrades.click = (state.upgrades.click or 0) + 1
		local gain = (Idle.GetClickDamage() - before) * CLICKS_PER_SECOND
		state.upgrades.click = state.upgrades.click - 1
		local score = Idle.GetCost("upgrade", click, 1) / gain
		if score < best.score then
			best = { kind = "upgrade", definition = click, score = score }
		end
		return best
	end


	-- Fight the strongest monster that dies within a few seconds.
	local function ChooseMonster()
		local dps = Idle.GetDamagePerSecond() + Idle.GetClickDamage() * 2
		local choice = 1
		for index = 1, math.min(state.unlocked, Idle.GetMonsterCount()) do
			local monster = Idle.GetMonster(index)
			if monster.health / dps <= (monster.boss and Idle.BOSS_TIME_LIMIT * 0.7 or 4) then
				choice = index
			end
		end
		Idle.SelectMonster(choice)
	end

	for second = 1, 10 * 3600 do
		if second % 20 == 1 then
			ChooseMonster()
		end

		for _ = 1, CLICKS_PER_SECOND do
			Idle.Click()
		end
		Idle.Tick(1)

		while true do
			local purchase = BestPurchase()
			if state.gold < Idle.GetCost(purchase.kind, purchase.definition, 1) then
				break
			end
			Idle.Buy(purchase.kind, purchase.definition, 1)
		end

		if second == 60 or second == 600 or second == 1800 or second == 3600 or second == 7200 or second == 18000 or second == 36000 then
			print(string.format("%5.1fmin  tier %2d  monster %2d  dps %-9s  runGold %-9s  kills %-6d  prestigeGain %d",
				second / 60, state.unlocked, state.monsterIndex, PTT.FormatNumber(Idle.GetDamagePerSecond()), PTT.FormatNumber(state.runGold), state.kills, Idle.GetPrestigeGain()))
		end
	end
end

os.exit(failures == 0 and 0 or 1)
