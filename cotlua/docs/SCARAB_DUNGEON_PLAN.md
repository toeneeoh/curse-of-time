# Scarab dungeon foundation

Status: design direction accepted; a development-only procedural crawl prototype
is implemented. Production entry, enemies, rewards, shared-vision isolation/item lamp rules,
and the boss are not implemented by this prototype. Numbers below remain test
targets, not balance promises.

## Current prototype and map preparation

The allocated area is x = -30000..-20000, y = 20000..30000. The owner will clear
and flatten it in the World Editor. Remove static decorations and pathing blockers,
make it flat/dry/walkable, and paint a cave-floor base. Keep imported art available.
No map binaries or editor objects were modified for the prototype.

`ScarabLayout` generates twelve connected logical rooms, reciprocal cardinal
doors, a few loops, irregular chambers, and winding connecting passages. Six
2624x3136 physical buffers form a 3x2 arrangement wholly within the allocated
rectangle. Centers start at x=-27712 with 2880 spacing: the western buffers move
640 units inward and retain at least 256 units between their physical bounds.
Joining an occupied logical room reuses the same buffer; empty buffers
are recycled with deterministic room shapes. No boss/key/access system yet.

Collision is generated at native 32-unit pathing resolution, with 64-unit layout
cells. Walking/flying availability is snapshotted and restored on stop. Walls use
model effects independently of collision, with one rock per boundary cell;
models, scale, and cap are the `ScarabCrawl.art` palette. The standard Warcraft
`Doodads\\LordaeronSummer\\Rocks\\Lords_Rock\\Lords_Rock0.mdx` model uses scale 1.7
(about 26% larger than the previous pass). The 96-model cap was removed because
it skipped arbitrary boundary cells while retaining their blocked collision. There are
no glowing exit markers. Effects are removed immediately when supported, or hidden
and buried before destruction on older engines, rather than leaving death animations.
No runtime tile painting or terrain height edits: the floor painted in the editor
is retained. The previous registered IDs resolved to unsuitable imported textures.
Construction/decorations/pathing restoration are batched. One 64-unit row per tick,
six rock creations per decoration tick, and cached walk/fly flags limit native work;
recycled buffers update only changed flags. Generation guards cancel stale callbacks.
Optional immediate removal is detected once with rawget, bypassing strict-global
logging when the native is absent. The previous per-rock lookup generated dozens
of warnings and full FileIO log rewrites at transitions, a likely stall contributor.
No rooms, effects, pathing edits, or crawl polling start at map initialization.

Test commands after a normal build/run:

1. Clear and flatten the staging corner before testing. Create a hero normally.
2. `-scarab ready` marks the prepared area for this lobby only. This is a safety
   acknowledgement, not an automatic clearing or terrain validator.
3. `-scarab start 12345` builds the crawl and moves the hero into its entrance.
   Other players use `-scarab start` to join the existing run (its original seed).
4. Use `-lamp` to toggle a warm test light, or `-lamp on` / `-lamp off`.
   Walk into the exits, or use `-scarab n`, `-scarab e`, `-scarab s`, and
   `-scarab w`. Arrival occurs inside the opposite entrance to avoid bouncing.
5. `-scarab leave` returns that player to their original location. Backpack units
   follow. The run remains available for others and revisiting.
6. `-scarab stop` returns remaining explorers, removes generated art, and restores
   saved pathing. Wait for restoration before starting another seed.
7. `-scarab graph 12345` exercises topology generation without altering the map.

Camera targets are restricted to the generated floor's bounding rectangle, inset
384 horizontally / 256 vertically (less in small chambers), rather than the whole
buffer. The actual minimap frame is hidden; no transparent minimap terrain texture
is used. Its previous visibility and camera presentation are restored on leaving.
Ambient lighting uses `blacklight.mdx`, without the Naga green hero ability.
Hero sight is 192 without the test lamp, 700 with it; backpack sight is zero.
The lamp attaches existing `LightYellow30.mdx`. Original sight and normal regional
lighting are restored on exit, death, cleanup, or stop. Shared vision remains unchanged.

This is an exploration test, not a ready-to-play dungeon: no enemies, reward
economy, actual lamp item integration, fog isolation, logical map UI, or encounter persistence.
Summon movement and ground-item/grave snapshots remain future work. Do not leave
valuable ground items in recycled rooms, save a character inside the prototype,
or use the prototype as a hardcore combat area. Runtime tests need to establish
actual wall coverage, collision, door timing, camera behavior, and multiplayer FPS.

## Identity and first recommendation

