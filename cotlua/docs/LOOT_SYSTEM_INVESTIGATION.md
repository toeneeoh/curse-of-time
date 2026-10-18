# Ground loot investigation — 2026-10-17

Historical investigation before implementation. The approved design is now
implemented with an eight-entry threshold; see [current implementation](LOOT_IMPLEMENTATION.md)
for actual behavior, validation and limitations. No in-engine performance
benchmark has been run. The discussion below records design considerations.

## Recommendation

Prefer a **single selectable unit per pile**, opening a loot
window with the stash's layout, twice the slot-grid width, anchored beside the
inventory. Use this as the first interaction prototype. A powerup
marker remains a benchmark comparison, not a settled requirement.
The per-drop-unit concerns in the alternatives table do not establish that one
unit representing many rewards is unsuitable.

For this variant, a marker unit has no inventory or stored native item handles.
A synchronized `LootPile` record owns the contents and a stable pile ID; the unit
only provides a model and native selection target. Selecting it opens the loot
panel and the player's inventory. Selection handling should return control to
the player's hero without disturbing the map's shared selection bookkeeping.
Inspection can be separate from interaction distance; taking/binding still
checks the real hero's reach and eligibility in the synchronized service.

The unit should be stationary, selectable, invulnerable, and have no collision,
attack, acquisition behavior, or reward/death logic. Explicitly exclude its type
from combat/threat/reward/enumeration consumers; do not give it Locust if normal
selection is required. UI claims transfer records directly through the inventory
domain, so ground acquisition no longer depends on a native inventory slot or
powerup consumption. Remove the marker when its last record is claimed/expired.
Empty/removed piles invalidate stale commands through logical IDs/revisions.

The current stash anchors TOPRIGHT to the inventory's TOPLEFT at (-0.006, 0),
with height 0.232, slot-grid width 0.1981 and fixed horizontal chrome of 0.072.
Doubling the grid gives proposed width 0.4682 (2 × 0.1981 + 0.072), retaining
the same height, icon size, row spacing, anchor and close-button standard. With
the inventory at x=0.575, its left edge would be about x=0.1008. This doubles
the item columns, not the title/padding. Reuse the same companion-panel space:
opening loot closes the stash, and opening stash closes loot. Pagination changes
the records bound to 72 reusable buttons; no rows are purchased or unlocked.
Actual layout, tooltips and selection still need in-game verification.

Prototype **Lua-backed loot piles with one simple unit marker per pile and
one reusable, paginated loot window**. Compare with powerup and
effect-only/label-driven variants. The principal saving is representing many
unclaimed rewards as data rather than creating an engine item for every reward.
The marker's type is a secondary decision and should remain replaceable.

Store rewards as records at drop creation. Do not first create all the normal Item wrappers
and then hide them in a bag: that retains most native objects and creation work.
Equipped/owned inventory items can continue using existing native carriers;
there is no need to rewrite every item ability to test a ground-loot redesign.

## Bundle threshold and addition feedback

Start the prototype with a configurable threshold of **eight nearby compatible
item records**. Count distinct item entries, not charges: a stack of 100 ore is
one entry. Compatibility includes access/ownership, encounter and quest rules,
not just spatial proximity. This is a proposed usability setting, not a measured
optimal threshold.

Below the threshold, expose individual rewards as lightweight powerup pickup
proxies referencing the same frozen records. They can be collected directly
without opening a bundle, including with six occupied native inventory slots if
the native powerup proof succeeds. They are not full managed Item wrappers and
do not have another native item hidden elsewhere. The proxy needs the explicit
consumption/disposal path described below. Ordinary native item drops would
reintroduce the original full-inventory pickup restriction.

When the eighth compatible entry arrives within the fixed merge radius, retire
the individual proxies and expose one selectable bundle unit. Transfer record
references without materializing, destroying/recreating their rolled item data,
or rerolling anything. A new reward near an existing compatible bundle joins it
immediately, regardless of the new reward count. Ignore stale proxy orders by
stable record ID and marker generation; retirement invalidates queued commands
to the old world representation. Claims and conversion must be serialized in the
same synchronized service so simultaneous pickup cannot duplicate or lose loot.

Once formed, retain the bundle until empty. Taking it below eight entries should
not repeatedly expand it back into ground pickups. A player already using the
window can take the remaining entries normally. Existing panels update by record
revision; entry clicks never identify rewards by a shifting page slot alone.

