# Validation report: [Elysium] SpellDelta 0.5.0

Target client: **WoW Forever 1.60.1.70938, interface 16001.**

**Status:** checked in game from 2026-11-15 to 2026-11-17 by Ryan with a level 34 Night
Elf priest (healing and caster damage spells). Every other class is covered only by game
data and unit tests; this report says so wherever it applies.

## 1. Checked in game

| Date | What | Result |
|---|---|---|
| 2026-11-16 | Alt over an item: Heal before and after a spell power change | Matched the game's own tooltip within 0.5. |
| 2026-11-16 | Character screen tab: plan slots, bag picker, right-click still equips, spell and stat changes | "Works great." |
| 2026-11-17 | Gear from naked: shoulders (+6 spell power), Glimmering Staff (+34), cloak, each Alt-hovered and then equipped | Renew gained the full +6, Smite +4 of +6 (each spell's own share). After the fixes below, every prediction matched the equipped number or was 1 off from the game cutting decimals. |
| 2026-11-17 | Talents that multiply the whole spell: Twin Disciplines at 1 and 3 points (Renew, Shadow Word: Pain, Starshards) | The game's numbers are floor((base + share x spell power) x (1 + talent %)). Item tooltips now include applied talent %. Twin Disciplines also raises channeled Starshards and not Power Word: Shield, so SpellDelta follows each talent's own affected-spell data, not its wording. |
| 2026-11-17 | Talents that raise only the base: Improved Power Word: Shield at ranks 1 and 3 (300 to 321 to 360, staff still +3) | Matched: the % does not touch what gear adds. |
| 2026-11-17 | Pending talent points (added, not applied) | The game's spell tooltips do not change until Apply Changes; SpellDelta works pending points out from the game data. |
| 2026-11-17 | Split healing/damage item (Death Speaker Robes: healing +20, damage +7) | Renew +20, Heal +17, Lesser Heal +14, Flash Heal +9, Prayer of Healing +6, Power Word: Shield +2. |
| 2026-11-17 | Enchant lines on items ("Enchanted: Stamina +4", two-part healing enchants) | "Everything seems to be working as intended." |

Fixes made because of these checks: talent % on gear gains, floor instead of rounding,
spell growth per level (Power Word: Shield), only passive talents count, split
healing/damage wording, enchant lines, decimal hit and crit wording.

## 2. Not checked in game

These follow the same game data and formulas, and unit tests cover them, but nobody has
compared them with the game's own numbers yet:

- **Other classes** (warrior, rogue, hunter, paladin, shaman, druid, mage, warlock):
  weapon strikes and their average hit, attack power, ranged attack power, druid forms,
  shield block value, finishers that use numbers measured by players (marked "*").
- **Talent effects other than spell %:** cost, cast time, cooldown, duration and extra
  damage-over-time ticks, crit chance and crit damage, character-sheet talents (block,
  dodge, parry, hit, % of a stat, armor from items, attack power, regeneration while
  casting), % school damage talents (Darkness).
- **Item wordings** read from game data only: hit and crit with a decimal, melee crit,
  block value, bonus armor, extra health and mana, "+N All Stats". The enchant names list
  was not exported, so enchant wordings follow what the item tooltips showed.

Left out on purpose: procs and chances, Use: effects, set bonuses, bonuses against one
creature type, anything that needs a certain weapon type, form or stance, weapon skill,
resistances.

## 3. Automated checks

| Check | Command | Result |
|---|---|---|
| Lua 5.1 syntax and no stray globals, all TOC files | `python scripts/check.py` | Pass (19 files) |
| Unit tests, including the in-game numbers above replayed (talents, gear, item wordings, enchants) | `python scripts/check.py` | 113/113 pass |
| Source and zip validation | `python scripts/package.py` | Pass |

## 4. Quick check before each release

1. The addon loads with no Lua errors after `/reload`.
2. Alt over a weapon in your bags lists spells with before and after numbers.
3. Equip it: the spell tooltips show the "after" numbers (or 1 off).
4. Talent window: add a point without applying, Alt over a talent, see the pending block.
5. Character screen: the SpellDelta side tab opens and the slots fill from your bags.
