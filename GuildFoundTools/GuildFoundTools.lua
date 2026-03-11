GuildFoundTools = GuildFoundTools or {}

GuildFoundTools.debugMode = true

local AceComm = LibStub("AceComm-3.0")
local AceSerializer = LibStub("AceSerializer-3.0")
local ADDON_PREFIX = "GFTools"

-- Guild member cache (shared across modules)
GuildFoundTools.guildMemberCache = {}

function GuildFoundTools.BuildGuildMemberCache()
	wipe(GuildFoundTools.guildMemberCache)
	local memberCount = GetNumGuildMembers()
	for index = 1, memberCount do
		local fullName, _, _, level, _, _, _, _, online, _, classFileName, _, _, _, _, _, guid = GetGuildRosterInfo(index)
		if fullName then
			local shortName = strsplit("-", fullName)
			GuildFoundTools.guildMemberCache[shortName] = {
				guid = guid,
				classFileName = classFileName,
				level = level,
				online = online,
			}
		end
	end
end

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

function GuildFoundTools.UnregisterEventHandler(event, handler)
	local handlers = eventHandlers[event]
	if not handlers then return end

	for index = #handlers, 1, -1 do
		if handlers[index] == handler then
			table.remove(handlers, index)
		end
	end

	if #handlers == 0 then
		eventHandlers[event] = nil
		eventFrame:UnregisterEvent(event)
	end
end

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

-- Send a message to the guild channel (via AceComm for automatic chunking)
function GuildFoundTools.SendGuildMessage(messageType, data)
	if not IsInGuild() then return end

	local message = AceSerializer:Serialize(messageType, data or false)

	if GuildFoundTools.debugMode then
		print("GFT ->", messageType, data)
	end

	AceComm:SendCommMessage(ADDON_PREFIX, message, "GUILD")
end

-- Send a whisper message to a specific player (via AceComm)
function GuildFoundTools.SendWhisperMessage(messageType, target, data)
	if not IsInGuild() then return end

	local message = AceSerializer:Serialize(messageType, data or false)

	if GuildFoundTools.debugMode then
		print("GFT W->", target, messageType, data)
	end

	AceComm:SendCommMessage(ADDON_PREFIX, message, "WHISPER", target)
end

-- ============================================================
-- Event handlers
-- ============================================================

GuildFoundTools.EventHandlers.ADDON_LOADED = function(addonName)
	if addonName ~= "GuildFoundTools" then return end
	GuildFoundToolsDB = GuildFoundToolsDB or {}
	GuildFoundToolsDB.minimap = GuildFoundToolsDB.minimap or {}
end

GuildFoundTools.EventHandlers.PLAYER_LOGIN = function()
	playerName = UnitName("player")
	playerRealm = GetRealmName()
end

-- Receive messages via AceComm (handles automatic chunk reassembly)
AceComm:RegisterComm(ADDON_PREFIX, function(prefix, message, distribution, sender)
	local success, messageType, data = AceSerializer:Deserialize(message)
	if not success then return end

	sender = strsplit("-", sender)

	if GuildFoundTools.debugMode then
		print("GFT <-", distribution, sender, messageType, data)
	end

	local handlers = messageHandlers[messageType]
	if handlers then
		for _, handler in ipairs(handlers) do
			handler(data, sender)
		end
	end
end)

-- ============================================================
-- Slash commands
-- ============================================================

SLASH_GUILDFOUNDTOOLS1 = "/gft"
SLASH_GUILDFOUNDTOOLS2 = "/guildfoundtools"
SlashCmdList["GUILDFOUNDTOOLS"] = function()
	GuildFoundTools.UI.Toggle()
end
