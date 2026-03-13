-- Professions tab

ClassicGuildTools.Professions = ClassicGuildTools.Professions or {}

local L = LibStub("AceLocale-3.0"):GetLocale("ClassicGuildTools")
local MESSAGE_TYPE = ClassicGuildTools.MESSAGE_TYPE
local SendGuildMessage = ClassicGuildTools.SendGuildMessage
local SendWhisperMessage = ClassicGuildTools.SendWhisperMessage

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
local PROFESSION_ID_TO_LOCALE_KEY = {
	[171] = "ProfessionAlchemy",
	[164] = "ProfessionBlacksmithing",
	[333] = "ProfessionEnchanting",
	[202] = "ProfessionEngineering",
	[165] = "ProfessionLeatherworking",
	[197] = "ProfessionTailoring",
	[185] = "ProfessionCooking",
	[129] = "ProfessionFirstAid",
	[755] = "ProfessionJewelcrafting",
	[773] = "ProfessionInscription",
}

local SORTED_PROFESSION_IDS = { 171, 164, 333, 202, 165, 197, 185, 129 }

if not ClassicGuildTools.Utils.isEra then
	table.insert(SORTED_PROFESSION_IDS, 755) -- Jewelcrafting
	table.insert(SORTED_PROFESSION_IDS, 773) -- Inscription
end

local PROFESSION_ID_TO_ICON = {
	[171] = "Interface\\Icons\\Trade_Alchemy",
	[164] = "Interface\\Icons\\Trade_BlackSmithing",
	[333] = "Interface\\Icons\\Trade_Engraving",
	[202] = "Interface\\Icons\\Trade_Engineering",
	[165] = "Interface\\Icons\\Trade_LeatherWorking",
	[197] = "Interface\\Icons\\Trade_Tailoring",
	[185] = "Interface\\Icons\\INV_Misc_Food_15",
	[129] = "Interface\\Icons\\Spell_Holy_SealOfSacrifice",
	[755] = "Interface\\Icons\\INV_Misc_Gem_01",
	[773] = "Interface\\Icons\\INV_Inscription_Tradeskill01",
}
local ROW_HEIGHT = 20
local ROW_SPACING = 2

local selectedProfessionId = nil
local searchText = ""
local recipeCache = {}

-- ============================================================
-- Data access helpers
-- ============================================================

local function GetGuildData(guildName)
	ClassicGuildToolsProfessions = ClassicGuildToolsProfessions or {}
	ClassicGuildToolsProfessions[guildName] = ClassicGuildToolsProfessions[guildName] or {}

	return ClassicGuildToolsProfessions[guildName]
end

local function GetCurrentGuildData()
	local guildName = GetGuildInfo("player")
	if not guildName then return nil end

	local guildKey = guildName .. "-" .. GetRealmName()

	return GetGuildData(guildKey)
end

local function GetPlayerRecipes()
	local guildData = GetCurrentGuildData()
	if not guildData then return {} end

	local guid = UnitGUID("player")
	guildData[guid] = guildData[guid] or {}
	return guildData[guid]
end

local function BroadcastPlayerProfessions(target, filterProfessionId)
	local guildData = GetCurrentGuildData()
	if not guildData then return end

	local guid = UnitGUID("player")
	local professions = guildData[guid]
	if not professions then return end

	for professionId, professionData in pairs(professions) do
		if not filterProfessionId or professionId == filterProfessionId then
			local payload = {
				guid = guid,
				professionId = professionId,
				recipes = professionData.recipes or {},
				rank = professionData.rank or 0,
				maxRank = professionData.maxRank or 0,
			}

			if target then
				SendWhisperMessage(MESSAGE_TYPE.PROFESSION_ANSWER, target, payload)
			else
				SendGuildMessage(MESSAGE_TYPE.PROFESSION_ANSWER, payload)
			end
		end
	end
end

local function RebuildRecipeCache()
	wipe(recipeCache)

	local guildData = GetCurrentGuildData()
	if not guildData then return end

	for guid, professions in pairs(guildData) do
		local _, _, _, _, _, playerName = GetPlayerInfoByGUID(guid)
		if playerName then
			for professionId, professionData in pairs(professions) do
				for _, itemId in ipairs(professionData.recipes or {}) do
					if itemId and itemId > 0 then
						if not recipeCache[itemId] then
							recipeCache[itemId] = { professionId = professionId, players = {} }
						end
						recipeCache[itemId].players[playerName] = true
					end
				end
			end
		end
	end
end

-- ============================================================
-- Profession scanning
-- ============================================================

