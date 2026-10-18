# Shared hero stat allocation: initial balance proposal

Historical planning analysis. The implemented rules and verification notes are in [STAT_ALLOCATION_IMPLEMENTATION.md](STAT_ALLOCATION_IMPLEMENTATION.md).

Analysis date: 2026-10-14. Recommendation only; gameplay and map objects have not been changed.

## Recommendation

Replace automatic attribute growth with **8 allocatable points per level gained**, shared by all heroes. One point adds one Strength, Agility, or Intelligence. Keep existing level-one attributes initially. This revises the original six-point recommendation after accounting for the historical tome reduction and current leveling economy; see the economy comparison below.

The level-earned budget is `8 * (level - 1)`. The larger free budget deliberately compensates for some lost early tome power while allowing a player to select the distribution. Continue this same linear rule through level 500: equipment and purchased points can naturally reduce its relative importance later, without introducing a cutoff.

This is an initial playtest value, not a claim that equal attribute budgets produce equal hero power. Ability coefficients, gear, primary-attribute attack damage, and attribute utility still differ.

## Sources and native-data verification

- `src/config/hero_definitions.lua`: all 19 selectable heroes' starting attributes and displayed growth.
- `src/config/rawcodes.lua`: hero identifiers used to match native objects.
- `B:/cothub/builder/CoTN-RPG-1.36.w3x/war3map.w3u` and `war3mapSkin.w3u`: parsed read-only, merging skin modifications after normal modifications.
- `src/gameplay/players/leveling.lua` and `src/gameplay/world/unit_table.lua`: leveling synchronizes the engine's native attributes; the Lua growth definitions do not award level stats.
- `src/gameplay/economy/tomes.lua` and `src/gameplay/persistence/profile.lua`: current purchase formula and cap.
- Existing `balance-items-player-1.pld` gameplay export: illustrative item values, not a new runtime measurement or a complete build simulation.

Starting attributes and all three gains match native overrides for 18 heroes, ignoring floating-point representation differences. Oblivion Guard's native Strength gain is **3.2**, versus **3.5** in the Lua selection data. Its Intelligence gain has no map override; its inherited Mountain King value is 1.5 in the available legacy `Units/UnitBalance.slk`. That inherited default has not been independently captured from the currently installed game patch.

## Current growth by hero

Values are attribute units per level. Oblivion Guard uses the native Strength value and the inherited Intelligence value described above.

| Hero | Strength | Agility | Intelligence | Total |
|---|---:|---:|---:|---:|
| Oblivion Guard | 3.2 | 0.5 | 1.5 | 5.2 |
| Bloodzerker | 3.5 | 1.4 | 0.5 | 5.4 |
| Royal Guardian | 3.7 | 0.9 | 0.5 | 5.1 |
| Warrior | 3.5 | 1.4 | 0.5 | 5.4 |
| Vampire Lord | 2.0 | 2.0 | 1.0 | 5.0 |
| Savior | 2.4 | 1.0 | 0.4 | 3.8 |
| Dark Savior | 1.5 | 0.7 | 2.5 | 4.7 |
| Crusader | 1.25 | 0.4 | 2.1 | 3.75 |
| Arcanist | 0.25 | 0.5 | 4.0 | 4.75 |
| Dark Summoner | 1.4 | 0.7 | 6.5 | 8.6 |
| Bard | 0.9 | 0.5 | 2.2 | 3.6 |
| Hydromancer | 0.6 | 0.6 | 4.0 | 5.2 |
| High Priestess | 1.7 | 0.6 | 3.8 | 6.1 |
| Elementalist | 0.4 | 0.0 | 8.4 | 8.8 |
| Assassin | 0.6 | 3.6 | 1.5 | 5.7 |
| Thunderblade | 1.0 | 3.4 | 1.4 | 5.8 |
| Master Rogue | 0.8 | 3.5 | 0.1 | 4.4 |
| Elite Marksman | 0.6 | 3.0 | 0.5 | 4.1 |
| Phoenix Ranger | 0.6 | 2.5 | 0.5 | 3.6 |

