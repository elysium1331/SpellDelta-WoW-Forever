# [Elysium] SpellDelta

Part of the **Elysium** addon collection for WoW Forever by
[elysium1331](https://github.com/elysium1331).

SpellDelta answers one question: *what does this talent, or this item, change about
the spells I actually use?* It reads the game's own tooltip numbers for the spells on
your action bars, so you see real numbers and no upgrade scores.

**Status:** 1.0.1, stable. What was checked in game, and what was not,
is in [docs/VALIDATION.md](docs/VALIDATION.md); the plan is in [docs/PLAN.md](docs/PLAN.md).

**Download:** [CurseForge](https://www.curseforge.com/wow/addons/elysium-spelldelta) or
[GitHub releases](https://github.com/elysium1331/SpellDelta-WoW-Forever/releases).

SpellDelta is an unofficial community addon. Blizzard Entertainment did not make or
endorse it.

## Supported client

| Client | Version / build | Interface | Status |
|---|---|---|---|
| World of Warcraft: Forever | 1.60.1.70938 | 16001 | Built against this build's Blizzard UI source and game data; checked in game with a level 34 priest (healing and caster damage spells, gear, enchants, talents). |

**Other classes have not been checked in game yet.** Warrior, rogue, hunter, paladin,
shaman, druid, mage and warlock numbers (weapon strikes, attack power, forms, block value)
come from the same game data and formulas and are unit-tested, but nobody has compared
them with the game's own tooltips. If a number looks off, please
[open an issue](https://github.com/elysium1331/SpellDelta-WoW-Forever/issues) with a
screenshot and the output of `/delta dump`.

## How to use it

Point at a weapon or armor piece: in your bags, on a loot roll, in the loot window, on a
quest reward or a chat link. If it changes any spell on your action bars, the tooltip
shows a grey line, "Hold Alt: spell changes". Hold Alt to see up to 6 spells, each with
its icon, number before and after, and the change:

```
Spells - with Death Speaker Scepter, replacing Glimmering Staff
  Heal                 629 to 665  (+36)
  Smite                116 to 97   (-19)
  Health               1210 to 1100 (-110)
  Mana                 1450 to 1285 (-165)
```

The 6 are the spells you cast most (SpellDelta counts them as you play); until it has seen
you cast, the biggest changes. Below them, every stat line the item changes (health, mana,
crit, armor...) always shows, so stamina or intellect you would lose is never hidden.

No setup and no commands. SpellDelta reads your spells' current tooltip numbers itself,
and knows from the game data how much each number grows per point of spell damage,
healing or attack power. Weapon strikes (Sinister Strike, Mortal Strike, Auto Shot...)
show their average hit, worked out from your weapon and attack power with the game's own
weapon formula; they only show when that formula matches the game's damage readout for
what you wear. It shows numbers only; it never tells you whether to Need or Greed.

Talents work the same way. Open the talent window and point at a talent: the tooltip
shows "Hold Alt: spell changes". Hold Alt to see what the talent's next rank does to the
spells on your bars, and, while you have added points without pressing Apply Changes yet,
what those pending points do:

```
Points not applied yet - spells on your bars
  Renew                211 to 217  (+6)
Rank 4 of 5 - spells on your bars
  Renew                217 to 219  (+2)
```

The game's spell tooltips only change after Apply Changes, so these are worked out from
the game data. Item tooltips also count your applied talents: a talent like Twin
Disciplines (+3% to instant spells) makes the staff's +34 spell power worth +35 on Renew,
while Improved Power Word: Shield (+20%) only raises the shield's own amount, not what gear
adds. Weapon strikes and finishers take their own talents too (Aggression, Opportunity), and
talents that change a cost, cast time, cooldown, duration or crit chance show those as plain
facts ("Mind Blast cooldown 8.0 to 7.5 sec"). Talents that change your character sheet show
the same "what you get" lines as gear: Shield Specialization shows block chance, Mental
Strength shows Intellect and the mana it brings, Toughness shows armor; Darkness raises your
shadow spells' numbers. Talents that only add a chance for something to happen (procs), or
that need a certain weapon, form or stance, are not shown: they can't be measured without
that condition.

To plan more than one item, open the character screen and pick the SpellDelta tab (the
last side tab), or click SpellDelta in the minimap AddOns menu. Click a slot to choose from
the bag items that fit it, or drop or Shift-click an item. The middle shows your spells now
and with the planned gear, the stat changes, what you get from them (health, attack power,
crit, armor, dodge, parry, block...), and which gear bonuses grow which of your spells.
Click a spell or a "what you get" line there to choose it for the Alt tooltip (up to 6
in all). Right-clicking an
item in your bags still equips it as usual; the plan adjusts to what you wear.

`/delta dump` prints what SpellDelta has read, for bug reports.

## Install

Copy the `Elysium_SpellDelta` folder from the release zip into
`World of Warcraft\_forever_\Interface\AddOns\`, then `/reload` or restart the game.

## Data and privacy

Everything SpellDelta learns is stored per character in its own saved variables
(`SpellDeltaCharDB`). Nothing is sent anywhere.

## License

MIT. See [LICENSE](LICENSE) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