function ClassicGuildTools.Professions.ScanProfessions()
	if not GetNumSkillLines then return end

	local playerRecipes = GetPlayerRecipes()

	for index = 1, GetNumSkillLines() do
		local skillName, isHeader, _, skillRank, _, _, skillMaxRank = GetSkillLineInfo(index)
		if skillName and not isHeader and PROFESSION_NAME_TO_ID[skillName] then
			local professionId = PROFESSION_NAME_TO_ID[skillName]
			playerRecipes[professionId] = playerRecipes[professionId] or {}
			playerRecipes[professionId].rank = skillRank or 0
			playerRecipes[professionId].maxRank = skillMaxRank or 0
		end
	end
end

local function ScanCurrentTradeSkill()
	if not GetTradeSkillLine or not GetNumTradeSkills then return end

	local tradeSkillName = GetTradeSkillLine()
	if not tradeSkillName or tradeSkillName == "UNKNOWN" then return end

	local professionId = PROFESSION_NAME_TO_ID[tradeSkillName]
	if not professionId then return end

	local recipeItemIds = {}
	for index = 1, GetNumTradeSkills() do
		local recipeName, recipeType = GetTradeSkillInfo(index)
		if recipeName and recipeType ~= "header" then
			local itemLink = GetTradeSkillItemLink(index)
			if itemLink then
				table.insert(recipeItemIds, tonumber(itemLink:match("item:(%d+)")) or 0)
			end
		end
	end

	local playerRecipes = GetPlayerRecipes()
	playerRecipes[professionId] = playerRecipes[professionId] or {}
	playerRecipes[professionId].recipes = recipeItemIds

	BroadcastPlayerProfessions(nil, professionId)
end

function ClassicGuildTools.Professions.GetScannedRecipes()
	return GetPlayerRecipes()
end

-- ============================================================
-- Professions UI
-- ============================================================

local contentFrame = ClassicGuildTools.UI.GetContentFrame(3)
contentFrame:SetScript("OnShow", function()
	ClassicGuildTools.UI.UpdateProfessionsUI()
end)

local function CollectRecipeData()
	local guildData = GetCurrentGuildData()
	if not guildData then return {} end

	local recipeMap = {}
	local myName = ClassicGuildTools.GetPlayerName()

	for guid, professions in pairs(guildData) do
		local _, _, _, _, _, playerName = GetPlayerInfoByGUID(guid)
		if playerName then
			local isself = playerName == myName
			local memberInfo = ClassicGuildTools.guildMemberCache[playerName]
			local isOnline = isself or (memberInfo and memberInfo.online)

			for professionId, professionData in pairs(professions) do
				if not selectedProfessionId or professionId == selectedProfessionId then
					for _, itemId in ipairs(professionData.recipes or {}) do
						if itemId and itemId > 0 then
							if not recipeMap[itemId] then
								recipeMap[itemId] = { players = {} }
							end
							table.insert(recipeMap[itemId].players, {
								name = playerName,
								isSelf = isself,
								isOnline = isOnline,
							})
						end
					end
				end
			end
		end
	end

	for _, data in pairs(recipeMap) do
		table.sort(data.players, function(a, b)
			if a.isSelf ~= b.isSelf then return a.isSelf end
			if a.isOnline ~= b.isOnline then return a.isOnline end
			return a.name < b.name
		end)
	end

	return recipeMap
end

local function CreateRecipeRow(parent)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(ROW_HEIGHT)
	row:EnableMouse(true)

	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(ROW_HEIGHT, ROW_HEIGHT)
	row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)

	row.itemName = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.itemName:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
	row.itemName:SetJustifyH("LEFT")

	row.players = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	row.players:SetPoint("RIGHT", row, "RIGHT", -4, 0)
	row.players:SetPoint("LEFT", row, "CENTER", -120, 0)
	row.players:SetJustifyH("LEFT")
	row.players:SetWordWrap(false)

	row.background = row:CreateTexture(nil, "BACKGROUND")
	row.background:SetAllPoints()
	row.background:SetColorTexture(1, 1, 1, 0.03)

	row:SetScript("OnEnter", function(self)
		if self.itemId then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetItemByID(self.itemId)
			GameTooltip:Show()
		end
	end)

	row:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	return row
end

-- Search box
local searchBox = CreateFrame("EditBox", nil, contentFrame, "InputBoxTemplate")
searchBox:SetSize(100, 20)
searchBox:SetAutoFocus(false)
searchBox:SetFontObject(ChatFontNormal)

local searchPlaceholder = searchBox:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
searchPlaceholder:SetPoint("LEFT", searchBox, "LEFT", 6, 0)
searchPlaceholder:SetText(L["SearchPlaceholder"])

searchBox:SetScript("OnEditFocusGained", function()
	searchPlaceholder:Hide()
end)

