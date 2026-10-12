# Scarab boss implementation basis

Status: model imported, arena prepared, and a development-only encounter slice
implemented in `src/gameplay/dungeons/scarab/boss.lua`. Nothing spawns at map startup.
Normal crawl access, boss multiboard integration, time mechanics, and rewards
remain unimplemented. No map object definitions were changed for this slice.

The implemented skills and proposed follow-ups are summarized for testers in
[SCARAB_BOSS_TESTER_BRIEF.md](SCARAB_BOSS_TESTER_BRIEF.md).

## Testing the first encounter slice

Use a living hero, preferably with max-upgrade Azazoth equipment:

1. `-scarabboss enter` — enter the saved arena with an instant camera snap.
   Each tester enters independently. The boss is invulnerable while staged.
2. `-scarabboss fight` — start combat once the party is ready.
3. `-scarabboss status` — show attempt time, scaling high-water mark, and brood count.
4. `-scarabboss leave` — restore the tester's previous position and camera.
5. `-scarabboss stop` — return remaining testers and remove the whole prototype.
   Use this after a kill before creating another test encounter.
6. Before starting combat, `-scarabboss anim spell / channel / slam / throw / walk / stand`
   previews the selected native unit sequence without enabling attacks.

Entering from the crawl first leaves it and restores the pre-crawl location.
The prototype does not yet provide a doorway back into its logical approach room.
Death, repick/cleanup, and walking outside the arena release the player's camera.

Implemented mechanics and provisional solo values:

- 1.5 billion HP, 1.5 million base attack damage, 650 armor, Chaos attack/armor.
- Frontal Slam: an eight-second schedule, 1.5-second stationary warning,
  1,000 range, 120-degree full cone, four million spell damage before mitigation.
  The warned origin/direction is fixed; dodging behind the boss works.
  Uses Spell Slam and the existing Azazoth `Indicators\wide cone.mdx`, scaled
  to its approximately 1,100-unit outer edge. MDX geometry spans roughly +/-60°.
- Brood discharge: a two-second channel on a 22-second schedule, up to six
  beetles per wave with a hard cap of 12 living summons. Existing waves are not
  replaced or multiplied without limit. Brood uses the crawl's swarm stats.
  Uses Spell Throw for the discharge. Melee crawl units and brood receive native
  Ghost (Visible), `Aeth`, to permit swarm overlap without disabling wall pathing.
  Ghost behavior still needs an in-game test. Summons lose their native guard
  position and check pursuit every half-second; valid targets are retained,
  while death, invisibility, invulnerability, or leaving the arena allows retargeting.
- Party scaling keeps the largest simultaneous eligible hero count for the pull.
  Incoming damage follows the crawl/Naga `.9` solo to `.4` at six convention;
  boss attacks gain 20% of solo damage per additional hero. Joining does not heal it.
- Five seconds with no living, non-invulnerable participants, or leaving the
  arena bounds, resets the boss, clears casts/brood/debuffs, heals it, and stages
  it again. One player leaving does not reset a continuing fight.

The boss uses the existing `U000` unit directly. Its editor model, portrait and
selection geometry are preserved; the imported model can be assigned in the
editor later. There is no attached presentation effect or movement/animation
polling controller. Native orders handle walking and attacks, while scripted
casts use named unit animations (`spell slam` and `spell throw`). The camera
inset is 850 units. Final impact frames, selection behavior and combat balance
require an in-game test. The warning timer remains authoritative. This is not
yet the normal Boss registry/multiboard integration.

## Runtime Spell View integration

`gameplay/abilities/runtime_spells.lua` defines stable string keys rather than
pretend FourCC abilities. `RuntimeSpells.define(key, spec)` registers the skill's
name, icon, description, cooldown, range/area, and optional passive status.
`RuntimeSpells.bind(unit, keys, context)` selects a per-unit skill list;
`RuntimeSpells.unbind(unit)` removes it during encounter cleanup.

Descriptions and remaining cooldowns can read encounter context through callbacks.
Spell View displays runtime bindings instead of template abilities, without
native ability queries; it refreshes binding revisions, cooldown overlays, and
hovered descriptions. Existing native/`Spells` tooltip behavior remains unchanged
for unbound units, including other units with the boss template's same FourCC.
This API provides presentation, not casting or a save format. Gameplay timers
remain the authoritative cast/cooldown state.

