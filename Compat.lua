-- Client compatibility layer. Every call into a client API goes through this file, guarded,
-- so a missing or changed API degrades to "no data" instead of a Lua error.
--
-- Verified against the Blizzard UI source for WoW Forever 1.60.1.70938 (interface 16001),
-- Gethe/wow-ui-source `forever` branch, commit bebcb6b:
--   C_Spell.GetSpellDescription(id) -> string (may be "" until loaded; SPELL_TEXT_UPDATE).
--   C_Spell.GetSpellPowerCost(id) -> { { type, name, cost, minCost, costPercent, ... } } or nil.
--   C_Spell.IsSpellHelpful / IsSpellHarmful / GetSpellName / IsSpellDataCached / RequestLoadSpellData.
--   C_Spell.GetSpellTexture(id) -> iconID (fileID), or nothing for an unknown spell.
--   UNIT_SPELLCAST_SUCCEEDED(unit, castGUID, spellID): SecretWhenUnitSpellCastRestricted.
--   GetSpellBonusDamage(school) / GetSpellBonusHealing(): SecretWhenUnitStatsRestricted, so a
--   value may be "secret" (unreadable) in restricted situations; issecretvalue() detects it.
--   The Forever character sheet shows min(GetSpellBonusDamage(2..7)) as "Spell Damage".
--   GetActionInfo(slot), GetMacroSpell(index): see ActionSpells.lua.
--   C_ClassTalents.GetActiveConfigID, C_Traits.GetConfigInfo(id).treeIDs,
--   C_Traits.GetTreeNodes(treeID), C_Traits.GetNodeInfo(configID, nodeID).ranksPurchased.
--   GetShapeshiftForm() (Shadowform changes spell numbers without changing spell bonus).
local _, ns = ...

local Compat = {}
ns.Compat = Compat

Compat.VERIFIED_INTERFACE = 16001
Compat.VERIFIED_BUILD = "1.60.1.70938"
Compat.MAX_ACTION_SLOT = 180
Compat.SCHOOLS = { 2, 3, 4, 5, 6, 7 } -- holy, fire, nature, frost, shadow, arcane

local function Call(fn, ...)
	if type(fn) ~= "function" then
		return false
	end
	return pcall(fn, ...)
end

function Compat.GetBuildInfo()
	if type(GetBuildInfo) ~= "function" then
		return nil, nil
	end
	local version, build, _, interface = GetBuildInfo()
	return (version or "?") .. "." .. (build or "?"), interface
end

function Compat.GetAddOnVersion(addonName)
	local getter = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
	local ok, value = Call(getter, addonName, "Version")
	if ok and type(value) == "string" then
		return value
	end
	return "?"
end

function Compat.IsSecret(value)
	if type(issecretvalue) ~= "function" then
		return false
	end
	local ok, secret = pcall(issecretvalue, value)
	return ok and secret == true
end

function Compat.InCombat()
	local ok, locked = Call(InCombatLockdown)
	if ok and locked then
		return true
	end
	local ok2, fighting = Call(UnitAffectingCombat, "player")
	return ok2 and fighting == true
end

function Compat.GetPlayerLevel()
	local ok, level = Call(UnitLevel, "player")
	return ok and tonumber(level) or 0
end

function Compat.GetShapeshiftForm()
	local ok, form = Call(GetShapeshiftForm)
	return ok and tonumber(form) or 0
end

-- Spell bonuses ----------------------------------------------------------------------

local function ReadNumber(fn, ...)
	local ok, value = Call(fn, ...)
	if not ok or value == nil or Compat.IsSecret(value) or type(value) ~= "number" then
		return nil
	end
	return value
end

-- { d = { [school] = bonus, 2..7 }, h = healing bonus } or nil if any value is unreadable.
function Compat.ReadBonuses()
	local d = {}
	for _, school in ipairs(Compat.SCHOOLS) do
		local value = ReadNumber(GetSpellBonusDamage, school)
		if not value then
			return nil
		end
		d[school] = value
	end
	local h = ReadNumber(GetSpellBonusHealing)
	if not h then
		return nil
	end
	return { d = d, h = h }
