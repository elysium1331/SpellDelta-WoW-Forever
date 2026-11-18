local H = ...
local ns = {}
H.load("Locales/enUS.lua", ns)
H.load("SpellData.lua", ns)
H.load("SpellText.lua", ns)
H.load("Talents.lua", ns)
H.load("Predict.lua", ns)
local Talents, Predict = ns.Talents, ns.Predict

-- Ryan's priest, level 34, read in game on 2026-11-17 after a respec: naked, then shoulders
-- (+6 spell power), staff (+34), cloak (+3), with Twin Disciplines and Improved Power Word: Shield.
local RENEW, PAIN, STARSHARDS, SHIELD, HEAL = 6077, 2767, 19302, 6065, 6064
local TWIN, IMP_SHIELD = 1225132, 14748
local LEVEL = 34
-- Improved Power Word: Shield's own text: 7% at rank 1, 20% at rank 3.
local function Points(talentID, rank)
	if talentID == IMP_SHIELD then
		return ({ 7, 13, 20 })[rank] / 20
	end
	return nil
end

local function Bonuses(sp)
	return { h = sp, d = { [2] = sp, [3] = sp, [4] = sp, [5] = sp, [6] = sp, [7] = sp } }
end

local function Shown(spellID, coef, sp, ranks)
	return Talents.Shown(Talents.Value(spellID, coef, sp, LEVEL, ranks, nil, Points))
end

H.test("talents: which spells a talent touches comes from the game data", function()
	H.eq(Talents.Matches(ns.SpellData.talents[TWIN][3], ns.SpellData.families[RENEW]), true)
	H.eq(Talents.Matches(ns.SpellData.talents[TWIN][3], ns.SpellData.families[STARSHARDS]), true)
	H.eq(Talents.Matches(ns.SpellData.talents[TWIN][2], ns.SpellData.families[SHIELD]), false)
	H.eq(Talents.Matches(ns.SpellData.talents[TWIN][3], ns.SpellData.families[SHIELD]), false)
	H.eq(Talents.Matches(ns.SpellData.talents[TWIN][2], ns.SpellData.families[HEAL]), false)
	H.eq(Talents.Matches(ns.SpellData.talents[IMP_SHIELD][2], ns.SpellData.families[SHIELD]), true)
end)

H.test("talents: gear gains grow with whole-amount talents only", function()
	local twin3 = { [TWIN] = 3 }
	H.near(Talents.GearScale(RENEW, twin3), 1.03, 1e-9)
	H.near(Talents.GearScale(STARSHARDS, twin3), 1.03, 1e-9)
	H.near(Talents.GearScale(HEAL, twin3), 1, 1e-9)
	H.near(Talents.GearScale(SHIELD, { [IMP_SHIELD] = 3 }, nil, Points), 1, 1e-9)
end)

H.test("talents: exact numbers match every in-game reading", function()
	local none, twin1, twin3 = {}, { [TWIN] = 1 }, { [TWIN] = 3 }
	H.eq(Shown(RENEW, 1, 0, none), 205)
	H.eq(Shown(RENEW, 1, 6, none), 211)
	H.eq(Shown(RENEW, 1, 0, twin1), 207)
	H.eq(Shown(RENEW, 1, 0, twin3), 211)
	H.eq(Shown(RENEW, 1, 6, twin3), 217)
	H.eq(Shown(RENEW, 1, 40, twin3), 252)
	H.eq(Shown(RENEW, 1, 43, twin3), 255)
	H.eq(Shown(PAIN, 1.2, 0, none), 288)
	H.eq(Shown(PAIN, 1.2, 6, none), 295)
	H.eq(Shown(PAIN, 1.2, 0, twin1), 290)
	H.eq(Shown(PAIN, 1.2, 0, twin3), 296)
	H.eq(Shown(PAIN, 1.2, 34, twin3), 338)
	H.eq(Shown(PAIN, 1.2, 6, twin3), 304)
	H.eq(Shown(PAIN, 1.2, 40, twin3), 346)
	H.eq(Shown(PAIN, 1.2, 43, twin3), 349)
	H.eq(Shown(STARSHARDS, 1.002, 0, twin1), 769)
	H.eq(Shown(STARSHARDS, 1.002, 0, twin3), 784)
	-- Power Word: Shield grows with level (291 + 2.3 per level from 30): 300 at 34.
	H.eq(Shown(SHIELD, 0.1, 0, none), 300)
	H.eq(Shown(SHIELD, 0.1, 34, none), 303)
	H.eq(Shown(SHIELD, 0.1, 0, { [IMP_SHIELD] = 1 }), 321)
	H.eq(Shown(SHIELD, 0.1, 34, { [IMP_SHIELD] = 1 }), 324)
	H.eq(Shown(SHIELD, 0.1, 0, { [IMP_SHIELD] = 3 }), 360)
	H.eq(Shown(SHIELD, 0.1, 34, { [IMP_SHIELD] = 3 }), 363)
	H.eq(Shown(SHIELD, 0.1, 40, { [IMP_SHIELD] = 3 }), 364)
end)

