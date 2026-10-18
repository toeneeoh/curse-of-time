# Inventory visual prediction

The owner sees a drag destination immediately, while actual equipment, charges,
native carriers, stats, and stored items change only in the synchronized command.
This is a presentation queue, not a second inventory. Inspected inventories show
confirmed state. World drops keep their existing ordered gameplay behavior and
are not visually removed before confirmation.

`ui/inventory/preview.lua` copies item references, logical identities, and charge
counts into a disposable view. It replays at most 16 outstanding moves against
the current authoritative inventory and stash. Moves, swaps, and inventory stack
merges are projected, including subsequent drags from a projected destination.
No Item fields, profiles, timers, or native gameplay objects are modified by the
model. Stash transfers remain swaps/moves, matching the stash domain rules.

The atomic `inventory_move` payload is:

```text
serial:from:to:source_sync_id:target_sync_id:x:y
```

Addresses 1 through `MAX_INVENTORY_SLOTS` are inventory slots; stash addresses
add that limit to the stash slot. Destination -1 requests a world drop. Expected
target identity is zero for an empty destination. Logical item identities are
session IDs, never native handle IDs. All clients validate serial ordering,
bounds, both identities, and domain restrictions against real profile data.
Preview state, hover state, and menu state never authorize a shared mutation.

On the owner, receiving the command removes its preview before domain commit.
This ordering matters because stack commits notify UI listeners synchronously.
Every redraw then rebases the remaining queue against current confirmed state;
operations whose expected pair no longer matches are skipped. Rejected moves
therefore restore the real layout, and dependent queued requests are rejected by
the synchronized identity checks. Independent requests can still proceed.
Queue clearing preserves serial numbers to avoid replay rejection after cleanup.
Failed sync sends remove the corresponding local preview immediately.

Normal dragging continues while confirmations are pending. Context actions and
Ctrl-click transfers wait for confirmations because their older protocols use
authoritative slots. Native potion refreshes remain in the synchronized path.
There is no longer a 50 ms post-move timer lockout. A submitted drag renders its
local preview once rather than rendering the previous layout after release.

Inventory begin/end traces stay enabled, but by default they defer persistence
to the existing periodic snapshot (30 seconds), or another immediate log write.
Previously each move saved the entire growing runtime log twice. For a focused
desync reproduction, set `DevLog.inventory_immediate_flush = true` to restore
that eager persistence. With deferred persistence, the latest buffered entries
may be lost on a crash/desync. FileIO.Save uses Preload output and does not
allocate synchronized gameplay handles; changing its cadence is diagnostic only.

Offline validation:

- `test_inventory_preview.lua`: pure model, chained swaps and stash moves,
  partial/full merges, rejection/rebase, queue bounds, and serial preservation.
- `test_inventory_sync.lua`: actual input, renderer, sync handler, and stack
  domain on clients with different native handles and local UI state. Includes
  immediate presentation without real mutation, rapid chains, synchronous stack
  notifications, rejected source/target identities, and stash mouse input.
- Existing drag tracker, tutorial practice, shop synchronization, architecture,
  and LuaLS error checks cover adjacent integration.

These are offline regressions, not proof of engine multiplayer behavior or a
measured latency improvement. Test host and guest with identical builds: rapid
empty/occupied/equipment/potion swaps, partial/full stacks, inventory/stash
chains, rejected equipment/locked-row moves, item replacement during a pending
request, and closing/reopening the UI while confirmations arrive. Confirm both
visual rollback and matching final equipment/stats on every client.
