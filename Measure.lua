-- Reads the action-bar spells and the current spell bonuses, and records a learning sample
-- for every new gear state. Readings are taken out of combat only, twice half a second
-- apart, and stored only if both readings agree (so a half-updated tooltip is never stored).
local _, ns = ...

local L = ns.L

local Measure = {}
ns.Measure = Measure

Measure.DEBOUNCE = 1.0
Measure.CONFIRM_DELAY = 0.5
Measure.MAX_RETRIES = 3 -- a text that keeps changing on its own must not cause endless re-reads

local talentSignature -- cached until TRAIT_CONFIG_UPDATED
local timer
local retries = 0
ns.lastState = nil

function Measure.InvalidateTalents()
	talentSignature = nil
end

local function TalentSignature()
	if not talentSignature or talentSignature == "none" then
		talentSignature = ns.Compat.GetTalentSignature()
	end
	return talentSignature
end

-- Group key: within a group a spell's base value cannot change (see Learning.lua).
function Measure.GroupKey()
	local Compat = ns.Compat
	local build = Compat.GetBuildInfo() or "?"
	return ("%s:%d:%s:%d"):format(build, Compat.GetPlayerLevel(), TalentSignature(), Compat.GetShapeshiftForm())
end

-- Returns state or nil, "combat".
-- state = { bonuses = { d, h } or nil, group, spells = { { spellID, name, viaMacro, values, cost, power, kind } } }
-- bonuses is nil when the game hides them; the spell numbers are still read (predictions
-- need only those), but nothing is learned from such a reading.
function Measure.Read()
	local Compat = ns.Compat
	if Compat.InCombat() then
		return nil, "combat"
	end
	local bonuses = Compat.ReadBonuses()
	local spells = {}
	for _, entry in ipairs(ns.ActionSpells.Collect(Compat.ActionApi())) do
		local id = entry.spellID
		local text = Compat.GetSpellDescription(id)
		local cost, power = Compat.GetSpellCost(id)
		spells[#spells + 1] = {
			spellID = id,
			name = Compat.GetSpellName(id),
			viaMacro = entry.viaMacro,
			values = text and ns.SpellText.Values(text) or nil,
			cost = cost,
			power = power,
			kind = Compat.GetSpellKind(id),
		}
	end
	return { bonuses = bonuses, group = Measure.GroupKey(), spells = spells }
end

local function SameValues(a, b)
	if a == nil or b == nil then
		return a == b
	end
	if #a ~= #b then
		return false
	end
	for i = 1, #a do
		if a[i] ~= b[i] then
			return false
		end
	end
	return true
end

-- True when two readings describe the same gear state with the same spell numbers.
function Measure.Same(a, b)
	if a.group ~= b.group or (a.bonuses == nil) ~= (b.bonuses == nil) then
		return false
	end
	if a.bonuses then
		if a.bonuses.h ~= b.bonuses.h then
			return false
		end
		for school, value in pairs(a.bonuses.d) do
			if b.bonuses.d[school] ~= value then
				return false
			end
		end
	end
	if #a.spells ~= #b.spells then
		return false
	end
	for i, sa in ipairs(a.spells) do
		local sb = b.spells[i]
		if sa.spellID ~= sb.spellID or not SameValues(sa.values, sb.values) or sa.cost ~= sb.cost then
			return false
		end
	end
	return true
end

-- Stores one sample per spell that has numbers. Returns how many samples were added.
function Measure.Record(db, state)
	local added = 0
	if not state.bonuses then
		return added
	end
	for _, s in ipairs(state.spells) do
		if s.values and #s.values > 0 then
			local entry = db.spells[s.spellID] or ns.Learning.NewEntry()
			local before = #entry.samples
			local d = {}
			for school, value in pairs(state.bonuses.d) do
				d[school] = value
			end
			ns.Learning.AddSample(entry, { g = state.group, d = d, h = state.bonuses.h, v = s.values })
			db.spells[s.spellID] = entry
			if #entry.samples > before then
				added = added + 1
			end
		end
	end
	return added
end

