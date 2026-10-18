# Early drop vendor values

Audited 93 distinct rawcodes from the destructible and prechaos creature pools in `drop_table.lua`, through devourers and ancient hydras. 57 gameplay items had neither a formula cost nor a Lua shop price. Native object gold costs alone are not read by the managed sell quote.

Existing formula/shop sell prices retain precedence. The new values are sell-only payouts, with material stacks paid per unit; they create no purchase offers. Values rise with equipment requirements and region, using shop equipment as anchors: Mythril weapons sell for 250 gold at level 7 and Axe of Speed for 750 at level 25. The 300-gold Ursa and 500-gold Ogre/Tauren payouts sit around those anchors.

| Rawcode | Item | Required level | Gold payout per item |
| --- | --- | ---: | ---: |
| I01V | Medallion of Courage | — | 25 |
| I021 | Medallion of Vitality | — | 40 |
| I02D | Ring of Regeneration | 3 | 25 |
| I03Q | Horse Boost | 4 | 55 |
| I025 | Greater Mask of Death | 15 | 100 |
| I02L | Great Circlet | 15 | 250 |
| I06T | Ursa Bone Sword | 7 | 300 |
| I034 | Ursa Bone Club | 7 | 300 |
| I0FG | Ursa Claws | 7 | 300 |
| I06R | Ursa Razor Arrows | 7 | 300 |
| I0FT | Ursa Shamanic Rod | 7 | 300 |
| I035 | Bear Hide Armor | 15 | 350 |
| I0FO | Bear Skin Coat | 15 | 350 |
| I07O | Bear Fur Robe | 15 | 350 |
| I0FQ | Mammoth Hide Armor | 15 | 400 |
| I08I | Ogre Club | 25 | 500 |
| I0FE | Ogre Staff | 25 | 500 |
| I07W | Ogre Cloth | 25 | 500 |
| I08B | Ogre Blade | 25 | 500 |
| I0FD | Ogre Plate | 25 | 500 |
| I08R | Ogre Heavy Armor | 25 | 500 |
| I08E | Tauren Arrows | 25 | 500 |
| I08F | Tauren Dagger | 25 | 500 |
| I07Y | Tauren Leather | 25 | 500 |
| I0FS | Unbroken Fullplate | 40 | 750 |
| I0FR | Unbroken Cloth | 40 | 750 |
| I0FY | Unbroken Leather | 40 | 750 |
| I01W | Unbroken Plate | 40 | 750 |
| I0MB | Unbroken Shield | 40 | 750 |
| I00Z | Fire Orb | 50 | 1000 |
| I00S | Fiery Bow | 50 | 1000 |
| I011 | Flaming Dagger | 50 | 1000 |
| I02E | Flaming Sword | 50 | 1000 |
| I023 | Molten Hammer | 50 | 1000 |
| I0MA | Flame Sigil | 50 | 1000 |
| I06J | Centaur Blade | 60 | 1250 |
| I06I | Centaur Axe | 60 | 1250 |
| I06L | Centaur Dagger | 60 | 1250 |
| I06K | Centaur Bow | 60 | 1250 |
| I07H | Centaur Wand | 60 | 1250 |
| I01Q | Magnataur Hide Plate | 70 | 1500 |
| I01N | Magnataur Hide Fullplate | 70 | 1500 |
| I015 | Forgotten One's Cloth | 70 | 1500 |
| I019 | Forgotten One's Leather Jacket | 70 | 1500 |
| I056 | Dragon Heart | — | 500 |
| I04X | Dragon Bone | — | 250 |
| I05Z | Dragon Scale | — | 250 |
| I02W | Devourer Arrows | 110 | 2500 |
| I00W | Devourer Stinger | 110 | 2500 |
| I017 | Devourer Fullplate | 110 | 2500 |
| I013 | Devourer Helm | 110 | 2500 |
| I02I | Devourer Crown | 110 | 2500 |
| I01P | Devourer Claw | 110 | 2500 |
| I006 | Devourer Tail | 110 | 2500 |
| I02V | Devourer Essence | 110 | 2500 |
| I009 | Devourer Sword | 110 | 2500 |
| I07N | Hydra Fang | — | 750 |

Hydra’s Head (`I044`) remains a quest turn-in, and the legacy native spell carrier (`I028`) remains unpriced. Colosseum tickets (`I008`) are also unsellable and now encode as empty inventory/stash slots. Save layout and version are unchanged.
