# Cave-kit test assembly

This is a separate development preview, not a conversion of the live crawl.
The cleared/flattened x = -30000…-20000, y = 20000…30000 corner is reserved
while it is running. A crawl and this preview cannot run simultaneously.
No new editor objects, terrain tiles, enemies or rewards are created.

Commands with a living hero outside another activity:

- `-scarab kit` builds the preview at scale 1.5 (20% larger than before) with a 3-unit floor lift.
- `-scarab kit 1 3` specifies uniform scale and floor lift. Allowed ranges:
  scale 0.75–1.75, lift 0–16. Stop the existing preview before changing these.
- `-scarab kitseed 12345 12` builds a seeded route of 12 chambers at scale 1.5.
  Seed and room count default to 1 and 12; allowed room counts are 4–40.
  Stop the existing preview before changing mode, seed or room count.
- `-scarab kitfloors 12345 6` builds larger party floors; defaults are seed 1,
  six floors, with 5–10 floors supported. This is the preferred test for the
  floor-based crawl direction; `kitseed` remains a directional-room comparison.
- `-scarab descend 1` uses numbered hole 1 in floor mode. Every participant
  must be alive and within 600 units of the selected hole. There is no automatic
  walk-over transition in this mode.
- `-scarab kitstatus` reports building/ready/closing state.
- `-scarab kitleave` returns to the entry position; last player leaving closes it.
- `-scarab kitstop` returns all participants and restores the original pathing.
- `-lamp on` / `-lamp off` toggles the same test lamp used by the crawl.
  The preview starts with the lamp on, black dungeon lighting, 800 hero sight
  with either lamp setting, and no backpack sight. The lamp toggles lighting
  artwork rather than reducing preview sight. The lamp model/radius
  and the actual crawl's 384/192 sight remain unchanged. No enemy detection
  workaround is implemented; wider sight must not be copied to gameplay yet.
  Use `-novision` if debug reveal is enabled; the preview does not change global fog.

If area readiness is disabled, first use `-scarab ready` **only after clearing
and flattening the corner in the editor**. Construction/restoration is batched;
players stay at their original positions until construction finishes.

Walk north from the narrow D cap through a, b and c, then around f's eastward
bend into g. From g, north leads into the wide h chamber; east and south end
in additional D caps. All four junction mouths are connected; no unused mouth
is blocked with an invisible cap. Nine assembled pieces cover all seven assets.

Models are `war3mapImported\Cave01_[a,b,c,D,f,g,h].mdx` (uppercase D).
Their naked `Cave01_D.blp` / `Cave02_D.blp` texture references are retained.
The measured floor lies at local Z=0. The small lift reduces terrain fighting;
it does not elevate the walkable terrain or create an actual second floor.

`kit_assets.lua` retains bounds and the material-2 floor triangles extracted
from the imported meshes. `tools/analyze_scarab_kit.js <import directory>` is
a read-only extractor. Other ground-level triangles belong to wall skirts and
are deliberately excluded. Per-model opening coordinates account for differing
origins; uniformly scaling all pieces preserves their matching tunnel widths.
The wide h chamber overlaps its junction by 4 model units (6 world units at
the default scale) to close the small visible seam. Its pathing moves with it.

## Fog-safe rendering trial and black exterior cover

These are special effects, not editor doodads, so an Animate in Fog setting
does not affect them. Whole-piece origins were disappearing outside sight even
when part of the tunnel was lit. The preview now uses generated 64-model-unit
sections, clipping triangles and interpolating UVs/normals without changing
the original cave files. Small sections have nearby render origins; this is an
in-game culling trial, not a claim that native fog sampling is pixel-exact.

Generated meshes live at `war3mapImported\ScarabKit\Cave01_<piece>_<index>.mdx`.
`kit_render_assets.lua` records offsets/bounds. Regenerate with:

```
node cotlua/tools/build_scarab_render_chunks.js <import-directory> <catalog-lua> <black-block-source-mdx>
```

The black-block source is D00H's model:
`Doodads\Cityscape\Structures\City_LowWall_ShortEndCap\City_LowWall_ShortEndCap.mdx`.
Its classic mesh was inspected from the local legacy archive (bounds about
60×60×90); current HD/DE geometry is not verified. D00H's RGB is 0/0/0 and its
editor pathing texture is empty. The preview reproduces that model and tint
using effects with custom X/Y/Z dimensions; it does not create D00H doodads.
Black cover is fitted outside the cave section bounds and divided into at-most
256×256 world-unit patches so the covers also avoid distant render origins.
An increased overlap of 36 units at scale 1.25 (43.2 at the new default 1.5)
brings the cover closer to the wall skirts and joins adjacent
patches without thin gaps. The overlap scales with the cave pieces so smaller
walls do not get swallowed. Cover height remains 140: very tall foreground
blocks could obscure the playable tunnel with the angled camera.
The covers are visual masking, **not** real light shadows or sight blockers.
They never expand hero sight or reveal enemies.

