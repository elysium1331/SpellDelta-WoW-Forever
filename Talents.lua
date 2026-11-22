-- Talents: which of your talents touch which spell, and by how much. The math is pure Lua and
-- unit-tested; the game is read through guarded calls at the bottom of this file.
--
-- What the game does, as tested in game on 2026-11-17 (priest level 34, Twin Disciplines and
-- Improved Power Word: Shield, naked and with three items):
--   shown number = floor((base x base talents + spell power x share x share talents) x whole talents)
--   * "whole" talents (operation 0 damage and healing, 22 over time) multiply everything,
--     spell power from gear included, so gear gains grow with them.
--   * "base" talents (3/12/23 one effect, 8 every effect) multiply only the spell's own amount,
--     so gear gains stay the same.
--   * ranks add up plainly (3 of 5 points = 3/5 of the full amount), and the game cuts
--     decimals off instead of rounding.
--   * spell tooltips show applied talents only, never points that are not applied yet.
-- Which spells a talent touches comes from the game data (class set and mask), not from its
-- wording: Twin Disciplines says "instant" but also boosts channeled Starshards, and skips
-- Power Word: Shield.
local _, ns = ...

local Talents = {}
ns.Talents = Talents

local EPSILON = 1e-6

-- Bitwise AND of two 32-bit masks. WoW has bit.band; plain Lua 5.1 (the tests) does not.
local function Band(a, b)
	if bit and bit.band then
		return bit.band(a, b)
	end
	local result, value = 0, 1
	while a > 0 and b > 0 do
		if a % 2 == 1 and b % 2 == 1 then
			result = result + value
		end
		a, b, value = math.floor(a / 2), math.floor(b / 2), value * 2
	end
	return result
end

-- mod = { kind, op, amount, class set, mask 1-4 }; fam = { class set, mask 1-4 }.
local function Matches(mod, fam)
	if not fam or (mod[1] ~= "p" and mod[1] ~= "f") or mod[4] ~= fam[1] then
		return false
	end
	for i = 1, 4 do
		if Band(mod[4 + i] or 0, fam[1 + i] or 0) ~= 0 then
			return true
		end
	end
	return false
end
Talents.Matches = Matches

local function Data(data)
	return data or ns.SpellData or {}
end

