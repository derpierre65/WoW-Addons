require("__tests__.wow_stubs")
require("__tests__.acecomm_stubs")
require("ClassicGuildTools.ClassicGuildTools")
require("ClassicGuildTools.ClassicGuildTools_Enums")
require("ClassicGuildTools.ClassicGuildTools_Utils")
require("ClassicGuildTools.ClassicGuildTools_UI")
require("ClassicGuildTools.ClassicGuildTools_Professions")

_G['ClassicGuildToolsProfessions'] = _G['ClassicGuildToolsProfessions'] or {}

local MESSAGE_TYPE = ClassicGuildTools.MESSAGE_TYPE

describe("ScanProfessions removes professions that are no longer learned", function()
	local guildData
	local originalGetNumSkillLines
	local originalGetSkillLineInfo

	before_each(function()
		ClassicGuildToolsProfessions["TestGuild-TestRealm"] = {}
		guildData = ClassicGuildToolsProfessions["TestGuild-TestRealm"]

		-- Player previously had Alchemy (171) at 100 and Blacksmithing (164) at 250
		guildData["player-guid"] = {
			[171] = { recipes = {}, rank = 100, maxRank = 300 },
			[164] = { recipes = {}, rank = 250, maxRank = 300 },
		}

		originalGetNumSkillLines = _G.GetNumSkillLines
		originalGetSkillLineInfo = _G.GetSkillLineInfo

		-- Player now has Blacksmithing (164) at 250 and Enchanting (333) at 150.
		-- Alchemy (171) was dropped and replaced by Enchanting (333).
		_G.GetNumSkillLines = function() return 2 end
		_G.GetSkillLineInfo = function(index)
			if index == 1 then
				return "Spell2018", false, nil, 250, nil, nil, 300
			elseif index == 2 then
				return "Spell7411", false, nil, 150, nil, nil, 300
			end
		end
	end)

	after_each(function()
		_G.GetNumSkillLines = originalGetNumSkillLines
		_G.GetSkillLineInfo = originalGetSkillLineInfo
	end)

	it("should remove the dropped profession and keep/add the current ones", function()
		ClassicGuildTools.Professions.ScanProfessions()

		local professions = guildData["player-guid"]

		-- Old profession (Alchemy) must be gone
		assert.is_nil(professions[171])

		-- Kept profession (Blacksmithing) keeps its rank
		assert.is_not_nil(professions[164])
		assert.equals(250, professions[164].rank)
		assert.equals(300, professions[164].maxRank)

		-- New profession (Enchanting) is present with the new rank
		assert.is_not_nil(professions[333])
		assert.equals(150, professions[333].rank)
		assert.equals(300, professions[333].maxRank)
	end)
end)

describe("PROFESSION_ANSWER reconciles remote player's professions via allProfessionIds", function()
	local guildData

	before_each(function()
		ClassicGuildToolsProfessions["TestGuild-TestRealm"] = {}
		guildData = ClassicGuildToolsProfessions["TestGuild-TestRealm"]

		-- Remote player previously had Alchemy (171) at 100 and Blacksmithing (164) at 250
		guildData["guid-remote"] = {
			[171] = { recipes = { 1001 }, rank = 100, maxRank = 300 },
			[164] = { recipes = { 2001 }, rank = 250, maxRank = 300 },
		}
	end)

	it("should remove old profession when allProfessionIds no longer contains it", function()
		-- Remote player dropped Alchemy (171) and learned Enchanting (333) at 150.
		-- Sender broadcasts one PROFESSION_ANSWER per current profession,
		-- each carrying the full list of currently known profession IDs.
		ClassicGuildTools.SendGuildMessage(MESSAGE_TYPE.PROFESSION_ANSWER, {
			guid = "guid-remote",
			professionId = 164,
			recipes = { 2001 },
			rank = 250,
			maxRank = 300,
			allProfessionIds = { 164, 333 },
		})

		ClassicGuildTools.SendGuildMessage(MESSAGE_TYPE.PROFESSION_ANSWER, {
			guid = "guid-remote",
			professionId = 333,
			recipes = { 3001, 3002 },
			rank = 150,
			maxRank = 300,
			allProfessionIds = { 164, 333 },
		})

		local professions = guildData["guid-remote"]

		-- Old profession (Alchemy) must be gone
		assert.is_nil(professions[171])

		-- Kept profession (Blacksmithing) keeps its rank/recipes
		assert.is_not_nil(professions[164])
		assert.equals(250, professions[164].rank)
		assert.equals(300, professions[164].maxRank)
		assert.equals(1, #professions[164].recipes)
		assert.equals(2001, professions[164].recipes[1])

		-- New profession (Enchanting) is present with the new rank/recipes
		assert.is_not_nil(professions[333])
		assert.equals(150, professions[333].rank)
		assert.equals(300, professions[333].maxRank)
		assert.equals(2, #professions[333].recipes)
		assert.equals(3001, professions[333].recipes[1])
	end)

	it("should not remove anything when allProfessionIds is missing (backwards compat)", function()
		ClassicGuildTools.SendGuildMessage(MESSAGE_TYPE.PROFESSION_ANSWER, {
			guid = "guid-remote",
			professionId = 164,
			recipes = { 2001 },
			rank = 250,
			maxRank = 300,
		})

		assert.is_not_nil(guildData["guid-remote"][171])
		assert.equals(100, guildData["guid-remote"][171].rank)
	end)
end)
