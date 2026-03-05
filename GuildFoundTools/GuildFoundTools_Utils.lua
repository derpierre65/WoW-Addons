GuildFoundTools = GuildFoundTools or {}
GuildFoundTools.Utils = GuildFoundTools.Utils or {}

local debounceTimers = {}

function GuildFoundTools.Utils.CreatePool(parent, createFunction, releaseCallback)
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

function GuildFoundTools.Utils.Debounce(key, delay, callback)
	if debounceTimers[key] then
		debounceTimers[key]:Cancel()
		debounceTimers[key] = nil
	end

	debounceTimers[key] = C_Timer.NewTimer(delay, function()
		debounceTimers[key] = nil
		callback()
	end)
end
