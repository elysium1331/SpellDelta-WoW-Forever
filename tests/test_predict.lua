local H = ...
local ns = {}
H.load("Locales/enUS.lua", ns)
H.load("SpellData.lua", ns)
H.load("Predict.lua", ns)
H.load("Gear.lua", ns)
local Predict, Gear = ns.Predict, ns.Gear

-- Ryan's priest (level 33), staff equipped. Tooltip numbers read in game 2026-11-14.
-- Spell IDs: Smite rank 4, Heal rank 3, Mind Blast rank 4, Power Word: Shield rank 5.
local SMITE, HEAL, MIND_BLAST, SHIELD = 984, 6063, 8104, 6065
local STAFF_SPELLS = {
	{ spellID = SMITE, name = "Smite", values = { 111, 120 } },
	{ spellID = HEAL, name = "Heal", values = { 595, 662 } },
	{ spellID = MIND_BLAST, name = "Mind Blast", values = { 187, 196 } },
	{ spellID = SHIELD, name = "Power Word: Shield", values = { 370, 30, 15 } },
	{ spellID = 586, name = "Fade", values = { 10 } },
}

-- The same tooltips with the mace and Raptor's Gaze: what the prediction must reach.
local MACE_MEASURED = { [SMITE] = 97.5, [HEAL] = 664.5, [MIND_BLAST] = 192.5, [SHIELD] = 374 }

-- Tooltip lines from Ryan's screenshot.
local STAFF_LINES = {
	"Glimmering Staff", "Soulbound", "Two-Hand", "32 - 49 Damage", "(18.4 damage per second)",
	"+11 Stamina", "+11 Intellect",
	"Equip: Increases damage and healing done by magical spells and effects by up to 34.",
	"Durability 100 / 100", "Requires Level 25",
}
local MACE_LINES = {
	"Death Speaker Scepter", "Soulbound", "Main Hand", "28 - 52 Damage",
	"Equip: Increases healing done by magical spells and effects by up to 68.",
	"Equip: Restores 12 Health per 5 sec.",
	"Equip: Increases damage done by Shadow spells and effects by up to 28.",
	"Durability 90 / 90", "Requires Level 28",
}
local GAZE_LINES = {
	"Raptor's Gaze", "Soulbound", "Held In Off-hand", "+4 Stamina", "+4 Intellect",
	"|cff1eff00Equip: Increases damage and healing done by magical spells and effects by up to 8.|r",
	"Requires Level 26",
}

H.test("data: Ryan's spells are in the generated game data", function()
	H.eq(ns.SpellData.spells[SMITE], "2:0.714*2")
	H.eq(ns.SpellData.spells[HEAL], "h:0.857*2")
	H.eq(ns.SpellData.spells[MIND_BLAST], "6:0.429*2")
	H.eq(ns.SpellData.spells[SHIELD], "h:0.1 0 0")
end)

H.test("data: only damage and healing numbers grow with bonuses", function()
	-- Resurrection carries a coefficient of 1 on its "resurrect" effect; the game ignores it.
	H.eq(ns.SpellData.spells[2010], nil, "Resurrection")
	H.eq(ns.SpellData.spells[10060], nil, "Power Infusion")
	H.eq(ns.SpellData.spells[589], "6:1.2 0", "Shadow Word: Pain")
	H.eq(ns.SpellData.spells[678], "0 2:0.429*2", "Holy Strike, a holy weapon strike")
end)