end

-- Spells ---------------------------------------------------------------------------

local function SpellAPI(name)
	return C_Spell and C_Spell[name]
end

function Compat.GetSpellName(spellID)
	local ok, name = Call(SpellAPI("GetSpellName"), spellID)
	if ok and type(name) == "string" then
		return name
	end
	return "#" .. tostring(spellID)
end

-- Icon file ID of a spell, or nil (C_Spell.GetSpellTexture returns nothing for unknown spells).
function Compat.GetSpellIcon(spellID)
	local ok, icon = Call(SpellAPI("GetSpellTexture"), spellID)
	if ok and (type(icon) == "number" or type(icon) == "string") and not Compat.IsSecret(icon) then
		return icon
	end
	return nil
end

-- Description text, or nil when it is not loaded yet (a load is requested).
function Compat.GetSpellDescription(spellID)
	local ok, text = Call(SpellAPI("GetSpellDescription"), spellID)
	if ok and type(text) == "string" and text ~= "" and not Compat.IsSecret(text) then
		return text
	end
	Call(SpellAPI("RequestLoadSpellData"), spellID)
	return nil
end

-- "heal" for helpful spells, "dmg" for harmful ones, nil if unknown.
function Compat.GetSpellKind(spellID)
	local ok, helpful = Call(SpellAPI("IsSpellHelpful"), spellID)
	if ok and helpful == true then
		return "heal"
	end
	local ok2, harmful = Call(SpellAPI("IsSpellHarmful"), spellID)
	if ok2 and harmful == true then
		return "dmg"
	end
	return nil
end

-- Mana cost (or the first cost if the spell uses another power), and the power's name.
function Compat.GetSpellCost(spellID)
	local ok, costs = Call(SpellAPI("GetSpellPowerCost"), spellID)
	if not ok or type(costs) ~= "table" then
		return nil
	end
	local chosen
	for _, c in ipairs(costs) do
		if type(c) == "table" and type(c.cost) == "number" and not Compat.IsSecret(c.cost) then
			if c.name == "MANA" or c.type == 0 then
				chosen = c
				break
			end
			chosen = chosen or c
		end
	end
	if not chosen then
		return nil
	end
	return chosen.cost, chosen.name
end

-- Action bars ----------------------------------------------------------------------

function Compat.ActionApi()
	return {
		maxSlot = Compat.MAX_ACTION_SLOT,
		getActionInfo = function(slot)
			local ok, actionType, id, subType = Call(GetActionInfo, slot)
			if ok then
				return actionType, id, subType
			end
		end,
		getMacroSpell = function(index)
			local ok, spellID = Call(GetMacroSpell, index)
			if ok then
				return spellID
			end
		end,
	}
end

-- Talents --------------------------------------------------------------------------

-- Short fingerprint of the talents currently taken, or "none" if they can't be read yet.
-- Used only to separate gear-state samples taken with different talents.
function Compat.GetTalentSignature()
	if not (C_ClassTalents and C_Traits) then
		return "none"
	end
	local ok, configID = Call(C_ClassTalents.GetActiveConfigID)
	if not ok or not configID then
		return "none"
	end
	local ok2, config = Call(C_Traits.GetConfigInfo, configID)
	if not ok2 or type(config) ~= "table" or type(config.treeIDs) ~= "table" then
		return "none"
	end
	local parts = {}
	for _, treeID in ipairs(config.treeIDs) do
		local ok3, nodes = Call(C_Traits.GetTreeNodes, treeID)
		if ok3 and type(nodes) == "table" then
			for _, nodeID in ipairs(nodes) do
				local ok4, info = Call(C_Traits.GetNodeInfo, configID, nodeID)
				if ok4 and type(info) == "table" and (info.ranksPurchased or 0) > 0 then
					parts[#parts + 1] = nodeID .. "=" .. info.ranksPurchased .. "/" .. tostring(info.activeEntry
						and info.activeEntry.entryID or "")
				end
			end
		end
	end
	if #parts == 0 then
		return "none"
	end
	table.sort(parts)
	-- djb2 hash; modular arithmetic stays exact in doubles.
	local h = 5381
	local text = table.concat(parts, ";")
	for i = 1, #text do
		h = (h * 33 + text:byte(i)) % 4294967296
	end
	return ("%08x"):format(h)
