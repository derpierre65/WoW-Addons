local _, PTT = ...
local L = PTT.L
local UI = PTT.UI

---------------------------------------------------------------------------
-- 2048
---------------------------------------------------------------------------

local LABEL_COLOR = { 0.7, 0.55, 0.35 }
local TEXT_COLOR = { 0.78, 0.74, 0.68 }
local GOLD = { 1, 0.82, 0 }

-- Dark boxes shared by the 2048 and Wordle pages.
local function CreateBox(parent, width, height)
	local box = UI.CreatePanel(parent)
	box:SetSize(width, height)
	box:SetBackdropColor(0.07, 0.06, 0.05, 0.95)
	box:SetBackdropBorderColor(0.3, 0.24, 0.15, 1)
	return box
end

local function CreateBoxHeader(box, text)
	local header = UI.CreateLabel(box, "GameFontNormalSmall", text)
	header:SetPoint("TOPLEFT", 12, -10)
	header:SetTextColor(LABEL_COLOR[1], LABEL_COLOR[2], LABEL_COLOR[3])
end

-- Returns the box and the value label.
local function CreateStatTile(parent, width, title)
	local tile = CreateBox(parent, width, 50)
	local header = UI.CreateLabel(tile, "GameFontNormalSmall", title)
	header:SetPoint("TOP", 0, -8)
	header:SetTextColor(LABEL_COLOR[1], LABEL_COLOR[2], LABEL_COLOR[3])
	local value = UI.CreateLabel(tile, "GameFontNormalLarge")
	value:SetPoint("TOP", 0, -24)
	return tile, value
end

-- Label left, value right, inside a box.
local function CreateStatRow(box, index, title)
	local y = -26 - (index - 1) * 20
	local name = UI.CreateLabel(box, "GameFontHighlight", title)
	name:SetPoint("TOPLEFT", 12, y)
	name:SetTextColor(TEXT_COLOR[1], TEXT_COLOR[2], TEXT_COLOR[3])
	local value = UI.CreateLabel(box, "GameFontHighlight")
	value:SetPoint("TOPRIGHT", -12, y)
	return value
end

UI.CreateBox, UI.CreateBoxHeader, UI.CreateStatTile, UI.CreateStatRow = CreateBox, CreateBoxHeader, CreateStatTile, CreateStatRow
UI.gameColors = { label = LABEL_COLOR, text = TEXT_COLOR, gold = GOLD }

local TILE_SIZE, TILE_GAP = 72, 6
local BOARD_SIZE = 4 * TILE_SIZE + 5 * TILE_GAP
local SIDE_PANEL_WIDTH = UI.contentWidth - BOARD_SIZE - 14

local TILE_COLORS = {
	[0] = { 0.1, 0.09, 0.08 },
	[2] = { 0.17, 0.15, 0.11 },
	[4] = { 0.23, 0.2, 0.14 },
	[8] = { 0.36, 0.25, 0.12 },
	[16] = { 0.46, 0.28, 0.12 },
	[32] = { 0.55, 0.3, 0.1 },
	[64] = { 0.6, 0.22, 0.1 },
	[128] = { 0.5, 0.45, 0.15 },
	[256] = { 0.55, 0.48, 0.15 },
	[512] = { 0.65, 0.55, 0.15 },
	[1024] = { 0.78, 0.62, 0.12 },
	[2048] = { 0.9, 0.72, 0.1 },
}
local TILE_COLOR_HIGH = { 0.35, 0.3, 0.2 }

local DIRECTION_KEYS = {
	UP = "up", W = "up",
	DOWN = "down", S = "down",
	LEFT = "left", A = "left",
	RIGHT = "right", D = "right",
}

local function GetTileFontSize(value)
	if value < 100 then
		return 28
	elseif value < 1000 then
		return 24
	elseif value < 10000 then
		return 20
	end
	return 16
end

