# Playable-character balance audit

Snapshot: current working tree on 2026-09-21, with object-editor data read from
the current `builder/CoTN-RPG-1.36.w3x/war3map.w3a`. This is a static audit, not
a combat-log benchmark. No runtime source was changed for this report.

## Scope and confidence limits

The map has 19 playable heroes. Lua supplies nearly all custom coefficients, but
some quantities remain engine-owned: inherited standard-object attack data,
animation backswing, pathing uptime, target acquisition, and the exact items a
real character has saved. Item definitions are encoded in object-editor
ubertips and rolled qualities also vary. Consequently:

- Global formulas, level growth, custom spell coefficients, damage types,
  cooldowns present in `war3map.w3a`, and multiplicative interactions are high
  confidence.
- Absolute DPS is not presented where it would require inventing an attack
  uptime, target count, item roll, or inherited SLK value.
- Natural attribute growth is documented only as an early-progression input.
  It must not be used as an endgame power proxy: purchased base attributes can
  fill the shared `TomeCap`, while equipment supplies additional bonus
  attributes outside that cap.
- “Realistic build” below means a stat priority and legal equipment family, not
  a claim that every named best-in-slot roll is available to every save.
- The old letter-grade table was not an exact DPS result. It has been replaced
  with source-supported conversion measurements and explicitly provisional
  ceiling groups. A defensible numeric roster ranking still requires exported
  live builds and timed combat traces.

## 1. Combat system summary

### Resources and attacks

For a unit wrapper with final base attributes and item bonuses:

```text
Max HP   = base_hp + bonus_hp + 25 * (STR + bonus_STR)
Max mana = base_mana + bonus_mana + 20 * (INT + bonus_INT)

HP regeneration = (flat_regen + regen_max% * Max HP) * regen_multiplier
Mana regeneration =
    (flat_mana_regen + 0.05 * total_INT + mana_regen_max% * Max mana)
    * mana_regen_multiplier

item/base weapon damage cache =
    (native base damage + bonus_damage) * damage_percent

base attack time = native_base_BAT * bonus_BAT_multiplier
```

The engine separately adds a hero's primary attribute to native attacks. A
useful attack estimate is therefore:

```text
raw attack ~= primary attribute
             + (native weapon damage + item damage) * damage_percent
```

before physical-dealt, target defenses, armor, and critical strikes. Native
attack-speed bonus is engine-capped, whereas the custom BAT multiplier changes
the underlying cooldown and therefore remains valuable after ordinary attack
speed has capped. This makes BAT disproportionately valuable to on-hit heroes.

Movement is capped at 600 unless `overmovespeed` is explicitly set.

### Spellboost

The two global spell multipliers are not equivalent:

```text
BOOST  = 1 + Spellboost + random variance in [-0.10, +0.10]
LBOOST = 1 + 0.5 * Spellboost
```

`BOOST` is refreshed once per second for each active hero, not once per cast or
hit. All spells within that second share the same variance. `LBOOST` commonly
scales radius, duration, target count, proc chance, and some cooldown-derived
rates. Thus one percentage point of Spellboost normally gives:

- about +1% to a `BOOST`-scaled amount;
- +0.5% to an `LBOOST`-scaled duration/radius/count;
- about +1.505% first-order gain when both independently multiply total output;
- still more for effects such as Assault Helicopter whose uptime and firing
  count both grow with `LBOOST`.

This broad and inconsistent scope is the most important global gear-scaling
mechanic. “Spellboost” is often damage, coverage, control duration, defensive
duration, proc frequency, and resource efficiency at once.

### Damage pipeline

For hostile damage, the custom pipeline is approximately:

```text
Physical = raw
         * expected_crit
         * source.dm * source.pm
         * target.dr * target.pr
         * armor_multiplier(after penetration)
         * chaos-type modifiers

Magic    = raw
         * source.dm * source.mm
         * target.dr * target.mr
         * chaos-armor modifier

Pure     = raw * source.dm * target.dr
```

Pure damage bypasses armor, physical/magic-specific dealt/taken multipliers,
and chaos armor's 0.03 multiplier. It does not bypass general `dm` or `dr`.

Critical strikes apply only in the physical branch. With `c` critical chance
and `d` critical-damage stat, both expressed as percentage points:

```text
critical hit multiplier = 1 + d / 100
expected multiplier     = 1 + c*d / 10000
```

The default 5 chance / 100 damage is 1.05 expected damage and a 2x critical
hit. A custom physical spell can crit unless it suppresses source events.
Magic spells do not crit.

### Armor, penetration, and effective health

```text
positive armor multiplier = 1 / (1 + 0.05 * armor)
negative armor multiplier = 2 - 0.94 ^ (-armor)
```

For positive armor:

```text
physical EHP = HP * (1 + 0.05 * armor) / (dr * pr)
magic EHP    = HP / (dr * mr * chaos_armor_modifier)
```

Every additional point of positive armor therefore adds exactly 5% of raw HP
to absolute physical EHP before `dr`/`pr`; the percentage gain relative to an
already large EHP pool declines. Percent armor penetration reduces only
positive armor in practice; the `min(old, penetrated)` expression leaves
negative armor unchanged.

Item damage resistance and magic resistance multiply `dr` and `mr` by
`1 - value/100`. Multiple sources therefore compound. Ten separate 5% general
resistance sources yield `0.95^10 = 0.599` damage taken, or 1.67x EHP, rather
than 50% additive resistance.

Chaos armor multiplies non-pure damage by 0.03. Chaos physical attacks then
receive a 350x attack-type multiplier. These constants are part of a numeric
representation change: chaos-era unit HP, damage, and armor are authored or
generated on the corresponding compressed scale. They are therefore not, by
themselves, evidence that a class becomes 350x stronger or that magic becomes
unusable. Comparisons across the transition must use final applied damage and
effective enemy durability after the authored compensation. Only an individual
ability or unit that misses that compensation is a balance defect.

### Healing, shields, avoidance, and death prevention

- All healing passes through the target's `regen_percent`; “healing received”
  and regeneration amplification are the same multiplier.
- Shields absorb already mitigated damage, so armor, `dr`, `pr`, and `mr`
  multiply shield value as well as health value.
- Evasion is checked before physical on-hit multiplier callbacks. It does not
  avoid magic or pure damage.
- Fatal-damage callbacks can set incoming damage to zero. Soul Link, Undying
  Rage, resurrection, and similar mechanics must therefore be valued as fight
  resets or death prevention rather than ordinary EHP.
- Hit-based-health units use a separate path and should not be included in
  ordinary EHP comparisons.

### Exact marginal stat returns

Before hero-specific abilities:

