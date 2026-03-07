-- LFG Tab: logic + UI for create/list/join groups

-- ============================================================
-- LFG Logic
-- ============================================================

GuildFoundTools.LFG = GuildFoundTools.LFG or {}

local L = LibStub("AceLocale-3.0"):GetLocale("GuildFoundTools")
local MESSAGE_TYPE = GuildFoundTools.MESSAGE_TYPE
local SendGuildMessage = GuildFoundTools.SendGuildMessage
local SendWhisperMessage = GuildFoundTools.SendWhisperMessage
local GetPlayerName = GuildFoundTools.GetPlayerName
local DUNGEON = GuildFoundTools.Enums.DUNGEON

-- Constants
local CATEGORIES = { "Dungeons", "Raids", "Custom" }
local ROLE_NAMES = { "TANK", "HEAL", "DD" }
local ROW_HEIGHT = 40
local ROW_SPACING = 3
local MAX_ROLE_SLOTS = 5
local ACTION_BAR_HEIGHT = 30
local ROLE_SORT_ORDER = { ["TANK"] = 1, ["HEAL"] = 2, ["DD"] = 3 }
local ROLE_BUTTON_SIZE = 48
local ROLE_BUTTON_SPACING = 8
local FORM_TOP_OFFSET = -68

local CreatePool = GuildFoundTools.Utils.CreatePool

-- State variables
local selectedGroupId = nil
local selectedRole = "DD"
local selectedBeginnerFriendly = false
local selectedCategory = "Dungeons"
local selectedDungeon = ""
local isEditingMyGroup = false
local roleButtons = {}
local pendingInviteFromLeader = nil
local guildMemberCache = {}
local ROLE_ICON_MARKUP = {}
local DUNGEON_BY_ID = {}

-- Forward declarations
local leftButton, rightButton

-- Generate a unique group ID
local function GenerateGroupId()
	return GetPlayerName() .. "-" .. time()
end

-- ============================================================
-- Session persistence (survives /reload)
-- ============================================================

local function SaveGroupToStorage(group)
	local characterGuid = UnitGUID("player")
	if not characterGuid then return end

	GuildFoundTools_LFG = GuildFoundTools_LFG or {}
	GuildFoundTools_LFG[characterGuid] = group
end

local function ClearGroupFromStorage()
	local characterGuid = UnitGUID("player")
	if not characterGuid then return end

	if GuildFoundTools_LFG then
		GuildFoundTools_LFG[characterGuid] = nil
	end
end

-- ============================================================
-- Party member tracking
-- ============================================================

GuildFoundTools.LFG.ownGroupId = nil

function GuildFoundTools.LFG.GetMemberCount(group)
	local count = 0
	for _ in pairs(group.members) do
		count = count + 1
	end
	return count
end

local function BroadcastMemberSync()
	if not GuildFoundTools.LFG.ownGroupId then return end

	local group = GuildFoundTools.groups[GuildFoundTools.LFG.ownGroupId]
	if not group then return end

	SendGuildMessage(MESSAGE_TYPE.GROUP_MEMBERS_SYNC, { groupId = GuildFoundTools.LFG.ownGroupId, members = group.members })

	if GuildFoundTools.LFG.UpdateLFGUI then
		GuildFoundTools.LFG.UpdateLFGUI()
	end
end

local function UpdateGroupMembers()
	if not GuildFoundTools.LFG.ownGroupId then return end

	local group = GuildFoundTools.groups[GuildFoundTools.LFG.ownGroupId]
	if not group then return end

	local newMembers = {
		[GetPlayerName()] = group.members[GetPlayerName()] or "DD"
	}
	local numGroupMembers = GetNumGroupMembers()

	for index = 1, numGroupMembers do
		local name = GetRaidRosterInfo(index)
		if name then
			name = strsplit("-", name)
			if group.applicants and group.applicants[name] then
				newMembers[name] = group.applicants[name]
				group.applicants[name] = nil
			else
				newMembers[name] = group.members[name] or "DD"
			end
		end
	end

	group.members = newMembers
end

local function RestoreGroupFromStorage()
	local characterGuid = UnitGUID("player")
	if not characterGuid or not GuildFoundTools_LFG then return end

	local saved = GuildFoundTools_LFG[characterGuid]
	if not saved then return end

	-- Restore members from storage, filtered by current party
	local savedMembers = saved.members or {}
	local restoredMembers = {
		[GetPlayerName()] = savedMembers[GetPlayerName()] or "DD"
	}

	local numGroupMembers = GetNumGroupMembers()
	for index = 1, numGroupMembers do
		local name = GetRaidRosterInfo(index)
		if name then
			name = strsplit("-", name)
			restoredMembers[name] = savedMembers[name] or "DD"
		end
	end

	local group = {
		id = saved.id,
		category = saved.category or "Custom",
		dungeon = saved.dungeon or "",
		description = saved.description or "",
		maxMembers = saved.maxMembers or 5,
		beginnerFriendly = saved.beginnerFriendly or false,
		leader = GetPlayerName(),
		members = restoredMembers,
		applicants = saved.applicants or {},
		createdAt = saved.createdAt or time(),
	}

	GuildFoundTools.groups[group.id] = group
	GuildFoundTools.LFG.ownGroupId = group.id

	-- Broadcast to guild so others know the group exists
	SendGuildMessage(MESSAGE_TYPE.GROUP_CREATE, group)
end

-- ============================================================
-- Group management API
-- ============================================================

function GuildFoundTools.LFG.CreateGroup(category, dungeon, description, maxMembers, beginnerFriendly, leaderRole)
	if not IsInGuild() then
		print("|cff00ccffGuildFound Tools:|r " .. L["NotInGuild"])
		return
	end

	-- Only one group per player allowed
	if GuildFoundTools.LFG.ownGroupId then
		print("|cff00ccffGuildFound Tools:|r " .. L["AlreadyHaveGroup"])
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
		leaderLevel = UnitLevel("player") or 60,
		leader = GetPlayerName(),
		members = { [GetPlayerName()] = leaderRole or "DD" },
		applicants = {},
		createdAt = time(),
	}

	GuildFoundTools.groups[groupId] = group
	GuildFoundTools.LFG.ownGroupId = groupId

	UpdateGroupMembers()
	SendGuildMessage(MESSAGE_TYPE.GROUP_CREATE, group)
	SaveGroupToStorage(group)

	return groupId
end

function GuildFoundTools.LFG.RemoveGroup(groupId)
	local group = GuildFoundTools.groups[groupId]
	if not group then return end
	if group.leader ~= GetPlayerName() then return end

	GuildFoundTools.groups[groupId] = nil
	GuildFoundTools.LFG.ownGroupId = nil

	ClearGroupFromStorage()

	SendGuildMessage(MESSAGE_TYPE.GROUP_REMOVE, { id = groupId })

	if GuildFoundTools.LFG.UpdateLFGUI then
		GuildFoundTools.LFG.UpdateLFGUI()
	end
end

function GuildFoundTools.LFG.EditGroup(groupId, category, dungeon, description, maxMembers, beginnerFriendly, leaderRole)
	local group = GuildFoundTools.groups[groupId]
	if not group then return end
	if group.leader ~= GetPlayerName() then return end

	group.category = category or group.category
	group.dungeon = dungeon or group.dungeon
	group.description = description or group.description
	group.maxMembers = maxMembers or group.maxMembers
	group.beginnerFriendly = beginnerFriendly
	group.leaderLevel = UnitLevel("player") or 60
	group.members[group.leader] = leaderRole or "DD"

	SaveGroupToStorage(group)
	SendGuildMessage(MESSAGE_TYPE.GROUP_EDIT, {
		id = groupId,
		category = group.category,
		dungeon = group.dungeon,
		description = group.description,
		maxMembers = group.maxMembers,
		beginnerFriendly = group.beginnerFriendly,
		leaderLevel = group.leaderLevel,
	})

	if GuildFoundTools.LFG.UpdateLFGUI then
		GuildFoundTools.LFG.UpdateLFGUI()
	end
end

function GuildFoundTools.LFG.SignupForGroup(groupId, role)
	if not IsInGuild() then return end

	-- If the player is a group leader, remove their group first
	if GuildFoundTools.LFG.ownGroupId then
		GuildFoundTools.LFG.RemoveGroup(GuildFoundTools.LFG.ownGroupId)
	end

	SendGuildMessage(MESSAGE_TYPE.GROUP_SIGNUP, { groupId = groupId, name = GetPlayerName(), role = role or "DD" })
end

function GuildFoundTools.LFG.LeaveGroup(groupId)
	if not IsInGuild() then return end

	local group = GuildFoundTools.groups[groupId]
	if not group then return end

	local playerName = GetPlayerName()
	if group.applicants and group.applicants[playerName] then
		SendGuildMessage(MESSAGE_TYPE.GROUP_WITHDRAW, { groupId = groupId, name = playerName })
	else
		SendGuildMessage(MESSAGE_TYPE.GROUP_LEAVE, { groupId = groupId, name = playerName })
	end
end

function GuildFoundTools.LFG.AcceptApplicant(groupId, applicantName)
	if not IsInGuild() then return end

	local group = GuildFoundTools.groups[groupId]
	if not group then return end
	if group.leader ~= GetPlayerName() then return end
	if not group.applicants or not group.applicants[applicantName] then return end

	-- Send whisper to applicant requesting confirmation before inviting
	SendWhisperMessage(MESSAGE_TYPE.GROUP_INVITE_REQUEST, applicantName, {
		groupId = groupId,
		leaderName = GetPlayerName(),
	})
end

function GuildFoundTools.LFG.DeclineApplicant(groupId, applicantName)
	if not IsInGuild() then return end

	local group = GuildFoundTools.groups[groupId]
	if not group then return end
	if group.leader ~= GetPlayerName() then return end
	if not group.applicants or not group.applicants[applicantName] then return end

	group.applicants[applicantName] = nil
	SaveGroupToStorage(group)

	SendGuildMessage(MESSAGE_TYPE.GROUP_DECLINE, { groupId = groupId, name = applicantName })

	if GuildFoundTools.LFG.UpdateLFGUI then
		GuildFoundTools.LFG.UpdateLFGUI()
	end
end

function GuildFoundTools.LFG.RequestGroupList()
	if not IsInGuild() then return end

	SendGuildMessage(MESSAGE_TYPE.GROUP_LIST_REQUEST)
end

-- ============================================================
-- LFG Message handlers
-- ============================================================

