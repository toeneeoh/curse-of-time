# Quantitative balance results

These results are produced by the in-engine commands documented in
`BALANCE_HARNESS.md`. Raw recordings remain in Warcraft III's CustomMapData
directory; this file records the interpreted, comparable results.

## Level 400 Vampire Lord: solo, zero-armor prechaos target

Recording: `balance-combat-player-1-vampire-400-solo2.pld`

Duration: 60.057 seconds. The target was an immortal punching bag, so
`applied_total` is intentionally zero and displayed post-mitigation damage is
the benchmark quantity.

### Build

| Stat | Final value |
|---|---:|
| Strength | 133,028 |
| Agility | 532,838 |
| Intelligence | 132,624 |
| Displayed attack damage | 1,154,569 |
| Physical-dealt multiplier | 1.25 |
| Spellboost | 62% |
| Critical chance | 35% |
| Bonus critical damage | 1,600% |
| BAT | 1.4994 |
| Maximum attacks/second | 3.3347 |

The six equipped items supplied 99.85% of final Agility, 99.39% of final
Strength, and 99.70% of final Intelligence. This is direct runtime evidence
that natural hero growth is negligible in an endgame comparison and that
build-equivalent item packages are required for a meaningful roster ranking.

### Damage result

| Source | Hits | Damage | DPS | Share |
|---|---:|---:|---:|---:|
| Basic Attack | 170 | 1,746,281,216 | 29,076,884 | 81.03% |
| Blood Domain | 42 | 145,483,824 | 2,422,414 | 6.75% |
| Blood Lord | 71 | 99,905,528 | 1,663,502 | 4.64% |
| Blood Nova | 16 | 94,033,528 | 1,565,728 | 4.36% |
| Blood Leech | 13 | 69,514,520 | 1,157,469 | 3.23% |
| **Total** | 312 | **2,155,212,288** | **35,885,888** | **100%** |

All spell sources together contributed 408,931,072 damage, or 6,809,007 DPS
and 18.97% of the total. On this stationary single target, Vampire is therefore
primarily a basic-attack character even while continuously using its spell
rotation.

### Attack-estimator validation and crit normalization

The snapshot predicted 28,587,008 basic-attack DPS at 90% attack uptime. The
recording measured 29,076,884, only 1.71% higher, but the close total conceals
two opposing effects:

- 170 attack events correspond to 84.88% of the maximum attack rate.
- The observed average hit implies about 65 critical hits (38.24%) rather than
  the expected 59.5 critical hits (35%).

Holding the observed 170 attack events constant while normalizing critical
chance to its expected value produces 26,962,269 basic-attack DPS and
33,771,276 total DPS. Alternatively, using the declared 90% attack-uptime
model produces about 35,396,015 total DPS. The latter is the more useful
stationary-target baseline; the raw 35.89M result should not be interpreted as
a precise repeatable ceiling from only one critical-hit sample.

### What this run establishes

1. The recorder correctly attributes attacks and all four Vampire damage tags.
2. The armor-neutral right-click estimator is sufficiently close for initial
   build searches, provided final comparisons use recorded combat.
3. Single-target Vampire damage is highly sensitive to critical chance,
   critical damage, BAT, and attack uptime; one 60-second trial still has
   visible critical-hit variance.
4. The next useful Vampire recordings are the same build against representative
   prechaos and chaos mitigation, followed by clustered-target and moving-boss
   runs. Those distinguish theoretical damage from AOE coverage and practical
   realization.

