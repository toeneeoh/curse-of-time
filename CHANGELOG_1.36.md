# Changelog 1.36

**CODE WIPE — previous-version saves are not compatible.**

Working release notes for changes since 1.35/1.35c.
[Google Doc](https://docs.google.com/document/d/1EcgvDSD0oWB2WVc9OeDEQ_9CuiAF60QUAJgIQMOD9oA)

This is the consolidated local draft, based on the supplied changelog and old
map script. Updating this file does not automatically update the Google Doc.
Verification notes and remaining editorial checks are kept in
[the baseline audit](CHANGELOG_1.36_BASELINE_AUDIT.md).

## System Changes

- Removed homes and bases. Factions replace their progression role, and gaining experience no longer requires a home.
- Raised the hero level cap to 500 and the total stat cap to 255,000.
- Completely reworked the XP and kill-reward systems. Leveling now follows a smoother progression curve instead of the old home-dependent XP rates and steep late-game XP slowdown.
- Reworked how XP and gold are shared with nearby allies.
- Fighting enemies below your level increasingly reduces XP and qualifying kill credit; fighting stronger eligible enemies grants bonus XP.
- Reworked repeatable kill bounties, with more rewarding XP turn-ins and reduced rewards for overleveled farming.
- Replaced Prestige with a persistent, profile-wide Perk Tree. Character milestones earn points for connected offensive, defensive, party, exploration, and inheritance bonuses.
- Added Status Resistance, which shortens applicable negative effects, and Cooldown Acceleration, which makes ability cooldowns recover faster.
- Critical Chance and Critical Damage are separate stats and can be increased through equipment and skills.
- Reduced spellboost variance to ±10% (from ±20%).
- Proficiency penalties now retain 75% of most item stats (from 50%).
- Boss crystals are awarded directly to nearby players rather than dropped on the ground.
- Removed the revival wait after a player's grave expires, along with the `-revive` / `-rv` commands.
- Players may flee the gods arena before killing Zeknen.
- Added the Giant Polar Bear headhunter quest.

## Interface and Controls

- Added a new hero-selection interface.
- Added a completely new custom inventory interface, with item dragging, swaps, context menus, item inspection, and two dedicated potion slots.
- Added a new Stat View and Profile tab for resources, playtime, Reveal and Teleport levels, best Struggle wave, and other character information.
- Added Drop Rate and Boss Drop Rate to the stat display.
- Added a completely new multiboard with boss health, retarget timing, current target, fight duration, individual damage contribution, and DPS.
- Added boss drop previews showing current drop chances.
- Added a Damage Log and improved reward notifications.
- Added an on-screen tracker for active repeatable kill quests.
- Added a new shop interface for buying and crafting. Crafting and upgrading can use items from all 24 inventory/backpack slots.
- Allied heroes, summons, and selected enemy units/bosses display their skills and cooldowns.
- Holding Left Alt displays spellboost ranges and applicable item stat/effect ranges.
- Improved shield feedback at the hero portrait.
- Floating damage numbers are limited to four popups per damage tick to reduce lag.
- The target dummy displays physical and magic damage separately.
- Added a fullscreen option for the Perk Tree.
- Certain action hotkeys can be changed through the backpack settings menu and save with the profile.
- Added a configurable ability-taunt toggle and hotkey.
- Replaced many typed commands with interface controls.

## Factions

- Added Cave Voyagers, Stormwatch, and Ashen Vanguard, each with themed quests, rank blessings, and its own shop.
- Faction membership, rank progress, unspent Faction Points, and completed quest rotations save with the character.
- Added rotating faction contracts.
- Players may change factions after the switching cooldown.
- Added mining deposits for Cave Voyagers, including rare and guarded deposits.
- Added rare hunts and empowered rare creatures for Ashen Vanguard.
- Added rotating faction events: Cave Voyagers' Hold the Line, Stormwatch's Eye of the Storm, and Ashen Vanguard's Grand Hunt.
- Added shared faction projects that reward continued quest and event participation.
- Added faction consumables for sharing blessings, influencing weather and mining, and marking bosses for improved drops.

## Colosseum

- Completely reworked Colosseum into a 20-wave run, with enemy scaling based on the participating characters.
- Added selectable run Augments with offensive, defensive, and utility choices.
- Added encounter hazards, boss affixes, and telegraphed attacks.
- Added wave progress and run information to the interface.
- Rebalanced tickets, enemy scaling, and gold rewards.
- Colosseum clears now award Honor instead of character XP.
- Honor can be allocated to bonuses at the Prize Vendor and reallocated without losing lifetime Honor.
- Added lifetime Honor milestones. Honor progression saves with the character.

## Infinite Struggle

- Completely reworked Infinite Struggle into an endless pressure mode with mixed melee, ranged, and special enemies.
- Wave number determines the base difficulty; changing equipment does not lower the wave's enemy stats.
- Enemy scaling transitions into Chaos at wave 200, with additional scaling for more participants.
- Added reward checkpoints: secure your current reward or continue and risk the unclaimed reward.
- Secured best waves save with the character. Later runs start within a bracket based on the lowest entrant's secured record.
- Replaced the old fixed Ring/Lesser Ring rewards with 100 reward ranks.
- Added the socketable Struggle Gem. The Prize Vendor can redeem the highest secured rank and convert a Ring of Struggle into its gem form.
- Only one Ring of Struggle or Struggle Gem may be equipped at a time.

## Potions

- Added refillable flasks and two dedicated potion-use slots.
- Added flask progression from basic Health/Mana flasks to Epic and exceptionally rare Legendary bases.
- Flasks can have variable restoration, maximum charges, and use cooldowns.
- Added prefix and suffix customization. Legendary bases support both, sacrificing restoration strength for additional effects.
- Added a Potion Master for refilling, rerolling, and transferring flask effects.
- Rerolling permanently locks a flask to one chosen category, with increasing costs for repeated attempts.
- Potion customization and reroll progress save with the item.
- Swapping flasks into potion slots outside town applies a 10-second readiness penalty. Swapping in town does not add that penalty.

## Personal Stash

- Added a saveable 6×6 personal item stash beside the inventory window.
- The first six-slot row is free, with additional rows available to purchase.
- The stash can be viewed anywhere, but item transfers and row purchases require being in town.
- Added dragging, item swaps, Ctrl-click quick transfers, and item context actions between the stash and inventory.

## Items, Upgrading, and Crafting

- Complete revamp of item rarity system as well as formulas for boss item stats and upgrade prices
- The enhancer may now Salvage your items for 25% of its gold/platinum cost (can be viewed with Item Info)
- Changed tooltip format for items
- Some items may now spawn and save with variable stat ranges
- Shields that reduced flat damage now reduce a percentage amount of damage on proc (ex: polar shield 20% chance to reduce 30% physical damage)
- Darkest of Darkness - Reduced damage resist to 30% (from 40), decreased cooldown to 90 seconds (from 240), increased duration to 20 seconds (from 10)
- Buffed some Giant Polar Bear drops and set their level requirement to 25 (some were 20)
- Jewel of the Horde grunts no longer have bloodlust, always spawn 3 grunts (from 3-5), increased grunt HP to 15000 (from 12000) and normalized damage range from 900-9200 to 5000-5000
- New Thanatos Wings visuals and you may cycle through them if unlocked by using the item spell
- Expanded boss-item upgrade progression, including equipment that previously could not be upgraded.
- All charged items preserve their remaining charges when saved, including resurrection items.
- Moved the Forgotten jewel progression into upgradeable socketables crafted at the Reclusive Blacksmith.
- Added equipment drops to Orsted and reworked Xallarath's equipment rewards.
- Dark Regeneration now requires level 300.

## Bosses

- Changed boss spell kits:
- Hellfire magi: Flame Strike, Chain Lightning, Frost Armor
- Dragoon: Evasion, Corrupted Arrows
- Vashj: Tornado Storm
- Forgotten Mystic: Mana Drain, Mana Shield
- Arkaden: Metamorphosis, Frost Nova, Raise Skeleton
- Azazoth: Replaced Strength Obliteration with Astral Prison
- Removed Forest Corruption
- New Chaos Boss: King of Despair
- Arkaden now respawns
- Removed innate magic resistance from Dark Soul (was 30%), Pure Existence (was 30%), and Azazoth (was 50%)
- Pure Existence’s Protected Existence now grants 33% magic resist (instead of full magic immunity)
- Azazoth’s Astral Shield now grants 66% magic resist (instead of full magic immunity)
- Dark Soul now announces their stun ability
- Thanatos’ Swift Hunt is now a ground area target instead of a unit target (similar to True Stealth)
- Absolute Horror True Stealth now deals 80k + 30% max hp (from 125k) spell damage and heals based on damage dealt (from 33% max health)
- Increased Legion Illusion damage taken to 350% (from 200)
- Xallarath Unstoppable Force cooldown increased to 14 seconds (from 12)
- Increased Giant Polar Bear HP by 5000
- Essence of Darkness can cast Freeze without blocking Mortify and Terrify throughout Freeze's cooldown.
- Reduced the delay between Essence of Darkness cast announcements and their effects.
- Pure Existence is now level 340 to match its equipment rewards.
- Added per-boss difficulty voting.

## Heroes

- Capped all hero cast points at 0.3 (improves cast point for elementalist, arcanist, hydromancer, etc.)
- Arcane Warrior - Reduced base physical resistance to 110% (from 100), reduced base magic resistance to 110% (from 100)
- Arcane Warrior - Now called "Crusader" and most skills have been reworked
- Arcanist - Increased base attack time to 2.5 seconds per attack (from 6)
- Arcanist Control Time (F) - Reworked, now grants a chance to reduce a spell's cooldown by a flat amount after casting, changed hotkey to (D)
- Arcanist Arcane Bolts (Q) - Now ignores terrain pathing, reduced cooldown to 5 seconds (from 25)
- Arcanist Arcane Barrage (W) - Reduced cooldown to 5 seconds (from 25)
- Arcanist Stasis Field (E) - Reduced cooldown to 20 (from 50)
- Arcanist Arcane Shift (R) - Increased stun duration to 4 seconds (from 3), now keeps enemies stunned over the entire duration (even after second casting), Reduced cooldown to 30 seconds (from 80)
- Arcanist Arcanosphere (T) - Movement is much smoother, arcane comets now randomly target nearby enemies instead of landing where your cursor was, Reduced cooldown to 60 seconds (from 300)
- Assassin Smokebomb (E) - Reduced movespeed slow to 30/32/34/36/38/40% (from 25/30/35/40/45/50)
- Assassin Dagger Storm (R) - Number of daggers reduced to 30 (from 60), damage scaling increased to 2x agi (from 1x), daggers are now immediately thrown without delay, increased dagger speed by 10%
- Assassin Phantom Slash (T) - Can no longer be recast before completing a dash, increased dash speed by 20%, grants 100% evasion during the dash, reduced required level to learn to 50 (from 100), damage scaling upped to 1.5/3 x Agi (from 1.5 at all levels)
- Bard - Increased base physical resistance to 180% (from 200), reduced base magic resistance to 160% (from 100)
- Bard Songs of the Traveler - Added better visual indicator for current playing song
- Bard Song of Peace - Increased mana regen to 1% (from 0.75%)
- Bard Encore (Q) - Removed mana cost, reduced Song of War max hit count down to 10 (from 20), song of war procs now use the Bard's spellboost for damage calculation and count as his own damage (for tracking boss damage)
- Bard Melody of Life (W) - Increased cast range to 500 (from 400)
- Bard Improv (R) - New spell!
- Bard Tone Of Death (T) - Spawns an extra 100 range away from the bard, reduced visual size, now costs 20% max mana
- Bloodzerker - Reduced base physical resistance to 160% (from 150), reduced base magic resistance to 180% (from 150), reduced base attack time to 1.5 (from 1.33)
- Bloodzerker Blood Frenzy (F) - Removed damage bonus completely, increased base attack speed bonus to 50% (from 20), reduced duration to 5 seconds (from 10), reduced cooldown to 5 seconds (from 13), moved hotkey to D
- Bloodzerker Blood Leap (Q) - Removed strength damage scaling, increased attack damage scaling to 80/120/160/200% (from 40/60/80/100), removed max health cost (from 5%)
- Bloodzerker Blood-Curdling Scream (W) - Increased max health cost to 10% (from 5)
- Bloodzerker Blood Cleave (E) - Reworked, now deals physical damage and leeches for the total damage dealt
- Bloodzerker Rampage (R) - No longer increases leap / blood cleave damage, now provides %ignore armor to physical damage, increased health drain to 8% current health per second (from 3)
- Bloodzerker Undying Rage (T) - New skill!
- Dark Savior - Reduced base physical resistance to 160% (from 130), reduced base magic resistance to 100% (from 90)
- Dark Savior Soul Steal - Removed
- Dark Savior Dark Seal (F) - No longer slows, Switched hotkey to D
- Dark Savior Dark Blade (E) - Reworked, now an innate with a duration and cooldown, switched hotkey to F
- Dark Savior Dark Shield (E) - New skill
- Dark Savior Metamorphosis (R) - Renamed to Dark Ascension, no longer provides ranged attacks and has a new model
- Dark Savior Freezing Blast (W) - Damage increased to 2/4/5/6 x int (from 1/2/3/4), freeze reduced to 1.5 seconds (from 5), and now slows for 30% for 3 seconds after freeze expires
- Dark Summoner Destroyer (E) - Increased attack range to 700 (from 600)
- Elementalist - New skill: Flame Breath, Increased attack range to 600 (from 475)
- Elementalist Master of Elements - Reduced cooldown to 3 seconds (from 10), Fire: No longer increases damage taken, Ice: Increased mana regeneration to 1.5% max mana per second (from 1) and move speed slow reduced to 35% (from 50), Lightning: Increased range to 900 and only shocks a single enemy for 0.5% current health pure damage every 5 seconds, Earth: Increased damage reduction to 25% (from 20), No longer reflects damage, now increases Gaia Armor shield amount by 250%
- Elementalist Ball of Lightning (Q) - Only hits a single target now, scaling increased to 6/7/8/9 x Int (from 2/4/6/8), Now has a 5% max mana cost
- Elementalist Frozen Orb (W) - Increased cooldown to 19/18/17/16/15 seconds (from 18/16/14/12/10), Can now be recast to explode immediately in place, reduced projectile speed by roughly 10%, and icicles are more consistent over the orb’s duration, now has 15% max mana cost
- Elementalist Armor of the Elements (E) - Renamed to Gaia Armor, Shield duration and cooldown changed to 30 seconds at all levels, scaling reduced to 1/…/3 x Int (from 3/…/4.5x) and removed Max HP scaling, health and mana restored upon taking fatal damage now scales from 20%/…/100% (from 50%)
- Elementalist Elemental Storm (T) - Cooldown reduced to 50/45/40 seconds (from 50), Number of strikes is now 12 across all levels and each strike deals 3/4/5 x Int by default in a consistent 400 AoE, Fire now increases strike damage and AoE by 50%, Ice freeze reduced to 2 seconds (from 3) and restores 15% max mana per strike, Lightning now deals 1.5% current health pure damage to a single target, Earth now stacks 4% damage amplification per strike (up to 40% max), The first 6 strikes of Elemental Storm are determined by the passive element from Master of Elements and the last 6 strikes are split between the remaining elements
- Elite Marksman Sniper Stance (E) - Moved to D hotkey and is now pre-skilled, Now halves base attack speed while active, but grants a 2x critical chance and damage multiplier
- Elite Marksman Hand Grenade (R) - Reduced damage to 50/60/70/80/90/100% attack damage (from 75/100/125/150/175%) and helicopter damage to 100/110/120/130/140/150%
- Elite Marksman U-235 Shell (T) - Reworked to Flaming Betty
- High Priestess Invigoration (F) - Now can be channeled forever with no cooldown, restores max mana per second to the priestess while channeled and heal changed to 0.15x int + 1% max hp of target, changed hotkey to (D)
- High Priestess Divine Light (Q) - Reduced cooldown to 5 seconds (from 7), heal changed to 1x int + 5% max hp of target and now grants a move speed buff, mana cost is now 5% max mana
- High Priestess Holy Shock (W) - Reworked to Sanctified Ground
- High Priestess Healing Rays (E) - Heal adjusted to 2.5 x int and deals 10 x int damage to enemies at max level, cooldown reduced to 15 seconds (from 17), mana cost is now 10% max mana
- High Priestess Protection (R) - Reworked - Now gives an intelligence based shield to all allies that increases their base attack speed while active, mana cost is now 50% max mana
- High Priestess Resurrection (T) - Mana cost is now 100% current mana, increased health/mana scaling to 60/80/100% (from 30/40/50), automatically casts on self if not on cooldown when dying
- Hydromancer Infused Water (F) - Frost blast damage multiplier increased to 200% (from 40%), reduced cooldown to 15 seconds (from 30)
- Hydromancer Frost Blast (Q) - Intelligence scaling raised to 1/2/3/4 (from 0.75/1.5/2.25/3), now has a 2x soaked damage multiplier, Increased missile speed to 1200 (from 1000) - Hits twice when hitting the target
- Hydromancer Whirlpool (W) - Duration expires faster with additional affected enemies, capped at 100% faster with 20 enemies
- Hydromancer Tidal Wave (T) - Increased projectile speed to 660 (from 560), damage amp increased to 15% (from 10), changed hotkey to E
- Hydromancer Blizzard (R) - Visual effect AoE now increases with spellboost
- Hydromancer Ice Prison (E) - Reworked to new ultimate spell Ice Barrage (T)
- Master Rogue Instant Death - Reworked to grant a 20% critical chance multiplier and a flat critical damage bonus of 400% + 100% per 50 levels
- Master Rogue Piercing Strikes - Increased duration to 3 seconds (from 2)
- Master Rogue Wind Walk (W) - Reworked to Hidden Guise
- Oblivion Guard - Reduced base physical resistance to 100% (from 90), reduced base magic resistance to 130% (from 110)
- Oblivion Guard Body of Fire - Now an innate ability that upgrades every 100 levels and now earns charges passively that are consumed by Infernal / Magnetic strikes
- Oblivion Guard Magnetic Stance (W) - Now can be toggled without cooldown, no longer deals damage, reduced % damage reduction to 10/15/20/25/30% (from 15/20/25/30/35)
- Oblivion Guard Infernal Strikes (E) - Healing from nearby hit enemies capped to 6% max hp, bosses now count as 5 units for healing, removed cooldown and now consumes a charge from Body of Fire per attack, Now benefits from critical strike instead of dealing 15x damage to chaotic armor
- Oblivion Guard Magnetic Strikes (R) - New spell
- Oblivion Guard Gatekeeper's Pact (T) - Moved to T hotkey, AoE scaling changed to 600/650/700/750 (from 500)
- Phoenix Ranger - Increased attack range to 700 (from 650)
- Royal Guardian - Reduced base physical resistance to 90% (from 70), reduced base magic resistance to 150% (from 120)
- Royal Guardian Steed Charge (D) - New innate ability
- Royal Guardian Protector - Now applies to the Royal Guardian, reduced % damage reduction to 9/11/13/15 (from 14/16/18/20) and increased AoE to 900 (from 800)
- Royal Guardian Shield Slam (Q) - Increased armor scaling damage to 6/12/18/24/30x (from 4/8/12/16/20), increased base stun to 3 seconds (from 2), removed damage and stun scaling per shield equipped, AoE damage now applies a stun as well for half the duration, reduced cooldown to 10 seconds (from 12)
- Savior - Reduced base physical resistance to 120% (from 100), reduced base magic resistance to 130% (from 100)
- Savior Light Seal (D) - New innate ability
- Savior Divine Judgement (Q) - Increased strength+damage scaling to 50/80/110/140/170/200% (from 66/99/132/165)
- Savior Righteous Might (R) - Reduced magic resistance to 80% (from 100),  Reduced bonus damage and armor scaling to 40/60/80/100% (from 60/80/100/120/140/160/180), Reduced cooldown to 60 seconds (from 70), Increased AoE strength damage to 6/10/14/18x (from ??), Reduced heal percent to 15/20/25/30% (from 14/17/20/23/26/29/32)
- Thunderblade Overload (F) - Now an innate ability, increased magic damage multiplier to 50/60/70/80/90/100% (from 10/20/30/40/50/60), removed bonus spell damage on attack, moved hotkey to D
- Thunderblade Monsoon (W) - Reduced cast time significantly, changed damage formula to 1.8 x Agi (from 1.4 x Agi plus the random level formula)
- Thunderblade Railgun (T) - New ability
- Warrior - Reduced base physical resistance to 110% (from 100), reduced base magic resistance to 150% (from 120)
- Warrior - Complete rework!
- Vampire Lord - Reduced base physical resistance to 150% (from 140), reduced base magic resistance to 150% (from 140), reduced cast point to 0.15 (from 0.3)
- Vampire Lord Blood Mist (E) - Reduced heal scaling to 0.5/0.75/1 x strength (from 1/1.5/2) and added 15% blood spent scaling (2.4x int)
- Vampire Lord Blood Lord (T) - Reduced strength damage reduction to 1% per 5% blood (from 1% per 4% blood)
- Dark Summoner received a complete summon-progression redesign, including displayed summon tiers, a revised summon roster, reworked Demonic Sacrifice and Bloodforged, and Unholy Ascension.
- Royal Guardian's Protector now correctly applies the strongest aura level to allies.
- Vampire Lord's Strength Blood Nova taunts affected enemies.

## Saving and General Improvements

- Profiles load automatically; `-load` replaces `-loadh` for loading heroes.
- Save/load files now use the “CoT Nevermore” folder.
- Saves retain the selected backpack skin and configured hotkeys.
- Added saving for faction progression, Honor, Struggle records, potion customization, and personal stash storage.
- Save backups now include the entire save folder.
- The Evil Shopkeeper's Brother gives hints about the Evil Shopkeeper's location.
- Improved town protection against roaming overworld/event enemies.
- Fixed repeated boss-party scaling accumulating across encounters.
- Fixed several item equip, socket, charge, and tooltip inconsistencies.
