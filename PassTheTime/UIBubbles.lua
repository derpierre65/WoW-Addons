local _, PTT = ...
local L = PTT.L
local UI = PTT.UI

---------------------------------------------------------------------------
-- Spell Orbs
---------------------------------------------------------------------------

local SIDE_WIDTH = 190
-- White disc with soft alpha edges; tinted per orb.
local CIRCLE_TEXTURE = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local NEXT_SCALE = 0.7
local GUIDE_DOTS = 14
local GUIDE_SPACING = 16
local GUIDE_DOT_SIZE = 4
local KEY_AIM_SPEED = math.rad(90)
-- Above this a lag spike would move the shot through several bubbles.
local MAX_FRAME_TIME = 0.1

-- Schools of magic: fire, frost, nature, holy, shadow, arcane.
local ORB_COLORS = {
	{ 0.95, 0.32, 0.15 },
	{ 0.3, 0.65, 1 },
	{ 0.35, 0.85, 0.3 },
	{ 1, 0.85, 0.25 },
	{ 0.6, 0.3, 0.88 },
	{ 1, 0.5, 0.85 },
}

local AIM_KEYS = { LEFT = -1, A = -1, RIGHT = 1, D = 1 }
local SHOOT_KEYS = { SPACE = true, UP = true, W = true }
local SWAP_KEYS = { DOWN = true, S = true }

local atan2 = math.atan2 or math.atan

local function CreateOrb(parent, size)
	local orb = {}
	orb.border = parent:CreateTexture(nil, "ARTWORK", nil, 1)
	orb.border:SetTexture(CIRCLE_TEXTURE)
	orb.border:SetVertexColor(0, 0, 0, 0.85)
	orb.body = parent:CreateTexture(nil, "ARTWORK", nil, 2)
	orb.body:SetTexture(CIRCLE_TEXTURE)
	orb.shine = parent:CreateTexture(nil, "ARTWORK", nil, 3)
	orb.shine:SetTexture(CIRCLE_TEXTURE)
	orb.shine:SetVertexColor(1, 1, 1, 0.45)

	function orb:SetSize(diameter)
		self.diameter = diameter
		self.border:SetSize(diameter, diameter)
		self.body:SetSize(diameter - 2, diameter - 2)
		self.shine:SetSize(diameter * 0.3, diameter * 0.3)
	end

	function orb:Place(x, y)
		self.border:ClearAllPoints()
		self.body:ClearAllPoints()
		self.shine:ClearAllPoints()
		self.border:SetPoint("CENTER", parent, "TOPLEFT", x, -y)
		self.body:SetPoint("CENTER", parent, "TOPLEFT", x, -y)
		self.shine:SetPoint("CENTER", parent, "TOPLEFT", x - self.diameter * 0.18, -(y - self.diameter * 0.18))
	end

	function orb:SetColor(color)
		local values = ORB_COLORS[color]
		self.body:SetVertexColor(values[1], values[2], values[3], 1)
	end

	function orb:SetShown(shown)
		self.border:SetShown(shown)
		self.body:SetShown(shown)
		self.shine:SetShown(shown)
	end

	orb:SetSize(size)
	return orb
end

