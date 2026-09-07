# Lua architecture boundaries

`cotlua/src/root.lua`, `config.lua`, and `main.lua` are compatibility
entrypoints required by the Warcraft compiler. Their implementations live in
`cotlua/src/bootstrap/`, and `bootstrap/root.lua` owns the source manifest.
Named `OnInit` resources define runtime availability; a source file being
loaded does not mean its API has initialized.

## Ownership rules

- Framework modules may use Warcraft natives and other framework modules, but
  must not mutate gameplay, content, or presentation state.
- Gameplay modules own synchronized state and transactions. They return result
  objects instead of deciding how frames, sounds, or camera state are rendered.
- Content modules register rawcodes, recipes, shops, quests, and abilities.
- UI modules may query gameplay and submit commands. Local-player branches may
  mutate only presentation state.
- Vendor libraries are wrapped and instrumented at their boundary rather than
  reorganized internally.
- Bootstrap owns initialization phases and the source manifest.

First-party source filenames use `snake_case`; named `OnInit` resources use
the corresponding `PascalCase`. A resource may add a contextual suffix needed
for uniqueness (`warrior.lua` provides `WarriorSpells`), but unrelated legacy
filename/resource pairs are not allowed. If a file's introductory comment
labels the source file, that label must match its current basename. Vendor
filenames and initializer names remain unchanged.

Configuration is separated by stability and ownership. `config/rawcodes.lua`
owns shared unit and ability identifiers; `config/item_schema.lua` owns the
serialized item-stat order and immutable item metadata; and
`config/stat_schema.lua` owns stat labels and tooltip parsing syntax. Runtime
stat getters and breakdowns live in `ui/hud/stat_values.lua`, where their
dependencies on profiles, progression, unit state, and world queries are
explicit. Hero definitions and stable boss indexes live in
`config/hero_definitions.lua` and `config/boss_schema.lua`. Main-map geometry,
player help text, hint configuration, and prestige state are owned by their
world, player, UI, and progression subsystems. `config/variables.lua` remains
the compatibility resource for the smaller set of shared runtime state that
does not yet have a narrower owner.

## Runtime diagnostics

Warcraft's Lua runtime does not provide the standard `io` or `debug` libraries.
Runtime failures are therefore reported in game through `DebugUtils`, which
already wraps native trigger actions, conditions, timer callbacks, enumeration
callbacks, and coroutines with its source-mapped `Debug.try` handler.

Do not add a second `pcall`/`xpcall` around those entry points or catch and
rethrow with `error`; that obscures the diagnostic boundary without improving
recovery. A custom callback registry may call subscribers through `Debug.try`
when the subscribers are nested ordinary Lua calls and must be isolated from
one another. Expected gameplay rejection is represented by `false` or a
structured result code, and development assertions report failures with
`print`.

The first extracted domain APIs are:

- `InventoryService.move(pid, from, to)`, which validates and commits a slot
  move/swap and returns `{ok, code, message, changed_slots}`.
- `ShopQuote.evaluate(shop, item, pid)`, which returns an immutable decision
  snapshot with a structured failure reason.
- `ShopTransaction.commit(shop, item, pid)`, which re-evaluates immediately
  before changing currency, components, result items, and stock.
- `GetItemPrice(id, pid)`, which returns a `PriceQuote` indexed by the numeric
  currency constants (`GOLD`, `PLATINUM`, and so on).
- `ItemRuntime.create` and `ItemRuntime.wrap`, which return managed item
  wrappers. The global Warcraft `CreateItem` native retains its original handle
  return contract for generated and third-party code.
- `NotifyItemChanged(pid)`, which publishes synchronized item mutations to UI
  subscribers without making item runtime depend on inventory or shop frames.

The former general-purpose helper module has been removed. Its low-level utility
families live in `framework/collections/table_helpers.lua`,
`framework/wc3/{geometry,effects,groups,audio,unit_animation,unit_helpers}.lua`,
and `framework/ui/{text_helpers,frame_helpers,floating_text}.lua`. Gameplay
operations are owned by focused modules under `gameplay/abilities`,
`gameplay/combat`, `gameplay/economy`, `gameplay/items`, `gameplay/persistence`,
`gameplay/players`, and `gameplay/world`. Existing global function names remain
available to preserve map-script compatibility, but initializers now require the
resource that owns the relevant family instead of a broad `Helper` resource.

The former world timer catch-all has also been removed. Camera locking and the
town camera target are scheduled by `gameplay/world/player_camera.lua`; hero
spellboost and backpack mirroring by `gameplay/players/hero_refresh.lua`;
playtime accounting by `gameplay/players/progression.lua`; fountain restoration
by `gameplay/world/fountain.lua`; rotating hints by `ui/hud/hints.lua`; and the
world-boss hunt timer by `gameplay/world/boss.lua`.

## Persistence format

The rawcode/index mapping lives in `src/config/save_schema.lua`. Entries in
`SAVE_UNIT_TYPE` are serialized indexes and must never be reordered without a
versioned migration.

Character payloads begin with magic `271828`, then
`CHARACTER_SAVE_VERSION`. Version 1 stores these scalar fields in order:

`id, hardcore, prestige, level, str, agi, int, gold, platinum, crystal,
honor, faction_points, time, teleport, reveal, skin`.

Each of the 26 inventory slots follows. A zero item id means an empty slot.
Otherwise the record is `id, stats, extra, socket_count`, followed by
`id, stats, extra` for each socket (up to `MAX_SOCKETS`).

Packed item fields are unsigned:

- item id word: item index bits 0-12, level bits 13-19, quality 1 bits 20-25,
  quality 2 bits 26-31;
- stats word: qualities 3-7, six bits each at offsets 0, 6, 12, 18, and 24;
- extra word: two 16-bit values at offsets 16 and 0.

Legacy character payloads without the magic prefix continue through the legacy
decoder. Unknown magic-prefixed versions fail before profile storage is
committed. Character synchronization uses `physical_slot:payload`, including
empty slots, so sparse profiles preserve checksum positions.

## Development verification

When `DEV_ENABLED` is true, `ArchitectureTests` runs safe checks after
initialization. Additional in-engine scenarios can register with
`ArchitectureTests.register(name, callback)`; callbacks return `true` on
success or `false, message` on failure. Runtime observations are exposed
through `RuntimeMetrics`, including initializer and live-item counters.

`DevRuntimeLog` mirrors DebugUtils output, test results, initializer state, and
metric snapshots to
`CustomMapData\\CoT Nevermore\\dev\\runtime-player-<slot>.pld`. FileIO replaces
the file after every entry, so it can be inspected while Warcraft is running.
Logging is controlled by `DEV_LOG_ENABLED` and uses separate files per local
player. Disable it after the current in-engine verification pass.

Outside Warcraft, syntax can be checked without executing natives:

```powershell
Get-ChildItem cotlua/src -Recurse -Filter *.lua | ForEach-Object {
    lua53 -e "assert(loadfile([[$($_.FullName)]]))"
}
```

Named resources and manifest ownership can be checked without launching the
map:

```powershell
pwsh -File cotlua/tools/check_architecture.ps1
```

This fails on missing or duplicate manifest entries, duplicate initializer
names, unresolved literal requirements, global-to-final phase inversions, and
reintroduction of the retired `Helper` dependency.

Folder moves must preserve `InitTrace` module names, phases, and completion
order. Compatibility globals should be retired only after runtime callers have
been characterized and migrated to owned APIs.
