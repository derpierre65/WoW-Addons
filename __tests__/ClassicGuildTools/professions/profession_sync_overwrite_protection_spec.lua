require("__tests__.wow_stubs")
require("__tests__.acecomm_stubs")
require("ClassicGuildTools.ClassicGuildTools")
require("ClassicGuildTools.ClassicGuildTools_Enums")
require("ClassicGuildTools.ClassicGuildTools_Utils")
require("ClassicGuildTools.ClassicGuildTools_UI")
require("ClassicGuildTools.ClassicGuildTools_Professions")

_G['ClassicGuildToolsProfessions'] = _G['ClassicGuildToolsProfessions'] or {}

local MESSAGE_TYPE = ClassicGuildTools.MESSAGE_TYPE

describe("PROFESSION_ANSWER sync overwrite protection", function()
	local guildData

	before_each(function()
		ClassicGuildToolsProfessions["TestGuild-TestRealm"] = {}
		guildData = ClassicGuildToolsProfessions["TestGuild-TestRealm"]

		guildData["guid-remote"] = {
			[171] = { recipes = { 1001, 1002 }, rank = 250, maxRank = 300 },
		}
	end)

	it("should NOT overwrite existing data when incoming rank is 0", function()
		ClassicGuildTools.SendGuildMessage(MESSAGE_TYPE.PROFESSION_ANSWER, {
			guid = "guid-remote",
			professionId = 171,
			recipes = {},
			rank = 0,
			maxRank = 0,
		})

		local profession = guildData["guid-remote"][171]
		assert.equals(250, profession.rank)
		assert.equals(300, profession.maxRank)
		assert.equals(2, #profession.recipes)
		assert.equals(1001, profession.recipes[1])
		assert.equals(1002, profession.recipes[2])
	end)

	it("should overwrite existing data when incoming rank > 0", function()
		ClassicGuildTools.SendGuildMessage(MESSAGE_TYPE.PROFESSION_ANSWER, {
			guid = "guid-remote",
			professionId = 171,
			recipes = { 2001, 2002, 2003 },
			rank = 275,
			maxRank = 300,
		})

		local profession = guildData["guid-remote"][171]
		assert.equals(275, profession.rank)
		assert.equals(300, profession.maxRank)
		assert.equals(3, #profession.recipes)
		assert.equals(2001, profession.recipes[1])
	end)

	it("should write data when no existing entry exists, even with rank 0", function()
		ClassicGuildTools.SendGuildMessage(MESSAGE_TYPE.PROFESSION_ANSWER, {
			guid = "guid-new",
			professionId = 171,
			recipes = { 3001 },
			rank = 0,
			maxRank = 0,
		})

		local profession = guildData["guid-new"][171]
		assert.is_not_nil(profession)
		assert.equals(0, profession.rank)
		assert.equals(1, #profession.recipes)
	end)

	it("should overwrite when existing rank is 0 and incoming rank is 0", function()
		guildData["guid-remote"][171] = { recipes = { 1001 }, rank = 0, maxRank = 0 }

		ClassicGuildTools.SendGuildMessage(MESSAGE_TYPE.PROFESSION_ANSWER, {
			guid = "guid-remote",
			professionId = 171,
			recipes = { 4001, 4002 },
			rank = 0,
			maxRank = 0,
		})

		local profession = guildData["guid-remote"][171]
		assert.equals(2, #profession.recipes)
		assert.equals(4001, profession.recipes[1])
	end)

	it("should preserve other professions when one is skipped due to rank 0", function()
		guildData["guid-remote"][164] = { recipes = { 5001 }, rank = 150, maxRank = 300 }

		ClassicGuildTools.SendGuildMessage(MESSAGE_TYPE.PROFESSION_ANSWER, {
			guid = "guid-remote",
			professionId = 171,
			recipes = {},
			rank = 0,
			maxRank = 0,
		})

		assert.equals(250, guildData["guid-remote"][171].rank)
		assert.equals(150, guildData["guid-remote"][164].rank)
		assert.equals(1, #guildData["guid-remote"][164].recipes)
	end)
end)