A subterranean hive that has consumed something older than itself. Exploration
is insect/parasite horror; time distortion becomes increasingly apparent near the
Scarab. This keeps the maggot-cave identity and gives the boss a distinct theme
without making every enemy a time mage.

Recommended foundation:

- A seeded logical room graph, assembled from authored chamber/tunnel templates.
- Personal, short-range visibility; the Sphere of Azazoth serves as a lamp.
- Independent player travel, with one shared encounter state per logical room.
- Meaningful room rewards, optional encounters, one key objective, and a boss.
- A boss whose time pressure is a soft enrage, not an automatic timed defeat.

Do not start with arbitrary terrain generation, shifting live pathing, a mandatory
upgraded-sphere sacrifice, permanent bonus-stat purchases, or full game-state rewind.

## Existing code and content

`gameplay/world/dungeons.lua` supplies queues, readiness, participant lists,
enemy ownership, exit handling, and the Naga dungeon's completion flow. Existing
dungeons are singleton runs with a global queue; reuse those entry semantics for
the first Scarab run rather than introducing concurrent parties immediately.
Its generic startup also applies `DisableItems` and backpack teleport restrictions.
Audit what those restrictions actually block before adopting them: the lamp,
flasks, combat item actives, and reincarnation must not accidentally stop working.

`Perks.completeMilestone(pid, "scarab")` already recognizes Scarab's milestone:
4 softcore / 6 hardcore points, once per character. There is no implemented Scarab
dungeon or Scarab boss registry entry in the inspected source. Do not award the
milestone merely for entering or finding the key.

`gameplay/items/potions.lua` explicitly reserves the stronger Chaos Flask for the
future Scarab dungeon. Use that existing base rather than inventing another tier.

`bootstrap/map_setup.lua` configures directional shared vision between human
players. `gameplay/world/regions.lua` controls regional camera/minimap presentation;
`MoveHero`/world transitions and player lifecycle cleanup must be respected.

Historical object comparison reports identify Sphere of Azazoth objects including
`I0LY`, `I0LW`, and `I0LX`. These are leads, not proof of their current runtime
identity, upgrade rules, or ability behavior. Confirm the actual item definition
before implementation; do not repurpose an unrelated object ID.

## Room model: large dungeon, small physical footprint

Keep two concepts separate:

| Logical room | Physical chamber buffer |
| --- | --- |
| Seeded identity, connections, encounter, remaining enemies, rewards, visitation. | Authored terrain area currently representing that room. |
| Exists for the entire run. | Assigned only while players occupy the room. |
| Revisiting restores its remaining state. | Never grants new enemies/rewards merely because it was reused. |

A 7x7 logical grid is a coordinate system, not 49 mandatory encounters. Start
with 8-12 reachable rooms for the full first version; tune toward a roughly
15-25 minute run after testing. Begin at a sanctuary near the center. Generate
a connected route, a key room off the direct route, optional branches, and a
boss entrance near the edge. All door connections must be reciprocal. Validate
that the key is reachable without passing the locked boss entrance.

Suggested initial room roles: entrance sanctuary, winding combat chamber,
brood chamber, key guardian, optional dangerous treasure room, merchant/rest
room, and boss chamber. Shuffle encounters and door connections first. Two or
three visually distinct authored layouts are better than many empty square rooms.

For six heroes, at most six distinct rooms need to be occupied simultaneously.
A six-buffer pool can therefore support independent travel if only participants
pin rooms. The boss uses a suitably sized buffer from the same pool; a separate
boss arena is an optional terrain choice, not an assumed seventh buffer.

When someone enters an occupied logical room, send them to its existing buffer.
When entering an empty room, assign a free buffer. If every buffer is occupied,
the departing hero must have been their source room's last occupant, allowing
that buffer to be snapshotted and reassigned. Summons/backpacks follow the hero;
abandoned units, missiles, timers, or loot must never keep an empty room pinned.

Transition sequence: validate door/party membership -> guard against repeat
entry -> detach from old room -> snapshot/release if empty -> assign/load target
room -> move hero and owned companions -> set camera/fog presentation -> unlock
input after arrival. Arrive at the opposite doorway with enough clearance to
prevent an immediate bounce back. Do not transition by reconstructing hero units.

Cleared doors remain passable. During an active encounter, gate retreat at a
clearly communicated room boundary rather than letting repeated door crossings
reset enemies for free. A voluntary exit must remain possible through a defined
safe exit/abandon action; death and disconnect cannot leave the run stuck.

## Persistence and deterministic generation

