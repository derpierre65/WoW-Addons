-- AceComm-3.0 and AceSerializer-3.0 stubs for testing

-- AceSerializer: wraps messageType + data into a table, Deserialize unwraps it
local AceSerializer = {}

function AceSerializer:Serialize(messageType, data)
	return { messageType = messageType, data = data }
end

function AceSerializer:Deserialize(message)
	if type(message) ~= "table" or not message.messageType then
		return false
	end
	return true, message.messageType, message.data
end

-- AceComm: tracks RegisterComm callbacks and dispatches on SendCommMessage
local AceComm = {
	_callbacks = {},
}

function AceComm:RegisterComm(prefix, callback)
	self._callbacks[prefix] = self._callbacks[prefix] or {}
	table.insert(self._callbacks[prefix], callback)
end

function AceComm:SendCommMessage(prefix, message, distribution, target)
	local playerName = _G.UnitName("player")
	local shouldReceive = distribution == "GUILD" or (distribution == "WHISPER" and target == playerName)

	if shouldReceive and self._callbacks[prefix] then
		for _, callback in ipairs(self._callbacks[prefix]) do
			callback(prefix, message, distribution, playerName)
		end
	end
end

function AceComm:Embed() end

-- Register in LibStub
local originalLibStub = _G.LibStub
_G.LibStub = setmetatable({}, {
	__call = function(self, name, ...)
		if name == "AceComm-3.0" then
			return AceComm
		end
		if name == "AceSerializer-3.0" then
			return AceSerializer
		end
		return originalLibStub(name, ...)
	end,
})
