GuildFoundTools = GuildFoundTools or {}

local ADDON_PREFIX = "GFTools"

local MESSAGE_TYPES = {
	GROUP_CREATE = "GC",
	GROUP_EDIT = "GE",
	GROUP_REMOVE = "GR",
	GROUP_SIGNUP = "GS",
	GROUP_LEAVE = "GL",
	GROUP_MEMBERS_SYNC = "GM",
	GROUP_LIST_REQUEST = "GQ",
	GROUP_LIST_ANSWER = "GA",
	PROFESSION_QUERY = "PQ",
	PROFESSION_ANSWER = "PA",
}

local EVENTS = {
	ADDON_LOADED = "ADDON_LOADED",
	PLAYER_LOGIN = "PLAYER_LOGIN",
	CHAT_MSG_ADDON = "CHAT_MSG_ADDON",
	TRADE_SKILL_SHOW = "TRADE_SKILL_SHOW",
	TRADE_SKILL_CLOSE = "TRADE_SKILL_CLOSE",
	GROUP_JOINED = "GROUP_JOINED",
	GROUP_ROSTER_UPDATE = "GROUP_ROSTER_UPDATE",
}

-- In-memory state
GuildFoundTools.groups = {}
GuildFoundTools.professions = {}

-- Local player info (populated on login)
local playerName = nil
local playerRealm = nil

local function GetPlayerName()
	if not playerName then
		playerName = UnitName("player")
	end
	return playerName
end

local function NormalizeSender(sender)
	local name = strsplit("-", sender)
	return name
end

-- Serialization: tab-separated fields
local function Serialize(messageType, ...)
	local parts = { messageType }
	for i = 1, select("#", ...) do
		local value = select(i, ...)
		table.insert(parts, tostring(value or ""))
	end
	return table.concat(parts, "\t")
end

local function Deserialize(message)
	return { strsplit("\t", message) }
end

-- Send a message to the guild channel
local function SendGuildMessage(message)
	if not IsInGuild() then return end
	C_ChatInfo.SendAddonMessage(ADDON_PREFIX, message, "GUILD")
end

-- Staggered send for multiple messages
local function SendGuildMessages(messages)
	for index, message in ipairs(messages) do
		C_Timer.After((index - 1) * 0.1, function()
			SendGuildMessage(message)
		end)
	end
end

-- Generate a unique group ID
local function GenerateGroupId()
	return GetPlayerName() .. "-" .. time()
end

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

function GuildFoundTools.ScanProfessions()
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

function GuildFoundTools.GetScannedRecipes()
	return scannedRecipes
end

-- ============================================================
-- Party member tracking
-- ============================================================

GuildFoundTools.ownGroupId = nil

function GuildFoundTools.GetMemberCount(group)
	local count = 0
	for _ in pairs(group.members) do
		count = count + 1
	end
	return count
end

local function SyncPartyMembers()
	if not GuildFoundTools.ownGroupId then return end

	local group = GuildFoundTools.groups[GuildFoundTools.ownGroupId]
	if not group then return end
	local newMembers = { [GetPlayerName()] = group.members[GetPlayerName()] or "DD" }
	local numGroupMembers = GetNumGroupMembers()

	for index = 1, numGroupMembers do
		local name = GetRaidRosterInfo(index)
		if name then
			name = strsplit("-", name)
			if name ~= GetPlayerName() then
				newMembers[name] = group.members[name] or "DD"
			end
		end
	end

	group.members = newMembers

	-- Broadcast full member list to guild
	local memberParts = {}
	for memberName, role in pairs(group.members) do
		table.insert(memberParts, memberName .. ":" .. role)
	end
	local message = Serialize(MESSAGE_TYPES.GROUP_MEMBERS_SYNC, GuildFoundTools.ownGroupId, table.concat(memberParts, ","))
	SendGuildMessage(message)

	if GuildFoundTools.UpdateLFGUI then
		GuildFoundTools.UpdateLFGUI()
	end
end

local function HandlePartyRosterUpdate()
	if GuildFoundTools.ownGroupId then
		SyncPartyMembers()
	end
end

-- ============================================================
-- Group management API
-- ============================================================

