local _, PTT = ...
local L = PTT.L
local UI = PTT.UI

local SETUP_WIDTH = 520
local PADDING = 20
local TEXT_WIDTH = SETUP_WIDTH - 2 * PADDING
local FALLBACK_HEIGHT = 640
-- Gives the loading screen and the login chat spam time to settle.
local SHOW_DELAY = 3

local FEATURES = {
	{ key = "setupFeatureBattle" },
	{ key = "setupFeatureHeroes" },
	{ key = "setupFeaturePrestige", argument = PTT.Idle.PRESTIGE_UNLOCK_LEVEL },
	{ key = "setupFeatureWorld" },
	{ key = "setupFeatureMiniGames" },
	{ key = "setupFeatureSocial" },
}

local setup

local function CreateText(parent, template, text, anchor, offsetY)
	local label = UI.CreateLabel(parent, template, text)
	label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, offsetY)
	label:SetWidth(TEXT_WIDTH)
	label:SetJustifyH("LEFT")
	return label
end

-- The height depends on the wrapped text of the client language, so it is measured once laid out.
local function FitHeight()
	local top, bottom = setup:GetTop(), setup.lowestElement:GetBottom()
	if top and bottom then
		setup:SetHeight(top - bottom + PADDING)
		return true
	end
	return false
end

local function CreateSetupWindow()
	setup = UI.CreatePanel(UIParent, "PassTheTimeSetup")
	setup:SetSize(SETUP_WIDTH, FALLBACK_HEIGHT)
	setup:SetPoint("CENTER")
	setup:SetFrameStrata("DIALOG")
	setup:SetClampedToScreen(true)
	setup:SetMovable(true)
	setup:EnableMouse(true)
	setup:RegisterForDrag("LeftButton")
	setup:SetScript("OnDragStart", setup.StartMoving)
	setup:SetScript("OnDragStop", setup.StopMovingOrSizing)
	setup:SetScript("OnHide", function()
		PTT.database.setupDone = true
		-- Waits for the setup so both windows never open on top of each other.
		UI.ShowPendingChangelog()
	end)

	local closeButton = CreateFrame("Button", nil, setup, "UIPanelCloseButton")
	closeButton:SetPoint("TOPRIGHT", -2, -2)

	local icon = setup:CreateTexture(nil, "ARTWORK")
	icon:SetSize(40, 40)
	icon:SetTexture("Interface\\Icons\\INV_Misc_PocketWatch_01")
	icon:SetPoint("TOPLEFT", PADDING, -PADDING)

	local title = UI.CreateLabel(setup, "GameFontNormalLarge", L.setupTitle)
	title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -3)

	local subtitle = UI.CreateLabel(setup, "GameFontHighlightSmall", L.setupSubtitle)
	subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
	subtitle:SetTextColor(0.6, 0.6, 0.6)

	local intro = CreateText(setup, "GameFontHighlight", L.setupIntro, icon, -14)

	local previous = CreateText(setup, "GameFontNormal", L.setupHowItWorks, intro, -16)
	for _, feature in ipairs(FEATURES) do
		local text = feature.argument and string.format(L[feature.key], feature.argument) or L[feature.key]
		previous = CreateText(setup, "GameFontHighlightSmall", "- " .. text, previous, -6)
	end

	local settingsTitle = CreateText(setup, "GameFontNormal", L.settings, previous, -16)

	local options = CreateFrame("Frame", nil, setup)
	options:SetPoint("TOPLEFT", settingsTitle, "BOTTOMLEFT", 0, -6)
	options:SetSize(TEXT_WIDTH, 1)
	local lowestOption, optionIndent = UI.BuildOptions(options, TEXT_WIDTH)

	local footer = UI.CreateLabel(setup, "GameFontHighlightSmall", L.setupFooter)
	footer:SetPoint("TOPLEFT", lowestOption, "BOTTOMLEFT", -optionIndent, -14)
	footer:SetWidth(TEXT_WIDTH)
	footer:SetJustifyH("LEFT")
	footer:SetTextColor(0.6, 0.6, 0.6)

	local startButton = UI.CreateButton(setup, L.setupStart, 150, 24, function()
		setup:Hide()
		if not UI.IsShown() then
			UI.Toggle()
		end
	end)
	startButton:SetPoint("TOPRIGHT", footer, "BOTTOMRIGHT", 0, -16)

	local closeSetupButton = UI.CreateButton(setup, L.setupClose, 110, 24, function()
		setup:Hide()
	end)
	closeSetupButton:SetPoint("RIGHT", startButton, "LEFT", -8, 0)

	setup.lowestElement = startButton
	table.insert(UISpecialFrames, "PassTheTimeSetup")
end

function UI.ShowSetup()
	if not setup then
		CreateSetupWindow()
	end
	setup:Show()
	if not FitHeight() then
		C_Timer.After(0, FitHeight)
	end
end

local function RunOutOfCombat(callback)
	if not InCombatLockdown() then
		callback()
		return
	end

	local waitFrame = CreateFrame("Frame")
	waitFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
	waitFrame:SetScript("OnEvent", function(self)
		self:UnregisterEvent("PLAYER_REGEN_ENABLED")
		callback()
	end)
end

function UI.ShowAfterLogin(show)
	local loginFrame = CreateFrame("Frame")
	loginFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	loginFrame:SetScript("OnEvent", function(self, event)
		if event ~= "PLAYER_ENTERING_WORLD" then
			return
		end
		self:UnregisterEvent("PLAYER_ENTERING_WORLD")
		C_Timer.After(SHOW_DELAY, function()
			RunOutOfCombat(show)
		end)
	end)
end

function UI.ScheduleSetup()
	if PTT.database.setupDone then
		return
	end

	UI.ShowAfterLogin(UI.ShowSetup)
end