Current keys: `scarab.frontal_slam` and `scarab.brood_discharge`. Their native icon
paths are listed in Warcraft's legacy Undead ability definitions (`BTNImpale.blp`
and `BTNLocustSwarm.blp`); actual frame rendering still needs an in-game check.

The map owner has visually identified Spell as the single-target stinger and
Stand Channel as a possible drain follow-up. Those mechanics are reserved for
the next design pass, not silently added to the provisional slam/discharge fight.

`tools/test_scarab_boss.lua` exercises the real module with offline native mocks:
startup guards, missing-region rejection, staging, cone geometry/dodging,
summon caps, scaling, reset, defeat, timer cancellation, and cleanup. It does
not validate Warcraft rendering or establish final combat balance.

## Model

Source: https://www.hiveworkshop.com/threads/silithid-devourer.289671/

The original main-model archive is staged under
`builder/.build/asset-downloads/silithid-devourer/`. Its MDX was read directly;
no model or texture edits were made. Imported map paths:

- `Silithid Devourer.mdx`
- `Silithid Devourer.blp`
- `AbdomenGlow.blp`

The two BLP paths match the MDX texture references exactly. Remaining texture
references are native `Textures\RibbonBlur1.blp`, `Textures\BloodSplash.blp`,
and replaceable team-color/glow slots. The separate portrait model has not been
downloaded/imported yet. Keep credits in the project's existing external credits,
not the repository README.

Verified sequence names and original intervals (milliseconds):

| Sequence | Interval | Duration |
| --- | --- | --- |
| Stand - 1 | 333–1333 | 1,000 ms |
| Walk | 2000–3000 | 1,000 ms |
| Attack - 1 | 3666–4533 | 867 ms |
| Attack - 2 | 5333–6466 | 1,133 ms |
| Spell | 7000–8500 | 1,500 ms |
| Spell Slam | 9000–9766 | 766 ms |
| Stand Channel | 10000–10800 | 800 ms |
| Death | 11333–13333 | 2,000 ms |
| Dissipate | 13666–15666 | 2,000 ms |
| Spell Throw | 16000–16933 | 933 ms |

These are sequence lengths, not verified impact frames. Inspect the animations
visually before deciding which corresponds to the requested sting or discharge.
Do not assume the hit lands at the end of a sequence. The resource page points
to its contest test map for animation/spell examples.

## Dedicated physical arena

Recommend a seventh, persistent area roughly 3,500–4,000 units across, rather
than borrowing one of the six crawl buffers. Six explorers can occupy six
different logical rooms; reserving one buffer for the boss reduces that capacity.
The arena should not be recycled while the boss encounter exists or players
arrive separately. Keep the boss's own participant/aggro/leash/reset state distinct
from chamber occupancy.

The current cave corner uses six 2,624×3,136 buffers centered at x=-27712,
-24832, -21952 and y=22208, 26816. All six remain unchanged.

The saved editor region `gg_rct_Scarab_Boss_Arena` supplies the dedicated arena:

- Bounds: x=-19936…-16032, y=25920…30688.
- Dimensions: 3,904×4,768 units.
- Center: (-17984, 28304).
- Horizontal clearance from the crawl footprint: 704 units.

Use that region rather than a guessed 4,000-unit square. The editor terrain and
region were prepared by the map owner; no programmatic terrain edits were made.

## Proposed first vertical slice

1. Dedicated arena, instant arrival camera, staged entry before combat, and
   normal boss preview/aggro/reset integration. Arrival may be independent;
   encounter party scaling should not fall when someone retreats or dies.
2. A clearly telegraphed frontal sting using the verified animation/impact frame.
   Tune the hit and optional short poison debuff against max-upgrade Azazoth gear.
3. A channel/discharge mechanic tied to the second distinctive model animation.
   First choose whether it releases brood/eggs or an arena hazard; avoid creating
   unbounded summons or unavoidable arena-wide damage.
4. Add the accepted time theme after the core fight works: positional Recall,
   telegraphed sand hazards, then capped Curse of Time pressure. Its clock starts
   with the boss fight, not the dungeon crawl, and resets only on a genuine reset.

The main dungeon plan remains the source for the accepted time-theme constraints.
Room-clear rewards, boss rewards, hard access requirements, final numbers, and
entry/access rules remain separate decisions, not implemented defaults.