function GuildFoundTools.CreateGroup(category, dungeon, description, maxMembers, beginnerFriendly, leaderRole)
	if not IsInGuild() then
		print("|cff00ccffGuildFound Tools:|r Du bist in keiner Gilde.")
		return
	end

	-- Only one group per player allowed
	if GuildFoundTools.ownGroupId then
		print("|cff00ccffGuildFound Tools:|r Du hast bereits eine Gruppe erstellt.")
		return
	end

	local groupId = GenerateGroupId()
	local group = {
		id = groupId,
		category = category or "Custom",
		dungeon = dungeon or "",
		description = description or "",
		maxMembers = maxMembers or 5,
		beginnerFriendly = beginnerFriendly or false,
		leader = GetPlayerName(),
		members = { [GetPlayerName()] = leaderRole or "DD" },
		createdAt = time(),
	}

	GuildFoundTools.groups[groupId] = group
	GuildFoundTools.ownGroupId = groupId

	local message = Serialize(MESSAGE_TYPES.GROUP_CREATE, groupId, category, dungeon, description, maxMembers, GetPlayerName(), leaderRole or "DD", beginnerFriendly and "1" or "0")
	SendGuildMessage(message)

	if GuildFoundTools.UpdateLFGUI then
		GuildFoundTools.UpdateLFGUI()
	end

	return groupId
end

function GuildFoundTools.RemoveGroup(groupId)
	local group = GuildFoundTools.groups[groupId]
	if not group then return end
	if group.leader ~= GetPlayerName() then return end

	GuildFoundTools.groups[groupId] = nil
	GuildFoundTools.ownGroupId = nil

	local message = Serialize(MESSAGE_TYPES.GROUP_REMOVE, groupId)
	SendGuildMessage(message)

	if GuildFoundTools.UpdateLFGUI then
		GuildFoundTools.UpdateLFGUI()
	end
end

function GuildFoundTools.EditGroup(groupId, category, dungeon, description, maxMembers, beginnerFriendly, leaderRole)
	local group = GuildFoundTools.groups[groupId]
	if not group then return end
	if group.leader ~= GetPlayerName() then return end

	group.category = category or group.category
	group.dungeon = dungeon or group.dungeon
	group.description = description or group.description
	group.maxMembers = maxMembers or group.maxMembers
	group.beginnerFriendly = beginnerFriendly
	group.members[group.leader] = leaderRole or "DD"

	local message = Serialize(MESSAGE_TYPES.GROUP_EDIT, groupId, group.category, group.dungeon, group.description, group.maxMembers, group.beginnerFriendly and "1" or "0")
	SendGuildMessage(message)

	if GuildFoundTools.UpdateLFGUI then
		GuildFoundTools.UpdateLFGUI()
	end
end

function GuildFoundTools.SignupForGroup(groupId, role)
	if not IsInGuild() then return end

	-- If the player is a group leader, remove their group first
	if GuildFoundTools.ownGroupId then
		GuildFoundTools.RemoveGroup(GuildFoundTools.ownGroupId)
	end

	local message = Serialize(MESSAGE_TYPES.GROUP_SIGNUP, groupId, GetPlayerName(), role or "DD")
	SendGuildMessage(message)
end

function GuildFoundTools.LeaveGroup(groupId)
	if not IsInGuild() then return end

	local message = Serialize(MESSAGE_TYPES.GROUP_LEAVE, groupId, GetPlayerName())
	SendGuildMessage(message)
end

function GuildFoundTools.RequestGroupList()
	if not IsInGuild() then return end

	local message = Serialize(MESSAGE_TYPES.GROUP_LIST_REQUEST)
	SendGuildMessage(message)
end

-- ============================================================
-- Profession query API
-- ============================================================

function GuildFoundTools.RequestProfessions()
	if not IsInGuild() then
		print("|cff00ccffGuildFound Tools:|r Du bist in keiner Gilde.")
		return
	end

	-- Clear old data
	wipe(GuildFoundTools.professions)

	local message = Serialize(MESSAGE_TYPES.PROFESSION_QUERY)
	SendGuildMessage(message)

	if GuildFoundTools.UpdateProfessionsUI then
		GuildFoundTools.UpdateProfessionsUI()
	end
end

-- ============================================================
-- Message handlers
-- ============================================================

local pendingSignups = {} -- buffer for GS/GL arriving before GC

