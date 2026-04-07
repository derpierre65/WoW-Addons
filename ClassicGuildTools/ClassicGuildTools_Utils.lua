ClassicGuildTools = ClassicGuildTools or {}
ClassicGuildTools.Utils = ClassicGuildTools.Utils or {}

local _, _, _, interfaceVersion = GetBuildInfo()
interfaceVersion = interfaceVersion or 0

ClassicGuildTools.Utils.isEra = interfaceVersion < 20000
ClassicGuildTools.Utils.isTBC = interfaceVersion >= 20000 and interfaceVersion < 30000
ClassicGuildTools.Utils.isWotLK = interfaceVersion >= 30000 and interfaceVersion < 40000
ClassicGuildTools.Utils.isHardcore = C_GameRules and C_GameRules.IsHardcoreActive and C_GameRules.IsHardcoreActive() or false

local debounceTimers = {}

function ClassicGuildTools.Utils.CreatePool(parent, createFunction, releaseCallback)
	local pool = {}
	local active = {}

	return {
		Acquire = function()
			local row = table.remove(pool)
			if not row then
				row = createFunction(parent)
			end
			row:SetParent(parent)
			row:ClearAllPoints()
			row:Show()
			table.insert(active, row)
			return row
		end,
		ReleaseAll = function()
			for _, row in ipairs(active) do
				row:Hide()
				if releaseCallback then
					releaseCallback(row)
				end
				table.insert(pool, row)
			end
			wipe(active)
		end,
	}
end

function ClassicGuildTools.Utils.CompareVersions(versionA, versionB)
	local majorA, minorA, patchA = versionA:match("^(%d+)%.(%d+)%.(%d+)$")
	local majorB, minorB, patchB = versionB:match("^(%d+)%.(%d+)%.(%d+)$")

	if not majorA or not majorB then return 0 end

	majorA, minorA, patchA = tonumber(majorA), tonumber(minorA), tonumber(patchA)
	majorB, minorB, patchB = tonumber(majorB), tonumber(minorB), tonumber(patchB)

	if majorA ~= majorB then return majorA < majorB and -1 or 1 end
	if minorA ~= minorB then return minorA < minorB and -1 or 1 end
	if patchA ~= patchB then return patchA < patchB and -1 or 1 end

	return 0
end

function ClassicGuildTools.Utils.RequestGuildRoster()
	if GuildRoster then
		GuildRoster()
	elseif C_GuildInfo and C_GuildInfo.GuildRoster then
		C_GuildInfo.GuildRoster()
	end
end

function ClassicGuildTools.Utils.Debounce(key, delay, callback)
	if debounceTimers[key] then
		debounceTimers[key]:Cancel()
		debounceTimers[key] = nil
	end

	debounceTimers[key] = C_Timer.NewTimer(delay, function()
		debounceTimers[key] = nil
		callback()
	end)
end

