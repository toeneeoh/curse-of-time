# Item progression audit

Snapshot: 2026-10-01. Numeric item values come from the latest available
in-engine export (`balance-items-player-1.pld`, generated 2026-09-21). Drop
pools, recipes, boss levels, inventory restrictions, and runtime behavior were
cross-checked against the current source tree. Potion bases and faction
consumables are outside the equipment comparisons below.

## Executive summary

The main equipment curve is structurally sound. Pre-Chaos equipment advances
through several short bands, Chaos world equipment advances every 20 levels
from 200 through 360, and the corresponding crafted sets sit 10 levels above
their component bands from 210 through 370. All fifteen five-piece set
families are complete.

The high-confidence defects found in the first pass are now corrected:

1. Nightmare Set Staff now has 24,000 Intelligence and 2,700 in both secondary
   attributes.
2. Hell Set Staff now has 32,000 Intelligence and 3,600 in both secondary
   attributes.
3. Existence Set Bow now has 140,000 damage.
4. Orsted now has an 85% level-250 pool of five class weapons.
5. Arkaden's three repeated Death Knight outcomes were replaced by three
   unique level-140 rewards; Chronos Stone remains the fourth outcome.
6. Pure Existence is now level 340, matching both of its rewards.
7. Exact duplicate boss-pool items and tier-23-or-higher equipment can no
   longer occupy equipped slots together. Ordinary pre-Chaos duplicates remain
   legal.

## Progression backbone

### Crafted sets

| Band | Set | Required level | Pieces |
|---:|---|---:|---:|
| Pre-Chaos | Ursine | 20 | 5 |
| Pre-Chaos | Ogre | 30 | 5 |
| Pre-Chaos | Unbroken | 50 | 5 |
| Pre-Chaos | Magnataur | 70 | 5 |
| Pre-Chaos | Devourer | 110 | 5 |
| Chaos | Demon | 190 | 5 |
| Chaos | Horror | 210 | 5 |
| Chaos | Despair | 230 | 5 |
| Chaos | Abyssal | 250 | 5 |
| Chaos | Void | 270 | 5 |
| Chaos | Nightmare | 290 | 5 |
| Chaos | Hell | 310 | 5 |
| Chaos | Existence | 330 | 5 |
| Chaos | Astral | 350 | 5 |
| Chaos | Dimensional | 370 | 5 |

The Chaos cadence is especially clean: ordinary component gear appears at
levels 200, 220, 240, 260, 280, 300, 320, 340, and 360, followed by its set 10
levels later. Demon equipment at 175 leading into the level-190 set is the only
slightly wider opening step.

The large set gap from Devourer 110 to Demon 190 is filled by boss gear,
quest rewards, level-175 Demonic equipment, and several one-piece class sets.
It is not automatically broken, but it makes the quality of the 120-175 boss
and quest rewards more important than the otherwise regular Chaos curve.

Set crafting prices also rise consistently within each family: Demon costs
250,000 gold; Horror 500,000; Despair 500,000 gold plus 1 Platinum and 1
Crystal; then Abyssal through Dimensional costs 4/2, 9/3, 16/6, 25/10,
40/15, 75/30, and 135/55 Platinum/Crystals. Every piece in a family has the
same currency cost. No missing or accidentally cheap Chaos set recipe was
found.

### Set-template anomalies

All other Chaos set archetypes follow recognizable templates:

- Heavy emphasizes Strength, armor, and moderate weapon damage.
- Sword emphasizes Strength and high weapon damage.
- Dagger emphasizes Agility.
- Bow emphasizes Agility and the second-highest weapon damage.
- Staff emphasizes Intelligence, regeneration, and Spellboost.

The three numeric anomalies originally identified here have been corrected in
object data. The set sequence should be regenerated in the next balance export
to verify its final post-upgrade curve.

## Boss-item progression

### Pool coverage