-- A gear delta the way Talents.Attach builds it, for fixed talents.
local function Delta(sp, now, ranks)
	local delta = Bonuses(sp)
	delta.scale = function(spellID)
		return Talents.GearScale(spellID, ranks, nil, Points)
	end
	delta.now = Bonuses(now)
	delta.value = function(spellID, coef, bonus)
		return Talents.Value(spellID, coef, bonus, LEVEL, ranks, nil, Points)
	end
	return delta
end

local function RowsByName(spells, delta)
	local out = {}
	for _, row in ipairs(Predict.Rows(spells, delta, nil, true)) do
		out[row.name] = row
	end
	return out
end

H.test("talents: Alt rows on the staff match the game with Twin Disciplines 3/5", function()
	-- Naked: the game showed Renew 246 and Shadow Word: Pain 338 with the staff on.
	local rows = RowsByName({
		{ spellID = RENEW, name = "Renew", values = { 211, 15 } },
		{ spellID = PAIN, name = "Shadow Word: Pain", values = { 296, 18 } },
		{ spellID = HEAL, name = "Heal", values = { 611, 691 } },
	}, Delta(34, 0, { [TWIN] = 3 }))
	H.eq(rows["Renew"].after, 246)
	H.eq(rows["Renew"].change, 35)
	H.eq(rows["Shadow Word: Pain"].after, 338)
	H.eq(rows["Shadow Word: Pain"].change, 42)
	H.eq(rows["Heal"].change, 29)
	-- Shoulders on: 252 and 346.
	rows = RowsByName({
		{ spellID = RENEW, name = "Renew", values = { 217, 15 } },
		{ spellID = PAIN, name = "Shadow Word: Pain", values = { 304, 18 } },
	}, Delta(34, 6, { [TWIN] = 3 }))
	H.eq(rows["Renew"].after, 252)
	H.eq(rows["Shadow Word: Pain"].after, 346)
	-- The cloak (+3) with staff and shoulders on: 255 and 349 (the old addon said 350).
	rows = RowsByName({
		{ spellID = RENEW, name = "Renew", values = { 252, 15 } },
		{ spellID = PAIN, name = "Shadow Word: Pain", values = { 346, 18 } },
	}, Delta(3, 40, { [TWIN] = 3 }))
	H.eq(rows["Renew"].after, 255)
	H.eq(rows["Shadow Word: Pain"].after, 349)
	H.eq(rows["Shadow Word: Pain"].change, 3)
end)

H.test("talents: Improved Power Word: Shield leaves the gear part alone", function()
	local rows = RowsByName({ { spellID = SHIELD, name = "Power Word: Shield", values = { 360, 30, 15 } } },
		Delta(34, 0, { [IMP_SHIELD] = 3 }))
	H.eq(rows["Power Word: Shield"].after, 363)
	H.eq(rows["Power Word: Shield"].change, 3)
end)

H.test("talents: a number the data can't rebuild keeps the old rounding", function()
	-- 218 is not what the data gives (217), so the gain is added and rounded as before.
	local rows = RowsByName({ { spellID = RENEW, name = "Renew", values = { 218, 15 } } },
		Delta(34, 6, { [TWIN] = 3 }))
	H.eq(rows["Renew"].change, 35)
end)

