local _, PTT = ...
local L = PTT.L
local UI = PTT.UI

local KEY_WIDTH, KEY_HEIGHT, KEY_GAP = 30, 30, 3
local SIDE_WIDTH, SIDE_GAP = 190, 14
-- Figure, word and keyboard use the space left of the stats column.
local BOARD_WIDTH = UI.contentWidth - SIDE_WIDTH - SIDE_GAP
local FIGURE_WIDTH, FIGURE_HEIGHT = 130, 190
local WORD_X = FIGURE_WIDTH + 30
local WORD_WIDTH = BOARD_WIDTH - WORD_X
local FIGURE_PARTS = 8

local COLORS = {
	gallows = { 0.55, 0.4, 0.25 },
	figure = { 0.88, 0.82, 0.7 },
	keyUnused = { 0.32, 0.28, 0.23 },
	keyCorrect = { 0.24, 0.5, 0.22 },
	keyWrong = { 0.12, 0.1, 0.09 },
}

local CATEGORY_LABELS = {
	cities = "categoryCities",
	zones = "categoryZones",
	bosses = "categoryBosses",
}

-- Umlauts are matched to their base letter, so there are no umlaut keys.
local KEY_ROWS = {
	enUS = { "QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM" },
	deDE = { "QWERTZUIOP", "ASDFGHJKL", "YXCVBNM" },
}

local KEYBOARD_ROW_COUNT, KEYBOARD_MAX_KEYS = 3, 10
local KEYBOARD_WIDTH = KEYBOARD_MAX_KEYS * (KEY_WIDTH + KEY_GAP) - KEY_GAP
local KEYBOARD_HEIGHT = KEYBOARD_ROW_COUNT * (KEY_HEIGHT + KEY_GAP) - KEY_GAP
local KEYBOARD_X = math.floor((BOARD_WIDTH - KEYBOARD_WIDTH) / 2)
local SOLVE_BUTTON_WIDTH = 100

local CreateBox, CreateBoxHeader, CreateStatTile, CreateStatRow = UI.CreateBox, UI.CreateBoxHeader, UI.CreateStatTile, UI.CreateStatRow
local SetColor, CreateDropdown = UI.SetColor, UI.CreateDropdown
local GOLD = UI.gameColors.gold

-- Each part of the figure is one or more rectangles { x, y, width, height } measured from the top left of the figure frame.
local FIGURE_LAYOUT = {
	{ { 0, -184, 110, 6 } },
	{ { 20, 0, 6, 184 } },
	{ { 20, 0, 90, 6 }, { 104, -6, 3, 22 } },
	{ { 92, -28, 26, 26 } },
	{ { 103, -54, 4, 50 } },
	{ { 83, -62, 20, 4 } },
	{ { 107, -62, 20, 4 } },
	{ { 97, -104, 4, 40 }, { 109, -104, 4, 40 } },
}

