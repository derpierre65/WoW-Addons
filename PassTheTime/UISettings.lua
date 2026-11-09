local _, PTT = ...
local L = PTT.L
local UI = PTT.UI

local ROW_HEIGHT = 56

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
}

local function BuildOptions(parent, width)
	local checkButtons = {}

	for index, option in ipairs(OPTIONS) do
		local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
		check:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
		check:SetScript("OnClick", function(self)
			option.set(self:GetChecked() and true or false)
		end)
		checkButtons[index] = check

		local label = UI.CreateLabel(parent, "GameFontHighlight", L[option.label])
		label:SetPoint("LEFT", check, "RIGHT", 4, 0)

		if option.hint then
			local hint = UI.CreateLabel(parent, "GameFontHighlightSmall", L[option.hint])
			hint:SetPoint("TOPLEFT", check, "BOTTOMLEFT", 30, 0)
			hint:SetWidth(width - 40)
			hint:SetJustifyH("LEFT")
			hint:SetTextColor(0.6, 0.6, 0.6)
		end
	end

	local function Refresh()
		for index, option in ipairs(OPTIONS) do
			checkButtons[index]:SetChecked(option.get())
		end
	end
	parent:HookScript("OnShow", Refresh)
	Refresh()
end

local function BuildSettingsView(parent)
	local view = CreateFrame("Frame", nil, parent)
	BuildOptions(view, UI.fullContentWidth)
	return view
end

PTT.RegisterView({ id = "settings", label = "settings", build = BuildSettingsView })

function UI.CreateOptionsPanel()
	local panel = CreateFrame("Frame", "PassTheTimeOptionsPanel")
	panel.name = L.addonTitle

	local content = CreateFrame("Frame", nil, panel)
	content:SetPoint("TOPLEFT", 16, -16)
	content:SetPoint("BOTTOMRIGHT", -16, 16)
	BuildOptions(content, 560)

	if Settings and Settings.RegisterCanvasLayoutCategory then
		Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutCategory(panel, panel.name))
	elseif InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(panel)
	end
end
