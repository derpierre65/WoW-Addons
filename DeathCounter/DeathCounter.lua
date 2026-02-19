-- local RealName = GetRealmName()
local _, DeathCounter = ...

-- elvUI stuff
local clientHasElvUI = IsAddOnLoaded("ElvUI");
local E, L, V, P, G, DT, lastElvUIPanel, displayString;

if (clientHasElvUI) then
    E, L, V, P, G = unpack(ElvUI) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
    DT = E:GetModule('DataTexts')
end

function DeathCounter_ElvUIEvent(self)
    lastElvUIPanel = self

    local i18n = DeathCounter.L["Deaths"];
    if (DeathCounterCharDB.deaths == 1) then
        i18n = DeathCounter.L["Death"];
    end

    self.text:SetFormattedText(displayString, i18n, DeathCounterCharDB.deaths)
end

function DeathCounter_OnLoad(self)
    self:RegisterEvent("PLAYER_DEAD")
    self:RegisterEvent("ADDON_LOADED")

    SLASH_DeathCounter1 = "/deathcounter"
    SLASH_DeathCounter2 = "/dc"
    SlashCmdList["DeathCounter"] = DeathCounter_SlashCmd

    if clientHasElvUI then
        local function ValueColorUpdatex(hex)
            displayString = strjoin("", "%s: ", hex, "%d|r")
            if lastElvUIPanel ~= nil then
                DeathCounter_ElvUIEvent(lastElvUIPanel)
            end
        end

        E.valueColorUpdateFuncs[ValueColorUpdatex] = true
        DT:RegisterDatatext('Deaths', { "PLAYER_ENTERING_WORLD" }, DeathCounter_ElvUIEvent, nil, nil, nil, nil, DeathCounter.L["Deaths"])
    end
end

function DeathCounter_Event(self, event, addon)
    if (event == "PLAYER_DEAD") then
        DeathCounterCharDB.deaths = DeathCounterCharDB.deaths + 1
        DeathCounter_Update()
    elseif event == "ADDON_LOADED" and addon == "DeathCounter" then
        DeathCounterCharDB = DeathCounterCharDB or {
            show = true,
            deaths = 0
        }
        DeathCounter_Update()
    end
end

function DeathCounter_UpdateValue(value, override)
    value = tonumber(value)
    if (override == true) then
        DeathCounterCharDB.deaths = value
    else
        DeathCounterCharDB.deaths = DeathCounterCharDB.deaths + value
    end

    if DeathCounterCharDB.deaths < 0 then
        DeathCounterCharDB.deaths = 0
    end

    DeathCounter_Update()
end

function DeathCounter_Update()
    if lastElvUIPanel ~= nil then
        DeathCounter_ElvUIEvent(lastElvUIPanel)
    end

    DeathCounter_Overlay_DeathText:SetText(DeathCounterCharDB.deaths .. " " .. DeathCounter.L["Deaths"]);

    if (DeathCounterCharDB.show == false) then
        DeathCounter_Overlay_DeathText:Hide()
        return
    end
end

function DeathCounter_SlashCmd(msg)
    local arg = ""
    local x = string.find(msg, " ")
    if (x ~= nil) then
        arg = string.sub(msg, x + 1)
        msg = string.sub(msg, 0, x - 1)
    end

    if (msg == "add") then
        DeathCounter_UpdateValue(arg)
    elseif (msg == "hide") then
        DeathCounter_Overlay_DeathText:Hide()
        DeathCounterCharDB.show = false
    elseif (msg == "show") then
        DeathCounter_Overlay_DeathText:Show()
        DeathCounterCharDB.show = true
    elseif (msg == "set") then
        DeathCounter_UpdateValue(arg, true)
    elseif (msg == "reset") then
        DeathCounter_UpdateValue(0, true)
    elseif (msg == "remove" or msg == "rem") then
        DeathCounter_UpdateValue(arg * -1)
    else
        print(DeathCounter.L["HelpInfo"])
        print("- /dc reset, " .. DeathCounter.L["HelpInfoReset"])
        print("- /dc set <count>, " .. DeathCounter.L["HelpInfoSet"])
        print("- /dc add <count>, " .. DeathCounter.L["HelpInfoAdd"])
        print("- /dc rem[ove] <count>, " .. DeathCounter.L["HelpInfoRemove"])
        print("- /dc hide, " .. DeathCounter.L["HelpInfoHide"])
        print("- /dc show, " .. DeathCounter.L["HelpInfoShow"])
    end
end