-- Share of a talent's full amount at a rank: from points(talentID, rank, entry) when given
-- (the game's own rank text), else rank / ranks.
local function Fraction(talentID, rank, entry, points)
	local frac = points and points(talentID, rank, entry)
	if type(frac) == "number" then
		return frac
	end
	return math.min(rank, entry[1]) / entry[1]
end

-- A talent part's amount at a rank: the game's own rank curve (SpellData.rankAmounts) when
-- there is one, else the part's amount x Fraction. i: the part's position in the talent entry.
local function Amount(data, talentID, i, mod, rank, frac)
	local curve = data.rankAmounts and data.rankAmounts[talentID]
	curve = curve and curve[i]
	if curve and #curve > 0 then
		return curve[math.max(1, math.min(rank, #curve))]
	end
	return mod[3] * frac
end
Talents.Amount = Amount

local NO_HEAD = { 0, false, false }
local HeadSchool

-- School bit (2 holy, 4 fire, 8 nature, 16 frost, 32 shadow, 64 arcane) of a damage spell's
-- first growing number, or nil (healing, physical, unknown).
HeadSchool = function(spellID, data)
	local spells = data and data.spells
	local slots = ns.Predict and ns.Predict.Slots(spellID, spells)
	for _, slot in ipairs(slots or {}) do
		if slot.var then
			if type(slot.var) == "number" then
				return 2 ^ (slot.var - 1)
			end
			return nil
		end
	end
	return nil
end

local function Ticks(duration, period)
	return math.floor(duration / period + EPSILON)
end

-- How the talents in `ranks` ({ [talent spell] = rank }) change one spell:
-- { whole, coef, base, flat, baseUnknown, touched } for its numbers, plus facts:
-- cost/costPct, cast (ms)/castPct, cooldown (ms)/cooldownPct, crit (percent points),
-- duration (ms)/durationPct. `whole` includes extra ticks from a longer duration.
-- periodic: true/false overrides whether the spell's number is over time (finishers).
function Talents.Factors(spellID, ranks, data, points, periodic)
	data = Data(data)
	local f = { whole = 1, coef = 1, base = 1, flat = 0, baseUnknown = false, touched = false,
		cost = 0, costPct = 1, cast = 0, castPct = 1, cooldown = 0, cooldownPct = 1, crit = 0,
		duration = 0, durationPct = 1, critDamage = 0, critDamagePct = 1 }
	local fam = data.families and data.families[spellID]
	local head = data.heads and data.heads[spellID] or NO_HEAD
	if periodic ~= nil then
		head = { head[1], head[2], periodic }
	end
	if not (fam and data.talents) then
		return f
	end
	local function Fact(name, pct, amount)
		if pct then
			f[name .. "Pct"] = f[name .. "Pct"] * (1 + amount / 100)
		else
			f[name] = f[name] + amount
		end
	end
	for talentID, rank in pairs(ranks or {}) do
		local entry = data.talents[talentID]
		if entry and rank > 0 then
			local frac = Fraction(talentID, rank, entry, points)
			for i = 2, #entry do
				local mod = entry[i]
				-- % damage of magic schools (Darkness, Searing Light, Moonfury): damage spells of
				-- those schools, the whole number.
				local school = mod[1] == "d" and HeadSchool(spellID, data)
				if school and Band(mod[4], school) ~= 0 then
					f.whole, f.touched = f.whole * (1 + Amount(data, talentID, i, mod, rank, frac) / 100), true
				end
				if Matches(mod, fam) then
					local amount, op, pct = Amount(data, talentID, i, mod, rank, frac), mod[2], mod[1] == "p"
					local idx = head[1]
					if op == 0 or (op == 22 and head[3]) then
						if pct then
							f.whole, f.touched = f.whole * (1 + amount / 100), true
						end
					elseif op == 24 then
						if pct then
							f.coef, f.touched = f.coef * (1 + amount / 100), true
						end
					elseif op == 8 or (op == 3 and idx == 1) or (op == 12 and idx == 2) or (op == 23 and idx == 3) then
						f.touched = true
						if pct then
							f.base = f.base * (1 + amount / 100)
						else
							f.flat = f.flat + amount
						end
					elseif (op == 3 or op == 12 or op == 23) and idx == 0 then
						f.baseUnknown, f.touched = true, true
					elseif op == 14 then
						Fact("cost", pct, amount)
					elseif op == 10 then
						Fact("cast", pct, amount)
					elseif op == 11 then
						Fact("cooldown", pct, amount)
					elseif op == 1 then
						Fact("duration", pct, amount)
					elseif op == 7 and not pct then
						f.crit = f.crit + amount
					elseif op == 15 then
						Fact("critDamage", pct, amount)
					end
				end
			end
		end
	end
	-- Damage or healing over time: a longer duration adds ticks, and the whole number grows.
	local period = data.periods and data.periods[spellID]
	if period and head[3] and (f.duration ~= 0 or f.durationPct ~= 1) then
		local ticks = Ticks(period[1], period[2])
		local longer = Ticks(math.max(0, period[1] * f.durationPct + f.duration), period[2])
		if ticks > 0 then
			f.whole, f.touched = f.whole * longer / ticks, true
		end
	end
	return f
end

-- How much more a point of gear bonus adds to this spell than its plain share: whole and
-- share talents (Twin Disciplines 3% turns the staff's +34 on Renew into +35).
function Talents.GearScale(spellID, ranks, data, points)
	local f = Talents.Factors(spellID, ranks, data, points)
	return f.whole * f.coef
end

-- What the talents multiply a whole hit by: weapon strikes and finishers, whose numbers
-- SpellDelta works out itself (Aggression, Opportunity, Improved Rend, Serrated Blades).
function Talents.Whole(spellID, ranks, data, points, periodic)
	return Talents.Factors(spellID, ranks, data, points, periodic).whole
end

-- The spell's exact first growing number before the game cuts decimals, or nil when the data
-- can't say (a "min to max" pair, an unknown effect, a base talent on an unknown effect).
-- coef: its growth per point of bonus (Predict.Slots); bonus: the player's spell bonus for it.
function Talents.Value(spellID, coef, bonus, level, ranks, data, points)
	data = Data(data)
	local head = data.heads and data.heads[spellID]
	if not head or type(head[2]) ~= "number" or type(bonus) ~= "number" then
		return nil
	end
	local f = Talents.Factors(spellID, ranks, data, points)
	if f.baseUnknown then
		return nil
	end
	local base = head[2]
	if head[4] then
		local lv = level or 0
		if head[6] and head[6] > 0 and lv > head[6] then
			lv = head[6]
		end
		base = base + head[4] * math.max(0, lv - head[5])
	end
	return ((base * f.base + f.flat) + coef * bonus * f.coef) * f.whole
end

-- The whole number the game shows for an exact value.
function Talents.Shown(x)
	return math.floor(x + EPSILON)
end

local function BonusOf(bonuses, var)
	if not bonuses then
		return nil
	end
	if type(var) == "number" then
		return bonuses.d and bonuses.d[var]
	end
	return bonuses[var] -- "h" healing, "ap" attack power, "rap" ranged attack power
end
Talents.BonusOf = BonusOf

-- The first growing number of a spell's tooltip: its slot and value (the average for a pair).
local function Head(spellID, values, data)
	local slots, total = ns.Predict.Slots(spellID, data and data.spells or nil)
	if not slots or type(values) ~= "table" or #values ~= total then
		return nil
	end
	local pos = 1
	for _, slot in ipairs(slots) do
		if slot.var then
			local sum = 0
			for k = 0, slot.n - 1 do
				sum = sum + values[pos + k]
			end
			return slot, sum / slot.n
		end
		pos = pos + slot.n
	end
	return nil
end

-- A spell's number with other talents (`ranks`), starting from what the game shows now with
-- the applied talents (`applied`). Exact when the data can rebuild the shown number; otherwise
-- worked out from the shown number for talents that multiply (nil for base talents then).
-- ctx = { bonuses, level, applied, data, points }
function Talents.ValueWith(spellID, values, ranks, ctx)
	local data = Data(ctx.data)
	local slot, shown = Head(spellID, values, ctx.data)
	if not slot then
		return nil
	end
	local bonus = BonusOf(ctx.bonuses, slot.var)
	if slot.n == 1 and bonus then
		local now = Talents.Value(spellID, slot.coef, bonus, ctx.level, ctx.applied, data, ctx.points)
		if now and Talents.Shown(now) == shown then
			local target = Talents.Value(spellID, slot.coef, bonus, ctx.level, ranks, data, ctx.points)
			return target and Talents.Shown(target), shown
		end
	end
	local f0 = Talents.Factors(spellID, ctx.applied, data, ctx.points)
	local f1 = Talents.Factors(spellID, ranks, data, ctx.points)
	if f0.baseUnknown or f1.baseUnknown or f0.base ~= f1.base or f0.flat ~= f1.flat or not bonus then
		if f0.whole == f1.whole and f0.coef == f1.coef and f0.base == f1.base and f0.flat == f1.flat then
			return shown, shown
		end
		return nil
	end
	-- shown = (own + share x bonus x coef) x whole: take out the old factors, put in the new ones.
	local own = shown / f0.whole - slot.coef * bonus * f0.coef
	local value = (own + slot.coef * bonus * f1.coef) * f1.whole
	return ns.Predict.Round(value), shown
end

-- Rows for the spells on the bars whose number changes from talent ranks `from` to `to`.
-- spells: the action-bar reading. Returns rows like Predict.Rows, biggest change first.
function Talents.Rows(spells, from, to, ctx)
	local byName = {}
	for _, s in ipairs(spells or {}) do
		local before = s.values and Talents.ValueWith(s.spellID, s.values, from, ctx)
		local after = before and Talents.ValueWith(s.spellID, s.values, to, ctx)
		if before and after and after ~= before then
			local slot = Head(s.spellID, s.values, ctx.data)
			local row = { spellID = s.spellID, name = s.name, key = s.name, var = slot and slot.var,
				before = before, after = after, change = after - before }
			local old = byName[s.name]
			if not old or row.before > old.before then
				byName[s.name] = row
			end
		end
	end
	local rows = {}
	for _, row in pairs(byName) do
		rows[#rows + 1] = row
	end
	table.sort(rows, function(a, b)
		if math.abs(a.change) ~= math.abs(b.change) then
			return math.abs(a.change) > math.abs(b.change)
		end
		return a.name < b.name
	end)
	return rows
end

local function SortRows(rows)
	table.sort(rows, function(a, b)
		if math.abs(a.change) ~= math.abs(b.change) then
			return math.abs(a.change) > math.abs(b.change)
		end
		return a.name < b.name
	end)
	return rows
end

-- Rows for weapon strikes and finishers (rows of Predict.Rows with no gear change, which
-- carry their own parts): strikes are worked out without talents, so the whole hit takes the
-- talents; a finisher's own tooltip part already has the applied talents in it.
function Talents.OtherRows(rows, from, to, ctx)
	local data = Data(ctx.data)
	local out = {}
	local function Value(row, ranks)
		local w = Talents.Whole(row.spellID, ranks, data, ctx.points, row.periodic)
		if row.raw then
			return ns.Predict.Round(row.raw * w)
		end
		local w0 = Talents.Whole(row.spellID, ctx.applied, data, ctx.points, row.periodic)
		return ns.Predict.Round(row.own * w / w0 + row.apPart * w)
	end
	for _, row in ipairs(rows or {}) do
		if row.raw or row.own then
			local before, after = Value(row, from), Value(row, to)
			if after ~= before then
				out[#out + 1] = { spellID = row.spellID, name = row.name, key = row.key, var = row.var,
					points = row.points, measured = row.measured, before = before, after = after,
					change = after - before }
			end
		end
	end
	return SortRows(out)
end

-- Facts a talent changes: cost, cast time, cooldown, crit chance from talents, duration.
-- live(spellID) -> { cost, cast (ms), cooldown (seconds) } as the game shows them now (with the
-- applied talents). Rows carry `unit` ("sec", "pct" or nil) and `fact`.
function Talents.FactRows(spells, from, to, ctx, live)
	local data = Data(ctx.data)
	local L = ns.L
	local byKey, out = {}, {}
	local function Add(s, fact, label, before, after, unit)
		if not (before and after) or math.abs(after - before) < 0.005 then
			return
		end
		local key = s.name .. ":" .. fact
		if byKey[key] then
			return
		end
		local row = { spellID = s.spellID, name = label:format(s.name), key = key, fact = fact,
			before = before, after = after, change = after - before, unit = unit, pct = unit == "pct" }
		byKey[key] = row
		out[#out + 1] = row
	end
	for _, s in ipairs(spells or {}) do
		local f0 = Talents.Factors(s.spellID, ctx.applied, data, ctx.points)
		local fa = Talents.Factors(s.spellID, from, data, ctx.points)
		local fb = Talents.Factors(s.spellID, to, data, ctx.points)
		local now = live and live(s.spellID) or {}
		if type(now.cost) == "number" and now.cost > 0 and f0.costPct > 0 then
			local raw = now.cost / f0.costPct - f0.cost
			local function Cost(f)
				return ns.Predict.Round(math.max(0, (raw + f.cost) * f.costPct))
			end
			Add(s, "cost", L.FACT_COST, Cost(fa), Cost(fb))
		end
		local base = data.casts and data.casts[s.spellID]
		if base and type(now.cast) == "number" and now.cast > 0 then
			local plain = (base + f0.cast) * f0.castPct
			if plain > 0 then
				local haste = now.cast / plain
				local function Cast(f)
					return math.max(0, (base + f.cast) * f.castPct) * haste / 1000
				end
				Add(s, "cast", L.FACT_CAST, Cast(fa), Cast(fb), "sec")
			end
		end
		if type(now.cooldown) == "number" and now.cooldown > 0 and f0.cooldownPct > 0 then
			local raw = now.cooldown / f0.cooldownPct - f0.cooldown / 1000
			local function Cooldown(f)
				return math.max(0, (raw + f.cooldown / 1000) * f.cooldownPct)
			end
			Add(s, "cooldown", L.FACT_COOLDOWN, Cooldown(fa), Cooldown(fb), "sec")
		end
		Add(s, "crit", L.FACT_CRIT, fa.crit, fb.crit, "pct")
		-- Crits do 200% for weapon attacks and 150% for spells; talents raise the extra part.
		if fa.critDamagePct ~= fb.critDamagePct or fa.critDamage ~= fb.critDamage then
			local weapon = ns.Predict.StrikeCode(s.spellID) or (ns.Measured and ns.Measured[s.spellID])
			local extra = weapon and 100 or 50
			local function CritDamage(f)
				return 100 + extra * f.critDamagePct + f.critDamage
			end
			Add(s, "critDamage", L.FACT_CRIT_DAMAGE, CritDamage(fa), CritDamage(fb), "pct")
		end
		local period = data.periods and data.periods[s.spellID]
		if period then
			local function Duration(f)
				return math.max(0, period[1] * f.durationPct + f.duration) / 1000
			end
			Add(s, "duration", L.FACT_DURATION, Duration(fa), Duration(fb), "sec")
		end
	end
	table.sort(out, function(a, b)
		return a.name < b.name
	end)
	return out
end

-- Character-sheet effects of talents --------------------------------------------------

local STAT_KEYS = { [1] = "str", [2] = "agi", [4] = "sta", [8] = "int", [16] = "spi" }
local FLAT = { [47] = "parry", [49] = "dodge", [51] = "block", [52] = "crit", [54] = "hit", [55] = "spellHit",
	[57] = "spellCrit", [134] = "regen" }
local PERCENT = { [142] = "armorItems", [466] = "armorItems", [166] = "ap", [167] = "rap", [272] = "blockValue" }

-- Sums of the talents' character-sheet effects: { str..spi (percent), parry, dodge, block,
-- crit, spellCrit, hit, spellHit, def, regen (percent points), armorItems, ap, rap,
-- blockValue (percent) }.
function Talents.Stats(ranks, data, points)
	data = Data(data)
	local s = { str = 0, agi = 0, sta = 0, int = 0, spi = 0, parry = 0, dodge = 0, block = 0, crit = 0,
		spellCrit = 0, hit = 0, spellHit = 0, def = 0, regen = 0, armorItems = 0, ap = 0, rap = 0, blockValue = 0 }
	for talentID, rank in pairs(ranks or {}) do
		local entry = data.talents and data.talents[talentID]
		if entry and rank > 0 then
			local frac = Fraction(talentID, rank, entry, points)
			for i = 2, #entry do
				local mod = entry[i]
				if mod[1] == "s" then
					local aura, amount = mod[2], Amount(data, talentID, i, mod, rank, frac)
					if aura == 137 then
						for bitValue, key in pairs(STAT_KEYS) do
							if Band(mod[5], bitValue) ~= 0 then
								s[key] = s[key] + amount
							end
						end
					elseif aura == 30 then
						s.def = s.def + amount
					elseif aura == 290 then
						s.crit = s.crit + amount
						if mod[6] == 1 then
							s.spellCrit = s.spellCrit + amount
						end
					elseif FLAT[aura] then
						s[FLAT[aura]] = s[FLAT[aura]] + amount
					elseif PERCENT[aura] then
						s[PERCENT[aura]] = s[PERCENT[aura]] + amount
					end
				end
			end
		end
	end
	return s
end

-- Stat change (Loadout.StatDelta form, for Body.Derive) from the applied talents to `ranks`,
-- on top of the character as the game shows it now. itemsArmor: armor from worn items.
local function StatDelta(ranks, ctx)
	local data, snap = Data(ctx.data), ctx.snap or {}
	local a = Talents.Stats(ctx.applied, data, ctx.points)
	local b = Talents.Stats(ranks, data, ctx.points)
	local st = snap.stats or {}
	local function Pct(now, key)
		if type(now) ~= "number" then
			return 0
		end
		return now * ((100 + b[key]) / (100 + a[key]) - 1)
	end
	local sd = {}
	for _, key in pairs(STAT_KEYS) do
		sd[key] = Pct(st[key], key)
	end
	sd.parry, sd.dodge, sd.blockpct = b.parry - a.parry, b.dodge - a.dodge, b.block - a.block
	sd.crit, sd.spellcrit, sd.def = b.crit - a.crit, b.spellCrit - a.spellCrit, b.def - a.def
	sd.armor = (ctx.itemsArmor or 0) * (b.armorItems - a.armorItems) / 100
	sd.ap = Pct(snap.ap, "ap")
	-- Body.Derive adds attack power to ranged attack power too (gear gives both).
	sd.rap = Pct(snap.rap, "rap") - sd.ap
	sd.block = Pct(snap.blockValue, "blockValue")
	return sd, a, b
end

local PRIMARY = { "str", "agi", "sta", "int", "spi" }

-- Rows for what talent ranks `from` -> `to` change on the character sheet: primary stats, the
-- "What you get" lines (Body.Derive), and hit, spell hit and regeneration while casting from
-- talents. ctx = { snap, itemsArmor, applied, data, points }.
function Talents.StatRows(from, to, ctx)
	local Body, L = ns.Body, ns.L
	local sdFrom, _, sFrom = StatDelta(from, ctx)
	local sdTo, _, sTo = StatDelta(to, ctx)
	local rows = {}
	local st = ctx.snap and ctx.snap.stats or {}
	for _, key in ipairs(PRIMARY) do
		if st[key] then
			local before, after = ns.Predict.Round(st[key] + sdFrom[key]), ns.Predict.Round(st[key] + sdTo[key])
			if after ~= before then
				rows[#rows + 1] = { key = "stat:" .. key, stat = key, name = L.STAT[key], before = before,
					after = after, change = after - before }
			end
		end
	end
	if Body and ctx.snap then
		local d1, d2 = Body.Derive(ctx.snap, sdFrom), Body.Derive(ctx.snap, sdTo)
		local combined = {}
		for key, line in pairs(d2) do
			local old = d1[key]
			if old then
				combined[key] = { now = old.plan, plan = line.plan, change = line.plan - old.plan, pct = line.pct }
			end
		end
		for _, row in ipairs(Body.StatRows(combined, L.DERIVED)) do
			rows[#rows + 1] = row
		end
	end
	for _, item in ipairs({ { "hit", L.FACT_HIT }, { "spellHit", L.FACT_SPELL_HIT }, { "regen", L.FACT_REGEN } }) do
		local before, after = sFrom[item[1]], sTo[item[1]]
		if math.abs(after - before) > 0.005 then
			rows[#rows + 1] = { key = "talent:" .. item[1], name = item[2], before = before, after = after,
				change = after - before, pct = true, fact = item[1] }
		end
	end
	return rows
end

-- Same talents in both tables?
function Talents.Same(a, b)
	for k, v in pairs(a or {}) do
		if (b and b[k] or 0) ~= v then
			return false
		end
	end
	for k, v in pairs(b or {}) do
		if (a and a[k] or 0) ~= v then
			return false
		end
	end
	return true
end

function Talents.Copy(ranks)
	local copy = {}
	for k, v in pairs(ranks or {}) do
		copy[k] = v
	end
	return copy
end

-- Reading the game ------------------------------------------------------------------------
-- Verified in the Forever 1.60.1.70938 UI source (Blizzard_SharedTalentUI, Camelot talents):
--   C_ClassTalents.GetActiveConfigID(); C_Traits.GetConfigInfo(id).treeIDs; GetTreeNodes(tree);
--   GetNodeInfo(config, node).activeEntry = { entryID, rank } (pending points included);
--   GetEntryInfo(config, entry).definitionID; GetDefinitionInfo(def).spellID;
--   ConfigHasStagedChanges(config); GetTraitDescription(entry, rank) (the rank's own text).

local function Call(fn, ...)
	if type(fn) ~= "function" then
		return false
	end
	return pcall(fn, ...)
end

local applied, current, entries = nil, nil, {}
local spellOfEntry, fractions = {}, {}

local function SpellOfEntry(configID, entryID)
	if spellOfEntry[entryID] ~= nil then
		return spellOfEntry[entryID]
	end
	local spell = false
	local ok, info = Call(C_Traits and C_Traits.GetEntryInfo, configID, entryID)
	if ok and type(info) == "table" and info.definitionID then
		local ok2, def = Call(C_Traits.GetDefinitionInfo, info.definitionID)
		if ok2 and type(def) == "table" and type(def.spellID) == "number" then
			spell = def.spellID
		end
	end
	spellOfEntry[entryID] = spell
	return spell
end

-- { [talent spell] = rank } for the talents the game shows now (pending points included).
local function ReadRanks()
	if not (C_ClassTalents and C_Traits) then
		return nil
	end
	local ok, configID = Call(C_ClassTalents.GetActiveConfigID)
	if not ok or not configID then
		return nil
	end
	local ok2, config = Call(C_Traits.GetConfigInfo, configID)
	if not ok2 or type(config) ~= "table" or type(config.treeIDs) ~= "table" then
		return nil
	end
	local ranks = {}
	for _, treeID in ipairs(config.treeIDs) do
		local ok3, nodes = Call(C_Traits.GetTreeNodes, treeID)
		for _, nodeID in ipairs(ok3 and type(nodes) == "table" and nodes or {}) do
			local ok4, info = Call(C_Traits.GetNodeInfo, configID, nodeID)
			local entry = ok4 and type(info) == "table" and info.activeEntry
			if entry and (entry.rank or 0) > 0 then
				local spell = SpellOfEntry(configID, entry.entryID)
				if spell then
					ranks[spell] = entry.rank
					entries[spell] = entry.entryID
				end
			end
		end
	end
	local ok5, staged = Call(C_Traits.ConfigHasStagedChanges, configID)
	return ranks, ok5 and staged == true
end

-- Reads the talents again. The applied set is only replaced while nothing is pending, so it
-- keeps what the game's spell numbers are built on.
function Talents.Refresh()
	local ranks, staged = ReadRanks()
	if not ranks then
		return
	end
	current = ranks
	if not staged or not applied then
		applied = ranks
	end
end

function Talents.Applied()
	return applied
end

-- The applied talents' character-sheet effects (Talents.Stats), for item stat changes; nil
-- until the talents can be read.
function Talents.AppliedStats()
	if not applied then
		Talents.Refresh()
	end
	return applied and Talents.Stats(applied, nil, Talents.Points) or nil
end

function Talents.Current()
	return current
end

function Talents.EntryOf(talentID)
	return entries[talentID]
end

-- The hovered talent's entry, so its rank text can be read before any point is in it.
function Talents.SetEntry(talentID, entryID)
	entries[talentID] = entries[talentID] or entryID
end

-- A rank's amount as a share of the data amount `full`, from the talent's own texts. The data
-- amount is the top rank's for most talents (Twin Disciplines: 5 = 1% a rank, 5% at 5) but
-- the first rank's for others (Improved Renew: 5 = 5% a rank, 15% at 3; Ryan, 2026-11-21:
-- Renew 357 at rank 1, 374 at rank 2), so the number is looked for in the top rank's text,
-- then in the first rank's. nil when neither text has it.
function Talents.RankFraction(full, textMax, textRank, textFirst)
	local Values = ns.SpellText.Values
	local numsMax, numsRank = Values(textMax), Values(textRank)
	if #numsRank ~= #numsMax then
		return nil
	end
	local function Find(nums)
		for i, v in ipairs(nums) do
			if math.abs(v - full) < 0.01 then
				return i
			end
		end
		return nil
	end
	local i = Find(numsMax)
	if not i and type(textFirst) == "string" then
		local numsFirst = Values(textFirst)
		if #numsFirst == #numsMax then
			i = Find(numsFirst)
		end
	end
	if i and numsRank[i] then
		return numsRank[i] / full
	end
	return nil
end

-- Share of the data amount at a rank, from the talent's own text for that rank
-- (Talents.RankFraction). nil when the text can't be matched (rank / ranks is used then).
function Talents.Points(talentID, rank, entry)
	local key = talentID .. ":" .. rank
	if fractions[key] ~= nil then
		return fractions[key] or nil
	end
	local frac = false
	local entryID = entries[talentID]
	local full = entry and entry[2] and math.abs(entry[2][3])
	local fn = C_Traits and C_Traits.GetTraitDescription
	if entryID and full and full > 0 and ns.SpellText then
		local okMax, textMax = Call(fn, entryID, entry[1])
		local okRank, textRank = Call(fn, entryID, rank)
		local okFirst, textFirst = Call(fn, entryID, 1)
		if okMax and okRank and type(textMax) == "string" and type(textRank) == "string" then
			frac = Talents.RankFraction(full, textMax, textRank, okFirst and textFirst or nil) or false
		end
	end
	fractions[key] = frac
	return frac or nil
end

-- Hooks the applied talents into a gear delta for Predict.Rows: the gear gain of each spell
-- gets its whole and share talents, and the first number is rebuilt exactly when it can be.
-- bonuses: the spell bonuses the spell reading was taken with.
function Talents.Attach(delta, bonuses, level)
	if not applied then
		Talents.Refresh()
	end
	if not (delta and applied and ns.SpellData and ns.SpellData.talents) then
		return delta
	end
	local ranks = applied
	delta.scale = function(spellID)
		return Talents.GearScale(spellID, ranks, nil, Talents.Points)
	end
	delta.whole = function(spellID, periodic)
		return Talents.Whole(spellID, ranks, nil, Talents.Points, periodic)
	end
	local base = delta.base or {}
	delta.now = bonuses and { h = bonuses.h, d = bonuses.d, ap = base.ap, rap = base.rap }
	delta.value = function(spellID, coef, bonus)
		return Talents.Value(spellID, coef, bonus, level, ranks, nil, Talents.Points)
	end
	return delta
end