| Increment | Direct return |
|---|---|
| +1,000 Strength | +25,000 HP; also +1,000 native attack damage for a Strength-primary hero |
| +1,000 Agility | +1,000 native attack damage for an Agility-primary hero; roughly +300 armor under the standard game constant; native attack speed until its cap |
| +1,000 Intelligence | +20,000 mana and +50 mana/second; also +1,000 native attack damage for an Intelligence-primary hero |
| +1 percentage point Spellboost | roughly +1% `BOOST` amount and +0.5% `LBOOST` dimensions; larger when several dimensions multiply |
| +1 percentage point crit chance | relative DPS gain `(d/10000)/(1+c*d/10000)`; 0.952% at default 5/100, but 7.89% for level-500 Master Rogue at 6/1500 |
| +1 percentage point crit damage | relative DPS gain `(c/10000)/(1+c*d/10000)` |
| +1 positive armor | +0.05 * raw HP / (`dr*pr`) absolute physical EHP |
| +1% general resistance | approximately +1.01% EHP for the first source, compounding thereafter |
| +1% BAT bonus | approximately +1% attacks/time through reciprocal BAT scaling; remains relevant beyond native attack-speed cap |

### Item economy

Eight inventory positions are equipment slots; slots 9-26 are backpack storage.
An item can hold up to three sockets. For a non-fixed item stat:

```text
seed = base + (flat_per_level * level
             + flat_per_rarity * floor(max(level-1, 0)/rarity))
             * percent_modifier

lower/upper = seed + seed * ITEM_STAT_MULTIPLIER[level] * percent_modifier
```

The level multipliers reach 11.2 at item level 16 and 13.4 at level 17, so a
non-fixed base stat can become 12.2x or 14.4x its seed. Fixed (`*`) percentage
stats avoid that general multiplier but may still receive flat-per-level or
flat-per-rarity additions. Sockets add their calculated values directly before
the item applies stats.

The existing level-400 Vampire developer loadout illustrates the scale and the
hybrid incentive: Dimensional Set Dagger, Azazoth's Doom Dagger, Azazoth's
Leather Armor, Torture Jewel, Thanatos's Wings, and Thanatos's Boots. It combines
large flat weapon damage and Agility with Strength, Intelligence, armor,
regeneration, crit, crit damage, BAT, Spellboost, and magic resistance. Exact
totals depend on item rarity/quality, but the definition-level conclusion is
stable: Vampire can monetize all three attributes, while a single-stat caster
usually wastes two-thirds of a tri-stat item's offensive budget.

### Purchased-stat economy (material correction)

The first version of this report gave innate level growth far too much weight.
`TomeService` purchases ordinary `str`, `agi`, or `int`, and the shared base-stat
cap is:

```text
TomeCap(level) = floor(0.000003*level^4 + 0.0005*level^3 + 10*level)
```

| Level | Shared STR+AGI+INT cap |
|---:|---:|
| 1 | 10 |
| 100 | 1,800 |
| 200 | 10,800 |
| 300 | 40,800 |
| 400 | 112,800 |
| 500 | 255,000 |

At level 500, the heroes' complete natural STR+AGI+INT totals range from
1,820.4 (Phoenix Ranger) to 4,435.2 (Elementalist), or only **0.71% to 1.74%**
of the tome cap. More importantly, natural stats count toward that cap. A
stat-capped character does not keep Elementalist's larger natural total on top
of 255,000 purchased stats; it merely buys slightly fewer points before
reaching the same shared total. Equipment then adds `bonus_str`, `bonus_agi`,
and `bonus_int`, which do not participate in this cap.

Consequences for the audit:

- Innate growth matters while leveling and changes the gold needed to approach
  the cap, but contributes almost nothing to a capped character's ceiling.
- Endgame comparisons must hold total purchased base stats constant, then add
  legal item/socket packages. Comparing gearless level-500 heroes is not a
  useful endgame balance test.
- The meaningful class differences are conversion coefficients, access to
  item families, percentage stats, attack/BAT behavior, target count, uptime,
  and whether one purchased stat powers several independent effects.
- Because the cap is shared across all three base attributes, hybrid heroes
  pay a real allocation cost. Vampire can use all three attributes, but it
  cannot simultaneously place the full 255,000 into each one through tomes.

### Exact conversion examples

These are exact local comparisons from source formulas. They are not presented
as whole-character DPS rankings, because cooldown, target uptime, and the rest
of the build still matter.

| Investment and state | Exact conversion | Relative interpretation |
|---|---:|---|
| +20 effective crit chance, ordinary 100 crit-damage hero starting at 5% | expected attack multiplier 1.05 -> 1.25 (**+19.05%**) | baseline |
| +20 effective crit chance, level-500 Master Rogue starting at 6% and 1,500 crit damage | 1.90 -> 4.90 (**+157.89%**) | the same increment is **8.29x as effective** as on the ordinary hero |
| +1,000 Agility to level-500 Thunderblade's magic spells | every listed AGI coefficient receives the 2.1 Overload multiplier | **110% more spell damage per AGI** than an otherwise identical 1.0-mm spell |
| +1,000 Armor to Shield Slam at rank `L` | `6,000L` raw magic damage per cast, plus physical EHP | exactly **6x** Shield Slam's raw per-point conversion from +1,000 Strength (`1,000L`), before Strength's HP/attack value |
| +1,000 of one stat to Blood Nova | AGI: 3,000; STR: 2,000; INT: 12,000 raw magic | for Nova alone, INT is **4x AGI** and **6x STR**; this is not the ordering for Vampire's whole kit |
| +1 percentage point Spellboost on one `BOOST` amount at current Spellboost `s` | relative gain `0.01/(1+s)` | 1.00% at 0%, 0.80% at 25%, 0.67% at 50%, 0.50% at 100% |
| +1 percentage point Spellboost when one `BOOST` amount and one `LBOOST` time/count dimension multiply | relative gain `(1.01+s)/(1+s) * (1.005+0.5s)/(1+0.5s) - 1` | about **1.51%** at 0%, 1.25% at 25%, 1.07% at 50%, 0.84% at 100% |

This is the format the completed model should use for every hero: compare the
same additional purchasable or item budget at the same existing stat point.
Quoting a coefficient without its denominator is not “stat efficiency.”

For identical raw physical damage against the same target, the hero definitions
also provide an exact first-order comparison through native `pm`:

| Heroes | Native physical-dealt multiplier | Same physical stat budget versus a 1.0 hero |
|---|---:|---:|
| Casters/supports using the 1.0 default | 1.00 | 100% |
| Oblivion Guard, Bloodzerker, Royal Guardian, Warrior, Savior | 1.20 | 120% (**20% more**) |
| Vampire, Assassin, Thunderblade, Master Rogue | 1.25 | 125% (**25% more**) |
| Elite Marksman, Phoenix Ranger | 1.30 | 130% (**30% more**) |

This means a bow carry converts a point of weapon damage or primary attribute
into the physical branch 8.33% more efficiently than a 1.20 melee hero and 4%
more efficiently than a 1.25 hero, before crit, BAT, on-hit effects, armor, or
class buffs. Thunderblade's magic spells separately reach 210% of the neutral
magic conversion at level 500, and Master Rogue's crit interaction then creates
the much larger nonlinear exception shown above.

