local _, PTT = ...
local L = PTT.L

local UI = {}
PTT.UI = UI

local WINDOW_WIDTH, WINDOW_HEIGHT = 920, 640
local NAV_WIDTH = 140
local BODY_PADDING = 10
local BODY_TOP = 28
local HEADER_HEIGHT = 76

UI.headerHeight = HEADER_HEIGHT
-- Content panel (4 px gap to the navigation) minus its 12 px inner padding on both sides.
UI.contentWidth = WINDOW_WIDTH - 2 * BODY_PADDING - NAV_WIDTH - 4 - 24
UI.fullContentWidth = WINDOW_WIDTH - 2 * BODY_PADDING - 24

local DEFAULT_ENTRY = "idle:monster"

-- Bottom tabs of the window. Entries open a view, optionally preselecting an inner tab of that view.
local GROUPS = {
	{
		id = "adventure",
		label = "tabAdventure",
		header = true,
		sections = {
			{
				label = "navPlay",
				entries = {
					{ label = "navBattle", view = "idle", tab = "monster" },
					{ label = "tabHeroes", view = "idle", tab = "ally" },
					{ label = "tabProfessions", view = "idle", tab = "profession" },
					{ label = "tabPrestige", view = "idle", tab = "prestige" },
				},
			},
			{
				label = "navProgress",
				entries = {
					-- Group and guild bosses are hidden until they are ready.
					{ label = "stats", view = "stats" },
					{ label = "leaderboard", view = "leaderboard" },
				},
			},
		},
	},
	{
		id = "minigames",
		label = "tabMiniGames",
		sections = {
			{
				label = "navGames",
				entries = {
					{ label = "game2048", view = "game2048" },
					{ label = "wordle", view = "wordle" },
					{ label = "minesweeper", view = "minesweeper" },
					{ label = "breakout", view = "breakout" },
					{ label = "memory", view = "memory" },
					{ label = "sudoku", view = "sudoku" },
				},
			},
		},
	},
	{
		id = "achievements",
		label = "achievements",
		hideNav = true,
		sections = {
			{
				label = "achievements",
				entries = {
					{ label = "achievements", view = "achievements" },
				},
			},
		},
	},
	{
		id = "settings",
		label = "settings",
		hideNav = true,
		plain = true,
		sections = {
			{
				label = "settings",
				entries = {
					{ label = "settings", view = "settings" },
				},
			},
		},
	},
}

local BACKDROP = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileSize = 16,
	edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

function UI.CreatePanel(parent, name)
	local panel = CreateFrame("Frame", name, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	panel:SetBackdrop(BACKDROP)
	panel:SetBackdropColor(0.04, 0.04, 0.07, 0.96)
	panel:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
	return panel
end

function UI.CreateButton(parent, text, width, height, onClick)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width, height)
	button:SetText(text)
	button:SetScript("OnClick", onClick)
	return button
end

function UI.HideTooltip()
	GameTooltip:Hide()
end

function UI.CreateLabel(parent, template, text)
	local label = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
	if text then
		label:SetText(text)
	end
	return label
end

local DEFAULT_BAR_COLOR = { 0.25, 0.25, 0.75 }

-- The bar of the default skills window, with its value centered inside. The texture is grey and tinted
-- by color; change the color later with bar:SetStatusBarColor.
function UI.CreateSkillBar(parent, height, color, textTemplate)
	color = color or DEFAULT_BAR_COLOR

	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetHeight(height)
	bar:SetStatusBarTexture("Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar")
	bar:SetStatusBarColor(color[1], color[2], color[3])
	bar:SetMinMaxValues(0, 1)

	bar.background = bar:CreateTexture(nil, "BACKGROUND")
	bar.background:SetAllPoints()
	bar.background:SetColorTexture(0, 0, 0, 0.6)

	-- The border art is 32 px tall with the frame drawn in its middle, so it keeps its native height and
	-- is centered on the bar; squeezing it to the bar height shrinks the drawn frame behind the fill.
	-- Three slices keep the rounded ends undistorted on wide bars.
	local file = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-BarBorder"
	local capWidth, capCoord, artHeight, overhang = 13, 0.05, 32, 5
	local left = bar:CreateTexture(nil, "OVERLAY")
	left:SetTexture(file)
	left:SetTexCoord(0, capCoord, 0, 1)
	left:SetSize(capWidth, artHeight)
	left:SetPoint("LEFT", bar, "LEFT", -overhang, 0)
	local right = bar:CreateTexture(nil, "OVERLAY")
	right:SetTexture(file)
	right:SetTexCoord(1 - capCoord, 1, 0, 1)
	right:SetSize(capWidth, artHeight)
	right:SetPoint("RIGHT", bar, "RIGHT", overhang, 0)
	local middle = bar:CreateTexture(nil, "OVERLAY")
	middle:SetTexture(file)
	middle:SetTexCoord(capCoord, 1 - capCoord, 0, 1)
	middle:SetHeight(artHeight)
	middle:SetPoint("LEFT", left, "RIGHT")
	middle:SetPoint("RIGHT", right, "LEFT")

	bar.text = UI.CreateLabel(bar, textTemplate or "GameFontHighlightSmall")
	bar.text:SetPoint("CENTER")
	return bar
