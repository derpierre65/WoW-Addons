-- Main frame, tab system, shared UI helpers

GuildFoundTools.UI = GuildFoundTools.UI or {}

local L = LibStub("AceLocale-3.0"):GetLocale("GuildFoundTools")

local FRAME_WIDTH = 500
local FRAME_HEIGHT = 450

-- Main Frame (BasicFrameTemplateWithInset provides title bar, close button, inset)
local mainFrame = CreateFrame("Frame", "GuildFoundToolsMainFrame", UIParent, "BasicFrameTemplateWithInset")
mainFrame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
mainFrame:SetPoint("CENTER")
mainFrame:SetMovable(true)
mainFrame:SetClampedToScreen(true)
mainFrame:SetFrameStrata("MEDIUM")
mainFrame:Hide()

-- Title (centered on the built-in title background)
mainFrame.title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
mainFrame.title:SetPoint("CENTER", mainFrame.TitleBg, "CENTER", 0, 0)
mainFrame.title:SetText(L["AddonTitle"])

-- Make frame draggable
mainFrame:EnableMouse(true)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)

tinsert(UISpecialFrames, "GuildFoundToolsMainFrame")

-- Settings gear button (left of the close button)
GuildFoundTools.UI.showAllLevelRanges = false

local settingsButton = CreateFrame("Button", nil, mainFrame)
settingsButton:SetSize(20, 20)
settingsButton:SetPoint("RIGHT", mainFrame.CloseButton, "LEFT", 4, 0)
settingsButton:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
settingsButton:SetHighlightTexture("Interface\\Buttons\\UI-OptionsButton")
settingsButton:GetHighlightTexture():SetAlpha(0.4)

local settingsDropdownFrame = CreateFrame("Frame", "GuildFoundToolsSettingsDropdown", mainFrame, "UIDropDownMenuTemplate")
settingsDropdownFrame:Hide()

UIDropDownMenu_Initialize(settingsDropdownFrame, function()
	local info = UIDropDownMenu_CreateInfo()
	info.text = L["SettingsShowAllLevelRanges"]
	info.isNotRadio = true
	info.keepShownOnClick = true
	info.checked = GuildFoundTools.UI.showAllLevelRanges
	info.func = function(_, _, _, checked)
		GuildFoundTools.UI.showAllLevelRanges = checked
		if GuildFoundTools.LFG and GuildFoundTools.LFG.UpdateLFGUI then
			GuildFoundTools.LFG.UpdateLFGUI()
		end
	end
	UIDropDownMenu_AddButton(info)
end, "MENU")

settingsButton:SetScript("OnClick", function(self)
	ToggleDropDownMenu(1, nil, settingsDropdownFrame, self, 0, 0)
end)

-- ============================================================
-- Tab system
-- ============================================================

local TAB_NAMES = { L["TabGroupBrowser"], L["TabCreateGroup"], L["TabProfessions"] }
local contentFrames = {}

-- Create tab buttons (below the frame)
for index = 1, #TAB_NAMES do
	local tabButton = CreateFrame("Button", "GuildFoundToolsMainFrameTab" .. index, mainFrame, "CharacterFrameTabButtonTemplate")
	tabButton:SetID(index)
	tabButton:SetText(TAB_NAMES[index])

	if index == 1 then
		tabButton:SetPoint("CENTER", mainFrame, "BOTTOMLEFT", 60, -12)
	else
		tabButton:SetPoint("LEFT", "GuildFoundToolsMainFrameTab" .. (index - 1), "RIGHT", -16, 0)
	end

	tabButton:SetScript("OnClick", function(self)
		PanelTemplates_SetTab(mainFrame, self:GetID())
		GuildFoundTools.UI.ShowTab(self:GetID())
	end)
end

-- Create content frames for each tab (below tabs, inside inset area)
for index = 1, #TAB_NAMES do
	local contentFrame = CreateFrame("Frame", "GuildFoundToolsTab" .. index .. "Content", mainFrame)
	contentFrame:SetPoint("TOPLEFT", mainFrame.InsetBg or mainFrame.Inset, "TOPLEFT", 8, -5)
	contentFrame:SetPoint("BOTTOMRIGHT", mainFrame.InsetBg or mainFrame.Inset, "BOTTOMRIGHT", -8, 8)
	contentFrame:Hide()
	contentFrames[index] = contentFrame
end

local tabButtons = {}
for index = 1, #TAB_NAMES do
	tabButtons[index] = _G["GuildFoundToolsMainFrameTab" .. index]
end

PanelTemplates_SetNumTabs(mainFrame, #TAB_NAMES)
PanelTemplates_SetTab(mainFrame, 1)
PanelTemplates_DisableTab(mainFrame, 3)

function GuildFoundTools.UI.SetTabText(tabIndex, text)
	local tabButton = tabButtons[tabIndex]
	if tabButton then
		tabButton:SetText(text)
		PanelTemplates_TabResize(tabButton, 0)
	end
end

function GuildFoundTools.UI.SetTabEnabled(tabIndex, enabled, disabledTooltip)
	local tabButton = tabButtons[tabIndex]
	if not tabButton then return end

	tabButton.disabledTooltip = not enabled and disabledTooltip or nil

	if not tabButton.tooltipInitialized then
		tabButton:HookScript("OnEnter", function(self)
			if self.disabledTooltip and not self:IsEnabled() then
				GameTooltip:SetOwner(self, "ANCHOR_TOP")
				GameTooltip:SetText(self.disabledTooltip)
				GameTooltip:Show()
			end
		end)
		tabButton:HookScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		tabButton.tooltipInitialized = true
	end

	if enabled then
		PanelTemplates_EnableTab(mainFrame, tabIndex)
	else
		PanelTemplates_DisableTab(mainFrame, tabIndex)
		-- If the disabled tab is currently selected, switch to tab 1
		if PanelTemplates_GetSelectedTab(mainFrame) == tabIndex then
			PanelTemplates_SetTab(mainFrame, 1)
			GuildFoundTools.UI.ShowTab(1)
		end
	end
end

function GuildFoundTools.UI.ShowTab(tabIndex)
	for index, contentFrame in ipairs(contentFrames) do
		if index == tabIndex then
			contentFrame:Show()
		else
			contentFrame:Hide()
		end
	end
end

function GuildFoundTools.UI.GetContentFrame(tabIndex)
	return contentFrames[tabIndex]
end

function GuildFoundTools.UI.GetMainFrame()
	return mainFrame
end

function GuildFoundTools.UI.Toggle()
	if mainFrame:IsShown() then
		mainFrame:Hide()
	else
		mainFrame:Show()
		GuildFoundTools.UI.ShowTab(PanelTemplates_GetSelectedTab(mainFrame) or 1)
	end
end

-- Show first tab by default when frame opens and request group list
mainFrame:SetScript("OnShow", function()
	local selectedTab = PanelTemplates_GetSelectedTab(mainFrame) or 1
	GuildFoundTools.UI.ShowTab(selectedTab)
	GuildFoundTools.LFG.RequestGroupList()
end)

