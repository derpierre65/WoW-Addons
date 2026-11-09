local _, PTT = ...
local L = PTT.L
local UI = PTT.UI

---------------------------------------------------------------------------
-- Toast
---------------------------------------------------------------------------

local toast

function UI.Toast(text)
	if not toast then
		toast = UI.CreatePanel(UIParent)
		toast:SetSize(380, 40)
		toast:SetPoint("TOP", UIParent, "TOP", 0, -110)
		toast:SetFrameStrata("DIALOG")
		toast.label = UI.CreateLabel(toast, "GameFontNormal")
		toast.label:SetPoint("CENTER")
		toast.age = 0
		toast:SetScript("OnUpdate", function(self, delta)
			self.age = self.age + delta
			if self.age >= 4 then
				self:Hide()
			elseif self.age > 3 then
				self:SetAlpha(4 - self.age)
			end
		end)
	end

	toast.label:SetText(text)
	toast.age = 0
	toast:SetAlpha(1)
	toast:Show()
end

---------------------------------------------------------------------------
-- Random event
---------------------------------------------------------------------------

function UI.BuildEventFrame()
	local Events = PTT.Events

	local frame = UI.CreatePanel(UIParent)
	frame:SetSize(320, 96)
	frame:SetPoint("TOP", UIParent, "TOP", 0, -170)
	frame:SetFrameStrata("FULLSCREEN_DIALOG")
	frame:EnableMouse(true)
	frame:Hide()
	frame:SetBackdropColor(0.15, 0.1, 0, 0.97)

	local highlight = frame:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetAllPoints()
	highlight:SetColorTexture(1, 1, 1, 0.12)

	local title = UI.CreateLabel(frame, "GameFontNormalLarge")
	title:SetFont(select(1, title:GetFont()), 22, "OUTLINE")
	title:SetPoint("TOP", 0, -16)
	title:SetTextColor(1, 0.82, 0)
	local subtitle = UI.CreateLabel(frame, "GameFontHighlight")
	subtitle:SetPoint("TOP", title, "BOTTOM", 0, -8)

	local pulse = 0
	frame:SetScript("OnShow", function()
		pulse = 0
		frame:SetBackdropBorderColor(1, 0.82, 0, 1)
		if PlaySound and SOUNDKIT and SOUNDKIT.READY_CHECK then
			PlaySound(SOUNDKIT.READY_CHECK)
		end
	end)

	frame:SetScript("OnMouseUp", function()
		local message = Events.Claim()
		if message then
			UI.Toast(message)
		end
	end)

	frame:SetScript("OnUpdate", function(_, delta)
		pulse = pulse + delta
		-- Pulsing border so the event cannot be missed.
		local strength = 0.5 + 0.5 * math.sin(pulse * 6)
		frame:SetBackdropBorderColor(1, 0.5 + 0.4 * strength, 0.1 * strength, 1)
		if Events.active then
			subtitle:SetText(string.format("%s (%d s)", L.eventClickNow, math.ceil(Events.active.remaining)))
		end
	end)

	Events.On("spawn", function(active)
		title:SetText(L[active.definition.nameKey])
		frame:Show()
	end)
	Events.On("finish", function()
		frame:Hide()
	end)
	Events.On("claim", function()
		frame:Hide()
	end)
end

---------------------------------------------------------------------------
-- Achievements view
---------------------------------------------------------------------------

local CARD_HEIGHT = 66
local CARD_GAP = 8
local CARD_COLUMNS = 2
local CHIP_HEIGHT = 24

local CATEGORY_ICONS = {
	combat = "Interface\\Icons\\INV_Sword_04",
	wealth = "Interface\\Icons\\INV_Misc_Coin_01",
	clicking = "Interface\\Icons\\INV_Misc_Gear_01",
	progress = "Interface\\Icons\\INV_Misc_Note_01",
	minigames = "Interface\\Icons\\INV_Misc_Dice_01",
}

---------------------------------------------------------------------------
-- Achievement banner
---------------------------------------------------------------------------

local BANNER_FADE_IN, BANNER_HOLD, BANNER_FADE_OUT = 0.3, 4, 0.7
local banner
local bannerQueue = {}

