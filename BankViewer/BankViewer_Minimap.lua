local BUTTON_RADIUS = 80
local DEFAULT_ANGLE = 220

local function IsSquareMinimap()
	return GetMinimapShape and GetMinimapShape() == "SQUARE"
end

local function GetMinimapButtonPosition(angle)
	local rad = math.rad(angle)
	local cos, sin = math.cos(rad), math.sin(rad)

	if IsSquareMinimap() then
		-- position along the edge of a square
		local halfWidth = Minimap:GetWidth() / 2 + 6
		local halfHeight = Minimap:GetHeight() / 2 + 6
		local scale = math.min(halfWidth / math.max(math.abs(cos), 0.001), halfHeight / math.max(math.abs(sin), 0.001))
		return cos * scale, sin * scale
	end

	local radius = Minimap:GetWidth() / 2 + 6
	return cos * radius, sin * radius
end

local minimapButton = CreateFrame("Button", "BankViewerMinimapButton", Minimap)
minimapButton:SetSize(33, 33)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:SetFrameLevel(8)
minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
minimapButton:SetMovable(true)

local overlay = minimapButton:CreateTexture(nil, "OVERLAY")
overlay:SetSize(53, 53)
overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
overlay:SetPoint("TOPLEFT")

local icon = minimapButton:CreateTexture(nil, "BACKGROUND")
icon:SetSize(21, 21)
icon:SetTexture("Interface\\Icons\\INV_Misc_Bag_10_Blue")
icon:SetPoint("CENTER", 0, 1)
minimapButton.icon = icon

local function UpdatePosition(angle)
	local x, y = GetMinimapButtonPosition(angle)
	minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- Dragging
local isDragging = false

minimapButton:RegisterForDrag("LeftButton")
minimapButton:SetScript("OnDragStart", function(self)
	isDragging = true
	self:SetScript("OnUpdate", function(self)
		local mx, my = Minimap:GetCenter()
		local cx, cy = GetCursorPosition()
		local scale = Minimap:GetEffectiveScale()
		cx, cy = cx / scale, cy / scale
		local angle = math.deg(math.atan2(cy - my, cx - mx))
		BankViewerDB._minimap = BankViewerDB._minimap or {}
		BankViewerDB._minimap.angle = angle
		UpdatePosition(angle)
	end)
end)

minimapButton:SetScript("OnDragStop", function(self)
	isDragging = false
	self:SetScript("OnUpdate", nil)
end)

minimapButton:SetScript("OnClick", function()
	BankViewer.Toggle()
end)

minimapButton:SetScript("OnEnter", function(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:AddLine("BankViewer")
	GameTooltip:AddLine("Click to toggle window", 1, 1, 1)
	GameTooltip:Show()
end)

minimapButton:SetScript("OnLeave", function()
	GameTooltip:Hide()
end)

-- Initialize position after DB is loaded
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
	BankViewerDB._minimap = BankViewerDB._minimap or {}
	local angle = BankViewerDB._minimap.angle or DEFAULT_ANGLE
	minimapButton:ClearAllPoints()
	UpdatePosition(angle)
	self:UnregisterAllEvents()
end)
