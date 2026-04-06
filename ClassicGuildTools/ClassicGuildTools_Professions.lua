-- Professions tab

ClassicGuildTools.Professions = ClassicGuildTools.Professions or {}

local L = LibStub("AceLocale-3.0"):GetLocale("ClassicGuildTools")
local MESSAGE_TYPE = ClassicGuildTools.MESSAGE_TYPE
local SendGuildMessage = ClassicGuildTools.SendGuildMessage
local SendWhisperMessage = ClassicGuildTools.SendWhisperMessage

-- Map spell IDs to profession IDs, then build localized name lookup via GetSpellInfo
local PROFESSION_SPELL_IDS = {
	-- classic
	[2259] = 171,   -- Alchemy
	[2018] = 164,   -- Blacksmithing
	[7411] = 333,   -- Enchanting
	[4036] = 202,   -- Engineering
	[2366] = 182,   -- Herbalism
	[2108] = 165,   -- Leatherworking
	[2575] = 186,   -- Mining
	[8613] = 393,   -- Skinning
	[3908] = 197,   -- Tailoring
	[2550] = 185,   -- Cooking
	[3273] = 129,   -- First Aid
	[7620] = 356,   -- Fishing
	-- tbc
	[25229] = 755,  -- Jewelcrafting
	[45357] = 773,  -- Inscription
}

local PROFESSIONS = {}
for spellId, professionId in pairs(PROFESSION_SPELL_IDS) do
	local spellName = GetSpellInfo(spellId)
	if spellName then
		PROFESSIONS[spellName] = professionId
	end
end

local PROFESSION_LOCALE_KEYS = {
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
	[182] = "ProfessionHerbalism",
	[186] = "ProfessionMining",
	[393] = "ProfessionSkinning",
}

local SORTED_PROFESSION_IDS = { 171, 164, 333, 202, 165, 197, 182, 186, 393, 185, 129 }

if not ClassicGuildTools.Utils.isEra then
	table.insert(SORTED_PROFESSION_IDS, 755) -- Jewelcrafting
	table.insert(SORTED_PROFESSION_IDS, 773) -- Inscription
end

local PROFESSION_ICONS = {
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
	[182] = "Interface\\Icons\\Trade_Herbalism",
	[186] = "Interface\\Icons\\Trade_Mining",
	[393] = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01",
}

local GATHERING_PROFESSIONS = {
	[182] = true, -- Herbalism
	[186] = true, -- Mining
	[393] = true, -- Skinning
}
local ROW_HEIGHT = 20
local ROW_SPACING = 2

local selectedProfessionId = nil
local searchText = ""
local recipeCache = {}

-- ============================================================
-- Data access helpers
-- ============================================================

local function GetItemIdFromLink(itemLink)
	if not itemLink then return nil end
	return tonumber(itemLink:match("item:(%d+)"))
end

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

	ClassicGuildTools.BuildGuildMemberCache()

	local myName = ClassicGuildTools.GetPlayerName()

	for guid, professions in pairs(guildData) do
		local _, _, _, _, _, playerName = GetPlayerInfoByGUID(guid)
		if playerName then
			for professionId, professionData in pairs(professions) do
				for _, recipeId in ipairs(professionData.recipes or {}) do
					if recipeId and recipeId ~= 0 then
						if not recipeCache[recipeId] then
							recipeCache[recipeId] = { professionId = professionId, players = {} }
						end
						table.insert(recipeCache[recipeId].players, {
							name = playerName,
							isSelf = playerName == myName,
							isOnline = playerName == myName or (ClassicGuildTools.guildMemberCache[playerName] and ClassicGuildTools.guildMemberCache[playerName].online),
							rank = professionData.rank or 0,
						})
					end
				end
			end
		end
	end

	for _, cached in pairs(recipeCache) do
		table.sort(cached.players, function(playerA, playerB)
			if playerA.isSelf ~= playerB.isSelf then return playerA.isSelf end
			if playerA.isOnline ~= playerB.isOnline then return playerA.isOnline end

			return playerA.rank > playerB.rank
		end)
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
		if skillName and not isHeader and PROFESSIONS[skillName] then
			local professionId = PROFESSIONS[skillName]
			playerRecipes[professionId] = playerRecipes[professionId] or {}
			playerRecipes[professionId].rank = skillRank or 0
			playerRecipes[professionId].maxRank = skillMaxRank or 0
			if GATHERING_PROFESSIONS[professionId] then
				playerRecipes[professionId].recipes = { professionId }
			end
		end
	end
