-- Item spell bonuses and "what would this item replace". Pure Lua; unit-tested.
--
-- ItemBonus: reads an item's spell damage / healing from its tooltip lines (English):
--   "Equip: Increases damage and healing done by magical spells and effects by up to 34."
--   "Equip: Increases healing done by magical spells and effects by up to 68."
--   "Equip: Increases damage done by Shadow spells and effects by up to 28."
--   "Equip: Increases healing done by up to 20 and damage done by up to 7 for all magical
--    spells and effects." (healing and damage split, a common wording on caster gear)
--   "+13 Shadow Spell Damage", "+22 Healing Spells", "+15 Damage and Healing Spells"
-- "Use:" effects and set bonuses are ignored (they are not always active).
--
-- Plan: which equipped items a hovered item would replace, pairing a two-hander swap
-- with the best one-hander or off-hand in the bags, the way the game's own comparison
-- does ("With Death Speaker Scepter equipped in main-hand").
local _, ns = ...

local Gear = {}
ns.Gear = Gear

local SCHOOL_BY_NAME = { holy = 2, fire = 3, nature = 4, frost = 5, shadow = 6, arcane = 7 }
local ALL_SCHOOLS = { 2, 3, 4, 5, 6, 7 }

local function NewBonus()
	return { d = { [2] = 0, [3] = 0, [4] = 0, [5] = 0, [6] = 0, [7] = 0 }, h = 0 }
end
Gear.NewBonus = NewBonus

local function AddAll(bonus, amount, healing)
	for _, school in ipairs(ALL_SCHOOLS) do
		bonus.d[school] = bonus.d[school] + amount
	end
	if healing then
		bonus.h = bonus.h + amount
	end
end

-- "stamina +4" -> "+4 stamina", so enchants read like the item's own stats.
local function Flip(part)
	part = part:gsub("^%s*and%s+", ""):match("^%s*(.-)%s*%.?$")
	local name, amount = part:match("^([%a%s]-)%s*(%+%d+%.?%d*)$")
	if name and name ~= "" then
		return amount .. " " .. name
	end
	return part
end

