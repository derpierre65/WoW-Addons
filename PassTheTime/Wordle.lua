local _, PTT = ...

local MAX_ATTEMPTS = 6
local STATE_RANK = { absent = 1, present = 2, correct = 3 }

local Wordle = { maxAttempts = MAX_ATTEMPTS }
PTT.Wordle = Wordle

-- Umlauts take two bytes, so letters are always split per UTF-8 character.
function Wordle.Split(text)
	local letters = {}
	for letter in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
		letters[#letters + 1] = letter
	end
	return letters
end

function Wordle.Length(text)
	return #Wordle.Split(text)
end

-- string.upper leaves umlauts untouched.
function Wordle.Normalize(text)
	text = text:gsub("ä", "Ä"):gsub("ö", "Ö"):gsub("ü", "Ü"):gsub("ß", "SS")
	return text:upper()
end

function Wordle.Evaluate(guess, answer)
	local guessLetters, answerLetters = Wordle.Split(guess), Wordle.Split(answer)
	local length = #answerLetters
	local result, remaining = {}, {}

	for position = 1, length do
		local letter = answerLetters[position]
		if guessLetters[position] == letter then
			result[position] = "correct"
		else
			result[position] = "absent"
			remaining[letter] = (remaining[letter] or 0) + 1
		end
	end

	for position = 1, length do
		if result[position] == "absent" then
			local letter = guessLetters[position]
			if (remaining[letter] or 0) > 0 then
				result[position] = "present"
				remaining[letter] = remaining[letter] - 1
			end
		end
	end

	return result
end

-- Languages with a word list; the name of each is localised as languageName_<code>.
Wordle.languages = { "deDE", "enUS" }

function Wordle.ResolveLanguage()
	local language = PTT.database.wordle.language
	if PTT.WordleWords[language] then
		return language
	end
	return PTT.WordleWords[PTT.locale] and PTT.locale or "enUS"
end

-- length is "all" or a letter count.
local function CollectWords(language, category, length)
	local words = {}

	for wordLength, categories in pairs(PTT.WordleWords[language]) do
		if length == "all" or length == wordLength then
			for _, key in ipairs(PTT.WordleCategories) do
				if category == "all" or category == key then
					for _, word in ipairs(categories[key] or {}) do
						words[#words + 1] = word
					end
				end
			end
		end
	end

	-- pairs has no stable order; sorting keeps a seeded random pick reproducible.
	table.sort(words)
	return words
end

-- Sorted letter counts that have words in this language and category.
function Wordle.GetLengths(language, category)
	local lengths = {}

	for wordLength, categories in pairs(PTT.WordleWords[language]) do
		for _, key in ipairs(PTT.WordleCategories) do
			if (category == "all" or category == key) and #(categories[key] or {}) > 0 then
				lengths[#lengths + 1] = wordLength
				break
			end
		end
	end

	table.sort(lengths)
	return lengths
end

function Wordle.NewGame(random)
	random = random or math.random
	local settings = PTT.database.wordle
	local language = Wordle.ResolveLanguage()
	local length = settings.length or "all"

	local words = CollectWords(language, settings.category, length)
	if #words == 0 then
		settings.length = "all"
		words = CollectWords(language, settings.category, "all")
	end
	if #words == 0 then
		settings.category = "all"
		words = CollectWords(language, "all", "all")
	end

	Wordle.game = {
		word = words[random(#words)],
		guesses = {},
		state = "playing",
	}
	settings.game = Wordle.game
end

function Wordle.Load()
	local saved = PTT.database.wordle.game
	if type(saved) == "table" and type(saved.word) == "string" and type(saved.guesses) == "table" then
		Wordle.game = saved
		return
	end
	Wordle.NewGame()
end

-- Returns true, or false plus a short reason key.
function Wordle.Submit(text)
	local game = Wordle.game
	if game.state ~= "playing" then
		return false, "finished"
	end

	local guess = Wordle.Normalize(text)
	local asciiLetters = guess:gsub("Ä", ""):gsub("Ö", ""):gsub("Ü", "")
	if guess == "" or not asciiLetters:match("^%u*$") then
		return false, "letters"
	end

	if Wordle.Length(guess) ~= Wordle.Length(game.word) then
		return false, "length"
	end

	game.guesses[#game.guesses + 1] = guess

	local settings = PTT.database.wordle
	if guess == game.word then
		game.state = "won"
		settings.played = settings.played + 1
		settings.won = settings.won + 1
		settings.streak = (settings.streak or 0) + 1
		settings.bestStreak = math.max(settings.bestStreak or 0, settings.streak)
	elseif #game.guesses >= MAX_ATTEMPTS then
		game.state = "lost"
		settings.played = settings.played + 1
		settings.streak = 0
	end

	return true
end

-- Best known state per letter, for the on-screen keyboard.
function Wordle.GetLetterStates()
	local states = {}
	for _, guess in ipairs(Wordle.game.guesses) do
		local letters = Wordle.Split(guess)
		for position, state in ipairs(Wordle.Evaluate(guess, Wordle.game.word)) do
			local letter = letters[position]
			if not states[letter] or STATE_RANK[state] > STATE_RANK[states[letter]] then
				states[letter] = state
			end
		end
	end
	return states
end

PTT.OnInitialize(Wordle.Load)