On a successful addition, show a brief, simple non-looping gold pulse on the
bundle unit. Batch additions for about 0.2 seconds per bundle before emitting
the pulse so simultaneous pack deaths produce one feedback event. The first
formation uses the same cue. Keep the effect short-lived and explicitly remove
it through a shared scheduler. The visual signals that loot arrived and where
it went; item counts in the open window update immediately rather than waiting
for the cosmetic batch. Floating text is not necessary for the first prototype.
Feedback should not allocate a traveling effect or poll movement for every
reward. Effect lifetime, aggregation, and any visibility filtering must not
influence shared drop/claim state or create divergent gameplay handle allocation.

The threshold increases transient proxy creation in sparse areas; include
formation/retirement bursts and dense sustained farming in the benchmark. The
steady-state bundle-object example below still applies once piles have formed.

This is the strongest practical candidate from the code/API investigation,
not a measured claim that it is the fastest implementation on the current patch.
The initial prototype must establish claims with six occupied native slots,
marker cleanup, selection/control handling, and reliable reopen behavior.

## What the current code does

Relevant sources (line references as inspected on this date):

| Source | Finding |
| --- | --- |
| `src/gameplay/world/drop_table.lua:212,292,414` | Ticket, boss equipment, and ordinary drops instantiate managed native items; these paths pass 600-second expiry. Other reward paths call subsystem factories. |
| `src/gameplay/items/item.lua:421` | Creation allocates a native item and a dedicated death trigger, assigns a logical sync ID, rolls quality, builds managed tables, and caches presentation/stats. Tiered items call `update`; boss level adjustment can rebuild presentation again. |
| `src/gameplay/items/item.lua:496` | Every managed item registers a death event. Expiring items enqueue one TimerQueue callback each. This is **not** one native timer per item; TimerQueue shares a native timer. |
| `src/framework/scheduling/timer_queue.lua:247` | Inserting a delayed callback walks the ordered linked queue. Large outstanding expiry populations can add insertion work even without many native timers. Actual time cost is unmeasured. |
| `src/gameplay/items/item.lua:261,1847` | Item death schedules destruction after two seconds. Destruction clears the registry, destroys its death trigger, restores item life to 1, removes the native item, and clears the wrapper's handle fields. The map already addresses the historical dead-tome cleanup pattern for items that reach this managed path. |
| `src/gameplay/items/item.lua:1885` | Expiry destroys only unheld, unbound items. It is a one-shot creation deadline, not a universal ten-minute ground lifetime. Bound items are exempt; a deadline that passes while held is not restarted by a later drop. |
| `src/gameplay/items/item.lua:500,1847` | Creation's expiry callback ID is discarded. Early destruction does not cancel that callback, so its arguments retain the wrapper until the deadline. This is temporary retention, not proof of a permanent native leak. |
| `src/gameplay/items/item.lua:573` | Six equipped positions can each have a native ability/display carrier. With all six occupied, extra-inventory storage does not guarantee that native ground acquisition is accepted. |
| `src/gameplay/items/item_lookup.lua:41` | Automatic-acquisition items currently follow the powerup lookup path rather than normal equip. A proxy must be recognized **before** generic wrapping/automatic-item handling. Merely changing all drops' auto-use flags is insufficient. |
| `src/gameplay/items/item.lua:775,1303` | Detailed inspection, ownership, level requirements, slot restrictions, and uniqueness are existing item concerns; retain these rules in the new claim transaction. |
| `src/gameplay/items/runtime_item_definitions.lua:223` | Logical factories still create a native carrier before applying their definition. They are not yet handle-free ground records. |
| `src/gameplay/items/boss_equipment.lua:89` | Boss-preview presentation temporarily constructs and destroys an item. This cannot be used from a client-local loot hover; presentation needs a pure record/definition formatter. |
| `src/gameplay/persistence/profile.lua:1148` | Inspection already has a data-snapshot precedent. Ground records must preserve more than a minimal display snapshot, including exact runtime state. |

Several special/quest rewards have no expiry argument. This should be audited by
category rather than silently imposing a new lifetime on every item. Current
bound/quest protections must not be sacrificed to meet a native-object target.

## Alternatives