local function Build2048(parent)
	local Game = PTT.Game2048
	local view = CreateFrame("Frame", nil, parent)

	-- Header: title and subtitle on the left, score, best and new game on the right
	local titleLabel = UI.CreateLabel(view, "GameFontNormalHuge", "2048")
	titleLabel:SetPoint("TOPLEFT", 2, 0)
	titleLabel:SetTextColor(GOLD[1], GOLD[2], GOLD[3])

	local subtitleLabel = UI.CreateLabel(view, "GameFontDisableSmall")
	subtitleLabel:SetPoint("TOPLEFT", 2, -30)

	local function Refresh() end

	local newGameButton = UI.CreateButton(view, L.newGame, 110, 50, function()
		Game.Reset()
		Refresh()
	end)
	newGameButton:SetPoint("TOPRIGHT", 0, 0)

	local bestTile, bestValue = CreateStatTile(view, 90, L.bestTitle)
	bestTile:SetPoint("RIGHT", newGameButton, "LEFT", -8, 0)
	bestValue:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
	local scoreTile, scoreValue = CreateStatTile(view, 90, L.scoreTitle)
	scoreTile:SetPoint("RIGHT", bestTile, "LEFT", -8, 0)
	scoreValue:SetTextColor(1, 1, 1)

	local board = UI.CreatePanel(view)
	board:SetSize(BOARD_SIZE, BOARD_SIZE)
	board:SetPoint("TOPLEFT", 0, -62)
	board:SetBackdropColor(0.07, 0.06, 0.05, 0.95)
	board:SetBackdropBorderColor(0.3, 0.24, 0.15, 1)

	local tiles = {}
	for index = 1, 16 do
		local row, column = math.floor((index - 1) / 4), (index - 1) % 4
		local tile = CreateFrame("Frame", nil, board)
		tile:SetSize(TILE_SIZE, TILE_SIZE)
		tile:SetPoint("TOPLEFT", TILE_GAP + column * (TILE_SIZE + TILE_GAP), -(TILE_GAP + row * (TILE_SIZE + TILE_GAP)))
		tile.background = tile:CreateTexture(nil, "BACKGROUND")
		tile.background:SetAllPoints()
		tile.label = tile:CreateFontString(nil, "OVERLAY")
		tile.label:SetPoint("CENTER")
		tiles[index] = tile
	end

	local overlay = CreateFrame("Frame", nil, board)
	overlay:SetAllPoints()
	overlay:SetFrameLevel(board:GetFrameLevel() + 10)
	overlay.background = overlay:CreateTexture(nil, "BACKGROUND")
	overlay.background:SetAllPoints()
	overlay.background:SetColorTexture(0, 0, 0, 0.65)
	overlay.label = UI.CreateLabel(overlay, "GameFontNormalHuge", L.gameOver)
	overlay.label:SetPoint("CENTER")
	overlay:Hide()

	-- Stats and controls on the right
	local statsBox = CreateBox(view, SIDE_PANEL_WIDTH, 96)
	statsBox:SetPoint("TOPLEFT", board, "TOPRIGHT", 14, 0)
	CreateBoxHeader(statsBox, L.game2048Stats)
	local playedValue = CreateStatRow(statsBox, 1, L.gamesPlayed)
	local highestValue = CreateStatRow(statsBox, 2, L.highestTile)
	highestValue:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
	local bestScoreValue = CreateStatRow(statsBox, 3, L.bestScore)

	local controlsBox = CreateBox(view, SIDE_PANEL_WIDTH, 104)
	controlsBox:SetPoint("TOPLEFT", statsBox, "BOTTOMLEFT", 0, -8)
	CreateBoxHeader(controlsBox, L.controls)

	local keyOffset = 12
	for _, letter in ipairs({ "W", "A", "S", "D" }) do
		local key = UI.CreatePanel(controlsBox)
		key:SetSize(26, 26)
		key:SetPoint("TOPLEFT", keyOffset, -30)
		key:SetBackdropColor(0.2, 0.17, 0.12, 1)
		key:SetBackdropBorderColor(0.4, 0.32, 0.2, 1)
		local keyLabel = UI.CreateLabel(key, "GameFontHighlight", letter)
		keyLabel:SetPoint("CENTER")
		keyOffset = keyOffset + 30
	end

	local arrowHint = UI.CreateLabel(controlsBox, "GameFontHighlightSmall", L.orArrowKeys)
	arrowHint:SetPoint("TOPLEFT", keyOffset + 6, -36)
	arrowHint:SetTextColor(TEXT_COLOR[1], TEXT_COLOR[2], TEXT_COLOR[3])

	local hint = UI.CreateLabel(controlsBox, "GameFontDisableSmall", L.hoverToPlay)
	hint:SetPoint("TOPLEFT", 12, -66)
	hint:SetWidth(SIDE_PANEL_WIDTH - 24)
	hint:SetJustifyH("LEFT")

	local function Move(direction)
		Game.Move(direction)
		Refresh()
	end

	-- Arrow buttons for mouse play, below the controls box.
	local padSize, padGap = 26, 3
	local pad = CreateFrame("Frame", nil, view)
	pad:SetSize(3 * padSize + 2 * padGap, 2 * padSize + padGap)
	pad:SetPoint("TOP", controlsBox, "BOTTOM", 0, -10)
	local function CreatePadButton(text, direction, column, row)
		local button = UI.CreateButton(pad, text, padSize, padSize, function()
			Move(direction)
		end)
		button:SetPoint("TOPLEFT", column * (padSize + padGap), -row * (padSize + padGap))
	end
	CreatePadButton("^", "up", 1, 0)
	CreatePadButton("<", "left", 0, 1)
	CreatePadButton("v", "down", 1, 1)
	CreatePadButton(">", "right", 2, 1)

	Refresh = function()
		for index, tile in ipairs(tiles) do
			local value = Game.board[index]
			local color = TILE_COLORS[value] or TILE_COLOR_HIGH
			tile.background:SetColorTexture(color[1], color[2], color[3], 1)
			tile.label:SetFont(STANDARD_TEXT_FONT, GetTileFontSize(value), "")
			tile.label:SetText(value > 0 and value or "")
			if value > 0 and value <= 4 then
				tile.label:SetTextColor(0.93, 0.89, 0.78)
			elseif value >= 1024 and value <= 2048 then
				tile.label:SetTextColor(0.15, 0.12, 0.05)
			else
				tile.label:SetTextColor(1, 1, 1)
			end
		end

		local settings = PTT.database.game2048
		scoreValue:SetText(PTT.FormatNumber(Game.score))
		bestValue:SetText(PTT.FormatNumber(Game.best))
		playedValue:SetText(PTT.FormatNumber(settings.played or 0))
		highestValue:SetText(PTT.FormatNumber(settings.highestTile or 0))
		bestScoreValue:SetText(PTT.FormatNumber(Game.best))
		overlay:SetShown(Game.over)

		if Game.won and not Game.over then
			subtitleLabel:SetText("|cffffd100" .. L.youWon .. "|r")
		else
			subtitleLabel:SetText(L.game2048Subtitle)
		end
	end

	UI.EnableHoverKeyboard(view, function(key)
		local direction = DIRECTION_KEYS[key]
		if not direction then
			return false
		end
		Move(direction)
		return true
	end)

	view:HookScript("OnShow", Refresh)
	Refresh()
	return view
