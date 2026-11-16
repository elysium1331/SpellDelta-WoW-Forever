# [Elysium] SpellDelta

Part of the **Elysium** addon collection for WoW Forever by
[elysium1331](https://github.com/elysium1331).

SpellDelta answers one question: *what does this talent, or this item, change about
the spells I actually use?* It reads the game's own tooltip numbers for the spells on
your action bars, so you see real numbers and no upgrade scores.

**Status:** 0.3.0-alpha.2, phase 3 of the plan in [docs/PLAN.md](docs/PLAN.md).
Not released yet.

SpellDelta is an unofficial community addon. Blizzard Entertainment did not make or
endorse it.

## Supported client

| Client | Version / build | Interface | Status |
|---|---|---|---|
| World of Warcraft: Forever | 1.60.1.70938 | 16001 | Built against this build's Blizzard UI source and game data; checked in game with a level 34 priest (healing and caster damage spells). |

## How to use it

Point at a weapon or armor piece: in your bags, on a loot roll, in the loot window, on a
quest reward or a chat link. If it changes any spell on your action bars, the tooltip
shows a grey line, "Hold Alt: spell changes". Hold Alt to see up to 6 spells, each with
its icon, number before and after, and the change:

```
Spells - with Death Speaker Scepter, replacing Glimmering Staff
  Heal                 629 to 665  (+36)
  Smite                116 to 97   (-19)
```

The 6 are the spells you cast most (SpellDelta counts them as you play); until it has seen
you cast, the biggest changes.

No setup and no commands. SpellDelta reads your spells' current tooltip numbers itself,
and knows from the game data how much each number grows per point of spell damage or
healing. It shows numbers only; it never tells you whether to Need or Greed.

To plan more than one item, open the character screen and pick the SpellDelta tab (the
last side tab), or click SpellDelta in the minimap AddOns menu. Click a slot to choose from
the bag items that fit it, or drop or Shift-click an item. The middle shows your spells now
and with the planned gear, the stat changes, and which gear bonuses grow which of your
spells. Click a spell there to choose it for the Alt tooltip (up to 6). Right-clicking an
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
