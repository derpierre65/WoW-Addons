-- Main frame, tab system, shared UI helpers

ClassicGuildTools.UI = ClassicGuildTools.UI or {}

local L = LibStub("AceLocale-3.0"):GetLocale("ClassicGuildTools")

local FRAME_WIDTH = 500
local FRAME_HEIGHT = 450

-- Main Frame (BasicFrameTemplateWithInset provides title bar, close button, inset)
local mainFrame = CreateFrame("Frame", "ClassicGuildToolsMainFrame", UIParent, "BasicFrameTemplateWithInset")
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

tinsert(UISpecialFrames, "ClassicGuildToolsMainFrame")

-- Settings gear button (left of the close button)
ClassicGuildTools.UI.showAllLevelRanges = false

local settingsButton = CreateFrame("Button", nil, mainFrame)
settingsButton:SetSize(20, 20)
settingsButton:SetPoint("RIGHT", mainFrame.CloseButton, "LEFT", 4, 0)
settingsButton:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
settingsButton:SetHighlightTexture("Interface\\Buttons\\UI-OptionsButton")
settingsButton:GetHighlightTexture():SetAlpha(0.4)

local settingsDropdownFrame = CreateFrame("Frame", "ClassicGuildToolsSettingsDropdown", mainFrame, "UIDropDownMenuTemplate")
settingsDropdownFrame:Hide()

UIDropDownMenu_Initialize(settingsDropdownFrame, function()
	local info = UIDropDownMenu_CreateInfo()
	info.text = L["SettingsShowAllLevelRanges"]
	info.isNotRadio = true
	info.keepShownOnClick = true
	info.checked = ClassicGuildTools.UI.showAllLevelRanges
	info.func = function(_, _, _, checked)
		ClassicGuildTools.UI.showAllLevelRanges = checked
		if ClassicGuildTools.LFG and ClassicGuildTools.LFG.UpdateLFGUI then
			ClassicGuildTools.LFG.UpdateLFGUI(true)
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
	local tabButton = CreateFrame("Button", "ClassicGuildToolsMainFrameTab" .. index, mainFrame, "CharacterFrameTabButtonTemplate")
	tabButton:SetID(index)
	tabButton:SetText(TAB_NAMES[index])

	if index == 1 then
		tabButton:SetPoint("CENTER", mainFrame, "BOTTOMLEFT", 60, -12)
	else
		tabButton:SetPoint("LEFT", "ClassicGuildToolsMainFrameTab" .. (index - 1), "RIGHT", -16, 0)
	end

	tabButton:SetScript("OnClick", function(self)
		PanelTemplates_SetTab(mainFrame, self:GetID())
		ClassicGuildTools.UI.ShowTab(self:GetID())
	end)
end

-- Create content frames for each tab (below tabs, inside inset area)
for index = 1, #TAB_NAMES do
	local contentFrame = CreateFrame("Frame", "ClassicGuildToolsTab" .. index .. "Content", mainFrame)
	contentFrame:SetPoint("TOPLEFT", mainFrame.InsetBg or mainFrame.Inset, "TOPLEFT", 8, -5)
	contentFrame:SetPoint("BOTTOMRIGHT", mainFrame.InsetBg or mainFrame.Inset, "BOTTOMRIGHT", -8, 8)
	contentFrame:Hide()
	contentFrames[index] = contentFrame
end

local tabButtons = {}
for index = 1, #TAB_NAMES do
	tabButtons[index] = _G["ClassicGuildToolsMainFrameTab" .. index]
end

PanelTemplates_SetNumTabs(mainFrame, #TAB_NAMES)
PanelTemplates_SetTab(mainFrame, 1)

function ClassicGuildTools.UI.SetTabText(tabIndex, text)
	local tabButton = tabButtons[tabIndex]
	if tabButton then
		tabButton:SetText(text)
		PanelTemplates_TabResize(tabButton, 0)
	end
end

function ClassicGuildTools.UI.SetTabEnabled(tabIndex, enabled, disabledTooltip)
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
			ClassicGuildTools.UI.ShowTab(1)
		end
	end
end

ClassicGuildTools.UI.SetTabEnabled(3, true)

function ClassicGuildTools.UI.ShowTab(tabIndex)
	local currentLeft = mainFrame:GetLeft()
	local currentTop = mainFrame:GetTop()

	if tabIndex == 3 then
		mainFrame:SetWidth(800)
	else
		mainFrame:SetWidth(FRAME_WIDTH)
	end

	if currentLeft and currentTop then
		mainFrame:ClearAllPoints()
		mainFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", currentLeft, currentTop)
	end

	for index, contentFrame in ipairs(contentFrames) do
		if index == tabIndex then
			contentFrame:Show()
		else
			contentFrame:Hide()
		end
	end

	if tabIndex == 3 and ClassicGuildTools.UI.UpdateProfessionsUI then
		ClassicGuildTools.UI.UpdateProfessionsUI()
	end
end

function ClassicGuildTools.UI.GetContentFrame(tabIndex)
	return contentFrames[tabIndex]
end

function ClassicGuildTools.UI.GetMainFrame()
	return mainFrame
end

function ClassicGuildTools.UI.Toggle()
	if mainFrame:IsShown() then
		mainFrame:Hide()
	else
		mainFrame:Show()
		ClassicGuildTools.UI.ShowTab(PanelTemplates_GetSelectedTab(mainFrame) or 1)
	end
end

-- Show first tab by default when frame opens and request group list
mainFrame:SetScript("OnShow", function()
	local selectedTab = PanelTemplates_GetSelectedTab(mainFrame) or 1
	ClassicGuildTools.UI.ShowTab(selectedTab)
	ClassicGuildTools.LFG.RequestGroupList()
end)

