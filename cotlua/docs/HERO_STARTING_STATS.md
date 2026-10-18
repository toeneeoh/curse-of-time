# Standardized starting attributes

All 19 selectable heroes have **35 starting attribute points**. These are fixed
starting attributes, separate from the 24,980 freely assignable points earned
by leveling to 500. Every allocated or purchased point still adds one base stat.

| Hero | Strength | Agility | Intelligence | Distribution rationale |
| --- | ---: | ---: | ---: | --- |
| Oblivion Guard | 20 | 6 | 9 | Tank durability with a usable spell resource pool. |
| Bloodzerker | 23 | 12 | 0 | Health and attacks; the kit does not need Intelligence. |
| Royal Guardian | 22 | 7 | 6 | Frontline tank with a small mana allocation. |
| Warrior | 20 | 10 | 5 | Strength melee fighter with secondary attack utility. |
| Vampire Lord | 14 | 14 | 7 | Keeps both Strength and Agility paths open; Intelligence supplies blood capacity. |
| Savior | 18 | 7 | 10 | Durable melee support with more mana than a pure fighter. |
| Dark Savior | 12 | 5 | 18 | Intelligence caster who still fights in melee. |
| Crusader | 14 | 5 | 16 | Hybrid caster/tank with a substantial health allocation. |
| Arcanist | 8 | 5 | 22 | Intelligence-focused ranged caster with a basic health floor. |
| Dark Summoner | 10 | 5 | 20 | Mana and spell scaling, with health for its sacrifice-oriented kit. |
| Bard | 9 | 6 | 20 | Mana-focused support with a little more mixed utility. |
| Hydromancer | 8 | 5 | 22 | Intelligence-focused ranged caster. |
| High Priest | 10 | 5 | 20 | Support spellcasting with some additional starting durability. |
| Elementalist | 8 | 5 | 22 | Matches other offensive casters instead of starting with 40 Intelligence. |
| Assassin | 10 | 17 | 8 | Melee durability, Agility spell damage and mana for combos. |
| Thunderblade | 9 | 18 | 8 | Agility melee damage with a usable mana reserve. |
| Master Rogue | 10 | 20 | 5 | Physical melee damage with a small spell-resource allocation. |
| Elite Marksman | 8 | 22 | 5 | Agility-heavy ranged attacker. |
| Phoenix Ranger | 8 | 21 | 6 | Agility-heavy ranged attacker with a little more mana support. |

The previous starting totals ranged from 24 to 44. This removes the unequal
starting budgets while retaining differences in class needs. Vampire specifically
keeps nonzero Intelligence because Blood Bank capacity is `200 * Intelligence`
and several blood mechanics also use it. Bloodzerker's kit uses health and attack
scaling, with no Intelligence dependency.

`config/hero_definitions.lua` is the shared source for character creation,
allocation/reset base values and the hero-selection tooltip. The update changes
starting attributes only; the common leveling curve and other class tuning are
separate. Existing saved allocation ledgers retain their assignments and use the
current hero starting attributes when applied.

Offline checks validate the real 19-hero catalog's totals, nonnegative integer
attributes, primary-attribute emphasis and resource requirements. Early-game
survivability and resource comfort still require playtesting.
