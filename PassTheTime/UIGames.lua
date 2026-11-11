local _, PTT = ...
local L = PTT.L
local UI = PTT.UI

---------------------------------------------------------------------------
-- 2048
---------------------------------------------------------------------------

local LABEL_COLOR = { 0.7, 0.55, 0.35 }
local TEXT_COLOR = { 0.78, 0.74, 0.68 }
local GOLD = { 1, 0.82, 0 }

-- Dark boxes shared by the 2048 and Hangman pages.
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

local SOUND_PATH = "Interface\\AddOns\\PassTheTime\\Sounds\\"

-- Plays Sounds\<name>.ogg on the effects channel, unless mini game sounds are off.
function UI.PlayGameSound(name)
	if PTT.database.settings.gameSounds and PlaySoundFile then
		PlaySoundFile(SOUND_PATH .. name .. ".ogg", "SFX")
	end
end

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
		UI.ConfirmNewGame(function()
			Game.Reset()
			Refresh()
		end, Game.over)
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

local function SetColor(texture, color)
	texture:SetColorTexture(color[1], color[2], color[3], 1)
end

local function CreateDropdown(parent, name, width)
	local dropdown = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
	UIDropDownMenu_SetWidth(dropdown, width)
	return dropdown
end

UI.SetColor, UI.CreateDropdown = SetColor, CreateDropdown