end

-- The mouse-over API differs between clients.
local function IsMouseOverFrame(frame)
	if frame.IsMouseOver then
		return frame:IsMouseOver() and true or false
	end
	return MouseIsOver and MouseIsOver(frame) and true or false
end
UI.IsMouseOver = IsMouseOverFrame

-- Captures the keyboard only while the mouse is over the frame, so movement keys keep working elsewhere.
function UI.EnableHoverKeyboard(frame, handler)
	frame:SetPropagateKeyboardInput(true)

	frame:SetScript("OnUpdate", function(self)
		-- Never capture keys in combat: changing key propagation may be blocked there.
		local isOver = IsMouseOverFrame(self) and not InCombatLockdown()
		if isOver ~= self.keyboardActive then
			self.keyboardActive = isOver
			self:EnableKeyboard(isOver)
		end
	end)

	frame:SetScript("OnKeyDown", function(self, key)
		if InCombatLockdown() then
			return
		end
		self:SetPropagateKeyboardInput(not handler(key))
	end)

	frame:SetScript("OnHide", function(self)
		self.keyboardActive = false
		self:EnableKeyboard(false)
	end)
end

local window, body, header, navPanel, contentPanel, container
local viewFrames = {}
local entriesById = {}
local groupFrames = {}
local groupLastEntry = {}
local tabButtons = {}
local hasPanelTabs = false

-- Selecting an entry also switches the bottom tab and the header/navigation layout of its group.
function UI.Select(entryId)
	local entry = entriesById[entryId] or entriesById[DEFAULT_ENTRY]
	local group = entry.group

	header:SetShown(group.header == true)
	navPanel:ClearAllPoints()
	navPanel:SetPoint("TOPLEFT", body, "TOPLEFT", 0, group.header and -(HEADER_HEIGHT + 4) or 0)
	navPanel:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", 0, 0)
	navPanel:SetShown(not group.hideNav)

	contentPanel:ClearAllPoints()
	if group.hideNav then
		contentPanel:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
	else
		contentPanel:SetPoint("TOPLEFT", navPanel, "TOPRIGHT", 4, 0)
	end
	contentPanel:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", 0, 0)
	if group.plain then
		contentPanel:SetBackdrop(nil)
	else
		contentPanel:SetBackdrop(BACKDROP)
		contentPanel:SetBackdropColor(0.03, 0.03, 0.06, 0.9)
		contentPanel:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
	end

	for id, frame in pairs(groupFrames) do
		frame:SetShown(id == group.id)
	end

	for _, other in pairs(entriesById) do
		if other.group == group then
			other.button.selected:SetShown(other == entry)
		end
	end

	for id, frame in pairs(viewFrames) do
		frame:SetShown(id == entry.view)
	end

	if not viewFrames[entry.view] then
		local frame = PTT.views[entry.view].build(container)
		frame:SetAllPoints(container)
		viewFrames[entry.view] = frame
	end
	viewFrames[entry.view]:Show()

	if entry.tab and viewFrames[entry.view].SetTab then
		viewFrames[entry.view].SetTab(entry.tab)
	end

	for index, tab in ipairs(tabButtons) do
		if GROUPS[index] == group then
			if hasPanelTabs then
				PanelTemplates_SetTab(window, index)
			else
				tab:LockHighlight()
			end
		elseif not hasPanelTabs then
			tab:UnlockHighlight()
		end
	end

	groupLastEntry[group.id] = entry.id
	PTT.database.window.entry = entry.id
end

