local _, PTT = ...
local L = PTT.L
local UI = PTT.UI
local Idle = PTT.Idle

local ROW_HEIGHT = 38
local MODEL_HEIGHT = 380
local MONSTER_ROW_HEIGHT = 24
local REFRESH_INTERVAL = 0.2
local LIST_TOP = -34
local MONSTER_LIST_TOP = 0
-- Heroes and the click upgrade carry a row of spell icons below their text.
local SPELL_ROW_HEIGHT = 72
local SPELL_ICON_SIZE = 28
local MAX_ROWS = 9
local CHECK_TEXTURE = "Interface\\Buttons\\UI-CheckBox-Check"
local ICON_PATH = "Interface\\Icons\\"

-- Icon file names per hero id, one per spell.
local SPELL_ICONS = {
	click = { "Ability_MeleeDamage", "INV_Sword_27", "Ability_DualWield", "Ability_Warrior_Sunder", "Ability_Warrior_BattleShout", "Ability_Warrior_Rampage" },
	recruit = { "Ability_Rogue_Ambush", "Ability_Gouge", "Ability_Whirlwind", "Ability_Warrior_SavageBlow", "Ability_CriticalStrike" },
	scout = { "Spell_Shadow_RitualOfSacrifice", "Ability_BackStab", "Ability_Warrior_PunishingBlow", "Spell_Shadow_ShadowWordDominate", "Spell_Ice_Lament" },
	footman = { "Spell_Nature_Lightning", "Spell_Fire_FlameShock", "Spell_Holy_SealOfMight", "Spell_Nature_ChainLightning", "Spell_Nature_WispHeal" },
	hunter = { "Ability_ImpalingBolt", "Ability_UpgradeMoonGlaive", "INV_Spear_07", "Ability_Hunter_RunningShot", "Ability_TrueShot" },
	mage = { "Spell_Fire_FlameBolt", "Spell_Holy_MagicalSentry", "Spell_Fire_Fireball02", "Spell_Holy_ArcaneIntellect", "Spell_Fire_SealOfFire" },
	warlock = { "Spell_Shadow_ShadowBolt", "Spell_Shadow_ChillTouch", "Spell_Fire_Immolation", "Spell_Shadow_Contagion", "Spell_Shadow_DeathCoil" },
	paladin = { "Ability_Warrior_InnerRage", "Spell_Holy_FistOfJustice", "Spell_Holy_RighteousFury", "Spell_Magic_MageArmor", "Spell_Holy_AvengineWrath" },
	slayer = { "Spell_Holy_HolySmite", "Spell_Holy_WordFortitude", "Spell_Shadow_UnholyFrenzy", "Spell_Holy_PrayerOfSpirit", "Spell_Holy_SearingLight" },
}

-- Left column: the selected list or panel. Right column: current enemy.
local ENEMY_WIDTH = 320
local ENEMY_X = UI.contentWidth - ENEMY_WIDTH
local LIST_WIDTH = ENEMY_X - 14
local AMOUNTS = { 1, 10, 100, "max" }

local function GetState()
	return PTT.database.idle
end

