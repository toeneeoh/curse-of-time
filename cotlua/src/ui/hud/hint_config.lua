OnInit.global("HintConfig", function()
    HINT_TOOLTIP = { ---@type string[]
        "|cffc0c0c0Did you know?|r |cff9966ffCoT RPG|r |cffc0c0c0has a discord!|r |cff9ebef5https://discord.gg/peSTvTd|r",
        "|cffc0c0c0Game too easy for you? Select|r |cff9966ffHardcore|r |cffc0c0c0on character creation to increase difficulty & increase benefits.|r",
        "|cffc0c0c0Type|r |cff9966ff-info|r |cffc0c0c0or|r check |cff9966ffF9|r |cffc0c0c0to for important game information, especially if you are new.|r",
        "|cffc0c0c0After an item drops it will be removed after 10 minutes, but don’t worry if you’ve already picked it up or bound it with your hero as they will not delete.|r",
        "|cffc0c0c0Game too difficult? We recommend playing with 2+ players. If you are playing solo, consider playing online with friends or others.|r",
        "|cffc0c0c0Enemies that respawn will appear as ghosts if you are too close, however if you walk away they will return to normal.|r",
        "|cffc0c0c0You can type|r |cff9966ff-hints|r or |cff9966ff-nohints|r |cffc0c0c0to toggle these messages on and off.|r",
        "|cffc0c0c0Once you challenge the gods you cannot flee.|r",
        "|cffc0c0c0Some artifacts remain frozen in ice, waiting to be recovered...|r",
        "|cffc0c0c0Spellboost innately affects the damage of your spells by plus or minus 10%.|r",
        "|cffc0c0c0Critical strike items and spells can stack their effect, the multipliers are additive.|r",
        "|cffc0c0c0The settings menu (Q on your backpack) provides many useful features such as displaying allied hero portraits on the left.|r",
        "|cffc0c0c0You can toggle off your auto attacks with CTRL + A.|r",
        "|cffc0c0c0Hotkeys for certain things may be changed in the settings menu (Q on your backpack).|r",
        "|cffc0c0c0If you meant to load another hero and you haven't left the church, you can type|r |cff9966ff-repick|r |cffc0c0c0and then|r |cff9966ff-load|r |cffc0c0c0to load another hero.|r",
        "|cffc0c0c0Hold |cff9966ffLeft Alt|r |cffc0c0c0while viewing your abilites to see how they are affected by Spellboost.|r",
    }

    LAST_HINT = 0
    FORCE_HINT = CreateForce() ---@type force
end, Debug and Debug.getLine())