The mean total is approximately **5.21**, the median **5.1**, and the range **3.6-8.8**. Elementalist receives about 2.44 times Bard's or Phoenix Ranger's total growth. The mean without Elementalist and Dark Summoner is approximately **4.8**.

Six points increases the mean total budget by about **15%**. Five points is close to the existing median but offers less room to support a primary attribute and both secondary attributes. Eight points increases the mean budget by about **54%**, before accounting for the advantage of freely concentrating points.

## Progression under eight points

These totals exclude starting attributes, gear, and purchased points. Level one has no level-earned points.

| Level | Earned points | Example primary gain at 6 per level | Each secondary gain at 1 per level |
|---|---:|---:|---:|
| 10 | 72 | 54 | 9 |
| 25 | 192 | 144 | 24 |
| 50 | 392 | 294 | 49 |
| 100 | 792 | 594 | 99 |
| 180 | 1,432 | 1,074 | 179 |
| 400 | 3,192 | 2,394 | 399 |
| 500 | 3,992 | 2,994 | 499 |

Example distributions, not enforced restrictions:

- 6 primary / 1 Strength or other secondary / 1 remaining secondary: offensive growth with secondary support.
- 4 Strength / 4 Agility: Vampire hybrid.
- 5 primary / 2 defensive secondary / 1 remaining secondary: more balanced.
- All 8 in one attribute: maximum specialization, with secondary needs supplied by starting stats, purchases, or equipment.

For most conventional heroes, 6 primary points is substantially above their current primary gain; this is an intentional early-power increase, not a neutral redistribution. Allocation also lets low-Strength casters and archers buy durability: `UnitTable` grants 25 health per Strength, so assigning one Strength each level adds 1,225 health by level 50. Intelligence grants 20 mana per point and contributes 0.05 base mana regeneration per point before other modifiers. The map grants 1 percentage point of attack speed and 0.03 armor per Agility. Equal point counts therefore do not imply interchangeable effects.

The existing item export gives useful scale references: level-25 weapons include Ogre Club with 60 Strength, Tauren Dagger with 95 Agility, and Ogre Staff with 105 Intelligence; level-50 examples include Hydra Polearm with 170 Strength, Hydra Dagger with 260 Agility, and Hydra Talisman with 290 Intelligence. A 6-point primary allocation produces 144 primary stats by level 25 and 294 by level 50, so level growth would be substantial alongside an early weapon. Several equipped items and bought points reduce its share of total power.

At level 400 the entire earned budget is 3,192. Current level-250 equipment definitions include a dagger with 10,300 Agility and a staff with 11,900 Intelligence, before upgrades. This supports continuing a linear budget into late game, although its precise share depends on the build.

## Heroes requiring particular attention

**Elementalist:** Eight points nearly preserve its current 8.4 Intelligence per level if fully specialized. At level 50, its modeled natural Intelligence is 451.6 today, versus 432 with all eight points assigned to Intelligence, or 334 with a 6/1/1 split. That is approximately 4% or 26% less natural Intelligence respectively, before gear and purchases. A larger total budget does not guarantee a buff to every allocation.

**Dark Summoner:** Its current Intelligence gain is 6.5 and total gain 8.6. At level 50, a 6/1/1 allocation produces 313 modeled Intelligence versus 337.5 currently; an all-eight Intelligence allocation produces 411 while sacrificing natural secondary growth. Summon scaling and early survivability warrant checking together.

**Low-growth heroes:** Bard and Phoenix Ranger gain 122% more total level-earned stats under an eight-point budget; Savior gains 111% more. Concentration can increase their relevant attribute even more than those total-budget percentages suggest.

These comparisons model fractional gains before native rounding. They indicate where to playtest; they do not substitute for measuring actual spell damage, survival, or clear speed. If high-growth casters become weak, adjust the affected early abilities or starting stats based on those measurements rather than immediately raising every hero's point budget.

## Purchase and implementation implications

The current tome service prices gains using the sum of base Strength, Agility, and Intelligence. That includes initial and level-earned stats. Its cap is also applied to that sum. A shared allocation system should track **level-earned points, purchased points, and allocations** separately, keeping equipment outside those counters.