local function GetEntries(tabId)
	local entries = {}
	if tabId == "ally" then
		entries[1] = { kind = "upgrade", definition = Idle.definitions.upgrade[1] }
		local revealed = Idle.UpdateRevealedHeroes()
		for index, definition in ipairs(Idle.definitions.ally) do
			if index <= revealed then
				entries[#entries + 1] = { kind = "ally", definition = definition }
			end
		end
	elseif tabId == "profession" then
		for _, definition in ipairs(Idle.definitions.profession) do
			entries[#entries + 1] = { kind = "profession", definition = definition }
		end
	end
	return entries
end

-- How many units one press on the buy button buys (at least 1, so the cost can always be shown).
local function ResolveAmount(kind, definition)
	local capacity = Idle.GetRemainingCapacity(kind, definition)
	if capacity <= 0 then
		return 0
	end

	local mode = GetState().buyAmount
	if mode == "max" then
		return math.max(1, Idle.GetMaxAffordable(kind, definition))
	end
	return math.min(mode, capacity)
end

local function GetDetailText(kind, definition)
	local owned = Idle.GetOwned(kind, definition.id)
	local gray = "  |cff999999%s|r"

	if kind == "upgrade" then
		return string.format(L.clickDamage, PTT.FormatNumber(Idle.GetClickDamage()))
	elseif kind == "ally" then
		local multiplier = Idle.GetDamageMultiplier()
		local current = PTT.FormatNumber(Idle.GetAllyDamage(definition) * multiplier) .. " " .. L.damagePerSecond
		return current .. string.format(gray, string.format(L.damageEach, PTT.FormatNumber(Idle.GetAllyUnitDamage(definition) * multiplier)))
	end

	local bonus
	if definition.effect == "bossTime" then
		bonus = string.format(L.professionBossTime, definition.perLevel)
	else
		bonus = string.format(L["profession_" .. definition.effect], definition.perLevel * 100)
	end
	return string.format(L.level, owned) .. " / " .. Idle.PROFESSION_MAX_LEVEL .. string.format(gray, bonus)
end

local function GetSpellEffectText(spell)
	if spell.click then
		return string.format(L.spellClickDamage, spell.click * 100)
	elseif spell.clickShare then
		return string.format(L.spellClickShare, spell.clickShare * 100)
	elseif spell.gold then
		return string.format(L.spellGold, spell.gold * 100)
	elseif spell.all then
		return string.format(L.spellAllDamage, spell.all * 100)
	end
	return string.format(L.spellOwnDamage, spell.own * 100)
end

local function ShowSpellTooltip(button)
	local spell = button.spell
	if not spell then
		return
	end

	GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
	GameTooltip:AddLine(Idle.GetName(spell))
	GameTooltip:AddLine(GetSpellEffectText(spell), 1, 1, 1)

	if Idle.IsSpellBought(spell) then
		GameTooltip:AddLine(L.spellUnlocked, 0.2, 1, 0.2)
	elseif Idle.GetBalance("ally") >= spell.cost then
		GameTooltip:AddLine(string.format(L.spellCost, PTT.FormatNumber(spell.cost)), 1, 0.82, 0)
	else
		GameTooltip:AddLine(string.format(L.spellCost, PTT.FormatNumber(spell.cost)), 1, 0.2, 0.2)
	end
	GameTooltip:Show()
end

local function CreateSpellButton(row, position, onChange)
	local button = CreateFrame("Button", nil, row, BackdropTemplateMixin and "BackdropTemplate" or nil)
	button:SetSize(SPELL_ICON_SIZE, SPELL_ICON_SIZE)
	button:SetPoint("BOTTOMLEFT", 6 + (position - 1) * (SPELL_ICON_SIZE + 6), 6)
	button:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10 })

	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetPoint("TOPLEFT", 2, -2)
	button.icon:SetPoint("BOTTOMRIGHT", -2, 2)
	button.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

	button.check = button:CreateTexture(nil, "OVERLAY")
	button.check:SetSize(SPELL_ICON_SIZE * 0.7, SPELL_ICON_SIZE * 0.7)
	button.check:SetPoint("BOTTOMRIGHT", 3, -3)
	button.check:SetTexture(CHECK_TEXTURE)

	button:SetScript("OnClick", function()
		if button.spell and Idle.BuySpell(button.spell) then
			onChange()
		end
	end)
	button:SetScript("OnEnter", ShowSpellTooltip)
	button:SetScript("OnLeave", UI.HideTooltip)
	return button
end

-- Visible spells; colored when they can be bought, gray otherwise. Returns whether any are shown.
local function UpdateSpellButtons(row, id)
	local spells = Idle.spells[id]
	local anyShown = false

	for position, button in ipairs(row.spellButtons) do
		local spell = spells and spells[position]
		if not spell or not Idle.IsSpellVisible(spell) then
			button:Hide()
			button.spell = nil
		else
			anyShown = true
			button:Show()
			button.spell = spell
			button.icon:SetTexture(ICON_PATH .. ((SPELL_ICONS[id] or {})[position] or "INV_Misc_QuestionMark"))

			if Idle.IsSpellBought(spell) then
				button.icon:SetVertexColor(1, 1, 1)
				button.check:Show()
				button:SetBackdropBorderColor(0.2, 1, 0.2, 1)
			else
				local usable = Idle.CanBuySpell(spell)
				button.icon:SetVertexColor(usable and 1 or 0.4, usable and 1 or 0.4, usable and 1 or 0.4)
				button.check:Hide()
				button:SetBackdropBorderColor(usable and 1 or 0.4, usable and 0.82 or 0.4, usable and 0 or 0.4, 1)
			end
		end
	end
	return anyShown
