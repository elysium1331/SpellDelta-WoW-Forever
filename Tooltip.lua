-- Item tooltips: a one-line hint, and with Alt held, what the item changes about the
-- spells on your action bars.
--
-- Hooks (verified in the Forever 1.60.1.70938 UI source):
--   TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, fn) runs after any
--   item tooltip is filled (bags, character sheet, loot rolls, loot window, quest rewards,
--   chat links). GameTooltip:RefreshData() refills a shown tooltip; used when Alt is pressed
--   or released so the block appears and disappears without moving the mouse.
local _, ns = ...

local L, Compat, Gear, Predict = ns.L, ns.Compat, ns.Gear, ns.Predict

local Tooltip = {}
ns.Tooltip = Tooltip

Tooltip.MAX_SPELLS = 6

local GOLD = { 1, 0.82, 0 }
local GREY = { 0.6, 0.6, 0.6 }
local WHITE = { 1, 1, 1 }
local GREEN = { 0.25, 1, 0.25 }
local RED = { 1, 0.3, 0.3 }

-- Computed results by link; cleared whenever gear, bags or the spell reading change.
local results = {}
local resultsState
-- After a gear change the spell reading still shows the old gear until it is measured
-- again (about a second, or after combat). Until then nothing is predicted.
local staleState

function Tooltip.Invalidate()
	results = {}
end

local ItemFor, Equipped, Bags = ns.Items.For, ns.Items.Worn, ns.Items.Bags

