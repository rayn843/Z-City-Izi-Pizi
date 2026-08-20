-- sh_vr_weapon_attach.lua
-- Прикрепление world model оружия к контроллерам VRMod (исправленная версия)

AddCSLuaFile()

-- ==================== УТИЛИТЫ VR ====================

-- Проверка, находится ли игрок в VR
local function IsInVR(ply)
    if CLIENT then
        ply = ply or LocalPlayer()
    end
    return IsValid(ply) and vrmod and vrmod.IsPlayerInVR and vrmod.IsPlayerInVR(ply)
end

-- Преобразование локальной позиции руки в мировые координаты
local function GetVRHandWorldPose(ply, bRightHand)
    if not IsInVR(ply) then return nil end

    local localPos, localAng
    if bRightHand then
        localPos, localAng = vrmod.GetRightHandPose(ply)
    else
        localPos, localAng = vrmod.GetLeftHandPose(ply)
    end

    if not localPos or not localAng then return nil end

    -- На сервере vrmod.GetRightHandPose уже возвращает мировые координаты
    if SERVER then
        return localPos, localAng
    end

    -- На клиенте vrmod возвращает координаты относительно центра комнаты (VR origin).
    -- Нам нужно преобразовать их в мировые координаты с помощью VR origin.
    if CLIENT then
        local originPos = vrmod.GetOriginPos()
        local originAng = vrmod.GetOriginAng()
        
        if originPos and originAng then
            local worldPos, worldAng = LocalToWorld(localPos, localAng, originPos, originAng)
            return worldPos, worldAng
        end
    end
    
    return nil
end

-- ==================== VR ТРАНСФОРМ ОРУЖИЯ ====================

local function WorldModel_Transform_VR(self, bNoApply, bNoAdditional, model)
    local owner = self:GetOwner()
    model = model or (self.GetWM and self:GetWM()) or self.worldModel

    if not IsValid(model) and self.CreateWorldModel then
        model = self:CreateWorldModel()
    end
    if not IsValid(model) then return end

    local handPos, handAng = GetVRHandWorldPose(owner, true)
    if not handPos then return end

    local basePos = (self.WorldPos or Vector(13, -0.3, 3.4)) + (self.VR_HandPosOffset or vector_origin)
    local baseAng = (self.WorldAng or Angle(5, 0, 180)) + (self.VR_HandAngOffset or angle_zero)

    local finalPos = basePos + (self.AdditionalPos2 or vector_origin)
    local finalAng = baseAng + (self.AdditionalAng2 or angle_zero)

    finalPos:Add(self.CloseAnimAddVec or vector_origin)
    finalAng:Add(self.CloseAnimAddAng or angle_zero)

    finalPos, finalAng = LocalToWorld(finalPos, finalAng, handPos, handAng)

    if self.ShouldUseFakeModel and self:ShouldUseFakeModel() then
        finalPos, finalAng = LocalToWorld(self.FakePos or vector_origin, self.FakeAng or angle_zero, finalPos, finalAng)
    end

    self.desiredPos, self.desiredAng = finalPos, finalAng
    self.handPos, self.handAng = handPos, handAng

    if not bNoApply then
        if SERVER then
            model:SetPos(finalPos)
            model:SetAngles(finalAng)
        else
            model:SetRenderOrigin(finalPos)
            model:SetRenderAngles(finalAng)
            model:SetPos(finalPos)
            model:SetAngles(finalAng)
        end
        if self.DrawShadow then self:DrawShadow(true) end
    end

    return finalPos, finalAng, handPos, handAng
end

-- ==================== ПЕРЕХВАТ БАЗЫ ОРУЖИЯ ====================

