# Hero spell scaling audit

Source audit, 2026-10-10. Scope: the 19 hero spell modules, their hero buff
consumers, the common spell tooltip parser, and selected current native ability
tooltips resolved from the builder's W3A/WTS files. This is not an in-game
validation or a claim that every native secondary ability has been verified.
The findings below record the initial audit. The first implementation pass now
fixes Comets' Power/impact radius and active-sphere lookup, Bard song membership,
Whirlpool/Blood Lord duration, Railgun explosion radius, Justice's active range,
and Missile Strike's second damage tag. Arcanosphere now scales its radius and
visual together; Whirlpool and Railgun art also track their effective area.
Frozen Orb's freeze tooltip now reflects its already-existing Duration scaling.
Bard songs and Body of Fire have explicit notes for their delegated scaling.
Assault Helicopter's inverse interval behavior and the balance decisions below
remain unchanged.

Second pass approved by the map owner: Bladestorm, Protection, and Gaia Armor's
shield now use Duration. Protection's buff and shield share the same scaled
lifetime. Gaia's base shield duration is aligned with its documented 30 seconds
(previous runtime was 31); its fatal-save mechanics are untouched. Bladestorm
retains its existing .33-second damage cadence and tick rounding. Their native
duration lines are tagged at runtime for Alt values and scaling notes.
Blood Domain explicitly remains fixed at five seconds to avoid excessive
Agility-build uptime. This supersedes their initial omission findings below.
Blood Frenzy was subsequently approved for Duration scaling as well; its base
five seconds, 15% health cost, and cooldown are otherwise unchanged.

## Proc-chance inventory for a possible Luck stat

Player-side random ability families identified in the current Lua code:

| Effect | Current chance treatment |
| --- | --- |
| Blood Cleave | 20% base, half-Power multiplier; Rampage/Rage modify the base chance. |
| Bladestorm electrocution | 15% base, half-Power multiplier. |
| Fiery Arrows | 2% per ability level, half-Power multiplier. |
| Control Time | Fixed 15% chance to reduce selected spell cooldowns. |
| Piercing Strike | Fixed 20% chance to apply its armor-penetration buff. |
| Destroyer Annihilation Strike | Fixed 10% + 2 percentage points per summon tier. Damage uses half Power separately. |
| Adaptive Strike / Limit Break | Chance to omit the normal recast lock: 25%, or 50% when empowered. |
| Equipment shield Block | Chance comes from the item's calculated ability stat; not Power-scaled. Shared family across seven registered IDs. |

Critical strike and evasion also have random rolls but already have independent
stats; they are not ordinary proc candidates by default. Cosmetic randomness,
random target/element selection, loot quality, and potion rerolls are not proc
chance. Guaranteed every-N-attacks effects are not random procs either.

This inventory justifies a future dedicated proc-rate stat, but currently only
three of these families inherit Spell Power for their odds. A Luck migration
must explicitly decide the scope and caps; blindly multiplying all random
checks would buff defensive Block, reset chances, critical strike, and evasion
in ways the current half-Power rules never did. No Luck stat or odds changes
were implemented here.

`BOOST` is full Spell Power with cast variance; `LBOOST` is half-strength
Spell Power without that variance. `ABOOST` is Spell Area; `DBOOST` is Spell
Duration. A missing multiplier is not automatically a bug: resource costs,
self-damage, cooldowns, proc suppression markers, aura refresh grace periods,
and manually maintained channels should not receive blanket scaling.

## Strong mismatches

