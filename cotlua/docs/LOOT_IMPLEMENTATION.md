# Data-backed ground loot

Implemented with the owner's approved **eight-entry** bundle threshold. No beta
map was packaged. The editable map object files have been updated separately.

## Player behavior

- Fewer than eight compatible nearby entries remain individual native powerup
  proxies. Picking one claims its real reward directly; no loot window is needed.
  Quantity/charges do not increase the entry count.
- At eight entries, the individual proxies are retired and one selectable treasure-pile
  unit appears. Its contents are records, not items in a hidden native inventory.
- New loot within 450 units of a compatible formed bundle prefers that bundle.
  Cluster anchors do not move or chain across the map. Ownership, cliff level,
  and protected-area scope partition grouping. The threshold/radius are constants
  at the top of `gameplay/items/loot.lua`.
- A formed bundle remains until empty. Taking it below eight does not expand it
  back into individual drops. New additions produce a short gold pulse, batched
  over 0.2 seconds; an open panel updates immediately.
- Selecting a bundle opens the player's inventory and a 12-column × 6-row loot
  window on its left, using the stash's top anchor and 0.006 gap. Width is 0.4682,
  height 0.232. The stash and loot panel share this companion-panel space.
- The title is `ITEM BUNDLE`. Each row tiles two six-slot inventory textures at
  the stash's normal dimensions. Selection uses the shop's blue energy border,
  enlarged 4% and layered above rarity as a sibling of the rarity backdrop.
- Click an entry to select it; use Take or double-click to collect. Inspect opens
  Item Details. The sidebar contains cycle-arrow page controls and the standard
  close button, with no Bind control.
- Selection is returned to the hero using native selection events. Opening and
  reading a visible pile does not allow remote claims: taking/binding requires a
  living, unpaused hero within 450 units, visibility, ownership and item-rule
  validation. Bound foreign entries show as unavailable.
- Full bags can still receive a partial compatible stack. The remainder stays in
  the pile or reappears as an individual pickup. Failed claims leave loot intact.
- Actual powerups retain their original native effect and ItemLookup behavior;
  their real item is created only on claim. Automatic proxies themselves have no
  item abilities or stat-granting effects.

## Data and native lifecycle

`ItemRuntime.withRecords(factory, ...)` runs synchronized drop factories using
the existing Item class, parser, roll calculation and logical-definition hooks,
without allocating a native item, death trigger or TimerQueue expiry per reward.
All rolls, extra fields, persistent custom state and sockets remain on the record.
There is no decode/recreate/reroll on a successful claim. `materialize` attaches
the real native handle to that same Item instance and preserves its sync ID.
Runtime-definition restore hooks rebuild dynamic presentation after attachment.

Ordinary object-editor metadata is primed through one temporary native sample
per rawcode, immediately removed and cached. This is synchronized, never done
from a local hover. Initial stat/tooltip calculation still runs on ground records;
this implementation does not claim fully lazy formatting or minimal Lua memory.

The sparse-drop proxy (`I1LP`, base `gold`) has auto-acquire, perishable/one-charge
fields and an empty ability list. Its skin, name, icon and tooltip present the
record. Proxies never enter `Item[]` and never become saveable inventory contents.
Parsed text is assigned to both native Description (ground selection panel) and
ExtendedTooltip, after applying the skin and local drop-appearance preference.
ItemLookup intercepts them before generic wrapping. A pickup or conversion unlinks
the proxy immediately, then one post-event cleanup batch restores life and calls
RemoveItem. There is no death trigger, timer per proxy, or secondary inventory.
Rejected/partial acquisitions restore a collectible proxy for surviving contents.

The bundle (`nLTP`, base `nshe`) is stationary, non-attacking, invulnerable and
non-colliding, without Locust or an Inventory ability. Its native selection is
only an interaction target. `IsDummy` excludes it from the common combat/group
filters and managed Unit indexing. Removing an empty pile removes this marker.
Its model is the imported `loot_bundle.mdx`, a copy of the installed classic
`Doodads\Dungeon\Props\TreasurePile\TreasurePile0.mdx`. The source has zero Stand
bounds and no per-animation geoset bounds. `tools/build_loot_model.js` fills these
from the existing mesh/model extents, preserving geometry, textures, material
opacity and size. This addresses suspected world culling when the model appears
in the portrait but not on the ground; rendering still needs an in-game check.
Creation explicitly sets scale 1, RGBA 255/255/255/255, and Stand animation.
Facing varies deterministically by pile ID without consuming gameplay RNG.
Building status is authored in object data, with an empty pathing texture. The
runtime building-field setter did not enable native hover names in testing and
has been removed. The updater also authors General/Magic merchants (`n01A`/`n01B`)
as buildings while preserving their other fields. The selection-circle scale is 0.7.
The bundle belongs to Neutral Passive; its hover name updates to `# items dropped`
as contents change. The object updater installs and registers the model import.
Each gold-pulse effect uses scale 0.975 and is explicitly hidden/destroyed after
1.8 seconds, allowing the animation to finish before cleanup.

The old A1GP attachment/pause/revive experiment is retired. GroundPickup retains
only a no-op compatibility entry point and attaches no abilities. The old object
definition can remain unused in editable data; it is not added to new heroes.

## Transactions and cleanup

