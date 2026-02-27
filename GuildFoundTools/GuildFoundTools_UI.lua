-- Main frame, tab system, shared UI helpers

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
mainFrame.title:SetText("GuildFound Tools")

-- Make frame draggable
mainFrame:EnableMouse(true)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)

tinsert(UISpecialFrames, "GuildFoundToolsMainFrame")

-- ============================================================
-- Tab system
-- ============================================================

local TAB_NAMES = { "Gruppensuche", "Berufe" }
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
		GuildFoundTools.ShowTab(self:GetID())
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

PanelTemplates_SetNumTabs(mainFrame, #TAB_NAMES)
PanelTemplates_SetTab(mainFrame, 1)

function GuildFoundTools.ShowTab(tabIndex)
	for index, contentFrame in ipairs(contentFrames) do
		if index == tabIndex then
			contentFrame:Show()
		else
			contentFrame:Hide()
		end
	end
end

function GuildFoundTools.GetContentFrame(tabIndex)
	return contentFrames[tabIndex]
end

function GuildFoundTools.GetMainFrame()
	return mainFrame
end

function GuildFoundTools.Toggle()
	if mainFrame:IsShown() then
		mainFrame:Hide()
	else
		mainFrame:Show()
		GuildFoundTools.ShowTab(PanelTemplates_GetSelectedTab(mainFrame) or 1)
	end
end

-- Show first tab by default when frame opens and request group list
mainFrame:SetScript("OnShow", function()
	local selectedTab = PanelTemplates_GetSelectedTab(mainFrame) or 1
	GuildFoundTools.ShowTab(selectedTab)
	GuildFoundTools.RequestGroupList()
end)

-- Close child windows when main frame is hidden
mainFrame:SetScript("OnHide", function()
	if GuildFoundToolsCreateGroupDialog then
		GuildFoundToolsCreateGroupDialog:Hide()
	end
end)
