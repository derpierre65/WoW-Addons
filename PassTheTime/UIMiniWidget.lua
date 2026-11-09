local _, PTT = ...
local L = PTT.L
local UI = PTT.UI

local WIDGET_WIDTH, WIDGET_HEIGHT = 200, 62
local REFRESH_INTERVAL = 0.2
local BOSS_COLOR, NORMAL_COLOR = "|cffff8800", "|cffffd100"

local widget

local function Refresh()
	local monster = PTT.Idle.GetCurrentMonster()
	widget.name:SetText("|cff999999" .. string.format(L.levelShort, monster.index) .. "|r  " .. (monster.boss and BOSS_COLOR or NORMAL_COLOR) .. PTT.Idle.GetName(monster) .. "|r")

	widget.health:SetValue(monster.currentHealth / monster.health)
	widget.health:SetStatusBarColor(monster.boss and 0.9 or 0.75, monster.boss and 0.5 or 0.15, monster.boss and 0.1 or 0.15)
	widget.health.text:SetText(PTT.FormatNumber(monster.currentHealth) .. " / " .. PTT.FormatNumber(monster.health))

	widget.gold:SetText(PTT.FormatNumber(PTT.database.idle.gold))
end

function UI.SetMiniWidgetShown(shown)
	if not widget then
		return
	end

	widget:SetShown(shown)
	if shown then
		Refresh()
	end
end

function UI.CreateMiniWidget()
	widget = UI.CreatePanel(UIParent, "PassTheTimeMiniWidget")
	widget:SetSize(WIDGET_WIDTH, WIDGET_HEIGHT)
	widget:SetFrameStrata("MEDIUM")
	widget:SetClampedToScreen(true)
	widget:SetMovable(true)
	widget:EnableMouse(true)
	widget:RegisterForDrag("LeftButton")
	widget:SetScript("OnDragStart", widget.StartMoving)
	widget:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, relativePoint, x, y = self:GetPoint()
		local saved = PTT.database.miniWidget
		saved.point, saved.relativePoint, saved.x, saved.y = point, relativePoint, x, y
	end)

	local saved = PTT.database.miniWidget
	widget:SetPoint(saved.point, UIParent, saved.relativePoint or saved.point, saved.x, saved.y)

	widget.name = UI.CreateLabel(widget, "GameFontNormal")
	widget.name:SetPoint("TOP", 0, -9)
	widget.name:SetWidth(WIDGET_WIDTH - 16)

	widget.health = UI.CreateSkillBar(widget, 12)
	widget.health:SetPoint("TOPLEFT", 12, -27)
	widget.health:SetPoint("TOPRIGHT", -12, -27)

	widget.gold = UI.CreateLabel(widget, "GameFontNormal")
	widget.gold:SetPoint("BOTTOMRIGHT", -12, 8)
	widget.goldTitle = UI.CreateLabel(widget, "GameFontNormalSmall", L.gold)
	widget.goldTitle:SetPoint("BOTTOMLEFT", 12, 9)

	local elapsed = 0
	widget:SetScript("OnUpdate", function(_, delta)
		elapsed = elapsed + delta
		if elapsed >= REFRESH_INTERVAL then
			elapsed = 0
			Refresh()
		end
	end)

	widget:SetShown(PTT.database.settings.miniWidget)
	if widget:IsShown() then
		Refresh()
	end
end
