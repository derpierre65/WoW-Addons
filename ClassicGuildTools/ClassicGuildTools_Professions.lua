-- Professions tab: logic + UI for querying guild professions and recipes

-- ============================================================
-- Profession Logic
-- ============================================================

ClassicGuildTools.Professions = ClassicGuildTools.Professions or {}

local L = LibStub("AceLocale-3.0"):GetLocale("ClassicGuildTools")
local MESSAGE_TYPE = ClassicGuildTools.MESSAGE_TYPE
local SendGuildMessage = ClassicGuildTools.SendGuildMessage

-- ============================================================
-- Profession scanning (Classic: GetNumSkillLines/GetSkillLineInfo)
-- ============================================================

local PROFESSION_NAME_TO_ID = {
	["Alchemy"] = 171, ["Alchimie"] = 171,
	["Blacksmithing"] = 164, ["Schmiedekunst"] = 164,
	["Enchanting"] = 333, ["Verzauberkunst"] = 333, ["Verzaubern"] = 333,
	["Engineering"] = 202, ["Ingenieurskunst"] = 202,
	["Herbalism"] = 182, ["Kraeuterkunde"] = 182,
	["Leatherworking"] = 165, ["Lederverarbeitung"] = 165,
	["Mining"] = 186, ["Bergbau"] = 186,
	["Skinning"] = 393, ["Kuerschnerei"] = 393,
	["Tailoring"] = 197, ["Schneiderei"] = 197,
	["Cooking"] = 185, ["Kochkunst"] = 185,
	["First Aid"] = 129, ["Erste Hilfe"] = 129,
	["Fishing"] = 356, ["Angeln"] = 356,
	["Jewelcrafting"] = 755, ["Juwelenschleifen"] = 755,
	["Inscription"] = 773, ["Inschriftenkunde"] = 773,
}

function ClassicGuildTools.Professions.ScanProfessions()
	local result = {}

	if not GetNumSkillLines then return result end

	for index = 1, GetNumSkillLines() do
		local skillName, isHeader, _, skillRank, _, _, skillMaxRank = GetSkillLineInfo(index)
		if skillName and not isHeader and PROFESSION_NAME_TO_ID[skillName] then
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

local function GetPlayerRecipes()
	ClassicGuildToolsProfessions = ClassicGuildToolsProfessions or {}
	local guid = UnitGUID("player")
	ClassicGuildToolsProfessions[guid] = ClassicGuildToolsProfessions[guid] or {}
	return ClassicGuildToolsProfessions[guid]
end

local function ScanCurrentTradeSkill()
	if not GetTradeSkillLine or not GetNumTradeSkills then return end

	local tradeSkillName = GetTradeSkillLine()
	if not tradeSkillName or tradeSkillName == "UNKNOWN" then return end

	local professionId = PROFESSION_NAME_TO_ID[tradeSkillName]
	if not professionId then return end

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
			})
		end
	end

	local playerRecipes = GetPlayerRecipes()
	playerRecipes[professionId] = recipes
end

function ClassicGuildTools.Professions.GetScannedRecipes()
	return GetPlayerRecipes()
end

-- ============================================================
-- Profession query API
-- ============================================================

function ClassicGuildTools.Professions.RequestProfessions()
	if not IsInGuild() then
		print("|cff00ccffClassic Guild Tools:|r " .. L["NotInGuild"])
		return
	end

	-- Clear old data
	wipe(ClassicGuildTools.professions)

	SendGuildMessage(MESSAGE_TYPE.PROFESSION_QUERY)

	if ClassicGuildTools.UI and ClassicGuildTools.UI.UpdateProfessionsUI then
		ClassicGuildTools.UI.UpdateProfessionsUI()
	end
end

-- ============================================================
-- Profession message handlers
-- ============================================================

ClassicGuildTools.MessageHandlers.PROFESSION_QUERY = function(data, sender)
	-- Someone is requesting professions; respond with ours
	local myProfessions = ClassicGuildTools.Professions.ScanProfessions()

	for _, profession in ipairs(myProfessions) do
		local recipes = scannedRecipes[profession.name]
		local recipeItemIds = {}
		if recipes and #recipes > 0 then
			for _, recipe in ipairs(recipes) do
				table.insert(recipeItemIds, recipe.itemId)
			end
		end

		SendGuildMessage(MESSAGE_TYPE.PROFESSION_ANSWER, {
			name = profession.name,
			rank = profession.rank,
			maxRank = profession.maxRank,
			recipes = recipeItemIds,
		})
	end
