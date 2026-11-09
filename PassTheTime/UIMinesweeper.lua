local _, PTT = ...
local L = PTT.L
local UI = PTT.UI

---------------------------------------------------------------------------
-- Minesweeper
---------------------------------------------------------------------------

local SIDE_WIDTH, SIDE_GAP = 190, 14
local BOARD_WIDTH = UI.contentWidth - SIDE_WIDTH - SIDE_GAP
local BOARD_MAX_HEIGHT = 330
local CELL_GAP, MAX_CELL_SIZE = 2, 32

local MINE_ICON = "Interface\\Icons\\INV_Misc_Bomb_04"
local FLAG_ICON = "Interface\\Icons\\Ability_Warrior_BattleShout"

local COLORS = {
	hidden = { 0.22, 0.18, 0.13 },
	revealed = { 0.09, 0.08, 0.07 },
	hit = { 0.6, 0.15, 0.1 },
	wrongFlag = { 0.4, 0.15, 0.12 },
}

local NUMBER_COLORS = {
	{ 0.4, 0.7, 1 }, { 0.35, 0.8, 0.35 }, { 1, 0.4, 0.4 }, { 0.55, 0.55, 1 },
	{ 0.95, 0.55, 0.2 }, { 0.3, 0.8, 0.8 }, { 0.9, 0.9, 0.9 }, { 0.6, 0.6, 0.6 },
}

