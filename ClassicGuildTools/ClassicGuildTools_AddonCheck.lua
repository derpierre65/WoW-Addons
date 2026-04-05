-- Addon Check tab (officer-only: query guild members for addon version)

ClassicGuildTools.AddonCheck = ClassicGuildTools.AddonCheck or {}

local L = LibStub("AceLocale-3.0"):GetLocale("ClassicGuildTools")
local MESSAGE_TYPE = ClassicGuildTools.MESSAGE_TYPE
local SendGuildMessage = ClassicGuildTools.SendGuildMessage
local SendWhisperMessage = ClassicGuildTools.SendWhisperMessage

local ROW_HEIGHT = 24
local ROW_SPACING = 2
local QUERY_TIMEOUT = 5

local activeQuery = nil

-- ============================================================
-- Permission checks
-- ============================================================

local function IsLocalPlayerOfficer()
	if not IsInGuild() then return false end
	local _, _, rankIndex = GetGuildInfo("player")
	return rankIndex ~= nil and rankIndex <= 2
end

local function IsGuildOfficer(playerName)
	if not IsInGuild() then return false end

	local memberCount = GetNumGuildMembers()
	for index = 1, memberCount do
		local fullName, _, rankIndex = GetGuildRosterInfo(index)
		if fullName then
			local shortName = strsplit("-", fullName)
			if shortName == playerName then
				return rankIndex <= 2
			end
		end
	end

	return false
end

-- ============================================================
-- Version comparison
-- ============================================================

local function CompareVersions(versionA, versionB)
	local majorA, minorA, patchA = versionA:match("^(%d+)%.(%d+)%.(%d+)$")
	local majorB, minorB, patchB = versionB:match("^(%d+)%.(%d+)%.(%d+)$")

	if not majorA or not majorB then return 0 end

	majorA, minorA, patchA = tonumber(majorA), tonumber(minorA), tonumber(patchA)
	majorB, minorB, patchB = tonumber(majorB), tonumber(minorB), tonumber(patchB)

	if majorA ~= majorB then return majorA < majorB and -1 or 1 end
	if minorA ~= minorB then return minorA < minorB and -1 or 1 end
	if patchA ~= patchB then return patchA < patchB and -1 or 1 end

	return 0
end

-- ============================================================
-- Online guild member counting
-- ============================================================

local function CountOnlineGuildMembers()
	local onlineCount = 0
	local myName = ClassicGuildTools.GetPlayerName()
	local memberCount = GetNumGuildMembers()

	for index = 1, memberCount do
		local fullName, _, _, _, _, _, _, _, isOnline = GetGuildRosterInfo(index)
		if fullName and isOnline then
			local shortName = strsplit("-", fullName)
			if shortName ~= myName then
				onlineCount = onlineCount + 1
			end
		end
	end

	return onlineCount
end

-- ============================================================
-- UI setup
-- ============================================================

local contentFrame = ClassicGuildTools.UI.GetContentFrame(4)

-- Query button
local queryButton = CreateFrame("Button", nil, contentFrame, "UIPanelButtonTemplate")
queryButton:SetSize(180, 30)
queryButton:SetPoint("CENTER", contentFrame, "CENTER", 0, 0)
queryButton:SetText(L["ButtonQueryGuild"])

-- Spinner
local spinnerFrame = CreateFrame("Frame", nil, contentFrame)
spinnerFrame:SetSize(48, 48)
spinnerFrame:SetPoint("CENTER", contentFrame, "CENTER", 0, 20)
spinnerFrame:Hide()

local spinnerTexture = spinnerFrame:CreateTexture(nil, "ARTWORK")
spinnerTexture:SetAllPoints()
spinnerTexture:SetTexture("Interface\\Minimap\\HumanUITile-TimeIndicator")

local spinnerAnimationGroup = spinnerTexture:CreateAnimationGroup()
local spinnerRotation = spinnerAnimationGroup:CreateAnimation("Rotation")
spinnerRotation:SetDegrees(-360)
spinnerRotation:SetDuration(1)
spinnerAnimationGroup:SetLooping("REPEAT")

-- Progress text
local progressText = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
progressText:SetPoint("TOP", spinnerFrame, "BOTTOM", 0, -10)
progressText:Hide()

-- No results text
local noResultsText = contentFrame:CreateFontString(nil, "OVERLAY", "GameFontDisable")
noResultsText:SetPoint("CENTER", contentFrame, "CENTER", 0, -20)
noResultsText:SetText(L["AddonCheckNoResults"])
noResultsText:Hide()

