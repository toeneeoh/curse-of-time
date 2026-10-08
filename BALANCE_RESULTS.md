# Quantitative balance results

These results are produced by the in-engine commands documented in
`BALANCE_HARNESS.md`. Raw recordings remain in Warcraft III's CustomMapData
directory; this file records the interpreted, comparable results.

## Calibration: level 400 Vampire Lord, zero-armor prechaos target

Recording: `balance-combat-player-1-vampire-400-solo2.pld`

Duration: 60.057 seconds. The target was an immortal punching bag, so
`applied_total` is intentionally zero and displayed post-mitigation damage is
the measured quantity. This is a damage-pipeline calibration, not a balance
baseline: real enemies have armor, which materially lowers the physical share.

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

## Calibration: level 400 Vampire Lord, zero-armor chaos target

Recording: `balance-combat-player-1-vampire-400-chaos.pld`

This 60.065-second recording used the same build against defense type 6 with
zero numerical armor. Its starting snapshot matches the prechaos run. The
ending snapshot's additional 222,848 Agility, 6,685 armor, and reduced BAT are
temporary Blood Lord state captured while the buff was active, not persistent
build drift.

| Source | Hits | Damage | DPS | Share |
|---|---:|---:|---:|---:|
| Basic Attack | 181 | 52,171,964 | 868,586 | 80.13% |
| Blood Lord | 102 | 4,307,724 | 71,717 | 6.62% |
| Blood Domain | 35 | 3,615,135 | 60,187 | 5.55% |
| Blood Nova | 18 | 3,231,080 | 53,793 | 4.96% |
| Blood Leech | 11 | 1,779,462 | 29,625 | 2.73% |
| **Total** | 347 | **65,105,156** | **1,083,904** | **100%** |

The run retained 3.0204% of the prechaos recording's DPS, a 96.9796%
reduction. Individual spell average hits retained approximately 3% as well:
Blood Lord 3.001%, Blood Domain 2.982%, Blood Nova 3.054%, and Blood Leech
3.025%. Their small deviations come from `BOOST` variance.

Basic-attack average damage retained only 2.806% because the two one-minute
runs rolled different critical-hit distributions. The maximum basic hit
retained almost exactly 3%, and the complete run is consistent with the same
chaos multiplier applying to physical and magical damage. Applying the 3%
multiplier to the prechaos crit-normalized/90%-uptime baseline predicts
1,061,880 DPS; the observed 1,083,904 is only 2.07% higher.

This establishes that the chaos transition currently acts as a near-uniform
33.33-to-1 compression rather than changing Vampire's physical-versus-magical
damage composition. Any chaos enemy-health comparison should therefore use
roughly 1.06M DPS as this build's stationary single-target baseline, not its
35.4M prechaos value.

## Level 400 Vampire Lord: 300-armor chaos comparison

Recordings:

- `balance-combat-player-1-vampire-400-hybrid-300-chaos.pld`
- `balance-combat-player-1-vampire-400-strict-attack-300-chaos.pld`
- `balance-combat-player-1-vampire-400-unrestricted-attack-300-chaos.pld`

All three sessions ran for approximately 120 seconds against the same immortal
punching bag. The recorder confirmed 300 armor, defense type 6, and 1.0
physical/magical taken multipliers in every session.

| Build | Total DPS | Basic-attack DPS | Magical DPS | Physical share | Attack-rate realization |
|---|---:|---:|---:|---:|---:|
| Existing hybrid | 285,408 | 54,408 | 230,999 | 19.06% | 90.08% |
| Strict-proficiency attack | 450,600 | 319,857 | 130,744 | 70.98% | 95.89% |
| Unrestricted attack | 473,107 | 457,645 | 15,463 | 96.73% | 102.95% |

Attack-rate realization is observed basic-attack events divided by the
snapshot's calculated maximum event rate. The unrestricted result slightly
exceeding 100% indicates that the estimator does not yet capture every engine
timing or extra-event detail; it is not literal uptime above 100%.

The strict attack build gained 57.88% total DPS over the existing hybrid. The
unrestricted sword build gained 65.77% over the hybrid but only 4.99% over the
strict dagger build. Its individual physical hits averaged 33.26% more damage
than the strict build and it landed attacks 7.37% more frequently, producing
43.08% more physical DPS. Conversely, the strict build produced 8.46 times as
much magical DPS.

This difference is a real Vampire mechanic rather than measurement noise. The
hybrid and strict builds are Agility-dominant, so Blood Lord selects the
offensive branch and halves the cooldowns of Blood Leech, Blood Nova, and Blood
Domain. The unrestricted sword build is Strength-dominant, selects the
damage-reduction branch, and uses the longer base cooldowns. Its 130% listed
critical chance also means critical randomness cannot explain its advantage.

The raw optimizer correctly found the highest stationary basic-attack package,
but its generic spell proxy cannot model this branch transition. That is why
the optimizer's large raw attack advantage became only a 5% total-DPS advantage
in engine. Hero-specific breakpoint rules must be part of later build profiles.

The builds also occupy very different defensive points. Before accounting for
the Strength branch's temporary Blood Lord damage reduction, the hybrid has
approximately 3.20 times the strict build's physical EHP and 4.54 times the
unrestricted build's physical EHP from HP and armor alone. Its two magic-resist
items also give it roughly 4.14 times the strict build's magic EHP and 3.54
times the unrestricted build's magic EHP. Therefore the unrestricted result is
a narrow stationary damage ceiling, not an unqualified best Vampire build.

## Level 400 Elementalist: Ice sustain against 300-armor chaos

Recording: `balance-combat-player-1-elementalist-400-ice-sustain-300-chaos.pld`

The legal average-roll build used Azazoth's Staff, Legion's Staff, Lexium
Crystal, Dimensional Set Staff, Ring of Existence, and Thanatos's Boots of Rift
Walking. It supplied 693,771 Intelligence and 86% Spellboost before elemental
stance bonuses. The rotation remained in Ice element to trade Fire's 15%
Spellboost for 1.5% maximum-mana regeneration per second.

| Source | Hits | DPS | Fixed-damage share |
|---|---:|---:|---:|
| Frozen Orb | 35 | 66,327 | 28.37% |
| Flame Breath | 97 | 65,134 | 27.86% |
| Ball of Lightning | 21 | 62,183 | 26.60% |
| Elemental Storm (magical) | 36 | 38,235 | 16.36% |
| Basic Attack | 114 | 1,903 | 0.81% |
| **Comparable fixed damage** | 303 | **233,779** | **100%** |
| Elemental Storm (% current health) | 4 | 53,217 | excluded |
| **Displayed total** | 307 | **286,995** | — |

Elemental Storm's pure component is excluded from the primary result because
the immortal punching bag returns to 100 million health after every hit. A
real target loses health, so repeated current-health hits decay instead of
remaining near 1.6 million damage each. This conditional contribution remains
listed separately for encounter-specific boss modeling.

Ice sustain produced 21.92% more comparable fixed DPS than the preliminary
Fire run (233,779 versus 191,751). Relative to the strict-proficiency Vampire
baseline, Elementalist delivered 51.88% as much stationary single-target fixed
DPS. That does not yet establish a balance deficit: Frozen Orb, Flame Breath,
Ball of Lightning, and Elemental Storm all gain substantial value from clustered
targets, whereas this test hit only one unit.

No Astral Freeze item-active damage was recorded. This matches the current
Vampire comparison, which also omitted its equipped Instill Fear active, so the
comparison currently measures hero-kit output with passive equipment stats
rather than player-triggered item abilities.
