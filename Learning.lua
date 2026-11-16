-- Learns how much each number in a spell's text grows per point of spell bonus.
-- Pure Lua; unit-tested.
--
-- Each time the addon sees a new gear state (out of combat), it stores a sample per spell:
--   { g = group key, d = { [school] = damage bonus, 2..7 }, h = healing bonus, v = { numbers } }
-- The group key is "build:level:talents". Within a group, a spell's base value is constant,
-- so comparing samples of the same group isolates the effect of the bonus. Samples from other
-- groups still help: each group's own average is removed first ("fixed effects"), so a
-- level-up changes the base value but not the slope.
--
-- For each number position the model is:  value = base(group) + slope * bonus
-- where bonus is the healing bonus or one school's damage bonus. There is no API for a spell's
-- school, so the school (or healing) whose bonus explains the changes best is chosen.
local _, ns = ...

local Learning = {}
ns.Learning = Learning

Learning.MAX_SAMPLES = 16
Learning.MIN_SPREAD_SQ = 50  -- two states 10 points apart give 2 * 5^2 = 50
Learning.FIXED_SLOPE = 0.02  -- below this a number is treated as not scaling (durations etc.)
Learning.GOOD_RMS = 1.0      -- whole-number rounding alone stays well below this
Learning.SCHOOLS = { 2, 3, 4, 5, 6, 7 } -- holy, fire, nature, frost, shadow, arcane

function Learning.NewEntry()
	return { n = 0, samples = {} }
end

local function SameState(a, b)
	if a.g ~= b.g or a.h ~= b.h then
		return false
	end
	for _, s in ipairs(Learning.SCHOOLS) do
		if (a.d[s] or 0) ~= (b.d[s] or 0) then
			return false
		end
	end
	return true
end

-- Adds a sample. A sample for the same gear state replaces the old one. If the text now has a
-- different count of numbers (a new rank or a patch changed the sentence), the spell restarts.
-- When over the cap, the oldest samples of other groups go first, then the oldest overall.
function Learning.AddSample(entry, sample, maxSamples)
	maxSamples = maxSamples or Learning.MAX_SAMPLES
	local n = #sample.v
	if entry.n ~= n then
		entry.n = n
		entry.samples = {}
	end
	local samples = entry.samples
	for i = #samples, 1, -1 do
		if SameState(samples[i], sample) then
			table.remove(samples, i)
		end
	end
	samples[#samples + 1] = sample
	while #samples > maxSamples do
		local drop = 1
		for i = 1, #samples do
			if samples[i].g ~= sample.g then
				drop = i
				break
			end
		end
		table.remove(samples, drop)
	end
	return entry
end

local function BonusOf(sample, var)
	if var == "heal" then
		return sample.h or 0
	end
	return sample.d[var] or 0
end

-- Fixed-effects regression of number `index` on one bonus variable.
-- Returns slope, rss (sum of squared residuals), sxx (spread of the bonus), count.
local function FitOne(samples, index, var)
	local groups = {}
	for _, s in ipairs(samples) do
		local y = s.v[index]
		if type(y) == "number" then
			local grp = groups[s.g]
			if not grp then
				grp = { xs = {}, ys = {} }
				groups[s.g] = grp
			end
			grp.xs[#grp.xs + 1] = BonusOf(s, var)
			grp.ys[#grp.ys + 1] = y
		end
	end
	local rows = {}
	for _, grp in pairs(groups) do
		local mx, my = 0, 0
		for i = 1, #grp.xs do
			mx = mx + grp.xs[i]
			my = my + grp.ys[i]
		end
		mx, my = mx / #grp.xs, my / #grp.ys
		for i = 1, #grp.xs do
			rows[#rows + 1] = { grp.xs[i] - mx, grp.ys[i] - my }
		end
	end
	local sxx, sxy = 0, 0
	for _, r in ipairs(rows) do
		sxx = sxx + r[1] * r[1]
		sxy = sxy + r[1] * r[2]
	end
	if sxx < Learning.MIN_SPREAD_SQ then
		return nil, nil, sxx, #rows
	end
	local slope = sxy / sxx
	local rss = 0
	for _, r in ipairs(rows) do
		local e = r[2] - slope * r[1]
		rss = rss + e * e
	end
	return slope, rss, sxx, #rows
end

-- hint: "heal" (helpful spell), "dmg" (harmful spell) or nil (try everything).
-- Returns { status = "single" | "fixed" | "learning", var = "heal" | school, slope, rms, samples }.
--   single:   the number scales with `var` by `slope` per point.
--   fixed:    the bonus changed enough but this number did not (a duration, a range...).
--   learning: not enough different gear states yet.
function Learning.Fit(entry, index, hint)
	local candidates = {}
	if hint ~= "dmg" then
		candidates[#candidates + 1] = "heal"
	end
	if hint ~= "heal" then
		for _, s in ipairs(Learning.SCHOOLS) do
			candidates[#candidates + 1] = s
		end
	end
	local best
	for _, var in ipairs(candidates) do
		local slope, rss, _, count = FitOne(entry.samples, index, var)
		if slope and (not best or rss < best.rss - 1e-9) then
			best = { var = var, slope = slope, rss = rss, count = count }
		end
	end
	if not best then
		return { status = "learning", samples = #entry.samples }
	end
	local rms = math.sqrt(best.rss / math.max(best.count, 1))
	local status = math.abs(best.slope) < Learning.FIXED_SLOPE and "fixed" or "single"
	return {
		status = status,
		var = best.var,
		slope = status == "fixed" and 0 or best.slope,
		rms = rms,
		poor = rms > Learning.GOOD_RMS,
		samples = #entry.samples,
	}
end

function Learning.FitAll(entry, hint)
	local fits = {}
	for i = 1, entry.n do
		fits[i] = Learning.Fit(entry, i, hint)
	end
	return fits
end

-- Bonus change between two states { d = { [school] = n }, h = n }.
function Learning.Delta(from, to)
	local d = {}
	for _, s in ipairs(Learning.SCHOOLS) do
		d[s] = (to.d[s] or 0) - (from.d[s] or 0)
	end
	return { d = d, h = (to.h or 0) - (from.h or 0) }
end

-- Predicts a number after a bonus change, from its current (measured) value.
-- Returns nil when the scaling is not known yet.
function Learning.Predict(fit, current, delta)
	if fit.status == "fixed" then
		return current
	end
	if fit.status ~= "single" then
		return nil
	end
	local change = fit.var == "heal" and delta.h or (delta.d[fit.var] or 0)
	return current + fit.slope * change
end