end

local function ScanCurrentTradeSkill()
	local tradeSkillName = "UNKNOWN"
	local recipeCount = 0
	local useCraftApi = false

	-- Try TradeSkill API first, fall back to Craft API
	if GetTradeSkillLine and GetNumTradeSkills then
		tradeSkillName = GetTradeSkillLine()
		if tradeSkillName and tradeSkillName ~= "UNKNOWN" then
			recipeCount = GetNumTradeSkills()
		end
	end

	if (not tradeSkillName or tradeSkillName == "UNKNOWN") and GetCraftDisplaySkillLine and GetNumCrafts then
		tradeSkillName = GetCraftDisplaySkillLine()
		if tradeSkillName and tradeSkillName ~= "UNKNOWN" then
			recipeCount = GetNumCrafts()
			useCraftApi = true
		end
	end

	if not tradeSkillName or tradeSkillName == "UNKNOWN" then return end

	local professionId = PROFESSIONS[tradeSkillName]
	if not professionId then return end

	local recipeItemIds = {}
	for index = 1, recipeCount do
		local recipeName, recipeType
		if useCraftApi then
			local name, _, craftType = GetCraftInfo(index)
			recipeName = name
			recipeType = craftType
		else
			recipeName, recipeType = GetTradeSkillInfo(index)
		end

		if recipeName and recipeType ~= "header" then
			if useCraftApi then
				local craftLink = GetCraftItemLink and GetCraftItemLink(index)

				-- use spell ID from craft recipe link, stored as negative
				if craftLink then
					local craftId = tonumber(craftLink:match("enchant:(%d+)"))
					if craftId then
						table.insert(recipeItemIds, -craftId)
					end
				end
			else
				local itemLink = GetTradeSkillItemLink(index)
				local itemId = GetItemIdFromLink(itemLink)
				if itemId then
					table.insert(recipeItemIds, itemId)
				end
			end
		end
	end

	local playerRecipes = GetPlayerRecipes()
	playerRecipes[professionId] = playerRecipes[professionId] or {}
	playerRecipes[professionId].recipes = recipeItemIds

	ClassicGuildTools.Utils.Debounce("ProfessionBroadcast", 30, BroadcastPlayerProfessions)
end

-- ============================================================
-- Professions UI
-- ============================================================

local contentFrame = ClassicGuildTools.UI.GetContentFrame(3)
contentFrame:SetScript("OnShow", function()
	ClassicGuildTools.UI.UpdateProfessionsUI()
end)

local function FormatPlayerName(playerName, rank)
	local myName = ClassicGuildTools.GetPlayerName()
	local isSelf = playerName == myName
	local displayName = isSelf and L["You"] or playerName

	local color
	if isSelf then
		color = "|cff00ff00"
	else
		local memberInfo = ClassicGuildTools.guildMemberCache[playerName]

		color = memberInfo and memberInfo.online and "|cffffffff" or "|cff808080"
	end

	return color .. displayName .. " (" .. rank .. ")"
end