GuildFoundTools.MessageHandlers.GROUP_CREATE = function(data, sender)
	if not data or not data.id then return end

	local isNewGroup = not GuildFoundTools.groups[data.id]

	data.leader = data.leader or sender
	data.createdAt = time()
	GuildFoundTools.groups[data.id] = data

	-- Show role popup if we are in the leader's party (only for new groups)
	if isNewGroup and data.leader ~= GetPlayerName() and GuildFoundTools.LFG.ShowPartyRolePopup then
		local numGroupMembers = GetNumGroupMembers()
		for index = 1, numGroupMembers do
			local name = GetRaidRosterInfo(index)
			if name then
				name = strsplit("-", name)
				if name == data.leader then
					GuildFoundTools.LFG.ShowPartyRolePopup(data.id)
					break
				end
			end
		end
	end

	if GuildFoundTools.LFG.UpdateLFGUI then
		GuildFoundTools.LFG.UpdateLFGUI()
	end
end

GuildFoundTools.MessageHandlers.GROUP_EDIT = function(data, sender)
	if not data or not data.id then return end

	local group = GuildFoundTools.groups[data.id]
	if not group then return end

	group.category = data.category or group.category
	group.dungeon = data.dungeon or group.dungeon
	group.description = data.description or group.description
	group.maxMembers = data.maxMembers or group.maxMembers
	group.beginnerFriendly = data.beginnerFriendly or false
	group.leaderLevel = data.leaderLevel or group.leaderLevel

	if GuildFoundTools.LFG.UpdateLFGUI then
		GuildFoundTools.LFG.UpdateLFGUI()
	end
end

GuildFoundTools.MessageHandlers.GROUP_REMOVE = function(data)
	if not data or not data.id then return end

	GuildFoundTools.groups[data.id] = nil

	-- Hide the role popup if it was shown for this group
	local rolePopup = _G["GuildFoundToolsPartyRolePopup"]
	if rolePopup and rolePopup.groupId == data.id then
		rolePopup:Hide()
	end

	if GuildFoundTools.LFG.UpdateLFGUI then
		GuildFoundTools.LFG.UpdateLFGUI()
	end
end

GuildFoundTools.MessageHandlers.GROUP_SIGNUP = function(data)
	if not data or not data.groupId or not data.name then return end

	local groupId = data.groupId
	local memberName = data.name
	local memberRole = data.role or "DD"

	local group = GuildFoundTools.groups[groupId]
	if not group then return end

	if group.members[memberName] then return end
	if group.applicants and group.applicants[memberName] then return end

	group.applicants = group.applicants or {}
	group.applicants[memberName] = memberRole

	if group.leader == GetPlayerName() then
		SaveGroupToStorage(group)
	end

	if GuildFoundTools.LFG.UpdateLFGUI then
		GuildFoundTools.LFG.UpdateLFGUI()
	end
end

GuildFoundTools.MessageHandlers.GROUP_LEAVE = function(data)
	if not data or not data.groupId or not data.name then return end

	local groupId = data.groupId
	local memberName = data.name

	local group = GuildFoundTools.groups[groupId]
	if not group then return end

	group.members[memberName] = nil

	if GuildFoundTools.LFG.UpdateLFGUI then
		GuildFoundTools.LFG.UpdateLFGUI()
	end
end

GuildFoundTools.MessageHandlers.GROUP_DECLINE = function(data)
	if not data or not data.groupId or not data.name then return end

	local groupId = data.groupId
	local applicantName = data.name

	local group = GuildFoundTools.groups[groupId]
	if not group then return end

	group.applicants = group.applicants or {}
	group.applicants[applicantName] = nil

	if GuildFoundTools.LFG.UpdateLFGUI then
		GuildFoundTools.LFG.UpdateLFGUI()
	end
end

GuildFoundTools.MessageHandlers.GROUP_WITHDRAW = function(data)
	if not data or not data.groupId or not data.name then return end

	local groupId = data.groupId
	local applicantName = data.name

	local group = GuildFoundTools.groups[groupId]
	if not group then return end

	group.applicants = group.applicants or {}
	group.applicants[applicantName] = nil

	if group.leader == GetPlayerName() then
		SaveGroupToStorage(group)
	end

	if GuildFoundTools.LFG.UpdateLFGUI then
		GuildFoundTools.LFG.UpdateLFGUI()
	end
end

GuildFoundTools.MessageHandlers.GROUP_MEMBERS_SYNC = function(data)
	if not data or not data.groupId then return end

	local group = GuildFoundTools.groups[data.groupId]
	if not group then return end

	group.members = data.members or {}

	-- Remove applicants who are now members
	if group.applicants then
		for name in pairs(group.members) do
			group.applicants[name] = nil
		end
	end

	if GuildFoundTools.LFG.UpdateLFGUI then
		GuildFoundTools.LFG.UpdateLFGUI()
	end
end

GuildFoundTools.MessageHandlers.GROUP_LIST_REQUEST = function(data, sender)
	if not GuildFoundTools.LFG.ownGroupId then return end

	local group = GuildFoundTools.groups[GuildFoundTools.LFG.ownGroupId]
	if not group then return end

	SendGuildMessage(MESSAGE_TYPE.GROUP_LIST_ANSWER, {
		id = GuildFoundTools.LFG.ownGroupId,
		category = group.category,
		dungeon = group.dungeon,
		description = group.description,
		maxMembers = group.maxMembers,
		leader = group.leader,
		leaderLevel = group.leaderLevel,
		members = group.members,
		beginnerFriendly = group.beginnerFriendly,
		applicants = group.applicants,
	})
end

GuildFoundTools.MessageHandlers.GROUP_LIST_ANSWER = function(data)
	if not data or not data.id then return end

	-- Don't overwrite if we already have it
	if GuildFoundTools.groups[data.id] then return end

	data.createdAt = time()
	GuildFoundTools.groups[data.id] = data

	if GuildFoundTools.LFG.UpdateLFGUI then
		GuildFoundTools.LFG.UpdateLFGUI()
	end
end

GuildFoundTools.MessageHandlers.GROUP_LEADER_CHANGE = function(data)
	if not data or not data.groupId or not data.newLeader then return end

	local groupId = data.groupId
	local newLeader = data.newLeader

	local group = GuildFoundTools.groups[groupId]
	if not group then return end

	group.leader = newLeader

	-- If I am the new leader, take ownership
	if newLeader == GetPlayerName() then
		GuildFoundTools.LFG.ownGroupId = groupId
		SaveGroupToStorage(group)
	else
		ClearGroupFromStorage()
	end

	if GuildFoundTools.LFG.UpdateLFGUI then
		GuildFoundTools.LFG.UpdateLFGUI()
	end
end

-- ============================================================
-- Invite confirmation popup (shown to applicant when leader accepts)
-- ============================================================

local inviteConfirmPopup = CreateFrame("Frame", "GuildFoundToolsInviteConfirmPopup", UIParent, "BasicFrameTemplateWithInset")
inviteConfirmPopup:SetSize(300, 110)
inviteConfirmPopup:SetPoint("CENTER")
inviteConfirmPopup:SetFrameStrata("DIALOG")
inviteConfirmPopup:Hide()
inviteConfirmPopup:EnableMouse(true)
inviteConfirmPopup:SetMovable(true)
inviteConfirmPopup:RegisterForDrag("LeftButton")
inviteConfirmPopup:SetScript("OnDragStart", inviteConfirmPopup.StartMoving)
inviteConfirmPopup:SetScript("OnDragStop", inviteConfirmPopup.StopMovingOrSizing)

inviteConfirmPopup.title = inviteConfirmPopup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
inviteConfirmPopup.title:SetPoint("CENTER", inviteConfirmPopup.TitleBg, "CENTER", 0, 0)
inviteConfirmPopup.title:SetText(L["InviteConfirmTitle"])

inviteConfirmPopup.leaderName = nil

inviteConfirmPopup.text = inviteConfirmPopup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
inviteConfirmPopup.text:SetPoint("TOP", 0, -32)
inviteConfirmPopup.text:SetPoint("LEFT", 16, 0)
inviteConfirmPopup.text:SetPoint("RIGHT", -16, 0)
inviteConfirmPopup.text:SetJustifyH("CENTER")
inviteConfirmPopup.text:SetWordWrap(true)

inviteConfirmPopup.warning = inviteConfirmPopup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
inviteConfirmPopup.warning:SetPoint("TOP", inviteConfirmPopup.text, "BOTTOM", 0, -8)
inviteConfirmPopup.warning:SetPoint("LEFT", 16, 0)
inviteConfirmPopup.warning:SetPoint("RIGHT", -16, 0)
inviteConfirmPopup.warning:SetJustifyH("CENTER")
inviteConfirmPopup.warning:SetTextColor(1, 0.5, 0)
inviteConfirmPopup.warning:SetWordWrap(true)

local inviteAcceptButton = CreateFrame("Button", nil, inviteConfirmPopup, "UIPanelButtonTemplate")
inviteAcceptButton:SetSize(120, 26)
inviteAcceptButton:SetPoint("BOTTOMLEFT", 16, 8)
inviteAcceptButton:SetText(L["ButtonAcceptInvite"])

local inviteDeclineButton = CreateFrame("Button", nil, inviteConfirmPopup, "UIPanelButtonTemplate")
inviteDeclineButton:SetSize(120, 26)
inviteDeclineButton:SetPoint("BOTTOMRIGHT", -16, 8)
inviteDeclineButton:SetText(L["ButtonDeclineInvite"])

inviteAcceptButton:SetScript("OnClick", function()
	local leaderName = inviteConfirmPopup.leaderName
	if leaderName then
		pendingInviteFromLeader = leaderName
		if GetNumGroupMembers() > 0 then
			LeaveParty()
			C_Timer.After(0.5, function()
				SendWhisperMessage(MESSAGE_TYPE.GROUP_INVITE_ACCEPT, leaderName)
			end)
		else
			SendWhisperMessage(MESSAGE_TYPE.GROUP_INVITE_ACCEPT, leaderName)
		end
	end
	inviteConfirmPopup:Hide()
end)

inviteDeclineButton:SetScript("OnClick", function()
	local leaderName = inviteConfirmPopup.leaderName
	if leaderName then
		SendWhisperMessage(MESSAGE_TYPE.GROUP_INVITE_DECLINE, leaderName)
	end
	inviteConfirmPopup:Hide()
end)

tinsert(UISpecialFrames, "GuildFoundToolsInviteConfirmPopup")

-- ============================================================
-- Invite confirmation message handlers
-- ============================================================

-- Received by applicant: leader wants to invite
GuildFoundTools.MessageHandlers.GROUP_INVITE_REQUEST = function(data, sender)
	if not data or not data.leaderName then return end

	inviteConfirmPopup.leaderName = data.leaderName
	inviteConfirmPopup.text:SetText(string.format(L["InviteConfirmText"], data.leaderName))

	if GetNumGroupMembers() > 0 then
		inviteConfirmPopup.warning:SetText(L["InviteConfirmLeaveWarning"])
		inviteConfirmPopup.warning:Show()
	else
		inviteConfirmPopup.warning:SetText("")
		inviteConfirmPopup.warning:Hide()
	end

	inviteConfirmPopup:Show()
	PlaySound(SOUNDKIT.READY_CHECK)
