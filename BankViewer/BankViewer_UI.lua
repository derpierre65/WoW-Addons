local SLOT_SIZE = 37
local SLOT_SPACING = 2
local BANK_CONTAINER = Enum.BagIndex.Bank
local BANK_BAG_FIRST = NUM_BAG_SLOTS + 1
local BANK_BAG_LAST = NUM_BAG_SLOTS + NUM_BANKBAGSLOTS

local QUALITY_COLORS = {
	[0] = { r = 0.62, g = 0.62, b = 0.62 }, -- Poor
	[1] = { r = 1.00, g = 1.00, b = 1.00 }, -- Common
	[2] = { r = 0.12, g = 1.00, b = 0.00 }, -- Uncommon
	[3] = { r = 0.00, g = 0.44, b = 0.87 }, -- Rare
	[4] = { r = 0.64, g = 0.21, b = 0.93 }, -- Epic
	[5] = { r = 1.00, g = 0.50, b = 0.00 }, -- Legendary
}

local selectedRealm, selectedName
local selectedType = "character" -- "character" or "guild"
local selectedGuildRealm, selectedGuildName
local slotButtons = {}

-- Main Frame
local mainFrame = CreateFrame("Frame", "BankViewerMainFrame", UIParent, "BackdropTemplate")
mainFrame:SetSize(345, 500)
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
mainFrame:SetResizeBounds(300, 250)
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
settingsPanel:SetSize(200, 105)
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

	if #chars == 0 and #guilds == 0 then
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

	if #guilds > 0 then
		-- Separator
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
			-- Merged mode: all tab items in one continuous grid
			local allItems = {}
			for _, tabIndex in ipairs(tabOrder) do
				local tabData = guildData.tabs[tabIndex]
				if tabData then
					for slot = 1, (tabData.slots or 98) do
						local itemData = tabData.items[tostring(slot)] or tabData.items[slot]
						if itemData or showEmpty then
							table.insert(allItems, itemData or false)
						end
					end
				end
			end

			for i, itemData in ipairs(allItems) do
				if itemData == false then itemData = nil end
				local btn = CreateSlotButton(scrollChild, i)
				local col = (i - 1) % columns
				local row = math.floor((i - 1) / columns)
				btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", col * (SLOT_SIZE + SLOT_SPACING), -(yOffset + row * (SLOT_SIZE + SLOT_SPACING)))
				SetSlotItem(btn, itemData)
				btn:Show()
				table.insert(slotButtons, btn)
			end

			local rows = math.ceil(#allItems / columns)
			yOffset = yOffset + rows * (SLOT_SIZE + SLOT_SPACING) + 10
		else
			-- Per-tab mode
			for _, tabIndex in ipairs(tabOrder) do
				local tabData = guildData.tabs[tabIndex]
				if tabData then
					-- Check if tab has any items
					local hasItems = false
					for slot = 1, (tabData.slots or 98) do
						if tabData.items[tostring(slot)] or tabData.items[slot] then
							hasItems = true
							break
						end
					end

					if hasItems or showEmpty then
						-- Tab header with icon and name
						local headerFrame = CreateFrame("Frame", nil, scrollChild)
						headerFrame:SetSize(contentWidth, 20)
						headerFrame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -yOffset)

						if tabData.icon then
							local tabIcon = headerFrame:CreateTexture(nil, "ARTWORK")
							tabIcon:SetSize(18, 18)
							tabIcon:SetPoint("LEFT", 0, 0)
							tabIcon:SetTexture(tabData.icon)

							local tabLabel = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
							tabLabel:SetPoint("LEFT", tabIcon, "RIGHT", 5, 0)
							tabLabel:SetText(tabData.name or ("Tab " .. tabIndex))
						else
							local tabLabel = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
							tabLabel:SetPoint("LEFT", 0, 0)
							tabLabel:SetText(tabData.name or ("Tab " .. tabIndex))
						end

						headerFrame:Show()
						yOffset = yOffset + 22

						local visibleSlots = {}
						for slot = 1, (tabData.slots or 98) do
							local itemData = tabData.items[tostring(slot)] or tabData.items[slot]
							if itemData or showEmpty then
								table.insert(visibleSlots, { slot = slot, itemData = itemData })
							end
						end

						for i, slotInfo in ipairs(visibleSlots) do
							local btn = CreateSlotButton(scrollChild, slotInfo.slot)
							local col = (i - 1) % columns
							local row = math.floor((i - 1) / columns)
							btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", col * (SLOT_SIZE + SLOT_SPACING), -(yOffset + row * (SLOT_SIZE + SLOT_SPACING)))
							SetSlotItem(btn, slotInfo.itemData)
							btn:Show()
							table.insert(slotButtons, btn)
						end

						local rows = math.ceil(#visibleSlots / columns)
						yOffset = yOffset + rows * (SLOT_SIZE + SLOT_SPACING) + 10
					end
				end
			end
		end
	else
		-- Character bank display
		if not selectedRealm or not selectedName then return end

		local data = BankViewerDB and BankViewerDB[selectedRealm] and BankViewerDB[selectedRealm][selectedName]
		if not data or not data.bags then return end

		-- Collect all bag IDs in order
		local bagOrder = { BANK_CONTAINER }
		for bagID = BANK_BAG_FIRST, BANK_BAG_LAST do
			table.insert(bagOrder, bagID)
		end

		if mergeBags then
			-- Merged mode: all items in one continuous grid
			local allItems = {}
			for _, bagID in ipairs(bagOrder) do
				local bagData = data.bags[tostring(bagID)] or data.bags[bagID]
				if bagData and bagData.slots and bagData.slots > 0 then
					for slot = 1, bagData.slots do
						local itemData = bagData.items[tostring(slot)] or bagData.items[slot]
						if itemData or showEmpty then
							table.insert(allItems, itemData or false)
						end
					end
				end
			end

			for i, itemData in ipairs(allItems) do
				if itemData == false then itemData = nil end
				local btn = CreateSlotButton(scrollChild, i)
				local col = (i - 1) % columns
				local row = math.floor((i - 1) / columns)
				btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", col * (SLOT_SIZE + SLOT_SPACING), -(yOffset + row * (SLOT_SIZE + SLOT_SPACING)))
				SetSlotItem(btn, itemData)
				btn:Show()
				table.insert(slotButtons, btn)
			end

			local rows = math.ceil(#allItems / columns)
			yOffset = yOffset + rows * (SLOT_SIZE + SLOT_SPACING) + 10
		else
			-- Per-bag mode
			for _, bagID in ipairs(bagOrder) do
				local bagData = data.bags[tostring(bagID)] or data.bags[bagID]
				if bagData and bagData.slots and bagData.slots > 0 then
					-- Check if bag has any items
					local hasItems = false
					for slot = 1, bagData.slots do
						if bagData.items[tostring(slot)] or bagData.items[slot] then
							hasItems = true
							break
						end
					end

					-- Skip completely empty bags when showEmpty is off
					if hasItems or showEmpty then
					-- Bag header
					if bagID == BANK_CONTAINER then
						local header = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
						header:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -yOffset)
						header:SetText("Main Bank")
						yOffset = yOffset + 18
					else
						local headerFrame = CreateFrame("Frame", nil, scrollChild)
						headerFrame:SetSize(contentWidth, 20)
						headerFrame:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -yOffset)

						if bagData.bagIcon then
							local bagIcon = headerFrame:CreateTexture(nil, "ARTWORK")
							bagIcon:SetSize(18, 18)
							bagIcon:SetPoint("LEFT", 0, 0)
							bagIcon:SetTexture(bagData.bagIcon)

							local bagLabel = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
							bagLabel:SetPoint("LEFT", bagIcon, "RIGHT", 5, 0)
							bagLabel:SetText("Bag " .. (bagID - NUM_BAG_SLOTS))
						else
							local bagLabel = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
							bagLabel:SetPoint("LEFT", 0, 0)
							bagLabel:SetText("Bag " .. (bagID - NUM_BAG_SLOTS))
						end

						headerFrame:Show()
						yOffset = yOffset + 22
					end

					local visibleSlots = {}
					for slot = 1, bagData.slots do
						local itemData = bagData.items[tostring(slot)] or bagData.items[slot]
						if itemData or showEmpty then
							table.insert(visibleSlots, { slot = slot, itemData = itemData })
						end
					end

					for i, slotInfo in ipairs(visibleSlots) do
						local btn = CreateSlotButton(scrollChild, slotInfo.slot)
						local col = (i - 1) % columns
						local row = math.floor((i - 1) / columns)
						btn:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", col * (SLOT_SIZE + SLOT_SPACING), -(yOffset + row * (SLOT_SIZE + SLOT_SPACING)))
						SetSlotItem(btn, slotInfo.itemData)
						btn:Show()
						table.insert(slotButtons, btn)
					end

					local rows = math.ceil(#visibleSlots / columns)
					yOffset = yOffset + rows * (SLOT_SIZE + SLOT_SPACING) + 10
					end -- hasItems or showEmpty
				end
			end
		end
	end

	scrollChild:SetHeight(yOffset + 10)
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
		resizeTimer = C_Timer.NewTimer(0.01, function()
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

	-- Scroll bar
	S:HandleScrollBar(BankViewerScrollFrameScrollBar)

	-- Dropdown
	S:HandleDropDownBox(dropdown)
	dropdown:ClearAllPoints()
	dropdown:SetPoint("TOPLEFT", 15, -30)
	UpdateDropdownWidth()

	-- Fix the left frame inside the dropdown so the menu opens aligned
	local ddLeft = _G["BankViewerCharDropdownLeft"]
	if ddLeft then
		ddLeft:ClearAllPoints()
		ddLeft:SetPoint("LEFT", dropdown, "LEFT", 0, 0)
	end

	-- Make the entire dropdown clickable
	local ddButton = _G["BankViewerCharDropdownButton"]
	if ddButton then
		ddButton:ClearAllPoints()
		ddButton:SetPoint("TOPLEFT", dropdown, "TOPLEFT", 0, 0)
		ddButton:SetPoint("BOTTOMRIGHT", dropdown, "BOTTOMRIGHT", 0, 0)
	end

	local ddText = _G["BankViewerCharDropdownText"]
	if ddText then
		ddText:ClearAllPoints()
		ddText:SetPoint("RIGHT", dropdown, "RIGHT", -20, 0)
	end

	-- Fix dropdown menu position to align left with the dropdown box
	hooksecurefunc("ToggleDropDownMenu", function(level, _, dropdownFrame)
		if dropdownFrame ~= dropdown then return end
		local listFrame = _G["DropDownList1"]
		if listFrame and listFrame:IsShown() then
			listFrame:ClearAllPoints()
			listFrame:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -2)
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
