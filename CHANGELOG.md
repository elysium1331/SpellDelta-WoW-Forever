# Changelog

All notable user-facing changes. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions follow [Semantic Versioning](https://semver.org/). The saved-data schema
version is tracked separately (currently schema 1).

## [0.3.0-alpha.2] - 2026-11-16

From Ryan's first look at the character tab. Not released.

### Added
- Click a slot on the SpellDelta tab to choose from the bag items that fit it.

### Changed
- The character model is gone; the changes list sits in the middle between the slots,
  where names have room, whether or not the game's right pane is open. The game's own
  stats pane stays visible on the right.
- The title and hint text that overlapped "Level 34 Priest" are gone; a hint shows in
  the list while nothing is planned.

### Fixed
- Equipping an item from the bags (right-click) while a plan exists no longer leaves an
  impossible plan, such as an off-hand next to a worn two-hander.

## [0.3.0-alpha.1] - 2026-11-16

Phase 3 of [docs/PLAN.md](docs/PLAN.md) (v5). Not released.

### Added
- A SpellDelta tab on the character screen (the bottom side tab, below the game's own).
  It shows your gear in the usual slots. Drop items on slots, or Shift-click them, to plan
  a loadout across several slots; the character in the middle wears the plan. The right
  side lists your spells (now, planned, change), stat changes, and which gear bonuses
  grow which spells. Right-click a slot or use "Reset to my gear" to undo. The plan is
  kept per character.
- Click a spell in the tab to choose it for the Alt tooltip (up to 6). With none chosen,
  the tooltip keeps showing the spells you cast most.
- The minimap AddOns menu entry opens the character screen on this tab.

## [0.2.0-alpha.2] - 2026-11-16

From Ryan's first in-game test of the Alt tooltip. Not released.

### Changed
- The Alt tooltip shows at most 6 spells, each with its icon before the name. It picks the
  spells you cast most (counted quietly as you play, all ranks together); until it has counts,
  the biggest changes. Damage spells are no longer pushed out by healing spells.
- The per-school summary line is gone from the tooltip; it moves to the window.

### Fixed
- Resurrection, Power Infusion, Vampiric Embrace and about 30 other spells were listed as if
  spell damage grew them. Only damage, healing and absorb numbers count now. Holy Strike and
  Holy Shield, whose holy damage does grow, are kept.

## [0.2.0-alpha.1] - 2026-11-15

Phase 2 of [docs/PLAN.md](docs/PLAN.md) (v3). Not released.

### Added
- Hold Alt while pointing at a weapon or armor piece to see what it changes about the
  spells on your action bars: each spell's number before and after, and a summary per
  school. Without Alt the tooltip shows one grey hint line. Works in bags, on the
  character sheet, on loot rolls, in the loot window, on quest rewards and on chat links.
- Swapping a two-hander for a one-hander or off-hand is paired with the best matching
  item in your bags, as the game's own comparison does.
- Spell growth per point of bonus now comes from game data (756 class spells), so no
  gear swapping is needed before predictions work.

### Changed
- The chat tip on first login now explains the Alt tooltip. Spell IDs no longer appear in
  `/delta dump`, which is now meant for bug reports only.

## [0.1.0-alpha.1] - 2026-11-15

First test build (phase 1 of [docs/PLAN.md](docs/PLAN.md)). Not released.

### Added
- Reads the spells on your action bars, including spells inside macros.
- Reads each spell's tooltip numbers and mana cost, plus your spell damage
  (per school) and healing bonuses.
- Learns, per spell, how much each number grows per point of bonus, from gear
  states you have worn. Levels, talents and Shadowform are kept apart, and
  measurements from older game builds are cleared after a patch.
- `/delta dump`, `/delta measure`, `/delta forget`, `/delta version`.