function UI.SelectView(viewId)
	for _, group in ipairs(GROUPS) do
		for _, section in ipairs(group.sections) do
			for _, entry in ipairs(section.entries) do
				if entry.view == viewId then
					UI.Select(entry.id)
					return
				end
			end
		end
	end
end

local function CreateNavButton(parent, text, onClick)
	local button = CreateFrame("Button", nil, parent)
	button:SetSize(NAV_WIDTH - 8, 24)
	button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

	button.selected = button:CreateTexture(nil, "BACKGROUND")
	button.selected:SetAllPoints()
	button.selected:SetColorTexture(1, 0.82, 0, 0.18)
	button.selected:Hide()

	button.label = UI.CreateLabel(button, "GameFontHighlight", text)
	button.label:SetPoint("LEFT", 10, 0)
	button:SetScript("OnClick", onClick)
	return button
end

local WINDOW_TEMPLATES = { "ButtonFrameTemplate", "BasicFrameTemplateWithInset" }
local TAB_TEMPLATES = { "PanelTabButtonTemplate", "CharacterFrameTabButtonTemplate" }

-- Standard Blizzard frame when the client has one, otherwise a plain backdrop panel.
local function CreateWindowFrame()
	for _, template in ipairs(WINDOW_TEMPLATES) do
		local success, frame = pcall(CreateFrame, "Frame", "PassTheTimeWindow", UIParent, template)
		if success then
			if ButtonFrameTemplate_HidePortrait then
				ButtonFrameTemplate_HidePortrait(frame)
			end
			if ButtonFrameTemplate_HideButtonBar then
				ButtonFrameTemplate_HideButtonBar(frame)
			end
			return frame, true
		end
	end

	return UI.CreatePanel(UIParent, "PassTheTimeWindow"), false
end

local function SetWindowTitle(frame, text)
	if frame.SetTitle then
		frame:SetTitle(text)
	elseif frame.TitleText then
		frame.TitleText:SetText(text)
	elseif frame.TitleContainer and frame.TitleContainer.TitleText then
		frame.TitleContainer.TitleText:SetText(text)
	end
end

local function CreateGroupTab(index, text)
	for _, template in ipairs(TAB_TEMPLATES) do
		local success, tab = pcall(CreateFrame, "Button", "PassTheTimeWindowTab" .. index, window, template)
		if success then
			tab:SetID(index)
			tab:SetText(text)
			if PanelTemplates_TabResize then
				pcall(PanelTemplates_TabResize, tab, 0)
			end
			return tab, true
		end
	end

	local tab = UI.CreateButton(window, text, 110, 24, nil)
	tab:SetID(index)
	return tab, false
end

local function SaveWindowPosition(self)
	local point, _, relativePoint, x, y = self:GetPoint()
	local saved = PTT.database.window
	saved.point, saved.relativePoint, saved.x, saved.y = point, relativePoint, x, y
end