local function BuildHangman(parent)
	local Hangman = PTT.Hangman
	local settings = PTT.database.hangman
	local view = CreateFrame("Frame", nil, parent)

	local statusLabel = UI.CreateLabel(view, "GameFontNormal")
	statusLabel:SetPoint("TOPLEFT", 4, -34)
	statusLabel:SetWidth(BOARD_WIDTH - 8)
	statusLabel:SetJustifyH("LEFT")

	-- Assigned below; the new game button is created before it.
	local StartNewWord

	local newWordButton = UI.CreateButton(view, L.newGame, 110, 50, function()
		UI.ConfirmNewGame(StartNewWord, Hangman.game.state ~= "playing")
	end)
	newWordButton:SetPoint("TOPRIGHT", 0, 0)

	local winRateTile, winRateValue = CreateStatTile(view, 90, L.hangmanWinRate)
	winRateTile:SetPoint("RIGHT", newWordButton, "LEFT", -8, 0)
	winRateValue:SetTextColor(1, 1, 1)
	local streakTile, streakValue = CreateStatTile(view, 90, L.hangmanStreak)
	streakTile:SetPoint("RIGHT", winRateTile, "LEFT", -8, 0)
	streakValue:SetTextColor(GOLD[1], GOLD[2], GOLD[3])

	-- Stats column on the right
	local side = CreateFrame("Frame", nil, view)
	side:SetSize(SIDE_WIDTH, 320)
	side:SetPoint("TOPRIGHT", 0, -58)

	local statsBox = CreateBox(side, SIDE_WIDTH, 96)
	statsBox:SetPoint("TOPLEFT", 0, 0)
	CreateBoxHeader(statsBox, L.hangmanYourStats)
	local playedValue = CreateStatRow(statsBox, 1, L.hangmanPlayed)
	local currentStreakValue = CreateStatRow(statsBox, 2, L.hangmanCurrentStreak)
	currentStreakValue:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
	local bestStreakValue = CreateStatRow(statsBox, 3, L.hangmanBestStreak)

	local wrongBox = CreateBox(side, SIDE_WIDTH, 96)
	wrongBox:SetPoint("TOPLEFT", statsBox, "BOTTOMLEFT", 0, -8)
	CreateBoxHeader(wrongBox, L.hangmanWrongLetters)
	local wrongLettersLabel = UI.CreateLabel(wrongBox, "GameFontHighlight")
	wrongLettersLabel:SetPoint("TOPLEFT", 12, -28)
	wrongLettersLabel:SetWidth(SIDE_WIDTH - 24)
	wrongLettersLabel:SetJustifyH("LEFT")
	local errorsLabel = UI.CreateLabel(wrongBox, "GameFontNormal")
	errorsLabel:SetPoint("BOTTOMLEFT", 12, 10)

	-- Gallows and figure
	local figure = CreateFrame("Frame", nil, view)
	figure:SetSize(FIGURE_WIDTH, FIGURE_HEIGHT)
	figure:SetPoint("TOPLEFT", 10, -62)

	local figureParts = {}
	for index, rectangles in ipairs(FIGURE_LAYOUT) do
		figureParts[index] = {}
		for _, rectangle in ipairs(rectangles) do
			local texture = figure:CreateTexture(nil, "ARTWORK")
			texture:SetPoint("TOPLEFT", rectangle[1], rectangle[2])
			texture:SetSize(rectangle[3], rectangle[4])
			SetColor(texture, index <= 3 and COLORS.gallows or COLORS.figure)
			figureParts[index][#figureParts[index] + 1] = texture
		end
	end

	-- The word, one underscore per hidden letter.
	local wordLabel = view:CreateFontString(nil, "OVERLAY")
	wordLabel:SetPoint("TOPLEFT", WORD_X, -100)
	wordLabel:SetWidth(WORD_WIDTH)
	wordLabel:SetWordWrap(false)
	wordLabel:SetJustifyH("CENTER")
	wordLabel:SetTextColor(1, 1, 1)

	-- Whole-word guess, built bottom-up above the keyboard and as wide as its longest row.
	local solveHint = UI.CreateLabel(view, "GameFontDisableSmall", L.hangmanSolveHint)
	solveHint:SetPoint("BOTTOMLEFT", KEYBOARD_X, KEYBOARD_HEIGHT + 14)

	local solveInput = CreateFrame("EditBox", nil, view, "InputBoxTemplate")
	solveInput:SetSize(KEYBOARD_WIDTH - SOLVE_BUTTON_WIDTH - 14, 22)
	solveInput:SetPoint("BOTTOMLEFT", solveHint, "TOPLEFT", 6, 6)
	solveInput:SetAutoFocus(false)
	solveInput:SetMaxLetters(40)

	local solveButton = UI.CreateButton(view, L.hangmanSolve, SOLVE_BUTTON_WIDTH, 24, function()
		solveInput:GetScript("OnEnterPressed")(solveInput)
	end)
	solveButton:SetPoint("LEFT", solveInput, "RIGHT", 8, 0)

	local solveLabel = UI.CreateLabel(view, "GameFontNormalSmall", L.hangmanSolveTitle)
	solveLabel:SetPoint("BOTTOMLEFT", solveInput, "TOPLEFT", -6, 6)
	solveLabel:SetTextColor(UI.gameColors.label[1], UI.gameColors.label[2], UI.gameColors.label[3])

	-- Buttons of the keyboard layout that is currently shown.
	local keyButtons = {}

	local function Refresh()
		local game = Hangman.game
		local errors, maxErrors = Hangman.GetErrors(), Hangman.GetMaxErrors()

		local shownParts = game.state == "lost" and FIGURE_PARTS or math.floor(errors * FIGURE_PARTS / maxErrors + 0.5)
		for index, textures in ipairs(figureParts) do
			for _, texture in ipairs(textures) do
				texture:SetShown(index <= shownParts)
			end
		end

		local display = Hangman.GetDisplay()
		local wordFontSize = math.max(12, math.min(30, math.floor(WORD_WIDTH / (0.9 * #display))))
		wordLabel:SetFont(STANDARD_TEXT_FONT, wordFontSize, "")
		wordLabel:SetText(table.concat(display, " "))

		local wrongSet = {}
		local wrongLetters = Hangman.GetWrongLetters()
		for _, letter in ipairs(wrongLetters) do
			wrongSet[letter] = true
		end
		for letter, button in pairs(keyButtons) do
			if wrongSet[letter] then
				SetColor(button.background, COLORS.keyWrong)
			elseif Hangman.IsGuessed(letter) then
				SetColor(button.background, COLORS.keyCorrect)
			else
				SetColor(button.background, COLORS.keyUnused)
			end
		end

		wrongLettersLabel:SetText(#wrongLetters > 0 and table.concat(wrongLetters, " ") or "|cff999999" .. L.hangmanNoWrongLetters .. "|r")
		errorsLabel:SetText(string.format("%s: %d / %d", L.hangmanErrors, errors, maxErrors))

		if game.state == "won" then
			statusLabel:SetText("|cff55dd55" .. L.hangmanWon .. "|r")
		elseif game.state == "lost" then
			statusLabel:SetText("|cffdd5555" .. string.format(L.hangmanLost, game.word) .. "|r")
		elseif Hangman.ShowsCategory(game.difficulty) then
			statusLabel:SetText(string.format("%s  |cff999999(%s)|r", string.format(L.hangmanHint, L[CATEGORY_LABELS[game.category]]), L.hangmanGuess))
		else
			statusLabel:SetText(string.format("%s  |cff999999(%s)|r", L.hangmanNoHint, L.hangmanGuess))
		end

		streakValue:SetText(settings.streak or 0)
		winRateValue:SetText(settings.played > 0 and string.format("%d%%", math.floor(settings.won / settings.played * 100 + 0.5)) or "-")
		playedValue:SetText(settings.played)
		currentStreakValue:SetText(settings.streak or 0)
		bestStreakValue:SetText(settings.bestStreak or 0)
	end

	solveInput:SetScript("OnEnterPressed", function(self)
		local text = self:GetText()
		if text == "" then
			return
		end

		if Hangman.GuessWord(text) then
			self:SetText("")
			self:ClearFocus()
			Refresh()
		end
	end)
	solveInput:SetScript("OnEscapePressed", solveInput.ClearFocus)

	local function PressLetter(letter)
		if Hangman.GuessLetter(letter) then
			Refresh()
		end
	end

	-- Forward declarations: a new word can change the language (keyboard) and fall back to other options.
	local ShowKeyboard, UpdateDropdownTexts

	StartNewWord = function()
		Hangman.NewGame()
		solveInput:SetText("")
		solveInput:ClearFocus()
		ShowKeyboard()
		UpdateDropdownTexts()
		Refresh()
	end

	-- Dropdowns
	local languageDropdown = CreateDropdown(view, "PassTheTimeHangmanLanguage", 90)
	languageDropdown:SetPoint("TOPLEFT", -16, -2)
	UIDropDownMenu_Initialize(languageDropdown, function(_, level)
		for _, code in ipairs(Hangman.languages) do
			local text = L["languageName_" .. code]
			local info = UIDropDownMenu_CreateInfo()
			info.text = text
			info.checked = Hangman.ResolveLanguage() == code
			info.func = function()
				settings.language = code
				UIDropDownMenu_SetText(languageDropdown, text)
				StartNewWord()
			end
			UIDropDownMenu_AddButton(info, level)
		end
	end)

	local categoryDropdown = CreateDropdown(view, "PassTheTimeHangmanCategory", 110)
	categoryDropdown:SetPoint("LEFT", languageDropdown, "RIGHT", -24, 0)
	local function GetCategoryText()
		if settings.category == "all" or not CATEGORY_LABELS[settings.category] then
			return L.hangmanAll
		end
		return L[CATEGORY_LABELS[settings.category]]
	end
	UIDropDownMenu_Initialize(categoryDropdown, function(_, level)
		local options = { { key = "all", text = L.hangmanAll } }
		for _, key in ipairs(PTT.HangmanCategories) do
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

	local difficultyDropdown = CreateDropdown(view, "PassTheTimeHangmanDifficulty", 90)
	difficultyDropdown:SetPoint("LEFT", categoryDropdown, "RIGHT", -24, 0)
	UIDropDownMenu_Initialize(difficultyDropdown, function(_, level)
		for _, key in ipairs(Hangman.difficulties) do
			local text = L["difficulty_" .. key]
			local info = UIDropDownMenu_CreateInfo()
			info.text = text
			info.checked = settings.difficulty == key
			info.func = function()
				settings.difficulty = key
				UIDropDownMenu_SetText(difficultyDropdown, text)
				StartNewWord()
			end
			UIDropDownMenu_AddButton(info, level)
		end
	end)

	UpdateDropdownTexts = function()
		UIDropDownMenu_SetText(languageDropdown, L["languageName_" .. Hangman.ResolveLanguage()])
		UIDropDownMenu_SetText(categoryDropdown, GetCategoryText())
		UIDropDownMenu_SetText(difficultyDropdown, L["difficulty_" .. settings.difficulty])
	end

	-- On-screen keyboard
	local function CreateKey(letter)
		local button = CreateFrame("Button", nil, view)
		button:SetSize(KEY_WIDTH, KEY_HEIGHT)
		button.background = button:CreateTexture(nil, "BACKGROUND")
		button.background:SetAllPoints()
		SetColor(button.background, COLORS.keyUnused)
		button.label = UI.CreateLabel(button, "GameFontHighlight", letter)
		button.label:SetPoint("CENTER")
		button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
		button:SetScript("OnClick", function()
			PressLetter(letter)
		end)
		return button
	end

	local function BuildKeyboard(language)
		local keyboard = CreateFrame("Frame", nil, view)
		keyboard:SetAllPoints()
		keyboard.buttons = {}

		local rows = KEY_ROWS[language]
		for rowIndex, rowLetters in ipairs(rows) do
			local rowWidth = #rowLetters * (KEY_WIDTH + KEY_GAP) - KEY_GAP
			local y = (#rows - rowIndex) * (KEY_HEIGHT + KEY_GAP)
			local x = math.floor((BOARD_WIDTH - rowWidth) / 2)

			for position = 1, #rowLetters do
				local letter = rowLetters:sub(position, position)
				local key = CreateKey(letter)
				key:SetParent(keyboard)
				key:SetPoint("BOTTOMLEFT", x, y)
				keyboard.buttons[letter] = key
				x = x + KEY_WIDTH + KEY_GAP
			end
		end

		return keyboard
	end

	local keyboards = {}
	ShowKeyboard = function()
		local language = Hangman.ResolveLanguage()
		for otherLanguage, keyboard in pairs(keyboards) do
			keyboard:SetShown(otherLanguage == language)
		end

		keyboards[language] = keyboards[language] or BuildKeyboard(language)
		keyboards[language]:Show()
		keyButtons = keyboards[language].buttons
	end
	ShowKeyboard()

	UI.EnableHoverKeyboard(view, function(key)
		if Hangman.game.state ~= "playing" or Hangman.Length(key) ~= 1 then
			return false
		end

		local letter = Hangman.Normalize(key)
		if keyButtons[letter] then
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

PTT.RegisterView({ id = "hangman", label = "hangman", build = BuildHangman })
