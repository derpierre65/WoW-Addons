-- Run from the workspace root: lua __tests__/PassTheTime/logic_test.lua
local PTT = {}
local initializeCallbacks = {}

function PTT.OnInitialize(callback)
	initializeCallbacks[#initializeCallbacks + 1] = callback
end

local function Load(path)
	local chunk = assert(loadfile(path))
	chunk("PassTheTime", PTT)
end

Load("PassTheTime/Game2048.lua")
Load("PassTheTime/WordleWords.lua")
Load("PassTheTime/Wordle.lua")

PTT.database = {
	game2048 = { score = 0, best = 0, wonShown = false },
	wordle = { language = "auto", category = "all", played = 0, won = 0 },
}
for _, callback in ipairs(initializeCallbacks) do
	callback()
end

local failures = 0
local function Check(condition, message)
	if not condition then
		failures = failures + 1
		print("FAIL: " .. message)
	end
end

local function Equal(actual, expected, message)
	local same = #actual == #expected
	for index = 1, #expected do
		same = same and actual[index] == expected[index]
	end
	Check(same, message .. " (got " .. table.concat(actual, ",") .. ")")
end

-- 2048 slide
local Game = PTT.Game2048
local function Board(rows)
	local board = {}
	for _, row in ipairs(rows) do
		for _, value in ipairs(row) do
			board[#board + 1] = value
		end
	end
	return board
end

local board, moved, gained = Game.Slide(Board({ { 2, 2, 2, 2 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 } }), "left")
Equal({ table.unpack(board, 1, 4) }, { 4, 4, 0, 0 }, "2 2 2 2 left")
Check(moved and gained == 8, "gain 8")

board = Game.Slide(Board({ { 2, 2, 4, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 } }), "right")
Equal({ table.unpack(board, 1, 4) }, { 0, 0, 4, 4 }, "2 2 4 0 right")

board = Game.Slide(Board({ { 4, 2, 2, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 } }), "left")
Equal({ table.unpack(board, 1, 4) }, { 4, 4, 0, 0 }, "4 2 2 0 left merges once")

board = Game.Slide(Board({ { 2, 0, 0, 0 }, { 2, 0, 0, 0 }, { 4, 0, 0, 0 }, { 0, 0, 0, 0 } }), "up")
Equal({ board[1], board[5], board[9], board[13] }, { 4, 4, 0, 0 }, "column up")

board = Game.Slide(Board({ { 2, 0, 0, 0 }, { 2, 0, 0, 0 }, { 4, 0, 0, 0 }, { 0, 0, 0, 0 } }), "down")
Equal({ board[1], board[5], board[9], board[13] }, { 0, 0, 4, 4 }, "column down")

_, moved = Game.Slide(Board({ { 2, 4, 8, 16 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 } }), "left")
Check(not moved, "no move reported when nothing changes")

Check(not Game.CanMove(Board({ { 2, 4, 2, 4 }, { 4, 2, 4, 2 }, { 2, 4, 2, 4 }, { 4, 2, 4, 2 } })), "full board without merges is stuck")
Check(Game.CanMove(Board({ { 2, 2, 2, 4 }, { 4, 2, 4, 2 }, { 2, 4, 2, 4 }, { 4, 2, 4, 2 } })), "full board with merge can move")

-- 2048 game flow (deterministic random)
local random = function(limit)
	if limit then
		return 1
	end
	return 0.5
end
Game.Reset(random)
local tiles = 0
for index = 1, 16 do
	tiles = tiles + (Game.board[index] ~= 0 and 1 or 0)
end
Check(tiles == 2, "new game has two tiles")

local before = 0
for index = 1, 16 do before = before + Game.board[index] end
Game.Move("left", random)
Game.Move("up", random)
Game.Move("right", random)
Game.Move("down", random)
local after = 0
for index = 1, 16 do after = after + Game.board[index] end
Check(after >= before, "tiles never vanish")
Check(PTT.database.game2048.board == Game.board, "state saved")

-- 2048 stats
local playedBefore = PTT.database.game2048.played or 0
Game.score = 0
Game.Reset(random)
Check((PTT.database.game2048.played or 0) == playedBefore, "an untouched game is not counted")
Game.board = Game.NewBoard()
Game.board[1], Game.board[2] = 512, 512
Game.score = 40
Game.Move("left", random)
Check(PTT.database.game2048.highestTile == 1024, "highest tile tracked")
Game.Reset(random)
Check(PTT.database.game2048.played == playedBefore + 1, "a played game is counted on reset")
Check(PTT.database.game2048.highestTile == 1024, "highest tile survives a reset")

-- Wordle evaluate
local function Evaluate(guess, answer)
	return table.concat(PTT.Wordle.Evaluate(guess, answer), ",")
end
Check(Evaluate("ROGUE", "ROGUE") == "correct,correct,correct,correct,correct", "all correct")
Check(Evaluate("ABBEY", "KEBAB") == "present,present,correct,present,absent", "duplicate handling")
Check(Evaluate("LLAMA", "ALLOY") == "present,correct,present,absent,absent", "double letters 1")
Check(Evaluate("EEL", "TEE") == "present,correct,absent", "double letters 2")

-- Wordle flow
Check(PTT.Wordle.Normalize("Jäger") == "JÄGER", "umlaut kept and capitalised")
Check(PTT.Wordle.Length("JÄGER") == 5, "umlaut counts as one letter")
Check(#PTT.Wordle.Split("ÖÜ") == 2, "umlauts split per character")
Check(PTT.Wordle.Normalize("Fuß") == "FUSS", "sharp s normalized")

PTT.Wordle.game = { word = "MAGE", guesses = {}, state = "playing" }
PTT.database.wordle.game = PTT.Wordle.game
Check(select(2, PTT.Wordle.Submit("abc")) == "length", "wrong length rejected")
Check(select(2, PTT.Wordle.Submit("ab1d")) == "letters", "non letters rejected")
Check(#PTT.Wordle.game.guesses == 0, "rejected guesses are not stored")
Check(PTT.Wordle.Submit("gams"), "valid guess accepted")
Check(PTT.Wordle.GetLetterStates().G == "present", "letter state present")
Check(PTT.Wordle.Submit("mage") and PTT.Wordle.game.state == "won", "win detected")
Check(PTT.database.wordle.won == 1 and PTT.database.wordle.played == 1, "stats updated")
Check(PTT.database.wordle.streak == 1 and PTT.database.wordle.bestStreak == 1, "win starts a streak")
Check(select(2, PTT.Wordle.Submit("mage")) == "finished", "no guesses after finish")

PTT.Wordle.game = { word = "MAGE", guesses = {}, state = "playing" }
for _ = 1, 6 do
	PTT.Wordle.Submit("rest")
end
Check(PTT.Wordle.game.state == "lost" and PTT.database.wordle.played == 2, "loss after six attempts")
Check(PTT.database.wordle.streak == 0 and PTT.database.wordle.bestStreak == 1, "loss resets the streak but keeps the best")

PTT.Wordle.game = { word = "MAGE", guesses = {}, state = "playing" }
PTT.Wordle.Submit("mage")
PTT.Wordle.game = { word = "MAGE", guesses = {}, state = "playing" }
PTT.Wordle.Submit("mage")
Check(PTT.database.wordle.streak == 2 and PTT.database.wordle.bestStreak == 2, "streak grows and updates the best")

-- Word lists
local function WordsOf(language, category)
	local words = {}
	for length, categories in pairs(PTT.WordleWords[language]) do
		for _, word in ipairs(categories[category] or {}) do
			words[#words + 1] = { word = word, length = length }
		end
	end
	return words
end

for language in pairs(PTT.WordleWords) do
	for _, category in ipairs(PTT.WordleCategories) do
		Check(#WordsOf(language, category) > 0, language .. " has " .. category)
		for _, entry in ipairs(WordsOf(language, category)) do
			local asciiLetters = entry.word:gsub("Ä", ""):gsub("Ö", ""):gsub("Ü", "")
			Check(asciiLetters:match("^%u+$") ~= nil, language .. "/" .. category .. " invalid word " .. entry.word)
			Check(PTT.Wordle.Length(entry.word) == entry.length, language .. " word in wrong length group " .. entry.word)
		end
	end
end

local function Contains(entries, word)
	for _, entry in ipairs(entries) do
		if entry.word == word then
			return true
		end
	end
	return false
end

PTT.database.wordle.category = "cities"
PTT.Wordle.NewGame()
Check(Contains(WordsOf("enUS", "cities"), PTT.Wordle.game.word), "new game honours category")

PTT.database.wordle.language = "deDE"
PTT.Wordle.NewGame()
Check(Contains(WordsOf("deDE", "cities"), PTT.Wordle.game.word), "new game honours language")

PTT.database.wordle.category = "all"
PTT.database.wordle.length = 8
for _ = 1, 20 do
	PTT.Wordle.NewGame()
	Check(PTT.Wordle.Length(PTT.Wordle.game.word) == 8, "new game honours length")
end

PTT.database.wordle.length = 99
PTT.Wordle.NewGame()
Check(PTT.database.wordle.length == "all" and PTT.Wordle.game.word ~= nil, "unavailable length falls back to all")

local lengths = PTT.Wordle.GetLengths("deDE", "all")
Check(lengths[1] == 4 and lengths[#lengths] == 16, "German lengths span 4 to 16")
Check(#PTT.Wordle.GetLengths("enUS", "all") == 10, "English has ten lengths")

-- Umlaut words
PTT.database.wordle.length = "all"
PTT.Wordle.game = { word = "DÄMMERWALD", guesses = {}, state = "playing" }
Check(PTT.Wordle.Submit("dämmerwald") and PTT.Wordle.game.state == "won", "umlaut guess solves the word")
PTT.Wordle.game = { word = "DÄMMERWALD", guesses = {}, state = "playing" }
Check(PTT.Wordle.Submit("daemmerwald") == false, "ae is no longer an umlaut stand-in")
PTT.Wordle.Submit("DÜMMERWALD")
Check(PTT.Wordle.Evaluate("DÜMMERWALD", "DÄMMERWALD")[2] == "absent", "umlauts are compared as letters")
Check(PTT.Wordle.GetLetterStates()["Ü"] == "absent", "umlaut letter state tracked")

print(failures == 0 and "ALL OK" or (failures .. " FAILURES"))
os.exit(failures == 0 and 0 or 1)
