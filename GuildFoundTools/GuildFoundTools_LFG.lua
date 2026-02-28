-- LFG Tab: create/list/join groups

local contentFrame = GuildFoundTools.GetContentFrame(1)

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
local ROLE_ICON_MARKUP = {}
for roleName, coords in pairs(ROLE_TEXCOORDS) do
	ROLE_ICON_MARKUP[roleName] = string.format(
		"|T%s:14:14:0:0:1024:1024:%d:%d:%d:%d|t",
		ROLE_TEXTURE,
		coords[1] * 1024, coords[2] * 1024,
		coords[3] * 1024, coords[4] * 1024
	)
end

-- Guild roster lookup for class color and level
local function GetGuildMemberInfo(name)
	local memberCount = GetNumGuildMembers()
	for index = 1, memberCount do
		local fullName, _, _, level, _, _, _, _, _, _, classFileName = GetGuildRosterInfo(index)
		if fullName then
			local shortName = strsplit("-", fullName)
			if shortName == name then
				return classFileName, level
			end
		end
	end
	return nil, nil
end

-- ============================================================
-- Dungeon/Raid data for Classic
-- ============================================================

local CATEGORIES = { "Dungeons", "Raids", "Custom" }

local DUNGEON_LIST = {
	["Dungeons"] = {
		"Ragefire Chasm",
		"Wailing Caverns",
		"The Deadmines",
		"Shadowfang Keep",
		"The Stockade",
		"Blackfathom Deeps",
		"Gnomeregan",
		"Razorfen Kraul",
		"Scarlet Monastery - Graveyard",
		"Scarlet Monastery - Library",
		"Scarlet Monastery - Armory",
		"Scarlet Monastery - Cathedral",
		"Razorfen Downs",
		"Uldaman",
		"Zul'Farrak",
		"Maraudon",
		"Temple of Atal'Hakkar",
		"Blackrock Depths",
		"Lower Blackrock Spire",
		"Upper Blackrock Spire",
		"Dire Maul East",
		"Dire Maul West",
		"Dire Maul North",
		"Stratholme - Living",
		"Stratholme - Undead",
		"Scholomance",
	},
	["Raids"] = {
		"Molten Core",
		"Onyxia's Lair",
		"Blackwing Lair",
		"Zul'Gurub",
		"Ruins of Ahn'Qiraj",
		"Temple of Ahn'Qiraj",
		"Naxxramas",
	},
	["Custom"] = {},
}

-- ============================================================
-- Top bar: Create Group button
-- ============================================================

local createGroupButton = CreateFrame("Button", nil, contentFrame, "UIPanelButtonTemplate")
createGroupButton:SetSize(130, 22)
createGroupButton:SetPoint("TOPLEFT", 0, 0)
createGroupButton:SetText("Gruppe erstellen")

-- No groups hint
local noGroupsText = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
noGroupsText:SetPoint("CENTER", 0, -20)
noGroupsText:SetText("Keine Gruppen vorhanden.\nErstelle eine Gruppe oder warte auf Gildenmitglieder.")
noGroupsText:SetJustifyH("CENTER")

-- ============================================================
-- Bottom action bar
-- ============================================================

local ACTION_BAR_HEIGHT = 30

local actionBar = CreateFrame("Frame", nil, contentFrame)
actionBar:SetHeight(ACTION_BAR_HEIGHT)
actionBar:SetPoint("BOTTOMLEFT", 0, 0)
actionBar:SetPoint("BOTTOMRIGHT", 0, 0)

-- Left side: selection-based buttons (Anmelden / Verlassen)
local signupButton = CreateFrame("Button", nil, actionBar, "UIPanelButtonTemplate")
signupButton:SetSize(120, 24)
signupButton:SetPoint("LEFT", 0, 0)
signupButton:SetText("Anmelden")
signupButton:Hide()

local leaveButton = CreateFrame("Button", nil, actionBar, "UIPanelButtonTemplate")
leaveButton:SetSize(120, 24)
leaveButton:SetPoint("LEFT", 0, 0)
leaveButton:SetText("Verlassen")
leaveButton:Hide()