local function HandleGroupCreate(fields, sender)
	-- GC groupId category dungeon description maxMembers leader leaderRole beginnerFriendly
	local groupId = fields[2]
	local category = fields[3]
	local dungeon = fields[4]
	local description = fields[5]
	local maxMembers = tonumber(fields[6]) or 5
	local leader = fields[7] or sender
	local leaderRole = fields[8] or "DD"
	local beginnerFriendly = fields[9] == "1"

	if not groupId then return end

	GuildFoundTools.groups[groupId] = {
		id = groupId,
		category = category or "Custom",
		dungeon = dungeon or "",
		description = description or "",
		maxMembers = maxMembers,
		beginnerFriendly = beginnerFriendly,
		leader = leader,
		members = { [leader] = leaderRole },
		createdAt = time(),
	}

	-- Apply any buffered signups
	if pendingSignups[groupId] then
		for _, signup in ipairs(pendingSignups[groupId]) do
			local group = GuildFoundTools.groups[groupId]
			if not group.members[signup.name] and GuildFoundTools.GetMemberCount(group) < group.maxMembers then
				group.members[signup.name] = signup.role or "DD"
			end
		end
		pendingSignups[groupId] = nil
	end

	if GuildFoundTools.UpdateLFGUI then
		GuildFoundTools.UpdateLFGUI()
	end
end

local function HandleGroupEdit(fields, sender)
	-- GE groupId category dungeon description maxMembers beginnerFriendly
	local groupId = fields[2]
	if not groupId then return end

	local group = GuildFoundTools.groups[groupId]
	if not group then return end

	group.category = fields[3] or group.category
	group.dungeon = fields[4] or group.dungeon
	group.description = fields[5] or group.description
	group.maxMembers = tonumber(fields[6]) or group.maxMembers
	group.beginnerFriendly = fields[7] == "1"

	if GuildFoundTools.UpdateLFGUI then
		GuildFoundTools.UpdateLFGUI()
	end
end

local function HandleGroupRemove(fields)
	local groupId = fields[2]
	if not groupId then return end

	GuildFoundTools.groups[groupId] = nil

	if GuildFoundTools.UpdateLFGUI then
		GuildFoundTools.UpdateLFGUI()
	end
end

local function HandleGroupSignup(fields)
	local groupId = fields[2]
	local memberName = fields[3]
	local memberRole = fields[4] or "DD"
	if not groupId or not memberName then return end

	local group = GuildFoundTools.groups[groupId]
	if not group then
		-- Buffer the signup for a short time
		pendingSignups[groupId] = pendingSignups[groupId] or {}
		table.insert(pendingSignups[groupId], { name = memberName, role = memberRole })
		C_Timer.After(5, function()
			pendingSignups[groupId] = nil
		end)
		return
	end

	if group.members[memberName] then return end

	if GuildFoundTools.GetMemberCount(group) < group.maxMembers then
		group.members[memberName] = memberRole
	end

	if GuildFoundTools.UpdateLFGUI then
		GuildFoundTools.UpdateLFGUI()
	end
end

local function HandleGroupLeave(fields)
	local groupId = fields[2]
	local memberName = fields[3]
	if not groupId or not memberName then return end

	local group = GuildFoundTools.groups[groupId]
	if not group then return end

	group.members[memberName] = nil

	if GuildFoundTools.UpdateLFGUI then
		GuildFoundTools.UpdateLFGUI()
	end
end

local function HandleGroupMembersSync(fields)
	-- GM groupId members(comma-sep name:role)
	local groupId = fields[2]
	local membersString = fields[3] or ""
	if not groupId then return end

	local group = GuildFoundTools.groups[groupId]
	if not group then return end

	local members = {}
	for entry in membersString:gmatch("[^,]+") do
		local name, role = strsplit(":", entry)
		members[name] = role or "DD"
	end

	group.members = members

	if GuildFoundTools.UpdateLFGUI then
		GuildFoundTools.UpdateLFGUI()
	end
end

local function HandleGroupListRequest(fields, sender)
	if not GuildFoundTools.ownGroupId then return end

	local group = GuildFoundTools.groups[GuildFoundTools.ownGroupId]
	if not group then return end

	local memberParts = {}
	for memberName, role in pairs(group.members) do
		table.insert(memberParts, memberName .. ":" .. role)
	end
	local message = Serialize(MESSAGE_TYPES.GROUP_LIST_ANSWER, GuildFoundTools.ownGroupId, group.category, group.dungeon, group.description, group.maxMembers, group.leader, table.concat(memberParts, ","), group.beginnerFriendly and "1" or "0")
	SendGuildMessage(message)
end

