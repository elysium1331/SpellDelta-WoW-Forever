-- A planned set of gear: the player's worn items with some slots replaced. Pure Lua;
-- unit-tested. Used by the SpellDelta tab on the character screen.
--
-- item = { link, loc, name, bonus, stats } (Items.For)
-- worn = { [slot] = item }                 what the character wears now
-- plan = { [slot] = item | false }          changes only; false = slot emptied
--
-- Rules follow the game: a two-hander empties the off-hand, an off-hand item replaces a
-- two-hander, a one-hander goes in the off-hand only for characters who can dual wield.
local _, ns = ...

local Gear = ns.Gear

local Loadout = {}
ns.Loadout = Loadout

local TWO_HAND = "INVTYPE_2HWEAPON"

local function SlotsFor(item, canDualWield)
	local slots = item and Gear.SLOTS[item.loc]
	if not slots then
		return nil
	end
	if item.loc == "INVTYPE_WEAPON" and canDualWield then
		return { 16, 17 }
	end
	return slots
end
Loadout.SlotsFor = SlotsFor

-- The items the plan would have on: { [slot] = item }.
function Loadout.Effective(worn, plan)
	local eff = {}
	for slot, item in pairs(worn) do
		eff[slot] = item
	end
	for slot, item in pairs(plan) do
		eff[slot] = item or nil
	end
	return eff
end

-- Drops entries that equal what is worn.
local function Tidy(plan, worn)
	for slot, item in pairs(plan) do
		local w = worn[slot]
		if (item == false and not w) or (item and w and item.link == w.link) then
			plan[slot] = nil
		end
	end
end

local function Set(plan, slot, item)
	plan[slot] = item
end

-- Puts `item` into `slot` (or the slot it fits best when slot is nil).
-- Returns the slot used, or nil and a reason: "cannot" (not wearable), "slot" (wrong slot).
function Loadout.Place(plan, worn, item, slot, canDualWield)
	local slots = SlotsFor(item, canDualWield)
	if not slots then
		return nil, "cannot"
	end
	if slot then
		local fits = false
		for _, s in ipairs(slots) do
			fits = fits or s == slot
		end
		if not fits then
			return nil, "slot"
		end
	elseif #slots == 1 then
		slot = slots[1]
	elseif item.loc == "INVTYPE_WEAPON" then
		slot = 16
	else
		-- Two ring or trinket slots: an empty one, else one not yet changed (the weaker), else the first.
		local eff = Loadout.Effective(worn, plan)
		for _, s in ipairs(slots) do
			if not slot and not eff[s] then
				slot = s
			end
		end
		if not slot then
			local a, b = slots[1], slots[2]
			if plan[a] == nil and plan[b] ~= nil then
				slot = a
			elseif plan[b] == nil and plan[a] ~= nil then
				slot = b
			else
				slot = Gear.Score(eff[a] and eff[a].bonus) <= Gear.Score(eff[b] and eff[b].bonus) and a or b
			end
		end
	end
	Set(plan, slot, item)
	local eff = Loadout.Effective(worn, plan)
	if slot == 16 and item.loc == TWO_HAND and eff[17] then
		Set(plan, 17, false)
	elseif slot == 17 and eff[16] and eff[16].loc == TWO_HAND then
		Set(plan, 16, false)
	end
	Tidy(plan, worn)
	return slot
end

-- Puts the worn item back in `slot`. If that clashes with a planned two-hander or off-hand,
-- the other hand goes back to what is worn too.
function Loadout.Revert(plan, worn, slot)
	plan[slot] = nil
	local eff = Loadout.Effective(worn, plan)
	if eff[16] and eff[16].loc == TWO_HAND and eff[17] then
		plan[slot == 17 and 16 or 17] = nil
	end
	Tidy(plan, worn)
end

-- Fixes a plan that no longer fits what is worn (the player equipped something from the bags):
-- a planned off-hand next to a newly worn two-hander is dropped; a planned two-hander next to a
-- newly worn off-hand takes the off-hand off.
function Loadout.Normalize(plan, worn)
	local eff = Loadout.Effective(worn, plan)
	if eff[16] and eff[16].loc == TWO_HAND and eff[17] then
		if plan[16] == nil then
			plan[17] = nil
		else
			plan[17] = false
		end
	end
	Tidy(plan, worn)
end

function Loadout.IsEmpty(plan)
	return next(plan) == nil
end

-- { [slot] = item | false } for Gear.Delta: only slots that really differ from worn.
function Loadout.Changes(plan, worn)
	local changes = {}
	for slot, item in pairs(plan) do
		local w = worn[slot]
		if item == false then
			if w then
				changes[slot] = false
			end
		elseif not w or w.link ~= item.link then
			changes[slot] = item
		end
	end
	return changes
end

-- Stat change of a plan: { [key] = number }, zero entries left out.
function Loadout.StatDelta(plan, worn)
	local delta = {}
	local function add(item, sign)
		for key, n in pairs(item and item.stats or {}) do
			delta[key] = (delta[key] or 0) + sign * n
		end
	end
	for slot, item in pairs(Loadout.Changes(plan, worn)) do
		add(item or nil, 1)
		add(worn[slot], -1)
	end
	for key, n in pairs(delta) do
		if n == 0 then
			delta[key] = nil
		end
	end
	return delta
end

-- Spell bonus change of a plan (Gear.Delta's format).
function Loadout.BonusDelta(plan, worn)
	return Gear.Delta({ changes = Loadout.Changes(plan, worn) }, worn)
end

-- Saved form: { [slot] = link | false }.
function Loadout.Save(plan)
	local saved = {}
	for slot, item in pairs(plan) do
		saved[slot] = item and item.link or false
	end
	return saved
end

-- Rebuilds a plan from its saved form. itemFor(link) -> item or nil.
function Loadout.Restore(saved, worn, itemFor)
	local plan = {}
	for slot, link in pairs(saved or {}) do
		if link == false then
			plan[slot] = false
		elseif type(link) == "string" then
			local item = itemFor(link)
			if item and item.loc then
				plan[slot] = item
			end
		end
	end
	Loadout.Normalize(plan, worn)
	return plan
end