-- Right side: leader buttons (always visible when player has a group)
local deleteGroupButton = CreateFrame("Button", nil, actionBar, "UIPanelButtonTemplate")
deleteGroupButton:SetSize(140, 24)
deleteGroupButton:SetPoint("RIGHT", 0, 0)
deleteGroupButton:SetText("Gruppe löschen")
deleteGroupButton:Hide()

local editGroupButton = CreateFrame("Button", nil, actionBar, "UIPanelButtonTemplate")
editGroupButton:SetSize(140, 24)
editGroupButton:SetPoint("RIGHT", deleteGroupButton, "LEFT", -4, 0)
editGroupButton:SetText("Gruppe bearbeiten")
editGroupButton:Hide()

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

local ROLE_NAMES = { "TANK", "HEAL", "DD" }

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
			GuildFoundTools.SignupForGroup(rolePopup.groupId, roleName)
		end
		rolePopup:Hide()
	end)

	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		if roleName == "TANK" then
			GameTooltip:SetText("Tank")
		elseif roleName == "HEAL" then
			GameTooltip:SetText("Heiler")
		else
			GameTooltip:SetText("Damage Dealer")
		end
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

tinsert(UISpecialFrames, "GuildFoundToolsRolePopup")

-- ============================================================
-- Scroll frame for group listing
-- ============================================================