Purchase prices and any purchase cap should depend on purchased points, including purchased points that remain unallocated. Otherwise delaying allocation or redistributing points could change the price or bypass a limit. Moving to a purchase-only cap requires a deliberate recalibration; the existing total-base-stat cap should not be copied unchanged and called equivalent.

When implementing replacement growth, remove or compensate native growth, award the full level delta when multiple levels are gained, and reconcile earned budgets on load. Existing characters' purchased stats must be preserved or migrated explicitly. The initial proposal does not specify a gold price, purchased-point cap, or save migration.

## Focused validation

Compare the same gear and purchase budget at levels 10, 25, 50, and 100. Include a conventional Strength hero, Vampire, Phoenix Ranger or Bard, Elementalist, and Dark Summoner. Measure clear time, deaths, and resource sustain under plausible allocations. This should establish whether eight points provides adequate early growth and whether the high-growth caster exceptions need targeted adjustments.

## Tome reduction and current gold economy

The previous recommendation compared natural growth alone. That understated the amount of early power removed by the tome formula change.

The recoverable historical function is `StatTome` in `05f327f^:cotlua/src/helper.lua`; the old shop callers remain visible in `515cd7f^:cotlua/src/items.lua`. The caller's `10` was a formula input, not a fixed award. For an ordinary 10,000-gold tome:

```text
Old scaledTotal = max(actual base STR+AGI+INT, level > 25 ? 250 : 50)
Old gain = floor(172 / scaledTotal^0.35)

Current per-iteration gain = floor(100 / projectedTotal^0.25)
                            * ln(cap / projectedTotal + 0.75) / ln(2.71828) / 3
Current awarded gain = floor(sum of iteration gains), limited to cap room
```

Old platinum tomes used a 1,000 input at 1 platinum, unlocked at level 100. Knowledge cost twice as much and awarded the calculated gain to each attribute. The old function checked the cap before buying but did not clamp the final award, permitting overshoot. The comparison data includes both that historical behavior and a cap-controlled variant; the latter avoids treating the old overshoot as a balance target.

With natural stats only and no earlier tome purchases, the roster-average 10,000-gold quote is approximately:

| Level | Historical single-stat gain | Current single-stat gain |
|---|---:|---:|
| 25 | 29.3 | 7.7 |
| 50 | 23.1 | 7.9 |
| 100 | 18.7 | 9.4 |
| 180 | 15.2 | 12.6 |

These are averages of per-hero quotes, not quotes evaluated at the mean hero. Repeated purchases lower subsequent gains.

### Income assumptions

The comparison holds the **current** XP, gold, and quest reward system constant and changes only tome purchasing. It is not a reconstruction of the full historical game's income curve.

- Solo, equal-level normal enemies; baseline XP and Gold Find; no prestige, account perks, or equipment bonuses.
- Every modeled kill contributes to a repeatable kill quest, with turn-ins amortized across those kills. Real quests have discrete goals, travel, level requirements, and monster levels, so this is a controlled scenario rather than a measured player route.
- Normal kills award `1.2 * EXPERIENCE_TABLE[level]` XP and `GOLD_TABLE[level]` gold. Kill quests add `0.5 * EXPERIENCE_TABLE[level]` XP and `0.5 * GOLD_TABLE[level]` gold per credited kill for an eligible solo recipient.
- Consequently, expected gold per level band is `10,000 * 1.5 * GOLD_TABLE[level] / (1.7 * EXPERIENCE_TABLE[level])`.
- Quest-free farming uses the ratio `1 / 1.2` instead of `1.5 / 1.7`: questing raises gold per level by only about **5.9%**, despite its 50% gold bonus per credited kill, because it also reduces the required kills.
- Purchase allowance is 25%, 50%, or 100% of gross earned gold. Unspent allowance carries forward. The remainder represents other spending or savings; it is not counted as tome spending.
- The player visits the shop after each level gained and buys the largest affordable supported bundle, with old platinum access beginning at level 100. No unearned starting wealth is included.
- Gold uses the mean random multiplier of 1. Sub-gold rounding, native fractional-stat rounding, and one-off head-quest XP are omitted. Boss gold, loot sales, mining, Struggle, Colosseum, and party leveling are excluded. These can materially change income; Colosseum supplies gold without XP, so level alone cannot bound total available money.