end

-- Received by leader: applicant accepted the invite
GuildFoundTools.MessageHandlers.GROUP_INVITE_ACCEPT = function(data, sender)
	if not GuildFoundTools.LFG.ownGroupId then return end

	local group = GuildFoundTools.groups[GuildFoundTools.LFG.ownGroupId]
	if not group then return end
	if not group.applicants or not group.applicants[sender] then return end

	C_PartyInfo.InviteUnit(sender)
end

-- Received by leader: applicant declined the invite
GuildFoundTools.MessageHandlers.GROUP_INVITE_DECLINE = function(data, sender)
	print("|cff00ccffGuildFound Tools:|r " .. string.format(L["InviteDeclinedMessage"], sender))
end

-- Auto-accept WoW party invite from the expected leader
GuildFoundTools.EventHandlers.PARTY_INVITE_REQUEST = function(inviterName)
	if not pendingInviteFromLeader then return end

	local shortName = strsplit("-", inviterName)
	if shortName == pendingInviteFromLeader then
		AcceptGroup()
		pendingInviteFromLeader = nil
		-- Hide the default invite popup
		StaticPopup_Hide("PARTY_INVITE")
	end
end

-- ============================================================
-- Role change handling
-- ============================================================

-- Receive role change from any guild member
GuildFoundTools.MessageHandlers.LFG_ROLE_CHANGE = function(data, sender)
	if not data or not data.groupId or not data.name or not data.role then return end

	local groupId = data.groupId
	local memberName = data.name
	local newRole = data.role

	local group = GuildFoundTools.groups[groupId]
	if not group then return end

	group.members[memberName] = newRole

	if group.leader == GetPlayerName() then
		SaveGroupToStorage(group)
	end

	if GuildFoundToolsMainFrame:IsShown() and GuildFoundTools.LFG.UpdateLFGUI then
		GuildFoundTools.LFG.UpdateLFGUI()
	end
end

-- Change the player's own role in their group
function GuildFoundTools.LFG.ChangeMyRole(newRole)
	local myGroup = GuildFoundTools.LFG.GetMyGroup and GuildFoundTools.LFG.GetMyGroup()
	if not myGroup then return end

	local playerName = GetPlayerName()
	myGroup.members[playerName] = newRole

	if myGroup.leader == playerName then
		SaveGroupToStorage(myGroup)
	end

	GuildFoundTools.Utils.Debounce("LFG_roleChange", 1, function()
		SendGuildMessage(MESSAGE_TYPE.LFG_ROLE_CHANGE, { groupId = myGroup.id, name = playerName, role = newRole })
	end)

	if GuildFoundTools.LFG.UpdateLFGUI then
		GuildFoundTools.LFG.UpdateLFGUI()
	end
end

-- Restore group session after login/reload
GuildFoundTools.EventHandlers.PLAYER_LOGIN = function()
	C_Timer.After(2, function()
		RestoreGroupFromStorage()
	end)
end

-- Register LFG event handlers
GuildFoundTools.EventHandlers.GROUP_JOINED = function()
	if GuildFoundTools.LFG.ownGroupId then
		-- If we joined someone else's party, remove our own tool group immediately
		-- (before PARTY_LEADER_CHANGED can transfer leadership)
		GuildFoundTools.LFG.RemoveGroup(GuildFoundTools.LFG.ownGroupId)
		print("|cff00ccffGuildFound Tools:|r " .. L["GroupRemovedJoinedOther"])
	end

	-- Check if anyone in the party is a tool group leader -> show role popup
	C_Timer.After(0.5, function()
		local numGroupMembers = GetNumGroupMembers()
		for index = 1, numGroupMembers do
			local name = GetRaidRosterInfo(index)
			if name then
				name = strsplit("-", name)
				for _, group in pairs(GuildFoundTools.groups) do
					if group.leader == name then
						-- Skip role popup if the player already signed up or is a member of this group
						local playerName = GetPlayerName()
						if (group.applicants and group.applicants[playerName]) or (group.members and group.members[playerName]) then
							return
						end
						if GuildFoundTools.LFG.ShowPartyRolePopup then
							GuildFoundTools.LFG.ShowPartyRolePopup(group.id)
						end
						return
					end
				end
			end
		end
	end)
end

GuildFoundTools.EventHandlers.GROUP_ROSTER_UPDATE = function()
	if not GuildFoundTools.LFG.ownGroupId then return end

	local group = GuildFoundTools.groups[GuildFoundTools.LFG.ownGroupId]
	if not group then return end

	UpdateGroupMembers()

	-- Auto-remove group from browser when maxMembers is reached
	if group.leader == GetPlayerName() and GuildFoundTools.LFG.GetMemberCount(group) >= group.maxMembers then
		GuildFoundTools.LFG.RemoveGroup(GuildFoundTools.LFG.ownGroupId)
		return
	end

	SaveGroupToStorage(group)
	BroadcastMemberSync()
end

GuildFoundTools.EventHandlers.GROUP_LEFT = function()
	if not GuildFoundTools.LFG.ownGroupId then return end

	local group = GuildFoundTools.groups[GuildFoundTools.LFG.ownGroupId]
	-- Don't remove the group if the player is the leader (e.g. party dissolved after a failed invite)
	if group and group.leader == GetPlayerName() then return end

	GuildFoundTools.LFG.RemoveGroup(GuildFoundTools.LFG.ownGroupId)
end

GuildFoundTools.EventHandlers.PARTY_LEADER_CHANGED = function()
	if GuildFoundTools.LFG.ownGroupId then
		local group = GuildFoundTools.groups[GuildFoundTools.LFG.ownGroupId]
		if group and group.leader == GetPlayerName() then
			-- Find the new party leader
			local numGroupMembers = GetNumGroupMembers()
			for index = 1, numGroupMembers do
				local name, rank = GetRaidRosterInfo(index)
				if name and rank == 2 then
					name = strsplit("-", name)
					if name ~= GetPlayerName() then
						-- Transfer leadership
						group.leader = name
						ClearGroupFromStorage()
						GuildFoundTools.LFG.ownGroupId = nil

						SendGuildMessage(MESSAGE_TYPE.GROUP_LEADER_CHANGE, { groupId = group.id, newLeader = name })
					end
					break
				end
			end
		end
	end

	if GuildFoundTools.LFG.UpdateLFGUI then
		GuildFoundTools.LFG.UpdateLFGUI()
	end
end

-- ============================================================
-- LFG UI
-- ============================================================

local contentFrame = GuildFoundTools.UI.GetContentFrame(1)

-- ============================================================
-- Role icons
-- ============================================================

local ROLE_TEXTURE, ROLE_TEXCOORDS, BEGINNER_FRIENDLY_TEXCOORD

local _, _, _, interfaceVersion = GetBuildInfo()
if interfaceVersion and interfaceVersion >= 20000 and interfaceVersion < 30000 then
	ROLE_TEXTURE = "Interface\\LFGFrame\\UILFGPrompts"
	ROLE_TEXCOORDS = {
		["TANK"] = { 0.63037109375, 0.75537109375, 0.25146484375, 0.37646484375 },
		["HEAL"] = { 0.00048828125, 0.12548828125, 0.75537109375, 0.88037109375 },
		["DD"]   = { 0.00048828125, 0.12548828125, 0.25146484375, 0.37646484375 },
	}
	BEGINNER_FRIENDLY_TEXCOORD = { 0.12646484375, 0.25146484375, 0.50341796875, 0.62841796875 }
else
	ROLE_TEXTURE = "Interface\\LFGFrame\\UILFGPromptSDF"
	ROLE_TEXCOORDS = {
		["TANK"] = { 0.75634765625, 0.88134765625, 0.25146484375, 0.37646484375 },
		["HEAL"] = { 0.12646484375, 0.25146484375, 0.25146484375, 0.37646484375 },
		["DD"]   = { 0.00048828125, 0.12548828125, 0.37744140625, 0.50244140625 },
	}
	BEGINNER_FRIENDLY_TEXCOORD = { 0.12646484375, 0.25146484375, 0.62939453125, 0.75439453125 }
end

-- Inline role icon markup for tooltips (|T...texture escape)
for roleName, coords in pairs(ROLE_TEXCOORDS) do
	ROLE_ICON_MARKUP[roleName] = string.format(
		"|T%s:14:14:0:0:1024:1024:%d:%d:%d:%d|t",
		ROLE_TEXTURE,
		coords[1] * 1024, coords[2] * 1024,
		coords[3] * 1024, coords[4] * 1024
	)
end

-- Guild roster lookup cache (rebuilt once per UI update)

local function BuildGuildMemberCache()
	wipe(guildMemberCache)
	local memberCount = GetNumGuildMembers()
	for index = 1, memberCount do
		local fullName, _, _, level, _, _, _, _, online, _, classFileName = GetGuildRosterInfo(index)
		if fullName then
			local shortName = strsplit("-", fullName)
			guildMemberCache[shortName] = {
				classFileName = classFileName,
				level = level,
				online = online,
			}
		end
	end
end

local function GetGuildMemberInfo(name)
	local info = guildMemberCache[name]
	if info then
		return info.classFileName, info.level, info.online
	end
	return nil, nil, false
end

-- ============================================================
-- Dungeon/Raid data for Classic
-- ============================================================

