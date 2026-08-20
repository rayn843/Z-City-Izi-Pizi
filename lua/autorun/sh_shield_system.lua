-- sh_shield_system.lua

-- Прекэш модели, чтобы избежать ошибки с NULL material
util.PrecacheModel("models/shield/shield_cz.mdl")

local DEBUG_SHIELD = true

local shieldMins = Vector(-13, -25, -1)
local shieldMaxs = Vector(13, 20, 1)

local shieldOffsetPos = Vector(0, 0, 0) 
local shieldOffsetAng = Angle(90, 0, 0)

--========================================================
-- СЕРВЕРНАЯ ЧАСТЬ
--========================================================
if SERVER then
    -- Команда для тестовой выдачи щита
    concommand.Add("give_shield", function(ply)
        if not IsValid(ply) then return end
        if not ply:IsAdmin() then return end
        
        ply.inventory = ply:GetNetVar("Inventory") or {}
        if not ply.inventory["Weapons"] then ply.inventory["Weapons"] = {} end
        
        if ply.inventory["Weapons"]["hg_shield"] then
            ply:ChatPrint("У вас уже есть щит в инвентаре.")
            return
        end
        
        ply.inventory["Weapons"]["hg_shield"] = true
        ply:SetNetVar("Inventory", ply.inventory)
        ply:ChatPrint("Вы получили щит. Возьмите пистолет, чтобы использовать.")
    end)

    local function DropShieldEntity(ply)
        local inventory = ply:GetNetVar("Inventory", {})
        if inventory and inventory["Weapons"] and inventory["Weapons"]["hg_shield"] then
            -- Удаляем из инвентаря
            inventory["Weapons"]["hg_shield"] = nil
            ply:SetNetVar("Inventory", inventory)
            
            -- Спавним энтити щита
            local ent = ents.Create("ent_shield")
            if IsValid(ent) then
                ent:SetPos(ply:GetPos() + Vector(0, 0, 10) + ply:GetForward() * 20)
                ent:Spawn()
                
                local phys = ent:GetPhysicsObject()
                if IsValid(phys) then
                    phys:ApplyForceCenter(ply:GetForward() * 100 + Vector(0, 0, 100))
                end
            end
        end
    end

    hook.Add("PlayerSwitchWeapon", "ShieldRestrictWeapons", function(ply, old, new)
        if ply:GetNWBool("HasShield", false) and IsValid(new) then
            if not (new.ishgweapon and new:IsPistolHoldType()) and new:GetClass() ~= "weapon_hands_sh" then
                -- Отправляем клиенту сигнал показать сообщение (на 3 секунды)
                ply:SetNW2Float("shield_block_expire", CurTime() + 3)
                DropShieldEntity(ply)
            end
        end
    end)


    -- Очистка пропов при выходе
    hook.Add("PlayerDisconnected", "ShieldPropRemove", function(ply)
        if IsValid(ply.ShieldProp) then ply.ShieldProp:Remove() end
    end)

    hook.Add("Think", "ShieldHitboxLerpUpdater", function()
        for _, ply in ipairs(player.GetAll()) do
            if not ply:GetNWBool("HasShield", false) then continue end
            local wep = ply:GetActiveWeapon()
            if not IsValid(wep) then continue end
            
            local isPistol = wep.ishgweapon and wep:IsPistolHoldType()
            local isHands = wep:GetClass() == "weapon_hands_sh"
            
            if isPistol then
                local isAiming = ply:KeyDown(IN_ATTACK2)
                ply:SetNW2Bool("ShieldLowered", isAiming)
                
                ply.sv_shield_lerp = ply.sv_shield_lerp or 0
                local target = isAiming and 0 or 1
                ply.sv_shield_lerp = math.Approach(ply.sv_shield_lerp, target, FrameTime() * 1)
            elseif isHands then
                ply:SetNW2Bool("ShieldLowered", false)
                ply.sv_shield_lerp = math.Approach(ply.sv_shield_lerp or 0, 1, FrameTime() * 1)
            else
                -- Держим другой предмет (бинт и т.д.) - плавно отключаем щит
                ply:SetNW2Bool("ShieldLowered", false)
                ply.sv_shield_lerp = math.Approach(ply.sv_shield_lerp or 0, 0, FrameTime() * 0.4)
            end
        end
    end)

    -- При смерти выпадает щит
    hook.Add("PlayerDeath", "ShieldPropRemoveDeath", function(ply)
        if IsValid(ply.ShieldProp) then ply.ShieldProp:Remove(); ply.ShieldProp = nil end
        DropShieldEntity(ply)
        ply:SetNWBool("HasShield", false)
    end)
    
    -- Очистка при спавне (на всякий случай)
    hook.Add("PlayerSpawn", "ShieldResetOnSpawn", function(ply)
        ply:SetNWBool("HasShield", false)
    end)
    
    hook.Add("Think", "ShieldForceCheckWeapon", function()
        for _, ply in ipairs(player.GetAll()) do
            local inventory = ply:GetNetVar("Inventory", {})
            local hasShieldItem = inventory and inventory["Weapons"] and inventory["Weapons"]["hg_shield"]

            if hasShieldItem and ply:Alive() then
                local wep = ply:GetActiveWeapon()
                local shouldHaveShield = false
                
                -- Проверяем, пистолет ли это (поддержка любых пистолетов, не только из Homigrad)
                if IsValid(wep) then
                    local holdType = wep:GetHoldType()
                    local isPistol = (wep.ishgweapon and wep:IsPistolHoldType()) or holdType == "pistol" or holdType == "revolver"
                    if isPistol or wep:GetClass() == "weapon_hands_sh" then
                        shouldHaveShield = true
                    end
                end

                if shouldHaveShield then
                    if not ply:GetNWBool("HasShield", false) then
                        ply:SetNWBool("HasShield", true)
                    end
                else
                    if ply:GetNWBool("HasShield", false) then
                        ply:SetNWBool("HasShield", false)
                        ply.ShieldWasDown = false
                    end
                    
                    -- Если игрок держит двухручку
                    if IsValid(wep) and wep:GetClass() ~= "weapon_hands_sh" then
                        if (ply.NextShieldBlockMsg or 0) < CurTime() then
                            ply:SetNW2Float("shield_block_expire", CurTime() + 4)
                            ply.NextShieldBlockMsg = CurTime() + 2
                        end
                    end
                end

                -- Звуки опускания/поднятия щита (ПКМ)
                if shouldHaveShield and IsValid(wep) and wep.ishgweapon and wep:IsPistolHoldType() then
                    local isAiming = ply:KeyDown(IN_ATTACK2)
                    if isAiming and not ply.ShieldWasDown then
                        ply.ShieldWasDown = true
                        ply:EmitSound("pwb2/weapons/asval/draw.wav", 30, 100)
                    elseif not isAiming and ply.ShieldWasDown then
                        ply.ShieldWasDown = false
                        ply:EmitSound("pwb2/weapons/asval/draw.wav", 30, 90)
                    end
                else
                    ply.ShieldWasDown = false
                end
            else
                if ply:GetNWBool("HasShield", false) then
                    ply:SetNWBool("HasShield", false)
                end
                if ply.ShieldWasDown then ply.ShieldWasDown = false end
            end
        end
    end)

    hook.Add("Think", "ShieldPreciseHitbox_DebugDraw", function()
        if not DEBUG_SHIELD then return end

        for _, ply in ipairs(player.GetAll()) do
            if ply:GetNWBool("HasShield", false) and ply:Alive() then
                local wep = ply:GetActiveWeapon()
                local isPistol = IsValid(wep) and wep.ishgweapon and wep:IsPistolHoldType()
                local isHands = IsValid(wep) and wep:GetClass() == "weapon_hands_sh"
                
                local shieldActive = false
                if isPistol then
                    shieldActive = true
                elseif isHands and wep.GetFists and wep:GetFists() and (not wep.attacked or wep.attacked < CurTime()) then
                    shieldActive = true
                end

                if shieldActive then
                    local ent = IsValid(ply.FakeRagdoll) and ply.FakeRagdoll or ply
                    local chestBone = ent:LookupBone("ValveBiped.Bip01_Spine4")
                    if not chestBone then continue end
                    local chestMat = ent:GetBoneMatrix(chestBone)
                    if not chestMat then continue end
                    local chestPos = chestMat:GetTranslation()
                    local eyeang = ply:EyeAngles()

                    local upPos = chestPos + eyeang:Forward() * 17 + eyeang:Up() * -3 + eyeang:Right() * 2
                    local downPos = chestPos + eyeang:Forward() * 13 - eyeang:Right() * 15 - eyeang:Up() * 5

                    local upAng = Angle(eyeang.p, eyeang.y, eyeang.r)
                    upAng:RotateAroundAxis(eyeang:Forward(), 90)
                    
                    local downAng = Angle(eyeang.p, eyeang.y, eyeang.r)
                    downAng:RotateAroundAxis(eyeang:Right(), -90)
                    downAng:RotateAroundAxis(eyeang:Forward(), 90)

                    local bonePos, boneAng

                    if isHands then
                        local bashPush = 0
                        if wep.shieldBashTime and wep.shieldBashTime > CurTime() then
                            local progress = 1 - math.Clamp((wep.shieldBashTime - CurTime()) / 0.5, 0, 1)
                            bashPush = math.sin(progress) * 6
                        end
                        bonePos = chestPos + eyeang:Forward() * (17 + bashPush) + eyeang:Up() * -3 + eyeang:Right() * 2
                        boneAng = upAng
                    else
                        local lerpVal = math.ease.InOutSine(ply.sv_shield_lerp or 1)
                        bonePos = LerpVector(lerpVal, downPos, upPos)
                        boneAng = LerpAngle(lerpVal, downAng, upAng)
                    end

                    local visOffsetPos = Vector(2, 4, -1)
                    local visOffsetAng = Angle(90, 0, 0)
                    local shieldPos, shieldAng = LocalToWorld(visOffsetPos, visOffsetAng, bonePos, boneAng)
                    
                    debugoverlay.BoxAngles(shieldPos, shieldMins, shieldMaxs, shieldAng, 0.1, Color(0, 255, 0, 0))
                    debugoverlay.Axis(shieldPos, shieldAng, 15, 0.1, true)
                end
            end
        end
    end)

    concommand.Add("hg_drop_shield", function(ply)
        if not IsValid(ply) then return end
        DropShieldEntity(ply)
    end)

