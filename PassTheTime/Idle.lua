local _, PTT = ...

local Idle = {}
PTT.Idle = Idle

Idle.PRESTIGE_UNLOCK_LEVEL = 100
Idle.LEVELS_PER_SOUL = 2000
Idle.PROFESSION_MAX_LEVEL = 75
-- Every this many levels a profession level costs one more soul.
Idle.PROFESSION_COST_STEP = 25
Idle.TIER_DAMAGE_BONUS = 0.03
Idle.MAX_TICK = 5
Idle.FIGHT_INTERVAL = 0.2
Idle.MAX_CLICKS_PER_SECOND = 20

Idle.MONSTER_BASE_HEALTH = 10
Idle.GOLD_PER_HEALTH_BASE = 1 / 15
Idle.GOLD_VARIATION = 0.25
Idle.MONSTER_HEALTH_GROWTH = 1.55
Idle.GOLD_PER_HEALTH_GROWTH = 1
Idle.BOSS_HEALTH_FACTOR = 10
Idle.BOSS_TIME_LIMIT = 30
Idle.BOSS_GOLD_MULTIPLIER = 10
Idle.KILLS_TO_UNLOCK = 10
Idle.BOSS_KILLS_TO_UNLOCK = 5

-- Set by the network layer, not saved.
Idle.groupBonus = 0

-- Not saved: the boss timer restarts after a login.
Idle.bossTimer = nil

