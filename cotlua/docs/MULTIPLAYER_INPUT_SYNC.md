# Multiplayer input/UI synchronization audit

Reported reproduction: the non-host disconnects after Tutorial Start, or after
selecting any hero and moving/right-clicking. Remaining idle did not reproduce it.
No Warcraft multiplayer reproduction has been run by the automated checks.

## Fixed hazards

- `gameplay/players/mouse_input.lua` and `hotkeys.lua` previously passed
  `GetMainSelectedUnit()` into shared selection subscribers. That function reads
  the current client's local selection, not the triggering player's selection.
  A host could therefore dispatch its hero for the guest while the guest
  dispatched nothing. Shared selection refreshes now use native selection-event
  state. Selected/deselected events also track group membership for movement.
- `framework/ui/glue_button.lua` previously scheduled cooldown animation tasks
  on the shared `TimerQueue`, including calls made inside local-only potion/shop
  refreshes. Cooldown animation now uses one native timer allocated and started
  on every client at initialization. Local entries mutate only UI state/frames.
  `ui/hud/buff_bar.lua` cancels stale displays when an icon becomes an aura/empty.
- The optional continuous right-click movement handler in `ability_controls.lua`
  no longer branches group creation or unit orders on `IsUnitSelected()`. It uses
  synchronized selection-event membership, including multi-unit selections.
- `framework/ui/frame_helpers.lua` no longer lazily allocates its filter/frame
  handles on first local use. Frame references are resolved after UI setup on
  every client. Its local enumeration uses a private group instead of mutating
  `bj_lastCreatedGroup`.
- `gameplay/abilities/spells.lua` resolves the ability handle before the local
  tooltip-writing branch. Text writes remain local.

Tutorial button CONTROL_CLICK events already dispatch their transitions on all
clients; no extra sync-data wrapper was added. The tutorial's visible frames and
practice items may differ locally, but must not drive shared timers, native
handle creation, RNG, or gameplay changes.

## Offline verification

From the repository root, run Lua 5.3 on `cotlua/tools/test_input_sync.lua`.
It executes the real mouse, selection-helper, button, and buff-bar modules plus
the actual hotkey-refresh/movement handlers in two isolated mocked clients.
The clients have different local selections but the same triggering player/unit.
The test compares shared callback/order traces and native allocation counts,
checks group selection/deselection, and rejects UI scheduling shared callbacks.
These are host-side mocks, not a network/desync guarantee; they are not included
in the shipped map and do not depend on Warcraft enabling `io` or `debug`.

## Required multiplayer retest

1. Both players use the same rebuilt map and fresh Warcraft sessions.
2. Without opening the tutorial, each player selects a hero, moves/right-clicks,
   and switches selection with F1/control groups. Include hero + backpack group
   selection and deselection; check ordinary movement and the movement toggle.
3. Non-host types `-new`, presses Start, then Next/Back/Skip. Also test the item
   context menu and finishing the tutorial before creating a profile.
4. Use a flask; select units with timed buffs/auras; switch selections while the
   cooldowns run. Check both players still see their own correct countdowns.
5. Swap host/non-host roles. Record the earliest failing action and collect both
   players' logs if a disconnect remains.

## Follow-up: inventory drag / backpack double-click disconnect

The host's `TONY_101126_232430_Desync.log` confirms a native desync, but does not
identify a Lua callsite. The guest's supplied `runtime-player-3.pld` has identical
item lifecycle, event, callback, damage, AI and timer counts to the host through
the final guest snapshot. Both logs contain the same `-color` exception; neither
contains a drag/selection exception. Their clock timestamps have different
origins. These snapshots do not rule out divergence between snapshots, and do
not establish which simultaneous input caused the disconnect.

Additional concrete hazards fixed:

- Inventory dragging used separate `context` and `target` sync messages and
  resumed per-client coroutines. Local context-menu/drag-release state decided
  whether a client created a coroutine at all; only clients with a resumed
  coroutine would mutate items, issue a drop order or schedule the shared
  cooldown. Even ordinary world mouse releases could start this protocol.
  Mouse input now builds an owner-local draft and sends one `inventory_move`
  request containing source, destination, source logical instance ID and drop
  coordinates. Its shared handler validates and executes directly, without
  consulting local menus, drafts or suspended threads. Stale source instances
  are rejected. Successful/error move results are logged for comparison.
- Local drag cleanup and Alt-tooltip refresh now render inventory frames only.
  They do not call the normal inventory refresh, which also invokes potion
  refresh and writes native item presentation/state. Details actions are local
  presentation; equipment/drop/sell/stash/use still enter shared sync handlers.
