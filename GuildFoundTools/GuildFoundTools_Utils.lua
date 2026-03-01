GuildFoundTools = GuildFoundTools or {}
GuildFoundTools.Utils = GuildFoundTools.Utils or {}

local debounceTimers = {}

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
