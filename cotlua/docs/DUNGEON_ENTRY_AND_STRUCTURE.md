# Dungeon entry and structure

The Scarab entrance is a native Marketplace (`nmrk`) placeholder at **(16000, 6311)**,
named Scarab Expedition. Its custom shop offers a free virtual entrance service:
no new object-editor item is required. Native marketplace selling is disabled.
The placeholder can be replaced later without changing the dungeon definition.

## Copy/paste entrance presentation

Name: **Enter the Scarab Tunnels**

Icon:
```
ReplaceableTextures\CommandButtons\BTNCarrionScarabs.blp
```

Extended tooltip (Warcraft color codes preserved):
```
|cffff0000Level Requirement: 500|r
|cff3399ffEnter:|r Open the expedition ready check. Nearby players can join before the party sets out.
|cff808080Beyond the entrance, the hive stretches into darkness.|r
```

Level 500 is provisional, based on the intended max-upgrade Azazoth loadout.
The start service does not charge gold or award milestones. Boss access and
room/boss rewards remain separate unfinished work.

## Ready check

Naga, Azazoth and Scarab now use the same standalone window, not a multiboard page.
An entrance purchase opens the queue. Living, non-busy heroes meeting the level
requirement automatically join within 750 units of that entrance. The roster
refreshes every 0.25 seconds. Leaving range, dying or changing heroes clears
readiness; returning requires Ready again. Any member can press Start once all
members are ready. The party is revalidated after the two-second departure fade;
membership changes cancel departure rather than silently changing its party.

Close/Escape hides the window without changing readiness. Purchase the entrance
service again or type `-dungeon` to reopen it. `-ready` remains a shortcut.
Scarab's prototype can currently be exited with `-scarab leave`; use
`-scarab stop` to stop/reset it during testing. Ending the last participant's
session closes the run and restores modified pathing before another party enters.

## Ownership

- `gameplay/dungeons/dungeon.lua`: shared lifecycle, entrance registration,
  queue state and synchronized ready/start validation; no encounter definitions.
- `content/dungeons/azazoth.lua`: Azazoth entry, boss activation and completion.
- `content/dungeons/naga.lua`: Naga floors, enemies, chests and rewards.
- `content/dungeons/scarab.lua`: Scarab party admission and crawl lifecycle.
- `gameplay/dungeons/scarab/{layout,crawl,combat,boss}.lua`: seeded graph,
  room recycling, combat helpers and the independent boss prototype.
- `content/shops/scarab_entrance.lua`: placeholder merchant and entrance offer.
- `ui/dialogs/dungeon_ready.lua`: roster display and synchronized Ready/Start
  requests. It observes the queue API; gameplay does not depend on its frames.

Bootstrap, offline tests and documentation use the new paths. Boss ability and
buff files remain under `content/abilities/`: they belong to the spell/buff systems,
not the crawl's room lifecycle.

## Audit notes addressed

- Removed direct shared-queue manipulation of multiboard frames and availability.
- Prevented repeated Start clicks from scheduling duplicate starts.
- Revalidated participants after the departure delay, including deaths/new arrivals.
- Removed empty-party starts and stale readiness on changed heroes or re-entry.
- Added timer generations so an old queue poll cannot mutate a newer queue.
- Cleared destroyed timer/chest references to avoid repeated teardown of handles.
- Prevented Azazoth's delayed activation from proceeding after the party is gone.
- Scarab leaves restore its busy/teleport state; last departure schedules safe
  cleanup instead of recursively stopping the crawl inside its leave callback.

Warcraft UI layout, native Marketplace presentation and multiplayer synchronization
still require in-game testing; offline native mocks cannot validate rendering.

## Visibility testing

`-test` no longer disables fog of war. `-vision` still explicitly reveals the map;
use `-novision` to restore normal fog in an existing session. The crawl warns on
entry if either fog or its mask is disabled, without changing those global settings
for everyone else. Darkness is lighting, not concealment: it cannot hide enemies
while fog is disabled. Current sight is 192 without the test lamp and 384 with it;
backpack sight is suppressed while inside and restored on departure.

Lamp sight was reduced from 700 as a provisional bright-core calibration; the
model's faint outer glow is not a usable visibility boundary. This does not claim
to reproduce its edge exactly or eliminate Warcraft's attack-reveal behavior.
`-scarab visibility` reports intended/native sight, backpack sight, fog flags and
the six nearest living enemies' distances, native visibility and fog sample radii.
Use this if enemies remain visible too far out with fog enabled.