- Slot mouse hitboxes now derive their centers from the same frame offsets as
  icon placement. Previously the equipment-row centers were 0.0074 UI units too
  high, with smaller offsets for backpack/potion rows, missing part of the icons.
- `-color` now accepts only integer entries in `OriginalHex`. Previously color
  25 (or fractional values) passed a bounds check even though the table has only
  24 colors, leaving partial player state changes before the nil concatenation.

Run `cotlua/tools/test_inventory_sync.lua` with host Lua 5.3. It replays the real
drag/action handlers on two isolated mocked clients with differing local menu
states, compares shared mutation/timer/error traces, checks stale/invalid data,
Ctrl-click and ordinary world double-clicks, and tests actual slot-center math
and the color handler. Like the other tests, it is not a Warcraft network test.

After rebuilding, have each player drag equipment to/from the backpack and
stash, Ctrl-click transfers, cancel a drag in a gap, and use right-click menus.
Include simultaneous backpack double-click/group selection on the other client.
If it still disconnects, retain both clients' newest native `*_Desync.log` files
and both runtime logs; the guest runtime log alone cannot compare native state.

## Follow-up: shop purchases (October 12)

Compared `RAGINUS_101226_065523_Desync.log` with the host's
`TONY_101126_235440_Desync.log`: all 48 captured sections align; only the
current-turn `ipse` section differs (turn 1856, entries 1 and 2). The meaning
of those counters is not established; this is not evidence of a specific Lua
line or purchase being the cause. The guest runtime snapshot contains no Lua
error and predates the final disconnect/actions, so silence is not exoneration.

The shop had an independent synchronization hazard: detail visibility and
refreshes are client-local, while purchase callbacks read detail/component/
related-item selections directly on every client. Purchases now send a concrete
`shop_buy` request with shop rawcode and catalog item key. All clients resolve
that key from the fixed catalog, check active shop/access, then re-evaluate
range, stock, money and components in the existing transaction service. Local
refreshes no longer alter authoritative active-shop state. Purchase audio and
animation remain local; commits and `SHOP` result logging remain shared.

Run `cotlua/tools/test_shop_sync.lua`: isolated mocks deliberately disagree on
detail selection and compare outcomes for two purchases, insufficient funds,
invalid/stale requests, offer keys and revoked access. It is an offline test,
not proof against Warcraft network desyncs. Retest concurrent shop purchases
and inventory dragging with a freshly rebuilt map; include the rejected third
purchase and related-item/detail-panel purchases after scrolling.

Separate save investigation: the supplied Bloodzerker slot-1 `SAVE_VALUES`
starts with item records `278,0,0,0,281,0,0,0,281,...`. The current reader expects
both state-count and socket-count fields, so it interprets the next item ID 281
as a socket-count. That demonstrates a record-layout mismatch, not 281 actual
sockets. Original save files have not been modified; do not clamp the count or
silently accept a guessed layout as recovery.

## Tutorial drag-start follow-up (October 12)

The tester archive `2026-10-12 19.18.26 e335a52c.zip` reports a disconnect at
turn 423 after clicking the tutorial Iron Sword to drag it. Its native dump
matches `TONY_101226_121412_Desync.log` in 47 of 48 sections, including the
previous captured turns. Only current-turn `ipse` entries 1 and 2 differ;
entry 2 differs by one. Counter semantics remain unconfirmed. The host runtime
log reports successful 281/281 initialization and no recorded Lua exception.

An explicit drag-start hazard was found: `showDragTracker` called `TimerStart`
only on the actor's client, and `hideDragTracker` locally paused that timer.
Both real inventory and tutorial practice share this tracker. Its native timer
now starts once on every client at initialization and remains running. A local
`tracker_active` flag gates frame updates only; show/hide, cancellation and
page changes never start, pause, destroy or replace the native timer.

`test_drag_tracker_sync.lua` executes the real tracker code in isolated client
mocks. It compares timer lifecycle traces across clients while dragging,
releasing and repeating, verifies that only the actor's icon moves, and checks
that idle callbacks do no UI work. This demonstrates the code-level fix, not
the engine cause or a completed multiplayer verification. Retest dragging the
practice sword and flask, stash transfers, and Next/Finish while dragging.

## Tutorial fountain/page-11 investigation (October 12)

`2026-10-12 19.58.02 3465bee8.zip` contains two native dump batches: the older
turn-423 disconnect and the new turn-702 disconnect. Compare only turns
700–702 against `TONY_101226_125424_Desync.log`. The new 48 sections match in
47 cases. Only the current-turn `ipse` entries 1 and 2 differ: guest
`0x0002831C/0x0002C4B6`, host `0x000282CE/0x0002C4B7`. Their semantics are
still not confirmed. Matching captured combat/RNG/unit sections do not establish
that a particular attack or camera native is safe.