local DUNGEON_LOCALE_KEY = {
	[DUNGEON.RAGEFIRE_CHASM] = "DungeonRagefireChasm",
	[DUNGEON.WAILING_CAVERNS] = "DungeonWailingCaverns",
	[DUNGEON.THE_DEADMINES] = "DungeonTheDeadmines",
	[DUNGEON.SHADOWFANG_KEEP] = "DungeonShadowfangKeep",
	[DUNGEON.BLACKFATHOM_DEEPS] = "DungeonBlackfathomDeeps",
	[DUNGEON.THE_STOCKADE] = "DungeonTheStockade",
	[DUNGEON.GNOMEREGAN] = "DungeonGnomeregan",
	[DUNGEON.RAZORFEN_KRAUL] = "DungeonRazorfenKraul",
	[DUNGEON.SCARLET_MONASTERY_GRAVEYARD] = "DungeonScarletMonasteryGraveyard",
	[DUNGEON.SCARLET_MONASTERY_LIBRARY] = "DungeonScarletMonasteryLibrary",
	[DUNGEON.SCARLET_MONASTERY_ARMORY] = "DungeonScarletMonasteryArmory",
	[DUNGEON.SCARLET_MONASTERY_CATHEDRAL] = "DungeonScarletMonasteryCathedral",
	[DUNGEON.RAZORFEN_DOWNS] = "DungeonRazorfenDowns",
	[DUNGEON.ULDAMAN] = "DungeonUldaman",
	[DUNGEON.ZULFARRAK] = "DungeonZulFarrak",
	[DUNGEON.MARAUDON] = "DungeonMaraudon",
	[DUNGEON.THE_TEMPLE_OF_ATALHAKKAR] = "DungeonTheTempleOfAtalHakkar",
	[DUNGEON.BLACKROCK_DEPTHS] = "DungeonBlackrockDepths",
	[DUNGEON.LOWER_BLACKROCK_SPIRE] = "DungeonLowerBlackrockSpire",
	[DUNGEON.UPPER_BLACKROCK_SPIRE] = "DungeonUpperBlackrockSpire",
	[DUNGEON.DIRE_MAUL_EAST] = "DungeonDireMaulEast",
	[DUNGEON.DIRE_MAUL_WEST] = "DungeonDireMaulWest",
	[DUNGEON.DIRE_MAUL_NORTH] = "DungeonDireMaulNorth",
	[DUNGEON.SCHOLOMANCE] = "DungeonScholomance",
	[DUNGEON.STRATHOLME_MAIN_GATE] = "DungeonStratholmeMainGate",
	[DUNGEON.STRATHOLME_SERVICE_GATE] = "DungeonStratholmeServiceGate",
	[DUNGEON.MOLTEN_CORE] = "RaidMoltenCore",
	[DUNGEON.ONYXIAS_LAIR] = "RaidOnyxiasLair",
	[DUNGEON.BLACKWING_LAIR] = "RaidBlackwingLair",
	[DUNGEON.ZULGURUB] = "RaidZulGurub",
	[DUNGEON.RUINS_OF_AHNQIRAJ] = "RaidRuinsOfAhnQiraj",
	[DUNGEON.TEMPLE_OF_AHNQIRAJ] = "RaidTempleOfAhnQiraj",
	[DUNGEON.NAXXRAMAS] = "RaidNaxxramas",
}

local function GetDungeonName(dungeonId)
	local localeKey = DUNGEON_LOCALE_KEY[dungeonId]
	if localeKey then
		return L[localeKey]
	end
	return dungeonId
end

local DUNGEON_LIST = {
	["Dungeons"] = {
		{ id = DUNGEON.STRATHOLME_SERVICE_GATE, minLevel = 58, maxLevel = 60 },
		{ id = DUNGEON.STRATHOLME_MAIN_GATE, minLevel = 58, maxLevel = 60 },
		{ id = DUNGEON.SCHOLOMANCE, minLevel = 58, maxLevel = 60 },
		{ id = DUNGEON.DIRE_MAUL_NORTH, minLevel = 58, maxLevel = 60 },
		{ id = DUNGEON.DIRE_MAUL_WEST, minLevel = 55, maxLevel = 60 },
		{ id = DUNGEON.DIRE_MAUL_EAST, minLevel = 55, maxLevel = 60 },
		{ id = DUNGEON.UPPER_BLACKROCK_SPIRE, minLevel = 55, maxLevel = 60 },
		{ id = DUNGEON.LOWER_BLACKROCK_SPIRE, minLevel = 55, maxLevel = 60 },
		{ id = DUNGEON.BLACKROCK_DEPTHS, minLevel = 52, maxLevel = 60 },
		{ id = DUNGEON.THE_TEMPLE_OF_ATALHAKKAR, minLevel = 50, maxLevel = 60 },
		{ id = DUNGEON.MARAUDON, minLevel = 46, maxLevel = 55 },
		{ id = DUNGEON.ZULFARRAK, minLevel = 44, maxLevel = 54 },
		{ id = DUNGEON.ULDAMAN, minLevel = 41, maxLevel = 51 },
		{ id = DUNGEON.RAZORFEN_DOWNS, minLevel = 37, maxLevel = 46 },
		{ id = DUNGEON.SCARLET_MONASTERY_CATHEDRAL, minLevel = 35, maxLevel = 45 },
		{ id = DUNGEON.SCARLET_MONASTERY_ARMORY, minLevel = 32, maxLevel = 42 },
		{ id = DUNGEON.SCARLET_MONASTERY_LIBRARY, minLevel = 29, maxLevel = 39 },
		{ id = DUNGEON.GNOMEREGAN, minLevel = 29, maxLevel = 38 },
		{ id = DUNGEON.RAZORFEN_KRAUL, minLevel = 29, maxLevel = 38 },
		{ id = DUNGEON.SCARLET_MONASTERY_GRAVEYARD, minLevel = 26, maxLevel = 36 },
		{ id = DUNGEON.BLACKFATHOM_DEEPS, minLevel = 24, maxLevel = 32 },
		{ id = DUNGEON.THE_STOCKADE, minLevel = 24, maxLevel = 32 },
		{ id = DUNGEON.SHADOWFANG_KEEP, minLevel = 22, maxLevel = 30 },
		{ id = DUNGEON.THE_DEADMINES, minLevel = 17, maxLevel = 26 },
		{ id = DUNGEON.WAILING_CAVERNS, minLevel = 17, maxLevel = 24 },
		{ id = DUNGEON.RAGEFIRE_CHASM, minLevel = 13, maxLevel = 18 },
	},
	["Raids"] = {
		{ id = DUNGEON.MOLTEN_CORE, minLevel = 60, maxLevel = 60 },
		{ id = DUNGEON.ONYXIAS_LAIR, minLevel = 60, maxLevel = 60 },
		{ id = DUNGEON.BLACKWING_LAIR, minLevel = 60, maxLevel = 60 },
		{ id = DUNGEON.ZULGURUB, minLevel = 60, maxLevel = 60 },
		{ id = DUNGEON.RUINS_OF_AHNQIRAJ, minLevel = 60, maxLevel = 60 },
		{ id = DUNGEON.TEMPLE_OF_AHNQIRAJ, minLevel = 60, maxLevel = 60 },
		{ id = DUNGEON.NAXXRAMAS, minLevel = 60, maxLevel = 60 },
	},
	["Custom"] = {},
}

local function GetDungeonLevelColor(playerLevel, minLevel, maxLevel)
	if playerLevel < minLevel then
		-- Player is below dungeon range, color based on minLevel
		local diff = minLevel - playerLevel
		if diff >= 5 then
			return 1, 0, 0 -- red
		elseif diff >= 3 then
			return 1, 0.5, 0 -- orange
		end
	elseif playerLevel > maxLevel then
		return 0.5, 0.5, 0.5 -- gray
	end

	-- Player is within dungeon range
	return 1, 1, 0 -- yellow
end

local function IsDungeonRed(dungeon)
	local playerLevel = UnitLevel("player") or 60

	return playerLevel < dungeon.minLevel and (dungeon.minLevel - playerLevel) >= 5
end

local function IsDungeonVisible(dungeon)
	return GuildFoundTools.UI.showAllLevelRanges or not IsDungeonRed(dungeon)
end

local function IsLevelRed(level)
	local playerLevel = UnitLevel("player") or 60
	return playerLevel < level and level - playerLevel >= 5
end

local function IsGroupVisible(group)
	if GuildFoundTools.UI.showAllLevelRanges then return true end

	local dungeon = group.dungeon and group.dungeon ~= "" and DUNGEON_BY_ID[group.dungeon]
	if dungeon then
		return not IsDungeonRed(dungeon)
	end

	if group.leaderLevel then
		return not IsLevelRed(group.leaderLevel)
	end

	return true
end

local function GetVisibleDungeons(category)
	local dungeons = DUNGEON_LIST[category] or {}
	local visible = {}
	for _, dungeon in ipairs(dungeons) do
		if IsDungeonVisible(dungeon) then
			table.insert(visible, dungeon)
		end
	end
	return visible
end

local function GetDungeonDisplayText(dungeon)
	local dungeonName = GetDungeonName(dungeon.id)
	local playerLevel = UnitLevel("player") or 60
	local red, green, blue = GetDungeonLevelColor(playerLevel, dungeon.minLevel, dungeon.maxLevel)
	local colorCode = string.format("|cff%02x%02x%02x", red * 255, green * 255, blue * 255)
	local isGray = (red == 0.5 and green == 0.5 and blue == 0.5)
	if isGray then
		return colorCode .. dungeonName .. " (" .. dungeon.minLevel .. " - " .. dungeon.maxLevel .. ")|r"
	end
	return dungeonName .. " " .. colorCode .. "(" .. dungeon.minLevel .. " - " .. dungeon.maxLevel .. ")|r"
end

for _, category in pairs(DUNGEON_LIST) do
	for _, dungeon in ipairs(category) do
		DUNGEON_BY_ID[dungeon.id] = dungeon
	end
end

local function GetDungeonDisplayTextById(dungeonId)
	local dungeon = DUNGEON_BY_ID[dungeonId]
	if dungeon then
		return GetDungeonDisplayText(dungeon)
	end
	return GetDungeonName(dungeonId)
end

-- No groups hint
local noGroupsText = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
noGroupsText:SetPoint("CENTER", 0, -20)
noGroupsText:SetText(L["NoGroupsAvailable"])
noGroupsText:SetJustifyH("CENTER")

-- ============================================================
-- Bottom action bar
-- ============================================================

local actionBar = CreateFrame("Frame", nil, contentFrame)
actionBar:SetHeight(ACTION_BAR_HEIGHT)
actionBar:SetPoint("BOTTOMLEFT", 0, 0)
actionBar:SetPoint("BOTTOMRIGHT", 0, 0)

-- Left side: selection-based buttons (Anmelden / Verlassen)
local signupButton = CreateFrame("Button", nil, actionBar, "UIPanelButtonTemplate")
signupButton:SetSize(120, 24)
signupButton:SetPoint("LEFT", 0, 0)
signupButton:SetText(L["ButtonSignUp"])
signupButton:Hide()

-- ============================================================
-- Role selection popup (for signup)
-- ============================================================

local rolePopup = CreateFrame("Frame", "GuildFoundToolsRolePopup", UIParent, "BackdropTemplate")
rolePopup:SetSize(130, 50)
rolePopup:SetFrameStrata("DIALOG")
rolePopup:SetBackdrop({
	bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileSize = 16,
	edgeSize = 12,
	insets = { left = 2, right = 2, top = 2, bottom = 2 },
})
rolePopup:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
rolePopup:Hide()
rolePopup:EnableMouse(true)

rolePopup.groupId = nil

