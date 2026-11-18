-- Talent tooltips: a one-line hint, and with Alt held, what the talent changes about the
-- spells on your action bars: first the points you added but did not apply yet, then the
-- talent's next rank.
--
-- Hooks (verified in the Forever 1.60.1.70938 UI source, Blizzard_SharedTalentUI):
--   TalentDisplayMixin:SetTooltipInternal fires EventRegistry "TalentDisplay.TooltipCreated"
--   (button, tooltip) after the talent tooltip is filled. button:GetSpellID() is the talent's
--   spell; button.nodeInfo.activeEntry / nextEntry carry its entryID. Hovering again
--   (button:OnEnter) rebuilds the tooltip, used when Alt is pressed or released.
local _, ns = ...

local L, Compat, Talents = ns.L, ns.Compat, ns.Talents

local TalentTip = {}
ns.TalentTip = TalentTip

TalentTip.MAX_ROWS = 6

local GOLD = { 1, 0.82, 0 }
local GREY = { 0.6, 0.6, 0.6 }
local WHITE = { 1, 1, 1 }
local GREEN = { 0.25, 1, 0.25 }
local RED = { 1, 0.3, 0.3 }

local function AddRows(tooltip, header, rows, empty)
	tooltip:AddLine(header, GOLD[1], GOLD[2], GOLD[3], true)
	if #rows == 0 then
		tooltip:AddLine(empty, GREY[1], GREY[2], GREY[3], true)
		return
	end
	for i = 1, math.min(#rows, TalentTip.MAX_ROWS) do
		local row = rows[i]
		-- Facts (cost, cast time, cooldown...) stay white: up or down is neither good nor bad here.
		local color = row.fact and WHITE or row.change > 0 and GREEN or row.change < 0 and RED or GREY
		tooltip:AddDoubleLine(ns.Tooltip.RowLabel(row), ns.Tooltip.ChangeText(row), WHITE[1], WHITE[2],
			WHITE[3], color[1], color[2], color[3])
	end
end

-- Every row a talent change makes: spell numbers, strikes and finishers (ctx.others: rows of
-- Predict.Rows with no gear change), then facts (ctx.live: cost, cast time, cooldown now).
local function Rows(spells, from, to, ctx)
	local rows = Talents.Rows(spells, from, to, ctx)
	for _, row in ipairs(Talents.OtherRows(ctx.others, from, to, ctx)) do
		rows[#rows + 1] = row
	end
	for _, row in ipairs(Talents.StatRows(from, to, ctx)) do
		rows[#rows + 1] = row
	end
	for _, row in ipairs(Talents.FactRows(spells, from, to, ctx, ctx.live)) do
		rows[#rows + 1] = row
	end
	return rows
end
TalentTip.Rows = Rows

-- The lines to add for one talent, as { header, rows, empty } blocks (pure; unit-tested).
-- talentID: the hovered talent's spell; applied/current: { [talent spell] = rank }.
function TalentTip.Blocks(talentID, applied, current, spells, ctx)
	local blocks = {}
	if not Talents.Same(applied, current) then
		blocks[#blocks + 1] = { header = L.TALENT_PENDING, rows = Rows(spells, applied, current, ctx),
			empty = L.TALENT_NO_CHANGE }
	end
	local data = ctx.data or ns.SpellData
	local entry = data and data.talents and data.talents[talentID]
	if not entry then
		blocks[#blocks + 1] = { text = L.TALENT_NO_NUMBERS }
		return blocks
	end
	local rank = current[talentID] or 0
	if rank >= entry[1] then
		blocks[#blocks + 1] = { text = L.TALENT_MAXED }
		return blocks
	end
	local to = Talents.Copy(current)
	to[talentID] = rank + 1
	blocks[#blocks + 1] = { header = L.TALENT_NEXT:format(rank + 1, entry[1]),
		rows = Rows(spells, current, to, ctx), empty = L.TALENT_NO_CHANGE }
	return blocks
end

local function TalentSpell(button)
	if not (button and button.GetSpellID) then
		return nil
	end
	local ok, spellID = pcall(button.GetSpellID, button)
	if ok and type(spellID) == "number" then
		return spellID
	end
	return nil
end

local function OnTalentTooltip(_, button, tooltip)
	if tooltip ~= GameTooltip or not ns.db then
		return
	end
	local talentID = TalentSpell(button)
	if not talentID then
		return
	end
	local info = button.nodeInfo
	local entry = info and (info.activeEntry or info.nextEntry)
	if entry and entry.entryID then
		Talents.SetEntry(talentID, entry.entryID)
	end
	if not Compat.IsAltKeyDown() then
		tooltip:AddLine(L.TIP_HINT, GREY[1], GREY[2], GREY[3])
		tooltip:Show()
		return
	end
	Talents.Refresh()
	local applied, current, state = Talents.Applied(), Talents.Current(), ns.lastState
	tooltip:AddLine(" ")
	if not (applied and current and state) then
		tooltip:AddLine(L.TALENT_NOT_READY, GREY[1], GREY[2], GREY[3], true)
		tooltip:Show()
		return
	end
	-- Strikes and finishers as SpellDelta works them out now (no gear change), with the
	-- applied talents; attack power for abilities that grow with it.
	local snap = Compat.Snapshot()
	local delta = ns.Body.Delta({}, ns.Items.Worn(), snap)
	local bonuses = state.bonuses or {}
	Talents.Attach(delta, bonuses, Compat.GetPlayerLevel())
	local others = ns.Predict.Rows(state.spells, delta, nil, true)
	local itemsArmor = 0
	for _, item in pairs(ns.Items.Worn() or {}) do
		itemsArmor = itemsArmor + (item and item.stats and item.stats.armor or 0)
	end
	local ctx = {
		snap = snap,
		itemsArmor = itemsArmor,
		bonuses = { h = bonuses.h, d = bonuses.d, ap = snap and snap.ap, rap = snap and snap.rap },
		level = Compat.GetPlayerLevel(),
		applied = applied,
		points = Talents.Points,
		others = others,
		live = function(spellID)
			return { cost = (Compat.GetSpellCost(spellID)), cast = Compat.GetCastTime(spellID),
				cooldown = Compat.GetCooldownSeconds(spellID) }
		end,
	}
	for i, block in ipairs(TalentTip.Blocks(talentID, applied, current, state.spells, ctx)) do
		if block.text then
			tooltip:AddLine(block.text, GREY[1], GREY[2], GREY[3], true)
		else
			if i > 1 then
				tooltip:AddLine(" ")
			end
			AddRows(tooltip, block.header, block.rows, block.empty)
		end
	end
	tooltip:Show()
end

-- Alt pressed or released over a talent: hover it again so the tooltip is rebuilt.
local function OnModifier(key)
	if key ~= "LALT" and key ~= "RALT" then
		return
	end
	if not (GameTooltip and GameTooltip:IsShown() and GameTooltip.GetOwner) then
		return
	end
	local owner = GameTooltip:GetOwner()
	if owner and owner.nodeInfo and owner.GetSpellID and owner.OnEnter and owner:IsMouseOver() then
		pcall(owner.OnEnter, owner)
	end
end

function TalentTip.Init()
	if not (EventRegistry and EventRegistry.RegisterCallback) then
		return false
	end
	EventRegistry:RegisterCallback("TalentDisplay.TooltipCreated", OnTalentTooltip, TalentTip)
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("MODIFIER_STATE_CHANGED")
	frame:SetScript("OnEvent", function(_, _, key)
		OnModifier(key)
	end)
	return true
end
