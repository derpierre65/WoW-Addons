local _, PTT = ...

local Bosses = {}
PTT.Bosses = Bosses

Bosses.GROUP_DURATION = 600
Bosses.GROUP_DIFFICULTY = 0.7
Bosses.GROUP_BUFF_MULTIPLIER = 1.5
Bosses.GROUP_BUFF_DURATION = 600
Bosses.GROUP_BROADCAST_INTERVAL = 5
Bosses.GUILD_ACTIVE_SECONDS = 4 * 3600
Bosses.GUILD_BUFF_MULTIPLIER = 2
Bosses.GUILD_BUFF_DURATION = 3600
Bosses.GUILD_BROADCAST_INTERVAL = 60
Bosses.GUILD_MEMBER_MAX_AGE = 14 * 86400
Bosses.GUILD_HEALTH_DELAY = 60
Bosses.WEEK = 7 * 86400

local Network = PTT.Network

-- Group boss lives in memory only: it is gone after 10 minutes anyway.
Bosses.group = nil

local finishListeners = {}

function Bosses.OnFinish(listener)
	finishListeners[#finishListeners + 1] = listener
end

local function Fire(kind, victory)
	for _, listener in ipairs(finishListeners) do
		listener(kind, victory)
	end
end

function Bosses.GetTotal(contributions)
	local total = 0
	for _, value in pairs(contributions) do
		total = total + value
	end
	return total
end

---------------------------------------------------------------------------
-- Group boss
---------------------------------------------------------------------------

function Bosses.IsGroupBossActive()
	return Bosses.group ~= nil and not Bosses.group.finished
end

function Bosses.GetGroupTimeLeft()
	if not Bosses.group then
		return 0
	end
	return math.max(0, Bosses.group.endTime - GetServerTime())
end

local function CreateGroupBoss(id, startTime, duration, health)
	Bosses.group = {
		id = id,
		endTime = startTime + duration,
		health = health,
		contributions = {},
		myDamage = 0,
		broadcastTimer = 0,
		finished = false,
	}
end

-- Returns true, or false plus a reason key.
function Bosses.StartGroupBoss()
	local channel = Network.GetGroupChannel()
	if not channel then
		return false, "needGroup"
	end

	if Bosses.IsGroupBossActive() then
		return false, "active"
	end

	local totalIncome = PTT.Idle.GetIncome()
	for _, player in ipairs(Network.GetGroupPlayers()) do
		totalIncome = totalIncome + player.income
	end

	if totalIncome <= 0 then
		return false, "noIncome"
	end

	local startTime = GetServerTime()
	local health = totalIncome * Bosses.GROUP_DURATION * Bosses.GROUP_DIFFICULTY
	local id = startTime .. "-" .. Network.GetPlayerName()

	CreateGroupBoss(id, startTime, Bosses.GROUP_DURATION, health)
	Network.Send(channel, "B", "start", id, startTime, Bosses.GROUP_DURATION, string.format("%.0f", health))
	return true
end

Network.On("B", function(fields)
	local action = fields[3]

	if action == "start" then
		if Bosses.IsGroupBossActive() then
			return
		end

		local startTime, duration, health = tonumber(fields[5]), tonumber(fields[6]), tonumber(fields[7])
		if fields[4] and startTime and duration and health and health > 0 then
			CreateGroupBoss(fields[4], startTime, duration, health)
		end
	elseif action == "dmg" then
		local boss = Bosses.group
		local name, total = fields[5], tonumber(fields[6])
		if boss and boss.id == fields[4] and name and total and name ~= Network.GetPlayerName() then
			boss.contributions[name] = math.max(boss.contributions[name] or 0, total)
		end
	end
end)

local function TickGroupBoss(dt)
	local boss = Bosses.group
	if not boss or boss.finished then
		return
	end

	if not Network.GetGroupChannel() then
		Bosses.group = nil
		return
	end

	boss.myDamage = boss.myDamage + PTT.Idle.GetIncome() * dt
	boss.contributions[Network.GetPlayerName()] = boss.myDamage

	boss.broadcastTimer = boss.broadcastTimer - dt
	if boss.broadcastTimer <= 0 then
		boss.broadcastTimer = Bosses.GROUP_BROADCAST_INTERVAL
		Network.Send(Network.GetGroupChannel(), "B", "dmg", boss.id, Network.GetPlayerName(), string.format("%.0f", boss.myDamage))
	end

	local victory = Bosses.GetTotal(boss.contributions) >= boss.health
	if victory or GetServerTime() >= boss.endTime then
		boss.finished = true
		boss.victory = victory

		if victory and boss.myDamage > 0 then
			PTT.Idle.AddBuff("boss_group", "bossBuffName", Bosses.GROUP_BUFF_MULTIPLIER, Bosses.GROUP_BUFF_DURATION)
			PTT.database.idle.groupBossKills = (PTT.database.idle.groupBossKills or 0) + 1
		end
		Fire("group", victory)
	end
end

---------------------------------------------------------------------------
-- Guild boss (weekly)
---------------------------------------------------------------------------

function Bosses.GetCurrentWeek()
	return math.floor(GetServerTime() / Bosses.WEEK)
end

function Bosses.GetGuildBoss()
	local boss = PTT.database.guildBoss
	local week = Bosses.GetCurrentWeek()

	if boss.week ~= week then
		boss.week = week
		boss.damage = 0
		boss.health = 0
		boss.claimed = false
		boss.contributions = {}
	end
	return boss
end

function Bosses.IsGuildBossDefeated()
	local boss = Bosses.GetGuildBoss()
	return boss.claimed or (boss.health > 0 and Bosses.GetTotal(boss.contributions) >= boss.health)
end

local function CalculateGuildHealth()
	local totalIncome = PTT.Idle.GetIncome()
	local now = GetServerTime()

	for _, entry in pairs(PTT.database.guildRanking) do
		if now - entry.seenAt <= Bosses.GUILD_MEMBER_MAX_AGE then
			totalIncome = totalIncome + entry.income
		end
	end
	return totalIncome * Bosses.GUILD_ACTIVE_SECONDS
end

Network.On("G", function(fields)
	local boss = Bosses.GetGuildBoss()
	local week, name, damage, health = tonumber(fields[3]), fields[4], tonumber(fields[5]), tonumber(fields[6])

	if week == boss.week and name and damage and name ~= Network.GetPlayerName() then
		boss.contributions[name] = math.max(boss.contributions[name] or 0, damage)

		-- Health is fixed once per week; it must not grow with income, or the boss would outrun everyone.
		if boss.health == 0 and health and health > 0 then
			boss.health = health
		end
	end
end)

local guildTimer = 0
local guildUptime = 0

local function TickGuildBoss(dt)
	if not Network.GetGuildChannel() then
		return
	end

	local boss = Bosses.GetGuildBoss()
	boss.damage = boss.damage + PTT.Idle.GetIncome() * dt
	boss.contributions[Network.GetPlayerName()] = boss.damage

	-- Wait for the guild's status replies so the health reflects more than just this player.
	guildUptime = guildUptime + dt
	if boss.health == 0 and guildUptime >= Bosses.GUILD_HEALTH_DELAY then
		boss.health = CalculateGuildHealth()
	end

	guildTimer = guildTimer - dt
	if guildTimer <= 0 then
		guildTimer = Bosses.GUILD_BROADCAST_INTERVAL
		Network.Send("GUILD", "G", boss.week, Network.GetPlayerName(), string.format("%.0f", boss.damage), string.format("%.0f", boss.health))
	end

	if not boss.claimed and boss.health > 0 and Bosses.GetTotal(boss.contributions) >= boss.health then
		boss.claimed = true
		if boss.damage > 0 then
			PTT.Idle.AddBuff("boss_guild", "bossBuffName", Bosses.GUILD_BUFF_MULTIPLIER, Bosses.GUILD_BUFF_DURATION)
			PTT.database.idle.guildBossKills = (PTT.database.idle.guildBossKills or 0) + 1
		end
		Fire("guild", true)
	end
end

function Bosses.Tick(dt)
	TickGroupBoss(dt)
	TickGuildBoss(dt)
end
