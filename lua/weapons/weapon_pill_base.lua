AddCSLuaFile()

SWEP.Base = "weapon_bandage_sh"

SWEP.PrintName = "Pill Base"
SWEP.Instructions = "Base for pills."
SWEP.Category = "ZCity Medicine"

SWEP.Spawnable = false
SWEP.AdminOnly = false

SWEP.Slot = 3
SWEP.SlotPos = 2

SWEP.HoldType = "slam"
SWEP.ViewModel = ""
SWEP.WorldModel = "models/bloocobalt/l4d/items/w_eq_pills.mdl"
SWEP.WorldModelReal = "models/bloocobalt/l4d/items/w_eq_pills.mdl"
SWEP.WorldModelExchange = false


if CLIENT then

SWEP.lpos = Vector(2.5, -2.5, 0)
SWEP.lang = Angle(-30, 20, 180)

function SWEP:DrawWorldModel2()
    local owner = self:GetOwner()

    if not IsValid(self.worldModel) then
        self.worldModel = ClientsideModel(self.WorldModel)
        self.worldModel:SetNoDraw(true)
        self.worldModel:SetSkin(self.WMSkin or 0)

        self:CallOnRemove("remove_pill_worldmodel", function()
            if IsValid(self.worldModel) then
                self.worldModel:Remove()
                self.worldModel = nil
            end
        end)
    end

    self.worldModel:SetNoDraw(true)

    if IsValid(owner) and (not owner.shouldTransmit or owner.NotSeen) then return end
    if not IsValid(owner) and (not self.shouldTransmit or self.NotSeen) then return end

    local WorldModel = self.worldModel

    WorldModel:SetModelScale(self.modelscale2 or 1)

    if WorldModel:GetModel() ~= self.WorldModel then
        WorldModel:SetModel(self.WorldModel)
    end

    local ent = IsValid(owner) and (IsValid(owner.FakeRagdoll) and owner.FakeRagdoll or owner) or nil

    if IsValid(ent) then
        local bone = ent:LookupBone("ValveBiped.Bip01_R_Hand")

        if bone then
            local mat = ent:GetBoneMatrix(bone)

            if mat then
                local posOffset = self.lpos or Vector(4, -0.5, -3)
                local angOffset = self.lang or Angle(-30, 20, 90)

                local pos, ang = LocalToWorld(
                    posOffset,
                    angOffset,
                    mat:GetTranslation(),
                    mat:GetAngles()
                )

                WorldModel:SetRenderOrigin(pos)
                WorldModel:SetRenderAngles(ang)
            end
        else
            WorldModel:SetRenderOrigin(ent:GetPos())
            WorldModel:SetRenderAngles(ent:GetAngles())
        end
    else
        WorldModel:SetRenderOrigin(self:GetPos())
        WorldModel:SetRenderAngles(self:GetAngles())
    end

    WorldModel:SetupBones()
    WorldModel:DrawModel()

    if self.DrawPostWorldModel then
        self:DrawPostWorldModel()
    end
end

end
SWEP.WorkWithFake = true
SWEP.ShouldDeleteOnFullUse = true

SWEP.modes = 1
SWEP.mode = 1

SWEP.modeNames = {
    [1] = "take pill"
}

SWEP.modeValuesdef = {
    [1] = {1, false}
}

SWEP.HoldPos = Vector(0,0,0)
SWEP.HoldAng = Angle(0,0,0)

function SWEP:InitializeAdd()
    self:SetHold(self.HoldType)
    self.modeValues = {
        [1] = 1
    }
end

-- Получить реального игрока-цель из entity, в который попали trace'ом
-- Например: игрок, его FakeRagdoll, ragdoll, entity с organism.owner
function SWEP:GetFeedTarget(ent)
    if not IsValid(ent) then return NULL end

    -- Если напрямую смотрим на игрока
    if ent:IsPlayer() then
        return ent
    end

    -- Если у entity есть organism и у него есть владелец-игрок
    local org = ent.organism
    if org and IsValid(org.owner) and org.owner:IsPlayer() then
        return org.owner
    end

    -- Если это ragdoll и можно получить его владельца
    if ent:IsRagdoll() and hg and hg.RagdollOwner then
        local ply = hg.RagdollOwner(ent)
        if IsValid(ply) and ply:IsPlayer() then
            return ply
        end
    end

    return NULL
