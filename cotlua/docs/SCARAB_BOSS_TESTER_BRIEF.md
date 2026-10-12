# Scarab encounter: tester brief

Only the first two skills are currently playable. Everything in the proposed
section is a design outline for feedback, not an implemented mechanic.

## Playable now

### Frontal Slam

- Spell Slam animation; the Scarab stops moving during a 1.5-second warning.
- A marked, 120-degree cone reaches 1,000 units in the direction selected at
  the start of the warning. It does not turn to follow the player afterward.
- Deals 4,000,000 spell damage before mitigation. No stun or drain is added.
- Scheduled every 8 seconds from the start of the fight; other casts can delay it.
- Counterplay: move behind the boss or outside the marked cone.

### Brood Discharge

- Spell Throw animation with a 2-second wind-up.
- Releases up to six beetles per wave, with a maximum of 12 living broodlings.
- Scheduled every 22 seconds; casts do not overlap with Frontal Slam.
- Broodlings: 40 million HP, 300,000 solo base damage, 550 armor, Chaos
  attack/armor, and 340 movespeed. Party scaling still applies.
- Broodlings keep pursuing valid targets, reacquire after losing their order,
  and do not require players to keep attacking them to maintain aggro.
- Counterplay: control/kill the brood and make room to dodge subsequent attacks.

Select the boss to inspect these two skills and their remaining cooldowns in
Spell View. This runtime skill list is independent of `U000`'s editor abilities.
The staged boss is paused and invulnerable until the fight is started.

## Proposed next skills — not implemented

### Parasitic Sting / Drain

A telegraphed, single-target stinger strike using **Spell**, followed by
**Stand Channel** to drain its victim. The intended counterplay is to break
the tether by moving away rather than being forced to stand still through a
long stun. Drain duration, break distance, damage, boss healing, and interrupt
rules need to be settled before implementation.

### Sands of Time

Clearly marked sand zones advance across the arena. Standing in them applies
a temporary aging penalty; staying mobile avoids it. The penalty's exact stat
effect is not settled. Do not assume a healing penalty is implemented.

The red liquid from **Spell Throw** could instead deliver a visible ground
hazard. If that direction is chosen, revisit the provisional brood animation
rather than making two unrelated skills indistinguishable.

### Recall

Mark recent safe player positions, show a clear delay, then return surviving
affected heroes to their own marked positions. This is a positioning challenge:
it does not restore HP, mana, potion charges, cooldowns, or dead players.
Return points must remain walkable and inside the arena.

### Curse of Time

Passive pressure that begins with the boss fight, not the crawl. The existing
provisional plan is a 60–90-second grace period, then +5% damage taken every
30 seconds, initially capped at +100%. It resets on a genuine wipe/reset, not
when one player briefly leaves. This is not a hard time-limit death mechanic.

## Test commands and useful feedback

1. `-scarabboss enter` for each participant.
2. Before starting: `-scarabboss anim stand / walk / spell / slam / throw / channel`.
3. `-scarabboss fight`, then select the boss and hover its skills.
4. `-scarabboss status` for elapsed fight time and scaling.
5. `-scarabboss leave` to return; `-scarabboss stop` to clean up before another test.

Check that the actual `U000` boss is visible, selectable and moves smoothly,
the cone matches its damage area, the brood does not lose
pursuit, and Spell View changes correctly between the boss and other units.
Report party size, hero/build, gear upgrades, and time to kill when discussing
damage/health tuning. Rewards and normal dungeon-to-boss entry remain unfinished.
