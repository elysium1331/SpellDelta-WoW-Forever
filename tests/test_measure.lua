local H = ...
local ns = {}
H.load("Locales/enUS.lua", ns)
H.load("SpellText.lua", ns)
H.load("Learning.lua", ns)
H.load("ActionSpells.lua", ns)
H.load("Measure.lua", ns)
local Measure = ns.Measure

-- A stubbed client: Ryan's priest with Smite, Heal and Fade on the bars.
local world = {
	combat = false,
	bonuses = { d = { [2] = 39, [3] = 39, [4] = 39, [5] = 39, [6] = 39, [7] = 39 }, h = 66 },
	texts = {
		[585] = "Smites an enemy for 87 to 96 Holy damage.",
		[2050] = "Heals a friendly target for 566 to 633.",
		[586] = "Fade out, discouraging enemies from attacking you for 10 sec.",
	},
}
ns.Compat = {
	SCHOOLS = { 2, 3, 4, 5, 6, 7 },
	InCombat = function() return world.combat end,
	ReadBonuses = function()
		local d = {}
		for k, v in pairs(world.bonuses.d) do d[k] = v end
		return { d = d, h = world.bonuses.h }
	end,
	ActionApi = function()
		local bar = { "spell", "spell", "spell" }
		local ids = { 585, 2050, 586 }
		return {
			maxSlot = 3,
			getActionInfo = function(slot) return bar[slot], ids[slot] end,
			getMacroSpell = function() return nil end,
		}
	end,
	GetSpellDescription = function(id) return world.texts[id] end,
	GetSpellCost = function(id) return ({ [585] = 67, [2050] = 155, [586] = 45 })[id], "MANA" end,
	GetSpellName = function(id) return ({ [585] = "Smite", [2050] = "Heal", [586] = "Fade" })[id] end,
	GetSpellKind = function(id) return ({ [585] = "dmg", [2050] = "heal" })[id] end,
	GetBuildInfo = function() return "1.60.1.70938", 16001 end,
	GetPlayerLevel = function() return 33 end,
	GetTalentSignature = function() return "abcd1234" end,
	GetShapeshiftForm = function() return 0 end,
}

H.test("measure: no reading in combat", function()
	world.combat = true
	local state, reason = Measure.Read()
	world.combat = false
	H.eq(state, nil)
	H.eq(reason, "combat")
end)

H.test("measure: reading has bonuses, group and spell numbers", function()
	local state = Measure.Read()
	H.eq(state.group, "1.60.1.70938:33:abcd1234:0")
	H.eq(#state.spells, 3)
	H.eq(state.spells[1].name, "Smite")
	H.eq(table.concat(state.spells[1].values, ","), "87,96")
	H.eq(state.spells[2].cost, 155)
end)

H.test("measure: two identical readings are the same; a gear change is not", function()
	local a = Measure.Read()
	local b = Measure.Read()
	H.truthy(Measure.Same(a, b))
	world.texts[585] = "Smites an enemy for 111 to 120 Holy damage."
	H.truthy(not Measure.Same(a, Measure.Read()), "changed text")
	world.texts[585] = "Smites an enemy for 87 to 96 Holy damage."
	world.bonuses.h = 100
	H.truthy(not Measure.Same(a, Measure.Read()), "changed bonus")
	world.bonuses.h = 66
end)

H.test("measure: recording two gear states teaches Smite and Heal", function()
	local db = { spells = {} }
	H.eq(Measure.Record(db, Measure.Read()), 3)
	-- Equip the staff: +34 to both.
	for s in pairs(world.bonuses.d) do world.bonuses.d[s] = 73 end
	world.bonuses.h = 100
	world.texts[585] = "Smites an enemy for 111 to 120 Holy damage."
	world.texts[2050] = "Heals a friendly target for 595 to 662."
	local state = Measure.Read()
	Measure.Record(db, state)
	H.eq(#db.spells[585].samples, 2)
	local lines = Measure.DumpLines(db, state)
	H.eq(lines[2], "spell bonus: damage 73, healing 100")
	H.truthy(lines[3]:find("Smite: 111, 120 | 67 mana | no game data | #1-2 x0.71 holy", 1, true), lines[3])
	H.truthy(lines[4]:find("#1-2 x0.85 healing", 1, true), lines[4])
	H.truthy(lines[5]:find("no number changes with spell bonus", 1, true), lines[5])
end)

H.test("measure: damage bonus summary lists differing schools", function()
	H.eq(Measure.FormatDamageBonus({ [2] = 47, [3] = 47, [4] = 47, [5] = 47, [6] = 75, [7] = 47 }),
		"47 (shadow 75)")
end)

H.test("measure: dump before any reading", function()
	H.eq(Measure.DumpLines({ spells = {} }, nil)[1], ns.L.DUMP_NOT_MEASURED)
end)

H.test("measure: a reading without bonuses still has spell numbers but teaches nothing", function()
	local saved = ns.Compat.ReadBonuses
	ns.Compat.ReadBonuses = function() return nil end
	local state = Measure.Read()
	ns.Compat.ReadBonuses = saved
	H.truthy(state, "state")
	H.eq(state.bonuses, nil)
	H.eq(#state.spells[1].values, 2)
	H.eq(Measure.Record({ spells = {} }, state), 0)
	H.truthy(Measure.DumpLines({ spells = {} }, state)[2]:find("hidden", 1, true))
end)
