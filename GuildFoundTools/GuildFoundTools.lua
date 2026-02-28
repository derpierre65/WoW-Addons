GuildFoundTools = GuildFoundTools or {}

local ADDON_PREFIX = "GFTools"

GuildFoundTools.MESSAGE_TYPES = {
	GROUP_CREATE = "GC",
	GROUP_EDIT = "GE",
	GROUP_REMOVE = "GR",
	GROUP_SIGNUP = "GS",
	GROUP_LEAVE = "GL",
	GROUP_MEMBERS_SYNC = "GM",
	GROUP_LIST_REQUEST = "GQ",
	GROUP_LIST_ANSWER = "GA",
	PROFESSION_QUERY = "PQ",
	PROFESSION_ANSWER = "PA",
}

-- Global event handler system (supports multiple handlers per event)
local eventFrame = CreateFrame("Frame")
local eventHandlers = {}

GuildFoundTools.EventHandlers = setmetatable({}, {
	__newindex = function(self, event, handler)
		if not eventHandlers[event] then
			eventHandlers[event] = {}
			eventFrame:RegisterEvent(event)
		end
		table.insert(eventHandlers[event], handler)
	end,
})

eventFrame:SetScript("OnEvent", function(self, event, ...)
	local handlers = eventHandlers[event]
	if handlers then
		for _, handler in ipairs(handlers) do
			handler(...)
		end
	end
end)

-- Global message handler system (supports multiple handlers per message type)
local messageHandlers = {}

-- Reverse lookup: message code -> message name
local MESSAGE_TYPE_NAMES = {}
for name, code in pairs(GuildFoundTools.MESSAGE_TYPES) do
	MESSAGE_TYPE_NAMES[code] = name
end

GuildFoundTools.MessageHandlers = setmetatable({}, {
	__newindex = function(self, messageType, handler)
		if not messageHandlers[messageType] then
			messageHandlers[messageType] = {}
		end
		table.insert(messageHandlers[messageType], handler)
	end,
})

-- In-memory state
GuildFoundTools.groups = {}
GuildFoundTools.professions = {}

-- Local player info (populated on login)
local playerName = nil
local playerRealm = nil

function GuildFoundTools.GetPlayerName()
	if not playerName then
		playerName = UnitName("player")
	end
	return playerName
end

local function NormalizeSender(sender)
	local name = strsplit("-", sender)
	return name
end

-- Serialization: tab-separated fields
function GuildFoundTools.Serialize(messageType, ...)
	local parts = { messageType }
	for i = 1, select("#", ...) do
		local value = select(i, ...)
		table.insert(parts, tostring(value or ""))
	end
	return table.concat(parts, "\t")
end

local function Deserialize(message)
	return { strsplit("\t", message) }
end

-- Send a message to the guild channel
function GuildFoundTools.SendGuildMessage(message)
	if not IsInGuild() then return end
	C_ChatInfo.SendAddonMessage(ADDON_PREFIX, message, "GUILD")
end

-- Staggered send for multiple messages
function GuildFoundTools.SendGuildMessages(messages)
	for index, message in ipairs(messages) do
		C_Timer.After((index - 1) * 0.1, function()
			GuildFoundTools.SendGuildMessage(message)
		end)
	end
end

-- ============================================================
-- Event handlers
-- ============================================================

GuildFoundTools.EventHandlers.ADDON_LOADED = function(addonName)
	if addonName ~= "GuildFoundTools" then return end
	GuildFoundToolsDB = GuildFoundToolsDB or {}
	GuildFoundToolsDB.minimap = GuildFoundToolsDB.minimap or {}
	C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)
end

GuildFoundTools.EventHandlers.PLAYER_LOGIN = function()
	playerName = UnitName("player")
	playerRealm = GetRealmName()
end

GuildFoundTools.EventHandlers.CHAT_MSG_ADDON = function(prefix, message, channel, sender)
	if prefix ~= ADDON_PREFIX or channel ~= "GUILD" then return end

	sender = NormalizeSender(sender)
	local fields = Deserialize(message)
	local messageCode = fields[1]
	local messageType = MESSAGE_TYPE_NAMES[messageCode]

	local handlers = messageHandlers[messageType]
	if handlers then
		for _, handler in ipairs(handlers) do
			handler(fields, sender)
		end
	end
end

-- ============================================================
-- Slash commands
-- ============================================================

SLASH_GUILDFOUNDTOOLS1 = "/gft"
SLASH_GUILDFOUNDTOOLS2 = "/guildfoundtools"
SlashCmdList["GUILDFOUNDTOOLS"] = function()
	GuildFoundTools.UI.Toggle()
end
