local H = ...

-- A stand-in for WoW frames: every method exists; the ones the tab reads return sensible values.
local Stub = {}
local function NewStub(kind)
	local obj = { kind = kind, shown = kind ~= "Frame" and true or true, scripts = {}, text = nil, children = {} }
	return setmetatable(obj, Stub)
end
local methods = {
	IsShown = function(self) return self.shown end,
	Show = function(self)
		local was = self.shown
		self.shown = true
		if not was and self.scripts.OnShow then
			self.scripts.OnShow(self)
		end
	end,
	Hide = function(self) self.shown = false end,
	SetShown = function(self, v) if v then self:Show() else self:Hide() end end,
	SetScript = function(self, name, fn) self.scripts[name] = fn end,
	HookScript = function(self, name, fn) self.scripts["hook" .. name] = fn end,
	GetScript = function(self, name) return self.scripts[name] end,
	CreateTexture = function() return NewStub("Texture") end,
	CreateFontString = function() return NewStub("FontString") end,
	SetText = function(self, t) self.text = t end,
	GetText = function(self) return self.text end,
	GetWidth = function() return 200 end,
	GetStringHeight = function() return 12 end,
	GetFrameLevel = function() return 400 end,
	GetFacing = function() return 0 end,
	IsRightPaneCollapsed = function(self) return self.collapsed == true end,
	SetCustomOnMouseUpHandler = function(self, fn) self.mouseUp = fn end,
	SetChecked = function(self, v) self.checked = v end,
}
Stub.__index = function(_, key)
	return methods[key] or function() end
end

