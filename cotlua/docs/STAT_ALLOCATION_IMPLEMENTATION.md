# Stat allocation

Implemented 2026-10-17. This supersedes the initial UI and balance proposals in `STAT_ALLOCATION_ANALYSIS.md`.

## Player behavior

- All 19 selectable heroes start with a shared 35-point attribute budget, distributed for their role and resource needs in `config/hero_definitions.lua`. These starting points are separate from assignable level/purchase points. Bloodzerker has no starting Intelligence; Vampire retains Intelligence for blood capacity and equal Strength/Agility for either build path.
- Early levels award eight assignable stat points per level. Awards rise by two or three points every ten levels beginning at 110, reaching 24,980 earned points at level 500. Level one starts with the hero's existing attributes and no level-earned points.
- There is one point balance and one allocation panel. Choose +1, +5, +10, +100 or All, stage changes with the attribute +/- controls, then Apply. The preview shows the resulting base attributes. Minus removes only staged changes.
- A `ReplaceableTextures\CommandButtons\BTNStatUp.blp` icon appears centered above the two inspect buttons when points are unspent, with a 0.03 gap above their top edge. It renders under `ConsoleUIBackdrop` while keeping its anchor relative to Inspect, so native and inspected-spell tooltips cover the reminder. Its tooltip shows the remaining points; there is no adjacent count text. It opens the owning player's allocation regardless of which unit is selected or inspected.
- Stat View has an attribute icon on the right of its existing tab strip. The original row positions and 28-row page capacity are retained.
- The allocation panel has no title header, uses wider left padding and the standard Cancel close icon at the top-right corner (moved 0.02 outward on each axis). Its height is 0.27 without Auto Allocation and 0.36 with it. The ratio labels, fields and buttons are entirely hidden without the perk.
- Reset in Town costs 100 gold per hero level and requires confirmation displaying that fee. It refunds assigned points, retains purchased points, disables automation and visibly clears the ratio to 0/0/0. Reset copy describes the points and ratio, without mentioning a plan. It grants no gold. Town, church and tavern use the existing service-area predicate. Both the panel and shop reset validate funds and the confirmed price through the same service; platinum can cover gold with change.
- Click callbacks toggle the actual trigger frame disabled/enabled before acting to release native keyboard focus. Icon buttons inherit this behavior from SimpleButton; the allocation panel's text buttons handle it locally.
- Button actions play local click feedback using sounds created once on all clients. Already-playing sounds finish naturally; rapid clicks do not force StopSound/start cycles. Successful manual Apply plays a skill-up sound and a short synchronized hero effect. Rejected requests play error feedback and produce no hero effect.
- The tutorial covers opening the panel, choosing an amount, adjusting attributes, applying the preview and resetting in town. Its no-hero preview is safe and does not discuss progression formulas or prestige.

## Increasing point awards

One point always adds one base stat at every level. There is no attribute multiplier, no bonus applied to starting attributes and no separate percentage allocation. Purchased points use the same one-for-one conversion.

The award for gaining level L is `8 + floor(27 * max(0, floor((L - 100) / 10)) / 10)`. Each threshold increases the award for subsequent levels until the next threshold. Earned points sum the awards for levels 2 through the current level; multi-level gains use the difference between cumulative budgets.

| Level reached | Points for that level | Total earned from leveling |
| --- | ---: | ---: |
| 100 | 8 | 792 |
| 110 | 10 | 874 |
| 200 | 35 | 2,789 |
| 300 | 62 | 7,486 |
| 400 | 89 | 14,883 |
| 500 | 116 | 24,980 |

Base attributes are rebuilt as `starting attribute + assigned points`. Equipment and buff bonus fields are untouched. Native attribute growth is disabled when creating a hero. Repeated level events do not award additional points, and automation distributes only the newly earned cumulative-budget difference.

## Automation perk

Auto Allocation is a one-point Legacy node directly connected to Origin. Its permanent save ID is 242; previous IDs and prerequisite paths are retained. The ninth allocation word is appended to profile saves. Existing profiles read a missing word as zero.

