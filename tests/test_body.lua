local H = ...
local ns = {}
H.load("Locales/enUS.lua", ns)
H.load("SpellData.lua", ns)
H.load("Measured.lua", ns)
H.load("Predict.lua", ns)
H.load("Gear.lua", ns)
H.load("Loadout.lua", ns)
H.load("Body.lua", ns)
local Gear, Body, Predict = ns.Gear, ns.Body, ns.Predict

local function item(link, loc, lines, class, sub)
	return { link = link, loc = loc, name = link, bonus = Gear.ParseBonus(lines), stats = Gear.ParseStats(lines),
		class = class, sub = sub }
end

-- A level 20 warrior: 2 attack power per Strength, 10 health per Stamina past the first 20.
local SWORD = item("Old Sword", "INVTYPE_2HWEAPON", { "40 - 60 Damage", "Speed 3.50" }, 2, 8)
local AXE = item("New Axe", "INVTYPE_2HWEAPON", { "50 - 80 Damage", "+10 Strength", "Speed 3.60" }, 2, 1)
local function Warrior(liveBase)
	return {
		class = "WARRIOR", level = 20,
		stats = { str = 100, agi = 50, sta = 80, int = 30 },
		ap = 200, melee = { base = liveBase or 100, bonus = 0, pct = 1 },
		health = 1000, mana = 0, crit = 5, dodge = 7.5, parry = 5, block = 0, armor = 1500, defense = 100,
		fn = {
			apFor = function(stat, v) return stat == 1 and v * 2 or 0 end,
			critFor = function(stat, v) return stat == 2 and v / 20 / 100 or 0 end,
			hpPerSta = 10, staBreak = 20, dodgeFromAgi = 0.025,
			armorEff = function(v) return v / (v + 400 + 85 * 20) end,
			apPerDps = 14,
		},
	}
end

H.test("gear: weapon damage, speed, ammo and attack power lines", function()
	local s = Gear.ParseStats({ "Bonecrusher", "Two-Hand", "40 - 60 Damage", "+5 - 10 Fire Damage",
		"(14.3 damage per second)", "+10 Strength", "Equip: +45 Attack Power when fighting Undead.",
		"Equip: +24 ranged Attack Power.", "Equip: +12 Attack Power.", "Speed 3.50", "Sword" })
	H.eq(s.wmin, 40)
	H.eq(s.wmax, 60)
	H.eq(s.speed, 3.5)
	H.eq(s.str, 10)
	H.eq(s.rap, 24)
	H.eq(s.ap, 12, "attack power against undead only is left out")
	H.eq(Gear.ParseStats({ "Adds 7.5 damage per second" }).ammodps, 7.5)
	H.eq(Body.Weapon(SWORD).kind, "twoHand")
	H.eq(Body.Weapon(item("Dirk", "INVTYPE_WEAPON", { "20 - 30 Damage", "Speed 1.80" }, 2, 15)).kind, "dagger")
	H.eq(Body.Weapon(item("Hat", "INVTYPE_HEAD", { "+3 Stamina" })), nil)
end)

H.test("data: attack-power abilities and weapon strikes come from the game data", function()
	H.eq(ns.SpellData.spells[402927], "ap:0.15 0 0", "Victory Rush: 15% of attack power")
	H.eq(ns.SpellData.strikes[11294], "m n+68", "Sinister Strike")
	H.eq(ns.SpellData.strikes[25300], "m n+150 *1.5", "Backstab")
	H.eq(ns.SpellData.strikes[25286], "m w+157", "Heroic Strike")
	H.eq(ns.SpellData.strikes[20904], "r n+350", "Aimed Shot")
	H.eq(ns.SpellData.strikes[678], nil, "Holy Strike grows with holy damage instead")
	H.truthy(Predict.Known(11294) and Predict.Known(402927) and not Predict.Known(871))
end)

H.test("body: strike damage follows the game's weapon formula", function()
	local live = { bonus = 0, pct = 1 }
	local dagger = { min = 20, max = 30, speed = 1.8, kind = "dagger" }
	-- Backstab: (25 + 140/14 * 1.7) * 1.5 + 150 * 1.5
	H.near(Body.StrikeValue("m n+150 *1.5", { w = dagger, ap = 140 }, live), 288, 0.001)
	-- Aimed Shot with a 3.0 bow and 5 dps arrows: 40 + 5*3 + 300/14*2.8 + 350
	local bow = { min = 30, max = 50, speed = 3.0, kind = "ranged" }
	H.near(Body.StrikeValue("r n+350", { w = bow, ap = 300, ammo = 5 }, live), 465, 0.001)
	-- Talents that raise physical damage by 5% (percent 1.05) scale the whole hit.
	H.near(Body.StrikeValue("m w+0", { w = dagger, ap = 0 }, { bonus = 0, pct = 1.05 }), 26.25, 0.001)
end)