end

PTT.RegisterView({ id = "game2048", label = "game2048", build = Build2048 })

---------------------------------------------------------------------------
-- Wordle
---------------------------------------------------------------------------

local MAX_COLUMNS = 20
local CELL_GAP = 4
local KEY_WIDTH, KEY_HEIGHT, KEY_GAP = 30, 30, 3
local SIDE_WIDTH, SIDE_GAP = 190, 14
-- Board and keyboard use the space left of the stats column.
local BOARD_WIDTH = UI.contentWidth - SIDE_WIDTH - SIDE_GAP

local COLORS = {
	empty = { 0.12, 0.1, 0.09 },
	typing = { 0.25, 0.22, 0.18 },
	absent = { 0.17, 0.15, 0.13 },
	present = { 0.74, 0.58, 0.13 },
	correct = { 0.24, 0.5, 0.22 },
	keyUnused = { 0.32, 0.28, 0.23 },
	keyAbsent = { 0.12, 0.1, 0.09 },
}

local CATEGORY_LABELS = {
	cities = "categoryCities",
	zones = "categoryZones",
	bosses = "categoryBosses",
}

local KEY_ROWS = {
	enUS = { "QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM" },
	deDE = { "QWERTZUIOPÜ", "ASDFGHJKLÖÄ", "YXCVBNM" },
}

local function SetColor(texture, color)
	texture:SetColorTexture(color[1], color[2], color[3], 1)
end

local function CreateDropdown(parent, name, width)
	local dropdown = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
	UIDropDownMenu_SetWidth(dropdown, width)
	return dropdown
end