| Representation | Useful properties | Costs / limitations | Assessment |
| --- | --- | --- | --- |
| Normal native item per drop | Native targeting, tooltip, movement | Full-six pickup blockage, per-item objects/triggers/callbacks in current implementation | Baseline only |
| Powerup proxy per drop | Candidate for native acquisition with all six occupied; native target for commands | Still one world item per reward; separate real hidden item would double objects; consumption cleanup must be explicit | Pickup proof, limited long-term clutter reduction |
| Effect per drop + custom input | No inventory gate; effects can be positioned and destroyed | Effect is not a native item target; needs picking, movement/range checks, inspection and claim flow; complex particle models can still be expensive | Credible comparison, not automatically cheaper |
| Trackable per drop | Native hover/click events | No standard move/removal API; triggering-player workaround; unsuitable for constantly spawning/expiring objects | Reject for dynamic loot |
| Unit per drop | Native targeting/selection and an approach-order target | Adds unit machinery and requires exclusion from combat, threat, death, reward and enumeration paths; Locust removes useful interaction | No compelling reason to choose it per reward without benchmarks |
| Frame label per drop | Can show names, tooltips, details, bind and claim actions | Camera projection, overlap, UI hitboxes, fog/vision filtering, custom approach logic; unbounded labels reproduce clutter in UI | Optional bounded presentation layer |
| Data-only contents + one marker per pile | Far fewer native world objects, native interaction candidate, full hover/detail/bind UI | Needs record/materialization split and shared claim service | Recommended prototype |

Frames do not inherently prevent inspection or pre-pickup binding. A frame can
display the frozen record and send a bind/claim command by logical ID. The
difficulties are input, layout and shared validation, not the absence of a native
item handle. A label UI can be added to the same loot data later without changing
drop generation or ownership rules.

## Proposed behavior and boundaries

1. On a synchronized drop roll, create a compact record with a monotonic loot
   ID, definition/rawcode, level, exact quality, charges, sockets, custom potion
   or other persistent state, binding/eligibility, origin, and expiry. Freeze all
   randomness now. Hovering, changing pages, or materializing must not reroll it
   or advance global gameplay RNG. Share immutable definitions between records.
2. Use a spatial index and a small fixed merge radius, initially around 200–300
   world units for testing. Assign to a compatible nearby pile using deterministic
   ties. Compare distance to its fixed anchor so chained merges cannot pull loot
   across a dungeon. Preserve quest, encounter, location and access boundaries.
3. Render one simple selectable unit for the pile, configured and excluded from
   combat systems as described above. It contains no native item inventory.
4. Selecting the unit opens its contents for that player without awarding any
   ownership. Keep selection and native object lifecycle synchronized, with only
   panel presentation local. Test repeated opening and restoration of hero
   control. A powerup comparison would instead open on native acquisition, remove
   its consumed proxy explicitly, and recreate the marker after the event if
   contents remain; its full-inventory and cleanup behavior need separate proof.
5. Open a 12-column × 6-row window for that player. Reuse 72 item buttons and their
   tooltip frames across pages. Populate visible entries only and cache formatted
   text by record revision. Do not create one UI object per stored reward or scan
   the entire world to refresh a page. A 72-button layout still needs resolution
   and tooltip-size checks; it is a proposed capacity, not validated UI geometry.
6. Allow inspecting and binding an individual entry before taking it. Binding
   restricts that record; it must not silently reserve the whole pile. Reuse the
   game's intended binding rules and reach/eligibility rules. Items can remain
   visible as unavailable to other players without allowing them to claim them.
7. Send `pile_id, loot_id, expected_record_revision, action` through synchronized
   commands; never use page/index or native handles as identity. Validate hero
   identity/alive state, allowed distance, vision/access, ownership, record state,
   capacity, level/type/unique constraints and expected revision on every client.
   Two simultaneous claims have one winner in synchronized delivery order.
8. Materialize the existing managed item only for a successful claim, restoring
   exact frozen state without rolling again. Separate validation/prepare from
   commit so failure leaves the reward intact and does not announce ownership.
   If a temporary native object is required during migration, allocate it only
   during synchronized claim, clean it on failure, and measure that cost. On a
   wholly absorbed compatible stack, data can transfer without a new carrier.
9. Track expiry centrally using a heap or time buckets and one shared scheduler.
   Preserve each reward's original deadline; adding new contents must not refresh
   old loot indefinitely. Use deterministic work budgets and release obsolete
   references. Bound/quest expiry is an explicit gameplay-policy question; keep
   current protection by default and use grouping to reduce its world footprint.
10. Keep UI page/hover state client-local. Native proxy and owned-item creation,
    cleanup, binding and claims execute identically on all clients. Pre-create
    and reuse the frame pool on all clients. Local camera/visibility/labels must
    never determine shared mutations or ID allocation.

Display/inspection should be separable from claim reach. A player can see a pile
without being entitled to take it remotely. The first prototype can require
arrival to open the window; a later visible-pile preview can allow remote
inspection while keeping bind/take subject to the same shared distance checks.
The selected-unit version can reject out-of-range claims without movement polling;
automatic approach, if added later, is a separate interaction choice.

