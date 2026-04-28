require("__tests__.wow_stubs")
require("__tests__.acecomm_stubs")
require("ClassicGuildTools.ClassicGuildTools")
require("ClassicGuildTools.ClassicGuildTools_Enums")
require("ClassicGuildTools.ClassicGuildTools_Utils")
require("ClassicGuildTools.ClassicGuildTools_UI")
require("ClassicGuildTools.ClassicGuildTools_Professions")

_G['ClassicGuildToolsProfessions'] = {}

describe("RebuildRecipeCache", function()
	local recipeCache
	local guildData

	before_each(function()
		recipeCache = ClassicGuildTools.Professions.recipeCache
		wipe(recipeCache)
		wipe(ClassicGuildTools.guildMemberCache)

		guildData = ClassicGuildToolsProfessions["TestGuild-TestRealm"]
		if guildData then wipe(guildData) end

		_G._testPlayersByGUID = {
			["guid-1"] = { name = "Alice" },
			["guid-2"] = { name = "Bob" },
			["guid-3"] = { name = "Charlie" },
		}

		-- Set up profession data for all players
		ClassicGuildToolsProfessions["TestGuild-TestRealm"] = {
			["guid-1"] = {
				[171] = { recipes = { 1001, 1002 }, rank = 300, maxRank = 300 },
			},
			["guid-2"] = {
				[171] = { recipes = { 1001 }, rank = 200, maxRank = 300 },
			},
			["guid-3"] = {
				[171] = { recipes = { 1003 }, rank = 100, maxRank = 300 },
			},
		}
	end)

	it("should include all players when guildMemberCache is empty", function()
        -- guildMemberCache is empty -> all players should be included
		ClassicGuildTools.Professions.RebuildRecipeCache()

		assert.is_not_nil(recipeCache[1001])
		assert.equals(2, #recipeCache[1001].players)

		assert.is_not_nil(recipeCache[1002])
		assert.equals(1, #recipeCache[1002].players)

		assert.is_not_nil(recipeCache[1003])
		assert.equals(1, #recipeCache[1003].players)
	end)

	it("should filter out players not in the guild when cache is populated", function()
		-- Only Alice and Bob are in the guild, Charlie left
		ClassicGuildTools.guildMemberCache["Alice"] = { online = true }
		ClassicGuildTools.guildMemberCache["Bob"] = { online = false }

		ClassicGuildTools.Professions.RebuildRecipeCache()

		-- Recipe 1001: Alice and Bob both have it
		assert.is_not_nil(recipeCache[1001])
		assert.equals(2, #recipeCache[1001].players)

		-- Recipe 1002: only Alice
		assert.is_not_nil(recipeCache[1002])
		assert.equals(1, #recipeCache[1002].players)
		assert.equals("Alice", recipeCache[1002].players[1].name)

		-- Recipe 1003: only Charlie had it, but he's not in guild
		assert.is_nil(recipeCache[1003])
	end)

	it("should set isOnline correctly based on guildMemberCache", function()
		ClassicGuildTools.guildMemberCache["Alice"] = { online = true }
		ClassicGuildTools.guildMemberCache["Bob"] = { online = false }

		ClassicGuildTools.Professions.RebuildRecipeCache()

		local players = recipeCache[1001].players
		local alice, bob

		for _, player in ipairs(players) do
			if player.name == "Alice" then alice = player end
			if player.name == "Bob" then bob = player end
		end

		assert.is_true(alice.isOnline)
		assert.is_false(bob.isOnline)
	end)

	it("should sort players: self first, then online, then by rank", function()
		_G._testPlayersByGUID["player-guid"] = { name = "TestPlayer" }
		ClassicGuildToolsProfessions["TestGuild-TestRealm"]["player-guid"] = {
			[171] = {
                recipes = {
                    1001
                },
                rank = 50,
                maxRank = 300,
            },
		}

		ClassicGuildTools.guildMemberCache["TestPlayer"] = { online = true }
		ClassicGuildTools.guildMemberCache["Alice"] = { online = true }
		ClassicGuildTools.guildMemberCache["Bob"] = { online = false }

		ClassicGuildTools.Professions.RebuildRecipeCache()

		local players = recipeCache[1001].players
		assert.equals(3, #players)

		-- Self (TestPlayer) first, then online (Alice, higher rank), then offline (Bob)
		assert.equals("TestPlayer", players[1].name)
		assert.equals("Alice", players[2].name)
		assert.equals("Bob", players[3].name)
	end)

	it("should call ScanProfessions and RebuildRecipeCache on PLAYER_LOGIN", function()
        local ScanProfessions = spy.on(ClassicGuildTools.Professions, "ScanProfessions")
        local RebuildRecipeCache = spy.on(ClassicGuildTools.Professions, "RebuildRecipeCache")

        _G.Test_SendEvent("PLAYER_LOGIN")
        assert.spy(ScanProfessions).was.called(1)
        assert.spy(RebuildRecipeCache).was.called(1)
        ScanProfessions:revert()
        RebuildRecipeCache:revert()
    end)
end)