end

local function ShowRowTooltip(row)
	local definition, kind = row.definition, row.kind
	if not definition then
		return
	end

	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	GameTooltip:AddLine(Idle.GetName(definition))

	if kind == "ally" then
		GameTooltip:AddLine(string.format(L.totalDamage, PTT.FormatNumber(Idle.GetAllyDamage(definition) * Idle.GetDamageMultiplier())), 1, 1, 1)
	end
	GameTooltip:Show()
end

-- Floating combat text that rises and fades, starting inside the model area.
local FLOATER_START = -110
local function CreateFloater(parent, anchor, offsetX, color)
	local floater = CreateFrame("Frame", nil, parent)
	floater:SetSize(140, 20)
	floater:SetFrameLevel(parent:GetFrameLevel() + 10)
	floater.text = UI.CreateLabel(floater, "GameFontNormalLarge")
	floater.text:SetPoint("CENTER")
	floater.text:SetTextColor(color[1], color[2], color[3])
	floater.anchor, floater.offsetX, floater.age = anchor, offsetX, 1
	floater:Hide()
	return floater
end

local function ShowFloater(floater, text)
	floater.text:SetText(text)
	floater.age = 0
	floater:Show()
end

local function UpdateFloater(floater, delta)
	if not floater:IsShown() then
		return
	end

	floater.age = floater.age + delta
	if floater.age >= 0.7 then
		floater:Hide()
		return
	end

	floater:SetAlpha(1 - floater.age / 0.7)
	floater:ClearAllPoints()
	floater:SetPoint("BOTTOM", floater.anchor, "TOP", floater.offsetX, FLOATER_START + floater.age * 28)
end

local BOSS_COLOR, NORMAL_COLOR = "|cffff8800", "|cffffd100"

-- Per NPC id: zoom multiplier (above 1 zooms out), z moves it up/down, y left/right.
local MODEL_ADJUSTMENTS = {
	[12201] = { zoom = 2 }, -- Princess Theradras
	[11502] = { z = -4 }, -- Ragnaros
}

