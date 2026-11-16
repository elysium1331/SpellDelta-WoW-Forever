local H = ...
local ns = H.load("SpellText.lua", {})
local SpellText = ns.SpellText

local function values(text)
	return table.concat(SpellText.Values(text), ",")
end

H.test("spelltext: Smite range", function()
	H.eq(values("Smites an enemy for 87 to 96 Holy damage."), "87,96")
end)

H.test("spelltext: Power Word: Shield keeps every number in order", function()
	local text = "Draws on the soul of the party member to shield them, absorbing 366 damage. Lasts 30 sec. "
		.. "While the shield holds, spellcasting will not be interrupted by damage. "
		.. "Once shielded, the target cannot be shielded again for 15 sec."
	H.eq(values(text), "366,30,15")
	local nums = SpellText.Numbers(text)
	H.eq(nums[1].unit, nil, "absorb has no unit")
	H.eq(nums[2].unit, "time")
	H.eq(nums[3].unit, "time")
end)

H.test("spelltext: thousands separators", function()
	H.eq(values("Heals for 1,234 to 1,456."), "1234,1456")
	H.eq(values("Deals 12,345,678 damage."), "12345678")
end)

H.test("spelltext: decimals and sentence-ending periods", function()
	H.eq(values("Reduces cast time by 0.5 sec."), "0.5")
	H.eq(values("Lasts 15."), "15")
end)

H.test("spelltext: comma-separated lists are separate numbers", function()
	H.eq(values("Ranks give 5, 10, or 15 points."), "5,10,15")
	H.eq(values("Hits 3,4 targets"), "3,4")
end)

H.test("spelltext: units", function()
	local nums = SpellText.Numbers("Increases damage by 5% for 2 min. Range 30 yd.")
	H.eq(nums[1].unit, "pct")
	H.eq(nums[2].unit, "time")
	H.eq(nums[3].unit, "dist")
end)

H.test("spelltext: color codes, textures and line breaks are removed", function()
	local text = "Heals |cffffffff566|r to |cFFFFFFFF633|r.|n|TInterface\\Icons\\Spell_Holy_Heal:0|t Lasts 12 sec."
	H.eq(values(text), "566,633,12")
end)

H.test("spelltext: empty or missing text", function()
	H.eq(#SpellText.Values(""), 0)
	H.eq(#SpellText.Values(nil), 0)
end)

H.test("spelltext: average of a range and of a single value", function()
	H.eq(SpellText.Average({ 87, 96 }, 1, 2), 91.5)
	H.eq(SpellText.Average({ 366 }, 1, 1), 366)
end)
