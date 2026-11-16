local H = ...
local ns = H.load("Learning.lua", {})
local Learning = ns.Learning

-- Ryan's in-game measurements (level 33 priest, 2026-11-14).
-- Bonus per school: 2 holy, 3 fire, 4 nature, 5 frost, 6 shadow, 7 arcane.
local function bonuses(all, shadow, heal)
	return { d = { [2] = all, [3] = all, [4] = all, [5] = all, [6] = shadow, [7] = all }, h = heal }
end
local NONE = bonuses(39, 39, 66)    -- no weapon
local STAFF = bonuses(73, 73, 100)  -- staff, +34 to both
local MACE = bonuses(47, 75, 142)   -- mace +68 healing / +28 shadow, off-hand +8 both

local MEASURED = {
	mindBlast = { [NONE] = { 173, 182 }, [STAFF] = { 187, 196 }, [MACE] = { 188, 197 } },
	smite = { [NONE] = { 87, 96 }, [STAFF] = { 111, 120 }, [MACE] = { 93, 102 } },
	shield = { [NONE] = { 366, 30, 15 }, [STAFF] = { 370, 30, 15 }, [MACE] = { 374, 30, 15 } },
	heal = { [NONE] = { 566, 633 }, [STAFF] = { 595, 662 }, [MACE] = { 631, 698 } },
}

local function entryFor(spell, states, group)
	local entry = Learning.NewEntry()
	for _, state in ipairs(states) do
		Learning.AddSample(entry, { g = group or "g1", d = state.d, h = state.h, v = MEASURED[spell][state] })
	end
	return entry
end

local ALL = { NONE, STAFF, MACE }

H.test("learning: Heal scales about 0.86 with healing bonus", function()
	local fit = Learning.Fit(entryFor("heal", ALL), 1, "heal")
	H.eq(fit.status, "single")
	H.eq(fit.var, "heal")
	H.near(fit.slope, 0.86, 0.03)
	H.near(Learning.Fit(entryFor("heal", ALL), 2, "heal").slope, 0.86, 0.03)
end)

H.test("learning: Smite scales about 0.71 with holy damage, not healing", function()
	local fit = Learning.Fit(entryFor("smite", ALL), 1, "dmg")
	H.eq(fit.status, "single")
	H.eq(fit.var, 2)
	H.near(fit.slope, 0.71, 0.03)
end)

H.test("learning: Mind Blast scales about 0.42 with shadow damage", function()
	local fit = Learning.Fit(entryFor("mindBlast", ALL), 1, "dmg")
	H.eq(fit.var, 6, "the mace's +28 shadow identifies the school")
	H.near(fit.slope, 0.42, 0.03)
end)

H.test("learning: Power Word: Shield scales about 0.10; its durations are fixed", function()
	local entry = entryFor("shield", ALL)
	local fits = Learning.FitAll(entry, "heal")
	H.near(fits[1].slope, 0.10, 0.03)
	H.eq(fits[2].status, "fixed")
	H.eq(fits[3].status, "fixed")
end)

H.test("learning: without a hint, healing vs. damage is found from the data", function()
	H.eq(Learning.Fit(entryFor("heal", ALL), 1, nil).var, "heal")
	H.eq(Learning.Fit(entryFor("smite", ALL), 1, nil).var, 2)
end)

H.test("learning: one gear state is not enough", function()
	local fit = Learning.Fit(entryFor("smite", { NONE }), 1, "dmg")
	H.eq(fit.status, "learning")
end)

H.test("learning: two states less than 10 points apart are not enough", function()
	local entry = Learning.NewEntry()
	Learning.AddSample(entry, { g = "g", d = bonuses(39, 39, 66).d, h = 66, v = { 87, 96 } })
	Learning.AddSample(entry, { g = "g", d = bonuses(44, 44, 71).d, h = 71, v = { 91, 100 } })
	H.eq(Learning.Fit(entry, 1, "dmg").status, "learning")
end)

H.test("learning: a 34-point gap is enough (staff vs. no weapon)", function()
	local fit = Learning.Fit(entryFor("smite", { NONE, STAFF }), 1, "dmg")
	H.eq(fit.status, "single")
	H.near(fit.slope, 0.71, 0.03)
end)

H.test("learning: groups (level or talent changes) keep their own base", function()
	local entry = Learning.NewEntry()
	-- Same slope 0.5, but the base rose by 20 after a level-up.
	Learning.AddSample(entry, { g = "lvl33", d = bonuses(40, 40, 0).d, h = 0, v = { 120 } })
	Learning.AddSample(entry, { g = "lvl33", d = bonuses(80, 80, 0).d, h = 0, v = { 140 } })
	Learning.AddSample(entry, { g = "lvl34", d = bonuses(40, 40, 0).d, h = 0, v = { 140 } })
	Learning.AddSample(entry, { g = "lvl34", d = bonuses(100, 100, 0).d, h = 0, v = { 170 } })
	local fit = Learning.Fit(entry, 1, "dmg")
	H.near(fit.slope, 0.5, 0.001)
end)

H.test("learning: the same gear state is stored once (latest reading wins)", function()
	local entry = Learning.NewEntry()
	Learning.AddSample(entry, { g = "g", d = NONE.d, h = NONE.h, v = { 87, 96 } })
	Learning.AddSample(entry, { g = "g", d = NONE.d, h = NONE.h, v = { 88, 97 } })
	H.eq(#entry.samples, 1)
	H.eq(entry.samples[1].v[1], 88)
end)

H.test("learning: a change in the number count restarts the spell", function()
	local entry = entryFor("smite", { NONE, STAFF })
	Learning.AddSample(entry, { g = "g1", d = MACE.d, h = MACE.h, v = { 93, 102, 5 } })
	H.eq(entry.n, 3)
	H.eq(#entry.samples, 1)
end)

H.test("learning: samples are capped, dropping other groups first", function()
	local entry = Learning.NewEntry()
	for i = 1, 5 do
		Learning.AddSample(entry, { g = "old", d = bonuses(i * 20, i * 20, 0).d, h = 0, v = { i } }, 6)
	end
	for i = 1, 4 do
		Learning.AddSample(entry, { g = "new", d = bonuses(i * 20, i * 20, 1).d, h = 1, v = { i } }, 6)
	end
	H.eq(#entry.samples, 6)
	local new = 0
	for _, s in ipairs(entry.samples) do
		if s.g == "new" then
			new = new + 1
		end
	end
	H.eq(new, 4, "all samples of the current group are kept")
end)

H.test("learning: predicting the staff from the mace matches the tooltip", function()
	local smite = Learning.Fit(entryFor("smite", ALL), 1, "dmg")
	local heal = Learning.Fit(entryFor("heal", ALL), 1, "heal")
	local mindBlast = Learning.Fit(entryFor("mindBlast", ALL), 1, "dmg")
	local delta = Learning.Delta(MACE, STAFF)
	H.near(Learning.Predict(smite, 93, delta), 111, 1)
	H.near(Learning.Predict(heal, 631, delta), 595, 1)
	H.near(Learning.Predict(mindBlast, 188, delta), 187, 1)
end)

H.test("learning: a fixed number never moves in a prediction", function()
	local fits = Learning.FitAll(entryFor("shield", ALL), "heal")
	H.eq(Learning.Predict(fits[2], 30, Learning.Delta(NONE, MACE)), 30)
end)
