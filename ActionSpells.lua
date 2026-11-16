-- The spells on the player's action bars, including spells inside macros. Pure Lua with the
-- game calls passed in (`api`), so it is unit-tested without a client.
--
-- Verified against Blizzard's action button code for 1.60.1.70938
-- (Blizzard_ActionBar/Shared/ActionButton.lua, Mainline/AssistedCombatManager.lua):
--   GetActionInfo(slot) -> "spell", spellID
--   GetActionInfo(slot) -> "macro", spellID, "spell"   (the macro already resolved to a spell)
--   GetActionInfo(slot) -> "macro", macroIndex          (then GetMacroSpell(macroIndex))
local _, ns = ...

local ActionSpells = {}
ns.ActionSpells = ActionSpells

local function ValidID(id)
	return type(id) == "number" and id > 0 and id == math.floor(id)
end

-- api = { maxSlot = n, getActionInfo = fn(slot), getMacroSpell = fn(index) }
-- Returns a list ordered by first slot: { spellID, slots = { ... }, viaMacro = bool }.
-- A spell that is both on a bar and in a macro counts as a bar spell.
function ActionSpells.Collect(api)
	local list, byID = {}, {}
	for slot = 1, api.maxSlot do
		local actionType, id, subType = api.getActionInfo(slot)
		local spellID, viaMacro
		if actionType == "spell" then
			spellID, viaMacro = id, false
		elseif actionType == "macro" then
			if subType == "spell" then
				spellID = id
			elseif id ~= nil then
				spellID = api.getMacroSpell(id)
			end
			viaMacro = true
		end
		if ValidID(spellID) then
			local entry = byID[spellID]
			if not entry then
				entry = { spellID = spellID, slots = {}, viaMacro = viaMacro }
				byID[spellID] = entry
				list[#list + 1] = entry
			elseif not viaMacro then
				entry.viaMacro = false
			end
			entry.slots[#entry.slots + 1] = slot
		end
	end
	return list
end
