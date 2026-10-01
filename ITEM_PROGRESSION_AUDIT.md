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

Four progression problems are high confidence:

1. **Nightmare Set Staff (`I0CF`, level 290) is missing its primary stat.** It
   has 2,700 Strength, 0 Agility, and only 2,700 Intelligence. The preceding
   Void Set Staff has 18,000 Intelligence and the following Hell tier should
   continue upward.
2. **Hell Set Staff (`I0DJ`, level 310) repeats the same defect.** It has 3,600
   Strength, 0 Agility, and only 3,600 Intelligence. Existence Set Staff then
   jumps to 45,000 Intelligence at level 330.
3. **Existence Set Bow (`I0DL`, level 330) has 14,000 damage.** Hell Set Bow has
   100,000, while Astral Set Bow has 196,000. The surrounding curve strongly
   indicates that this should be approximately 140,000.
4. **Orsted (`N00F`, level 250) has no equipment drop table.** The boss exists
   and has combat content, but `Rates[N00F]` and `setup_rates(N00F, ...)` are
   absent. It can only award independent generic boss rewards such as tickets
   and potion rolls.

The first three should be corrected in item object data. Orsted needs a design
decision about whether it should drop a unique family, crafting material, or a
curated level-250 pool.

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

Nightmare and Hell Staffs are the only two consecutive staff entries that lose
both the large Intelligence allocation and the normal secondary Agility. The
defect is severe enough that upgrading from Void Set Staff at level 270 is a
large downgrade until Existence Set Staff at 330.

Existence Set Bow is the only weapon in the high-level set sequence whose
damage regresses by nearly an order of magnitude. Its name also contains a
trailing space in object data; that part is cosmetic but worth cleaning when
the numeric field is corrected.

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
| Arkaden | 140 | 80% | 4 | One level-140 item; three level-120 repeats |
| Goddesses | 180 | 100% each | 4 separate pools | Level 130 aura items |
| Demon Prince | 190 | 100% | 1 | Level-190 crafting component |
| Absolute Horror | 230 | 85% | 3 | Materials for level-230 Absolute gear |
| **Orsted** | **250** | **0%** | **0** | **No equipment reward** |
| Slaughter Queen | 270 | 85% | 5 | Level 270 |
| Essence of Darkness | 300 | 70% | 4 | Three at 300; one at 308 |
| Satan | 310 | 65% | 2 | Level 310 |
| Thanatos | 320 | 65% | 2 | Level 320 |
| Pure Existence | 320 | 60% | 2 | Both require level 340 |
| Legion | 340 | 60% | 10 | Level 340 |
| Xallarath | 360 | 30% | 3 | Level 360 |
| Azazoth | 380 | 60% | 10 | Level 380 |

The displayed chance is the normal-difficulty chance for one equipment roll,
before first-kill and Drop Rate modifiers. Hard difficulty performs additional
rolls rather than replacing this percentage.

### High-confidence boss oddities

- **Orsted has no pool.** This is the only ordinary progression boss in the
  sequence with neither unique equipment nor a material table.
- **Arkaden recycles most of Death Knight's pool.** Godslayer's Cloak,
  Savior's Armor, and Savior's Sword are shared; Chronos Stone is the only new
  outcome. Thus 75% of successful equipment rolls can repeat the previous
  boss's rewards.
- **Pure Existence cannot provide an immediately equippable reward at its
  authored level.** The level-320 boss drops Ring of Existence and Existence
  Soul, both requiring 340. The inventory system permits picking up items up to
  20 levels ahead, so the drops are not lost, but they are deferred rewards and
  directly overlap Legion's level band.
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
- Pure Existence's level-340 requirements may intentionally make it a source
  of future gear. If not, either the boss should be level 340 or its two items
  should be level 320.

## Equipment-limit and optimizer mismatch

The live inventory restriction only checks items whose `ITEM_LIMIT` is above
zero. Consequently, two copies of the same limit-zero item may be equipped at
once. This includes most ordinary Chaos equipment and several strong boss
accessories, notably Satan's Ace, Satan's Heart, and Ring of Existence.

The offline build analyzer now rejects duplicate rawcodes regardless of
`ITEM_LIMIT`. Its generated builds therefore model a healthier one-copy rule
that the game does not actually enforce. Older generated results even exposed
six Ring of Existence copies as the leading generic spell-stat package.

This requires an explicit policy:

- If duplicate equipment is intended, the analyzer must allow it and balance
  should account for six-copy boss-item builds.
- If duplicate equipment is not intended, exact duplicate rawcodes should be
  rejected for equipped slots even when their limit group is zero. Shared
  limit groups can continue handling mutually exclusive families such as sets.

Changing this silently would invalidate existing builds, so this audit does
not choose one policy.

## Acquisition metadata limitations

The runtime balance export marks drop pools, shops, and runtime definitions,
but not direct quest-choice rewards. Spider armor and Polar quest equipment
therefore appear unavailable in a naive export analysis even though they are
awarded by the headhunter quests. Future exports should add a `quest_reward`
column before using acquisition flags to identify orphaned items.

One item remains suspicious after the quest cross-check: **Unbroken Bow
(`I06X`, level 30)** exists but is not referenced by a drop pool, shop, recipe,
quest reward, or runtime definition. Sword of Floyd is also unavailable, but
is explicitly spawned only by developer commands and appears intentionally
non-production.

## Recommended correction order

1. Correct Nightmare Set Staff, Hell Set Staff, and Existence Set Bow in object
   data, then regenerate the item export.
2. Decide and implement Orsted's reward identity.
3. Decide whether exact duplicate equipped items are legal; make the runtime
   and analyzer follow the same rule.
4. Decide whether Pure Existence is meant to award future level-340 gear.
5. Replace Arkaden's recycled outcomes or explicitly present Arkaden as a
   second-chance source for Death Knight gear.
6. Add quest rewards to the balance export and either place or retire
   Unbroken Bow.

After those decisions, rerun `-balance items` and the level
50/100/200/300/400/500 build matrix. That regenerated catalog is necessary for
a trustworthy second-pass numerical comparison after object-data corrections.