## 2. Character-by-character analysis

### Oblivion Guard — tank / percent-health bruiser

Major mechanics: Body of Fire supplies charges; Meteor and Magnetic Stance use
Strength; Magnetic Stance trades outgoing damage for durability; Magnetic
Strike applies 15% general vulnerability; Infernal Strike replaces the next
attack with an AOE physical hit; Gatekeeper's Pact is a delayed 15x Strength
magic AOE plus 5-second stun.

Key formulas at rank `L`:

- Meteor: `L * STR`, 300 AOE, 10-second configured cooldown.
- Magnetic Stance: outgoing `dm = 0.45 + 0.05L`, incoming
  `dr = 0.95 - 0.05L`; at L5 both are 0.70.
- Infernal Strike: `L*STR + current_target_HP*(0.25+0.05L)`, half against the
  code's boss defense types, physical and AOE. At L5 the non-boss term is 50%
  current HP; its physical type permits crit and subjects it to chaos/armor.
- Gatekeeper's Pact: `15*STR`, 750 AOE at L4, 45-second cooldown at L4.

Best stats/build: Strength, general resistance, armor, BAT/attack speed, then
Spellboost and penetration. Fullplate/plate lets it build the best defensive
frontier. Spellboost is unusually efficient because it grows Infernal Strike's
current-HP amount through `LBOOST`, not only a flat coefficient.

Performance: high physical EHP, medium magic EHP, medium sustained damage, high
opening boss damage, strong AOE control and self-heal (up to 6% max HP per
Infernal Strike based on weighted targets). Its theoretical ceiling is driven
by percent-current-HP damage plus multiplicative vulnerability. The meaningful
cost is Magnetic Stance's 30% outgoing loss at max rank.

Risk: current-HP scaling remains useful regardless of enemy HP inflation and is
only controlled by damage type, the boss half modifier, and encounter armor.
The boss test reads the originally struck target's defense type for every unit
in the splash group. Striking a normal creep beside a boss can therefore apply
the unhalved current-HP formula to the boss; striking the boss halves damage to
nearby normal units as well.

### Bloodzerker — high-risk sustained physical bruiser

Blood Frenzy gives 1.5x faster BAT for 15% max-HP pure self-damage. Blood Leap
is `0.4+0.4L` times cached weapon damage in AOE. Blood-Curdling Scream costs 10%
max HP and reduces armor by 12% + 2% per rank. Blood Cleave has 20% base proc
chance, deals `(0.45+0.05L)*weapon_damage` as physical AOE, and heals from an
independently estimated damage value. Rampage grants 5% penetration per rank
while draining 8% current HP per second. Undying Rage prevents incoming damage
for `10*LBOOST` seconds and settles accumulated damage versus regeneration on
expiry, capped to one max-health bar either way.

Best stats/build: weapon damage, Strength, BAT, crit chance/damage, penetration,
and enough resistance/regen to finance self-costs. It converts regeneration
twice: normal sustain and Undying Rage settlement.

Performance: high sustained and AOE physical output with excellent attack-speed
conversion, but its base `pr=1.6`, `mr=1.8` are the weakest melee baseline.
Undying Rage changes burst survivability from worst-in-role to temporary
invulnerability. The damage build is efficient only while it can keep hitting;
control or target downtime is a severe opportunity cost.

Blood Cleave now totals the damage pipeline's returned applied damage for each
secondary target, after that target's evasion, crit, multipliers, armor,
shields, and fatal prevention. Its healing therefore follows damage actually
dealt rather than independently estimating mitigation from the primary target.

### Royal Guardian — primary tank / group immunity support

Shield Slam deals `L*(STR + 6*armor)` magic damage. Royal Plate grants:

```text
armor = 0.006*L^5 + 10*L^2 + 25*L
```

times `BOOST`, and another 30% if a shield is already active. Provoke heals
`(missing HP)*(0.20+0.01L)*BOOST`, applies a 25% total-damage penalty to enemies,
and taunts. Protector applies an always-on general resistance aura
`dr = 0.93-0.02L`. Fight Me gives nearby allies complete damage immunity for
`(4+L)*LBOOST` seconds on a 45-second cooldown. Steed Charge supplies mobility.

At Royal Plate L20 the formula is 23,700 armor before Spellboost and the
shield bonus. That alone represents 1,186 raw-health multiples against physical
damage during the buff. Shield Slam then converts the same armor into offense.

Best stats/build: armor is dominant because it simultaneously grants physical
EHP and Shield Slam damage. Strength/HP, general and magic resistance cover the
other axis; Spellboost scales Royal Plate, missing-health healing, and duration.

Performance: top physical tank, strong enemy damage suppression, top-tier raid
utility, low ordinary sustained DPS but potentially extreme Shield Slam burst.
Its maximum build has little offense/defense tradeoff because armor buys both.
Fight Me is stronger than an equivalent heal because it blanks arbitrary burst
for the whole party.

Balance concern: the fifth-power armor formula and armor-to-damage conversion
form the clearest tank scaling outlier. Verify that reaching rank 20 is intended.

### Warrior — flexible bruiser / counter and party attack support

Parry blanks damage and retaliates for cached weapon damage as magic. Spin Dash
deals `(0.7+0.2L)*weapon_damage`, can be recast, and slows BAT. Intimidating
Shout gives allies +20% attack damage and subtracts 40 percentage points from
enemy attack damage; a Limit Break branch also gives enemies 40% increased
magic taken. Wind Scar deals `(0.7+0.1L)*weapon_damage`. Adaptive Strike selects
several effects, including `(1+0.2L)*weapon_damage`, a heal of `10*regen`,
knock-up, party shout, or tornado damage. Limit Break upgrades those branches.

Best stats/build: balanced weapon damage/Strength/regen/BAT with enough defense
to stay in melee. Regen is a real offensive-combat stat because Adaptive Strike
turns it into burst healing.

Performance: medium-high sustained and burst, high tactical survivability, good
mobility/control, and strong physical-party support. It does not have the raw
EHP conversion of Royal Guardian or the current-HP scaling of Oblivion Guard,
but has fewer dead matchups. A magic-heavy party makes the Limit Break shout
especially valuable.

### Vampire — hybrid carry / self-sustaining AOE

Blood Bank holds up to `200*INT`, gains `0.75*STR` per attack, and replaces mana.
Blood Leech deals `(2.75+0.25L)*(AGI+STR)` and deposits `10*AGI+5*STR` blood.
Blood Domain ticks for `(0.5+0.5L)*AGI + (1.5+0.5L)*STR`, but reduces each
target's amount as nearby target count rises, to a 20% floor. Blood Mist spends
`16*INT` and heals `(0.25+0.25L)*STR + 15% of cost`. Blood Nova spends `40*INT`
and deals `3*AGI + 2*STR + 30% of cost`, i.e. an additional `12*INT`. Blood Lord
adds `0.75*AGI+STR` magic on attacks. Its Strength branch reaches at most 20%
general damage reduction from a full bank; its Agility branch halves core
cooldowns.

