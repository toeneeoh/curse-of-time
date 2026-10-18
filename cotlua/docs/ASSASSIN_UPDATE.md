# Assassin focused update

Implemented October 17, 2026 from the owner's approved feedback proposal.

- Smoke Bomb is untargeted and instant, with a 450 base radius and eight-second
  base duration. The cloud follows Assassin. Spell Area and Spell Duration apply
  to the radius and cloud lifetime. Ally evasion and enemy slow are retained.
- Smoke applies its aura immediately, then refreshes it every half second.
  The visual follows every 0.1 seconds and runs at 1.5x speed. The ability uses
  Berserk's alternate order queue (`Absk` / `berserk`), distinct from Phantom
  Slash (`immolation`) and manual Spin (`manashieldon`). It does not change the
  hero's cast point or animation speed. Native Berserk bonuses are zeroed.
- Assassin receives a separate +100% physical-evasion buff for exactly three
  seconds, unaffected by Spell Duration. It stacks additively with ordinary
  Smoke evasion and removes only its own contribution. Recast replaces the old
  cloud; cancellation/death clears its remaining opening protection.
- Smoke costs 15% maximum mana instead of 20%; its cooldown remains 20 seconds.
- Blink Strike replaces its spirit-puff ring and old target impacts with one
  darker-green `war3mapImported\dustwaveanimate2.mdx` wave at the destination
  (RGB 140/210/150).
  It explicitly plays the model's non-looping Stand animation at 2x speed
  (438 ms), scales its roughly 300-unit authored radius to 1.45x the spell area,
  and hides/destroys the handle after 0.6 seconds. Native BlinkCaster and
  BlinkTarget bursts appear at the departure and actual arrival positions. The original MDX is unchanged. Its only texture,
  `meteor2.blp`, is imported at the map root to match the embedded texture path.
- Blade Spin radius is 350 instead of 250. Active and passive damage are both
  multiplied by 1.5 when the complete pre-damage target list contains one enemy.
  This makes isolated active/passive damage 6x/12x Agility before Spell Power.
- Phantom Slash readies one manual Spin at completion, including empty dashes.
  Multiple enemies cannot grant multiple charges, and
  readying an already-ready Spin does not recreate its native ability.
- Passive Spin's attack-count check now receives the source hero, matching the
  documented reduction to five attacks by level 300. Damage remains magical;
  existing physical evasion semantics and Dagger Storm's instant launch remain.

Smoke's Berserk base also requires the corresponding map object data. Apply `node cotlua/tools/update_assassin_smoke.js <map-directory>`
before packaging an unpacked map that has not received this update. The script
changes Smoke's base in both ability and skin object files, neutralizes native
Berserk effects, and retains other objects, cooldowns, and tooltip text. It is
idempotent. Assassin has no runtime tooltip rewrite hooks; the owner maintains
all native skill tooltip text and formatting.

Offline tests execute real Smoke/buff and PlayerTimer callbacks, Spin/Phantom
callbacks. They cover cleanup, recast,
fixed/scaled lifetimes, single/multiple targets, empty/successful dashes and
non-stacking readiness. The buff mock mirrors the real nil-returning
`Buff:duration`; the opening veil is stored before scheduling expiration, and
cleanup only removes a still-active matching buff, including after dispel. Native cast responsiveness, moving-cloud appearance,
animation transitions, multiplayer behavior and practical boss DPS remain
in-game checks.
