-- Predicts a spell's tooltip numbers after a change in spell bonuses. Pure Lua; unit-tested.
--
-- Input: the spell's live tooltip numbers (SpellText.Values) and how much each bonus
-- changes. The growth per point of bonus comes from SpellData.lua (generated from the
-- game files). A prediction is made only when the live tooltip shows exactly as many
-- numbers as the data expects, so a mismatch can never produce a wrong number.
local _, ns = ...

local Predict = {}
ns.Predict = Predict

local cache = {}

-- "2:0.714*2 0 h:0.1" -> { { var = 2, coef = 0.714, n = 2 }, { n = 1 }, { var = "h", coef = 0.1, n = 1 } }
-- Returns slots, total numbers; nil if the spell is not in the data.
function Predict.Slots(spellID, data)
	local default = ns.SpellData and ns.SpellData.spells
	data = data or default
	if not data then
		return nil
	end
	local useCache = data == default
	if useCache and cache[spellID] then
		return cache[spellID].slots, cache[spellID].total
	end
	local text = data[spellID]
	if type(text) ~= "string" then
		return nil
	end
	local slots, total = {}, 0
	for token in text:gmatch("%S+") do
		local var, coef, pair = token:match("^(%w+):([%d%.]+)(%*?2?)$")
		local slot
		if var then
			slot = { var = tonumber(var) or var, coef = tonumber(coef) or 0, n = pair == "*2" and 2 or 1 }
		else
			slot = { n = 1 }
		end
		slots[#slots + 1] = slot
		total = total + slot.n
	end
	if useCache then
		cache[spellID] = { slots = slots, total = total }
	end
	return slots, total
end

-- Bonus change for one slot. delta = { d = { [2..7] = n }, h = n, ap = n, rap = n }.
local function Change(delta, var)
	if var == "h" or var == "ap" or var == "rap" then
		return delta[var] or 0
	end
	return (delta.d and delta.d[var]) or 0
end

-- Weapon strike code for a spell (SpellData.strikes), or nil.
function Predict.StrikeCode(spellID)
	local strikes = ns.SpellData and ns.SpellData.strikes
	return strikes and strikes[spellID] or nil
end

-- True for spells SpellDelta can say something about.
function Predict.Known(spellID)
	return Predict.Slots(spellID) ~= nil or Predict.StrikeCode(spellID) ~= nil
		or (ns.Measured ~= nil and ns.Measured[spellID] ~= nil)
end

-- An ability whose attack power or block value share is only known from players' measurements
-- (Measured.lua): the base from its own tooltip numbers plus that share. nil when it can't be
-- worked out (unknown ability, unexpected text, no live numbers, no shield for block value).
function Predict.Measured(spellID, values, delta, measured)
	local m = (measured or ns.Measured or {})[spellID]
	local base = delta and delta.base
	if not (m and type(values) == "table" and base) then
		return nil
	end
	local n = #values
	local first = m.first < 0 and n + 1 + m.first or m.first
	local last = m.last < 0 and n + 1 + m.last or m.last
	if first < 1 or last > n or first > last then
		return nil
	end
	local sum = 0
	for i = first, last do
		sum = sum + values[i]
	end
	local now, change
	if m.var == "ap" then
		now, change = base.ap, delta.ap
	elseif m.var == "block" and base.shield then
		now, change = base.blockValue, base.blockChange
	end
	if not now then
		return nil
	end
	-- The tooltip part already carries the applied talents; the measured share gets them here
	-- (Talents.Attach: Aggression on Eviscerate, Serrated Blades on Rupture).
	local w = delta.whole and delta.whole(spellID, m.periodic) or 1
	local own = sum / (last - first + 1) + (m.fixed or 0)
	local before = own + m.share * now * w
	return { var = m.var, before = before, after = before + m.share * (change or 0) * w, measured = true,
		points = m.points, own = own, apPart = m.share * now, periodic = m.periodic }
end

-- The name a row shows: "Eviscerate (5 pts)*" for a measured finisher, else the spell's name.
function Predict.Label(row)
	local name = row.name
	if row.points then
		name = ns.L.ROW_POINTS:format(name, row.points)
	end
	if row.measured then
		name = name .. ns.L.MEASURED_MARK
	end
	return name
end

-- Returns a prediction or nil, reason ("unknown" | "count").
-- prediction = {
--   var = "h" | 2..7,           the bonus of the headline number
--   before, after,              headline number (average of a "min to max" pair)
--   values = { ... },           every tooltip number after the change
-- }
-- The headline is the first number that grows with a bonus (a spell's main effect).
function Predict.Spell(spellID, values, delta, data)
	local slots, total = Predict.Slots(spellID, data)
	if not slots then
		return nil, "unknown"
	end
	if type(values) ~= "table" or #values ~= total then
		return nil, "count"
	end
	local after, pos, head = {}, 1, nil
	-- Applied talents that multiply the whole amount also multiply what gear adds (Talents.Attach).
	local scale = delta.scale and delta.scale(spellID) or 1
	for _, slot in ipairs(slots) do
		local change = slot.var and Change(delta, slot.var) or 0
		local grow = slot.var and slot.coef * change * scale or 0
		local sum, newSum = 0, 0
		for k = 0, slot.n - 1 do
			local v = values[pos + k]
			after[pos + k] = v + grow
			sum, newSum = sum + v, newSum + v + grow
		end
		-- The first growing number rebuilt from the game data, when it matches what the game shows:
		-- then the new number is cut off the way the game does it (no rounding).
		if slot.var and not head and slot.n == 1 and delta.value and delta.now then
			local bonus
			if type(slot.var) == "number" then
				bonus = delta.now.d and delta.now.d[slot.var]
			else
				bonus = delta.now[slot.var]
			end
			local exact = type(bonus) == "number" and delta.value(spellID, slot.coef, bonus)
			if exact and math.floor(exact + 1e-6) == values[pos] then
				local target = delta.value(spellID, slot.coef, bonus + change)
				if target then
					after[pos] = math.floor(target + 1e-6)
					newSum = after[pos]
				end
			end
		end
		if slot.var and not head then
			head = { var = slot.var, before = sum / slot.n, after = newSum / slot.n }
		end
		pos = pos + slot.n
	end
	if not head then
		return nil, "unknown"
	end
	head.values = after
	return head
end

-- Rounds the way tooltips show numbers.
function Predict.Round(x)
	if x >= 0 then
		return math.floor(x + 0.5)
	end
	return -math.floor(-x + 0.5)
end

-- Builds the list a tooltip shows: one row per spell name whose headline changes.
-- spells: { { spellID, name, values }, ... } (the action-bar reading).
-- Returns rows sorted healing first, then by size of change; plus per-bonus totals.
-- row = { spellID, name, var, before, after, change }; totals = { [var] = { before, after } }
-- keepUnchanged: also return spells whose number does not change (the character tab's "Show all").
function Predict.Rows(spells, delta, data, keepUnchanged)
	local byName = {}
	for _, s in ipairs(spells or {}) do
		local p = s.values and Predict.Spell(s.spellID, s.values, delta, data)
		if not p and ns.Body then
			-- A weapon strike: its hit is worked out from the weapon and attack power.
			local code = Predict.StrikeCode(s.spellID)
			local before, after, kind = nil, nil, nil
			local measured
			if code then
				before, after, kind, measured = ns.Body.Strike(code, delta)
			end
			if before then
				-- Strikes are worked out without the ability's own talents; they join here.
				local w = delta.whole and delta.whole(s.spellID) or 1
				p = { var = kind, before = before * w, after = after * w, strike = true, measured = measured,
					raw = before }
			end
		end
		if not p then
			p = Predict.Measured(s.spellID, s.values, delta)
		end
		if p then
			-- The change is rounded on its own, so a +0.9 change shows as +1 even when both
			-- averages round to the same whole number.
			local before, change = Predict.Round(p.before), Predict.Round(p.after - p.before)
			local row = { spellID = s.spellID, name = s.name, key = s.name, var = p.var, before = before,
				after = before + change, change = change, strike = p.strike, measured = p.measured,
				points = p.points, raw = p.raw, own = p.own, apPart = p.apPart, periodic = p.periodic }
			-- Several ranks of one spell on the bars: keep the strongest.
			local old = byName[s.name]
			if not old or row.before > old.before then
				byName[s.name] = row
			end
		end
	end
	local rows, totals = {}, {}
	for _, row in pairs(byName) do
		if row.change ~= 0 or keepUnchanged then
			rows[#rows + 1] = row
		end
		local t = totals[row.var] or { before = 0, after = 0 }
		t.before, t.after = t.before + row.before, t.after + row.after
		totals[row.var] = t
	end
	table.sort(rows, function(a, b)
		local ah, bh = a.var == "h", b.var == "h"
		if ah ~= bh then
			return ah
		end
		if math.abs(a.change) ~= math.abs(b.change) then
			return math.abs(a.change) > math.abs(b.change)
		end
		return a.name < b.name
	end)
	return rows, totals
end

-- The rows an item tooltip shows. Spells: at most `max`. With spells (or stat lines, key
-- "stat:...") the player chose (tracked = { key, ... }), those, in the player's order. Otherwise
-- the ones cast most often first, then the biggest changes. casts = { [name] = count }
-- (Database.AddCast). Stat lines that change (health, mana, armor...) always follow, in the
-- tab's order and outside the limit: an item that adds spell power but costs 11 stamina must
-- show the lost health too.
local function AddChangedStats(picked, rows)
	local have = {}
	for _, row in ipairs(picked) do
		have[row] = true
	end
	for _, row in ipairs(rows or {}) do
		if row.stat and row.change ~= 0 and not have[row] then
			picked[#picked + 1] = row
		end
	end
	return picked
end

function Predict.Pick(rows, casts, max, tracked)
	if type(tracked) == "table" and #tracked > 0 then
		local byName, picked = {}, {}
		for _, row in ipairs(rows or {}) do
			byName[row.key or row.name] = row
		end
		for _, name in ipairs(tracked) do
			if byName[name] and #picked < (max or #tracked) then
				picked[#picked + 1] = byName[name]
			end
		end
		return AddChangedStats(picked, rows)
	end
	casts = casts or {}
	local ranked, stats = {}, {}
	for _, row in ipairs(rows or {}) do
		if row.stat then
			stats[#stats + 1] = row
		else
			ranked[#ranked + 1] = row
		end
	end
	table.sort(ranked, function(a, b)
		local ca, cb = casts[a.name] or 0, casts[b.name] or 0
		if ca ~= cb then
			return ca > cb
		end
		if math.abs(a.change) ~= math.abs(b.change) then
			return math.abs(a.change) > math.abs(b.change)
		end
		return a.name < b.name
	end)
	for i = #ranked, (max or #ranked) + 1, -1 do
		ranked[i] = nil
	end
	for _, row in ipairs(stats) do
		ranked[#ranked + 1] = row
	end
	return ranked
end

-- Which bonus grows which spell, for "What gear bonuses do for your spells".
-- spells: the action-bar reading. Returns { { var = "h" | 2..7 | "ap" | "rap", names = { ... } }, ... },
-- healing first, then holy, fire, nature, frost, shadow, arcane, attack power (with melee weapon
-- strikes), ranged attack power (with ranged strikes); names sorted, no repeats.
function Predict.Groups(spells, data)
	local seen = {}
	local function add(var, name)
		seen[var] = seen[var] or {}
		seen[var][name] = true
	end
	for _, s in ipairs(spells or {}) do
		local slots = Predict.Slots(s.spellID, data)
		for _, slot in ipairs(slots or {}) do
			if slot.var then
				add(slot.var, s.name)
			end
		end
		local code = not slots and Predict.StrikeCode(s.spellID)
		if code and ns.Body then
			add(ns.Body.StrikeGroup(code), s.name)
		end
		local m = not slots and not code and ns.Measured and ns.Measured[s.spellID]
		if m then
			add(m.var, s.name)
		end
	end
	local groups = {}
	for _, var in ipairs({ "h", 2, 3, 4, 5, 6, 7, "ap", "rap", "block" }) do
		if seen[var] then
			local names = {}
			for name in pairs(seen[var]) do
				names[#names + 1] = name
			end
			table.sort(names)
			groups[#groups + 1] = { var = var, names = names }
		end
	end
	return groups
end
