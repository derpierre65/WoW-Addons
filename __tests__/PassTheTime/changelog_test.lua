-- Run from the workspace root: lua __tests__/PassTheTime/changelog_test.lua
local function NewFrame()
	local frame = { scripts = {}, shown = false }
	local overrides = {
		Show = function(self) self.shown = true end,
		Hide = function(self) self.shown = false; if self.scripts.OnHide then self.scripts.OnHide(self) end end,
		IsShown = function(self) return self.shown end,
		SetScript = function(self, event, handler) self.scripts[event] = handler end,
		SetText = function(self, text) self.text = text end,
		GetStringHeight = function() return 12 end,
		CreateTexture = function() return NewFrame() end,
		CreateFontString = function() return NewFrame() end,
	}
	return setmetatable(frame, {
		__index = function(_, key)
			return overrides[key] or (key:match("^%u") and function() end) or nil
		end,
	})
end

function GetLocale() return "deDE" end
function CreateFrame() return NewFrame() end
UIParent = NewFrame()
UISpecialFrames = {}

local PTT = {}
local function Load(path)
	assert(loadfile(path))("PassTheTime", PTT)
end

Load("PassTheTime/Localization.lua")
Load("PassTheTime/Changelog.lua")

local loginCallbacks = {}
local createdPanels = {}
PTT.UI = {
	CreatePanel = function() local panel = NewFrame(); table.insert(createdPanels, panel); return panel end,
	CreateLabel = function(parent, template, text) local label = NewFrame(); label.text = text; return label end,
	CreateButton = function(parent, text, width, height, onClick) local button = NewFrame(); button.scripts.OnClick = onClick; return button end,
	ShowAfterLogin = function(callback) table.insert(loginCallbacks, callback) end,
}
Load("PassTheTime/UIChangelog.lua")

local Changelog, UI = PTT.Changelog, PTT.UI
local failures = 0
local function Check(condition, message)
	if not condition then
		failures = failures + 1
		print("FAIL: " .. message)
	end
end

Check(Changelog.Compare("0.10.0", "0.9.0") == 1, "0.10.0 is newer than 0.9.0")
Check(Changelog.Compare("0.4", "0.4.0") == 0, "missing parts count as zero")
Check(Changelog.Compare("0.3.0", "0.4.0") == -1, "0.3.0 is older than 0.4.0")

local entries = Changelog.GetBetween("0.2.0", "0.4.0")
Check(#entries == 2 and entries[1].version == "0.4.0" and entries[2].version == "0.3.0", "0.2.0 to 0.4.0 shows 0.4.0 and 0.3.0, newest first")
Check(#Changelog.GetBetween("0.3.0", "0.3.0") == 0, "same version shows nothing")
Check(#Changelog.GetBetween("0.3.0", "0.3.5") == 0, "unreleased versions stay hidden")
Check(Changelog.GetSections(entries[1])[1].changes[1]:find("Zauberkugeln"), "German client gets German changes")

for _, entry in ipairs(Changelog.entries) do
	local message = "version " .. entry.version .. " has the same sections and changes in enUS and deDE"
	Check(entry.enUS and entry.deDE and #entry.enUS == #entry.deDE, message)
	for index, section in ipairs(entry.enUS) do
		local translated = entry.deDE[index]
		Check(translated and #section.changes == #translated.changes and (section.title == nil) == (translated.title == nil), message)
	end
end

local function Start(database, version, isNewInstall)
	PTT.database = database
	PTT.version = version
	PTT.isNewInstall = isNewInstall
	loginCallbacks = {}
	UI.ScheduleChangelog()
end

-- Fresh install: nothing to show, the current version counts as seen.
Start({ setupDone = false }, "0.4.0", true)
Check(PTT.database.changelogVersion == "0.4.0" and #loginCallbacks == 0, "fresh install skips the changelog")
UI.ShowPendingChangelog()
Check(#createdPanels == 0, "fresh install has nothing pending")

-- Update from 0.3.0, which did not track the version yet and had no setup.
Start({ setupDone = false }, "0.4.0", false)
Check(PTT.database.changelogVersion == nil, "not marked as seen before it was shown")
Check(#loginCallbacks == 0, "waits for the setup instead of opening at login")
UI.ShowPendingChangelog()
local window = createdPanels[1]
Check(window and window:IsShown(), "closing the setup opens the changelog")
Check(window.subtitle.text == string.format(PTT.L.changelogSince, "0.3.0"), "subtitle names the last seen version")
window:Hide()
Check(PTT.database.changelogVersion == "0.4.0", "closing marks the version as seen")

-- Later update with the setup done: opens after login.
Start({ setupDone = true, changelogVersion = "0.3.0" }, "0.4.0", false)
Check(#loginCallbacks == 1, "scheduled after login")
loginCallbacks[1]()
Check(window:IsShown(), "shows after login")
window:Hide()

-- Login without update.
Start({ setupDone = true, changelogVersion = "0.4.0" }, "0.4.0", false)
Check(#loginCallbacks == 0, "no update, no changelog")

UI.ShowChangelog()
Check(window:IsShown() and window.subtitle.text == PTT.L.changelogAll, "/ptt changelog shows all changes")

if failures > 0 then
	error(failures .. " check(s) failed")
end
print("changelog_test OK")