-- result = { rows, totals, header } or false (nothing to show).
function Tooltip.Compute(link)
	local state = ns.lastState
	if state ~= resultsState then
		results, resultsState = {}, state
	end
	if state == nil or state == staleState then
		return false
	end
	if results[link] ~= nil then
		return results[link]
	end
	local result = false
	local hovered = ItemFor(link)
	if hovered and hovered.loc and not hovered.bonus then
		return false -- not loaded yet; asked for, retried on the next hover
	end
	local equipped
	if hovered and hovered.loc and Gear.SLOTS[hovered.loc] then
		equipped = Equipped()
		local plan = Gear.Plan(hovered, equipped, Bags)
		if plan then
			local delta = ns.Body.Delta(plan.changes, equipped, Compat.Snapshot())
			-- Applied talents: gear gains grow with whole-amount talents (Twin Disciplines).
			if ns.Talents then
				ns.Talents.Attach(delta, state.bonuses, Compat.GetPlayerLevel())
			end
			-- Rows that change, plus the ones the player chose even when they don't (+0 is an answer).
			local chosen = {}
			for _, key in ipairs(ns.db and ns.db.tracked or {}) do
				chosen[key] = true
			end
			local all, totals = Predict.Rows(state.spells, delta, nil, true)
			local rows = {}
			for _, row in ipairs(all) do
				if row.change ~= 0 or chosen[row.key] then
					rows[#rows + 1] = row
				end
			end
			-- Stat lines (health, armor, dodge...) join the spells; Pick decides what fits.
			for _, row in ipairs(ns.Body.StatRows(delta.derived, L.DERIVED, chosen)) do
				rows[#rows + 1] = row
			end
			-- Always a result for wearable gear: "no change" is an answer too.
			result = { rows = rows, totals = totals, header = Tooltip.Header(plan, equipped) }
		end
		-- An item whose tooltip was not loaded yet is retried next time.
		local missing = not hovered.bonus
		for _, item in pairs(equipped or {}) do
			missing = missing or not item.bonus
		end
		if missing then
			return result
		end
	end
	results[link] = result
	return result
end

function Tooltip.Header(plan, equipped)
	local replaced = Gear.Replaced(plan, equipped)
	local parts = {}
	if plan.paired then
		parts[#parts + 1] = L.TIP_WITH:format(plan.paired.name)
	end
	if #replaced > 0 then
		parts[#parts + 1] = L.TIP_REPLACING:format(table.concat(replaced, L.TIP_AND))
	else
		parts[#parts + 1] = L.TIP_EMPTY_SLOT
	end
	return L.TIP_HEADER:format(table.concat(parts, ", "))
end

local function VarName(var)
	if var == "h" then
		return L.TOTAL_HEALING
	end
	return L.TOTAL_SCHOOL[var] or "?"
end

-- "Healing +6%   Holy -16%   Shadow about the same"
function Tooltip.TotalsText(totals)
	local order = { "h", 2, 3, 4, 5, 6, 7 }
	local parts = {}
	for _, var in ipairs(order) do
		local t = totals[var]
		if t and t.before > 0 then
			local pct = (t.after / t.before - 1) * 100
			local text
			if math.abs(pct) < 1 then
				text = L.TOTAL_SAME:format(VarName(var))
			else
				text = L.TOTAL_PCT:format(VarName(var), pct >= 0 and "+" or "-", Predict.Round(math.abs(pct)))
			end
			parts[#parts + 1] = text
		end
	end
	return table.concat(parts, "   ")
end

function Tooltip.ChangeText(row)
	local sign = row.change >= 0 and "+" or "-"
	if row.unit == "sec" then
		return L.TIP_ROW_SEC:format(row.before, row.after, sign, math.abs(row.change))
	end
	if row.pct then
		return L.TIP_ROW_PCT:format(row.before, row.after, sign, math.abs(row.change))
	end
	return L.TIP_ROW:format(row.before, row.after, sign, math.abs(row.change))
end

-- "|T<icon>:0|t Heal": the spell's icon at text height, then its name.
function Tooltip.RowLabel(row)
	local icon = row.spellID and Compat.GetSpellIcon and Compat.GetSpellIcon(row.spellID)
	if icon then
		return ("  |T%s:0|t %s"):format(tostring(icon), Predict.Label(row))
	end
	return "  " .. Predict.Label(row)
end

local function AddBlock(tooltip, result)
	tooltip:AddLine(" ")
	tooltip:AddLine(result.header, GOLD[1], GOLD[2], GOLD[3], true)
	local casts = ns.db and ns.db.casts
	local picked = Predict.Pick(result.rows, casts, Tooltip.MAX_SPELLS, ns.db and ns.db.tracked)
	for _, row in ipairs(picked) do
		local color = row.change > 0 and GREEN or row.change < 0 and RED or GREY
		tooltip:AddDoubleLine(Tooltip.RowLabel(row), Tooltip.ChangeText(row), WHITE[1], WHITE[2], WHITE[3],
			color[1], color[2], color[3])
	end
	local measured = false
	for _, row in ipairs(picked) do
		measured = measured or row.measured == true
	end
	if #picked == 0 then
		tooltip:AddLine(L.TIP_NO_CHANGE, GREY[1], GREY[2], GREY[3], true)
	elseif measured then
		tooltip:AddLine(L.MEASURED_NOTE, GREY[1], GREY[2], GREY[3], true)
	end
end

local function OnItemTooltip(tooltip)
	if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then
		return -- not the comparison tooltips or other addons' tooltips
	end
	if not (ns.db and tooltip.GetItem) then
		return
	end
	local ok, _, link = pcall(tooltip.GetItem, tooltip)
	if not ok or type(link) ~= "string" then
		return
	end
	local result = Tooltip.Compute(link)
	if not result then
		return
	end
	if Compat.IsAltKeyDown() then
		AddBlock(tooltip, result)
	else
		tooltip:AddLine(L.TIP_HINT, GREY[1], GREY[2], GREY[3])
	end
	tooltip:Show()
end

local function OnModifier(key)
	if key ~= "LALT" and key ~= "RALT" then
		return
	end
	for _, tooltip in ipairs({ GameTooltip, ItemRefTooltip }) do
		if tooltip and tooltip:IsShown() and tooltip.RefreshData and tooltip.GetItem then
			local ok, _, link = pcall(tooltip.GetItem, tooltip)
			if ok and link then
				pcall(tooltip.RefreshData, tooltip)
			end
		end
	end
end

function Tooltip.Init()
	if not (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType) then
		return false
	end
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, OnItemTooltip)
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("MODIFIER_STATE_CHANGED")
	frame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
	frame:RegisterEvent("BAG_UPDATE_DELAYED")
	frame:SetScript("OnEvent", function(_, event, arg1)
		if event == "MODIFIER_STATE_CHANGED" then
			OnModifier(arg1)
		else
			if event == "PLAYER_EQUIPMENT_CHANGED" then
				staleState = ns.lastState
			end
			Tooltip.Invalidate()
		end
	end)
	return true
end