local function BuildIdleView(parent)
	local view = CreateFrame("Frame", nil, parent)
	local activeTab = "monster"

	-- Monster panel
	local monsterName = UI.CreateLabel(view, "GameFontNormalLarge")
	monsterName:SetPoint("TOP", view, "TOPLEFT", ENEMY_X + ENEMY_WIDTH / 2, -2)

	local healthBar = UI.CreateSkillBar(view, 16, { 0.75, 0.15, 0.15 }, "GameFontHighlight")
	healthBar:SetPoint("TOPLEFT", ENEMY_X + 5, -30)
	healthBar:SetWidth(ENEMY_WIDTH - 10)
	healthBar.timerText = UI.CreateLabel(healthBar, "GameFontHighlight")
	healthBar.timerText:SetPoint("RIGHT", -8, 0)

	-- The enemy itself is the attack button: click the 3D model.
	local modelHolder = UI.CreatePanel(view)
	modelHolder:SetSize(ENEMY_WIDTH, MODEL_HEIGHT)
	modelHolder:SetPoint("TOPLEFT", ENEMY_X, -52)
	modelHolder:SetBackdropColor(0.02, 0.02, 0.04, 0.9)

	-- Progress towards the next enemy tier.
	local tierLabel = UI.CreateLabel(view, "GameFontNormalSmall")
	tierLabel:SetPoint("TOPLEFT", modelHolder, "BOTTOMLEFT", 2, -10)
	local tierBar = UI.CreateSkillBar(view, 14, { 0.3, 0.5, 0.9 })
	tierBar:SetPoint("TOPLEFT", tierLabel, "BOTTOMLEFT", 0, -12)
	tierBar:SetWidth(ENEMY_WIDTH - 4)

	-- Moves on to the next enemy after each unlock; a failed boss switches it off again.
	local autoButton = UI.CreateButton(view, L.autoAdvance, 60, 20, function()
		local state = GetState()
		state.autoAdvance = not state.autoAdvance
		view.Refresh()
	end)
	autoButton:SetPoint("TOPRIGHT", modelHolder, "BOTTOMRIGHT", 0, -6)

	local modelFrame = CreateFrame("PlayerModel", nil, modelHolder)
	modelFrame:SetPoint("TOPLEFT", 4, -4)
	modelFrame:SetPoint("BOTTOMRIGHT", -4, 4)
	modelFrame:EnableMouse(true)
	modelFrame:SetScript("OnMouseUp", function(_, button)
		if button ~= "LeftButton" then
			return
		end

		local damage = Idle.Click()
		if damage > 0 then
			ShowFloater(view.damageFloater, "-" .. PTT.FormatNumber(damage))
		end
		view.Refresh()
	end)

	local hintFrame = CreateFrame("Frame", nil, modelHolder)
	hintFrame:SetAllPoints()
	hintFrame:SetFrameLevel(modelFrame:GetFrameLevel() + 2)
	local clickDamageLabel = UI.CreateLabel(hintFrame, "GameFontDisableSmall")
	clickDamageLabel:SetPoint("BOTTOMLEFT", 8, 6)

	local shownMonster

	function UI.ResetModel()
		shownMonster = nil
	end

	local function Try(method, ...)
		if modelFrame[method] then
			pcall(modelFrame[method], modelFrame, ...)
		end
	end

	local function ApplyModel(monster)
		local adjustment = MODEL_ADJUSTMENTS[monster.npc] or {}
		Try("ClearModel")
		Try("SetCreature", monster.npc)
		Try("SetPosition", 0, adjustment.y or 0, adjustment.z or 0)
		Try("SetCamDistanceScale", (monster.boss and PTT.database.window.bossZoom or PTT.database.window.modelZoom) * (adjustment.zoom or 1))
	end

	-- Unseen creatures sometimes only show up on a second attempt, so the model is applied again shortly after.
	local function UpdateModel(monster)
		if shownMonster == monster.index then
			return
		end
		shownMonster = monster.index
		ApplyModel(monster)

		for _, delay in ipairs({ 0.5, 2 }) do
			C_Timer.After(delay, function()
				if shownMonster == monster.index then
					ApplyModel(monster)
				end
			end)
		end
	end

	view.damageFloater = CreateFloater(view, modelHolder, -80, { 1, 0.35, 0.35 })
	view.goldFloater = CreateFloater(view, modelHolder, 80, { 1, 0.82, 0 })
	Idle.OnKill(function(_, gold)
		ShowFloater(view.goldFloater, "+" .. PTT.FormatNumber(gold))
	end)

	-- The window's navigation picks the inner tab.
	function view.SetTab(tabId)
		activeTab = tabId
		view.Refresh()
	end

	-- Buy amount selector
	local amountLabel = UI.CreateLabel(view, "GameFontNormalSmall", L.buyAmount)
	amountLabel:SetPoint("TOPLEFT", 0, -8)

	local amountButtons = {}
	local previousAmount
	for _, amount in ipairs(AMOUNTS) do
		local button = UI.CreateButton(view, amount == "max" and L.buyMax or ("x" .. amount), 44, 20, function()
			GetState().buyAmount = amount
			view.Refresh()
		end)
		if previousAmount then
			button:SetPoint("LEFT", previousAmount, "RIGHT", 3, 0)
		else
			button:SetPoint("LEFT", amountLabel, "RIGHT", 8, 0)
		end
		amountButtons[amount] = button
		previousAmount = button
	end

	-- Upgrade rows (heroes with their spell icons, and professions)
	local rowScroll = CreateFrame("ScrollFrame", "PassTheTimeUpgradeScroll", view, "UIPanelScrollFrameTemplate")
	rowScroll:SetPoint("TOPLEFT", 0, LIST_TOP)
	rowScroll:SetPoint("BOTTOMRIGHT", view, "BOTTOMLEFT", LIST_WIDTH - 26, 0)

	local rowContent = CreateFrame("Frame", nil, rowScroll)
	rowContent:SetSize(LIST_WIDTH - 26, MAX_ROWS * SPELL_ROW_HEIGHT)
	rowScroll:SetScrollChild(rowContent)

	local rows = {}
	for index = 1, MAX_ROWS do
		local row = CreateFrame("Frame", nil, rowContent)
		row:SetSize(LIST_WIDTH - 26, ROW_HEIGHT - 2)
		row:EnableMouse(true)
		row.background = row:CreateTexture(nil, "BACKGROUND")
		row.background:SetAllPoints()
		row.background:SetColorTexture(1, 1, 1, 0.05)

		row.nameLabel = UI.CreateLabel(row, "GameFontNormal")
		row.nameLabel:SetPoint("TOPLEFT", 6, -4)
		row.detailLabel = UI.CreateLabel(row, "GameFontHighlightSmall")

		row.spellButtons = {}
		for position = 1, #Idle.SPELL_LEVELS do
			row.spellButtons[position] = CreateSpellButton(row, position, function()
				view.Refresh()
			end)
		end

		row.buyButton = UI.CreateButton(row, L.buy, 110, 22, function()
			if row.definition then
				Idle.Buy(row.kind, row.definition, row.amount)
				view.Refresh()
			end
		end)
		row.buyButton:SetPoint("RIGHT", -4, 0)

		row:SetScript("OnEnter", ShowRowTooltip)
		row:SetScript("OnLeave", UI.HideTooltip)
		row.buyButton:SetScript("OnEnter", function()
			ShowRowTooltip(row)
		end)
		row.buyButton:SetScript("OnLeave", UI.HideTooltip)

		rows[index] = row
	end

	-- Monster list
	local monsterScroll = CreateFrame("ScrollFrame", "PassTheTimeMonsterScroll", view, "UIPanelScrollFrameTemplate")
	monsterScroll:SetPoint("TOPLEFT", 0, MONSTER_LIST_TOP)
	monsterScroll:SetPoint("BOTTOMRIGHT", view, "BOTTOMLEFT", LIST_WIDTH - 26, 0)

	local monsterContent = CreateFrame("Frame", nil, monsterScroll)
	monsterContent:SetSize(LIST_WIDTH - 26, Idle.GetMonsterCount() * MONSTER_ROW_HEIGHT)
	monsterScroll:SetScrollChild(monsterContent)

	local monsterRows = {}
	for index = 1, Idle.GetMonsterCount() do
		local row = CreateFrame("Button", nil, monsterContent)
		row:SetSize(LIST_WIDTH - 26, MONSTER_ROW_HEIGHT - 2)
		row:SetPoint("TOPLEFT", 0, -(index - 1) * MONSTER_ROW_HEIGHT)
		row.background = row:CreateTexture(nil, "BACKGROUND")
		row.background:SetAllPoints()
		row:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

		row.nameLabel = UI.CreateLabel(row, "GameFontNormal")
		row.nameLabel:SetPoint("LEFT", 6, 0)
		row.nameLabel:SetWidth(170)
		row.nameLabel:SetWordWrap(false)
		row.nameLabel:SetJustifyH("LEFT")
		row.infoLabel = UI.CreateLabel(row, "GameFontHighlightSmall")
		row.infoLabel:SetPoint("RIGHT", -6, 0)
		row.infoLabel:SetJustifyH("RIGHT")

		row.index = index
		row:SetScript("OnClick", function()
			if Idle.SelectMonster(index) then
				view.Refresh()
			end
		end)
		monsterRows[index] = row
	end

	-- Prestige panel
	local prestigePanel = CreateFrame("Frame", nil, view)
	prestigePanel:SetSize(LIST_WIDTH, 140)
	prestigePanel:SetPoint("TOPLEFT", 0, MONSTER_LIST_TOP)

	local prestigeInfo = UI.CreateLabel(prestigePanel, "GameFontHighlight", L.prestigeInfo)
	prestigeInfo:SetPoint("TOPLEFT", 4, -4)
	prestigeInfo:SetWidth(LIST_WIDTH - 8)
	prestigeInfo:SetJustifyH("LEFT")

	local prestigeProgress = UI.CreateLabel(prestigePanel, "GameFontNormal")
	prestigeProgress:SetPoint("TOPLEFT", 4, -56)

	local prestigeLocked = UI.CreateLabel(prestigePanel, "GameFontDisable")
	prestigeLocked:SetPoint("TOPLEFT", 4, -80)
	prestigeLocked:SetWidth(LIST_WIDTH - 8)
	prestigeLocked:SetJustifyH("LEFT")

	local prestigeButton = UI.CreateButton(prestigePanel, "", 260, 28, function()
		StaticPopup_Show("PASSTHETIME_PRESTIGE", Idle.GetPrestigeGain())
	end)
	prestigeButton:SetPoint("TOPLEFT", 4, -104)

	StaticPopupDialogs["PASSTHETIME_PRESTIGE"] = {
		text = L.prestigeConfirm,
		button1 = YES,
		button2 = NO,
		OnAccept = function()
			Idle.Prestige()
			view.Refresh()
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}

	local function RefreshMonsterPanel()
		local monster = Idle.GetCurrentMonster()
		monsterName:SetText("|cff999999" .. string.format(L.levelShort, monster.index) .. "|r  " .. (monster.boss and BOSS_COLOR or NORMAL_COLOR) .. Idle.GetName(monster) .. "|r")

		healthBar:SetValue(monster.currentHealth / monster.health)

		-- Rounded up so a living enemy never shows 0%.
		local percent = math.ceil(monster.currentHealth / monster.health * 100)
		healthBar.text:SetText(string.format("%s / %s (%d%%)", PTT.FormatNumber(monster.currentHealth), PTT.FormatNumber(monster.health), percent))

		local timeLeft = Idle.GetBossTimeLeft()
		if timeLeft then
			healthBar.timerText:SetText("|cffffd100" .. math.ceil(timeLeft) .. " s|r")
			healthBar:SetStatusBarColor(0.9, 0.5, 0.1)
		else
			healthBar.timerText:SetText("")
			healthBar:SetStatusBarColor(0.75, 0.15, 0.15)
		end
		clickDamageLabel:SetText(string.format(L.clickHint, PTT.FormatNumber(Idle.GetClickDamage())))

		local state = GetState()
		if state.autoAdvance then
			autoButton:LockHighlight()
		else
			autoButton:UnlockHighlight()
		end

		-- Only the newest unlocked enemy has kills counting towards the next unlock.
		local needsUnlock = monster.index == state.unlocked and state.unlocked < Idle.GetMonsterCount()
		tierLabel:SetShown(needsUnlock)
		tierBar:SetShown(needsUnlock)
		if needsUnlock then
			tierLabel:SetText(string.format(L.nextUnlock, "???"))
			local needed = Idle.GetKillsToUnlock(state.unlocked)
			local kills = math.min(Idle.GetTierKills(state.unlocked), needed)
			tierBar:SetValue(kills / needed)
			tierBar.text:SetText(string.format("%d / %d", kills, needed))
		end

		UpdateModel(monster)
	end

	local function RefreshMonsterList()
		local state = GetState()
		monsterContent:SetHeight(math.max(1, state.unlocked * MONSTER_ROW_HEIGHT))

		for index, row in ipairs(monsterRows) do
			-- Enemies that are not unlocked yet stay hidden.
			row:SetShown(Idle.IsUnlocked(index))

			if row:IsShown() then
				local monster = Idle.GetMonster(index)

				if index == state.monsterIndex then
					row.background:SetColorTexture(0.2, 0.5, 0.2, 0.35)
				else
					row.background:SetColorTexture(1, 1, 1, index % 2 == 0 and 0.06 or 0.02)
				end

				row.nameLabel:SetText("|cff999999" .. string.format(L.levelShort, index) .. "|r  " .. (monster.boss and BOSS_COLOR or NORMAL_COLOR) .. Idle.GetName(monster) .. "|r")

				local info = string.format(L.monsterInfo, PTT.FormatNumber(monster.health), PTT.FormatNumber(monster.gold * Idle.GetGoldMultiplier()))
				if index == state.unlocked and index < Idle.GetMonsterCount() then
					info = string.format("|cff88ccff%d/%d|r  ", Idle.GetTierKills(index), Idle.GetKillsToUnlock(index)) .. info
				end
				row.infoLabel:SetText(info)
			end
		end
	end

	function view.Refresh()
		local state = GetState()
		RefreshMonsterPanel()

		local isMonster = activeTab == "monster"
		local isPrestige = activeTab == "prestige"
		local hasRows = not isMonster and not isPrestige

		monsterScroll:SetShown(isMonster)
		prestigePanel:SetShown(isPrestige)
		amountLabel:SetShown(hasRows)
		for amount, button in pairs(amountButtons) do
			button:SetShown(hasRows)
			if amount == state.buyAmount then
				button:LockHighlight()
			else
				button:UnlockHighlight()
			end
		end

		if isMonster then
			RefreshMonsterList()
		end

		rowScroll:SetShown(hasRows)
		local entries = GetEntries(activeTab)
		rowContent:SetHeight(math.max(1, #entries * SPELL_ROW_HEIGHT))
		local offset = 0
		for index, row in ipairs(rows) do
			local entry = entries[index]
			if not entry then
				row:Hide()
				row.definition = nil
			else
				local kind, definition = entry.kind, entry.definition
				local isHero = kind ~= "profession"
				local hasSpells = isHero and UpdateSpellButtons(row, definition.id)
				local height = hasSpells and SPELL_ROW_HEIGHT or ROW_HEIGHT
				row:Show()
				row:SetHeight(height - 2)
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", 0, -offset)
				offset = offset + height
				row.definition = definition
				row.kind = kind
				row.amount = ResolveAmount(kind, definition)

				row.detailLabel:ClearAllPoints()
				if hasSpells then
					row.detailLabel:SetPoint("TOPLEFT", 6, -22)
				else
					row.detailLabel:SetPoint("BOTTOMLEFT", 6, 4)
				end
				if not isHero then
					for _, button in ipairs(row.spellButtons) do
						button:Hide()
						button.spell = nil
					end
				end

				local name = Idle.GetName(definition)
				if isHero then
					name = name .. "  |cff999999" .. string.format(L.level, Idle.GetOwned(kind, definition.id)) .. "|r"
				end
				row.nameLabel:SetText(name)
				row.detailLabel:SetText(GetDetailText(kind, definition))

				if row.amount == 0 then
					row.buyButton:SetText(L.maxLevel)
					row.buyButton:Disable()
				else
					local cost = Idle.GetCost(kind, definition, row.amount)
					local label = row.amount > 1 and ("x" .. row.amount .. "  ") or ""
					local unit = kind == "profession" and (" " .. L.renownShort) or ""
					row.buyButton:SetText(label .. PTT.FormatNumber(cost) .. unit)
					row.buyButton:SetEnabled(Idle.GetBalance(kind) >= cost)
				end
			end
		end

		if isPrestige then
			local gain = Idle.GetPrestigeGain()
			prestigeButton:SetText(string.format(L.prestigeGain, gain))
			prestigeProgress:SetText(string.format(L.prestigeProgress, PTT.FormatNumber(Idle.GetHeroLevels()), PTT.FormatNumber((gain + 1) * Idle.LEVELS_PER_SOUL)))

			local canPrestige = Idle.CanPrestige()
			prestigeButton:SetEnabled(canPrestige)
			if canPrestige then
				prestigeLocked:SetText("")
			else
				prestigeLocked:SetText(string.format(L.prestigeLocked, Idle.PRESTIGE_UNLOCK_LEVEL))
			end
		end
	end

	local elapsed = 0
	view:SetScript("OnUpdate", function(_, delta)
		UpdateFloater(view.damageFloater, delta)
		UpdateFloater(view.goldFloater, delta)

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

PTT.RegisterView({ id = "idle", label = "idle", build = BuildIdleView })

---------------------------------------------------------------------------
-- Always-visible header strip (Adventure)
---------------------------------------------------------------------------

local STAT_WIDTH = 104
local BUFF_SLOTS, BUFF_SLOT_SIZE, BUFF_SLOT_GAP = 5, 60, 6
local BUFF_ICON_FALLBACK = "Interface\\Icons\\INV_Misc_QuestionMark"
local BUFF_ICONS = {
	world = "Interface\\Icons\\INV_Misc_Map_01",
	levelUp = "Interface\\Icons\\Spell_ChargePositive",
	event_goblin = "Interface\\Icons\\INV_Misc_Coin_02",
	boss_group = "Interface\\Icons\\Spell_Holy_PrayerOfHealing",
	boss_guild = "Interface\\Icons\\Spell_Holy_GreaterBlessingofKings",
}

function UI.BuildHeader(panel)
	panel:SetBackdropColor(0.08, 0.08, 0.12, 0.9)

	local function CreateStat(index, title, template)
		local offsetX = 12 + (index - 1) * STAT_WIDTH
		local titleLabel = UI.CreateLabel(panel, "GameFontNormalSmall", title)
		titleLabel:SetPoint("TOPLEFT", offsetX, -10)
		local value = UI.CreateLabel(panel, template)
		value:SetPoint("TOPLEFT", offsetX, -24)
		value:SetWidth(STAT_WIDTH - 6)
		value:SetJustifyH("LEFT")
		return value
	end

	local goldValue = CreateStat(1, L.gold, "GameFontNormalLarge")
	local damageValue = CreateStat(2, L.damagePerSecond, "GameFontHighlightLarge")
	local renownValue = CreateStat(3, L.renownSouls, "GameFontHighlightLarge")
	local groupValue = CreateStat(4, L.groupBonus, "GameFontHighlightLarge")
	local timeValue = CreateStat(5, L.activeTime, "GameFontHighlightLarge")

	local worldValue = UI.CreateLabel(panel, "GameFontHighlightSmall")
	worldValue:SetPoint("TOPLEFT", 12, -52)
	worldValue:SetWidth(360)
	worldValue:SetJustifyH("LEFT")
	worldValue:SetWordWrap(false)

	local slots = {}
	for index = 1, BUFF_SLOTS do
		local slot = CreateFrame("Frame", nil, panel, BackdropTemplateMixin and "BackdropTemplate" or nil)
		slot:SetSize(BUFF_SLOT_SIZE, BUFF_SLOT_SIZE)
		slot:SetPoint("TOPRIGHT", -12 - (BUFF_SLOTS - index) * (BUFF_SLOT_SIZE + BUFF_SLOT_GAP), -8)
		slot:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12 })
		slot:EnableMouse(true)

		slot.icon = slot:CreateTexture(nil, "ARTWORK")
		slot.icon:SetSize(32, 32)
		slot.icon:SetPoint("TOP", 0, -7)
		slot.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
		slot.multiplier = UI.CreateLabel(slot, "NumberFontNormalSmall")
		slot.multiplier:SetPoint("BOTTOMRIGHT", slot.icon, "BOTTOMRIGHT", 2, 0)
		slot.time = UI.CreateLabel(slot, "GameFontHighlightSmall")
		slot.time:SetPoint("BOTTOM", 0, 7)
		slot.more = UI.CreateLabel(slot, "GameFontNormalSmall")
		slot.more:SetPoint("TOPRIGHT", -5, -5)

		slot:SetScript("OnEnter", function(self)
			if self.buff then
				GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
				GameTooltip:SetText(L[self.buff.nameKey])
				GameTooltip:AddLine(string.format("x%.2f (%s)", self.buff.multiplier, PTT.FormatDuration(self.buff.remaining)), 1, 1, 1)
				GameTooltip:Show()
			end
		end)
		slot:SetScript("OnLeave", GameTooltip_Hide)
		slots[index] = slot
	end

	local function Refresh()
		local state = GetState()
		goldValue:SetText(PTT.FormatNumber(state.gold))
		damageValue:SetText(PTT.FormatNumber(Idle.GetDamagePerSecond()))

		timeValue:SetText(PTT.FormatDuration(state.runTime))
		groupValue:SetText(string.format("+%d%%", math.floor(Idle.groupBonus * 100 + 0.5)))
		renownValue:SetText(state.renown)

		local active = {}
		for id, buff in pairs(state.buffs) do
			active[#active + 1] = { id = id, buff = buff }
		end
		-- Id as tie-breaker keeps the slot order stable.
		table.sort(active, function(a, b)
			if a.buff.remaining ~= b.buff.remaining then
				return a.buff.remaining > b.buff.remaining
			end
			return a.id < b.id
		end)

		for index, slot in ipairs(slots) do
			local entry = active[index]
			slot.buff = entry and entry.buff
			if entry then
				slot:SetBackdropBorderColor(1, 0.82, 0, 1)
				slot.icon:SetTexture(BUFF_ICONS[entry.id] or BUFF_ICON_FALLBACK)
				slot.icon:Show()
				slot.multiplier:SetText(string.format("x%.2f", entry.buff.multiplier))
				slot.time:SetText(PTT.FormatDuration(entry.buff.remaining))
			else
				slot:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.6)
				slot.icon:Hide()
				slot.multiplier:SetText("")
				slot.time:SetText("")
			end
			local extra = index == #slots and #active - #slots or 0
			slot.more:SetText(extra > 0 and ("+" .. extra) or "")
		end

		local world = PTT.World
		if world.stacks > 0 and world.last then
			worldValue:SetText(string.format(L.worldBonusValue, world.GetBonus() * 100, L[world.labelKeys[world.last.kind]]))
		else
			worldValue:SetText("|cff999999" .. L.worldBonusHint .. "|r")
		end
	end

	local elapsed = 0
	panel:SetScript("OnUpdate", function(_, delta)
		elapsed = elapsed + delta
		if elapsed >= REFRESH_INTERVAL then
			elapsed = 0
			Refresh()
		end
	end)
	panel:HookScript("OnShow", Refresh)
	Refresh()
end