searchBox:SetScript("OnEditFocusLost", function(self)
	if self:GetText() == "" then
		searchPlaceholder:Show()
	end
end)

searchBox:SetScript("OnTextChanged", function(self)
	searchText = self:GetText():lower()
	if searchText == "" then
		searchPlaceholder:Show()
	else
		searchPlaceholder:Hide()
	end
	ClassicGuildTools.UI.UpdateProfessionsUI()
end)

searchBox:SetScript("OnEscapePressed", function(self)
	self:ClearFocus()
end)

searchBox:SetScript("OnEnterPressed", function(self)
	self:ClearFocus()
end)

-- Profession dropdown
local professionDropdown = CreateFrame("Frame", "ClassicGuildToolsProfessionDropdown", contentFrame, "UIDropDownMenuTemplate")
professionDropdown:SetPoint("TOPRIGHT", contentFrame, "TOPRIGHT", 0, 2)
UIDropDownMenu_SetWidth(professionDropdown, 150)
UIDropDownMenu_SetText(professionDropdown, L["AllProfessions"])

local function UpdateDropdownDisplay(professionId)
	if professionId then
		local localeKey = PROFESSION_ID_TO_LOCALE_KEY[professionId]
		local icon = PROFESSION_ID_TO_ICON[professionId]
		UIDropDownMenu_SetText(professionDropdown, L[localeKey] .. " |T" .. icon .. ":16|t")
	else
		UIDropDownMenu_SetText(professionDropdown, L["AllProfessions"])
	end
end

searchBox:SetPoint("LEFT", contentFrame, "LEFT", 6, 0)
searchBox:SetPoint("RIGHT", professionDropdown, "LEFT", -10, 0)
searchBox:SetPoint("BOTTOM", professionDropdown, "BOTTOM", 0, 8)

UIDropDownMenu_Initialize(professionDropdown, function()
	local info = UIDropDownMenu_CreateInfo()
	info.text = L["AllProfessions"]
	info.checked = selectedProfessionId == nil
	info.func = function()
		selectedProfessionId = nil
		UpdateDropdownDisplay(nil)
		ClassicGuildTools.UI.UpdateProfessionsUI()
	end
	UIDropDownMenu_AddButton(info)

	for _, professionId in ipairs(SORTED_PROFESSION_IDS) do
		local localeKey = PROFESSION_ID_TO_LOCALE_KEY[professionId]
		if localeKey then
			info = UIDropDownMenu_CreateInfo()
			info.text = L[localeKey]
			info.icon = PROFESSION_ID_TO_ICON[professionId]
			info.checked = (selectedProfessionId == professionId)
			info.func = function()
				selectedProfessionId = professionId
				UpdateDropdownDisplay(professionId)
				ClassicGuildTools.UI.UpdateProfessionsUI()
			end
			UIDropDownMenu_AddButton(info)
		end
	end
end)

-- Scroll frame
local scrollFrame = CreateFrame("ScrollFrame", nil, contentFrame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -48)
scrollFrame:SetPoint("BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", -22, 0)

-- Column headers (anchored to scrollFrame so they align with row columns)
local headerItem = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
headerItem:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 4, -32)
headerItem:SetText(L["ColumnItem"])

local headerPlayers = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
headerPlayers:SetPoint("LEFT", scrollFrame, "CENTER", -120, 0)
headerPlayers:SetPoint("TOP", headerItem, "TOP", 0, 0)
headerPlayers:SetText(L["ColumnPlayers"])

local scrollChild = CreateFrame("Frame", nil, scrollFrame)
scrollChild:SetWidth(scrollFrame:GetWidth())
scrollChild:SetHeight(1)
scrollFrame:SetScrollChild(scrollChild)

scrollFrame:SetScript("OnSizeChanged", function(self)
	scrollChild:SetWidth(self:GetWidth())
end)

-- No results text
local noResultsText = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
noResultsText:SetPoint("CENTER", scrollFrame, "CENTER", 0, 0)
noResultsText:SetText(L["NoRecipesFound"])
noResultsText:Hide()

-- Row pool
local rowPool = ClassicGuildTools.Utils.CreatePool(scrollChild, CreateRecipeRow)

