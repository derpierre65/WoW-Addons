local _, PTT = ...
local L = PTT.L
local UI = PTT.UI

---------------------------------------------------------------------------
-- Debug window: all Memory symbols with their file path and the picture the game loads for them
---------------------------------------------------------------------------

local WINDOW_WIDTH, WINDOW_HEIGHT = 620, 500
local ROW_HEIGHT, ICON_SIZE = 40, 32
local WINDOW_NAME = "PassTheTimeIconDebug"

local window

local function CreateRow(content, index)
	local row = CreateFrame("Frame", nil, content)
	row:SetSize(WINDOW_WIDTH - 56, ROW_HEIGHT - 2)
	row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)
	row.background = row:CreateTexture(nil, "BACKGROUND")
	row.background:SetAllPoints()
	row.background:SetColorTexture(1, 1, 1, index % 2 == 0 and 0.06 or 0.02)

	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(ICON_SIZE, ICON_SIZE)
	row.icon:SetPoint("LEFT", 6, 0)

	row.numberLabel = UI.CreateLabel(row, "GameFontNormal")
	row.numberLabel:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -1)

	row.statusLabel = UI.CreateLabel(row, "GameFontHighlightSmall")
	row.statusLabel:SetPoint("TOPRIGHT", -8, -4)

	-- An edit box so the path can be selected and copied.
	row.pathBox = CreateFrame("EditBox", nil, row)
	row.pathBox:SetFontObject("GameFontDisableSmall")
	row.pathBox:SetAutoFocus(false)
	row.pathBox:SetSize(WINDOW_WIDTH - 56 - ICON_SIZE - 24, 14)
	row.pathBox:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 1)
	row.pathBox:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)
	row.pathBox:SetScript("OnTextChanged", function(self, userInput)
		if userInput then
			self:SetText(self.path or "")
		end
	end)

	return row
end

local function BuildWindow()
	local Memory = PTT.Memory

	local frame = UI.CreatePanel(UIParent, WINDOW_NAME)
	frame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:Hide()
	table.insert(UISpecialFrames, WINDOW_NAME)

	local title = UI.CreateLabel(frame, "GameFontNormalLarge", L.iconDebugTitle)
	title:SetPoint("TOPLEFT", 14, -12)

	frame.summaryLabel = UI.CreateLabel(frame, "GameFontHighlightSmall")
	frame.summaryLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)

	local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	closeButton:SetPoint("TOPRIGHT", -2, -2)

	local scroll = CreateFrame("ScrollFrame", WINDOW_NAME .. "Scroll", frame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 12, -56)
	scroll:SetPoint("BOTTOMRIGHT", -32, 12)

	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(WINDOW_WIDTH - 56, #Memory.symbols * ROW_HEIGHT)
	scroll:SetScrollChild(content)

	frame.rows = {}
	for index = 1, #Memory.symbols do
		frame.rows[index] = CreateRow(content, index)
	end

	-- Fresh data on every opening, the game may resolve pictures differently by then.
	frame:SetScript("OnShow", function(self)
		local unique = {}
		for _, symbol in ipairs(Memory.GetUniqueSymbols()) do
			unique[symbol] = true
		end

		local skipped = 0
		for index, symbol in ipairs(Memory.symbols) do
			local row = self.rows[index]
			local name = symbol:gsub("^Interface\\Icons\\", "")
			row.icon:SetTexture(symbol)
			row.numberLabel:SetText(string.format("%d  %s", index, name))
			row.pathBox.path = symbol
			row.pathBox:SetText(symbol)
			row.pathBox:SetCursorPosition(0)

			local picture = tostring(Memory.ResolveIcon(symbol))
			if unique[symbol] then
				row.statusLabel:SetText(string.format(L.iconDebugPicture, picture))
			else
				row.statusLabel:SetText("|cffff5555" .. string.format(L.iconDebugSkipped, picture) .. "|r")
				skipped = skipped + 1
			end
		end
		self.summaryLabel:SetText(string.format(L.iconDebugSummary, #Memory.symbols, #Memory.symbols - skipped, skipped))
	end)

	return frame
end

function UI.ToggleIconDebug()
	window = window or BuildWindow()
	window:SetShown(not window:IsShown())
end