H.test("body: a warrior's planned two-hander changes Mortal Strike and Heroic Strike", function()
	local worn = { [16] = SWORD }
	local delta = Body.Delta({ [16] = AXE }, worn, Warrior())
	H.eq(delta.ap, 20)
	local spells = {
		{ spellID = 21553, name = "Mortal Strike", values = { 50, 10, 160 } },
		{ spellID = 25286, name = "Heroic Strike", values = { 157 } },
		{ spellID = 402927, name = "Victory Rush", values = { 31, 10, 20 } },
		{ spellID = 871, name = "Shield Wall", values = { 75, 10 } },
	}
	local rows = Predict.Rows(spells, delta)
	local byName = {}
	for _, row in ipairs(rows) do
		byName[row.name] = row
	end
	H.eq(byName["Mortal Strike"].before, 257)
	H.eq(byName["Mortal Strike"].after, 277)
	H.eq(byName["Heroic Strike"].before, 257)
	H.eq(byName["Heroic Strike"].after, 279)
	H.eq(byName["Victory Rush"].change, 3, "15% of +20 attack power")
	H.eq(byName["Shield Wall"], nil, "gear does not change Shield Wall")
end)

H.test("body: no strikes when our weapon math disagrees with the game's", function()
	local delta = Body.Delta({ [16] = AXE }, { [16] = SWORD }, Warrior(120))
	local rows = Predict.Rows({ { spellID = 21553, name = "Mortal Strike", values = { 50, 10, 160 } } }, delta)
	H.eq(#rows, 0)
	-- Without a weapon in the plan there is nothing to strike with either.
	delta = Body.Delta({ [16] = false }, { [16] = SWORD }, Warrior())
	H.eq(#Predict.Rows({ { spellID = 21553, name = "Mortal Strike", values = { 50, 10, 160 } } }, delta), 0)
end)

H.test("body: health, attack power, crit, avoidance and armor from the game's stat functions", function()
	local d = Body.Derive(Warrior(), { str = 10, agi = 20, sta = 5, armor = -30, def = 2 })
	H.eq(d.health.change, 50)
	H.eq(d.health.plan, 1050)
	H.eq(d.ap.change, 20)
	H.near(d.crit.change, 1.0, 0.0001)
	H.near(d.dodge.change, 1.08, 0.0001, "1% from agility, 0.08% from defense")
	H.near(d.parry.change, 0.08, 0.0001)
	H.eq(d.block, nil, "no shield, no block line")
	H.eq(d.mana, nil, "warriors have no mana")
	H.eq(d.armor.change, 10, "-30 armor, +40 from agility")
	H.truthy(d.reduction.change > 0)
	H.eq(d.defense.change, 2)
	local rows = Body.StatRows(d, ns.L.DERIVED)
	H.eq(rows[1].name, "Health")
	H.eq(rows[1].key, "stat:health")
	-- A missing game function leaves its line out instead of guessing.
	local snap = Warrior()
	snap.fn.apFor = nil
	H.eq(Body.Derive(snap, { str = 10 }).ap, nil)
	H.eq(Body.Derive(snap, { sta = 1 }).ap.change, 0, "no strength change needs no function")
end)

H.test("body: a chosen stat line can be picked for item tooltips", function()
	local d = Body.Derive(Warrior(), { sta = 5 })
	local rows = Body.StatRows(d, ns.L.DERIVED)
	local spellRow = { spellID = 1, name = "Heroic Strike", key = "Heroic Strike", change = 3 }
	rows[#rows + 1] = spellRow
	local auto = Predict.Pick(rows, {}, 6)
	H.eq(auto[1].name, "Heroic Strike", "spells first")
	H.eq(auto[2].name, "Health", "then stat lines fill free spots")
	H.eq(#Predict.Pick(rows, {}, 1), 1, "stat lines never push out a spell")
	H.eq(Predict.Pick(rows, {}, 1)[1].name, "Heroic Strike")
	local picked = Predict.Pick(rows, {}, 6, { "stat:health", "Heroic Strike" })
	H.eq(picked[1].name, "Health")
	H.eq(picked[2].name, "Heroic Strike")
end)

H.test("data: percent-of-weapon, off-hand, both-hand, attack-power share and block value abilities", function()
	local s = ns.SpellData.strikes
	H.eq(s[14251], "m w+0 *1.5", "Riposte")
	H.eq(s[19503], "r w+0 *0.5", "Scatter Shot")
	H.eq(s[403196], "m w+0 *1.5", "Devastate")
	H.eq(s[424799], "o w+0", "Shiv")
	H.eq(s[1680], "b n+0", "Whirlwind")
	H.eq(s[1241590], "b n+88 *0.9", "Mutilate")
	H.eq(s[23894], "a 0.45+48", "Bloodthirst")
	H.eq(s[399986], "a 0.5+0", "Shuriken Toss")
	H.eq(s[23925], "k 655", "Shield Slam")
end)

local function rowsFor(spells, delta)
	local byName = {}
	for _, row in ipairs(Predict.Rows(spells, delta)) do
		byName[row.name] = row
	end
	return byName
end

H.test("body: Bloodthirst, Whirlwind with a two-hander, and Shield Slam", function()
	local rows = rowsFor({
		{ spellID = 23894, name = "Bloodthirst", values = { 45, 48, 10, 8 } },
		{ spellID = 1680, name = "Whirlwind", values = { 4, 8 } },
	}, Body.Delta({ [16] = AXE }, { [16] = SWORD }, Warrior()))
	H.eq(rows.Bloodthirst.before, 138, "45% of 200 plus 48")
	H.eq(rows.Bloodthirst.after, 147)
	H.eq(rows.Whirlwind.before, 97, "no off-hand weapon: the main-hand hit")
	H.eq(rows.Whirlwind.after, 117)

	local blade = item("Blade", "INVTYPE_WEAPONMAINHAND", { "30 - 50 Damage", "Speed 2.60" }, 2, 7)
	local buckler = item("Buckler", "INVTYPE_SHIELD", { "800 Armor", "20 Block" }, 4, 6)
	local tower = item("Tower Shield", "INVTYPE_SHIELD", { "1200 Armor", "30 Block" }, 4, 6)
	local snap = Warrior(40 + 200 / 14 * 2.6)
	snap.block, snap.blockValue = 5, 30
	rows = rowsFor({ { spellID = 23925, name = "Shield Slam", values = { 1, 627, 683 } } },
		Body.Delta({ [17] = tower }, { [16] = blade, [17] = buckler }, snap))
	H.eq(rows["Shield Slam"].before, 685, "655 plus block value 30")
	H.eq(rows["Shield Slam"].after, 695)
	-- Without a shield in the plan there is no Shield Slam.
	rows = rowsFor({ { spellID = 23925, name = "Shield Slam", values = { 1, 627, 683 } } },
		Body.Delta({ [17] = false }, { [16] = blade, [17] = buckler }, snap))
	H.eq(rows["Shield Slam"], nil)
end)

H.test("body: off-hand strikes use the game's own off-hand reduction", function()
	local main = item("Main Dirk", "INVTYPE_WEAPON", { "20 - 30 Damage", "Speed 1.80" }, 2, 15)
	local off = item("Old Dirk", "INVTYPE_WEAPON", { "10 - 20 Damage", "Speed 1.40" }, 2, 15)
	local newOff = item("New Dirk", "INVTYPE_WEAPON", { "20 - 30 Damage", "Speed 1.50" }, 2, 15)
	local snap = {
		class = "ROGUE", stats = { str = 50, agi = 90 }, ap = 140,
		melee = { base = 43, bonus = 0, pct = 1 }, offhand = { base = 14.5, bonus = 0, pct = 1 },
		fn = { apFor = function() return 0 end, apPerDps = 14 },
	}
	local rows = rowsFor({
		{ spellID = 424799, name = "Shiv", values = { 1 } },
		{ spellID = 1241590, name = "Mutilate", values = {} },
	}, Body.Delta({ [17] = newOff }, { [16] = main, [17] = off }, snap))
	H.eq(rows.Shiv.before, 15, "half of 15 + 140/14 * 1.4")
	H.eq(rows.Shiv.change, 6, "14.5 to 20: the change is rounded on its own")
	H.eq(rows.Mutilate.before, 211, "both hands: 117 + 93.6")
	-- An off-hand reading the game would never give is not trusted.
	snap.offhand.base = 2
	rows = rowsFor({ { spellID = 424799, name = "Shiv", values = { 1 } } },
		Body.Delta({ [17] = newOff }, { [16] = main, [17] = off }, snap))
	H.eq(rows.Shiv, nil)
end)

H.test("measured: Eviscerate adds the players' 3% of attack power per combo point", function()
	local delta = Body.Delta({ [16] = AXE }, { [16] = SWORD }, Warrior())
	local values = { 1, 6, 11, 2, 12, 17, 3, 18, 23, 4, 24, 29, 5, 30, 35 }
	local rows = Predict.Rows({ { spellID = 31016, name = "Eviscerate", values = values } }, delta)
	H.eq(#rows, 1)
	H.eq(rows[1].before, 63, "5 points: 32.5 from the tooltip + 0.15 x 200 attack power")
	H.eq(rows[1].change, 3, "+20 attack power x 0.15")
	H.truthy(rows[1].measured)
	H.eq(Predict.Label(rows[1]), "Eviscerate (5 pts)*")
	H.truthy(Predict.Known(31016))
	H.eq(ns.Measured[2025], nil)
	local groups = Predict.Groups({ { spellID = 31016, name = "Eviscerate" } })
	H.eq(groups[1].var, "ap")
	H.eq(Predict.Measured(31016, {}, delta), nil, "no tooltip numbers: nothing shown")
end)

H.test("measured: Shield of Righteousness adds 2.2 x block value plus 20, only with a shield", function()
	local snap = Warrior()
	snap.block, snap.blockValue = 5, 40
	local old = item("Old Shield", "INVTYPE_SHIELD", { "400 Armor" }, 4, 6)
	local new = item("New Shield", "INVTYPE_SHIELD", { "500 Armor", "10 Block", "+20 Strength" }, 4, 6)
	local sor = { { spellID = 440658, name = "Shield of Righteousness", values = { 100 } } }
	local rows = Predict.Rows(sor, Body.Delta({ [17] = new }, { [17] = old }, snap))
	H.eq(rows[1].before, 208, "100 from the tooltip + 20 + 2.2 x 40")
	H.eq(rows[1].change, 24, "11 more block value x 2.2")
	H.eq(rows[1].points, nil)
	local none = Predict.Rows(sor, Body.Delta({ [17] = false }, { [17] = old }, snap))
	H.eq(#none, 0, "no shield planned: nothing shown")
end)

H.test("druid forms: the game's form damage decides whether the weapon counts", function()
	local oldStaff = item("Old Staff", "INVTYPE_2HWEAPON", { "40 - 60 Damage", "Speed 3.00" }, 2, 10)
	local newStaff = item("New Staff", "INVTYPE_2HWEAPON", { "60 - 90 Damage", "Speed 3.00" }, 2, 10)
	local claw = { { spellID = 1082, name = "Claw", values = { 1 } } }
	-- Rule 1: weapon DPS x 1.0 sec + 200 / 14 x 1.0 = 30.95 matches the game's cat damage.
	local snap = Warrior(30.95)
	snap.class, snap.feral, snap.formSpeed = "DRUID", "cat", 1.0
	local rows = Predict.Rows(claw, Body.Delta({ [16] = newStaff }, { [16] = oldStaff }, snap))
	H.eq(rows[1].change, 12, "(25 - 16.7) DPS x 1.0 sec x 140%")
	H.eq(rows[1].measured, nil)
	-- Rule 2: the game's damage doesn't fit, so the weapon is left out; attack power still counts.
	snap = Warrior(50)
	snap.class, snap.feral, snap.formSpeed = "DRUID", "cat", 1.0
	rows = Predict.Rows(claw, Body.Delta({ [16] = newStaff }, { [16] = oldStaff }, snap))
	H.eq(#rows, 0, "a weapon swap alone changes nothing")
	local strong = item("Strong Staff", "INVTYPE_2HWEAPON", { "40 - 60 Damage", "+10 Strength", "Speed 3.00" }, 2, 10)
	rows = Predict.Rows(claw, Body.Delta({ [16] = strong }, { [16] = oldStaff }, snap))
	H.eq(rows[1].change, 2, "+20 attack power / 14 x 1.0 sec x 140%")
	H.truthy(rows[1].measured)
	H.eq(Predict.Label(rows[1]), "Claw*")
end)

H.test("gear: attack power in forms only counts in Cat or Bear Form", function()
	local s = Gear.ParseStats({ "Equip: +100 Attack Power in Cat, Bear, Dire Bear, and Moonkin forms only." })
	H.eq(s.feralap, 100)
	H.eq(s.ap, nil)
	local staff = item("Feral Staff", "INVTYPE_2HWEAPON", { "40 - 60 Damage", "Speed 3.00",
		"Equip: Increases attack power by 100 in Cat, Bear, Dire Bear, and Moonkin forms only." }, 2, 10)
	local old = item("Old Staff", "INVTYPE_2HWEAPON", { "40 - 60 Damage", "Speed 3.00" }, 2, 10)
	local snap = Warrior()
	snap.class = "DRUID"
	H.eq(Body.Delta({ [16] = staff }, { [16] = old }, snap).ap, 0, "caster form: no change")
	snap.feral, snap.formSpeed = "bear", 2.5
	H.eq(Body.Delta({ [16] = staff }, { [16] = old }, snap).ap, 100, "bear form: +100")
end)
