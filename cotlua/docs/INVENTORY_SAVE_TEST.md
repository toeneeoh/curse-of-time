# Manual inventory save/load fixture

Select any living hero and type **`-invtest`**. The developer command adds a
loadout to free slots, unlocks at least four stash rows, and prints each item's
actual slot and expected charge/socket counts. Existing inventory and stash
items stay in place. If a preferred slot is occupied, the fixture uses another
compatible free slot; occupied potion slots send the test flasks to the backpack.
Insufficient space rejects setup before creating items. Repeat invocations add
another loadout if there is room.

On an empty character, the layout is:

| Location | Contents | Expected after reload |
| --- | --- | --- |
| Inventory 1 | Medallion of Courage with Vigor Gem, Torture Jewel, Lexium Crystal | All three sockets and their stats remain |
| Inventory 3 | Medallion of Vitality | Equipped in slot 3 |
| Inventory 7 | Health Flask, 1 charge | 1 charge |
| Inventory 8 | Mana Flask, 0 charges | Still empty |
| Backpack 9 | Sword of Revival, 2 charges | 2 charges |
| Backpack 11 | Sword of Revival, 0 charges | Still empty |
| Backpack 15 | Dragon Bone stack of 7 | Stack of 7 |
| Backpack 26 | Colosseum Ticket | Empty slot |
| Stash 1 | Medallion of Courage with Torture Jewel | One socket remains |
| Stash 8 | Sword of Revival, 1 charge | 1 charge |
| Stash 18 | Runtime Greater Health Flask, 2 charges | Identity, rolls, and 2 charges remain |
| Stash 24 | Colosseum Ticket | Empty slot |

Save normally, reload the character, then compare against the printed layout.
Check four unlocked stash rows, empty gaps, equipment bonuses and socket tooltips,
backpack placement, flask identity, and the partial/empty charge counts. The gems
are attached before equipping the parent, allowing the same fixture on a low-level
hero. The command does not change hero level.

Colosseum tickets are explicitly omitted by both the normal save validation and
the serializer. Unexpected items that cannot be encoded still reject saving,
including unencodable sockets; this distinguishes intended exclusions from
corrupt or unsupported item data.

`test_inventory_loadout.lua` executes the fixture service with mocked natives and
the production item encoders/character serializer. Actual native presentation,
disk save/load, equip effects, and multiplayer behavior require the manual run.