function UI.CreateWindow()
	local isTemplated
	window, isTemplated = CreateWindowFrame()
	window:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
	window:SetFrameStrata("MEDIUM")
	-- Insets shrink the clamp area to the window center, so half of it may leave the screen (title bar stays visible at the top).
	window:SetClampedToScreen(true)
	window:SetClampRectInsets(WINDOW_WIDTH / 2, -WINDOW_WIDTH / 2, 0, WINDOW_HEIGHT / 2)
	window:SetMovable(true)
	window:EnableMouse(true)
	window:RegisterForDrag("LeftButton")
	window:SetScript("OnDragStart", window.StartMoving)
	window:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SaveWindowPosition(self)
	end)

	local saved = PTT.database.window
	window:SetPoint(saved.point, UIParent, saved.relativePoint or saved.point, saved.x, saved.y)

	if isTemplated then
		SetWindowTitle(window, L.addonTitle)
	else
		local title = UI.CreateLabel(window, "GameFontNormalLarge", L.addonTitle)
		title:SetPoint("TOP", 0, -14)

		local closeButton = CreateFrame("Button", nil, window, "UIPanelCloseButton")
		closeButton:SetPoint("TOPRIGHT", -2, -2)
	end

	body = CreateFrame("Frame", nil, window)
	body:SetPoint("TOPLEFT", BODY_PADDING, -(isTemplated and BODY_TOP or 36))
	body:SetPoint("BOTTOMRIGHT", -BODY_PADDING, BODY_PADDING)

	header = UI.CreatePanel(body)
	header:SetPoint("TOPLEFT")
	header:SetPoint("TOPRIGHT")
	header:SetHeight(HEADER_HEIGHT)
	if UI.BuildHeader then
		UI.BuildHeader(header)
	end

	navPanel = UI.CreatePanel(body)
	navPanel:SetWidth(NAV_WIDTH)
	navPanel:SetBackdropColor(0.06, 0.06, 0.09, 0.9)

	contentPanel = UI.CreatePanel(body)
	contentPanel:SetPoint("TOPLEFT", navPanel, "TOPRIGHT", 4, 0)
	contentPanel:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", 0, 0)
	contentPanel:SetBackdropColor(0.03, 0.03, 0.06, 0.9)

	container = CreateFrame("Frame", nil, contentPanel)
	container:SetPoint("TOPLEFT", 12, -12)
	container:SetPoint("BOTTOMRIGHT", -12, 12)

	for groupIndex, group in ipairs(GROUPS) do
		local frame = CreateFrame("Frame", nil, navPanel)
		frame:SetAllPoints()
		groupFrames[group.id] = frame

		local offsetY = -10
		for _, section in ipairs(group.sections) do
			local sectionLabel = UI.CreateLabel(frame, "GameFontNormalSmall", L[section.label])
			sectionLabel:SetPoint("TOPLEFT", 12, offsetY)
			offsetY = offsetY - 20

			for _, entry in ipairs(section.entries) do
				entry.id = entry.view .. (entry.tab and (":" .. entry.tab) or "")
				entry.group = group
				entry.button = CreateNavButton(frame, L[entry.label], function()
					UI.Select(entry.id)
				end)
				entry.button:SetPoint("TOPLEFT", 4, offsetY)
				offsetY = offsetY - 26
				entriesById[entry.id] = entry
				groupLastEntry[group.id] = groupLastEntry[group.id] or entry.id
			end

			offsetY = offsetY - 10
		end

		local tab, isPanelTab = CreateGroupTab(groupIndex, L[group.label])
		tab:SetScript("OnClick", function()
			UI.Select(groupLastEntry[group.id])
		end)
		tabButtons[groupIndex] = tab
		hasPanelTabs = isPanelTab
		if groupIndex == 1 then
			tab:SetPoint("TOPLEFT", window, "BOTTOMLEFT", 12, 2)
		else
			tab:SetPoint("LEFT", tabButtons[groupIndex - 1], "RIGHT", isPanelTab and -16 or 4, 0)
		end
	end

	if hasPanelTabs and PanelTemplates_SetNumTabs then
		PanelTemplates_SetNumTabs(window, #GROUPS)
	else
		hasPanelTabs = false
	end

	window:Hide()
	table.insert(UISpecialFrames, "PassTheTimeWindow")

	return window
end

function UI.Toggle()
	if window:IsShown() then
		window:Hide()
		return
	end

	window:Show()
	UI.Select(PTT.database.window.entry)
end

function UI.CreateMinimapButton()
	local button = CreateFrame("Button", "PassTheTimeMinimapButton", Minimap)
	button:SetSize(33, 33)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local overlay = button:CreateTexture(nil, "OVERLAY")
	overlay:SetSize(53, 53)
	overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	overlay:SetPoint("TOPLEFT")

	local icon = button:CreateTexture(nil, "BACKGROUND")
	icon:SetSize(21, 21)
	icon:SetTexture("Interface\\Icons\\INV_Misc_PocketWatch_01")
	icon:SetPoint("CENTER", 0, 1)

	local function UpdatePosition()
		local radians = math.rad(PTT.database.minimap.angle)
		local radius = Minimap:GetWidth() / 2 + 6
		button:ClearAllPoints()
		button:SetPoint("CENTER", Minimap, "CENTER", math.cos(radians) * radius, math.sin(radians) * radius)
	end

	button:RegisterForDrag("LeftButton")
	button:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", function()
			local centerX, centerY = Minimap:GetCenter()
			local cursorX, cursorY = GetCursorPosition()
			local scale = Minimap:GetEffectiveScale()
			PTT.database.minimap.angle = math.deg(math.atan2(cursorY / scale - centerY, cursorX / scale - centerX))
			UpdatePosition()
		end)
	end)
	button:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
	end)

	button:SetScript("OnClick", UI.Toggle)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine(L.addonTitle)
		GameTooltip:AddLine(L.minimapTooltip, 1, 1, 1)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", UI.HideTooltip)

	UpdatePosition()
	button:SetShown(not PTT.database.minimap.hidden)
	UI.minimapButton = button
end