-- Scroll frame for results
local scrollFrame = CreateFrame("ScrollFrame", nil, contentFrame, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", contentFrame, "TOPLEFT", 0, -8)
scrollFrame:SetPoint("BOTTOMRIGHT", contentFrame, "BOTTOMRIGHT", -22, 40)
scrollFrame:Hide()

local scrollChild = CreateFrame("Frame", nil, scrollFrame)
scrollChild:SetWidth(scrollFrame:GetWidth())
scrollChild:SetHeight(1)
scrollFrame:SetScrollChild(scrollChild)

scrollFrame:SetScript("OnSizeChanged", function(self)
	scrollChild:SetWidth(self:GetWidth())
end)

-- ============================================================
-- Result row creation (pool pattern)
-- ============================================================

local function CreateResultRow(parent)
	local row = CreateFrame("Frame", nil, parent)
	row:SetHeight(ROW_HEIGHT)
	row:EnableMouse(true)

	row.playerName = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	row.playerName:SetPoint("LEFT", row, "LEFT", 8, 0)
	row.playerName:SetJustifyH("LEFT")

	row.status = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	row.status:SetPoint("RIGHT", row, "RIGHT", -8, 0)
	row.status:SetJustifyH("RIGHT")

	row.background = row:CreateTexture(nil, "BACKGROUND")
	row.background:SetAllPoints()
	row.background:SetColorTexture(1, 1, 1, 0.03)

	row:SetScript("OnMouseUp", function(self, button)
		if button == "LeftButton" and self.playerShortName then
			ChatFrame_SendTell(self.playerShortName)
		end
	end)

	row:SetScript("OnEnter", function(self)
		self.background:SetColorTexture(1, 1, 1, 0.1)
		if self.playerShortName then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(L["SendMessageTo"]:format("|cffffd100" .. self.playerShortName .. "|r"))
			GameTooltip:Show()
		end
	end)

	row:SetScript("OnLeave", function(self)
		GameTooltip:Hide()
		if self.rowIndex and self.rowIndex % 2 == 0 then
			self.background:SetColorTexture(1, 1, 1, 0.05)
		else
			self.background:SetColorTexture(0, 0, 0, 0)
		end
	end)

	return row
end

local rowPool = ClassicGuildTools.Utils.CreatePool(scrollChild, CreateResultRow)

-- ============================================================
-- UI state management
-- ============================================================

local function ShowIdleState()
	queryButton:ClearAllPoints()
	queryButton:SetPoint("CENTER", contentFrame, "CENTER", 0, 0)
	queryButton:Show()
	spinnerFrame:Hide()
	spinnerAnimationGroup:Stop()
	progressText:Hide()
	scrollFrame:Hide()
	noResultsText:Hide()
	rowPool:ReleaseAll()
end

local function ShowLoadingState(expectedCount)
	queryButton:Hide()
	spinnerFrame:Show()
	spinnerAnimationGroup:Play()
	progressText:SetText(L["AddonCheckQuerying"]:format(0, expectedCount))
	progressText:Show()
	scrollFrame:Hide()
	noResultsText:Hide()
	rowPool:ReleaseAll()
end

local function UpdateProgressText()
	if not activeQuery then return end
	progressText:SetText(L["AddonCheckQuerying"]:format(activeQuery.responseCount, activeQuery.expectedCount))
end

local function ShowResultsState(results)
	spinnerFrame:Hide()
	spinnerAnimationGroup:Stop()
	progressText:Hide()
	queryButton:ClearAllPoints()
	queryButton:SetPoint("BOTTOM", contentFrame, "BOTTOM", 0, 4)
	queryButton:Show()

	rowPool:ReleaseAll()

	if #results == 0 then
		scrollFrame:Hide()
		noResultsText:Show()
		return
	end

	noResultsText:Hide()
	scrollFrame:Show()

	for index, result in ipairs(results) do
		local row = rowPool:Acquire()
		row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -((index - 1) * (ROW_HEIGHT + ROW_SPACING)))
		row:SetPoint("RIGHT", scrollChild, "RIGHT", 0, 0)

		row.playerShortName = result.name
		row.rowIndex = index

		local classColor = RAID_CLASS_COLORS[result.classFileName]
		if classColor then
			row.playerName:SetText(string.format("|cff%02x%02x%02x%s|r", classColor.r * 255, classColor.g * 255, classColor.b * 255, result.name))
		else
			row.playerName:SetText(result.name)
		end

		if result.status == "not_installed" then
			row.status:SetText("|cffff4444" .. L["AddonCheckStatusNotInstalled"] .. "|r")
		elseif result.status == "outdated" then
			row.status:SetText("|cffffff00" .. L["AddonCheckStatusOutdated"]:format(result.version) .. "|r")
		end

		if index % 2 == 0 then
			row.background:SetColorTexture(1, 1, 1, 0.05)
		else
			row.background:SetColorTexture(0, 0, 0, 0)
		end
	end

	scrollChild:SetHeight(math.max(1, #results * (ROW_HEIGHT + ROW_SPACING)))
end

contentFrame:SetScript("OnShow", function()
	if not activeQuery then
		ShowIdleState()
	end
end)

-- ============================================================
-- Query logic
-- ============================================================

local function BuildResultList()
	local results = {}
	local currentVersion = GetAddOnMetadata("ClassicGuildTools", "Version")
	local myName = ClassicGuildTools.GetPlayerName()
	local memberCount = GetNumGuildMembers()

	for index = 1, memberCount do
		local fullName, _, _, _, _, _, _, _, isOnline, _, classFileName = GetGuildRosterInfo(index)
		if fullName and isOnline then
			local shortName = strsplit("-", fullName)
			if shortName ~= myName then
				local responseVersion = activeQuery.responses[shortName]
				if not responseVersion then
					table.insert(results, {
						name = shortName,
						classFileName = classFileName,
						status = "not_installed",
						version = nil,
					})
				elseif CompareVersions(responseVersion, currentVersion) < 0 then
					table.insert(results, {
						name = shortName,
						classFileName = classFileName,
						status = "outdated",
						version = responseVersion,
					})
				end
			end
		end
	end

	table.sort(results, function(resultA, resultB)
		if resultA.status ~= resultB.status then
			return resultA.status == "outdated"
		end
		return resultA.name < resultB.name
	end)

	return results
end

local function FinishQuery()
	if not activeQuery then return end

	if activeQuery.timer then
		activeQuery.timer:Cancel()
		activeQuery.timer = nil
	end

	local results = BuildResultList()
	activeQuery = nil

	ShowResultsState(results)
end

local function StartQuery()
	if activeQuery then return end

	if GuildRoster then GuildRoster() elseif C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end
	ClassicGuildTools.BuildGuildMemberCache()

	local expectedCount = CountOnlineGuildMembers()

	activeQuery = {
		responses = {},
		responseCount = 0,
		expectedCount = expectedCount,
		timer = nil,
	}

	ShowLoadingState(expectedCount)

	SendGuildMessage(MESSAGE_TYPE.ADDON_CHECK_QUERY)

	activeQuery.timer = C_Timer.NewTimer(QUERY_TIMEOUT, function()
		FinishQuery()
	end)
end

queryButton:SetScript("OnClick", function()
	StartQuery()
end)

-- ============================================================
-- Message handlers
-- ============================================================

ClassicGuildTools.MessageHandlers.ADDON_CHECK_QUERY = function(data, sender)
	if sender == ClassicGuildTools.GetPlayerName() then return end
	if not IsGuildOfficer(sender) then return end

	local version = GetAddOnMetadata("ClassicGuildTools", "Version")
	SendWhisperMessage(MESSAGE_TYPE.ADDON_CHECK_ANSWER, sender, version)
end

ClassicGuildTools.MessageHandlers.ADDON_CHECK_ANSWER = function(data, sender)
	if not activeQuery then return end

	activeQuery.responses[sender] = data
	activeQuery.responseCount = activeQuery.responseCount + 1

	UpdateProgressText()

	if activeQuery.responseCount >= activeQuery.expectedCount then
		FinishQuery()
	end
end

-- ============================================================
-- Tab visibility management
-- ============================================================

local function UpdateTabVisibility()
	ClassicGuildTools.UI.SetTabVisible(4, IsLocalPlayerOfficer())
end

-- Hide tab 4 initially
ClassicGuildTools.UI.SetTabVisible(4, false)

ClassicGuildTools.EventHandlers.PLAYER_LOGIN = function()
	C_Timer.After(2, UpdateTabVisibility)
end

ClassicGuildTools.EventHandlers.GUILD_ROSTER_UPDATE = function()
	UpdateTabVisibility()
end
