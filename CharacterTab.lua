-- The SpellDelta tab on the character screen: plan gear in the slots, see what it changes.
--
-- Built against Forever 1.60.1.70938's character screen (Blizzard_UIPanels_Game/Camelot):
--   CharacterFrame.LeftPaneHost (398 wide: slots and model). Our panel covers only this, so the
--   game's own stats pane on the right stays as it is. Side tabs live in
--   CharacterFrame.ModeTabs (LargeSideTabButtonTemplate, stacked by UpdateTabLayout).
--   Slot buttons are named CharacterHeadSlot ... CharacterRangedSlot.
--
-- Safety: nothing here is added to Blizzard's tab list or written into Blizzard's frames.
-- Our tab is our own frame from the same template; our panel is our own frame laid over the
-- gear area. Blizzard methods are only post-hooked (hooksecurefunc / HookScript), so the
-- character screen keeps working in combat. Gear is never equipped by the addon.
local _, ns = ...

local L, Compat, Gear, Predict, Loadout, Database = ns.L, ns.Compat, ns.Gear, ns.Predict, ns.Loadout, ns.Database

local Tab = {}
ns.CharacterTab = Tab

Tab.ICON = "Interface\\Icons\\INV_Misc_Gear_01"

-- slot id, Blizzard slot button, slot name for the empty-slot picture.
Tab.SLOTS = {
	{ 1, "CharacterHeadSlot", "HeadSlot" }, { 2, "CharacterNeckSlot", "NeckSlot" },
	{ 3, "CharacterShoulderSlot", "ShoulderSlot" }, { 15, "CharacterBackSlot", "BackSlot" },
	{ 5, "CharacterChestSlot", "ChestSlot" }, { 4, "CharacterShirtSlot", "ShirtSlot" },
	{ 19, "CharacterTabardSlot", "TabardSlot" }, { 9, "CharacterWristSlot", "WristSlot" },
	{ 10, "CharacterHandsSlot", "HandsSlot" }, { 6, "CharacterWaistSlot", "WaistSlot" },
	{ 7, "CharacterLegsSlot", "LegsSlot" }, { 8, "CharacterFeetSlot", "FeetSlot" },
	{ 11, "CharacterFinger0Slot", "Finger0Slot" }, { 12, "CharacterFinger1Slot", "Finger1Slot" },
	{ 13, "CharacterTrinket0Slot", "Trinket0Slot" }, { 14, "CharacterTrinket1Slot", "Trinket1Slot" },
	{ 16, "CharacterMainHandSlot", "MainHandSlot" }, { 17, "CharacterSecondaryHandSlot", "SecondaryHandSlot" },
	{ 18, "CharacterRangedSlot", "RangedSlot" },
}

-- Planned gear (items) and what is worn; rebuilt from saved links when the tab opens.
local plan, worn = {}, {}
local showAll = false
local ui -- frames, created on first use

local GOLD = "|cffffd100"
local GREEN = { 0.25, 1, 0.25 }
local RED = { 1, 0.3, 0.3 }
local GREY = { 0.6, 0.6, 0.6 }
local WHITE = { 1, 1, 1 }

-- What the right side shows (pure; unit-tested) ------------------------------------------

local function SortRows(rows, trackedOrder)
	table.sort(rows, function(a, b)
		local ta, tb = trackedOrder[a.name], trackedOrder[b.name]
		if ta or tb then
			if ta and tb then
				return ta < tb
			end
			return ta ~= nil
		end
		local ca, cb = math.abs(a.change), math.abs(b.change)
		if ca ~= cb then
			return ca > cb
		end
		return a.name < b.name
	end)
end

-- Item stats that a "What you get" line already covers (with the stats behind it): shown once.
local COVERED = { health = "health", mana = "mana", ap = "ap", rap = "rap", armor = "armor", def = "defense", dodge = "dodge", parry = "parry",
	blockpct = "block", block = "blockValue", crit = "crit", spellcrit = "spellCrit" }