end

    hook.Add("Think", "ShieldHookPrimaryAttack", function()
        local base = weapons.GetStored("homigrad_base")
        if not base or not base.PrimaryAttack then return end

        -- Восстанавливаем оригинал при горячей перезагрузке
        if base.OrgPrimaryAttack then
            base.PrimaryAttack = base.OrgPrimaryAttack
            base.OrgPrimaryAttack = nil
        end

        base.OrgPrimaryAttack = base.PrimaryAttack
        base.PrimaryAttack = function(self, broadcast)
            local ply = self:GetOwner()
            local hasShield = IsValid(ply) and ply.GetNWBool and ply:GetNWBool("HasShield", false)
            local isPistol = self.ishgweapon and self:IsPistolHoldType()
            
            -- Если щит есть, оружие пистолет, а ПКМ не зажата -> отменяем выстрел полностью
            if hasShield and isPistol then
                if not ply:KeyDown(IN_ATTACK2) then
                    return false
                end
            end
            
            -- В остальных случаях стреляем нормально
            return base.OrgPrimaryAttack(self, broadcast)
        end
        hook.Remove("Think", "ShieldHookPrimaryAttack")
    end)



hook.Add("IKPoleLeftArm", "ShieldLeftArmPole", function(ply, ent, pos, segments)
    if IsValid(ply) and ply:GetNWBool("HasShield", false) then
        local wep = ply:GetActiveWeapon()
        if IsValid(wep) and (wep.ishgweapon and wep:IsPistolHoldType() or wep:GetClass() == "weapon_hands_sh") then
            local spineBone = ent:LookupBone("ValveBiped.Bip01_Spine4")
            if spineBone then
                local spinePos = ent:GetBoneMatrix(spineBone):GetTranslation()
                local eyeang = ply:EyeAngles()
                
                -- Подтягиваем полюс левого локтя вперед
                return spinePos + eyeang:Forward() * 30 + eyeang:Up() * -0 + eyeang:Right() * -50
            end
        end
    end
end)

