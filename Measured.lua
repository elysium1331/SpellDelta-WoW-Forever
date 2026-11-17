-- Shares of attack power and block value that the game's files leave out. The client data
-- for these abilities only says "increased by Attack Power" (or "based on your block value");
-- the amount is worked out on Blizzard's servers. These numbers were measured by players and
-- are taken from the wowsims Season of Discovery simulator (github.com/wowsims/sod):
--   rogue/eviscerate.go, rogue/rupture.go, rogue/garrote.go, druid/ferocious_bite.go,
--   druid/rip.go, paladin/shield_of_righteousness.go (read 2026-11-16).
-- Rows that use them are marked as measured by players wherever they show.
--
-- Between the Eyes is left out: the simulator itself marks its attack power share as untested.
--
-- Each entry:
--   var    "ap" (attack power) or "block" (block value)
--   share  how much of it the whole hit (or the whole damage over time) gets, at `points`
--          combo points where the ability has them
--   fixed  a flat amount the simulator adds on top (found by testing)
--   first, last  which numbers of the ability's own tooltip hold its base damage for that hit
--          (an average when two: "min-max"); negative counts from the end of the text
local _, ns = ...

local EVISCERATE = { var = "ap", share = 0.03 * 5, points = 5, first = -2, last = -1 }
local FEROCIOUS_BITE = { var = "ap", share = 0.05 * 5, points = 5, first = -2, last = -1 }
-- Rupture at 5 points: 8 ticks of 0.24 / 8 attack power each.
local RUPTURE = { var = "ap", share = 0.24, points = 5, first = -2, last = -2 }
-- Rip at 5 points: 8 ticks of 0.01 x 4 attack power, then +50% periodic damage (SoD tuning).
local RIP = { var = "ap", share = 0.01 * 4 * 8 * 1.5, points = 5, first = -2, last = -2 }
-- Garrote: 6 ticks of 0.03 attack power.
local GARROTE = { var = "ap", share = 0.03 * 6, first = 1, last = 1 }
-- Shield of Righteousness: 2.2 x block value plus 20, on top of the amount the tooltip shows.
local SHIELD_OF_RIGHTEOUSNESS = { var = "block", share = 2.2, fixed = 20, first = 1, last = 1 }

local M = {}
local function add(entry, ids)
	for _, id in ipairs(ids) do
		M[id] = entry
	end
end
add(EVISCERATE, { 2098, 6760, 6761, 6762, 8623, 8624, 11299, 11300, 31016 })
add(FEROCIOUS_BITE, { 22568, 22827, 22828, 22829, 31018, 1328618 })
add(RUPTURE, { 1943, 8639, 8640, 11273, 11274, 11275 })
add(RIP, { 1079, 9492, 9493, 9752, 9894, 9896 })
add(GARROTE, { 703, 8631, 8632, 8633, 11289, 11290 })
add(SHIELD_OF_RIGHTEOUSNESS, { 440658 })

ns.Measured = M