`LootModel` owns fixed-anchor spatial buckets, compact entry arrays, stable item
identities, and an indexed expiry min-heap. Removing a claimed/bound record also
removes its heap node, rather than retaining one expiry callback per record. One
shared one-second scheduler expires up to 128 due records per tick. Timed-out
backlogs drain deterministically; they never depend on local wall-clock budgets.
Each reward retains its own deadline as other loot joins the pile.

Existing bound-item protection remains. Binding cancels that entry's expiry, and
player cleanup destroys their bound ground records. Authored rewards without an
expiry retain that behavior. User-dropped unbound inventory/stash/socket items
receive a 600-second ground lifetime; bound drops remain protected. Failed direct
grants also enter this system instead of leaving an ordinary native item behind.

All item mutations run in the synchronized service. Local UI uses
`action:pile_id:logical_item_id:expected_record_revision`, with no native handles,
page numbers, selection queries, or preview state deciding a shared mutation.
Double-click collection also requires the same selected identity/revision on
both clicks, so a slot replacement between clicks cannot retarget the action.
An entry revision continues across taking and re-dropping the same Item, so an
old command cannot become valid again inside the same surviving pile. Shared
delivery order resolves competing claims; a successful complete claim removes
the record before another request can award it.

For real automatic powerups, acquisition is observed through an ItemLookup
receipt rather than trusting UnitAddItem's boolean alone. Failed attempts restore
the record with its remaining lifetime, not a renewed ten-minute deadline.
Native effect/lookup behavior still requires an in-game check on the current
patch. Paused/dead heroes are rejected before materialization.

Owned items continue using the existing inventory/stash/save APIs and native
ability carriers. Dropping converts their root and socket handles back to data;
materializing attaches them again. Destroying an item destroys socket children as
well. There is no new save format or save migration.

Ordinary/elite/boss equipment, flask/donor/ticket drop sources, destructable
rewards and authored special-unit drops use the new factories. Shops, decoding,
previews, preload items and direct native grants retain their normal factory API.
Existing preplaced/native items outside these paths are not globally swept or
silently reinterpreted. This is not a replacement for every CreateItem call.

## Validation and in-game checks

Offline regressions:

- `lua53 cotlua/tools/test_loot.lua`: actual model, service and UI on native
  boundaries. Covers eight-entry formation, immediate bundle preference, fixed
  anchors/scopes, sparse pickup/rejection/dead-proxy disposal, host/guest logical
  claims and replay rejection, re-drop revisions, full-bag partial stacks,
  automatic-item receipts/failures, binding/reach, deadlines/player cleanup,
  coalesced effects, 3,000-entry heap removal/order, fixed 72-button pagination,
  and local input without inventory mutation.
- `lua53 cotlua/tools/test_loot_item_records.lua`: actual Item creation, data
  application, calculation, presentation, logical initialize/restore hooks,
  materialization and destruction. Verifies no native reward handle/trigger or
  per-record expiry callback, exact frozen state, recursive socket conversion,
  and scope restoration after a factory error.
- `lua53 cotlua/tools/test_ground_pickup.lua`: real dispatch intercepts raw
  proxies before wrapping; ordinary/dummy/automatic-item behavior remains; the
  retired experiment adds/removes no inventory ability and installs no pause hook.
- `node cotlua/tools/test_loot_objects.js`: v1/v2/v3 object preservation,
  idempotence, collisions/truncation, and object configuration.
- LuaLS error and architecture checks pass. Adjacent inventory, tutorial, item
  identity, sale, shop and character-save regressions pass. A broader 51-suite
  run found 50 passing and one unrelated Smoke Bomb test expecting older aura
  values; Assassin sources were not changed for this feature.

The offline native mocks do not prove full-inventory powerup acquisition, unit
selection, current-patch engine cleanup/leak behavior, actual UI rendering or FPS.
Test an identical fresh build on host and guest, including a hero with all six
native carriers occupied, both individual loot and bundles, full custom bags,
partial stacks, real tomes/quest powerups, failed requirements/binding, simultaneous
claims, repeated selection, pause/death/revival, expiry while open, and player
departure. Check that icons/skins do not change the proxy's auto-use behavior.

Development helpers (DEV_ENABLED builds):

```text
-loottest 7 I01V       # seven direct pickups
-loottest 1 I01V       # eighth nearby entry creates a bundle
-loottest 80 I01V      # pagination / additions to the existing bundle
-lootstats            # records, bundles, proxies and expiry-heap entries
```

The count is clamped to 1–1,000. With development logging, periodic runtime
snapshots also include a LOOT record with those counters. These are known object
counts, not a native-engine memory or FPS benchmark. In dense steady state, N
rewards can be one bundle unit plus N Lua records; their underlying real native
items do not exist until claimed. Sparse areas still have up to seven proxies
per candidate cluster. Measure concentrated and dispersed workloads separately.

Reapply editable object changes with:

```text
node cotlua/tools/update_loot_objects.js <unpacked-map-directory>
```

It validates all four object/skin files before writing, preserves unrelated
records byte-for-byte, and does not package a map. No new imported asset is needed.

API/engine references used for the design:
[historical Item Cleanup](https://www.hiveworkshop.com/threads/system-item-cleanup.175663/),
[powerups versus paused UnitAddItem](https://www.hiveworkshop.com/threads/powerups-and-pauseunit.240118/),
[2026 discussion of harmless powerup proxies](https://www.hiveworkshop.com/threads/how-to-increase-health-of-my-unit-after-tacking-item-without-triggers.371198/).
These references support the approach, not a performance or stability guarantee
for the current map/patch.
