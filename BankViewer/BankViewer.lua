BankViewer = {}
BankViewer.version = "1.0.0"

local BANK_CONTAINER = Enum.BagIndex.Bank
local BANK_SLOTS = 28
local BANK_BAG_FIRST = NUM_BAG_SLOTS + 1 -- 5
local BANK_BAG_LAST = NUM_BAG_SLOTS + NUM_BANKBAGSLOTS -- 11

-- C_Container API (Anniversary / modern Classic clients)
local GetContainerNumSlots = C_Container.GetContainerNumSlots
local GetContainerItemInfo = C_Container.GetContainerItemInfo
local GetContainerItemLink = C_Container.GetContainerItemLink
local ContainerIDToInventoryID = C_Container.ContainerIDToInventoryID

local bankOpen = false
local guildBankOpen = false

-- Guild bank API (may be under C_ namespace in Anniversary Edition)
local GetGuildBankNumTabs = GetNumGuildBankTabs or (C_GuildBank and C_GuildBank.GetNumTabs)
local GetGuildBankTabInfoFn = GetGuildBankTabInfo or (C_GuildBank and C_GuildBank.GetTabInfo)
local GetGuildBankItemInfoFn = GetGuildBankItemInfo or (C_GuildBank and C_GuildBank.GetItemInfo)
local GetGuildBankItemLinkFn = GetGuildBankItemLink or (C_GuildBank and C_GuildBank.GetItemLink)

local GUILD_BANK_SLOTS_PER_TAB = 98

local guildBankHooked = false

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("BANKFRAME_OPENED")
frame:RegisterEvent("BANKFRAME_CLOSED")
frame:RegisterEvent("BAG_UPDATE")

local function GetCharKey()
	local name = UnitName("player")
	local realm = GetRealmName()
	return realm, name
end

local function ScanBank()
	local realm, name = GetCharKey()

	if not BankViewerDB[realm] then
		BankViewerDB[realm] = {}
	end

	local charData = {
		bags = {},
		lastScan = time(),
	}

	-- Scan main bank container (-1, 28 slots)
	local mainSlots = GetContainerNumSlots(BANK_CONTAINER)
	charData.bags[BANK_CONTAINER] = {
		slots = mainSlots,
		items = {},
	}

	for slot = 1, mainSlots do
		local info = GetContainerItemInfo(BANK_CONTAINER, slot)
		if info then
			charData.bags[BANK_CONTAINER].items[slot] = {
				itemLink = info.hyperlink or GetContainerItemLink(BANK_CONTAINER, slot),
				count = info.stackCount or 1,
				icon = info.iconFileID,
				quality = info.quality or 0,
			}
		end
	end

	-- Scan bank bags (5-11)
	for bagID = BANK_BAG_FIRST, BANK_BAG_LAST do
		local numSlots = GetContainerNumSlots(bagID)
		if numSlots and numSlots > 0 then
			charData.bags[bagID] = {
				slots = numSlots,
				items = {},
				bagIcon = GetInventoryItemTexture("player", ContainerIDToInventoryID(bagID)),
			}

			for slot = 1, numSlots do
				local info = GetContainerItemInfo(bagID, slot)
				if info then
					charData.bags[bagID].items[slot] = {
						itemLink = info.hyperlink or GetContainerItemLink(bagID, slot),
						count = info.stackCount or 1,
						icon = info.iconFileID,
						quality = info.quality or 0,
					}
				end
			end
		else
			-- Empty bag slot
			charData.bags[bagID] = {
				slots = 0,
				items = {},
			}
		end
	end

	BankViewerDB[realm][name] = charData
	print("|cff00ccffBankViewer:|r Bank data saved for " .. name .. ".")

	if BankViewer.UpdateUI then
		BankViewer.UpdateUI()
	end
end

