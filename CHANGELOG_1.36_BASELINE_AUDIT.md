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

- `B:\cothub\builder\.build\reports\changelog-135-compare\135`
- `B:\cothub\builder\.build\reports\changelog-135-compare\135c`
- `B:\cothub\builder\.build\reports\changelog-135-compare\135c-to-136-object-diff.json`

The original map files were read only and were not modified.

## Consolidated draft review — 2026-10-07

The maintained local release draft is [CHANGELOG_1.36.md](CHANGELOG_1.36.md).
It links the owner's Google Doc. The browser could not read that document, so
the supplied pasted text was used as its editorial snapshot. No Google Doc
edit or automatic synchronization was performed.

The newly supplied `C:\Users\Antonio\Downloads\war3map.j` is 1,749,257 bytes,
SHA-256 `C72E46F5B7BDBA130D5A66BFE2735129348BE6233D99DB65FD409F5E503A54A7`.
It was supplied as the 1.35 baseline. Its hash differs from the previously
extracted 1.35c script, so these two scripts must not be treated as identical
minor releases. Neither baseline was modified or copied into the repository.

### Evidence checked for this update

| Player-facing change | Old-script evidence | Current source |
| --- | --- | --- |
| No home-dependent XP gate; new level/reward curve | `ExperienceControl`, starting at line 7946, gates XP by `urhome`, level bands, Prestige, and arena state | `gameplay/players/progression.lua`, `reward_scaling.lua` |
| Reworked repeatable kill bounties | `KillQuestHandler`, line 22134, uses band-average reward estimates and an upper eligibility cutoff | `gameplay/world/quests.lua` accumulates actual defeated-unit values and contribution quality; `ui/hud/quest_tracker.lua` adds the tracker |
| Colosseum is a rework, not a new mode | Existing Colosseum wave progression and clear rewards | `gameplay/world/colosseum.lua`: 20 waves, Augments, hazards, Honor |
| Struggle is a rework, not a new mode | `AdvanceStruggle`, line 8689, advances finite waves and awards Lesser Ring/Ring | `gameplay/world/struggle.lua`, `struggle_rewards.lua`: endless waves, checkpoints, saved records, 100 reward ranks |
| Perks replace Prestige | `AllocatePrestige` and `SetPrestigeEffects` | `gameplay/players/perks.lua`, `ui/dialogs/perk_tree.lua` |
| New complete inventory/shop/stat/boss interfaces | Limited built-in frame use beginning around line 21892, not equivalent inventory/shop/perk systems | `ui/inventory/`, `ui/shop/`, `ui/hud/stat_view.lua`, `multiboard.lua` |
| Factions, contracts, events, and ongoing project rewards | Home/nation progression in old XP and placement logic; owner confirms replacement | `gameplay/factions/`, `content/shops/faction.lua`, `gameplay/items/faction_consumables.lua` |
| Potion customization and saved stash | New systems confirmed by owner and current implementation | `gameplay/items/potions.lua`, `stash.lua`, `ui/inventory/potion.lua`, `stash.lua` |
| New Orsted/Xallarath equipment and socket recipes | Compare with existing boss pools/socketable progression, not raw object counts | `gameplay/items/boss_equipment.lua`, `gameplay/world/drop_table.lua`, `content/shops/recipe.lua` |

Paths in the table are relative to `cotlua/src/`. This is a targeted source
review, not a claim that every balance number in the original draft has been
independently revalidated or tested in game.

### Corrections to the earlier additions draft

- Rerolling locks one category for the item's lifetime, rather than rerolling
  restoration, charges, and cooldown together. Current categories are
  Restoration, Charges, Cooldown, and Prefix strength.
- The default flask cooldown is five seconds, not three. Rolled cooldowns have
  their own base-dependent ranges.
- Moving a flask into a potion slot in town adds no equip penalty; it does not
  clear a cooldown already running. Outside town the equip penalty is ten seconds.
- Stormwatch's current event is Eye of the Storm, with anomaly stabilization
  followed by the Lightning Revenant encounter.
- Current faction projects are Survey Boom, Favorable Forecast, and Vanguard
  Mobilization. The latter grants a lobby-only 25% Boss Drop Rate buff for
  15 minutes; it is separate from the targeted Vanguard Bounty consumable.
- Vanguard Bounty uses native backpack targeting, marks bosses above 90% HP,
  clears on retreat, and has a shared ten-minute shop requisition cooldown.
- Early normal-difficulty Chaos bosses start at a 3.5% Epic-flask base chance;
  level and difficulty improve it. It is not the earlier flat 8% estimate.
- Forgotten jewel recipes require a +8 Heart of the Forgotten at the Reclusive
  Blacksmith, not just mining materials at a faction shop.
- The stronger Chaos Flask definition exists but its intended Scarab dungeon
  acquisition is not implemented. It is excluded from available-content claims.
- The previous additions file claimed three unique Arkaden drops. Current
  `drop_table.lua` still registers `I02O`, `I02C`, `I02B`, and `I036` for Arkaden.
  The builder's object-update script contains proposed unique items, but that
  alone does not prove acquisition. The unique-drop claim is omitted pending
  reconciliation with the active map data and drop pool.

### Remaining editorial checks before publishing

- The supplied draft's detailed hero and boss balance numbers are preserved,
  not all independently audited against both script versions and object data.
  In particular, wording about increasing/reducing physical or magic
  resistance sometimes conflicts with the listed numbers. Confirm whether
  these describe damage taken before normalizing the terminology.
- The supplied Hydromancer Whirlpool line contradicted itself. It now describes
  the stated capped increase in duration expiry rather than retaining both
  opposite claims; confirm exact tuning before publication.
- Retained historical item/hero names and the removed Forest Corruption claim
  come from the owner's draft. Verify final names and availability for release.
- Check acquisition, shop stock timing, boss previews, and save/load behavior
  in game. Source availability is not a substitute for an end-to-end test.

### Maintaining the release notes

Editorial direction: keep the public draft focused on major systems,
progression, and meaningful balance changes. Omit effect catalogs, item names
for new boss pools, recipe components, detailed faction reward payouts,
shop stock descriptions, potion naming/presentation, and routine interaction
or bug-fix details players can discover naturally. Describe difficulty voting
as a new per-boss feature, not as an incremental voting fix. Duplicate-equipment
restrictions predate this release and must not be presented as new. Describe
stash access directly (view anywhere, transfer in town) without the phrase
"read-only" in public notes.

Update `CHANGELOG_1.36.md` for confirmed player-visible changes. Describe new
systems relative to the release baseline, not their intermediate prototypes.
Merge changes into an existing entry rather than accumulating contradictory
patch notes. Keep internal refactors, rawcodes, asset filenames, packaging,
minor alignment fixes, and speculative/unobtainable content out of public notes.
Put uncertain findings and supporting evidence here. The earlier
`CHANGELOG_1.36_ADDITIONS.md` is historical and is no longer the release draft.
