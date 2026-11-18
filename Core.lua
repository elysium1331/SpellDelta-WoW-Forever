-- Startup, saved variables, events, slash commands and quiet messaging.
local ADDON_NAME, ns = ...

local L, Compat, Database, Measure = ns.L, ns.Compat, ns.Database, ns.Measure

-- The single public table.
SpellDelta = SpellDelta or {}
local API = SpellDelta

ns.version = "?"
ns.db = nil

-- Messaging --------------------------------------------------------------------

local lastMessage = {}
local MESSAGE_COOLDOWN = 10

-- Prints at most once per `key` every MESSAGE_COOLDOWN seconds (always when `force`).
function ns.Notify(key, text, force)
	local now = GetTime and GetTime() or 0
	if not force and lastMessage[key] and now - lastMessage[key] < MESSAGE_COOLDOWN then
		return
	end
	lastMessage[key] = now
	local frame = DEFAULT_CHAT_FRAME
	if frame and frame.AddMessage then
		frame:AddMessage("|cffd4b56a" .. L.MSG_PREFIX .. "|r " .. text)
	end
end

local function PrintHelp()
	for i, line in ipairs(L.MSG_HELP) do
		ns.Notify("help" .. i, line, true)
	end
end

local function Dump()
	for i, line in ipairs(Measure.DumpLines(ns.db, ns.lastState)) do
		ns.Notify("dump" .. i, line, true)
	end
end

-- Slash commands -----------------------------------------------------------------

local function RegisterSlash()
	-- Never replace another addon's command.
	local taken = {}
	pcall(function()
		for key, value in pairs(_G) do
			if type(key) == "string" and type(value) == "string" and key:sub(1, 6) == "SLASH_" then
				taken[value:lower()] = true
			end
		end
	end)
	if type(hash_SlashCmdList) == "table" then
		for cmd in pairs(hash_SlashCmdList) do
			if type(cmd) == "string" then
				taken[cmd:lower()] = true
			end
		end
	end
	local wanted = { "/delta", "/spelldelta" }
	local free = {}
	for _, cmd in ipairs(wanted) do
		if not taken[cmd] then
			free[#free + 1] = cmd
		end
	end
	if #free == 0 or (SlashCmdList and SlashCmdList.SPELLDELTA) then
		ns.Notify("slash", L.MSG_NO_SLASH)
		return
	end
	for i, cmd in ipairs(free) do
		_G["SLASH_SPELLDELTA" .. i] = cmd
	end
	SlashCmdList.SPELLDELTA = function(msg)
		msg = (msg or ""):lower():match("^%s*(.-)%s*$")
		if msg == "dump" then
			Dump()
		elseif msg == "measure" then
			Measure.Take(true)
		elseif msg == "forget" then
			Database.Forget(ns.db)
			ns.Notify("forget", L.MSG_FORGOTTEN, true)
		elseif msg == "version" then
			local build, interface = Compat.GetBuildInfo()
			ns.Notify("version", ("%s, client %s (interface %s)"):format(ns.version, tostring(build),
				tostring(interface)), true)
		else
			PrintHelp()
		end
	end
	if #free < #wanted then
		local missing = free[1] == wanted[1] and wanted[2] or wanted[1]
		ns.Notify("slashpartial", L.MSG_SLASH_PARTIAL:format(missing, free[1]))
	end
end

-- Events -------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")

local function OnAddonLoaded()
	ns.version = Compat.GetAddOnVersion(ADDON_NAME)
	local db, report = Database.Load(SpellDeltaCharDB)
	SpellDeltaCharDB = db
	ns.db = db
	if report.reset then
		ns.Notify("recovered", L.MSG_RECOVERED)
	end
end

local function OnPlayerLogin()
	if not ns.db then
		eventFrame:UnregisterEvent("ADDON_LOADED")
		OnAddonLoaded()
	end
	local build = Compat.GetBuildInfo()
	if build then
		local dropped = Database.PruneBuild(ns.db, build)
		if dropped > 0 then
			ns.Notify("pruned", L.MSG_PRUNED:format(dropped))
		end
	end
	RegisterSlash()
	ns.Talents.Refresh()
	ns.Tooltip.Init()
	ns.TalentTip.Init()
	ns.CharacterTab.Init()
	if not ns.db.altTipShown then
		ns.db.altTipShown = true
		ns.Notify("tip", L.MSG_TIP)
	end
	Measure.Schedule(true)
end

-- Events after which spell numbers or the spell list may have changed.
local REMEASURE = {
	PLAYER_EQUIPMENT_CHANGED = true,
	PLAYER_DAMAGE_DONE_MODS = true,
	SPELL_POWER_CHANGED = true,
	PLAYER_LEVEL_UP = true,
	ACTIONBAR_SLOT_CHANGED = true,
	UPDATE_MACROS = true,
	UPDATE_SHAPESHIFT_FORM = true,
	PLAYER_REGEN_ENABLED = true,
	SPELL_TEXT_UPDATE = true,
}

-- Counts a finished cast of a spell that gear can change (UNIT_SPELLCAST_SUCCEEDED: unit,
-- castGUID, spellID; the payload may be secret in restricted situations and is then skipped).
local function OnCast(spellID)
	if not ns.db or type(spellID) ~= "number" or Compat.IsSecret(spellID) then
		return
	end
	if ns.Predict.Known(spellID) then
		Database.AddCast(ns.db, Compat.GetSpellName(spellID))
	end
end

eventFrame:SetScript("OnEvent", function(_, event, arg1, _, arg3)
	if event == "UNIT_SPELLCAST_SUCCEEDED" then
		OnCast(arg3)
	elseif event == "ADDON_LOADED" then
		if arg1 == ADDON_NAME then
			eventFrame:UnregisterEvent("ADDON_LOADED")
			OnAddonLoaded()
		end
	elseif event == "PLAYER_LOGIN" then
		OnPlayerLogin()
	elseif event == "TRAIT_CONFIG_UPDATED" or event == "PLAYER_SPECIALIZATION_CHANGED" then
		ns.Talents.Refresh()
		ns.Tooltip.Invalidate()
		Measure.InvalidateTalents()
		Measure.Schedule(true)
	elseif REMEASURE[event] and ns.db then
		Measure.Schedule(true)
	end
end)

eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
eventFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
if eventFrame.RegisterUnitEvent then
	pcall(eventFrame.RegisterUnitEvent, eventFrame, "UNIT_SPELLCAST_SUCCEEDED", "player")
end
for event in pairs(REMEASURE) do
	-- pcall: an event this client does not know must not stop the addon from loading.
	pcall(eventFrame.RegisterEvent, eventFrame, event)
end

-- Public surface -----------------------------------------------------------------

function API.Dump()
	Dump()
end

-- Minimap AddOns menu entry (TOC: AddonCompartmentFunc): opens the character screen on the
-- SpellDelta tab.
function SpellDelta_OnAddonCompartmentClick()
	if not ns.CharacterTab.Open() then
		Dump()
	end
end
