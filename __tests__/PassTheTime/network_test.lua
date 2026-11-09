-- Run from the workspace root: lua __tests__/PassTheTime/network_test.lua
local currentTime = 100
local serverTime = 1700000000
function GetTime() return currentTime end
function GetServerTime() return serverTime end
function UnitName() return "Tester" end

local inGroup, inGuild = true, true
function IsInRaid() return false end
function IsInGroup() return inGroup end
function IsInGuild() return inGuild end

local PTT = {}
function PTT.OnInitialize() end
for _, file in ipairs({ "Idle", "Network", "Bosses" }) do
	assert(loadfile("PassTheTime/" .. file .. ".lua"))("PassTheTime", PTT)
end

PTT.database = {
	idle = {
		gold = 0, runGold = 0, lifetimeGold = 5000, runTime = 0, totalTime = 0,
		clicks = 0, renown = 3, renownEarned = 3, prestiges = 1, unlocked = 1, tierKills = {}, kills = 0, bossKills = 0, groupBossKills = 0, guildBossKills = 0, monsterIndex = 1, monsterDamage = 0,
		allies = { scout = 10 }, upgrades = {}, professions = {}, buffs = {},
		buyAmount = 1, lifetimeKills = 0, eventsClaimed = 0,
	},
	guildRanking = {},
	guildBoss = { week = 0, damage = 0, health = 0, claimed = false, contributions = {} },
}