| Hero / spell | Evidence | Likely correction to consider |
| --- | --- | --- |
| Arcanist — Arcane Comets | Tooltip advertises `[dmg]` and `{aoe}`. `comet_land` deals raw `self.dmg`; `spawn` passes the Arcanosphere timer's `pt.aoe` instead of the comet's own 250 AoE. Enemy acquisition separately uses a fixed 800. | Apply Power to damage; distinguish sphere search radius from comet impact radius and scale each only once. Also verify the sphere timer lookup actually finds a live sphere: this module does not visibly register it in TimerList. |
| Bard — all four ongoing songs | Initial enumeration uses `900 * ABOOST`, but all four final `IsUnitInRange` checks still use 900. Positive Area therefore cannot extend the actual hero-centered song radius. Improv's separate radius check does use its stored scaled radius. | Use one shared scaled song radius for enumeration and final checks. |
| Hydromancer — Whirlpool | Tooltip `{dur}` uses Duration. `onCast` adds the Infused Water bonus to raw `self.dur` and starts the countdown without multiplying by `DBOOST`. Area and Power are applied. | Scale the chosen total starting duration once, then preserve the intended faster expiry per enemy. |
| Vampire — Blood Lord | Tooltip `{dur}` advertises Duration; buff is applied for raw `self.dur`. Its buff damage does use Power and its automatic pulse uses Area. | Apply Duration to the actual transformation lifetime. |
| Thunderblade — Railgun | Tooltip `{aoe}` advertises Area; explosion uses raw `thistype.aoe` and the same unscaled value sizes its explosion effect. | Scale explosion radius and matching art. The search range is explicitly an unscaled `\\range` tag, so changing travel/search distance is a separate choice. |
| Crusader — Aura of Justice | Passive aura enumeration uses `900 * ABOOST`; active shield enumeration remains fixed at 900. Shield strength uses half Power and lifetime uses Duration. | Decide whether active and passive ranges should agree; if yes, share the same scaled radius. |
| Elite Marksman — Assault Helicopter | `values.cd` already divides the base rocket interval by `LBOOST^2`; the runtime multiplies it by LBOOST once, yielding base/LBOOST. Tooltip `{cd}` also multiplies once, but its generic scaling note suggests ordinary half-Power improvement rather than a faster firing interval. | Preserve or intentionally redesign the inverse interval formula; describe faster rocket firing explicitly. Do not multiply the interval as though it were damage. |
| Elite Marksman — Hand Grenade / Missile Strike | Missile Strike advertises the `[dmg]` tag used by the normal grenade, but the runtime rocket uses `self.dmg2 * heli.boost`. Their base damage formulas differ. | Use the second damage value in the second tooltip section; account for the helicopter's captured Power multiplier. |

Evidence files: `src/content/abilities/heroes/arcanist.lua`, `bard.lua`,
`hydromancer.lua`, `vampire.lua`, `thunderblade.lua`, `crusader.lua`, and
`elite_marksman.lua`.

## Missing or uneven compatibility worth a balance decision

These are real omissions/irregularities, but not sufficient evidence of an
implementation error without deciding which mechanics should scale.

- **Warrior:** Wind Scar has Power damage, but both ordinary and Limit Break
  collision radii are fixed (150/120); Adaptive Strike tornado collision is
  fixed at 200 while its other effect radii use Area. Wind Scar's flight/orbit
  windows are fixed. Spin Dash's debuff lasts a fixed two seconds. Those are
  different questions from scaling its recast window or movement speed.
- **Thunderblade:** Bladestorm has Area, Power damage, and half-Power proc
  chance, but a fixed approximately three-second lifetime (`pt.dur=9`,
  decremented every .33 seconds). Omnislash deliberately scales hit count
  with half Power, not Duration. That is an unusual but coherent potency choice.
- **Elementalist:** Gaia Armor's shield scales with Power, but its lifetime is
  fixed at 31 seconds (native text says 30). Its fatal-save healing/mana,
  400-radius burst, and four-second stun do not use Power/Area/Duration.
  Frozen Orb scales icicle search and shatter radius with Area, and freeze
  with Duration; its travel limit is fixed, and the native freeze tag is
  explicitly unscaled despite the runtime applying Duration. Elemental Storm
  has deliberately fixed strike count; its two-second freeze and ten-second
  Earth debuff are also fixed. Do not treat count as a duration automatically.
- **High Priestess:** Protection's shield magnitude/radius scale, but both its
  shield and attack-speed buff use fixed `20 + 10 * level` lifetimes. Divine
  Light's auxiliary three-second buff is fixed. Invigoration's healing scales
  with Power but its mana restoration does not. Its maintained channel has no
  finite duration to extend.
- **Royal Guardian:** Shield Slam has Area and Power, but its primary three-
  second and splash 1.5-second stuns are fixed. Steed Charge's one-second
  collision stun and +100 movement bonus are fixed even though mounted
  lifetime uses Duration. Extending charge motion itself is a separate choice.
