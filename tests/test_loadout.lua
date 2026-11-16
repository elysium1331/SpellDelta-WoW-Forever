local H = ...
local ns = {}
H.load("Gear.lua", ns)
H.load("Loadout.lua", ns)
local Gear, Loadout = ns.Gear, ns.Loadout

local function item(link, loc, lines)
	return { link = link, loc = loc, name = link, bonus = Gear.ParseBonus(lines or {}), stats = Gear.ParseStats(lines or {}) }
end

-- Ryan's gear and bag items (tooltip lines from his screenshots).
local STAFF = item("Glimmering Staff", "INVTYPE_2HWEAPON", {
	"+11 Stamina", "+11 Intellect",
	"Equip: Increases damage and healing done by magical spells and effects by up to 34." })
local MACE = item("Death Speaker Scepter", "INVTYPE_WEAPONMAINHAND", {
	"Equip: Increases healing done by magical spells and effects by up to 68.",
	"Equip: Restores 12 Health per 5 sec.",
	"Equip: Increases damage done by Shadow spells and effects by up to 28." })
local GAZE = item("Raptor's Gaze", "INVTYPE_HOLDABLE", { "+4 Stamina", "+4 Intellect",
	"Equip: Increases damage and healing done by magical spells and effects by up to 8." })
local RING_A = item("Ring A", "INVTYPE_FINGER", { "+2 Spirit" })
local RING_B = item("Ring B", "INVTYPE_FINGER", { "+5 Spirit" })
local NEW_RING = item("New Ring", "INVTYPE_FINGER", { "+3 Intellect" })
local DAGGER = item("Dagger", "INVTYPE_WEAPON", {})

H.test("gear: stats are read from tooltip lines", function()
	local s = Gear.ParseStats({
		"Glimmering Staff", "Two-Hand", "32 - 49 Damage", "+11 Stamina", "-5 Spirit", "45 Armor", "12 Block",
		"|cff1eff00Equip: Restores 4 mana per 5 sec.|r", "Equip: Improves your chance to get a critical strike with spells by 1%.",
		"Equip: Improves your chance to hit by 2%.", "Equip: +20 Attack Power.", "Equip: Increased Defense +7.",
		"Use: +50 Intellect for 10 sec.", "(2) Set: +10 Stamina", "Durability 100 / 100", "Requires Level 25",
	})
	H.eq(s.sta, 11)
	H.eq(s.spi, -5)
	H.eq(s.armor, 45)
	H.eq(s.block, 12)
	H.eq(s.mp5, 4)
	H.eq(s.spellcrit, 1)
	H.eq(s.hit, 2)
	H.eq(s.ap, 20)
	H.eq(s.def, 7)
	H.eq(s.int, nil, "Use: effects are not counted")
	H.eq(MACE.stats.hp5, 12)
end)

H.test("loadout: mace and off-hand replace the staff in two steps", function()
	local worn, plan = { [16] = STAFF }, {}
	H.eq(Loadout.Place(plan, worn, MACE, nil, false), 16)
	H.eq(Loadout.Place(plan, worn, GAZE, nil, false), 17)
	local delta = Loadout.BonusDelta(plan, worn)
	H.eq(delta.h, 42)
	H.eq(delta.d[2], -26)
	H.eq(delta.d[6], 2)
	local stats = Loadout.StatDelta(plan, worn)
	H.eq(stats.sta, -7)
	H.eq(stats.int, -7)
	H.eq(stats.hp5, 12)
end)

H.test("loadout: an off-hand on a two-hander empties the main hand; a two-hander empties the off-hand", function()
	local worn, plan = { [16] = STAFF }, {}
	Loadout.Place(plan, worn, GAZE, 17, false)
	H.eq(plan[16], false, "staff comes off")
	H.eq(plan[17], GAZE)
	local worn2, plan2 = { [16] = MACE, [17] = GAZE }, {}
	Loadout.Place(plan2, worn2, STAFF, 16, false)
	H.eq(plan2[17], false)
	H.eq(Loadout.BonusDelta(plan2, worn2).h, -42)
end)

H.test("loadout: wrong slots and unwearable items are refused", function()
	local plan = {}
	local slot, why = Loadout.Place(plan, {}, GAZE, 16, false)
	H.eq(slot, nil)
	H.eq(why, "slot")
	slot, why = Loadout.Place(plan, {}, item("Shirt?", nil), nil, false)
	H.eq(why, "cannot")
	H.eq(Loadout.Place(plan, {}, DAGGER, 17, false), nil, "no dual wield")
	H.eq(Loadout.Place(plan, {}, DAGGER, 17, true), 17, "dual wield")
end)

H.test("loadout: a ring goes in the slot you drop it on, or replaces the weaker one", function()
	local worn = { [11] = RING_B, [12] = RING_A }
	local plan = {}
	H.eq(Loadout.Place(plan, worn, NEW_RING, 11, false), 11)
	plan = {}
	-- Both rings give no spell bonus: the first slot.
	H.eq(Loadout.Place(plan, worn, NEW_RING, nil, false), 11)
	-- A second new ring goes in the slot not yet changed.
	H.eq(Loadout.Place(plan, worn, item("Other Ring", "INVTYPE_FINGER", {}), nil, false), 12)
end)

H.test("loadout: putting back what you wear, and reverting a hand that clashes", function()
	local worn, plan = { [16] = STAFF }, {}
	Loadout.Place(plan, worn, GAZE, 17, false)
	Loadout.Revert(plan, worn, 16)
	H.eq(plan[16], nil)
	H.eq(plan[17], nil, "the staff is back, so the off-hand goes too")
	H.truthy(Loadout.IsEmpty(plan))
	Loadout.Place(plan, worn, STAFF, 16, false)
	H.truthy(Loadout.IsEmpty(plan), "placing the worn item is no change")
end)

H.test("loadout: saved as links and restored", function()
	local worn, plan = { [16] = STAFF }, {}
	Loadout.Place(plan, worn, MACE, nil, false)
	Loadout.Place(plan, worn, GAZE, nil, false)
	local saved = Loadout.Save(plan)
	H.eq(saved[16], MACE.link)
	local byLink = { [MACE.link] = MACE, [GAZE.link] = GAZE }
	local restored = Loadout.Restore(saved, worn, function(link) return byLink[link] end)
	H.eq(restored[16], MACE)
	H.eq(restored[17], GAZE)
	-- After Ryan equips the mace and off-hand, the plan has nothing left to change.
	local nowWorn = { [16] = MACE, [17] = GAZE }
	H.truthy(Loadout.IsEmpty(Loadout.Restore(saved, nowWorn, function(link) return byLink[link] end)))
end)

H.test("loadout: equipping from the bags never leaves an impossible plan", function()
	local byLink = { [MACE.link] = MACE, [GAZE.link] = GAZE, [STAFF.link] = STAFF }
	local find = function(link) return byLink[link] end
	-- Ryan's case: mace worn, off-hand planned, then the staff equipped by right-click.
	local saved = { [17] = GAZE.link }
	local plan = Loadout.Restore(saved, { [16] = STAFF }, find)
	H.truthy(Loadout.IsEmpty(plan), "the planned off-hand is dropped")
	-- A planned staff while an off-hand gets equipped: the off-hand comes off in the plan.
	plan = Loadout.Restore({ [16] = STAFF.link }, { [16] = MACE, [17] = GAZE }, find)
	H.eq(plan[16], STAFF)
	H.eq(plan[17], false)
end)
