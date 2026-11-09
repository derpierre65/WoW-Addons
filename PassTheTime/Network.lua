local _, PTT = ...

local unpack = unpack or table.unpack

local Network = { players = {} }
PTT.Network = Network

local PREFIX = "PTT"
local PROTOCOL = "1"

Network.STATUS_INTERVAL = 30
Network.ACTIVE_WINDOW = 100
Network.BONUS_PER_PLAYER = 0.05
Network.MAX_GROUP_BONUS = 0.25
Network.REPLY_COOLDOWN = 10

local handlers = {}
local statusTimer = 5
local lastReply = -math.huge
local queryTimer

local isForever = WOW_PROJECT_CAMELOT ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT

-- Names inside the payload identify players, so the sender format of the client does not matter.
function Network.GetPlayerName()
	local firstName, surname = UnitName("player")
	if isForever and surname and surname ~= "" then
		return firstName .. " " .. surname
	end
	return firstName
end

-- Only the home group: instance groups (battlegrounds) have no PARTY channel and would cause system spam.
function Network.GetGroupChannel()
	local category = LE_PARTY_CATEGORY_HOME
	if IsInRaid and IsInRaid(category) then
		return "RAID"
	elseif IsInGroup and IsInGroup(category) then
		return "PARTY"
	end
	return nil
end

function Network.GetGuildChannel()
	if IsInGuild and IsInGuild() then
		return "GUILD"
	end
	return nil
end

-- Replaced in tests.
Network.transport = function(channel, message)
	local send = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage
	send(PREFIX, message, channel)
end

function Network.Send(channel, messageType, ...)
	if not channel then
		return false
	end

	local fields = { messageType, PROTOCOL, ... }
	for index, value in ipairs(fields) do
		fields[index] = tostring(value)
	end

	Network.transport(channel, table.concat(fields, "|"))
	return true
end

function Network.On(messageType, handler)
	handlers[messageType] = handler
end

local function Split(text)
	local fields = {}
	for field in (text .. "|"):gmatch("(.-)|") do
		fields[#fields + 1] = field
	end
	return fields
end

-- fields: type, protocol, ...payload
function Network.HandleMessage(text, channel)
	local fields = Split(text)
	if fields[2] ~= PROTOCOL or not handlers[fields[1]] then
		return
	end
	handlers[fields[1]](fields, channel)
end

---------------------------------------------------------------------------
-- Player status
---------------------------------------------------------------------------

function Network.BroadcastStatus(messageType)
	local state = PTT.database.idle
	local arguments = {
		Network.GetPlayerName(),
		string.format("%.0f", state.lifetimeGold),
		string.format("%.2f", PTT.Idle.GetIncome()),
		state.renownEarned,
		state.prestiges,
	}

	Network.Send(Network.GetGroupChannel(), messageType or "S", unpack(arguments))
	Network.Send(Network.GetGuildChannel(), messageType or "S", unpack(arguments))
end

local function HandleStatus(fields, channel)
	local name = fields[3]
	if not name or name == "" or name == Network.GetPlayerName() then
		return
	end

	local player = Network.players[name] or { name = name }
	Network.players[name] = player

	player.lifetimeGold = tonumber(fields[4]) or 0
	player.income = tonumber(fields[5]) or 0
	player.renown = tonumber(fields[6]) or 0
	player.prestiges = tonumber(fields[7]) or 0
	player.lastSeen = GetTime()

	if channel == "PARTY" or channel == "RAID" then
		player.groupSeen = GetTime()
	elseif channel == "GUILD" then
		PTT.database.guildRanking[name] = {
			lifetimeGold = player.lifetimeGold,
			income = player.income,
			renown = player.renown,
			seenAt = GetServerTime(),
		}
	end

	return player
end

Network.On("S", HandleStatus)
Network.On("Q", function(fields, channel)
	HandleStatus(fields, channel)

	if GetTime() - lastReply >= Network.REPLY_COOLDOWN then
		lastReply = GetTime()
		Network.BroadcastStatus("S")
	end
end)

---------------------------------------------------------------------------
-- Group
---------------------------------------------------------------------------

function Network.GetGroupPlayers()
	local result = {}
	if not Network.GetGroupChannel() then
		return result
	end

	for _, player in pairs(Network.players) do
		if player.groupSeen and GetTime() - player.groupSeen <= Network.ACTIVE_WINDOW then
			result[#result + 1] = player
		end
	end
	return result
end

function Network.IsOnline(player)
	return player.lastSeen ~= nil and GetTime() - player.lastSeen <= Network.ACTIVE_WINDOW
end

function Network.UpdateGroupBonus()
	local count = #Network.GetGroupPlayers()
	PTT.Idle.groupBonus = math.min(Network.MAX_GROUP_BONUS, count * Network.BONUS_PER_PLAYER)
end

function Network.Tick(dt)
	statusTimer = statusTimer - dt
	if statusTimer <= 0 then
		statusTimer = Network.STATUS_INTERVAL
		Network.BroadcastStatus("S")
	end

	if queryTimer then
		queryTimer = queryTimer - dt
		if queryTimer <= 0 then
			queryTimer = nil
			Network.BroadcastStatus("Q")
		end
	end

	Network.UpdateGroupBonus()
end

function Network.RegisterEvents()
	local register = (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) or RegisterAddonMessagePrefix
	register(PREFIX)

	local frame = CreateFrame("Frame")
	for _, event in ipairs({ "CHAT_MSG_ADDON", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD" }) do
		pcall(frame.RegisterEvent, frame, event)
	end

	frame:SetScript("OnEvent", function(_, event, prefix, text, channel)
		if event == "CHAT_MSG_ADDON" then
			if prefix == PREFIX then
				Network.HandleMessage(text, channel)
			end
		elseif event == "GROUP_ROSTER_UPDATE" then
			if not Network.GetGroupChannel() then
				for _, player in pairs(Network.players) do
					player.groupSeen = nil
				end
			end
			queryTimer = 2
		elseif event == "PLAYER_ENTERING_WORLD" then
			queryTimer = 5
		end
	end)
end
