# Spell stat split

Spell Power scales supported damage, healing, shields, and other potency bonuses.
Spell Area scales supported effect radii and travel distances. It does not
universally modify native ability cast range. Spell Duration scales supported
effect durations and lifetimes, not cooldowns.

## Item definitions

- `[spellpower #]`: power only.
- `[spellarea #]`: area bonus in percent.
- `[spellduration #]`: duration bonus in percent.

All three support the existing item stat formula syntax. Old `[spellboost #]`
definitions remain accepted. Set and Chaotic Set classifications (8 and 22)
receive only power. Other legacy definitions retain their previous utility:
area and duration each equal half the calculated power value. These derived
bonuses share the original quality roll and do not consume extra saved rolls.
An explicit area or duration formula replaces the respective derived bonus.
New power formulas never imply area or duration.

Existing power storage keeps its enum index and internal `spellboost` field;
area and duration are appended item stats. The runtime multipliers are `BOOST`
(full power with variance), `LBOOST` (half-strength power), `ABOOST` (area), and
`DBOOST` (duration). Ability consumers use the appropriate multiplier rather
than treating utility as half-strength power. Hero multipliers refresh on the
existing periodic refresh cadence.

Perks provide separate investment branches for power, area, and duration.
Stat View lists the three stats separately and paginates the Stats tab at 28
rows per page.

## Verification

`tools/test_spell_scaling.lua` is an offline Lua test for definition migration,
shared legacy rolls, fractional utility values, tooltip multiplier selection,
and pagination. The shipped architecture tests also exercise definition
migration without requiring the disabled Warcraft `io` or `debug` libraries.
Host tests do not establish native rendering or real combat timing.

In game, compare a Spellboost set with a non-set Spellboost item: only the
non-set item should retain area/duration. Allocate each utility perk branch
separately and check an ability with a scaled radius and timed effect, including
its Alt tooltip. Allow the normal refresh tick after changing equipment/perks.
Check both Stats pages and switch to other tabs to verify paging controls hide.