Best stats/build: genuinely hybrid. Agility improves armor/attack speed, Leech,
Domain, Nova, and the offensive Blood Lord branch; Strength is the primary
attack attribute and gives HP, Leech, Domain, Nova, and sustain; Intelligence
gives bank capacity and the very large Nova coefficient. BAT, Spellboost, and
resistance then multiply the package.

Performance: high realistic AOE, high sustain, high burst, and excellent gear
conversion despite only 2/2/1 innate gains. Its single-target boss output rises
sharply when Blood Lord and fast cooldowns overlap. It is less efficient with
pure single-stat drops, but tri-stat and mixed offensive items lose almost no
budget on it. That flexibility is itself a balance advantage.

### Savior — defensive bruiser / shield support

Divine Judgement is `(0.2+0.3L)*(STR+weapon_damage)`. Savior's Guidance shields
for `(2.25+0.25L)*STR*BOOST` and can cover allies. Holy Bash deals
`L*(STR+0.4*weapon_damage)` on-hit magic damage and heals allies for
`25+0.5*STR`. Thunder Clap deals `0.25*(L+1)*(STR+weapon_damage)` and applies
35% movement/attack slow. Righteous Might at L4 grants +100% attack damage,
+100% armor, multiplies magic taken by 0.20, heals 30% max HP, lasts
`25*LBOOST` seconds, and deals `10*STR*BOOST` in AOE.

Best stats/build: Strength, weapon damage, armor, general resistance and
Spellboost. Fullplate access supports a true frontline build. Strength has
unusually broad conversion into damage, shields, healing, HP, and attacks.