Tutorial page 11 is the fountain and the first camera-preview page. At initial
inspection,
`PreviewPlayerCamera` already schedules its .03-second callback on every client;
only camera snapshots, bounds, minimap texture, and pan calls are local. Restore
does not schedule a shared callback. This path does not call lighting ability
mutators. Buzan's on-struck/enrage callbacks have no direct local-player branch;
damage-number settings change local text tags, not the shared instance count or
update-queue condition. No definite Lua-side desync fault was demonstrated by
this inspection, and no speculative runtime change was applied.

`test_player_camera_sync.lua` runs the actual camera module in isolated host/guest
mocks, comparing queued-work traces for a non-host's fountain page, Back/Skip,
and rapid Next. It forbids gameplay/native timer lifecycle mutations in preview
and checks stale pans are cancelled. It cannot exercise native engine allocation
or prove multiplayer safety. The existing tutorial test also passes.

Next reproduction: have the non-host cross page 10→11 while all other players
are idle, then separately attack Buzan without any tutorial running. Include both
clients' native dumps and the guest runtime log; the provided archive has no guest
`runtime-player-*.pld`. This separates the first camera/minimap transition from
the concurrent damage path before choosing a runtime fix.

After the reported transition was confirmed, the camera helper was hardened for
the next multiplayer test. Its delayed pan no longer uses the shared TimerQueue.
One native .03-second polling timer is created and started on every client at
initialization and is never locally restarted/paused/destroyed. Preview/Restore
only replace or clear a client-local pending record. Two ticks let bounds settle;
rapid page changes coalesce to the newest target, and Back/Skip cancels the pending
pan. Smooth tutorial panning and instant dungeon traversal are retained. Repeated
requests for the currently active minimap texture no longer reload it.

The updated isolated-client test covers calls made on all clients and calls made
only on the actor's client, with and without a hero. Both have identical native
timer lifecycle traces and no shared queue mutations. This is targeted hardening,
not proof that the original synchronized camera callback caused turn 702 or that
the native camera/minimap transition is now network-safe. Retest with the new
build, including existing-hero page 10→11, Back, Skip and Finish.

The user subsequently reproduced page 10→11 on that timer-hardened build. The
timer change therefore did not resolve the fault. The next diagnostic beta keeps
bounds changes and smooth panning, but passes `preserve_minimap` for tutorial
previews so they do not call `BlzChangeMinimapTerrainTex`. It also resolves the
minimap origin frame during synchronized tutorial frame construction, rather
than first resolving it inside the location page's local render. Dungeon previews
retain their texture behavior. These are isolation changes, not a confirmed
native root cause; multiplayer retesting is still required.

The next supplied archive (`2026-10-12 20.52.46 b8b48450.zip`) reports turn 142.
Its host/guest dumps match in 47 of 48 sections; the remaining section differs
only in value #2 by one. This does not establish what the internal counter means.
The attached `runtime-player-2(1).pld` has the same SHA-256 as the earlier runtime
file, so it provides no new post-initialization evidence.

With the user's approval, the next diagnostic build temporarily sets
`SKIP_FOUNTAIN_CAMERA_DIAGNOSTIC` in `tutorial.lua`. Entering page 11 retains all
existing text, highlight, buttons and rendering but does not call the camera
preview helper. Pages 12-14 retain normal camera behavior. Retest only 10→11
first, without Mark Location, to separate the page UI from preview side effects.
If it survives, the next test should isolate bounds and panning separately; if it
still desyncs, investigate the page transition/rendering independently of camera.
This was an isolation diagnostic, not a production fix.

On October 17, the user requested consistent tutorial panning again. The temporary
fountain skip was removed. Entering the fountain page now uses the same smooth
camera-preview path as the kill-quest page, targeting the fixed map coordinates
(-270, 320) also used by its minimap marker. The timer isolation and minimap-texture
preservation remain in place. Offline tests cover the fountain pan with and
without a selected hero and restoration on Back/Finish; this does not establish
the cause or resolution of the earlier multiplayer fault.

## Backpack-to-equipment desync audit

The user supplied `2026-10-12 21.25.35 3b81d768.zip` and a fresh player-5 runtime
log. The archive reports turn 2936 and appends this dump to an older report.
Comparing only turns 2934-2936 with the corresponding host dump again finds
47/48 sections identical; the remaining section has different #1 and #2 values.
The internal fields are undocumented and are not treated as identified handles.
The host runtime records a successful move from slot 9 to slot 2. The guest's
last periodic flush precedes that transaction, so its absence from the guest log
does not establish that the sync event failed to arrive.

