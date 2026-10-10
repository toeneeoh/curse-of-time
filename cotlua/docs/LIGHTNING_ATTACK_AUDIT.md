# Lightning attack migration

Checked `builder/CoTN-RPG-1.36.w3x/war3map.w3a` and
`war3mapSkin.w3a`. Gameplay fields and skin fields are separate; both must be
consulted. `gameplay/abilities/tools.lua` now owns the native visual settings.

| Original ability | Lightning (`alig`) | Graphic duration (`Lit2`) | Uses |
| --- | --- | --- | --- |
| A01Y | CLSB | 1 second | Medean Lightning, its Dark Seal augment, Bladestorm |
| A09D | DRAL | 1 second | Blood Siphon, initial and periodic drains |
| A09Q | YENL | 1 second | Holy Rays (previously migrated, now shares the helper) |
| A09R | MBUR | 1 second | Naga Spirit Call |
| A09W | CLPB | 1 second | Elementalist Lightning element |
| A0A1 | AFOD | 1 second | Blood Leech |
| A010 | RAIL | 1.5 seconds (script override) | Railgun; editor Lit2 is 5 seconds, shortened on request |

Target art and attachment points also match `atat` and `ata0`: A01Y uses
BoltImpact at chest, A09W uses BoltImpact at origin, A09R uses FarseerMissile
at chest, and A09Q uses HolyBoltSpecialArt at origin. The others have no target
art. Effects use their model death animation, like the existing Holy Rays fix.

All eight remaining spell/buff dummy attack call sites were replaced. Damage,
healing, and debuffs are applied explicitly, with their original source, formula,
and cadence; they no longer wait for the engine's dummy attack hit event. Drain
beams retain their reversed direction and corpse visuals. The unused
`Dummy:lightning` point helper also uses a native beam rather than attacking a
new target dummy. Ordinary spell-casting and positional dummies remain.

Beams are instant at the scripted hit and use fixed endpoints. A010's editor
graphic delay (`Lit1 = 1`) is not added to Railgun's existing charge/hit timing.
The other migrated abilities all have `Lit1 = 0`.

Other Alit-derived records were inspected:

- A08B has no lightning type and uses SpiritDragonMissile(Red) as a real Phoenix
  Ranger weapon projectile. It is not a lightning dummy and was left intact.
- A014 (FINL, 1 second) and A05J (BULL, 6 seconds) have no runtime ability
  references. Marksman's existing native BULL beam has its own scripted timing;
  it does not use A05J and was not changed.

`tools/test_lightning_attacks.lua` reads both binary object files and checks the
actual helper's lightning IDs, lifetimes, target art, and cleanup calls. Offline
mocks cannot establish native rendering or sound parity.

In-game checks: Medean Lightning with/without Dark Seal, Bladestorm procs,
Lightning element, Blood Siphon including corpses, Blood Leech, Naga Spirit Call,
Holy Rays, and Railgun. Check beam direction, impact art/sound, damage/debuffs,
expiry, and repeated casts without dummy-dependent hit failures.