-- ctx = { state, plan, worn, tracked = { names and "stat:" keys }, showAll, playerStats, snap }
-- Returns lines: { kind = "header" | "columns" | "spell" | "toggle" | "stat" | "derived" | "text" |
-- "spacer", ... }
function Tab.Build(ctx)
	local lines = {}
	local function add(line)
		lines[#lines + 1] = line
	end
	local state, tracked = ctx.state, ctx.tracked or {}
	local delta = ns.Body.Delta(ctx.plan, ctx.worn, ctx.snap, ns.Talents and ns.Talents.AppliedStats())
	local trackedSet = {}
	for _, key in ipairs(tracked) do
		trackedSet[key] = true
	end

	if Loadout.IsEmpty(ctx.plan) then
		add({ kind = "text", text = L.TAB_EMPTY_HINT, color = GREY })
		add({ kind = "spacer" })
	end
	add({ kind = "header", text = L.TAB_SPELLS })
	if not state then
		add({ kind = "text", text = L.TAB_READING, color = GREY })
	else
		if ns.Talents then
			ns.Talents.Attach(delta, state.bonuses, ns.Compat.GetPlayerLevel())
		end
		local rows = Predict.Rows(state.spells, delta, nil, true)
		if #rows == 0 then
			add({ kind = "text", text = L.TAB_NO_SPELLS, color = GREY })
		else
			local trackedOrder = {}
			for i, name in ipairs(tracked) do
				trackedOrder[name] = i
			end
			SortRows(rows, trackedOrder)
			local anyChange = false
			for _, row in ipairs(rows) do
				anyChange = anyChange or row.change ~= 0
			end
			local hidden, measured = 0, false
			add({ kind = "columns" })
			for _, row in ipairs(rows) do
				local isTracked = trackedOrder[row.name] ~= nil
				if not anyChange or ctx.showAll or row.change ~= 0 or isTracked then
					add({ kind = "spell", row = row, tracked = isTracked })
					measured = measured or row.measured == true
				else
					hidden = hidden + 1
				end
			end
			if measured then
				add({ kind = "text", text = L.MEASURED_NOTE, color = GREY })
			end
			if hidden > 0 then
				add({ kind = "toggle", text = L.TAB_SHOW_ALL:format(hidden) })
			elseif ctx.showAll and anyChange then
				add({ kind = "toggle", text = L.TAB_SHOW_FEWER })
			end
			local n, max = #tracked, Database.MAX_TRACKED
			if n == 0 then
				add({ kind = "text", text = L.TAB_PICK_AUTO, color = GREY })
			end
			add({ kind = "text", text = (n >= max and L.TAB_PICK_FULL or L.TAB_PICK_HINT):format(n, max), color = GREY })
		end
	end

	add({ kind = "spacer" })
	add({ kind = "header", text = L.TAB_STATS })
	local any = false
	local statDelta = Loadout.StatDelta(ctx.plan, ctx.worn)
	local playerStats = ctx.playerStats or {}
	for _, key in ipairs(Gear.STAT_ORDER) do
		local change = statDelta[key]
		if change and not (COVERED[key] and delta.derived[COVERED[key]]) then
			local now = playerStats[key]
			add({ kind = "stat", label = L.STAT[key], now = now, plan = now and now + change, change = change })
			any = true
		end
	end
	local bonuses = state and state.bonuses
	if delta.h ~= 0 then
		local now = bonuses and bonuses.h
		add({ kind = "stat", label = L.BONUS_HEALING, now = now, plan = now and now + delta.h, change = delta.h })
		any = true
	end
	for school = 2, 7 do
		local change = delta.d[school]
		if change ~= 0 then
			local now = bonuses and bonuses.d[school]
			add({ kind = "stat", label = L.BONUS_SCHOOL:format(L.TOTAL_SCHOOL[school]), now = now,
				plan = now and now + change, change = change })
			any = true
		end
	end
	-- Every stat line the game gives this character, so any of them can be chosen for Alt. Like
	-- spells: all of them when nothing changes, otherwise changed and chosen ones plus "Show all".
	local derived = ns.Body.StatRows(delta.derived, L.DERIVED, true)
	local statChange = false
	for _, row in ipairs(derived) do
		statChange = statChange or row.change ~= 0
	end
	local statHidden = 0
	for _, row in ipairs(derived) do
		local isTracked = trackedSet[row.key] == true
		if not statChange or ctx.showAll or row.change ~= 0 or isTracked then
			add({ kind = "derived", row = row, tracked = isTracked })
		else
			statHidden = statHidden + 1
		end
	end
	if statHidden > 0 then
		add({ kind = "toggle", text = L.TAB_SHOW_ALL:format(statHidden) })
	elseif ctx.showAll and statChange then
		add({ kind = "toggle", text = L.TAB_SHOW_FEWER })
	end
	if #derived > 0 then
		add({ kind = "text", text = L.TAB_STAT_PICK, color = GREY })
	end
	if not any and #derived == 0 then
		add({ kind = "text", text = L.TAB_NO_STATS, color = GREY })
	end

	local groups = Predict.Groups(state and state.spells)
	if #groups > 0 then
		add({ kind = "spacer" })
		add({ kind = "header", text = L.TAB_GROUPS })
		local spellGroups = false
		for _, g in ipairs(groups) do
			spellGroups = spellGroups or type(g.var) == "number" or g.var == "h"
		end
		if spellGroups then
			add({ kind = "text", text = GOLD .. L.TAB_GROUP_ALL .. ":|r " .. L.TAB_GROUP_ALL_TEXT, color = WHITE })
		end
		for _, g in ipairs(groups) do
			local label
			if g.var == "h" then
				label = L.TOTAL_HEALING
			elseif g.var == "ap" then
				label = L.GROUP_AP
			elseif g.var == "rap" then
				label = L.GROUP_RAP
			elseif g.var == "block" then
				label = L.GROUP_BLOCK
			else
				label = L.BONUS_SCHOOL:format(L.TOTAL_SCHOOL[g.var])
			end
			add({ kind = "text", text = GOLD .. label .. ":|r " .. table.concat(g.names, ", "), color = WHITE })
		end
	end
	return lines
end

-- Planned gear ---------------------------------------------------------------------

local function Save()
	if ns.db then
		ns.db.plan = Loadout.Save(plan)
	end
end

-- Re-reads worn gear and the planned items (an item read before its data loaded is read again).
local function Reload()
	worn = ns.Items.Worn()
	plan = Loadout.Restore(ns.db and ns.db.plan or Loadout.Save(plan), worn, ns.Items.For)
	Save()
end

local function SetStatus(text)
	if ui then
		ui.status:SetText(text or "")
	end
end

-- Places the item a link names; slot nil = the slot it fits.
local function PlaceLink(link, slot)
	local item = ns.Items.For(link)
	if not item then
		return
	end
	local placed, why = Loadout.Place(plan, worn, item, slot, Compat.CanDualWield())
	if not placed then
		SetStatus(why == "slot" and L.TAB_WRONG_SLOT or L.TAB_CANNOT)
		return
	end
	SetStatus(nil)
	Save()
	Tab.Refresh()
end

local function PlaceFromCursor(slot)
	local link = Compat.CursorItemLink()
	if link then
		Compat.ClearCursor()
		PlaceLink(link, slot)
		return true
	end
	return false
end

-- Drawing ---------------------------------------------------------------------------

local function ShownLink(slot)
	local item = plan[slot]
	if item == false then
		return nil
	end
	if item then
		return item.link
	end
	return Compat.EquippedLink(slot)
end

local function UpdateSlotButton(button)
	local slot = button.slot
	local link = ShownLink(slot)
	local icon = link and Compat.ItemIcon(link) or Compat.SlotEmptyTexture(button.slotName)
	button.icon:SetTexture(icon)
	button.icon:SetDesaturated(link == nil)
	local quality = link and Compat.ItemQuality(link)
	if quality and SetItemButtonQuality then
		pcall(SetItemButtonQuality, button, quality, link)
	elseif button.IconBorder then
		button.IconBorder:Hide()
	end
	button.planned:SetShown(plan[slot] ~= nil)
end

local function SlotTooltip(button)
	local slot = button.slot
	local link = ShownLink(slot)
	GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
	if link then
		GameTooltip:SetHyperlink(link)
	else
		GameTooltip:SetText(L.TAB_SLOT_DROP)
	end
	if plan[slot] ~= nil then
		local wornLink = Compat.EquippedLink(slot)
		local wornName = wornLink and Compat.ItemName(wornLink) or L.TAB_NOTHING
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine((plan[slot] and L.TAB_SLOT_PLANNED or L.TAB_SLOT_EMPTIED):format(wornName),
			GREEN[1], GREEN[2], GREEN[3], true)
		GameTooltip:AddLine(L.TAB_SLOT_REVERT, GREY[1], GREY[2], GREY[3], true)
	end
	GameTooltip:Show()
end

local function Num(n)
	if n == nil then
		return ""
	end
	return tostring(Predict.Round(n))
end

local function Signed(n)
	n = Predict.Round(n)
	return (n > 0 and "+" or "") .. n
end

local function Pct(n, signed)
	if n == nil then
		return ""
	end
	return ((signed and n > 0) and "+" or "") .. ("%.2f"):format(n)
end

local function AcquireRow(index)
	local row = ui.rows[index]
	if row then
		return row
	end
	row = CreateFrame("Button", nil, ui.content)
	row:SetHeight(16)
	row.check = row:CreateTexture(nil, "ARTWORK")
	row.check:SetSize(12, 12)
	row.check:SetPoint("LEFT", 0, 0)
	row.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
	row.icon = row:CreateTexture(nil, "ARTWORK")
	row.icon:SetSize(14, 14)
	row.icon:SetPoint("LEFT", 13, 0)
	row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	row.name:SetJustifyH("LEFT")
	row.name:SetWordWrap(false)
	row.now = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	row.plan = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	row.chg = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	for _, fs in ipairs({ row.now, row.plan, row.chg }) do
		fs:SetJustifyH("RIGHT")
		fs:SetWidth(34)
	end
	row.chg:SetPoint("RIGHT", 0, 0)
	row.plan:SetPoint("RIGHT", row.chg, "LEFT", -2, 0)
	row.now:SetPoint("RIGHT", row.plan, "LEFT", -2, 0)
	row.text = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	row.text:SetJustifyH("LEFT")
	row.text:SetPoint("TOPLEFT", 0, 0)
	row.highlight = row:CreateTexture(nil, "HIGHLIGHT")
	row.highlight:SetAllPoints()
	row.highlight:SetColorTexture(1, 1, 1, 0.08)
	row:SetScript("OnReceiveDrag", function()
		PlaceFromCursor(nil)
	end)
	row:SetScript("OnClick", function(self)
		if self.line and (self.line.kind == "spell" or self.line.kind == "derived") and ns.db then
			Database.ToggleTracked(ns.db, self.line.row.key or self.line.row.name)
			if ns.Tooltip then
				ns.Tooltip.Invalidate()
			end
			Tab.Refresh()
		elseif self.line and self.line.kind == "toggle" then
			showAll = not showAll
			Tab.Refresh()
		end
	end)
	ui.rows[index] = row
	return row
end

local function ShowLine(row, line, width)
	row.line = line
	for _, part in ipairs({ row.check, row.icon, row.name, row.now, row.plan, row.chg, row.text }) do
		part:Hide()
	end
	local clickable = line.kind == "spell" or line.kind == "derived" or line.kind == "toggle"
	row:EnableMouse(clickable)
	row.highlight:SetShown(clickable)
	local height = 16
	if line.kind == "header" then
		row.text:SetFontObject("GameFontNormal")
		row.text:SetWidth(width)
		row.text:SetText(line.text)
		row.text:SetTextColor(1, 0.82, 0)
		row.text:Show()
		height = 20
	elseif line.kind == "columns" then
		row.now:SetText(L.TAB_COL_NOW)
		row.plan:SetText(L.TAB_COL_PLAN)
		row.chg:SetText(L.TAB_COL_CHANGE)
		for _, fs in ipairs({ row.now, row.plan, row.chg }) do
			fs:SetTextColor(GREY[1], GREY[2], GREY[3])
			fs:Show()
		end
		height = 14
	elseif line.kind == "spell" or line.kind == "stat" or line.kind == "derived" then
		local r = line.row
		local nameLeft = line.kind == "spell" and 29 or line.kind == "derived" and 13 or 0
		row.name:ClearAllPoints()
		row.name:SetPoint("LEFT", nameLeft, 0)
		row.name:SetPoint("RIGHT", row.now, "LEFT", -4, 0)
		row.name:SetText(r and Predict.Label(r) or line.label)
		row.name:Show()
		local now, planned, change
		if r then
			now, planned, change = r.before, r.after, r.change
			row.check:SetShown(line.tracked)
			local icon = r.spellID and Compat.GetSpellIcon(r.spellID)
			row.icon:SetTexture(icon)
			row.icon:SetShown(icon ~= nil)
		else
			now, planned, change = line.now, line.plan, line.change
		end
		if r and r.pct then
			row.now:SetText(Pct(now))
			row.plan:SetText(Pct(planned))
			row.chg:SetText(change ~= 0 and Pct(change, true) or "")
		else
			row.now:SetText(Num(now))
			row.plan:SetText(Num(planned))
			row.chg:SetText(change ~= 0 and Signed(change) or "")
		end
		local color = change > 0 and GREEN or change < 0 and RED or WHITE
		row.now:SetTextColor(WHITE[1], WHITE[2], WHITE[3])
		row.plan:SetTextColor(WHITE[1], WHITE[2], WHITE[3])
		row.chg:SetTextColor(color[1], color[2], color[3])
		row.now:Show()
		row.plan:Show()
		row.chg:Show()
	elseif line.kind == "toggle" then
		row.text:SetFontObject("GameFontNormalSmall")
		row.text:SetWidth(width)
		row.text:SetText(line.text)
		row.text:SetTextColor(0.4, 0.75, 1)
		row.text:Show()
	elseif line.kind == "text" then
		row.text:SetFontObject("GameFontHighlightSmall")
		row.text:SetWidth(width)
		row.text:SetText(line.text)
		local c = line.color or WHITE
		row.text:SetTextColor(c[1], c[2], c[3])
		row.text:Show()
		height = math.max(14, (row.text:GetStringHeight() or 12) + 4)
	elseif line.kind == "spacer" then
		height = 8
	end
	row:SetHeight(height)
	row:Show()
	return height
end

local function DrawList()
	local width = math.max(150, (ui.scroll:GetWidth() or 0) - 4)
	ui.content:SetWidth(width)
	local lines = Tab.Build({
		state = ns.lastState,
		plan = plan,
		worn = worn,
		tracked = ns.db and ns.db.tracked,
		showAll = showAll,
		playerStats = Compat.PlayerStats(),
		snap = Compat.Snapshot(),
	})
	local y = 0
	for i, line in ipairs(lines) do
		local row = AcquireRow(i)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", ui.content, "TOPLEFT", 0, -y)
		row:SetWidth(width)
		y = y + ShowLine(row, line, width)
	end
	for i = #lines + 1, #ui.rows do
		ui.rows[i]:Hide()
	end
	ui.content:SetHeight(math.max(1, y))
end

function Tab.Refresh()
	if not (ui and ui.panel:IsShown()) then
		return
	end
	Reload()
	for _, button in ipairs(ui.slots) do
		UpdateSlotButton(button)
	end
	ui.reset:SetEnabled(not Loadout.IsEmpty(plan))
	DrawList()
end

function Tab.OnStateChanged()
	Tab.Refresh()
end

-- Frames -----------------------------------------------------------------------------

local function CreateSlotButton(panel, info, index)
	local slot, frameName, slotName = info[1], info[2], info[3]
	local button = CreateFrame("ItemButton", nil, panel)
	button.slot, button.slotName = slot, slotName
	local anchor = _G[frameName]
	if anchor then
		button:SetAllPoints(anchor)
	else
		button:SetSize(37, 37)
		button:SetPoint("TOPLEFT", panel, "TOPLEFT", 20 + math.floor((index - 1) / 8) * 300, -60 - ((index - 1) % 8) * 41)
	end
	button.planned = button:CreateTexture(nil, "OVERLAY")
	button.planned:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
	button.planned:SetBlendMode("ADD")
	button.planned:SetVertexColor(GREEN[1], GREEN[2], GREEN[3])
	button.planned:SetPoint("CENTER")
	button.planned:SetSize(66, 66)
	button.planned:Hide()
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:SetScript("OnClick", function(self, mouse)
		if mouse == "RightButton" then
			Tab.HideFlyout()
			Loadout.Revert(plan, worn, self.slot)
			Save()
			SetStatus(nil)
			Tab.Refresh()
		elseif not PlaceFromCursor(self.slot) then
			Tab.ToggleFlyout(self)
		end
		SlotTooltip(self)
	end)
	button:SetScript("OnReceiveDrag", function(self)
		PlaceFromCursor(self.slot)
	end)
	button:SetScript("OnEnter", SlotTooltip)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	return button
end

local function CreateUI()
	local cf = CharacterFrame
	local panel = CreateFrame("Frame", nil, cf)
	panel:SetFrameLevel(400)
	panel:SetPoint("TOPLEFT", cf.LeftPaneHost, "TOPLEFT")
	panel:SetPoint("BOTTOMRIGHT", cf.LeftPaneHost, "BOTTOMRIGHT")
	panel:EnableMouse(true)
	panel:Hide()

	local bg = panel:CreateTexture(nil, "BACKGROUND", nil, -2)
	bg:SetAllPoints()
	bg:SetColorTexture(0.05, 0.05, 0.05, 1)
	local art = panel:CreateTexture(nil, "BACKGROUND", nil, -1)
	art:SetAtlas("UI-Character-Info-General-BG", true)
	art:SetPoint("TOPLEFT")

	local slots = {}
	for i, info in ipairs(Tab.SLOTS) do
		slots[i] = CreateSlotButton(panel, info, i)
	end

	-- The area between the slot columns holds the changes.
	local middle = CreateFrame("Frame", nil, panel)
	local topLeft, bottomRight = _G.CharacterHeadSlot, _G.CharacterTrinket1Slot
	if topLeft and bottomRight then
		middle:SetPoint("TOPLEFT", topLeft, "TOPRIGHT", 10, 0)
		middle:SetPoint("BOTTOMRIGHT", bottomRight, "BOTTOMLEFT", -8, 0)
	else
		middle:SetPoint("TOPLEFT", 70, -60)
		middle:SetPoint("BOTTOMRIGHT", -70, 60)
	end

	local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", middle, "TOPLEFT", 0, 0)
	scroll:SetPoint("BOTTOMRIGHT", middle, "BOTTOMRIGHT", -22, 0)
	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(180, 1)
	scroll:SetScrollChild(content)
	-- Items dropped anywhere on the list go to the slot they fit.
	for _, target in ipairs({ scroll, content }) do
		target:SetScript("OnReceiveDrag", function()
			PlaceFromCursor(nil)
		end)
		target:SetScript("OnMouseUp", function()
			PlaceFromCursor(nil)
		end)
	end

	local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	reset:SetSize(120, 22)
	reset:SetPoint("BOTTOMLEFT", 12, 12)
	reset:SetText(L.TAB_RESET)
	reset:SetScript("OnClick", function()
		Tab.HideFlyout()
		plan = {}
		Save()
		SetStatus(nil)
		Tab.Refresh()
	end)

	local status = panel:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
	status:SetPoint("BOTTOMLEFT", reset, "TOPLEFT", 0, 4)
	status:SetWidth(130)
	status:SetJustifyH("LEFT")

	-- The bag picker that opens from a slot.
	local flyout = CreateFrame("Frame", nil, panel)
	flyout:SetFrameLevel(panel:GetFrameLevel() + 50)
	flyout:EnableMouse(true)
	local fbg = flyout:CreateTexture(nil, "BACKGROUND")
	fbg:SetAllPoints()
	fbg:SetColorTexture(0, 0, 0, 0.92)
	flyout.empty = flyout:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	flyout.empty:SetPoint("CENTER")
	flyout.empty:SetText(L.TAB_FLYOUT_NONE)
	flyout.buttons = {}
	flyout:Hide()

	ui = {
		panel = panel, slots = slots, middle = middle, status = status, reset = reset,
		scroll = scroll, content = content, rows = {}, flyout = flyout,
	}
	panel:SetScript("OnShow", function()
		Tab.Refresh()
	end)
	panel:SetScript("OnHide", function()
		flyout:Hide()
	end)
	panel:SetScript("OnMouseDown", function()
		flyout:Hide()
	end)
end

-- Bag picker ---------------------------------------------------------------------------

local LEFT_COLUMN = { [1] = true, [2] = true, [3] = true, [15] = true, [5] = true, [4] = true, [19] = true, [9] = true }
local FLYOUT_SIZE, FLYOUT_GAP, FLYOUT_PAD, FLYOUT_PER_ROW = 37, 4, 6, 5

-- Bag items that fit `slot`, other than what the slot shows now.
function Tab.ItemsForSlot(slot)
	local fits, shown = {}, ShownLink(slot)
	local canDualWield = Compat.CanDualWield()
	for _, item in ipairs(ns.Items.Bags()) do
		local ok = false
		for _, s in ipairs(Loadout.SlotsFor(item, canDualWield) or {}) do
			ok = ok or s == slot
		end
		if ok and item.link ~= shown then
			fits[#fits + 1] = item
		end
	end
	return fits
end

local function FlyoutButton(index)
	local flyout = ui.flyout
	local button = flyout.buttons[index]
	if button then
		return button
	end
	button = CreateFrame("ItemButton", nil, flyout)
	button:SetSize(FLYOUT_SIZE, FLYOUT_SIZE)
	button:SetScript("OnClick", function(self)
		flyout:Hide()
		GameTooltip:Hide()
		PlaceLink(self.link, flyout.slot)
	end)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetHyperlink(self.link)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	flyout.buttons[index] = button
	return button
end

function Tab.HideFlyout()
	if ui then
		ui.flyout:Hide()
	end
end

function Tab.ToggleFlyout(slotButton)
	local flyout = ui.flyout
	if flyout:IsShown() and flyout.slot == slotButton.slot then
		flyout:Hide()
		return
	end
	flyout.slot = slotButton.slot
	local items = Tab.ItemsForSlot(slotButton.slot)
	for i, item in ipairs(items) do
		local button = FlyoutButton(i)
		button.link = item.link
		button.icon:SetTexture(Compat.ItemIcon(item.link))
		local quality = Compat.ItemQuality(item.link)
		if quality and SetItemButtonQuality then
			pcall(SetItemButtonQuality, button, quality, item.link)
		end
		local col, row = (i - 1) % FLYOUT_PER_ROW, math.floor((i - 1) / FLYOUT_PER_ROW)
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", flyout, "TOPLEFT", FLYOUT_PAD + col * (FLYOUT_SIZE + FLYOUT_GAP),
			-FLYOUT_PAD - row * (FLYOUT_SIZE + FLYOUT_GAP))
		button:Show()
	end
	for i = #items + 1, #flyout.buttons do
		flyout.buttons[i]:Hide()
	end
	local n = #items
	flyout.empty:SetShown(n == 0)
	if n == 0 then
		flyout:SetSize(190, 30)
	else
		local cols, rows = math.min(n, FLYOUT_PER_ROW), math.ceil(n / FLYOUT_PER_ROW)
		flyout:SetSize(FLYOUT_PAD * 2 + cols * FLYOUT_SIZE + (cols - 1) * FLYOUT_GAP,
			FLYOUT_PAD * 2 + rows * FLYOUT_SIZE + (rows - 1) * FLYOUT_GAP)
	end
	flyout:ClearAllPoints()
	local slot = slotButton.slot
	if slot >= 16 then
		flyout:SetPoint("BOTTOM", slotButton, "TOP", 0, 6)
	elseif LEFT_COLUMN[slot] then
		flyout:SetPoint("TOPLEFT", slotButton, "TOPRIGHT", 6, 0)
	else
		flyout:SetPoint("TOPRIGHT", slotButton, "TOPLEFT", -6, 0)
	end
	flyout:Show()
end

-- The side tab ------------------------------------------------------------------------

local tabButton

local function BlizzardTabs()
	return CharacterFrame and CharacterFrame.ModeTabs and CharacterFrame.ModeTabs.Tabs or {}
end

local function PositionTab()
	if not tabButton then
		return
	end
	local last
	for _, t in ipairs(BlizzardTabs()) do
		if t:IsShown() then
			last = t
		end
	end
	tabButton:ClearAllPoints()
	if last then
		tabButton:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -2)
	else
		tabButton:SetPoint("TOPLEFT", CharacterFrame.ModeTabs, "TOPLEFT")
	end