for index, roleName in ipairs(ROLE_NAMES) do
	local button = CreateFrame("Button", nil, rolePopup)
	button:SetSize(32, 32)
	button:SetPoint("LEFT", 8 + (index - 1) * 40, 0)

	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetAllPoints()
	button.icon:SetTexture(ROLE_TEXTURE)
	button.icon:SetTexCoord(unpack(ROLE_TEXCOORDS[roleName]))

	button:SetScript("OnClick", function()
		if rolePopup.groupId then
			GuildFoundTools.LFG.SignupForGroup(rolePopup.groupId, roleName)
		end
		rolePopup:Hide()
	end)

	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(L[roleName])
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

tinsert(UISpecialFrames, "GuildFoundToolsRolePopup")

-- ============================================================
-- Scroll frame for group listing
-- ============================================================

local scrollFrame = CreateFrame("ScrollFrame", "GuildFoundToolsLFGScrollFrame", contentFrame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 0, 0)
scrollFrame:SetPoint("BOTTOMRIGHT", -16, ACTION_BAR_HEIGHT)

local scrollBar = scrollFrame.ScrollBar or _G["GuildFoundToolsLFGScrollFrameScrollBar"]
scrollBar:ClearAllPoints()
scrollBar:SetPoint("TOPLEFT", scrollFrame, "TOPRIGHT", 0, -16)
scrollBar:SetPoint("BOTTOMLEFT", scrollFrame, "BOTTOMRIGHT", 0, -16)

local scrollChild = CreateFrame("Frame", "GuildFoundToolsLFGScrollChild", scrollFrame)
scrollChild:SetSize(scrollFrame:GetWidth(), 1)
scrollFrame:SetScrollChild(scrollChild)

-- ============================================================
-- Group row pool
-- ============================================================

-- Right-click context menu using MenuUtil
local function ShowContextMenu(owner, group)
	MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
		local playerName = UnitName("player")

		-- Send message
		rootDescription:CreateButton(L["ContextMenuSendMessage"], function()
			ChatFrame_SendTell(group.leader)
		end)

		-- Group invite (only for leader, only if target is alone)
		if group.leader ~= playerName and GuildFoundTools.LFG.GetMemberCount(group) == 1 then
			if GuildFoundTools.LFG.ownGroupId then
				rootDescription:CreateButton(L["ContextMenuInvitePlayer"], function()
					C_PartyInfo.InviteUnit(group.leader)
				end)
			end
		end
	end)
end

local function CreateGroupRow(parent)
	local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
	row:SetHeight(ROW_HEIGHT)
	row:SetBackdrop({
		bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 12,
		insets = { left = 2, right = 2, top = 2, bottom = 2 },
	})
	row:SetBackdropColor(0, 0, 0, 0.6)

	-- Selected highlight
	row.selectedTexture = row:CreateTexture(nil, "BACKGROUND")
	row.selectedTexture:SetAllPoints()
	row.selectedTexture:SetColorTexture(0.2, 0.4, 0.8, 0.3)
	row.selectedTexture:Hide()

	-- Hover highlight
	row.hoverTexture = row:CreateTexture(nil, "BACKGROUND")
	row.hoverTexture:SetAllPoints()
	row.hoverTexture:SetColorTexture(1, 1, 1, 0.05)
	row.hoverTexture:Hide()

	-- Leader name (top left)
	row.leaderText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.leaderText:SetPoint("TOPLEFT", 8, -5)
	row.leaderText:SetJustifyH("LEFT")

	-- Dungeon/description (bottom left)
	row.dungeonText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.dungeonText:SetPoint("TOPLEFT", 8, -20)
	row.dungeonText:SetPoint("RIGHT", -140, 0)
	row.dungeonText:SetJustifyH("LEFT")
	row.dungeonText:SetMaxLines(1)

	-- Beginner friendly icon (small, on the right before role slots)
	row.beginnerFriendlyIcon = row:CreateTexture(nil, "ARTWORK")
	row.beginnerFriendlyIcon:SetSize(16, 16)
	row.beginnerFriendlyIcon:SetTexture(ROLE_TEXTURE)
	row.beginnerFriendlyIcon:SetTexCoord(unpack(BEGINNER_FRIENDLY_TEXCOORD))
	row.beginnerFriendlyIcon:Hide()

	-- Role icon slots (up to MAX_ROLE_SLOTS, 20x20 each, anchored from RIGHT)
	row.roleSlots = {}
	for index = 1, MAX_ROLE_SLOTS do
		local slot = row:CreateTexture(nil, "ARTWORK")
		slot:SetSize(20, 20)
		slot.memberName = nil
		slot.memberRole = nil
		row.roleSlots[index] = slot
	end

	-- Role count display (for groups with >5 members)
	row.roleCounts = {}
	local roleCountNames = { "TANK", "HEAL", "DD" }
	for index, roleName in ipairs(roleCountNames) do
		local icon = row:CreateTexture(nil, "ARTWORK")
		icon:SetSize(16, 16)
		icon:SetTexture(ROLE_TEXTURE)
		icon:SetTexCoord(unpack(ROLE_TEXCOORDS[roleName]))
		icon:Hide()

		local count = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		count:SetPoint("LEFT", icon, "RIGHT", 2, 0)
		count:Hide()

		row.roleCounts[index] = { icon = icon, count = count, role = roleName }
	end

	-- Tooltip area over role icons
	row.roleArea = CreateFrame("Frame", nil, row)
	row.roleArea:SetSize(MAX_ROLE_SLOTS * 22 + 20, ROW_HEIGHT)
	row.roleArea:SetPoint("RIGHT", -4, 0)

	-- Click handler for row selection + right-click context menu
	row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	row:SetScript("OnClick", function(self, button)
		if button == "RightButton" then
			local group = GuildFoundTools.groups[self.groupId]
			if not group then return end
			if group.members[UnitName("player")] then return end

			ShowContextMenu(self, group)
		else
			selectedGroupId = self.groupId
			GuildFoundTools.LFG.UpdateLFGUI()
		end
	end)

	row:SetScript("OnEnter", function(self)
		if self.groupId ~= selectedGroupId then
			self.hoverTexture:Show()
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

		-- Beginner friendly hint (green, top of tooltip)
		if self.groupBeginnerFriendly then
			GameTooltip:AddLine(L["BeginnerFriendly"], 0, 1, 0)
			GameTooltip:AddLine(" ")
		end

		-- Members header + list (with role icon, class color, level)
		if self.roleArea.members and #self.roleArea.members > 0 then
			local tankCount, healCount, ddCount = 0, 0, 0
			for _, memberInfo in ipairs(self.roleArea.members) do
				local roleIcon = ROLE_ICON_MARKUP[memberInfo.role] or ROLE_ICON_MARKUP["DD"]
				local classFileName, level = GetGuildMemberInfo(memberInfo.name)

				local red, green, blue = 1, 1, 1
				if classFileName and RAID_CLASS_COLORS[classFileName] then
					red = RAID_CLASS_COLORS[classFileName].r
					green = RAID_CLASS_COLORS[classFileName].g
					blue = RAID_CLASS_COLORS[classFileName].b
				end

				local levelText = ""
				if level and level > 0 then
					levelText = " |cff888888Lvl " .. level .. "|r"
				end

				local leaderIcon = ""
				if memberInfo.name == self.groupLeader then
					leaderIcon = "|TInterface\\GroupFrame\\UI-Group-LeaderIcon:14:14|t "
				end

				GameTooltip:AddLine(leaderIcon .. roleIcon .. " " .. memberInfo.name .. levelText, red, green, blue)

				if memberInfo.role == "TANK" then
					tankCount = tankCount + 1
				elseif memberInfo.role == "HEAL" then
					healCount = healCount + 1
				else
					ddCount = ddCount + 1
				end
			end

			-- Member count with role breakdown
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine(string.format(L["TooltipMembersSummary"], #self.roleArea.members, self.groupMaxMembers or "?", tankCount, healCount, ddCount))
		end

		-- Description (if exists)
		if self.groupDescription and self.groupDescription ~= "" then
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine(self.groupDescription, 0.6, 0.6, 0.6, true)
		end

		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", function(self)
		self.hoverTexture:Hide()
		GameTooltip:Hide()
	end)

	return row
end

local groupRowPool = CreatePool(scrollChild, CreateGroupRow, function(row)
	row.selectedTexture:Hide()
	row.hoverTexture:Hide()
end)

-- ============================================================
-- Update action bar based on selected group
-- ============================================================

local withdrawButton = CreateFrame("Button", nil, actionBar, "UIPanelButtonTemplate")
withdrawButton:SetSize(120, 24)
withdrawButton:SetPoint("LEFT", 0, 0)
withdrawButton:SetText(L["ButtonWithdraw"])
withdrawButton:Hide()

local pendingText = actionBar:CreateFontString(nil, "OVERLAY", "GameFontDisable")
pendingText:SetPoint("LEFT", withdrawButton, "RIGHT", 8, 0)
pendingText:SetText(L["ApplicationPending"])
pendingText:Hide()

local function UpdateActionBar()
	signupButton:Hide()
	withdrawButton:Hide()
	pendingText:Hide()

	local playerName = UnitName("player")
	local ownGroupId = GuildFoundTools.LFG.ownGroupId

	-- Selection-based buttons (only for non-own groups)
	if selectedGroupId and selectedGroupId ~= ownGroupId then
		local group = GuildFoundTools.groups[selectedGroupId]
		if group then
			if group.applicants and group.applicants[playerName] then
				withdrawButton:Show()
				pendingText:Show()
			else
				signupButton:Show()
				signupButton:SetEnabled(GuildFoundTools.LFG.GetMemberCount(group) < group.maxMembers)
			end
		end
	end
end

-- Wire up action bar buttons
signupButton:SetScript("OnClick", function(self)
	if not selectedGroupId then return end
	rolePopup.groupId = selectedGroupId
	rolePopup:ClearAllPoints()
	rolePopup:SetPoint("BOTTOM", self, "TOP", 0, 4)
	rolePopup:Show()
end)

withdrawButton:SetScript("OnClick", function()
	if not selectedGroupId then return end
	GuildFoundTools.LFG.LeaveGroup(selectedGroupId)
end)

-- ============================================================
-- Update group listing
-- ============================================================

function GuildFoundTools.LFG.UpdateLFGUI(skipCreateGroupTab)
	BuildGuildMemberCache()
	groupRowPool:ReleaseAll()

	local groups = GuildFoundTools.groups

	-- Update tab 2 text based on group state
	if not skipCreateGroupTab then
		GuildFoundTools.LFG.UpdateCreateGroupTab()
	end

	-- Validate selected group still exists
	if selectedGroupId and not groups[selectedGroupId] then
		selectedGroupId = nil
	end

	-- Filter and sort groups by member count (most members first)
	local sortedGroups = {}
	for _, group in pairs(groups) do
		if IsGroupVisible(group) then
			table.insert(sortedGroups, group)
		end
	end
	table.sort(sortedGroups, function(a, b)
		return GuildFoundTools.LFG.GetMemberCount(a) > GuildFoundTools.LFG.GetMemberCount(b)
	end)

	local hasGroups = #sortedGroups > 0
	noGroupsText:SetShown(not hasGroups)
	scrollFrame:SetShown(hasGroups)
	actionBar:SetShown(hasGroups)

	if not hasGroups then
		selectedGroupId = nil
		UpdateActionBar()
		return
	end

	local yOffset = 0

	for _, group in ipairs(sortedGroups) do
		local row = groupRowPool:Acquire()
		row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -yOffset)
		row:SetPoint("RIGHT", scrollChild, "RIGHT", 0, 0)
		row.groupId = group.id

		-- Selected highlight
		row.selectedTexture:SetShown(group.id == selectedGroupId)

		-- Leader name (top left)
		row.leaderText:SetText(group.leader or "?")

		-- Dungeon/description line (bottom left)
		local descriptionLine = ""
		if group.dungeon and group.dungeon ~= "" then
			descriptionLine = GetDungeonDisplayTextById(group.dungeon)
		elseif group.description and group.description ~= "" then
			descriptionLine = group.description
		else
			descriptionLine = group.category or "Custom"
		end
		row.dungeonText:SetText(descriptionLine)
		row.groupDescription = group.description or ""
		row.groupMaxMembers = group.maxMembers
		row.groupLeader = group.leader
		row.groupBeginnerFriendly = group.beginnerFriendly

		-- Beginner friendly icon
		row.beginnerFriendlyIcon:SetShown(group.beginnerFriendly == true)

		-- Build member lists
		local memberInfoList = {}
		for memberName, role in pairs(group.members) do
			table.insert(memberInfoList, { name = memberName, role = role })
		end

		-- Tooltip: leader first, then by role priority
		table.sort(memberInfoList, function(a, b)
			if a.name == group.leader then return true end
			if b.name == group.leader then return false end
			return (ROLE_SORT_ORDER[a.role] or 3) < (ROLE_SORT_ORDER[b.role] or 3)
		end)
		row.roleArea.members = memberInfoList

		-- Row icons: sorted strictly by role (TANK, HEAL, DD)
		local iconSortedMembers = {}
		for memberName, role in pairs(group.members) do
			table.insert(iconSortedMembers, { name = memberName, role = role })
		end
		table.sort(iconSortedMembers, function(a, b)
			return (ROLE_SORT_ORDER[a.role] or 3) < (ROLE_SORT_ORDER[b.role] or 3)
		end)

		-- Anchor beginner friendly icon
		local rightEdgeOffset = -8
		if group.beginnerFriendly then
			row.beginnerFriendlyIcon:ClearAllPoints()
			row.beginnerFriendlyIcon:SetPoint("RIGHT", row, "RIGHT", rightEdgeOffset, 0)
			rightEdgeOffset = rightEdgeOffset - 20
		end

		if group.maxMembers > MAX_ROLE_SLOTS then
			-- Large group: show role count summary (Tank X, Heal X, DD X)
			for slotIndex = 1, MAX_ROLE_SLOTS do
				row.roleSlots[slotIndex]:Hide()
			end

			local roleTotals = { ["TANK"] = 0, ["HEAL"] = 0, ["DD"] = 0 }
			for _, info in ipairs(memberInfoList) do
				local role = info.role or "DD"
				roleTotals[role] = (roleTotals[role] or 0) + 1
			end

			-- Position from right to left: DD, HEAL, TANK (so TANK ends up leftmost)
			local offset = rightEdgeOffset
			for index = #row.roleCounts, 1, -1 do
				local roleCount = row.roleCounts[index]
				roleCount.count:SetText(roleTotals[roleCount.role] or 0)
				roleCount.count:ClearAllPoints()
				roleCount.count:SetPoint("RIGHT", row, "RIGHT", offset, 0)
				roleCount.count:Show()

				local countWidth = roleCount.count:GetStringWidth()
				roleCount.icon:ClearAllPoints()
				roleCount.icon:SetPoint("RIGHT", row, "RIGHT", offset - countWidth - 2, 0)
				roleCount.icon:Show()

				offset = offset - countWidth - 2 - 16 - 8
			end
		else
			-- Small group: show individual role icon slots
			for _, roleCount in ipairs(row.roleCounts) do
				roleCount.icon:Hide()
				roleCount.count:Hide()
			end

			local maxSlots = group.maxMembers

			for slotIndex = 1, MAX_ROLE_SLOTS do
				local slot = row.roleSlots[slotIndex]
				if slotIndex <= maxSlots then
					slot:ClearAllPoints()
					slot:SetPoint("RIGHT", row, "RIGHT", rightEdgeOffset - (slotIndex - 1) * 22, 0)
					slot:SetTexture(ROLE_TEXTURE)

					local memberIndex = maxSlots - slotIndex + 1
					if memberIndex <= #iconSortedMembers then
						local role = iconSortedMembers[memberIndex].role
						slot:SetTexCoord(unpack(ROLE_TEXCOORDS[role] or ROLE_TEXCOORDS["DD"]))
						slot:SetDesaturated(false)
						slot:SetAlpha(1)
					else
						slot:SetTexCoord(unpack(ROLE_TEXCOORDS["DD"]))
						slot:SetDesaturated(true)
						slot:SetAlpha(0.2)
					end
					slot:Show()
				else
					slot:Hide()
				end
			end
		end

		yOffset = yOffset + ROW_HEIGHT + ROW_SPACING
	end

	scrollChild:SetHeight(yOffset)

	UpdateActionBar()
end

-- Initial update when tab 1 is shown
contentFrame:SetScript("OnShow", function()
	GuildFoundTools.LFG.UpdateLFGUI()
end)

-- ============================================================
-- Create Group / My Group Tab (Tab 2)
-- ============================================================

local createGroupContent = GuildFoundTools.UI.GetContentFrame(2)

-- Helper: find the group the player belongs to (own or as member)
function GuildFoundTools.LFG.GetMyGroup()
	if GuildFoundTools.LFG.ownGroupId then
		return GuildFoundTools.groups[GuildFoundTools.LFG.ownGroupId]
	end
	local playerName = GetPlayerName()
	for _, group in pairs(GuildFoundTools.groups) do
		if group.members[playerName] then
			return group
		end
	end
	return nil
end

-- Check if player is an applicant to any group
function GuildFoundTools.LFG.GetMyApplicationGroup()
	local playerName = GetPlayerName()
	for _, group in pairs(GuildFoundTools.groups) do
		if group.applicants and group.applicants[playerName] then
			return group
		end
	end
	return nil
end

local function UpdateRoleButtons()
	for _, roleButton in ipairs(roleButtons) do
		if roleButton.roleKey == selectedRole then
			roleButton.icon:SetDesaturated(false)
			roleButton:SetAlpha(1)
		else
			roleButton.icon:SetDesaturated(true)
			roleButton:SetAlpha(0.4)
		end
	end
end

-- Container to center all role buttons
local roleContainer = CreateFrame("Frame", nil, createGroupContent)
roleContainer:SetSize(1, ROLE_BUTTON_SIZE)
roleContainer:SetPoint("TOP", 0, -8)

for index, roleName in ipairs(ROLE_NAMES) do
	local roleButton = CreateFrame("Button", nil, roleContainer)
	roleButton:SetSize(ROLE_BUTTON_SIZE, ROLE_BUTTON_SIZE)
	roleButton:SetPoint("LEFT", (index - 1) * (ROLE_BUTTON_SIZE + ROLE_BUTTON_SPACING), 0)
	roleButton.roleKey = roleName

	roleButton.icon = roleButton:CreateTexture(nil, "ARTWORK")
	roleButton.icon:SetAllPoints()
	roleButton.icon:SetTexture(ROLE_TEXTURE)
	roleButton.icon:SetTexCoord(unpack(ROLE_TEXCOORDS[roleName]))

	roleButton:SetScript("OnClick", function(self)
		if selectedRole == self.roleKey then return end
		selectedRole = self.roleKey

		-- In "My Group" mode (not editing, not creating): change role immediately
		local myGroup = GuildFoundTools.LFG.GetMyGroup and GuildFoundTools.LFG.GetMyGroup()
		if myGroup and not isEditingMyGroup then
			GuildFoundTools.LFG.ChangeMyRole(self.roleKey)
		end

		UpdateRoleButtons()
	end)

	roleButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(L[self.roleKey])
		GameTooltip:Show()
	end)
	roleButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

	table.insert(roleButtons, roleButton)
