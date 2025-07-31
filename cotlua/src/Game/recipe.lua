--[[
    recipe.lua

    Sets up shops and crafting recipes for items
]]

OnInit.final("Recipe", function(Require)
    Require('Units')
    Require('Shop')
    Require('Items')

    local sword, heavy, dagger, bow, staff, plate, fullplate, leather, cloth, Shield, misc, sets
    local id = FourCC('n02C')  ---@type integer --town smith
    local id2 = FourCC('n09D')  ---@type integer --reclusive blacksmith
    local id3 = FourCC('n01F')  ---@type integer --evil shopkeeper

    ITEM_PRICE['I02B:0'][GOLD] = 20000
    ITEM_PRICE['I02C:0'][GOLD] = 20000
    ITEM_PRICE['I0EY:0'][GOLD] = 20000
    ITEM_PRICE['I074:0'][GOLD] = 20000
    ITEM_PRICE['I03U:0'][GOLD] = 20000
    ITEM_PRICE['I07F:0'][GOLD] = 20000
    ITEM_PRICE['I03P:0'][GOLD] = 20000
    ITEM_PRICE['I0F9:0'][GOLD] = 20000
    ITEM_PRICE['I079:0'][GOLD] = 20000
    ITEM_PRICE['I0FC:0'][GOLD] = 20000
    ITEM_PRICE['I00A:0'][GOLD] = 80000
    ITEM_PRICE['I0JR:0'][GOLD] = 100000
    ITEM_PRICE['I08K:0'][GOLD] = 100000
    ITEM_PRICE['I0F4:0'][GOLD] = 100000
    ITEM_PRICE['I0F5:0'][GOLD] = 100000
    ITEM_PRICE['I012:0'][GOLD] = 150000
    ITEM_PRICE['I04J:0'][GOLD] = 400000

    CreateShop(id, 1000., 0.5)
    CreateShop(id2, 1000., 0.5)
    evilshop = CreateShop(id3, 1000., 0.5)

    -- blacksmith
    sword = ShopAddCategory(id, "ReplaceableTextures\\CommandButtons\\BTNThoriumMelee.blp", "Sword")
    heavy = ShopAddCategory(id, "ReplaceableTextures\\CommandButtons\\BTNImprovedStrengthOfTheMoon.tga", "Heavy")
    dagger = ShopAddCategory(id, "ReplaceableTextures\\CommandButtons\\BTNDaggerOfEscape.blp", "Dagger")
    bow = ShopAddCategory(id, "ReplaceableTextures\\CommandButtons\\BTNScoutsBow.blp", "Bow")
    staff = ShopAddCategory(id, "ReplaceableTextures\\CommandButtons\\BTNWitchDoctorAdept.blp", "Staff")
    plate = ShopAddCategory(id, "ReplaceableTextures\\CommandButtons\\BTNAdvancedMoonArmor.blp", "Plate")
    fullplate = ShopAddCategory(id, "ReplaceableTextures\\CommandButtons\\BTNArmorGolem.blp", "Fullplate")
    leather = ShopAddCategory(id, "ReplaceableTextures\\CommandButtons\\BTNLeatherUpgradeOne.blp", "Leather")
    cloth = ShopAddCategory(id, "ReplaceableTextures\\CommandButtons\\BTNMantleOfIntelligence.blp", "Cloth")
    Shield = ShopAddCategory(id, "ReplaceableTextures\\CommandButtons\\BTNHumanArmorUpTwo.blp", "Shield")
    misc = ShopAddCategory(id, "ReplaceableTextures\\CommandButtons\\BTNCrystalBall.blp", "Miscellaneous")
    sets = ShopAddCategory(id, "ReplaceableTextures\\CommandButtons\\BTNManaShield.blp", "Sets")
    -- reclusive blacksmith
    ShopAddCategory(id2, "ReplaceableTextures\\CommandButtons\\BTNThoriumMelee.blp", "Sword")
    ShopAddCategory(id2, "ReplaceableTextures\\CommandButtons\\BTNImprovedStrengthOfTheMoon.tga", "Heavy")
    ShopAddCategory(id2, "ReplaceableTextures\\CommandButtons\\BTNDaggerOfEscape.blp", "Dagger")
    ShopAddCategory(id2, "ReplaceableTextures\\CommandButtons\\BTNScoutsBow.blp", "Bow")
    ShopAddCategory(id2, "ReplaceableTextures\\CommandButtons\\BTNWitchDoctorAdept.blp", "Staff")
    ShopAddCategory(id2, "ReplaceableTextures\\CommandButtons\\BTNAdvancedMoonArmor.blp", "Plate")
    ShopAddCategory(id2, "ReplaceableTextures\\CommandButtons\\BTNArmorGolem.blp", "Fullplate")
    ShopAddCategory(id2, "ReplaceableTextures\\CommandButtons\\BTNLeatherUpgradeOne.blp", "Leather")
    ShopAddCategory(id2, "ReplaceableTextures\\CommandButtons\\BTNMantleOfIntelligence.blp", "Cloth")
    ShopAddCategory(id2, "ReplaceableTextures\\CommandButtons\\BTNHumanArmorUpTwo.blp", "Shield")
    ShopAddCategory(id2, "ReplaceableTextures\\CommandButtons\\BTNCrystalBall.blp", "Miscellaneous")
    -- evil shopkeeper
    ShopAddCategory(id3, "ReplaceableTextures\\CommandButtons\\BTNThoriumMelee.blp", "Sword")
    ShopAddCategory(id3, "ReplaceableTextures\\CommandButtons\\BTNImprovedStrengthOfTheMoon.tga", "Heavy")
    ShopAddCategory(id3, "ReplaceableTextures\\CommandButtons\\BTNDaggerOfEscape.blp", "Dagger")
    ShopAddCategory(id3, "ReplaceableTextures\\CommandButtons\\BTNScoutsBow.blp", "Bow")
    ShopAddCategory(id3, "ReplaceableTextures\\CommandButtons\\BTNWitchDoctorAdept.blp", "Staff")
    ShopAddCategory(id3, "ReplaceableTextures\\CommandButtons\\BTNAdvancedMoonArmor.blp", "Plate")
    ShopAddCategory(id3, "ReplaceableTextures\\CommandButtons\\BTNArmorGolem.blp", "Fullplate")
    ShopAddCategory(id3, "ReplaceableTextures\\CommandButtons\\BTNLeatherUpgradeOne.blp", "Leather")
    ShopAddCategory(id3, "ReplaceableTextures\\CommandButtons\\BTNMantleOfIntelligence.blp", "Cloth")
    ShopAddCategory(id3, "ReplaceableTextures\\CommandButtons\\BTNHumanArmorUpTwo.blp", "Shield")
    ShopAddCategory(id3, "ReplaceableTextures\\CommandButtons\\BTNCrystalBall.blp", "Miscellaneous")

    -- ursa components
    ShopAddItem(id, 'I06T:0', sword)
    ShopAddItem(id, 'I034:0', heavy)
    ShopAddItem(id, 'I0FG:0', dagger)
    ShopAddItem(id, 'I06R:0', bow)
    ShopAddItem(id, 'I0FT:0', staff)
    ShopAddItem(id, 'I035:0', plate)
    ShopAddItem(id, 'I0FQ:0', fullplate)
    ShopAddItem(id, 'I0FO:0', leather)
    ShopAddItem(id, 'I07O:0', cloth)

    -- ursa sets
    -- sword
    ITEM_PRICE['I0H5:0'][GOLD] = 2000
    ShopAddItem(id, 'I0H5:0', sets + sword + plate)
    ItemAddComponents('I0H5:0', "I06T I06T I06T I035 I035 I034")
    -- heavy
    ITEM_PRICE['I0H6:0'][GOLD] = 2000
    ShopAddItem(id, 'I0H6:0', sets + heavy + fullplate)
    ItemAddComponents('I0H6:0', "I0FQ I0FQ I0FQ I034 I034 I035")
    -- dagger
    ITEM_PRICE['I0H7:0'][GOLD] = 2000
    ShopAddItem(id, 'I0H7:0', sets + dagger + leather)
    ItemAddComponents('I0H7:0', "I0FG I0FG I0FG I0FO I0FO I0FO")
    -- bow
    ITEM_PRICE['I0H8:0'][GOLD] = 2000
    ShopAddItem(id, 'I0H8:0', sets + bow + leather)
    ItemAddComponents('I0H8:0', "I06R I06R I06R I0FO I0FO I0FO")
    -- staff
    ITEM_PRICE['I0H9:0'][GOLD] = 2000
    ShopAddItem(id, 'I0H9:0', sets + staff + cloth)
    ItemAddComponents('I0H9:0', "I0FT I0FT I0FT I07O I07O I07O")

    -- ogre components
    ShopAddItem(id, 'I08B:0', sword)
    ShopAddItem(id, 'I08I:0', heavy)
    ShopAddItem(id, 'I08F:0', dagger)
    ShopAddItem(id, 'I08E:0', bow)
    ShopAddItem(id, 'I0FE:0', staff)
    ShopAddItem(id, 'I0FD:0', plate)
    ShopAddItem(id, 'I08R:0', fullplate)
    ShopAddItem(id, 'I07Y:0', leather)
    ShopAddItem(id, 'I07W:0', cloth)

    -- ogre sets
    -- sword
    ITEM_PRICE['I0HA:0'][GOLD] = 8000
    ShopAddItem(id, 'I0HA:0', sets + sword + plate)
    ItemAddComponents('I0HA:0', "I08B I08B I08B I0FD I0FD I08I")
    -- heavy
    ITEM_PRICE['I0HB:0'][GOLD] = 8000
    ShopAddItem(id, 'I0HB:0', sets + heavy + fullplate)
    ItemAddComponents('I0HB:0', "I08R I08R I08R I08I I08I I0FD")
    -- dagger
    ITEM_PRICE['I0HC:0'][GOLD] = 8000
    ShopAddItem(id, 'I0HC:0', sets + dagger + leather)
    ItemAddComponents('I0HC:0', "I08F I08F I08F I07Y I07Y I07Y")
    -- bow
    ITEM_PRICE['I0HD:0'][GOLD] = 8000
    ShopAddItem(id, 'I0HD:0', sets + bow + leather)
    ItemAddComponents('I0HD:0', "I08E I08E I08E I07Y I07Y I07Y")
    -- staff
    ITEM_PRICE['I0HE:0'][GOLD] = 8000
    ShopAddItem(id, 'I0HE:0', sets + staff + cloth)
    ItemAddComponents('I0HE:0', "I0FE I0FE I0FE I07W I07W I07W")

    -- unbroken components
    ShopAddItem(id, 'I02E:0', sword)
    ShopAddItem(id, 'I023:0', heavy)
    ShopAddItem(id, 'I011:0', dagger)
    ShopAddItem(id, 'I00S:0', bow)
    ShopAddItem(id, 'I00Z:0', staff)
    ShopAddItem(id, 'I01W:0', plate)
    ShopAddItem(id, 'I0FS:0', fullplate)
    ShopAddItem(id, 'I0FY:0', leather)
    ShopAddItem(id, 'I0FR:0', cloth)

    -- unbroken sets
    -- sword
    ITEM_PRICE['I0HF:0'][GOLD] = 32000
    ShopAddItem(id, 'I0HF:0', sets + sword + plate)
    ItemAddComponents('I0HF:0', "I02E I02E I02E I01W I01W I023")
    -- heavy
    ITEM_PRICE['I0HG:0'][GOLD] = 32000
    ShopAddItem(id, 'I0HG:0', sets + heavy + fullplate)
    ItemAddComponents('I0HG:0', "I0FS I0FS I0FS I023 I023 I01W")
    -- dagger
    ITEM_PRICE['I0HH:0'][GOLD] = 32000
    ShopAddItem(id, 'I0HH:0', sets + dagger + leather)
    ItemAddComponents('I0HH:0', "I011 I011 I011 I0FY I0FY I0FY")
    -- bow
    ITEM_PRICE['I0HI:0'][GOLD] = 32000
    ShopAddItem(id, 'I0HI:0', sets + bow + leather)
    ItemAddComponents('I0HI:0', "I00S I00S I00S I0FY I0FY I0FY")
    -- staff
    ITEM_PRICE['I0HJ:0'][GOLD] = 32000
    ShopAddItem(id, 'I0HJ:0', sets + staff + cloth)
    ItemAddComponents('I0HJ:0', "I00Z I00Z I00Z I0FR I0FR I0FR")

    -- magnataur components
    ShopAddItem(id, 'I06J:0', sword)
    ShopAddItem(id, 'I06I:0', heavy)
    ShopAddItem(id, 'I06L:0', dagger)
    ShopAddItem(id, 'I06K:0', bow)
    ShopAddItem(id, 'I07H:0', staff)
    ShopAddItem(id, 'I01Q:0', plate)
    ShopAddItem(id, 'I01N:0', fullplate)
    ShopAddItem(id, 'I019:0', leather)
    ShopAddItem(id, 'I015:0', cloth)

    -- magnataur sets
    -- sword
    ITEM_PRICE['I0HK:0'][GOLD] = 100000
    ShopAddItem(id, 'I0HK:0', sets + sword + plate)
    ItemAddComponents('I0HK:0', "I06J I06J I06J I01Q I01Q I06I")
    -- heavy
    ITEM_PRICE['I0HL:0'][GOLD] = 100000
    ShopAddItem(id, 'I0HL:0', sets + heavy + fullplate)
    ItemAddComponents('I0HL:0', "I01N I01N I01N I06I I06I I01Q")
    -- dagger
    ITEM_PRICE['I0HM:0'][GOLD] = 100000
    ShopAddItem(id, 'I0HM:0', sets + dagger + leather)
    ItemAddComponents('I0HM:0', "I06L I06L I06L I019 I019 I019")
    -- bow
    ITEM_PRICE['I0HN:0'][GOLD] = 100000
    ShopAddItem(id, 'I0HN:0', sets + bow + leather)
    ItemAddComponents('I0HN:0', "I06K I06K I06K I019 I019 I019")
    -- staff
    ITEM_PRICE['I0HO:0'][GOLD] = 100000
    ShopAddItem(id, 'I0HO:0', sets + staff + cloth)
    ItemAddComponents('I0HO:0', "I07H I07H I07H I015 I015 I015")

    -- devourer components
    ShopAddItem(id, 'I009:0', sword)
    ShopAddItem(id, 'I006:0', heavy)
    ShopAddItem(id, 'I00W:0', dagger)
    ShopAddItem(id, 'I02W:0', bow)
    ShopAddItem(id, 'I02V:0', staff)
    ShopAddItem(id, 'I013:0', plate)
    ShopAddItem(id, 'I017:0', fullplate)
    ShopAddItem(id, 'I01P:0', leather)
    ShopAddItem(id, 'I02I:0', cloth)

    -- devourer sets
    -- sword
    ITEM_PRICE['I04R:0'][GOLD] = 200000
    ShopAddItem(id, 'I04R:0', sets + sword + plate)
    ItemAddComponents('I04R:0', "I009 I009 I009 I013 I013 I017")
    -- heavy
    ITEM_PRICE['I04K:0'][GOLD] = 200000
    ShopAddItem(id, 'I04K:0', sets + heavy + fullplate)
    ItemAddComponents('I04K:0', "I006 I006 I006 I017 I017 I013")
    -- dagger
    ITEM_PRICE['I047:0'][GOLD] = 200000
    ShopAddItem(id, 'I047:0', sets + dagger + leather)
    ItemAddComponents('I047:0', "I00W I00W I00W I01P I01P I01P")
    -- bow
    ITEM_PRICE['I02J:0'][GOLD] = 200000
    ShopAddItem(id, 'I02J:0', sets + bow + leather)
    ItemAddComponents('I02J:0', "I02W I02W I02W I01P I01P I01P")
    -- staff
    ITEM_PRICE['I04P:0'][GOLD] = 200000
    ShopAddItem(id, 'I04P:0', sets + staff + cloth)
    ItemAddComponents('I04P:0', "I02V I02V I02V I02I I02I I02I")

    -- shopkeeper components
    ShopAddItem(id3, 'I02B:0', sword)
    ShopAddItem(id3, 'I02C:0', plate)
    ShopAddItem(id3, 'I0EY:0', bow)
    ShopAddItem(id3, 'I074:0', dagger)
    ShopAddItem(id3, 'I03U:0', staff)
    ShopAddItem(id3, 'I07F:0', cloth)
    ShopAddItem(id3, 'I03P:0', heavy)
    ShopAddItem(id3, 'I0F9:0', misc)
    ShopAddItem(id3, 'I079:0', heavy)
    ShopAddItem(id3, 'I0FC:0', heavy)
    ShopAddItem(id3, 'I00A:0', misc)

    -- godslayer set
    ShopAddItem(id, 'I0JR:0', sets + plate)
    ItemAddComponents('I0JR:0', "I02B I02C I02O")

    -- dwarven set
    ShopAddItem(id, 'I08K:0', sets + fullplate)
    ItemAddComponents('I08K:0', "I079 I0FC I07B")

    -- dragoon set
    ShopAddItem(id, 'I0F4:0', sets + leather)
    ItemAddComponents('I0F4:0', "I0EY I074 I04N I0EX")

    -- forgotten mystic set
    ShopAddItem(id, 'I0F5:0', sets + cloth)
    ItemAddComponents('I0F5:0', "I03U I07F I0F3")

    -- paladin set
    ShopAddItem(id, 'I012:0', sets + Shield)
    ItemAddComponents('I012:0', "I03P I0FX I0C0 I0F9")

    -- aura of gods
    ShopAddItem(id, 'I04J:0', sets + misc)
    ItemAddComponents('I04J:0', "I00A I030 I04I I031 I02Z")

    -- demon components
    ShopAddItem(id, 'I06S:0', sword)
    ShopAddItem(id, 'I04T:0', heavy)
    ShopAddItem(id, 'I06U:0', dagger)
    ShopAddItem(id, 'I06O:0', bow)
    ShopAddItem(id, 'I06Q:0', staff)
    ShopAddItem(id, 'I073:0', plate)
    ShopAddItem(id, 'I075:0', fullplate)
    ShopAddItem(id, 'I06Z:0', leather)
    ShopAddItem(id, 'I06W:0', cloth)

    -- demon sets
    -- sword
    ITEM_PRICE['I0CK:0'][GOLD] = 250000
    ShopAddItem(id, 'I0CK:0', sets + sword + plate)
    ItemAddComponents('I0CK:0', "I06S I06S I06S I073 I073 I04T")
    -- heavy
    ITEM_PRICE['I0BN:0'][GOLD] = 250000
    ShopAddItem(id, 'I0BN:0', sets + heavy + fullplate)
    ItemAddComponents('I0BN:0', "I075 I075 I075 I04T I04T I073")
    -- dagger
    ITEM_PRICE['I0BO:0'][GOLD] = 250000
    ShopAddItem(id, 'I0BO:0', sets + dagger + leather)
    ItemAddComponents('I0BO:0', "I06U I06U I06U I06Z I06Z I06Z")
    -- bow
    ITEM_PRICE['I0CU:0'][GOLD] = 250000
    ShopAddItem(id, 'I0CU:0', sets + bow + leather)
    ItemAddComponents('I0CU:0', "I06O I06O I06O I06Z I06Z I06Z")
    -- staff
    ITEM_PRICE['I0CT:0'][GOLD] = 250000
    ShopAddItem(id, 'I0CT:0', sets + staff + cloth)
    ItemAddComponents('I0CT:0', "I06Q I06Q I06Q I06W I06W I06W")

    -- horror components
    ShopAddItem(id, 'I07M:0', sword)
    ShopAddItem(id, 'I07A:0', heavy)
    ShopAddItem(id, 'I07L:0', dagger)
    ShopAddItem(id, 'I07P:0', bow)
    ShopAddItem(id, 'I077:0', staff)
    ShopAddItem(id, 'I07E:0', plate)
    ShopAddItem(id, 'I07I:0', fullplate)
    ShopAddItem(id, 'I07G:0', leather)
    ShopAddItem(id, 'I07C:0', cloth)
    ShopAddItem(id, 'I07K:0', misc)
    ShopAddItem(id, 'I05D:0', Shield)

    -- horror sets
    -- sword
    ITEM_PRICE['I0CV:0'][GOLD] = 500000
    ShopAddItem(id, 'I0CV:0', sets + sword + plate)
    ItemAddComponents('I0CV:0', "I07M I07M I07M I07E I07E I07A I07A")
    -- heavy
    ITEM_PRICE['I0C2:0'][GOLD] = 500000
    ShopAddItem(id, 'I0C2:0', sets + heavy + fullplate)
    ItemAddComponents('I0C2:0', "I07I I07I I07I I07A I07A I07E I05D")
    -- dagger
    ITEM_PRICE['I0C1:0'][GOLD] = 500000
    ShopAddItem(id, 'I0C1:0', sets + dagger + leather)
    ItemAddComponents('I0C1:0', "I07L I07L I07L I07G I07G I07G I07K")
    -- bow
    ITEM_PRICE['I0CW:0'][GOLD] = 500000
    ShopAddItem(id, 'I0CW:0', sets + bow + leather)
    ItemAddComponents('I0CW:0', "I07P I07P I07P I07G I07G I07G I07K")
    -- staff
    ITEM_PRICE['I0CX:0'][GOLD] = 500000
    ShopAddItem(id, 'I0CX:0', sets + staff + cloth)
    ItemAddComponents('I0CX:0', "I077 I077 I077 I07C I07C I07C I07K")

    -- despair components
    ShopAddItem(id, 'I07V:0', sword)
    ShopAddItem(id, 'I07X:0', heavy)
    ShopAddItem(id, 'I07Z:0', dagger)
    ShopAddItem(id, 'I07R:0', bow)
    ShopAddItem(id, 'I07T:0', staff)
    ShopAddItem(id, 'I087:0', plate)
    ShopAddItem(id, 'I089:0', fullplate)
    ShopAddItem(id, 'I083:0', leather)
    ShopAddItem(id, 'I081:0', cloth)
    ShopAddItem(id, 'I05P:0', misc)

    -- despair sets
    -- sword
    ITEM_PRICE['I0CY:0'][GOLD] = 500000
    ITEM_PRICE['I0CY:0'][PLATINUM] = 1
    ITEM_PRICE['I0CY:0'][CRYSTAL] = 1
    ShopAddItem(id, 'I0CY:0', sets + sword + plate)
    ItemAddComponents('I0CY:0', "I07V I07V I07V I087 I087 I07X")
    -- heavy
    ITEM_PRICE['I0BQ:0'][GOLD] = 500000
    ITEM_PRICE['I0BQ:0'][PLATINUM] = 1
    ITEM_PRICE['I0BQ:0'][CRYSTAL] = 1
    ShopAddItem(id, 'I0BQ:0', sets + heavy + fullplate)
    ItemAddComponents('I0BQ:0', "I089 I089 I089 I07X I07X I087")
    -- dagger
    ITEM_PRICE['I0BP:0'][GOLD] = 500000
    ITEM_PRICE['I0BP:0'][PLATINUM] = 1
    ITEM_PRICE['I0BP:0'][CRYSTAL] = 1
    ShopAddItem(id, 'I0BP:0', sets + dagger + leather)
    ItemAddComponents('I0BP:0', "I07Z I07Z I07Z I083 I083 I083")
    -- bow
    ITEM_PRICE['I0CZ:0'][GOLD] = 500000
    ITEM_PRICE['I0CZ:0'][PLATINUM] = 1
    ITEM_PRICE['I0CZ:0'][CRYSTAL] = 1
    ShopAddItem(id, 'I0CZ:0', sets + bow + leather)
    ItemAddComponents('I0CZ:0', "I07R I07R I07R I083 I083 I083")
    -- staff
    ITEM_PRICE['I0D3:0'][GOLD] = 500000
    ITEM_PRICE['I0D3:0'][PLATINUM] = 1
    ITEM_PRICE['I0D3:0'][CRYSTAL] = 1
    ShopAddItem(id, 'I0D3:0', sets + staff + cloth)
    ItemAddComponents('I0D3:0', "I07T I07T I07T I081 I081 I081")

    -- abyssal components
    ShopAddItem(id, 'I06A:0', sword)
    ShopAddItem(id, 'I06D:0', heavy)
    ShopAddItem(id, 'I06B:0', dagger)
    ShopAddItem(id, 'I06C:0', bow)
    ShopAddItem(id, 'I09N:0', staff)
    ShopAddItem(id, 'I09X:0', plate)
    ShopAddItem(id, 'I0A0:0', fullplate)
    ShopAddItem(id, 'I0A2:0', leather)
    ShopAddItem(id, 'I0A5:0', cloth)

    -- abyssal sets
    -- sword
    ITEM_PRICE['I0C9:0'][PLATINUM] = 4
    ITEM_PRICE['I0C9:0'][CRYSTAL] = 2
    ShopAddItem(id, 'I0C9:0', sets + sword + plate)
    ItemAddComponents('I0C9:0', "I06A I06A I06A I09X I09X I06D")
    -- heavy
    ITEM_PRICE['I0C8:0'][PLATINUM] = 4
    ITEM_PRICE['I0C8:0'][CRYSTAL] = 2
    ShopAddItem(id, 'I0C8:0', sets + heavy + fullplate)
    ItemAddComponents('I0C8:0', "I0A0 I0A0 I0A0 I06D I06D I09X")
    -- dagger
    ITEM_PRICE['I0C7:0'][PLATINUM] = 4
    ITEM_PRICE['I0C7:0'][CRYSTAL] = 2
    ShopAddItem(id, 'I0C7:0', sets + dagger + leather)
    ItemAddComponents('I0C7:0', "I06B I06B I06B I0A2 I0A2 I0A2")
    -- bow
    ITEM_PRICE['I0C6:0'][PLATINUM] = 4
    ITEM_PRICE['I0C6:0'][CRYSTAL] = 2
    ShopAddItem(id, 'I0C6:0', sets + bow + leather)
    ItemAddComponents('I0C6:0', "I06C I06C I06C I0A2 I0A2 I0A2")
    -- staff
    ITEM_PRICE['I0C5:0'][PLATINUM] = 4
    ITEM_PRICE['I0C5:0'][CRYSTAL] = 2
    ShopAddItem(id, 'I0C5:0', sets + staff + cloth)
    ItemAddComponents('I0C5:0', "I09N I09N I09N I0A5 I0A5 I0A5")

    -- void components
    ShopAddItem(id, 'I08C:0', sword)
    ShopAddItem(id, 'I08D:0', heavy)
    ShopAddItem(id, 'I08J:0', dagger)
    ShopAddItem(id, 'I08H:0', bow)
    ShopAddItem(id, 'I08G:0', staff)
    ShopAddItem(id, 'I08S:0', plate)
    ShopAddItem(id, 'I08U:0', fullplate)
    ShopAddItem(id, 'I08O:0', leather)
    ShopAddItem(id, 'I08M:0', cloth)
    ShopAddItem(id, 'I055:0', misc)
    ShopAddItem(id, 'I04Y:0', misc)
    ShopAddItem(id, 'I08N:0', misc)
    ShopAddItem(id, 'I04W:0', Shield)

    -- void sets
    -- sword
    ITEM_PRICE['I0D7:0'][PLATINUM] = 9
    ITEM_PRICE['I0D7:0'][CRYSTAL] = 3
    ShopAddItem(id, 'I0D7:0', sets + sword + plate)
    ItemAddComponents('I0D7:0', "I08C I08C I08C I08S I08S I08D I055")
    -- heavy
    ITEM_PRICE['I0C4:0'][PLATINUM] = 9
    ITEM_PRICE['I0C4:0'][CRYSTAL] = 3
    ShopAddItem(id, 'I0C4:0', sets + heavy + fullplate)
    ItemAddComponents('I0C4:0', "I08U I08U I08U I08D I08D I08S I04W")
    -- dagger
    ITEM_PRICE['I0C3:0'][PLATINUM] = 9
    ITEM_PRICE['I0C3:0'][CRYSTAL] = 3
    ShopAddItem(id, 'I0C3:0', sets + dagger + leather)
    ItemAddComponents('I0C3:0', "I08J I08J I08J I08O I08O I08O I055")
    -- bow
    ITEM_PRICE['I0D5:0'][PLATINUM] = 9
    ITEM_PRICE['I0D5:0'][CRYSTAL] = 3
    ShopAddItem(id, 'I0D5:0', sets + bow + leather)
    ItemAddComponents('I0D5:0', "I08H I08H I08H I08O I08O I08O I055")
    -- staff
    ITEM_PRICE['I0D6:0'][PLATINUM] = 9
    ITEM_PRICE['I0D6:0'][CRYSTAL] = 3
    ShopAddItem(id, 'I0D6:0', sets + staff + cloth)
    ItemAddComponents('I0D6:0', "I08G I08G I08G I08M I08M I08M I04Y")

    -- nightmare components
    ShopAddItem(id, 'I09P:0', sword)
    ShopAddItem(id, 'I09V:0', heavy)
    ShopAddItem(id, 'I09R:0', dagger)
    ShopAddItem(id, 'I09S:0', bow)
    ShopAddItem(id, 'I09T:0', staff)
    ShopAddItem(id, 'I0A7:0', plate)
    ShopAddItem(id, 'I0A9:0', fullplate)
    ShopAddItem(id, 'I0AC:0', leather)
    ShopAddItem(id, 'I0AB:0', cloth)

    -- nightmare sets
    -- sword
    ITEM_PRICE['I0CB:0'][PLATINUM] = 16
    ITEM_PRICE['I0CB:0'][CRYSTAL] = 6
    ShopAddItem(id, 'I0CB:0', sets + sword + plate)
    ItemAddComponents('I0CB:0', "I09P I09P I09P I09P I0A7 I0A7 I09V")
    -- heavy
    ITEM_PRICE['I0CA:0'][PLATINUM] = 16
    ITEM_PRICE['I0CA:0'][CRYSTAL] = 6
    ShopAddItem(id, 'I0CA:0', sets + heavy + fullplate)
    ItemAddComponents('I0CA:0', "I0A9 I0A9 I0A9 I09V I09V I09V I0A7")
    -- dagger
    ITEM_PRICE['I0CD:0'][PLATINUM] = 16
    ITEM_PRICE['I0CD:0'][CRYSTAL] = 6
    ShopAddItem(id, 'I0CD:0', sets + dagger + leather)
    ItemAddComponents('I0CD:0', "I09R I09R I09R I09R I0AC I0AC I0AC")
    -- bow
    ITEM_PRICE['I0CE:0'][PLATINUM] = 16
    ITEM_PRICE['I0CE:0'][CRYSTAL] = 6
    ShopAddItem(id, 'I0CE:0', sets + bow + leather)
    ItemAddComponents('I0CE:0', "I09S I09S I09S I09S I0AC I0AC I0AC")
    -- staff
    ITEM_PRICE['I0CF:0'][PLATINUM] = 16
    ITEM_PRICE['I0CF:0'][CRYSTAL] = 6
    ShopAddItem(id, 'I0CF:0', sets + staff + cloth)
    ItemAddComponents('I0CF:0', "I09T I09T I09T I09T I0AB I0AB I0AB")

    -- hell components
    ShopAddItem(id, 'I05G:0', sword)
    ShopAddItem(id, 'I08W:0', heavy)
    ShopAddItem(id, 'I08Z:0', dagger)
    ShopAddItem(id, 'I091:0', bow)
    ShopAddItem(id, 'I093:0', staff)
    ShopAddItem(id, 'I097:0', plate)
    ShopAddItem(id, 'I098:0', leather)
    ShopAddItem(id, 'I05H:0', fullplate)
    ShopAddItem(id, 'I095:0', cloth)
    ShopAddItem(id, 'I05I:0', misc)

    -- hell sets
    -- sword
    ITEM_PRICE['I0D8:0'][PLATINUM] = 25
    ITEM_PRICE['I0D8:0'][CRYSTAL] = 10
    ShopAddItem(id, 'I0D8:0', sets + sword + plate)
    ItemAddComponents('I0D8:0', "I05G I05G I05G I097 I097 I08W I05I")
    -- heavy
    ITEM_PRICE['I0BW:0'][PLATINUM] = 25
    ITEM_PRICE['I0BW:0'][CRYSTAL] = 10
    ShopAddItem(id, 'I0BW:0', sets + heavy + fullplate)
    ItemAddComponents('I0BW:0', "I05H I05H I05H I08W I08W I08W I097")
    -- dagger
    ITEM_PRICE['I0BU:0'][PLATINUM] = 25
    ITEM_PRICE['I0BU:0'][CRYSTAL] = 10
    ShopAddItem(id, 'I0BU:0', sets + dagger + leather)
    ItemAddComponents('I0BU:0', "I08Z I08Z I08Z I098 I098 I098 I05I")
    -- bow
    ITEM_PRICE['I0DK:0'][PLATINUM] = 25
    ITEM_PRICE['I0DK:0'][CRYSTAL] = 10
    ShopAddItem(id, 'I0DK:0', sets + bow + leather)
    ItemAddComponents('I0DK:0', "I091 I091 I091 I098 I098 I098 I05I")
    -- staff
    ITEM_PRICE['I0DJ:0'][PLATINUM] = 25
    ITEM_PRICE['I0DJ:0'][CRYSTAL] = 10
    ShopAddItem(id, 'I0DJ:0', sets + staff + cloth)
    ItemAddComponents('I0DJ:0', "I093 I093 I093 I093 I095 I095 I095")

    -- existence components
    ShopAddItem(id, 'I09K:0', sword)
    ShopAddItem(id, 'I09M:0', heavy)
    ShopAddItem(id, 'I09I:0', dagger)
    ShopAddItem(id, 'I09G:0', bow)
    ShopAddItem(id, 'I09E:0', staff)
    ShopAddItem(id, 'I09U:0', plate)
    ShopAddItem(id, 'I09W:0', fullplate)
    ShopAddItem(id, 'I09Q:0', leather)
    ShopAddItem(id, 'I09O:0', cloth)

    -- existence sets
    -- sword
    ITEM_PRICE['I0DX:0'][PLATINUM] = 40
    ITEM_PRICE['I0DX:0'][CRYSTAL] = 15
    ShopAddItem(id, 'I0DX:0', sets + sword + plate)
    ItemAddComponents('I0DX:0', "I09K I09K I09K I09K I09U I09U I09M")
    -- heavy
    ITEM_PRICE['I0BT:0'][PLATINUM] = 40
    ITEM_PRICE['I0BT:0'][CRYSTAL] = 15
    ShopAddItem(id, 'I0BT:0', sets + heavy + fullplate)
    ItemAddComponents('I0BT:0', "I09W I09W I09W I09M I09M I09M I09U")
    -- dagger
    ITEM_PRICE['I0BR:0'][PLATINUM] = 40
    ITEM_PRICE['I0BR:0'][CRYSTAL] = 15
    ShopAddItem(id, 'I0BR:0', sets + dagger + leather)
    ItemAddComponents('I0BR:0', "I09I I09I I09I I09I I09Q I09Q I09Q")
    -- bow
    ITEM_PRICE['I0DL:0'][PLATINUM] = 40
    ITEM_PRICE['I0DL:0'][CRYSTAL] = 15
    ShopAddItem(id, 'I0DL:0', sets + bow + leather)
    ItemAddComponents('I0DL:0', "I09G I09G I09G I09G I09Q I09Q I09Q")
    -- staff
    ITEM_PRICE['I0DY:0'][PLATINUM] = 40
    ITEM_PRICE['I0DY:0'][CRYSTAL] = 15
    ShopAddItem(id, 'I0DY:0', sets + staff + cloth)
    ItemAddComponents('I0DY:0', "I09E I09E I09E I09E I09O I09O I09O")

    -- astral components
    ShopAddItem(id, 'I0A3:0', sword)
    ShopAddItem(id, 'I0A6:0', heavy)
    ShopAddItem(id, 'I0A1:0', dagger)
    ShopAddItem(id, 'I0A4:0', bow)
    ShopAddItem(id, 'I09Z:0', staff)
    ShopAddItem(id, 'I0AL:0', plate)
    ShopAddItem(id, 'I0AN:0', fullplate)
    ShopAddItem(id, 'I0AA:0', leather)
    ShopAddItem(id, 'I0A8:0', cloth)

    -- astral sets
    -- sword
    ITEM_PRICE['I0E0:0'][PLATINUM] = 75
    ITEM_PRICE['I0E0:0'][CRYSTAL] = 30
    ShopAddItem(id, 'I0E0:0', sets + sword + plate)
    ItemAddComponents('I0E0:0', "I0A3 I0A3 I0A3 I0A3 I0AL I0AL I0A6")
    -- heavy
    ITEM_PRICE['I0BM:0'][PLATINUM] = 75
    ITEM_PRICE['I0BM:0'][CRYSTAL] = 30
    ShopAddItem(id, 'I0BM:0', sets + heavy + fullplate)
    ItemAddComponents('I0BM:0', "I0AN I0AN I0AN I0A6 I0A6 I0A6 I0AL")
    -- dagger
    ITEM_PRICE['I0DZ:0'][PLATINUM] = 75
    ITEM_PRICE['I0DZ:0'][CRYSTAL] = 30
    ShopAddItem(id, 'I0DZ:0', sets + dagger + leather)
    ItemAddComponents('I0DZ:0', "I0A1 I0A1 I0A1 I0A1 I0AA I0AA I0AA")
    -- bow
    ITEM_PRICE['I059:0'][PLATINUM] = 75
    ITEM_PRICE['I059:0'][CRYSTAL] = 30
    ShopAddItem(id, 'I059:0', sets + bow + leather)
    ItemAddComponents('I059:0', "I0A4 I0A4 I0A4 I0A4 I0AA I0AA I0AA")
    -- staff
    ITEM_PRICE['I0E1:0'][PLATINUM] = 75
    ITEM_PRICE['I0E1:0'][CRYSTAL] = 30
    ShopAddItem(id, 'I0E1:0', sets + staff + cloth)
    ItemAddComponents('I0E1:0', "I09Z I09Z I09Z I09Z I0A8 I0A8 I0A8")

    -- dimensional components
    ShopAddItem(id, 'I0AO:0', sword)
    ShopAddItem(id, 'I0AQ:0', heavy)
    ShopAddItem(id, 'I0AT:0', dagger)
    ShopAddItem(id, 'I0AR:0', bow)
    ShopAddItem(id, 'I0AW:0', staff)
    ShopAddItem(id, 'I0AY:0', plate)
    ShopAddItem(id, 'I0B0:0', fullplate)
    ShopAddItem(id, 'I0B2:0', leather)
    ShopAddItem(id, 'I0B3:0', cloth)

    -- dimensional sets
    -- sword
    ITEM_PRICE['I0CG:0'][PLATINUM] = 135
    ITEM_PRICE['I0CG:0'][CRYSTAL] = 55
    ShopAddItem(id, 'I0CG:0', sets + sword + plate)
    ItemAddComponents('I0CG:0', "I0AO I0AO I0AO I0AO I0AY I0AY I0AQ")
    -- heavy
    ITEM_PRICE['I0FH:0'][PLATINUM] = 135
    ITEM_PRICE['I0FH:0'][CRYSTAL] = 55
    ShopAddItem(id, 'I0FH:0', sets + heavy + fullplate)
    ItemAddComponents('I0FH:0', "I0B0 I0B0 I0B0 I0AQ I0AQ I0AQ I0AY")
    -- dagger
    ITEM_PRICE['I0CI:0'][PLATINUM] = 135
    ITEM_PRICE['I0CI:0'][CRYSTAL] = 55
    ShopAddItem(id, 'I0CI:0', sets + dagger + leather)
    ItemAddComponents('I0CI:0', "I0AT I0AT I0AT I0AT I0B2 I0B2 I0B2")
    -- bow
    ITEM_PRICE['I0FI:0'][PLATINUM] = 135
    ITEM_PRICE['I0FI:0'][CRYSTAL] = 55
    ShopAddItem(id, 'I0FI:0', sets + bow + leather)
    ItemAddComponents('I0FI:0', "I0AR I0AR I0AR I0AR I0B2 I0B2 I0B2")
    -- staff
    ITEM_PRICE['I0FZ:0'][PLATINUM] = 135
    ITEM_PRICE['I0FZ:0'][CRYSTAL] = 55
    ShopAddItem(id, 'I0FZ:0', sets + staff + cloth)
    ItemAddComponents('I0FZ:0', "I0AW I0AW I0AW I0AW I0B3 I0B3 I0B3")
    -- cheese shield
    -- call ShopAddItem(id2, 'I01Y:0', misc)
    ITEM_PRICE['I038:0'][GOLD] = 100
    ShopAddItem(id2, 'I038:0', misc)
    ItemAddComponents('I038:0', "I01Y")

    -- hydra weapons
    ITEM_PRICE['I02N:0'][GOLD] = 5000
    ITEM_PRICE['I072:0'][GOLD] = 5000
    ITEM_PRICE['I06Y:0'][GOLD] = 5000
    ITEM_PRICE['I070:0'][GOLD] = 5000
    ITEM_PRICE['I071:0'][GOLD] = 5000
    ShopAddItem(id2, 'I02N:0', sword)
    ShopAddItem(id2, 'I072:0', heavy)
    ShopAddItem(id2, 'I06Y:0', dagger)
    ShopAddItem(id2, 'I070:0', bow)
    ShopAddItem(id2, 'I071:0', staff)

    ItemAddComponents('I02N:0', "I07N")
    ItemAddComponents('I072:0', "I07N")
    ItemAddComponents('I06Y:0', "I07N")
    ItemAddComponents('I070:0', "I07N")
    ItemAddComponents('I071:0', "I07N")

    -- iron golem fist
    -- call ShopAddItem(id2, 'I02Q:0', misc)

    ITEM_PRICE['I046:0'][GOLD] = 75000
    ShopAddItem(id2, 'I046:0', misc)
    ItemAddComponents('I046:0', "I02Q I02Q I02Q I02Q I02Q I02Q")

    -- dragon armor
    ITEM_PRICE['I048:0'][GOLD] = 10000
    ITEM_PRICE['I02U:0'][GOLD] = 10000
    ITEM_PRICE['I064:0'][GOLD] = 10000
    ITEM_PRICE['I02P:0'][GOLD] = 10000
    ShopAddItem(id2, 'I048:0', plate)
    ShopAddItem(id2, 'I02U:0', fullplate)
    ShopAddItem(id2, 'I064:0', leather)
    ShopAddItem(id2, 'I02P:0', cloth)

    ItemAddComponents('I048:0', "I05Z I05Z I056")
    ItemAddComponents('I02U:0', "I05Z I05Z I056")
    ItemAddComponents('I064:0', "I05Z I05Z I056")
    ItemAddComponents('I02P:0', "I05Z I05Z I056")

    -- dragon weapons
    ITEM_PRICE['I033:0'][GOLD] = 10000
    ITEM_PRICE['I0BZ:0'][GOLD] = 10000
    ITEM_PRICE['I02S:0'][GOLD] = 10000
    ITEM_PRICE['I032:0'][GOLD] = 10000
    ITEM_PRICE['I065:0'][GOLD] = 10000
    ShopAddItem(id2, 'I033:0', sword)
    ShopAddItem(id2, 'I0BZ:0', heavy)
    ShopAddItem(id2, 'I02S:0', dagger)
    ShopAddItem(id2, 'I032:0', bow)
    ShopAddItem(id2, 'I065:0', staff)

    ItemAddComponents('I033:0', "I04X I04X I056")
    ItemAddComponents('I0BZ:0', "I04X I04X I056")
    ItemAddComponents('I02S:0', "I04X I04X I056")
    ItemAddComponents('I032:0', "I04X I04X I056")
    ItemAddComponents('I065:0', "I04X I04X I056")

    -- bloody armor
    ITEM_PRICE['I0N4:0'][CRYSTAL] = 1
    ITEM_PRICE['I00X:0'][CRYSTAL] = 1
    ITEM_PRICE['I0N5:0'][CRYSTAL] = 1
    ITEM_PRICE['I0N6:0'][CRYSTAL] = 1
    ShopAddItem(id2, 'I0N4:0', plate)
    ShopAddItem(id2, 'I00X:0', fullplate)
    ShopAddItem(id2, 'I0N5:0', leather)
    ShopAddItem(id2, 'I0N6:0', cloth)

    ItemAddComponents('I0N4:0', "I04Q")
    ItemAddComponents('I00X:0', "I04Q")
    ItemAddComponents('I0N5:0', "I04Q")
    ItemAddComponents('I0N6:0', "I04Q")

    -- bloody weapons
    ITEM_PRICE['I03F:0'][CRYSTAL] = 1
    ITEM_PRICE['I04S:0'][CRYSTAL] = 1
    ITEM_PRICE['I020:0'][CRYSTAL] = 1
    ITEM_PRICE['I016:0'][CRYSTAL] = 1
    ITEM_PRICE['I0AK:0'][CRYSTAL] = 1
    ShopAddItem(id2, 'I03F:0', sword)
    ShopAddItem(id2, 'I04S:0', heavy)
    ShopAddItem(id2, 'I020:0', dagger)
    ShopAddItem(id2, 'I016:0', bow)
    ShopAddItem(id2, 'I0AK:0', staff)

    ItemAddComponents('I03F:0', "I04Q")
    ItemAddComponents('I04S:0', "I04Q")
    ItemAddComponents('I020:0', "I04Q")
    ItemAddComponents('I016:0', "I04Q")
    ItemAddComponents('I0AK:0', "I04Q")

    -- chaotic necklace
    ITEM_PRICE['I050:0'][PLATINUM] = 10
    ITEM_PRICE['I050:0'][CRYSTAL] = 10
    ShopAddItem(id2, 'I050:0', misc)
    ItemAddComponents('I050:0', "I04Z I04Z I04Z I04Z I04Z I04Z")

    -- drum of war
    ITEM_PRICE['I0NJ:0'][GOLD] = 100000
    ShopAddItem(id2, 'I0NJ:0', sets + misc)
    ItemAddComponents('I0NJ:0', "I04J I00H")

    -- demon golem fist
    ITEM_PRICE['I0OF:0'][GOLD] = 100000
    ShopAddItem(id2, 'I0OF:0', misc)
    ItemAddComponents('I0OF:0', "I046 I04Q")

    -- chaos shield
    ITEM_PRICE['I01J:0'][GOLD] = 1000000
    ShopAddItem(id2, 'I01J:0', misc)
    ItemAddComponents('I01J:0', "I0BY I09Y I0BX:5 I0AI I0AH I08N")

    -- absolute items
    ITEM_PRICE['I0NA:0'][GOLD] = 50000
    ShopAddItem(id2, 'I0NA:0', fullplate)
    ItemAddComponents('I0NA:0', "I02U I0N9 I0N9")

    ITEM_PRICE['I0NB:0'][GOLD] = 50000
    ShopAddItem(id2, 'I0NB:0', heavy)
    ItemAddComponents('I0NB:0', "I033 I0N8 I0N8")

    ITEM_PRICE['I0NC:0'][GOLD] = 50000
    ShopAddItem(id2, 'I0NC:0', bow)
    ItemAddComponents('I0NC:0', "I032 I0N7 I0N7")

    ITEM_PRICE['I0ND:0'][GOLD] = 50000
    ShopAddItem(id2, 'I0ND:0', dagger)
    ItemAddComponents('I0ND:0', "I02S I0N7 I0N7")

    ITEM_PRICE['I0NE:0'][GOLD] = 50000
    ShopAddItem(id2, 'I0NE:0', staff)
    ItemAddComponents('I0NE:0', "I065 I0N7 I0N8")

    ITEM_PRICE['I0NF:0'][GOLD] = 50000
    ShopAddItem(id2, 'I0NF:0', sword)
    ItemAddComponents('I0NF:0', "I0BZ I0N8 I0N8")

    ITEM_PRICE['I0NI:0'][GOLD] = 50000
    ShopAddItem(id2, 'I0NI:0', cloth)
    ItemAddComponents('I0NI:0', "I02P I0N9 I0N9")

    ITEM_PRICE['I0NG:0'][GOLD] = 50000
    ShopAddItem(id2, 'I0NG:0', plate)
    ItemAddComponents('I0NG:0', "I048 I0N9 I0N9")

    ITEM_PRICE['I0NH:0'][GOLD] = 50000
    ShopAddItem(id2, 'I0NH:0', leather)
    ItemAddComponents('I0NH:0', "I064 I0N9 I0N9")

    -- evil shopkeeper initialization
    ShopkeeperMove()
end, Debug and Debug.getLine())