end

ClassicGuildTools.MessageHandlers.PROFESSION_ANSWER = function(data, sender)
	if not data or not data.name then return end

	ClassicGuildTools.professions[sender] = ClassicGuildTools.professions[sender] or {}

	ClassicGuildTools.professions[sender][data.name] = {
		rank = data.rank or 0,
		maxRank = data.maxRank or 0,
		recipes = data.recipes or {},
	}

	if ClassicGuildTools.UI and ClassicGuildTools.UI.UpdateProfessionsUI then
		ClassicGuildTools.UI.UpdateProfessionsUI()
	end
end

-- Register profession event handlers
local function OnTradeSkillUpdate()
	ClassicGuildTools.Utils.Debounce("TradeSkillUpdate", 1, ScanCurrentTradeSkill)
end

ClassicGuildTools.EventHandlers.TRADE_SKILL_SHOW = function()
	OnTradeSkillUpdate()
	ClassicGuildTools.EventHandlers.TRADE_SKILL_UPDATE = OnTradeSkillUpdate
	ClassicGuildTools.EventHandlers.CRAFT_UPDATE = OnTradeSkillUpdate
end

ClassicGuildTools.EventHandlers.TRADE_SKILL_CLOSE = function()
	ClassicGuildTools.UnregisterEventHandler("TRADE_SKILL_UPDATE", OnTradeSkillUpdate)
	ClassicGuildTools.UnregisterEventHandler("CRAFT_UPDATE", OnTradeSkillUpdate)
	ScanCurrentTradeSkill()
end

-- ============================================================
-- Professions UI
-- ============================================================

local contentFrame = ClassicGuildTools.UI.GetContentFrame(3)

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
queryButton:SetText(L["ButtonQueryProfessions"])

local statusText = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
statusText:SetPoint("LEFT", queryButton, "RIGHT", 10, 0)
statusText:SetText("")

queryButton:SetScript("OnClick", function()
	statusText:SetText(L["QuerySent"])
	ClassicGuildTools.Professions.RequestProfessions()
	C_Timer.After(5, function()
		local count = 0
		for _ in pairs(ClassicGuildTools.professions) do
			count = count + 1
		end
		statusText:SetText(string.format(L["ResponsesReceived"], count))
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

local leftScrollFrame = CreateFrame("ScrollFrame", "ClassicGuildToolsProfLeftScroll", leftPanel, "UIPanelScrollFrameTemplate")
leftScrollFrame:SetPoint("TOPLEFT", 5, -5)
leftScrollFrame:SetPoint("BOTTOMRIGHT", -25, 5)

local leftScrollChild = CreateFrame("Frame", "ClassicGuildToolsProfLeftScrollChild", leftScrollFrame)
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

local rightScrollFrame = CreateFrame("ScrollFrame", "ClassicGuildToolsProfRightScroll", rightPanel, "UIPanelScrollFrameTemplate")
rightScrollFrame:SetPoint("TOPLEFT", 5, -25)
rightScrollFrame:SetPoint("BOTTOMRIGHT", -25, 5)

local rightScrollChild = CreateFrame("Frame", "ClassicGuildToolsProfRightScrollChild", rightScrollFrame)
rightScrollChild:SetSize(200, 1)
rightScrollFrame:SetScrollChild(rightScrollChild)

-- Hint text when no recipes
local noRecipesText = rightPanel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
noRecipesText:SetPoint("CENTER", 0, 0)
noRecipesText:SetText(L["OpenProfessionWindow"])
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

	local memberData = ClassicGuildTools.professions[selectedMember]
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
		noRecipesText:SetText(L["OpenProfessionWindow"])
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
			entry.text:SetText(string.format(L["LoadingItem"], itemId))
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

	local professions = ClassicGuildTools.professions
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

function ClassicGuildTools.UI.UpdateProfessionsUI()
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