-- ДОБАВЛЯЕМ ПРАВЫЙ ЛОКОТЬ (Чтобы правое предплечье тоже сгибалось к кисти)
hook.Add("IKPoleRightArm", "ShieldRightArmPole", function(ply, ent, pos, segments)
    if IsValid(ply) and ply:GetNWBool("HasShield", false) then
        local wep = ply:GetActiveWeapon()
        if IsValid(wep) and (wep.ishgweapon and wep:IsPistolHoldType() or wep:GetClass() == "weapon_hands_sh") then
            local spineBone = ent:LookupBone("ValveBiped.Bip01_Spine4")
            if spineBone then
                local spinePos = ent:GetBoneMatrix(spineBone):GetTranslation()
                local eyeang = ply:EyeAngles()
                
                -- Подтягиваем полюс правого локтя вперед
                return spinePos + eyeang:Forward() * 30 + eyeang:Up() * -0 + eyeang:Right() * 50
            end
        end
    end
end)

hook.Add("Think", "ShieldHookHomigradBase", function()
    local base = weapons.GetStored("homigrad_base")
    if not base or not base.SetHandPos then return end

    if base.OrgSetHandPos then
        base.SetHandPos = base.OrgSetHandPos
        base.OrgSetHandPos = nil
    end

    base.OrgSetHandPos = base.SetHandPos
    base.SetHandPos = function(self, noset)
        local ply = self:GetOwner()
        local hasShield = IsValid(ply) and ply.GetNWBool and ply:GetNWBool("HasShield", false)
        local isPistol = self.ishgweapon and self:IsPistolHoldType()
        
        if hasShield and isPistol then
            self.OrgSetLHIK = self.OrgSetLHIK or self.setlhik
            self.setlhik = true
        end
        
        old_SetHandPos = base.OrgSetHandPos
        old_SetHandPos(self, noset)
        
        if hasShield and isPistol then
            local ent = IsValid(ply.FakeRagdoll) and ply.FakeRagdoll or ply
            local eyeang = ply:EyeAngles()
            
            local lh = ent:LookupBone("ValveBiped.Bip01_L_Hand")
            if lh then
                local chestBone = ent:LookupBone("ValveBiped.Bip01_Spine4")
                if chestBone then
                    local chestPos = ent:GetBoneMatrix(chestBone):GetTranslation()
                    
                    local shield_up = not ply:GetNW2Bool("ShieldLowered", false)
                    ply.shield_lerp = ply.shield_lerp or 0
                    ply.shield_lerp = math.Approach(ply.shield_lerp, shield_up and 1 or 0, FrameTime() * 0.4)
                    local lerp = math.ease.InOutSine(ply.shield_lerp)
                    
                    local upPos = chestPos + eyeang:Forward() * 17 + eyeang:Up() * -3 + eyeang:Right() * 2
                    local downPos = chestPos + eyeang:Forward() * 13 - eyeang:Right() * 15 - eyeang:Up() * 5
                    local targetPos = LerpVector(lerp, downPos, upPos)
                    
                    local handAng = Angle(0, 0, 0)
                    handAng:RotateAroundAxis(eyeang:Forward(), 50)
                    
                    local lhmat = ent:GetBoneMatrix(lh)
                    if lhmat then
                        lhmat:SetTranslation(targetPos)
                        lhmat:SetAngles(handAng)
                        hg.bone_apply_matrix(ent, lh, lhmat)
                        -- Убрано принудительное сохранение в ply.lhold, чтобы не ломать кэш при выключении
                    end
                end
            end
            
            if self.OrgSetLHIK != nil then
                self.setlhik = self.OrgSetLHIK
                self.OrgSetLHIK = nil
            end
        end
    end
    hook.Remove("Think", "ShieldHookHomigradBase")
end)