local function CreateBanner()
	local frame = UI.CreatePanel(UIParent)
	frame:SetSize(340, 62)
	frame:SetPoint("TOP", UIParent, "TOP", 0, -50)
	frame:SetFrameStrata("DIALOG")
	frame:SetBackdropColor(0.08, 0.06, 0.03, 0.96)
	frame:SetBackdropBorderColor(0.9, 0.7, 0.2, 1)
	frame:EnableMouse(true)
	frame:Hide()

	frame.iconFrame = UI.CreatePanel(frame)
	frame.iconFrame:SetSize(44, 44)
	frame.iconFrame:SetPoint("LEFT", 10, 0)
	frame.iconFrame:SetBackdropColor(0.11, 0.09, 0.07, 1)
	frame.iconFrame:SetBackdropBorderColor(0.9, 0.7, 0.2, 1)
	frame.icon = frame.iconFrame:CreateTexture(nil, "ARTWORK")
	frame.icon:SetPoint("TOPLEFT", 5, -5)
	frame.icon:SetPoint("BOTTOMRIGHT", -5, 5)

	frame.pointsLabel = UI.CreateLabel(frame, "GameFontNormalLarge")
	frame.pointsLabel:SetPoint("RIGHT", -14, 0)

	frame.headerLabel = UI.CreateLabel(frame, "GameFontNormalSmall", L.addonTitle)
	frame.headerLabel:SetPoint("TOPLEFT", frame.iconFrame, "TOPRIGHT", 10, -2)
	frame.headerLabel:SetTextColor(0.9, 0.7, 0.2)

	frame.nameLabel = UI.CreateLabel(frame, "GameFontHighlightLarge")
	frame.nameLabel:SetPoint("TOPLEFT", frame.headerLabel, "BOTTOMLEFT", 0, -4)
	frame.nameLabel:SetPoint("RIGHT", frame.pointsLabel, "LEFT", -8, 0)
	frame.nameLabel:SetJustifyH("LEFT")
	frame.nameLabel:SetWordWrap(false)

	frame:SetScript("OnMouseUp", function(self)
		self.age = math.max(self.age, BANNER_FADE_IN + BANNER_HOLD)
	end)

	frame:SetScript("OnUpdate", function(self, delta)
		self.age = self.age + delta
		local fadeOutStart = BANNER_FADE_IN + BANNER_HOLD
		if self.age >= fadeOutStart + BANNER_FADE_OUT then
			self:Hide()
			local nextDefinition = table.remove(bannerQueue, 1)
			if nextDefinition then
				UI.ShowAchievementBanner(nextDefinition)
			end
		elseif self.age > fadeOutStart then
			self:SetAlpha(1 - (self.age - fadeOutStart) / BANNER_FADE_OUT)
		else
			self:SetAlpha(math.min(1, self.age / BANNER_FADE_IN))
		end
	end)

	return frame
end

