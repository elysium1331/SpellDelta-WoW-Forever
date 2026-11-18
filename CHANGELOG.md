# Changelog

All notable user-facing changes. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versions follow [Semantic Versioning](https://semver.org/). The saved-data schema
version is tracked separately (currently schema 1).

## [1.0.0] - 2026-11-17

Stable release. Same features and numbers as 0.5.0, which passed its in-game checks on WoW
Forever 1.60.1 (build 70938). Other classes than priest are still not checked in game; see
docs/VALIDATION.md.

## [0.5.0] - 2026-11-17

First public release, for WoW Forever 1.60.1 (build 70938). Everything below from the
alphas, in short:

### Added
- Hold Alt over an item (bags, loot rolls, quest rewards, chat links) to see what it changes
  about up to 6 spells on your action bars, with before and after numbers, and what the stat
  changes give you (health, mana, attack power, crit, armor, dodge, parry, block).
- Hold Alt over a talent to see what its next rank does, and what points you added but have
  not applied yet will do, including costs, cast times, cooldowns, durations and crit.
- A SpellDelta tab on the character screen to plan a whole set of gear.
- All classes: spells, weapon strikes, attack power, finishers, druid forms. Checked in game
  with a priest only; see docs/VALIDATION.md.

## [0.5.0-alpha.6] - 2026-11-17

### Fixed
- Enchants with more than one part ("Healing +8 and Spell Damage +3", "Stamina +10, Defense +7
  and Healing +24", "Armor +16/Spell Power +2") count each part.

## [0.5.0-alpha.5] - 2026-11-17

### Fixed
- Enchants on an item ("Enchanted: Stamina +4", "Healing Spells +24", "+100 Health") were not
  counted.
- Hit and crit worded with a decimal ("Improves your chance to hit by 1.0%") were not read;
  most hit and crit gear uses that wording.
- Also read now: melee crit ("critical strike with melee attacks"), crit with spells and
  attacks, spell hit ring runes, shield block value ("Increases the block value of your
  shield"), bonus armor ("+40 Armor"), extra health and mana, Defense from enchants, dodge
  from enchants, and "+N All Stats".

## [0.5.0-alpha.4] - 2026-11-17

### Fixed
- Items worded "Increases healing done by up to 20 and damage done by up to 7 for all magical
  spells and effects" (Death Speaker Robes and about 80 others) showed only stat lines: their
  spell power was not read. Two rarer wordings are read too.

## [0.5.0-alpha.3] - 2026-11-17

### Added
- Alt over a talent shows what it changes on your character sheet, with the same lines gear
  uses: block, parry and dodge chance (Shield Specialization, Deflection), crit and hit chance,
  Defense, a percent of a stat and what that stat brings (Mental Strength: Intellect and mana),
  armor from items (Toughness), attack power, block value, and mana regeneration while casting.
- Talents that raise a magic school's damage (Darkness, Searing Light, Moonfury) raise those
  spells' numbers, in the talent tooltip and in item tooltips.
- Crit damage talents (Lethality, Ruin) show the crit damage of the abilities they touch.
- Parts of a talent that depend on a weapon type, form, stance or event are left out.

## [0.5.0-alpha.2] - 2026-11-17

### Added
- Talents for every class's abilities, not only spells: weapon strikes and finishers take the
  talents that raise their whole hit (Aggression on Sinister Strike and Eviscerate, Opportunity
  on Backstab, Serrated Blades on Rupture), in item tooltips and on Alt over a talent.
- Alt over a talent also lists the plain facts it changes: cost, cast time (with your haste),
  cooldown, crit chance from talents, and duration. A longer damage over time also shows its
  bigger total (Improved Shadow Word: Pain: 6 ticks become 8).

### Fixed
- Talents you press to use (Inner Focus, Cold Blood, Arcane Power) no longer count as if they
  were always on.

## [0.5.0-alpha.1] - 2026-11-17

### Added
- Alt over a talent in the talent window: what its next rank does to the spells on your bars,
  and what the points you added but did not apply yet do. The game's own spell tooltips only
  change after Apply Changes, so these come from the game data.

### Fixed
- Item tooltips now count your applied talents. A talent that raises a spell's whole amount
  (Twin Disciplines) also raises what gear adds: the staff's +34 on Renew shows +35 at 3 points,
  as the game does. Talents that only raise a spell's own amount (Improved Power Word: Shield)
  leave the gear part alone, as the game does.
- The new number is cut off the way the game does it instead of rounded (Shadow Word: Pain with
  the cloak showed 350, the game 349), whenever the game data can rebuild the current number.

## [0.4.0-alpha.5] - 2026-11-16

### Added
- Eviscerate, Ferocious Bite, Rupture and Rip (at 5 combo points), Garrote and Shield of
  Righteousness. The game files only say these grow with attack power or block value, not by
  how much, so the share comes from players' measurements (wowsims Season of Discovery
  simulator): Eviscerate 3% of attack power per combo point, Ferocious Bite 5%, Rupture 24% at
  5 points, Rip 48% at 5 points, Garrote 18%, Shield of Righteousness 2.2 x block value + 20.
  These rows are marked "*" with a footnote. Between the Eyes stays out: the simulator marks its
  share as untested.
- Druid Cat and Bear Form: Claw, Shred, Rake, Maul and other strikes show while in that form.
  If the game's form damage matches "weapon DPS x form speed", weapon swaps count; otherwise
  the weapon is left out (the simulator's rule, marked "*") and only attack power counts.
- "Attack power in Cat, Bear, Dire Bear, and Moonkin forms" on druid weapons counts while in
  Cat or Bear Form.

## [0.4.0-alpha.4] - 2026-11-16

### Changed
- The tab's Stats section lists every stat line the game gives your character (health, mana,
  attack power, crit, spell crit, armor, damage reduction, defense, dodge...), not only the ones
  planned gear changes, so any of them can be clicked to show on Alt. With gear planned, unchanged
  lines wait behind "Show all", like spells.

## [0.4.0-alpha.3] - 2026-11-16

### Fixed
- A spell or stat line chosen on the tab now always shows when holding Alt over gear, as
  "629 to 629 (+0)" in grey when the item doesn't change it. Before, chosen lines with no
  change were dropped, so a chosen Holy Light vanished on items without healing.

## [0.4.0-alpha.2] - 2026-11-16

### Changed
- Holding Alt over wearable gear always shows a SpellDelta block. When no spell or ability
  changes, the stat lines that do change (health, armor, dodge...) fill the free spots; when
  nothing at all changes it says "No change to your spells, abilities or stats." Before, items
  that changed no spell showed nothing, which looked broken on new characters.

## [0.4.0-alpha.1] - 2026-11-16

All classes (plan v6). Not released.

### Added
- Warriors, rogues, hunters, feral and enhancement abilities: abilities whose number grows
  with attack power (Victory Rush, Revenge), and weapon strikes (Sinister Strike, Mortal
  Strike, Heroic Strike, Backstab, Auto Shot, Aimed Shot and more) with their average hit
  before and after a gear change, worked out from the weapon, attack power and game data.
  Strikes only show when SpellDelta's weapon math matches the game's own main-hand or
  ranged damage for what you wear.
- Also covered: abilities that are a percentage of weapon damage (Riposte, Scatter Shot,
  Devastate, Divine Storm), off-hand strikes (Shank, Shiv, Main Gauche, Poisoned Knife,
  Lava Lash) using the game's own off-hand reduction, both-hand strikes (Mutilate, and
  Whirlwind, which counts the main hand only with a two-hander), a share of attack power
  (Bloodthirst, Shuriken Toss) and block value (Shield Slam).
- "What you get" lines on the SpellDelta tab: health, mana, attack power, crit chance,
  spell crit chance, armor, physical damage reduction, defense, dodge, parry, block chance
  and block value, from the game's own stat functions.
- Click a "What you get" line to show it on items when you hold Alt, the same way as spells
  (six picks in all).
- "Attack power and weapon damage" groups in "What gear bonuses do for your spells".

### Changed
- Item stats read weapon damage, weapon speed, ranged attack power and ammunition damage.
  Attack power that only counts in some forms or against some foes is left out.
- When a two-hander swap pairs a bag item, a tie in spell bonus goes to the higher weapon
  damage per second.

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
