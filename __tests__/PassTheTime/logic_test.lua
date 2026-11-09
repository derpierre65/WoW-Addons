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
Load("PassTheTime/HangmanWords.lua")
Load("PassTheTime/Hangman.lua")

PTT.database = {
	game2048 = { score = 0, best = 0, wonShown = false },
	hangman = { language = "auto", category = "all", difficulty = "medium", played = 0, won = 0 },
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

-- Hangman helpers
local Hangman = PTT.Hangman

local function StartGame(word, difficulty)
	Hangman.game = { word = word, category = "cities", difficulty = difficulty or "medium", letters = {}, wrongWords = 0, state = "playing" }
	PTT.database.hangman.game = Hangman.game
end

local function Shown()
	return table.concat(Hangman.GetDisplay())
end

Check(Hangman.Normalize("Jäger") == "JAGER", "umlauts become their base letter")
Check(Hangman.Normalize("Fuß") == "FUSS", "sharp s normalized")
Check(Hangman.Length("JÄGER") == 5, "umlaut counts as one letter")
Check(#Hangman.Split("ÖÜ") == 2, "umlauts split per character")

-- Letter guesses
StartGame("MAGE")
Check(select(2, Hangman.GuessLetter("1")) == "letters", "non letters rejected")
Check(select(2, Hangman.GuessLetter("ab")) == "letters", "more than one letter rejected")
Check(Shown() == "____", "word starts hidden")
Check(Hangman.GuessLetter("m") and Shown() == "M___", "correct letter revealed")
Check(select(2, Hangman.GuessLetter("M")) == "used", "repeated letter rejected")
Check(Hangman.GetErrors() == 0, "correct letter costs nothing")
Check(Hangman.GuessLetter("x") and Hangman.GetErrors() == 1, "wrong letter costs an error")
Check(Hangman.GetWrongLetters()[1] == "X" and #Hangman.GetWrongLetters() == 1, "wrong letters listed")
Hangman.GuessLetter("g")
Hangman.GuessLetter("a")
Check(Hangman.game.state == "playing", "still playing with a letter missing")
Hangman.GuessLetter("e")
Check(Hangman.game.state == "won" and Shown() == "MAGE", "last letter wins")
Check(PTT.database.hangman.won == 1 and PTT.database.hangman.played == 1, "stats updated")
Check(PTT.database.hangman.streak == 1 and PTT.database.hangman.bestStreak == 1, "win starts a streak")
Check(select(2, Hangman.GuessLetter("z")) == "finished", "no guesses after finish")

-- Losing, per difficulty
StartGame("MAGE")
for _, letter in ipairs({ "X", "Y", "Z", "Q", "W" }) do
	Hangman.GuessLetter(letter)
end
Check(Hangman.game.state == "playing" and Hangman.GetErrors() == 5, "medium survives five errors")
Hangman.GuessLetter("K")
Check(Hangman.game.state == "lost" and PTT.database.hangman.played == 2, "medium loses on the sixth error")
Check(PTT.database.hangman.streak == 0 and PTT.database.hangman.bestStreak == 1, "loss resets the streak but keeps the best")
Check(Shown() == "MAGE", "word is revealed after a loss")

StartGame("MAGE", "hard")
for _, letter in ipairs({ "X", "Y", "Z", "Q" }) do
	Hangman.GuessLetter(letter)
end
Check(Hangman.game.state == "lost" and Hangman.GetMaxErrors() == 4, "hard loses on the fourth error")

StartGame("MAGE", "easy")
for _, letter in ipairs({ "X", "Y", "Z", "Q", "W", "K", "J" }) do
	Hangman.GuessLetter(letter)
end
Check(Hangman.game.state == "playing" and Hangman.GetMaxErrors() == 8, "easy survives seven errors")

StartGame("MAGE")
Hangman.GuessLetter("m")
Hangman.GuessLetter("a")
Hangman.GuessLetter("g")
Hangman.GuessLetter("e")
StartGame("MAGE")
Hangman.GuessLetter("m")
Hangman.GuessLetter("a")
Hangman.GuessLetter("g")
Hangman.GuessLetter("e")
Check(PTT.database.hangman.streak == 2 and PTT.database.hangman.bestStreak == 2, "streak grows and updates the best")

-- Whole-word guesses
StartGame("MAGE")
Check(select(2, Hangman.GuessWord("")) == "letters", "empty word rejected")
Check(Hangman.GuessWord("rest") and Hangman.GetErrors() == 1, "wrong word costs an error")
Check(Shown() == "____", "wrong word reveals no letter")
Check(Hangman.GuessWord("mage") and Hangman.game.state == "won", "right word wins")

StartGame("MAGE")
for _ = 1, 6 do
	Hangman.GuessWord("rest")
end
Check(Hangman.game.state == "lost", "wrong words can lose the game")

-- Special characters and umlauts
StartGame("MAL'GANIS")
Check(Shown() == "___'_____", "special characters are shown from the start")
Hangman.GuessLetter("m")
Check(Shown() == "M__'_____", "letters are revealed around special characters")
Check(Hangman.GuessWord("mal ganis") and Hangman.game.state == "won", "punctuation is ignored in a word guess")

StartGame("DÄMMERWALD")
Hangman.GuessLetter("a")
Check(Shown() == "_Ä_____A__", "a reveals the umlaut and the plain letter")
Check(Hangman.GuessLetter("Ä") == false, "umlaut key counts as its base letter")
StartGame("DÄMMERWALD")
Check(Hangman.GuessWord("dammerwald") and Hangman.game.state == "won", "word guess without umlauts is accepted")
StartGame("DÜSTERMOOR")
Check(Hangman.GuessWord("düstermoor") and Hangman.game.state == "won", "word guess with umlauts is accepted")

-- Hint
Check(Hangman.ShowsCategory("easy") and Hangman.ShowsCategory("medium"), "easy and medium show the category")
Check(not Hangman.ShowsCategory("hard"), "hard hides the category")

-- Word lists
local function WordsOf(language, category)
	local words = {}
	for _, entry in ipairs(PTT.HangmanWords[language]) do
		if entry.category == category then
			words[#words + 1] = entry
		end
	end
	return words
end

for language in pairs(PTT.HangmanWords) do
	for _, category in ipairs(PTT.HangmanCategories) do
		Check(#WordsOf(language, category) > 0, language .. " has " .. category)
		for _, entry in ipairs(WordsOf(language, category)) do
			local asciiLetters = entry.word:gsub("Ä", ""):gsub("Ö", ""):gsub("Ü", "")
			Check(asciiLetters:match("^%u+$") ~= nil, language .. "/" .. category .. " invalid word " .. entry.word)
			Check(entry.difficulty >= 1 and entry.difficulty <= 3, language .. " invalid difficulty " .. entry.word)
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

local settings = PTT.database.hangman

settings.language, settings.category = "enUS", "cities"
Hangman.NewGame()
Check(Contains(WordsOf("enUS", "cities"), Hangman.game.word), "new game honours category")
Check(settings.game == Hangman.game, "new game is stored for the next session")

settings.language = "deDE"
Hangman.NewGame()
Check(Contains(WordsOf("deDE", "cities"), Hangman.game.word), "new game honours language")

settings.language, settings.category = "enUS", "all"
settings.difficulty = "easy"
for _ = 1, 40 do
	Hangman.NewGame()
	Check(not Contains(WordsOf("enUS", "bosses"), Hangman.game.word), "easy draws no hard words")
	Check(Hangman.game.difficulty == "easy", "game keeps its difficulty")
end

settings.difficulty = "hard"
for _ = 1, 40 do
	Hangman.NewGame()
	Check(not Contains(WordsOf("enUS", "cities"), Hangman.game.word), "hard draws no easy words")
end

settings.category = "cities"
Hangman.NewGame()
Check(Contains(WordsOf("enUS", "cities"), Hangman.game.word), "empty difficulty pool falls back to the category")

-- A saved game survives a reload
settings.difficulty, settings.category = "medium", "all"
Hangman.NewGame()
local saved = Hangman.game
Hangman.game = nil
Hangman.Load()
Check(Hangman.game == saved, "saved game is restored")
settings.game = { word = "MAGE" }
Hangman.Load()
Check(Hangman.game ~= nil and Hangman.game.letters ~= nil, "unusable saved game is replaced")

print(failures == 0 and "ALL OK" or (failures .. " FAILURES"))
os.exit(failures == 0 and 0 or 1)
