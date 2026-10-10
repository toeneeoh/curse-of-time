# Profile perk tree

The graph has 240 spendable nodes. Each character awards 4 softcore or 6 hardcore
points per completed milestone (Naga and Scarab), for 8/12 points per character.
Completing both milestones on twenty hardcore characters funds the entire graph.
This is the initial expansion target, not a change to milestone rewards.

The original combat bonuses remain, with small investments leading to payoffs:
0.25% attack damage/Spell Power/Spell Area/Spell Duration, 0.5% armor/regeneration, 0.1% resistance/drop rate,
1 movement speed/critical damage, and 0.5% gold find per filler node. Larger icons
denote larger bonuses within the same effect; equal bonuses have equal sizes.

## Investment and payoffs

Comparable minor/major bonuses now share progression paths instead of competing
as separate high-value and low-value purchases. The first reward follows four
minor nodes; the next two rewards each follow three more minor nodes. All nodes
still cost one point. Branch choices separate specializations early, while deeper
rewards require committing more of the profile budget.

For movement, the path is four +1 nodes, then +5 (5 points for +9 total), three
more +1 nodes, then +5 (9 points for +17 total), and three more +1 nodes, then +10
(13 points for +30 total). Continuing reaches the existing deeper +5 nodes.
The same investment pattern gates attack, Spell Power, Spell Duration, Spell Area,
critical damage, armor, regeneration, damage/magic resistance, gold find, and drop rates.
The area and duration investment paths replace the former mana-recovery lanes;
the deeper Legacy mana-recovery nodes remain. Each utility path totals +8.5%.
Experience remains five +2% nodes, reached through the movement entrance; it is
not mandatory travel to gold/movement specializations. Potion duration and extra
reincarnation capacity retain their long utility investment paths.

## Utility paths

These are maximum bonuses from allocating the relevant paths, not starting perks.

| Effect | Maximum | Behavior |
| --- | --- | --- |
| Shared experience rate | +10% per profile | Five +2% nodes; active profiles stack across the lobby. |
| Potion restoration | +9% | Multiplies actual health/mana restoration, including the rolled percentage amounts. Does not rewrite item rolls. |
| Infusion duration | +10% | Multiplies duration for effects that use the potion's duration multiplier. |
| Potion refill savings | 12% | Reduces the actual service quote; applies to flasks throughout inventory. |
| Reincarnation gold savings | 9% | Reduces the gold portion of the recharge price; platinum is unchanged. |
| Reincarnation capacity | +1 charge | Rechargeable items may hold four charges instead of three. Charges are purchased normally; cooldown and currency checks remain. |
| Return Home | 25% shorter channel | Applies after teleport level scaling; never shortens the channel below one second. |

The two former experience nodes in Legacy now grant refill savings and infusion
duration, retaining their node IDs and allocations. Bounty auto turn-in is unchanged.
Utility branches remain available near the Legacy entrance. The refill reward
now follows four smaller refill investments, and the Legacy movement rewards
require Return Home investment instead of serving as cheap movement shortcuts.

## Layout and persistence

The tree opens at a usable scale around its origin. Drag and zoom to explore;
the All button provides an overview, and branch buttons fit their respective paths.
Branch names stay in the header so they cannot overlap nodes.

All nodes occupy four separate cardinal districts. Positions follow prerequisite
subtrees with disjoint branch corridors instead of independently placed rings.
Districts share only the origin. Unrelated primary paths neither cross nor overlap;
The former alternate bridges have been removed where they bypassed investment.
Node tooltips explicitly name their prerequisites. Effects, costs, and saved IDs
remain; prerequisite paths have changed.

Panning translates one parent canvas. Allocation styles are cached until profile
state changes, and hidden geometry is updated only when it enters the viewport.
Connector legs are individually clipped to the viewport, independently of endpoint
icon visibility. Only partially clipped lines need geometry updates while panning;
fully visible lines continue to move with the canvas. The node canvas is above the
background input catcher so nodes retain hover tooltips and click interactions.
Connector thickness has a minimum floor so overview zoom does not shrink strokes
to a small fraction of a pixel. Routes are precomputed, not rebuilt while panning.
The local cursor timer samples at 32 Hz and performs no UI work while stationary.
Offline native-call regressions check these budgets; actual FPS requires playtesting.

Allocations occupy eight positive 30-bit words at the profile's existing tail.
The first three words and all earlier fields retain their positions. Older profiles
with only three words load the five absent words as zero. Character saves and their
milestone masks are unchanged. New nodes append IDs; existing IDs are not reordered.
If a saved build no longer satisfies prerequisites, all spent points are refunded
and a free reset remains available. Earned points and milestones are not changed.
Already-valid builds are retained.

## Testing

Use `-perks 240` for temporary in-game allocation testing. Check the small-bonus
tooltips, utility paths, refill/recharge quotes, four-charge capacity, potion effects,
and Return Home at several upgrade levels. Test allocation save/load with a genuinely
earned budget: development points themselves are not saved.

Offline regressions run real graph, service, potion-use, teleport-channel, and profile
serialization functions with native calls mocked. They do not validate WC3 rendering.
