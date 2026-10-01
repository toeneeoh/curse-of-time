# 1.35/1.35c to 1.36 baseline audit

This is supporting evidence for the public 1.36 changelog. It is not intended
to be published as release notes.

## Changelog methodology

Use the existing hand-written draft as the editorial foundation. Verify the
old behavior against the compiled 1.35c `war3map.j`, WTS strings, and Object
Editor tables, then compare those with the current map and source. Git history
is useful for identifying recent work and implementation intent, but it is not
the release baseline because substantial 1.36 development predates the useful
repository history.

Only changes that affect gameplay, progression, balance, controls, or a major
player-facing interface belong in the public changelog. Architecture work,
developer tooling, rawcode reuse, doodad counts, asset filenames, and minor
visual cleanup remain in this audit when they are useful evidence.

## Baseline files

- `CotN-RPG-1.35.w3x`
  - Size: 38,168,465 bytes
  - SHA-256: `527DFC7FF69CD983BFA857D846523C0B06D9C0E1ADE287208964089F6C83FC17`
  - Unprotected listfile with 1,667 entries.
- `CoTN-RPG-1.35c.w3x`
  - Size: 44,114,291 bytes
  - SHA-256: `3A91290C4C751D7548383B074D2120B1512BA1B16C89BA6E2BFB1C01C7AEE889`
  - Protected listfile exposing only `war3map.j` and `war3map.wts`.
  - Standard terrain, pathing, doodad, map-info, script, string, object, and
    object-skin files remain extractable by known filename.

The 1.35c map is the gameplay baseline. The unprotected 1.35 map is used only
for placement/import context that protection hides in 1.35c.

## Compiled-script UI baseline

The 1.35c `war3map.j` does use a limited set of frame natives for the AFK and
damage-dummy displays, hardmode voting, the resource bar, a menu button, and
minor manipulation of built-in quest/alliance frames. It does not load a TOC
and contains no equivalent of the 1.36 custom inventory, shop, hero-select,
stat, perk, faction, or potion interfaces. Public changelog wording should call
those complete UI systems new without claiming that 1.35c contained no frame
code whatsoever.

## Terrain and placements

- 1.35, 1.35c, and 1.36 all use a 481 by 481 terrain-vertex grid. The playable
  map was not expanded.
- The 1.35c and 1.36 ground/cliff tile palettes match.
- The terrain format changed from version 11 to version 12.
- The pathing file remains 3,686,416 bytes.
- Placed doodads decreased from 15,467 in 1.35c to 11,133 in 1.36: 4,334
  fewer placed doodads.
- The protected 1.35c unit-placement file cannot be extracted. The unprotected
  1.35 map contains 141 placed units and the current 1.36 map contains 47, but
  this cannot be treated as an exact 1.35c-to-1.36 count.

## Object-data comparison

The comparison merges `war3map.*` and `war3mapSkin.*` tables and resolves WTS
strings before comparing rawcodes and fields.

| Object type | New custom objects | Removed custom objects | Modified records |
| --- | ---: | ---: | ---: |
| Units | 36 | 501 | 163 |
| Items | 8 | 361 | 539 |
| Destructables | 14 | 1 | 0 |
| Buffs | 6 | 99 | 7 |
| Doodads | 35 | 7 | 11 |
| Abilities | 29 | 214 | 361 |
| Upgrades | 0 | 44 | 0 |

Large removal counts mostly reflect the code wipe, removal of Object Editor
level variants, and migration of behavior into Lua. They must not be described
as literal removal of that many player-facing units, items, or abilities.

### Confirmed semantic findings

- Colosseum and Infinite Struggle existed in 1.35c. Their 1.36 entries must be
  described as reworks, not brand-new modes.
- `I00T` changed from **Lesser Ring of Struggle** to **Struggle Gem**.
- The existing **Ring of Struggle** (`I0D0`) was retained and reworked for the
  ranked reward system.
- `I0ER` changed from the old **Colosseum - Solo [EXTREME]** selector to the
  unified **Colosseum** entry.
- `I008` changed from **Naga Nation** to **Colosseum Ticket**.
- `n032` changed from **Enhancer** to **Prize Vendor**.
- `n004` changed from **Bandit Rider** to the first **Faction Salesman**;
  `n0P0` and `n0P1` add the two other unique faction shops.
- New named units include King of Despair, Mining Deposit, Guardian, Giant
  Polar Bear, Polar Bear, Spider Lord, Spider Seer, Devourer Berserker,
  Forgotten Archer, and Flaming Betty.
- New named abilities include Frozen Orb Second Cast, Steed Charge, Hidden
  Guise, Improv, Magnetic Stance, Light Seal, Blood Potion, and Dragon Potion.
- New named buffs include Inspired, Overload, and Rampage.
- Added destructable/pathing definitions include separate town, Orc, Scarab,
  cave, Colosseum, Struggle, Naga Dungeon, and God Arena pathing blockers.

## Imported assets

The unprotected 1.35 archive can be compared by filename with the current map:

- 1.35 listfile entries: 1,667
- Current extracted-map files: 2,434
- Present in current map but not 1.35: 846
- Present in 1.35 but not current map: 79

The 846 additions include 499 BLP textures, 241 MDX models, 67 DDS textures,
18 TGA images, UI frame definitions, music, and other supporting assets. This
supports the changelog's new UI, hero visual, encounter, faction, item-rarity,
and effect entries, but individual asset filenames should not normally appear
in public release notes.

Because the 1.35c import manifest is protected, these asset counts are strictly
1.35-to-current rather than 1.35c-to-current.

## Generated evidence

Temporary extracted baseline data and the complete field-level JSON report are
stored outside the source repository at:

- `B:\cothub\builder\.build\changelog-135-compare\135`
- `B:\cothub\builder\.build\changelog-135-compare\135c`
- `B:\cothub\builder\.build\changelog-135-compare\135c-to-136-object-diff.json`

The original map files were read only and were not modified.