| Boss | Boss level | Base equipment chance | Pool | Immediate usability |
|---|---:|---:|---:|---|
| Minotaur | 75 | 70% | 5 | Level 75 |
| Siren of the Tides | 75 | 70% | 2 | Level 75 |
| Forgotten Mystic | 100 | 70% | 3 | Level 100 |
| Hellfire Magi | 100 | 70% | 4 | Level 100 |
| Last Dwarf | 100 | 70% | 3 | Level 100 |
| Dragoon | 100 | 70% | 4 | Level 100 |
| Death Knight | 120 | 80% | 4 | Level 120 |
| Vengeful Paladin | 140 | 80% | 4 | Level 140 |
| Arkaden | 140 | 80% | 4 | Three unique level-140 items and Chronos Stone |
| Goddesses | 180 | 100% each | 4 separate pools | Level 130 aura items |
| Demon Prince | 190 | 100% | 1 | Level-190 crafting component |
| Absolute Horror | 230 | 85% | 3 | Materials for level-230 Absolute gear |
| Orsted | 250 | 85% | 5 | Level-250 class weapons |
| Slaughter Queen | 270 | 85% | 5 | Level 270 |
| Essence of Darkness | 300 | 70% | 4 | Three at 300; one at 308 |
| Satan | 310 | 65% | 2 | Level 310 |
| Thanatos | 320 | 65% | 2 | Level 320 |
| Pure Existence | 340 | 60% | 2 | Level 340 |
| Legion | 340 | 60% | 10 | Level 340 |
| Xallarath | 360 | 30% | 3 | Level 360 |
| Azazoth | 380 | 60% | 10 | Level 380 |

The displayed chance is the normal-difficulty chance for one equipment roll,
before first-kill and Drop Rate modifiers. Hard difficulty performs additional
rolls rather than replacing this percentage.

### Remaining boss oddities

- **Dark Regeneration requires level 308 while its boss is level 300.** This is
  a small, unusual delay rather than a progression blocker.

### Findings that need a design decision

- Xallarath's 30% total equipment chance is half of Legion, Pure Existence,
  and Azazoth's 60%, although its three jewels are unusually concentrated and
  strong. The resulting per-item normal chance is roughly 10%, compared with
  roughly 6% for an individual Legion or Azazoth item. The lower total rate is
  therefore not clearly wrong.
- The boss sequence uses two reward models: direct finished equipment and
  guaranteed/likely crafting materials. The multiboard communicates the item
  odds, but it does not explain the finished items produced by material pools.
  Absolute Horror can consequently look much less rewarding than it is.

## Equipment-limit and optimizer mismatch

The runtime now rejects exact duplicate rawcodes when an item is present in an
authored boss pool or has tier 23 or higher. This captures pre-Chaos boss drops,
direct Chaos boss drops, and boss-crafted endgame gear without preventing
players from equipping duplicate ordinary pre-Chaos equipment. Existing
`ITEM_LIMIT` groups continue to enforce broader mutually exclusive families
such as crafted sets.

The offline analyzer's exact-duplicate rule is therefore aligned for
boss-grade equipment but remains stricter for ordinary items. Future analyzer
runs should adopt the same acquisition/tier predicate if ordinary duplicate
builds need to be modeled exactly.

## Acquisition metadata limitations

The runtime balance export marks drop pools, shops, and runtime definitions,
but not direct quest-choice rewards. Spider armor and Polar quest equipment
therefore appear unavailable in a naive export analysis even though they are
awarded by the headhunter quests. Future exports should add a `quest_reward`
column before using acquisition flags to identify orphaned items.

Unbroken Bow (`I06X`, level 30) remains unavailable by design: a similar
pre-Chaos Hell component already fills its role, while Unbroken enemies are
primarily an armor source. Sword of Floyd is also unavailable, but is
explicitly spawned only by developer commands and appears intentionally
non-production.

## Recommended correction order

1. Regenerate the item export after the object-data and pool corrections.
2. Add quest rewards to the balance export.
3. Decide whether Dark Regeneration's level-308 requirement is intentional.
4. Review Orsted's new weapon values after live combat and upgrade testing.

After those changes, rerun `-balance items` and the level
50/100/200/300/400/500 build matrix. That regenerated catalog is necessary for
a trustworthy second-pass numerical comparison after object-data corrections.
