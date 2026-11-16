-- Saved-variable schema, defaults, validation and pruning. Pure Lua; unit-tested.
--
-- SpellDeltaCharDB (per character):
--   schemaVersion  number
--   tipShown       bool (0.1.0-alpha.1 chat tip; kept so it is not shown again)
--   altTipShown    bool (the "hold Alt" tip)
--   spells         { [spellID] = { n = number count, samples = { sample, ... } } }  (Learning.lua)
--   casts          { [spell name] = number }: how often each spell that grows with gear was
--                  cast (all ranks together). Picks the spells the item tooltip shows.
--   tracked        { name, ... }: up to 6 spells the player chose for the item tooltip.
--   plan           { [slot] = item link | false }: planned gear on the character tab.
local _, ns = ...

local Database = {}
ns.Database = Database

Database.SCHEMA_VERSION = 1

local function CopyDefaults()
	return {
		schemaVersion = Database.SCHEMA_VERSION,
		tipShown = false,
		altTipShown = false,
		spells = {},
		casts = {},
		tracked = {},
		plan = {},
	}
end
Database.CopyDefaults = CopyDefaults

local function ValidSample(s)
	return type(s) == "table" and type(s.g) == "string" and type(s.h) == "number"
		and type(s.d) == "table" and type(s.v) == "table"
end

local function CleanSpells(spells)
	local clean = {}
	if type(spells) ~= "table" then
		return clean
	end
	for id, entry in pairs(spells) do
		if type(id) == "number" and type(entry) == "table" and type(entry.n) == "number"
			and type(entry.samples) == "table" then
			local kept = {}
			for _, s in ipairs(entry.samples) do
				if ValidSample(s) then
					kept[#kept + 1] = s
				end
			end
			entry.samples = kept
			clean[id] = entry
		end
	end
	return clean
end

local function CleanCasts(casts)
	local clean = {}
	if type(casts) ~= "table" then
		return clean
	end
	for name, count in pairs(casts) do
		if type(name) == "string" and type(count) == "number" and count > 0 then
			clean[name] = math.floor(count)
		end
	end
	return clean
end

Database.MAX_TRACKED = 6

local function CleanTracked(tracked)
	local clean, seen = {}, {}
	if type(tracked) ~= "table" then
		return clean
	end
	for _, name in ipairs(tracked) do
		if type(name) == "string" and name ~= "" and not seen[name] and #clean < Database.MAX_TRACKED then
			clean[#clean + 1] = name
			seen[name] = true
		end
	end
	return clean
end

local function CleanPlan(plan)
	local clean = {}
	if type(plan) ~= "table" then
		return clean
	end
	for slot, link in pairs(plan) do
		if type(slot) == "number" and slot >= 1 and slot <= 19 and slot == math.floor(slot)
			and (link == false or (type(link) == "string" and link:find("item:", 1, true))) then
			clean[slot] = link
		end
	end
	return clean
end

-- Adds or removes a spell from the tooltip list. Returns "added", "removed" or "full".
function Database.ToggleTracked(db, name)
	for i, n in ipairs(db.tracked) do
		if n == name then
			table.remove(db.tracked, i)
			return "removed"
		end
	end
	if #db.tracked >= Database.MAX_TRACKED then
		return "full"
	end
	db.tracked[#db.tracked + 1] = name
	return "added"
end

function Database.IsTracked(db, name)
	for _, n in ipairs(db.tracked) do
		if n == name then
			return true
		end
	end
	return false
end

-- Counts one cast of a spell (by name, so every rank counts together).
function Database.AddCast(db, name)
	if type(name) ~= "string" or name == "" then
		return
	end
	db.casts[name] = (db.casts[name] or 0) + 1
end

-- Validates and repairs a stored table. Returns db, report where report = { reset = bool }.
function Database.Load(stored)
	local report = { reset = false }
	if stored == nil then
		return CopyDefaults(), report
	end
	if type(stored) ~= "table" then
		report.reset = true
		return CopyDefaults(), report
	end
	local db = CopyDefaults()
	db.tipShown = stored.tipShown == true
	db.altTipShown = stored.altTipShown == true
	db.spells = CleanSpells(stored.spells)
	db.casts = CleanCasts(stored.casts)
	db.tracked = CleanTracked(stored.tracked)
	db.plan = CleanPlan(stored.plan)
	return db, report
end

-- Drops samples recorded on another game build (group keys start with the build).
-- A patch can change a spell's scaling, so learning restarts for the new build.
-- Returns the number of samples dropped.
function Database.PruneBuild(db, build)
	local prefix = build .. ":"
	local dropped = 0
	for id, entry in pairs(db.spells) do
		local kept = {}
		for _, s in ipairs(entry.samples) do
			if s.g:sub(1, #prefix) == prefix then
				kept[#kept + 1] = s
			else
				dropped = dropped + 1
			end
		end
		entry.samples = kept
		if #kept == 0 then
			db.spells[id] = nil
		end
	end
	return dropped
end

-- Clears everything the addon has learned; settings stay.
function Database.Forget(db)
	db.spells = {}
	db.casts = {}
end
