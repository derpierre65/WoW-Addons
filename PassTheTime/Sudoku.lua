local _, PTT = ...

local Sudoku = {}
PTT.Sudoku = Sudoku

local SIZE, BOX, CELLS = 9, 3, 81

-- Clues left on the board. Fewer clues make a harder puzzle; every puzzle has exactly one solution.
Sudoku.difficulties = {
	{ id = "easy", clues = 40 },
	{ id = "medium", clues = 34 },
	{ id = "hard", clues = 28 },
	{ id = "expert", clues = 24 },
}

-- Replaced in tests. Takes the size of the range and returns an index in it.
Sudoku.random = math.random

local function GetSettings()
	return PTT.database.sudoku
end

function Sudoku.GetDifficulty(id)
	for _, difficulty in ipairs(Sudoku.difficulties) do
		if difficulty.id == id then
			return difficulty
		end
	end
	return Sudoku.difficulties[1]
end

function Sudoku.GetName(difficulty)
	return PTT.L["difficulty_" .. difficulty.id]
end

local function GetRow(index)
	return math.floor((index - 1) / SIZE) + 1
end

local function GetColumn(index)
	return (index - 1) % SIZE + 1
end

local function GetBox(index)
	return math.floor((GetRow(index) - 1) / BOX) * BOX + math.floor((GetColumn(index) - 1) / BOX) + 1
end

Sudoku.GetRow, Sudoku.GetColumn, Sudoku.GetBox = GetRow, GetColumn, GetBox

