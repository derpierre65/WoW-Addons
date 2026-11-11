local _, PTT = ...
local L = PTT.L
local UI = PTT.UI

local ROW_SPACING = 4

-- get/set work on the "shown" state; Refresh on show keeps every copy of the box in sync.
local OPTIONS = {
	{
		label = "settingsMiniWidget",
		hint = "settingsMiniWidgetHint",
		get = function() return PTT.database.settings.miniWidget end,
		set = function(checked)
			PTT.database.settings.miniWidget = checked
			UI.SetMiniWidgetShown(checked)
		end,
	},
	{
		label = "settingsMinimapButton",
		get = function() return not PTT.database.minimap.hidden end,
		set = function(checked)
			PTT.database.minimap.hidden = not checked
			UI.minimapButton:SetShown(checked)
		end,
	},
	{
		label = "settingsCloseInCombat",
		get = function() return PTT.database.settings.closeInCombat end,
		set = function(checked)
			PTT.database.settings.closeInCombat = checked
		end,
	},
	{
		label = "settingsRealmLeaderboard",
		hint = "settingsRealmLeaderboardHint",
		get = function() return PTT.database.settings.realmLeaderboard end,
		set = function(checked)
			PTT.Network.SetRealmLeaderboard(checked)
		end,
	},
}

-- Returns the lowest element and its indent, so callers can anchor content below the options.
function UI.BuildOptions(parent, width)
	local checkButtons = {}
	-- Each row hangs below the previous row's lowest element, so rows without a hint stay compact.
	local previousBottom, previousIndent

	for index, option in ipairs(OPTIONS) do
		local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
		if previousBottom then
			check:SetPoint("TOPLEFT", previousBottom, "BOTTOMLEFT", -previousIndent, -ROW_SPACING)
		else
			check:SetPoint("TOPLEFT", 0, 0)
		end
		check:SetScript("OnClick", function(self)
			option.set(self:GetChecked() and true or false)
		end)
		checkButtons[index] = check
		previousBottom, previousIndent = check, 0

		local label = UI.CreateLabel(parent, "GameFontHighlight", L[option.label])
		label:SetPoint("LEFT", check, "RIGHT", 4, 0)

		if option.hint then
			local indent = check:GetWidth() + 4
			local hint = UI.CreateLabel(parent, "GameFontHighlightSmall", L[option.hint])
			hint:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -2)
			hint:SetWidth(width - indent)
			hint:SetJustifyH("LEFT")
			hint:SetTextColor(0.6, 0.6, 0.6)
			previousBottom, previousIndent = hint, indent
		end
	end

	local function Refresh()
		for index, option in ipairs(OPTIONS) do
			checkButtons[index]:SetChecked(option.get())
		end
	end
	parent:HookScript("OnShow", Refresh)
	Refresh()

	return previousBottom, previousIndent
end

local function BuildSettingsView(parent)
	local view = CreateFrame("Frame", nil, parent)
	UI.BuildOptions(view, UI.fullContentWidth)
	return view
end

PTT.RegisterView({ id = "settings", label = "settings", build = BuildSettingsView })

function UI.CreateOptionsPanel()
	local panel = CreateFrame("Frame", "PassTheTimeOptionsPanel")
	panel.name = L.addonTitle

	local content = CreateFrame("Frame", nil, panel)
	content:SetPoint("TOPLEFT", 16, -16)
	content:SetPoint("BOTTOMRIGHT", -16, 16)
	UI.BuildOptions(content, 560)

	if Settings and Settings.RegisterCanvasLayoutCategory then
		Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutCategory(panel, panel.name))
	elseif InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(panel)
	end
end
