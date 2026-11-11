local _, PTT = ...
local L = PTT.L
local UI = PTT.UI
local Changelog = PTT.Changelog

local WINDOW_NAME = "PassTheTimeChangelog"
local WINDOW_WIDTH = 480
local WINDOW_HEIGHT = 440
local PADDING = 20
local SCROLLBAR_WIDTH = 26
local CONTENT_WIDTH = WINDOW_WIDTH - 2 * PADDING - SCROLLBAR_WIDTH
local BULLET_INDENT = 8
-- The last release without the changelog, its players count as having seen it.
local UNTRACKED_VERSION = "0.3.0"

local window
local pending

local function CreateChangelogWindow()
	window = UI.CreatePanel(UIParent, WINDOW_NAME)
	window:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
	window:SetPoint("CENTER")
	window:SetFrameStrata("DIALOG")
	window:SetClampedToScreen(true)
	window:SetMovable(true)
	window:EnableMouse(true)
	window:RegisterForDrag("LeftButton")
	window:SetScript("OnDragStart", window.StartMoving)
	window:SetScript("OnDragStop", window.StopMovingOrSizing)
	window:SetScript("OnHide", function()
		PTT.database.changelogVersion = PTT.version
	end)

	local closeButton = CreateFrame("Button", nil, window, "UIPanelCloseButton")
	closeButton:SetPoint("TOPRIGHT", -2, -2)

	local icon = window:CreateTexture(nil, "ARTWORK")
	icon:SetSize(40, 40)
	icon:SetTexture("Interface\\Icons\\INV_Misc_PocketWatch_01")
	icon:SetPoint("TOPLEFT", PADDING, -PADDING)

	local title = UI.CreateLabel(window, "GameFontNormalLarge", L.changelogTitle)
	title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -3)

	window.subtitle = UI.CreateLabel(window, "GameFontHighlightSmall")
	window.subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
	window.subtitle:SetTextColor(0.6, 0.6, 0.6)

	local okayButton = UI.CreateButton(window, L.changelogOkay, 120, 24, function()
		window:Hide()
	end)
	okayButton:SetPoint("BOTTOMRIGHT", -PADDING, PADDING - 4)

	window.scroll = CreateFrame("ScrollFrame", WINDOW_NAME .. "Scroll", window, "UIPanelScrollFrameTemplate")
	window.scroll:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -14)
	window.scroll:SetPoint("BOTTOMRIGHT", okayButton, "TOPRIGHT", -SCROLLBAR_WIDTH, 12)

	-- The width has to be set before the wrapped text heights can be measured.
	window.content = CreateFrame("Frame", nil, window.scroll)
	window.content:SetSize(CONTENT_WIDTH, 1)
	window.scroll:SetScrollChild(window.content)
	window.labels = {}

	table.insert(UISpecialFrames, WINDOW_NAME)
end

local function FillEntries(entries)
	local labelCount, offsetY = 0, 0

	local function AddLine(template, text, spacing, indent)
		labelCount = labelCount + 1
		local label = window.labels[labelCount]
		if not label then
			label = UI.CreateLabel(window.content)
			label:SetJustifyH("LEFT")
			window.labels[labelCount] = label
		end
		label:SetFontObject(template)
		label:ClearAllPoints()
		label:SetPoint("TOPLEFT", indent, -(offsetY + spacing))
		label:SetWidth(CONTENT_WIDTH - indent)
		label:SetText(text)
		label:Show()
		offsetY = offsetY + spacing + label:GetStringHeight()
	end

	for entryIndex, entry in ipairs(entries) do
		AddLine("GameFontNormal", string.format(L.changelogVersion, entry.version), entryIndex == 1 and 0 or 16, 0)
		for _, section in ipairs(Changelog.GetSections(entry)) do
			if section.title then
				AddLine("GameFontNormalSmall", section.title, 10, BULLET_INDENT)
			end
			for _, change in ipairs(section.changes) do
				AddLine("GameFontHighlightSmall", "- " .. change, 5, 2 * BULLET_INDENT)
			end
		end
	end

	for index = labelCount + 1, #window.labels do
		window.labels[index]:Hide()
	end
	window.content:SetHeight(math.max(offsetY, 1))
	window.scroll:SetVerticalScroll(0)
end

-- Without arguments it shows every version, for /ptt changelog.
function UI.ShowChangelog(entries, sinceVersion)
	pending = nil
	if not window then
		CreateChangelogWindow()
	end

	FillEntries(entries or Changelog.entries)
	window.subtitle:SetText(sinceVersion and string.format(L.changelogSince, sinceVersion) or L.changelogAll)
	window:Show()
end

function UI.ShowPendingChangelog()
	if pending then
		UI.ShowChangelog(pending.entries, pending.sinceVersion)
	end
end

function UI.ScheduleChangelog()
	local database = PTT.database
	if PTT.isNewInstall then
		database.changelogVersion = PTT.version
		return
	end

	local sinceVersion = database.changelogVersion or UNTRACKED_VERSION
	local entries = Changelog.GetBetween(sinceVersion, PTT.version)
	if #entries == 0 then
		database.changelogVersion = PTT.version
		return
	end

	pending = { entries = entries, sinceVersion = sinceVersion }
	-- Otherwise the setup still has to show and opens the changelog once closed.
	if database.setupDone then
		UI.ShowAfterLogin(UI.ShowPendingChangelog)
	end
end
