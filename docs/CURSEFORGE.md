# CurseForge listing: [Elysium] SpellDelta

Everything below is ready to paste. Nothing has been submitted.

## Project name

```
[Elysium] SpellDelta
```

Suggested slug: `elysium-spelldelta` (no CurseForge project named SpellDelta was found on
2026-11-17). Category: **Tooltip** (secondary: *Class* or *Bags & Inventory*, if a second
is allowed). License: **MIT**. Game flavor: **Forever**, game version **1.60.1** only.

## Summary (256 characters at most)

```
Hold Alt over an item or a talent to see what it changes about the spells on your action bars: real before-and-after numbers for heals, damage, abilities and stats. No scores, no setup.
```

(186 characters.)

## Description (CurseForge accepts Markdown)

```markdown
# [Elysium] SpellDelta

**What does this item, or this talent, actually change about the spells I use?** Hold Alt and see it, in real numbers.

SpellDelta is part of the **Elysium** addon collection for **WoW Forever**.

## Items

Point at any weapon or armor: in your bags, on a loot roll, a quest reward or a chat link. Hold **Alt** and the tooltip lists the spells on your action bars, each with its number now, its number with that item, and the change:

    Spells - with Death Speaker Robes, in an empty slot
      Renew                211 to 231  (+20)
      Heal                 651 to 668  (+17)
      Flash Heal           317 to 326  (+9)

- Every spell takes its own share of spell power, healing or attack power, worked out from the game's own data, so +6 spell power can be +6 on Renew and +4 on Smite.
- Your applied talents are included (Twin Disciplines, Improved Power Word: Shield and so on).
- Weapon strikes show their average hit from your weapon and attack power, and only when that matches the game's own damage readout.
- Below the spells: what the stat changes give you, such as health, mana, crit, armor, dodge, parry, block.
- Shows the 6 spells you cast most. Quick numbers for a 60-second loot roll.

## Talents

Open the talent window and hold **Alt** over a talent: see what its next rank does to your spells, and what the points you added but haven't applied yet will do. Costs, cast times, cooldowns, durations and crit chance show as plain facts ("Mind Blast cooldown 8.0 to 7.5 sec").

## Plan a whole set

Open the character screen and pick the **SpellDelta** side tab. Click a slot to choose from the bag items that fit it, and see your spells and stats now and with the planned gear.

## Good to know

- **Numbers only.** SpellDelta never says Need or Greed and never scores an item.
- No setup, no commands, no libraries, nothing sent anywhere.
- Checked in game on WoW Forever 1.60.1 with a priest (healing and caster damage). Other classes use the same game data and formulas but **have not been checked in game yet**. If a number looks off, please open an issue with a screenshot and the output of `/delta dump`.
- Not shown on purpose: procs and chances, Use: effects, set bonuses, and bonuses that need a certain weapon, form, stance or creature type.

## Feedback and source

Bug reports and source code: [GitHub](https://github.com/elysium1331/SpellDelta-WoW-Forever)

*SpellDelta is an unofficial community addon, not affiliated with or endorsed by Blizzard Entertainment. Spell coefficients come from the game's own data; a few attack-power numbers come from the wowsims simulator (MIT) and are marked "*".*
```

## Images

| File | Use |
|---|---|
| (to capture) | Alt tooltip on an item in your bags, cropped to the tooltip (no chat or player names). |
| (to capture) | Alt tooltip on a talent with a pending point. |
| (to capture) | The SpellDelta tab on the character screen with a planned item. |
| (to make) | Project logo / avatar (square). |

## Upload

- File: `dist/Elysium_SpellDelta-0.5.0.zip` (95,166 bytes, same as the GitHub release; SHA-256
  `7d79291ae3d4a118924635cc4a3e0c87f8765a252321b37997fc28ff15bd5e86`).
- Release type: **Release**. Game version: Forever 1.60.1 only.
- Changelog: paste the `## [0.5.0]` section of `CHANGELOG.md`.
- After approval: add the CurseForge URL to `README.md` and `## X-Curse-Project-ID:` to the TOC.
