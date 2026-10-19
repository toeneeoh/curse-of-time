# High Priestess model

Replaced E012's Sally Whitemane model with the owner's
`B:/wc3assets/HighPriestess/priest1.mdx` (Calia Menethil). The supplied source is
stored byte-for-byte as `assets/high_priestess/HighPriestess.mdx`. Its original
eight animations, emitters, attachments and portrait camera are retained.
The unit keeps its existing 1.1 model scale and other object fields.

The installer repairs the gameplay model's existing team-color hero glow. Its
three additive, unshaded glow quads were accidentally divided by 100 while
their bounds remained full-sized. Only those 12 vertices are restored to match
the authored bounds; the stock replaceable Team Glow texture and pulsing bones
are retained. The repair is idempotent. The selection sprite continues to be
built from the supplied source and retains its existing appearance.

The accompanying `HighPriestessSprite.mdx` follows the manually made selection
sprites:

- Keeps the two ordinary idle sequences, Stand -1 and Stand Second. Removes
  other sequence entries, including the victory pose, and their keyframes.
- Removes particle emitters, attachments, event/sound emitters, camera and
  collision objects. Shared global animation tracks remain intact.
- Adds one `root_bind` helper above every original root, retaining the internal
  skeleton. Uses quaternion `(-0.5, -0.5, -0.5, 0.5)`, matching the existing
  High Priestess, Arcanist and Dark Savior selection sprites.
- Enables Unshaded on every material layer. Compacts node and pivot IDs and
  updates mesh references, sequence bounds and geoset animation bounds.

The sprite is 49,040 bytes versus 78,090 bytes for the gameplay model. Geometry,
UVs, skin weights and the retained animation keys are preserved.

`calia.blp` and `calia1.blp` are imported at the map root, matching their embedded
paths. Six other texture paths are stock Warcraft assets; they were checked
against the installed legacy MPQs. The existing sprite path and Lua hero-select
configuration remain valid.

Rebuild and install into an editable map:

```powershell
node cotlua/tools/build_hero_sprite.js cotlua/assets/high_priestess/HighPriestess.mdx cotlua/assets/high_priestess/HighPriestessSprite.mdx
node cotlua/tools/test_high_priestess_assets.js
node cotlua/tools/update_high_priestess.js <editable-map-directory>
node cotlua/tools/update_high_priestess.js <editable-map-directory> --check
```

The installer changes only E012's authored model field, the relevant imports
and the four model/texture files. Existing import entries and other unit fields
are preserved. Re-running it makes no further changes.

Validation also loaded the sprite in Retera's independent MDX parser and rendered
both idle animations with its animation evaluator and the actual BLP textures.
These are offline asset checks; final Warcraft lighting, portrait framing and
hero-select frame placement still need an in-game look.