Fixed/directional previews spawn at most 12 scenery effects per timer tick, before teleporting
players in. Expect several seconds of preparation, not an immediate transition.
Original pathing and all scenery effects are cleaned up on cancellation/exit.

Pathing is rasterized onto the native 32-unit grid, with 16-unit inward samples
for wall clearance. Both walk and flight flags are saved/restored. Effects are
removed immediately on teardown. Camera pans instantly and the global minimap
is hidden for participants, then restored. Hero/backpack sight and normal regional
lighting are restored on departure, death, repick or stop. Other heroes/summons
can still supply shared vision: test solo without summons for isolated culling.

In-game checks still needed: seams at a/b/c, the curved f floor, rotated D caps,
walking against walls, and whether h's floor needs a different small lift.
Offline tests verify geometry/lifecycle only, not Warcraft rendering. The kit
has no supplied pathing/collision mesh, so the raster is the movement authority.

## Seeded chambers and transitions

The same seed and room count reproduce the same connected room graph and
cave-piece recipes. Most chambers use a junction, with random a/b/c tunnel
variations and lengths; adjacent two-exit chambers use a rotated bend. Unused
mouths end in narrow or wide caps. This is a first seeded kit prototype, not
an enemy encounter generator or a replacement for the live combat crawl.

Two physical buffers centered at (-27500,25000) and (-22500,25000) alternate.
Walk onto a Circle of Power at an exit, or use `-scarab n/e/s/w`. Any participant
can trigger a transition, which moves the whole party to the matching entrance
in the next chamber and snaps the camera instantly. Arrival points sit inward
from the runes to avoid immediately triggering the return exit.

The first unexplored neighboring chamber is prepared in the other buffer while
players explore. A cached transition is immediate; otherwise the party is held
in the intact current chamber until batched construction finishes. The current
room is never dismantled underneath its occupants. Backtracking may require
reconstruction if that buffer has already been reused. Stop/leave restores
pause state, camera, sight, lamp, entry positions and changed pathing.

Black-cover overlap is reduced locally when it would intersect a measured
floor, particularly at open transition mouths. Offline tests check deterministic
recipes, buffer bounds, portals, party transitions and cancellation; exit-marker
visibility and remaining visual seams still require an in-game check.

## Larger party floors

Floor mode assembles 2×2 or 3×3 grids of joined junction assets, with seeded
perimeter tunnel variations and narrow/wide end chambers. All pieces use the
same scale so their mouth widths match. Wide caps are checked against other
piece footprints; conflicting placements use a narrow cap instead. Independently
enlarging h caused mismatched seams and has been removed. The junction combinations remain
interconnected cave passages, not a seamless open arena: removing internal
walls would require mesh variants. Decorations are deliberately deferred.

Each non-final floor has two or three numbered progression markers. Choosing
one seeds the next floor's geometry differently; repeating the original seed
and the same choices reproduces the route. Holes are currently labeled Circle
of Power placeholders, not beetle burrows or selectable waygates. They do not
yet determine encounter/reward types or require enemies to be cleared.
The final floor reserves the endpoint; this preview does not spawn the boss.

Larger floors use the full cleared 10000×10000 corner rather than two half-width
buffers. Before rebuilding, the party is paused and staged at its original
entry positions with restored camera/lighting. The previous floor is cleaned
up in faster bounded batches. The next floor streams in 512-unit sectors, with
the spawn neighborhood first and a two-second minimum warmup; entry occurs
when that neighborhood is complete, without waiting for the entire floor.
After entry, construction follows synchronized hero positions with up to 64
scenery effects per tick. Each sector finishes its native pathing, cave chunks
and exterior covers together. A 900-unit completed-sector guard keeps rushing
players out of unfinished scenery; their attempted positions receive priority.
If a machine takes longer to finish the spawn neighborhood, entry waits for
safety rather than treating two seconds as a guaranteed load time. The preview must be
entered from outside that reserved corner. No extra editor area is assumed.
Lamp on/off choices persist per player across transitions; preview sight is 800.
No lamp carrier or
shared-light gameplay rule is added here.

Offline tests sample 300 bounded, reproducible floors, both cluster sizes,
walkable progression holes, party regrouping/staging, chosen-hole seed behavior
and cancellation cleanup, consistent mouth scales, wide-chamber separation,
early entry, continued streaming and rush containment. Chamber seams, fog culling and rendering
performance still need in-game testing.
