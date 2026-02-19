local _, DeathCounter = ...
DeathCounter.L = {}

if (GetLocale() == "deDE") then
    DeathCounter.L["Deaths"] = "Tode"
    DeathCounter.L["Death"] = "Tod"
    DeathCounter.L["HelpInfo"] = "Hilfe zu Death Counter:"
    DeathCounter.L["HelpInfoReset"] = "um den Counter zurückzusetzen."
    DeathCounter.L["HelpInfoSet"] = "um den Counter auf ein bestimmten Wert zu setzen."
    DeathCounter.L["HelpInfoAdd"] = "um dem Counter einen bestimmten Wert hinzuzufügen."
    DeathCounter.L["HelpInfoRemove"] = "um dem Counter einen bestimmten Wert abzuziehen."
    DeathCounter.L["HelpInfoHide"] = "um den Counter zu verstecken."
    DeathCounter.L["HelpInfoShow"] = "um den Counter anzuzeigen."
else
    DeathCounter.L["Deaths"] = "Deaths"
    DeathCounter.L["Death"] = "Death"
    DeathCounter.L["HelpInfo"] = "Help for Death Counter:"
    DeathCounter.L["HelpInfoReset"] = "to reset the counter."
    DeathCounter.L["HelpInfoSet"] = "to set the counter to count."
    DeathCounter.L["HelpInfoAdd"] = "to add value to counter."
    DeathCounter.L["HelpInfoRemove"] = "to remove value from counter."
    DeathCounter.L["HelpInfoHide"] = "to hide the counter."
    DeathCounter.L["HelpInfoShow"] = "to show the counter."
end