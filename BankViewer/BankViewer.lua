BankViewer = {}
BankViewer.version = (C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata)("BankViewer", "Version")

-- Detect retail 11.2+ tab-based bank system
local isRetailBankTabs = Enum.BagIndex and Enum.BagIndex.CharacterBankTab_1 ~= nil
BankViewer.isRetailBankTabs = isRetailBankTabs

-- Detect Warband (account) bank support (retail 11.0+)
local isWarbandBankAvailable = Enum.BagIndex and Enum.BagIndex.AccountBankTab_1 ~= nil and C_Bank ~= nil
BankViewer.isWarbandBankAvailable = isWarbandBankAvailable

local BANK_CONTAINER = (Enum.BagIndex and Enum.BagIndex.Bank) or -1

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
if isWarbandBankAvailable then
	pcall(frame.RegisterEvent, frame, "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED")
end

local function GetCharKey()
	local name = UnitName("player")
	local realm = GetRealmName()
	return realm, name
end

local function ScanContainerItems(bagID)
	local items = {}
	local numSlots = GetContainerNumSlots(bagID)
	if not numSlots or numSlots == 0 then
		return items, 0
	end

	for slot = 1, numSlots do
		local info = GetContainerItemInfo(bagID, slot)
		if info then
			items[slot] = {
				itemLink = info.hyperlink or GetContainerItemLink(bagID, slot),
				count = info.stackCount or 1,
				icon = info.iconFileID,
				quality = info.quality or 0,
			}
		end
	end

	return items, numSlots
end

local function ScanBank()
	local realm, name = GetCharKey()

	BankViewerDB[realm] = BankViewerDB[realm] or {}

	local charData = {
		bags = {},
		lastScan = time(),
	}

	if isRetailBankTabs then
		-- Retail 11.2+: Tab-based bank (CharacterBankTab_1 through CharacterBankTab_6)
		local purchasedTabs = C_Bank.FetchPurchasedBankTabData(Enum.BankType.Character)
		for tabIndex = 1, 6 do
			local bagID = Enum.BagIndex["CharacterBankTab_" .. tabIndex]
			if bagID then
				local items, numSlots = ScanContainerItems(bagID)
				local tabData = purchasedTabs and purchasedTabs[tabIndex]
				charData.bags[bagID] = {
					slots = numSlots,
					items = items,
					tabName = tabData and tabData.name or ("Tab " .. tabIndex),
					tabIcon = tabData and tabData.icon,
				}
			end
		end
	else
		-- Classic: Main bank container (-1) + bank bags (5-11)
		local mainItems, mainSlots = ScanContainerItems(BANK_CONTAINER)
		charData.bags[BANK_CONTAINER] = {
			slots = mainSlots,
			items = mainItems,
		}

		local bankBagFirst = NUM_BAG_SLOTS + 1
		local bankBagLast = NUM_BAG_SLOTS + (NUM_BANKBAGSLOTS or 0)
		for bagID = bankBagFirst, bankBagLast do
			local items, numSlots = ScanContainerItems(bagID)
			if numSlots > 0 then
				charData.bags[bagID] = {
					slots = numSlots,
					items = items,
					bagIcon = GetInventoryItemTexture("player", ContainerIDToInventoryID(bagID)),
				}
			else
				charData.bags[bagID] = {
					slots = 0,
					items = {},
				}
			end
		end
	end

	BankViewerDB[realm][name] = charData
	print("|cff00ccffBankViewer:|r Bank data saved for " .. name .. ".")

	if BankViewer.UpdateUI then
		BankViewer.UpdateUI()
	end
end

local function ScanWarbandBank()
	if not isWarbandBankAvailable then return end

	local warbandData = {
		tabs = {},
		lastScan = time(),
	}

	local purchasedTabs = C_Bank.FetchPurchasedBankTabData(Enum.BankType.Account)
	for tabIndex = 1, 5 do
		local bagID = Enum.BagIndex["AccountBankTab_" .. tabIndex]
		if bagID then
			local items, numSlots = ScanContainerItems(bagID)
			if numSlots > 0 then
				local tabData = purchasedTabs and purchasedTabs[tabIndex]
				warbandData.tabs[tabIndex] = {
					slots = numSlots,
					items = items,
					name = tabData and tabData.name or ("Tab " .. tabIndex),
					icon = tabData and tabData.icon,
				}
			end
		end
	end

	BankViewerDB._warband = warbandData
	print("|cff00ccffBankViewer:|r Warband bank data saved.")

	if BankViewer.UpdateUI then
		BankViewer.UpdateUI()
	end
end

local function ScanGuildBank()
	if not GetGuildBankNumTabs then return end

	local guildName = GetGuildInfo("player")
	if not guildName then return end

	local realm = GetRealmName()

	BankViewerDB._guilds = BankViewerDB._guilds or {}
	BankViewerDB._guilds[realm] = BankViewerDB._guilds[realm] or {}

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
	if guildBankHooked or not GuildBankFrame then return end

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

	pcall(frame.RegisterEvent, frame, "GUILDBANKBAGSLOTS_CHANGED")
end

frame:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == "BankViewer" then
			BankViewerDB = BankViewerDB or {}
			BankViewerDB._settings = BankViewerDB._settings or { showEmpty = true }
			BankViewerDB._guilds = BankViewerDB._guilds or {}
			BankViewerDB._warband = BankViewerDB._warband or {}
		elseif arg1 == "Blizzard_GuildBankUI" then
			HookGuildBankFrame()
		end
	elseif event == "BANKFRAME_OPENED" then
		bankOpen = true
		ScanBank()
		ScanWarbandBank()
	elseif event == "BANKFRAME_CLOSED" then
		bankOpen = false
	elseif event == "BAG_UPDATE" and bankOpen then
		ScanBank()
	elseif event == "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED" and bankOpen then
		ScanWarbandBank()
	elseif event == "GUILDBANKBAGSLOTS_CHANGED" and guildBankOpen then
		ScanGuildBank()
	end
end)

function BankViewer.Toggle()
	if BankViewerMainFrame then
		BankViewerMainFrame:SetShown(not BankViewerMainFrame:IsShown())
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

function BankViewer.GetWarbandBank()
	return BankViewerDB and BankViewerDB._warband
end

BankViewer.GetCurrentCharKey = GetCharKey

SLASH_BANKVIEWER1 = "/bv"
SLASH_BANKVIEWER2 = "/bankviewer"
SlashCmdList["BANKVIEWER"] = BankViewer.Toggle
