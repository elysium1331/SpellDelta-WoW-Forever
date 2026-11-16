local H = ...
local ns = {}
H.load("Locales/enUS.lua", ns)
H.load("SpellData.lua", ns)
H.load("Predict.lua", ns)
H.load("Gear.lua", ns)

-- A stubbed client: staff equipped, mace and Raptor's Gaze in the bags.
local LINKS = {
	staff = "|cff1eff00|Hitem:1:::::::::|h[Glimmering Staff]|h|r",
	mace = "|cff0070dd|Hitem:2:::::::::|h[Death Speaker Scepter]|h|r",
	gaze = "|cff1eff00|Hitem:3:::::::::|h[Raptor's Gaze]|h|r",
	boots = "|cffffffff|Hitem:4:::::::::|h[Plain Boots]|h|r",
}
local ITEMS = {
	[LINKS.staff] = { "INVTYPE_2HWEAPON", { "Equip: Increases damage and healing done by magical spells and effects by up to 34." } },
	[LINKS.mace] = { "INVTYPE_WEAPONMAINHAND", { "Equip: Increases healing done by magical spells and effects by up to 68.",
		"Equip: Increases damage done by Shadow spells and effects by up to 28." } },
	[LINKS.gaze] = { "INVTYPE_HOLDABLE", { "Equip: Increases damage and healing done by magical spells and effects by up to 8." } },
	[LINKS.boots] = { "INVTYPE_FEET", { "+5 Stamina" } },
}
local alt = false
ns.Compat = {
	ItemEquipLoc = function(link) return ITEMS[link] and ITEMS[link][1] end,
	ItemLines = function(link) return ITEMS[link] and ITEMS[link][2] end,
	ItemName = function(link) return link:match("|h%[(.-)%]|h") end,
	EquippedLink = function(slot) return slot == 16 and LINKS.staff or nil end,
	BagLinks = function() return { LINKS.mace, LINKS.gaze, LINKS.boots } end,
	IsAltKeyDown = function() return alt end,
	GetSpellIcon = function(id) return id == 6063 and 135913 or nil end,
}
ns.db = {}
ns.lastState = {
	spells = {
		{ spellID = 984, name = "Smite", values = { 111, 120 } },
		{ spellID = 6063, name = "Heal", values = { 595, 662 } },
		{ spellID = 8104, name = "Mind Blast", values = { 187, 196 } },
		{ spellID = 6065, name = "Power Word: Shield", values = { 370, 30, 15 } },
	},
}

H.load("Items.lua", ns)

-- Client globals the tooltip module touches at Init and when a tooltip is filled.
local postCall
TooltipDataProcessor = { AddTooltipPostCall = function(_, fn) postCall = fn end }
Enum = { TooltipDataType = { Item = 0 } }
CreateFrame = function()
	return { RegisterEvent = function() end, SetScript = function() end }
end
local function FakeTooltip(link)
	local t = { lines = {}, link = link }
	function t:GetItem() return "name", self.link end
	function t:AddLine(text) self.lines[#self.lines + 1] = text end
	function t:AddDoubleLine(left, right) self.lines[#self.lines + 1] = left .. " | " .. right end
	function t:Show() end
	return t
end

H.load("Tooltip.lua", ns)
local Tooltip = ns.Tooltip

H.test("tooltip: init registers the item post-call", function()
	H.truthy(Tooltip.Init())
	H.truthy(postCall)
end)

H.test("tooltip: without Alt, one grey hint line", function()
	GameTooltip = FakeTooltip(LINKS.gaze)
	alt = false
	postCall(GameTooltip)
	H.eq(#GameTooltip.lines, 1)
	H.eq(GameTooltip.lines[1], ns.L.TIP_HINT)
end)

H.test("tooltip: with Alt, the spell block for Ryan's swap", function()
	GameTooltip = FakeTooltip(LINKS.gaze)
	alt = true
	ns.db.casts = {}
	postCall(GameTooltip)
	local L = GameTooltip.lines
	H.eq(#L, 6)
	H.eq(L[2], "Spells - with Death Speaker Scepter, replacing Glimmering Staff")
	-- Nothing cast yet: biggest change first. Heal has an icon, the others none in this stub.
	H.eq(L[3], "  |T135913:0|t Heal | 629 to 665  (+36)")
	H.eq(L[4], "  Smite | 116 to 97  (-19)")
	H.eq(L[5], "  Power Word: Shield | 370 to 374  (+4)")
	H.eq(L[6], "  Mind Blast | 192 to 193  (+1)")
end)

H.test("tooltip: the spells cast most come first", function()
	GameTooltip = FakeTooltip(LINKS.gaze)
	alt = true
	ns.db.casts = { ["Mind Blast"] = 10, Smite = 3 }
	postCall(GameTooltip)
	local L = GameTooltip.lines
	H.eq(L[3], "  Mind Blast | 192 to 193  (+1)")
	H.eq(L[4], "  Smite | 116 to 97  (-19)")
	H.eq(L[5], "  |T135913:0|t Heal | 629 to 665  (+36)")
	ns.db.casts = {}
end)

H.test("tooltip: items that change no spell bonus, and the equipped staff, add nothing", function()
	alt = true
	GameTooltip = FakeTooltip(LINKS.boots)
	postCall(GameTooltip)
	H.eq(#GameTooltip.lines, 0)
	GameTooltip = FakeTooltip(LINKS.staff)
	postCall(GameTooltip)
	H.eq(#GameTooltip.lines, 0)
end)

H.test("tooltip: comparison tooltips are left alone", function()
	alt = true
	local shopping = FakeTooltip(LINKS.gaze)
	GameTooltip = FakeTooltip(LINKS.gaze)
	postCall(shopping)
	H.eq(#shopping.lines, 0)
end)

H.test("tooltip: an item not loaded yet is retried, not remembered as empty", function()
	alt = true
	local link = "|cff1eff00|Hitem:5:::::::::|h[Late Wand]|h|r"
	ITEMS[link] = { "INVTYPE_HOLDABLE", nil }
	GameTooltip = FakeTooltip(link)
	postCall(GameTooltip)
	H.eq(#GameTooltip.lines, 0)
	ITEMS[link][2] = { "Equip: Increases damage and healing done by magical spells and effects by up to 20." }
	GameTooltip = FakeTooltip(link)
	postCall(GameTooltip)
	H.truthy(#GameTooltip.lines > 0, "shown once loaded")
end)
