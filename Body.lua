-- What gear changes about the character beyond spell bonuses: health, mana, attack power,
-- crit, avoidance, armor, and the damage of weapon strikes. Pure Lua; unit-tested.
--
-- snap (Compat.Snapshot) holds the live numbers and the game's own "what is a stat worth"
-- functions. Everything here is worked out from those; when a number or function is missing
-- (unreadable or secret), whatever depends on it is left out rather than guessed.
--
-- Weapon strikes (SpellData.strikes): the game's formula for a weapon hit is
--   (weapon damage + attack power / 14 * weapon speed + bonus) * percent
-- (PaperDollFrame_GetDamage in the game's character screen). Before a strike is shown, that
-- formula is checked against the game's own main-hand (or ranged) damage for the worn weapon;
-- if they disagree by more than a point (a druid form, an unusual weapon, a client change),
-- no strike is shown at all.
local _, ns = ...

local Loadout = ns.Loadout

local Body = {}
ns.Body = Body

-- Weapon speed that instant attacks use, by weapon kind (the game's normalized speeds).
Body.NORMALIZED = { dagger = 1.7, oneHand = 2.4, twoHand = 3.3, ranged = 2.8 }
Body.TOLERANCE = 1.0
Body.DEFENSE_PCT = 0.04 -- STAT_PER_DEFENSE in the game's character screen code
Body.BLOCK_PER_STR = 20 -- BLOCK_VALUE_PER_STRENGTH
Body.ARMOR_PER_AGI = 2 -- ARMOR_PER_AGILITY

local RANGED = { INVTYPE_RANGED = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_THROWN = true }
local WEAPON_CLASS, DAGGER = 2, 15

-- { min, max, speed, kind } from an item, or nil for a non-weapon.
function Body.Weapon(item)
	local s = item and item.stats
	if not (s and s.wmin and s.wmax and s.speed and s.speed > 0) then
		return nil
	end
	local kind = "oneHand"
	if RANGED[item.loc] then
		kind = "ranged"
	elseif item.loc == "INVTYPE_2HWEAPON" then
		kind = "twoHand"
	elseif item.class == WEAPON_CLASS and item.sub == DAGGER then
		kind = "dagger"
	end
	return { min = s.wmin, max = s.wmax, speed = s.speed, kind = kind }
end

local function Ammo(item)
	return item and item.stats and item.stats.ammodps or 0
end

-- Average weapon hit before bonus and percent: what the game's damage tooltip calls "base".
function Body.WhiteBase(weapon, ap, ammo, apPerDps, speed)
	speed = speed or weapon.speed
	return (weapon.min + weapon.max) / 2 + (ammo or 0) * weapon.speed + ap / (apPerDps or 14) * speed
end

-- Average hit of a weapon strike. code = "m n+68 *1.5" (SpellData.strikes); side = { w, ap,
-- ammo, factor } (factor: the game's off-hand reduction, 1 for other hands).
function Body.StrikeValue(code, side, live, apPerDps)
	local steps = code:match("^%a (.*)$")
	if not steps then
		return nil
	end
	local fixed, mult, normalized = 0, 1, false
	for token in steps:gmatch("%S+") do
		local kind, n = token:match("^([wn])%+(%-?%d+)$")
		if kind then
			normalized = normalized or kind == "n"
			fixed = fixed + tonumber(n)
		else
			local pct = tonumber(token:match("^%*([%d%.]+)$"))
			if not pct then
				return nil
			end
			mult, fixed = mult * pct, fixed * pct
		end
	end
	local speed = normalized and Body.NORMALIZED[side.w.kind] or side.w.speed
	local base = Body.WhiteBase(side.w, side.ap, side.ammo, apPerDps, speed) * (side.factor or 1)
	return ((base + live.bonus) * mult + fixed) * live.pct
end

local function Sum(sd, ...)
	local total = 0
	for _, key in ipairs({ ... }) do
		total = total + (sd[key] or 0)
	end
	return total
end

-- What a stat change is worth by one of the game's "value of a stat" functions.
local function Worth(fn, stat, now, change)
	if change == 0 then
		return 0
	end
	if not (fn and now) then
		return nil
	end
	local a, b = fn(stat, now), fn(stat, now + change)
	if not (a and b) then
		return nil
	end
	return b - a
end

-- Stat lines a gear change gives: { [key] = { now, plan, change, pct } } with key one of
-- Body.DERIVED_ORDER. sd = Loadout.StatDelta. Lines are left out when the character has no
-- such number (no mana, no shield) or it cannot be read.
Body.DERIVED_ORDER = { "health", "mana", "ap", "rap", "crit", "spellCrit", "armor", "reduction", "defense",
	"dodge", "parry", "block", "blockValue" }

function Body.Derive(snap, sd)
	local out = {}
	if not snap then
		return out
	end
	sd = sd or {}
	local st, fn = snap.stats or {}, snap.fn or {}
	local function line(key, now, change, pct)
		if now and change then
			out[key] = { now = now, plan = now + change, change = change, pct = pct }
		end
	end
	local dStr, dAgi, dSta, dInt = Sum(sd, "str"), Sum(sd, "agi"), Sum(sd, "sta"), Sum(sd, "int")

	if st.sta and fn.hpPerSta then
		local brk = fn.staBreak or 20
		local function hp(sta)
			return math.min(brk, sta) + (math.max(brk, sta) - brk) * fn.hpPerSta
		end
		line("health", snap.health, hp(st.sta + dSta) - hp(st.sta))
	end
	if snap.mana and snap.mana > 0 and st.int then
		local brk, per = fn.intBreak or 20, fn.manaPerInt or 15
		local function mana(int)
			return math.min(brk, int) + (math.max(brk, int) - brk) * per
		end
		line("mana", snap.mana, mana(st.int + dInt) - mana(st.int))
	end
	local fromStr, fromAgi = Worth(fn.apFor, 1, st.str, dStr), Worth(fn.apFor, 2, st.agi, dAgi)
	if fromStr and fromAgi then
		-- "Attack power in Cat, Bear..." on druid weapons only counts while in such a form.
		local feral = snap.feral and Sum(sd, "feralap") or 0
		line("ap", snap.ap, fromStr + fromAgi + Sum(sd, "ap") + feral)
	end
	if snap.class == "HUNTER" or snap.ranged then
		local rStr, rAgi = Worth(fn.rapFor, 1, st.str, dStr), Worth(fn.rapFor, 2, st.agi, dAgi)
		if rStr and rAgi then
			line("rap", snap.rap, rStr + rAgi + Sum(sd, "ap", "rap"))
		end
	end
	local critAgi = Worth(fn.critFor, 2, st.agi, dAgi)
	if critAgi then
		line("crit", snap.crit, critAgi * 100 + Sum(sd, "crit"), true)
	end
	if snap.mana and snap.mana > 0 then
		local critInt = Worth(fn.spellCritFor, 4, st.int, dInt)
		if critInt then
			line("spellCrit", snap.spellCrit, critInt * 100 + Sum(sd, "spellcrit"), true)
		end
	end
	local dArmor = Sum(sd, "armor") + Body.ARMOR_PER_AGI * dAgi
	line("armor", snap.armor, dArmor)
	if snap.armor and fn.armorEff then
		local a, b = fn.armorEff(snap.armor), fn.armorEff(snap.armor + dArmor)
		if a and b then
			line("reduction", a * 100, (b - a) * 100, true)
		end
	end
	local dDef = Sum(sd, "def")
	line("defense", snap.defense, dDef)
	local fromDef = dDef * Body.DEFENSE_PCT
	local dodgeAgi = 0
	if fn.dodgeFromAgi and st.agi and st.agi > 0 then
		dodgeAgi = fn.dodgeFromAgi * 100 / st.agi * dAgi
	end
	line("dodge", snap.dodge, dodgeAgi + Sum(sd, "dodge") + fromDef, true)
	if snap.parry and snap.parry > 0 then
		line("parry", snap.parry, Sum(sd, "parry") + fromDef, true)
	end
	if snap.block and snap.block > 0 then
		line("block", snap.block, Sum(sd, "blockpct") + fromDef, true)
		if st.str then
			local fromStrBlock = math.floor((st.str + dStr) / Body.BLOCK_PER_STR) - math.floor(st.str / Body.BLOCK_PER_STR)
			line("blockValue", snap.blockValue, Sum(sd, "block") + fromStrBlock)
		end
	end
	return out
end

-- One weapon side for strikes: "m" main hand, "r" ranged, "o" off-hand. nil when nothing can
-- be shown. The main hand and ranged weapon must match the game's own damage readout. The
-- off-hand's reduction (half damage, more with talents) is read from the game's off-hand damage.
local SLOT = { m = 16, r = 18, o = 17 }
Body.OFF_HAND_FACTOR = { 0.3, 1.0 } -- a reading outside this range is not trusted

-- Druid Cat or Bear Form: the main-hand side swings at the form's speed. Two rules are tried,
-- and the game's own form damage decides:
--   1. weapon DPS x form speed + attack power / 14 x form speed (weapon counts in form). Used
--      only when it matches the game's damage readout within a point.
--   2. otherwise the form's own damage, with the weapon left out (the players' simulator says
--      forms ignore the weapon); only attack power changes it. Marked as measured by players.
local function FormSide(snap, worn, eff, apChange, live, apNow, per)
	local fs = snap.formSpeed
	local function scaled(w)
		if not w or w.kind == "ranged" then
			return nil
		end
		return { min = w.min / w.speed * fs, max = w.max / w.speed * fs, speed = fs, kind = "form" }
	end
	local nowW = scaled(Body.Weapon(worn[16]))
	if nowW and math.abs(Body.WhiteBase(nowW, apNow, 0, per) - live.base) <= Body.TOLERANCE then
		local planW = scaled(Body.Weapon(eff[16]))
		return {
			live = live,
			per = per,
			now = { w = nowW, ap = apNow, ammo = 0, factor = 1 },
			plan = planW and { w = planW, ap = apNow + (apChange or 0), ammo = 0, factor = 1 } or nil,
		}
	end
	local fixed = live.base - apNow / per * fs
	local claws = { min = fixed, max = fixed, speed = fs, kind = "form" }
	return {
		live = live,
		per = per,
		measured = true,
		now = { w = claws, ap = apNow, ammo = 0, factor = 1 },
		plan = { w = claws, ap = apNow + (apChange or 0), ammo = 0, factor = 1 },
	}
end

local function Side(kind, snap, worn, eff, apChange)
	local slot = SLOT[kind]
	if snap.feral and snap.formSpeed then
		if kind ~= "m" or not (snap.melee and snap.ap) then
			return nil -- no off-hand or ranged attacks in form
		end
		return FormSide(snap, worn, eff, apChange, snap.melee, snap.ap, snap.fn and snap.fn.apPerDps or 14)
	end
	local live = (kind == "m" and snap.melee) or (kind == "r" and snap.ranged) or (kind == "o" and snap.offhand)
	local apNow = kind == "r" and snap.rap or snap.ap
	local now = Body.Weapon(worn[slot])
	if not (live and apNow and now) or (kind ~= "r" and now.kind == "ranged") then
		return nil
	end
	local ammo = kind == "r" and Ammo(worn[0]) or 0
	local per = snap.fn and snap.fn.apPerDps or 14
	local white = Body.WhiteBase(now, apNow, ammo, per)
	local factor = 1
	if kind == "o" then
		factor = white > 0 and live.base / white or 0
		if factor < Body.OFF_HAND_FACTOR[1] or factor > Body.OFF_HAND_FACTOR[2] then
			return nil
		end
	elseif math.abs(white - live.base) > Body.TOLERANCE then
		return nil -- our weapon math does not match the game's: show no strikes
	end
	local planned = Body.Weapon(eff[slot])
	if planned and kind ~= "r" and planned.kind == "ranged" then
		planned = nil
	end
	return {
		live = live,
		per = per,
		now = { w = now, ap = apNow, ammo = ammo, factor = factor },
		plan = planned and { w = planned, ap = apNow + (apChange or 0), ammo = ammo, factor = factor } or nil,
	}
end

-- The full change a plan makes, for Predict.Rows: spell bonuses (d, h), attack power (ap, rap),
-- stat lines (derived) and the weapon sides for strikes. snap may be nil (spell bonuses only).
function Body.Delta(plan, worn, snap)
	local delta = Loadout.BonusDelta(plan, worn)
	local sd = Loadout.StatDelta(plan, worn)
	delta.stats = sd
	delta.derived = Body.Derive(snap, sd)
	delta.ap = delta.derived.ap and delta.derived.ap.change or 0
	delta.rap = delta.derived.rap and delta.derived.rap.change or 0
	if snap then
		local eff = Loadout.Effective(worn, plan)
		local rapChange = delta.derived.rap and delta.rap or Sum(sd, "ap", "rap")
		delta.strikes = {
			m = Side("m", snap, worn, eff, delta.ap),
			r = Side("r", snap, worn, eff, rapChange),
			o = Side("o", snap, worn, eff, delta.ap),
		}
		local shield = eff[17] and eff[17].loc == "INVTYPE_SHIELD"
		delta.base = {
			ap = snap.ap, rap = snap.rap, rapChange = rapChange,
			pct = snap.melee and snap.melee.pct or 1,
			rpct = snap.ranged and snap.ranged.pct or 1,
			blockValue = snap.blockValue,
			blockChange = delta.derived.blockValue and delta.derived.blockValue.change,
			shield = shield,
			offWeapon = Body.Weapon(worn[17]) ~= nil or Body.Weapon(eff[17]) ~= nil,
		}
	end
	return delta
end

local function RoundTo(x, places)
	local m = 10 ^ (places or 0)
	if x >= 0 then
		return math.floor(x * m + 0.5) / m
	end
	return -math.floor(-x * m + 0.5) / m
end
Body.RoundTo = RoundTo

-- Rows for the stat lines that change, in DERIVED_ORDER: { key = "stat:health", stat = "health",
-- name, before, after, change, pct }. Percentages keep two decimals, the rest whole numbers.
-- labels = { [stat] = text }. keep = { ["stat:..."] = true }: also list these when unchanged.
function Body.StatRows(derived, labels, keep)
	local rows = {}
	for _, stat in ipairs(Body.DERIVED_ORDER) do
		local d = derived and derived[stat]
		if d then
			local places = d.pct and 2 or 0
			local before, change = RoundTo(d.now, places), RoundTo(d.change, places)
			local key = "stat:" .. stat
			if change ~= 0 or keep == true or (type(keep) == "table" and keep[key]) then
				rows[#rows + 1] = { key = key, stat = stat, name = labels and labels[stat] or stat, before = before,
					after = before + change, change = change, pct = d.pct }
			end
		end
	end
	return rows
end

-- Which group a strike belongs to in "What gear bonuses do": "ap", "rap" or "block".
function Body.StrikeGroup(code)
	local kind = code:match("^(%a+) ")
	if kind == "r" or kind == "ra" then
		return "rap"
	elseif kind == "k" then
		return "block"
	end
	return "ap"
end

local function WeaponStrike(code, side)
	if not (side and side.plan) then
		return nil
	end
	local before = Body.StrikeValue(code, side.now, side.live, side.per)
	local after = Body.StrikeValue(code, side.plan, side.live, side.per)
	if before and after then
		return before, after
	end
	return nil
end

-- A strike row's before and after (average hit), and its group; nil when it cannot be shown.
-- code from SpellData.strikes.
function Body.Strike(code, delta)
	local kind, rest = code:match("^(%a+) (.*)$")
	local strikes, base = delta and delta.strikes, delta and delta.base
	if not (kind and strikes and base) then
		return nil
	end
	local before, after
	if kind == "a" or kind == "ra" then
		-- A share of attack power plus a fixed amount (Bloodthirst).
		local share, fixed = rest:match("^([%d%.]+)%+(%-?%d+)$")
		local ap = kind == "a" and base.ap or base.rap
		local change = kind == "a" and delta.ap or base.rapChange
		share, fixed = tonumber(share), tonumber(fixed)
		if not (share and ap) then
			return nil
		end
		local pct = kind == "a" and base.pct or base.rpct
		before = (ap * share + fixed) * pct
		after = ((ap + (change or 0)) * share + fixed) * pct
	elseif kind == "k" then
		-- A fixed amount plus block value (Shield Slam); needs a shield in the plan too.
		local fixed = tonumber(rest)
		if not (fixed and base.blockValue and base.blockChange and base.shield) then
			return nil
		end
		before = (fixed + base.blockValue) * base.pct
		after = (fixed + base.blockValue + base.blockChange) * base.pct
	elseif kind == "b" then
		-- Both hands: the main-hand hit plus the off-hand hit.
		local mb, ma = WeaponStrike(code, strikes.m)
		local ob, oa = WeaponStrike(code, strikes.o)
		if mb and ob then
			before, after = mb + ob, ma + oa
		elseif mb and not base.offWeapon then
			before, after = mb, ma -- no off-hand weapon (a two-hander): the main hand only
		end
	else
		before, after = WeaponStrike(code, strikes[kind])
	end
	if not (before and after) then
		return nil
	end
	-- In a druid form whose damage ignores the weapon, the strike rests on players' measurements.
	local measured = (kind == "m" or kind == "b") and strikes.m and strikes.m.measured or nil
	return before, after, Body.StrikeGroup(code), measured
end
