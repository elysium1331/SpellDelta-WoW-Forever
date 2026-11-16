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

-- Bonus change for one slot. delta = { d = { [2..7] = n }, h = n }.
local function Change(delta, var)
	if var == "h" then
		return delta.h or 0
	end
	return (delta.d and delta.d[var]) or 0
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
	for _, slot in ipairs(slots) do
		local grow = slot.var and slot.coef * Change(delta, slot.var) or 0
		local sum, newSum = 0, 0
		for k = 0, slot.n - 1 do
			local v = values[pos + k]
			after[pos + k] = v + grow
			sum, newSum = sum + v, newSum + v + grow
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
		if p then
			-- The change is rounded on its own, so a +0.9 change shows as +1 even when both
			-- averages round to the same whole number.
			local before, change = Predict.Round(p.before), Predict.Round(p.after - p.before)
			local row = { spellID = s.spellID, name = s.name, var = p.var, before = before, after = before + change,
				change = change }
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

-- The spells an item tooltip shows: at most `max`. With spells the player chose (tracked =
-- { name, ... }), those, in the player's order. Otherwise the ones cast most often first, then
-- the biggest changes. casts = { [name] = count } (Database.AddCast).
function Predict.Pick(rows, casts, max, tracked)
	if type(tracked) == "table" and #tracked > 0 then
		local byName, picked = {}, {}
		for _, row in ipairs(rows or {}) do
			byName[row.name] = row
		end
		for _, name in ipairs(tracked) do
			if byName[name] and #picked < (max or #tracked) then
				picked[#picked + 1] = byName[name]
			end
		end
		return picked
	end
	casts = casts or {}
	local ranked = {}
	for i, row in ipairs(rows or {}) do
		ranked[i] = row
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
	return ranked
end

-- Which bonus grows which spell, for "What gear bonuses do for your spells".
-- spells: the action-bar reading. Returns { { var = "h" | 2..7, names = { ... } }, ... },
-- healing first, then holy, fire, nature, frost, shadow, arcane; names sorted, no repeats.
function Predict.Groups(spells, data)
	local seen = {}
	for _, s in ipairs(spells or {}) do
		local slots = Predict.Slots(s.spellID, data)
		for _, slot in ipairs(slots or {}) do
			if slot.var then
				seen[slot.var] = seen[slot.var] or {}
				seen[slot.var][s.name] = true
			end
		end
	end
	local groups = {}
	for _, var in ipairs({ "h", 2, 3, 4, 5, 6, 7 }) do
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