function ClassicGuildTools.UI.UpdateProfessionsUI()
	rowPool:ReleaseAll()

	local recipeMap = CollectRecipeData()
	local recipeList = {}

	for itemId, data in pairs(recipeMap) do
		local itemName, itemLink, _, _, _, _, _, _, _, itemTexture = GetItemInfo(itemId)
		if itemName and itemLink then
			if searchText == "" or itemName:lower():find(searchText, 1, true) then
				table.insert(recipeList, {
					itemId = itemId,
					itemName = itemName,
					itemLink = itemLink,
					itemTexture = itemTexture,
					players = data.players,
				})
			end
		end
	end

	table.sort(recipeList, function(a, b)
		return a.itemName < b.itemName
	end)

	if #recipeList == 0 then
		noResultsText:Show()
	else
		noResultsText:Hide()
	end

	for index, recipe in ipairs(recipeList) do
		local row = rowPool:Acquire()
		row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -((index - 1) * (ROW_HEIGHT + ROW_SPACING)))
		row:SetPoint("RIGHT", scrollChild, "RIGHT", 0, 0)

		row.itemId = recipe.itemId
		row.icon:SetTexture(recipe.itemTexture)
		row.itemName:SetText(recipe.itemLink)

		local availableWidth = row.players:GetWidth()
		local playerText = ""
		local truncated = false

		for partIndex, player in ipairs(recipe.players) do
			local color = player.isSelf and "|cff00ff00" or player.isOnline and "|cffffffff" or "|cff808080"
			local name = player.isSelf and L["You"] or player.name
			local testText = playerText

			if testText ~= "" then testText = testText .. ", " end
			testText = testText .. color .. name

			if availableWidth and availableWidth > 0 and partIndex > 1 then
				row.players:SetText(testText)
				if row.players:GetStringWidth() > availableWidth then
					truncated = true
					break
				end
			end

			playerText = testText
		end

		if truncated then
			playerText = playerText .. ", ..."
		end

		row.players:SetText(playerText)

		if index % 2 == 0 then
			row.background:SetColorTexture(1, 1, 1, 0.05)
		else
			row.background:SetColorTexture(0, 0, 0, 0)
		end
	end

	scrollChild:SetHeight(math.max(1, #recipeList * (ROW_HEIGHT + ROW_SPACING)))
end

-- ============================================================
-- Profession message handlers
-- ============================================================

ClassicGuildTools.MessageHandlers.PROFESSION_QUERY = function(data, sender)
	if sender == ClassicGuildTools.GetPlayerName() then return end
	BroadcastPlayerProfessions(sender)
end

ClassicGuildTools.MessageHandlers.PROFESSION_ANSWER = function(data, sender)
	if not data or not data.guid or not data.professionId then return end

	local guildData = GetCurrentGuildData()
	if not guildData then return end

	guildData[data.guid] = guildData[data.guid] or {}
	guildData[data.guid][data.professionId] = guildData[data.guid][data.professionId] or {}
	guildData[data.guid][data.professionId].recipes = data.recipes or {}
	guildData[data.guid][data.professionId].rank = data.rank or 0
	guildData[data.guid][data.professionId].maxRank = data.maxRank or 0

	ClassicGuildTools.Utils.Debounce("RebuildRecipeCache", 1, RebuildRecipeCache)
end

-- ============================================================
-- Tooltip hook
-- ============================================================

GameTooltip:HookScript("OnTooltipSetItem", function(self)
	local _, itemLink = self:GetItem()
	if not itemLink then return end

	local itemId = tonumber(itemLink:match("item:(%d+)"))
	if not itemId then return end

	local cached = recipeCache[itemId]
	if not cached then return end

	local myName = ClassicGuildTools.GetPlayerName()
	local playerParts = {}
	local sortedNames = {}
	for playerName in pairs(cached.players) do
		table.insert(sortedNames, playerName)
	end
	table.sort(sortedNames, function(a, b)
		if a == myName then return true end
		if b == myName then return false end
		return a < b
	end)

	for _, playerName in ipairs(sortedNames) do
		if playerName == myName then
			table.insert(playerParts, "|cff00ff00" .. L["You"] .. "|r")
		else
			table.insert(playerParts, playerName)
		end
	end

	local localeKey = PROFESSION_ID_TO_LOCALE_KEY[cached.professionId]
	local icon = PROFESSION_ID_TO_ICON[cached.professionId]

	self:AddLine(" ")
	if localeKey and icon then
		self:AddLine("|T" .. icon .. ":14|t " .. L[localeKey] .. " (" .. L["AddonTitle"] .. ")")
	end
	self:AddLine(table.concat(playerParts, ", "), 1, 1, 1, true)
	self:Show()
end)

-- ============================================================
-- Event handlers
-- ============================================================

-- Register profession event handlers
local function OnTradeSkillUpdate()
	ClassicGuildTools.Utils.Debounce("TradeSkillUpdate", 1, ScanCurrentTradeSkill)
end

ClassicGuildTools.EventHandlers.PLAYER_LOGIN = function()
	ClassicGuildTools.Professions.ScanProfessions()
	RebuildRecipeCache()
	SendGuildMessage(MESSAGE_TYPE.PROFESSION_QUERY)
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