hook.Add("Think", "ShieldHookHomigradTPIK", function()
    if not hg or not hg.DoTPIK then return end

    if hg.OrgDoTPIK then
        hg.DoTPIK = hg.OrgDoTPIK
        hg.OrgDoTPIK = nil
    end

    hg.OrgDoTPIK = hg.DoTPIK
    hg.DoTPIK = function(ply, ent)
        local applyShieldIK = false
        local targetPos

        if IsValid(ply) and ply:IsPlayer() and ply.GetNWBool and ply:GetNWBool("HasShield", false) then
            local wep = ply:GetActiveWeapon()
            if IsValid(wep) and wep.ishgweapon and wep:IsPistolHoldType() and hg.CanUseLeftHand(ply) then
                local chestBone = ent:LookupBone("ValveBiped.Bip01_Spine4")
                if chestBone then
                    applyShieldIK = true
                    local chestPos = ent:GetBoneMatrix(chestBone):GetTranslation()
                    local eyeang = ply:EyeAngles()
                    
                    -- ИСПРАВЛЕНО: Читаем из сети, а не локальный KeyDown
                    local shield_up = not ply:GetNW2Bool("ShieldLowered", false)
                    ply.shield_lerp = ply.shield_lerp or 0
                    ply.shield_lerp = math.Approach(ply.shield_lerp, shield_up and 1 or 0, FrameTime() * 0.4)
                    local lerp = math.ease.InOutSine(ply.shield_lerp)
                    
                    local upPos = chestPos + eyeang:Forward() * 17 + eyeang:Up() * -3 + eyeang:Right() * 2
                    local downPos = chestPos + eyeang:Forward() * 13 - eyeang:Right() * 15 - eyeang:Up() * 5
                    targetPos = LerpVector(lerp, downPos, upPos)
                    
                    local lh_pre = ent:LookupBone("ValveBiped.Bip01_L_Hand")
                    if lh_pre then
                        local lhmat_pre = ent:GetBoneMatrix(lh_pre)
                        if lhmat_pre then
                            lhmat_pre:SetTranslation(targetPos)
                            hg.bone_apply_matrix(ent, lh_pre, lhmat_pre)
                        end
                    end
                end
            end
        end
        
        hg.OrgDoTPIK(ply, ent)
        
        if applyShieldIK then
            local lh = ent:LookupBone("ValveBiped.Bip01_L_Hand")
            local l_forearm = ent:LookupBone("ValveBiped.Bip01_L_Forearm")
            if lh and l_forearm then
                local lhmat = ent:GetBoneMatrix(lh)
                local fmat = ent:GetBoneMatrix(l_forearm)
                if lhmat and fmat then
                    local currentPos = lhmat:GetTranslation()
                    local handAng = fmat:GetAngles()
                    handAng:RotateAroundAxis(handAng:Forward(), 90)
                    
                    lhmat:SetTranslation(currentPos)
                    lhmat:SetAngles(handAng)
                    hg.bone_apply_matrix(ent, lh, lhmat)
                    hg.set_hold(ent, "normal")
                    
                    ply.shieldRenderPos = lhmat:GetTranslation()
                    ply.shieldRenderAng = lhmat:GetAngles()
                end
            end
        end
    end
    
    hook.Remove("Think", "ShieldHookHomigradTPIK")
end)

