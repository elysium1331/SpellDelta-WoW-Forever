# Talent rank audit (2026-11-21)

**Why:** Ryan's Improved Renew check (Renew 340, 357, 374 at ranks 0, 1, 2) showed that
SpellDelta got a talent's per-rank amount wrong. A talent spell's own amount is sometimes the
first rank's (Improved Renew: 5 = 5/10/15%), sometimes the top rank's (Twin Disciplines:
5 = 1..5%) and sometimes neither (Mental Strength: 15, but the game gives 2..10%). The game
keeps the real amount of every rank in a rank curve per talent effect
(`TraitDefinitionEffectPoints` -> `CurvePoint`).

**What changed (1.0.3):** `CurvePoint` was exported with wow.export from build 1.60.1.70938, and
`scripts/extract_spelldata.py` now writes every talent effect's amount at each rank into
`SpellData.rankAmounts`. Talents.lua uses those amounts; the talent text is only a fallback for
talents without a curve (single-rank talents, which don't need one). Every multi-rank talent
of every class has its curves (a test checks this). The curves match every in-game check:
Improved Renew 5/10, Improved Power Word: Shield 7 and 20 (rank 2 is 14), Twin Disciplines 1..3.

**Oddities in the game data:**
- Deadliness (rogue, 2 ranks): melee attack power 5/10%, but the ranged part's curve has 5
  steps (2/4/6/8/10), so ranks 1 and 2 give 2% and 4% ranged attack power. SpellDelta follows
  the game data; not checked in game.
- Improved Serpent Sting and Piercing Ice: one part has no curve of its own; it takes the curve
  of the talent's other part (same amount).

## Result

Talent effects with more than one rank: 281. For each, the game's amounts were compared with
what SpellDelta 1.0.2 used.

| | Parts |
|---|---|
| Same as an even split of the spell's amount (always right) | 144 |
| Different, but 1.0.2 read them right from the talent's text in game | 70 |
| **Wrong in 1.0.2** (fixed in 1.0.3) | **67** |

1.0.2's text reading could not help when the spell's amount was neither the first nor the top
rank's (Mental Strength, Mindfulness, Aggression...), or for cast time, cooldown and duration
(milliseconds in the data, seconds in the text).

Values are per rank; times in seconds. "Even split" is the spell's own amount x rank / ranks,
what SpellDelta used when the text could not be matched.

### Druid

| Talent | Changes | Game, per rank | Even split of the spell's amount | 1.0.2 |
|---|---|---|---|---|
| Brutal Impact | duration | 0.5s/1s | 0.25s/0.5s | **wrong** |
| Feral Instinct | base amount | 5/10/15 | 1/2/3 | **wrong** |
| Feral Instinct | damage/healing % | 10/20/30 | 1/2/3 | **wrong** |
| Ferocity | cost | -1/-2/-3/-4/-5 | -0.2/-0.4/-0.6/-0.8/-1 | right (read from the text) |
| Ferocity | cost | -10/-20/-30/-40/-50 | -2/-4/-6/-8/-10 | right (read from the text) |
| Genesis | damage/healing % | 2/4/6/8/10 | 0.2/0.4/0.6/0.8/1 | **wrong** |
| Genesis | over-time % | 2/4/6/8/10 | 0.2/0.4/0.6/0.8/1 | **wrong** |
| Gift of Nature | damage/healing % | 2/4/6/8/10 | 0.4/0.8/1.2/1.6/2 | right (read from the text) |
| Gift of Nature | over-time % | 2/4/6/8/10 | 0.4/0.8/1.2/1.6/2 | right (read from the text) |
| Improved Moonfire | crit chance | 5/10 | 1/2 | **wrong** |
| Improved Moonfire | damage/healing % | 5/10 | 1/2 | **wrong** |
| Improved Moonfire | over-time % | 5/10 | 1/2 | **wrong** |
| Improved Regrowth | crit chance | 10/20/30/40/50 | 2/4/6/8/10 | right (read from the text) |
| Improved Rejuvenation | over-time % | 5/10/15 | 1.66667/3.33333/5 | right (read from the text) |
| Improved Wrath | cast time | -0.1s/-0.2s/-0.3s/-0.4s/-0.5s | -0.02s/-0.04s/-0.06s/-0.08s/-0.1s | **wrong** |
| Moonfury | % school damage | 2/4/6/8/10 | 0.4/0.8/1.2/1.6/2 | right (read from the text) |
| Moonglow | cost | -8/-17/-25 | -8.33333/-16.6667/-25 | right (read from the text) |
| Natural Shapeshifter | cost | -10/-20/-30 | -3.33333/-6.66667/-10 | right (read from the text) |
| Naturalist | cast time | -0.1s/-0.2s/-0.3s/-0.4s/-0.5s | -0.02s/-0.04s/-0.06s/-0.08s/-0.1s | **wrong** |
| Nature's Majesty | crit chance | 2/4 | 0.5/1 | **wrong** |
| Reflection | regen while casting | 17/33/50 | 16.6667/33.3333/50 | right (read from the text) |
| Savage Fury | damage/healing % | 5/10 | 10/20 | **wrong** |
| Savage Fury | over-time % | 5/10 | 10/20 | **wrong** |
| Shredding Attacks | cost | -10/-20/-30 | -20/-40/-60 | **wrong** |
| Shredding Attacks | cost | -6/-12/-18 | -2/-4/-6 | right (read from the text) |
| Tranquil Spirit | cost | -2/-4/-6/-8/-10 | -0.4/-0.8/-1.2/-1.6/-2 | right (read from the text) |
| Vengeance | crit damage | 20/40/60/80/100 | 4/8/12/16/20 | right (read from the text) |

### Hunter

| Talent | Changes | Game, per rank | Even split of the spell's amount | 1.0.2 |
|---|---|---|---|---|
| Bestial Discipline | base amount | 10/20 | 50/100 | **wrong** |
| Ferocity | base amount | 2/4/6/8/10 | 3.2/6.4/9.6/12.8/16 | **wrong** |
| Improved Aspect of the Monkey | base amount | 2/4/6 | 1.33333/2.66667/4 | **wrong** |
| Improved Hunter's Mark | base amount | 10/20/30 | 1/2/3 | **wrong** |
| Improved Stings | over-time % | 6/13/20 | 6.66667/13.3333/20 | right (read from the text) |
| Lethal Attacks | crit chance | 1/2/3/4/5 | 0.2/0.4/0.6/0.8/1 | right (read from the text) |
| Savage Strikes | crit chance | 2/4 | 10/20 | **wrong** |
| Unleashed Fury | base amount | 3/6/9/12/15 | 4/8/12/16/20 | **wrong** |

### Mage

| Talent | Changes | Game, per rank | Even split of the spell's amount | 1.0.2 |
|---|---|---|---|---|
| Arcane Instability | crit chance | 1/2/3 | 0.333333/0.666667/1 | right (read from the text) |
| Arcane Instability | damage/healing % | 1/2/3 | 0.333333/0.666667/1 | right (read from the text) |
| Arcane Instability | over-time % | 1/2/3 | 0.333333/0.666667/1 | right (read from the text) |
| Arcane Meditation | regen while casting | 17/33/50 | 16.6667/33.3333/50 | right (read from the text) |
| Critical Mass | crit chance | 2/4/6 | 0.666667/1.33333/2 | right (read from the text) |
| Frost Warding | base amount | 10/20 | 0/0 | **wrong** |
| Frost Warding | base amount | 10/20 | 0/0 | **wrong** |
| Frost Warding | base amount | 15/30 | 7.5/15 | right (read from the text) |
| Improved Cone of Cold | damage/healing % | 12/23/35 | 5/10/15 | **wrong** |
| Improved Frostbolt | cast time | -0.1s/-0.2s/-0.3s/-0.4s/-0.5s | -0.02s/-0.04s/-0.06s/-0.08s/-0.1s | **wrong** |
| Incineration | crit chance | 2/4/6/8/10 | 1.2/2.4/3.6/4.8/6 | **wrong** |
| Permafrost | base amount | -3/-7/-10 | -3.33333/-6.66667/-10 | **wrong** |
| Piercing Ice | damage/healing % | 2/4/6 | 0.666667/1.33333/2 | right (read from the text) |
| Piercing Ice | over-time % | 2/4/6 | 0.666667/1.33333/2 | right (read from the text) |

### Paladin

| Talent | Changes | Game, per rank | Even split of the spell's amount | 1.0.2 |
|---|---|---|---|---|
| Conviction | crit chance | 2/4/6 | 1.66667/3.33333/5 | **wrong** |
| Deflection | parry | 1/2/3/4/5 | 0.2/0.4/0.6/0.8/1 | right (read from the text) |
| Divine Intellect | % of a stat | 2/4/6/8/10 | 0.4/0.8/1.2/1.6/2 | right (read from the text) |
| Divine Strength | % of a stat | 2/4/6/8/10 | 0.4/0.8/1.2/1.6/2 | right (read from the text) |
| Guardian's Favor | cooldown | -60s/-120s | -30s/-60s | **wrong** |
| Guardian's Favor | duration | 3s/6s | 1.5s/3s | **wrong** |
| Healing Light | damage/healing % | 4/8/12 | 1.33333/2.66667/4 | right (read from the text) |
| Improved Concentration Aura | base amount | -15/-30 | 15/30 | **wrong** |
| Improved Concentration Aura | base amount | 8/15 | 7.5/15 | right (read from the text) |
| Improved Hammer of Justice | cooldown | -5s/-10s/-15s | -1.66667s/-3.33333s/-5s | **wrong** |
| Improved Judgement | cooldown | -1s/-2s | -0.5s/-1s | **wrong** |
| Improved Righteous Fury | base amount | -3/-6/-9 | -2/-4/-6 | **wrong** |
| Improved Seals | damage/healing % | 3/6/9/12/15 | 0/0/0/0/0 | **wrong** |
| Precision | hit | 1/2/3 | 0.333333/0.666667/1 | right (read from the text) |
| Precision | spell hit | 1/2/3 | 0.333333/0.666667/1 | right (read from the text) |
| Purifying Power | cooldown | -17/-33 | -25/-50 | **wrong** |
| Toughness | armor from items | 2/4/6/8/10 | 0.4/0.8/1.2/1.6/2 | right (read from the text) |
| Turn Evil | cast time | -0.5s/-1s | -0.75s/-1.5s | **wrong** |
| Turn Evil | cooldown | -5s/-10s | -0.75s/-1.5s | **wrong** |

### Priest

| Talent | Changes | Game, per rank | Even split of the spell's amount | 1.0.2 |
|---|---|---|---|---|
| Holy Specialization | crit chance | 1/2/3/4/5 | 0.2/0.4/0.6/0.8/1 | right (read from the text) |
| Improved Power Word: Shield | base amount | 7/14/20 | 6.66667/13.3333/20 | right (read from the text) |
| Improved Renew | over-time % | 5/10/15 | 1.66667/3.33333/5 | right (read from the text) |
| Meditation | regen while casting | 17/33/50 | 16.6667/33.3333/50 | right (read from the text) |
| Mental Agility | cost | -3/-7/-10 | -3.33333/-6.66667/-10 | right (read from the text) |
| Mental Strength | % of a stat | 2/4/6/8/10 | 3/6/9/12/15 | **wrong** |
| Searing Light | % school damage | 2/5 | 5/10 | **wrong** |
| Spiritual Healing | damage/healing % | 3/7/10 | 0.666667/1.33333/2 | **wrong** |
| Spiritual Healing | over-time % | 3/7/10 | 0.666667/1.33333/2 | **wrong** |

### Rogue

| Talent | Changes | Game, per rank | Even split of the spell's amount | 1.0.2 |
|---|---|---|---|---|
| Aggression | damage/healing % | 5/10/15 | 0.666667/1.33333/2 | **wrong** |
| Composure | base amount | -5/-10 | 0/0 | **wrong** |
| Coup de Grace | damage/healing % | 7/13/20 | 6.66667/13.3333/20 | right (read from the text) |
| Coup de Grace | damage/healing % | 7/13/20 | 6.66667/13.3333/20 | right (read from the text) |
| Deadliness | ranged attack power % | 2/4 | 5/10 | **wrong** |
| Deflection | parry | 2/4/6 | 0.333333/0.666667/1 | **wrong** |
| Efficient Strikes | cost | -3/-5 | -2.5/-5 | right (read from the text) |
| Flash of Steel | cooldown | -0.4s/-0.8s/-1.2s/-1.6s/-2s | -0.5s/-1s/-1.5s/-2s/-2.5s | **wrong** |
| Flawless Execution | cost | -10/-10 | -7.5/-15 | **wrong** |
| Improved Slice and Dice | duration | 15/30/45 | 5/10/15 | right (read from the text) |
| Lethality | crit damage | 10/20 | 3/6 | **wrong** |
| Opportunity | damage/healing % | 4/8/12/16/20 | 2/4/6/8/10 | **wrong** |
| Opportunity | over-time % | 4/8/12/16/20 | 2/4/6/8/10 | **wrong** |
| Precision | hit | 1/2/3 | 0.333333/0.666667/1 | right (read from the text) |
| Precision | spell hit | 1/2/3 | 0.333333/0.666667/1 | right (read from the text) |

### Shaman

| Talent | Changes | Game, per rank | Even split of the spell's amount | 1.0.2 |
|---|---|---|---|---|
| Anticipation | dodge | 2/4/6 | 0.333333/0.666667/1 | **wrong** |
| Concussion | damage/healing % | 1/2/3/4/5 | 0.2/0.4/0.6/0.8/1 | right (read from the text) |
| Convection | cost | -2/-4/-6/-8/-10 | -0.4/-0.8/-1.2/-1.6/-2 | right (read from the text) |
| Earth's Grasp | base amount | 25/50 | 12.5/25 | right (read from the text) |
| Elemental Alacrity | cast time | -0.17s/-0.33s/-0.5s | -0.0666667s/-0.133333s/-0.2s | **wrong** |
| Elemental Weapons | base amount | 13/27/40 | 4.33333/8.66667/13 | **wrong** |
| Elemental Weapons | base amount | 7/13/20 | 2.33333/4.66667/7 | right (read from the text) |
| Elemental Weapons | damage/healing % | 5/10/15 | 1.66667/3.33333/5 | **wrong** |
| Guardian Totems | base amount | 10/20 | 5/10 | right (read from the text) |
| Guardian Totems | cooldown | -1s/-2s | -0.5s/-1s | right (read from the text) |
| Healing Way | damage/healing % | 8/17/25 | 11/22/33 | **wrong** |
| Improved Ghost Wolf | cast time | -1s/-3s | -1.5s/-3s | **wrong** |
| Improved Healing Wave | cast time | -0.1s/-0.2s/-0.3s/-0.4s/-0.5s | -0.02s/-0.04s/-0.06s/-0.08s/-0.1s | **wrong** |
| Improved Lightning Shield | damage/healing % | 5/10/15 | 1.66667/3.33333/5 | right (read from the text) |
| Improved Reincarnation | base amount | 10/20 | 5/10 | **wrong** |
| Improved Reincarnation | cooldown | -600s/-1200s | -300s/-600s | **wrong** |
| Mindfulness | regen while casting | 17/33/50 | 1.66667/3.33333/5 | **wrong** |
| Restorative Totems | base amount | 5/10/15/20/25 | 1/2/3/4/5 | right (read from the text) |
| Restorative Totems | over-time % | 10/20/30/40/50 | 1/2/3/4/5 | **wrong** |
| Reverberation | cooldown | -0.2s/-0.4s/-0.6s/-0.8s/-1s | -0.04s/-0.08s/-0.12s/-0.16s/-0.2s | **wrong** |
| Thundering Strikes | crit chance | 1/2/3/4/5 | 0.2/0.4/0.6/0.8/1 | right (read from the text) |
| Tidal Mastery | crit chance | 1/2/3/4/5 | 0.2/0.4/0.6/0.8/1 | right (read from the text) |
| Totemic Focus | cost | -5/-10/-15/-20/-25 | -1/-2/-3/-4/-5 | right (read from the text) |
| Toughness | % of a stat | 2/4/6/8/10 | 0.4/0.8/1.2/1.6/2 | right (read from the text) |
| Trial by Fire | cooldown | -2s/-4s | -1s/-2s | **wrong** |

### Warlock

| Talent | Changes | Game, per rank | Even split of the spell's amount | 1.0.2 |
|---|---|---|---|---|
| Agonizing Flames | crit chance | 3/7/10 | 3.33333/6.66667/10 | right (read from the text) |
| Agonizing Flames | damage/healing % | 3/7/10 | 3.33333/6.66667/10 | right (read from the text) |
| Agonizing Flames | over-time % | 3/7/10 | 3.33333/6.66667/10 | right (read from the text) |
| Cataclysm | cost | -3/-6/-10 | -3.33333/-6.66667/-10 | right (read from the text) |
| Decimation | damage/healing % | 3/6 | 0/0 | **wrong** |
| Fire and Brimstone | crit chance | 8/17/25 | 8.33333/16.6667/25 | right (read from the text) |
| Improved Bane of Agony | over-time % | 5/10 | 1/2 | **wrong** |
| Improved Drains | base amount | 7/13/20 | 6.66667/13.3333/20 | right (read from the text) |
| Improved Drains | over-time % | 7/13/20 | 6.66667/13.3333/20 | right (read from the text) |
| Pandemic | crit damage | 33/67/100 | 33.3333/66.6667/100 | right (read from the text) |
| Shadow Mastery | damage/healing % | 2/4/6/8/10 | 0.4/0.8/1.2/1.6/2 | right (read from the text) |
| Shadow Mastery | over-time % | 2/4/6/8/10 | 0.4/0.8/1.2/1.6/2 | right (read from the text) |

### Warrior

| Talent | Changes | Game, per rank | Even split of the spell's amount | 1.0.2 |
|---|---|---|---|---|
| Deflection | parry | 1/2/3/4/5 | 0.2/0.4/0.6/0.8/1 | right (read from the text) |
| Impale | crit damage | 10/20 | 5/10 | right (read from the text) |
| Improved Charge | base amount | 30/60 | 15/30 | right (read from the text) |
| Improved Disarm | cooldown | -7s/-13s/-20s | -6.66667s/-13.3333s/-20s | **wrong** |
| Improved Execute | cost | -30/-50 | -25/-50 | right (read from the text) |
| Improved Heroic Strike | cost | -10/-20/-30 | -3.33333/-6.66667/-10 | right (read from the text) |
| Improved Overpower | crit chance | 25/50 | 12.5/25 | right (read from the text) |
| Improved Rend | over-time % | 12/23/35 | 5/10/15 | **wrong** |