end

local function MarkTabs()
	local shown = ui and ui.panel:IsShown()
	if shown then
		for _, t in ipairs(BlizzardTabs()) do
			t:SetChecked(false)
		end
	end
	if tabButton then
		tabButton:SetChecked(shown == true)
	end
end

function Tab.Select()
	if not tabButton then
		return
	end
	if not ui then
		CreateUI()
	end
	if CharacterFrame.activeSubframe ~= "PaperDollFrame" and ToggleCharacter then
		ToggleCharacter("PaperDollFrame", true)
	end
	ui.panel:Show()
	MarkTabs()
end

function Tab.Deselect()
	if ui and ui.panel:IsShown() then
		ui.panel:Hide()
		GameTooltip:Hide()
	end
	MarkTabs()
end

-- Opens the character screen on this tab (minimap AddOns menu).
function Tab.Open()
	if not tabButton then
		return false
	end
	if not CharacterFrame:IsShown() and ToggleCharacter then
		ToggleCharacter("PaperDollFrame")
	end
	Tab.Select()
	return true
end

function Tab.Init()
	if tabButton or not (CharacterFrame and CharacterFrame.ModeTabs and CharacterFrame.LeftPaneHost
		and CharacterFrame.RightPaneHost and hooksecurefunc) then
		return tabButton ~= nil
	end
	local ok = pcall(function()
		tabButton = CreateFrame("Frame", nil, CharacterFrame.ModeTabs, "LargeSideTabButtonTemplate")
	end)
	if not ok or not tabButton then
		tabButton = nil
		return false
	end
	tabButton.tooltipText = L.TAB_TOOLTIP
	tabButton.Icon:SetTexture(Tab.ICON)
	if tabButton.SetFillToInterior then
		tabButton:SetFillToInterior(true)
	end
	tabButton:EnableMouse(true)
	tabButton:SetCustomOnMouseUpHandler(function(_, mouse, upInside)
		if mouse == "LeftButton" and upInside then
			Tab.Select()
		end
	end)
	tabButton:SetChecked(false)
	PositionTab()

	hooksecurefunc(CharacterFrame, "UpdateTabLayout", PositionTab)
	hooksecurefunc(CharacterFrame, "OnModeTabClicked", function(_, clicked)
		if clicked ~= tabButton then
			Tab.Deselect()
		end
	end)
	hooksecurefunc(CharacterFrame, "ShowSubFrame", function(_, frameName)
		if frameName ~= "PaperDollFrame" then
			Tab.Deselect()
		end
	end)
	hooksecurefunc(CharacterFrame, "RefreshDisplay", MarkTabs)
	CharacterFrame:HookScript("OnShow", PositionTab)
	CharacterFrame:HookScript("OnHide", Tab.Deselect)
	if HandleModifiedItemClick then
		hooksecurefunc("HandleModifiedItemClick", function(link)
			if ui and ui.panel:IsShown() and type(link) == "string" and link:find("|Hitem:", 1, true)
				and IsModifiedClick and IsModifiedClick("CHATLINK") then
				PlaceLink(link, nil)
			end
		end)
	end

	local events = CreateFrame("Frame")
	events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
	events:RegisterEvent("GET_ITEM_INFO_RECEIVED")
	events:SetScript("OnEvent", function()
		if ui and ui.panel:IsShown() and not events.pending then
			events.pending = true
			local timer = Compat.After(0.3, function()
				events.pending = nil
				Tab.Refresh()
			end)
			if not timer then
				events.pending = nil
				Tab.Refresh()
			end
		end
	end)
	return true
end