end

-- Beginner friendly button (next to role buttons)
local beginnerFriendlyButton = CreateFrame("Button", nil, roleContainer)
beginnerFriendlyButton:SetSize(ROLE_BUTTON_SIZE, ROLE_BUTTON_SIZE)
beginnerFriendlyButton:SetPoint("LEFT", 3 * (ROLE_BUTTON_SIZE + ROLE_BUTTON_SPACING), 0)

beginnerFriendlyButton.icon = beginnerFriendlyButton:CreateTexture(nil, "ARTWORK")
beginnerFriendlyButton.icon:SetAllPoints()
beginnerFriendlyButton.icon:SetTexture(ROLE_TEXTURE)
beginnerFriendlyButton.icon:SetTexCoord(unpack(BEGINNER_FRIENDLY_TEXCOORD))
beginnerFriendlyButton.icon:SetDesaturated(true)
beginnerFriendlyButton:SetAlpha(0.4)

local function UpdateBeginnerFriendlyButton()
	if selectedBeginnerFriendly then
		beginnerFriendlyButton.icon:SetDesaturated(false)
		beginnerFriendlyButton:SetAlpha(1)
	else
		beginnerFriendlyButton.icon:SetDesaturated(true)
		beginnerFriendlyButton:SetAlpha(0.4)
	end
end

beginnerFriendlyButton:SetScript("OnClick", function()
	selectedBeginnerFriendly = not selectedBeginnerFriendly
	UpdateBeginnerFriendlyButton()
end)

beginnerFriendlyButton:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:AddLine(L["BeginnerFriendly"], 0, 1, 0)
	GameTooltip:AddLine(L["BeginnerFriendlyTooltip"], 1, 0.82, 0, true)
	GameTooltip:Show()
end)
beginnerFriendlyButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