### Cumulative purchased stats

Numbers are rounded roster means. All rows use **single-stat tomes** and the actual historical cap behavior. The gold column is gross cumulative income, not the tome allowance or amount actually spent.

| Level | Gross gold | Old purchases, 25% allowance | Current purchases, 25% | Lost stats, 25% | Old purchases, 50% allowance | Current purchases, 50% | Lost stats, 50% |
|---|---:|---:|---:|---:|---:|---:|---:|
| 25 | 45,207 | 29 | 8 | 22 | 57 | 15 | 42 |
| 50 | 237,606 | 120 | 36 | 84 | 240 | 74 | 166 |
| 75 | 738,953 | 356 | 122 | 234 | 623 | 215 | 408 |
| 100 | 1,857,187 | 767 | 294 | 472 | 1,259 | 495 | 764 |
| 150 | 8,688,740 | 2,631 | 1,206 | 1,425 | 3,938 | 1,915 | 2,023 |
| 180 | 19,747,536 | 4,959 | 2,513 | 2,447 | 7,327 | 3,841 | 3,485 |

Clamping the historical final award changes the 50%-allowance old purchases to approximately 55, 238, 615, 1,252, 3,898, and 6,900 respectively. The large early difference is therefore not principally an old cap exploit.

Knowledge changes the total attribute budget and its distribution. At a 50% allowance, historical Knowledge purchases produce approximately 88 total stats versus 23 currently by level 25, and 309 versus 98 by level 50. Those are sums across all three attributes; the historical totals include cap overshoot. Cap-controlled historical totals are 81 and 264 respectively. A single-stat and a Knowledge budget are not interchangeable offensive investments.

### Effect on the proposed level budget

At level 50, the six-point proposal adds only about **39** free total stats over current mean natural growth. The modeled lost purchases are **84-166** at 25-50% spending. Eight points adds about **137**, and nine adds about **186**, before purchase feedback.

Under the unchanged current formula, extra natural stats also reduce purchased gains. At a 50% single-stat allowance, total base attributes, including starting stats and purchases, become:

| Level | Historical growth + historical tomes | Current growth + current tomes | 6 points + current tomes | 8 points + current tomes | 9 points + current tomes |
|---|---:|---:|---:|---:|---:|
| 25 | 214 | 171 | 189 | 233 | 253 |
| 50 | 526 | 361 | 391 | 472 | 514 |
| 75 | 1,040 | 632 | 667 | 772 | 839 |
| 100 | 1,807 | 1,043 | 1,084 | 1,196 | 1,288 |
| 180 | 8,291 | 4,805 | 4,854 | 5,012 | 5,047 |

**Revised recommendation:** start at **8 points per level** when introducing the allocation system and purchase-only pricing/caps. This deliberately restores a meaningful part of the lost early power, nearly preserves Elementalist's fully specialized natural INT gain, and avoids calibrating every hero to the old cap-filling economy. If the current tome formula is retained and the immediate target is close to the old level-50 budget for a player spending half their gold on tomes, **9 points** is a better numerical match.

Neither value restores the historical level-100+ purchasing curve. The lost purchase budget grows nonlinearly with available gold and cap behavior. Trying to compensate for it entirely through a constant free level reward would overcorrect the earliest levels and still miss later milestones. Revise the purchase curve separately if preserving more of that old power is desired.

Also, the existing total-stat cap constrains a larger free budget: at nine points, the average level-25 natural total is about 247 versus a cap of 258; ten points already exceeds that cap on average. Separating free growth from the purchase cap is therefore part of the redesign, not merely bookkeeping.

### Reproduction and verification

Run `node cotlua/tools/analyze_stat_economy.js` from the repository root. The generated report is saved in `STAT_ECONOMY_SCENARIOS.json`, including 100% spending, Knowledge, quest coverage, 20% Gold Find, bundle behavior, and a cap-controlled historical comparison. The script checks that the source formulas still match the model and verifies four current quote cases against the unmodified Lua `TomeService.quote`, including multi-iteration and Knowledge quotes near the cap. These are offline estimates, not new in-game measurements.
