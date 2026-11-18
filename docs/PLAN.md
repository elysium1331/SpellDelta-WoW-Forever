# [Elysium] SpellDelta: design and build plan

**Status: v5 (2026-11-16). v5 replaces the separate window (1c) with a SpellDelta tab on the
character screen. Phase 1 and phase 2 (Alt-hover, 0.2.0-alpha.2) are built; Ryan confirmed in game
that the tooltip follows his casts and the icons read well.**

Changes in v5, from Ryan:
- **A SpellDelta tab on the character screen** replaces the single-item window. It opens with
  your current gear in every slot (same layout as the game's gear screen: slot columns, weapons at
  the bottom, character in the middle). Drop the gear you are considering onto slots, or onto the
  panel to let it find the slot; several slots at once make a planned loadout. Changed slots are
  highlighted; right-click a slot to put your worn item back; "Reset to my gear" undoes all. You
  choose which ring or trinket is replaced. A two-hander clears the off-hand and the reverse. The
  plan is kept per character until reset. The character model wears the planned gear (the game's
  try-on, as in the dressing room).
- **Right panel, the Delta:** spells and abilities (your 6 first, then "Show all"; learned spells
  at your current rank only), then stats (Health, Intellect, Spirit, Armor and so on), each as
  now, planned and change.
- **"What gear bonuses do for your spells" box**, grouped the way items word their bonuses, so
  the player sees that general spell damage helps every spell and a school bonus helps only that
  school. Lines appear only for bonuses that help a spell you know. No per-point numbers: the
  spell list already shows what the planned gear does.
  ```
  Spell damage and healing   all your spells below
  Healing                    Heal, Renew, Flash Heal, Power Word: Shield
  Shadow damage              Mind Blast, Shadow Word: Pain
  Holy damage                Smite, Holy Fire
  Arcane damage              Starshards
  ```
  Facts from the game data only, unlike hand-written "stat priority" boxes in other addons.
- **The tab is our own button styled like the game's tabs**, not added to Blizzard's tab list:
  changing Blizzard's frames from an addon can cause "action blocked" errors. Clicking it lays our
  panel over the gear area; clicking any game tab hides it. Opening SpellDelta from the minimap
  AddOns menu opens the character screen on this tab. Before building, read Forever's character
  screen source to line the button up with its tabs and confirm try-on is available.
- v5.1 after Ryan's first look (0.3.0-alpha.2): no character model (it rendered badly, and
  looks are not the point); the changes list sits between the slot columns, so the game's
  right pane can stay open or closed. Click a slot to pick from fitting bag items. Right-click
  in the bags stays the game's equip; the plan corrects itself to what is worn.
- v6, all classes (0.4.0-alpha.1): abilities whose tooltip number grows with attack power
  (Victory Rush, Revenge) come from the game data like spells do. Weapon strikes (Sinister
  Strike, Mortal Strike, Heroic Strike, Auto Shot, Aimed Shot...) show their average hit,
  worked out with the game's own weapon formula from the weapon, attack power and the strike's
  game data; the formula is first checked against the game's main-hand (or ranged) damage for
  the worn weapon, and strikes are left out if it does not match (druid forms, for example).
  "What you get" stat lines (health, mana, attack power, crit, armor, physical damage reduction,
  defense, dodge, parry, block) are worked out with the game's own "what is a stat worth"
  functions, and each can be chosen, like a spell, to show on items when Alt is held.
- Left out for now: an automatic "best gear" button (it would make upgrade decisions) and several
  saved loadouts. Set bonuses and tank/melee stat lines fit here later.

Changes in v4, from Ryan's in-game test (the Heal prediction matched his tooltip to half a point):
- **At most 6 spells on hover, chosen by the player.** Until the player chooses, the addon counts
  the spells they cast (spells gear can change, all ranks together) and shows the 6 most cast;
  with no counts yet, the biggest changes. No healing/damage split, so it suits every class.
- **The window (now the character tab, v5) is where you choose** (up to 6, or just 1): pick from the full list, or drag from
  the spellbook. Only spells gear can change are selectable (Shield Wall is not; Victory Rush is).
  The window also shows every spell and the per-school summary that left the tooltip.
- **Stat lines can be tracked too**, alongside spells, for classes whose gear matters beyond spell
  numbers: Health, Damage reduction % (armor), Avoidance % (dodge, parry, block, miss; defense
  also cuts crits taken), Block amount, Attack power. Tanks and melee pick these in the window.
- **Every class's abilities, not only spell power.** Attack-power abilities (Victory Rush's
  "1 + $AP * 15/100", Sinister Strike, Mortal Strike) need the extractor to read `$AP` and items'
  Strength/Agility/Attack Power. Required before release.
- **Icons:** each row starts with the spell's icon at text height, then the name.
- **Talents:** checked in game on 2026-11-17 (respec, priest 34, naked and with three items, Twin
  Disciplines 1 and 3 points, Improved Power Word: Shield 1 and 3 points). Spell tooltips include
  applied talents, never pending ones; item tooltips never include talents. The game's number is
  floor((base x base talents + spell power x share) x whole talents). Talent operations in the
  data (aura 108 EffectMiscValue): 0 and 22 multiply the whole amount, 3/12/23/8 only the base.
  Which spells a talent touches comes from its class mask, not its wording (Twin Disciplines
  boosts channeled Starshards and skips Power Word: Shield). Built in 0.5.0-alpha.1.