H.test("predict: slots parse pairs and fixed numbers", function()
	local slots, total = Predict.Slots(SHIELD)
	H.eq(total, 3)
	H.eq(slots[1].var, "h")
	H.near(slots[1].coef, 0.1, 1e-9)
	H.eq(slots[2].var, nil)
	local s2, t2 = Predict.Slots(SMITE)
	H.eq(t2, 2)
	H.eq(#s2, 1)
	H.eq(s2[1].var, 2)
	H.eq(s2[1].n, 2)
end)

H.test("gear: bonuses read from Ryan's three items", function()
	local staff, mace, gaze = Gear.ParseBonus(STAFF_LINES), Gear.ParseBonus(MACE_LINES), Gear.ParseBonus(GAZE_LINES)
	H.eq(staff.h, 34)
	H.eq(staff.d[2], 34)
	H.eq(staff.d[6], 34)
	H.eq(mace.h, 68)
	H.eq(mace.d[2], 0)
	H.eq(mace.d[6], 28)
	H.eq(gaze.h, 8)
	H.eq(gaze.d[3], 8)
end)

H.test("gear: other spell bonus wordings", function()
	local b = Gear.ParseBonus({
		"+13 Shadow Spell Damage", "+22 Healing Spells", "+5 Damage and Healing Spells",
		"Use: Increases damage and healing done by magical spells and effects by up to 100 for 20 sec.",
		"(2) Set: Increases damage and healing done by magical spells and effects by up to 12.",
		"Equip: Increases damage done by Fire spells and effects by up to 7.",
	})
	H.eq(b.d[6], 18)
	H.eq(b.d[3], 12)
	H.eq(b.d[2], 5)
	H.eq(b.h, 27)
end)

local function item(link, loc, lines)
	return { link = link, loc = loc, name = link, bonus = Gear.ParseBonus(lines) }
end
local STAFF = item("Glimmering Staff", "INVTYPE_2HWEAPON", STAFF_LINES)
local MACE = item("Death Speaker Scepter", "INVTYPE_WEAPONMAINHAND", MACE_LINES)
local GAZE = item("Raptor's Gaze", "INVTYPE_HOLDABLE", GAZE_LINES)

H.test("gear: hovering the off-hand pairs it with the mace, like the game does", function()
	local equipped = { [16] = STAFF }
	local plan = Gear.Plan(GAZE, equipped, function() return { MACE, GAZE } end)
	H.eq(plan.paired, MACE)
	H.eq(plan.changes[16], MACE)
	H.eq(plan.changes[17], GAZE)
	local delta = Gear.Delta(plan, equipped)
	H.eq(delta.h, 42)
	H.eq(delta.d[2], -26)
	H.eq(delta.d[6], 2)
	H.eq(table.concat(Gear.Replaced(plan, equipped), ","), "Glimmering Staff")
end)

H.test("gear: hovering the mace pairs it with the off-hand; same change", function()
	local equipped = { [16] = STAFF }
	local plan = Gear.Plan(MACE, equipped, { MACE, GAZE })
	H.eq(plan.paired, GAZE)
	local delta = Gear.Delta(plan, equipped)
	H.eq(delta.h, 42)
	H.eq(delta.d[6], 2)
end)

H.test("gear: the equipped item itself shows nothing; a staff replaces both hands", function()
	H.eq(Gear.Plan(STAFF, { [16] = STAFF }, {}), nil)
	local equipped = { [16] = MACE, [17] = GAZE }
	local plan = Gear.Plan(STAFF, equipped, {})
	H.eq(plan.changes[16], STAFF)
	H.eq(plan.changes[17], false)
	local delta = Gear.Delta(plan, equipped)
	H.eq(delta.h, -42)
	H.eq(table.concat(Gear.Replaced(plan, equipped), ","), "Death Speaker Scepter,Raptor's Gaze")
end)

H.test("gear: a ring replaces the weaker of two rings", function()
	local weak = item("Weak Ring", "INVTYPE_FINGER", { "+2 Healing Spells" })
	local strong = item("Strong Ring", "INVTYPE_FINGER", { "+20 Healing Spells" })
	local new = item("New Ring", "INVTYPE_FINGER", { "+10 Healing Spells" })
	local plan = Gear.Plan(new, { [11] = strong, [12] = weak }, {})
	H.eq(plan.changes[12], new)
	H.eq(Gear.Delta(plan, { [11] = strong, [12] = weak }).h, 8)
	H.eq(Gear.Plan(item("Shirt", "INVTYPE_NON_EQUIP", {}), {}, {}), nil)
end)

H.test("predict: staff -> mace and Raptor's Gaze matches Ryan's real tooltips", function()
	local delta = Gear.Delta(Gear.Plan(GAZE, { [16] = STAFF }, { MACE }), { [16] = STAFF })
	for _, s in ipairs(STAFF_SPELLS) do
		local p = Predict.Spell(s.spellID, s.values, delta)
		if MACE_MEASURED[s.spellID] then
			H.truthy(p, s.name)
			H.near(p.after, MACE_MEASURED[s.spellID], 1.0, s.name)
		else
			H.eq(p, nil, s.name)
		end
	end
end)

H.test("predict: a tooltip with a different number count predicts nothing", function()
	local p, why = Predict.Spell(SMITE, { 111 }, { d = { [2] = 10 }, h = 0 })
	H.eq(p, nil)
	H.eq(why, "count")
	local p2, why2 = Predict.Spell(586, { 10 }, { d = {}, h = 10 })
	H.eq(p2, nil)
	H.eq(why2, "unknown")
end)

H.test("predict: rows put healing first, then the biggest change", function()
	local delta = Gear.Delta(Gear.Plan(GAZE, { [16] = STAFF }, { MACE }), { [16] = STAFF })
	local rows, totals = Predict.Rows(STAFF_SPELLS, delta)
	local names = {}
	for i, row in ipairs(rows) do
		names[i] = row.name
	end
	H.eq(table.concat(names, ","), "Heal,Power Word: Shield,Smite,Mind Blast")
	H.eq(rows[1].before, 629)
	H.eq(rows[1].after, 665)
	H.eq(rows[3].before, 116)
	H.eq(rows[3].after, 97)
	H.eq(rows[4].change, 1)
	H.truthy(totals.h and totals[2] and totals[6], "totals per bonus")
end)

H.test("predict: pick keeps at most six, most-cast first, then the biggest change", function()
	local rows = {}
	for i = 1, 8 do
		rows[i] = { name = "S" .. i, change = i }
	end
	local picked = Predict.Pick(rows, { S1 = 5, S2 = 9 }, 6)
	H.eq(#picked, 6)
	H.eq(picked[1].name, "S2")
	H.eq(picked[2].name, "S1")
	H.eq(picked[3].name, "S8")
	H.eq(picked[6].name, "S5")
	H.eq(#rows, 8, "the full list is left as it was")
end)