Per-character STR/AGI/INT weights accept integers from 0 to 100. Enabling automation requires at least one positive weight; 0/0/0 is valid while disabled, including across saves. Default weights are 1:1:8. Enable Plan automatically assigns future level points and purchases. Existing unspent points remain manual. Save Ratio updates the weights without changing the enabled/paused mode.

The smooth weighted scheduler carries integer rounding between awards. Ten eight-point awards at 1:1:8 yield exactly 8 STR, 8 AGI and 64 INT. Losing or resetting the perk stops automatic assignments even if the character remembers an enabled plan.

## Shop and economy

The magic/time shop has one virtual Stat Points offer rather than four attribute tomes. It opens the existing bundle and confirmation flow and credits the common point balance. The former tome action IDs resolve to this same offer.

The diminishing-return formula, currency denominations and level cap are retained. The pricing/cap input is:

`starting STR + AGI + INT + cumulative level-earned points + total purchased points`

Unspent points count, so delaying allocation or resetting cannot improve a quote. The old Focus action, if invoked, uses the same paid reset without a gold refund.

## Persistence

A mandatory 12-integer versioned allocation tail follows character stash records. It saves purchased points, the three assigned totals, automatic-mode state, weights and rounding carry. Drafts, frame state, generation and revision counters are not serialized. The tail's format version is 2.

There is no character-save migration or inference of former stat purchases. Missing, incomplete or unsupported allocation data is rejected. Character saves also require the current character magic/version. Newly created characters start with an empty allocation ledger.

The beta character version is 0x40000004, matching the current schema revision. Earlier betas used 0x40000002 for incompatible character/item layouts; they now fail at the version check before item/socket parsing. The profile version is unchanged. Current-format inventory and stash items, their sockets and runtime state, and cleared allocation ratios are covered by offline round-trip checks using the real DTO and runtime architecture callbacks.

## Synchronization

Frames are constructed on all clients. Opening, drafting, changing step amounts and editing ratios are local presentation operations. Apply, plan changes and reset send numeric requests through `stat_alloc`. Authoritative callbacks validate sender, hero generation, draft revision, budget, perk access and service-area eligibility. No mutation reads inspected-player state or local draft tables.

Base-stat updates suppress intermediate stat events and publish one final change. They never rewrite another subsystem's bonus contribution.

## Verification and in-game checks

Offline checks exercise the real model, allocation service, character serialization/deserialization methods, rejected old formats, tome quotes/commits, UI callbacks, tutorial navigation and perk graph. Frame mocks do not verify actual rendering or multiplayer execution.

Before distribution, test:

1. Gain one and several levels on a new hero. Verify eight points per early level and the larger later awards, without native attribute growth. Inspect another unit and confirm the HUD shortcut opens your own allocation.
2. Use each bulk amount, apply a draft and close another draft without applying. Spend the final point and verify the HUD reminder disappears.
3. Cross levels 109 to 110 and 119 to 120, then jump to 500. Verify awards of 10, 13 and 116, and 24,980 total level-earned points at 500. Assign +1 at each level and confirm it always adds one base stat, with starting and bonus stats unchanged.
4. Buy, allocate and reset points. Verify an unchanged point-purchase quote at the same purchased count and level, the displayed level-scaled reset fee, correct platinum change, and rejection of insufficient funds, changed prices and resets outside service areas.
5. Unlock Auto Allocation, enable 1:1:8 and gain ten levels. Verify 8/8/64 assigned points. Purchases follow the plan, existing banked points stay manual and resetting perks stops automation.
6. Save/reload assignments, purchases, ratio, enabled state and rounding carry. Confirm saves without the required allocation data are rejected without conversion.
7. With two clients, allocate simultaneously, inspect one another and navigate the tutorial before hero selection. Confirm only authoritative requests change the sender's hero and check frame positions at supported aspect ratios.