local NUMBER_SUFFIXES = { "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

-- Numbers below this are written out in full.
local ABBREVIATION_START = 100000

function PTT.FormatNumber(value)
	if value ~= value then
		return "0"
	end

	local thousands, decimal = PTT.L.thousandsSeparator, PTT.L.decimalSeparator

	if value < ABBREVIATION_START then
		if value < 10 and value ~= math.floor(value) then
			return (string.format("%.1f", value):gsub("%.", decimal))
		end

		local text = string.format("%d", math.floor(value))
		local replaced
		repeat
			text, replaced = text:gsub("^(-?%d+)(%d%d%d)", "%1" .. thousands .. "%2")
		until replaced == 0
		return text
	end

	local tier = math.min(math.floor(math.log(value) / math.log(1000)), #NUMBER_SUFFIXES)
	local scaled = value / 1000 ^ tier
	-- Rounding to two decimals can reach 1000 and needs the next suffix.
	if scaled >= 999.995 and tier < #NUMBER_SUFFIXES then
		tier = tier + 1
		scaled = value / 1000 ^ tier
	end
	if scaled >= 1000 then
		return string.format("%.2e", value)
	end

	local text = string.format("%.2f", scaled):gsub("0+$", ""):gsub("%.$", "")
	return (text:gsub("%.", decimal)) .. NUMBER_SUFFIXES[tier]
end

function PTT.FormatDuration(seconds)
	seconds = math.max(0, math.floor(seconds))
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor(seconds % 3600 / 60)
	local remaining = seconds % 60

	if hours > 0 then
		return string.format("%d:%02d:%02d", hours, minutes, remaining)
	end
	return string.format("%d:%02d", minutes, remaining)
end

-- Names live in Localization.lua as <kind>_<id>.
Idle.definitions = {
	ally = {
		{ id = "recruit", cost = 15, damage = 0.05 },
		{ id = "scout", cost = 100, damage = 0.5 },
		{ id = "footman", cost = 1100, damage = 4 },
		{ id = "hunter", cost = 12000, damage = 24 },
		{ id = "mage", cost = 130000, damage = 130 },
		{ id = "warlock", cost = 1.4e6, damage = 700 },
		{ id = "paladin", cost = 2e7, damage = 3900 },
		{ id = "slayer", cost = 3.3e8, damage = 22000 },
	},
	upgrade = {
		{ id = "click", cost = 10 },
	},
	profession = {
		-- Cost is renown souls per level (plus one per PROFESSION_COST_STEP levels owned), perLevel the bonus per level (seconds for bossTime).
		{ id = "herbalism", cost = 1, effect = "heroCost", perLevel = 0.005 },
		{ id = "mining", cost = 1, effect = "gold", perLevel = 0.02 },
		{ id = "skinning", cost = 1, effect = "click", perLevel = 0.02 },
		{ id = "alchemy", cost = 2, effect = "buffDuration", perLevel = 0.02 },
		{ id = "blacksmithing", cost = 2, effect = "damage", perLevel = 0.015 },
		{ id = "enchanting", cost = 3, effect = "bossTime", perLevel = 2 },
	},
}

for kind, list in pairs(Idle.definitions) do
	for _, definition in ipairs(list) do
		definition.nameKey = kind .. "_" .. definition.id
	end
end

local STATE_KEYS = { ally = "allies", upgrade = "upgrades", profession = "professions" }
local GROWTH = { ally = 1.07, upgrade = 1.07 }

-- Every hero has five spells and the click upgrade six, bought in order once the hero reaches the level.
Idle.SPELL_LEVELS = { 10, 25, 50, 75, 100, 150 }
local SPELL_COST_FACTORS = { 40, 150, 800, 4500, 25000, 200000 }

-- Effect per spell: own = this hero's damage, all = every hero's damage, click = click damage,
-- clickShare = share of the total hero damage added to the click, gold = gold from kills. Values are fractions.
local SPELL_EFFECTS = {
	click = { { click = 0.5 }, { click = 0.75 }, { click = 1 }, { click = 1.25 }, { click = 1.5 }, { click = 2 } },
	recruit = { { own = 0.25 }, { own = 0.5 }, { own = 0.75 }, { own = 1 }, { own = 2 } },
	scout = { { own = 0.4 }, { gold = 0.1 }, { own = 0.8 }, { own = 1.2 }, { gold = 0.15 } },
	footman = { { own = 0.5 }, { own = 1 }, { own = 1.5 }, { all = 0.05 }, { own = 3 } },
	hunter = { { own = 0.75 }, { own = 1.5 }, { clickShare = 0.005 }, { own = 2.5 }, { own = 4 } },
	mage = { { own = 0.6 }, { all = 0.1 }, { own = 1.2 }, { all = 0.15 }, { own = 2.4 } },
	warlock = { { own = 0.5 }, { all = 0.08 }, { own = 1.5 }, { all = 0.12 }, { own = 3 } },
	paladin = { { own = 0.5 }, { all = 0.1 }, { own = 1.5 }, { all = 0.2 }, { own = 3 } },
	slayer = { { own = 0.6 }, { all = 0.15 }, { own = 1.8 }, { all = 0.25 }, { own = 4 } },
}

-- Idle.spells[id] = list of { id, kind, index, level, cost, nameKey, plus the effect field }.
Idle.spells = {}

local function BuildSpells(kind, definition)
	local list = {}
	for index, effect in ipairs(SPELL_EFFECTS[definition.id]) do
		local spell = {
			id = definition.id,
			kind = kind,
			index = index,
			level = Idle.SPELL_LEVELS[index],
			cost = definition.cost * SPELL_COST_FACTORS[index],
			nameKey = "spell_" .. definition.id .. "_" .. index,
		}
		for field, value in pairs(effect) do
			spell[field] = value
		end
		list[index] = spell
	end
	Idle.spells[definition.id] = list
end

BuildSpells("upgrade", Idle.definitions.upgrade[1])
for _, definition in ipairs(Idle.definitions.ally) do
	BuildSpells("ally", definition)
end

-- Levels 1-100 with a boss every fifth level, then the raid bosses as the strongest enemies.
-- { boss, NPC id for the 3D model }; the name is npc_<id> in Localization.lua.
local ZONE_MONSTERS = {
	{ false, 299 }, { false, 257 }, { false, 38 }, { false, 117 }, { true, 448 },
	{ false, 646 }, { false, 116 }, { false, 3653 }, { false, 3669 }, { true, 639 },
	{ false, 1716 }, { false, 4275 }, { false, 3974 }, { false, 6487 }, { true, 3977 },
	{ false, 10436 }, { false, 10435 }, { false, 10439 }, { false, 9033 }, { true, 10440 },
	{ false, 9019 }, { false, 10429 }, { false, 1853 }, { false, 15338 }, { true, 15264 },
	{ false, 4540 }, { false, 4542 }, { false, 4302 }, { false, 4303 }, { true, 12201 },
	{ false, 8531 }, { false, 8607 }, { false, 8548 }, { false, 8550 }, { true, 2748 },
	{ false, 7077 }, { false, 7023 }, { false, 7523 }, { false, 8504 }, { true, 5709 },
	{ false, 5267 }, { false, 5260 }, { false, 5277 }, { false, 5708 }, { true, 9568 },
	{ false, 9819 }, { false, 9818 }, { false, 9096 }, { false, 9517 }, { true, 10430 },
	{ false, 10742 }, { false, 10442 }, { false, 8890 }, { false, 5081 }, { true, 9816 },
	{ false, 7439 }, { false, 7430 }, { false, 7448 }, { false, 7440 }, { true, 7273 },
	{ false, 6502 }, { false, 6498 }, { false, 6516 }, { false, 6509 }, { true, 11380 },
	{ false, 11353 }, { false, 11373 }, { false, 11347 }, { false, 11361 }, { true, 11382 },
	{ false, 11372 }, { false, 9020 }, { false, 7138 }, { false, 7157 }, { true, 6109 },
	{ false, 15196 }, { false, 15262 }, { false, 15335 }, { false, 15311 }, { true, 14890 },
	{ false, 12100 }, { false, 11671 }, { false, 11658 }, { false, 12076 }, { true, 14889 },
	{ false, 11666 }, { false, 11667 }, { false, 11673 }, { false, 11672 }, { true, 14887 },
	{ false, 12460 }, { false, 12422 }, { false, 12459 }, { false, 12457 }, { true, 14888 },
	{ false, 16168 }, { false, 16146 }, { false, 16165 }, { false, 15980 }, { true, 12397 },
}

-- NPC ids in order: Molten Core, Onyxia, Blackwing Lair, Zul'Gurub, Temple of Ahn'Qiraj, Naxxramas.
local RAID_BOSSES = {
	12118, 11982, 12259, 12057, 12264, 12056, 12098, 11988, 12018, 11502,
	10184,
	12435, 13020, 12017, 11983, 14601, 11981, 14020, 11583,
	14517, 14507, 14510, 14509, 14515, 15082,
	15263, 15516, 15510, 15299, 15509, 15276, 15517, 15339,
	15956, 15953, 15952, 15954, 15936, 16011, 16061, 16060, 16064, 16028, 15931, 15932, 15928, 15989, 15990,
}

Idle.monsterDefinitions = {}
for _, entry in ipairs(ZONE_MONSTERS) do
	Idle.monsterDefinitions[#Idle.monsterDefinitions + 1] = { nameKey = "npc_" .. entry[2], boss = entry[1], npc = entry[2] }
end
for _, npc in ipairs(RAID_BOSSES) do
	Idle.monsterDefinitions[#Idle.monsterDefinitions + 1] = { nameKey = "npc_" .. npc, boss = true, npc = npc }
end

function Idle.GetName(definition)
	return PTT.L[definition.nameKey]
end

local function GetState()
	return PTT.database.idle
end

---------------------------------------------------------------------------
-- Upgrades
---------------------------------------------------------------------------

function Idle.GetOwned(kind, id)
	return GetState()[STATE_KEYS[kind]][id] or 0
end

-- Professions cost renown souls, everything else gold.
function Idle.GetBalance(kind)
	local state = GetState()
	return kind == "profession" and state.renown or state.gold
end

-- Sum of floor(level / PROFESSION_COST_STEP) for all levels below the given one.
local function ProfessionSurcharge(levels)
	local steps = math.floor(levels / Idle.PROFESSION_COST_STEP)
	return Idle.PROFESSION_COST_STEP * steps * (steps - 1) / 2 + steps * (levels % Idle.PROFESSION_COST_STEP)
end

function Idle.GetCost(kind, definition, amount)
	if kind == "profession" then
		local owned = Idle.GetOwned(kind, definition.id)
		return definition.cost * amount + ProfessionSurcharge(owned + amount) - ProfessionSurcharge(owned)
	end

	local growth = GROWTH[kind]
	local owned = Idle.GetOwned(kind, definition.id)
	return definition.cost * growth ^ owned * (growth ^ amount - 1) / (growth - 1) * Idle.GetCostFactor(kind)
end

function Idle.GetRemainingCapacity(kind, definition)
	if kind == "profession" then
		return Idle.PROFESSION_MAX_LEVEL - Idle.GetOwned(kind, definition.id)
	end
	return math.huge
end

function Idle.GetMaxAffordable(kind, definition)
	local capacity = Idle.GetRemainingCapacity(kind, definition)
	if capacity <= 0 then
		return 0
	end

	local balance = Idle.GetBalance(kind)
	if kind == "profession" then
		local amount = 0
		while amount < capacity and Idle.GetCost(kind, definition, amount + 1) <= balance do
			amount = amount + 1
		end
		return amount
	end

	local growth = GROWTH[kind]
	local owned = Idle.GetOwned(kind, definition.id)
	local discounted = balance / Idle.GetCostFactor(kind)
	local amount = math.floor(math.log(discounted * (growth - 1) / (definition.cost * growth ^ owned) + 1) / math.log(growth))
	amount = math.max(0, math.min(amount, capacity))

	-- The logarithm can be off by one at exact prices.
	while amount < capacity and Idle.GetCost(kind, definition, amount + 1) <= balance do
		amount = amount + 1
	end
	while amount > 0 and Idle.GetCost(kind, definition, amount) > balance do
		amount = amount - 1
	end
	return amount
end

-- amount is a number or "max". Returns how many were bought.
function Idle.Buy(kind, definition, amount)
	local state = GetState()
	local count = amount == "max" and Idle.GetMaxAffordable(kind, definition) or amount

	if count < 1 or count > Idle.GetRemainingCapacity(kind, definition) then
		return 0
	end

	local cost = Idle.GetCost(kind, definition, count)
	if Idle.GetBalance(kind) < cost then
		return 0
	end

	if kind == "profession" then
		state.renown = state.renown - cost
	else
		state.gold = state.gold - cost
		state.goldSpent = (state.goldSpent or 0) + cost
	end
	local owned = state[STATE_KEYS[kind]]
	owned[definition.id] = (owned[definition.id] or 0) + count
	return count
end

-- The next hero shows up once the player could afford (or owns) the last visible one; it stays visible.
function Idle.UpdateRevealedHeroes()
	local state = GetState()
	local heroes = Idle.definitions.ally
	local revealed = math.max(1, state.heroesRevealed or 1)

	while revealed < #heroes do
		local definition = heroes[revealed]
		if Idle.GetOwned("ally", definition.id) < 1 and state.gold < Idle.GetCost("ally", definition, 1) then
			break
		end
		revealed = revealed + 1
	end

	state.heroesRevealed = revealed
	return revealed
end

---------------------------------------------------------------------------
-- Spells
---------------------------------------------------------------------------

-- state.spells[id] is a set of bought spell indexes. Older saves stored a count instead.
local function GetBoughtSpells(id)
	local state = GetState()
	state.spells = state.spells or {}

	local bought = state.spells[id]
	if type(bought) == "number" then
		local converted = {}
		for index = 1, bought do
			converted[index] = true
		end
		state.spells[id] = converted
		return converted
	end
	return bought or {}
end

function Idle.IsSpellBought(spell)
	return GetBoughtSpells(spell.id)[spell.index] == true
end

function Idle.GetSpellCount(id)
	local count = 0
	for _ in pairs(GetBoughtSpells(id)) do
		count = count + 1
	end
	return count
end

-- Shown (and buyable) once the hero exists and either the previous spell is bought or the hero has the spell's level.
function Idle.IsSpellVisible(spell)
	if Idle.GetOwned(spell.kind, spell.id) < 1 then
		return false
	end

	if spell.index == 1 or Idle.GetOwned(spell.kind, spell.id) >= spell.level or Idle.IsSpellBought(spell) then
		return true
	end
	return GetBoughtSpells(spell.id)[spell.index - 1] == true
end

function Idle.CanBuySpell(spell)
	return Idle.IsSpellVisible(spell) and not Idle.IsSpellBought(spell) and GetState().gold >= spell.cost
end

function Idle.BuySpell(spell)
	if not Idle.CanBuySpell(spell) then
		return false
	end

	local state = GetState()
	state.gold = state.gold - spell.cost
	state.goldSpent = (state.goldSpent or 0) + spell.cost
	GetBoughtSpells(spell.id)
	state.spells[spell.id] = state.spells[spell.id] or {}
	state.spells[spell.id][spell.index] = true
	return true
end

-- Sum of one effect field over the bought spells of the given ids.
local function SumSpellBonus(field, ids)
	local total = 0
	for _, id in ipairs(ids) do
		for _, spell in ipairs(Idle.spells[id]) do
			if Idle.IsSpellBought(spell) then
				total = total + (spell[field] or 0)
			end
		end
	end
	return total
end

function Idle.GetOwnSpellBonus(id)
	return SumSpellBonus("own", { id })
end

local function SumHeroSpellBonus(field)
	local ids = {}
	for _, definition in ipairs(Idle.definitions.ally) do
		ids[#ids + 1] = definition.id
	end
	return SumSpellBonus(field, ids)
end

function Idle.GetAllHeroesSpellBonus()
	return SumHeroSpellBonus("all")
end

function Idle.GetClickSpellBonus()
	return SumSpellBonus("click", { "click" })
end

function Idle.GetClickShareSpellBonus()
	return SumHeroSpellBonus("clickShare")
end

function Idle.GetGoldSpellBonus()
	return SumHeroSpellBonus("gold")
end

---------------------------------------------------------------------------
-- Damage and gold
---------------------------------------------------------------------------

-- Damage of one hero of this kind; only spells raise it.
function Idle.GetAllyUnitDamage(definition)
	return definition.damage
		* (1 + Idle.GetOwnSpellBonus(definition.id))
		* (1 + Idle.GetAllHeroesSpellBonus())
end

function Idle.GetAllyDamage(definition)
	return Idle.GetOwned("ally", definition.id) * Idle.GetAllyUnitDamage(definition)
end

function Idle.GetBaseDamagePerSecond()
	local total = 0
	for _, definition in ipairs(Idle.definitions.ally) do
		total = total + Idle.GetAllyDamage(definition)
	end
	return total
end

-- Total bonus of one effect from all professions that grant it.
function Idle.GetProfessionBonus(effect)
	local total = 0
	for _, definition in ipairs(Idle.definitions.profession) do
		if definition.effect == effect then
			total = total + Idle.GetOwned("profession", definition.id) * (definition.perLevel or 0)
		end
	end
	return total
end

-- Heroes get cheaper, at most by 50%.
function Idle.GetCostFactor(kind)
	if kind ~= "ally" then
		return 1
	end
	return 1 - math.min(0.5, Idle.GetProfessionBonus("heroCost"))
end

function Idle.GetBossTimeLimit()
	return Idle.BOSS_TIME_LIMIT + Idle.GetProfessionBonus("bossTime")
end

function Idle.GetBuffMultiplier()
	local multiplier = 1
	for _, buff in pairs(GetState().buffs) do
		multiplier = multiplier * buff.multiplier
	end
	return multiplier
end

function Idle.GetDamageMultiplier()
	local state = GetState()
	return (1 + Idle.GetProfessionBonus("damage"))
		* (1 + (state.unlocked - 1) * Idle.TIER_DAMAGE_BONUS)
		* (1 + Idle.groupBonus)
		* Idle.GetBuffMultiplier()
end

function Idle.GetGoldMultiplier()
	return 1 + Idle.GetProfessionBonus("gold") + Idle.GetGoldSpellBonus()
end

function Idle.GetDamagePerSecond()
	return Idle.GetBaseDamagePerSecond() * Idle.GetDamageMultiplier()
end

function Idle.GetClickDamage()
	local level = Idle.GetOwned("upgrade", "click")
	local base = 1 + level * (1 + level * 0.05) + Idle.GetBaseDamagePerSecond() * Idle.GetClickShareSpellBonus()
	return base * Idle.GetDamageMultiplier() * (1 + Idle.GetProfessionBonus("click")) * (1 + Idle.GetClickSpellBonus())
end

---------------------------------------------------------------------------
-- Monsters
---------------------------------------------------------------------------

function Idle.GetMonster(index)
	local definition = Idle.monsterDefinitions[index]
	-- Clicker Heroes curve: 10, 26, 45, 68, boss 977, 140, 199 ...
	local tier = index - 1
	local tierHealth = Idle.MONSTER_BASE_HEALTH * (tier + Idle.MONSTER_HEALTH_GROWTH ^ tier)
	local health = math.ceil(tierHealth)
	local gold = tierHealth * Idle.GOLD_PER_HEALTH_BASE * Idle.GOLD_PER_HEALTH_GROWTH ^ tier

	if definition.boss then
		health = math.floor(tierHealth * Idle.BOSS_HEALTH_FACTOR)
		gold = gold * Idle.BOSS_GOLD_MULTIPLIER
	end

	return {
		index = index,
		nameKey = definition.nameKey,
		boss = definition.boss,
		npc = definition.npc,
		health = health,
		gold = gold,
	}
end

function Idle.GetMonsterCount()
	return #Idle.monsterDefinitions
end

function Idle.IsUnlocked(index)
	return index >= 1 and index <= Idle.GetMonsterCount() and index <= GetState().unlocked
end

function Idle.SelectMonster(index)
	local state = GetState()
	if not Idle.IsUnlocked(index) or index == state.monsterIndex then
		return false
	end

	state.monsterIndex = index
	state.monsterDamage = 0
	Idle.bossTimer = nil
	return true
end

-- Seconds left to kill the current boss, nil while fighting a normal enemy.
function Idle.GetBossTimeLeft()
	if not Idle.GetMonster(GetState().monsterIndex).boss then
		return nil
	end
	return Idle.bossTimer or Idle.GetBossTimeLimit()
end

local bossFailedListeners = {}

function Idle.OnBossFailed(listener)
	bossFailedListeners[#bossFailedListeners + 1] = listener
end

-- Too slow: the boss escapes and the fight drops back to the previous enemy.
local function FailBoss()
	local state = GetState()
	local boss = Idle.GetMonster(state.monsterIndex)

	state.monsterIndex = math.max(1, state.monsterIndex - 1)
	state.monsterDamage = 0
	state.autoAdvance = false
	Idle.bossTimer = nil

	for _, listener in ipairs(bossFailedListeners) do
		listener(boss)
	end
end

function Idle.GetCurrentMonster()
	local state = GetState()
	local monster = Idle.GetMonster(state.monsterIndex)
	monster.currentHealth = math.max(0, monster.health - state.monsterDamage)
	return monster
end

-- Expected gold per second while fighting the current monster.
function Idle.GetIncome()
	local monster = Idle.GetMonster(GetState().monsterIndex)
	return Idle.GetDamagePerSecond() * (monster.gold / monster.health) * Idle.GetGoldMultiplier()
end

function Idle.GetTierKills(index)
	return GetState().tierKills[index] or 0
end

function Idle.GetKillsToUnlock(index)
	return Idle.monsterDefinitions[index].boss and Idle.BOSS_KILLS_TO_UNLOCK or Idle.KILLS_TO_UNLOCK
end

-- Saves from before the unlock system stored a level instead.
function Idle.Migrate()
	local state = GetState()
	if state.unlocked == 1 and (state.level or 1) > 1 then
		state.unlocked = math.min(state.level, Idle.GetMonsterCount())
	end
end

function Idle.AddGold(amount)
	local state = GetState()
	state.gold = state.gold + amount
	state.runGold = state.runGold + amount
	state.lifetimeGold = state.lifetimeGold + amount
	state.bestReward = math.max(state.bestReward or 0, amount)
end

-- Not saved: the time of the current login session.
Idle.sessionTime = 0

function Idle.StartSession()
	local state = GetState()
	state.sessions = (state.sessions or 0) + 1
	Idle.sessionTime = 0
end

local killListeners = {}
local unlockListeners = {}

function Idle.OnKill(listener)
	killListeners[#killListeners + 1] = listener
end

function Idle.OnUnlock(listener)
	unlockListeners[#unlockListeners + 1] = listener
end

-- Replaced in tests.
Idle.random = math.random

-- Each kill pays a little more or less than average, but at least 1 gold.
local function RollGold(monster)
	local factor = 1 - Idle.GOLD_VARIATION + 2 * Idle.GOLD_VARIATION * Idle.random()
	return math.max(1, math.floor(monster.gold * Idle.GetGoldMultiplier() * factor + 0.5))
end

local function KillMonster()
	local state = GetState()
	local monster = Idle.GetMonster(state.monsterIndex)
	local gold = RollGold(monster)

	Idle.AddGold(gold)
	state.kills = state.kills + 1
	state.lifetimeKills = state.lifetimeKills + 1
	state.monsterDamage = 0
	Idle.bossTimer = nil

	if monster.boss then
		state.bossKills = state.bossKills + 1
	end

	-- Ten kills (five for a boss) of the highest unlocked enemy open up the next one.
	state.tierKills[monster.index] = (state.tierKills[monster.index] or 0) + 1
	if monster.index == state.unlocked
		and state.unlocked < Idle.GetMonsterCount()
		and state.tierKills[monster.index] >= Idle.GetKillsToUnlock(monster.index) then
		state.unlocked = state.unlocked + 1
		for _, listener in ipairs(unlockListeners) do
			listener(state.unlocked)
		end
	end

	if state.autoAdvance and Idle.IsUnlocked(monster.index + 1) then
		state.monsterIndex = monster.index + 1
	end

	for _, listener in ipairs(killListeners) do
		listener(monster, gold)
	end
end

-- Replaced in tests.
function Idle.clock()
	return GetTime()
end

-- Times of the clicks counted in the last second, not saved.
local recentClicks = {}

function Idle.ResetClickLimit()
	recentClicks = {}
end

-- Never more than MAX_CLICKS_PER_SECOND accepted clicks within any one second.
local function IsClickAllowed()
	local now = Idle.clock()

	while recentClicks[1] and now - recentClicks[1] >= 1 do
		table.remove(recentClicks, 1)
	end

	if #recentClicks >= Idle.MAX_CLICKS_PER_SECOND then
		return false
	end

	recentClicks[#recentClicks + 1] = now
	return true
end

-- Returns the damage dealt, 0 while the click limit is reached.
function Idle.Click()
	if not IsClickAllowed() then
		return 0
	end

	local state = GetState()
	local damage = Idle.GetClickDamage()
	state.clicks = state.clicks + 1
	state.monsterDamage = state.monsterDamage + damage

	if state.monsterDamage >= Idle.GetMonster(state.monsterIndex).health then
		KillMonster()
	end
	return damage
end

local function Fight(dt)
	local state = GetState()
	local damagePerSecond = Idle.GetDamagePerSecond()
	if damagePerSecond <= 0 then
		return
	end

	-- One hit per FIGHT_INTERVAL, at most one kill per hit, overkill is lost.
	local remaining = dt
	while remaining > 1e-9 do
		local step = math.min(Idle.FIGHT_INTERVAL, remaining)
		remaining = remaining - step

		state.monsterDamage = state.monsterDamage + damagePerSecond * step
		if state.monsterDamage >= Idle.GetMonster(state.monsterIndex).health then
			KillMonster()
		end
	end
end

function Idle.Tick(dt)
	dt = math.min(dt, Idle.MAX_TICK)
	local state = GetState()

	state.runTime = state.runTime + dt
	state.totalTime = state.totalTime + dt
	Idle.sessionTime = Idle.sessionTime + dt
	state.longestSession = math.max(state.longestSession or 0, Idle.sessionTime)
	state.highestEnemy = math.max(state.highestEnemy or 1, state.unlocked)

	Fight(dt)
	Idle.UpdateRevealedHeroes()

	if Idle.GetMonster(state.monsterIndex).boss then
		Idle.bossTimer = (Idle.bossTimer or Idle.GetBossTimeLimit()) - dt
		if Idle.bossTimer <= 0 then
			FailBoss()
		end
	else
		Idle.bossTimer = nil
	end

	for id, buff in pairs(state.buffs) do
		buff.remaining = buff.remaining - dt
		if buff.remaining <= 0 then
			state.buffs[id] = nil
		end
	end
end

function Idle.AddBuff(id, nameKey, multiplier, seconds)
	seconds = seconds * (1 + Idle.GetProfessionBonus("buffDuration"))
	local buffs = GetState().buffs
	local existing = buffs[id]
	if existing and existing.multiplier == multiplier then
		existing.remaining = math.max(existing.remaining, seconds)
		return
	end
	buffs[id] = { nameKey = nameKey, multiplier = multiplier, remaining = seconds }
end

---------------------------------------------------------------------------
-- Prestige
---------------------------------------------------------------------------

function Idle.GetHeroLevels()
	local levels = 0
	for _, definition in ipairs(Idle.definitions.ally) do
		levels = levels + Idle.GetOwned("ally", definition.id)
	end
	return levels
end

function Idle.GetPrestigeGain()
	return math.floor(Idle.GetHeroLevels() / Idle.LEVELS_PER_SOUL)
end

function Idle.CanPrestige()
	return GetState().unlocked >= Idle.PRESTIGE_UNLOCK_LEVEL
end

function Idle.Prestige()
	if not Idle.CanPrestige() then
		return false
	end

	local state = GetState()
	local gain = Idle.GetPrestigeGain()
	state.renown = state.renown + gain
	state.renownEarned = state.renownEarned + gain
	state.prestiges = state.prestiges + 1
	state.gold = 0
	state.runGold = 0
	state.runTime = 0
	state.unlocked = 1
	state.tierKills = {}
	state.kills = 0
	state.monsterIndex = 1
	state.monsterDamage = 0
	state.allies = {}
	state.upgrades = {}
	state.spells = {}
	state.heroesRevealed = 1
	state.buffs = {}
	Idle.bossTimer = nil
	return true
end