- **Oblivion Guard:** Gatekeeper's Pact's five-second stun is fixed; Meteor's
  stun scales with Duration. Infernal Strike's damage uses half Power but its
  percentage-health leech is fixed. Body of Fire applies Power to its returned
  damage, while the native `\\dmg` tag is explicitly unscaled and the new gray
  note therefore misses that compatibility.
- **Assassin:** Blink Strike's six-second bonus buff and Phantom Slash's
  four-second Marked for Death debuff are fixed. Smoke Bomb correctly scales
  cloud Area/Duration, but evasion/slow potency is fixed. Whether those capped
  bonuses should receive Power needs an explicit balance decision.
- **Master Rogue:** Hidden Guise's two-second invulnerability is fixed, as is
  Piercing Strike's three-second proc buff. These need not scale just because
  Death Strike/Nerve Gas use Duration. **Nerve Gas deliberately divides damage
  per tick by the scaled duration**, so Duration extends control and spreads
  approximately the same total damage over more time rather than raising DPS.
  Live multiplier changes during the debuff can disturb that total: damage
  denominator and Power are recomputed each tick, lifetime was set on application.
- **Phoenix Ranger:** Ignite/Burning five-second debuff lifetimes are fixed,
  while Flaming Bow's lifetime scales. Fiery Arrows' proc chance uses half
  Power; direct/on-hit damage uses full Power. Scaling a proc chance and its
  damage together gives compounded benefit, not a simple one-for-one damage
  increase. The same applies to Blood Cleave and Bladestorm.
- **Bloodzerker:** Blood Frenzy's five-second buff is fixed while Undying Rage
  uses Duration. Blood Cleave scales both proc chance (half Power) and damage
  (full Power). Rage's stored incoming-damage recovery is not ordinary spell
  healing and should not receive a blanket multiplier.
- **Vampire:** Blood Domain's five-second lifetime is fixed; its damage and
  radius scale. Blood Bank generation/capacity and Blood Lord's bank-based
  attribute conversion are unscaled resource mechanics, not necessarily omissions.
- **Dark Savior:** Dark Blade's demon-form splash radius is fixed at 300;
  nearby other effects use Area. Dark Ascension's damage multiplier is based
  on sacrificed/current health rather than Power; the granted Dark Blade does
  have Power damage. Its current gray note only identifies Duration.

Dark Summoner's core summon attributes already use half Power, its later
sacrifice/ascension effects use their separate Area/Duration multipliers, and
Savior's main damaging/healing abilities use Power and their supported utility
multipliers. No strong missing-scaling defect was identified in those sampled
paths. This does not imply all passive bonuses must scale.

## Tooltip system limits

- The gray note currently describes dynamic tags, not all runtime effects.
  Fixed text for a scaled radius, delegated buff logic, or a skill with no
  `values` table can omit a genuine compatibility. Bard's ongoing songs and
  Body of Fire are examples. Explicit `scaling_note` metadata is available.
- A tag marked unscaled (`\\`) is not proof the implementation is unscaled:
  Frozen Orb freeze and Body of Fire's return damage contradict that convention.
- The advertised `tooltip_scaling = {tag = "power"}` override currently falls
  through to half Power; there is no explicit full-Power branch for `{...}`.
  Existing `[` tags remain full Power. This is a latent API inconsistency,
  not evidence that an existing hero has already selected that override.
- A single note saying "Power" can conceal differences between shield/heal,
  proc chance, hit count, summon attributes, and inverse firing intervals.
  Targeted wording is better than implying every component scales equally.
- Periodic effects often round to ticks. Duration increases need not change
  outcomes smoothly. Keep aura refresh timers and duplicate-hit markers fixed;
  audit actual effect lifetimes rather than scaling every number named `dur`.

## Recommended implementation order

1. Resolve the strong runtime/tooltip mismatches first, with per-spell tests.
2. Make the radius inconsistencies agree, keeping projectile collision versus
   impact radius and search radius distinct.
3. Decide a consistent policy for stuns, damage-over-time totals, transformation
   lifetimes, and passive proc strength; keep costs/cooldowns/resource mechanics
   separate.
4. Give delegated/mixed effects explicit compatibility metadata, then test with
   each of Power, Area, and Duration changed independently in game.
