local _, PTT = ...
local L = PTT.L
local UI = PTT.UI

---------------------------------------------------------------------------
-- Blockfall
---------------------------------------------------------------------------

local SIDE_WIDTH = 190
local CELL_INSET = 1
local PREVIEW_CELL_SIZE = 14
local GHOST_ALPHA = 0.22
-- Above this a lag spike would drop the piece several rows at once.
local MAX_FRAME_TIME = 0.25
-- Held keys repeat after a short delay, like a keyboard's own auto-repeat.
local REPEAT_DELAY = 0.17
local REPEAT_INTERVAL = 0.05

local EMPTY_COLOR = { 0.08, 0.08, 0.07 }
-- Class colors.
local PIECE_COLORS = {
	I = { 0.25, 0.78, 0.92 },
	O = { 1, 0.96, 0.41 },
	T = { 0.53, 0.53, 0.93 },
	S = { 0.67, 0.83, 0.45 },
	Z = { 0.77, 0.12, 0.23 },
	J = { 0, 0.44, 0.87 },
	L = { 1, 0.49, 0.04 },
}

local KEY_ACTIONS = {
	LEFT = "left", A = "left",
	RIGHT = "right", D = "right",
	DOWN = "down", S = "down",
	UP = "rotate", W = "rotate",
	SPACE = "drop",
	P = "pause",
}
local REPEATING_ACTIONS = { left = true, right = true, down = true }

