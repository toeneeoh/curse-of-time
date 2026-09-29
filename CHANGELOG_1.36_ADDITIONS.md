# Changelog 1.36 — additions pending merge

This file supplements the existing 1.36 draft with notable player-facing
changes. Internal refactors, developer tooling, raw object changes, and minor
visual cleanup are intentionally excluded.

## System Changes

- Replaced Prestige with a profile-wide, persistent Perk Tree. Perk Points are
  earned from character milestones and may be spent on connected offensive,
  defensive, exploration, party, and inheritance bonuses.
- Colosseum Honor, Infinite Struggle records and rewards, faction membership,
  faction rank, Faction Points, and completed faction quest rotations now save
  with the character.
- Expanded the Stat View with additional inspection tabs for perks, faction
  status, event information, and related progression.
- Limited-item swaps between the hero and backpack now unequip the original
  item first and correctly disable invalid equip actions.
- Steepened the reward penalty for fighting enemies far below the hero's level.

## Faction Changes

- Added three joinable factions: Cave Voyagers, Stormwatch, and Ashen Vanguard.
- Faction membership, rank, unspent Faction Points, and completed quest
  rotations save with the character.
- Players may change faction after the switching cooldown instead of being
  permanently locked to their first choice.
- Added rotating faction contracts with reusable objective types, rank
  progression, and Faction Point rewards.
- Completed quests remain locked for the rest of their current rotation.
- Added Cave Voyager mining contracts and interactable deposits. Deposits are
  mined through right-click channeling and include guarded and rare variants.
- Added hourly faction events. Only one faction event is selected for each
  hourly rotation.
- Added the Cave Voyager defense event and its faction reward cache.
- Added the Stormwatch Tempest event, an active survival encounter with scaling
  storm hazards and participation rewards.
- Added Ashen Vanguard rare hunts, empowered rare variants, and the Grand Hunt
  faction event.
- Endgame bosses remain eligible for relevant faction boss objectives.
- Added a unique potion shop for each faction. A faction shop only opens for
  members of that faction, and its flask requires Faction Rank 4.

## Colosseum Changes

- Reworked the Colosseum into a paced 20-wave run with enemy scaling based on
  the participating characters, including bonus attributes.
- Added a wave progress display and clearer encounter presentation.
- Added selectable run Augments, including offensive, defensive, and utility
  choices.
- Added encounter hazards such as spikes, earthquakes, projectile barrages,
  pursuit threats, crossfire, Gravity Well, and Void Sweep.
- Added boss affixes and abilities with visible telegraphs and cooldowns.
- Rebalanced Colosseum tickets, enemy scaling, and gold rewards.
- Colosseum clears award Honor instead of character experience.
- Added reallocatable Honor bonuses at the Prize Vendor. Allocated Honor may be
  reset without losing lifetime Honor earned.
- Added lifetime Honor milestones and improved Honor reward presentation.

## Infinite Struggle Changes

- Completely reworked the existing Infinite Struggle into an endless wave mode
  whose enemy composition and difficulty are defined by the current wave.
- Added melee, ranged, and priority enemies with distinct abilities and clearer
  visual identification.
- Added reward checkpoints where each player may secure the current reward or
  continue at the risk of losing the unclaimed reward.
- A character's best secured wave is saved and used to recommend later starting
  waves.
- Replaced the old fixed Ring/Lesser Ring of Struggle rewards with 100 ranked
  reward levels.
- Added a socketable Struggle Gem form. The Prize Vendor can redeem the highest
  secured rank and freely convert a Ring of Struggle into its gem form.
- Only one Ring of Struggle or one Struggle Gem may be equipped at a time.

## Potion Changes

- Added dedicated, refillable Health and Mana Flask progression for the
  pre-Chaos game:
  - Greater Flasks at level 50.
  - Superior Flasks at level 110.
  - Grand Flasks at level 170.
- Chaos flasks may roll restoration values, maximum charges, and use cooldown
  within their tier ranges.
- Potion healing and mana restoration may include both flat and percentage
  values. Percentage healing is now labelled `Max Health Restored`.
- Flasks begin with their maximum charges, consume one charge per use, and may
  be refilled.
- Added three Rank 4 faction flasks:
  - **Stoneblood Flask — Cave Voyagers:** restores Health and reduces damage
    taken by 15% for 12 seconds.
  - **Tempest Flask — Stormwatch:** restores Mana and makes ability cooldowns
    recover 100% faster for 8 seconds.
  - **Vampiric Flask — Ashen Vanguard:** restores Health and Mana and restores
    8% of damage dealt as Health for 12 seconds.
- Faction flasks have four to eight charges and a level requirement of 200.
- Added a Potion Master in town with separate services for refilling, rerolling,
  and transferring flask prefixes or suffixes.
- The Potion Master can work with flasks in any inventory or backpack slot.
- Potion Services can reroll a Chaos flask's restoration, maximum charges, and
  use cooldown. Its base cost scales with the flask's tier and level, each
  subsequent reroll costs 35% more, and its saved roll sequence cannot be
  changed by reloading.
- Flask rerolls report their new values, with perfect and near-perfect results
  announced to all players.