Keep a run seed and independent seeded decisions for topology, encounters, and
rewards. Generate these in synchronized gameplay state, never inside local UI
branches. Room visits and the order players explore must not reroll content.
Use a fresh seed for a new run; a cached seed alone is not an anti-farming policy.

Run state is lobby-local, not character-save data. Persist normal awarded items
and the completion milestone through existing systems. Do not serialize rooms,
temporary keys, time curses, or merchant buffs into character saves.

Ground loot must retain its runtime identity, rolls, sockets, and charges across
room unloading. Store the actual item state; never generate a replacement drop
on revisit. Choose a policy for unclaimed loot and graves before buffer recycling
so neither quietly disappears nor pins more rooms than the participant limit.

The first unload prototype must preserve survivor health, deaths, opened doors,
looted containers, key collection, and whether rewards were already granted.
Empty-room simulation pauses. Extend snapshots to necessary cooldowns/buffs
before admitting encounters that depend on them; avoid assuming a recreated
unit is equivalent to the original. Pending boss fights stay resident for the
first version rather than being unloaded mid-mechanic.
If every participant leaves the boss room, reset the encounter before releasing
its buffer; an empty ongoing boss fight cannot silently consume a seventh slot.

Every buffer assignment has a generation token. Delayed callbacks, projectiles,
and spawn requests check run/room generation before acting so an old encounter
cannot affect whoever next occupies that physical space.

## Darkness, sphere, and navigation

Recommended: no sphere is required or consumed at entry. Without a lamp, players
can explore but have severely reduced warning distance. A carried Sphere provides
a useful radius; upgrades can improve that radius with a cap. Prototype about
200-300 sight without it and 600-800 with it, then judge against actual tunnel
width, camera distance, and enemy speed. These are test values only.

Count the sphere anywhere in the player's carried inventory, not the stash,
unless an equipment-slot tradeoff is explicitly selected later. Check ownership
through the runtime item system, including upgrades. Do not add an unrelated
combat buff just to justify the lamp. Enemies and danger cues must remain legible
inside the lit radius; darkness should create tension, not untelegraphed deaths.

Personal vision needs an early engine prototype. Shared-vision alliances are
directional and player-wide, not regional. Snapshot affected relationships and
restore their previous values; do not blindly enable every alliance on exit.
Keep allies friendly. Test grants in both directions, outside players, invisible
heroes, summons, backpack units, reveal effects, and spectator/developer vision.
Removing shared vision alone does not reduce a hero's own sight.

An outside player's scouting or global reveal must not defeat the dungeon's
darkness. Decide whether outside players can spectate it before choosing the
alliance policy. Preserve camera/minimap state independently for every player.
Restore sight, fog modifiers, alliances, and camera restrictions on every exit,
death policy transition, disconnect, repick, wipe, and failed initialization.

Hide the physical dungeon minimap for participants: recycled buffer coordinates
are misleading. A small remembered logical-room map is preferable eventually;
initially, show the current chamber and discovered exits without enemy positions.
Do not expose the generated key/boss location before discovery. Large irregular
chambers and short entry passages help hide the room-reuse illusion.

## Enemies and reasons to explore

Use a few readable roles rather than walls of generic melee insects:

- Skittering swarm: numerous, low individual health, responsive to AoE.
- Burrower: telegraphed emergence behind or beside the group, not unavoidable damage.
- Brood keeper: spawning priority target, with finite encounter spawn limits.
- Parasite: a visible, short-lived debuff that makes cleansing/status resistance useful.

Room clears grant useful gold/material rewards once, even if the party later
fails the boss. Prefer existing currency/material hooks before creating another
permanent currency. The key should be a party run flag, not an inventory-space tax.

An optional merchant room gives side exploration purpose. Start with a limited
run-local restoration/utility offer and/or an ordinary crafting component offer;
define prices after comparison with Naga income and current crafting costs.
Do not move the Reclusive Blacksmith's jewel crafts into this merchant. A new
carapace currency or highest-tier gem stock needs a separate economy decision.

Run-only buffs can make combat rooms valuable without uncapped permanent stats.
Reward claims and merchant stock belong to the logical run/room, not the physical
buffer. They cannot reset by revisiting. Avoid a mandatory beetle set that players
must already finish farming to be capable of reaching the boss.

## Scarab boss: hive first, time distortion second

Build a recognizable insect boss with three initial mechanics:

1. Brood release: finite waves from eggs; killing priority targets opens room to
   maneuver. Swarm damage should not make every melee approach impossible.