Performance: medium sustained DPS, high cooldown-window damage and EHP, strong
shield/heal output, good AOE control. Righteous Might creates an enormous
magic-survival window (6.5x base magic EHP after the hero's native `mr=1.3`),
while the same cast doubles attack and armor. This is a powerful but visible
60-second-window identity rather than permanent dominance.

### Dark Savior — magic bruiser / stacking transformation carry

Dark Seal counts nearby units (heroes count as 10), up to
`5 + 10*floor(hero_level/100)` charges; each charge gives 1% Spellboost and 1%
reciprocal BAT. Medean Lightning hits about `L+1.5` targets for
`(1.5+0.5L)*INT`. Freezing Blast is `(L+2)*INT` with freeze/slow. Dark Blade
adds `1.5*INT` magic on each hit, restores 0.5% max mana, and permanently banks
health during the buff through temporary Strength gained per hit. Dark Shield
sets general damage taken to `0.45-0.05L` while draining two mana per point of
post-mitigation damage. Dark Ascension halves current HP, sets BAT to 1.0,
multiplies total damage by roughly 1.25-1.50 depending on pre-cast HP, and turns
Dark Blade into 300-radius splash.

Best stats/build: Intelligence, BAT, Spellboost, mana sustain, then enough HP
and general resistance to support the melee transformation. Its unusual
sword/plate and staff/cloth access permits real bruiser or caster frontiers.

Performance: medium outside setup, very high sustained AOE once Seal,
Ascension, and Dark Blade overlap; very high magic EHP while Dark Shield has
mana. Target density directly becomes Spellboost/BAT, so large packs make the
hero stronger rather than merely offering more AOE targets.

Risk: target-density scaling and permanent retained health from repeated Dark
Blade hits deserve long-duration stress tests. Dark Shield's mana drain is the
main intended limiter.

### Crusader — premier multiplicative party support

Soul Link snapshots HP/mana, prevents one fatal hit during `5*LBOOST` seconds,
then restores lost resources to the snapshot. Law of Resonance echoes 20% + 5%
per rank of post-mitigation physical damage as pure damage. Law of Valor grants
`(0.08+0.02L)*caster_STR*BOOST` flat regeneration and 8% + 2% per rank healing
amplification. Law of Might grants the target `(10+5L)%*LBOOST` of its own
highest attribute plus `(0.04+0.01L)*caster_INT*BOOST`. Aura of Justice gives
up to 15% physical resistance to nearby allies and actively shields every ally
for `(20+5L)% max HP * LBOOST` for five scaled seconds. Divine Radiance ticks
`2*INT` damage to enemies and `2*STR` healing to allies for ten scaled seconds.

Best stats/build: Intelligence/Spellboost for Law of Might and Radiance, with
Strength for Valor/Radiance and defensive gear for uptime. Unlike personal DPS
heroes, its best build is the one that maximizes the strongest ally's output.

Performance: low personal burst, medium personal sustain, but the highest
general party scaling in the roster. At Law of Might L6, a carry receives 40%
of its own highest stat times `LBOOST`, plus 10% of the Crusader's Intelligence.
Resonance then adds a 50% pure-damage echo. In a six-player physical party its
aggregate contribution can exceed several personal DPS slots.

Resonance is restricted to basic physical attacks and derives its echo after
ordinary mitigation and shield processing. The echo is marked as an
already-scaled amount, so source/target multipliers, armor penetration, crit,
and offensive proc events are not applied twice. The resulting pure-damage hit
can still interact with the target's shields and fatal-damage mechanics.

### Arcanist — cooldown-reset AOE caster

Control Time gives registered Arcanist casts a 15% chance to reduce their
cooldown by 20 seconds, effectively resetting most of the kit. Arcane Bolts
fires `L+2` missiles, each dealing `2*INT` in 250 AOE (5-second configured
cooldown). Arcane Barrage deals `(L+1)*INT` over a 750 area, with 5 seconds
normally and 3 during Arcanosphere. Arcane Shift deals `(5+3L)*INT` in 350 AOE
and supplies mobility. Stasis Field controls a 250 area for six scaled seconds.
Arcanosphere lasts `8+4L` seconds and changes several spells' behavior.

Best stats/build: Intelligence and Spellboost, then mana and defenses. Spellboost
is better than its tooltip suggests because it expands AOE/control while
Control Time increases cast frequency independently.

Performance: high AOE and burst, medium sustained boss output, strong control,
low innate durability. Its theoretical ceiling is proc-driven: sequences with
repeated 15% resets are far above the mean but not dependable. Evaluate both
mean output and 95th-percentile burst rather than only a deterministic rotation.

### Dark Summoner — persistent multi-unit carry / support

Reaver inherits at least 25% of Summoner INT+STR as Strength,
level-scaled percentages of INT as Agility/Intelligence, and supplies cleave and
wounds. Skull Brute receives 40% of INT+STR as Strength and 60% of INT as
Agility, functioning as the durable tank. Destroyer receives 6.66% of INT+STR
as Strength and `0.5*INT*ability_rank` as Intelligence, making it the fragile
damage specialist. Essence allocation raises tiers while active summons reserve
essence. Demonic Sacrifice pays escalating, potentially lethal hero health,
then heals/buffs nearby summons after projectile travel. Unholy Ascension gives
level-dependent damage and utility to summons in an expanding wave.

Best stats/build: Intelligence dominates because it improves hero mana/attack,
all three summon baselines, and several tier/sacrifice outcomes. Spellboost
scales radii, durations and tier effects; defensive gear protects the otherwise
fragile controller. Summon composition is an opportunity cost: two tier-5
summons consume the essence that would support a third full-strength summon.

Performance: high sustained single-target and AOE when summons maintain uptime,
high utility, medium burst, low direct hero durability. The realistic ceiling
is constrained by summon deaths, 30-second death cooldowns, pathing, leash/range
requirements, and micro. The theoretical stationary-target ceiling is much
higher because one Intelligence purchase is converted by multiple simultaneous
units.

Balance concern: multi-body inheritance lets one purchased or itemized INT
point contribute to several simultaneous units. The 6.5 INT/level growth is
minor beside the tome and equipment budgets; the multi-body conversion is the
part that should be benchmarked. Measure summon uptime, not only target-dummy
DPS.

### Bard — raid amplifier / sustain support

Song of War gives nearby allies +20% attack damage; Harmony gives 1% max-HP
regen; Peace gives 1% max-mana regen; Fatigue reduces enemy movement and attack
speed by 30%. Inspire grants 8% + 2% per rank Spellboost. Encore can heal
`(0.75+0.25L)*INT`, give 20% general resistance, add ten attacks each worth
`(0.25+0.25L)*target_main_stat`, or stun/fatigue. Melody of Life spends 10% of
current mana and heals 25% + 25% per rank of that cost. Improv and Tone of Death
provide area damage/control.

Best stats/build: Intelligence, Spellboost, mana/mana regeneration, and defense.
Personal attack stats are poor investments. In a full party, durability that
maintains aura uptime can be worth more than another small personal coefficient.

Performance: low personal DPS and burst, high sustain, very high utility and
party damage. Song of War alone adds about 20% to the weapon component of each
affected ally, while max Inspire adds 20% Spellboost and all its `LBOOST` side
benefits. It is weak solo by design but can be mandatory if party buffs stack
without composition constraints.

### Hydromancer — AOE control / vulnerability support

Infused Water and Frost Blast use `L*INT` with 250 AOE and freeze logic.
Whirlpool ticks `0.25*L*INT`, pulls in 330 scaled AOE, and lasts `2+2L` seconds.
Tidal Wave supplies displacement and applies 15% increased general damage taken.
Blizzard ticks `0.25*L*INT` over `L+3` scaled duration. Ice Barrage fires
`12+4L` instances of `0.5*INT`. Soaked reduces movement by 50% and attack speed
by 30%.

Best stats/build: Intelligence/Spellboost, then mana and enough defense to
channel/position. Tidal Wave's general vulnerability makes cooldown/coverage
more valuable in parties than a small personal damage increase.

Performance: high AOE, control, and party amplification; medium boss DPS unless
the boss remains in persistent zones. Fifteen percent vulnerability is
approximately 15% more combined party output when no mutually exclusive or
refresh issue intervenes.

### High Priestess — primary healer / resurrection support

Invigoration repeatedly heals the lowest-health ally for
`(0.15*INT + 1% target max HP)*BOOST` every 0.5 seconds while channeling and
restores mana. Divine Light heals `((0.25+0.25L)*INT + 5% target max HP)*BOOST`
and reduces Resurrection cooldown. Sanctified Ground removes 100% healing from
normal enemies (50% from bosses), slows them, and also reduces Resurrection
cooldown. Holy Rays deals `2L*INT` to enemies and heals `0.5L*INT` to allies in
600 scaled AOE. Protection shields all nearby heroes for `3*INT*BOOST`, lasts
20+10L seconds, and grants a 10% BAT improvement. Resurrection restores 40% +
20% per rank and also provides a long-cooldown self resurrection.

Best stats/build: Intelligence and Spellboost, followed by mana economy and
survival. Max-HP coefficients mean it remains useful on tanks even if its own
INT lags gear inflation.

Performance: low personal DPS, best direct healing, excellent shields and
fight recovery, moderate control. Invigoration is roughly 2% target max HP per
second plus `0.3*INT*BOOST` per second before healing amplification, making it
scale with the recipient as well as the caster. Resurrection cannot be reduced
to ordinary HPS and is strongest in long boss attempts.

### Elementalist — repeated-coefficient spell scaler / AOE burst carry

Element modes add different effects: Fire grants 15% Spellboost, Earth grants
25% general resistance, Ice supplies regeneration/control, and Lightning adds
mobility/offense. Ball of Lightning is `(5+L)*INT` with increasing range.
Frozen Orb deals `3L*INT` plus repeated `0.5+0.5L` INT ice bursts and freeze.
Gaia Armor shields `(0.5+0.5L)*INT`, multiplied by 2.5 under the relevant Earth
state. Flame Breath repeatedly deals `(0.5+0.5L)*INT`. Elemental Storm makes
about 12 strikes of `(1.5+0.5L)*INT` at 0.4-second intervals; Fire strikes are
1.5x, Ice freezes/restores mana, Earth stacks 4% general vulnerability, and
Lightning also hits one target for 1.5% current HP as pure damage.

Best stats/build: Intelligence/Spellboost are overwhelmingly dominant, with
mana and defense after them. Fire mode multiplicatively improves already high
Spellboost builds; Earth mode is the safer frontier.

Performance: top candidate for AOE burst and sustained caster output, useful
control, and low passive EHP. The ultimate also includes enemy-stat scaling
through pure current-HP damage. Its 8.4 INT/level is conspicuous in a gearless
comparison but only changes how much INT must be purchased before reaching the
shared cap; it is not an endgame ceiling advantage.

### Assassin — mobile burst / evasion skirmisher

Shadow Shuriken scales from `(AGI+weapon_damage)*(L+5)*0.25`. Blink Strike is
`L*(0.5*AGI+0.25*weapon_damage)` in AOE and grants 30 evasion. Smoke Bomb grants
roughly 10-15 evasion (double for the Assassin) while slowing enemies 28-40%.
Dagger Storm launches 30 daggers at `2*AGI`. Blade Spin performs fewer cycles
as hero level rises (8 down to a floor of 5) but each cycle uses `8*AGI`
physical or `4*AGI` magic depending on state. Phantom Slash deals `1.5L*AGI`
per strike while granting 100 evasion during execution.

Best stats/build: Agility, weapon damage, Spellboost, BAT/crit for sustained
attacks, with enough HP/resistance to survive between evasion windows.

Performance: high mobile burst and avoidance, medium sustained boss damage,
good AOE when projectiles connect, little party amplification. Its 3.6 AGI/level
is strong. The level-dependent reduction in Blade Spin cycles is an unusual
negative scaling term and should be verified as deliberate compensation for
gear growth.

### Thunderblade — magic burst melee / invulnerable-window carry

Overload multiplies magic dealt by `1 + 0.5 + 0.1*floor(level/75)`, reaching
2.1x at level 500. Thunder Dash deals `2*AGI`; Monsoon makes `L+1` strikes of
`1.8*AGI`; Bladestorm deals `(L+2)*AGI` plus `0.2L*AGI` damage-over-time and
proc effects; Omnislash makes `L+3` hits of `1.5*AGI` while taking only 20% total
damage; Railgun deals `(15+5L)*AGI` over long range and large AOE.

Best stats/build: Agility and Spellboost first, then general magic-dealt sources,
with BAT/crit only for the native-attack portion. Because Overload is `mm`, it
multiplies item magic procs as well as class spells.

Performance: very high burst, high mobility, strong temporary survivability,
medium sustained output between cooldowns, minimal party support. At level 500
every magic coefficient effectively doubles before Spellboost, which makes
gear and item-proc comparisons against other Agility heroes misleading unless
Overload is included.

### Master Rogue — physical crit/penetration boss carry

Instant Death adds `400 + 100*floor(level/50)` critical-damage points and sets
critical chance multiplier to 1.2. At level 500, total crit damage is 1,500
including the default 100, critical hits deal 16x, and base effective crit
chance is 6%. Expected attack damage is already 1.90x before crit items, versus
1.05x for a default hero. Death Strike deals `(0.5+0.5L)*AGI`. Nerve Gas deals
`3L*AGI` over ten scaled seconds and applies 20% armor reduction plus 30%
movement/attack slow. Backstab adds `(0.16*AGI+0.03*weapon_damage)*L` magic on
rear attacks. Piercing Strike has a 20% on-hit chance to grant 30% + rank armor
penetration, reaching 50% at rank 20.

Best stats/build: critical chance is overwhelmingly first until practical cap,
then Agility, BAT, weapon damage and penetration. Crit damage itself has much
lower marginal value because the passive already supplies 1,400 points.

Performance: top sustained physical boss ceiling, good single-target burst,
medium AOE/control, ordinary survivability. Adding 20 effective crit-chance
points at level 500 changes expected attack multiplier from 1.90 to 4.90; the
same addition on a default 100-crit-damage hero changes 1.05 to 1.25. This is
the clearest item-synergy outlier in the roster.

### Elite Marksman — ranged area/summon DPS

Tri Rocket deals `L*AGI + 0.1L*weapon_damage` and switches between 6 and 3
seconds with Sniper Stance. Assault Helicopter lasts `30*LBOOST` seconds; rockets
use `0.35*(weapon_damage+AGI)*BOOST`, sniper rockets are 2.5x, cluster mode fires
once at every enemy in range, and effective shot interval falls with `LBOOST`.
Single Shot deals `5*AGI` and slows. Hand Grenade uses
`(0.4+0.1L)*weapon_damage` or `(0.9+0.1L)` with helicopter state. Flaming Betty
lasts `15*LBOOST`, fires 20% weapon-damage magic procs, and has a 42-2L code
cooldown.

Best stats/build: Agility, weapon damage and Spellboost. Spellboost is unusually
efficient for Helicopter because it multiplies projectile damage, duration, and
shot count; cluster mode additionally scales with enemy count. Defensive stats
matter because base `pr=2.0`, `mr=1.8` are the worst baseline in the roster.

Performance: high ranged AOE/summon uptime, high target-rich theoretical
ceiling, medium single-target burst, very low passive durability. Cluster
Helicopter is uncapped per firing cycle, so a 20-target pack produces about 20x
the projectile contribution of one target.

### Phoenix Ranger — ranged attack carry / reincarnation

Multishot supplies attack coverage. Phoenix Flight is mobility plus `1.5*AGI`.
Fiery Arrows has `2L*LBOOST` proc chance and deals approximately
`L*AGI + 0.3*weapon_damage` magic. Searing Arrows hits all enemies in 900 scaled
AOE for weapon damage, applies Burning, and converts repeated hits into a
5-second DoT of `(0.05+0.05L)*weapon_damage` per second. Flaming Bow grants 50%
attack damage immediately, ramps by attacks to 80% + 2% per rank, and passively
grants 10% + rank armor penetration. Reincarnation is a major fight-recovery
mechanic rather than DPS.

Best stats/build: weapon damage, Agility, BAT, crit and penetration, with enough
defense to exploit Reincarnation rather than repeatedly die. Spellboost improves
proc chance, AOE, duration and DoT damage, so it remains valuable on this
attack-oriented hero.

Performance: high sustained physical/magic hybrid output, excellent AOE, low
burst without Flaming Bow, and very poor passive EHP (`pr=2.0`, `mr=1.8`). It
scales strongly with uninterrupted attack time; movement-heavy bosses sharply
reduce ramp value.

## 3. Cross-character comparison

### Stat-cap scale at level 500

This replaces the misleading gearless EHP table. The natural total is shown
only to establish how small it is beside the 255,000 purchased-stat cap.

| Hero | Natural STR+AGI+INT | Share of cap |
|---|---:|---:|
| Oblivion Guard | 2,774.5 | 1.09% |
| Bloodzerker | 2,726.6 | 1.07% |
| Royal Guardian | 2,568.9 | 1.01% |
| Warrior | 2,726.6 | 1.07% |
| Vampire | 2,520.0 | 0.99% |
| Savior | 1,922.2 | 0.75% |
| Dark Savior | 2,383.3 | 0.93% |
| Crusader | 1,907.2 | 0.75% |
| Arcanist | 2,406.2 | 0.94% |
| Dark Summoner | 4,326.4 | 1.70% |
| Bard | 1,836.4 | 0.72% |
| Hydromancer | 2,624.8 | 1.03% |
| High Priestess | 3,070.9 | 1.20% |
| Elementalist | 4,435.2 | 1.74% |
| Assassin | 2,877.3 | 1.13% |
| Thunderblade | 2,926.2 | 1.15% |
| Master Rogue | 2,222.6 | 0.87% |
| Elite Marksman | 2,072.9 | 0.81% |
| Phoenix Ranger | 1,820.4 | 0.71% |

The widest natural-total gap is 2,614.8, only 1.03% of the cap, and disappears
from total base-stat ceiling after purchases. It remains relevant only before
the character can afford to fill the gap.

### Provisional potential-damage groups

The previous letter grades implied precision the audit had not earned. The
following are candidate ceiling groups, not a finished tier list. Placement is
based on source-visible multipliers and target conditions; no percentage is
assigned until the same legal item and purchased-stat budgets are simulated.

| Scenario | Highest ceiling candidates | Why the ceiling can diverge |
|---|---|---|
| Stationary single-target sustained | Master Rogue, Dark Summoner, Dark Savior, Phoenix Ranger | crit singularity; multiple inherited bodies; density/BAT/on-hit scaling; attack ramp and BAT |
| Ten-second personal burst | Thunderblade, Elementalist, Assassin, Vampire | 2.1x magic multiplier; repeated INT coefficients/current-HP strike; concentrated AGI sequences; tri-stat Nova/Lord overlap |
| Dense target-rich AOE | Elite Marksman, Elementalist, Vampire, Dark Savior, Phoenix Ranger | uncapped cluster target count; repeated area strikes; Domain/Nova; splash on-hit setup; Searing/Multishot coverage |
| Enemy-HP-driven ceiling | Oblivion Guard, Elementalist | current-HP damage scales with the encounter rather than only the player's budget |
| Party-attributed damage | Crusader, Bard, Hydromancer, Royal Guardian | ally stat grant/echo; attack and Spellboost auras; vulnerability; immunity and enemy damage suppression increasing uptime |

An exact tier list should report, for each hero, three numbers relative to the
median: 60-second single-target damage, ten-second burst, and total damage to a
fixed dense pack. Supports need a fourth number: party damage attributable to
their buffs/debuffs. Ranking source formulas without those common inputs would
repeat the original report's mistake.

## 4. Scaling outliers

1. **Dark Summoner multi-body conversion:** INT inheritance converts one stat
   purchase into several simultaneous damage/utility bodies. This, not its
   natural INT growth, is the potential scaling outlier.
2. **Master Rogue crit chance:** at level 500, each additional crit-chance point
   gives about 7.89% relative expected physical output at the base 6% chance,
   versus 0.95% for a normal 5/100 hero.
3. **Royal Plate:** `0.006L^5 + 10L^2 + 25L` reaches 23,700 armor at L20 and
   also fuels Shield Slam. This removes the normal tank offense tradeoff.
4. **Spellboost compound users:** Elite Marksman Helicopter, Dark Savior Seal,
   Phoenix Ranger, and persistent AOE casters gain output from both amount and
   time/coverage. High Priestess/Crusader also gain group-wide defensive
   coverage, making their party return nonlinear in party size.
5. **Enemy-stat scalers:** Oblivion Guard current-HP strikes and Elemental Storm
   pure current-HP lightning do not fall off when enemy health budgets grow.
6. **Multiplicative defense:** general resistance, type resistance, armor, and
   post-mitigation shields multiply. Royal Guardian, Savior, Dark Savior,
   Crusader, and Bard can layer these without a shared cap.

## 5. Item interaction outliers

- **Master Rogue + crit chance:** strongest interaction by a wide margin. A
  crit-chance item worth 20 effective points can move expected attack output
  from 1.90x to 4.90x base, while a normal hero moves only 1.05x to 1.25x.
- **Royal Guardian + armor/Spellboost:** Royal Plate and Shield Slam make armor
  both defense and burst; Spellboost further multiplies the temporary armor.
- **Elite Marksman + Spellboost:** Helicopter gains damage, duration, firing
  rate, and target-count output. Test it separately at 1, 5, and 20 targets.
- **Dark Savior/Phoenix/Bloodzerker + BAT:** BAT bypasses the ordinary attack
  speed cap and raises on-hit proc frequency. Dark Seal and Blood Frenzy add
  another reciprocal BAT layer.
- **Vampire + tri-stat gear:** all three attributes have direct offensive and
  resource value; mixed pieces have much less opportunity cost than on other
  heroes.
- **Crusader + strongest carry:** Law of Might scales from the recipient's
  already item-inflated highest stat. Crusader gear and carry gear multiply
  rather than substitute.
- **Strength tanks + %max-HP shields/heals:** flat Strength provides HP, which is
  multiplied by armor/resistance and then protected/restored by max-HP effects.
- **Pure-damage item/ability effects:** disproportionately valuable after chaos
  armor because they skip the 0.03 modifier.

Potential item-system concern:

- Fixed percentage stats with flat-per-level syntax can become large while
  avoiding the main item multiplier. This is intentional parser behavior but
  should be included in item-budget spreadsheets.

## 6. Enemy matchup analysis

### Struggle

At wave `w` before wave 200:

```text
base HP     = 80w
base damage = 5w
base armor  = 0.75w
count factor = clamp(sqrt(12 / spawned_units), 0.55, 0.80)
```

Role, party, and count multipliers then apply. After wave 200, HP gains an
additional `1.0225^(w-200)` and damage `1.02^(w-200)`. Enemies switch to chaos
armor/attack at 200, with written damage divided by 350 to neutralize the type
switch. Each extra entrant adds 80% HP and 30% damage, plus special conversions.

Consequences:

- Compare wave 199 and wave 200 using effective HP and final applied damage,
  not raw object fields; the type switch and numeric compression are paired.
- Percent-current-HP and pure damage remain important because they bypass parts
  of conventional scaling, but the chaos label alone does not prove a jump.
- Uncapped AOE benefits from 25-40-unit waves; single-target burst must be
  rewarded by deleting ranged/fury/miasma specials quickly.
- Tank/healer party scaling is stressed by +30% incoming damage per entrant,
  but support multiplicativity can still outgrow this at six players.

### Colosseum

Difficulty snapshots entrant average level and each entrant's highest total
attribute. For normal waves:

```text
wave multiplier = 0.95 + 0.05*wave
count multiplier = 10 / spawned_count
HP ~= (avg_highest_stat + avg_level*50*wave_mult*party_HP*count_mult)*role_HP
damage ~= (avg_highest_stat + avg_level*5*wave_mult*party_DMG*count_mult)
          * role_damage * late_damage_multiplier
armor ~= (0.0003*avg_highest_stat + avg_level*0.75*wave_mult)*role_armor
```

Bosses replace 50/5/0.75 with 1000/50/2. Extra players add 65% total health and
10% damage. From level 200 onward the late damage multiplier adds 0.06 per
level; chaos armor begins at 200 and chaos attacks at 250.

Because only highest attribute is sampled, specialized offense determines both
enemy HP and damage even when the player sacrificed EHP to obtain it. Balanced
and tank builds can therefore be easier than glass-cannon builds at the same
level. Honor bonuses intentionally apply after the snapshot.

### Matchup summary

- High armor: Hydromancer/Elementalist/Arcanist/Thunderblade gain relative to
  physical carries; Master Rogue, Phoenix Ranger, and Bloodzerker depend on
  penetration/debuff uptime.
- Chaos-era enemies: compare final time-to-kill after the content's HP/damage/
  armor compression. Flag only specific unadjusted damage paths rather than the
  representation scheme as a whole.
- Very high HP: Oblivion Guard and Elementalist gain from current-HP mechanics;
  fixed-coefficient burst loses relative value.
- Dense waves: Elite Marksman, Phoenix Ranger, Vampire, Elementalist,
  Hydromancer, and transformed Dark Savior gain most.
- Mobile/split targets: stationary zones, Dark Seal density, Phoenix ramp, and
  summon pathing lose value; Assassin, Thunderblade, and Arcanist mobility gain.
- Long attrition: High Priestess, Bard, Crusader, Vampire, and Bloodzerker have
  much higher effective contribution than short dummy tests show.

## 7. Findings by confidence

### High confidence

- Master Rogue crit-chance conversion is many times the normal marginal return.
- Royal Plate's formula reaches 23,700 armor at rank 20 and Shield Slam consumes
  current armor offensively.
- Spellboost has compound effects well beyond displayed spell amounts.
- Boss party scaling has been corrected to apply a stable 20% of baseline
  damage and Strength per additional nearby player, including the existing
  five-second nearby-count linger.

### Medium confidence

- Elementalist is a top general-caster candidate at equal total stat and item
  budgets because repeated coefficients, mode buffs, and a percent-HP ultimate
  point the same way. Natural INT growth is not a meaningful endgame advantage.
- Crusader and Bard can be composition-mandatory in six-player parties because
  their output scales across every ally.
- Elite Marksman has a pathological target-rich Helicopter ceiling. Real target
  acquisition and projectile travel may cap realized output.
- Royal Guardian's defense/offense frontier dominates other tanks during Royal
  Plate/Fight Me windows. Cooldown downtime may keep whole-fight averages sane.
- Dark Summoner INT scaling is above the normal curve, but summon death/pathing
  can create a large realization penalty.

### Low confidence / requires logs

- Exact whole-fight DPS ordering among Warrior, Bloodzerker, Phoenix Ranger,
  Assassin, and Thunderblade.
- Exact best-in-slot lists for all 19 heroes; rolled item quality, saved
  availability, and inherited object fields need runtime export.
- Mana starvation outside the obvious percentage-cost abilities.
- Real six-player support value under movement, deaths, dispels, and range loss.

### Resolved boss Strength regression

This was not a claim that boss balance intentionally used a hidden Strength
formula. Git history showed that the refactor had mistranslated this code:

```text
flat damage bonus = native base damage * 0.2 * (players - 1)
bonus Strength   += base Strength * 0.2 * (players - 1)
```

The broken translation instead did the equivalent of:

```text
BossRecord.damage_percent = 100 + 20 * (players - 1)
UnitWrapper.bonus_str     += base Strength * 20 * (players - 1)
```

It had three separate issues:

1. `damage_percent` uses multiplier units (`1.2`, not `120`) on `Unit`, while
   the code writes percentage-looking units to the unrelated `Boss` record.
   No code reads that Boss field, so the intended extra damage is not applied.
2. Strength changed from `0.2` to `20`, a 100x translation error.
3. The periodic loop uses `+=`, so even the old 20% value accumulates every
   second instead of representing a stable party-size bonus.

The implemented fix preserves the apparent original intent—20% of baseline
damage and 20% of baseline Strength for each extra nearby player—and stores the
previously applied party bonus so it can apply only the delta when the effective
nearby count changes. This avoids overwriting unrelated buffs and preserves the
five-second nearby-count linger. If Strength was only intended as an indirect
way to add boss HP, a later balance change can replace it with an explicit
baseline-HP bonus so primary-attribute attack damage is not also increased.

## 8. Most important balance problems

1. **Master Rogue's crit-chance singularity.** The passive creates 16x crits at
   level 500 and then multiplies crit chance by 1.2. Crit chance becomes roughly
   8.3 times as efficient at the base point as it is on a default hero. A shared
   item budget cannot price crit chance fairly for both.
2. **Royal Plate's fifth-power curve.** At rank 20, 23,700 armor means roughly
   1,186x raw physical EHP during the buff before further resistance, and that
   armor also becomes Shield Slam damage. There is almost no offense/defense
   opportunity cost.
3. **Spellboost is an unpriced bundle of dimensions.** It can multiply amount,
   duration, area, count, chance, cooldown frequency, shields, and crowd-control
   duration. A 20% item may be near 20% on one spell and over 30-40% total-value
   gain on another before target-count effects.
4. **Uncapped party multipliers.** Law of Might, Resonance, Aura of Justice,
   Inspire, Song of War, Fight Me, and general vulnerabilities scale with every
   ally. Personal-versus-party balance changes drastically from solo to six
   players.
5. **Infernal Strike's boss reduction is selected by the primary target.** The
   splash loop checks `target` rather than each `u`; players can potentially
   strike a nearby non-boss to bypass the boss half-damage rule.

## 9. Recommended test cases

Add combat-log scenarios rather than relying on floating numbers:

1. Export a runtime snapshot for each hero at levels 100, 200, 350, and 500:
   final attributes, weapon damage, BAT, attack-speed bonus, armor, `dm/mm/pm`,
   `dr/pr/mr`, crit, Spellboost, and all eight equipped-item stat tables.
2. Use four fixed targets: 0 armor/normal defense, 400 armor/normal defense,
   400 armor/chaos defense, and a chaos boss. Give each 10 million and then 1
   billion HP to expose percent-HP scaling.
3. Measure 60-second and 10-second windows separately. Record raw event damage
   by tag, applied damage, casts, attacks, crits, target uptime, and mana ending.
4. Run every DPS hero at 0/20/40/60% crit chance. Master Rogue should be graphed
   separately; compare observed slope to `1+c*d/10000`.
5. Run every Spellboost user at 0/25/50/100%. Log damage, hits, targets, radius
   contacts, duration, and casts. Assault Helicopter and persistent AOE require
   1-, 5-, and 20-target versions.
6. Royal Guardian: log armor and physical EHP at every Royal Plate rank, with
   and without an existing shield; then log Shield Slam from the same states.
7. Crusader Resonance: hold raw attack constant while independently changing
   attacker `dm`, target `dr`, armor, penetration, shields, and chaos defense;
   the echo should remain its stated percentage of the surviving attack.
8. Blood Cleave: compare its heal with the sum of applied cleave damage under
   target `pr/dr`, source `dm/pm`, crit, evasion, armor, penetration, shields,
   and chaos armor.
9. Boss party scaling: keep one boss engaged for 60 seconds with two players and
   log Strength/max HP/damage each second; players entering/leaving should return
   stats to stable plateaus rather than accumulate.
10. Supports: test solo, 3-player, and 6-player parties. Attribute total party
    damage and prevented damage to Bard/Crusader/Guardian/Priest rather than
    reporting only their personal numbers.
11. Summoner: compare target-dummy ceiling with a moving boss course and a
    high-AOE boss. Report summon alive-time and travel-time loss.
12. Item frontier: for each proficiency family, export damage-max, defense-max,
    and balanced legal eight-item sets, then swap one item at a time to calculate
    marginal DPS/EHP. This supplies the missing exact opportunity-cost curves.

## Recommended balance order

Do not start with broad coefficient nerfs. First verify the corrected boss
party scaling, Resonance, and Blood Cleave behavior in-engine. Then build the
runtime snapshot/log harness and establish the three fixed-target benchmarks
using equal purchased-stat budgets and legal item packages. After those
correctness checks, address crit chance for Master Rogue and Royal Plate's
curve. Natural level-growth differences do not need endgame normalization
because the shared tome cap already normalizes them. Tune party support and
Spellboost only after the corrected measurements.
