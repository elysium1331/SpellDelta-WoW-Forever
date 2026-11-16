local H = ...
local ns = H.load("Database.lua", {})
local Database = ns.Database

H.test("database: nil gives defaults", function()
	local db, report = Database.Load(nil)
	H.eq(db.schemaVersion, Database.SCHEMA_VERSION)
	H.eq(type(db.spells), "table")
	H.eq(report.reset, false)
end)

H.test("database: unreadable data is reset and reported", function()
	local db, report = Database.Load("garbage")
	H.eq(type(db.spells), "table")
	H.eq(report.reset, true)
end)

H.test("database: broken spell entries are dropped, good ones kept", function()
	local good = { n = 2, samples = { { g = "x", h = 1, d = { [2] = 1 }, v = { 1, 2 } } } }
	local db = Database.Load({
		schemaVersion = 1,
		spells = {
			[585] = good,
			[2050] = "nope",
			[139] = { n = "two", samples = {} },
			[17] = { n = 1, samples = { { g = "x", h = 1, d = {}, v = "bad" } } },
			bad = good,
		},
	})
	H.eq(db.spells[585], good)
	H.eq(db.spells[2050], nil)
	H.eq(db.spells[139], nil)
	H.eq(#db.spells[17].samples, 0, "the bad sample is removed")
	H.eq(db.spells.bad, nil)
end)

H.test("database: samples from another game build are dropped", function()
	local db = Database.Load({
		schemaVersion = 1,
		spells = {
			[585] = { n = 1, samples = {
				{ g = "1.60.1.70862:33:a", h = 1, d = {}, v = { 1 } },
				{ g = "1.60.1.70938:33:a", h = 2, d = {}, v = { 2 } },
			} },
			[139] = { n = 1, samples = { { g = "1.60.1.70862:33:a", h = 1, d = {}, v = { 1 } } } },
		},
	})
	local dropped = Database.PruneBuild(db, "1.60.1.70938")
	H.eq(dropped, 2)
	H.eq(#db.spells[585].samples, 1)
	H.eq(db.spells[139], nil, "a spell with no samples left is removed")
end)

H.test("database: forget clears learned data only", function()
	local db = Database.Load({ schemaVersion = 1, tipShown = true, spells = { [585] = { n = 1, samples = {} } } })
	Database.AddCast(db, "Heal")
	Database.Forget(db)
	H.eq(next(db.spells), nil)
	H.eq(next(db.casts), nil)
	H.eq(db.tipShown, true)
end)

H.test("database: casts are counted by name, bad entries dropped", function()
	local db = Database.Load({ schemaVersion = 1, casts = { Heal = 4, Smite = "x", [12] = 3, Renew = -1 } })
	H.eq(db.casts.Heal, 4)
	H.eq(db.casts.Smite, nil)
	H.eq(db.casts[12], nil)
	H.eq(db.casts.Renew, nil)
	Database.AddCast(db, "Heal")
	Database.AddCast(db, "Smite")
	Database.AddCast(db, nil)
	H.eq(db.casts.Heal, 5)
	H.eq(db.casts.Smite, 1)
	H.eq(type(Database.Load(nil).casts), "table")
end)
