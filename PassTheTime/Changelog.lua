local _, PTT = ...

local Changelog = {}
PTT.Changelog = Changelog

-- Newest version first. Each version lists sections per locale, enUS is the fallback for other client languages.
Changelog.entries = {
	{
		version = "0.4.0",
		enUS = {
			{
				title = "New features",
				changes = {
					"New mini games: Snake, Blockfall and Spell Orbs.",
					"Sound effects for the mini games, they can be turned off in the settings.",
					"Realm leaderboard: compare your progress with everyone on your realm.",
					"Setup window on first start with a short tour and the most important settings.",
					"The window no longer has to close when entering combat, this can now be turned off in the settings.",
					"This changelog shows the changes after every update (/ptt changelog).",
				},
			},
			{
				title = "Mini games",
				changes = {
					"Hangman: the solve input is now above the keyboard.",
				},
			},
		},
		deDE = {
			{
				title = "Neue Funktionen",
				changes = {
					"Neue Minispiele: Snake, Blockfall und Zauberkugeln.",
					"Soundeffekte für die Minispiele, sie lassen sich in den Einstellungen abschalten.",
					"Realm-Rangliste: vergleiche deinen Fortschritt mit allen auf deinem Realm.",
					"Einrichtungsfenster beim ersten Start mit einer kurzen Einführung und den wichtigsten Einstellungen.",
					"Das Fenster muss sich bei Kampfbeginn nicht mehr schließen, das lässt sich jetzt in den Einstellungen abschalten.",
					"Dieses Änderungsprotokoll zeigt die Neuerungen nach jedem Update (/ptt changelog).",
				},
			},
			{
				title = "Minispiele",
				changes = {
					"Hangman: das Eingabefeld zum Lösen ist jetzt über der Tastatur.",
				},
			},
		},
	},
	{
		version = "0.3.0",
		enUS = {
			{
				title = "New features",
				changes = {
					"Auto button below the enemy: automatically moves on to the next enemy after each unlock. If a boss is not beaten in time, auto mode switches off and the previous enemy returns.",
					"Hero spells: every hero has spells to improve your stats.",
					"Achievements for every hero: one for the first spell, one for all spells bought.",
					"Damage milestones: from hero level 200, every 25 levels grants ×4 hero damage.",
					"The health bar shows the remaining health as a percentage.",
					"The enemy is now on the right, the lists and panels on the left.",
				},
			},
			{
				title = "Combat",
				changes = {
					"Damage is dealt every 0.2 seconds (DPS / 5 per hit). Kills pay gold and respawn the enemy immediately, even after the first hit.",
				},
			},
			{
				title = "Balance",
				changes = {
					"Hero cost growth reduced from 1.07 to 1.05 per level.",
					"Base damage raised: Warrior 0.05 -> 0.5, Rogue 0.5 -> 1, Shaman 4 -> 10, Hunter 24 -> 36, Mage 130 -> 200, Warlock 700 -> 1,100.",
					"Professions nerfed: Enchanting gives +2 s boss time per level (was +5 s), and every 25 levels a profession level costs one more soul.",
					"The doubling milestones were removed and replaced.",
				},
			},
			{
				title = "Mini games",
				changes = {
					"Wordle replaced by Hangman.",
					"Confirmation for unfinished games was added, to prevent losing progress.",
				},
			},
		},
		deDE = {
			{
				title = "Neue Funktionen",
				changes = {
					"Auto-Button unter dem Gegner: zieht nach jeder Freischaltung automatisch zum nächsten Gegner weiter. Wird ein Boss nicht rechtzeitig besiegt, schaltet sich der Auto-Modus ab und der vorherige Gegner kehrt zurück.",
					"Heldenzauber: jeder Held hat Zauber, die deine Werte verbessern.",
					"Erfolge für jeden Helden: einer für den ersten Zauber, einer für alle gekauften Zauber.",
					"Schadens-Meilensteine: ab Heldenlevel 200 gibt es alle 25 Level ×4 Heldenschaden.",
					"Der Lebensbalken zeigt das verbleibende Leben in Prozent.",
					"Der Gegner steht jetzt rechts, die Listen und Panels links.",
				},
			},
			{
				title = "Kampf",
				changes = {
					"Schaden wird alle 0,2 Sekunden verursacht (DPS / 5 pro Treffer). Kills bringen Gold und lassen den Gegner sofort neu erscheinen, auch nach dem ersten Treffer.",
				},
			},
			{
				title = "Balance",
				changes = {
					"Kostenanstieg der Helden von 1,07 auf 1,05 pro Level gesenkt.",
					"Grundschaden erhöht: Krieger 0,05 -> 0,5, Schurke 0,5 -> 1, Schamane 4 -> 10, Jäger 24 -> 36, Magier 130 -> 200, Hexenmeister 700 -> 1.100.",
					"Berufe abgeschwächt: Verzauberkunst gibt +2 s Bosszeit pro Level (vorher +5 s), und alle 25 Level kostet ein Berufslevel eine Seele mehr.",
					"Die Verdopplungs-Meilensteine wurden entfernt und ersetzt.",
				},
			},
			{
				title = "Minispiele",
				changes = {
					"Wordle wurde durch Hangman ersetzt.",
					"Nicht beendete Spiele fragen jetzt vor einem neuen Spiel nach, damit kein Fortschritt verloren geht.",
				},
			},
		},
	},
	{
		version = "0.2.0",
		enUS = {
			{
				title = "New",
				changes = {
					"Yahtzee mini game and 5 new achievements.",
				},
			},
			{
				title = "Changes",
				changes = {
					"Bosses now need 5 kills to unlock the next enemy.",
					"The progress bar towards the next unlock only shows on the newest unlocked enemy.",
					"Event popup is larger, with a pulsing border and a ready-check sound.",
					'Mini widget: clicking it attacks the enemy and a new "+" button opens the main window.',
				},
			},
		},
		deDE = {
			{
				title = "Neu",
				changes = {
					"Kniffel-Minispiel und 5 neue Erfolge.",
				},
			},
			{
				title = "Änderungen",
				changes = {
					"Bosse brauchen jetzt 5 Kills, um den nächsten Gegner freizuschalten.",
					"Der Fortschrittsbalken zur nächsten Freischaltung erscheint nur noch beim neuesten freigeschalteten Gegner.",
					"Das Event-Popup ist größer, mit pulsierendem Rand und Bereitschaftscheck-Sound.",
					'Mini-Widget: ein Klick greift den Gegner an, ein neuer "+"-Button öffnet das Hauptfenster.',
				},
			},
		},
	},
	{
		version = "0.1.0",
		enUS = {
			{ changes = { "First release." } },
		},
		deDE = {
			{ changes = { "Erste Veröffentlichung." } },
		},
	},
}

local function ParseVersion(version)
	local numbers = {}
	for number in tostring(version):gmatch("%d+") do
		table.insert(numbers, tonumber(number))
	end
	return numbers
end

-- Numeric per part, so 0.10.0 is newer than 0.9.0.
function Changelog.Compare(left, right)
	local leftNumbers, rightNumbers = ParseVersion(left), ParseVersion(right)
	for index = 1, math.max(#leftNumbers, #rightNumbers) do
		local leftNumber, rightNumber = leftNumbers[index] or 0, rightNumbers[index] or 0
		if leftNumber ~= rightNumber then
			return leftNumber < rightNumber and -1 or 1
		end
	end
	return 0
end

-- Entries newer than fromVersion up to and including toVersion, newest first. A nil bound is open.
function Changelog.GetBetween(fromVersion, toVersion)
	local entries = {}
	for _, entry in ipairs(Changelog.entries) do
		local isNewer = not fromVersion or Changelog.Compare(entry.version, fromVersion) > 0
		local isReleased = not toVersion or Changelog.Compare(entry.version, toVersion) <= 0
		if isNewer and isReleased then
			table.insert(entries, entry)
		end
	end
	return entries
end

function Changelog.GetSections(entry)
	return entry[PTT.locale] or entry.enUS
end
