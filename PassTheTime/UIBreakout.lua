local _, PTT = ...
local L = PTT.L
local UI = PTT.UI

---------------------------------------------------------------------------
-- Breakout
---------------------------------------------------------------------------

local SIDE_WIDTH, SIDE_GAP = 190, 14
local MAX_BRICKS, MAX_ITEMS = 60, 8
local KEY_STEP = 24
local MAX_FRAME_TIME = 0.05

local BALL_ICON = "Interface\\Icons\\Spell_Fire_FlameBolt"
local ITEM_ICONS = {
	shield = "Interface\\Icons\\Spell_Holy_PowerWordShield",
	rage = "Interface\\Icons\\Spell_Nature_Bloodlust",
	multi = "Interface\\Icons\\Ability_UpgradeMoonGlaive",
	wide = "Interface\\Icons\\Spell_Magic_GreaterBlessingofKings",
}
local ITEM_LABELS = { shield = "itemShield", rage = "itemRage", multi = "itemMulti", wide = "itemWide" }

local function BuildBreakout(parent)
	local Breakout = PTT.Breakout
	local colors = UI.gameColors
	local view = CreateFrame("Frame", nil, parent)

	-- Header
	local titleLabel = UI.CreateLabel(view, "GameFontNormalHuge", L.breakout)
	titleLabel:SetPoint("TOPLEFT", 2, 0)
	titleLabel:SetTextColor(colors.gold[1], colors.gold[2], colors.gold[3])

	local subtitleLabel = UI.CreateLabel(view, "GameFontDisableSmall")
	subtitleLabel:SetPoint("TOPLEFT", 2, -30)

	local Refresh
	local newGameButton = UI.CreateButton(view, L.newGame, 110, 50, function()
		UI.ConfirmNewGame(function()
			Breakout.NewGame()
			Refresh()
		end, Breakout.game.state == "won" or Breakout.game.state == "lost")
	end)
	newGameButton:SetPoint("TOPRIGHT", 0, 0)

	local livesTile, livesValue = UI.CreateStatTile(view, 90, L.livesTitle)
	livesTile:SetPoint("RIGHT", newGameButton, "LEFT", -8, 0)
	livesValue:SetTextColor(colors.gold[1], colors.gold[2], colors.gold[3])
	local scoreTile, scoreValue = UI.CreateStatTile(view, 90, L.scoreTitle)
	scoreTile:SetPoint("RIGHT", livesTile, "LEFT", -8, 0)
	scoreValue:SetTextColor(1, 1, 1)

	-- Arena
	local frame = UI.CreatePanel(view)
	frame:SetSize(Breakout.FIELD_WIDTH + 4, Breakout.FIELD_HEIGHT + 4)
	frame:SetPoint("TOPLEFT", 0, -62)
	frame:SetBackdropColor(0.05, 0.04, 0.04, 0.95)
	frame:SetBackdropBorderColor(0.3, 0.24, 0.15, 1)

	local arena = CreateFrame("Frame", nil, frame)
	arena:SetSize(Breakout.FIELD_WIDTH, Breakout.FIELD_HEIGHT)
	arena:SetPoint("TOPLEFT", 2, -2)
	arena:EnableMouse(true)

	local brickTextures = {}
	for index = 1, MAX_BRICKS do
		brickTextures[index] = arena:CreateTexture(nil, "ARTWORK")
	end

	local bossLabel = arena:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	bossLabel:SetTextColor(0.1, 0.07, 0.02)

	local paddle = arena:CreateTexture(nil, "ARTWORK")
	paddle:SetColorTexture(0.75, 0.62, 0.3, 1)

	local ballSize = 2 * Breakout.BALL_RADIUS + 6
	local ballTextures = {}
	for index = 1, Breakout.MAX_BALLS do
		local texture = arena:CreateTexture(nil, "OVERLAY")
		texture:SetSize(ballSize, ballSize)
		texture:SetTexture(BALL_ICON)
		ballTextures[index] = texture
	end

	local itemTextures = {}
	for index = 1, MAX_ITEMS do
		local texture = arena:CreateTexture(nil, "OVERLAY")
		texture:SetSize(Breakout.ITEM_SIZE, Breakout.ITEM_SIZE)
		itemTextures[index] = texture
	end

	local messageLabel = UI.CreateLabel(arena, "GameFontNormalLarge")
	messageLabel:SetPoint("CENTER", 0, -40)

	-- Side column
	local side = CreateFrame("Frame", nil, view)
	side:SetSize(SIDE_WIDTH, 340)
	side:SetPoint("TOPRIGHT", 0, -62)

	local encounterBox = UI.CreateBox(side, SIDE_WIDTH, 96)
	encounterBox:SetPoint("TOPLEFT", 0, 0)
	UI.CreateBoxHeader(encounterBox, L.encounterTitle)
	local raidValue = UI.CreateStatRow(encounterBox, 1, L.raid)
	local bossValue = UI.CreateStatRow(encounterBox, 2, L.boss)
	bossValue:SetTextColor(colors.gold[1], colors.gold[2], colors.gold[3])
	local bricksValue = UI.CreateStatRow(encounterBox, 3, L.bricksLeft)

	local statsBox = UI.CreateBox(side, SIDE_WIDTH, 96)
	statsBox:SetPoint("TOPLEFT", encounterBox, "BOTTOMLEFT", 0, -8)
	UI.CreateBoxHeader(statsBox, L.breakoutStats)
	local highScoreValue = UI.CreateStatRow(statsBox, 1, L.highScore)
	highScoreValue:SetTextColor(colors.gold[1], colors.gold[2], colors.gold[3])
	local bestRaidValue = UI.CreateStatRow(statsBox, 2, L.bestRaid)
	local bossesValue = UI.CreateStatRow(statsBox, 3, L.bossesDefeated)

	local controlsBox = UI.CreateBox(side, SIDE_WIDTH, 148)
	controlsBox:SetPoint("TOPLEFT", statsBox, "BOTTOMLEFT", 0, -8)
	UI.CreateBoxHeader(controlsBox, L.controls)
	for index, text in ipairs({ L.breakoutControlMouse, L.breakoutControlLaunch, L.breakoutControlKeys }) do
		local line = UI.CreateLabel(controlsBox, "GameFontHighlightSmall", text)
		line:SetPoint("TOPLEFT", 12, -28 - (index - 1) * 14)
		line:SetWidth(SIDE_WIDTH - 24)
		line:SetJustifyH("LEFT")
		line:SetWordWrap(false)
		line:SetTextColor(colors.text[1], colors.text[2], colors.text[3])
	end
	for index, kind in ipairs(Breakout.ITEM_KINDS) do
		local icon = controlsBox:CreateTexture(nil, "ARTWORK")
		icon:SetSize(14, 14)
		icon:SetPoint("TOPLEFT", 12, -78 - (index - 1) * 17)
		icon:SetTexture(ITEM_ICONS[kind])
		local line = UI.CreateLabel(controlsBox, "GameFontHighlightSmall", L[ITEM_LABELS[kind]])
		line:SetPoint("LEFT", icon, "RIGHT", 6, 0)
		line:SetWidth(SIDE_WIDTH - 12 - 14 - 6 - 8)
		line:SetJustifyH("LEFT")
		line:SetWordWrap(false)
		line:SetTextColor(colors.text[1], colors.text[2], colors.text[3])
	end

	-- Drawing
	local shownLevel
	local function DrawBricks(game)
		local level = Breakout.levels[game.level]
		local bossShown = false

		for index, texture in ipairs(brickTextures) do
			local brick = game.bricks[index]
			if brick and brick.health > 0 then
				if texture.brick ~= brick then
					texture.brick = brick
					texture:ClearAllPoints()
					texture:SetPoint("TOPLEFT", arena, "TOPLEFT", brick.x, -brick.y)
					texture:SetSize(brick.width, brick.height)
				end

				local shade = 0.55 + 0.45 * brick.health / brick.maxHealth
				local color = brick.boss and { 0.92, 0.76, 0.2 } or level.color
				texture:SetColorTexture(color[1] * shade, color[2] * shade, color[3] * shade, 1)
				texture:Show()

				if brick.boss then
					bossShown = true
					if shownLevel ~= game.level then
						shownLevel = game.level
						bossLabel:ClearAllPoints()
						bossLabel:SetPoint("CENTER", arena, "TOPLEFT", brick.x + brick.width / 2, -(brick.y + brick.height / 2))
						bossLabel:SetText(Breakout.GetBossName(level))
					end
				end
			else
				texture.brick = nil
				texture:Hide()
			end
		end
		bossLabel:SetShown(bossShown)
	end

	local function DrawMovers(game)
		local paddleWidth = Breakout.GetPaddleWidth()
		paddle:SetSize(paddleWidth, Breakout.PADDLE_HEIGHT)
		paddle:ClearAllPoints()
		paddle:SetPoint("TOPLEFT", arena, "TOPLEFT", game.paddleX - paddleWidth / 2, -Breakout.PADDLE_TOP)

		for index, texture in ipairs(ballTextures) do
			local ball = game.balls[index]
			if ball then
				texture:ClearAllPoints()
				texture:SetPoint("TOPLEFT", arena, "TOPLEFT", ball.x - ballSize / 2, -(ball.y - ballSize / 2))
				texture:Show()
			else
				texture:Hide()
			end
		end

		for index, texture in ipairs(itemTextures) do
			local item = game.items[index]
			if item then
				texture:ClearAllPoints()
				texture:SetPoint("TOPLEFT", arena, "TOPLEFT", item.x - Breakout.ITEM_SIZE / 2, -(item.y - Breakout.ITEM_SIZE / 2))
				texture:SetTexture(ITEM_ICONS[item.kind])
				texture:Show()
			else
				texture:Hide()
			end
		end
	end

	Refresh = function()
		local game = Breakout.game
		local level = Breakout.levels[game.level]
		local settings = PTT.database.breakout

		DrawBricks(game)
		DrawMovers(game)

		scoreValue:SetText(PTT.FormatNumber(game.score))
		livesValue:SetText(game.lives)
		raidValue:SetText(Breakout.GetName(level))
		bossValue:SetText(Breakout.GetBossName(level))
		bricksValue:SetText(game.aliveBricks)
		highScoreValue:SetText(PTT.FormatNumber(settings.highScore))
		bestRaidValue:SetText(string.format("%d / %d", settings.bestLevel, #Breakout.levels))
		bossesValue:SetText(PTT.FormatNumber(settings.bossesKilled))

		local effects = {}
		if #game.rageTimers > 0 then
			effects[#effects + 1] = string.format(L.rageActive, #game.rageTimers, math.ceil(Breakout.GetLongestTimer(game.rageTimers)))
		end
		if #game.wideTimers > 0 then
			effects[#effects + 1] = string.format(L.wideActive, #game.wideTimers, math.ceil(Breakout.GetLongestTimer(game.wideTimers)))
		end

		if #effects > 0 then
			subtitleLabel:SetText("|cffffd100" .. table.concat(effects, "   ") .. "|r")
		else
			subtitleLabel:SetText(string.format(L.breakoutRaid, game.level, #Breakout.levels, Breakout.GetName(level)))
		end

		if game.state == "ready" then
			messageLabel:SetText(L.breakoutLaunch)
		elseif game.state == "lost" then
			messageLabel:SetText("|cffdd5555" .. L.breakoutLost .. "|r")
		elseif game.state == "won" then
			messageLabel:SetText("|cffffd100" .. L.breakoutWon .. "|r")
		else
			messageLabel:SetText("")
		end
	end

	local function FollowMouse()
		if not UI.IsMouseOver(arena) then
			return
		end
		local left = arena:GetLeft()
		if left then
			local cursorX = GetCursorPosition()
			Breakout.MovePaddle(cursorX / arena:GetEffectiveScale() - left)
		end
	end

	arena:SetScript("OnUpdate", function(_, delta)
		FollowMouse()
		Breakout.Update(math.min(delta, MAX_FRAME_TIME))
		Refresh()
	end)

	arena:SetScript("OnMouseDown", function()
		Breakout.Launch()
	end)

	UI.EnableHoverKeyboard(view, function(key)
		local game = Breakout.game
		if key == "LEFT" or key == "A" then
			Breakout.MovePaddle(game.paddleX - KEY_STEP)
		elseif key == "RIGHT" or key == "D" then
			Breakout.MovePaddle(game.paddleX + KEY_STEP)
		elseif key == "SPACE" then
			Breakout.Launch()
		else
			return false
		end
		return true
	end)

	view:HookScript("OnShow", function()
		shownLevel = nil
		Refresh()
	end)
	Refresh()
	return view
end

PTT.RegisterView({ id = "breakout", label = "breakout", build = BuildBreakout })
