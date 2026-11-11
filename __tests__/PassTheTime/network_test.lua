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
function GetRealmName() return "Testrealm" end
function UnitFactionGroup() return "Alliance" end
local channelIndex = 0
local channelCalls = {}
function GetChannelName() return channelIndex end
function JoinTemporaryChannel(name) channelCalls[#channelCalls + 1] = "join " .. name; channelIndex = 5 end
function LeaveChannelByName(name) channelCalls[#channelCalls + 1] = "leave " .. name; channelIndex = 0 end

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
	realmRanking = {},
	settings = { realmLeaderboard = true },
	guildBoss = { week = 0, damage = 0, health = 0, claimed = false, contributions = {} },
}

local sent = {}
PTT.Network.transport = function(channel, message, target) sent[#sent + 1] = { channel = channel, message = message, target = target } end

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
Check(Network.players.Carol == nil, "status with broken numbers ignored")

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

-- Realm leaderboard: incoming channel messages
Network.players = {}
local function RealmCount()
	local count = 0
	for _ in pairs(Network.GetRealmRanking()) do
		count = count + 1
	end
	return count
end

Network.HandleMessage("S|1|Hanna|7000|3.5|2|0", "CHANNEL", "Hanna-Testrealm")
local hanna = Network.GetRealmRanking().Hanna
Check(hanna and hanna.name == "Hanna" and hanna.lifetimeGold == 7000 and hanna.income == 3.5, "realm status stored")
Check(PTT.database.realmRanking["Testrealm-Alliance"] ~= nil, "realm list keyed by realm and faction")
Check(Network.players.Hanna == nil, "realm status does not count as group or guild player")

Network.HandleMessage("S|1|Hanna|1|1|1|1", "CHANNEL", "Mallory-Testrealm")
Check(Network.GetRealmRanking().Hanna.lifetimeGold == 7000 and Network.GetRealmRanking().Mallory == nil, "name of another character ignored")
Network.HandleMessage("S|1|Ivan|1|1|1|1", "CHANNEL")
Check(Network.GetRealmRanking().Ivan == nil, "channel status without sender ignored")
Network.HandleMessage("S|1|Hanna Smith|1|1|1|1", "CHANNEL", "Hanna Smith-Testrealm")
Check(Network.GetRealmRanking()["Hanna Smith"] ~= nil, "surname clients match by first word")

Network.HandleMessage("S|1|Hanna|9000|4|2|0", "CHANNEL", "Hanna-Testrealm")
Check(Network.GetRealmRanking().Hanna.lifetimeGold == 7000, "update within the minimum gap ignored")
serverTime = serverTime + Network.REALM_MIN_UPDATE_GAP
Network.HandleMessage("S|1|Hanna|9000|4|2|0", "CHANNEL", "Hanna-Testrealm")
Check(Network.GetRealmRanking().Hanna.lifetimeGold == 9000, "update after the gap stored")

local invalidStatuses = {
	"S|1|Mallory|inf|1|1|1", "S|1|Mallory|nan|1|1|1", "S|1|Mallory|-5|1|1|1", "S|1|Mallory|1e999|1|1|1",
	"S|1|Mallory|1|-inf|1|1", "S|1|Mallory|1|1|nan|1", "S|1|Mallory|1|1|1|x", "S|1|Mallory|1",
	"S|1|Mal\nlory|1|1|1|1", "S|1|" .. string.rep("M", 60) .. "|1|1|1|1", "S|1||1|1|1|1",
	"S|1|Mallory|1|1|1|1" .. string.rep("9", 300),
}
for _, message in ipairs(invalidStatuses) do
	Network.HandleMessage(message, "CHANNEL", "Mallory-Testrealm")
end
Check(Network.GetRealmRanking().Mallory == nil, "invalid realm statuses ignored")

Bosses.group = nil
Network.HandleMessage("B|1|start|evil|" .. serverTime .. "|600|1", "CHANNEL", "Mallory-Testrealm")
Check(Bosses.group == nil, "boss start through the channel ignored")
sent = {}
Network.HandleMessage("Q|1|Mallory|1|1|1|1", "CHANNEL", "Mallory-Testrealm")
Check(#sent == 0, "query through the channel not answered")

Network.HandleMessage("B|1|start|whisper|" .. serverTime .. "|600|1", "WHISPER", "Mallory-Testrealm")
Check(Bosses.group == nil, "boss start through a whisper ignored")
Network.HandleMessage("S|1|Mallory|1|1|1|1", "WHISPER", "Mallory-Testrealm")
Network.HandleMessage("S|1|Mallory|1|1|1|1", "UNKNOWN", "Mallory-Testrealm")
Check(Network.players.Mallory == nil and Network.GetRealmRanking().Mallory == nil, "status from untrusted distributions ignored")

-- Garbage from other players must never raise an error.
local garbage = { "", "|", "||||||||", "S", "S|", "S|1|", "S|1|||||||||", "B|1", "B|1|dmg", "G|1", "G|1|x|y|z|w", "Q|1",
	"S|1|0x10|0x10|0x10|0x10|0x10", "S|1|Hanna|1e308|1e308|1e308|1e308" }
math.randomseed(1)
for _ = 1, 500 do
	local characters = {}
	for index = 1, math.random(0, 40) do
		characters[index] = string.char(math.random(0, 255))
	end
	garbage[#garbage + 1] = (math.random() < 0.5 and "S|1|" or "") .. table.concat(characters)
end
for _, message in ipairs(garbage) do
	for _, channel in ipairs({ "CHANNEL", "PARTY", "GUILD" }) do
		local ok, problem = pcall(Network.HandleMessage, message, channel, "Fuzz-Testrealm")
		Check(ok, "garbage raised an error: " .. tostring(problem))
	end
end
Check(pcall(Network.HandleMessage, nil, "CHANNEL", nil), "nil message raises no error")

local savedLimit = Network.MAX_REALM_ENTRIES
Network.MAX_REALM_ENTRIES = 5
for index = 1, 8 do
	serverTime = serverTime + 1
	Network.HandleMessage("S|1|Many" .. index .. "|1|1|1|1", "CHANNEL", "Many" .. index .. "-Testrealm")
end
Check(RealmCount() == 5 and Network.GetRealmRanking().Many8 ~= nil, "realm list capped, newest kept")
Network.MAX_REALM_ENTRIES = savedLimit

serverTime = serverTime + Network.REALM_EXPIRY + 1
Network.HandleMessage("S|1|Fresh|1|1|1|1", "CHANNEL", "Fresh-Testrealm")
Network.PruneRealmRanking()
Check(RealmCount() == 1 and Network.GetRealmRanking().Fresh ~= nil, "expired realm entries pruned")

-- Realm leaderboard: joining and sending
local function ChannelSends()
	local result = {}
	for _, message in ipairs(sent) do
		if message.channel == "CHANNEL" then
			result[#result + 1] = message
		end
	end
	return result
end

sent = {}
Network.Tick(Network.CHANNEL_JOIN_DELAY - 1)
Check(#channelCalls == 0, "no join before the delay")
Network.Tick(1)
Check(channelCalls[1] == "join " .. Network.CHANNEL_NAME, "channel joined after the delay")
Check(#ChannelSends() == 0, "no status right at the join")
Network.Tick(Network.CHANNEL_FIRST_STATUS)
local channelSends = ChannelSends()
Check(#channelSends == 1 and channelSends[1].target == 5 and channelSends[1].message:match("^S|1|Tester|5000|"), "first status sent to the channel")
for _ = 1, Network.CHANNEL_INTERVAL - 1 do
	Network.Tick(1)
end
Check(#ChannelSends() == 1, "no second status within the interval")
Network.Tick(1)
Check(#ChannelSends() == 2, "status repeated after the interval")

Network.SetRealmLeaderboard(false)
Check(channelCalls[#channelCalls] == "leave " .. Network.CHANNEL_NAME, "turning off leaves the channel")
sent = {}
Network.Tick(Network.CHANNEL_INTERVAL * 2)
Check(#ChannelSends() == 0 and #channelCalls == 2, "nothing sent or joined while turned off")
Network.SetRealmLeaderboard(true)
Check(channelCalls[#channelCalls] == "join " .. Network.CHANNEL_NAME, "turning on joins right away")

print(failures == 0 and "NETWORK OK" or (failures .. " FAILURES"))
os.exit(failures == 0 and 0 or 1)