end

-- Проверка, лежит ли цель
-- Учитываем обычные ragdoll'ы и fake/otrub состояние из organism
function SWEP:IsTargetLying(ent)
    if not IsValid(ent) then return false end

    -- Если это сам по себе ragdoll — считаем, что цель лежит
    if ent:IsRagdoll() then
        return true
    end

    local ply = self:GetFeedTarget(ent)
    if not IsValid(ply) then return false end

    -- Если у игрока есть активный fake ragdoll
    if IsValid(ply.FakeRagdoll) then
        return true
    end

    if IsValid(ply:GetNWEntity("FakeRagdoll")) then
        return true
    end

    -- Если игрок находится в unconscious/fake состоянии
    local org = ply.organism
    if org and (
        org.fake or
        org.otrub or
        org.needfake or
        org.ownerFake or
        org.needotrub
    ) then
        return true
    end

    return false
end

-- Можно ли вообще использовать таблетку
function SWEP:CanHeal(ent)
    if not SERVER then return false end

    local owner = self:GetOwner()
    if not IsValid(owner) or not owner:Alive() or not owner.organism then
        return false
    end

    if not IsValid(ent) then
        ent = owner
    end

    if not self.modeValues or (self.modeValues[1] or 0) <= 0 then
        return false
    end

    local target = self:GetFeedTarget(ent)

    if not IsValid(target) then return false end
    if not target.organism then return false end

    -- Самому себе через RMB не даём.
    -- Но если ent == owner, то это обычное использование через LMB.
    if target == owner then
        return IsValid(ent) and ent == owner
    end

    -- Для другого игрока требуем, чтобы он лежал
    return self:IsTargetLying(ent) or self:IsTargetLying(target)
end

-- Правая кнопка мыши: скормить таблетку другому лежащему игроку
function SWEP:SecondaryAttack()
    if not SERVER then return end

    if IsValid(self:GetNWEntity("fakeGun")) then return end

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    local tr = hg.eyeTrace(owner)
    local ent = tr and tr.Entity

    self.healbuddy = ent

    if not IsValid(ent) then return end

    local target = self:GetFeedTarget(ent)

    -- Запрещаем кормить самого себя через RMB
    if not IsValid(target) or target == owner then return end

    if not self:CanHeal(ent) then return end

    local done = self:Heal(ent, self.mode)

    if done then
        if self.PostHeal then
            self:PostHeal(target, self.mode)
        end

        if (self.net_cooldown2 or 0) < CurTime() then
            self:SetNetVar("modeValues", self.modeValues)
            -- self.net_cooldown2 = CurTime() + 0.1
        end
    end
end

-- Основная логика применения таблетки
-- ent может быть самим игроком, его ragdoll'ом или FakeRagdoll'ом
function SWEP:Heal(ent, mode)
    if not SERVER then return false end

    local owner = self:GetOwner()
    if not IsValid(owner) or not owner.organism then return false end

    if not IsValid(ent) then
        ent = owner
    end

    if not self.modeValues or (self.modeValues[1] or 0) <= 0 then
        return false
    end

    local target = self:GetFeedTarget(ent)

    if not IsValid(target) then return false end
    if not target.organism then return false end

    if not self:CanHeal(ent) then return false end

    -- Конкретная таблетка должна переопределять ApplyPill.
    -- Если ApplyPill вернёт false, таблетка не будет потрачена.
    if self.ApplyPill then
        if self:ApplyPill(target.organism, target) == false then
            return false
        end
    end

    -- Тратим одну дозу
    self.modeValues[1] = math.max((self.modeValues[1] or 1) - 1, 0)

    -- Звук лучше проигрывать на той сущности, в которую реально смотрим
    local sndEnt = IsValid(ent) and ent or target
    sndEnt:EmitSound("snds_jack_gmod/ez_medical/15.wav", 55, math.random(95, 105))

    -- Если таблетки закончились и они должны удалиться
    if self.modeValues[1] <= 0 and self.ShouldDeleteOnFullUse then
        timer.Simple(0.2, function()
            if IsValid(self) then
                if IsValid(owner) and owner:IsPlayer() then
                    owner:SelectWeapon("weapon_hands_sh")
                end

                self:Remove()
            end
        end)
    end

    return true
end

function SWEP:ApplyPill(org, ent)
    -- Переопределяется конкретными таблетками.
end