local function HandleGroupListAnswer(fields)
	-- GA groupId category dungeon description maxMembers leader members(comma-sep) beginnerFriendly
	local groupId = fields[2]
	if not groupId then return end

	-- Don't overwrite if we already have it
	if GuildFoundTools.groups[groupId] then return end

	local category = fields[3]
	local dungeon = fields[4]
	local description = fields[5]
	local maxMembers = tonumber(fields[6]) or 5
	local leader = fields[7] or ""
	local membersString = fields[8] or leader
	local beginnerFriendly = fields[9] == "1"

	local members = {}
	if membersString and membersString ~= "" then
		for entry in membersString:gmatch("[^,]+") do
			local name, entryRole = strsplit(":", entry)
			members[name] = entryRole or "DD"
		end
	end

	GuildFoundTools.groups[groupId] = {
		id = groupId,
		category = category or "Custom",
		dungeon = dungeon or "",
		description = description or "",
		maxMembers = maxMembers,
		beginnerFriendly = beginnerFriendly,
		leader = leader,
		members = members,
		createdAt = time(),
	}

	if GuildFoundTools.UpdateLFGUI then
		GuildFoundTools.UpdateLFGUI()
	end
end

-- Profession message chunks: PA sender profName rank maxRank numChunks chunkIndex itemId1,itemId2,...
local professionChunks = {} -- [sender..profName] = { chunks = {}, expected = N }

