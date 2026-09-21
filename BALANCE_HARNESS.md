# Quantitative balance harness

The balance harness measures the game that actually runs. It does not duplicate
ability formulas in a spreadsheet and therefore retains proc chains, summons,
Spellboost, critical strikes, target mitigation, and item formulas.

Files are written through Warcraft III's `Preload` FileIO under:

```text
Documents\Warcraft III\CustomMapData\CoT Nevermore BETA\dev
```

## Commands

```text
-balance items
-balance snapshot [label]
-balance start [seconds] [label]
-balance stop
```

`-balance items` scans the custom item rawcode range in small batches and writes
`balance-items-player-1.pld`. Every item is parsed by `ParseItemTooltip` and
evaluated by `Item:cache_stats` at its maximum upgrade. Each stat has two
columns:

- `*_average`: the exact expected midpoint of the 64 possible quality rolls.
- `*_perfect`: quality roll 63, used for theoretical best-in-slot comparisons.

The export also includes level requirement, proficiency type, tier, rarity,
limit group, and both embedded item-ability definitions. This makes it possible
to compare the item economy at fixed level bands without estimating values from
rendered tooltip text.

`-balance snapshot` writes the current hero stats and six equipped items. Its
`attack_dps_90pct` field is an armor-neutral right-click estimate:

```text
(displayed damage)
* (1 + min(crit chance, 100%) * bonus crit damage)
* (1 / BAT)
* (1 + min(Agility, 400) / 100)
* physical damage multiplier
* 0.90 uptime
```

`-balance start` records final applied hostile damage for the requested period.
It groups results by source unit rawcode, source name, damage type, and damage
tag. Consequently, summoned-unit attacks and spell damage remain distinguishable
from the hero's own output. The report includes starting and ending builds,
target defenses, distinct targets hit, hit count, total damage, DPS, average
hit, and maximum hit. `-balance stop` ends a session early.

## Benchmark matrix

Use levels 50, 100, 200, 300, 400, and 500. At each breakpoint compare:

1. Equal-budget average-roll equipment.
2. Optimized legal average-roll equipment.
3. Optimized legal perfect-roll equipment for the ceiling, clearly separated
   from the normal-build result.

Run each build in these scenarios:

- One stationary target for single-target burst and sustained output.
- Six clustered targets for ordinary AOE.
- A replenishing target group for uncapped or long-duration AOE.
- A moving boss course for realization loss from channels, projectiles,
  summons, and melee travel.

Use a 60-second session after cooldowns and resources have been reset. Record
one unbuffed solo run first. Party-support runs should use a separately named,
fixed support package so their multipliers are not silently included in the
base hero ranking.

The build optimizer/report consumes the item export and combat sessions. Its
primary comparisons should be total applied DPS, damage-source share, marginal
gain per stat, burst versus sustained output, and single-target versus AOE
realization. Healing, shields, control, and party amplification remain separate
utility columns rather than being converted into arbitrary damage.
