local _, PTT = ...

-- Words are grouped by language, then letter count, then category, so the available lengths are easy to see.
-- Letters A-Z plus Ä, Ö, Ü (German only). Written in capitals, no spaces or apostrophes.
PTT.WordleCategories = { "cities", "zones", "bosses" }

PTT.WordleWords = {
	enUS = {
		[4] = {
			bosses = { "GARR", "OURO" },
		},
		[5] = {
			cities = { "BRILL" },
			bosses = { "GLUTH" },
		},
		[6] = {
			zones = { "ELWYNN", "UNGORO" },
			bosses = { "GOTHIK", "HAKKAR", "HEIGAN", "ONYXIA", "SKERAM" },
		},
		[7] = {
			cities = { "RATCHET" },
			zones = { "AZSHARA", "BARRENS", "DUROTAR", "FELWOOD", "FERALAS", "MULGORE", "TANARIS" },
			bosses = { "EBONROC", "FIREMAW", "HUHURAN", "LOATHEB", "MAEXXNA", "VENOXIS" },
		},
		[8] = {
			cities = { "BOOTYBAY", "DOLANAAR", "KHARANOS" },
			zones = { "BADLANDS", "DESOLACE", "DUSKWOOD", "REDRIDGE", "SILITHUS", "TIRISFAL", "WESTFALL" },
			bosses = { "FAERLINA", "FANKRISS", "FLAMEGOR", "GEHENNAS", "GOLEMAGG", "LUCIFRON", "MAGMADAR", "MANDOKIR", "NEFARIAN", "RAGNAROS", "SHAZZRAH", "THADDIUS", "VISCIDUS" },
		},
		[9] = {
			cities = { "ASTRANAAR", "DARNASSUS", "GADGETZAN", "GOLDSHIRE", "IRONFORGE", "LAKESHIRE", "ORGRIMMAR", "RAZORHILL", "STORMWIND", "THELSAMAR", "THERAMORE", "UNDERCITY" },
			zones = { "ASHENVALE", "DARKSHORE", "DUNMOROGH", "HILLSBRAD", "LOCHMODAN" },
			bosses = { "GROBBULUS", "KELTHUZAD", "PATCHWERK", "RAZORGORE", "RAZUVIOUS", "SAPPHIRON" },
		},
		[10] = {
			zones = { "SILVERPINE", "STONETALON", "TELDRASSIL" },
			bosses = { "CHROMAGGUS" },
		},
		[11] = {
			bosses = { "VAELASTRASZ" },
		},
		[12] = {
			cities = { "THUNDERBLUFF" },
			zones = { "WINTERSPRING" },
		},
		[13] = {
			zones = { "STRANGLETHORN" },
		},
	},
	deDE = {
		[4] = {
			bosses = { "GARR", "OURO" },
		},
		[5] = {
			cities = { "BRILL" },
			bosses = { "GLUTH" },
		},
		[6] = {
			zones = { "ELWYNN", "UNGORO" },
			bosses = { "GOTHIK", "HAKKAR", "HEIGAN", "ONYXIA", "SKERAM" },
		},
		[7] = {
			cities = { "RATCHET" },
			zones = { "AZSHARA", "DUROTAR", "FERALAS", "MULGORE", "TANARIS" },
			bosses = { "EBONROC", "FIREMAW", "HUHURAN", "LOATHEB", "MAEXXNA", "VENOXIS" },
		},
		[8] = {
			cities = { "DOLANAAR", "GOLDHAIN", "KHARANOS" },
			zones = { "DESOLACE", "SILITHUS", "TIRISFAL", "WESTFALL" },
			bosses = { "FAERLINA", "FANKRISS", "FLAMEGOR", "GEHENNAS", "GOLEMAGG", "LUCIFRON", "MAGMADAR", "MANDOKIR", "NEFARIAN", "RAGNAROS", "SHAZZRAH", "THADDIUS", "VISCIDUS" },
		},
		[9] = {
			cities = { "ASTRANAAR", "DARNASSUS", "GADGETZAN", "ORGRIMMAR", "STURMWIND", "THELSAMAR", "THERAMORE" },
			zones = { "BRACHLAND", "DUNMOROGH", "LOCHMODAN" },
			bosses = { "GROBBULUS", "KELTHUZAD", "PATCHWERK", "RAZORGORE", "RAZUVIOUS", "SAPPHIRON" },
		},
		[10] = {
			cities = { "BEUTEBUCHT", "DONNERFELS", "UNTERSTADT" },
			zones = { "ASCHENVALE", "DÄMMERWALD", "SILBERWALD", "TELDRASSIL" },
			bosses = { "CHROMAGGUS" },
		},
		[11] = {
			zones = { "DUNKELKÜSTE", "TEUFELSWALD", "WINTERQUELL" },
			bosses = { "VAELASTRASZ" },
		},
		[13] = {
			cities = { "EISENSCHMIEDE" },
		},
		[14] = {
			zones = { "ROTKAMMGEBIRGE" },
		},
		[16] = {
			zones = { "SCHLINGENDORNTAL" },
		},
	},
}