local frames = {}
CreateFrame = function(kind, _, parent, template)
	local f = NewStub(kind)
	f.parent, f.template = parent, template
	if template == "LargeSideTabButtonTemplate" then
		f.Icon = NewStub("Texture")
	end
	if kind == "ItemButton" then
		f.icon = NewStub("Texture")
		f.IconBorder = NewStub("Texture")
	end
	frames[#frames + 1] = f
	if kind == "Frame" and parent == nil then
		f.shown = true
	end
	return f
end
local hooks = {}
hooksecurefunc = function(a, b, c)
	if type(a) == "string" then
		hooks[a] = b
	else
		hooks[b] = c
	end
end
CharacterFrame = NewStub("Frame")
CharacterFrame.LeftPaneHost = NewStub("Frame")
CharacterFrame.RightPaneHost = NewStub("Frame")
CharacterFrame.ModeTabs = NewStub("Frame")
CharacterFrame.ModeTabs.Tabs = { NewStub("Frame"), NewStub("Frame") }
CharacterFrame.activeSubframe = "PaperDollFrame"
local toggled
ToggleCharacter = function(name) toggled = name end
GameTooltip = NewStub("Frame")
HandleModifiedItemClick = function() end
IsModifiedClick = function() return true end

-- Client data: staff worn, the mace on the cursor.
local LINKS = {
	staff = "|cff1eff00|Hitem:1:::::::::|h[Glimmering Staff]|h|r",
	mace = "|cff0070dd|Hitem:2:::::::::|h[Death Speaker Scepter]|h|r",
	gaze = "|cff1eff00|Hitem:3:::::::::|h[Raptor's Gaze]|h|r",
}
local ITEMS = {
	[LINKS.staff] = { "INVTYPE_2HWEAPON", { "+11 Stamina", "+11 Intellect",
		"Equip: Increases damage and healing done by magical spells and effects by up to 34." } },
	[LINKS.mace] = { "INVTYPE_WEAPONMAINHAND", { "Equip: Increases healing done by magical spells and effects by up to 68.",
		"Equip: Increases damage done by Shadow spells and effects by up to 28." } },
	[LINKS.gaze] = { "INVTYPE_HOLDABLE", { "+4 Stamina", "+4 Intellect",
		"Equip: Increases damage and healing done by magical spells and effects by up to 8." } },
}
local cursor
C_Item = {
	GetItemInfoInstant = function(link) return 1, "Armor", "Misc", ITEMS[link] and ITEMS[link][1], 135000 end,
	GetItemInfo = function() return "name", "link", 2 end,
}
C_TooltipInfo = {
	GetHyperlink = function(link)
		local lines = {}
		for i, text in ipairs(ITEMS[link] and ITEMS[link][2] or {}) do
			lines[i] = { leftText = text }
		end
		return { lines = lines }
	end,
}
GetInventoryItemLink = function(_, slot) return slot == 16 and LINKS.staff or nil end
GetCursorInfo = function() if cursor then return "item", 2, cursor end end
ClearCursor = function() cursor = nil end
CanDualWield = function() return false end
C_Container = {
	GetContainerNumSlots = function(bag) return bag == 0 and 2 or 0 end,
	GetContainerItemLink = function(_, slot) return slot == 1 and LINKS.mace or LINKS.gaze end,
}
UnitStat = function(_, i) return 0, ({ 40, 30, 60, 112, 90 })[i] end
UnitArmor = function() return 0, 300 end

local ns = {}
H.load("Locales/enUS.lua", ns)
H.load("Compat.lua", ns)
H.load("Database.lua", ns)
H.load("SpellData.lua", ns)
H.load("Predict.lua", ns)
H.load("Gear.lua", ns)
H.load("Items.lua", ns)
H.load("Loadout.lua", ns)
H.load("CharacterTab.lua", ns)
local Tab = ns.CharacterTab
ns.db = ns.Database.Load(nil)
ns.lastState = {
	bonuses = { d = { [2] = 34, [3] = 34, [4] = 34, [5] = 34, [6] = 34, [7] = 34 }, h = 100 },
	spells = {
		{ spellID = 984, name = "Smite", values = { 111, 120 } },
		{ spellID = 6063, name = "Heal", values = { 595, 662 } },
		{ spellID = 8104, name = "Mind Blast", values = { 187, 196 } },
		{ spellID = 6065, name = "Power Word: Shield", values = { 370, 30, 15 } },
		{ spellID = 586, name = "Fade", values = { 10 } },
	},
}

local function kinds(lines, kind)
	local out = {}
	for _, line in ipairs(lines) do
		if line.kind == kind then
			out[#out + 1] = line
		end
	end
	return out
end

H.test("tab: with nothing planned, every spell is listed so you can pick your six", function()
	local worn = { [16] = ns.Items.For(LINKS.staff) }
	local lines = Tab.Build({ state = ns.lastState, plan = {}, worn = worn, tracked = {} })
	H.eq(#kinds(lines, "spell"), 4, "Fade does not grow with gear")
	H.eq(#kinds(lines, "toggle"), 0)
	H.eq(kinds(lines, "stat")[1], nil)
end)

H.test("tab: Ryan's planned mace and off-hand", function()
	local worn = { [16] = ns.Items.For(LINKS.staff) }
	local plan = {}
	ns.Loadout.Place(plan, worn, ns.Items.For(LINKS.mace), nil, false)
	ns.Loadout.Place(plan, worn, ns.Items.For(LINKS.gaze), nil, false)
	local lines = Tab.Build({ state = ns.lastState, plan = plan, worn = worn, tracked = { "Mind Blast" },
		playerStats = { sta = 60, int = 112 } })
	local spells = kinds(lines, "spell")
	H.eq(spells[1].row.name, "Mind Blast", "chosen spells first")
	H.truthy(spells[1].tracked)
	H.eq(spells[2].row.name, "Heal")
	H.eq(spells[2].row.before, 629)
	H.eq(spells[2].row.after, 665)
	local stats = kinds(lines, "stat")
	H.eq(stats[1].label, "Stamina")
	H.eq(stats[1].now, 60)
	H.eq(stats[1].plan, 53)
	H.eq(stats[1].change, -7)
	local healing
	for _, s in ipairs(stats) do
		if s.label == "Bonus healing" then
			healing = s
		end
	end
	H.eq(healing.plan, 142)
	local texts = {}
	for _, t in ipairs(kinds(lines, "text")) do
		texts[#texts + 1] = t.text
	end
	local all = table.concat(texts, "\n")
	H.truthy(all:find("Healing:|r Heal, Power Word: Shield", 1, true), all)
	H.truthy(all:find("Holy damage:|r Smite", 1, true))
	H.truthy(all:find("Shadow damage:|r Mind Blast", 1, true))
end)

H.test("tab: picking spells for the item tooltip", function()
	local db = ns.Database.Load(nil)
	for i = 1, 6 do
		H.eq(ns.Database.ToggleTracked(db, "S" .. i), "added")
	end
	H.eq(ns.Database.ToggleTracked(db, "S7"), "full")
	H.eq(ns.Database.ToggleTracked(db, "S2"), "removed")
	H.eq(#db.tracked, 5)
	local kept = ns.Database.Load({ tracked = { "A", "A", 3, "B" }, plan = { [16] = LINKS.mace, [17] = false, [40] = "x", [2] = "nope" } })
	H.eq(table.concat(kept.tracked, ","), "A,B")
	H.eq(kept.plan[16], LINKS.mace)
	H.eq(kept.plan[17], false)
	H.eq(kept.plan[40], nil)
	H.eq(kept.plan[2], nil)
end)

H.test("tab: init adds our own side tab without touching Blizzard's list", function()
	H.truthy(Tab.Init())
	H.eq(#CharacterFrame.ModeTabs.Tabs, 2)
	H.truthy(hooks.OnModeTabClicked and hooks.ShowSubFrame, "post-hooks only")
end)

H.test("tab: clicking it opens the panel; dropping the mace plans it; Reset clears", function()
	local tab
	for _, f in ipairs(frames) do
		if f.template == "LargeSideTabButtonTemplate" then
			tab = f
		end
	end
	H.truthy(tab and tab.mouseUp, "tab has a click handler")
	tab.mouseUp(tab, "LeftButton", true)
	H.eq(tab.checked, true)
	H.eq(CharacterFrame.ModeTabs.Tabs[1].checked, false, "the game's tabs show unselected")
	-- Drop the mace on the main-hand slot button.
	local mainHand
	for _, f in ipairs(frames) do
		if f.kind == "ItemButton" and f.slot == 16 then
			mainHand = f
		end
	end
	cursor = LINKS.mace
	mainHand.scripts.OnReceiveDrag(mainHand)
	H.eq(cursor, nil, "cursor cleared")
	H.eq(ns.db.plan[16], LINKS.mace)
	-- Shift-click the off-hand from the bags.
	hooks.HandleModifiedItemClick(LINKS.gaze)
	H.eq(ns.db.plan[17], LINKS.gaze)
	-- Right-click the main hand: staff back, so the off-hand goes too.
	mainHand.scripts.OnClick(mainHand, "RightButton")
	H.eq(next(ns.db.plan), nil)
	-- Clicking a game tab hides our panel.
	hooks.ShowSubFrame(CharacterFrame, "ReputationFrame")
	H.eq(tab.checked, false)
	H.eq(toggled, nil, "already on the gear screen")
end)

H.test("tab: clicking an empty-handed slot opens a picker of bag items that fit", function()
	local tab
	for _, f in ipairs(frames) do
		if f.template == "LargeSideTabButtonTemplate" then
			tab = f
		end
	end
	tab.mouseUp(tab, "LeftButton", true)
	local mainHand
	for _, f in ipairs(frames) do
		if f.kind == "ItemButton" and f.slot == 16 then
			mainHand = f
		end
	end
	cursor = nil
	mainHand.scripts.OnClick(mainHand, "LeftButton")
	local fits = Tab.ItemsForSlot(16)
	H.eq(#fits, 1, "the mace fits the main hand; the off-hand and the worn staff do not show")
	H.eq(fits[1].link, LINKS.mace)
	local pick
	for _, f in ipairs(frames) do
		if f.kind == "ItemButton" and rawget(f, "link") == LINKS.mace and rawget(f, "slot") == nil then
			pick = f
		end
	end
	H.truthy(pick, "a picker button for the mace")
	pick.scripts.OnClick(pick)
	H.eq(ns.db.plan[16], LINKS.mace)
	-- Ryan's case: the plan holds an off-hand, then the staff is equipped from the bags.
	ns.db.plan = { [17] = LINKS.gaze }
	Tab.Refresh()
	H.eq(next(ns.db.plan), nil, "no impossible staff plus off-hand plan")
end)
