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

-- Pops spread outward from the impact, one step per bubble diameter.
local POP_STAGGER = 0.035
local POP_DURATION = 0.2
local POP_GROWTH = 0.6
local SPARKS_PER_POP = 5
local SPARK_DURATION = 0.35
local SPARK_SIZE = 5
local SPARK_MIN_SPEED = 50
local SPARK_MAX_SPEED = 120
local DROP_GRAVITY = 1100
local DROP_MAX_SIDE_SPEED = 50
local DROP_JUMP_SPEED = 90
local DROP_FADE_START = 0.5
local DROP_DURATION = 0.9
local SCORE_DURATION = 0.9
local SCORE_RISE = 28
local SCORE_FADE_START = 0.6
local LEVEL_BANNER_DURATION = 1.6
local POP_SOUND_GAP = 0.04
-- Sounds\orbPop1.ogg up to orbPop5.ogg, rising in pitch.
local POP_SOUND_STEPS = 5
local EFFECT_SOUNDS = { bounce = "orbBounce", land = "orbLand", row = "orbRow", lost = "orbLose" }

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

	function orb:SetAlpha(alpha)
		self.border:SetAlpha(alpha)
		self.body:SetAlpha(alpha)
		self.shine:SetAlpha(alpha)
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

	local Refresh, ClearAnimations
	local aimDirection = 0
	local newGameButton = UI.CreateButton(view, L.newGame, 110, 50, function()
		local state = Bubbles.game.state
		UI.ConfirmNewGame(function()
			Bubbles.NewGame()
			ClearAnimations()
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
	-- Falling orbs leave through the bottom edge.
	field:SetClipsChildren(true)

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

	-- Above the board orbs, below the message.
	local effectsFrame = CreateFrame("Frame", nil, field)
	effectsFrame:SetAllPoints()
	effectsFrame:SetFrameLevel(field:GetFrameLevel() + 3)

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

	-- Animations
	local animations = {}
	local freeOrbs, freeSparks, freeLabels = {}, {}, {}
	local bannerText, bannerTime = nil, 0
	local soundClock, lastPopSound = 0, -math.huge

	local function AcquireOrb(effect)
		local orb = table.remove(freeOrbs) or CreateOrb(effectsFrame, diameter)
		orb:SetSize(diameter)
		orb:Place(effect.x, effect.y)
		orb:SetColor(effect.color)
		orb:SetAlpha(1)
		orb:SetShown(true)
		return orb
	end

	local function StartSparks(x, y, color)
		local values = ORB_COLORS[color]
		for _ = 1, SPARKS_PER_POP do
			local spark = table.remove(freeSparks)
			if not spark then
				spark = effectsFrame:CreateTexture(nil, "OVERLAY")
				spark:SetTexture(CIRCLE_TEXTURE)
			end
			spark:SetVertexColor(values[1], values[2], values[3], 1)
			spark:Show()
			local angle = math.random() * 2 * math.pi
			local speed = SPARK_MIN_SPEED + math.random() * (SPARK_MAX_SPEED - SPARK_MIN_SPEED)
			animations[#animations + 1] = {
				kind = "spark", texture = spark, elapsed = 0, x = x, y = y,
				velocityX = math.cos(angle) * speed, velocityY = math.sin(angle) * speed,
			}
		end
	end

	local function StartEffects(effects)
		local lastPopDelay = 0
		for _, effect in ipairs(effects) do
			if effect.kind == "pop" then
				lastPopDelay = math.max(lastPopDelay, effect.distance / diameter * POP_STAGGER)
			end
		end

		-- Pops of one shot climb in pitch.
		local chain = { pops = 0 }
		local dropSoundQueued = false
		for _, effect in ipairs(effects) do
			if effect.kind == "pop" then
				animations[#animations + 1] = {
					kind = "pop", orb = AcquireOrb(effect), elapsed = 0, x = effect.x, y = effect.y, color = effect.color,
					delay = effect.distance / diameter * POP_STAGGER, chain = chain,
				}
			elseif effect.kind == "drop" then
				if not dropSoundQueued then
					dropSoundQueued = true
					animations[#animations + 1] = { kind = "sound", name = "orbDrop", elapsed = 0, delay = lastPopDelay + POP_DURATION / 2 }
				end
				animations[#animations + 1] = {
					kind = "drop", orb = AcquireOrb(effect), elapsed = 0, x = effect.x, y = effect.y,
					delay = lastPopDelay + POP_DURATION / 2,
					velocityX = (math.random() * 2 - 1) * DROP_MAX_SIDE_SPEED, velocityY = -DROP_JUMP_SPEED,
				}
			elseif effect.kind == "score" or effect.kind == "level" then
				local label = table.remove(freeLabels) or UI.CreateLabel(effectsFrame, "GameFontNormalLarge")
				label:SetText("+" .. PTT.FormatNumber(effect.points))
				label:SetTextColor(colors.gold[1], colors.gold[2], colors.gold[3])
				label:SetAlpha(1)
				label:Show()
				local x, y = effect.x, effect.y
				if effect.kind == "level" then
					x, y = Bubbles.WIDTH / 2, Bubbles.HEIGHT / 2 + 30
					bannerText, bannerTime = string.format(L.level, effect.level), LEVEL_BANNER_DURATION
					animations[#animations + 1] = { kind = "sound", name = "orbLevel", elapsed = 0, delay = lastPopDelay + POP_DURATION }
				end
				label:ClearAllPoints()
				label:SetPoint("CENTER", effectsFrame, "TOPLEFT", x, -y)
				animations[#animations + 1] = { kind = "score", label = label, elapsed = 0, x = x, y = y, delay = lastPopDelay }
			elseif EFFECT_SOUNDS[effect.kind] then
				UI.PlayGameSound(EFFECT_SOUNDS[effect.kind])
			end
		end
	end

	local function Release(animation)
		if animation.orb then
			animation.orb:SetShown(false)
			freeOrbs[#freeOrbs + 1] = animation.orb
		elseif animation.texture then
			animation.texture:Hide()
			freeSparks[#freeSparks + 1] = animation.texture
		elseif animation.label then
			animation.label:Hide()
			freeLabels[#freeLabels + 1] = animation.label
		end
	end

	-- Returns true once the animation is over.
	local function StepAnimation(animation, delta)
		animation.elapsed = animation.elapsed + delta
		local time = animation.elapsed - (animation.delay or 0)
		if time < 0 then
			return false
		end

		if animation.kind == "sound" then
			UI.PlayGameSound(animation.name)
			return true
		elseif animation.kind == "pop" then
			if not animation.burst then
				animation.burst = true
				StartSparks(animation.x, animation.y, animation.color)
				local chain = animation.chain
				chain.pops = chain.pops + 1
				-- Big groups would stack dozens of pops in a few frames.
				if soundClock - lastPopSound >= POP_SOUND_GAP then
					lastPopSound = soundClock
					UI.PlayGameSound("orbPop" .. math.min(POP_SOUND_STEPS, chain.pops))
				end
			end
			local progress = time / POP_DURATION
			if progress >= 1 then
				return true
			end
			animation.orb:SetSize(diameter * (1 + POP_GROWTH * progress))
			animation.orb:Place(animation.x, animation.y)
			animation.orb:SetAlpha(1 - progress)
		elseif animation.kind == "spark" then
			local progress = time / SPARK_DURATION
			if progress >= 1 then
				return true
			end
			animation.x = animation.x + animation.velocityX * delta
			animation.y = animation.y + animation.velocityY * delta
			local size = SPARK_SIZE * (1 - progress / 2)
			animation.texture:SetSize(size, size)
			animation.texture:ClearAllPoints()
			animation.texture:SetPoint("CENTER", effectsFrame, "TOPLEFT", animation.x, -animation.y)
			animation.texture:SetAlpha(1 - progress)
		elseif animation.kind == "drop" then
			if time >= DROP_DURATION or animation.y > Bubbles.HEIGHT + diameter then
				return true
			end
			animation.velocityY = animation.velocityY + DROP_GRAVITY * delta
			animation.x = animation.x + animation.velocityX * delta
			animation.y = animation.y + animation.velocityY * delta
			animation.orb:Place(animation.x, animation.y)
			animation.orb:SetAlpha(1 - math.max(0, (time - DROP_FADE_START) / (DROP_DURATION - DROP_FADE_START)))
		elseif animation.kind == "score" then
			local progress = time / SCORE_DURATION
			if progress >= 1 then
				return true
			end
			animation.label:ClearAllPoints()
			animation.label:SetPoint("CENTER", effectsFrame, "TOPLEFT", animation.x, -(animation.y - SCORE_RISE * progress))
			animation.label:SetAlpha(1 - math.max(0, (progress - SCORE_FADE_START) / (1 - SCORE_FADE_START)))
		end
		return false
	end

	local function StepAnimations(delta)
		soundClock = soundClock + delta
		local effects = Bubbles.game.effects
		if #effects > 0 then
			Bubbles.game.effects = {}
			StartEffects(effects)
		end
		for index = #animations, 1, -1 do
			local animation = animations[index]
			if StepAnimation(animation, delta) then
				Release(animation)
				table.remove(animations, index)
			end
		end
	end

	ClearAnimations = function()
		for _, animation in ipairs(animations) do
			Release(animation)
		end
		animations = {}
		bannerText, bannerTime = nil, 0
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
		elseif bannerText then
			message = "|cffffd100" .. bannerText .. "|r"
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
		if Bubbles.Update(delta) then
			changed = true
		end
		StepAnimations(delta)
		if bannerText then
			bannerTime = bannerTime - delta
			if bannerTime <= 0 then
				bannerText = nil
				changed = true
			end
		end
		if changed then
			Refresh()
		end
	end)

	local function Shoot()
		if not Bubbles.Shoot() then
			return false
		end
		UI.PlayGameSound("orbShoot")
		return true
	end

	field:SetScript("OnMouseDown", function(_, button)
		local changed
		if button == "RightButton" then
			changed = Bubbles.Swap()
		else
			changed = Shoot()
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
			changed = Shoot()
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
