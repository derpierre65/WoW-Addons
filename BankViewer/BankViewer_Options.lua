local L = BankViewer.L

local panel = CreateFrame("Frame", "BankViewerOptionsPanel")
panel.name = L.addonTitle

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText(L.addonTitle)

local hideMinimapCheckbox = CreateFrame("CheckButton", "BankViewerHideMinimapCheckbox", panel, "UICheckButtonTemplate")
hideMinimapCheckbox:SetSize(26, 26)
hideMinimapCheckbox:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
local hideMinimapLabel = _G["BankViewerHideMinimapCheckboxText"]
hideMinimapLabel:SetText(L.settingHideMinimapButton)
hideMinimapLabel:SetFontObject("GameFontHighlight")

hideMinimapCheckbox:SetScript("OnClick", function(self)
	BankViewerDB._settings = BankViewerDB._settings or {}
	BankViewerDB._settings.hideMinimapButton = self:GetChecked() and true or false
	BankViewer.UpdateMinimapButton()
end)

panel:SetScript("OnShow", function()
	BankViewerDB._settings = BankViewerDB._settings or {}
	hideMinimapCheckbox:SetChecked(BankViewerDB._settings.hideMinimapButton)
end)

if Settings and Settings.RegisterCanvasLayoutCategory then
	local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
	Settings.RegisterAddOnCategory(category)
else
	InterfaceOptions_AddCategory(panel)
end
