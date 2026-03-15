ClassicGuildTools = ClassicGuildTools or {}

ClassicGuildTools.debugMode = false

local AceComm = LibStub("AceComm-3.0")
local AceSerializer = LibStub("AceSerializer-3.0")
local ADDON_PREFIX = "CGTools"

-- Guild member cache (shared across modules)
ClassicGuildTools.guildMemberCache = {}
local guildMemberCacheDirty = true

function ClassicGuildTools.BuildGuildMemberCache()
	if not guildMemberCacheDirty then return end
	guildMemberCacheDirty = false

	wipe(ClassicGuildTools.guildMemberCache)
	local memberCount = GetNumGuildMembers()
	for index = 1, memberCount do
		local fullName, _, _, level, _, _, _, _, online, _, classFileName, _, _, _, _, _, guid = GetGuildRosterInfo(index)
		if fullName then
			local shortName = strsplit("-", fullName)
			ClassicGuildTools.guildMemberCache[shortName] = {
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

ClassicGuildTools.EventHandlers = setmetatable({}, {
	__newindex = function(self, event, handler)
		if not eventHandlers[event] then
			eventHandlers[event] = {}
			eventFrame:RegisterEvent(event)
		end
		table.insert(eventHandlers[event], handler)
	end,
})

function ClassicGuildTools.UnregisterEventHandler(event, handler)
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

ClassicGuildTools.MessageHandlers = setmetatable({}, {
	__newindex = function(self, messageType, handler)
		if not messageHandlers[messageType] then
			messageHandlers[messageType] = {}
		end
		table.insert(messageHandlers[messageType], handler)
	end,
})

-- In-memory state
ClassicGuildTools.groups = {}
ClassicGuildTools.professions = {}

-- Local player info (populated on login)
local playerName = nil
local playerRealm = nil

function ClassicGuildTools.GetPlayerName()
	if not playerName then
		playerName = UnitName("player")
	end
	return playerName
end

-- Send a message to the guild channel (via AceComm for automatic chunking)
function ClassicGuildTools.SendGuildMessage(messageType, data)
	if not IsInGuild() then return end

	local message = AceSerializer:Serialize(messageType, data or false)

	if ClassicGuildTools.debugMode then
		print("GFT ->", messageType, data)
	end

	AceComm:SendCommMessage(ADDON_PREFIX, message, "GUILD")
end

-- Send a whisper message to a specific player (via AceComm)
function ClassicGuildTools.SendWhisperMessage(messageType, target, data)
	if not IsInGuild() then return end

	local message = AceSerializer:Serialize(messageType, data or false)

	if ClassicGuildTools.debugMode then
		print("GFT W->", target, messageType, data)
	end

	AceComm:SendCommMessage(ADDON_PREFIX, message, "WHISPER", target)
end

-- ============================================================
-- Event handlers
-- ============================================================

ClassicGuildTools.EventHandlers.ADDON_LOADED = function(addonName)
	if addonName ~= "ClassicGuildTools" then return end
	ClassicGuildToolsDB = ClassicGuildToolsDB or {}
	ClassicGuildToolsDB.minimap = ClassicGuildToolsDB.minimap or {}
end

ClassicGuildTools.EventHandlers.PLAYER_LOGIN = function()
	playerName = UnitName("player")
	playerRealm = GetRealmName()
	ClassicGuildTools.debugMode = playerName == "Pierrehunter"

	if ClassicGuildTools.Utils.isHardcore and UnitIsGhost("player") then
		ClassicGuildTools.SendGuildMessage(ClassicGuildTools.MESSAGE_TYPE.PLAYER_DIED)
	end
end

-- Receive messages via AceComm (handles automatic chunk reassembly)
AceComm:RegisterComm(ADDON_PREFIX, function(prefix, message, distribution, sender)
	local success, messageType, data = AceSerializer:Deserialize(message)
	if not success then return end

	sender = strsplit("-", sender)

	if ClassicGuildTools.debugMode then
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

SLASH_GUILDTOOLS1 = "/gt"
SLASH_GUILDTOOLS2 = "/guildtools"
SlashCmdList["GUILDTOOLS"] = function()
	ClassicGuildTools.UI.Toggle()
end

ClassicGuildTools.EventHandlers["PLAYER_DEAD"] = function()
	if ClassicGuildTools.Utils.isHardcore then
		ClassicGuildTools.SendGuildMessage(ClassicGuildTools.MESSAGE_TYPE.PLAYER_DIED)
	end
end

ClassicGuildTools.EventHandlers["GUILD_ROSTER_UPDATE"] = function()
	guildMemberCacheDirty = true
end
