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

local function BroadcastPlayerProfessions(target)
	local guildData = GetCurrentGuildData()
	if not guildData then return end

	local guid = UnitGUID("player")
	local professions = guildData[guid]
	if not professions then return end

	for professionId, professionData in pairs(professions) do
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

	BroadcastPlayerProfessions()
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

	BroadcastPlayerProfessions()
end

function ClassicGuildTools.Professions.GetScannedRecipes()
	return GetPlayerRecipes()
end

-- ============================================================
-- Professions UI
-- ============================================================

local contentFrame = ClassicGuildTools.UI.GetContentFrame(3)

function ClassicGuildTools.UI.UpdateProfessionsUI()
end

-- ============================================================
-- Profession message handlers
-- ============================================================

ClassicGuildTools.MessageHandlers.PROFESSION_QUERY = function(data, sender)
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
end

-- ============================================================
-- Event handlers
-- ============================================================

-- Register profession event handlers
local function OnTradeSkillUpdate()
	ClassicGuildTools.Utils.Debounce("TradeSkillUpdate", 1, ScanCurrentTradeSkill)
end

ClassicGuildTools.EventHandlers.PLAYER_LOGIN = function()
	ClassicGuildTools.Professions.ScanProfessions()
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