The request handler uses one sync packet and calls InventoryService directly.
No coroutine is used in this inventory UI/service path. Attachment, stat updates,
item-change subscribers, and native carrier moves remain part of the downstream
audit. A large rewrite is not evidence of sync safety.

Two concrete unsafe timer paths were found independently of the unproven equip
root cause: Button.onScrolled and Shop.onScroll selected per-player timers using
GetLocalPlayer and restarted them during frame events. Their throttle now uses
local numeric deadlines and reads the existing Button.double clock, which is
created and started once on all clients. Scroll actions no longer allocate,
restart, pause or destroy timers or enqueue shared work. This also removes shop
scroll timers that were repeatedly allocated and overwritten during shop setup.

Inventory move/action handlers now immediately flush begin/end diagnostic entries
with request identity, source/target rawcodes and handle IDs, and the six native
carrier IDs. These reads do not allocate native objects or consult local UI.
Collect both clients' current runtime files after reproducing; a begin without
an end, or differences in identity/carriers/results, will narrow the failing
transaction. Do not declare the equip desync fixed by the scroll change.

Sync invariants: local UI may update frames and private Lua drafts. It must not
change gameplay state, allocate native handles, mutate native timer lifecycle,
or insert/remove work in a gameplay TimerQueue. A timer allocated elsewhere does
not make local TimerStart safe. Uniform periodic callbacks can process local
presentation drafts only when the timer itself is created/started identically
on every client and local branches never schedule shared work. Asynchronous
native getters must not decide inventory validation or gameplay mutations.

## Empty-backpack move: confirmed divergent validation (October 12)

The archive `2026-10-12 21.51.39 6b775cf0.zip`, attached
`runtime-player-5(2).pld`, and the live host `dev/runtime-player-1.pld`
capture the SAME `inventory_move` request, actor pid 1, slot 10 to empty slot 16:

| Client | Requested native ID | Actual source native ID | Source rawcode | Result |
| --- | --- | --- | --- | --- |
| Host | 1134071 | 1134071 | 1227894865 | move |
| Guest | 1134071 | 1128067 | 1227894865 | stale |

Both clients' preceding periodic snapshots have identical item lifecycle counts
(27 live / 493 created / 466 destroyed) and event/callback counts. The handler
compared an actor-supplied GetHandleId(item.obj) against each client's own
GetHandleId. That definitely took different gameplay branches: the host moved
the item while the guest left it in place. Neither equipment attachment nor an
occupied destination is required to reproduce this fault.