local peers = {}
for index = 1, CELLS do
	peers[index] = {}
	for other = 1, CELLS do
		if other ~= index and (GetRow(other) == GetRow(index) or GetColumn(other) == GetColumn(index) or GetBox(other) == GetBox(index)) then
			peers[index][#peers[index] + 1] = other
		end
	end
end

function Sudoku.GetPeers(index)
	return peers[index]
end

---------------------------------------------------------------------------
-- Solver and generator
---------------------------------------------------------------------------

local function NewUsed()
	local used = {}
	for group = 1, SIZE do
		used[group] = {}
	end
	return used
end

local function NewSearch(grid)
	local search = { grid = {}, rows = NewUsed(), columns = NewUsed(), boxes = NewUsed() }
	for index = 1, CELLS do
		local digit = grid[index]
		search.grid[index] = digit
		if digit ~= 0 then
			if search.rows[GetRow(index)][digit] or search.columns[GetColumn(index)][digit] or search.boxes[GetBox(index)][digit] then
				search.invalid = true
			end
			search.rows[GetRow(index)][digit] = true
			search.columns[GetColumn(index)][digit] = true
			search.boxes[GetBox(index)][digit] = true
		end
	end
	return search
end

local function Shuffle(list)
	for index = #list, 2, -1 do
		local other = Sudoku.random(index)
		list[index], list[other] = list[other], list[index]
	end
	return list
end

-- Counts solutions up to limit, always continuing with the empty cell that has the fewest candidates.
local function CountSolutions(search, limit, shuffleDigits)
	local bestIndex, bestCandidates
	for index = 1, CELLS do
		if search.grid[index] == 0 then
			local row, column, box = search.rows[GetRow(index)], search.columns[GetColumn(index)], search.boxes[GetBox(index)]
			local candidates = {}
			for digit = 1, SIZE do
				if not row[digit] and not column[digit] and not box[digit] then
					candidates[#candidates + 1] = digit
				end
			end

			if #candidates == 0 then
				return 0
			end
			if not bestCandidates or #candidates < #bestCandidates then
				bestIndex, bestCandidates = index, candidates
				if #candidates == 1 then
					break
				end
			end
		end
	end

	if not bestIndex then
		if not search.solution then
			search.solution = {}
			for index = 1, CELLS do
				search.solution[index] = search.grid[index]
			end
		end
		return 1
	end

	if shuffleDigits then
		Shuffle(bestCandidates)
	end

	local found = 0
	local row, column, box = search.rows[GetRow(bestIndex)], search.columns[GetColumn(bestIndex)], search.boxes[GetBox(bestIndex)]
	for _, digit in ipairs(bestCandidates) do
		search.grid[bestIndex] = digit
		row[digit], column[digit], box[digit] = true, true, true
		found = found + CountSolutions(search, limit - found, shuffleDigits)
		search.grid[bestIndex] = 0
		row[digit], column[digit], box[digit] = nil, nil, nil
		if found >= limit then
			break
		end
	end
	return found
end

local function EmptyGrid()
	local grid = {}
	for index = 1, CELLS do
		grid[index] = 0
	end
	return grid
end

-- A grid that breaks the rules has no solution.
function Sudoku.CountSolutions(grid, limit)
	local search = NewSearch(grid)
	if search.invalid then
		return 0
	end
	return CountSolutions(search, limit or 2, false)
end

function Sudoku.GenerateSolution()
	local search = NewSearch(EmptyGrid())
	CountSolutions(search, 1, true)
	return search.solution
end

-- Takes clues away in random order while the solution stays unique, until the wanted number is left.
function Sudoku.GeneratePuzzle(clues)
	local solution = Sudoku.GenerateSolution()
	local puzzle = {}
	for index = 1, CELLS do
		puzzle[index] = solution[index]
	end

	local order = {}
	for index = 1, CELLS do
		order[index] = index
	end
	Shuffle(order)

	local left = CELLS
	for _, index in ipairs(order) do
		if left <= clues then
			break
		end

		local digit = puzzle[index]
		puzzle[index] = 0
		if CountSolutions(NewSearch(puzzle), 2, false) == 1 then
			left = left - 1
		else
			puzzle[index] = digit
		end
	end
	return puzzle, solution
end

---------------------------------------------------------------------------
-- Game
---------------------------------------------------------------------------

function Sudoku.NewGame(difficultyId)
	local settings = GetSettings()
	local difficulty = Sudoku.GetDifficulty(difficultyId or settings.difficulty)
	settings.difficulty = difficulty.id

	local givens, solution = Sudoku.GeneratePuzzle(difficulty.clues)
	local entries = {}
	for index = 1, CELLS do
		entries[index] = 0
	end

	-- Stored in the saved variables as it is, so a half solved puzzle survives a reload.
	Sudoku.game = {
		difficulty = difficulty.id,
		givens = givens,
		solution = solution,
		entries = entries,
		notes = {},
		wrongMarks = {},
		state = "ready",
		mistakes = 0,
		hints = 0,
		elapsed = 0,
	}
	settings.game = Sudoku.game
	return Sudoku.game
end

local function IsValidSave(saved)
	if type(saved) ~= "table" or type(saved.givens) ~= "table" or type(saved.solution) ~= "table" or type(saved.entries) ~= "table" then
		return false
	end
	return #saved.givens == CELLS and #saved.solution == CELLS and #saved.entries == CELLS and type(saved.notes) == "table"
end

function Sudoku.Load()
	local saved = GetSettings().game
	if IsValidSave(saved) then
		saved.wrongMarks = saved.wrongMarks or {}
		Sudoku.game = saved
		return
	end
	Sudoku.NewGame()
end

function Sudoku.IsGiven(index)
	return Sudoku.game.givens[index] ~= 0
end

function Sudoku.GetValue(index)
	local game = Sudoku.game
	return game.givens[index] ~= 0 and game.givens[index] or game.entries[index]
end

-- Only cells the last verification found wrong are marked; editing a cell takes its mark away.
function Sudoku.IsWrong(index)
	return Sudoku.game.wrongMarks[index] == true
end

function Sudoku.IsComplete()
	for index = 1, CELLS do
		if Sudoku.GetValue(index) == 0 then
			return false
		end
	end
	return true
end

function Sudoku.GetNotes(index)
	return Sudoku.game.notes[index]
end

function Sudoku.CountDigit(digit)
	local count = 0
	for index = 1, CELLS do
		if Sudoku.GetValue(index) == digit then
			count = count + 1
		end
	end
	return count
end

local function Win(game)
	local settings = GetSettings()
	local seconds = math.max(1, math.floor(game.elapsed))

	game.state = "won"
	settings.won = settings.won + 1
	settings.wonBy[game.difficulty] = (settings.wonBy[game.difficulty] or 0) + 1
	if game.mistakes == 0 then
		settings.flawlessWins = settings.flawlessWins + 1
		if game.hints == 0 then
			settings.pureWins = settings.pureWins + 1
		end
	end
	if not settings.bestTimes[game.difficulty] or seconds < settings.bestTimes[game.difficulty] then
		settings.bestTimes[game.difficulty] = seconds
	end
end

local function StartIfReady(game)
	if game.state == "ready" then
		game.state = "playing"
		GetSettings().played = GetSettings().played + 1
	end
end

local function CanEdit(index)
	local game = Sudoku.game
	return game.state ~= "won" and not Sudoku.IsGiven(index)
end

-- A placed number takes the same note out of every cell that sees it.
local function ClearPeerNotes(game, index, digit)
	for _, peer in ipairs(peers[index]) do
		if game.notes[peer] then
			game.notes[peer][digit] = nil
		end
	end
end

function Sudoku.SetNumber(index, digit)
	local game = Sudoku.game
	if not CanEdit(index) or game.entries[index] == digit then
		return false
	end
	StartIfReady(game)

	game.entries[index] = digit
	game.notes[index] = nil
	game.wrongMarks[index] = nil
	ClearPeerNotes(game, index, digit)
	return true
end

function Sudoku.ClearCell(index)
	local game = Sudoku.game
	if not CanEdit(index) or (game.entries[index] == 0 and not game.notes[index]) then
		return false
	end

	game.entries[index] = 0
	game.notes[index] = nil
	game.wrongMarks[index] = nil
	return true
end

function Sudoku.ToggleNote(index, digit)
	local game = Sudoku.game
	if not CanEdit(index) or game.entries[index] ~= 0 then
		return false
	end
	StartIfReady(game)

	game.notes[index] = game.notes[index] or {}
	game.notes[index][digit] = not game.notes[index][digit] or nil
	if next(game.notes[index]) == nil then
		game.notes[index] = nil
	end
	return true
end

-- Fills in the correct number of one cell. A hint costs nothing on the clock but ends a hint-free win.
function Sudoku.Hint(index)
	local game = Sudoku.game
	if not CanEdit(index) or game.entries[index] == game.solution[index] then
		return false
	end
	StartIfReady(game)

	game.entries[index] = game.solution[index]
	game.notes[index] = nil
	game.wrongMarks[index] = nil
	game.hints = game.hints + 1
	ClearPeerNotes(game, index, game.solution[index])
	return true
end

-- Checks a full board. Returns true when it is solved, otherwise false and why: "incomplete" or "wrong" plus the number of wrong cells.
-- Every wrong cell counts as a mistake and stays marked until it is changed.
function Sudoku.Verify()
	local game = Sudoku.game
	if game.state == "won" or not Sudoku.IsComplete() then
		return false, "incomplete"
	end

	local wrong = 0
	for index = 1, CELLS do
		if Sudoku.GetValue(index) ~= game.solution[index] then
			wrong = wrong + 1
			game.wrongMarks[index] = true
		end
	end

	if wrong == 0 then
		Win(game)
		return true
	end

	game.mistakes = game.mistakes + wrong
	return false, "wrong", wrong
end

function Sudoku.Tick(deltaSeconds)
	local game = Sudoku.game
	if game.state == "playing" then
		game.elapsed = game.elapsed + deltaSeconds
	end
end

PTT.OnInitialize(Sudoku.Load)