end

-- Timers ---------------------------------------------------------------------------

-- Runs fn after `seconds`; returns a handle with :Cancel(), or nil if timers are unavailable.
function Compat.After(seconds, fn)
	if C_Timer and C_Timer.NewTimer then
		return C_Timer.NewTimer(seconds, fn)
	end
	return nil
end

-- Items ----------------------------------------------------------------------------
-- C_Item.GetItemInfoInstant(link) -> itemID, type, subType, equipLoc, ... (no server query).
-- C_TooltipInfo.GetHyperlink(link) -> { lines = { { leftText = ... } } }: the item's tooltip
-- lines, including enchants and random "of Healing" suffixes carried by the link.
-- GetInventoryItemLink("player", slot); C_Container.GetContainerNumSlots(bag) /
-- GetContainerItemLink(bag, slot) for bags 0-4.

function Compat.ItemEquipLoc(link)
	local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
	local ok, _, _, _, equipLoc = Call(fn, link)
	if ok and type(equipLoc) == "string" and equipLoc ~= "" then
		return equipLoc
	end
	return nil
end

function Compat.ItemName(link)
	return type(link) == "string" and link:match("|h%[(.-)%]|h") or "?"
end

-- Tooltip text lines of an item link, or nil while the item is not loaded yet.
function Compat.ItemLines(link)
	if not (C_TooltipInfo and C_TooltipInfo.GetHyperlink) then
		return nil
	end
	-- A freshly dropped item may not be loaded yet; its tooltip would lack the "Equip:"
	-- lines and read as "no bonus". Ask for it and report "not loaded".
	local itemID = tonumber(type(link) == "string" and link:match("item:(%d+)") or nil)
	if itemID and C_Item and C_Item.IsItemDataCachedByID then
		local okCached, cached = Call(C_Item.IsItemDataCachedByID, itemID)
		if okCached and cached == false then
			Call(C_Item.RequestLoadItemDataByID, itemID)
			return nil
		end
	end
	local ok, data = Call(C_TooltipInfo.GetHyperlink, link)
	if not ok or type(data) ~= "table" or type(data.lines) ~= "table" or #data.lines == 0 then
		return nil
	end
	local lines = {}
	for i, line in ipairs(data.lines) do
		local text = line.leftText
		if type(text) == "string" and not Compat.IsSecret(text) then
			lines[i] = text
		else
			lines[i] = ""
		end
	end
	-- Right-hand texts ("Speed 2.80", "Mace") follow as lines of their own.
	for _, line in ipairs(data.lines) do
		local text = line.rightText
		if type(text) == "string" and text ~= "" and not Compat.IsSecret(text) then
			lines[#lines + 1] = text
		end
	end
	return lines
end

-- Item class and subclass (2 = weapon; weapon subclass 15 = dagger), or nil.
function Compat.ItemClass(link)
	local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
	local ok, _, _, _, _, _, classID, subclassID = Call(fn, link)
	if ok and type(classID) == "number" then
		return classID, subclassID
	end
	return nil
end

function Compat.EquippedLink(slot)
	local ok, link = Call(GetInventoryItemLink, "player", slot)
	if ok and type(link) == "string" then
		return link
	end
	return nil
end

-- Every item link in the backpack and bags 1-4.
function Compat.BagLinks()
	local links = {}
	if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemLink) then
		return links
	end
	for bag = 0, 4 do
		local ok, count = Call(C_Container.GetContainerNumSlots, bag)
		if ok and type(count) == "number" then
			for slot = 1, count do
				local ok2, link = Call(C_Container.GetContainerItemLink, bag, slot)
				if ok2 and type(link) == "string" then
					links[#links + 1] = link
				end
			end
		end
	end
	return links
end

function Compat.IsAltKeyDown()
	local ok, down = Call(IsAltKeyDown)
	return ok and down == true
end

-- Character tab ----------------------------------------------------------------------
-- GetCursorInfo() -> "item", itemID, itemLink while an item is on the cursor.
-- CanDualWield(), GetInventorySlotInfo(slotName) -> slotID, emptyTexture.
-- UnitStat("player", 1..5) -> base, effective, ... (strength, agility, stamina, intellect,
-- spirit); UnitArmor("player") -> base, effective. Either may be secret when stats are restricted.

function Compat.CanDualWield()
	local ok, can = Call(CanDualWield)
	return ok and can == true
end

function Compat.CursorItemLink()
	local ok, kind, _, link = Call(GetCursorInfo)
	if ok and kind == "item" and type(link) == "string" then
		return link
	end
	return nil
end

function Compat.ClearCursor()
	Call(ClearCursor)
end

function Compat.SlotEmptyTexture(slotName)
	local ok, _, texture = Call(GetInventorySlotInfo, slotName)
	if ok then
		return texture
	end
	return nil
end

function Compat.ItemIcon(link)
	local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
	local ok, _, _, _, _, icon = Call(fn, link)
	if ok and icon then
		return icon
	end
	return nil
end

function Compat.ItemQuality(link)
	local fn = (C_Item and C_Item.GetItemInfo) or GetItemInfo
	local ok, _, _, quality = Call(fn, link)
	if ok and type(quality) == "number" then
		return quality
	end
	return nil
end

-- The character's numbers that gear changes, for Body.lua. Every reader is the one the
-- game's own character screen uses (Blizzard_UIPanels_Game/Camelot/PaperDollFrame*.lua):
--   UnitAttackPower / UnitRangedAttackPower -> base, buffs, debuffs
--   UnitDamage -> min, max, offhand min, max, bonus, penalty, percent
--   UnitRangedDamage -> speed, min, max, bonus, penalty, percent
--   GetAttackPowerForStat(stat, value), GetRangedAttackPowerForStat(stat, value),
--   GetCritChanceFromStat(stat, value), GetSpellCritChanceFromStat(stat, value): what a stat
--   value is worth (the stat tooltips call them with the current value; we call them with
--   the planned one too), UnitHPPerStamina, GetDodgeChanceFromAttribute,
--   C_PaperDollInfo.GetArmorEffectiveness(armor, attackerLevel).
-- Unreadable or secret values are left out; Body.lua then leaves out what depends on them.
local function Num(fn, ...)
	local ok, value = Call(fn, ...)
	if ok and type(value) == "number" and not Compat.IsSecret(value) then
		return value
	end
	return nil
end

local function Pack(...)
	return select("#", ...), { ... }
end

-- All return values of fn as numbers (nil returns stay nil, e.g. no off-hand), or nil when
-- the call fails or any value is not a readable number.
local function Nums(fn, ...)
	local n, packed = Pack(Call(fn, ...))
	if not packed[1] then
		return nil
	end
	local out = {}
	for i = 2, n do
		local v = packed[i]
		if v ~= nil then
			if type(v) ~= "number" or Compat.IsSecret(v) then
				return nil
			end
			out[i - 1] = v
		end
	end
	return out
end

-- Average of a live damage range with bonuses and percent taken out (as the game's own
-- damage tooltip does): what the weapon and attack power give.
local function LiveBase(min, max, pos, neg, percent)
	if not (min and max and percent and percent > 0) then
		return nil
	end
	return { base = (min + max) / 2 / percent - (pos or 0) - (neg or 0), bonus = (pos or 0) + (neg or 0), pct = percent }
end

local function StatFn(fn)
	if type(fn) ~= "function" then
		return nil
	end
	return function(stat, value)
		return Num(fn, stat, value)
	end
end

function Compat.Snapshot()
	local snap = { stats = {}, fn = {} }
	local okClass, _, classFile = Call(UnitClass, "player")
	snap.class = okClass and classFile or nil
	snap.level = Compat.GetPlayerLevel()
	for index, key in ipairs({ "str", "agi", "sta", "int", "spi" }) do
		local r = Nums(UnitStat, "player", index)
		snap.stats[key] = r and r[2]
	end
	local ap = Nums(UnitAttackPower, "player")
	snap.ap = ap and ap[1] + (ap[2] or 0) + (ap[3] or 0)
	local rap = Nums(UnitRangedAttackPower, "player")
	snap.rap = rap and rap[1] + (rap[2] or 0) + (rap[3] or 0)
	local d = Nums(UnitDamage, "player")
	snap.melee = d and LiveBase(d[1], d[2], d[5], d[6], d[7])
	snap.offhand = d and d[3] and d[4] and d[4] > 0 and LiveBase(d[3], d[4], d[5], d[6], d[7]) or nil
	local r = Nums(UnitRangedDamage, "player")
	snap.ranged = r and (r[1] or 0) > 0 and LiveBase(r[2], r[3], r[4], r[5], r[6]) or nil
	snap.health = Num(UnitHealthMax, "player")
	snap.mana = Num(UnitPowerMax, "player", 0)
	snap.crit = Num(GetCritChance)
	snap.rangedCrit = Num(GetRangedCritChance)
	local spellCrit
	for school = 2, 7 do
		local v = Num(GetSpellCritChance, school)
		if v and (not spellCrit or v > spellCrit) then
			spellCrit = v
		end
	end
	snap.spellCrit = spellCrit
	snap.dodge = Num(GetDodgeChance)
	snap.parry = Num(GetParryChance)
	snap.block = Num(GetBlockChance)
	snap.blockValue = Num(GetShieldBlock)
	local armor = Nums(UnitArmor, "player")
	snap.armor = armor and armor[2]
	local def = Nums(UnitDefense, "player")
	snap.defense = def and def[1] + (def[2] or 0)
	local fn = snap.fn
	fn.apFor = StatFn(GetAttackPowerForStat)
	fn.rapFor = StatFn(GetRangedAttackPowerForStat)
	fn.critFor = StatFn(GetCritChanceFromStat)
	fn.spellCritFor = StatFn(GetSpellCritChanceFromStat)
	fn.hpPerSta = Num(UnitHPPerStamina, "player")
	fn.dodgeFromAgi = Num(GetDodgeChanceFromAttribute)
	if C_PaperDollInfo and type(C_PaperDollInfo.GetArmorEffectiveness) == "function" then
		fn.armorEff = function(value)
			return Num(C_PaperDollInfo.GetArmorEffectiveness, value, snap.level)
		end
	end
	fn.staBreak = type(STAMINA_BREAK) == "number" and STAMINA_BREAK or 20
	fn.intBreak = type(INTELLECT_BREAK) == "number" and INTELLECT_BREAK or 20
	fn.manaPerInt = type(MANA_PER_INTELLECT) == "number" and MANA_PER_INTELLECT or 15
	fn.apPerDps = type(ATTACK_POWER_MAGIC_NUMBER) == "number" and ATTACK_POWER_MAGIC_NUMBER or 14
	-- Druid Cat or Bear Form: auto attacks swing at the form's own speed.
	if snap.class == "DRUID" then
		local formID = Num(GetShapeshiftFormID)
		local feral = (formID == 1 and "cat") or ((formID == 5 or formID == 8) and "bear") or nil
		local speed = feral and Num(UnitAttackSpeed, "player")
		if feral and speed and speed > 0 then
			snap.feral, snap.formSpeed = feral, speed
		end
	end
	return snap
end

-- { str, agi, sta, int, spi, armor } as shown on the character sheet; unreadable ones left out.
function Compat.PlayerStats()
	local stats = {}
	for index, key in ipairs({ "str", "agi", "sta", "int", "spi" }) do
		local ok, _, value = Call(UnitStat, "player", index)
		if ok and type(value) == "number" and not Compat.IsSecret(value) then
			stats[key] = value
		end
	end
	local ok, _, armor = Call(UnitArmor, "player")
	if ok and type(armor) == "number" and not Compat.IsSecret(armor) then
		stats.armor = armor
	end
	return stats
end
