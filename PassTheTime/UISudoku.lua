local _, PTT = ...
local L = PTT.L
local UI = PTT.UI

---------------------------------------------------------------------------
-- Sudoku
---------------------------------------------------------------------------

local SIDE_WIDTH = 190
local CELL_SIZE, CELL_GAP, BOX_GAP, BOARD_PADDING = 40, 1, 4, 4

local COLORS = {
	cell = { 0.12, 0.1, 0.08 },
	cellAlternate = { 0.15, 0.13, 0.1 },
	peer = { 0.2, 0.17, 0.11 },
	sameDigit = { 0.32, 0.26, 0.1 },
	selected = { 0.45, 0.35, 0.1 },
}

local TEXT_COLORS = {
	given = { 0.93, 0.89, 0.78 },
	entry = { 1, 0.82, 0 },
	wrong = { 1, 0.35, 0.3 },
}

local NAVIGATION = { UP = -9, DOWN = 9, LEFT = -1, RIGHT = 1 }

-- Notes keep their place in a 3x3 layout; missing digits are invisible placeholders of the same width.
local function FormatNotes(notes)
	if not notes then
		return ""
	end

	local lines = {}
	for row = 0, 2 do
		local parts = {}
		for column = 1, 3 do
			local digit = row * 3 + column
			parts[column] = notes[digit] and digit or ("|c00000000" .. digit .. "|r")
		end
		lines[#lines + 1] = table.concat(parts, " ")
	end
	return table.concat(lines, "\n")
end

local function BuildSudoku(parent)
	local Sudoku = PTT.Sudoku
	local colors = UI.gameColors
	local view = CreateFrame("Frame", nil, parent)

	local selected = 1
	local notesMode = false
	-- Result of the last verification, shown until the next change on the board.
	local message

	-- Header
	local titleLabel = UI.CreateLabel(view, "GameFontNormalHuge", L.sudoku)
	titleLabel:SetPoint("TOPLEFT", 2, 0)
	titleLabel:SetTextColor(colors.gold[1], colors.gold[2], colors.gold[3])

	local subtitleLabel = UI.CreateLabel(view, "GameFontDisableSmall")
	subtitleLabel:SetPoint("TOPLEFT", 2, -30)

	local Refresh
	local function StartGame(difficultyId)
		Sudoku.NewGame(difficultyId)
		selected = 1
		message = nil
		Refresh()
	end

	local newGameButton = UI.CreateButton(view, L.newGame, 110, 50, function()
		UI.ConfirmNewGame(StartGame)
	end)
	newGameButton:SetPoint("TOPRIGHT", 0, 0)

	local timeTile, timeValue = UI.CreateStatTile(view, 90, L.timeTitle)
	timeTile:SetPoint("RIGHT", newGameButton, "LEFT", -8, 0)
	timeValue:SetTextColor(1, 1, 1)
	local mistakesTile, mistakesValue = UI.CreateStatTile(view, 90, L.mistakesTitle)
	mistakesTile:SetPoint("RIGHT", timeTile, "LEFT", -8, 0)
	mistakesValue:SetTextColor(colors.gold[1], colors.gold[2], colors.gold[3])

	-- Board
	local boardSize = 2 * BOARD_PADDING + 9 * CELL_SIZE + 8 * CELL_GAP + 2 * (BOX_GAP - CELL_GAP)
	local board = UI.CreatePanel(view)
	board:SetSize(boardSize, boardSize)
	board:SetPoint("TOPLEFT", 0, -62)
	board:SetBackdropColor(0.07, 0.06, 0.05, 0.95)
	board:SetBackdropBorderColor(0.3, 0.24, 0.15, 1)

	local function GetOffset(position)
		return BOARD_PADDING + (position - 1) * (CELL_SIZE + CELL_GAP) + math.floor((position - 1) / 3) * (BOX_GAP - CELL_GAP)
	end

	local cells = {}
	for index = 1, 81 do
		local cell = CreateFrame("Button", nil, board)
		cell:SetSize(CELL_SIZE, CELL_SIZE)
		cell:SetPoint("TOPLEFT", GetOffset(Sudoku.GetColumn(index)), -GetOffset(Sudoku.GetRow(index)))
		cell.background = cell:CreateTexture(nil, "BACKGROUND")
		cell.background:SetAllPoints()
		cell.label = cell:CreateFontString(nil, "OVERLAY")
		cell.label:SetPoint("CENTER")
		cell.label:SetFont(STANDARD_TEXT_FONT, 22, "")
		cell.notes = cell:CreateFontString(nil, "OVERLAY")
		cell.notes:SetPoint("CENTER")
		cell.notes:SetFont(STANDARD_TEXT_FONT, 9, "")
		cell.notes:SetTextColor(0.7, 0.62, 0.45)
		cell:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
		cell:SetScript("OnClick", function()
			selected = index
			Refresh()
		end)
		cells[index] = cell
	end

	-- Side column
	local side = CreateFrame("Frame", nil, view)
	side:SetSize(SIDE_WIDTH, 380)
	side:SetPoint("TOPRIGHT", 0, -62)

	local difficultyBox = UI.CreateBox(side, SIDE_WIDTH, 84)
	difficultyBox:SetPoint("TOPLEFT", 0, 0)
	UI.CreateBoxHeader(difficultyBox, L.difficultyTitle)
	local difficultyButtons = {}
	local difficultyWidth = (SIDE_WIDTH - 24 - 4) / 2
	for index, difficulty in ipairs(Sudoku.difficulties) do
		local button = UI.CreateButton(difficultyBox, "", difficultyWidth, 22, function()
			StartGame(difficulty.id)
		end)
		button:SetPoint("TOPLEFT", 12 + ((index - 1) % 2) * (difficultyWidth + 4), -28 - math.floor((index - 1) / 2) * 26)
		difficultyButtons[index] = button
	end

	local numbersBox = UI.CreateBox(side, SIDE_WIDTH, 214)
	numbersBox:SetPoint("TOPLEFT", difficultyBox, "BOTTOMLEFT", 0, -8)
	UI.CreateBoxHeader(numbersBox, L.numbersTitle)

	local function PlaceDigit(digit)
		message = nil
		if notesMode then
			Sudoku.ToggleNote(selected, digit)
		else
			Sudoku.SetNumber(selected, digit)
		end
		Refresh()
	end

	local padWidth, padHeight, padGap = 50, 30, 4
	local digitButtons = {}
	for digit = 1, 9 do
		local button = UI.CreateButton(numbersBox, tostring(digit), padWidth, padHeight, function()
			PlaceDigit(digit)
		end)
		button:SetPoint("TOPLEFT", 12 + ((digit - 1) % 3) * (padWidth + padGap), -28 - math.floor((digit - 1) / 3) * (padHeight + padGap))
		digitButtons[digit] = button
	end

	local eraseButton = UI.CreateButton(numbersBox, L.erase, padWidth, padHeight, function()
		message = nil
		Sudoku.ClearCell(selected)
		Refresh()
	end)
	eraseButton:SetPoint("TOPLEFT", 12, -28 - 3 * (padHeight + padGap))

	local notesButton = UI.CreateButton(numbersBox, L.notes, padWidth, padHeight, function()
		notesMode = not notesMode
		Refresh()
	end)
	notesButton:SetPoint("TOPLEFT", 12 + (padWidth + padGap), -28 - 3 * (padHeight + padGap))

	local hintButton = UI.CreateButton(numbersBox, L.hint, padWidth, padHeight, function()
		message = nil
		Sudoku.Hint(selected)
		Refresh()
	end)
	hintButton:SetPoint("TOPLEFT", 12 + 2 * (padWidth + padGap), -28 - 3 * (padHeight + padGap))

	-- Only a full board can be verified; a wrong one stays open, the wrong cells turn red.
	local verifyButton = UI.CreateButton(numbersBox, L.verify, 3 * padWidth + 2 * padGap, padHeight, function()
		local _, reason, wrong = Sudoku.Verify()
		message = reason == "wrong" and string.format(L.sudokuWrong, wrong) or nil
		Refresh()
	end)
	verifyButton:SetPoint("TOPLEFT", 12, -28 - 4 * (padHeight + padGap) - 4)

	local statsBox = UI.CreateBox(side, SIDE_WIDTH, 96)
	statsBox:SetPoint("TOPLEFT", numbersBox, "BOTTOMLEFT", 0, -8)
	UI.CreateBoxHeader(statsBox, L.sudokuStats)
	local wonValue = UI.CreateStatRow(statsBox, 1, L.gamesWon)
	local bestTimeValue = UI.CreateStatRow(statsBox, 2, L.bestTime)
	local hintsValue = UI.CreateStatRow(statsBox, 3, L.hintsUsed)
	hintsValue:SetTextColor(colors.gold[1], colors.gold[2], colors.gold[3])

	local function RefreshTime()
		timeValue:SetText(PTT.FormatDuration(math.floor(Sudoku.game.elapsed)))
	end

	local function SetColor(texture, color)
		texture:SetColorTexture(color[1], color[2], color[3], 1)
	end

	Refresh = function()
		local game = Sudoku.game
		local selectedValue = Sudoku.GetValue(selected)

		for index, cell in ipairs(cells) do
			local value = Sudoku.GetValue(index)
			local color = (Sudoku.GetBox(index) % 2 == 0) and COLORS.cellAlternate or COLORS.cell
			if index == selected then
				color = COLORS.selected
			elseif selectedValue ~= 0 and value == selectedValue then
				color = COLORS.sameDigit
			else
				for _, peer in ipairs(Sudoku.GetPeers(selected)) do
					if peer == index then
						color = COLORS.peer
						break
					end
				end
			end
			SetColor(cell.background, color)

			if value ~= 0 then
				local textColor = Sudoku.IsGiven(index) and TEXT_COLORS.given or (Sudoku.IsWrong(index) and TEXT_COLORS.wrong or TEXT_COLORS.entry)
				cell.label:SetTextColor(textColor[1], textColor[2], textColor[3])
				cell.label:SetText(value)
				cell.notes:SetText("")
			else
				cell.label:SetText("")
				cell.notes:SetText(FormatNotes(Sudoku.GetNotes(index)))
			end
		end

		mistakesValue:SetText(game.mistakes)
		RefreshTime()

		if game.state == "won" then
			subtitleLabel:SetText("|cffffd100" .. string.format(L.sudokuWon, PTT.FormatDuration(math.max(1, math.floor(game.elapsed)))) .. "|r")
		elseif message then
			subtitleLabel:SetText("|cffdd5555" .. message .. "|r")
		else
			subtitleLabel:SetText(L.sudokuSubtitle)
		end
		verifyButton:SetEnabled(game.state ~= "won" and Sudoku.IsComplete())

		for index, difficulty in ipairs(Sudoku.difficulties) do
			difficultyButtons[index]:SetText(Sudoku.GetName(difficulty))
			if difficulty.id == game.difficulty then
				difficultyButtons[index]:LockHighlight()
			else
				difficultyButtons[index]:UnlockHighlight()
			end
		end

		for digit, button in ipairs(digitButtons) do
			button:SetEnabled(Sudoku.CountDigit(digit) < 9)
		end
		if notesMode then
			notesButton:LockHighlight()
		else
			notesButton:UnlockHighlight()
		end

		local settings = PTT.database.sudoku
		wonValue:SetText(PTT.FormatNumber(settings.won))
		bestTimeValue:SetText(settings.bestTimes[game.difficulty] and PTT.FormatDuration(settings.bestTimes[game.difficulty]) or "-")
		hintsValue:SetText(game.hints)
	end

	-- The view's own OnUpdate belongs to the keyboard handling, so the clock runs on a child.
	local clock = CreateFrame("Frame", nil, view)
	clock:SetScript("OnUpdate", function(_, delta)
		Sudoku.Tick(delta)
		RefreshTime()
	end)

	UI.EnableHoverKeyboard(view, function(key)
		local digit = tonumber(key:match("^NUMPAD(%d)$") or key)
		if digit and digit >= 1 and digit <= 9 then
			PlaceDigit(digit)
		elseif key == "BACKSPACE" or key == "DELETE" then
			message = nil
			Sudoku.ClearCell(selected)
			Refresh()
		elseif key == "N" then
			notesMode = not notesMode
			Refresh()
		elseif NAVIGATION[key] then
			local target = selected + NAVIGATION[key]
			local sameRow = Sudoku.GetRow(target) == Sudoku.GetRow(selected)
			if target >= 1 and target <= 81 and (math.abs(NAVIGATION[key]) == 9 or sameRow) then
				selected = target
				Refresh()
			end
		else
			return false
		end
		return true
	end)

	view:HookScript("OnShow", Refresh)
	Refresh()
	return view
end

PTT.RegisterView({ id = "sudoku", label = "sudoku", build = BuildSudoku })