local function UpdateRoleContainerLayout()
	local buttonCount = #roleButtons
	if beginnerFriendlyButton:IsShown() then
		buttonCount = buttonCount + 1
	end
	local totalWidth = buttonCount * ROLE_BUTTON_SIZE + (buttonCount - 1) * ROLE_BUTTON_SPACING
	roleContainer:SetWidth(totalWidth)

	for index, roleButton in ipairs(roleButtons) do
		roleButton:ClearAllPoints()
		roleButton:SetPoint("LEFT", (index - 1) * (ROLE_BUTTON_SIZE + ROLE_BUTTON_SPACING), 0)
	end

	beginnerFriendlyButton:ClearAllPoints()
	beginnerFriendlyButton:SetPoint("LEFT", #roleButtons * (ROLE_BUTTON_SIZE + ROLE_BUTTON_SPACING), 0)
end

-- Category dropdown
local categoryLabel = createGroupContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
categoryLabel:SetPoint("TOPLEFT", 4, FORM_TOP_OFFSET)
categoryLabel:SetText(L["LabelCategory"])

local categoryDropdown = CreateFrame("Frame", "GuildFoundToolsCategoryDropdown", createGroupContent, "UIDropDownMenuTemplate")
categoryDropdown:SetPoint("TOPLEFT", -12, FORM_TOP_OFFSET - 12)
UIDropDownMenu_SetWidth(categoryDropdown, 140)
UIDropDownMenu_SetText(categoryDropdown, "Dungeons")

-- Dungeon dropdown
local dungeonLabel = createGroupContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
dungeonLabel:SetPoint("TOPLEFT", 4, FORM_TOP_OFFSET - 42)
dungeonLabel:SetText(L["LabelDungeonRaid"])

local dungeonDropdown = CreateFrame("Frame", "GuildFoundToolsDungeonDropdown", createGroupContent, "UIDropDownMenuTemplate")
dungeonDropdown:SetPoint("TOPLEFT", -12, FORM_TOP_OFFSET - 54)
UIDropDownMenu_SetWidth(dungeonDropdown, 280)
UIDropDownMenu_SetText(dungeonDropdown, L["DropdownSelect"])

local function IsDungeonSelectionValid()
	local requiresDungeon = (selectedCategory == "Dungeons" or selectedCategory == "Raids")
	return not requiresDungeon or (selectedDungeon ~= "")
end

local function UpdateFormValidation()
	if not rightButton then return end

	if IsDungeonSelectionValid() then
		rightButton:Enable()
	else
		rightButton:Disable()
	end
end

local function InitDungeonDropdown(self, level)
	local dungeons = GetVisibleDungeons(selectedCategory)
	for _, dungeon in ipairs(dungeons) do
		local info = UIDropDownMenu_CreateInfo()
		info.text = GetDungeonDisplayText(dungeon)
		info.func = function()
			selectedDungeon = dungeon.id
			UIDropDownMenu_SetText(dungeonDropdown, GetDungeonDisplayText(dungeon))
			CloseDropDownMenus()
			UpdateFormValidation()
		end
		info.checked = (selectedDungeon == dungeon.id)
		UIDropDownMenu_AddButton(info)
	end
end

UIDropDownMenu_Initialize(dungeonDropdown, InitDungeonDropdown)

local function InitCategoryDropdown(self, level)
	for _, category in ipairs(CATEGORIES) do
		local info = UIDropDownMenu_CreateInfo()
		info.text = category
		info.func = function()
			selectedCategory = category
			selectedDungeon = ""
			UIDropDownMenu_SetText(categoryDropdown, category)
			UIDropDownMenu_SetText(dungeonDropdown, L["DropdownSelect"])
			UIDropDownMenu_Initialize(dungeonDropdown, InitDungeonDropdown)
			CloseDropDownMenus()

			if category == "Custom" then
				UIDropDownMenu_DisableDropDown(dungeonDropdown)
			else
				UIDropDownMenu_EnableDropDown(dungeonDropdown)
			end
			UpdateFormValidation()
		end
		info.checked = (selectedCategory == category)
		UIDropDownMenu_AddButton(info)
	end
end

UIDropDownMenu_Initialize(categoryDropdown, InitCategoryDropdown)

-- Description editbox
local descriptionLabel = createGroupContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
descriptionLabel:SetPoint("TOPLEFT", 4, FORM_TOP_OFFSET - 86)
descriptionLabel:SetText(L["LabelDescription"])

local descriptionEditBox = CreateFrame("EditBox", "GuildFoundToolsDescriptionEditBox", createGroupContent, "InputBoxTemplate")
descriptionEditBox:SetSize(290, 24)
descriptionEditBox:SetPoint("TOPLEFT", 9, FORM_TOP_OFFSET - 100)
descriptionEditBox:SetAutoFocus(false)
descriptionEditBox:SetMaxLetters(100)
descriptionEditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
descriptionEditBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

-- Max members
local maxMembersLabel = createGroupContent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
maxMembersLabel:SetPoint("TOPLEFT", 4, FORM_TOP_OFFSET - 132)
maxMembersLabel:SetText(L["LabelMaxMembers"])

local maxMembersEditBox = CreateFrame("EditBox", "GuildFoundToolsMaxMembersEditBox", createGroupContent, "InputBoxTemplate")
maxMembersEditBox:SetSize(50, 24)
maxMembersEditBox:SetPoint("TOPLEFT", 9, FORM_TOP_OFFSET - 146)
maxMembersEditBox:SetAutoFocus(false)
maxMembersEditBox:SetNumeric(true)
maxMembersEditBox:SetMaxLetters(2)
maxMembersEditBox:SetText("5")
maxMembersEditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
maxMembersEditBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
maxMembersEditBox:SetScript("OnTextChanged", function(self)
	local value = tonumber(self:GetText())
	if value and value > 40 then
		self:SetText("40")
	end
end)

-- Bottom buttons (shared between all states)
leftButton = CreateFrame("Button", nil, createGroupContent, "UIPanelButtonTemplate")
leftButton:SetSize(140, 26)
leftButton:SetPoint("BOTTOMLEFT", 0, 0)
leftButton:SetText(L["ButtonCreate"])

rightButton = CreateFrame("Button", nil, createGroupContent, "UIPanelButtonTemplate")
rightButton:SetSize(140, 26)
rightButton:SetPoint("BOTTOMRIGHT", 0, 0)
rightButton:Hide()
rightButton:SetMotionScriptsWhileDisabled(true)
rightButton:SetScript("OnEnter", function(self)
	if self:IsEnabled() then return end
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	if selectedCategory == "Dungeons" then
		GameTooltip:SetText(L["ValidationNoDungeonSelected"])
	elseif selectedCategory == "Raids" then
		GameTooltip:SetText(L["ValidationNoRaidSelected"])
	end
	GameTooltip:Show()
end)
rightButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Placeholder text for "My Group" list view (when no applicants yet)
local myGroupInfoText = createGroupContent:CreateFontString(nil, "OVERLAY", "GameFontDisable")
myGroupInfoText:SetPoint("CENTER", 0, 0)
myGroupInfoText:SetJustifyH("CENTER")
myGroupInfoText:SetText(L["NoApplicantsYet"])
myGroupInfoText:Hide()

-- Applicants scroll frame for "My Group" tab
local applicantsScrollFrame = CreateFrame("ScrollFrame", "GuildFoundToolsApplicantsScrollFrame", createGroupContent, "UIPanelScrollFrameTemplate")
applicantsScrollFrame:SetPoint("TOPLEFT", 0, FORM_TOP_OFFSET)
applicantsScrollFrame:SetPoint("BOTTOMRIGHT", -16, 30)
applicantsScrollFrame:Hide()

local applicantsScrollBar = applicantsScrollFrame.ScrollBar or _G["GuildFoundToolsApplicantsScrollFrameScrollBar"]
applicantsScrollBar:ClearAllPoints()
applicantsScrollBar:SetPoint("TOPLEFT", applicantsScrollFrame, "TOPRIGHT", 0, -16)
applicantsScrollBar:SetPoint("BOTTOMLEFT", applicantsScrollFrame, "BOTTOMRIGHT", 0, 16)

local applicantsScrollChild = CreateFrame("Frame", "GuildFoundToolsApplicantsScrollChild", applicantsScrollFrame)
applicantsScrollChild:SetSize(applicantsScrollFrame:GetWidth(), 1)
applicantsScrollFrame:SetScrollChild(applicantsScrollChild)

-- Applicant row pool

local function CreateApplicantRow(parent)
	local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	row:SetHeight(30)
	row:SetBackdrop({
		bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 12,
		insets = { left = 2, right = 2, top = 2, bottom = 2 },
	})
	row:SetBackdropColor(0, 0, 0, 0.4)

	-- Role icon
	row.roleIcon = row:CreateTexture(nil, "ARTWORK")
	row.roleIcon:SetSize(20, 20)
	row.roleIcon:SetPoint("LEFT", 6, 0)
	row.roleIcon:SetTexture(ROLE_TEXTURE)

	-- Name text
	row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.nameText:SetPoint("LEFT", row.roleIcon, "RIGHT", 6, 0)
	row.nameText:SetJustifyH("LEFT")

	-- Decline button
	row.declineButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	row.declineButton:SetSize(80, 22)
	row.declineButton:SetPoint("RIGHT", -4, 0)
	row.declineButton:SetText(L["ButtonDecline"])

	-- Accept button
	row.acceptButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	row.acceptButton:SetSize(80, 22)
	row.acceptButton:SetPoint("RIGHT", row.declineButton, "LEFT", -4, 0)
	row.acceptButton:SetText(L["ButtonAccept"])

	return row
end

local applicantRowPool = CreatePool(applicantsScrollChild, CreateApplicantRow)

local function UpdateApplicantsList(group, isLeader)
	applicantRowPool:ReleaseAll()

	local applicants = group.applicants or {}
	local applicantList = {}
	for applicantName, role in pairs(applicants) do
		table.insert(applicantList, { name = applicantName, role = role })
	end

	table.sort(applicantList, function(a, b)
		return (ROLE_SORT_ORDER[a.role] or 3) < (ROLE_SORT_ORDER[b.role] or 3)
	end)

	if #applicantList == 0 then
		applicantsScrollFrame:Hide()
		if isLeader then
			myGroupInfoText:SetText(L["NoApplicantsYet"])
		else
			myGroupInfoText:SetText(string.format(L["MemberOfGroup"], group.leader) .. "\n" .. L["NoApplicantsYet"])
		end
		myGroupInfoText:Show()
		return
	end

	myGroupInfoText:Hide()
	applicantsScrollFrame:Show()

	local yOffset = 0
	for _, applicantInfo in ipairs(applicantList) do
		local row = applicantRowPool:Acquire()
		row:SetPoint("TOPLEFT", applicantsScrollChild, "TOPLEFT", 0, -yOffset)
		row:SetPoint("RIGHT", applicantsScrollChild, "RIGHT", 0, 0)

		-- Role icon
		local texCoords = ROLE_TEXCOORDS[applicantInfo.role] or ROLE_TEXCOORDS["DD"]
		row.roleIcon:SetTexCoord(unpack(texCoords))

		-- Name with class color
		local classFileName, level, online = GetGuildMemberInfo(applicantInfo.name)
		local red, green, blue = 1, 1, 1
		if classFileName and RAID_CLASS_COLORS[classFileName] then
			red = RAID_CLASS_COLORS[classFileName].r
			green = RAID_CLASS_COLORS[classFileName].g
			blue = RAID_CLASS_COLORS[classFileName].b
		end

		local nameDisplay = applicantInfo.name
		if level and level > 0 then
			nameDisplay = nameDisplay .. " |cff888888(" .. level .. ")|r"
		end
		if not online then
			nameDisplay = nameDisplay .. " |cffff0000(offline)|r"
		end
		row.nameText:SetText(nameDisplay)
		row.nameText:SetTextColor(red, green, blue)

		-- Show/hide buttons based on leader status
		if isLeader then
			row.acceptButton:Show()
			row.declineButton:Show()
			row.acceptButton:SetScript("OnClick", function()
				GuildFoundTools.LFG.AcceptApplicant(group.id, applicantInfo.name)
			end)
			row.declineButton:SetScript("OnClick", function()
				GuildFoundTools.LFG.DeclineApplicant(group.id, applicantInfo.name)
			end)
		else
			row.acceptButton:Hide()
			row.declineButton:Hide()
		end

		yOffset = yOffset + 33
	end

	applicantsScrollChild:SetHeight(yOffset)

	if yOffset > applicantsScrollFrame:GetHeight() then
		applicantsScrollBar:Show()
	else
		applicantsScrollBar:Hide()
	end
end

-- Form elements to show/hide together
local formElements = { categoryLabel, categoryDropdown, dungeonLabel, dungeonDropdown, descriptionLabel, descriptionEditBox, maxMembersLabel, maxMembersEditBox }

local function ShowFormElements(visible)
	for _, element in ipairs(formElements) do
		if visible then
			element:Show()
		else
			element:Hide()
		end
	end
end

local function ResetForm()
	selectedCategory = "Dungeons"
	selectedDungeon = ""
	UIDropDownMenu_SetText(categoryDropdown, "Dungeons")
	UIDropDownMenu_SetText(dungeonDropdown, L["DropdownSelect"])
	UIDropDownMenu_EnableDropDown(dungeonDropdown)
	descriptionEditBox:SetText("")
	maxMembersEditBox:SetText("5")
	selectedRole = "DD"
	UpdateRoleButtons()
	selectedBeginnerFriendly = false
	UpdateBeginnerFriendlyButton()
	UpdateFormValidation()
end

local function PopulateFormFromGroup(group)
	local playerName = GetPlayerName()

	selectedCategory = group.category or "Dungeons"
	UIDropDownMenu_SetText(categoryDropdown, selectedCategory)

	selectedDungeon = group.dungeon or ""
	if selectedDungeon ~= "" then
		UIDropDownMenu_SetText(dungeonDropdown, GetDungeonDisplayTextById(selectedDungeon))
	else
		UIDropDownMenu_SetText(dungeonDropdown, L["DropdownSelect"])
	end

	if selectedCategory == "Custom" then
		UIDropDownMenu_DisableDropDown(dungeonDropdown)
	else
		UIDropDownMenu_EnableDropDown(dungeonDropdown)
	end

	descriptionEditBox:SetText(group.description or "")
	maxMembersEditBox:SetText(tostring(group.maxMembers or 5))

	selectedRole = group.members[playerName] or "DD"
	UpdateRoleButtons()

	selectedBeginnerFriendly = group.beginnerFriendly or false
	UpdateBeginnerFriendlyButton()
	UpdateFormValidation()
end

local function ShowMyGroupListView(myGroup)
	ShowFormElements(false)

	-- Show current role selection
	selectedRole = myGroup.members[GetPlayerName()] or "DD"
	UpdateRoleButtons()

	-- Show applicants list
	UpdateApplicantsList(myGroup, myGroup.leader == GetPlayerName())

	leftButton:SetText(L["ButtonRemoveGroup"])
	leftButton:Show()
	rightButton:SetText(L["ButtonEdit"])
	rightButton:Enable()
	rightButton:Show()
end

local function ShowMyGroupEditView(myGroup)
	ShowFormElements(true)
	myGroupInfoText:Hide()
	applicantsScrollFrame:Hide()
	applicantRowPool:ReleaseAll()
	PopulateFormFromGroup(myGroup)

	leftButton:SetText(L["ButtonBack"])
	leftButton:Show()
	rightButton:SetText(L["ButtonSave"])
	rightButton:Show()
end

function GuildFoundTools.LFG.UpdateCreateGroupTab()
	local myGroup = GuildFoundTools.LFG.GetMyGroup()
	local playerName = GetPlayerName()

	if myGroup then
		GuildFoundTools.UI.SetTabText(2, L["TabMyGroup"])
		GuildFoundTools.UI.SetTabEnabled(2, true)

		if myGroup.leader == playerName then
			if isEditingMyGroup then
				beginnerFriendlyButton:Show()
				UpdateRoleContainerLayout()
				ShowMyGroupEditView(myGroup)
			else
				beginnerFriendlyButton:Hide()
				UpdateRoleContainerLayout()
				ShowMyGroupListView(myGroup)
			end
		else
			-- Member: show info text, role selection, and applicants
			isEditingMyGroup = false
			beginnerFriendlyButton:Hide()
			UpdateRoleContainerLayout()
			ShowFormElements(false)
			myGroupInfoText:Hide()
			leftButton:Hide()
			rightButton:Hide()

			-- Set role from group data and show role buttons
			selectedRole = myGroup.members[playerName] or "DD"
			UpdateRoleButtons()

			-- Show applicants (read-only, no buttons)
			UpdateApplicantsList(myGroup, false)
		end
	else
		GuildFoundTools.UI.SetTabText(2, L["TabCreateGroup"])
		isEditingMyGroup = false

		local isInPartyAsNonLeader = GetNumGroupMembers() > 0 and not UnitIsGroupLeader("player")
		GuildFoundTools.UI.SetTabEnabled(2, not isInPartyAsNonLeader, L["TabCreateGroupDisabled"])

		beginnerFriendlyButton:Show()
		UpdateRoleContainerLayout()
		ShowFormElements(true)
		myGroupInfoText:Hide()
		applicantsScrollFrame:Hide()
		applicantRowPool:ReleaseAll()
		leftButton:Hide()
		rightButton:SetText(L["ButtonCreate"])
		rightButton:Show()
		ResetForm()
	end
end

leftButton:SetScript("OnClick", function()
	local myGroup = GuildFoundTools.LFG.GetMyGroup()
	if not myGroup or myGroup.leader ~= GetPlayerName() then return end

	if isEditingMyGroup then
		-- Back to list view
		isEditingMyGroup = false
		GuildFoundTools.LFG.UpdateCreateGroupTab()
	else
		-- Remove group
		if GuildFoundTools.LFG.ownGroupId then
			GuildFoundTools.LFG.RemoveGroup(GuildFoundTools.LFG.ownGroupId)
		end
	end
end)

rightButton:SetScript("OnClick", function()
	local myGroup = GuildFoundTools.LFG.GetMyGroup()

	if myGroup and myGroup.leader == GetPlayerName() and isEditingMyGroup then
		-- save edits
		local category = selectedCategory
		local dungeon = selectedDungeon
		local description = descriptionEditBox:GetText() or ""
		local maxMembers = tonumber(maxMembersEditBox:GetText()) or 5

		if maxMembers < 1 then maxMembers = 1 end
		if maxMembers > 40 then maxMembers = 40 end

		GuildFoundTools.LFG.EditGroup(GuildFoundTools.LFG.ownGroupId, category, dungeon, description, maxMembers, selectedBeginnerFriendly, selectedRole)
		isEditingMyGroup = false
		GuildFoundTools.LFG.UpdateCreateGroupTab()
	elseif myGroup then
		-- switch to edit view
		isEditingMyGroup = true
		GuildFoundTools.LFG.UpdateCreateGroupTab()
	else
		-- create new group
		local category = selectedCategory
		local dungeon = selectedDungeon
		local description = descriptionEditBox:GetText() or ""
		local maxMembers = tonumber(maxMembersEditBox:GetText()) or 5

		if maxMembers < 2 then maxMembers = 2 end
		if maxMembers > 40 then maxMembers = 40 end

		GuildFoundTools.LFG.CreateGroup(category, dungeon, description, maxMembers, selectedBeginnerFriendly, selectedRole)
	end
end)

createGroupContent:SetScript("OnShow", function()
	isEditingMyGroup = false
	GuildFoundTools.LFG.UpdateCreateGroupTab()
end)

-- ============================================================
-- Party role selection popup (shown when joining a group leader's party)
-- ============================================================

local partyRolePopup = CreateFrame("Frame", "GuildFoundToolsPartyRolePopup", UIParent, "BasicFrameTemplateWithInset")
partyRolePopup:SetSize(230, 100)
partyRolePopup:SetPoint("CENTER")
partyRolePopup:SetFrameStrata("DIALOG")
partyRolePopup:Hide()
partyRolePopup:EnableMouse(true)
partyRolePopup:SetMovable(true)
partyRolePopup:RegisterForDrag("LeftButton")
partyRolePopup:SetScript("OnDragStart", partyRolePopup.StartMoving)
partyRolePopup:SetScript("OnDragStop", partyRolePopup.StopMovingOrSizing)

partyRolePopup.title = partyRolePopup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
partyRolePopup.title:SetPoint("CENTER", partyRolePopup.TitleBg, "CENTER", 0, 0)
partyRolePopup.title:SetText(L["SelectRoleTitle"])

partyRolePopup.groupId = nil

local partyRoleLabel = partyRolePopup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
partyRoleLabel:SetPoint("TOP", 0, -30)
partyRoleLabel:SetText(L["SelectRolePrompt"])

for index, roleName in ipairs(ROLE_NAMES) do
	local button = CreateFrame("Button", nil, partyRolePopup)
	button:SetSize(36, 36)
	button:SetPoint("BOTTOM", -40 + (index - 1) * 40, 12)

	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetAllPoints()
	button.icon:SetTexture(ROLE_TEXTURE)
	button.icon:SetTexCoord(unpack(ROLE_TEXCOORDS[roleName]))

	button:SetScript("OnClick", function()
		if partyRolePopup.groupId then
			GuildFoundTools.LFG.SignupForGroup(partyRolePopup.groupId, roleName)
			selectedRole = roleName
			GuildFoundTools.LFG.ChangeMyRole(roleName)
		end
		partyRolePopup:Hide()
	end)

	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(L[roleName])
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

tinsert(UISpecialFrames, "GuildFoundToolsPartyRolePopup")

function GuildFoundTools.LFG.ShowPartyRolePopup(groupId)
	partyRolePopup.groupId = groupId
	partyRolePopup:Show()
end