local function BuildMinesweeper(parent)
	local Minesweeper = PTT.Minesweeper
	local colors = UI.gameColors
	local view = CreateFrame("Frame", nil, parent)

	local maxCells = 0
	for _, difficulty in ipairs(Minesweeper.difficulties) do
		maxCells = math.max(maxCells, difficulty.width * difficulty.height)
	end

	-- Header
	local titleLabel = UI.CreateLabel(view, "GameFontNormalHuge", L.minesweeper)
	titleLabel:SetPoint("TOPLEFT", 2, 0)
	titleLabel:SetTextColor(colors.gold[1], colors.gold[2], colors.gold[3])

	local subtitleLabel = UI.CreateLabel(view, "GameFontDisableSmall")
	subtitleLabel:SetPoint("TOPLEFT", 2, -30)

	local Refresh
	local function StartGame(difficultyId)
		Minesweeper.NewGame(difficultyId)
		Refresh(true)
	end

	local newGameButton = UI.CreateButton(view, L.newGame, 110, 50, function()
		UI.ConfirmNewGame(StartGame, Minesweeper.game.state == "won" or Minesweeper.game.state == "lost")
	end)
	newGameButton:SetPoint("TOPRIGHT", 0, 0)

	local timeTile, timeValue = UI.CreateStatTile(view, 90, L.timeTitle)
	timeTile:SetPoint("RIGHT", newGameButton, "LEFT", -8, 0)
	timeValue:SetTextColor(1, 1, 1)
	local minesTile, minesValue = UI.CreateStatTile(view, 90, L.minesTitle)
	minesTile:SetPoint("RIGHT", timeTile, "LEFT", -8, 0)
	minesValue:SetTextColor(colors.gold[1], colors.gold[2], colors.gold[3])

	-- Board
	local board = UI.CreatePanel(view)
	board:SetPoint("TOPLEFT", 0, -62)
	board:SetBackdropColor(0.07, 0.06, 0.05, 0.95)
	board:SetBackdropBorderColor(0.3, 0.24, 0.15, 1)

	local cells = {}
	for index = 1, maxCells do
		local cell = CreateFrame("Button", nil, board)
		cell:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		cell.background = cell:CreateTexture(nil, "BACKGROUND")
		cell.background:SetAllPoints()
		cell.icon = cell:CreateTexture(nil, "ARTWORK")
		cell.icon:SetPoint("TOPLEFT", 3, -3)
		cell.icon:SetPoint("BOTTOMRIGHT", -3, 3)
		cell.label = cell:CreateFontString(nil, "OVERLAY")
		cell.label:SetPoint("CENTER")
		cell:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
		cell:SetScript("OnClick", function(_, button)
			if button == "RightButton" then
				Minesweeper.ToggleFlag(index)
			else
				Minesweeper.Reveal(index)
			end
			Refresh()
		end)
		cells[index] = cell
	end

	local layoutKey
	local function Layout(game)
		if layoutKey == game.difficulty.id then
			return
		end
		layoutKey = game.difficulty.id

		local cellSize = math.min(
			MAX_CELL_SIZE,
			math.floor((BOARD_WIDTH - CELL_GAP) / game.width) - CELL_GAP,
			math.floor((BOARD_MAX_HEIGHT - CELL_GAP) / game.height) - CELL_GAP
		)
		board:SetSize(game.width * (cellSize + CELL_GAP) + CELL_GAP, game.height * (cellSize + CELL_GAP) + CELL_GAP)

		for index, cell in ipairs(cells) do
			if index > game.width * game.height then
				cell:Hide()
			else
				local row, column = math.floor((index - 1) / game.width), (index - 1) % game.width
				cell:Show()
				cell:SetSize(cellSize, cellSize)
				cell:ClearAllPoints()
				cell:SetPoint("TOPLEFT", CELL_GAP + column * (cellSize + CELL_GAP), -(CELL_GAP + row * (cellSize + CELL_GAP)))
				cell.label:SetFont(STANDARD_TEXT_FONT, cellSize >= 26 and 16 or 13, "")
			end
		end
	end

	-- Side column
	local side = CreateFrame("Frame", nil, view)
	side:SetSize(SIDE_WIDTH, 320)
	side:SetPoint("TOPRIGHT", 0, -62)

	local zoneBox = UI.CreateBox(side, SIDE_WIDTH, 116)
	zoneBox:SetPoint("TOPLEFT", 0, 0)
	UI.CreateBoxHeader(zoneBox, L.zoneTitle)
	local zoneButtons = {}
	for index, difficulty in ipairs(Minesweeper.difficulties) do
		local button = UI.CreateButton(zoneBox, "", SIDE_WIDTH - 24, 22, function()
			StartGame(difficulty.id)
		end)
		button:SetPoint("TOPLEFT", 12, -28 - (index - 1) * 26)
		zoneButtons[index] = button
	end

	local statsBox = UI.CreateBox(side, SIDE_WIDTH, 96)
	statsBox:SetPoint("TOPLEFT", zoneBox, "BOTTOMLEFT", 0, -8)
	UI.CreateBoxHeader(statsBox, L.minesweeperStats)
	local wonValue = UI.CreateStatRow(statsBox, 1, L.gamesWon)
	local streakValue = UI.CreateStatRow(statsBox, 2, L.winStreak)
	streakValue:SetTextColor(colors.gold[1], colors.gold[2], colors.gold[3])
	local bestTimeValue = UI.CreateStatRow(statsBox, 3, L.bestTime)

	local controlsBox = UI.CreateBox(side, SIDE_WIDTH, 92)
	controlsBox:SetPoint("TOPLEFT", statsBox, "BOTTOMLEFT", 0, -8)
	UI.CreateBoxHeader(controlsBox, L.controls)
	for index, text in ipairs({ L.mineControlReveal, L.mineControlFlag, L.mineControlChord }) do
		local line = UI.CreateLabel(controlsBox, "GameFontHighlightSmall", text)
		line:SetPoint("TOPLEFT", 12, -28 - (index - 1) * 17)
		line:SetWidth(SIDE_WIDTH - 24)
		line:SetJustifyH("LEFT")
		line:SetWordWrap(false)
		line:SetTextColor(colors.text[1], colors.text[2], colors.text[3])
	end

	local function SetCellColor(cell, color)
		cell.background:SetColorTexture(color[1], color[2], color[3], 1)
	end

	local function RefreshTime()
		local game = Minesweeper.game
		timeValue:SetText(PTT.FormatDuration(math.floor(game.elapsed)))
	end

	Refresh = function(forceLayout)
		local game = Minesweeper.game
		if forceLayout then
			layoutKey = nil
		end
		Layout(game)

		local lost, won = game.state == "lost", game.state == "won"
		for index = 1, game.width * game.height do
			local cell = cells[index]
			local showIcon, text = false, ""
			local color = COLORS.hidden

			if game.revealed[index] then
				color = COLORS.revealed
				if game.adjacent[index] > 0 then
					text = game.adjacent[index]
				end
			elseif lost and game.mine[index] and not game.flagged[index] then
				color = index == game.hitIndex and COLORS.hit or COLORS.revealed
				showIcon = true
				cell.icon:SetTexture(MINE_ICON)
			elseif lost and game.flagged[index] and not game.mine[index] then
				color = COLORS.wrongFlag
				showIcon = true
				cell.icon:SetTexture(FLAG_ICON)
			elseif game.flagged[index] or (won and game.mine[index]) then
				showIcon = true
				cell.icon:SetTexture(FLAG_ICON)
			end

			SetCellColor(cell, color)
			cell.icon:SetShown(showIcon)
			cell.label:SetText(text)
			if text ~= "" then
				local numberColor = NUMBER_COLORS[game.adjacent[index]]
				cell.label:SetTextColor(numberColor[1], numberColor[2], numberColor[3])
			end
		end

		minesValue:SetText(Minesweeper.GetMinesLeft())
		RefreshTime()

		if won then
			subtitleLabel:SetText("|cffffd100" .. string.format(L.minesweeperWon, PTT.FormatDuration(math.max(1, math.floor(game.elapsed)))) .. "|r")
		elseif lost then
			subtitleLabel:SetText("|cffdd5555" .. L.minesweeperLost .. "|r")
		else
			subtitleLabel:SetText(L.minesweeperSubtitle)
		end

		local settings = PTT.database.minesweeper
		for index, difficulty in ipairs(Minesweeper.difficulties) do
			zoneButtons[index]:SetText(Minesweeper.GetName(difficulty))
			if difficulty.id == game.difficulty.id then
				zoneButtons[index]:LockHighlight()
			else
				zoneButtons[index]:UnlockHighlight()
			end
		end
		wonValue:SetText(PTT.FormatNumber(settings.won))
		streakValue:SetText(settings.streak)
		local bestTime = settings.bestTimes[game.difficulty.id]
		bestTimeValue:SetText(bestTime and PTT.FormatDuration(bestTime) or "-")
	end

	view:SetScript("OnUpdate", function(_, delta)
		Minesweeper.Tick(delta)
		RefreshTime()
	end)

	view:HookScript("OnShow", function()
		Refresh(true)
	end)
	Refresh(true)
	return view
end

PTT.RegisterView({ id = "minesweeper", label = "minesweeper", build = BuildMinesweeper })
