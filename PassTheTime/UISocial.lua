local _, PTT = ...
local L = PTT.L
local UI = PTT.UI

local REFRESH_INTERVAL = 0.5
local TOP_CONTRIBUTORS = 5

local function FormatAgo(seconds, onlineWindow)
	if seconds < (onlineWindow or PTT.Network.ACTIVE_WINDOW) then
		return "|cff55dd55" .. L.rankOnline .. "|r"
	end

	local text
	if seconds < 3600 then
		text = math.floor(seconds / 60) .. "m"
	elseif seconds < 86400 then
		text = math.floor(seconds / 3600) .. "h"
	else
		text = math.floor(seconds / 86400) .. "d"
	end
	return string.format(L.rankAgo, text)
end

---------------------------------------------------------------------------
-- Leaderboard
---------------------------------------------------------------------------

local ROW_HEIGHT = 20

local ROW_WIDTH = UI.contentWidth - 26
local COLUMN_GAP = 12

-- A nil width marks the name column, which takes the remaining space.
local COLUMNS = {
	{ key = "rank", width = 30, justify = "RIGHT" },
	{ key = "name", justify = "LEFT" },
	{ key = "gold", width = 120, justify = "RIGHT" },
	{ key = "income", width = 110, justify = "RIGHT" },
	{ key = "renown", width = 70, justify = "RIGHT" },
	{ key = "seen", width = 100, justify = "RIGHT" },
}

