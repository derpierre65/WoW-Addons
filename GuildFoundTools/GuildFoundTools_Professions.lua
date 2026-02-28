-- Professions tab: logic + UI for querying guild professions and recipes

-- ============================================================
-- Profession Logic
-- ============================================================

GuildFoundTools.Professions = GuildFoundTools.Professions or {}

local MESSAGE_TYPES = GuildFoundTools.MESSAGE_TYPES
local Serialize = GuildFoundTools.Serialize
local SendGuildMessage = GuildFoundTools.SendGuildMessage

-- ============================================================
-- Profession scanning (Classic: GetNumSkillLines/GetSkillLineInfo)
-- ============================================================

local KNOWN_PROFESSIONS = {
	["Alchemy"] = true, ["Alchimie"] = true,
	["Blacksmithing"] = true, ["Schmiedekunst"] = true,
	["Enchanting"] = true, ["Verzauberkunst"] = true,
	["Engineering"] = true, ["Ingenieurskunst"] = true,
	["Herbalism"] = true, ["Kraeuterkunde"] = true,
	["Leatherworking"] = true, ["Lederverarbeitung"] = true,
	["Mining"] = true, ["Bergbau"] = true,
	["Skinning"] = true, ["Kuerschnerei"] = true,
	["Tailoring"] = true, ["Schneiderei"] = true,
	["Cooking"] = true, ["Kochkunst"] = true,
	["First Aid"] = true, ["Erste Hilfe"] = true,
	["Fishing"] = true, ["Angeln"] = true,
	["Jewelcrafting"] = true, ["Juwelenschleifen"] = true,
	["Inscription"] = true, ["Inschriftenkunde"] = true,
}

function GuildFoundTools.Professions.ScanProfessions()
	local result = {}

	if not GetNumSkillLines then return result end

	for index = 1, GetNumSkillLines() do
		local skillName, isHeader, _, skillRank, _, _, skillMaxRank = GetSkillLineInfo(index)
		if skillName and not isHeader and KNOWN_PROFESSIONS[skillName] then
			table.insert(result, {
				name = skillName,
				rank = skillRank or 0,
				maxRank = skillMaxRank or 0,
			})
		end
	end

	return result
end

-- ============================================================
-- Recipe scanning (when tradeskill window is open)
-- ============================================================

local scannedRecipes = {} -- [professionName] = { { itemId = number, name = string }, ... }

local function ScanCurrentTradeSkill()
	if not GetTradeSkillLine or not GetNumTradeSkills then return end

	local tradeSkillName = GetTradeSkillLine()
	if not tradeSkillName or tradeSkillName == "UNKNOWN" then return end

	local recipes = {}
	for index = 1, GetNumTradeSkills() do
		local recipeName, recipeType = GetTradeSkillInfo(index)
		if recipeName and recipeType ~= "header" then
			local itemLink = GetTradeSkillItemLink(index)
			local itemId = 0
			if itemLink then
				itemId = tonumber(itemLink:match("item:(%d+)")) or 0
			end
			table.insert(recipes, {
				itemId = itemId,
				name = recipeName,
			})
		end
	end

	scannedRecipes[tradeSkillName] = recipes
end

function GuildFoundTools.Professions.GetScannedRecipes()
	return scannedRecipes
end

-- ============================================================
-- Profession query API
-- ============================================================

function GuildFoundTools.Professions.RequestProfessions()
	if not IsInGuild() then
		print("|cff00ccffGuildFound Tools:|r Du bist in keiner Gilde.")
		return
	end

	-- Clear old data
	wipe(GuildFoundTools.professions)

	local message = Serialize(MESSAGE_TYPES.PROFESSION_QUERY)
	SendGuildMessage(message)

	if GuildFoundTools.UI and GuildFoundTools.UI.UpdateProfessionsUI then
		GuildFoundTools.UI.UpdateProfessionsUI()
	end
end

-- ============================================================
-- Profession message handlers
-- ============================================================

GuildFoundTools.MessageHandlers.PROFESSION_QUERY = function(fields, sender)
	-- Someone is requesting professions; respond with ours
	local myProfessions = GuildFoundTools.Professions.ScanProfessions()

	for _, profession in ipairs(myProfessions) do
		local recipes = scannedRecipes[profession.name]
		local itemIdsString = ""
		if recipes and #recipes > 0 then
			local itemIds = {}
			for _, recipe in ipairs(recipes) do
				table.insert(itemIds, recipe.itemId)
			end
			itemIdsString = table.concat(itemIds, ",")
		end

		SendGuildMessage(Serialize(MESSAGE_TYPES.PROFESSION_ANSWER, profession.name, profession.rank, profession.maxRank, itemIdsString))
	end
end

GuildFoundTools.MessageHandlers.PROFESSION_ANSWER = function(fields, sender)
	-- PA profName rank maxRank itemIds
	local professionName = fields[2]
	local rank = tonumber(fields[3]) or 0
	local maxRank = tonumber(fields[4]) or 0
	local itemIdsString = fields[5] or ""

	if not professionName then return end

	GuildFoundTools.professions[sender] = GuildFoundTools.professions[sender] or {}

	local recipes = {}
	if itemIdsString ~= "" then
		for itemId in itemIdsString:gmatch("[^,]+") do
			local id = tonumber(itemId)
			if id and id > 0 then
				table.insert(recipes, id)
			end
		end
	end

	GuildFoundTools.professions[sender][professionName] = {
		rank = rank,
		maxRank = maxRank,
		recipes = recipes,
	}

	if GuildFoundTools.UI and GuildFoundTools.UI.UpdateProfessionsUI then
		GuildFoundTools.UI.UpdateProfessionsUI()
	end
end

-- Register profession event handlers
GuildFoundTools.EventHandlers.TRADE_SKILL_SHOW = function()
	ScanCurrentTradeSkill()
end

GuildFoundTools.EventHandlers.TRADE_SKILL_CLOSE = function()
	ScanCurrentTradeSkill()
end

-- ============================================================
-- Professions UI
-- ============================================================

local contentFrame = GuildFoundTools.UI.GetContentFrame(3)

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
	GuildFoundTools.Professions.RequestProfessions()
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
noRecipesText:SetText("Berufsfenster öffnen\num Rezepte zu teilen")
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
		noRecipesText:SetText("Berufsfenster öffnen\num Rezepte zu teilen")
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

function GuildFoundTools.UI.UpdateProfessionsUI()
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