local function HandleProfessionQuery(fields, sender)
	-- Someone is requesting professions; respond with ours
	local myProfessions = GuildFoundTools.ScanProfessions()
	local messages = {}

	for _, profession in ipairs(myProfessions) do
		local recipes = scannedRecipes[profession.name]
		if recipes and #recipes > 0 then
			-- Chunk the recipe item IDs to fit within 255 bytes
			local itemIds = {}
			for _, recipe in ipairs(recipes) do
				table.insert(itemIds, recipe.itemId)
			end

			local chunks = {}
			local currentChunk = {}
			local currentLength = 0
			-- Header overhead: PA\tprofName\trank\tmaxRank\tnumChunks\tchunkIndex\t = ~50 chars
			local maxPayload = 180

			for _, itemId in ipairs(itemIds) do
				local idStr = tostring(itemId)
				local addLength = #idStr + (currentLength > 0 and 1 or 0) -- comma separator
				if currentLength + addLength > maxPayload and #currentChunk > 0 then
					table.insert(chunks, table.concat(currentChunk, ","))
					currentChunk = {}
					currentLength = 0
				end
				table.insert(currentChunk, idStr)
				currentLength = currentLength + addLength
			end
			if #currentChunk > 0 then
				table.insert(chunks, table.concat(currentChunk, ","))
			end

			for chunkIndex, chunkData in ipairs(chunks) do
				local message = Serialize(MESSAGE_TYPES.PROFESSION_ANSWER, profession.name, profession.rank, profession.maxRank, #chunks, chunkIndex, chunkData)
				table.insert(messages, message)
			end
		else
			-- No recipes scanned, just send profession info
			local message = Serialize(MESSAGE_TYPES.PROFESSION_ANSWER, profession.name, profession.rank, profession.maxRank, 0, 0, "")
			table.insert(messages, message)
		end
	end

	if #messages > 0 then
		SendGuildMessages(messages)
	end
end

local function HandleProfessionAnswer(fields, sender)
	-- PA profName rank maxRank numChunks chunkIndex itemIds
	local professionName = fields[2]
	local rank = tonumber(fields[3]) or 0
	local maxRank = tonumber(fields[4]) or 0
	local numChunks = tonumber(fields[5]) or 0
	local chunkIndex = tonumber(fields[6]) or 0
	local itemIdsString = fields[7] or ""

	if not professionName then return end

	-- Initialize profession data for this sender
	GuildFoundTools.professions[sender] = GuildFoundTools.professions[sender] or {}

	local chunkKey = sender .. "|" .. professionName

	if numChunks == 0 then
		-- No recipes, just profession info
		GuildFoundTools.professions[sender][professionName] = {
			rank = rank,
			maxRank = maxRank,
			recipes = {},
		}
	else
		-- Accumulate chunks
		professionChunks[chunkKey] = professionChunks[chunkKey] or { chunks = {}, expected = numChunks, rank = rank, maxRank = maxRank }
		professionChunks[chunkKey].chunks[chunkIndex] = itemIdsString

		-- Check if all chunks received
		local allReceived = true
		for index = 1, professionChunks[chunkKey].expected do
			if not professionChunks[chunkKey].chunks[index] then
				allReceived = false
				break
			end
		end

		if allReceived then
			local allItemIds = {}
			for index = 1, professionChunks[chunkKey].expected do
				for itemId in professionChunks[chunkKey].chunks[index]:gmatch("[^,]+") do
					local id = tonumber(itemId)
					if id and id > 0 then
						table.insert(allItemIds, id)
					end
				end
			end

			GuildFoundTools.professions[sender][professionName] = {
				rank = rank,
				maxRank = maxRank,
				recipes = allItemIds,
			}

			professionChunks[chunkKey] = nil
		end
	end

	if GuildFoundTools.UpdateProfessionsUI then
		GuildFoundTools.UpdateProfessionsUI()
	end
end

-- Message dispatch
local MESSAGE_HANDLERS = {
	[MESSAGE_TYPES.GROUP_CREATE] = HandleGroupCreate,
	[MESSAGE_TYPES.GROUP_EDIT] = HandleGroupEdit,
	[MESSAGE_TYPES.GROUP_REMOVE] = HandleGroupRemove,
	[MESSAGE_TYPES.GROUP_SIGNUP] = HandleGroupSignup,
	[MESSAGE_TYPES.GROUP_LEAVE] = HandleGroupLeave,
	[MESSAGE_TYPES.GROUP_MEMBERS_SYNC] = HandleGroupMembersSync,
	[MESSAGE_TYPES.GROUP_LIST_REQUEST] = HandleGroupListRequest,
	[MESSAGE_TYPES.GROUP_LIST_ANSWER] = HandleGroupListAnswer,
	[MESSAGE_TYPES.PROFESSION_QUERY] = HandleProfessionQuery,
	[MESSAGE_TYPES.PROFESSION_ANSWER] = HandleProfessionAnswer,
}

-- ============================================================
-- Event handling
-- ============================================================

local frame = CreateFrame("Frame")
for _, eventName in pairs(EVENTS) do
	frame:RegisterEvent(eventName)
end

frame:SetScript("OnEvent", function(self, event, ...)
	if event == EVENTS.ADDON_LOADED then
		local addonName = ...
		if addonName == "GuildFoundTools" then
			GuildFoundToolsDB = GuildFoundToolsDB or {}
			GuildFoundToolsDB.minimap = GuildFoundToolsDB.minimap or {}
			C_ChatInfo.RegisterAddonMessagePrefix(ADDON_PREFIX)
		end
	elseif event == EVENTS.PLAYER_LOGIN then
		playerName = UnitName("player")
		playerRealm = GetRealmName()
	elseif event == EVENTS.CHAT_MSG_ADDON then
		local prefix, message, channel, sender = ...
		if prefix ~= ADDON_PREFIX or channel ~= "GUILD" then return end

		sender = NormalizeSender(sender)
		local fields = Deserialize(message)
		local messageType = fields[1]

		local handler = MESSAGE_HANDLERS[messageType]
		if handler then
			handler(fields, sender)
		end
	elseif event == EVENTS.GROUP_JOINED then
		if GuildFoundTools.ownGroupId then
			-- If we joined someone else's party, remove our own tool group
			C_Timer.After(0.5, function()
				if not UnitIsGroupLeader("player") then
					GuildFoundTools.RemoveGroup(GuildFoundTools.ownGroupId)
					print("|cff00ccffGuildFound Tools:|r Deine Gruppe wurde entfernt, da du einer anderen Gruppe beigetreten bist.")
				end
			end)
		else
			-- Check if anyone in the party is a tool group leader -> show role popup
			C_Timer.After(0.5, function()
				local numGroupMembers = GetNumGroupMembers()
				for index = 1, numGroupMembers do
					local name = GetRaidRosterInfo(index)
					if name then
						name = strsplit("-", name)
						for _, group in pairs(GuildFoundTools.groups) do
							if group.leader == name and GuildFoundTools.ShowPartyRolePopup then
								GuildFoundTools.ShowPartyRolePopup(group.id)
								return
							end
						end
					end
				end
			end)
		end
	elseif event == EVENTS.GROUP_ROSTER_UPDATE then
		HandlePartyRosterUpdate()
	elseif event == EVENTS.TRADE_SKILL_SHOW then
		ScanCurrentTradeSkill()
	elseif event == EVENTS.TRADE_SKILL_CLOSE then
		-- Scan one more time before closing
		ScanCurrentTradeSkill()
	end
end)

-- ============================================================
-- Slash commands
-- ============================================================

SLASH_GUILDFOUNDTOOLS1 = "/gft"
SLASH_GUILDFOUNDTOOLS2 = "/guildfoundtools"
SlashCmdList["GUILDFOUNDTOOLS"] = function()
	GuildFoundTools.Toggle()
end