local function BuildBlocks(parent)
	local Blocks = PTT.Blocks
	local colors = UI.gameColors
	local cellSize = Blocks.CELL_SIZE
	local fieldWidth, fieldHeight = Blocks.COLUMNS * cellSize, Blocks.ROWS * cellSize
	local view = CreateFrame("Frame", nil, parent)

	-- Header
	local titleLabel = UI.CreateLabel(view, "GameFontNormalHuge", L.blocks)
	titleLabel:SetPoint("TOPLEFT", 2, 0)
	titleLabel:SetTextColor(colors.gold[1], colors.gold[2], colors.gold[3])

	local subtitleLabel = UI.CreateLabel(view, "GameFontDisableSmall", L.blocksSubtitle)
	subtitleLabel:SetPoint("TOPLEFT", 2, -30)

	local Refresh
	local heldActions = {}
	local newGameButton = UI.CreateButton(view, L.newGame, 110, 50, function()
		local state = Blocks.game.state
		UI.ConfirmNewGame(function()
			Blocks.NewGame()
			heldActions = {}
			Refresh()
		end, state == "ready" or state == "lost")
	end)
	newGameButton:SetPoint("TOPRIGHT", 0, 0)

	local levelTile, levelValue = UI.CreateStatTile(view, 80, L.levelTitle)
	levelTile:SetPoint("RIGHT", newGameButton, "LEFT", -8, 0)
	levelValue:SetTextColor(colors.gold[1], colors.gold[2], colors.gold[3])
	local linesTile, linesValue = UI.CreateStatTile(view, 80, L.linesTitle)
	linesTile:SetPoint("RIGHT", levelTile, "LEFT", -8, 0)
	linesValue:SetTextColor(1, 1, 1)
	local scoreTile, scoreValue = UI.CreateStatTile(view, 90, L.scoreTitle)
	scoreTile:SetPoint("RIGHT", linesTile, "LEFT", -8, 0)
	scoreValue:SetTextColor(1, 1, 1)

	-- Side column
	local side = CreateFrame("Frame", nil, view)
	side:SetSize(SIDE_WIDTH, fieldHeight + 4)
	side:SetPoint("TOPRIGHT", 0, -62)

	-- Field, centered in the space left of the side column
	local area = CreateFrame("Frame", nil, view)
	area:SetPoint("TOPLEFT", 0, -62)
	area:SetPoint("BOTTOMRIGHT", side, "BOTTOMLEFT", -8, 0)

	local frame = UI.CreatePanel(area)
	frame:SetSize(fieldWidth + 4, fieldHeight + 4)
	frame:SetPoint("TOP", 0, 0)
	frame:SetBackdropColor(0.04, 0.05, 0.04, 0.95)
	frame:SetBackdropBorderColor(0.3, 0.24, 0.15, 1)

	local field = CreateFrame("Frame", nil, frame)
	field:SetSize(fieldWidth, fieldHeight)
	field:SetPoint("TOPLEFT", 2, -2)

	local cellTextures = {}
	for y = 1, Blocks.ROWS do
		cellTextures[y] = {}
		for x = 1, Blocks.COLUMNS do
			local texture = field:CreateTexture(nil, "ARTWORK")
			texture:SetSize(cellSize - 2 * CELL_INSET, cellSize - 2 * CELL_INSET)
			texture:SetPoint("TOPLEFT", field, "TOPLEFT", (x - 1) * cellSize + CELL_INSET, -((y - 1) * cellSize + CELL_INSET))
			cellTextures[y][x] = texture
		end
	end

	local messageFrame = CreateFrame("Frame", nil, field)
	messageFrame:SetSize(fieldWidth, 56)
	messageFrame:SetPoint("CENTER", 0, 0)
	messageFrame:SetFrameLevel(field:GetFrameLevel() + 5)
	local messageBackground = messageFrame:CreateTexture(nil, "BACKGROUND")
	messageBackground:SetAllPoints()
	messageBackground:SetColorTexture(0, 0, 0, 0.75)
	local messageLabel = UI.CreateLabel(messageFrame, "GameFontNormal")
	messageLabel:SetPoint("CENTER", 0, 0)
	messageLabel:SetWidth(fieldWidth - 12)
	messageLabel:SetWordWrap(true)

	local nextBox = UI.CreateBox(side, SIDE_WIDTH, 80)
	nextBox:SetPoint("TOPLEFT", 0, 0)
	UI.CreateBoxHeader(nextBox, L.nextTitle)
	local preview = CreateFrame("Frame", nil, nextBox)
	preview:SetSize(4 * PREVIEW_CELL_SIZE, 2 * PREVIEW_CELL_SIZE)
	preview:SetPoint("TOP", 0, -32)
	local previewTextures = {}
	for index = 1, 4 do
		local texture = preview:CreateTexture(nil, "ARTWORK")
		texture:SetSize(PREVIEW_CELL_SIZE - 2 * CELL_INSET, PREVIEW_CELL_SIZE - 2 * CELL_INSET)
		previewTextures[index] = texture
	end

	local statsBox = UI.CreateBox(side, SIDE_WIDTH, 96)
	statsBox:SetPoint("TOPLEFT", nextBox, "BOTTOMLEFT", 0, -8)
	UI.CreateBoxHeader(statsBox, L.blocksStats)
	local highScoreValue = UI.CreateStatRow(statsBox, 1, L.highScore)
	highScoreValue:SetTextColor(colors.gold[1], colors.gold[2], colors.gold[3])
	local mostLinesValue = UI.CreateStatRow(statsBox, 2, L.mostLines)
	local playedValue = UI.CreateStatRow(statsBox, 3, L.gamesPlayed)

	local controlLines = { L.blocksControlMove, L.blocksControlRotate, L.blocksControlSoftDrop, L.blocksControlHardDrop, L.blocksControlPause }
	local controlsBox = UI.CreateBox(side, SIDE_WIDTH, 38 + #controlLines * 14)
	controlsBox:SetPoint("TOPLEFT", statsBox, "BOTTOMLEFT", 0, -8)
	UI.CreateBoxHeader(controlsBox, L.controls)
	for index, text in ipairs(controlLines) do
		local line = UI.CreateLabel(controlsBox, "GameFontHighlightSmall", text)
		line:SetPoint("TOPLEFT", 12, -28 - (index - 1) * 14)
		line:SetWidth(SIDE_WIDTH - 24)
		line:SetJustifyH("LEFT")
		line:SetWordWrap(false)
		line:SetTextColor(colors.text[1], colors.text[2], colors.text[3])
	end

	-- Drawing
	local function SetCell(x, y, color, alpha)
		if y >= 1 then
			cellTextures[y][x]:SetColorTexture(color[1], color[2], color[3], alpha)
		end
	end

	local function DrawField(game)
		for y = 1, Blocks.ROWS do
			local row = game.board[y]
			for x = 1, Blocks.COLUMNS do
				local kind = row[x]
				SetCell(x, y, kind and PIECE_COLORS[kind] or EMPTY_COLOR, 1)
			end
		end

		if game.state == "lost" then
			return
		end
		local piece = game.piece
		local color = PIECE_COLORS[piece.kind]
		for _, cell in ipairs(Blocks.GetCells(piece.kind, piece.rotation, piece.x, Blocks.GetDropY())) do
			SetCell(cell.x, cell.y, color, GHOST_ALPHA)
		end
		for _, cell in ipairs(Blocks.GetPieceCells(piece)) do
			SetCell(cell.x, cell.y, color, 1)
		end
	end

	local function DrawPreview(kind)
		local cells = Blocks.GetCells(kind, 0, 0, 0)
		local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
		for _, cell in ipairs(cells) do
			minX, maxX = math.min(minX, cell.x), math.max(maxX, cell.x)
			minY, maxY = math.min(minY, cell.y), math.max(maxY, cell.y)
		end
		local offsetX = (4 - (maxX - minX + 1)) / 2 * PREVIEW_CELL_SIZE
		local offsetY = (2 - (maxY - minY + 1)) / 2 * PREVIEW_CELL_SIZE
		local color = PIECE_COLORS[kind]
		for index, cell in ipairs(cells) do
			local texture = previewTextures[index]
			texture:ClearAllPoints()
			texture:SetPoint("TOPLEFT", preview, "TOPLEFT",
				offsetX + (cell.x - minX) * PREVIEW_CELL_SIZE + CELL_INSET,
				-(offsetY + (cell.y - minY) * PREVIEW_CELL_SIZE + CELL_INSET))
			texture:SetColorTexture(color[1], color[2], color[3], 1)
		end
	end

	-- Sounds come from comparing with the last drawn state, so key input and gravity share one place.
	local last = {}
	local hardDropped = false
	local function PlaySounds(game)
		if last.game == game then
			if game.state == "lost" and last.state ~= "lost" then
				UI.PlayGameSound("blockLost")
			elseif game.level > last.level then
				UI.PlayGameSound("blockLevel")
			elseif game.lines > last.lines then
				UI.PlayGameSound(game.lines - last.lines >= 4 and "blockQuad" or "blockLine")
			elseif game.piece ~= last.piece then
				UI.PlayGameSound(hardDropped and "blockDrop" or "blockLock")
			elseif game.piece.rotation ~= last.rotation then
				UI.PlayGameSound("blockRotate")
			end
		end
		hardDropped = false
		last.game, last.state, last.level, last.lines = game, game.state, game.level, game.lines
		last.piece, last.rotation = game.piece, game.piece.rotation
	end

	Refresh = function()
		local game = Blocks.game
		local settings = PTT.database.blocks
		PlaySounds(game)

		DrawField(game)
		DrawPreview(game.next)

		scoreValue:SetText(PTT.FormatNumber(game.score))
		linesValue:SetText(game.lines)
		levelValue:SetText(game.level)
		highScoreValue:SetText(PTT.FormatNumber(settings.highScore))
		mostLinesValue:SetText(PTT.FormatNumber(settings.mostLines))
		playedValue:SetText(PTT.FormatNumber(settings.played))

		local message
		if game.state == "ready" then
			message = L.blocksStart
		elseif game.state == "paused" then
			message = L.blocksPaused
		elseif game.state == "lost" then
			message = "|cffdd5555" .. L.blocksLost .. "|r"
		end
		messageLabel:SetText(message or "")
		messageFrame:SetShown(message ~= nil)
	end

	field:SetScript("OnUpdate", function(_, delta)
		-- Keys only reach the game while the mouse is over the view and out of combat.
		if not UI.IsMouseOver(view) or InCombatLockdown() then
			-- Key-up events are lost once the keyboard is released.
			if next(heldActions) then
				heldActions = {}
			end
			if Blocks.Pause() then
				Refresh()
			end
			return
		end

		delta = math.min(delta, MAX_FRAME_TIME)
		local changed = false
		if Blocks.game.state == "playing" then
			for action, timer in pairs(heldActions) do
				timer = timer + delta
				while timer >= REPEAT_INTERVAL and Blocks.game.state == "playing" do
					timer = timer - REPEAT_INTERVAL
					changed = Blocks.Input(action) or changed
				end
				heldActions[action] = timer
			end
		end
		if Blocks.Update(delta) or changed then
			Refresh()
		end
	end)

	UI.EnableHoverKeyboard(view, function(key)
		local action = KEY_ACTIONS[key]
		if not action then
			return false
		end
		-- The client may resend a held key; the repeat timer handles that.
		if heldActions[action] then
			return true
		end
		if REPEATING_ACTIONS[action] then
			heldActions[action] = -REPEAT_DELAY
		end
		if Blocks.Input(action) then
			hardDropped = action == "drop"
			Refresh()
		end
		return true
	end)

	view:SetScript("OnKeyUp", function(_, key)
		local action = KEY_ACTIONS[key]
		if action then
			heldActions[action] = nil
		end
	end)

	view:HookScript("OnHide", function()
		Blocks.Pause()
		heldActions = {}
	end)
	view:HookScript("OnShow", Refresh)
	Refresh()
	return view
end

PTT.RegisterView({ id = "blocks", label = "blocks", build = BuildBlocks })