local function SetupVRHooks()
    if not vrmod or not vrmod.IsPlayerInVR then
        timer.Simple(3, SetupVRHooks)
        return
    end

    local meta = weapons.GetStored("weapon_hg_base")
        or weapons.GetStored("homigrad_base")
        or weapons.GetStored("weapon_base")

    if not meta then
        for _, wep in pairs(weapons.GetList()) do
            if wep.WorldModel_Transform and (wep.Base == "weapon_hg_base" or wep.Base == "homigrad_base") then
                meta = wep
                break
            end
        end
    end

    if not meta then
        print("[VR Weapon] База оружия ещё не загружена, повтор через 3 сек...")
        timer.Simple(3, SetupVRHooks)
        return
    end

    if meta.VR_Hooked then return end
    meta.VR_Hooked = true

    meta.WorldModel_Transform_VR = WorldModel_Transform_VR

    local origTransform = meta.WorldModel_Transform
    if not origTransform then
        print("[VR Weapon] ОШИБКА: WorldModel_Transform не найден в базе оружия!")
        return
    end

    meta.WorldModel_Transform = function(self, bNoApply, bNoAdditional, model)
        local owner = self:GetOwner()
        if IsValid(owner) and owner:IsPlayer() and IsInVR(owner) then
            if owner:GetActiveWeapon() == self then
                return self:WorldModel_Transform_VR(bNoApply, bNoAdditional, model)
            end
        end
        return origTransform(self, bNoApply, bNoAdditional, model)
    end

    local origSetHandPos = meta.SetHandPos
    if origSetHandPos then
        meta.SetHandPos = function(self, noset)
            local owner = self:GetOwner()
            if IsValid(owner) and owner:IsPlayer() and IsInVR(owner)
               and self.ShouldUseFakeModel and self:ShouldUseFakeModel() then

                local wm = self:GetWM()
                if not IsValid(wm) then
                    return origSetHandPos(self, noset)
                end

                local lhPos, lhAng = GetVRHandWorldPose(owner, false)
                if not lhPos then
                    return origSetHandPos(self, noset)
                end

                -- Исправление бага с LookupAttachment (возвращает 0, если не найдено, а 0 это true в Lua)
                local lhAttID = wm:LookupAttachment("grip")
                if not lhAttID or lhAttID == 0 then lhAttID = wm:LookupAttachment("foregrip") end
                if not lhAttID or lhAttID == 0 then lhAttID = wm:LookupAttachment("muzzle") end

                local targetPos, targetAng = lhPos, lhAng

                if lhAttID and lhAttID > 0 then
                    local att = wm:GetAttachment(lhAttID)
                    if att then
                        targetPos, targetAng = att.Pos, att.Ang
                    end
                end

                local ent = IsValid(owner.FakeRagdoll) and owner.FakeRagdoll or owner
                local lhBone = ent:LookupBone("ValveBiped.Bip01_L_Hand")
                if not lhBone then
                    return origSetHandPos(self, noset)
                end

                local lhMat = ent:GetBoneMatrix(lhBone)
                if lhMat then
                    lhMat:SetTranslation(targetPos)
                    lhMat:SetAngles(targetAng)
                    if hg and hg.bone_apply_matrix then
                        hg.bone_apply_matrix(ent, lhBone, lhMat)
                    end
                end
                return
            end

            return origSetHandPos(self, noset)
        end
    end

    print("[VR Weapon] Перехват установлен для базы:", tostring(meta.ClassName or meta.Base))
end

hook.Add("InitPostEntity", "VR_Weapon_Attach_Init", function()
    timer.Simple(2, SetupVRHooks)
end)

if CLIENT and IsValid(LocalPlayer()) then
    timer.Simple(2, SetupVRHooks)
end

-- ==================== ХАПТИКА ====================

if CLIENT then
    hook.Add("EntityEmitSound", "VR_Weapon_Haptic_Feedback", function(data)
        if not IsInVR() then return end
        local ent = data.Entity
        if not IsValid(ent) or not ent:IsWeapon() then return end

        local isShootSound = data.Channel == CHAN_WEAPON
            or string.find(data.SoundName or "", "fire")
            or string.find(data.SoundName or "", "shoot")

        if isShootSound then
            local owner = ent:GetOwner()
            if IsValid(owner) and owner == LocalPlayer() then
                local force = ent.Primary and math.Clamp((ent.Primary.Force or 50) / 100, 0.2, 1.0) or 0.5
                if VRMod and VRMod.HapticEffect then
                    VRMod.HapticEffect(force, 0, 1, true)
                elseif vrmod and vrmod.HapticEffect then
                    vrmod.HapticEffect(force, 0, 1, true)
                end
            end
        end
    end)
end

-- ==================== DEBUG ====================

if CLIENT then
    concommand.Add("vr_weapon_debug", function()
        local ply = LocalPlayer()
        local wep = ply:GetActiveWeapon()

        print("========== VR WEAPON DEBUG ==========")
        print("VRMod загружен:", tostring(vrmod ~= nil))
        print("Игрок в VR:", tostring(IsInVR(ply)))

        if IsInVR(ply) then
            local rPos, rAng = vrmod.GetRightHandPose(ply)
            print("Правый контроллер (локальные):", rPos, rAng)
            local wPos, wAng = GetVRHandWorldPose(ply, true)
            print("Правый контроллер (мировые):", wPos, wAng)
        end

        if IsValid(wep) then
            local meta = weapons.GetStored(wep.Base or "")
            print("Оружие:", wep:GetClass())
            print("База:", wep.Base)
            print("VR-хук установлен:", tostring(meta and meta.VR_Hooked or false))
        else
            print("Оружие не найдено")
        end
        print("=====================================")
    end)
end