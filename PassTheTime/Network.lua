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

-- Realm leaderboard: a hidden custom channel every addon user joins.
Network.CHANNEL_NAME = "PassTheTimeLB"
Network.CHANNEL_JOIN_DELAY = 60
-- Gives the join time to complete before the first status.
Network.CHANNEL_FIRST_STATUS = 5
Network.CHANNEL_INTERVAL = 180
-- Two missed statuses before a player counts as offline.
Network.REALM_ONLINE_WINDOW = 2 * Network.CHANNEL_INTERVAL + 30
Network.REALM_MIN_UPDATE_GAP = 20
Network.MAX_REALM_ENTRIES = 250
Network.REALM_EXPIRY = 14 * 86400
Network.MAX_MESSAGE_LENGTH = 255
Network.MAX_NAME_LENGTH = 48

local handlers = {}
local statusTimer = 5
local lastReply = -math.huge
local queryTimer
local channelJoinTimer = Network.CHANNEL_JOIN_DELAY
local channelStatusTimer
-- Distributions the addon sends on. Whispers and unknown ones are dropped; the public channel only carries
-- statuses, anything else would let anyone trigger group features (bosses) realm-wide.
local TRUSTED_DISTRIBUTIONS = { PARTY = true, RAID = true, GUILD = true }
local CHANNEL_MESSAGE_TYPES = { S = true }

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
Network.transport = function(channel, message, target)
	local send = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage
	send(PREFIX, message, channel, target)
end

local function BuildMessage(messageType, ...)
	local fields = { messageType, PROTOCOL, ... }
	for index, value in ipairs(fields) do
		fields[index] = tostring(value)
	end
	return table.concat(fields, "|")
end

function Network.Send(channel, messageType, ...)
	if not channel then
		return false
	end

	Network.transport(channel, BuildMessage(messageType, ...))
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
function Network.HandleMessage(text, channel, sender)
	if type(text) ~= "string" or #text > Network.MAX_MESSAGE_LENGTH then
		return
	end

	local fields = Split(text)
	if fields[2] ~= PROTOCOL or not handlers[fields[1]] then
		return
	end
	if not TRUSTED_DISTRIBUTIONS[channel] and not (channel == "CHANNEL" and CHANNEL_MESSAGE_TYPES[fields[1]]) then
		return
	end
	handlers[fields[1]](fields, channel, sender)
end

-- Finite and not negative: inf and nan from tonumber would break sorting and number formatting.
local function ParseAmount(text)
	local value = tonumber(text)
	if not value or value ~= value or value < 0 or value == math.huge then
		return nil
	end
	return value
end

local function IsValidName(name)
	return type(name) == "string" and #name >= 2 and #name <= Network.MAX_NAME_LENGTH and not name:find("%c")
end

-- Character name without realm.
local function GetSenderKey(sender)
	if type(sender) ~= "string" then
		return nil
	end
	return sender:match("^[^%-]+")
end

-- The payload name carries the surname on some clients, so only the first word must match the sender.
local function FirstWord(text)
	return text:match("^%S+")
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

local HandleRealmStatus

local function HandleStatus(fields, channel, sender)
	local name = fields[3]
	if not IsValidName(name) or name == Network.GetPlayerName() then
		return
	end

	local lifetimeGold, income = ParseAmount(fields[4]), ParseAmount(fields[5])
	local renown, prestiges = ParseAmount(fields[6] or 0), ParseAmount(fields[7] or 0)
	if not lifetimeGold or not income or not renown or not prestiges then
		return
	end

	if channel == "CHANNEL" then
		HandleRealmStatus(name, sender, lifetimeGold, income, renown)
		return
	end

	local player = Network.players[name] or { name = name }
	Network.players[name] = player

	player.lifetimeGold = lifetimeGold
	player.income = income
	player.renown = renown
	player.prestiges = prestiges
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
-- Realm leaderboard
---------------------------------------------------------------------------

-- Saved variables are shared by all characters of the account, so every realm and faction keeps its own list.
function Network.GetRealmRanking()
	local realm = GetRealmName and GetRealmName() or "?"
	local faction = UnitFactionGroup and UnitFactionGroup("player") or "?"
	local key = realm .. "-" .. faction

	local rankings = PTT.database.realmRanking
	rankings[key] = rankings[key] or {}
	return rankings[key]
end

local function RemoveOldestEntry(ranking)
	local oldestKey, oldestTime
	for key, entry in pairs(ranking) do
		if not oldestTime or entry.seenAt < oldestTime then
			oldestKey, oldestTime = key, entry.seenAt
		end
	end
	if oldestKey then
		ranking[oldestKey] = nil
	end
end

function Network.PruneRealmRanking()
	local ranking = Network.GetRealmRanking()
	local now = GetServerTime()
	local count = 0
	for key, entry in pairs(ranking) do
		if type(entry) ~= "table" or type(entry.seenAt) ~= "number" or now - entry.seenAt > Network.REALM_EXPIRY then
			ranking[key] = nil
		else
			count = count + 1
		end
	end
	for _ = Network.MAX_REALM_ENTRIES + 1, count do
		RemoveOldestEntry(ranking)
	end
end

