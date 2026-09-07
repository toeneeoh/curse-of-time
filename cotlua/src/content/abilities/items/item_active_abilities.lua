OnInit.final("ItemActiveAbilities", function(Require)
    Require("Spells")

    local PALADIN_BOOK = Spell.define('A083')
    do
        local thistype = PALADIN_BOOK

        function thistype:onCast()
            local heal = 3 * GetHeroInt(self.caster, true) * BOOST[self.pid]
            if GetUnitTypeId(self.target) == BACKPACK then
                HP(self.caster, Hero[self.tpid], heal, thistype.tag)
            else
                HP(self.caster, self.target, heal, thistype.tag)
            end
        end
    end

    local INSTILL_FEAR = Spell.define('A02A')
    do
        local thistype = INSTILL_FEAR

        local missile_template = {
            selfInteractions = {
                CAT_MoveHoming3D,
                CAT_Orient3D,
            },
            interactions = {
                unit = CAT_UnitCollisionCheck3D,
            },
            visualZ = 70.,
            identifier = "missile",
            collisionRadius = 1.,
            onlyTarget = true,
            speed = 1400.,
            onUnitCollision = CAT_UnitImpact3D,
            onUnitCallback = function(self, enemy)
                InstillFearDebuff:add(self.source, enemy):duration(7.)
            end,
        }
        missile_template.__index = missile_template

        function thistype:onCast()
            local missile = setmetatable({}, missile_template)
            missile.x = self.x
            missile.y = self.y
            missile.z = GetUnitZ(self.caster)
            missile.visual = AddSpecialEffect("Abilities\\Spells\\NightElf\\shadowstrike\\ShadowStrikeMissile.mdl", self.x, self.y)
            BlzSetSpecialEffectScale(missile.visual, 1.1)
            missile.source = self.caster
            missile.target = self.target
            missile.owner = Player(self.pid - 1)

            ALICE_Create(missile)
        end
    end

    local DARKEST_OF_DARKNESS = Spell.define('A055')
    do
        local thistype = DARKEST_OF_DARKNESS

        function thistype:onCast()
            DarkestOfDarknessBuff:add(self.caster, self.caster):duration(20.)
        end
    end

    local ASTRAL_FREEZE_ITEM = Spell.define('A0SX')
    do
        local thistype = ASTRAL_FREEZE_ITEM

        function thistype:onCast()
            local pt = TimerList[self.pid]:add()
            pt.source = self.caster
            pt.dmg = 40. * GetHeroInt(self.caster, true) * BOOST[self.pid]
            pt.angle = bj_RADTODEG * self.angle

            pt:after(0., ASTRAL_FREEZE.effect)
        end
    end

    local FINAL_BLAST = Spell.define('A00E')
    do
        local thistype = FINAL_BLAST

        function thistype:onCast()
            local ug = CreateGroup()
            MakeGroupInRange(self.pid, ug, self.x, self.y, 600.00, Condition(FilterEnemy))
            local x, y

            for i = 1, 12 do
                if i < 7 then
                    x = self.x + 200 * math.cos(60.00 * i * bj_DEGTORAD)
                    y = self.y + 200 * math.sin(60.00 * i * bj_DEGTORAD)
                    DestroyEffect(AddSpecialEffect("war3mapImported\\NeutralExplosion.mdx", x, y))
                end
                x = self.x + 400 * math.cos(60.00 * i * bj_DEGTORAD)
                y = self.y + 400 * math.sin(60.00 * i * bj_DEGTORAD)
                DestroyEffect(AddSpecialEffect("war3mapImported\\NeutralExplosion.mdx", x, y))
                x = self.x + 600 * math.cos(60.00 * i * bj_DEGTORAD)
                y = self.y + 600 * math.sin(60.00 * i * bj_DEGTORAD)
                DestroyEffect(AddSpecialEffect("war3mapImported\\NeutralExplosion.mdx", x, y))
            end

            for target in each(ug) do
                DamageTarget(self.caster, target, 10.00 * (GetHeroInt(self.caster, true) + GetHeroAgi(self.caster, true) + GetHeroStr(self.caster, true)) * BOOST[self.pid], ATTACK_TYPE_NORMAL, MAGIC, thistype.tag)
            end

            DestroyGroup(ug)
        end
    end

    local BANISH_DEMON = Spell.define('A00Q')
    do
        local thistype = BANISH_DEMON

        local quotes = {
            [BOSS_LEGION] = "|cffffcc00Legion:|r Fool! Did you really think splashing water on me would do anything?",
            [BOSS_DEATH_KNIGHT] = "|cffffcc00Death Knight:|r ...???",
        }

        function thistype:onCast()
            local itm = GetItemFromPlayer(self.pid, FourCC('I0OU'))
            local boss = IsBoss(self.target)

            if boss and quotes[boss.index] then
                itm:destroy()
                if not boss.disable_respawn then
                    boss.disable_respawn = true
                    DisplayTimedTextToForce(FORCE_PLAYING, 30., quotes[boss.index])
                end
            else
                DisplayTimedTextToPlayer(Player(self.pid - 1), 0., 0., 30., "Maybe you shouldn't waste this...")
            end
        end
    end

    local INTENSE_FOCUS = Spell.define('A0B9')
    do
        local thistype = INTENSE_FOCUS

        function thistype.onUnequip(itm, id, index, orig_holder)
            IntenseFocusBuff:dispel(orig_holder, orig_holder)
        end

        function thistype.onEquip(itm, id, index)
            IntenseFocusBuff:add(itm.holder, itm.holder)
        end
    end
end, Debug and Debug.getLine())
