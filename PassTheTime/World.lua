local _, PTT = ...

local World = {}
PTT.World = World

-- Real actions in the world build up a small damage bonus that fades after a while.
World.MAX_STACKS = 10
World.BONUS_PER_STACK = 0.01
World.DURATION = 60

World.rewards = {
	kill = 0.5,
	loot = 1,
	skill = 3,
	quest = 5,
	level = 10,
}

World.labelKeys = {
	kill = "worldKill",
	loot = "worldLoot",
	skill = "worldSkill",
	quest = "worldQuest",
	level = "worldLevel",
}

-- A level-up also grants its own damage buff that lasts one minute per level.
World.LEVEL_BUFF_MULTIPLIER = 1.25

World.stacks = 0

-- Most recent action, shown in the side panel.
World.last = nil

function World.GetBonus()
	return World.stacks * World.BONUS_PER_STACK
end

function World.Credit(kind)
	World.stacks = math.min(World.MAX_STACKS, World.stacks + World.rewards[kind])
	World.last = { kind = kind, time = GetTime() }
	PTT.database.idle.worldBonuses = (PTT.database.idle.worldBonuses or 0) + 1
	PTT.Idle.AddBuff("world", "worldBonus", 1 + World.GetBonus(), World.DURATION)
end

function World.GrantLevelBuff(level)
	if type(level) == "number" and level >= 1 then
		PTT.Idle.AddBuff("levelUp", "buffLevelUp", World.LEVEL_BUFF_MULTIPLIER, level * 60)
	end
end

function World.Tick()
	if PTT.database.idle.buffs.world == nil then
		World.stacks = 0
	end
end

local function IsPlayer(guid)
	return guid ~= nil and guid == UnitGUID("player")
end

function World.RegisterEvents()
	local frame = CreateFrame("Frame")

	-- Not every client knows every event.
	-- The combat log event is forbidden to addons on newer clients, so kills are detected via XP messages.
	for _, event in ipairs({ "CHAT_MSG_COMBAT_XP_GAIN", "CHAT_MSG_LOOT", "CHAT_MSG_SKILL", "QUEST_TURNED_IN", "PLAYER_LEVEL_UP" }) do
		pcall(frame.RegisterEvent, frame, event)
	end

	frame:SetScript("OnEvent", function(_, event, ...)
		if event == "CHAT_MSG_COMBAT_XP_GAIN" then
			World.Credit("kill")
		elseif event == "CHAT_MSG_LOOT" then
			if IsPlayer(select(12, ...)) then
				World.Credit("loot")
			end
		elseif event == "CHAT_MSG_SKILL" then
			World.Credit("skill")
		elseif event == "QUEST_TURNED_IN" then
			World.Credit("quest")
		elseif event == "PLAYER_LEVEL_UP" then
			World.Credit("level")
			World.GrantLevelBuff(...)
		end
	end)
end
