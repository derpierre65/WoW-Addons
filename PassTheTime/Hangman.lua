local _, PTT = ...

local Hangman = {}
PTT.Hangman = Hangman

Hangman.maxErrors = { easy = 8, medium = 6, hard = 4 }
Hangman.difficulties = { "easy", "medium", "hard" }

-- Word difficulty range each setting draws from. Falls back to the whole list when a category has no match.
local DIFFICULTY_RANGE = { easy = { 1, 2 }, medium = { 1, 3 }, hard = { 2, 3 } }
local HINT_DIFFICULTIES = { easy = true, medium = true }

-- Umlauts take two bytes, so letters are always split per UTF-8 character.
function Hangman.Split(text)
	local letters = {}
	for letter in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
		letters[#letters + 1] = letter
	end
	return letters
end

function Hangman.Length(text)
	return #Hangman.Split(text)
end

-- Capitals without umlauts: guesses and the word are compared in this form. string.upper leaves umlauts untouched.
function Hangman.Normalize(text)
	text = text:gsub("ä", "A"):gsub("ö", "O"):gsub("ü", "U"):gsub("Ä", "A"):gsub("Ö", "O"):gsub("Ü", "U"):gsub("ß", "SS")
	return text:upper()
end

local function IsGuessable(letter)
	return Hangman.Normalize(letter):match("^%u$") ~= nil
end

function Hangman.ShowsCategory(difficulty)
	return HINT_DIFFICULTIES[difficulty] == true
end

-- Languages with a word list; the name of each is localised as languageName_<code>.
Hangman.languages = { "deDE", "enUS" }

function Hangman.ResolveLanguage()
	local language = PTT.database.hangman.language
	if PTT.HangmanWords[language] then
		return language
	end
	return PTT.HangmanWords[PTT.locale] and PTT.locale or "enUS"
end

local function CollectEntries(language, category, difficulty)
	local range = DIFFICULTY_RANGE[difficulty] or DIFFICULTY_RANGE.medium
	local entries = {}

	for _, entry in ipairs(PTT.HangmanWords[language]) do
		local matchesCategory = category == "all" or category == entry.category
		if matchesCategory and entry.difficulty >= range[1] and entry.difficulty <= range[2] then
			entries[#entries + 1] = entry
		end
	end

	-- Sorting keeps a seeded random pick reproducible regardless of list order.
	table.sort(entries, function(left, right) return left.word < right.word end)
	return entries
end

function Hangman.NewGame(random)
	random = random or math.random
	local settings = PTT.database.hangman
	local language = Hangman.ResolveLanguage()

	local entries = CollectEntries(language, settings.category, settings.difficulty)
	if #entries == 0 then
		entries = CollectEntries(language, settings.category, "medium")
	end
	if #entries == 0 then
		settings.category = "all"
		entries = CollectEntries(language, "all", settings.difficulty)
	end

	local entry = entries[random(#entries)]
	Hangman.game = {
		word = entry.word,
		category = entry.category,
		difficulty = settings.difficulty,
		-- Guessed letters in the order they were tried.
		letters = {},
		-- Wrong whole-word guesses; they cost an error but reveal nothing.
		wrongWords = 0,
		state = "playing",
	}
	settings.game = Hangman.game
end

function Hangman.Load()
	local saved = PTT.database.hangman.game
	if type(saved) == "table" and type(saved.word) == "string" and type(saved.letters) == "table" and Hangman.maxErrors[saved.difficulty] then
		Hangman.game = saved
		return
	end
	Hangman.NewGame()
end

local function Contains(list, value)
	for _, entry in ipairs(list) do
		if entry == value then
			return true
		end
	end
	return false
end

function Hangman.GetMaxErrors()
	return Hangman.maxErrors[Hangman.game.difficulty]
end

function Hangman.GetErrors()
	local game = Hangman.game
	local base = Hangman.Normalize(game.word)
	local errors = game.wrongWords
	for _, letter in ipairs(game.letters) do
		if not base:find(letter, 1, true) then
			errors = errors + 1
		end
	end
	return errors
end

-- One entry per character of the word: the letter once revealed, "_" while hidden, special characters as they are.
function Hangman.GetDisplay()
	local game = Hangman.game
	local display = {}
	for index, letter in ipairs(Hangman.Split(game.word)) do
		if not IsGuessable(letter) or game.state ~= "playing" or Contains(game.letters, Hangman.Normalize(letter)) then
			display[index] = letter
		else
			display[index] = "_"
		end
	end
	return display
end

-- Guessed letters that are not in the word.
function Hangman.GetWrongLetters()
	local base = Hangman.Normalize(Hangman.game.word)
	local wrong = {}
	for _, letter in ipairs(Hangman.game.letters) do
		if not base:find(letter, 1, true) then
			wrong[#wrong + 1] = letter
		end
	end
	return wrong
end

function Hangman.IsGuessed(letter)
	return Contains(Hangman.game.letters, letter)
end

local function Finish(state)
	local game, settings = Hangman.game, PTT.database.hangman
	game.state = state
	settings.played = settings.played + 1
	if state == "won" then
		settings.won = settings.won + 1
		settings.streak = (settings.streak or 0) + 1
		settings.bestStreak = math.max(settings.bestStreak or 0, settings.streak)
	else
		settings.streak = 0
	end
end

local function AllLettersGuessed()
	local game = Hangman.game
	for _, letter in ipairs(Hangman.Split(Hangman.Normalize(game.word))) do
		if IsGuessable(letter) and not Contains(game.letters, letter) then
			return false
		end
	end
	return true
end

local function CheckLoss()
	if Hangman.GetErrors() >= Hangman.GetMaxErrors() then
		Finish("lost")
	end
end

-- Returns true, or false plus a short reason key.
function Hangman.GuessLetter(text)
	local game = Hangman.game
	if game.state ~= "playing" then
		return false, "finished"
	end

	local letter = Hangman.Normalize(text)
	if not letter:match("^%u$") then
		return false, "letters"
	end
	if Contains(game.letters, letter) then
		return false, "used"
	end

	game.letters[#game.letters + 1] = letter
	if AllLettersGuessed() then
		Finish("won")
	else
		CheckLoss()
	end
	return true
end

-- Spaces and punctuation are ignored when comparing, so "Mal'Ganis" matches "malganis".
function Hangman.GuessWord(text)
	local game = Hangman.game
	if game.state ~= "playing" then
		return false, "finished"
	end

	local function LettersOnly(value)
		return (Hangman.Normalize(value):gsub("[^%u]", ""))
	end

	local guess = LettersOnly(text)
	if guess == "" then
		return false, "letters"
	end

	if guess == LettersOnly(game.word) then
		Finish("won")
	else
		game.wrongWords = game.wrongWords + 1
		CheckLoss()
	end
	return true
end

PTT.OnInitialize(Hangman.Load)
