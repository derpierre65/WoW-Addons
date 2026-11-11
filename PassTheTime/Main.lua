local _, PTT = ...
local L = PTT.L

local lastTick
local slowDelta = 0

local function RunTick()
	local now = GetTime()
	local delta = math.min(now - lastTick, PTT.Idle.MAX_TICK)
	lastTick = now

	PTT.Idle.Tick(delta)

	-- Everything except the fight only needs a one second resolution.
	slowDelta = slowDelta + delta
	if slowDelta < 1 then
		return
	end
	delta = slowDelta
	slowDelta = 0

	PTT.World.Tick(delta)

	-- Events only appear while the window is open, so they never pop up in combat or cutscenes.
	if PassTheTimeWindow:IsShown() then
		PTT.Events.Tick(delta)
	else
		PTT.Events.Dismiss()
	end

	PTT.Achievements.Tick(delta)
	PTT.Network.Tick(delta)
	PTT.Bosses.Tick(delta)
end

PTT.OnInitialize(function()
	PTT.UI.CreateWindow()
	PTT.UI.CreateMinimapButton()
	PTT.UI.BuildEventFrame()
	PTT.UI.CreateMiniWidget()
	PTT.UI.CreateOptionsPanel()	PTT.World.RegisterEvents()
	PTT.Network.RegisterEvents()

	PTT.Bosses.OnFinish(function(kind, victory)
		local message = kind == "guild" and PTT.L.bossGuildDefeated or (victory and PTT.L.bossVictory or PTT.L.bossDefeat)
		PTT.UI.Toast(message)
	end)

	PTT.Idle.Migrate()
	PTT.Idle.StartSession()
	PTT.Idle.OnUnlock(function(index)
		PTT.UI.Toast(string.format(PTT.L.enemyUnlocked, PTT.Idle.GetName(PTT.Idle.GetMonster(index))))
	end)

	PTT.Idle.OnBossFailed(function(boss)
		PTT.UI.Toast(string.format(PTT.L.bossFailed, PTT.Idle.GetName(boss)))
	end)

	PTT.Achievements.OnUnlock(PTT.UI.ShowAchievementBanner)

	local combatFrame = CreateFrame("Frame")
	combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
	combatFrame:SetScript("OnEvent", function()
		if PTT.database.settings.closeInCombat then
			PassTheTimeWindow:Hide()
		end
	end)

	lastTick = GetTime()
	C_Timer.NewTicker(PTT.Idle.FIGHT_INTERVAL, RunTick)
end)

SLASH_PASSTHETIME1 = "/ptt"
SLASH_PASSTHETIME2 = "/passthetime"
SlashCmdList["PASSTHETIME"] = function(message)
	local command = strtrim(message or ""):lower()

	if command == "minimap" then
		local settings = PTT.database.minimap
		settings.hidden = not settings.hidden
		PTT.UI.minimapButton:SetShown(not settings.hidden)
	elseif command == "icons" then
		PTT.UI.ToggleIconDebug()
	elseif command == "help" then
		print("|cff00ccff" .. L.addonTitle .. ":|r " .. L.slashHelp)
	else
		PTT.UI.Toggle()
	end
end
