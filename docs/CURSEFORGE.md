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

*Logo: original, made with AI image generation (OpenAI, via Codex) and reviewed by hand, MIT-licensed like the code. SpellDelta is an unofficial community addon, not affiliated with or endorsed by Blizzard Entertainment. Spell coefficients come from the game's own data; a few attack-power numbers come from the wowsims simulator (MIT) and are marked "*".*
```

## Images

| File | Use |
|---|---|
| `art/curseforge/01-item-shoulders.png` | Alt over an item: spell damage and healing shoulders, six spells. |
| `art/curseforge/02-item-cloak-enchant.png` | Alt over an item with an enchant line. |
| `art/curseforge/03-item-robes-healing.png` | Alt over an item with split healing/damage: each spell takes its own share. |
| `art/curseforge/04-talent-twin-disciplines.png` | Alt over a talent: next rank on the spells on your bars. |
| `art/curseforge/05-talent-mana-cost.png` | Alt over a talent that changes costs (Mental Agility). |
| `art/curseforge/06-talent-darkness.png` | Alt over a shadow damage talent (Darkness). |
| `art/curseforge/07-tab-spells.png` | SpellDelta tab: spells now and with the planned gear. |
| `art/curseforge/08-tab-stats.png` | SpellDelta tab: stats and what they give. |
| `art/curseforge/logo.png` | Project logo / avatar (1024 x 1024): a glowing triangle (delta, "change") rising from an open spellbook in a gold medallion, matching ProfessionWheel's logo. Made with Codex image generation from `art/briefs/logo-1.md`; spare option in `art/curseforge/raw/logo-b.png`. |

All cropped from 5120x2160 originals on 2026-11-17; no character name, chat or other
players' names are visible.

## Upload

- Latest file: `dist/Elysium_SpellDelta-1.0.3.zip` (98,674 bytes, same as the GitHub release;
  SHA-256 `906e4d06f6a5fd66cd34a19c5f88d1ba7a04c0925f351e2859c92f3d37cdcc73`). Before it: 1.0.2
  (96,112 bytes, SHA-256 `f00d8c3ebc5a75b1dfae37f5fa048d96a669f18cf0fb3063109b1cfa8d65357a`), 1.0.1
  (95,701 bytes, SHA-256 `adfd03be904613298b6345c2516c45a494beca3a2fd21713414d8c2502f7f099`). First upload was
  1.0.0 (95,233 bytes, SHA-256 `c7edaf25a4f8f64cbf6c979cab5cc055bdf69ddb33c99d7a40bb9fc7d3d86c3d`).
- Release type: **Release**. Game version: Forever 1.60.1 only.
- Changelog: paste the newest section of `CHANGELOG.md` (for 1.0.3: `## [1.0.3]`).
- Approved 2026-11-18: https://www.curseforge.com/wow/addons/elysium-spelldelta, project ID
  1813861 (in `README.md` and the TOC as `## X-Curse-Project-ID:`).