For bosses, create one encounter pile rather than many individual ground items.
Keep distribution state in the record, separate from physical marker state. That
supports a future roll/bid service without redesigning storage, but does not itself
implement reservations, bidding currency, winner selection, or new loot policies.

## Leak handling and benchmark gates

Historical powerup reports describe consumed items dying without ordinary decay.
The existing managed path already restores life before removal, but new raw
proxies will bypass it. Give them one explicit lifecycle: active → consumed →
removed, with registry cleanup and idempotent disposal. If current-patch tests
show restoring life is needed, restore it immediately before final removal after
the event. Ensure reentrant death/pickup notifications cannot dispose twice or
recreate a deleted pile. Use one bounded cleanup queue, not one permanent death
trigger or native timer per pickup. Avoid pooling consumed item handles until
reuse behavior is demonstrated; a small bounded allocation rate is preferable
to keeping dead objects forever. Effects must likewise be destroyed, and Lua
references released. None of these facts establishes zero internal engine leaks.

Illustrative object accounting, **not FPS or memory measurements**: if 1,200
unclaimed rewards occupy 24 compatible pile areas (50 per pile), today's path
has roughly 1,200 native reward items, 1,200 death triggers and 1,200 expiry
callbacks. A data-backed pile implementation would have 24 marker items, 1,200
compact records, one shared expiry scheduler, and one fixed UI button pool per
client, with no native item per unclaimed record. That is 98% fewer ground-item
instances in this example, not a claim of 98% less lag. In dispersed loot, there
may be nearly one marker per record; grouping benefits are workload-dependent.

Compare on the same map/build, camera, graphics settings, models and hardware:

- Baseline; individual powerup proxies; data-backed powerup piles; data-backed
  effect piles with bounded labels. Include unit proxies only as a measured
  challenger if needed, not an assumed improvement.
- 100, 500, 2,000 and 5,000 rewards, both concentrated and spread across the map;
  also realistic sustained kill/drop rates over at least the current lifetime.
- Stationary/camera-panning frame time, worst spawn bursts and percentile stalls;
  camera away from loot to distinguish rendering from simulation cost. Separate
  native marker cost from model/particle cost using equivalent simple visuals.
- Lua generation, formatting, grouping, claim and expiry time; callback backlog,
  known live items/triggers/effects/markers, records, tooltip cache and UI updates.
  Record object counts directly; GetHandleId growth is not a leak measurement.
- Repeated create/claim/expire cycles and long soaks with no gameplay logs saved
  in the hot path. Track post-cleanup counts and process-memory trends; engine
  allocator caching means memory alone cannot prove a leak or its absence.
- Host/guest concurrent claims, binding races, full bags with partial stacks,
  all-six native slots occupied, invalid level/binding, death/revive/pause,
  stale pages, expiry while a window is open, zone/quest eligibility, and player
  departure. Final loot/owned-item state must match on all clients.

Before a full rewrite, a tiny disposable native proof should demonstrate pickup,
cleanup and reopening with a full inventory. Then a side-by-side density test can
choose the marker. Offline mocks can validate record state transitions but cannot
establish engine cleanup, targetability, frame time, or multiplayer stability.

## Sources

- [TasInventoryEx, author documentation and replies](https://www.hiveworkshop.com/threads/tasinventoryex.338519/): extra inventories still require a free visible slot for acquisition.
- [Tirlititi's Item Cleanup](https://www.hiveworkshop.com/threads/system-item-cleanup.175663/): historical dead-powerup removal and restore-life-before-removal workaround. Treat age/version limits explicitly.
- [Item Cleanup 1.3, authors' resource and discussion](https://www.hiveworkshop.com/threads/item-cleanup-1-3.201057/): shared queued cleanup rather than a timer per consumed tome.
- [Jassdoc API declarations and annotations](https://github.com/lep/jassdoc/blob/master/common.j): trackable API lacks destruction/movement; item boolean setter interactions; frame creation/reuse restrictions. It does not provide comparative loot benchmarks.
- [Trackables tutorial, author explanation](https://www.hiveworkshop.com/threads/trackables.176983/): immovable/non-removable trackables and triggering-player workaround.
- [Fast World2Screen Transform, author's implementation](https://www.hiveworkshop.com/threads/fast-world2screen-transform-synced-async.354017/): custom labels can be projected from world coordinates. Its microbenchmark is not a benchmark of this map's loot UI.