local SPELLS = {
	{ spellID = RENEW, name = "Renew", values = { 211, 15 } },
	{ spellID = PAIN, name = "Shadow Word: Pain", values = { 295, 18 } },
	{ spellID = HEAL, name = "Heal", values = { 616, 697 } },
	{ spellID = SHIELD, name = "Power Word: Shield", values = { 300, 30, 15 } },
	{ spellID = STARSHARDS, name = "Starshards", values = { 768, 6 } },
}

H.test("talents: points not applied yet, shoulders on", function()
	local ctx = { bonuses = Bonuses(6), level = LEVEL, applied = {}, points = Points }
	local rows = Talents.Rows(SPELLS, {}, { [TWIN] = 3 }, ctx)
	local byName = {}
	for _, row in ipairs(rows) do
		byName[row.name] = row
	end
	H.eq(byName["Renew"].before, 211)
	H.eq(byName["Renew"].after, 217)
	H.eq(byName["Shadow Word: Pain"].after, 304)
	H.eq(byName["Starshards"].after, 791)
	H.eq(byName["Heal"], nil)
	H.eq(byName["Power Word: Shield"], nil)
	H.eq(rows[1].name, "Starshards") -- biggest change first
end)

H.test("talents: next rank on top of applied points", function()
	local spells = {
		{ spellID = RENEW, name = "Renew", values = { 217, 15 } },
		{ spellID = SHIELD, name = "Power Word: Shield", values = { 300, 30, 15 } },
	}
	local ctx = { bonuses = Bonuses(6), level = LEVEL, applied = { [TWIN] = 3 }, points = Points }
	local rows = Talents.Rows(spells, { [TWIN] = 3 }, { [TWIN] = 4 }, ctx)
	H.eq(#rows, 1)
	H.eq(rows[1].before, 217)
	H.eq(rows[1].after, 219)
	rows = Talents.Rows(spells, { [TWIN] = 3 }, { [TWIN] = 3, [IMP_SHIELD] = 1 }, ctx)
	H.eq(#rows, 1)
	H.eq(rows[1].name, "Power Word: Shield")
	H.eq(rows[1].after, 321)
end)

H.test("talents: without exact data, multiplying talents still work from the shown number", function()
	local ctx = { bonuses = Bonuses(6), level = LEVEL, applied = { [TWIN] = 3 }, points = Points }
	local after = Talents.ValueWith(RENEW, { 218, 15 }, { [TWIN] = 5 }, ctx)
	H.eq(after, 222)
end)

H.load("TalentTip.lua", ns)
local TalentTip = ns.TalentTip

H.test("talent tooltip: pending points first, then the next rank", function()
	local ctx = { bonuses = Bonuses(6), level = LEVEL, applied = {}, points = Points }
	local blocks = TalentTip.Blocks(TWIN, {}, { [TWIN] = 3 }, SPELLS, ctx)
	H.eq(#blocks, 2)
	H.eq(blocks[1].header, ns.L.TALENT_PENDING)
	H.eq(#blocks[1].rows, 3) -- Renew, Shadow Word: Pain, Starshards
	H.eq(blocks[2].header, ns.L.TALENT_NEXT:format(4, 5))
end)

H.test("talent tooltip: nothing pending, maxed, or no numbers", function()
	local ctx = { bonuses = Bonuses(6), level = LEVEL, applied = { [TWIN] = 5 }, points = Points }
	local blocks = TalentTip.Blocks(TWIN, { [TWIN] = 5 }, { [TWIN] = 5 }, SPELLS, ctx)
	H.eq(#blocks, 1)
	H.eq(blocks[1].text, ns.L.TALENT_MAXED)
	blocks = TalentTip.Blocks(12345, {}, {}, SPELLS, ctx)
	H.eq(blocks[1].text, ns.L.TALENT_NO_NUMBERS)
	blocks = TalentTip.Blocks(IMP_SHIELD, {}, {}, SPELLS, { bonuses = Bonuses(6), level = LEVEL, applied = {},
		points = Points })
	H.eq(blocks[1].header, ns.L.TALENT_NEXT:format(1, 3))
	H.eq(blocks[1].rows[1].name, "Power Word: Shield")
	H.eq(blocks[1].rows[1].after, 321)
end)

-- Melee and facts -----------------------------------------------------------------------
local AGGRESSION, OPPORTUNITY, IMP_MIND_BLAST, IMP_PAIN, MENTAL_AGILITY = 18427, 14057, 15273, 15275, 14520
local SINISTER, BACKSTAB, EVISCERATE, MIND_BLAST = 11294, 8721, 2098, 8104

H.test("talents: strikes and finishers take the ability's own talents", function()
	H.near(Talents.Whole(SINISTER, { [AGGRESSION] = 3 }), 1.02, 1e-9)
	H.near(Talents.Whole(BACKSTAB, { [OPPORTUNITY] = 5 }), 1.10, 1e-9)
	H.near(Talents.Whole(BACKSTAB, { [AGGRESSION] = 3 }), 1, 1e-9)
	local others = {
		{ spellID = SINISTER, name = "Sinister Strike", key = "Sinister Strike", raw = 100 },
		{ spellID = EVISCERATE, name = "Eviscerate", key = "Eviscerate", own = 50, apPart = 30, measured = true,
			points = 5 },
		{ spellID = RENEW, name = "Renew", key = "Renew" }, -- a spell row: handled by Talents.Rows
	}
	local rows = Talents.OtherRows(others, {}, { [AGGRESSION] = 3 }, { applied = {} })
	H.eq(#rows, 2)
	H.eq(rows[1].name, "Eviscerate") -- 80 -> 82 (+2) before Sinister Strike 100 -> 102 by name
	H.eq(rows[1].after, 82)
	H.eq(rows[2].after, 102)
	H.eq(rows[1].points, 5)
	-- With Aggression already applied, the finisher's own tooltip part has it; only new ranks count.
	rows = Talents.OtherRows({ others[2] }, { [AGGRESSION] = 3 }, { [AGGRESSION] = 3 }, { applied = { [AGGRESSION] = 3 } })
	H.eq(#rows, 0)
end)

H.test("talents: facts - cooldown, cost, duration and the longer damage over time", function()
	local live = function(spellID)
		if spellID == MIND_BLAST then
			return { cost = 225, cast = 1304, cooldown = 8 }
		end
		return { cost = 170 }
	end
	local spells = {
		{ spellID = MIND_BLAST, name = "Mind Blast", values = { 200, 210 } },
		{ spellID = RENEW, name = "Renew", values = { 205, 15 } },
		{ spellID = PAIN, name = "Shadow Word: Pain", values = { 288, 18 } },
	}
	local ctx = { applied = {}, bonuses = Bonuses(0), level = LEVEL }
	local rows = Talents.FactRows(spells, {}, { [IMP_MIND_BLAST] = 1 }, ctx, live)
	H.eq(#rows, 1)
	H.eq(rows[1].name, ns.L.FACT_COOLDOWN:format("Mind Blast"))
	H.near(rows[1].after, 7.5, 1e-9)
	H.eq(rows[1].unit, "sec")
	rows = Talents.FactRows(spells, {}, { [MENTAL_AGILITY] = 3 }, ctx, live)
	local cost
	for _, row in ipairs(rows) do
		if row.name == ns.L.FACT_COST:format("Renew") then
			cost = row
		end
	end
	H.eq(cost.before, 170)
	H.eq(cost.after, 153)
	rows = Talents.FactRows(spells, {}, { [IMP_PAIN] = 2 }, ctx, live)
	H.eq(rows[1].name, ns.L.FACT_DURATION:format("Shadow Word: Pain"))
	H.near(rows[1].after, 24, 1e-9)
	-- 6 ticks become 8: the whole number grows by a third.
	local numbers = Talents.Rows(spells, {}, { [IMP_PAIN] = 2 }, ctx)
	H.eq(numbers[1].name, "Shadow Word: Pain")
	H.eq(numbers[1].after, 384)
end)

H.test("talents: cast time keeps the player's haste", function()
	local D = {
		families = { [1] = { 6, 1, 0, 0, 0 } },
		casts = { [1] = 2500 },
		talents = { [9] = { 5, { "f", 10, -500, 6, 1, 0, 0, 0 } } },
		heads = {},
	}
	local rows = Talents.FactRows({ { spellID = 1, name = "Smite" } }, {}, { [9] = 5 },
		{ applied = {}, data = D }, function() return { cast = 2174 } end)
	H.eq(#rows, 1)
	H.near(rows[1].before, 2.174, 1e-9)
	H.near(rows[1].after, 2.0 * 2174 / 2500, 1e-9)
end)

H.test("talents: buttons like Inner Focus are not counted as lasting talents", function()
	H.eq(ns.SpellData.talents[14751], nil)
	H.truthy(ns.SpellData.talents[IMP_MIND_BLAST])
end)

-- Character-sheet talents, school damage, crit damage ------------------------------------
H.load("Gear.lua", ns)
H.load("Loadout.lua", ns)
H.load("Body.lua", ns)
local DARKNESS, MENTAL_STRENGTH, SHIELD_SPEC, TOUGHNESS, LETHALITY = 15259, 18551, 12298, 12299, 14128

H.test("talents: Darkness raises shadow damage spells, not heals", function()
	local ctx = { bonuses = Bonuses(0), level = LEVEL, applied = {} }
	local rows = Talents.Rows({
		{ spellID = PAIN, name = "Shadow Word: Pain", values = { 288, 18 } },
		{ spellID = RENEW, name = "Renew", values = { 205, 15 } },
	}, {}, { [DARKNESS] = 5 }, ctx)
	H.eq(#rows, 1)
	H.eq(rows[1].after, 316) -- 288 x 1.10 = 316.8, cut off
	-- Applied Darkness also makes gear worth more on shadow spells.
	H.near(Talents.GearScale(PAIN, { [DARKNESS] = 5 }), 1.10, 1e-9)
	H.near(Talents.GearScale(RENEW, { [DARKNESS] = 5 }), 1, 1e-9)
end)

local SNAP = {
	stats = { str = 24, agi = 34, sta = 33, int = 80, spi = 70 },
	mana = 1672, health = 928, armor = 105, block = 5, blockValue = 20, dodge = 6.3,
	fn = { intBreak = 20, manaPerInt = 15, staBreak = 20, hpPerSta = 10 },
}

local function StatByName(rows)
	local out = {}
	for _, row in ipairs(rows) do
		out[row.name] = row
	end
	return out
end

H.test("talents: Mental Strength shows Intellect and the mana it brings", function()
	local rows = StatByName(Talents.StatRows({}, { [MENTAL_STRENGTH] = 5 }, { snap = SNAP, applied = {} }))
	H.eq(rows["Intellect"].before, 80)
	H.eq(rows["Intellect"].after, 92)
	H.eq(rows["Mana"].after, 1672 + 180)
end)

H.test("talents: block chance, armor from items, and already-applied ranks", function()
	local rows = StatByName(Talents.StatRows({}, { [SHIELD_SPEC] = 5, [TOUGHNESS] = 1 },
		{ snap = SNAP, applied = {}, itemsArmor = 100 }))
	H.near(rows["Block chance"].after, 10, 1e-9)
	H.eq(rows["Armor"].after, 115)
	-- Mental Strength already applied: the shown Intellect has it; the next rank adds 3% of 80/1.12.
	rows = StatByName(Talents.StatRows({ [MENTAL_STRENGTH] = 4 }, { [MENTAL_STRENGTH] = 5 },
		{ snap = { stats = { int = 92 } }, applied = { [MENTAL_STRENGTH] = 4 } }))
	H.eq(rows["Intellect"].before, 92)
	H.eq(rows["Intellect"].after, 94) -- 92 / 1.12 x 1.15 = 94.5
end)

H.test("talents: crit damage for weapon attacks and spells", function()
	local spells = { { spellID = SINISTER, name = "Sinister Strike" } }
	local rows = Talents.FactRows(spells, {}, { [LETHALITY] = 2 }, { applied = {} }, function() return {} end)
	H.eq(rows[1].name, ns.L.FACT_CRIT_DAMAGE:format("Sinister Strike"))
	H.near(rows[1].before, 200, 1e-9)
	H.near(rows[1].after, 206, 1e-9)
end)
