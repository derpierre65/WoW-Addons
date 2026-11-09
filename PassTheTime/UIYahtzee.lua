local _, PTT = ...
local L = PTT.L
local UI = PTT.UI

---------------------------------------------------------------------------
-- Yahtzee
---------------------------------------------------------------------------

local SIDE_WIDTH, SIDE_GAP = 190, 14
local MAIN_WIDTH = UI.contentWidth - SIDE_WIDTH - SIDE_GAP
local DICE_SIZE, DICE_GAP = 60, 6
local SHEET_GAP, ROW_HEIGHT = 12, 26
local SHEET_WIDTH = math.floor((MAIN_WIDTH - SHEET_GAP) / 2)

local COLORS = {
	die = { 0.2, 0.17, 0.12 },
	dieHeld = { 0.45, 0.35, 0.1 },
	dieEmpty = { 0.1, 0.09, 0.08 },
	row = { 0.12, 0.1, 0.08 },
	rowFree = { 0.17, 0.14, 0.09 },
}

local function BuildYahtzee(parent)
	local Yahtzee = PTT.Yahtzee
	local colors = UI.gameColors
	local view = CreateFrame("Frame", nil, parent)

	-- Header
	local titleLabel = UI.CreateLabel(view, "GameFontNormalHuge", L.yahtzee)
	titleLabel:SetPoint("TOPLEFT", 2, 0)
	titleLabel:SetTextColor(colors.gold[1], colors.gold[2], colors.gold[3])

	local subtitleLabel = UI.CreateLabel(view, "GameFontDisableSmall")
	subtitleLabel:SetPoint("TOPLEFT", 2, -30)

	local Refresh
	local newGameButton = UI.CreateButton(view, L.newGame, 110, 50, function()
		Yahtzee.NewGame()
		Refresh()
	end)
	newGameButton:SetPoint("TOPRIGHT", 0, 0)

	local scoreTile, scoreValue = UI.CreateStatTile(view, 90, L.scoreTitle)
	scoreTile:SetPoint("RIGHT", newGameButton, "LEFT", -8, 0)
	scoreValue:SetTextColor(colors.gold[1], colors.gold[2], colors.gold[3])
	local turnTile, turnValue = UI.CreateStatTile(view, 90, L.turnTitle)
	turnTile:SetPoint("RIGHT", scoreTile, "LEFT", -8, 0)
	turnValue:SetTextColor(1, 1, 1)

	-- Dice
	local diceBox = UI.CreateBox(view, MAIN_WIDTH, DICE_SIZE + 62)
	diceBox:SetPoint("TOPLEFT", 0, -62)

	local dice = {}
	for index = 1, Yahtzee.DICE_COUNT do
		local die = CreateFrame("Button", nil, diceBox)
		die:SetSize(DICE_SIZE, DICE_SIZE)
		die:SetPoint("TOPLEFT", 12 + (index - 1) * (DICE_SIZE + DICE_GAP), -12)
		die.background = die:CreateTexture(nil, "BACKGROUND")
		die.background:SetAllPoints()
		die.value = UI.CreateLabel(die, "GameFontNormalHuge")
		die.value:SetPoint("CENTER")
		die.value:SetFont(die.value:GetFont(), 40, "OUTLINE")
		die.hold = UI.CreateLabel(die, "GameFontNormalSmall", L.yahtzeeHeld)
		die.hold:SetPoint("BOTTOM", 0, 4)
		die:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
		die:SetScript("OnClick", function()
			Yahtzee.ToggleHold(index)
			Refresh()
		end)
		dice[index] = die
	end

	local rollButton = UI.CreateButton(diceBox, "", 150, 40, function()
		Yahtzee.Roll()
		Refresh()
	end)
	rollButton:SetPoint("TOPRIGHT", -12, -12)

	local rollsLabel = UI.CreateLabel(diceBox, "GameFontNormalSmall")
	rollsLabel:SetPoint("TOP", rollButton, "BOTTOM", 0, -6)
	rollsLabel:SetTextColor(colors.label[1], colors.label[2], colors.label[3])

	local hintLabel = UI.CreateLabel(diceBox, "GameFontDisableSmall", L.yahtzeeHint)
	hintLabel:SetPoint("BOTTOMLEFT", 12, 12)

	-- Score sheet: upper section on the left, lower section on the right.
	local sheets = {
		upper = UI.CreateBox(view, SHEET_WIDTH, 2 * 12 + 8 * ROW_HEIGHT),
		lower = UI.CreateBox(view, SHEET_WIDTH, 2 * 12 + 8 * ROW_HEIGHT),
	}
	sheets.upper:SetPoint("TOPLEFT", diceBox, "BOTTOMLEFT", 0, -8)
	sheets.lower:SetPoint("TOPLEFT", sheets.upper, "TOPRIGHT", SHEET_GAP, 0)

	local rows = {}
	local function CreateRow(sheet, position, clickable)
		local row = CreateFrame(clickable and "Button" or "Frame", nil, sheet)
		row:SetSize(SHEET_WIDTH - 16, ROW_HEIGHT - 2)
		row:SetPoint("TOPLEFT", 8, -(12 + (position - 1) * ROW_HEIGHT))
		row.background = row:CreateTexture(nil, "BACKGROUND")
		row.background:SetAllPoints()
		row.name = UI.CreateLabel(row, "GameFontHighlight")
		row.name:SetPoint("LEFT", 6, 0)
		row.points = UI.CreateLabel(row, "GameFontHighlight")
		row.points:SetPoint("RIGHT", -6, 0)
		if clickable then
			row:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
		end
		return row
	end

	local upperPosition, lowerPosition = 0, 0
	for _, category in ipairs(Yahtzee.categories) do
		local sheet, position
		if category.lower then
			lowerPosition = lowerPosition + 1
			sheet, position = sheets.lower, lowerPosition
		else
			upperPosition = upperPosition + 1
			sheet, position = sheets.upper, upperPosition
		end

		local row = CreateRow(sheet, position, true)
		row.category = category
		row:SetScript("OnClick", function()
			Yahtzee.Choose(category.id)
			Refresh()
		end)
		rows[#rows + 1] = row
	end

	local sumRow = CreateRow(sheets.upper, 7)
	sumRow.name:SetTextColor(colors.label[1], colors.label[2], colors.label[3])
	local bonusRow = CreateRow(sheets.upper, 8)
	bonusRow.name:SetTextColor(colors.label[1], colors.label[2], colors.label[3])
	local totalRow = CreateRow(sheets.lower, 8)
	totalRow.name:SetTextColor(colors.gold[1], colors.gold[2], colors.gold[3])
	totalRow.points:SetTextColor(colors.gold[1], colors.gold[2], colors.gold[3])

	-- Side column
	local side = CreateFrame("Frame", nil, view)
	side:SetSize(SIDE_WIDTH, 200)
	side:SetPoint("TOPRIGHT", 0, -62)

	local statsBox = UI.CreateBox(side, SIDE_WIDTH, 138)
	statsBox:SetPoint("TOPLEFT", 0, 0)
	UI.CreateBoxHeader(statsBox, L.yahtzeeStats)
	local completedValue = UI.CreateStatRow(statsBox, 1, L.gamesFinished)
	local highScoreValue = UI.CreateStatRow(statsBox, 2, L.highScore)
	highScoreValue:SetTextColor(colors.gold[1], colors.gold[2], colors.gold[3])
	local yahtzeesValue = UI.CreateStatRow(statsBox, 3, L.yahtzeesRolled)
	local bonusesValue = UI.CreateStatRow(statsBox, 4, L.yahtzeeBonuses)

	Refresh = function()
		local game = Yahtzee.game
		local rolled = Yahtzee.HasRolled()
		local over = game.state == "over"

		for index, die in ipairs(dice) do
			local value = game.dice[index]
			local held = game.held[index]
			local color = held and COLORS.dieHeld or (value and COLORS.die or COLORS.dieEmpty)
			die.background:SetColorTexture(color[1], color[2], color[3], 1)
			die.value:SetText(value or "")
			die.hold:SetShown(held == true)
			die:SetEnabled(not over and rolled and game.rollsLeft > 0)
		end

		rollButton:SetText(L.yahtzeeRoll)
		rollButton:SetEnabled(not over and game.rollsLeft > 0)
		rollsLabel:SetText(string.format(L.yahtzeeRollsLeft, game.rollsLeft))

		for _, row in ipairs(rows) do
			local id = row.category.id
			local points = game.scores[id]
			row.name:SetText(Yahtzee.GetName(row.category))
			if points then
				row.background:SetColorTexture(COLORS.row[1], COLORS.row[2], COLORS.row[3], 1)
				row.points:SetText(points)
				row.points:SetTextColor(1, 1, 1)
				row:Disable()
			else
				row.background:SetColorTexture(COLORS.rowFree[1], COLORS.rowFree[2], COLORS.rowFree[3], 1)
				row:SetEnabled(not over and rolled)
				if rolled and not over then
					local potential = Yahtzee.Score(id, game.dice)
					row.points:SetText(potential)
					row.points:SetTextColor(potential > 0 and 0.4 or 0.55, potential > 0 and 0.9 or 0.5, potential > 0 and 0.4 or 0.45)
				else
					row.points:SetText("")
				end
			end
		end

		local upperSum = Yahtzee.GetUpperSum()
		sumRow.name:SetText(string.format(L.yahtzeeUpperSum, Yahtzee.BONUS_THRESHOLD))
		sumRow.points:SetText(upperSum)
		bonusRow.name:SetText(string.format(L.yahtzeeBonus, Yahtzee.BONUS))
		bonusRow.points:SetText(Yahtzee.GetBonus())
		totalRow.name:SetText(L.yahtzeeTotal)
		totalRow.points:SetText(Yahtzee.GetTotal())

		scoreValue:SetText(Yahtzee.GetTotal())
		turnValue:SetText(over and #Yahtzee.categories .. "/" .. #Yahtzee.categories or game.turn .. "/" .. #Yahtzee.categories)

		if over then
			subtitleLabel:SetText("|cffffd100" .. string.format(L.yahtzeeOver, game.total) .. "|r")
		else
			subtitleLabel:SetText(L.yahtzeeSubtitle)
		end

		local settings = PTT.database.yahtzee
		completedValue:SetText(PTT.FormatNumber(settings.completed))
		highScoreValue:SetText(PTT.FormatNumber(settings.highScore))
		yahtzeesValue:SetText(PTT.FormatNumber(settings.yahtzees))
		bonusesValue:SetText(PTT.FormatNumber(settings.bonuses))
	end

	view:HookScript("OnShow", Refresh)
	Refresh()
	return view
end

PTT.RegisterView({ id = "yahtzee", label = "yahtzee", build = BuildYahtzee })
