# Item ability activation audit

Reviewed 2026-10-07 against the item modules and the active map's merged item
object/skin tooltips. `ACTIVE` describes player activation, not whether an
ability needs to be attached to a native inventory carrier. The six dummy IDs
remain slot/cooldown identities; their instance flags follow the assigned spell.

## Active

- Blade Storm and Stomp (`A07G`, `A0B5`).
- Thanatos Wings cycling and item blinks (`A01F`, `A03D`, `A061`, `AIbk`,
  `A018`, `A01S`). Wings remain active despite also having equip effects.
- Paladin Book, Instill Fear, Darkest of Darkness, Astral Freeze, Final Blast,
  and Banish Demon (`A083`, `A02A`, `A055`, `A0SX`, `A00E`, `A00Q`).
- Crystal Ball, Sea Wards, and Jewel of the Horde (`AIta`, `A0E2`, `A0D3`):
  native reveal/ward/summon casts, even without Lua `onCast` implementations.
- Basic/Advanced Chisel (`A00D`, `A01G`) and Vanguard Bounty (`A1VB`).

## Passive

- All seven Block variants (`Zs00`–`Zs06`), Mana Flow (`A0C0`), Horse Boost
  (`A09O`), Resurgence (`Areg`), Powerful Strike (`Abon`), Siphon Blood
  (`Ahrt`), and Intense Focus (`A0B9`): equip buffs, periodic effects, or event
  callbacks rather than player casts.
- Both reincarnation variants (`Anrv`, `Arrv`): their Lua `onCast` handlers are
  invoked by the death/revival system, not manual item activation.
- Empyrean Song, Unholy Aura, Detection, Endurance Aura, Vampiric Aura, and
  Command Aura (`A04I`, `A03G`, `Adt1`, `A03F`, `A03H`, `AIcd`). These retain
  native attachment through `ITEM_NATIVE_ABILITY` to preserve existing aura
  and detection behavior, while their carrier is marked not actively used.

## Existing unregistered references

The live map also contains tooltip tokens for seven passive effects that have
no current `Spell` registration: Lightning Attack (`A0C7`), Ice Attack
(`A0CD`), Evil Vision (`A0CQ`), Life Steal (`AIva`), Armor of the Gods (`Aarm`),
Bash (`Abas`), and Spell Shield (`Assh`). They are classified here as passive,
but this presentation audit does not restore their gameplay implementations.
In particular, the existing removal of Armor of the Gods and Bash definitions
is preserved. Because the item attachment path already skips unregistered
spells, these references are not newly created ability dummies.

## Native slot safety

Ability carriers are non-droppable, non-pawnable, and do not drop on death.
Locks are reapplied after native ability and presentation setup, including the
explicit drop/death-drop boolean fields. Pickup/drop adapters queue recovery of
an escaped carrier to its owning hero/backpack after the native event finishes.
Recovery preserves handles and cooldowns and checks current logical ownership
so it cannot undo an intentional unequip or restore a destroyed item.
Every equipped item has one native carrier, including equipment without an
ability. Carriers show the item's name, icon, charges, and full generated tooltip
(stats, requirements, effects, sockets, and flavor), refreshed by item-change
notifications. Hero-side abilities share their item's carrier; backpack-side
abilities remain on the backpack.

Rearrange equipped items through the custom inventory: carriers follow equipment
slots 1–6 using their existing handles. Cooldown dummy IDs are allocated
independently of position so sparse or rearranged slots cannot duplicate an ID.
Unequipping frees the carrier immediately, while TimerQueue tracks any remaining
hero ability cooldown for restoration on re-equip. Atomic swaps defer attachment
until both slot transitions finish, avoiding temporary overflow in full inventories.
No object-data edits or save-format changes are required.

## Verification

The architecture regression covers all 41 registered rawcodes (33 definitions,
including shared Block/Blink variants) and requires native attachment for the
six aura/detection definitions. In-game checks should compare Block with an
active spell in the same native inventory slot, then verify auras, Detection,
automatic reincarnation, and both native-targeted and instant active casts.

The mocked regression also exercises the actual dummy assignment function:
run `cotlua/tools/test_item_ability_classification.lua` from the repository
root with a Lua interpreter. It checks instance flags and native attachment,
plus six-item mirroring, full tooltip refresh, slot swaps, deferred attachment,
and cooldown restoration. It cannot prove the engine's rendering or aura effects.
