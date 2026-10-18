# Native NPC hover-name investigation

Compared the current editable map's gameplay and skin unit records, their base
objects in the installed classic `UnitUI.slk`, `UnitData.slk`, `UnitBalance.slk`,
and the native map creation code. Both failing objects are already buildings
owned by Neutral Passive. The missing field is **Neutral unit classification**
(`utyp=neutral`), which is separate from owner and race.

The comparison below records the state before the targeted fix.

| Object | Rawcode | Base | Building | Neutral classification before fix |
| --- | --- | --- | --- | --- |
| Colosseum Director | `h059` | Footman `hfoo` | Yes, explicit | Missing |
| Item bundle | `nLTP` | Sheep `nshe` | Yes, explicit | Missing |
| Anvil | `n006` | Goblin Merchant `ngme` | Yes, inherited | Yes, explicit |
| Mystic/Magic merchant | `n01B` | Goblin Merchant `ngme` | Yes, inherited | Yes, explicit |
| General merchant | `n01A` | Goblin Merchant `ngme` | Yes, inherited | Yes, explicit |
| Blacksmith | `n02C` | Goblin Merchant `ngme` | Yes, inherited | Yes, explicit |
| Prize vendor | `n032` | Goblin Merchant `ngme` | Yes, inherited | Yes, explicit |

This matches the reported requirement for native Neutral Passive hover names:
building status plus Neutral classification. See the firsthand explanation in
[Removing player name, post 12](https://www.hiveworkshop.com/threads/removing-player-name.295521/).
The editor field to change on `h059` and `nLTP` is **Stats → Unit Classification →
Neutral**. Retain any other classifications. Changing owner, model, selection
scale, shop abilities, or the displayed name does not supply this classification.
The Chaos transition changes the Director's skin to `e000`; its gameplay type
remains `h059`.

The working vendors also inherit the neutral minimap-icon field (`unbm=1`),
whereas the Footman/Sheep bases do not. This is a separate field, not evidence
that a minimap icon is necessary for the name. Test classification alone first.
Neutral classification can also affect neutral-building exploration/minimap
behavior; see the firsthand research in
[Mysterious Unit Editor Fields](https://www.hiveworkshop.com/threads/mysterious-unit-editor-fields.307275/).
Check that bundles stay absent from the minimap and respect the intended fog
behavior when testing the change.

The targeted fix sets building status and adds Neutral classification through
`tools/update_npc_hover.js`. It covers the Director (`h059`), bundle (`nLTP`),
Huntsman (`h036`), Headhunter (`h03A`), and Chaotic Huntsman (`h009`). Existing
classifications are retained. Gameplay records receive the fields, and existing skin overrides are also
updated; artwork-only skin records remain byte-exact. Names, models, selection
scales, shadows, abilities, ownership and minimap fields are unchanged.

The current bundle's native TreasurePile model and shadow differ from the earlier
generated definition. The targeted updater preserves these editor changes; the
full loot-object updater is not used for this fix. The default bundle definition
in that older updater now also includes Neutral classification.

Run `node cotlua/tools/update_npc_hover.js <editable-map-directory> --check` to
preview, or omit `--check` to apply. No beta is packaged. In-game verification
should cover the Director before/after Chaos and bundles as their item count
changes, including minimap/fog behavior.

The Chaotic Huntsman is spawned as `h009` during the Chaos transition, so it
requires its own object flags. The Chaos Director remains `h059` and receives
only the `e000` appearance through `BlzSetUnitSkin`; its Director gameplay flags
remain in effect. The `e000` Chaos Knight skin is also used by Colosseum enemies
and is not modified by this NPC updater.
