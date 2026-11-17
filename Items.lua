-- Item facts read from the client: equip location, name, spell bonuses and stats.
-- Shared by the item tooltip and the character tab.
local _, ns = ...

local Compat, Gear = ns.Compat, ns.Gear

local Items = {}
ns.Items = Items

-- Parsed tooltip facts by link (a link carries enchants and suffixes, so it identifies them).
local parsed = {}

-- item = { link, loc, name, bonus, stats, class, sub }; bonus and stats are nil while the item's
-- tooltip is not loaded yet (a load is requested; ask again later).
function Items.For(link)
	if type(link) ~= "string" then
		return nil
	end
	local loc = Compat.ItemEquipLoc(link)
	local facts = parsed[link]
	if not facts then
		local lines = Compat.ItemLines(link)
		if lines then
			facts = { bonus = Gear.ParseBonus(lines), stats = Gear.ParseStats(lines) }
			parsed[link] = facts
		end
	end
	local class, sub = Compat.ItemClass(link)
	return {
		link = link,
		loc = loc,
		name = Compat.ItemName(link),
		bonus = facts and facts.bonus,
		stats = facts and facts.stats,
		class = class,
		sub = sub,
	}
end

-- What the character wears: { [slot] = item } for slots 1-18, and 0 for ammunition.
function Items.Worn()
	local worn = {}
	for slot = 0, 18 do
		local item = Items.For(Compat.EquippedLink(slot))
		if item then
			worn[slot] = item
		end
	end
	return worn
end

-- Wearable items in the bags.
function Items.Bags()
	local items = {}
	for _, link in ipairs(Compat.BagLinks()) do
		local item = Items.For(link)
		if item and item.loc then
			items[#items + 1] = item
		end
	end
	return items
end