local function BuildWordle(parent)
	local Wordle = PTT.Wordle
	local settings = PTT.database.wordle
	local view = CreateFrame("Frame", nil, parent)
	-- Typed letters, one entry per character (umlauts are multi-byte).
	local input = {}

	local statusLabel = UI.CreateLabel(view, "GameFontNormal")
	statusLabel:SetPoint("TOPLEFT", 4, -34)
	statusLabel:SetWidth(BOARD_WIDTH - 8)
	statusLabel:SetJustifyH("LEFT")

	-- Stats column on the right
	local side = CreateFrame("Frame", nil, view)
	side:SetSize(SIDE_WIDTH, 320)
	side:SetPoint("TOPRIGHT", 0, -36)

	local tileWidth = (SIDE_WIDTH - 8) / 2
	local streakTile, streakValue = CreateStatTile(side, tileWidth, L.wordleStreak)
	streakTile:SetPoint("TOPLEFT", 0, 0)
	streakValue:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
	local winRateTile, winRateValue = CreateStatTile(side, tileWidth, L.wordleWinRate)
	winRateTile:SetPoint("TOPLEFT", tileWidth + 8, 0)
	winRateValue:SetTextColor(1, 1, 1)

	local statsBox = CreateBox(side, SIDE_WIDTH, 96)
	statsBox:SetPoint("TOPLEFT", 0, -58)
	CreateBoxHeader(statsBox, L.wordleYourStats)
	local playedValue = CreateStatRow(statsBox, 1, L.wordlePlayed)
	local currentStreakValue = CreateStatRow(statsBox, 2, L.wordleCurrentStreak)
	currentStreakValue:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
	local bestStreakValue = CreateStatRow(statsBox, 3, L.wordleBestStreak)

	local legendBox = CreateBox(side, SIDE_WIDTH, 124)
	legendBox:SetPoint("TOPLEFT", statsBox, "BOTTOMLEFT", 0, -8)
	CreateBoxHeader(legendBox, L.wordleLegend)

	for index, entry in ipairs({
		{ COLORS.correct, L.wordleLegendCorrect },
		{ COLORS.present, L.wordleLegendPresent },
		{ COLORS.absent, L.wordleLegendAbsent },
	}) do
		local swatch = legendBox:CreateTexture(nil, "ARTWORK")
		swatch:SetSize(16, 16)
		swatch:SetPoint("TOPLEFT", 12, -30 - (index - 1) * 30)
		SetColor(swatch, entry[1])
		local label = UI.CreateLabel(legendBox, "GameFontHighlightSmall", entry[2])
		label:SetPoint("LEFT", swatch, "RIGHT", 8, 0)
		label:SetWidth(SIDE_WIDTH - 52)
		label:SetJustifyH("LEFT")
	end

	local grid = CreateFrame("Frame", nil, view)
	grid:SetPoint("TOP", view, "TOPLEFT", BOARD_WIDTH / 2, -58)

	local cells = {}
	for row = 1, Wordle.maxAttempts do
		cells[row] = {}
		for column = 1, MAX_COLUMNS do
			local cell = CreateFrame("Frame", nil, grid)
			cell.background = cell:CreateTexture(nil, "BACKGROUND")
			cell.background:SetAllPoints()
			cell.label = cell:CreateFontString(nil, "OVERLAY")
			cell.label:SetPoint("CENTER")
			cell.label:SetTextColor(1, 1, 1)
			cells[row][column] = cell
		end
	end

	-- Buttons of the keyboard layout that is currently shown.
	local keyButtons = {}

	local function Refresh()
		local game = Wordle.game
		local length = Wordle.Length(game.word)
		local cellSize = math.min(34, math.floor((BOARD_WIDTH + CELL_GAP) / length) - CELL_GAP)

		grid:SetSize(length * (cellSize + CELL_GAP) - CELL_GAP, Wordle.maxAttempts * (cellSize + CELL_GAP) - CELL_GAP)

		for row = 1, Wordle.maxAttempts do
			local guess = game.guesses[row]
			local evaluation = guess and Wordle.Evaluate(guess, game.word)
			local guessLetters = guess and Wordle.Split(guess)
			local isTypingRow = not guess and game.state == "playing" and row == #game.guesses + 1

			for column = 1, MAX_COLUMNS do
				local cell = cells[row][column]
				if column > length then
					cell:Hide()
				else
					cell:Show()
					cell:SetSize(cellSize, cellSize)
					cell:ClearAllPoints()
					cell:SetPoint("TOPLEFT", (column - 1) * (cellSize + CELL_GAP), -(row - 1) * (cellSize + CELL_GAP))
					cell.label:SetFont(STANDARD_TEXT_FONT, cellSize >= 28 and 20 or 14, "")

					local letter = ""
					local color = COLORS.empty
					if guess then
						letter = guessLetters[column]
						color = COLORS[evaluation[column]]
					elseif isTypingRow and input[column] then
						letter = input[column]
						color = COLORS.typing
					end
					cell.label:SetText(letter)
					SetColor(cell.background, color)
				end
			end
		end

		local states = Wordle.GetLetterStates()
		for letter, button in pairs(keyButtons) do
			local state = states[letter]
			if state == "absent" then
				SetColor(button.background, COLORS.keyAbsent)
			elseif state then
				SetColor(button.background, COLORS[state])
			else
				SetColor(button.background, COLORS.keyUnused)
			end
		end

		if game.state == "won" then
			statusLabel:SetText("|cff55dd55" .. L.wordleWon .. "|r")
		elseif game.state == "lost" then
			statusLabel:SetText("|cffdd5555" .. string.format(L.wordleLost, game.word) .. "|r")
		else
			statusLabel:SetText(string.format("%s  |cff999999(%s)|r", L.wordleGuess, string.format(L.wordleLength, length)))
		end

		streakValue:SetText(settings.streak or 0)
		winRateValue:SetText(settings.played > 0 and string.format("%d%%", math.floor(settings.won / settings.played * 100 + 0.5)) or "-")
		playedValue:SetText(settings.played)
		currentStreakValue:SetText(settings.streak or 0)
		bestStreakValue:SetText(settings.bestStreak or 0)
	end

	local function PressLetter(letter)
		if Wordle.game.state ~= "playing" or #input >= Wordle.Length(Wordle.game.word) then
			return
		end
		input[#input + 1] = letter
		Refresh()
	end

	local function PressBackspace()
		if Wordle.game.state ~= "playing" or #input == 0 then
			return
		end
		input[#input] = nil
		Refresh()
	end

	local function PressEnter()
		local game = Wordle.game
		if game.state ~= "playing" then
			return
		end

		local length = Wordle.Length(game.word)
		if #input ~= length then
			statusLabel:SetText("|cffdd9955" .. string.format(L.wordleTooShort, length) .. "|r")
			return
		end

		if Wordle.Submit(table.concat(input)) then
			input = {}
			Refresh()
		end
	end

	-- Forward declarations: a new word can change the language (keyboard) and fall back to other options.
	local ShowKeyboard, UpdateDropdownTexts

	local function StartNewWord()
		Wordle.NewGame()
		input = {}
		ShowKeyboard()
		UpdateDropdownTexts()
		Refresh()
	end

	-- Dropdowns
	local languageDropdown = CreateDropdown(view, "PassTheTimeWordleLanguage", 90)
	languageDropdown:SetPoint("TOPLEFT", -16, -2)
	UIDropDownMenu_Initialize(languageDropdown, function(_, level)
		for _, code in ipairs(Wordle.languages) do
			local text = L["languageName_" .. code]
			local info = UIDropDownMenu_CreateInfo()
			info.text = text
			info.checked = Wordle.ResolveLanguage() == code
			info.func = function()
				settings.language = code
				UIDropDownMenu_SetText(languageDropdown, text)
				StartNewWord()
			end
			UIDropDownMenu_AddButton(info, level)
		end
	end)

	local categoryDropdown = CreateDropdown(view, "PassTheTimeWordleCategory", 110)
	categoryDropdown:SetPoint("LEFT", languageDropdown, "RIGHT", -24, 0)
	local function GetCategoryText()
		if settings.category == "all" or not CATEGORY_LABELS[settings.category] then
			return L.wordleAll
		end
		return L[CATEGORY_LABELS[settings.category]]
	end
	UIDropDownMenu_Initialize(categoryDropdown, function(_, level)
		local options = { { key = "all", text = L.wordleAll } }
		for _, key in ipairs(PTT.WordleCategories) do
			options[#options + 1] = { key = key, text = L[CATEGORY_LABELS[key]] }
		end

		for _, option in ipairs(options) do
			local info = UIDropDownMenu_CreateInfo()
			info.text = option.text
			info.checked = settings.category == option.key
			info.func = function()
				settings.category = option.key
				UIDropDownMenu_SetText(categoryDropdown, option.text)
				StartNewWord()
			end
			UIDropDownMenu_AddButton(info, level)
		end
	end)

	local lengthDropdown = CreateDropdown(view, "PassTheTimeWordleLength", 100)
	lengthDropdown:SetPoint("LEFT", categoryDropdown, "RIGHT", -24, 0)
	local function GetLengthText()
		if type(settings.length) ~= "number" then
			return L.wordleAll
		end
		return string.format(L.wordleLength, settings.length)
	end
	UIDropDownMenu_Initialize(lengthDropdown, function(_, level)
		local options = { { key = "all", text = L.wordleAll } }
		for _, length in ipairs(Wordle.GetLengths(Wordle.ResolveLanguage(), settings.category)) do
			options[#options + 1] = { key = length, text = string.format(L.wordleLength, length) }
		end

		for _, option in ipairs(options) do
			local info = UIDropDownMenu_CreateInfo()
			info.text = option.text
			info.checked = (settings.length or "all") == option.key
			info.func = function()
				settings.length = option.key
				UIDropDownMenu_SetText(lengthDropdown, option.text)
				StartNewWord()
			end
			UIDropDownMenu_AddButton(info, level)
		end
	end)

	UpdateDropdownTexts = function()
		UIDropDownMenu_SetText(languageDropdown, L["languageName_" .. Wordle.ResolveLanguage()])
		UIDropDownMenu_SetText(categoryDropdown, GetCategoryText())
		UIDropDownMenu_SetText(lengthDropdown, GetLengthText())
	end

	local newWordButton = UI.CreateButton(view, L.newGame, 90, 24, StartNewWord)
	newWordButton:SetPoint("TOPRIGHT", 0, -4)

	-- On-screen keyboard
	local function CreateKey(text, width, onClick)
		local button = CreateFrame("Button", nil, view)
		button:SetSize(width, KEY_HEIGHT)
		button.background = button:CreateTexture(nil, "BACKGROUND")
		button.background:SetAllPoints()
		SetColor(button.background, COLORS.keyUnused)
		button.label = UI.CreateLabel(button, "GameFontHighlight", text)
		button.label:SetPoint("CENTER")
		button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
		button:SetScript("OnClick", onClick)
		return button
	end

	local function BuildKeyboard(language)
		local keyboard = CreateFrame("Frame", nil, view)
		keyboard:SetAllPoints()
		keyboard.buttons = {}

		local rows = KEY_ROWS[language]
		for rowIndex, rowLetters in ipairs(rows) do
			local letters = Wordle.Split(rowLetters)
			local isLastRow = rowIndex == #rows
			local extraWidth = isLastRow and (2 * (KEY_WIDTH + 18 + KEY_GAP)) or 0
			local rowWidth = #letters * (KEY_WIDTH + KEY_GAP) - KEY_GAP + extraWidth
			local y = (#rows - rowIndex) * (KEY_HEIGHT + KEY_GAP)
			local x = math.floor((BOARD_WIDTH - rowWidth) / 2)

			if isLastRow then
				local enter = CreateKey("OK", KEY_WIDTH + 18, PressEnter)
				enter:SetParent(keyboard)
				enter:SetPoint("BOTTOMLEFT", x, y)
				x = x + KEY_WIDTH + 18 + KEY_GAP
			end

			for _, letter in ipairs(letters) do
				local key = CreateKey(letter, KEY_WIDTH, function()
					PressLetter(letter)
				end)
				key:SetParent(keyboard)
				key:SetPoint("BOTTOMLEFT", x, y)
				keyboard.buttons[letter] = key
				x = x + KEY_WIDTH + KEY_GAP
			end

			if isLastRow then
				local backspace = CreateKey("<-", KEY_WIDTH + 18, PressBackspace)
				backspace:SetParent(keyboard)
				backspace:SetPoint("BOTTOMLEFT", x, y)
			end
		end

		return keyboard
	end

	local keyboards = {}
	ShowKeyboard = function()
		local language = Wordle.ResolveLanguage()
		for otherLanguage, keyboard in pairs(keyboards) do
			keyboard:SetShown(otherLanguage == language)
		end

		keyboards[language] = keyboards[language] or BuildKeyboard(language)
		keyboards[language]:Show()
		keyButtons = keyboards[language].buttons
	end
	ShowKeyboard()

	UI.EnableHoverKeyboard(view, function(key)
		if Wordle.game.state ~= "playing" then
			return false
		end

		if key == "BACKSPACE" then
			PressBackspace()
			return true
		elseif key == "ENTER" then
			PressEnter()
			return true
		end

		-- Only letters that exist on the shown keyboard, so umlauts work in German only.
		local letter = Wordle.Normalize(key)
		if Wordle.Length(key) == 1 and keyButtons[letter] then
			PressLetter(letter)
			return true
		end
		return false
	end)

	view:HookScript("OnShow", function()
		ShowKeyboard()
		UpdateDropdownTexts()
		Refresh()
	end)
	UpdateDropdownTexts()
	Refresh()
	return view
end

PTT.RegisterView({ id = "wordle", label = "wordle", build = BuildWordle })