local function CreateRecipeRow(parent)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(ROW_HEIGHT)
	row:EnableMouse(true)

	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(ROW_HEIGHT, ROW_HEIGHT)
	row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)

	row.itemName = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.itemName:SetPoint("LEFT", row.icon, "RIGHT", 4, 0)
	row.itemName:SetJustifyH("LEFT")

	row.players = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
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
			if self.isSpell then
				GameTooltip:SetSpellByID(-self.itemId)
			else
				GameTooltip:SetItemByID(self.itemId)
			end
			GameTooltip:Show()
		end
	end)

	row:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	row:SetScript("OnMouseUp", function(self, button)
		if button == "LeftButton" and IsShiftKeyDown() and self.itemLink then
			ChatEdit_InsertLink(self.itemLink)
		elseif button == "RightButton" and self.onlinePlayers and #self.onlinePlayers > 0 then
			local onlinePlayers = self.onlinePlayers
			MenuUtil.CreateContextMenu(self, function(_, rootDescription)
				rootDescription:SetScrollMode(GetScreenHeight() * 0.5)
				for _, playerName in ipairs(onlinePlayers) do
					rootDescription:CreateButton(L["SendMessageTo"]:format("|cffffd100" .. playerName .. "|r"), function()
						ChatFrame_SendTell(playerName)
					end)
				end
			end)
		end
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

-- Settings button
local function GetSettings()
	ClassicGuildToolsDB = ClassicGuildToolsDB or {}
	ClassicGuildToolsDB.professions = ClassicGuildToolsDB.professions or {}
	return ClassicGuildToolsDB.professions
end

local mainFrame = ClassicGuildTools.UI.GetMainFrame()
local professionSettingsButton = CreateFrame("Button", nil, mainFrame)
professionSettingsButton:SetSize(20, 20)
professionSettingsButton:SetPoint("RIGHT", mainFrame.CloseButton, "LEFT", 4, 0)
professionSettingsButton:Hide()
ClassicGuildTools.UI.professionSettingsButton = professionSettingsButton
professionSettingsButton:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
professionSettingsButton:SetHighlightTexture("Interface\\Buttons\\UI-OptionsButton")
professionSettingsButton:GetHighlightTexture():SetAlpha(0.4)

professionSettingsButton:SetScript("OnClick", function(self)
	MenuUtil.CreateContextMenu(self, function(ownerRegion, rootDescription)
		rootDescription:CreateCheckbox(
			L["SettingsShowOnlyOnline"],
			function() return GetSettings().showOnlyOnline end,
			function()
				GetSettings().showOnlyOnline = not GetSettings().showOnlyOnline
				ClassicGuildTools.Professions.UpdateDropdownDisplay(selectedProfessionId)
				ClassicGuildTools.UI.UpdateProfessionsUI()
			end
		)
	end)
end)

-- Profession dropdown
local professionDropdown = CreateFrame("DropdownButton", "ClassicGuildToolsProfessionDropdown", contentFrame, "WowStyle1DropdownTemplate")
professionDropdown:SetPoint("TOPRIGHT", contentFrame, "TOPRIGHT", -4, 0)
professionDropdown:SetWidth(180)
professionDropdown:SetDefaultText(L["AllProfessions"])

local function CountPlayersForProfession(professionId)
	local guildData = GetCurrentGuildData()
	if not guildData then return 0 end

	local onlyOnline = GetSettings().showOnlyOnline
	local myName = ClassicGuildTools.GetPlayerName()
	local count = 0
	for guid, professions in pairs(guildData) do
		if professions[professionId] and professions[professionId].recipes and #professions[professionId].recipes > 0 then
			local _, _, _, _, _, playerName = GetPlayerInfoByGUID(guid)
			if playerName then
				if not onlyOnline then
					count = count + 1
				else
					local isSelf = playerName == myName
					local memberInfo = ClassicGuildTools.guildMemberCache[playerName]
					if isSelf or (memberInfo and memberInfo.online) then
						count = count + 1
					end
				end
			end
		end
	end

	return count
end

function ClassicGuildTools.Professions.UpdateDropdownDisplay(professionId)
	if professionId then
		local localeKey = PROFESSION_LOCALE_KEYS[professionId]
		local icon = PROFESSION_ICONS[professionId]
		local playerCount = CountPlayersForProfession(professionId)
		professionDropdown:SetDefaultText(L[localeKey] .. " (" .. playerCount .. ") |T" .. icon .. ":16|t")
	else
		professionDropdown:SetDefaultText(L["AllProfessions"])
	end
end

searchBox:SetPoint("LEFT", contentFrame, "LEFT", 6, 0)
searchBox:SetPoint("RIGHT", professionDropdown, "LEFT", -10, 0)
searchBox:SetPoint("BOTTOM", professionDropdown, "BOTTOM", 0, 8)

professionDropdown:SetupMenu(function(dropdown, rootDescription)
	rootDescription:CreateRadio(L["AllProfessions"], function() return selectedProfessionId == nil end, function()
		selectedProfessionId = nil
		ClassicGuildTools.Professions.UpdateDropdownDisplay(nil)
		ClassicGuildTools.UI.UpdateProfessionsUI()
	end)

	for _, professionId in ipairs(SORTED_PROFESSION_IDS) do
		local localeKey = PROFESSION_LOCALE_KEYS[professionId]
		if localeKey then
			local playerCount = CountPlayersForProfession(professionId)
			rootDescription:CreateRadio("|T" .. PROFESSION_ICONS[professionId] .. ":16|t " .. L[localeKey] .. " (" .. playerCount .. ")", function() return selectedProfessionId == professionId end, function()
				selectedProfessionId = professionId
				ClassicGuildTools.Professions.UpdateDropdownDisplay(professionId)
				ClassicGuildTools.UI.UpdateProfessionsUI()
			end)
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

	local recipeList = {}

	for recipeId, data in pairs(recipeCache) do
		if not selectedProfessionId or data.professionId == selectedProfessionId then
			local recipeName, recipeLink, recipeTexture, isSpell, isGathering

			if GATHERING_PROFESSIONS[data.professionId] and recipeId == data.professionId then
				local localeKey = PROFESSION_LOCALE_KEYS[data.professionId]
				recipeName = localeKey and L[localeKey] or "Unknown"
				recipeTexture = PROFESSION_ICONS[data.professionId]
				isGathering = true
			elseif recipeId < 0 then
				-- Spell-based recipe (negative ID = spell ID)
				local spellId = -recipeId
				local spellName, _, spellIcon = GetSpellInfo(spellId)
				if spellName then
					recipeName = spellName
					recipeLink = GetSpellLink(spellId)
					recipeTexture = spellIcon
					isSpell = true
				end
			else
				local itemName, itemLink, _, _, _, _, _, _, _, itemTexture = GetItemInfo(recipeId)
				if itemName and itemLink then
					recipeName = itemName
					recipeLink = itemLink
					recipeTexture = itemTexture
				end
			end

			if recipeName and (recipeLink or isGathering) then
				if searchText == "" or recipeName:lower():find(searchText, 1, true) then
					local players = data.players
					if GetSettings().showOnlyOnline then
						players = {}
						for _, player in ipairs(data.players) do
							if player.isSelf or player.isOnline then
								table.insert(players, player)
							end
						end
					end

					if #players > 0 then
						table.insert(recipeList, {
							recipeId = recipeId,
							isSpell = isSpell,
							isGathering = isGathering,
							itemName = recipeName,
							itemLink = recipeLink,
							itemTexture = recipeTexture,
							players = players,
						})
					end
				end
			end
		end
	end

	table.sort(recipeList, function(a, b)
		return a.itemName < b.itemName
	end)

	if #recipeList == 0 then
		noResultsText:Show()
		headerItem:Hide()
		headerPlayers:Hide()
	else
		noResultsText:Hide()
		headerItem:Show()
		headerPlayers:Show()
	end

	for index, recipe in ipairs(recipeList) do
		local row = rowPool:Acquire()
		row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -((index - 1) * (ROW_HEIGHT + ROW_SPACING)))
		row:SetPoint("RIGHT", scrollChild, "RIGHT", 0, 0)

		row.itemId = not recipe.isGathering and recipe.recipeId or nil
		row.isSpell = recipe.isSpell
		row.itemLink = recipe.itemLink

		local onlinePlayers = {}
		for _, player in ipairs(recipe.players) do
			if not player.isSelf and player.isOnline then
				table.insert(onlinePlayers, player.name)
			end
		end
		row.onlinePlayers = onlinePlayers
		row.icon:SetTexture(recipe.itemTexture)
		local displayText
		if recipe.isGathering then
			displayText = "|cffffd100" .. recipe.itemName .. "|r"
		elseif recipe.isSpell then
			displayText = "|cff71d5ff" .. recipe.itemName .. "|r"
		else
			displayText = recipe.itemLink:gsub("|h%[", "|h"):gsub("%]|h", "|h")
		end
		row.itemName:SetText(displayText)

		local availableWidth = row.players:GetWidth()
		local playerText = ""
		local truncated = false
		local lastPlayerOnline = false

		for partIndex, player in ipairs(recipe.players) do
			local testText = playerText

			if testText ~= "" then testText = testText .. ", " end
			testText = testText .. FormatPlayerName(player.name, player.rank)

			if availableWidth and availableWidth > 0 and partIndex > 1 then
				row.players:SetText(testText)
				if row.players:GetStringWidth() > availableWidth then
					truncated = true
					break
				end
			end

			lastPlayerOnline = player.isSelf or player.isOnline
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

ClassicGuildTools.MessageHandlers.PLAYER_DIED = function(data, sender)
	if not ClassicGuildTools.Utils.isHardcore then
		return
	end

	local guildData = GetCurrentGuildData()
	if not guildData then return end

	for guid, _ in pairs(guildData) do
		local _, _, _, _, _, playerName = GetPlayerInfoByGUID(guid)
		if playerName == sender then
			guildData[guid] = nil
			ClassicGuildTools.Utils.Debounce("RebuildRecipeCache", 1, RebuildRecipeCache)
			break
		end
	end
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

local function AddRecipeCacheTooltip(self, cached)
	local playerParts = {}
	for _, player in ipairs(cached.players) do
		table.insert(playerParts, FormatPlayerName(player.name, player.rank))
	end

	local localeKey = PROFESSION_LOCALE_KEYS[cached.professionId]
	local icon = PROFESSION_ICONS[cached.professionId]

	self:AddLine(" ")
	if localeKey and icon then
		self:AddLine("|T" .. icon .. ":14|t " .. L[localeKey] .. " (" .. L["AddonTitle"] .. ")")
	end
	self:AddLine(table.concat(playerParts, ", "), 1, 1, 1, true)
	self:Show()
end

GameTooltip:HookScript("OnTooltipSetItem", function(self)
	local _, itemLink = self:GetItem()
	if not itemLink then return end

	local itemId = GetItemIdFromLink(itemLink)
	if not itemId then return end
	if GATHERING_PROFESSIONS[itemId] then return end

	local cached = recipeCache[itemId]
	if not cached then return end

	AddRecipeCacheTooltip(self, cached)
end)

GameTooltip:HookScript("OnTooltipSetSpell", function(self)
	local _, spellId = self:GetSpell()
	if not spellId then return end

	local cached = recipeCache[-spellId]
	if not cached then return end

	AddRecipeCacheTooltip(self, cached)
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
end

ClassicGuildTools.EventHandlers.TRADE_SKILL_CLOSE = function()
	ClassicGuildTools.UnregisterEventHandler("TRADE_SKILL_UPDATE", OnTradeSkillUpdate)
	ScanCurrentTradeSkill()
end

ClassicGuildTools.EventHandlers.CRAFT_SHOW = function()
	OnTradeSkillUpdate()
	ClassicGuildTools.EventHandlers.CRAFT_UPDATE = OnTradeSkillUpdate
end

ClassicGuildTools.EventHandlers.CRAFT_CLOSE = function()
	ClassicGuildTools.UnregisterEventHandler("CRAFT_UPDATE", OnTradeSkillUpdate)
	ScanCurrentTradeSkill()
end