-- Shown like the game's own achievement alert; further ones wait their turn.
function UI.ShowAchievementBanner(definition)
	banner = banner or CreateBanner()
	if banner:IsShown() and banner.definition ~= definition then
		bannerQueue[#bannerQueue + 1] = definition
		return
	end

	banner.definition = definition
	banner.icon:SetTexture(CATEGORY_ICONS[definition.category])
	banner.nameLabel:SetText(PTT.Achievements.GetName(definition))
	banner.pointsLabel:SetText(definition.points)
	banner.age = 0
	banner:SetAlpha(0)
	banner:Show()
end

local CARD_COLORS = {
	earned = { background = { 0.106, 0.09, 0.059 }, border = { 0.42, 0.34, 0.19 }, icon = { 0.79, 0.6, 0.18 }, title = { 1, 0.82, 0 } },
	open = { background = { 0.063, 0.055, 0.043 }, border = { 0.18, 0.15, 0.11 }, icon = { 0.23, 0.19, 0.13 }, title = { 0.93, 0.89, 0.82 } },
}


local function CreateAchievementCard(parent, definition, width)
	local card = UI.CreatePanel(parent)
	card:SetSize(width, CARD_HEIGHT)
	card.definition = definition

	card.iconFrame = UI.CreatePanel(card)
	card.iconFrame:SetSize(44, 44)
	card.iconFrame:SetPoint("LEFT", 10, 0)
	card.iconFrame:SetBackdropColor(0.11, 0.09, 0.07, 1)
	card.icon = card.iconFrame:CreateTexture(nil, "ARTWORK")
	card.icon:SetPoint("TOPLEFT", 5, -5)
	card.icon:SetPoint("BOTTOMRIGHT", -5, 5)
	card.icon:SetTexture(CATEGORY_ICONS[definition.category])

	card.pointsLabel = UI.CreateLabel(card, "GameFontNormalSmall")
	card.pointsLabel:SetPoint("TOPRIGHT", -10, -10)

	card.titleLabel = UI.CreateLabel(card, "GameFontNormal")
	card.titleLabel:SetPoint("TOPLEFT", card.iconFrame, "TOPRIGHT", 10, 0)
	card.titleLabel:SetPoint("RIGHT", card.pointsLabel, "LEFT", -6, 0)
	card.titleLabel:SetJustifyH("LEFT")
	card.titleLabel:SetWordWrap(false)

	card.descriptionLabel = UI.CreateLabel(card, "GameFontHighlightSmall")
	card.descriptionLabel:SetPoint("TOPLEFT", card.titleLabel, "BOTTOMLEFT", 0, -3)
	card.descriptionLabel:SetPoint("RIGHT", card, "RIGHT", -10, 0)
	card.descriptionLabel:SetJustifyH("LEFT")
	card.descriptionLabel:SetWordWrap(false)
	card.descriptionLabel:SetTextColor(0.64, 0.6, 0.51)

	card.earnedLabel = UI.CreateLabel(card, "GameFontHighlightSmall")
	card.earnedLabel:SetPoint("BOTTOMLEFT", card.iconFrame, "BOTTOMRIGHT", 10, 0)
	card.earnedLabel:SetTextColor(0.56, 0.82, 0.42)

	card.progressBar = UI.CreateSkillBar(card, 14)
	card.progressBar:SetPoint("BOTTOMLEFT", card.iconFrame, "BOTTOMRIGHT", 13, 3)
	card.progressBar:SetPoint("RIGHT", card, "RIGHT", -13, 0)

	return card
end

local function RefreshAchievementCard(card)
	local Achievements = PTT.Achievements
	local definition = card.definition
	local earned = Achievements.IsUnlocked(definition)
	local colors = earned and CARD_COLORS.earned or CARD_COLORS.open

	card:SetBackdropColor(colors.background[1], colors.background[2], colors.background[3], 1)
	card:SetBackdropBorderColor(colors.border[1], colors.border[2], colors.border[3], 1)
	card.iconFrame:SetBackdropBorderColor(colors.icon[1], colors.icon[2], colors.icon[3], 1)
	card.icon:SetDesaturated(not earned)
	card.icon:SetAlpha(earned and 1 or 0.55)

	card.titleLabel:SetText(Achievements.GetName(definition))
	card.titleLabel:SetTextColor(colors.title[1], colors.title[2], colors.title[3])
	card.pointsLabel:SetText(string.format(L.achievementPointsShort, definition.points))
	card.pointsLabel:SetTextColor(colors.title[1], colors.title[2], colors.title[3])
	card.descriptionLabel:SetText(Achievements.GetDescription(definition))

	card.earnedLabel:SetShown(earned)
	card.progressBar:SetShown(not earned)

	if earned then
		card.earnedLabel:SetText(string.format(L.achievementEarnedOn, date("%d.%m.%Y", Achievements.GetUnlockTime(definition))))
	else
		local value, target = Achievements.GetProgress(definition)
		local format = definition.format or PTT.FormatNumber
		card.progressBar:SetValue(value / target)
		card.progressBar.text:SetText(format(value) .. " / " .. format(target))
	end
end

local function BuildAchievementsView(parent)
	local Achievements = PTT.Achievements
	local view = CreateFrame("Frame", nil, parent)
	local activeCategory = "all"

	local title = UI.CreateLabel(view, "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 0, 0)
	title:SetText(L.achievements)
	local subtitle = UI.CreateLabel(view, "GameFontDisableSmall")
	subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)

	local pointsBar = UI.CreateSkillBar(view, 14)
	pointsBar:SetWidth(240)
	pointsBar:SetPoint("TOPRIGHT", -3, -26)
	local pointsLabel = UI.CreateLabel(view, "GameFontDisableSmall", L.achievementPoints)
	pointsLabel:SetPoint("BOTTOMLEFT", pointsBar, "TOPLEFT", 0, 6)

	local scroll = CreateFrame("ScrollFrame", "PassTheTimeAchievementScroll", view, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 0, -90)
	scroll:SetPoint("BOTTOMRIGHT", -30, 0)

	-- This view has no navigation column, so it spans the full window; the scroll bar needs the right margin.
	local contentWidth = UI.fullContentWidth - 30
	local cardWidth = math.floor((contentWidth - CARD_GAP * (CARD_COLUMNS - 1)) / CARD_COLUMNS)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(contentWidth, 1)
	scroll:SetScrollChild(content)

	local cards = {}
	for index, definition in ipairs(Achievements.definitions) do
		cards[index] = CreateAchievementCard(content, definition, cardWidth)
	end

	local chips = {}

	local function Layout()
		local position = 0
		for _, card in ipairs(cards) do
			if activeCategory == "all" or card.definition.category == activeCategory then
				local column = position % CARD_COLUMNS
				local row = math.floor(position / CARD_COLUMNS)
				card:ClearAllPoints()
				card:SetPoint("TOPLEFT", column * (cardWidth + CARD_GAP), -row * (CARD_HEIGHT + CARD_GAP))
				card:Show()
				position = position + 1
			else
				card:Hide()
			end
		end
		content:SetHeight(math.max(1, math.ceil(position / CARD_COLUMNS) * (CARD_HEIGHT + CARD_GAP)))
	end

	local function Refresh()
		local earned, total = Achievements.GetPoints()
		subtitle:SetText(string.format(L.achievementsEarned, Achievements.CountUnlocked(), #Achievements.definitions))
		pointsBar.text:SetText(earned .. " / " .. total)
		pointsBar:SetValue(total > 0 and earned / total or 0)

		for id, chip in pairs(chips) do
			if id == activeCategory then
				chip:LockHighlight()
			else
				chip:UnlockHighlight()
			end
		end

		for _, card in ipairs(cards) do
			RefreshAchievementCard(card)
		end
	end

	local previousChip
	local categoryIds = { "all" }
	for _, id in ipairs(Achievements.categories) do
		categoryIds[#categoryIds + 1] = id
	end

	for _, id in ipairs(categoryIds) do
		local label = L["category" .. id:sub(1, 1):upper() .. id:sub(2)]
		local chip = UI.CreateButton(view, label, math.max(60, #label * 8 + 20), CHIP_HEIGHT, function()
			activeCategory = id
			Layout()
			Refresh()
		end)
		if previousChip then
			chip:SetPoint("LEFT", previousChip, "RIGHT", 6, 0)
		else
			chip:SetPoint("TOPLEFT", 0, -56)
		end
		chips[id] = chip
		previousChip = chip
	end

	Layout()
	view:HookScript("OnShow", Refresh)
	Refresh()
	return view
end

PTT.RegisterView({ id = "achievements", label = "achievements", build = BuildAchievementsView })

---------------------------------------------------------------------------
-- Stats view
---------------------------------------------------------------------------

local STAT_ROW_HEIGHT = 26
local STAT_CARD_GAP = 12
local STAT_CARD_HEADER = 40
local GOLD_VALUE_COLOR = "|cffffd100"

local function BuildStatsView(parent)
	local Idle = PTT.Idle
	local view = CreateFrame("Frame", nil, parent)

	-- highlight paints the value gold; counters tolerate saves from before the field existed.
	local cards = {
		{
			title = "statsCombat",
			stats = {
				{ label = "statEnemies", value = function(state) return PTT.FormatNumber(state.lifetimeKills - state.bossKills) end },
				{ label = "statBosses", value = function(state) return PTT.FormatNumber(state.bossKills) end },
				{ label = "statGroupBosses", value = function(state) return PTT.FormatNumber(state.groupBossKills) end },
				{ label = "statGuildBosses", value = function(state) return PTT.FormatNumber(state.guildBossKills) end },
				{ label = "statHighestEnemy", value = function(state) return string.format(L.levelShort, math.max(state.highestEnemy or 1, state.unlocked)) end },
				{ label = "statClicks", value = function(state) return PTT.FormatNumber(state.clicks) end },
				{ label = "statClickDamage", value = function() return PTT.FormatNumber(Idle.GetClickDamage()) end },
				{ label = "statDamagePerSecond", value = function() return PTT.FormatNumber(Idle.GetDamagePerSecond()) end },
			},
		},
		{
			title = "statsEconomy",
			stats = {
				{ label = "statGoldEarned", highlight = true, value = function(state) return PTT.FormatNumber(state.lifetimeGold) end },
				{ label = "statGoldSpent", value = function(state) return PTT.FormatNumber(state.goldSpent or 0) end },
				{
					label = "statGoldPerHour",
					highlight = true,
					value = function(state)
						return PTT.FormatNumber(state.totalTime > 0 and state.lifetimeGold / state.totalTime * 3600 or 0)
					end,
				},
				{ label = "statBestReward", highlight = true, value = function(state) return PTT.FormatNumber(state.bestReward or 0) end },
				{ label = "statRenownEarned", value = function(state) return PTT.FormatNumber(state.renownEarned) end },
				{ label = "statPrestiges", value = function(state) return PTT.FormatNumber(state.prestiges) end },
			},
		},
		{
			title = "statsProgress",
			stats = {
				{ label = "statActiveTime", value = function(state) return PTT.FormatDuration(state.totalTime) end },
				{ label = "statSessions", value = function(state) return PTT.FormatNumber(state.sessions or 0) end },
				{ label = "statLongestSession", value = function(state) return PTT.FormatDuration(state.longestSession or 0) end },
				{
					label = "statAchievements",
					value = function()
						return string.format("%d / %d", PTT.Achievements.CountUnlocked(), #PTT.Achievements.definitions)
					end,
				},
				{ label = "statAchievementPoints", highlight = true, value = function() return PTT.FormatNumber((PTT.Achievements.GetPoints())) end },
				{ label = "statWorldBonuses", value = function(state) return PTT.FormatNumber(state.worldBonuses or 0) end },
			},
		},
	}

	local cardWidth = math.floor((UI.contentWidth - 2 * STAT_CARD_GAP) / 3)
	local tallestCard = 0
	for _, card in ipairs(cards) do
		tallestCard = math.max(tallestCard, #card.stats)
	end

	local valueLabels = {}
	for cardIndex, card in ipairs(cards) do
		local panel = UI.CreatePanel(view)
		panel:SetSize(cardWidth, STAT_CARD_HEADER + tallestCard * STAT_ROW_HEIGHT + 12)
		panel:SetPoint("TOPLEFT", (cardIndex - 1) * (cardWidth + STAT_CARD_GAP), 0)
		panel:SetBackdropColor(0.08, 0.08, 0.12, 0.9)

		local title = UI.CreateLabel(panel, "GameFontNormalSmall", L[card.title]:upper())
		title:SetPoint("TOPLEFT", 14, -14)

		local divider = panel:CreateTexture(nil, "ARTWORK")
		divider:SetColorTexture(1, 0.82, 0, 0.25)
		divider:SetHeight(1)
		divider:SetPoint("TOPLEFT", 14, -32)
		divider:SetPoint("TOPRIGHT", -14, -32)

		for statIndex, stat in ipairs(card.stats) do
			local top = -(STAT_CARD_HEADER + (statIndex - 1) * STAT_ROW_HEIGHT)
			local nameLabel = UI.CreateLabel(panel, "GameFontNormal", L[stat.label])
			nameLabel:SetPoint("TOPLEFT", 14, top)
			nameLabel:SetTextColor(0.8, 0.8, 0.8)
			local valueLabel = UI.CreateLabel(panel, "GameFontHighlight")
			valueLabel:SetPoint("TOPRIGHT", -14, top)
			valueLabels[#valueLabels + 1] = { label = valueLabel, stat = stat }
		end
	end

	local function Refresh()
		local state = PTT.database.idle
		for _, entry in ipairs(valueLabels) do
			local text = entry.stat.value(state)
			entry.label:SetText(entry.stat.highlight and (GOLD_VALUE_COLOR .. text .. "|r") or text)
		end
	end

	local elapsed = 0
	view:SetScript("OnUpdate", function(_, delta)
		elapsed = elapsed + delta
		if elapsed >= 0.5 then
			elapsed = 0
			Refresh()
		end
	end)
	view:HookScript("OnShow", Refresh)
	Refresh()
	return view
end

PTT.RegisterView({ id = "stats", label = "stats", build = BuildStatsView })
