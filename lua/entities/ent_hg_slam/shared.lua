ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "ent_hg_slam"
ENT.Spawnable = false
ENT.WorldModel = "models/mmod/weapons/w_slam.mdl"

ENT.SoundFar = {"iedins/ied_detonate_dist_01.wav", "ied/ied_detonate_dist_02.wav", "ied/ied_detonate_dist_03.wav"}
ENT.Sound = {"ied/ied_detonate_01.wav", "ied/ied_detonate_02.wav", "ied/ied_detonate_03.wav"}
ENT.SoundWater = "iedins/water/ied_water_detonate_01.wav"
ENT.BlastDis = 3
ENT.BlastDamage = 70

ENT.offsetPos = Vector(-2.25, 1.38, 0)
ENT.offsetAng = Angle(-90, 180, 0)

function ENT:Think()
    local tr = {}
    local pos, ang = self:GetPos(), self:GetAngles()
    local pos, ang = LocalToWorld(self.offsetPos, self.offsetAng, pos, ang)
    tr.start = pos
    tr.endpos = tr.start + ang:Forward() * 700
    tr.filter = self
    tr.collisiongroup = COLLISION_GROUP_NONE
    local tr = util.TraceLine(tr)

    self.TraceStart = pos
    self.TraceHitPos = tr.HitPos

    if SERVER then
        local beepSnd = math.abs(math.sin(CurTime() * 8))
        self.Played = self.Played or false
        if self.Safety > CurTime() and beepSnd > 0.9 and not self.Played then
            self.Played = true
            self:EmitSound("buttons/button24.wav",60,100 + (25 * (3-(self.Safety - CurTime()))) )
        elseif beepSnd < 0.9 then
            self.Played = false
        end
    end

    if SERVER and tr.Hit and (tr.Entity:GetVelocity():LengthSqr() > 1 or tr.Entity:IsPlayer()) and self.Safety < CurTime() then
        self:ActivateExplosive()
    end

    -- Защита: проверяем не только флаг, но и физическое наличие метода на клиенте
    if CLIENT and not self.HookAdded and self.CreateLaserHook and self:GetNWFloat("Safety",CurTime()) < CurTime() then
        self:CreateLaserHook()
    end

    self:NextThink(CurTime())
    return true
end

-- Переносим всю клиентскую логику сюда для стабильности регистрации
if CLIENT then
    local laserMaterial = CreateMaterial("tripmine_laser_fixed", "UnlitGeneric", {
        ["$basetexture"] = "sprites/laserbeam",
        ["$additive"] = "1",
        ["$vertexcolor"] = "1",
        ["$vertexalpha"] = "1",
        ["$nocull"] = "1",
        ["$brightness"] = "64",
        ["$textureScrollRate"] = "25.6",
    })

    function ENT:CreateLaserHook()
        self.HookAdded = true
        hook.Add("PostDrawOpaqueRenderables", "SlamRender" .. self:EntIndex(), function()
            if not IsValid(self) then return end -- проверка на валидность внутри хука
            if not self.TraceStart or not self.TraceHitPos then return end

            render.SetMaterial(laserMaterial)
            render.DrawBeam(
                self.TraceStart,
                self.TraceHitPos,
                0.35,
                0,
                1,
                Color(255, 55, 52, 64)
            )
        end)
    end

    function ENT:Draw()
        self:DrawModel()
    end

    function ENT:OnRemove()
        -- ФИКС: исправлен регистр букв "SlaMRender" -> "SlamRender", хук теперь успешно удаляется
        hook.Remove("PostDrawOpaqueRenderables", "SlamRender" .. self:EntIndex())
    end
end