2. Sands of Time: clearly marked advancing sand zones; avoid them or accept a
   temporary aging debuff. A separate temporary healing penalty is a possible
   later addition, not assumed to work through every healing path today.
3. Recall: mark each player's location, give a clear delay, then return affected
   heroes to their own recent safe arena position. This creates positional
   planning without refunding potion charges, mana, cooldowns, death, or rewards.

Recall is a positional mechanic, not a literal Weaver-style restoration of all
state. Keep bounded samples of valid positions while fighting. Never resurrect
dead heroes or move someone through unwalkable terrain, a closed door, or out
of the arena. Telegraphed danger must account for the return location. Start with
one fixed short recall window before implementing elaborate timeline combinations.

Curse of Time starts with the boss encounter, not dungeon entry. After a grace
period, gradually increase incoming damage to participants. Try a 60-90 second
grace, followed by +5% damage taken every 30 seconds, capped initially at +100%.
Treat this as a provisional soft-enrage curve and tune against actual party DPS.
The cap avoids secretly implementing an inevitable timed kill. Keep boss healing,
damage, and phase transitions independent of global traversal time.

Use the Buff/combat modifier system rather than overwriting character stats.
Reset the clock/curse on a genuine wipe or encounter reset, not a single player's
door crossing. No saving the curse. Do not let one leashing player reset pressure
while others continue dealing damage. Declare whether the curse is unavoidable
encounter pressure; temporary parasite/aging debuffs can separately interact with
status resistance so that stat has an actual role.

`ResourceChanges.registerHealAction` currently observes healing after it is
applied; it is not a pre-heal modifier. A healing-reduction version needs an audit
of `HP`, potions, regeneration, native healing, and special survival mechanics.
Do not implement it by subtracting health again from that notification callback.

On victory, use the normal boss drop system and preview for Chaos Flask and gear,
award the Scarab milestone to the eligible completion roster, and open the exit.
Confirm dead-but-participating players versus surviving players explicitly before
copying Naga's current surviving-player list. No milestone on an abandoned run.

## Build order and acceptance gates

1. **Vision/transition spike:** two temporary authored chambers, lamp/no-lamp,
   personal vision, doorway transitions, all exit cleanup. Establish that the
   engine behavior works before committing a large amount of terrain work.
2. **Pure room graph:** seeded generator and validators; connected start/key/boss,
   reciprocal doors, bounded run size, reproducibility. No WC3 frame dependency.
3. **Reusable room prototype:** two buffers, room snapshots, two players splitting
   and rejoining, enemies never respawning/rewarding twice. Model six-buffer
   independent travel even if the first test uses two players.
4. **Exploration slice:** 4-6 logical rooms, basic swarm/guardian, key and locked
   entrance, one optional reward room. Test whether the crawl is fun before scale.
5. **Boss slice:** brood, positional Recall, and soft enrage. Connect existing
   Chaos Flask reward, boss preview, and once-per-character milestone.
6. **Expand and tune:** full reachable-room count, six players, more room templates,
   merchant stock, temporary aging, final rewards/level requirements.

Offline tests: graph invariants, fixed-seed decisions, maximum simultaneous room
occupancy, transitions, generation-token guards, snapshot/revisit state, single
reward claims, and milestone idempotence. Native mocks do not establish fog,
pathing, camera, visual timing, multiplayer synchronization, or performance.

In-game tests: all six players in different rooms; simultaneous joins; last-player
buffer recycling; summons/companions; drops and pickups around doors; casting or
dying during transition; recall while stunned/dead; invisible heroes; leavers;
wipe/restart; outside-player vision; leaving with an unclaimed reward; and return
to normal town sight/camera/minimap after every cleanup route.

## Choices to settle before production

- Personal lamp required, recommended, or an optional difficulty modifier?
  Recommendation: recommended, not a sacrificed entry key.
- Physical staging area confirmed: x = -30000..-20000, y = 20000..30000.
  Map preparation is manual; chamber boundaries and decoration placement are
  generated programmatically. Art can be refined independently of collision.
- Party death/re-entry and completion-credit rules, including hardcore handling.
- Target difficulty relative to Naga/Azazoth and expected character level/gear.
- Fixed seed per lobby/day or fresh per run? Recommendation: fresh per run, with
  rewards validated against restart farming rather than a hidden seed promise.
- Run-local merchant benefits versus a persistent material sink. Avoid permanent
  cap-breaking stats until the broader progression budget is explicitly approved.

The recommendations are accepted as the baseline. Boss/access work is deferred
while the generated crawl is developed. No object-editor changes or new imports
have been made; the runtime generation is behind explicit developer commands.