-- Keyed by the sending character, so one character can never fill the list with made-up names.
HandleRealmStatus = function(name, sender, lifetimeGold, income, renown)
	local senderKey = GetSenderKey(sender)
	local firstName = FirstWord(name)
	if not senderKey or not firstName or FirstWord(senderKey) ~= firstName then
		return
	end

	local ranking = Network.GetRealmRanking()
	local now = GetServerTime()
	local entry = ranking[senderKey]
	if entry then
		if now - entry.seenAt < Network.REALM_MIN_UPDATE_GAP then
			return
		end
	else
		local count = 0
		for _ in pairs(ranking) do
			count = count + 1
		end
		if count >= Network.MAX_REALM_ENTRIES then
			RemoveOldestEntry(ranking)
		end
		entry = {}
		ranking[senderKey] = entry
	end

	entry.name = name
	entry.lifetimeGold = lifetimeGold
	entry.income = income
	entry.renown = renown
	entry.seenAt = now
end

function Network.GetChannelIndex()
	if not GetChannelName then
		return nil
	end
	local index = GetChannelName(Network.CHANNEL_NAME)
	if type(index) == "number" and index > 0 then
		return index
	end
	return nil
end

local function IsOwnChannel(...)
	local channelName, channelBaseName = select(4, ...), select(9, ...)
	local wanted = Network.CHANNEL_NAME:lower()
	return (type(channelBaseName) == "string" and channelBaseName:lower() == wanted)
		or (type(channelName) == "string" and channelName:lower():find(wanted, 1, true) ~= nil)
end

local chatFilterInstalled = false

-- Join notices and anything typed into the channel stay out of every chat frame.
local function InstallChatFilter()
	if chatFilterInstalled or not ChatFrame_AddMessageEventFilter then
		return
	end
	chatFilterInstalled = true

	local function Filter(_, _, ...)
		return IsOwnChannel(...)
	end
	for _, event in ipairs({ "CHAT_MSG_CHANNEL", "CHAT_MSG_CHANNEL_NOTICE", "CHAT_MSG_CHANNEL_NOTICE_USER", "CHAT_MSG_CHANNEL_JOIN", "CHAT_MSG_CHANNEL_LEAVE" }) do
		ChatFrame_AddMessageEventFilter(event, Filter)
	end
end

function Network.JoinChannel()
	InstallChatFilter()
	local join = JoinTemporaryChannel or JoinChannelByName
	if not join or Network.GetChannelIndex() then
		return
	end

	join(Network.CHANNEL_NAME)
	if ChatFrame_RemoveChannel then
		for index = 1, (NUM_CHAT_WINDOWS or 0) do
			local chatFrame = _G["ChatFrame" .. index]
			if chatFrame then
				ChatFrame_RemoveChannel(chatFrame, Network.CHANNEL_NAME)
			end
		end
	end
end

function Network.LeaveChannel()
	if LeaveChannelByName and Network.GetChannelIndex() then
		LeaveChannelByName(Network.CHANNEL_NAME)
	end
end

function Network.SendChannelStatus()
	local index = Network.GetChannelIndex()
	if not index then
		return false
	end

	local state = PTT.database.idle
	local message = BuildMessage("S",
		Network.GetPlayerName(),
		string.format("%.0f", state.lifetimeGold),
		string.format("%.2f", PTT.Idle.GetIncome()),
		state.renownEarned,
		state.prestiges
	)
	Network.transport("CHANNEL", message, index)
	return true
end

function Network.SetRealmLeaderboard(enabled)
	PTT.database.settings.realmLeaderboard = enabled
	if not enabled then
		Network.LeaveChannel()
	elseif not channelJoinTimer then
		-- The start delay is over, so the player expects to show up right away.
		Network.JoinChannel()
		channelStatusTimer = Network.CHANNEL_FIRST_STATUS
	end
end

local function TickChannel(delta)
	if not PTT.database.settings.realmLeaderboard then
		return
	end

	if channelJoinTimer then
		channelJoinTimer = channelJoinTimer - delta
		if channelJoinTimer > 0 then
			return
		end
		channelJoinTimer = nil
		Network.PruneRealmRanking()
		Network.JoinChannel()
		channelStatusTimer = Network.CHANNEL_FIRST_STATUS
	end

	channelStatusTimer = (channelStatusTimer or 0) - delta
	if channelStatusTimer <= 0 then
		channelStatusTimer = Network.CHANNEL_INTERVAL
		-- Full channel list or a manual /leave: retry once per interval instead of every second.
		if not Network.SendChannelStatus() then
			Network.JoinChannel()
		end
	end
end

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
	TickChannel(dt)
end

function Network.RegisterEvents()
	local register = (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) or RegisterAddonMessagePrefix
	register(PREFIX)

	local frame = CreateFrame("Frame")
	for _, event in ipairs({ "CHAT_MSG_ADDON", "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD" }) do
		pcall(frame.RegisterEvent, frame, event)
	end

	frame:SetScript("OnEvent", function(_, event, prefix, text, channel, sender)
		if event == "CHAT_MSG_ADDON" then
			if prefix == PREFIX then
				-- Messages come from other players; a malformed one must never raise an error for the receiver.
				pcall(Network.HandleMessage, text, channel, sender)
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
