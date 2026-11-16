-- Reads the numbers out of a spell's description text. Pure Lua; unit-tested.
--
-- "Smites an enemy for 87 to 96 Holy damage." -> { 87, 96 }
-- Each number keeps its position in the text, so the same position can be compared
-- between gear states (Learning.lua) and, later, mapped to a spell effect.
local _, ns = ...

local SpellText = {}
ns.SpellText = SpellText

-- Removes UI markup: colors (|cAARRGGBB ... |r), textures (|T...|t), atlases (|A...|a),
-- and line breaks (|n and real newlines).
function SpellText.Clean(text)
	if type(text) ~= "string" then
		return ""
	end
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	text = text:gsub("|T.-|t", " "):gsub("|A.-|a", " ")
	text = text:gsub("|n", " "):gsub("[\r\n]", " ")
	return text
end

-- Word after a number -> unit hint. English only; the hint is used for display, never for
-- the learning maths, so other languages just show no unit.
local UNIT_WORDS = {
	sec = "time", secs = "time", second = "time", seconds = "time",
	min = "time", mins = "time", minute = "time", minutes = "time",
	hour = "time", hours = "time", hr = "time", hrs = "time",
	yd = "dist", yds = "dist", yard = "dist", yards = "dist",
}

local function UnitAfter(text, pos)
	local rest = text:sub(pos)
	if rest:match("^%s*%%") then
		return "pct"
	end
	local word = rest:match("^%s*(%a+)")
	return word and UNIT_WORDS[word:lower()] or nil
end

-- "1,234" is one number only when every group after a comma has exactly three digits.
local function SplitThousands(raw)
	if not raw:find(",", 1, true) then
		return { raw }
	end
	local parts = {}
	for part in raw:gmatch("[^,]+") do
		parts[#parts + 1] = part
	end
	-- Lua patterns cannot repeat a group, so check each group: 1-3 digits first, then
	-- exactly 3 digits (the last group may carry decimals).
	local grouped = #parts >= 2 and parts[1]:match("^%d%d?%d?$") ~= nil
	for i = 2, #parts do
		local ok = parts[i]:match("^%d%d%d$") or (i == #parts and parts[i]:match("^%d%d%d%.%d+$"))
		if not ok then
			grouped = false
		end
	end
	if grouped then
		return { raw }
	end
	return parts
end

-- Returns { { value = number, raw = string, unit = "pct" | "time" | "dist" | nil }, ... }.
function SpellText.Numbers(text)
	text = SpellText.Clean(text)
	local out = {}
	local pos = 1
	while true do
		local s, e = text:find("%d[%d,%.]*", pos)
		if not s then
			break
		end
		local raw = text:sub(s, e)
		-- A trailing comma or period ends the sentence or the list item, not the number.
		while raw:find("[,%.]$") do
			raw = raw:sub(1, -2)
			e = e - 1
		end
		local parts = SplitThousands(raw)
		for i, part in ipairs(parts) do
			local value = tonumber((part:gsub(",", "")))
			if value then
				-- Only the last part of a split number is followed by the unit word.
				local unit = (i == #parts) and UnitAfter(text, e + 1) or nil
				out[#out + 1] = { value = value, raw = part, unit = unit }
			end
		end
		pos = e + 1
	end
	return out
end

-- Just the values, in text order.
function SpellText.Values(text)
	local values = {}
	for i, n in ipairs(SpellText.Numbers(text)) do
		values[i] = n.value
	end
	return values
end

-- Average of positions first..last (a "min to max" range, or a single value).
function SpellText.Average(values, first, last)
	local sum, count = 0, 0
	for i = first, last do
		if values[i] then
			sum = sum + values[i]
			count = count + 1
		end
	end
	return count > 0 and sum / count or nil
end