do
	local fixed = COLUMN_GAP * (#COLUMNS - 1) + 4
	for _, column in ipairs(COLUMNS) do
		fixed = fixed + (column.width or 0)
	end

	local x = 2
	for _, column in ipairs(COLUMNS) do
		column.width = column.width or (ROW_WIDTH - fixed)
		column.x = x
		x = x + column.width + COLUMN_GAP
	end
end

local function CollectEntries(source)
	local Network, state = PTT.Network, PTT.database.idle
	local entries = {
		{
			name = Network.GetPlayerName(),
			lifetimeGold = state.lifetimeGold,
			income = PTT.Idle.GetIncome(),
			renown = state.renownEarned,
			seconds = 0,
			you = true,
		},
	}

	if source == "group" then
		for _, player in ipairs(Network.GetGroupPlayers()) do
			entries[#entries + 1] = {
				name = player.name,
				lifetimeGold = player.lifetimeGold,
				income = player.income,
				renown = player.renown,
				seconds = GetTime() - player.lastSeen,
			}
		end
	elseif source == "realm" then
		for _, entry in pairs(Network.GetRealmRanking()) do
			if entry.name ~= Network.GetPlayerName() then
				entries[#entries + 1] = {
					name = entry.name,
					lifetimeGold = entry.lifetimeGold,
					income = entry.income,
					renown = entry.renown,
					seconds = GetServerTime() - entry.seenAt,
					onlineWindow = Network.REALM_ONLINE_WINDOW,
				}
			end
		end
	else
		for name, entry in pairs(PTT.database.guildRanking) do
			if name ~= Network.GetPlayerName() then
				local player = Network.players[name]
				entries[#entries + 1] = {
					name = name,
					lifetimeGold = entry.lifetimeGold,
					income = entry.income,
					renown = entry.renown,
					seconds = player and player.lastSeen and (GetTime() - player.lastSeen) or (GetServerTime() - entry.seenAt),
				}
			end
		end
	end

	table.sort(entries, function(first, second)
		return first.lifetimeGold > second.lifetimeGold
	end)
	return entries
end

local function BuildLeaderboardView(parent)
	local view = CreateFrame("Frame", nil, parent)
	local source = "group"

	local tabButtons = {}
	local function CreateTab(id, label, offsetX)
		local button = UI.CreateButton(view, label, 96, 24, function()
			source = id
			view.Refresh()
		end)
		button:SetPoint("TOPLEFT", offsetX, 0)
		tabButtons[id] = button
	end
	CreateTab("group", L.sourceGroup, 0)
	CreateTab("guild", L.sourceGuild, 100)
	CreateTab("realm", L.sourceRealm, 200)

	-- Every player reports their own values, so nothing stops a modified addon from faking them.
	local disclaimer = UI.CreateLabel(view, "GameFontDisableSmall", L.rankDisclaimer)
	disclaimer:SetPoint("TOPLEFT", 0, -32)
	disclaimer:SetWidth(ROW_WIDTH)
	disclaimer:SetJustifyH("LEFT")

	local headerTexts = { L.rankName, L.rankGold, L.rankIncome, L.rankRenown, L.rankSeen }
	local headerKeys = { "name", "gold", "income", "renown", "seen" }
	for index, key in ipairs(headerKeys) do
		for _, column in ipairs(COLUMNS) do
			if column.key == key then
				local label = UI.CreateLabel(view, "GameFontNormalSmall", headerTexts[index])
				label:SetPoint("TOPLEFT", disclaimer, "BOTTOMLEFT", column.x, -8)
				label:SetWidth(column.width)
				label:SetJustifyH(column.justify)
			end
		end
	end

	local scroll = CreateFrame("ScrollFrame", "PassTheTimeLeaderboardScroll", view, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", disclaimer, "BOTTOMLEFT", 0, -26)
	scroll:SetPoint("BOTTOMRIGHT", -26, 0)

	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(ROW_WIDTH, 1)
	scroll:SetScrollChild(content)

	local emptyLabel = UI.CreateLabel(view, "GameFontDisable", L.rankNobody)
	emptyLabel:SetPoint("TOP", scroll, "TOP", 0, -38)

	local rows = {}
	local function GetRow(index)
		if rows[index] then
			return rows[index]
		end

		local row = CreateFrame("Frame", nil, content)
		row:SetSize(ROW_WIDTH, ROW_HEIGHT - 2)
		row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
		row.background = row:CreateTexture(nil, "BACKGROUND")
		row.background:SetAllPoints()
		row.cells = {}
		for _, column in ipairs(COLUMNS) do
			local label = UI.CreateLabel(row, "GameFontHighlightSmall")
			label:SetPoint("LEFT", column.x, 0)
			label:SetWidth(column.width)
			label:SetJustifyH(column.justify)
			row.cells[column.key] = label
		end
		rows[index] = row
		return row
	end

	function view.Refresh()
		for id, button in pairs(tabButtons) do
			if id == source then
				button:LockHighlight()
			else
				button:UnlockHighlight()
			end
		end

		local entries = CollectEntries(source)
		local realmDisabled = source == "realm" and not PTT.database.settings.realmLeaderboard
		emptyLabel:SetText(realmDisabled and L.rankRealmDisabled or L.rankNobody)
		emptyLabel:SetShown(#entries <= 1)
		content:SetHeight(math.max(1, #entries * ROW_HEIGHT))

		for index, entry in ipairs(entries) do
			local row = GetRow(index)
			row:Show()
			row.background:SetColorTexture(1, 1, 1, entry.you and 0.14 or (index % 2 == 0 and 0.06 or 0.02))
			row.cells.rank:SetText(index)
			row.cells.name:SetText(entry.you and (entry.name .. " |cff999999" .. L.you .. "|r") or entry.name)
			row.cells.gold:SetText(PTT.FormatNumber(entry.lifetimeGold))
			row.cells.income:SetText(PTT.FormatNumber(entry.income))
			row.cells.renown:SetText(entry.renown)
			row.cells.seen:SetText(FormatAgo(entry.seconds, entry.onlineWindow))
		end

		for index = #entries + 1, #rows do
			rows[index]:Hide()
		end
	end

	local elapsed = 0
	view:SetScript("OnUpdate", function(_, delta)
		elapsed = elapsed + delta
		if elapsed >= 1 then
			elapsed = 0
			view.Refresh()
		end
	end)
	view:HookScript("OnShow", view.Refresh)
	view.Refresh()
	return view
end

PTT.RegisterView({ id = "leaderboard", label = "leaderboard", build = BuildLeaderboardView })

---------------------------------------------------------------------------
-- Bosses
---------------------------------------------------------------------------

local function CreateBar(parent, offsetY)
	local bar = UI.CreateSkillBar(parent, 16, { 0.75, 0.15, 0.15 })
	bar:SetPoint("TOPLEFT", 5, offsetY)
	bar:SetPoint("TOPRIGHT", -5, offsetY)
	return bar
end

local function FormatContributions(contributions)
	local list = {}
	for name, damage in pairs(contributions) do
		list[#list + 1] = { name = name, damage = damage }
	end
	table.sort(list, function(first, second)
		return first.damage > second.damage
	end)

	local lines = {}
	for index = 1, math.min(#list, TOP_CONTRIBUTORS) do
		lines[index] = string.format("%d. %s  |cff999999%s|r", index, list[index].name, PTT.FormatNumber(list[index].damage))
	end
	return table.concat(lines, "\n")
end

local function UpdateBar(bar, remaining, maximum)
	bar:SetValue(maximum > 0 and math.max(0, math.min(1, remaining / maximum)) or 0)
	bar.text:SetText(string.format(L.bossHealth, PTT.FormatNumber(math.max(0, remaining)), PTT.FormatNumber(maximum)))
end

local function BuildBossesView(parent)
	local Bosses = PTT.Bosses
	local view = CreateFrame("Frame", nil, parent)

	-- Group boss
	local groupHeader = UI.CreateLabel(view, "GameFontNormalLarge", L.groupBoss)
	groupHeader:SetPoint("TOPLEFT", 0, -2)

	local startButton = UI.CreateButton(view, L.bossStart, 160, 24, function()
		Bosses.StartGroupBoss()
		view.Refresh()
	end)
	startButton:SetPoint("TOPRIGHT", 0, 0)

	local groupBar = CreateBar(view, -28)
	local groupInfo = UI.CreateLabel(view, "GameFontHighlightSmall")
	groupInfo:SetPoint("TOPLEFT", 2, -52)
	local groupContributions = UI.CreateLabel(view, "GameFontHighlightSmall")
	groupContributions:SetPoint("TOPLEFT", 2, -70)
	groupContributions:SetJustifyH("LEFT")

	-- Guild boss
	local guildHeader = UI.CreateLabel(view, "GameFontNormalLarge", L.bossGuildWeek)
	guildHeader:SetPoint("TOPLEFT", 0, -180)

	local guildBar = CreateBar(view, -206)
	local guildInfo = UI.CreateLabel(view, "GameFontHighlightSmall")
	guildInfo:SetPoint("TOPLEFT", 2, -230)
	local guildContributions = UI.CreateLabel(view, "GameFontHighlightSmall")
	guildContributions:SetPoint("TOPLEFT", 2, -248)
	guildContributions:SetJustifyH("LEFT")

	function view.Refresh()
		-- Group boss
		local boss = Bosses.group
		local hasGroup = PTT.Network.GetGroupChannel() ~= nil
		startButton:SetEnabled(hasGroup and not Bosses.IsGroupBossActive() and PTT.Idle.GetIncome() > 0)

		if boss then
			local total = Bosses.GetTotal(boss.contributions)
			UpdateBar(groupBar, boss.health - total, boss.health)

			if boss.finished then
				groupInfo:SetText(boss.victory and ("|cff55dd55" .. L.bossVictory .. "|r") or ("|cffdd5555" .. L.bossDefeat .. "|r"))
			else
				groupInfo:SetText(string.format(L.bossTimeLeft, PTT.FormatDuration(Bosses.GetGroupTimeLeft()))
					.. "     " .. string.format(L.bossYourDamage, PTT.FormatNumber(boss.myDamage)))
			end
			groupContributions:SetText(FormatContributions(boss.contributions))
		else
			UpdateBar(groupBar, 0, 0)
			groupInfo:SetText("|cff999999" .. (hasGroup and L.bossNoActive or L.bossNeedGroup) .. "|r")
			groupContributions:SetText("")
		end

		-- Guild boss
		if PTT.Network.GetGuildChannel() then
			local guildBoss = Bosses.GetGuildBoss()
			local total = Bosses.GetTotal(guildBoss.contributions)
			UpdateBar(guildBar, guildBoss.health - total, guildBoss.health)

			if Bosses.IsGuildBossDefeated() then
				guildInfo:SetText("|cff55dd55" .. L.bossGuildDefeated .. "|r")
			else
				guildInfo:SetText(string.format(L.bossYourDamage, PTT.FormatNumber(guildBoss.damage)) .. "     |cff999999" .. L.bossGuildProgress .. "|r")
			end
			guildContributions:SetText(FormatContributions(guildBoss.contributions))
		else
			UpdateBar(guildBar, 0, 0)
			guildInfo:SetText("|cff999999" .. L.bossGuildNeedGuild .. "|r")
			guildContributions:SetText("")
		end
	end

	local elapsed = 0
	view:SetScript("OnUpdate", function(_, delta)
		elapsed = elapsed + delta
		if elapsed >= REFRESH_INTERVAL then
			elapsed = 0
			view.Refresh()
		end
	end)
	view:HookScript("OnShow", view.Refresh)
	view.Refresh()
	return view
end

PTT.RegisterView({ id = "bosses", label = "bosses", build = BuildBossesView })