- Fixed: effects that never grow with bonuses (Resurrection's "resurrect", buffs, dummies) are no
  longer read as scaling.

Changes in v3, from Ryan's first in-game look at phase 1:
- **No commands in normal use.** Chat output and `/delta` commands were hard to read and not
  usable. Everything the player needs appears on its own: on item tooltips now, in a window later.
  `/delta` stays only for bug reports.
- **Alt-hover on item tooltips is the main feature.** Pointing at an item shows one grey line,
  "Hold Alt: spell changes". Holding Alt adds the spells on your bars whose numbers change, with
  before, after and the change, plus a per-school summary. It pairs a two-hand swap with the best
  one-hander or off-hand in the bags, like the game's own comparison. Works wherever the game shows
  an item tooltip: bags, character sheet, loot rolls, loot window, quest rewards, chat links. This
  replaces the separate loot-roll card (1a).
- **Coefficients come from the game files, not from swapping gear.** wow.export was run once on
  build 70938 (30 tables exported into the git-ignored `data-src/`). `scripts/extract_spelldata.py`
  writes `SpellData.lua`: for 756 class spells, every tooltip number and how much it grows per point
  of spell damage (by school) or healing. The values match Ryan's measured ones (Heal 0.857, Smite
  0.714, Mind Blast 0.429, Shield 0.1). A spell is predicted only when its live tooltip shows exactly
  the expected count of numbers, so a misread template shows nothing instead of a wrong number.
- **Learning stays, silently,** as a background check; it no longer has to run before anything works.
- Spell IDs are removed from all player-facing text.

