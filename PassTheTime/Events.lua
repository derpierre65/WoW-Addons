local _, PTT = ...

local Events = {}
PTT.Events = Events

Events.ACTIVE_SECONDS = 20
Events.MIN_DELAY = 180
Events.MAX_DELAY = 480
Events.MINIMUM_REWARD = 25

Events.definitions = {
	{ id = "merchant", nameKey = "eventMerchant", kind = "gold", minSeconds = 60, maxSeconds = 180 },
	{ id = "rare", nameKey = "eventRare", kind = "gold", minSeconds = 120, maxSeconds = 300 },
	{ id = "goblin", nameKey = "eventGoblin", kind = "buff", multiplier = 7, duration = 30 },
}

-- Not saved: a fresh timer on every login.
Events.countdown = nil
Events.active = nil

local listeners = { spawn = {}, finish = {}, claim = {} }

function Events.On(name, listener)
	table.insert(listeners[name], listener)
end

local function Fire(name, ...)
	for _, listener in ipairs(listeners[name]) do
		listener(...)
	end
end

local function ScheduleNext(random)
	Events.countdown = (random or math.random)(Events.MIN_DELAY, Events.MAX_DELAY)
end

function Events.Spawn(random)
	random = random or math.random
	Events.active = {
		definition = Events.definitions[random(#Events.definitions)],
		remaining = Events.ACTIVE_SECONDS,
	}
	Fire("spawn", Events.active)
end

-- Returns the message to show, or nil when nothing was active.
function Events.Claim(random)
	local active = Events.active
	if not active then
		return nil
	end

	random = random or math.random
	local definition = active.definition
	local name = PTT.L[definition.nameKey]
	local message

	if definition.kind == "gold" then
		local seconds = random(definition.minSeconds, definition.maxSeconds)
		local amount = math.max(PTT.Idle.GetIncome() * seconds, Events.MINIMUM_REWARD)
		PTT.Idle.AddGold(amount)
		message = string.format(PTT.L.eventGold, name, PTT.FormatNumber(amount))
	else
		PTT.Idle.AddBuff("event_" .. definition.id, definition.nameKey, definition.multiplier, definition.duration)
		message = string.format(PTT.L.eventBuff, name, definition.multiplier, definition.duration)
	end

	PTT.database.idle.eventsClaimed = PTT.database.idle.eventsClaimed + 1
	Events.active = nil
	Fire("claim", message)
	return message
end

function Events.Dismiss()
	if Events.active then
		Events.active = nil
		Fire("finish")
	end
end

function Events.Tick(dt, random)
	if not Events.countdown then
		ScheduleNext(random)
	end

	if Events.active then
		Events.active.remaining = Events.active.remaining - dt
		if Events.active.remaining <= 0 then
			Events.active = nil
			Fire("finish")
		end
		return
	end

	Events.countdown = Events.countdown - dt
	if Events.countdown <= 0 then
		ScheduleNext(random)
		Events.Spawn(random)
	end
end
