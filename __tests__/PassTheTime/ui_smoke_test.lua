-- Loads the addon against a permissive frame stub and drives the UI. Catches Lua errors, not API mistakes.
-- Run from the workspace root: lua __tests__/PassTheTime/ui_smoke_test.lua
local createdFrames = {}

date = date or os.date

local function NewFrame(name)
	local frame = { _scripts = {}, _shown = true }
	local overrides = {
		GetPoint = function() return "CENTER", nil, "CENTER", 0, 0 end,
		GetFrameLevel = function() return 1 end,
		GetWidth = function() return 100 end,
		GetHeight = function() return 100 end,
		GetCenter = function() return 0, 0 end,
		GetEffectiveScale = function() return 1 end,
		IsShown = function(self) return self._shown end,
		Show = function(self) self._shown = true; if self._scripts.OnShow then self._scripts.OnShow(self) end end,
		Hide = function(self) self._shown = false; if self._scripts.OnHide then self._scripts.OnHide(self) end end,
		SetShown = function(self, shown) if shown then self:Show() else self:Hide() end end,
		SetScript = function(self, event, handler) self._scripts[event] = handler end,
		SetText = function(self, text) self._text = text end,
		GetScript = function(self, event) return self._scripts[event] end,
		GetText = function(self) return self._text or "" end,
		HookScript = function(self, event, handler)
			local previous = self._scripts[event]
			self._scripts[event] = function(...)
				if previous then previous(...) end
				handler(...)
			end
		end,
		CreateTexture = function() return NewFrame() end,
		CreateFontString = function() return NewFrame() end,
		GetChecked = function() return false end,
	}
	setmetatable(frame, {
		__index = function(_, key)
			if overrides[key] then
				return overrides[key]
			end
			-- Only WoW-style methods (capitalised) exist; plain fields are nil like on real frames.
			if type(key) == "string" and key:match("^%u") then
				return function() end
			end
			return nil
		end,
	})
	if name then
		_G[name] = frame
	end
	createdFrames[#createdFrames + 1] = frame
	return frame
end

function CreateFrame(_, name) return NewFrame(name) end
function GetLocale() return "deDE" end
function MouseIsOver() return false end
function GetCursorPosition() return 0, 0 end
function UIDropDownMenu_SetWidth() end
function UIDropDownMenu_SetText() end
function UIDropDownMenu_CreateInfo() return {} end
function UIDropDownMenu_AddButton(info) _G.lastDropdownInfo = info end
local initializers = {}
function UIDropDownMenu_Initialize(dropdown, initializer) initializers[#initializers + 1] = initializer end
function strtrim(text) return (text:gsub("^%s+", ""):gsub("%s+$", "")) end
function GameTooltip_Hide() end
UIParent = NewFrame()
Minimap = NewFrame()
GameTooltip = NewFrame()
UISpecialFrames = {}
STANDARD_TEXT_FONT = "font"
BackdropTemplateMixin = true
SlashCmdList = {}
local currentTime = 1000
function GetTime() return currentTime end
local tickers = {}
C_Timer = { NewTicker = function(_, callback) tickers[#tickers + 1] = callback end, After = function(_, callback) callback() end }
time = os.time
function InCombatLockdown() return false end
function GetServerTime() return 1700000000 end
local groupState = false
function IsInGroup() return groupState end
function IsInRaid() return false end
function IsInGuild() return groupState end
C_ChatInfo = { RegisterAddonMessagePrefix = function() end, SendAddonMessage = function() end }
function UnitName() return "Tester" end
function UnitGUID() return "player-guid" end
function CombatLogGetCurrentEventInfo() return 0, "PARTY_KILL", false, "player-guid" end
YES, NO = "Yes", "No"
StaticPopupDialogs = {}
function StaticPopup_Show(name, argument) _G.lastPopup = { name = name, argument = argument } end
playedSounds = {}
function PlaySoundFile(path) playedSounds[path:match("([%w]+)%.ogg$")] = true end

local PTT = {}
local function Load(path)
	assert(loadfile(path))("PassTheTime", PTT)
end

for line in io.lines("PassTheTime/PassTheTime.toc") do
	if line:match("%.lua$") then
		Load("PassTheTime/" .. line)
	end
end

-- Simulate ADDON_LOADED
PassTheTimeDB = nil
for _, frame in ipairs(createdFrames) do
	if frame._scripts.OnEvent then
		frame._scripts.OnEvent(frame, "ADDON_LOADED", "PassTheTime")
		break
	end
end

assert(PTT.database, "database not initialised")

-- First login shows the setup once; closing it marks it as done.
assert(PTT.database.setupDone == false, "setup not seen yet")
for index, frame in ipairs(createdFrames) do
	if index > 1 and frame._scripts.OnEvent then
		frame._scripts.OnEvent(frame, "PLAYER_ENTERING_WORLD")
	end
end
assert(PassTheTimeSetup and PassTheTimeSetup:IsShown(), "setup shows on first login")
for _, frame in ipairs(createdFrames) do
	if frame._scripts.OnClick and frame._text == PTT.L.setupStart then
		frame._scripts.OnClick(frame)
	end
end
assert(not PassTheTimeSetup:IsShown(), "start button closes the setup")
assert(PTT.database.setupDone == true, "closing the setup marks it as done")
assert(PassTheTimeWindow:IsShown(), "start button opens the window")
PassTheTimeWindow:Hide()
SlashCmdList["PASSTHETIME"]("setup")
assert(PassTheTimeSetup:IsShown(), "setup reopens with /ptt setup")
PassTheTimeSetup:Hide()
SlashCmdList["PASSTHETIME"]("")
assert(PassTheTimeWindow:IsShown(), "window shows")

for _, viewId in ipairs(PTT.viewOrder) do
	PTT.UI.SelectView(viewId)
end

-- Run dropdown initializers (they call UIDropDownMenu_AddButton with callbacks)
for _, initializer in ipairs(initializers) do
	initializer(nil, 1)
	if lastDropdownInfo and lastDropdownInfo.func then
		lastDropdownInfo.func()
	end
end

for _, frame in ipairs(createdFrames) do
	if frame._scripts.OnKeyDown then
		for _, key in ipairs({ "LEFT", "UP", "W", "A", "S", "D", "B", "ENTER", "BACKSPACE", "F5", "ENTER" }) do
			frame._scripts.OnKeyDown(frame, key)
		end
		for _ = 1, 30 do
			frame._scripts.OnKeyDown(frame, "A")
			frame._scripts.OnKeyDown(frame, "ENTER")
		end
	end
end

-- Idle: visit every tab and press every button on it
PTT.database.idle.gold = 1e12
PTT.database.idle.renown = 1000
PTT.database.idle.unlocked = 30
local tabEntries = { "idle:monster", "idle:ally", "idle:profession", "idle:prestige" }

for _, entryId in ipairs(tabEntries) do
	PTT.UI.Select(entryId)
	for _, frame in ipairs(createdFrames) do
		-- Navigation buttons (they carry a selection texture) would switch the tab under test.
		if frame._scripts.OnClick and frame._shown and not frame.selected and tostring(frame._text):find("^Prestige") == nil then
			frame._scripts.OnClick(frame)
		end
	end
end
assert(PTT.database.idle.upgrades.click and PTT.database.idle.upgrades.click > 0, "hero tab bought the click upgrade")
assert(next(PTT.database.idle.allies) ~= nil, "hero tab bought allies")
assert(next(PTT.database.idle.professions) ~= nil, "profession tab bought levels")
assert(PTT.database.idle.monsterIndex > 1, "monster list selected a monster")
for _ = 1, 3 do
	for _, frame in ipairs(createdFrames) do
		if frame._scripts.OnClick then
			frame._scripts.OnClick(frame)
		end
	end
end
for _ = 1, 20 do
	currentTime = currentTime + 1
	for _, ticker in ipairs(tickers) do ticker() end
	for _, frame in ipairs(createdFrames) do
		if frame._scripts.OnUpdate and frame._shown then
			frame._scripts.OnUpdate(frame, 0.3)
		end
	end
end
assert(PTT.database.idle.runTime > 0, "ticker advanced time")

-- World events, random event spawn + click, achievements view
for _, frame in ipairs(createdFrames) do
	if frame._scripts.OnEvent and frame ~= createdFrames[1] then
		for _, event in ipairs({ "COMBAT_LOG_EVENT_UNFILTERED", "CHAT_MSG_LOOT", "CHAT_MSG_SKILL", "QUEST_TURNED_IN", "PLAYER_LEVEL_UP" }) do
			frame._scripts.OnEvent(frame, event, "text", "name", "", "", "", "", 0, 0, "", 0, 1, "player-guid")
		end
	end
end
PTT.Events.Spawn()
for _, frame in ipairs(createdFrames) do
	if frame._scripts.OnUpdate and frame._shown then frame._scripts.OnUpdate(frame, 0.3) end
	if frame._scripts.OnMouseUp then frame._scripts.OnMouseUp(frame) end
end
assert(PTT.database.idle.eventsClaimed == 1, "event claimed through UI")
PTT.Achievements.Check()
PTT.UI.SelectView("achievements")
for _, frame in ipairs(createdFrames) do
	if frame._scripts.OnUpdate and frame._shown then frame._scripts.OnUpdate(frame, 5) end
end
PTT.database.idle.unlocked = PTT.Idle.PRESTIGE_UNLOCK_LEVEL
for _, frame in ipairs(createdFrames) do
	if frame._scripts.OnClick then frame._scripts.OnClick(frame) end
end
-- Social views with and without group/guild
for _, grouped in ipairs({ false, true }) do
	groupState = grouped
	PTT.Network.HandleMessage("S|1|Alice|1000|5|1|0", "PARTY")
	PTT.Network.HandleMessage("S|1|Bob|2000|6|2|0", "GUILD")
	PTT.UI.SelectView("leaderboard")
	PTT.UI.SelectView("bosses")
	for _, frame in ipairs(createdFrames) do
		if frame._scripts.OnClick then frame._scripts.OnClick(frame) end
		if frame._scripts.OnUpdate and frame._shown then frame._scripts.OnUpdate(frame, 2) end
	end
	for _ = 1, 3 do
		currentTime = currentTime + 1
		for _, ticker in ipairs(tickers) do ticker() end
	end
end
groupState = false
assert(StaticPopupDialogs["PASSTHETIME_PRESTIGE"], "prestige popup defined")
StaticPopupDialogs["PASSTHETIME_PRESTIGE"].OnAccept()
assert(PTT.database.idle.prestiges == 1, "prestige executed")

SlashCmdList["PASSTHETIME"]("icons")
assert(PassTheTimeIconDebug:IsShown(), "icon debug window opens")
SlashCmdList["PASSTHETIME"]("icons")
assert(not PassTheTimeIconDebug:IsShown(), "icon debug window closes")

SlashCmdList["PASSTHETIME"]("model")
SlashCmdList["PASSTHETIME"]("model scan")
SlashCmdList["PASSTHETIME"]("model all")
SlashCmdList["PASSTHETIME"]("model 12")
SlashCmdList["PASSTHETIME"]("model 9999")
SlashCmdList["PASSTHETIME"]("minimap")
SlashCmdList["PASSTHETIME"]("help")
SlashCmdList["PASSTHETIME"]("")
SlashCmdList["PASSTHETIME"]("")

-- Spell Orbs: one shot that pops, drops and clears the board runs every animation
-- The OnClick sweep above unticked every option, including the sounds.
PTT.database.settings.gameSounds = true
PTT.UI.SelectView("bubbles")
local Bubbles = PTT.Bubbles
Bubbles.NewGame()
local orbs = Bubbles.game
for row = 1, Bubbles.MAX_ROWS + 1 do
	orbs.grid[row] = {}
end
orbs.grid[1][5], orbs.grid[1][6], orbs.grid[2][5] = 2, 2, 3
orbs.current = 2
local targetX, targetY = Bubbles.GetCellCenter(1, 7)
Bubbles.Aim(math.atan(targetX - Bubbles.SHOOTER_X, Bubbles.SHOOTER_Y - targetY))
Bubbles.Shoot()
for _ = 1, 80 do
	for _, frame in ipairs(createdFrames) do
		if frame._scripts.OnUpdate and frame._shown then frame._scripts.OnUpdate(frame, 0.05) end
	end
end
assert(orbs.level == 2, "spell orbs board cleared")
assert(#orbs.effects == 0, "spell orbs effects consumed by the UI")
for _, name in ipairs({ "orbPop1", "orbDrop", "orbLevel" }) do
	assert(playedSounds[name], "spell orbs played " .. name)
end

-- Yahtzee: rolling and holding a die play their sounds
PTT.UI.SelectView("yahtzee")
PTT.Yahtzee.NewGame()
playedSounds = {}
for _, frame in ipairs(createdFrames) do
	if frame._scripts.OnClick and frame._text == PTT.L.yahtzeeRoll then
		frame._scripts.OnClick(frame)
	end
end
assert(playedSounds.diceRoll, "yahtzee roll sound")

-- Only the selected view is shown, so only its keyboard handler gets the key.
local function PressKey(key)
	for _, frame in ipairs(createdFrames) do
		if frame._shown and frame._scripts.OnKeyDown then
			frame._scripts.OnKeyDown(frame, key)
		end
	end
end
local function FindFrames(match)
	local found = {}
	for _, frame in ipairs(createdFrames) do
		if frame._scripts.OnClick and match(frame) then
			found[#found + 1] = frame
		end
	end
	return found
end

-- Memory: flipping a matching pair
PTT.UI.SelectView("memory")
PTT.Memory.NewGame("easy")
PTT.Memory.game.symbols[2] = PTT.Memory.game.symbols[1]
playedSounds = {}
local memoryCards = FindFrames(function(frame) return frame.mark end)
memoryCards[1]._scripts.OnClick(memoryCards[1])
memoryCards[2]._scripts.OnClick(memoryCards[2])
assert(playedSounds.cardFlip and playedSounds.cardMatch, "memory flip and match sounds")

-- Blockfall: rotate, then hard drop
PTT.UI.SelectView("blocks")
PTT.Blocks.random = function() return 0.5 end
PTT.Blocks.NewGame()
playedSounds = {}
PressKey("UP")
PressKey("UP")
PressKey("SPACE")
assert(playedSounds.blockRotate and playedSounds.blockDrop, "blockfall rotate and drop sounds")

-- Snake: eat the food straight ahead, then run into the wall
PTT.UI.SelectView("snake")
local Snake = PTT.Snake
Snake.NewGame()
playedSounds = {}
PressKey("RIGHT")
local head = Snake.game.segments[1]
Snake.game.food = { x = head.x + 1, y = head.y }
Snake.Update(Snake.GetInterval())
PressKey("RIGHT")
Snake.Update(10)
PressKey("SPACE")
assert(playedSounds.snakeEat and playedSounds.snakeCrash, "snake eat and crash sounds")

-- Breakout: launch and let the ball reach the bricks
PTT.UI.SelectView("breakout")
PTT.Breakout.NewGame()
playedSounds = {}
PressKey("SPACE")
for _ = 1, 40 do
	for _, frame in ipairs(createdFrames) do
		if frame._scripts.OnUpdate and frame._shown then frame._scripts.OnUpdate(frame, 0.05) end
	end
end
assert(playedSounds.brickLaunch, "breakout launch sound")
assert(playedSounds.brickHit or playedSounds.brickBreak, "breakout brick sound")

-- Minesweeper: first click opens safely, right click plants a banner
PTT.UI.SelectView("minesweeper")
local Minesweeper = PTT.Minesweeper
Minesweeper.NewGame()
playedSounds = {}
local mineCells = FindFrames(function(frame) return frame.label and frame.icon end)
mineCells[1]._scripts.OnClick(mineCells[1], "LeftButton")
assert(playedSounds.mineReveal or playedSounds.mineCascade or playedSounds.mineWin, "minesweeper reveal sound")
for index, cell in ipairs(mineCells) do
	if index <= Minesweeper.game.width * Minesweeper.game.height and not Minesweeper.game.revealed[index] then
		cell._scripts.OnClick(cell, "RightButton")
		break
	end
end
assert(playedSounds.mineFlag, "minesweeper flag sound")

-- Hangman: one right and one wrong letter
PTT.UI.SelectView("hangman")
PTT.Hangman.NewGame()
PTT.Hangman.game.word = "TEST"
playedSounds = {}
PressKey("T")
PressKey("Q")
assert(playedSounds.hangRight and playedSounds.hangWrong, "hangman right and wrong sounds")

PTT.database.settings.gameSounds = false
playedSounds = {}
PTT.UI.PlayGameSound("orbPop1")
assert(not next(playedSounds), "sounds stay off when disabled")

-- Every sound a game references ships as a file
local function AssertSoundFile(name)
	local handle = io.open("PassTheTime/Sounds/" .. name .. ".ogg", "rb")
	assert(handle, "missing sound file " .. name)
	handle:close()
end
local SOUND_PREFIXES = {
	["UIBubbles.lua"] = "orb",
	["UIYahtzee.lua"] = "dice",
	["UIMemory.lua"] = "card",
	["UIBlocks.lua"] = "block",
	["UISnake.lua"] = "snake",
	["UIBreakout.lua"] = "brick",
	["UIMinesweeper.lua"] = "mine",
	["UIHangman.lua"] = "hang",
}
for file, prefix in pairs(SOUND_PREFIXES) do
	local gameSource = io.open("PassTheTime/" .. file):read("*a")
	local count = 0
	for name in gameSource:gmatch('"(%l+%u%a+)"') do
		-- "orbPop" is only the prefix of the numbered pop sounds.
		if name:sub(1, #prefix) == prefix and name ~= "orbPop" then
			AssertSoundFile(name)
			count = count + 1
		end
	end
	assert(count > 0, "no sounds found in " .. file)
end
for step = 1, 5 do
	AssertSoundFile("orbPop" .. step)
end

-- Every localisation key referenced must exist in both locales
local source = {}
for _, file in ipairs({ "UI.lua", "UIIdle.lua", "UIGames.lua", "UIExtras.lua", "UISocial.lua", "UISettings.lua", "UISetup.lua", "UIMiniWidget.lua", "UIBlocks.lua", "UIBubbles.lua", "Main.lua" }) do
	local handle = io.open("PassTheTime/" .. file)
	source[#source + 1] = handle:read("*a")
	handle:close()
end
local missing = 0
for key in table.concat(source, "\n"):gmatch("L%.([%w_]+)") do
	if PTT.L[key] == key then
		print("MISSING locale key: " .. key)
		missing = missing + 1
	end
end
for _, label in pairs({ "categoryCities", "categoryZones", "categoryBosses", "setupFeatureBattle", "setupFeatureHeroes", "setupFeaturePrestige", "setupFeatureWorld", "setupFeatureMiniGames", "setupFeatureSocial" }) do
	if PTT.L[label] == label then
		print("MISSING locale key: " .. label)
		missing = missing + 1
	end
end

print(missing == 0 and "SMOKE OK" or "SMOKE FAILED")
os.exit(missing == 0 and 0 or 1)