- Flask prefixes include Vampiric, Stoneblood, Tempest, Aegis, Fury, Arcane,
  Swiftness, Purity, Omniscient, Frenzied, and Phasing. Applying one requires
  extracting it from another flask and consumes the donor.
- Flask suffixes include:
  - **Potent:** stronger infusion effects.
  - **Lingering:** longer infusion effects.
  - **Accelerant:** a shorter potion cooldown in exchange for shorter infusion
    duration.
  - **Bounty:** stronger Health and Mana restoration.
  - **Conservation:** a chance not to consume a charge.
  - **Echoes:** repeats part of the flask's restoration after a delay.
- Chaos bosses can drop prefix or suffix donor flasks. Higher-level and
  higher-difficulty bosses have better odds. Their separate chance to drop the
  two-slot Legendary Flask base is exceptionally rare.
- Prefix effect strength rolls within a narrow range and transfers with the
  prefix when its donor flask is consumed.
- Holding Alt shows the possible prefix-effect and use-cooldown ranges.
- Shop previews show the complete possible flask ranges instead of the random
  values rolled by a temporary catalog item.
- Bounty increases restoration without paying the normal one-affix restoration
  penalty for its own suffix slot.
- Faction flasks carry one transferable faction prefix and do not support a
  second affix.
- Added a Legendary Flask base that supports both a prefix and suffix.
  Each affix reduces its displayed and actual restoration, with a much larger
  sacrifice for using both.
- Flask tooltips now show compact Prefix and Suffix slot states, and upgraded
  flask tiers use the standard item rarity headers and colored borders.
- Prefixes, suffixes, restoration rolls, and escalating reroll costs are
  preserved when saving.
- Moving a different flask into a potion slot applies a 10-second cooldown so
  backpack flask stockpiles cannot bypass normal potion-use pacing.
- Basic Health and Mana Flask tooltips now list their three-second use
  cooldown.
- Added Status Resistance, which reduces the duration of applicable negative
  effects, and Cooldown Acceleration, which makes ability cooldowns recover
  faster.

## Stash Changes

- Added a saveable 6-by-6 personal stash for holding flasks and other items.
- The first six-slot row is available by default. Five additional rows can be
  unlocked from the stash interface for progressively higher gold costs.
- The stash may be viewed anywhere, while depositing, withdrawing, and buying
  rows require the player's hero to be in town.
- The stash opens beside Inventory as a companion window. Items can be dragged
  within either window or moved and swapped between them.
- Ctrl-clicking an item quickly transfers it to the first available slot in the
  other window. Stored items also support Withdraw, Drop, Sell, and Details
  actions from their right-click menu.

## Item and Shop Fixes

- Restored boss-drop level requirements that could be lost during item creation.
- Item spell tooltips now update with the item's current level.
- Holding Left Alt correctly refreshes dynamic item tooltip ranges.
- Fixed item stats not applying when equipped through some inventory paths.
- Fixed max-level socket handling.
- Equipment changes now use whichever result leaves the hero with less current
  Health and Mana: equipping additional maximum resources grants no current
  resources, while removing them lowers current resources proportionally.
- Charge counts are now preserved when saving all charged items, including
  rechargeable resurrection items.

## Boss Changes

- Azazoth is briefly invulnerable when the encounter begins.
- Added and stabilized Azazoth's Astral Prison and Astral Chain effects.
- Hellfire Magi spells now cast through dedicated casters with tighter timing.
- Fixed boss party scaling accumulating across repeated encounters.
- Fixed Kroresh positioning in its encounter.
- Essence of Darkness now gives Freeze a casting opportunity without ignoring
  Mortify or Terrify for the entire Freeze cooldown.
- Reduced the delay between Essence of Darkness cast announcements and the
  corresponding Freeze, Mortify, or Terrify effect.

## Hero Changes

- Added a configurable ability-taunt toggle and hotkey.
- Dark Summoner received a complete summon-progression redesign:
  - Summon Essence now controls clearly displayed summon tiers.
  - Reworked the summon roster and renamed Meat Golem to Skull Brute.
  - Reworked Demonic Sacrifice and Bloodforged.
  - Added Dread Cleave, summon wounds, Reaver passives, War Cry tier scaling,
    and improved summon controls and lifecycle handling.
  - Added Unholy Ascension with an expanding area that empowers valid summons.
  - Rebalanced summon attributes, movement, cleave mitigation, targeting, and
    progression across hero levels.
- Elite Marksman Sniper Stance no longer relies on Metamorphosis or an alternate
  unit form.
- Fixed Elite Marksman projectiles.
- Fixed Royal Guardian Protector failing to apply the strongest aura level to
  every ally.
- Fixed Oblivion Guard Magnetic Force timer state.
- Restored Resonance spell-damage echoes and corrected its scaling.
- Corrected Blood Cleave scaling.
- Vampire Lord Strength Blood Nova now taunts affected enemies.
- Fixed faulty mana-regeneration calculations.
- Selected-unit and summon ability tooltips now refresh after tier or level
  changes.

## General Fixes

- Fixed startup and character-setup cases that could leave a hero unable to
  receive orders.
- Fixed entering or leaving Chaos more than once during the same transition.
- Overworld enemies defer their respawn when their spawn point is blocked.
- Dead overworld enemies no longer leave collision behind.
