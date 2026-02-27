-- Professions tab: query guild, display recipes

local contentFrame = GuildFoundTools.GetContentFrame(2)

local LEFT_PANEL_WIDTH = 180
local selectedMember = nil
local selectedProfession = nil
local pendingItemRequests = {}

-- ============================================================
-- Top bar
-- ============================================================

local queryButton = CreateFrame("Button", nil, contentFrame, "UIPanelButtonTemplate")
queryButton:SetSize(140, 22)
queryButton:SetPoint("TOPLEFT", 0, 0)
queryButton:SetText("Berufe abfragen")

local statusText = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
statusText:SetPoint("LEFT", queryButton, "RIGHT", 10, 0)
statusText:SetText("")

queryButton:SetScript("OnClick", function()
	statusText:SetText("Abfrage gesendet...")
	GuildFoundTools.RequestProfessions()
	C_Timer.After(5, function()
		local count = 0
		for _ in pairs(GuildFoundTools.professions) do
			count = count + 1
		end
		statusText:SetText(count .. " Antworten erhalten")
	end)
end)

-- ============================================================
-- Left panel: member list with professions
-- ============================================================

local leftPanel = CreateFrame("Frame", nil, contentFrame, "BackdropTemplate")
leftPanel:SetPoint("TOPLEFT", 0, -30)
leftPanel:SetPoint("BOTTOMLEFT", 0, 0)
leftPanel:SetWidth(LEFT_PANEL_WIDTH)
leftPanel:SetBackdrop({
	bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileSize = 16,
	edgeSize = 12,
	insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
leftPanel:SetBackdropColor(0, 0, 0, 0.6)

local leftScrollFrame = CreateFrame("ScrollFrame", "GuildFoundToolsProfLeftScroll", leftPanel, "UIPanelScrollFrameTemplate")
leftScrollFrame:SetPoint("TOPLEFT", 5, -5)
leftScrollFrame:SetPoint("BOTTOMRIGHT", -25, 5)

local leftScrollChild = CreateFrame("Frame", "GuildFoundToolsProfLeftScrollChild", leftScrollFrame)
leftScrollChild:SetSize(LEFT_PANEL_WIDTH - 30, 1)
leftScrollFrame:SetScrollChild(leftScrollChild)

-- ============================================================
-- Right panel: recipe list
-- ============================================================

local rightPanel = CreateFrame("Frame", nil, contentFrame, "BackdropTemplate")
rightPanel:SetPoint("TOPLEFT", leftPanel, "TOPRIGHT", 5, 0)
rightPanel:SetPoint("BOTTOMRIGHT", 0, 0)
rightPanel:SetBackdrop({
	bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileSize = 16,
	edgeSize = 12,
	insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
rightPanel:SetBackdropColor(0, 0, 0, 0.6)

local rightHeader = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
rightHeader:SetPoint("TOP", 0, -8)
rightHeader:SetText("")

local rightScrollFrame = CreateFrame("ScrollFrame", "GuildFoundToolsProfRightScroll", rightPanel, "UIPanelScrollFrameTemplate")
rightScrollFrame:SetPoint("TOPLEFT", 5, -25)
rightScrollFrame:SetPoint("BOTTOMRIGHT", -25, 5)

local rightScrollChild = CreateFrame("Frame", "GuildFoundToolsProfRightScrollChild", rightScrollFrame)
rightScrollChild:SetSize(200, 1)
rightScrollFrame:SetScrollChild(rightScrollChild)

-- Hint text when no recipes
local noRecipesText = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
noRecipesText:SetPoint("CENTER", 0, 0)
noRecipesText:SetText("Berufsfenster oeffnen\num Rezepte zu teilen")
noRecipesText:SetJustifyH("CENTER")
noRecipesText:Hide()

-- ============================================================
-- Left panel entry pool
-- ============================================================

local leftEntryPool = {}
local activeLeftEntries = {}

local function CreateLeftEntry(parent)
	local button = CreateFrame("Button", nil, parent)
	button:SetHeight(16)

	button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	button.text:SetPoint("LEFT", 0, 0)
	button.text:SetPoint("RIGHT", 0, 0)
	button.text:SetJustifyH("LEFT")

	button.highlight = button:CreateTexture(nil, "HIGHLIGHT")
	button.highlight:SetAllPoints()
	button.highlight:SetColorTexture(1, 1, 1, 0.1)

	button.selected = button:CreateTexture(nil, "BACKGROUND")
	button.selected:SetAllPoints()
	button.selected:SetColorTexture(0.3, 0.5, 0.8, 0.3)
	button.selected:Hide()

	return button
end

local function AcquireLeftEntry()
	local entry = table.remove(leftEntryPool)
	if not entry then
		entry = CreateLeftEntry(leftScrollChild)
	end
	entry:SetParent(leftScrollChild)
	entry:ClearAllPoints()
	entry:Show()
	return entry
end

local function ReleaseLeftEntries()
	for _, entry in ipairs(activeLeftEntries) do
		entry:Hide()
		entry.selected:Hide()
		table.insert(leftEntryPool, entry)
	end
	wipe(activeLeftEntries)
end

-- ============================================================
-- Right panel entry pool (recipe rows)
-- ============================================================

local rightEntryPool = {}
local activeRightEntries = {}

local function CreateRightEntry(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetHeight(16)

	frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.text:SetPoint("LEFT", 5, 0)
	frame.text:SetPoint("RIGHT", -5, 0)
	frame.text:SetJustifyH("LEFT")

	return frame
end

local function AcquireRightEntry()
	local entry = table.remove(rightEntryPool)
	if not entry then
		entry = CreateRightEntry(rightScrollChild)
	end
	entry:SetParent(rightScrollChild)
	entry:ClearAllPoints()
	entry:Show()
	return entry
end

local function ReleaseRightEntries()
	for _, entry in ipairs(activeRightEntries) do
		entry:Hide()
		table.insert(rightEntryPool, entry)
	end
	wipe(activeRightEntries)
end

-- ============================================================
-- Update right panel (recipe list)
-- ============================================================

local function UpdateRightPanel()
	ReleaseRightEntries()

	if not selectedMember or not selectedProfession then
		rightHeader:SetText("")
		noRecipesText:Hide()
		return
	end

	local memberData = GuildFoundTools.professions[selectedMember]
	if not memberData then
		rightHeader:SetText("")
		noRecipesText:Hide()
		return
	end

	local professionData = memberData[selectedProfession]
	if not professionData then
		rightHeader:SetText("")
		noRecipesText:Hide()
		return
	end

	rightHeader:SetText(selectedProfession .. " (" .. professionData.rank .. "/" .. professionData.maxRank .. ")")

	local recipes = professionData.recipes
	if not recipes or #recipes == 0 then
		noRecipesText:Show()
		noRecipesText:SetText("Berufsfenster oeffnen\num Rezepte zu teilen")
		return
	end

	noRecipesText:Hide()

	local yOffset = 0
	for _, itemId in ipairs(recipes) do
		local entry = AcquireRightEntry()
		entry:SetPoint("TOPLEFT", rightScrollChild, "TOPLEFT", 0, -yOffset)
		entry:SetPoint("RIGHT", rightScrollChild, "RIGHT", 0, 0)

		local itemName = GetItemInfo(itemId)
		if itemName then
			entry.text:SetText(itemName)
		else
			entry.text:SetText("Lade... (Item " .. itemId .. ")")
			-- Request item info
			pendingItemRequests[itemId] = true
		end

		table.insert(activeRightEntries, entry)
		yOffset = yOffset + 17
	end

	rightScrollChild:SetHeight(yOffset)
end

-- ============================================================
-- Update left panel (member + profession list)
-- ============================================================

local function UpdateLeftPanel()
	ReleaseLeftEntries()

	local professions = GuildFoundTools.professions
	local yOffset = 0

	-- Sort members alphabetically
	local members = {}
	for memberName in pairs(professions) do
		table.insert(members, memberName)
	end
	table.sort(members)

	for _, memberName in ipairs(members) do
		local memberData = professions[memberName]

		-- Member name header
		local memberEntry = AcquireLeftEntry()
		memberEntry:SetPoint("TOPLEFT", leftScrollChild, "TOPLEFT", 0, -yOffset)
		memberEntry:SetPoint("RIGHT", leftScrollChild, "RIGHT", 0, 0)
		memberEntry.text:SetText("|cffffd100" .. memberName .. "|r")
		memberEntry.text:SetPoint("LEFT", 2, 0)
		memberEntry:SetScript("OnClick", nil)
		memberEntry:Disable()
		table.insert(activeLeftEntries, memberEntry)
		yOffset = yOffset + 17

		-- Profession entries (indented)
		local professionNames = {}
		for professionName in pairs(memberData) do
			table.insert(professionNames, professionName)
		end
		table.sort(professionNames)

		for _, professionName in ipairs(professionNames) do
			local professionData = memberData[professionName]
			local professionEntry = AcquireLeftEntry()
			professionEntry:SetPoint("TOPLEFT", leftScrollChild, "TOPLEFT", 0, -yOffset)
			professionEntry:SetPoint("RIGHT", leftScrollChild, "RIGHT", 0, 0)
			professionEntry.text:SetPoint("LEFT", 15, 0)

			local levelText = professionData.rank .. "/" .. professionData.maxRank
			professionEntry.text:SetText(professionName .. " |cff888888(" .. levelText .. ")|r")

			-- Highlight selection
			if selectedMember == memberName and selectedProfession == professionName then
				professionEntry.selected:Show()
			end

			professionEntry:Enable()
			professionEntry:SetScript("OnClick", function()
				selectedMember = memberName
				selectedProfession = professionName
				UpdateLeftPanel()
				UpdateRightPanel()
			end)

			table.insert(activeLeftEntries, professionEntry)
			yOffset = yOffset + 17
		end

		yOffset = yOffset + 5 -- spacing between members
	end

	leftScrollChild:SetHeight(yOffset)
end

-- ============================================================
-- Public update function
-- ============================================================

function GuildFoundTools.UpdateProfessionsUI()
	if not contentFrame:IsShown() then return end
	UpdateLeftPanel()
	UpdateRightPanel()
end

-- ============================================================
-- Handle async item info loading
-- ============================================================

local itemInfoFrame = CreateFrame("Frame")
itemInfoFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
itemInfoFrame:SetScript("OnEvent", function(self, event, itemId, success)
	if pendingItemRequests[itemId] then
		pendingItemRequests[itemId] = nil
		-- Refresh right panel to update names
		if contentFrame:IsShown() then
			UpdateRightPanel()
		end
	end
end)

-- Update when tab is shown
contentFrame:SetScript("OnShow", function()
	UpdateLeftPanel()
	UpdateRightPanel()
end)