local function BuildBubbles(parent)
	local Bubbles = PTT.Bubbles
	local colors = UI.gameColors
	local diameter = 2 * Bubbles.RADIUS
	local view = CreateFrame("Frame", nil, parent)

	-- Header
	local titleLabel = UI.CreateLabel(view, "GameFontNormalHuge", L.bubbles)
	titleLabel:SetPoint("TOPLEFT", 2, 0)
	titleLabel:SetTextColor(colors.gold[1], colors.gold[2], colors.gold[3])

	local subtitleLabel = UI.CreateLabel(view, "GameFontDisableSmall", L.bubblesSubtitle)
	subtitleLabel:SetPoint("TOPLEFT", 2, -30)

	local Refresh
	local aimDirection = 0
	local newGameButton = UI.CreateButton(view, L.newGame, 110, 50, function()
		local state = Bubbles.game.state
		UI.ConfirmNewGame(function()
			Bubbles.NewGame()
			Refresh()
		end, state == "ready" or state == "lost")
	end)
	newGameButton:SetPoint("TOPRIGHT", 0, 0)

	local levelTile, levelValue = UI.CreateStatTile(view, 80, L.levelTitle)
	levelTile:SetPoint("RIGHT", newGameButton, "LEFT", -8, 0)
	levelValue:SetTextColor(colors.gold[1], colors.gold[2], colors.gold[3])
	local scoreTile, scoreValue = UI.CreateStatTile(view, 90, L.scoreTitle)
	scoreTile:SetPoint("RIGHT", levelTile, "LEFT", -8, 0)
	scoreValue:SetTextColor(1, 1, 1)

	-- Side column
	local side = CreateFrame("Frame", nil, view)
	side:SetSize(SIDE_WIDTH, Bubbles.HEIGHT + 4)
	side:SetPoint("TOPRIGHT", 0, -62)

	-- Field, centered in the space left of the side column
	local area = CreateFrame("Frame", nil, view)
	area:SetPoint("TOPLEFT", 0, -62)
	area:SetPoint("BOTTOMRIGHT", side, "BOTTOMLEFT", -8, 0)

	local frame = UI.CreatePanel(area)
	frame:SetSize(Bubbles.WIDTH + 4, Bubbles.HEIGHT + 4)
	frame:SetPoint("TOP", 0, 0)
	frame:SetBackdropColor(0.04, 0.04, 0.07, 0.95)
	frame:SetBackdropBorderColor(0.3, 0.24, 0.15, 1)

	local field = CreateFrame("Frame", nil, frame)
	field:SetSize(Bubbles.WIDTH, Bubbles.HEIGHT)
	field:SetPoint("TOPLEFT", 2, -2)
	field:EnableMouse(true)

	local limitLine = field:CreateTexture(nil, "BORDER")
	limitLine:SetHeight(1)
	limitLine:SetPoint("TOPLEFT", 0, -(Bubbles.RADIUS + Bubbles.MAX_ROWS * Bubbles.ROW_HEIGHT))
	limitLine:SetPoint("TOPRIGHT", 0, -(Bubbles.RADIUS + Bubbles.MAX_ROWS * Bubbles.ROW_HEIGHT))
	limitLine:SetColorTexture(0.8, 0.2, 0.2, 0.5)

	local guideDots = {}
	for index = 1, GUIDE_DOTS do
		local dot = field:CreateTexture(nil, "ARTWORK")
		dot:SetTexture(CIRCLE_TEXTURE)
		dot:SetSize(GUIDE_DOT_SIZE, GUIDE_DOT_SIZE)
		guideDots[index] = dot
	end

	-- Created on demand, rows can be added until the board reaches the limit.
	local gridOrbs = {}
	local function GetGridOrb(index)
		local orb = gridOrbs[index]
		if not orb then
			orb = CreateOrb(field, diameter)
			gridOrbs[index] = orb
		end
		return orb
	end

	local shotOrb = CreateOrb(field, diameter)
	local currentOrb = CreateOrb(field, diameter)
	currentOrb:Place(Bubbles.SHOOTER_X, Bubbles.SHOOTER_Y)
	local nextOrb = CreateOrb(field, diameter * NEXT_SCALE)
	nextOrb:Place(Bubbles.SHOOTER_X - 3 * Bubbles.RADIUS, Bubbles.SHOOTER_Y + 2)

	local messageFrame = CreateFrame("Frame", nil, field)
	messageFrame:SetSize(Bubbles.WIDTH, 56)
	messageFrame:SetPoint("CENTER", 0, -40)
	messageFrame:SetFrameLevel(field:GetFrameLevel() + 5)
	local messageBackground = messageFrame:CreateTexture(nil, "BACKGROUND")
	messageBackground:SetAllPoints()
	messageBackground:SetColorTexture(0, 0, 0, 0.75)
	local messageLabel = UI.CreateLabel(messageFrame, "GameFontNormal")
	messageLabel:SetPoint("CENTER", 0, 0)
	messageLabel:SetWidth(Bubbles.WIDTH - 16)
	messageLabel:SetWordWrap(true)

	local statsBox = UI.CreateBox(side, SIDE_WIDTH, 96)
	statsBox:SetPoint("TOPLEFT", 0, 0)
	UI.CreateBoxHeader(statsBox, L.bubblesStats)
	local highScoreValue = UI.CreateStatRow(statsBox, 1, L.highScore)
	highScoreValue:SetTextColor(colors.gold[1], colors.gold[2], colors.gold[3])
	local bestLevelValue = UI.CreateStatRow(statsBox, 2, L.bestLevel)
	local playedValue = UI.CreateStatRow(statsBox, 3, L.gamesPlayed)

	local controlLines = { L.bubblesControlAim, L.bubblesControlShoot, L.bubblesControlSwap, L.bubblesControlKeys, L.bubblesControlRow }
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
	local drawnGame, drawnRevision

	local function DrawGrid(game)
		local count = 0
		for row = 1, Bubbles.MAX_ROWS + 1 do
			for column, color in pairs(game.grid[row]) do
				count = count + 1
				local orb = GetGridOrb(count)
				orb:Place(Bubbles.GetCellCenter(row, column))
				orb:SetColor(color)
				orb:SetShown(true)
			end
		end
		for index = count + 1, #gridOrbs do
			gridOrbs[index]:SetShown(false)
		end
	end

	-- Follows wall bounces and stops at the first bubble.
	local function DrawGuide(game)
		local visible = game.state ~= "lost" and not game.shot
		local x, y = Bubbles.SHOOTER_X, Bubbles.SHOOTER_Y
		local directionX, directionY = math.sin(game.angle), -math.cos(game.angle)
		local left, right = Bubbles.RADIUS, Bubbles.WIDTH - Bubbles.RADIUS
		local values = ORB_COLORS[game.current or 1]
		for index, dot in ipairs(guideDots) do
			x, y = x + directionX * GUIDE_SPACING, y + directionY * GUIDE_SPACING
			if x < left then
				x, directionX = 2 * left - x, -directionX
			elseif x > right then
				x, directionX = 2 * right - x, -directionX
			end
			visible = visible and y > Bubbles.RADIUS and not Bubbles.Touches(x, y)
			if visible then
				dot:ClearAllPoints()
				dot:SetPoint("CENTER", field, "TOPLEFT", x, -y)
				dot:SetVertexColor(values[1], values[2], values[3], 1 - index / (GUIDE_DOTS + 2))
			end
			dot:SetShown(visible)
		end
	end

	local function DrawAmmo(game)
		if game.shot then
			shotOrb:Place(game.shot.x, game.shot.y)
			shotOrb:SetColor(game.shot.color)
		end
		shotOrb:SetShown(game.shot ~= nil)

		local showAmmo = game.state ~= "lost"
		if showAmmo and game.current then
			currentOrb:SetColor(game.current)
		end
		currentOrb:SetShown(showAmmo and game.current ~= nil)
		if showAmmo then
			nextOrb:SetColor(game.next)
		end
		nextOrb:SetShown(showAmmo)
	end

	Refresh = function()
		local game = Bubbles.game
		local settings = PTT.database.bubbles

		if game ~= drawnGame or game.revision ~= drawnRevision then
			drawnGame, drawnRevision = game, game.revision
			DrawGrid(game)
		end
		DrawGuide(game)
		DrawAmmo(game)

		scoreValue:SetText(PTT.FormatNumber(game.score))
		levelValue:SetText(game.level)
		highScoreValue:SetText(PTT.FormatNumber(settings.highScore))
		bestLevelValue:SetText(PTT.FormatNumber(settings.bestLevel))
		playedValue:SetText(PTT.FormatNumber(settings.played))

		local message
		if game.state == "ready" then
			message = L.bubblesStart
		elseif game.state == "lost" then
			message = "|cffdd5555" .. L.bubblesLost .. "|r"
		end
		messageLabel:SetText(message or "")
		messageFrame:SetShown(message ~= nil)
	end

	-- Mouse aim only takes over once the cursor moves, so key aim is not overridden.
	local lastCursorX, lastCursorY
	local function FollowMouse()
		if not UI.IsMouseOver(field) then
			return false
		end
		local left, top = field:GetLeft(), field:GetTop()
		if not left or not top then
			return false
		end
		local cursorX, cursorY = GetCursorPosition()
		if cursorX == lastCursorX and cursorY == lastCursorY then
			return false
		end
		lastCursorX, lastCursorY = cursorX, cursorY
		local scale = field:GetEffectiveScale()
		local x, y = cursorX / scale - left, top - cursorY / scale
		Bubbles.Aim(atan2(x - Bubbles.SHOOTER_X, Bubbles.SHOOTER_Y - y))
		return true
	end

	field:SetScript("OnUpdate", function(_, delta)
		if not UI.IsMouseOver(view) or InCombatLockdown() then
			aimDirection = 0
		end
		delta = math.min(delta, MAX_FRAME_TIME)
		local changed = FollowMouse()
		if aimDirection ~= 0 then
			Bubbles.Aim(Bubbles.game.angle + aimDirection * KEY_AIM_SPEED * delta)
			changed = true
		end
		if Bubbles.Update(delta) or changed then
			Refresh()
		end
	end)

	field:SetScript("OnMouseDown", function(_, button)
		local changed
		if button == "RightButton" then
			changed = Bubbles.Swap()
		else
			changed = Bubbles.Shoot()
		end
		if changed then
			Refresh()
		end
	end)

	UI.EnableHoverKeyboard(view, function(key)
		local changed
		if AIM_KEYS[key] then
			aimDirection = AIM_KEYS[key]
			return true
		elseif SHOOT_KEYS[key] then
			changed = Bubbles.Shoot()
		elseif SWAP_KEYS[key] then
			changed = Bubbles.Swap()
		else
			return false
		end
		if changed then
			Refresh()
		end
		return true
	end)

	view:SetScript("OnKeyUp", function(_, key)
		if AIM_KEYS[key] == aimDirection then
			aimDirection = 0
		end
	end)

	view:HookScript("OnHide", function()
		aimDirection = 0
	end)
	view:HookScript("OnShow", Refresh)
	Refresh()
	return view
end

PTT.RegisterView({ id = "bubbles", label = "bubbles", build = BuildBubbles })
