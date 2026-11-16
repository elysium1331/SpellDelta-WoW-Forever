local H = ...
local ns = H.load("ActionSpells.lua", {})
local ActionSpells = ns.ActionSpells

local function api(slots, macros)
	return {
		maxSlot = 120,
		getActionInfo = function(slot)
			local a = slots[slot]
			if a then
				return a[1], a[2], a[3]
			end
		end,
		getMacroSpell = function(index)
			return macros[index]
		end,
	}
end

H.test("actionspells: spells, macros, items and duplicates", function()
	local list = ActionSpells.Collect(api({
		[1] = { "spell", 585 },              -- Smite
		[2] = { "spell", 2050 },             -- Heal
		[3] = { "item", 6948 },              -- Hearthstone: skipped
		[4] = { "macro", 7, "" },            -- macro index 7 -> GetMacroSpell
		[5] = { "macro", 17, "spell" },      -- mainline: macro already resolved to a spell ID
		[6] = { "spell", 585 },              -- duplicate Smite
		[7] = { "macro", 8, "" },            -- macro that casts nothing right now
		[8] = { "companion", 1 },            -- skipped
		[9] = { "flyout", 3 },               -- skipped
		[120] = { "spell", 139 },            -- Renew on the last slot
		[121] = { "spell", 17 },             -- beyond maxSlot: ignored
	}, { [7] = 8092, [8] = nil }))
	local ids = {}
	for _, s in ipairs(list) do
		ids[#ids + 1] = s.spellID
	end
	H.eq(table.concat(ids, ","), "585,2050,8092,17,139")
	H.eq(#list[1].slots, 2, "Smite is on two slots")
	H.eq(list[3].viaMacro, true)
	H.eq(list[1].viaMacro, false)
end)

H.test("actionspells: a spell on a bar and in a macro is listed once, as a bar spell", function()
	local list = ActionSpells.Collect(api({
		[1] = { "macro", 2, "" },
		[2] = { "spell", 2050 },
	}, { [2] = 2050 }))
	H.eq(#list, 1)
	H.eq(list[1].viaMacro, false)
end)

H.test("actionspells: bad values are ignored", function()
	local list = ActionSpells.Collect(api({
		[1] = { "spell", 0 },
		[2] = { "spell", "x" },
		[3] = { "spell", nil },
	}, {}))
	H.eq(#list, 0)
end)