hook.Add("Think", "ShieldHookPosAngChanges", function()
    local base = weapons.GetStored("homigrad_base")
    if not base or not base.PosAngChanges then return end

    if base.OrgPosAngChanges then
        base.PosAngChanges = base.OrgPosAngChanges
        base.OrgPosAngChanges = nil
    end

    base.OrgPosAngChanges = base.PosAngChanges
    base.PosAngChanges = function(self, ply, desiredPos, desiredAng, bNoAdditional, closeanim, dtime)
        local pos, ang = base.OrgPosAngChanges(self, ply, desiredPos, desiredAng, bNoAdditional, closeanim, dtime)
        
        local hasShield = IsValid(ply) and ply.GetNWBool and ply:GetNWBool("HasShield", false)
        local isPistol = self.ishgweapon and self:IsPistolHoldType()
        
        if hasShield and isPistol then
            -- ЧИТАЕМ СТАТУС ИЗ СЕТИ
            local shield_up = not ply:GetNW2Bool("ShieldLowered", false)
            ply.shield_rh_lerp = ply.shield_rh_lerp or 0
            ply.shield_rh_lerp = math.Approach(ply.shield_rh_lerp, shield_up and 1 or 0, FrameTime() * 0.5)
            local rh_lerp = math.ease.InOutSine(ply.shield_rh_lerp)
            
            if rh_lerp > 0.01 then
                local eyeang = ply:EyeAngles()
                
                local offsetPos = eyeang:Right() * 6 + eyeang:Forward() * -2 + eyeang:Up() * 2
                pos = pos + offsetPos * rh_lerp
                
                ang:RotateAroundAxis(eyeang:Forward(), 0 * rh_lerp)
                ang:RotateAroundAxis(eyeang:Right(), 45 * rh_lerp)
                ang:RotateAroundAxis(eyeang:Up(), 0 * rh_lerp)
            end
        end
        
        return pos, ang
    end
    hook.Remove("Think", "ShieldHookPosAngChanges")
end)

-- 2. Перехват hg.set_hold (Запрещаем пальцам сжиматься в рукоятку пистолета)
hook.Add("Think", "ShieldHookHomigradHold", function()
    if not hg or not hg.set_hold then return end

    if hg.OrgSetHold then
        hg.set_hold = hg.OrgSetHold
        hg.OrgSetHold = nil
    end

    hg.OrgSetHold = hg.set_hold
    hg.set_hold = function(ent, hold, copyent)
        local ply = hg.RagdollOwner and hg.RagdollOwner(ent) or ent
        if IsValid(ply) and ply:IsPlayer() and ply.GetNWBool and ply:GetNWBool("HasShield", false) then
            local wep = ply:GetActiveWeapon()
            if IsValid(wep) and wep.ishgweapon and wep:IsPistolHoldType() then
                hold = "normal"
            end
        end
        return hg.OrgSetHold(ent, hold, copyent)
    end
    hook.Remove("Think", "ShieldHookHomigradHold")
end)

hook.Add("Think", "ShieldHookHomigradTPIK", function()
    if not hg or not hg.DoTPIK then return end

    if hg.OrgDoTPIK then
        hg.DoTPIK = hg.OrgDoTPIK
        hg.OrgDoTPIK = nil
    end

    hg.OrgDoTPIK = hg.DoTPIK
    hg.DoTPIK = function(ply, ent)
        local applyShieldIK = false
        local targetPos

        if IsValid(ply) and ply:IsPlayer() and ply.GetNWBool and ply:GetNWBool("HasShield", false) then
            local wep = ply:GetActiveWeapon()
            if IsValid(wep) and wep.ishgweapon and wep:IsPistolHoldType() and hg.CanUseLeftHand(ply) then
                local chestBone = ent:LookupBone("ValveBiped.Bip01_Spine4")
                if chestBone then
                    applyShieldIK = true
                    local chestPos = ent:GetBoneMatrix(chestBone):GetTranslation()
                    local eyeang = ply:EyeAngles()
                    
                    local shield_up = not ply:KeyDown(IN_ATTACK2)
                    ply.shield_lerp = ply.shield_lerp or 0
                    ply.shield_lerp = math.Approach(ply.shield_lerp, shield_up and 1 or 0, FrameTime() * 0.4)
                    local lerp = math.ease.InOutSine(ply.shield_lerp)
                    
                    local upPos = chestPos + eyeang:Forward() * 17 + eyeang:Up() * -3 + eyeang:Right() * 2
                    local downPos = chestPos + eyeang:Forward() * 13 - eyeang:Right() * 15 - eyeang:Up() * 5
                    targetPos = LerpVector(lerp, downPos, upPos)
                    
                    -- ИСПРАВЛЕНО: Задаем цель для IK ДО того, как солвер начнет считать руку
                    local lh_pre = ent:LookupBone("ValveBiped.Bip01_L_Hand")
                    if lh_pre then
                        local lhmat_pre = ent:GetBoneMatrix(lh_pre)
                        if lhmat_pre then
                            lhmat_pre:SetTranslation(targetPos)
                            hg.bone_apply_matrix(ent, lh_pre, lhmat_pre)
                        end
                    end
                end
            end
        end
        
        -- Запускаем оригинальный IK солвер Homigrad. Он сам правильно согнет предплечье.
        hg.OrgDoTPIK(ply, ent)
        
        if applyShieldIK then
            local lh = ent:LookupBone("ValveBiped.Bip01_L_Hand")
            local l_forearm = ent:LookupBone("ValveBiped.Bip01_L_Forearm")
            if lh and l_forearm then
                local lhmat = ent:GetBoneMatrix(lh)
                local fmat = ent:GetBoneMatrix(l_forearm)
                if lhmat and fmat then
                    -- ИСПРАВЛЕНО: Не двигаем позицию кисти после IK! Берем позицию, которую рассчитал IK
                    local currentPos = lhmat:GetTranslation()
                    
                    -- Применяем только угол хвата, чтобы рука держала щит
                    local handAng = fmat:GetAngles()
                    handAng:RotateAroundAxis(handAng:Forward(), 90)
                    
                    lhmat:SetTranslation(currentPos)
                    lhmat:SetAngles(handAng)
                    hg.bone_apply_matrix(ent, lh, lhmat)
                    hg.set_hold(ent, "normal")
                    
                    ply.shieldRenderPos = lhmat:GetTranslation()
                    ply.shieldRenderAng = lhmat:GetAngles()
                end
            end
        end
    end
    
    hook.Remove("Think", "ShieldHookHomigradTPIK")
end)

