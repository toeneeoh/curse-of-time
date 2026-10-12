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
  request containing source, destination, source native item ID and drop
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
