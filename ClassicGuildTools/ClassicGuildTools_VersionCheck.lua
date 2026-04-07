-- Version check: notify player when their addon version is outdated
local L = LibStub("AceLocale-3.0"):GetLocale("ClassicGuildTools")
local MESSAGE_TYPE = ClassicGuildTools.MESSAGE_TYPE
local SendGuildMessage = ClassicGuildTools.SendGuildMessage
local SendWhisperMessage = ClassicGuildTools.SendWhisperMessage
local GetAddOnMetadata = GetAddOnMetadata or C_AddOns and C_AddOns.GetAddOnMetadata
local outdatedNotificationShown = false

-- ============================================================
-- Notification window
-- ============================================================

local function ShowOutdatedNotification(localVersion, newerVersion)
	if outdatedNotificationShown then return end
	outdatedNotificationShown = true

	local frame = CreateFrame("Frame", "ClassicGuildToolsVersionCheckFrame", UIParent, "BasicFrameTemplateWithInset")
	frame:SetSize(350, 100)
	frame:SetPoint("TOP", UIParent, "TOP", 0, -100)
	frame:SetFrameStrata("DIALOG")
	frame:SetFrameLevel(200)

	frame.TitleBg:SetHeight(24)
	frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	frame.title:SetPoint("TOP", frame.TitleBg, "TOP", 0, -3)
	frame.title:SetText(L["AddonTitle"])

	local message = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	message:SetPoint("CENTER", frame.InsetBg, "CENTER", 0, 0)
	message:SetPoint("LEFT", frame, "LEFT", 20, 0)
	message:SetPoint("RIGHT", frame, "RIGHT", -20, 0)
	message:SetText(L["VersionOutdatedMessage"]:format(localVersion, newerVersion))
	message:SetJustifyH("CENTER")

	tinsert(UISpecialFrames, "ClassicGuildToolsVersionCheckFrame")
end

-- ============================================================
-- Event & message handlers
-- ============================================================

ClassicGuildTools.EventHandlers.PLAYER_LOGIN = function()
	if not IsInGuild() then return end

	C_Timer.After(5, function()
		local version = GetAddOnMetadata("ClassicGuildTools", "Version")
		SendGuildMessage(MESSAGE_TYPE.VERSION_BROADCAST, version)
	end)
end

-- When receiving a version broadcast, check if our version is higher and notify the sender
ClassicGuildTools.MessageHandlers.VERSION_BROADCAST = function(data, sender)
	if sender == ClassicGuildTools.GetPlayerName() then return end

	local localVersion = GetAddOnMetadata("ClassicGuildTools", "Version")
	if not data or not localVersion then return end

	if ClassicGuildTools.Utils.CompareVersions(localVersion, data) > 0 then
		SendWhisperMessage(MESSAGE_TYPE.VERSION_OUTDATED_NOTIFY, sender, localVersion)
	end
end

-- When receiving an outdated notification, show the update window (only once)
ClassicGuildTools.MessageHandlers.VERSION_OUTDATED_NOTIFY = function(data, sender)
	if outdatedNotificationShown then return end

	local localVersion = GetAddOnMetadata("ClassicGuildTools", "Version")
	ShowOutdatedNotification(localVersion, data)
end