hook.Add("EntityTakeDamage", "ShieldPreciseHitbox", function(target, dmginfo)
    if not SERVER then return end
    if not IsValid(target) then return end

    local ply
    if target:IsPlayer() then
        ply = target
    elseif target:IsRagdoll() then
        ply = target:GetNWEntity("ply")
        if not IsValid(ply) then return end
    else
        return
    end

    if not ply:GetNWBool("HasShield", false) or not ply:Alive() then return end

    local wep = ply:GetActiveWeapon()
    local isPistol = IsValid(wep) and wep.ishgweapon and wep:IsPistolHoldType()
    local isHands = IsValid(wep) and wep:GetClass() == "weapon_hands_sh"
    
    -- Если щит полностью опущен (предмет в руках), хитбокса нет
    if not (isPistol or isHands) or (ply.sv_shield_lerp or 0) < 0.01 then return end

    local ent = target
    local chestBone = ent:LookupBone("ValveBiped.Bip01_Spine4")
    if not chestBone then return end
    local chestMat = ent:GetBoneMatrix(chestBone)
    if not chestMat then return end
    local chestPos = chestMat:GetTranslation()
    local eyeang = ply:EyeAngles()

    local upPos = chestPos + eyeang:Forward() * 17 + eyeang:Up() * -3 + eyeang:Right() * 2
    local downPos = chestPos + eyeang:Forward() * 13 - eyeang:Right() * 15 - eyeang:Up() * 5

    local upAng = Angle(eyeang.p, eyeang.y, eyeang.r)
    upAng:RotateAroundAxis(eyeang:Forward(), 90)
    
    local downAng = Angle(eyeang.p, eyeang.y, eyeang.r)
    downAng:RotateAroundAxis(eyeang:Right(), -90)
    downAng:RotateAroundAxis(eyeang:Forward(), 90)

    local bonePos, boneAng

    if isHands then
        local bashPush = 0
        if wep.shieldBashTime and wep.shieldBashTime > CurTime() then
            local progress = 1 - math.Clamp((wep.shieldBashTime - CurTime()) / 0.5, 0, 1)
            bashPush = math.sin(progress) * 6
        end
        bonePos = chestPos + eyeang:Forward() * (17 + bashPush) + eyeang:Up() * -3 + eyeang:Right() * 2
        boneAng = upAng
    else
        local lerpVal = math.ease.InOutSine(ply.sv_shield_lerp or 1)
        bonePos = LerpVector(lerpVal, downPos, upPos)
        boneAng = LerpAngle(lerpVal, downAng, upAng)
    end

    local visOffsetPos = Vector(2, 4, -1)
    local visOffsetAng = Angle(90, 0, 0)
    local shieldPos, shieldAng = LocalToWorld(visOffsetPos, visOffsetAng, bonePos, boneAng)

    if DEBUG_SHIELD then
        debugoverlay.BoxAngles(shieldPos, shieldMins, shieldMaxs, shieldAng, 0.1, Color(0, 255, 0, 0))
    end

    local dmgForce = dmginfo:GetDamageForce()
    local bulletDir = dmgForce:GetNormalized()
    
    local attacker = dmginfo:GetAttacker()
    local rayStart = IsValid(attacker) and (dmginfo:GetDamagePosition() - bulletDir * 128) or dmginfo:GetDamagePosition()

    local intersectPos, intersectNormal = util.IntersectRayWithOBB(rayStart, bulletDir * 10000, shieldPos, shieldAng, shieldMins, shieldMaxs)

    if intersectPos then
        if DEBUG_SHIELD then
            debugoverlay.Line(rayStart, intersectPos, 5, Color(255, 255, 0), true)
            debugoverlay.Sphere(intersectPos, 2, 5, Color(255, 0, 0, 255), true)
        end

        dmginfo:ScaleDamage(0)

        local effdata = EffectData()
        effdata:SetOrigin(intersectPos)
        effdata:SetNormal(intersectNormal or -bulletDir)
        effdata:SetMagnitude(0.25)
        effdata:SetRadius(4)
        effdata:SetEntity(target)
        effdata:SetSurfaceProp(67)
        effdata:SetDamageType(dmginfo:GetDamageType())
        util.Effect("Impact", effdata)

        sound.Play("physics/metal/metal_solid_impact_bullet" .. math.random(1, 4) .. ".wav", intersectPos, 80, math.random(95, 105))

        if dmginfo:IsDamageType(DMG_BULLET + DMG_BUCKSHOT) and target:IsPlayer() then
            ply:ViewPunch(AngleRand(-1.5, 1.5))
        end

        return true
    end
end)


