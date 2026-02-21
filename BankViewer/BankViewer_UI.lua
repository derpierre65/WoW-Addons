local SLOT_SIZE = 37
local SLOT_SPACING = 2
local BANK_CONTAINER = (Enum.BagIndex and Enum.BagIndex.Bank) or -1

local QUALITY_COLORS = {
	[0] = { r = 0.62, g = 0.62, b = 0.62 }, -- Poor
	[1] = { r = 1.00, g = 1.00, b = 1.00 }, -- Common
	[2] = { r = 0.12, g = 1.00, b = 0.00 }, -- Uncommon
	[3] = { r = 0.00, g = 0.44, b = 0.87 }, -- Rare
	[4] = { r = 0.64, g = 0.21, b = 0.93 }, -- Epic
	[5] = { r = 1.00, g = 0.50, b = 0.00 }, -- Legendary
}

local selectedRealm, selectedName
local selectedType = "character" -- "character", "guild", or "warband"
local selectedGuildRealm, selectedGuildName
local selectedSort = "none"
local searchText = ""
local slotButtons = {}

-- Main Frame
local mainFrame = CreateFrame("Frame", "BankViewerMainFrame", UIParent, "BackdropTemplate")
mainFrame:SetSize(600, 500)
mainFrame:SetPoint("CENTER")
mainFrame:SetMovable(true)
mainFrame:EnableMouse(true)
mainFrame:SetClampedToScreen(true)
mainFrame:RegisterForDrag("LeftButton")
mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
mainFrame:SetScript("OnDragStop", mainFrame.StopMovingOrSizing)
mainFrame:SetBackdrop({
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true,
	tileSize = 32,
	edgeSize = 32,
	insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
mainFrame:SetResizable(true)
mainFrame:SetResizeBounds(600, 250)
mainFrame:SetFrameStrata("MEDIUM")
mainFrame:Hide()

tinsert(UISpecialFrames, "BankViewerMainFrame")

-- Resize grip
local resizeButton = CreateFrame("Button", nil, mainFrame)
resizeButton:SetSize(16, 16)
resizeButton:SetPoint("BOTTOMRIGHT", -6, 7)
resizeButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
resizeButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
resizeButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
resizeButton:SetScript("OnMouseDown", function()
	mainFrame:StartSizing("BOTTOMRIGHT")
end)
resizeButton:SetScript("OnMouseUp", function()
	mainFrame:StopMovingOrSizing()
end)

-- Title
local title = mainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
title:SetPoint("TOP", 0, -20)
title:SetText("BankViewer")

-- Close button
local closeBtn = CreateFrame("Button", nil, mainFrame, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -5, -5)

-- Settings panel
local settingsPanel = CreateFrame("Frame", nil, mainFrame, "BackdropTemplate")
settingsPanel:SetPoint("TOPLEFT", mainFrame, "TOPRIGHT", 2, 0)
settingsPanel:SetSize(200, 135)
settingsPanel:SetBackdrop({
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true,
	tileSize = 32,
	edgeSize = 32,
	insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
settingsPanel:SetFrameStrata("HIGH")
settingsPanel:Hide()

local settingsTitle = settingsPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
settingsTitle:SetPoint("TOP", 0, -15)
settingsTitle:SetText("Settings")

local mergeBagsCheck = CreateFrame("CheckButton", "BankViewerMergeBagsCheck", settingsPanel, "UICheckButtonTemplate")
mergeBagsCheck:SetSize(26, 26)
mergeBagsCheck:SetPoint("TOPLEFT", 15, -32)
mergeBagsCheck.text = _G["BankViewerMergeBagsCheckText"]
mergeBagsCheck.text:SetText("Merge all bags")
mergeBagsCheck.text:SetFontObject("GameFontNormalSmall")
mergeBagsCheck:SetScript("OnClick", function(self)
	BankViewerDB._settings = BankViewerDB._settings or {}
	BankViewerDB._settings.mergeBags = self:GetChecked()
	BankViewer.UpdateUI()
end)

local showEmptyCheck = CreateFrame("CheckButton", "BankViewerShowEmptyCheck", settingsPanel, "UICheckButtonTemplate")
showEmptyCheck:SetSize(26, 26)
showEmptyCheck:SetPoint("TOPLEFT", mergeBagsCheck, "BOTTOMLEFT", 0, -2)
showEmptyCheck.text = _G["BankViewerShowEmptyCheckText"]
showEmptyCheck.text:SetText("Show empty slots")
showEmptyCheck.text:SetFontObject("GameFontNormalSmall")
showEmptyCheck:SetScript("OnClick", function(self)
	BankViewerDB._settings = BankViewerDB._settings or {}
	BankViewerDB._settings.showEmpty = self:GetChecked()
	BankViewer.UpdateUI()
end)

-- Guild bank vertical layout option (only available in TBC+, interface >= 20000)
local hasGuildBank = select(4, GetBuildInfo()) >= 20000
local guildBankVerticalCheck = CreateFrame("CheckButton", "BankViewerGuildBankVerticalCheck", settingsPanel, "UICheckButtonTemplate")
guildBankVerticalCheck:SetSize(26, 26)
guildBankVerticalCheck:SetPoint("TOPLEFT", showEmptyCheck, "BOTTOMLEFT", 0, -2)
guildBankVerticalCheck.text = _G["BankViewerGuildBankVerticalCheckText"]
guildBankVerticalCheck.text:SetText("Guild bank vertical layout")
guildBankVerticalCheck.text:SetFontObject("GameFontNormalSmall")
guildBankVerticalCheck:SetScript("OnClick", function(self)
	BankViewerDB._settings = BankViewerDB._settings or {}
	BankViewerDB._settings.guildBankVertical = self:GetChecked()
	BankViewer.UpdateUI()
end)
if not hasGuildBank then
	guildBankVerticalCheck:Hide()
	settingsPanel:SetSize(200, 105)
end

-- Settings button (gear icon)
local settingsBtn = CreateFrame("Button", nil, mainFrame)
settingsBtn:SetSize(20, 20)
settingsBtn:SetPoint("TOPRIGHT", closeBtn, "TOPLEFT", 2, -6)
settingsBtn:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
settingsBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
settingsBtn:SetScript("OnClick", function()
	if settingsPanel:IsShown() then
		settingsPanel:Hide()
	else
		-- Sync checkbox state
		BankViewerDB._settings = BankViewerDB._settings or {}
		mergeBagsCheck:SetChecked(BankViewerDB._settings.mergeBags)
		showEmptyCheck:SetChecked(BankViewerDB._settings.showEmpty)
		guildBankVerticalCheck:SetChecked(BankViewerDB._settings.guildBankVertical ~= false)
		settingsPanel:Show()
	end
end)

-- Scroll frame
local scrollFrame = CreateFrame("ScrollFrame", "BankViewerScrollFrame", mainFrame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 15, -65)
scrollFrame:SetPoint("BOTTOMRIGHT", -35, 15)

local scrollChild = CreateFrame("Frame", "BankViewerScrollChild", scrollFrame)
scrollChild:SetSize(260, 1)
scrollFrame:SetScrollChild(scrollChild)

-- Dropdown
local dropdown = CreateFrame("Frame", "BankViewerCharDropdown", mainFrame, "UIDropDownMenuTemplate")
dropdown:SetPoint("TOPLEFT", -5, -35)
UIDropDownMenu_SetText(dropdown, "Select Character")

local function UpdateDropdownWidth()
	local measureFont = dropdown:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	local maxWidth = 0

	local chars = BankViewer.GetCharacters and BankViewer.GetCharacters() or {}
	local guilds = BankViewer.GetGuilds and BankViewer.GetGuilds() or {}

	for _, char in ipairs(chars) do
		measureFont:SetText(char.name .. " - " .. char.realm)
		local w = measureFont:GetStringWidth()
		if w > maxWidth then maxWidth = w end
	end

	for _, guild in ipairs(guilds) do
		measureFont:SetText(guild.name .. " (Gildenbank)")
		local w = measureFont:GetStringWidth()
		if w > maxWidth then maxWidth = w end
	end

	if maxWidth == 0 then
		measureFont:SetText("Select Character")
		maxWidth = measureFont:GetStringWidth()
	end

	measureFont:Hide()
	UIDropDownMenu_SetWidth(dropdown, maxWidth + 25)
end
UIDropDownMenu_SetWidth(dropdown, 120)

local function InitDropdown(self, level)
	local chars = BankViewer.GetCharacters()
	local guilds = BankViewer.GetGuilds()
	local warbandData = BankViewer.GetWarbandBank()
	local hasWarband = warbandData and warbandData.tabs and next(warbandData.tabs)

	if #chars == 0 and #guilds == 0 and not hasWarband then
		local info = UIDropDownMenu_CreateInfo()
		info.text = "No data yet"
		info.disabled = true
		info.notCheckable = true
		UIDropDownMenu_AddButton(info)
		return
	end

	for _, char in ipairs(chars) do
		local info = UIDropDownMenu_CreateInfo()
		info.text = char.name .. " - " .. char.realm
		info.func = function()
			selectedType = "character"
			selectedRealm = char.realm
			selectedName = char.name
			selectedGuildRealm = nil
			selectedGuildName = nil
			UIDropDownMenu_SetText(dropdown, char.name .. " - " .. char.realm)
			CloseDropDownMenus()
			BankViewer.UpdateUI()
		end
		info.checked = (selectedType == "character" and selectedRealm == char.realm and selectedName == char.name)
		UIDropDownMenu_AddButton(info)
	end

	if hasWarband then
		local sep = UIDropDownMenu_CreateInfo()
		sep.disabled = true
		sep.notCheckable = true
		sep.isTitle = true
		sep.text = " "
		UIDropDownMenu_AddButton(sep)

		local displayName = "Warband Bank"
		local info = UIDropDownMenu_CreateInfo()
		info.text = displayName
		info.func = function()
			selectedType = "warband"
			selectedRealm = nil
			selectedName = nil
			selectedGuildRealm = nil
			selectedGuildName = nil
			UIDropDownMenu_SetText(dropdown, displayName)
			CloseDropDownMenus()
			BankViewer.UpdateUI()
		end
		info.checked = (selectedType == "warband")
		UIDropDownMenu_AddButton(info)
	end

	if #guilds > 0 then
		local sep = UIDropDownMenu_CreateInfo()
		sep.disabled = true
		sep.notCheckable = true
		sep.isTitle = true
		sep.text = " "
		UIDropDownMenu_AddButton(sep)

		for _, guild in ipairs(guilds) do
			local displayName = guild.name .. " (Gildenbank)"
			local info = UIDropDownMenu_CreateInfo()
			info.text = displayName
			info.disabled = false
			info.isTitle = false
			info.notCheckable = false
			info.func = function()
				selectedType = "guild"
				selectedGuildRealm = guild.realm
				selectedGuildName = guild.name
				selectedRealm = nil
				selectedName = nil
				UIDropDownMenu_SetText(dropdown, displayName)
				CloseDropDownMenus()
				BankViewer.UpdateUI()
			end
			info.checked = (selectedType == "guild" and selectedGuildRealm == guild.realm and selectedGuildName == guild.name)
			UIDropDownMenu_AddButton(info)
		end
	end
end

UIDropDownMenu_Initialize(dropdown, InitDropdown)

-- Sort function
local SORT_OPTIONS = {
	{ value = "none", label = "None" },
	{ value = "name_asc", label = "Name (A-Z)" },
	{ value = "name_desc", label = "Name (Z-A)" },
	{ value = "count_asc", label = "Stack (Low-High)" },
	{ value = "count_desc", label = "Stack (High-Low)" },
	{ value = "ilvl_asc", label = "Item Level (Low-High)" },
	{ value = "ilvl_desc", label = "Item Level (High-Low)" },
}

local function SortItems(items)
	if selectedSort == "none" then return end

	table.sort(items, function(a, b)
		-- Empty slots (false/nil) always sort to the end
		local aEmpty = not a or a == false
		local bEmpty = not b or b == false
		if aEmpty and bEmpty then return false end
		if aEmpty then return false end
		if bEmpty then return true end

		-- For visibleSlots entries (tables with .itemData), unwrap
		local aData = a.itemData or a
		local bData = b.itemData or b

		-- If itemData is nil/false inside wrapper, treat as empty
		if not aData or aData == false then return false end
		if not bData or bData == false then return true end

		if selectedSort == "count_asc" then
			return (aData.count or 1) < (bData.count or 1)
		elseif selectedSort == "count_desc" then
			return (aData.count or 1) > (bData.count or 1)
		end

		-- Name and ilvl need GetItemInfo
		local aName, _, _, aIlvl = C_Item.GetItemInfo(aData.itemLink or "")
		local bName, _, _, bIlvl = C_Item.GetItemInfo(bData.itemLink or "")
		aName = aName or ""
		bName = bName or ""
		aIlvl = aIlvl or 0
		bIlvl = bIlvl or 0

		if selectedSort == "name_asc" then
			return aName < bName
		elseif selectedSort == "name_desc" then
			return aName > bName
		elseif selectedSort == "ilvl_asc" then
			return aIlvl < bIlvl
		elseif selectedSort == "ilvl_desc" then
			return aIlvl > bIlvl
		end

		return false
	end)
end

-- Sort Dropdown
local sortDropdown = CreateFrame("Frame", "BankViewerSortDropdown", mainFrame, "UIDropDownMenuTemplate")
sortDropdown:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", 5, -35)

-- Search Box (stretches between the two dropdowns)
local searchBox = CreateFrame("EditBox", "BankViewerSearchBox", mainFrame, "InputBoxTemplate")
searchBox:SetHeight(20)
searchBox:SetPoint("LEFT", dropdown, "RIGHT", -4, 2)
searchBox:SetPoint("RIGHT", sortDropdown, "LEFT", 4, 2)
searchBox:SetAutoFocus(false)
searchBox:SetFontObject("GameFontHighlightSmall")

local searchPlaceholder = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
searchPlaceholder:SetPoint("LEFT", 5, 0)
searchPlaceholder:SetText("Search...")
searchBox.placeholder = searchPlaceholder

searchBox:SetScript("OnTextChanged", function(self)
	searchText = strlower(strtrim(self:GetText()))
	self.placeholder:SetShown(searchText == "")
	BankViewer.ApplySearchHighlight()
end)
searchBox:SetScript("OnEditFocusGained", function(self)
	self.placeholder:Hide()
end)
searchBox:SetScript("OnEditFocusLost", function(self)
	if strtrim(self:GetText()) == "" then
		self.placeholder:Show()
	end
end)
searchBox:SetScript("OnEscapePressed", function(self)
	self:ClearFocus()
end)
searchBox:SetScript("OnEnterPressed", function(self)
	self:ClearFocus()
end)
UIDropDownMenu_SetText(sortDropdown, "None")
UIDropDownMenu_SetWidth(sortDropdown, 120)

local function InitSortDropdown(self, level)
	for _, opt in ipairs(SORT_OPTIONS) do
		local info = UIDropDownMenu_CreateInfo()
		info.text = opt.label
		info.func = function()
			selectedSort = opt.value
			UIDropDownMenu_SetText(sortDropdown, opt.label)
			CloseDropDownMenus()
			BankViewer.UpdateUI()
		end
		info.checked = (selectedSort == opt.value)
		UIDropDownMenu_AddButton(info)
	end
end

UIDropDownMenu_Initialize(sortDropdown, InitSortDropdown)

local function CreateSlotButton(parent, index)
	local btn = CreateFrame("Button", nil, parent)
	btn:SetSize(SLOT_SIZE, SLOT_SIZE)

	local icon = btn:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints()
	btn.icon = icon

	local border = btn:CreateTexture(nil, "OVERLAY")
	border:SetSize(SLOT_SIZE + 3, SLOT_SIZE + 3)
	border:SetPoint("CENTER")
	border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
	border:SetBlendMode("ADD")
	border:SetAlpha(0.8)
	border:Hide()
	btn.border = border

	local countText = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
	countText:SetPoint("BOTTOMRIGHT", -2, 2)
	countText:SetJustifyH("RIGHT")
	btn.countText = countText

	-- Normal texture (empty slot look)
	local normalTex = btn:CreateTexture(nil, "ARTWORK")
	normalTex:SetAllPoints()
	normalTex:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
	btn.normalTex = normalTex

	btn:SetScript("OnEnter", function(self)
		if self.itemLink then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetHyperlink(self.itemLink)
			GameTooltip:Show()
		end
	end)

	btn:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	return btn
end

local function SetSlotItem(btn, itemData)
	if itemData then
		btn.icon:SetTexture(itemData.icon)
		btn.icon:Show()
		btn.normalTex:Hide()
		btn.itemLink = itemData.itemLink

		if itemData.count and itemData.count > 1 then
			btn.countText:SetText(itemData.count)
			btn.countText:Show()
		else
			btn.countText:Hide()
		end

		local color = QUALITY_COLORS[itemData.quality]
		if color and itemData.quality >= 2 then
			btn.border:SetVertexColor(color.r, color.g, color.b)
			btn.border:Show()
		else
			btn.border:Hide()
		end
	else
		btn.icon:Hide()
		btn.normalTex:Show()
		btn.itemLink = nil
		btn.countText:Hide()
		btn.border:Hide()
	end
end

-- Hidden tooltip for scanning item text
local scanTooltip = CreateFrame("GameTooltip", "BankViewerScanTooltip", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

local function ItemMatchesSearch(itemLink)
	-- Check item name first
	local itemName = C_Item.GetItemInfo(itemLink)
	if itemName and strfind(strlower(itemName), searchText, 1, true) then
		return true
	end

	-- Scan tooltip text
	scanTooltip:ClearLines()
	scanTooltip:SetHyperlink(itemLink)

	for i = 2, scanTooltip:NumLines() do
		local left = _G["BankViewerScanTooltipTextLeft" .. i]
		local right = _G["BankViewerScanTooltipTextRight" .. i]
		if left then
			local text = left:GetText()
			if text and strfind(strlower(text), searchText, 1, true) then
				return true
			end
		end
		if right then
			local text = right:GetText()
			if text and strfind(strlower(text), searchText, 1, true) then
				return true
			end
		end
	end

	return false
end

function BankViewer.ApplySearchHighlight()
	if searchText == "" then
		for _, btn in ipairs(slotButtons) do
			btn:SetAlpha(1)
		end
		return
	end

	for _, btn in ipairs(slotButtons) do
		if btn.itemLink then
			if ItemMatchesSearch(btn.itemLink) then
				btn:SetAlpha(1)
			else
				btn:SetAlpha(0.3)
			end
		else
			btn:SetAlpha(0.3)
		end
	end
end

local function CollectItems(itemsTable, slotCount, showEmpty)
	local items = {}
	for slot = 1, slotCount do
		local itemData = itemsTable[tostring(slot)] or itemsTable[slot]
		if itemData or showEmpty then
			table.insert(items, itemData or false)
		end
	end
	return items
end

local function ContainerHasItems(itemsTable, slotCount)
	for slot = 1, slotCount do
		if itemsTable[tostring(slot)] or itemsTable[slot] then
			return true
		end
	end
	return false
end

local function CreateSectionHeader(contentWidth, yOffset, label, icon)
	if not icon then
		local header = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		header:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -yOffset)
		header:SetText(label)
		return yOffset + 18
	end

	local headerFrame = CreateFrame("Frame", nil, scrollChild)
	headerFrame:SetSize(contentWidth, 20)
	headerFrame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -yOffset)

	local headerIcon = headerFrame:CreateTexture(nil, "ARTWORK")
	headerIcon:SetSize(18, 18)
	headerIcon:SetPoint("LEFT", 0, 0)
	headerIcon:SetTexture(icon)

	local headerLabel = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	headerLabel:SetPoint("LEFT", headerIcon, "RIGHT", 5, 0)
	headerLabel:SetText(label)

	headerFrame:Show()
	return yOffset + 22
end

local GUILD_BANK_COLUMNS = 14
local GUILD_BANK_ROWS = 7

local function RenderItemGrid(items, columns, yOffset)
	SortItems(items)

	for i, itemData in ipairs(items) do
		if itemData == false then itemData = nil end
		local btn = CreateSlotButton(scrollChild, i)
		local col = (i - 1) % columns
		local row = math.floor((i - 1) / columns)
		btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", col * (SLOT_SIZE + SLOT_SPACING), -(yOffset + row * (SLOT_SIZE + SLOT_SPACING)))
		SetSlotItem(btn, itemData)
		btn:Show()
		table.insert(slotButtons, btn)
	end

	local rows = math.ceil(#items / columns)
	return yOffset + rows * (SLOT_SIZE + SLOT_SPACING) + 10
end

-- Render guild bank items in vertical (column-major) layout matching the WoW guild bank UI.
-- In the API, slots 1-14 fill column 1 top-to-bottom, slots 15-28 fill column 2, etc.
local function RenderGuildBankVerticalGrid(items, yOffset)
	SortItems(items)

	-- When sorted, items are reordered so column-major transposition no longer applies
	if selectedSort ~= "none" then
		for i, itemData in ipairs(items) do
			if itemData == false then itemData = nil end
			local btn = CreateSlotButton(scrollChild, i)
			local col = (i - 1) % GUILD_BANK_COLUMNS
			local row = math.floor((i - 1) / GUILD_BANK_COLUMNS)
			btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", col * (SLOT_SIZE + SLOT_SPACING), -(yOffset + row * (SLOT_SIZE + SLOT_SPACING)))
			SetSlotItem(btn, itemData)
			btn:Show()
			table.insert(slotButtons, btn)
		end
		local rows = math.ceil(#items / GUILD_BANK_COLUMNS)
		return yOffset + rows * (SLOT_SIZE + SLOT_SPACING) + 10
	end

	-- Column-major: grid position (row, col) maps to item index col * GUILD_BANK_ROWS + row + 1
	for row = 0, GUILD_BANK_ROWS - 1 do
		for col = 0, GUILD_BANK_COLUMNS - 1 do
			local slotIndex = col * GUILD_BANK_ROWS + row + 1
			if slotIndex <= #items then
				local itemData = items[slotIndex]
				if itemData == false then itemData = nil end
				local btn = CreateSlotButton(scrollChild, slotIndex)
				btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", col * (SLOT_SIZE + SLOT_SPACING), -(yOffset + row * (SLOT_SIZE + SLOT_SPACING)))
				SetSlotItem(btn, itemData)
				btn:Show()
				table.insert(slotButtons, btn)
			end
		end
	end

	return yOffset + GUILD_BANK_ROWS * (SLOT_SIZE + SLOT_SPACING) + 10
end

function BankViewer.UpdateUI()
	UpdateDropdownWidth()

	-- Clear existing buttons
	for _, btn in ipairs(slotButtons) do
		btn:Hide()
		btn:SetParent(nil)
	end
	wipe(slotButtons)

	-- Hide extra children (section headers) and regions (font strings)
	for _, child in ipairs({ scrollChild:GetChildren() }) do
		child:Hide()
		child:SetParent(nil)
	end
	for _, region in ipairs({ scrollChild:GetRegions() }) do
		region:Hide()
		region:SetParent(nil)
	end

	-- Auto-select current char if nothing selected
	if selectedType == "character" and (not selectedRealm or not selectedName) then
		local realm, name = BankViewer.GetCurrentCharKey()
		if BankViewerDB and BankViewerDB[realm] and BankViewerDB[realm][name] then
			selectedRealm = realm
			selectedName = name
			UIDropDownMenu_SetText(dropdown, name .. " - " .. realm)
		end
	end

	local yOffset = 0
	local contentWidth = scrollFrame:GetWidth() - 5
	local columns = math.max(1, math.floor((contentWidth + SLOT_SPACING) / (SLOT_SIZE + SLOT_SPACING)))

	BankViewerDB._settings = BankViewerDB._settings or {}
	local mergeBags = BankViewerDB._settings.mergeBags
	local showEmpty = BankViewerDB._settings.showEmpty
	local guildBankVertical = BankViewerDB._settings.guildBankVertical ~= false

	if selectedType == "guild" then
		-- Guild bank display
		if not selectedGuildRealm or not selectedGuildName then return end

		local guildData = BankViewerDB._guilds and BankViewerDB._guilds[selectedGuildRealm] and BankViewerDB._guilds[selectedGuildRealm][selectedGuildName]
		if not guildData or not guildData.tabs then return end

		-- Collect tab indices in order
		local tabOrder = {}
		for tabIndex in pairs(guildData.tabs) do
			table.insert(tabOrder, tabIndex)
		end
		table.sort(tabOrder)

		if mergeBags then
			local allItems = {}
			for _, tabIndex in ipairs(tabOrder) do
				local tabData = guildData.tabs[tabIndex]
				if tabData then
					for _, item in ipairs(CollectItems(tabData.items, tabData.slots or 98, showEmpty)) do
						table.insert(allItems, item)
					end
				end
			end
			if guildBankVertical then
				yOffset = RenderGuildBankVerticalGrid(allItems, yOffset)
			else
				yOffset = RenderItemGrid(allItems, columns, yOffset)
			end
		else
			for _, tabIndex in ipairs(tabOrder) do
				local tabData = guildData.tabs[tabIndex]
				if tabData and (ContainerHasItems(tabData.items, tabData.slots or 98) or showEmpty) then
					yOffset = CreateSectionHeader(contentWidth, yOffset, tabData.name or ("Tab " .. tabIndex), tabData.icon)
					local items = CollectItems(tabData.items, tabData.slots or 98, showEmpty)
					if guildBankVertical then
						yOffset = RenderGuildBankVerticalGrid(items, yOffset)
					else
						yOffset = RenderItemGrid(items, columns, yOffset)
					end
				end
			end
		end
	elseif selectedType == "warband" then
		-- Warband bank display
		local warbandData = BankViewer.GetWarbandBank()
		if not warbandData or not warbandData.tabs then return end

		local tabOrder = {}
		for tabIndex in pairs(warbandData.tabs) do
			table.insert(tabOrder, tabIndex)
		end
		table.sort(tabOrder)

		if mergeBags then
			local allItems = {}
			for _, tabIndex in ipairs(tabOrder) do
				local tabData = warbandData.tabs[tabIndex]
				if tabData then
					for _, item in ipairs(CollectItems(tabData.items, tabData.slots or 98, showEmpty)) do
						table.insert(allItems, item)
					end
				end
			end
			yOffset = RenderItemGrid(allItems, columns, yOffset)
		else
			for _, tabIndex in ipairs(tabOrder) do
				local tabData = warbandData.tabs[tabIndex]
				if tabData and (ContainerHasItems(tabData.items, tabData.slots or 98) or showEmpty) then
					yOffset = CreateSectionHeader(contentWidth, yOffset, tabData.name or ("Tab " .. tabIndex), tabData.icon)
					local items = CollectItems(tabData.items, tabData.slots or 98, showEmpty)
					yOffset = RenderItemGrid(items, columns, yOffset)
				end
			end
		end
	else
		-- Character bank display
		if not selectedRealm or not selectedName then return end

		local data = BankViewerDB and BankViewerDB[selectedRealm] and BankViewerDB[selectedRealm][selectedName]
		if not data or not data.bags then return end

		-- Build bag order depending on classic vs retail bank system
		local bagOrder = {}
		if BankViewer.isRetailBankTabs then
			for tabIndex = 1, 6 do
				local bagID = Enum.BagIndex["CharacterBankTab_" .. tabIndex]
				if bagID then
					table.insert(bagOrder, bagID)
				end
			end
		else
			table.insert(bagOrder, BANK_CONTAINER)
			local bankBagFirst = NUM_BAG_SLOTS + 1
			local bankBagLast = NUM_BAG_SLOTS + (NUM_BANKBAGSLOTS or 0)
			for bagID = bankBagFirst, bankBagLast do
				table.insert(bagOrder, bagID)
			end
		end

		if mergeBags then
			local allItems = {}
			for _, bagID in ipairs(bagOrder) do
				local bagData = data.bags[tostring(bagID)] or data.bags[bagID]
				if bagData and bagData.slots and bagData.slots > 0 then
					for _, item in ipairs(CollectItems(bagData.items, bagData.slots, showEmpty)) do
						table.insert(allItems, item)
					end
				end
			end
			yOffset = RenderItemGrid(allItems, columns, yOffset)
		else
			for _, bagID in ipairs(bagOrder) do
				local bagData = data.bags[tostring(bagID)] or data.bags[bagID]
				if bagData and bagData.slots and bagData.slots > 0 and (ContainerHasItems(bagData.items, bagData.slots) or showEmpty) then
					local label, icon
					if BankViewer.isRetailBankTabs then
						label = bagData.tabName or ("Tab " .. bagID)
						icon = bagData.tabIcon
					else
						label = bagID == BANK_CONTAINER and "Main Bank" or ("Bag " .. (bagID - NUM_BAG_SLOTS))
						icon = bagID ~= BANK_CONTAINER and bagData.bagIcon or nil
					end
					yOffset = CreateSectionHeader(contentWidth, yOffset, label, icon)
					local items = CollectItems(bagData.items, bagData.slots, showEmpty)
					yOffset = RenderItemGrid(items, columns, yOffset)
				end
			end
		end
	end

	scrollChild:SetHeight(yOffset + 10)
	BankViewer.ApplySearchHighlight()
end

mainFrame:SetScript("OnShow", function()
	BankViewer.UpdateUI()
end)

local resizeTimer = nil
mainFrame:SetScript("OnSizeChanged", function()
	if mainFrame:IsShown() then
		if resizeTimer then
			resizeTimer:Cancel()
		end
		resizeTimer = C_Timer.NewTimer(0.15, function()
			BankViewer.UpdateUI()
			resizeTimer = nil
		end)
	end
end)

-- ElvUI Skinning
local function ApplyElvUISkin()
	local E = unpack(ElvUI)
	local S = E:GetModule("Skins")

	-- Main frame
	mainFrame:StripTextures()
	mainFrame:SetTemplate("Transparent")

	-- Title reposition for ElvUI template
	title:ClearAllPoints()
	title:SetPoint("TOP", 0, -10)

	-- Close button
	S:HandleCloseButton(closeBtn)
	closeBtn:ClearAllPoints()
	closeBtn:SetPoint("TOPRIGHT", -2, -2)

	-- Settings panel
	settingsPanel:StripTextures()
	settingsPanel:SetTemplate("Transparent")

	-- Checkboxes
	S:HandleCheckBox(mergeBagsCheck)
	S:HandleCheckBox(showEmptyCheck)
	S:HandleCheckBox(guildBankVerticalCheck)

	-- Scroll bar
	S:HandleScrollBar(BankViewerScrollFrameScrollBar)

	-- Skin a dropdown: fix Left, Button, and Text elements
	local function SkinDropdown(dropdownFrame, name)
		S:HandleDropDownBox(dropdownFrame)

		local left = _G[name .. "Left"]
		if left then
			left:ClearAllPoints()
			left:SetPoint("LEFT", dropdownFrame, "LEFT", 0, 0)
		end

		local button = _G[name .. "Button"]
		if button then
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", dropdownFrame, "TOPLEFT", 0, 0)
			button:SetPoint("BOTTOMRIGHT", dropdownFrame, "BOTTOMRIGHT", 0, 0)
		end

		local text = _G[name .. "Text"]
		if text then
			text:ClearAllPoints()
			text:SetPoint("RIGHT", dropdownFrame, "RIGHT", -20, 0)
		end
	end

	-- Dropdown
	SkinDropdown(dropdown, "BankViewerCharDropdown")
	dropdown:ClearAllPoints()
	dropdown:SetPoint("TOPLEFT", 15, -30)
	UpdateDropdownWidth()

	-- Search box (stretches between the two dropdowns)
	S:HandleEditBox(searchBox)
	searchBox:ClearAllPoints()
	searchBox:SetHeight(28)
	searchBox:SetPoint("LEFT", dropdown, "RIGHT", 8, 0)
	searchBox:SetPoint("RIGHT", sortDropdown, "LEFT", -8, 0)

	local searchIcon = searchBox:CreateTexture(nil, "OVERLAY")
	searchIcon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
	searchIcon:SetSize(14, 14)
	searchIcon:SetPoint("LEFT", searchBox, "LEFT", 4, -1)
	searchIcon:SetVertexColor(1, 1, 1, 0.8)

	searchBox:SetTextInsets(18, 0, 0, 0)
	searchBox.placeholder:ClearAllPoints()
	searchBox.placeholder:SetPoint("LEFT", 18, 0)

	-- Sort dropdown
	SkinDropdown(sortDropdown, "BankViewerSortDropdown")
	sortDropdown:ClearAllPoints()
	sortDropdown:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", -10, -30)

	-- Fix dropdown menu position to align left with the dropdown box
	hooksecurefunc("ToggleDropDownMenu", function(level, _, dropdownFrame)
		if dropdownFrame ~= dropdown and dropdownFrame ~= sortDropdown then return end
		local listFrame = _G["DropDownList1"]
		if listFrame and listFrame:IsShown() then
			listFrame:ClearAllPoints()
			listFrame:SetPoint("TOPLEFT", dropdownFrame, "BOTTOMLEFT", 0, -2)
		end
	end)

	-- Settings button - restyle as simple ElvUI button
	settingsBtn:StripTextures()
	settingsBtn:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
	settingsBtn:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
	settingsBtn:GetHighlightTexture():SetBlendMode("ADD")
	settingsBtn:ClearAllPoints()
	settingsBtn:SetPoint("RIGHT", closeBtn, "LEFT", -2, 0)

	-- Resize button - hide default textures, use simple arrow
	resizeButton:StripTextures()
	resizeButton:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	resizeButton:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	resizeButton:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

	-- Skin slot buttons when created
	local origCreateSlotButton = CreateSlotButton
	CreateSlotButton = function(parent, index)
		local btn = origCreateSlotButton(parent, index)
		btn:SetTemplate("Default")
		btn.icon:SetInside()
		btn.icon:SetTexCoord(unpack(E.TexCoords))
		btn.normalTex:SetInside()
		btn.normalTex:SetTexCoord(unpack(E.TexCoords))
		btn.border:SetAlpha(0)
		return btn
	end
end

local skinFrame = CreateFrame("Frame")
skinFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
skinFrame:SetScript("OnEvent", function(self)
	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	if ElvUI then
		local success, err = pcall(ApplyElvUISkin)
		if not success then
			print("|cff00ccffBankViewer:|r ElvUI skin failed: " .. tostring(err))
		end
	end
end)