Revised phases (replace section 7's table):

| Phase | Delivers | State |
|---|---|---|
| 1. Skeleton + reading | Tooling, action-bar and macro spells, tooltip number reader, learning. | Built (0.1.0-alpha.1) |
| 2. Alt-hover | Generated `SpellData.lua`, item bonus reader, pairing, Alt tooltip block, hint line; 6 spells by casts, icons. | Built (0.2.0-alpha.2); Heal matched in game |
| 3. Character tab | SpellDelta tab on the character screen (v5): planned loadout in gear slots, bag picker per slot, spell and stat Delta, "What gear bonuses do" box, choosing the 6 hover spells (stat lines later). Learned spells at your current rank only; future ranks and talent-granted spells belong to the Talent tester. | Checked in game (0.3.0-alpha.2, level 34 priest) |
| 3b. All classes | Attack-power abilities, weapon strikes, "What you get" stat lines (choosable for the Alt tooltip), attack-power groups (v6). | Built (0.4.0-alpha.5), in-game check pending |
| 4. Talent effects | Talent modifiers on spell numbers (generated from SpellEffect, SpellClassOptions, Trait*); gear gains scaled by applied whole-amount talents; exact numbers rebuilt from the data and cut off like the game; Alt over a talent: pending points and next rank. Since alpha.2 also weapon strikes and finishers (whole-hit talents), and facts: cost, cast time (keeps haste), cooldown (from the spell's tooltip), crit chance from talents, duration (longer damage over time adds ticks). Only passive talents count (Inner Focus, Cold Blood are buttons). Since alpha.3 character-sheet talents (block, parry, dodge, crit, hit, defense, % of a stat, armor from items, attack power, block value, regeneration while casting) as "what you get" lines, % damage of magic schools (Darkness), crit damage. Left out: procs, and any part of a talent whose words name a weapon, form, stance or event (physical % damage needs a weapon type the exported data does not name). | Built (0.5.0-alpha.3), in-game check pending |
| 5. Talent tester | As in 1d. | |
| 6. Release | All classes labelled unverified, README, VALIDATION.md, release on Ryan's OK. | |

Known limits of phase 2, with Ryan's notes (2026-11-16):
- Talents already taken are in the live tooltip numbers, so gear predictions start from them.
  Since 0.5.0-alpha.1 a percentage talent that multiplies the whole amount (Twin Disciplines)
  also scales the bonus the new gear adds, and the first number is rebuilt from the game data
  and cut off like the game when the data matches what the game shows (otherwise rounded as
  before; "min to max" pairs always so). Off by one is still possible in that fallback.
- Since 0.4.0-alpha.1 every class's main numbers are modelled (attack power, weapon strikes,
  off-hand and both-hand strikes, attack-power shares, block value, health, avoidance). Rule
  (Ryan, 2026-11-16): an ability is in when gear changes its number, the same as a spell; it
  is out when gear cannot change it (Shield Wall, Levitate, Resurrection). Since 0.4.0-alpha.5
  (Ryan's choice): finishers whose text says "increased by Attack Power" without saying how much
  (Eviscerate, Rupture, Garrote, Rip, Ferocious Bite) and Shield of Righteousness use numbers
  measured by players (wowsims SoD simulator, Measured.lua), marked "*" with a footnote;
  Between the Eyes stays out (the simulator marks its share untested). Druid Cat and Bear Form
  strikes show while in that form: the weapon counts only if "weapon DPS x form speed" matches
  the game's form damage, otherwise the weapon is left out (simulator rule, marked "*"). Known
  gaps: talents
  that change a strike's own damage (only talents raising all physical damage are counted);
  stance-dependent tooltip numbers use the no-stance value (Revenge); percentage talents on
  stats (for example +5% Stamina); attack power that only counts against some foes.
- Set bonuses are ignored. Wanted later; not needed for testing now.

Changes in v2, from Ryan's feedback:
- Items you **could own right now** are in scope: loot rolls (with a quick Need/Greed card),
  the loot window, quest rewards, and items linked in chat. See 1a and 2.
- New **Talent tester**: plan a build (a full respec or a few moved points) and see its effect on
  your spells before paying for a respec. See 1d.
- Data source decided: **read Ryan's own install with wow.export** (approved). Section 4c explains
  why one extraction covers every class and every player.

Target client: WoW Forever **1.60.1.70938** (read from the install's `.build.info`; the game has
patched since SocialWheel was tested on 70862). APIs were checked against the Gethe/wow-ui-source
`forever` branch at commit `bebcb6b` ("1.60.1 (70938)"), the same build. That copy was cloned to a
scratch folder and used as reference only. The interface number is assumed to still be 16001;
confirm it in game (check 1 in section 8).

The addon answers one question:

> "What does this talent, or this item, change about the spells I actually use?"

---

## 0. Name

Pick one. Renaming the folder before the build starts costs nothing.

| Option | Addon folder | Repo | Why |
|---|---|---|---|
| **SpellDelta** (recommended) | `Elysium_SpellDelta` | `SpellDelta-WoW-Forever` | Says what it shows: the change ("delta") in your spells, for items and talents alike. Short and easy to search for. |
| Ripple | `Elysium_Ripple` | `Ripple-WoW-Forever` | Friendly ("see how a talent ripples through your spells"), but harder to find by search. |
| SpellLens | `Elysium_SpellLens` | `SpellLens-WoW-Forever` | "Look at your spells through an item." |

TOC: `## Title: [Elysium] SpellDelta`, `## Category: Elysium`, `## Group: Elysium_SpellDelta`.
The dev folder is `wow-addons\SpellDelta`, like `SocialWheel` and `ProfessionWheel`. `package.py`
builds the `Elysium_SpellDelta` addon folder from it.

---

## 1. What the player sees (UX)

Design rule: **show the result, not the formula, and nothing to configure.** There are no stat
weights, no "upgrade" arrows and no scores. SpellCoda shows every formula input; SpellDelta shows
only what changes.

Three ways in, one window:

| Where | What | Speed |
|---|---|---|
| Loot roll | A small card under each roll, already filled in (1a) | Instant, no hovering |
| Tooltips | One line on talents and on items you own or could own (1b) | Instant |
| "SpellDelta" window | **Items** tab: full before/after table (1c). **Talent tester** tab: plan a build (1d). | When you have time |

### 1a. Loot roll card (the 60-second Need/Greed decision)

When a roll starts, a compact card appears under the game's roll frame, already calculated. You
read it while the timer runs; you don't need to hover or open anything.

```
+-----------------------------------------------------------------+
| [icon] Robe of Evening Light            [Need] [Greed] [Pass]  |
|        =============================-------- 0:47               |
+-----------------------------------------------------------------+
| SpellDelta  ~ vs. your Twill Robe (chest)                       |
|   Healing spells   +3%   Heal +21, Renew +9, Flash Heal +7      |
|   Damage spells     0%   no change                              |
|   Mana cost        no change                                    |
|   Other stats      +6 Int, +4 Spirit, -5 Stamina, -38 Armor     |
+-----------------------------------------------------------------+
```

What each line means:
- **Healing spells / Damage spells:** the average percentage change across your healing (or
  damage) spells on your action bars, followed by the 2 or 3 biggest changes in actual numbers.
  Healing and damage are always shown separately, because you switch between them.
- **Mana cost:** shown only if the item changes costs (rare, from set bonuses and special items).
- **Other stats:** the plain difference in stats the spell numbers don't capture (Intellect,
  Spirit, Stamina, armor, crit and so on). Listed, not rated.
- **Special cases:**
  - Can't equip it (wrong armor or weapon type): the card says
    `You can't use this (the game's reason)` and nothing else.
  - Ring or trinket: one line per slot, `vs. ring 1: ...` and `vs. ring 2: ...`.
  - Two-hand weapon vs. your main-hand + off-hand: compared against both together (and the
    reverse).
  - Same item already equipped: `You already have this.`
  - Item data not loaded yet: the card shows "loading" and fills in within a second.
- The card **never says Need or Greed** and never says "upgrade". It gives you the numbers to
  decide in a few seconds. The ~ means "estimate" (an item you haven't worn can't be measured
  exactly; see 3c).

### 1b. One line on tooltips

Shown on talents and on items you own **or could own right now** (section 2):

```
 Twin Disciplines                          Rank 3/5
 Increases damage and healing of your instant spells by 3%.
 ...
 SpellDelta ~ affects 4 of your spells. Biggest: Renew +11 healing
```

```
 Brightwood Staff                          (in your bags)
 ...
 SpellDelta ~ vs. your mace + off-hand: Healing -4%  Damage +9%
   Biggest: Smite +18, Heal -36
```

```
 Ironbound Mace                            (equipped)
 ...
 SpellDelta: without it, Healing -9%. Biggest: Heal -58
```

- It uses the same "Healing % / Damage %" summary as the roll card, so you learn to read one
  format.
- For a talent you have not taken, it shows what taking it would add. For a talent you have, it
  shows what it adds now.
- Hold **Shift** to see the top 3 spells. Shift+click opens the full window on that item or talent.
- The line can be turned off with one checkbox in Settings.

### 1c. Window, Items tab (replaced in v5 by the character tab)

Opened by `/delta`, the addon compartment button, or Shift+clicking a tooltip line or roll card.

```
+--[Elysium] SpellDelta ------------------------------------------------ X -+
|  [ Items ]  [ Talent tester ]                                              |
|                                                                            |
|  Compare:  [ Drop an item here ]                                           |
|            Brightwood Staff  (in bags; replaces Ironbound Mace +           |
|                               Tome of Shadows)                             |
|  Mode:  (o) Preview (estimate)   ( ) Swap and compare (exact, owned only)  |
|                                                                            |
|  Spell                 Now      With     Change   Mana   Per mana          |
|  --------------------  -------  -------  -------  -----  ------------      |
|  Smite                 98       116      +18      67     1.5 -> 1.7        |
|  Mind Blast            192      191      -1       140    1.4 -> 1.4        |
|  Holy Fire             244      266      +22      104    2.3 -> 2.6        |
|  Heal                  665      629      -36      155    4.3 -> 4.1        |
|  Renew                 300      282      -18      69     4.3 -> 4.1        |
|  Power Word: Shield    374      370      -4       109    3.4 -> 3.4        |
|                                                                            |
|  Healing spells -4%   Damage spells +9%    Other: +4 Stamina, -10 Spirit   |
|  ~ = estimate. Amounts are the average of the tooltip's range.             |
|  12 spells on your bars, 6 shown (6 unchanged; [Show all]).                |
+----------------------------------------------------------------------------+
```

(Smite, Mind Blast, Heal and Power Word: Shield use your measured tooltips for staff vs. mace +
off-hand. The item names, Holy Fire, Renew and all mana numbers are made up for illustration.)

- **Drop an item:** drag an item from your bags, character sheet, loot window or roll frame, or
  Shift+click any item link you are allowed to compare (section 2).
- **Columns:**
  - **Now / With / Change:** the average of the tooltip's range (87-96 -> 91.5, shown rounded).
    Hover a row for the full ranges.
  - **Mana:** the cost now, shown as `104 -> 98` if it changes.
  - **Per mana:** average amount divided by mana cost.
  - **Cast** and **Crit** columns appear only when something changes them (mostly talents, 1d).
- Green and red colouring is only a reading aid. There is no overall score.
- Spells that don't change are folded under "Show all".

### 1d. Window, Talent tester tab (new)

Lets you try a build before paying for a respec: a full spec change, or the same spec with a few
points moved.

```
+--[Elysium] SpellDelta ------------------------------------------------ X -+
|  [ Items ]  [ Talent tester ]                                              |
|                                                                            |
|  Plan: [ My build (copy) v ] [Save as...]   Points for level: [ 40 v ]    |
|  Points: 31 of 31 used    Discipline 21 / Holy 10 / Shadow 0               |
|  [Reset to my build]  [Clear all]                                          |
|                                                                            |
|   DISCIPLINE (21)          HOLY (10)              SHADOW (0)              |
|   [ ][5][ ]                [ ][5][ ]              [ ][ ][ ]                |
|   [2][3][ ][ ]             [ ][5][ ]              [ ][ ][ ][ ]             |
|   ...                      ...                    ...                     |
|   (the game's own tree, drawn from live talent data; click = +1 rank,     |
|    right-click = -1 rank; locked talents greyed out with the reason)      |
|                                                                            |
|  Changes from your build:  -3 Twin Disciplines, +3 Divine Fury            |
|                                                                            |
|  Spell                 Now      Plan     Change   Mana   Cast    Per mana  |
|  --------------------  -------  -------  -------  -----  ------  --------  |
|  Smite                 98       95       -3       67     2.5->2.0  ...     |
|  Holy Fire           ~ 244      237      -7       104    3.5->3.0  ...     |
|  Renew               ~ 300      291      -9       69     -         ...     |
|  Heal                  665      665      0        155    3.0->2.5  ...     |
|                                                                            |
|  New spells from this plan: none.   Lost: none.                            |
|  Also changes (not calculated): none.                                      |
+----------------------------------------------------------------------------+
```

How it works:
- **The tree comes from the game at runtime**: positions, max ranks, prerequisite arrows and
  "N points in this tree" gates (`C_Traits.GetTreeNodes / GetNodeInfo / GetConditionInfo`). It
  reads the whole tree, including talents you have not taken. The addon never changes your real
  talents; the plan exists only inside the addon.
- **The plan starts as a copy of your current build.** Clicks add or remove ranks. The game's
  rules (gates, prerequisites, points available) are enforced, so a plan can always actually be
  taken.
- **Points for level:** your level by default. Pick a higher level to plan ahead (e.g. "at 40").
- **Impact table:** your action-bar spells, current build vs. plan, using your current gear.
  Effects come from the generated talent data (section 4). Cast time and crit appear because
  talents often change those rather than the amount.
- **New / lost spells:** talents that grant a spell (e.g. a 31-point talent) are listed as "New
  spells". A talent spell on your bars that the plan drops is listed under "Lost".
- **Also changes:** talents that don't touch your spells' numbers (mana regen, threat, resistances)
  are listed with the talent's own text, so nothing is silently ignored.
- **Saved plans:** up to 10 named plans per character (e.g. "Disc 40 heal", "Shadow 40").
- Results are labelled ~ unless the talent is a plain modifier verified in game (3e).
- Later, only if Forever supports it (check 9): "Copy build string" to import the plan after your
  respec. The source has `C_Traits.GenerateImportString` and `C_ClassTalents.ImportLoadout`, but
  whether Forever's respec-at-trainer system accepts them is unknown.

### 1e. Which spells are listed

Only spells on your action bars, including spells inside macros:
- Every action slot (`GetActionInfo`). Spell entries are read directly; macro entries via
  `GetMacroSpell(macroIndex)`, which gives the spell the macro would cast now (the one its button
  shows).
- Duplicates are merged. Items, mounts, toys, flyouts and equipment sets are skipped.
- Spells with no amount (Fade, Levitate) appear only under "Show all", with cost.
- The list refreshes on `ACTIONBAR_SLOT_CHANGED`, `UPDATE_MACROS` and login.

---

## 2. Scope rules

| Rule | How the plan follows it |
|---|---|
| **Items you own or could own right now** (changed in v2) | Allowed: equipped, bags, **loot rolls**, the **loot window**, **quest reward choices**, and items **linked in chat** (someone asks "anyone need this?"). Not allowed: dungeon journal, item databases, the auction house, vendors, or any item search. So no browsing theoretical gear. The bank can be added later. |
| No "upgrade" verdicts | Numbers only: no Need/Greed advice, arrows, scores or "best" sorting. The healing/damage % summary is a measurement, not a verdict. |
| Every class from release 1 | The data file covers every class (4c). A small `VERIFIED = { PRIEST = true }` table adds an "unverified class" note in the window footer and a one-time chat line. A class becomes verified when someone runs the section 8 checks on it. |

---

## 3. Measuring engine

### 3a. Where the numbers come from (all confirmed in the Forever UI source, build 70938)

| What | API | Notes from the source |
|---|---|---|
| Spell text with live numbers | `C_Spell.GetSpellDescription(spellID)` | May be empty until the spell loads. Listen for `SPELL_TEXT_UPDATE`, or use `Spell:CreateFromSpellID(id):ContinueOnSpellLoad`. Not restricted for addons. |
| Mana cost | `C_Spell.GetSpellPowerCost(spellID)` | Returns a list of `{type, name, cost, minCost, costPercent, ...}`. |
| Current bonuses | `GetSpellBonusDamage(school)`, `GetSpellBonusHealing()` | Flagged `SecretWhenUnitStatsRestricted`, so they can return unreadable "secret" values in some restricted situations (likely boss encounters). We measure only out of combat and skip a value if `issecretvalue()` reports it. The Forever character sheet (`Camelot/PaperDollFrame.lua`) shows the **lowest** bonus across schools 2-7 as "Spell Damage". That is why your mace's +28 shadow didn't show there but did raise Mind Blast. The addon always reads the spell's own school. |
| Item stats (any item link) | `C_Item.GetItemStats(link)`, `C_TooltipInfo.GetHyperlink` | Work on any link, owned or not. |
| Loot rolls | `START_LOOT_ROLL`, `GetLootRollItemLink(rollID)`, `GetLootRollItemInfo(rollID)` | Forever uses the standard mainline `GroupLootFrame` (`Blizzard_UIPanels_Game/Mainline/GroupLootFrame.lua`). `GetLootRollItemInfo` also returns `canNeed` and the reason if you can't. We attach the card to the visible roll frame; we never click a roll button. |
| Talents | `C_ClassTalents.GetActiveConfigID`, `C_Traits.GetTreeNodes / GetNodeInfo / GetEntryInfo / GetDefinitionInfo / GetConditionInfo / GetTreeCurrencyInfo` | **Forever uses the modern talent-tree system**, re-skinned to look Classic (`Blizzard_PlayerSpells/Camelot`). Node info includes `posX/posY`, `maxRanks`, `visibleEdges` and `conditionIDs`; condition info includes `isGate` and `spentAmountRequired`. That is everything the tester needs to draw and enforce the tree. Each talent's definition gives a `spellID`, which is our key into the data file. |
| Talent tooltip hook | `EventRegistry` callback `"TalentDisplay.TooltipCreated"` | Fired by Blizzard's talent button with the button and the tooltip. Blizzard's own PTR addon uses the same hook. |
| Item tooltip hook | `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, ...)` | Standard. |
| Action bars / macros | `GetActionInfo(slot)`, `GetMacroSpell(index)` | Both used by Blizzard code in this build. |
| Dropped item | `GetCursorInfo()` | Returns `"item", itemID, itemLink`. |
| Swapping (owned only) | `C_Item.EquipItemByName`, `C_Item.IsBound(itemLocation)` | Not marked protected. Out of combat only. |
| Refresh triggers | `PLAYER_EQUIPMENT_CHANGED`, `TRAIT_CONFIG_UPDATED`, `SPELL_TEXT_UPDATE`, `ACTIONBAR_SLOT_CHANGED`, `UPDATE_MACROS`, `START_LOOT_ROLL` | All documented in this build. |

### 3b. Reading a number out of a spell's text

Spell text is a sentence: "Smites an enemy for 87 to 96 Holy damage." To know **which** number is
the amount (not the duration or range), the data file stores where each effect's number appears in
the text. It takes this from the spell's description template, e.g. `$s1 to $S1` covers numbers 1
and 2. The addon picks numbers by position instead of guessing. If the text has an unexpected
count of numbers (after a new patch, or on a non-English client with a different word order), that
spell falls back to the calculated path and is marked ~.

### 3c. Item comparisons: preview and exact

**Preview (estimate)**: used for loot rolls, tooltips and the window's default mode.

`new amount = current measured amount + coefficient x (bonus change)`

The bonus change is the item's spell damage and healing bonuses minus those of the item it
replaces. Bonuses come from the item's stats, or from its "Equip:" effects via the data file. This
works for any item link, so it is ready the instant a roll starts. Everything is precomputed from
your current spells, so the card costs a few table lookups.

**Swap and compare (exact)**: items you own only. Uses only the game's own numbers.
1. Out of combat, the addon reads every listed spell's text and cost ("before").
2. It equips the item, waits for the spell text to update, reads again ("after"), then puts your
   original items back.
3. Safety checks first:
   - Refuses in combat.
   - Asks first if equipping would bind the item ("Binds when equipped").
   - Handles two-hand vs. main-hand + off-hand.
   - If anything fails, it aborts and restores your gear. `/delta restore` is a manual fallback.
4. Swapping gear yourself also works: the addon records every gear state it sees.

### 3d. Learning each spell's scaling (coefficient)

Your measurements already prove the method: Heal rose 0.86 per point of healing bonus, Smite 0.71,
Mind Blast 0.42 and Power Word: Shield 0.10, and healing bonus changed no damage spell.

- At every new gear state (out of combat), the addon stores per spell `{ bonus seen, amount read }`
  in `SpellDeltaCharDB` (per character).
- With two or more states at least 10 bonus points apart, it fits a straight line: the slope is
  the coefficient. Tooltip numbers are whole numbers, so a 34-point gap gives about +/-0.03.
- Until a spell has been learned, it uses the coefficient from the data file. If the learned and
  generated values differ by more than 0.05, the learned one wins and the row says so on hover.
  This is also how we catch data or hotfix mismatches.
- Learned values are tagged with the game build and re-checked after a patch.

### 3e. Talents: always calculated

You can't try a talent without a respec, so talent results are calculated: the current measured
amount, with the modifiers of the current build removed and the planned build's added (section 4).
- Rows are labelled ~ unless the talent is a plain, unconditional modifier (like Twin Disciplines
  or Mental Agility) whose numbers have been checked against the game's tooltip after taking it.
  Checked talents are recorded in `VERIFIED_TALENTS`.
- Talents that change stats (e.g. a percentage of Spirit as spell power) convert the stat change
  into bonus, then apply the learned coefficient. These are always ~.

---

## 4. Talent and spell data: generated, not hand-written

### 4a. How the game describes talents (why this works)

- Every class spell has a **spell family** (priest = 6) and a **family mask**: a set of on/off
  flags stored as four 32-bit numbers. Smite, Holy Fire and the instant spells each have their own
  flag.
- A talent like Mental Agility is a passive spell whose effect is a **modifier aura**. In plain
  terms: "add a percent modifier to `cost`, -2% per rank, for spells whose family mask matches
  these flags". Twin Disciplines is the same shape, with `damage and healing` +1% per rank.
- So one rule covers every talent of this kind: *for each talent effect, apply the change to each
  of your spells in the same family whose mask shares a flag with the effect's mask.*
- Addons can't read these game tables at runtime. A script reads them once per patch and writes
  `SpellData.lua`, the same way `extract_catalog.py` writes `CatalogData.lua` for SocialWheel.
- The tree **layout** does not need to be in the file; the game provides it at runtime (3a).

### 4b. What the generated file contains

Class spells (spells in a class family), talents, and spell-bonus "Equip:" effects. Not the whole
game.

```lua
-- GENERATED by scripts/extract_spelldata.py from client 1.60.1.70938. Do not edit by hand.
-- Derived from World of Warcraft game data, (c) Blizzard Entertainment.
ns.SpellData = {
  build = "1.60.1.70938",
  spells = {
    -- [spellID] = { family, {m1,m2,m3,m4}, school, castMs, effects = { {kind, base, coeff, textPos} } }
    [585] = { 6, {0x80,0,0,0}, 2, 2500, effects = { { "dmg", 13, 0.714, {1,2} } } }, -- Smite
  },
  talents = {
    -- [talentSpellID] = { ranks = { [1] = { { op = "cost", pct = -2, mask = {...} } } } }
  },
  equip = {
    -- [equipSpellID] = { "heal", 68 } / { "dmg", 28, schoolMask }
  },
  items = {
    -- [itemID] = { equipSpellID, ... }  (only items with spell-bonus equip effects)
  },
}
```

Source tables (names as wow.export shows them): `SpellName`, `Spell` (description templates, 3b),
`SpellMisc` (school, cast time), `SpellCastTimes`, `SpellClassOptions` (family and mask),
`SpellEffect` (effect type, aura, base points, coefficient, which stat is modified, effect mask),
`SpellPower` (cost), `SkillLineAbility` (which spells belong to which class), `TraitDefinition` and
`TraitNodeEntry` (talent to spell), and `ItemEffect` (item to "Equip:" spell).

Size estimate: roughly 300-700 KB of Lua. If loading is slow, the file is split per class and only
your class (plus the shared item table) is loaded.

### 4c. Data source: your own install, read with wow.export (approved)

**Does everyone need wow.export? No. Only you, once per game patch.**
- The game client on your PC contains the data for **every** class, spell, talent and item, not
  just your priest's. Every client needs it to show other players' spells and tooltips. So one
  extraction from your install gives the full data set.
- The script turns that into `SpellData.lua`, which **ships inside the addon**. Players just
  install SpellDelta; they never see wow.export, CSVs or Python.
- **Re-run it when Forever patches** in a way that changes spells or talents. Until then:
  - Measured numbers (tooltips, swaps, learned coefficients) stay correct, since they come from
    the live game.
  - Only talent effects and item previews could be stale.
  - The addon compares the data file's build to the running client and shows "data from an older
    patch" in the window footer when they differ.
- Language: the data is numbers and IDs, so it works on any client language. Only the "which
  number in the text" positions (3b) come from the English templates; other languages fall back to
  calculated values.

**Why this source** (research 2026-11-15, public pages only, nothing downloaded):

| Source | What we found | Role |
|---|---|---|
| **Your install via wow.export** | wow.export (MIT, open source) lists product `wowf`, "World of Warcraft Forever", in its code. Forever support was added in 0.2.20 (Nov 2026). It exports game tables (DB2) to CSV and handles encrypted ones. Your install is `wowf` 1.60.1.70938. | **Primary.** It is the exact build you play, repeatable, and depends on no website. |
| wago.tools CSV downloads | Automated requests got 403 (blocked), but its `robots.txt` allows the CSV pages (`/db2/<Table>/csv?build=...`). Forever coverage is unconfirmed, and it publishes no terms. | Fallback: you'd open a few links by hand in a browser if wow.export ever breaks. |
| SpellCoda's generated data (`jezzi23/spellcoda-generated`, `Camelot` folder) | MIT, updated 2026-11-13. It has per-spell base values, coefficients, costs and ranks; no family masks or talent modifier tables were visible. | Cross-check of our coefficients in tests only. Not copied. |

**Hotfixes.** Blizzard tunes numbers between patches with hotfixes. The client stores them in
`_forever_\Cache\ADB\enUS\DBCache.bin`, and wow.export does not appear to apply them.
1. To start, we rely on the measuring engine: live tooltip numbers always include hotfixes, and
   learned coefficients override the file. Mismatches are flagged.
2. If mismatches turn out to be common, we add a step using DBCD (MIT), which applies
   `DBCache.bin`. It needs the .NET runtime, so that would be a separate OK.

**Per-patch routine:**
1. Log in once so the hotfix cache is current, then quit.
2. Open wow.export, select your `_forever_` install, and export the tables in 4b to CSV into
   `SpellDelta\data-src\<build>\` (git-ignored, never shipped). I'll walk you through it the first
   time.
3. Run `python scripts/extract_spelldata.py data-src\1.60.1.70938 1.60.1.70938`, which writes
   `SpellData.lua`.
4. Run `python scripts/check.py`. It includes data sanity tests: Smite's coefficient is near 0.71,
   Heal's near 0.86, Mental Agility touches Smite and Holy Fire, and every class has spells.

You approved the method. The download (wow.export's GitHub release, roughly 100-200 MB; it only
reads game files) happens at the start of phase 4. I'll tell you right before it.

**SpellCoda Forever, for comparison.** Its CurseForge page was unreachable to automated fetches.
Search snippets describe it as an MIT port of SpellCoda that reads talents through the modern talent
API. The original SpellCoda (MIT, `jezzi23/spellcoda`, which now has its own Forever variant) is a
full theorycrafting calculator: DPS/HPS, stat weights, upgrade scores and a spell browser.

| | SpellCoda (Forever) | SpellDelta |
|---|---|---|
| Question | "What is optimal?" | "What does this one thing change?" |
| Numbers | Its own formulas | The game's tooltip numbers; data fills the gaps |
| Items | Any item, upgrade scores | Owned or about-to-own items, no verdicts |
| Spells shown | Every spell | Only spells on your bars |
| Talents | Talent effects in its formulas | Generated modifier data, a tester on the real tree, labelled exceptions |
| UI | Many panels and settings | One roll card, one tooltip line, one window with two tabs |

### 4d. Hand-written exceptions (only for proc or conditional talents)

`Exceptions.lua` is small and clearly labelled. Priest examples:
- "On critical heal" effects (Inspiration and similar): shown as "on crit: +X", estimate.
- Talents that turn one stat into another (e.g. a percentage of Spirit as spell power): estimate
  from your current stats.
- Effects conditional on a buff, the target's health or a stack count: shown as "when active",
  estimate.

Everything else comes from the generated file. A test fails if an exception names a talent the
generated file already handles, so an exception can't quietly override real data.

---

## 5. License

**MIT, like the other Elysium addons. No data source forces anything else.**
- Our code, including the extractor script, is MIT.
- The generated file holds numeric game facts (IDs, flags, coefficients) from Blizzard's game files.
  No open license covers those facts, whatever the source. Shipping generated tables is normal:
  SocialWheel's `CatalogData.lua`, SpellCoda's data and LibTalentTree all do it. The README and the
  file header will say "derived from World of Warcraft game data, (c) Blizzard Entertainment".
  Blizzard's add-on policy (free, readable code) is met.
- The tools (wow.export, DBCD) are MIT and are not shipped. WoWDBDefs table definitions are
  CC BY-SA 4.0, but we don't bundle them: the extractor reads wow.export's CSV columns directly.
- No SpellCoda code or data is copied. If that ever changes, MIT asks only that we keep its notice
  in `THIRD_PARTY_NOTICES.md`.

---

## 6. Risks and open questions

| # | Risk / question | What we do |
|---|---|---|
| R1 | Forever may have per-rank spells (Smite Rank 1, 2...) or merged ranks. | The action bar gives the exact spell ID either way, and the data is keyed by spell ID. Check 4. |
| R2 | Number positions in spell text differ by language. | 1.0 is tested in English; other languages fall back to calculated values (~). Known limit. |
| R3 | Do percent modifiers add together or multiply? | One constant in code, settled by check 7. |
| R4 | Swapping a BoE item binds it; weapon swaps may trigger a global cooldown; a failed swap could leave you without a weapon. | Confirm prompt, out of combat only, always restore, `/delta restore`. |
| R5 | Spell bonus APIs can return secret values in restricted contexts. | Measure out of combat only; skip secret values. The roll card uses stored numbers, so it works mid-dungeon. |
| R6 | Item data not cached when a roll starts. | Wait for the item to load (Item mixin), with a "loading" state. Usually a second or less. |
| R7 | Other loot addons replace or move the roll frame. | The card anchors to Blizzard's frame. If it's hidden, the tooltip line still works. Listed as a known limit. |
| R8 | The roll card is an estimate for items not yet worn. | Labelled ~. Accuracy depends on learned coefficients, so it improves the more gear states you've worn. |
| R9 | Talent tester: points per level and gates on Forever (one point per level from 10, 5 points per row?). | The points available at your level come from the game (`GetTreeCurrencyInfo`). For planning ahead we use the Classic rule unless check 8 says otherwise. |
| R10 | Talent tester accuracy for talents that change crit, cast time or stats. | Cast and Crit columns; stat talents labelled ~; "Also changes" list for anything not calculated. |
| R11 | Hotfixes are missing from the extracted tables. | Live numbers win, mismatches are flagged, and a DBCD step is added if needed. |
| R12 | wow.export's Forever support is new and could break on a patch. | wago.tools CSVs by hand as fallback. Phases 1-3 need no data file. |
| R13 | A talent's ranks may be separate spells or one spell with scaled values. | The extractor handles both. Confirmed in the first export (Mental Agility ranks 1-5). |
| R14 | Interface number after the 70938 patch. | Check 1. |
| R15 | Generated coefficients may be zero or placeholders for some Classic-style spells. | Learned coefficients override them; the window reports mismatches. |

---

## 7. Phased build plan

Ordered so the Need/Greed card is usable as early as possible. Each phase ends with the automated
checks passing and a short in-game check by Ryan.

| Phase | Delivers | Needs the data file? |
|---|---|---|
| 1. Skeleton + reading | Repo with tooling copied from ProfessionWheel (check.py, package.py, install.ps1, test harness, CI, LICENSE); action bar + macro spell list; spell text parser; cost and bonus readers; coefficient learning; `/delta dump` prints what it read. | No |
| 2. Need/Greed | Item preview engine (estimate), loot roll card, tooltip line on owned and could-own items, healing/damage % summary. Usable in your next dungeon. | No (stat-based items and learned coefficients). "Equip:" bonuses that aren't plain stats arrive in phase 4. |
| 3. Items window | Window (Items tab), drop box, Swap and compare (exact) with all safety checks. | No |
| 4. Data + talent effects | wow.export export, `extract_spelldata.py`, `SpellData.lua`, talent tooltip line, "Equip:" bonuses for previews. | Yes |
| 5. Talent tester | Tester tab: live tree, plan editing with game rules, impact table with Cast/Crit, new/lost spells, "Also changes", saved plans. | Yes |
| 6. Exceptions, all classes, release | Priest `Exceptions.lua`; other classes generic and labelled unverified; README, VALIDATION.md, CHANGELOG; 0.1.0 release on your OK. | Yes |

Effort: roughly 6-8 working sessions. Phases 4 and 5 are the largest.

Planned files: `Elysium_SpellDelta.toc`, `Core.lua`, `Compat.lua`, `Database.lua`, `ActionSpells.lua`,
`SpellText.lua` (parser), `Measure.lua` (snapshots, learning, swap), `ItemPreview.lua`,
`RollCard.lua`, `TooltipLine.lua`, `Modifiers.lua` (talent math), `TalentTester.lua`, `Window.lua`,
`Settings.lua`, `SpellData.lua` (generated), `Exceptions.lua`, `Locales/enUS.lua`,
`scripts/extract_spelldata.py`.

---

## 8. Things to check in game (Ryan)

Use a `/run` line or the addon's `/delta dump`:
1. The addon list accepts interface 16001 on build 70938, or shows the new number.
2. `C_Spell.GetSpellDescription(585)` (Smite) matches the tooltip.
3. `C_Spell.GetSpellPowerCost(585)` shows Smite's cost, and it drops with Mental Agility.
4. Are spells ranked (one Smite, or Smite Rank 1..n in the spellbook)?
5. On the staff, is "+34 to both" a green stat line or an "Equip:" line?
6. Does a macro on your bars (`/cast Heal`) report its spell?
7. On one spell with two percentage talents, does the tooltip match "added" or "multiplied"?
8. Talent points: how many at level 33 / 40, and does each row need 5 points in that tree?
9. Is there a talent import/export string anywhere in Forever's talent window?
10. In a dungeon: does the roll card appear on a real roll, and is it readable in time? (Phase 2.)
11. Equip a weapon from your bags with the swap button out of combat: any global cooldown or
    error? (Phase 3.)

---

## 9. Test plan

Same as the other Elysium repos: `python scripts/check.py`, run from a scratch venv with `lupa`
(Lua 5.1), plus the global-write scanner (`scripts/lua51_globals.lua`).

Automated (no game needed):
- **Syntax and globals:** every TOC Lua file compiles as Lua 5.1. The only globals are
  `SpellDelta`, `SpellDeltaCharDB`, the binding label and the compartment function.
- **`test_spelltext.lua`:** number extraction from real English spell texts (ranges, single values,
  "over 15 sec", "absorbs 366 damage", thousands separators), position mapping, and the mismatch
  fallback.
- **`test_learning.lua`:** a line fit on your table reproduces Heal 0.86, Smite 0.71, Mind Blast 0.42
  and PW:S 0.10 (+/-0.03). Points too close together are rejected, and healing bonus doesn't move
  damage spells.
- **`test_itempreview.lua`:** your staff / mace + off-hand / no-weapon table, predicted from the
  learned coefficients, lands within +/-1 of your measured tooltips. Also covers two-hand vs.
  main + off-hand, rings/trinkets per slot, can't-equip, and same item.
- **`test_rollcard.lua`:** the summary (healing %, damage %, top changes, other stats) from stubbed
  roll data, and the "loading" state.
- **`test_modifiers.lua`:** family-mask matching, percent vs. flat, the stacking constant, ranks,
  cost/cast/crit changes, amount per mana.
- **`test_tester.lua`:** on a stub tree, gates, prerequisites and the points budget are enforced,
  "Reset to my build" works, the plan diff is right, and new/lost spells are found.
- **`test_actionspells.lua`:** stubbed `GetActionInfo` / `GetMacroSpell` with spells, macros, items
  and duplicates.
- **`test_scope.lua`:** owned and could-own sources are accepted; journal, vendor and AH are refused.
- **`test_extract.py`** (run by check.py): the extractor on tiny fixture CSVs gives the expected Lua,
  which loads in Lua 5.1.
- **Data sanity** (once the file exists): known coefficients, Mental Agility's targets, every class
  has spells and talents, and no exception duplicates generated data.

In game (Ryan, priest): checks 1-11. Then a scripted pass:
- Staff vs. mace + off-hand vs. no weapon in the window, compared with your measured tables.
- The roll card on a real dungeon roll.
- Mental Agility's cost change.
- Twin Disciplines on Renew and PW:S.
- A tester plan (e.g. moving 3 points into Divine Fury), checked against the real tooltips after
  your next respec.

Results go into `docs/VALIDATION.md`.

---

## 10. Approval

Ryan, please confirm or change:
1. The name (SpellDelta / Ripple / SpellLens).
2. The roll card (1a): lines shown, and that it never advises Need/Greed.
3. Which could-own sources to include (section 2): rolls, loot window, quest rewards, chat links.
4. The Talent tester (1d) as described, with "copy build string" only if Forever supports it.
5. The phase order (Need/Greed card first, talents after the data file).

Already approved: data source (your install via wow.export).
Nothing will be built until you approve the rest.