local sent = {}
PTT.Network.transport = function(channel, message) sent[#sent + 1] = { channel = channel, message = message } end

local Network, Bosses = PTT.Network, PTT.Bosses
local failures = 0
local function Check(condition, message)
	if not condition then
		failures = failures + 1
		print("FAIL: " .. message)
	end
end

-- Status
Network.HandleMessage("S|1|Alice|1000000|50.5|7|2", "PARTY")
Check(Network.players.Alice and Network.players.Alice.income == 50.5, "status parsed")
Check(#Network.GetGroupPlayers() == 1, "party sender is a group player")
Network.UpdateGroupBonus()
Check(math.abs(PTT.Idle.groupBonus - 0.05) < 1e-9, "one group player gives 5%")

Network.HandleMessage("S|1|Tester|1|1|1|1", "PARTY")
Check(Network.players.Tester == nil, "own status ignored")

Network.HandleMessage("S|2|Bob|1|1|1|1", "PARTY")
Check(Network.players.Bob == nil, "other protocol ignored")
Network.HandleMessage("garbage", "PARTY")
Network.HandleMessage("S|1", "PARTY")
Network.HandleMessage("S|1|Carol|x|y|z|w", "GUILD")
Check(Network.players.Carol.lifetimeGold == 0, "broken numbers become 0")

for index = 1, 10 do
	Network.HandleMessage("S|1|Player" .. index .. "|1|1|1|1", "RAID")
end
Network.UpdateGroupBonus()
Check(PTT.Idle.groupBonus == Network.MAX_GROUP_BONUS, "group bonus capped")

currentTime = currentTime + Network.ACTIVE_WINDOW + 1
Network.UpdateGroupBonus()
Check(PTT.Idle.groupBonus == 0, "stale players give no bonus")

inGroup = false
Network.HandleMessage("S|1|Dave|1|1|1|1", "PARTY")
Check(#Network.GetGroupPlayers() == 0, "no group players while ungrouped")
inGroup = true

-- Guild ranking persistence
Network.HandleMessage("S|1|Erin|9000|12|4|1", "GUILD")
Check(PTT.database.guildRanking.Erin and PTT.database.guildRanking.Erin.lifetimeGold == 9000, "guild status persisted")

-- Query reply and cooldown
sent = {}
Network.HandleMessage("Q|1|Frank|1|1|1|1", "GUILD")
Check(#sent >= 1 and sent[1].message:match("^S|1|Tester|"), "query answered with status")
local replies = #sent
Network.HandleMessage("Q|1|Gina|1|1|1|1", "GUILD")
Check(#sent == replies, "second query within cooldown not answered")

sent = {}
Network.BroadcastStatus("S")
Check(#sent == 2 and sent[1].channel == "PARTY" and sent[2].channel == "GUILD", "status goes to group and guild")
inGuild = false
sent = {}
Network.BroadcastStatus("S")
Check(#sent == 1, "no guild message without guild")
inGuild = true

-- Group boss
Check(not Bosses.IsGroupBossActive(), "no boss yet")
sent = {}
Check(Bosses.StartGroupBoss(), "start group boss")
Check(sent[1].message:match("^B|1|start|"), "start message sent")
Check(not Bosses.StartGroupBoss(), "cannot start a second boss")
local boss = Bosses.group
Check(boss.health > 0, "boss has health")

local knownIncome = PTT.Idle.GetIncome()
for _, player in ipairs(Network.GetGroupPlayers()) do
	knownIncome = knownIncome + player.income
end
Check(math.abs(boss.health - knownIncome * Bosses.GROUP_DURATION * Bosses.GROUP_DIFFICULTY) < 1, "boss health from known incomes")

local finished
Bosses.OnFinish(function(kind, victory) finished = { kind = kind, victory = victory } end)
Network.HandleMessage("B|1|dmg|" .. boss.id .. "|Alice|" .. math.floor(boss.health), "PARTY")
Bosses.Tick(1)
Check(boss.finished and boss.victory and finished.kind == "group" and finished.victory, "victory when contributions reach health")
Check(PTT.database.idle.buffs.boss_group ~= nil, "group buff granted")
Check(Bosses.IsGroupBossActive() == false, "finished boss is not active")

-- Group boss timeout
Bosses.group = nil
Check(Bosses.StartGroupBoss(), "start again")
boss = Bosses.group
serverTime = serverTime + Bosses.GROUP_DURATION + 1
Bosses.Tick(1)
Check(boss.finished and not boss.victory, "defeat on timeout")

-- Foreign boss adoption
Bosses.group = nil
Network.HandleMessage("B|1|start|abc|" .. serverTime .. "|600|123456", "PARTY")
Check(Bosses.group and Bosses.group.id == "abc" and Bosses.group.health == 123456, "adopt boss from another player")
Network.HandleMessage("B|1|dmg|other|Alice|5", "PARTY")
Check(Bosses.group.contributions.Alice == nil, "damage for another boss id ignored")
Network.HandleMessage("B|1|start|zzz|" .. serverTime .. "|600|1", "PARTY")
Check(Bosses.group.id == "abc", "second start ignored while active")

inGroup = false
Bosses.Tick(1)
Check(Bosses.group == nil, "boss dropped when leaving the group")
inGroup = true

-- Guild boss
local guildBoss = Bosses.GetGuildBoss()
Check(guildBoss.week == Bosses.GetCurrentWeek(), "week assigned")
Network.HandleMessage("G|1|" .. guildBoss.week .. "|Erin|500|1000000000", "GUILD")
Check(guildBoss.contributions.Erin == 500 and guildBoss.health == 1000000000, "guild contribution stored")
Network.HandleMessage("G|1|" .. (guildBoss.week - 1) .. "|Erin|999|9", "GUILD")
Check(guildBoss.contributions.Erin == 500, "old week ignored")
Network.HandleMessage("G|1|" .. guildBoss.week .. "|Erin|100|5", "GUILD")
Check(guildBoss.contributions.Erin == 500 and guildBoss.health == 1000000000, "values never go down")

sent = {}
Bosses.Tick(Bosses.GUILD_BROADCAST_INTERVAL + 1)
Check(guildBoss.damage > 0 and guildBoss.contributions.Tester == guildBoss.damage, "own damage tracked")
Check(sent[#sent] and sent[#sent].message:match("^G|1|"), "guild boss progress broadcast")

Network.HandleMessage("G|1|" .. guildBoss.week .. "|Erin|2000000000|1000000000", "GUILD")
Bosses.Tick(1)
Check(guildBoss.claimed and PTT.database.idle.buffs.boss_guild ~= nil, "guild boss defeated and rewarded")
Check(Bosses.IsGuildBossDefeated(), "defeated flag")
PTT.database.idle.buffs.boss_guild = nil
Bosses.Tick(1)
Check(PTT.database.idle.buffs.boss_guild == nil, "reward only once per week")

serverTime = serverTime + Bosses.WEEK
guildBoss = Bosses.GetGuildBoss()
Check(not guildBoss.claimed and guildBoss.damage == 0 and next(guildBoss.contributions) == nil, "new week resets the guild boss")

-- A zero-income start is refused
local savedMiners = PTT.database.idle.allies.scout
PTT.database.idle.allies.scout = nil
Network.players = {}
Bosses.group = nil
local started, reason = Bosses.StartGroupBoss()
Check(started == false and reason == "noIncome", "no group boss without income")
PTT.database.idle.allies.scout = savedMiners

-- Guild boss over a week: income grows between sessions, health must stay fixed and the boss must die
serverTime = serverTime + Bosses.WEEK
PTT.database.guildRanking = {}
PTT.database.idle.allies = { scout = 1000 }
guildBoss = Bosses.GetGuildBoss()
Bosses.Tick(Bosses.GUILD_HEALTH_DELAY)
local fixedHealth = guildBoss.health
Check(fixedHealth > 0, "guild boss health computed after the delay")

local scoutCounts = { 1000, 3000, 9000 }
for _, scouts in ipairs(scoutCounts) do
	PTT.database.idle.allies = { scout = scouts }
	for _ = 1, 120 do
		Bosses.Tick(60)
	end
	Check(guildBoss.health == fixedHealth, "guild boss health does not grow during the week")
end
Check(guildBoss.claimed, "guild boss dies within three 2h sessions with growing income")

-- Prestige in the middle of the week must not make the boss unwinnable for a guild
serverTime = serverTime + Bosses.WEEK
guildBoss = Bosses.GetGuildBoss()
PTT.database.idle.allies = { scout = 1000 }
Bosses.Tick(Bosses.GUILD_HEALTH_DELAY)
Network.HandleMessage("G|1|" .. guildBoss.week .. "|Erin|" .. math.floor(guildBoss.health) .. "|1", "GUILD")
PTT.database.idle.allies = {}
Bosses.Tick(1)
Check(guildBoss.claimed, "other members can finish the boss after this player prestiged")

print(failures == 0 and "NETWORK OK" or (failures .. " FAILURES"))
os.exit(failures == 0 and 0 or 1)