-- A tooltip line as parts in lower case without colors, "Equip:" or "Enchanted:"; empty for
-- lines that are not always active (Use:, Chance on hit:, set bonuses). Enchants are worded
-- "Stamina +4", "Healing +6 and Spell Damage +2" or "Stamina +10, Defense +7 and Healing +24";
-- each amount becomes its own part ("+6 healing", "+2 spell damage"). "+18 Healing and Spell
-- Damage" stays whole: only one side has a number.
local function Parts(line)
	local text = line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):match("^%s*(.-)%s*$"):lower()
	if text:find("^use:") or text:find("^chance on hit:") or text:find("set:") then
		return {}
	end
	local enchant = text:match("^enchanted:%s*(.*)$")
	if not enchant then
		return { (text:gsub("^equip:%s*", "")) }
	end
	local parts = {}
	for piece in (enchant .. "/"):gmatch("([^/,]+)[/,]") do
		local rest = piece
		while true do
			local a, b = rest:match("^(.-%d.-) and (.-%d.*)$")
			if not a then
				break
			end
			parts[#parts + 1] = Flip(a)
			rest = b
		end
		parts[#parts + 1] = Flip(rest)
	end
	return parts
end
Gear.Parts = Parts

-- One cleaned part -> adds to bonus. Returns true if it was a spell bonus.
local function ParseLine(bonus, body)
	local n = body:match("^increases damage and healing done by magical spells and effects by up to (%d+)")
	if n then
		AddAll(bonus, tonumber(n), true)
		return true
	end
	-- Healing and damage split: "healing done by up to 20 and damage done by up to 7 for all
	-- magical spells and effects", or "healing done by spells and effects by up to 20 and
	-- damage done by up to 7".
	local heal, dmg = body:match("^increases healing done by up to (%d+) and damage done by up to (%d+)")
	if not heal then
		heal, dmg = body:match("^increases healing done by .-spells and effects by up to (%d+) and damage done by up to (%d+)")
	end
	if heal then
		AddAll(bonus, tonumber(dmg), false)
		bonus.h = bonus.h + tonumber(heal)
		return true
	end
	n = body:match("^increases damage done by spells and effects by up to (%d+)")
		or body:match("^increases damage done by magical spells and effects by up to (%d+)")
	if n then
		AddAll(bonus, tonumber(n), false)
		return true
	end
	n = body:match("^increases healing done by .-spells and effects by up to (%d+)")
	if n then
		bonus.h = bonus.h + tonumber(n)
		return true
	end
	local school
	school, n = body:match("^increases damage done by (%a+) spells and effects by up to (%d+)")
	if school and SCHOOL_BY_NAME[school] then
		bonus.d[SCHOOL_BY_NAME[school]] = bonus.d[SCHOOL_BY_NAME[school]] + tonumber(n)
		return true
	end
	n = body:match("^%+(%d+) damage and healing") or body:match("^%+(%d+) spell damage and healing")
		or body:match("^%+(%d+) healing and spell damage") or body:match("^%+(%d+) healing and damage")
		or body:match("^%+(%d+) spell power")
	if n then
		AddAll(bonus, tonumber(n), true)
		return true
	end
	n = body:match("^%+(%d+) healing") or body:match("^%+(%d+) spell healing")
	if n then
		bonus.h = bonus.h + tonumber(n)
		return true
	end
	n, school = body:match("^%+(%d+) (%a+) spell damage")
	if n and SCHOOL_BY_NAME[school] then
		bonus.d[SCHOOL_BY_NAME[school]] = bonus.d[SCHOOL_BY_NAME[school]] + tonumber(n)
		return true
	end
	n = body:match("^%+(%d+) spell damage")
	if n then
		AddAll(bonus, tonumber(n), false)
		return true
	end
	return false
end

-- lines: array of strings. Returns bonus = { d = { [2..7] }, h }.
function Gear.ParseBonus(lines)
	local bonus = NewBonus()
	for _, line in ipairs(lines or {}) do
		if type(line) == "string" then
			for _, part in ipairs(Parts(line)) do
				ParseLine(bonus, part)
			end
		end
	end
	return bonus
end

-- Item stats other than spell bonuses, read from tooltip lines (English). Keys:
--   str, agi, sta, int, spi, armor, block, ap, rap, mp5, hp5, crit, spellcrit, hit, spellhit,
--   def, dodge, parry, blockpct
-- Weapons also get wmin, wmax ("28 - 52 Damage") and speed ("Speed 2.80"); ammunition gets
-- ammodps ("Adds 7.5 damage per second"). Attack power that only counts against some foes or
-- in some forms ("+45 Attack Power when fighting Undead") is left out.
Gear.STAT_ORDER = { "sta", "int", "spi", "str", "agi", "health", "mana", "armor", "ap", "rap", "mp5", "hp5", "spellcrit", "crit",
	"spellhit", "hit", "def", "dodge", "parry", "blockpct", "block", "feralap" }
local PRIMARY = { stamina = "sta", intellect = "int", spirit = "spi", strength = "str", agility = "agi" }
-- Percent amounts may have a decimal ("by 1.0%"). A rule with two keys adds to both.
local PCT = "(%d+%.?%d*)%%"
local EQUIP_STATS = {
	{ "^restores (%d+) mana per 5 sec", "mp5" },
	{ "^restores (%d+) health per 5 sec", "hp5" },
	{ "^%+(%d+) mana every 5 sec", "mp5" },
	{ "^%+(%d+) mana per 5 sec", "mp5" },
	{ "^mana regen (%d+) per 5 sec", "mp5" },
	{ "^improves your chance to get a critical strike with spells by " .. PCT, "spellcrit" },
	{ "^improves your chance to get a critical strike with melee attacks by " .. PCT, "crit" },
	{ "^improves your chance to get a critical strike by " .. PCT, "crit" },
	{ "^increases your critical strike chance with spells and attacks by " .. PCT, "crit", "spellcrit" },
	{ "^improves your chance to hit with spells by " .. PCT, "spellhit" },
	{ "^chance to hit with spells increased by " .. PCT, "spellhit" },
	{ "^improves your chance to hit by " .. PCT, "hit" },
	{ "^increases the block value of your shield by (%d+)%.?$", "block" },
	{ "^%+(%d+) block value", "block" },
	{ "^%+(%d+) armor%.?$", "armor" },
	{ "^increases your armor by (%d+)%.?$", "armor" },
	{ "^%+(%d+) health%.?$", "health" },
	{ "^%+(%d+) hit points%.?$", "health" },
	{ "^%+(%d+) mana%.?$", "mana" },
	{ "^%+(%d+) defense%.?$", "def" },
	{ "^%+(%d+) defense skill%.?$", "def" },
	{ "^increases your defense by (%d+)%.?$", "def" },
	{ "^%+(%d+) ranged attack power%.?$", "rap" },
	{ "^%+(%d+) attack power%.?$", "ap" },
	-- Druid weapons: only counts in Cat or Bear Form, so it is kept apart (Body adds it in form).
	{ "^%+(%d+) attack power in cat, bear", "feralap" },
	{ "^increases attack power by (%d+) in cat, bear", "feralap" },
	{ "^increased defense %+(%d+)", "def" },
	{ "^increases your chance to dodge an attack by " .. PCT, "dodge" },
	{ "^%+" .. PCT .. " dodge", "dodge" },
	{ "^increases your chance to parry an attack by " .. PCT, "parry" },
	{ "^increases your chance to block attacks with a shield by " .. PCT, "blockpct" },
}
local ALL_PRIMARY = { "str", "agi", "sta", "int", "spi" }

function Gear.ParseStats(lines)
	local stats = {}
	local function add(key, n)
		stats[key] = (stats[key] or 0) + n
	end
	for _, line in ipairs(lines or {}) do
		for _, text in ipairs(type(line) == "string" and Parts(line) or {}) do
			do
				local sign, n, name = text:match("^([%+%-])(%d+) (%a+)%.?$")
				local all = text:match("^%+(%d+) all stats%.?$") or text:match("^%+(%d+) stats%.?$")
				local n2 = text:match("^(%d+) armor$")
				local n3 = text:match("^(%d+) block$")
				local wmin, wmax = text:match("^(%d+) %- (%d+) damage$")
				local speed = text:match("^speed (%d+%.?%d*)$")
				local ammo = text:match("^adds (%d+%.?%d*) damage per second$")
				if wmin and not stats.wmin then
					stats.wmin, stats.wmax = tonumber(wmin), tonumber(wmax)
				elseif speed then
					stats.speed = tonumber(speed)
				elseif ammo then
					stats.ammodps = tonumber(ammo)
				elseif sign and PRIMARY[name] then
					add(PRIMARY[name], (sign == "-" and -1 or 1) * tonumber(n))
				elseif all then
					for _, key in ipairs(ALL_PRIMARY) do
						add(key, tonumber(all))
					end
				elseif n2 then
					add("armor", tonumber(n2))
				elseif n3 then
					add("block", tonumber(n3))
				else
					for _, rule in ipairs(EQUIP_STATS) do
						local v = text:match(rule[1])
						if v then
							for i = 2, #rule do
								add(rule[i], tonumber(v))
							end
							break
						end
					end
				end
			end
		end
	end
	return stats
end

-- A single number for "which of two items gives more spell power".
function Gear.Score(bonus)
	if not bonus then
		return 0
	end
	local best = 0
	for _, school in ipairs(ALL_SCHOOLS) do
		best = math.max(best, bonus.d[school] or 0)
	end
	return best + (bonus.h or 0)
end

function Gear.IsZero(bonus)
	if (bonus.h or 0) ~= 0 then
		return false
	end
	for _, school in ipairs(ALL_SCHOOLS) do
		if (bonus.d[school] or 0) ~= 0 then
			return false
		end
	end
	return true
end

-- Inventory slots each equip location can go into.
Gear.SLOTS = {
	INVTYPE_HEAD = { 1 }, INVTYPE_NECK = { 2 }, INVTYPE_SHOULDER = { 3 }, INVTYPE_BODY = { 4 },
	INVTYPE_CHEST = { 5 }, INVTYPE_ROBE = { 5 }, INVTYPE_WAIST = { 6 }, INVTYPE_LEGS = { 7 },
	INVTYPE_FEET = { 8 }, INVTYPE_WRIST = { 9 }, INVTYPE_HAND = { 10 }, INVTYPE_FINGER = { 11, 12 },
	INVTYPE_TRINKET = { 13, 14 }, INVTYPE_CLOAK = { 15 }, INVTYPE_WEAPON = { 16 },
	INVTYPE_2HWEAPON = { 16 }, INVTYPE_WEAPONMAINHAND = { 16 }, INVTYPE_WEAPONOFFHAND = { 17 },
	INVTYPE_SHIELD = { 17 }, INVTYPE_HOLDABLE = { 17 }, INVTYPE_RANGED = { 18 },
	INVTYPE_RANGEDRIGHT = { 18 }, INVTYPE_THROWN = { 18 }, INVTYPE_RELIC = { 18 },
}
local MAIN_HAND = { INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true }
local OFF_HAND = { INVTYPE_WEAPONOFFHAND = true, INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true }

-- Weapon damage per second from an item's tooltip numbers (0 for non-weapons).
function Gear.WeaponDps(item)
	local s = item and item.stats
	if s and s.wmin and s.wmax and s.speed and s.speed > 0 then
		return (s.wmin + s.wmax) / 2 / s.speed
	end
	return 0
end

-- The bag item a two-hander swap pairs with: the most spell bonus, then the most weapon damage.
local function Better(a, b)
	local sa, sb = Gear.Score(a.bonus), Gear.Score(b.bonus)
	if sa ~= sb then
		return sa > sb
	end
	return Gear.WeaponDps(a) > Gear.WeaponDps(b)
end

local function Best(items, accept, exclude)
	local best
	for _, item in ipairs(items or {}) do
		if accept[item.loc] and item.link ~= exclude and (not best or Better(item, best)) then
			best = item
		end
	end
	return best
end

-- hovered  = { link, loc, name, bonus }
-- equipped = { [slot] = { link, loc, name, bonus } }
-- bags     = function() -> array of items (only called when a pairing is needed)
-- Returns plan = { changes = { [slot] = item or false }, paired = item or nil } or nil when
-- the item can't be equipped or is already equipped.
function Gear.Plan(hovered, equipped, bags)
	local slots = hovered and Gear.SLOTS[hovered.loc]
	if not slots then
		return nil
	end
	for _, slot in ipairs(slots) do
		if equipped[slot] and equipped[slot].link == hovered.link then
			return nil
		end
	end
	local changes, paired = {}, nil
	local mainHand = equipped[16]
	local wearingTwoHander = mainHand and mainHand.loc == "INVTYPE_2HWEAPON"
	if hovered.loc == "INVTYPE_2HWEAPON" then
		changes[16] = hovered
		if equipped[17] then
			changes[17] = false
		end
	elseif OFF_HAND[hovered.loc] then
		changes[17] = hovered
		if wearingTwoHander then
			paired = Best(type(bags) == "function" and bags() or bags, MAIN_HAND, hovered.link)
			changes[16] = paired or false
		end
	elseif MAIN_HAND[hovered.loc] then
		changes[16] = hovered
		if wearingTwoHander then
			paired = Best(type(bags) == "function" and bags() or bags, OFF_HAND, hovered.link)
			if paired then
				changes[17] = paired
			end
		end
	elseif #slots == 2 then
		local a, b = equipped[slots[1]], equipped[slots[2]]
		local slot
		if not a then
			slot = slots[1]
		elseif not b then
			slot = slots[2]
		else
			slot = Gear.Score(a.bonus) <= Gear.Score(b.bonus) and slots[1] or slots[2]
		end
		changes[slot] = hovered
	else
		changes[slots[1]] = hovered
	end
	return { changes = changes, paired = paired }
end

-- Bonus change of a plan: new items minus the items they replace.
function Gear.Delta(plan, equipped)
	local delta = NewBonus()
	local function add(item, sign)
		if item and item.bonus then
			for _, school in ipairs(ALL_SCHOOLS) do
				delta.d[school] = delta.d[school] + sign * (item.bonus.d[school] or 0)
			end
			delta.h = delta.h + sign * (item.bonus.h or 0)
		end
	end
	for slot, item in pairs(plan.changes) do
		add(item or nil, 1)
		add(equipped[slot], -1)
	end
	return delta
end

-- Names of the equipped items a plan takes off, in slot order.
function Gear.Replaced(plan, equipped)
	local slots = {}
	for slot in pairs(plan.changes) do
		if equipped[slot] then
			slots[#slots + 1] = slot
		end
	end
	table.sort(slots)
	local names = {}
	for _, slot in ipairs(slots) do
		names[#names + 1] = equipped[slot].name
	end
	return names
end