-- Reads twice, CONFIRM_DELAY apart, and records if both readings agree.
-- verbose: print the outcome (for /delta measure).
function Measure.Take(verbose)
	local first = Measure.Read()
	if not first then
		if verbose then
			ns.Notify("measure", L.MSG_COMBAT, true)
		end
		return
	end
	ns.Compat.After(Measure.CONFIRM_DELAY, function()
		local second = Measure.Read()
		if not second then
			return
		end
		ns.lastState = second
		if ns.CharacterTab and ns.CharacterTab.OnStateChanged then
			ns.CharacterTab.OnStateChanged()
		end
		if not Measure.Same(first, second) then
			if verbose then
				ns.Notify("measure", L.MSG_UNSTABLE, true)
			end
			retries = retries + 1
			if retries <= Measure.MAX_RETRIES then
				Measure.Schedule()
			end
			return
		end
		retries = 0
		local added = Measure.Record(ns.db, second)
		if verbose then
			ns.Notify("measure", L.MSG_MEASURED:format(#second.spells, added), true)
		end
	end)
end

-- Debounced measurement after gear, talent, bar or form changes.
-- fromEvent: a game event (not a retry), which resets the retry budget.
function Measure.Schedule(fromEvent)
	if fromEvent then
		retries = 0
	end
	if timer then
		timer:Cancel()
	end
	timer = ns.Compat.After(Measure.DEBOUNCE, function()
		timer = nil
		Measure.Take(false)
	end)
end

-- Formatting for /delta dump ---------------------------------------------------------

local function VarName(var)
	if var == "heal" then
		return L.SCHOOL_HEAL
	end
	return L.SCHOOL[var] or tostring(var)
end

-- "47 (shadow 75)": the most common school value, then the schools that differ.
function Measure.FormatDamageBonus(d)
	local counts, common, best = {}, nil, -1
	for _, school in ipairs(ns.Compat.SCHOOLS) do
		local v = d[school] or 0
		counts[v] = (counts[v] or 0) + 1
		if counts[v] > best then
			common, best = v, counts[v]
		end
	end
	local others = {}
	for _, school in ipairs(ns.Compat.SCHOOLS) do
		if (d[school] or 0) ~= common then
			others[#others + 1] = L.SCHOOL[school] .. " " .. (d[school] or 0)
		end
	end
	if #others == 0 then
		return tostring(common)
	end
	return ("%d (%s)"):format(common, table.concat(others, ", "))
end

-- "#1-2 x0.70 holy" for each run of neighbouring numbers that scale the same way.
function Measure.FormatFits(fits, samples)
	local parts, i = {}, 1
	local anyLearning = false
	while i <= #fits do
		local f = fits[i]
		if f.status == "single" then
			local j = i
			while fits[j + 1] and fits[j + 1].status == "single" and fits[j + 1].var == f.var
				and math.abs(fits[j + 1].slope - f.slope) < 0.02 do
				j = j + 1
			end
			local range = (i == j) and tostring(i) or (i .. "-" .. j)
			parts[#parts + 1] = L.DUMP_SCALES:format(range, f.slope, VarName(f.var)) .. (f.poor and L.DUMP_NOISY or "")
			i = j + 1
		else
			if f.status == "learning" then
				anyLearning = true
			end
			i = i + 1
		end
	end
	if #parts > 0 then
		return table.concat(parts, ", ")
	end
	if anyLearning or #fits == 0 then
		return L.DUMP_LEARNING:format(samples, samples == 1 and "" or "s")
	end
	return L.DUMP_FIXED_ONLY
end

function Measure.DumpLines(db, state)
	local lines = {}
	if not state then
		lines[1] = L.DUMP_NOT_MEASURED
		return lines
	end
	local build, _ = ns.Compat.GetBuildInfo()
	local talents, form = state.group:match(":%d+:([^:]+):(%d+)$")
	lines[#lines + 1] = L.DUMP_HEADER:format(tostring(build), ns.Compat.GetPlayerLevel(), tostring(talents),
		tonumber(form) or 0)
	if state.bonuses then
		lines[#lines + 1] = L.DUMP_BONUSES:format(Measure.FormatDamageBonus(state.bonuses.d), state.bonuses.h)
	else
		lines[#lines + 1] = L.DUMP_BONUSES_HIDDEN
	end
	if #state.spells == 0 then
		lines[#lines + 1] = L.DUMP_NO_SPELLS
		return lines
	end
	for _, s in ipairs(state.spells) do
		local numbers
		if not s.values then
			numbers = L.DUMP_LOADING
		elseif #s.values == 0 then
			numbers = L.DUMP_NO_NUMBERS
		else
			numbers = table.concat(s.values, ", ")
		end
		local cost = s.cost and L.DUMP_COST:format(s.cost, (s.power or ""):lower()) or L.DUMP_NO_COST
		local learned = ""
		local entry = db.spells[s.spellID]
		if s.values and #s.values > 0 then
			if entry and entry.n == #s.values then
				learned = Measure.FormatFits(ns.Learning.FitAll(entry, s.kind), #entry.samples)
			else
				learned = L.DUMP_LEARNING:format(0, "s")
			end
		end
		local predicted = ns.Predict and ns.Predict.Slots(s.spellID) and L.DUMP_DATA or L.DUMP_NO_DATA
		lines[#lines + 1] = L.DUMP_SPELL:format(s.name, s.viaMacro and L.DUMP_MACRO or "",
			numbers, cost, predicted, learned)
	end
	lines[#lines + 1] = L.DUMP_FOOTER:format(#state.spells)
	return lines
end
