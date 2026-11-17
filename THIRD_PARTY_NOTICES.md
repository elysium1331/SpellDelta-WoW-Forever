# Third-party notices

## Bundled third-party code or libraries

None. SpellDelta uses no external libraries and does not require any other addon.

## Blizzard Entertainment material (not covered by the MIT License)

- **Game data read at runtime:** spell names, spell descriptions, costs and spell
  bonuses are read from the running client and are not shipped with the addon.
- **Generated game data:** `SpellData.lua` contains numeric facts (spell IDs and spell
  bonus coefficients) extracted from the World of Warcraft game files with
  [wow.export](https://github.com/Kruithne/wow.export) (MIT; used as a tool, not bundled),
  (c) Blizzard Entertainment. It contains no Blizzard code, text or art.

## Numbers measured by players

`Measured.lua` holds a few numbers that the game files leave out (how much attack power
or block value some abilities add). They are taken from the
[wowsims Season of Discovery simulator](https://github.com/wowsims/sod) (MIT), where
players derived them from testing. Only the numbers are used; no code is copied. Rows
that use them are marked with "*" in the addon.

World of Warcraft and Blizzard Entertainment are trademarks or registered
trademarks of Blizzard Entertainment, Inc. SpellDelta is an unofficial community
project that Blizzard has not endorsed.