local function ScanGuildBank()
	if not GetGuildBankNumTabs then return end

	local guildName = GetGuildInfo("player")
	if not guildName then return end

	local realm = GetRealmName()

	if not BankViewerDB._guilds then
		BankViewerDB._guilds = {}
	end
	if not BankViewerDB._guilds[realm] then
		BankViewerDB._guilds[realm] = {}
	end

	local numTabs = GetGuildBankNumTabs()
	local guildData = {
		tabs = {},
		lastScan = time(),
	}

	for tab = 1, numTabs do
		local tabName, tabIcon = GetGuildBankTabInfoFn(tab)
		if tabName then
			local tabData = {
				name = tabName,
				icon = tabIcon,
				slots = GUILD_BANK_SLOTS_PER_TAB,
				items = {},
			}

			for slot = 1, GUILD_BANK_SLOTS_PER_TAB do
				local texture, count, locked = GetGuildBankItemInfoFn(tab, slot)
				if texture then
					local itemLink = GetGuildBankItemLinkFn(tab, slot)
					if itemLink then
						local _, _, quality = GetItemInfo(itemLink)
						tabData.items[slot] = {
							itemLink = itemLink,
							count = count or 1,
							icon = texture,
							quality = quality or 0,
						}
					end
				end
			end

			guildData.tabs[tab] = tabData
		end
	end

	BankViewerDB._guilds[realm][guildName] = guildData
	print("|cff00ccffBankViewer:|r Guild bank data saved for " .. guildName .. ".")

	if BankViewer.UpdateUI then
		BankViewer.UpdateUI()
	end
end

local function HookGuildBankFrame()
	if guildBankHooked then return end
	if not GuildBankFrame then return end

	guildBankHooked = true

	GuildBankFrame:HookScript("OnShow", function()
		guildBankOpen = true
		-- Delay scan slightly so the data is available from the server
		C_Timer.After(0.5, function()
			if guildBankOpen then
				ScanGuildBank()
			end
		end)
	end)

	GuildBankFrame:HookScript("OnHide", function()
		guildBankOpen = false
	end)

	-- Try to register content update events via pcall
	pcall(function()
		frame:RegisterEvent("GUILDBANKBAGSLOTS_CHANGED")
	end)
end

frame:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == "BankViewer" then
			if not BankViewerDB then
				BankViewerDB = {}
			end
			if not BankViewerDB._settings then
				BankViewerDB._settings = { showEmpty = true }
			end
			if not BankViewerDB._guilds then
				BankViewerDB._guilds = {}
			end
		elseif arg1 == "Blizzard_GuildBankUI" then
			HookGuildBankFrame()
		end
	elseif event == "BANKFRAME_OPENED" then
		bankOpen = true
		ScanBank()
	elseif event == "BANKFRAME_CLOSED" then
		bankOpen = false
	elseif event == "BAG_UPDATE" and bankOpen then
		ScanBank()
	elseif event == "GUILDBANKBAGSLOTS_CHANGED" and guildBankOpen then
		ScanGuildBank()
	end
end)

function BankViewer.Toggle()
	if BankViewerMainFrame then
		if BankViewerMainFrame:IsShown() then
			BankViewerMainFrame:Hide()
		else
			BankViewerMainFrame:Show()
		end
	end
end

function BankViewer.GetCharacters()
	local chars = {}
	if not BankViewerDB then
		return chars
	end

	for realm, realmData in pairs(BankViewerDB) do
		if type(realmData) == "table" then
			for name, data in pairs(realmData) do
				if type(data) == "table" and data.bags then
					table.insert(chars, { realm = realm, name = name, data = data })
				end
			end
		end
	end

	return chars
end

function BankViewer.GetGuilds()
	local guilds = {}
	if not BankViewerDB or not BankViewerDB._guilds then
		return guilds
	end

	for realm, realmData in pairs(BankViewerDB._guilds) do
		if type(realmData) == "table" then
			for guildName, data in pairs(realmData) do
				if type(data) == "table" and data.tabs then
					table.insert(guilds, { realm = realm, name = guildName, data = data })
				end
			end
		end
	end

	return guilds
end

function BankViewer.GetCurrentCharKey()
	local realm, name = GetCharKey()
	return realm, name
end

SLASH_BANKVIEWER1 = "/bv"
SLASH_BANKVIEWER2 = "/bankviewer"
SlashCmdList["BANKVIEWER"] = function()
	BankViewer.Toggle()
end
