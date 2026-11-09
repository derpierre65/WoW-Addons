local _, PTT = ...
local L = PTT.L
local UI = PTT.UI

---------------------------------------------------------------------------
-- Memory
---------------------------------------------------------------------------

local SIDE_WIDTH, SIDE_GAP = 190, 14
local BOARD_WIDTH = UI.contentWidth - SIDE_WIDTH - SIDE_GAP
local BOARD_MAX_HEIGHT = 420
local CARD_GAP, MAX_CARD_SIZE, MAX_CARDS = 4, 84, 48

local COLORS = {
	back = { 0.22, 0.18, 0.13 },
	face = { 0.12, 0.1, 0.08 },
	matched = { 0.14, 0.3, 0.15 },
	wrong = { 0.38, 0.13, 0.1 },
}

local function BuildMemory(parent)
	local Memory = PTT.Memory
	local colors = UI.gameColors
	local view = CreateFrame("Frame", nil, parent)

	-- Header
	local titleLabel = UI.CreateLabel(view, "GameFontNormalHuge", L.memory)
	titleLabel:SetPoint("TOPLEFT", 2, 0)
	titleLabel:SetTextColor(colors.gold[1], colors.gold[2], colors.gold[3])

	local subtitleLabel = UI.CreateLabel(view, "GameFontDisableSmall")
	subtitleLabel:SetPoint("TOPLEFT", 2, -30)

	local Refresh
	local function StartGame(difficultyId)
		Memory.NewGame(difficultyId)
		Refresh(true)
	end

	local newGameButton = UI.CreateButton(view, L.newGame, 110, 50, function()
		UI.ConfirmNewGame(StartGame)
	end)
	newGameButton:SetPoint("TOPRIGHT", 0, 0)

	local timeTile, timeValue = UI.CreateStatTile(view, 90, L.timeTitle)
	timeTile:SetPoint("RIGHT", newGameButton, "LEFT", -8, 0)
	timeValue:SetTextColor(1, 1, 1)
	local movesTile, movesValue = UI.CreateStatTile(view, 90, L.movesTitle)
	movesTile:SetPoint("RIGHT", timeTile, "LEFT", -8, 0)
	movesValue:SetTextColor(colors.gold[1], colors.gold[2], colors.gold[3])

	-- Board
	local board = UI.CreatePanel(view)
	board:SetPoint("TOPLEFT", 0, -62)
	board:SetBackdropColor(0.07, 0.06, 0.05, 0.95)
	board:SetBackdropBorderColor(0.3, 0.24, 0.15, 1)

	local cards = {}
	for index = 1, MAX_CARDS do
		local card = CreateFrame("Button", nil, board)
		card.background = card:CreateTexture(nil, "BACKGROUND")
		card.background:SetAllPoints()
		card.icon = card:CreateTexture(nil, "ARTWORK")
		card.icon:SetPoint("TOPLEFT", 4, -4)
		card.icon:SetPoint("BOTTOMRIGHT", -4, 4)
		card.mark = UI.CreateLabel(card, "GameFontNormalLarge", "?")
		card.mark:SetPoint("CENTER")
		card.mark:SetTextColor(colors.gold[1], colors.gold[2], colors.gold[3])
		card:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
		card:SetScript("OnClick", function()
			Memory.Flip(index)
			Refresh()
		end)
		cards[index] = card
	end

	local layoutKey
	local function Layout(game)
		local key = #game.symbols .. ":" .. game.columns
		if layoutKey == key then
			return
		end
		layoutKey = key

		local rows = math.ceil(#game.symbols / game.columns)
		local size = math.min(
			MAX_CARD_SIZE,
			math.floor((BOARD_WIDTH - CARD_GAP) / game.columns) - CARD_GAP,
			math.floor((BOARD_MAX_HEIGHT - CARD_GAP) / rows) - CARD_GAP
		)
		board:SetSize(game.columns * (size + CARD_GAP) + CARD_GAP, rows * (size + CARD_GAP) + CARD_GAP)

		for index, card in ipairs(cards) do
			if index > #game.symbols then
				card:Hide()
			else
				local row, column = math.floor((index - 1) / game.columns), (index - 1) % game.columns
				card:Show()
				card:SetSize(size, size)
				card:ClearAllPoints()
				card:SetPoint("TOPLEFT", CARD_GAP + column * (size + CARD_GAP), -(CARD_GAP + row * (size + CARD_GAP)))
			end
		end
	end

	-- Side column
	local side = CreateFrame("Frame", nil, view)
	side:SetSize(SIDE_WIDTH, 340)
	side:SetPoint("TOPRIGHT", 0, -62)

	local difficultyBox = UI.CreateBox(side, SIDE_WIDTH, 106)
	difficultyBox:SetPoint("TOPLEFT", 0, 0)
	UI.CreateBoxHeader(difficultyBox, L.difficultyTitle)
	local difficultyButtons = {}
	for index, difficulty in ipairs(Memory.difficulties) do
		local button = UI.CreateButton(difficultyBox, "", SIDE_WIDTH - 24, 22, function()
			StartGame(difficulty.id)
		end)
		button:SetPoint("TOPLEFT", 12, -28 - (index - 1) * 26)
		difficultyButtons[index] = button
	end

	local statsBox = UI.CreateBox(side, SIDE_WIDTH, 118)
	statsBox:SetPoint("TOPLEFT", difficultyBox, "BOTTOMLEFT", 0, -8)
	UI.CreateBoxHeader(statsBox, L.memoryStats)
	local wonValue = UI.CreateStatRow(statsBox, 1, L.gamesWon)
	local perfectValue = UI.CreateStatRow(statsBox, 2, L.perfectGames)
	perfectValue:SetTextColor(colors.gold[1], colors.gold[2], colors.gold[3])
	local bestTimeValue = UI.CreateStatRow(statsBox, 3, L.bestTime)
	local bestMovesValue = UI.CreateStatRow(statsBox, 4, L.bestMoves)

	local function RefreshTime()
		timeValue:SetText(PTT.FormatDuration(math.floor(Memory.game.elapsed)))
	end

	Refresh = function(forceLayout)
		local game = Memory.game
		if forceLayout then
			layoutKey = nil
		end
		Layout(game)

		local wrong = game.pending
		for index = 1, #game.symbols do
			local card = cards[index]
			local color, showIcon = COLORS.back, false
			if game.matched[index] then
				color, showIcon = COLORS.matched, true
			elseif game.faceUp[index] then
				color, showIcon = COLORS.face, true
				if wrong and (wrong[1] == index or wrong[2] == index) then
					color = COLORS.wrong
				end
			end

			card.background:SetColorTexture(color[1], color[2], color[3], 1)
			card.icon:SetShown(showIcon)
			card.mark:SetShown(not showIcon)
			if showIcon then
				card.icon:SetTexture(game.symbols[index])
			end
		end

		movesValue:SetText(game.moves)
		RefreshTime()

		if game.state == "won" then
			subtitleLabel:SetText("|cffffd100" .. string.format(L.memoryWon, game.moves) .. "|r")
		else
			subtitleLabel:SetText(L.memorySubtitle)
		end

		for index, difficulty in ipairs(Memory.difficulties) do
			difficultyButtons[index]:SetText(Memory.GetName(difficulty))
			if difficulty.id == game.difficulty.id then
				difficultyButtons[index]:LockHighlight()
			else
				difficultyButtons[index]:UnlockHighlight()
			end
		end

		local settings = PTT.database.memory
		local id = game.difficulty.id
		wonValue:SetText(PTT.FormatNumber(settings.won))
		perfectValue:SetText(PTT.FormatNumber(settings.perfectWins))
		bestTimeValue:SetText(settings.bestTimes[id] and PTT.FormatDuration(settings.bestTimes[id]) or "-")
		bestMovesValue:SetText(settings.bestMoves[id] or "-")
	end

	view:SetScript("OnUpdate", function(_, delta)
		local hadPending = Memory.game.pending
		Memory.Tick(delta)
		RefreshTime()
		if hadPending and not Memory.game.pending then
			Refresh()
		end
	end)

	view:HookScript("OnShow", function()
		Refresh(true)
	end)
	Refresh(true)
	return view
end

PTT.RegisterView({ id = "memory", label = "memory", build = BuildMemory })