[jassdoc's GetHandleId documentation](https://github.com/lep/jassdoc/blob/master/common.j)
explicitly notes that IDs can differ between clients. Thus the handle mismatch
itself is NOT proof of an earlier gameplay/native-object allocation bug. Native
IDs remain useful local diagnostics, but are not a cross-client identity.

Each managed item now receives a monotonic Lua-only `sync_id` during synchronized
ItemRuntime creation/first wrapping. Existing wraps return the same instance
without advancing the counter. Drag drafts send this identity; shared validation
compares it, preserving rejection of an outdated draft even when the replacement
has the same rawcode. These session IDs are not saved or derived from native IDs,
local UI, wall-clock time, RNG, or per-client metrics. Item creation/first wrapping
must continue to occur on every client in the same order; local presentation must
never lazily create a managed item. Diagnostics now include logical identities
alongside the intentionally client-specific native IDs.

`test_item_sync_identity.lua` executes actual creation/wrapping code on mocked
clients with different native handles. `test_inventory_sync.lua` now deliberately
uses different source/carrier native IDs, covering empty-backpack moves,
same-type swaps, and stale same-type replacements. These offline tests demonstrate
the corrected validation; they do not establish that all multiplayer faults are
resolved. Retest both host and non-host dragging between empty backpack slots,
occupied slots, equipment and stash with the same fresh build on every client.

## Retired multi-inventory pickup experiment

The experiment below is superseded by [data-backed ground loot](LOOT_IMPLEMENTATION.md).
Current heroes receive no A1GP or pause/revive inventory hooks. Individual drops
use disposable auto-acquire proxies; eight entries form a selectable unit-backed
bundle whose contents remain data until claimed. The text below records the old
experiment and its limitations, not current setup instructions.

The current experiment uses original Inventory `A0KB` plus `A1GP` (base `AInv`).
Both provide six native slots. The helper used to have only one slot; this was
unsafe for UI presentation because the newest inventory may be the visible one.
The managed inventory remains the only persistent equipment/storage model.
`ItemLookup` handles the native pickup event, positions the acquired item to
release its native ownership, then validates and transfers it into the managed
inventory. Rejected acquisitions remain on the ground at the hero.

Never remove either Inventory ability. The previous `GroundPickup.refresh`
removed `A1GP` on every smart-item order and unpause, then used an ability-level
check to decide whether to add it back. The owner's supplied May 2024 discussion
reports that removing even one inventory can disable the unit-wide pickup/UI
state, and that native Inventory queries may alias other inventory abilities.
That makes the old removal/check cycle unsafe; it could leave the hero without
working pickup instead of repairing it. The native ability was also assumed
removable in the earlier mock, which did not test this engine failure mode.

Attachment is now tracked in a weak-key Lua table, independent of native queries.
It happens once at setup. Pause/death marks a restore pending; the helper is
re-added without removing anything, once the hero is alive and unpaused. Both
pause variants and native/custom revive notifications share that pending flag,
so redundant unpauses and duplicate revive notifications do not repeatedly add
inventories. Smart-item orders are diagnostic only and never mutate abilities,
issue movement orders, or create timers. Unexpected native silence/morph paths
may still require separate investigation; this is not a proven general recovery.

With development logging enabled, `GROUND_PICKUP` entries record `setup`,
`restore`, `smart-item`, and `native-pickup`. They enumerate actual ability
rawcodes through `BlzGetUnitAbilityByIndex`/`BlzGetAbilityId`, report counts for
`A0KB`, `A1GP`, and `AInv`, and show reported native size/occupied slots plus the
possibly aliased helper-level query. Enumeration and handles are diagnostic only;
they never decide cross-client gameplay. If smart-item logs appear without a
native-pickup entry, the engine is rejecting acquisition before `ItemLookup`.
Repeated inventory counts in restore logs can also expose native layer growth.

Apply `node cotlua/tools/update_pickup_inventory.js <unpacked-map-directory>`
to update the helper's capacity in both object/skin files before building. This
does not package a map. A fresh map/hero is required to test clean attachment;
a live hero whose inventory was disabled by the old removal path is not repaired
by merely editing the source files.

The local ability insight source is
`B:/cothub/HiveWE 0.10/data/warcraft/ability_insights.json`, entry `AInv`.
[TasInventoryEx's author](https://www.hiveworkshop.com/threads/tasinventoryex.338519/)
reports both pause/revive resets and the restriction requiring a free slot in the
visible/main inventory. That restriction may still prevent six-carrier pickup;
removing our bad removal logic does not prove the restriction is bypassed.
The [Jassdoc alias report](https://github.com/lep/jassdoc/issues/152) separately
documents aliased ability-level/get/remove operations for worker build abilities.

`test_ground_pickup.lua` executes real callbacks on native mocks with aliased
ability-level queries and an inventory-removal function that throws. It covers
idempotent attachment, deduplicated pause/death/revive recovery, diagnostic-only
orders, rawcode logging, rejected/full bags, powerups and untouched carriers.
It cannot prove current-patch native layering or pickup behavior. Test a fresh
hero's right-click pickup with all six carriers occupied on host and guest,
repeat after pause/revival, and check both native item use and the new log entries.

## Immediate local drag previews (2026-10-17)

Inventory and stash dragging now uses a local presentation queue while all item
mutations remain synchronized. Each atomic request supplies a serial plus both
expected logical item identities. The owner can drag a projected item again
before acknowledgement; confirmed state is checked independently on every
client. Rejected requests restore the authoritative layout on the next redraw.
The old 50 ms movement lockout is removed, and inventory trace writes are
buffered by default rather than saving the entire log twice per move.

See [Inventory visual prediction](INVENTORY_VISUAL_PREDICTION.md) for the wire
format, acknowledgement ordering, restrictions, diagnostic setting, and offline
coverage. This preserves the synchronized gameplay boundary; live multiplayer
testing is still needed to establish responsiveness and engine behavior.

## Loot claims (2026-10-17)

`loot_action` sends action, pile ID, logical item ID and expected record revision.
All clients validate current reach, visibility, binding, hero/record state and
inventory restrictions. Record revisions survive re-dropping; native handles,
local pages, highlights and hero-selection UI never decide shared claims. The
fixed loot-frame pool is created on every client, with only presentation local.
Native bundle selection opens the inventory on all clients before returning
control through normal native selection events. See the implementation document
for receipt-based automatic powerups, shared cleanup/expiry, tests and limitations.