local scrollFrame = CreateFrame("ScrollFrame", "GuildFoundToolsLFGScrollFrame", contentFrame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", 0, -30)
scrollFrame:SetPoint("BOTTOMRIGHT", -25, ACTION_BAR_HEIGHT)

local scrollChild = CreateFrame("Frame", "GuildFoundToolsLFGScrollChild", scrollFrame)
scrollChild:SetSize(scrollFrame:GetWidth(), 1)
scrollFrame:SetScrollChild(scrollChild)

-- ============================================================
-- Group row pool
-- ============================================================

local rowPool = {}
local activeRows = {}
local selectedGroupId = nil

local ROW_HEIGHT = 40
local ROW_SPACING = 3
local MAX_ROLE_SLOTS = 5

-- Right-click context menu using MenuUtil
local function ShowContextMenu(owner, group)
	MenuUtil.CreateContextMenu(owner, function(_, rootDescription)
		local playerName = UnitName("player")

		-- Send message
		rootDescription:CreateButton("Nachricht senden", function()
			ChatFrame_SendTell(group.leader)
		end)

		-- Group invite (only for leader, only if target is alone)
		if group.leader ~= playerName and GuildFoundTools.GetMemberCount(group) == 1 then
			if GuildFoundTools.ownGroupId then
				rootDescription:CreateButton("Spieler einladen", function()
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
			if self.groupId == GuildFoundTools.ownGroupId then return end
			local group = GuildFoundTools.groups[self.groupId]
			if not group then return end

			ShowContextMenu(self, group)
		else
			selectedGroupId = self.groupId
			GuildFoundTools.UpdateLFGUI()
		end
	end)

	row:SetScript("OnEnter", function(self)
		if self.groupId ~= selectedGroupId then
			self.hoverTexture:Show()
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

		-- Members first (with role icon, class color, level)
		if self.roleArea.members and #self.roleArea.members > 0 then
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

				GameTooltip:AddLine(leaderIcon .. memberInfo.name .. levelText .. " " .. roleIcon, red, green, blue)
			end
		end

		-- Description (if exists)
		if self.groupDescription and self.groupDescription ~= "" then
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine(self.groupDescription, 0.6, 0.6, 0.6, true)
		end

		-- Member count
		if self.roleArea.members then
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine("Mitglieder: " .. #self.roleArea.members .. "/" .. (self.groupMaxMembers or "?"), 0.6, 0.6, 0.6)
		end

		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", function(self)
		self.hoverTexture:Hide()
		GameTooltip:Hide()
	end)

	return row
end

local function AcquireRow()
	local row = table.remove(rowPool)
	if not row then
		row = CreateGroupRow(scrollChild)
	end
	row:SetParent(scrollChild)
	row:ClearAllPoints()
	row:Show()
	return row
end

local function ReleaseRows()
	for _, row in ipairs(activeRows) do
		row:Hide()
		row.selectedTexture:Hide()
		row.hoverTexture:Hide()
		table.insert(rowPool, row)
	end
	wipe(activeRows)
end

-- ============================================================
-- Update action bar based on selected group
-- ============================================================

local function UpdateActionBar()
	signupButton:Hide()
	leaveButton:Hide()
	deleteGroupButton:Hide()
	editGroupButton:Hide()

	local playerName = UnitName("player")

	-- Leader buttons: always visible when player has a group
	local ownGroupId = GuildFoundTools.ownGroupId

	if ownGroupId then
		deleteGroupButton:Show()
		editGroupButton:Show()
	end

	-- Selection-based buttons (only for non-own groups)
	if selectedGroupId and selectedGroupId ~= ownGroupId then
		local group = GuildFoundTools.groups[selectedGroupId]
		if group then
			if group.members[playerName] then
				leaveButton:Show()
			else
				signupButton:Show()
				signupButton:SetEnabled(GuildFoundTools.GetMemberCount(group) < group.maxMembers)
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

leaveButton:SetScript("OnClick", function()
	if not selectedGroupId then return end
	GuildFoundTools.LeaveGroup(selectedGroupId)
end)

deleteGroupButton:SetScript("OnClick", function()
	local playerName = UnitName("player")
	local ownGroupId = GuildFoundTools.ownGroupId
	if ownGroupId then
		if selectedGroupId == ownGroupId then
			selectedGroupId = nil
		end
		GuildFoundTools.RemoveGroup(ownGroupId)
	end
end)

-- ============================================================
-- Update group listing
-- ============================================================

function GuildFoundTools.UpdateLFGUI()
	ReleaseRows()

	local groups = GuildFoundTools.groups
	local playerName = UnitName("player")

	-- Disable create button if player already has a group
	createGroupButton:SetEnabled(not GuildFoundTools.ownGroupId)

	-- Validate selected group still exists
	if selectedGroupId and not groups[selectedGroupId] then
		selectedGroupId = nil
	end

	-- Sort groups by creation time (newest first)
	local sortedGroups = {}
	for _, group in pairs(groups) do
		table.insert(sortedGroups, group)
	end
	table.sort(sortedGroups, function(a, b)
		return (a.createdAt or 0) > (b.createdAt or 0)
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
		local row = AcquireRow()
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
			descriptionLine = group.dungeon
		elseif group.description and group.description ~= "" then
			descriptionLine = group.description
		else
			descriptionLine = group.category or "Custom"
		end
		row.dungeonText:SetText(descriptionLine)
		row.groupDescription = group.description or ""
		row.groupMaxMembers = group.maxMembers
		row.groupLeader = group.leader

		-- Beginner friendly icon
		row.beginnerFriendlyIcon:SetShown(group.beginnerFriendly == true)

		-- Role icon slots (right side)
		local memberInfoList = {}
		for memberName, role in pairs(group.members) do
			table.insert(memberInfoList, { name = memberName, role = role })
		end

		-- Sort members by role priority: TANK first, then HEAL, then DD
		local ROLE_SORT_ORDER = { ["TANK"] = 1, ["HEAL"] = 2, ["DD"] = 3 }
		table.sort(memberInfoList, function(a, b)
			return (ROLE_SORT_ORDER[a.role] or 3) < (ROLE_SORT_ORDER[b.role] or 3)
		end)

		row.roleArea.members = memberInfoList

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
					if memberIndex <= #memberInfoList then
						local role = memberInfoList[memberIndex].role
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

		table.insert(activeRows, row)
		yOffset = yOffset + ROW_HEIGHT + ROW_SPACING
	end

	scrollChild:SetHeight(yOffset)

	UpdateActionBar()
end

local editingGroupId = nil

-- ============================================================
-- Create / Edit Group dialog
-- ============================================================

local dialogFrame = CreateFrame("Frame", "GuildFoundToolsCreateGroupDialog", UIParent, "BasicFrameTemplateWithInset")
dialogFrame:SetSize(350, 340)
dialogFrame:SetPoint("CENTER")
dialogFrame:SetMovable(true)
dialogFrame:SetClampedToScreen(true)
dialogFrame:SetFrameStrata("DIALOG")
dialogFrame:Hide()

dialogFrame.title = dialogFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
dialogFrame.title:SetPoint("CENTER", dialogFrame.TitleBg, "CENTER", 0, 0)
dialogFrame.title:SetText("Gruppe erstellen")

dialogFrame:EnableMouse(true)
dialogFrame:RegisterForDrag("LeftButton")
dialogFrame:SetScript("OnDragStart", dialogFrame.StartMoving)
dialogFrame:SetScript("OnDragStop", dialogFrame.StopMovingOrSizing)

tinsert(UISpecialFrames, "GuildFoundToolsCreateGroupDialog")

-- Category dropdown
local categoryLabel = dialogFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
categoryLabel:SetPoint("TOPLEFT", 20, -35)
categoryLabel:SetText("Kategorie:")

local categoryDropdown = CreateFrame("Frame", "GuildFoundToolsCategoryDropdown", dialogFrame, "UIDropDownMenuTemplate")
categoryDropdown:SetPoint("TOPLEFT", 4, -47)
UIDropDownMenu_SetWidth(categoryDropdown, 140)
UIDropDownMenu_SetText(categoryDropdown, "Dungeons")

local selectedCategory = "Dungeons"

-- Dungeon dropdown
local dungeonLabel = dialogFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
dungeonLabel:SetPoint("TOPLEFT", 20, -77)
dungeonLabel:SetText("Dungeon/Raid:")

local dungeonDropdown = CreateFrame("Frame", "GuildFoundToolsDungeonDropdown", dialogFrame, "UIDropDownMenuTemplate")
dungeonDropdown:SetPoint("TOPLEFT", 4, -89)
UIDropDownMenu_SetWidth(dungeonDropdown, 280)
UIDropDownMenu_SetText(dungeonDropdown, "-- Wählen --")

local selectedDungeon = ""

local function InitDungeonDropdown(self, level)
	local dungeons = DUNGEON_LIST[selectedCategory] or {}
	if #dungeons == 0 then
		local info = UIDropDownMenu_CreateInfo()
		info.text = "(Freitext in Beschreibung)"
		info.disabled = true
		info.notCheckable = true
		UIDropDownMenu_AddButton(info)
		return
	end

	for _, dungeon in ipairs(dungeons) do
		local info = UIDropDownMenu_CreateInfo()
		info.text = dungeon
		info.func = function()
			selectedDungeon = dungeon
			UIDropDownMenu_SetText(dungeonDropdown, dungeon)
			CloseDropDownMenus()
		end
		info.checked = (selectedDungeon == dungeon)
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
			UIDropDownMenu_SetText(dungeonDropdown, "-- Wählen --")
			UIDropDownMenu_Initialize(dungeonDropdown, InitDungeonDropdown)
			CloseDropDownMenus()

			-- Show/hide dungeon dropdown based on category
			if category == "Custom" then
				dungeonDropdown:SetAlpha(0.5)
			else
				dungeonDropdown:SetAlpha(1)
			end
		end
		info.checked = (selectedCategory == category)
		UIDropDownMenu_AddButton(info)
	end
end

UIDropDownMenu_Initialize(categoryDropdown, InitCategoryDropdown)

-- Description editbox
local descriptionLabel = dialogFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
descriptionLabel:SetPoint("TOPLEFT", 20, -121)
descriptionLabel:SetText("Beschreibung:")

local descriptionEditBox = CreateFrame("EditBox", "GuildFoundToolsDescriptionEditBox", dialogFrame, "InputBoxTemplate")
descriptionEditBox:SetSize(290, 24)
descriptionEditBox:SetPoint("TOPLEFT", 25, -135)
descriptionEditBox:SetAutoFocus(false)
descriptionEditBox:SetMaxLetters(100)
descriptionEditBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
descriptionEditBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

-- Max members
local maxMembersLabel = dialogFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
maxMembersLabel:SetPoint("TOPLEFT", 20, -167)
maxMembersLabel:SetText("Max. Mitglieder:")

local maxMembersEditBox = CreateFrame("EditBox", "GuildFoundToolsMaxMembersEditBox", dialogFrame, "InputBoxTemplate")
maxMembersEditBox:SetSize(50, 24)
maxMembersEditBox:SetPoint("TOPLEFT", 25, -181)
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

-- Role selection
local roleLabel = dialogFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
roleLabel:SetPoint("TOPLEFT", 20, -213)
roleLabel:SetText("Rolle:")

local selectedRole = "DD"
local roleButtons = {}
local roles = {
	{ key = "TANK" },
	{ key = "HEAL" },
	{ key = "DD" },
}

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

for index, roleData in ipairs(roles) do
	local roleButton = CreateFrame("Button", nil, dialogFrame)
	roleButton:SetSize(32, 32)
	roleButton:SetPoint("TOPLEFT", 20 + (index - 1) * 36, -227)
	roleButton.roleKey = roleData.key

	roleButton.icon = roleButton:CreateTexture(nil, "ARTWORK")
	roleButton.icon:SetAllPoints()
	roleButton.icon:SetTexture(ROLE_TEXTURE)
	roleButton.icon:SetTexCoord(unpack(ROLE_TEXCOORDS[roleData.key]))

	roleButton:SetScript("OnClick", function(self)
		selectedRole = self.roleKey
		UpdateRoleButtons()
	end)

	roleButton:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		if self.roleKey == "TANK" then
			GameTooltip:SetText("Tank")
		elseif self.roleKey == "HEAL" then
			GameTooltip:SetText("Heiler")
		else
			GameTooltip:SetText("Damage Dealer")
		end
		GameTooltip:Show()
	end)
	roleButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

	table.insert(roleButtons, roleButton)
end

-- Beginner friendly button (same style as role buttons)
local selectedBeginnerFriendly = false

local beginnerFriendlyButton = CreateFrame("Button", nil, dialogFrame)
beginnerFriendlyButton:SetSize(32, 32)
beginnerFriendlyButton:SetPoint("TOPLEFT", 20 + 3 * 36, -227)

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
	GameTooltip:SetText("Neulinge willkommen")
	GameTooltip:Show()
end)
beginnerFriendlyButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Create / Cancel buttons
local createButton = CreateFrame("Button", nil, dialogFrame, "UIPanelButtonTemplate")
createButton:SetSize(120, 26)
createButton:SetPoint("BOTTOMLEFT", 30, 15)
createButton:SetText("Erstellen")

local cancelButton = CreateFrame("Button", nil, dialogFrame, "UIPanelButtonTemplate")
cancelButton:SetSize(120, 26)
cancelButton:SetPoint("BOTTOMRIGHT", -30, 15)
cancelButton:SetText("Abbrechen")

cancelButton:SetScript("OnClick", function()
	dialogFrame:Hide()
end)

createButton:SetScript("OnClick", function()
	local category = selectedCategory
	local dungeon = selectedDungeon
	local description = descriptionEditBox:GetText() or ""
	local maxMembers = tonumber(maxMembersEditBox:GetText()) or 5

	if maxMembers < 1 then maxMembers = 1 end
	if maxMembers > 40 then maxMembers = 40 end

	if editingGroupId then
		GuildFoundTools.EditGroup(editingGroupId, category, dungeon, description, maxMembers, selectedBeginnerFriendly, selectedRole)
	else
		GuildFoundTools.CreateGroup(category, dungeon, description, maxMembers, selectedBeginnerFriendly, selectedRole)
	end
	editingGroupId = nil
	dialogFrame:Hide()
end)

-- Wire up the create group button
createGroupButton:SetScript("OnClick", function()
	-- Reset dialog for creating
	editingGroupId = nil
	dialogFrame.title:SetText("Gruppe erstellen")
	createButton:SetText("Erstellen")
	selectedCategory = "Dungeons"
	selectedDungeon = ""
	UIDropDownMenu_SetText(categoryDropdown, "Dungeons")
	UIDropDownMenu_SetText(dungeonDropdown, "-- Wählen --")
	dungeonDropdown:SetAlpha(1)
	descriptionEditBox:SetText("")
	maxMembersEditBox:SetText("5")
	selectedRole = "DD"
	UpdateRoleButtons()
	selectedBeginnerFriendly = false
	UpdateBeginnerFriendlyButton()
	dialogFrame:Show()
end)

-- Wire up edit group button
editGroupButton:SetScript("OnClick", function()
	local playerName = UnitName("player")
	local ownGroup = nil
	local ownGroupId = GuildFoundTools.ownGroupId
	if not ownGroupId then return end
	ownGroup = GuildFoundTools.groups[ownGroupId]
	if not ownGroup then return end

	editingGroupId = ownGroup.id
	dialogFrame.title:SetText("Gruppe bearbeiten")
	createButton:SetText("Speichern")

	-- Populate dialog with current group values
	selectedCategory = ownGroup.category or "Dungeons"
	UIDropDownMenu_SetText(categoryDropdown, selectedCategory)

	selectedDungeon = ownGroup.dungeon or ""
	if selectedDungeon ~= "" then
		UIDropDownMenu_SetText(dungeonDropdown, selectedDungeon)
	else
		UIDropDownMenu_SetText(dungeonDropdown, "-- Wählen --")
	end

	if selectedCategory == "Custom" then
		dungeonDropdown:SetAlpha(0.5)
	else
		dungeonDropdown:SetAlpha(1)
	end

	descriptionEditBox:SetText(ownGroup.description or "")
	maxMembersEditBox:SetText(tostring(ownGroup.maxMembers or 5))

	selectedRole = ownGroup.members[playerName] or "DD"
	UpdateRoleButtons()

	selectedBeginnerFriendly = ownGroup.beginnerFriendly or false
	UpdateBeginnerFriendlyButton()

	dialogFrame:Show()
end)

-- Initial update when tab is shown
contentFrame:SetScript("OnShow", function()
	GuildFoundTools.UpdateLFGUI()
end)

-- ============================================================
-- Party role selection popup (shown when joining a group leader's party)
-- ============================================================

local partyRolePopup = CreateFrame("Frame", "GuildFoundToolsPartyRolePopup", UIParent, "BasicFrameTemplateWithInset")
partyRolePopup:SetSize(200, 100)
partyRolePopup:SetPoint("CENTER")
partyRolePopup:SetFrameStrata("DIALOG")
partyRolePopup:Hide()
partyRolePopup:EnableMouse(true)

partyRolePopup.title = partyRolePopup:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
partyRolePopup.title:SetPoint("CENTER", partyRolePopup.TitleBg, "CENTER", 0, 0)
partyRolePopup.title:SetText("Rolle wählen")

partyRolePopup.groupId = nil

local partyRoleLabel = partyRolePopup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
partyRoleLabel:SetPoint("TOP", 0, -30)
partyRoleLabel:SetText("Welche Rolle möchtest du spielen?")

local PARTY_ROLE_NAMES = { "TANK", "HEAL", "DD" }

for index, roleName in ipairs(PARTY_ROLE_NAMES) do
	local button = CreateFrame("Button", nil, partyRolePopup)
	button:SetSize(36, 36)
	button:SetPoint("BOTTOM", -40 + (index - 1) * 40, 12)

	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetAllPoints()
	button.icon:SetTexture(ROLE_TEXTURE)
	button.icon:SetTexCoord(unpack(ROLE_TEXCOORDS[roleName]))

	button:SetScript("OnClick", function()
		if partyRolePopup.groupId then
			GuildFoundTools.SignupForGroup(partyRolePopup.groupId, roleName)
		end
		partyRolePopup:Hide()
	end)

	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		if roleName == "TANK" then
			GameTooltip:SetText("Tank")
		elseif roleName == "HEAL" then
			GameTooltip:SetText("Heiler")
		else
			GameTooltip:SetText("Damage Dealer")
		end
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

tinsert(UISpecialFrames, "GuildFoundToolsPartyRolePopup")

function GuildFoundTools.ShowPartyRolePopup(groupId)
	partyRolePopup.groupId = groupId
	partyRolePopup:Show()
end
