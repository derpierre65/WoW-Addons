-- Minimal WoW API stubs for testing

-- Lua 5.1 compatibility
_G.unpack = _G.unpack or table.unpack

-- WoW API stubs
_G._testPlayersByGUID = {}

function _G.GetPlayerInfoByGUID(guid)
	local data = _G._testPlayersByGUID[guid]
	if data then
		return nil, nil, nil, nil, nil, data.name
	end
	return nil
end

function _G.IsInGuild()
	return true
end

function _G.GetGuildInfo()
	return "TestGuild"
end

function _G.GetRealmName()
	return "TestRealm"
end

function _G.UnitGUID()
	return "player-guid"
end

function _G.UnitName(unit)
	if unit == "player" then return "TestPlayer" end
	return nil
end

function _G.GetSpellInfo(spellId)
	return "Spell" .. spellId, nil, nil
end

function _G.GetNumSkillLines()
	return 0
end

function _G.GetSpellLink()
	return nil
end

function _G.GetItemInfo()
	return nil
end

function _G.GetNumGuildMembers()
	return 0
end

function _G.GetGuildRosterInfo()
	return nil
end

function _G.wipe(table)
	for key in pairs(table) do
		table[key] = nil
	end
end

-- LibStub stub
_G.LibStub = setmetatable({}, {
	__call = function(self, name)
		if name == "AceLocale-3.0" then
			return {
				GetLocale = function()
					return setmetatable({}, {
						__index = function(_, key) return key end,
					})
				end,
			}
		end
		return {}
	end,
})

-- Event system
_G._testFrames = {}

function _G.Test_SendEvent(event, ...)
	for _, frame in ipairs(_G._testFrames) do
		if frame._events[event] and frame._scripts["OnEvent"] then
			frame._scripts["OnEvent"](frame, event, ...)
		end
	end
end

-- Frame stubs
local function CreateFontString()
	return {
		SetPoint = function() end,
		SetText = function() end,
		SetJustifyH = function() end,
		SetWordWrap = function() end,
		Hide = function() end,
		Show = function() end,
		GetWidth = function() return 200 end,
		GetStringWidth = function() return 100 end,
	}
end

local function CreateTexture()
	return {
		SetSize = function() end,
		SetPoint = function() end,
		SetAllPoints = function() end,
		SetColorTexture = function() end,
		SetTexture = function() end,
		SetAlpha = function() end,
	}
end

function _G.CreateFrame(frameType, name, parent, template)
	local frame = {
		_events = {},
		_scripts = {},
		SetSize = function() end,
		SetPoint = function() end,
		SetHeight = function() end,
		SetWidth = function() end,
		SetAutoFocus = function() end,
		SetFontObject = function() end,
		SetScrollChild = function() end,
		SetDefaultText = function() end,
		EnableMouse = function() end,
		Hide = function() end,
		Show = function() end,
		GetWidth = function() return 400 end,
		GetHeight = function() return 300 end,
		CreateFontString = function() return CreateFontString() end,
		CreateTexture = function() return CreateTexture() end,
		HookScript = function() end,
		SetNormalTexture = function() end,
		SetHighlightTexture = function() end,
		GetHighlightTexture = function() return { SetAlpha = function() end } end,
		SetupMenu = function() end,
		SetMovable = function() end,
		SetFrameStrata = function() end,
		SetClampedToScreen = function() end,
		SetFrameLevel = function() end,
		RegisterForDrag = function() end,
		SetID = function() end,
		GetID = function() return 0 end,
		SetText = function() end,
		GetText = function() return "" end,
		SetEnabled = function() end,
		Disable = function() end,
		Enable = function() end,
		Click = function() end,
	}

	function frame:SetScript(scriptType, handler)
		self._scripts[scriptType] = handler
	end

	function frame:RegisterEvent(event)
		self._events[event] = true
	end

	function frame:UnregisterEvent(event)
		self._events[event] = nil
	end

	table.insert(_G._testFrames, frame)

	return frame
end

_G.GameTooltip = { HookScript = function() end }
_G.GameFontHighlight = {}
_G.GameFontNormal = {}
_G.GameFontDisable = {}
_G.GameFontDisableSmall = {}
_G.ChatFontNormal = {}
_G.MenuUtil = { CreateContextMenu = function() end }

function _G.GetScreenHeight() return 768 end

_G.SlashCmdList = {}
_G.PanelTemplates_SetNumTabs = function() end
_G.PanelTemplates_SetTab = function() end
_G.UISpecialFrames = {}
_G.tinsert = table.insert

function _G.strsplit(delimiter, text, limit)
	local result = {}
	local pattern = "([^" .. delimiter .. "]*)"
	for match in text:gmatch(pattern) do
		table.insert(result, match)
		if limit and #result >= limit then break end
	end
	return unpack(result)
end

function _G.GetBuildInfo()
	return "1.15.6", "57461", "Jan 1 2025", 11506
end

_G.C_Timer = {
	NewTimer = function(_, _)
		return { Cancel = function() end }
	end,
	After = function(_, _) end,
}