if CLIENT then
    hook.Add("Think", "CreateShieldModel", function()
        for _, ply in ipairs(player.GetAll()) do
            if not IsValid(ply) or not ply:GetNWBool("HasShield", false) then
                if IsValid(ply.ShieldEnt) then
                    ply.ShieldEnt:Remove()
                    ply.ShieldEnt = nil
                end
                continue
            end

            local wep = ply:GetActiveWeapon()
            local isPistol = IsValid(wep) and wep.ishgweapon and wep:IsPistolHoldType()
            local isHands = IsValid(wep) and wep:GetClass() == "weapon_hands_sh"
            local shouldHaveShield = isPistol or isHands

            -- Удаляем модель щита ТОЛЬКО если в руках не пистолет и не руки (например, бинт)
            if not shouldHaveShield and IsValid(ply.ShieldEnt) then
                ply.ShieldEnt:Remove()
                ply.ShieldEnt = nil
            elseif shouldHaveShield and not IsValid(ply.ShieldEnt) then
                ply.ShieldEnt = ClientsideModel("models/shield/shield_cz.mdl", RENDERGROUP_OPAQUE)
                ply.ShieldEnt:SetNoDraw(true)
            end
            
            if IsValid(ply.ShieldEnt) and ply.ShieldEnt:GetParent() ~= NULL then
                ply.ShieldEnt:SetParent(NULL)
                ply.ShieldEnt:FollowBone(NULL, 0)
            end
        end
    end)

    local debugShield = CreateClientConVar("shield_debug", "0", true, false, "Показывать серверный хитбокс щита")
    
    hook.Add("PostDrawOpaqueRenderables", "DebugShieldHitbox", function(bDepth, bSkybox)
        if bSkybox then return end
        if not debugShield:GetBool() then return end

        for _, ply in ipairs(player.GetAll()) do
            if ply:GetNWBool("HasShield", false) and not ply:KeyDown(IN_ATTACK2) then
                local chestBone = ply:LookupBone("ValveBiped.Bip01_Spine4")
                if chestBone then
                    local mat = ply:GetBoneMatrix(chestBone)
                    if mat then
                        local chestPos = mat:GetTranslation()
                        local eyeang = ply:EyeAngles()
                        local flatAng = Angle(0, eyeang.y, 0)
                        
                        local shieldHandPos = chestPos + flatAng:Forward() * 12 + flatAng:Up() * -4
                        local offsetPos = Vector(10, 0, 0) 
                        local offsetAng = Angle(0, 90, 0)
                        
                        local worldPos, worldAng = LocalToWorld(offsetPos, offsetAng, shieldHandPos, flatAng)
                        
                        render.DrawWireframeBox(worldPos, worldAng, Vector(-25, -10, -35), Vector(25, 10, 35), Color(255, 0, 0))
                    end
                end
            end
        end
    end)
    

    hook.Add("PostDrawOpaqueRenderables", "DrawShieldModel", function(bDepth, bSkybox)
        if bSkybox then return end

        for _, ply in ipairs(player.GetAll()) do
            if not IsValid(ply) or not ply:GetNWBool("HasShield", false) then continue end
            if not IsValid(ply.ShieldEnt) then continue end
            
            -- Если в руках бинт/иное — не рисуем щит
            local wep = ply:GetActiveWeapon()
            local isPistol = IsValid(wep) and wep.ishgweapon and wep:IsPistolHoldType()
            local isHands = IsValid(wep) and wep:GetClass() == "weapon_hands_sh"
            if not (isPistol or isHands) then continue end
            
            local ent = IsValid(ply.FakeRagdoll) and ply.FakeRagdoll or ply
            if not IsValid(ent) then continue end

            local drawPos, drawAng

            -- Берем позицию, которую рассчитал IK
            if ply.shieldRenderPos then
                drawPos = ply.shieldRenderPos
                drawAng = ply.shieldRenderAng
            else
                local bone = ent:LookupBone("ValveBiped.Bip01_L_Hand")
                if bone then
                    local matrix = ent:GetBoneMatrix(bone)
                    if matrix then
                        drawPos = matrix:GetTranslation()
                        drawAng = matrix:GetAngles()
                    end
                end
            end

            if drawPos and drawAng then
                local offsetPos = Vector(-2, 4, -1) 
                local offsetAng = Angle(-60,100 ,-20 )

                local newPos, newAng = LocalToWorld(offsetPos, offsetAng, drawPos, drawAng)
                
                ply.ShieldEnt:SetPos(newPos)
                ply.ShieldEnt:SetAngles(newAng)
                ply.ShieldEnt:SetupBones()
                ply.ShieldEnt:DrawModel()
            end
        end
    end)

    hook.Add("EntityRemoved", "CleanupShield", function(ent)
        if ent:IsPlayer() and IsValid(ent.ShieldEnt) then
            ent.ShieldEnt:Remove()
        end
    end)

    local shield_weapon_block_phrases = {
        "I can't hold this two-handed weapon with my shield...",
        "Need to drop the shield to use this properly.",
        "My hands are full with the shield.",
        "This requires both hands. The shield is in the way.",
        "I can't aim this with a shield in my left hand.",
        "Should I ditch the shield for this heavy weapon?",
        "Too heavy to hold both.",
        "I need a free hand for this weapon.",
        "No way I can hold this and the shield.",
    }

    local nextShieldMsgTime = 0

    hook.Add("Think", "ShieldSendNotification", function()
        local ply = LocalPlayer()
        if not IsValid(ply) or not ply:Alive() then return end

        local expire = ply:GetNW2Float("shield_block_expire", 0)
        local isBlocked = expire > CurTime()

        if isBlocked and CurTime() > nextShieldMsgTime then
            local msg = shield_weapon_block_phrases[math.random(#shield_weapon_block_phrases)]
            
            if ply.Notify then
                ply:Notify(msg, 4, Color(255, 255, 255))
            end
            
            nextShieldMsgTime = CurTime() + 5
        end
    end)

    hook.Add("Think", "ShieldInjectDropButton", function()
        if not IsValid(hg.armorMenuPanel) or not IsValid(hg.armorMenuPanel.scroll) then return end
        
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        
        local inventory = ply:GetNetVar("Inventory", {})
        local hasShield = inventory and inventory["Weapons"] and inventory["Weapons"]["hg_shield"]
        
        if hasShield and not IsValid(hg.armorMenuPanel.ShieldDropButton) then
            local but = vgui.Create("DButton")
            but:SetText("Drop Shield")
            but:SetFont("ZCity_Tiny")
            but:Dock(TOP)
            but:DockMargin(0, 0, 0, 5)
            but:SetSize(0, ScreenScaleH(20))
            
            local mat = Material("homigrad/vgui/gradient_left.png")
            but.Paint = function(self, w, h)
                surface.SetMaterial(mat)
                surface.SetDrawColor(100, 0, 0, 255)
                surface.DrawTexturedRect(0, 0, w, h)
            end

            but.DoClick = function()
                RunConsoleCommand("hg_drop_shield")
                hg.armorMenuPanel:Remove()
            end

            hg.armorMenuPanel.scroll:AddItem(but)
            hg.armorMenuPanel.ShieldDropButton = but
        end
    end)

    hook.Add("Think", "ShieldResetLeftHandIK", function()
        for _, ply in ipairs(player.GetAll()) do
            if not ply:GetNWBool("HasShield", false) then
                -- Если щита нет, но мы его только что выключили
                if ply.shieldIKWasActive then
                    ply.shieldIKWasActive = false
                    
                    -- Очищаем запомненные позиции IK, чтобы рука вернулась в нормальную анимацию
                    ply.lhold = nil
                    ply.last_lh = nil
                    ply.segmentsl = nil
                    ply.lerp_lh = 0 -- Сбрасываем плавность, чтобы рука не пыталась лерпиться к старой позиции
                end
            else
                ply.shieldIKWasActive = true
            end
        end
    end)

    hook.Add("radialOptions", "ShieldDropOption", function()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        
        local inventory = ply:GetNetVar("Inventory", {})
        local hasShield = inventory and inventory["Weapons"] and inventory["Weapons"]["hg_shield"]
        local organism = ply.organism or {}

        if hasShield and not organism.otrub and ply:KeyDown(IN_WALK) then
            local tbl = {function()
                RunConsoleCommand("hg_drop_shield")
            end, "Drop Shield"}
            hg.radialOptions[#hg.radialOptions + 1] = tbl
        end
    end)

    concommand.Add("shield_test_msg", function()
        local ply = LocalPlayer()
        print("[КЛИЕНТ DEBUG] Принудительно включаю сообщение на 5 секунд...")
        ply:SetNW2Float("shield_block_expire", CurTime() + 5)
    end)
end