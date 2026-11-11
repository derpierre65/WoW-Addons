local _, PTT = ...
local L = PTT.L
local UI = PTT.UI

---------------------------------------------------------------------------
-- Snake
---------------------------------------------------------------------------

local SIDE_WIDTH = 190
local SEGMENT_INSET = 1
-- Above this a lag spike would skip several cells at once.
local MAX_FRAME_TIME = 0.25

local FOOD_ICON = "Interface\\Icons\\INV_Misc_Food_19"
local HEAD_COLOR = { 0.62, 0.9, 0.35 }
local BODY_COLOR = { 0.3, 0.65, 0.22 }
local TAIL_COLOR = { 0.14, 0.38, 0.12 }

local DIRECTION_KEYS = {
	UP = "up", W = "up",
	DOWN = "down", S = "down",
	LEFT = "left", A = "left",
	RIGHT = "right", D = "right",
}

local function BuildSnake(parent)
	local Snake = PTT.Snake
	local colors = UI.gameColors
	local cellSize = Snake.CELL_SIZE
	local fieldWidth, fieldHeight = Snake.COLUMNS * cellSize, Snake.ROWS * cellSize
	local view = CreateFrame("Frame", nil, parent)

	-- Header
	local titleLabel = UI.CreateLabel(view, "GameFontNormalHuge", L.snake)
	titleLabel:SetPoint("TOPLEFT", 2, 0)
	titleLabel:SetTextColor(colors.gold[1], colors.gold[2], colors.gold[3])

	local subtitleLabel = UI.CreateLabel(view, "GameFontDisableSmall", L.snakeSubtitle)
	subtitleLabel:SetPoint("TOPLEFT", 2, -30)

	local Refresh
	local newGameButton = UI.CreateButton(view, L.newGame, 110, 50, function()
		local state = Snake.game.state
		UI.ConfirmNewGame(function()
			Snake.NewGame()
			Refresh()
		end, state == "ready" or state == "won" or state == "lost")
	end)
	newGameButton:SetPoint("TOPRIGHT", 0, 0)

	local lengthTile, lengthValue = UI.CreateStatTile(view, 90, L.lengthTitle)
	lengthTile:SetPoint("RIGHT", newGameButton, "LEFT", -8, 0)
	lengthValue:SetTextColor(colors.gold[1], colors.gold[2], colors.gold[3])
	local scoreTile, scoreValue = UI.CreateStatTile(view, 90, L.scoreTitle)
	scoreTile:SetPoint("RIGHT", lengthTile, "LEFT", -8, 0)
	scoreValue:SetTextColor(1, 1, 1)

	-- Field
	local frame = UI.CreatePanel(view)
	frame:SetSize(fieldWidth + 4, fieldHeight + 4)
	frame:SetPoint("TOPLEFT", 0, -62)
	frame:SetBackdropColor(0.04, 0.05, 0.04, 0.95)
	frame:SetBackdropBorderColor(0.3, 0.24, 0.15, 1)

	local field = CreateFrame("Frame", nil, frame)
	field:SetSize(fieldWidth, fieldHeight)
	field:SetPoint("TOPLEFT", 2, -2)

	local food = field:CreateTexture(nil, "ARTWORK")
	food:SetSize(cellSize, cellSize)
	food:SetTexture(FOOD_ICON)
	food:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	-- Created on demand, the snake can grow to fill the whole field.
	local segmentTextures = {}
	local function GetSegmentTexture(index)
		local texture = segmentTextures[index]
		if not texture then
			texture = field:CreateTexture(nil, "ARTWORK")
			texture:SetSize(cellSize - 2 * SEGMENT_INSET, cellSize - 2 * SEGMENT_INSET)
			segmentTextures[index] = texture
		end
		return texture
	end

	local messageLabel = UI.CreateLabel(field, "GameFontNormalLarge")
	messageLabel:SetPoint("CENTER", 0, -40)

	-- Side column
	local side = CreateFrame("Frame", nil, view)
	side:SetSize(SIDE_WIDTH, fieldHeight)
	side:SetPoint("TOPRIGHT", 0, -62)

	local statsBox = UI.CreateBox(side, SIDE_WIDTH, 96)
	statsBox:SetPoint("TOPLEFT", 0, 0)
	UI.CreateBoxHeader(statsBox, L.snakeStats)
	local highScoreValue = UI.CreateStatRow(statsBox, 1, L.highScore)
	highScoreValue:SetTextColor(colors.gold[1], colors.gold[2], colors.gold[3])
	local longestValue = UI.CreateStatRow(statsBox, 2, L.longestSnake)
	local playedValue = UI.CreateStatRow(statsBox, 3, L.gamesPlayed)

	local controlsBox = UI.CreateBox(side, SIDE_WIDTH, 96)
	controlsBox:SetPoint("TOPLEFT", statsBox, "BOTTOMLEFT", 0, -8)
	UI.CreateBoxHeader(controlsBox, L.controls)
	for index, text in ipairs({ L.snakeControlKeys, L.snakeControlPause, L.snakeControlFood }) do
		local line = UI.CreateLabel(controlsBox, "GameFontHighlightSmall", text)
		line:SetPoint("TOPLEFT", 12, -28 - (index - 1) * 14)
		line:SetWidth(SIDE_WIDTH - 24)
		line:SetJustifyH("LEFT")
		line:SetWordWrap(false)
		line:SetTextColor(colors.text[1], colors.text[2], colors.text[3])
	end

	-- Drawing
	local function PlaceCell(texture, x, y, inset)
		texture:ClearAllPoints()
		texture:SetPoint("TOPLEFT", field, "TOPLEFT", (x - 1) * cellSize + inset, -((y - 1) * cellSize + inset))
	end

	local function DrawSnake(game)
		local count = #game.segments
		for index, segment in ipairs(game.segments) do
			local texture = GetSegmentTexture(index)
			PlaceCell(texture, segment.x, segment.y, SEGMENT_INSET)
			if index == 1 then
				texture:SetColorTexture(HEAD_COLOR[1], HEAD_COLOR[2], HEAD_COLOR[3], 1)
			else
				local fade = count > 2 and (index - 2) / (count - 2) or 0
				texture:SetColorTexture(
					BODY_COLOR[1] + (TAIL_COLOR[1] - BODY_COLOR[1]) * fade,
					BODY_COLOR[2] + (TAIL_COLOR[2] - BODY_COLOR[2]) * fade,
					BODY_COLOR[3] + (TAIL_COLOR[3] - BODY_COLOR[3]) * fade,
					1
				)
			end
			texture:Show()
		end
		for index = count + 1, #segmentTextures do
			segmentTextures[index]:Hide()
		end

		if game.food then
			PlaceCell(food, game.food.x, game.food.y, 0)
			food:Show()
		else
			food:Hide()
		end
	end

	local lastGame, lastState, lastEaten
	local function PlaySounds(game)
		if lastGame == game then
			if game.state == "lost" and lastState ~= "lost" then
				UI.PlayGameSound("snakeCrash")
			elseif game.state == "won" and lastState ~= "won" then
				UI.PlayGameSound("snakeWin")
			elseif game.eaten > lastEaten then
				UI.PlayGameSound("snakeEat")
			end
		end
		lastGame, lastState, lastEaten = game, game.state, game.eaten
	end

	Refresh = function()
		local game = Snake.game
		local settings = PTT.database.snake
		PlaySounds(game)

		DrawSnake(game)

		scoreValue:SetText(PTT.FormatNumber(game.score))
		lengthValue:SetText(#game.segments)
		highScoreValue:SetText(PTT.FormatNumber(settings.highScore))
		longestValue:SetText(PTT.FormatNumber(settings.longest))
		playedValue:SetText(PTT.FormatNumber(settings.played))

		if game.state == "ready" then
			messageLabel:SetText(L.snakeStart)
		elseif game.state == "paused" then
			messageLabel:SetText(L.snakePaused)
		elseif game.state == "lost" then
			messageLabel:SetText("|cffdd5555" .. L.snakeLost .. "|r")
		elseif game.state == "won" then
			messageLabel:SetText("|cffffd100" .. L.snakeWon .. "|r")
		else
			messageLabel:SetText("")
		end
	end

	field:SetScript("OnUpdate", function(_, delta)
		-- Keys only reach the game while the mouse is over the view and out of combat.
		if Snake.game.state == "playing" and (not UI.IsMouseOver(view) or InCombatLockdown()) then
			Snake.Pause()
			Refresh()
			return
		end
		if Snake.Update(math.min(delta, MAX_FRAME_TIME)) then
			Refresh()
		end
	end)

	UI.EnableHoverKeyboard(view, function(key)
		local direction = DIRECTION_KEYS[key]
		if direction then
			Snake.Steer(direction)
		elseif key == "SPACE" then
			Snake.TogglePause()
		else
			return false
		end
		Refresh()
		return true
	end)

	view:HookScript("OnHide", function()
		Snake.Pause()
	end)
	view:HookScript("OnShow", Refresh)
	Refresh()
	return view
end

PTT.RegisterView({ id = "snake", label = "snake", build = BuildSnake })
