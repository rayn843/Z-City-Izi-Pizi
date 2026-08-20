AddCSLuaFile()

local surface_hardness = {
    [MAT_METAL] = 1,
    [MAT_COMPUTER] = 0.9,
    [MAT_VENT] = 0.9,
    [MAT_GRATE] = 0.9,
    [MAT_FLESH] = 0.5,
    [MAT_ALIENFLESH] = 0.3,
    [MAT_SAND] = 0.1,
    [MAT_DIRT] = 0.9,
    [74] = 0.1,
    [85] = 0.2,
    [MAT_WOOD] = 0.5,
    [MAT_FOLIAGE] = 0.5,
    [MAT_CONCRETE] = 0.9,
    [MAT_TILE] = 0.8,
    [MAT_SLOSH] = 0.05,
    [MAT_PLASTIC] = 0.3,
    [MAT_GLASS] = 0.6,
}

local effect = {
    [MAT_METAL] = {"metal",1},
    [MAT_COMPUTER] = {"metal",1},
    [MAT_VENT] = {"metal",1},
    [MAT_FLESH] = {"flesh",0.75},
    [MAT_ALIENFLESH] = {"alienflesh",1},
    [MAT_SAND] = {"sand",1},
    [MAT_DIRT] = {"dirt",1},
    [MAT_WOOD] = {"wood",1},
    [MAT_FOLIAGE] = {"grass",1},
    [MAT_CONCRETE] = {"concrete",1},
    [MAT_TILE] = {"concrete",1},
    [MAT_SLOSH] = {"concrete",1},
    [MAT_PLASTIC] = {"concrete",1},
    [MAT_GLASS] = {"glass",1},
}

if SERVER then
    util.AddNetworkString("hg_add_bullethole")
    util.AddNetworkString("hg_bullet_batch") -- Новый канал для батчинга

    hg.bulletholes = hg.bulletholes or {}
    hg.areaportalCache = hg.areaportalCache or {}
    hg.pendingBullets = hg.pendingBullets or {} -- Очередь дырок для отправки

    -- Кэшируем ареапорталы
    local function CacheAreaportals()
        hg.areaportalCache = {}
        for _, ent in ipairs(ents.FindByClass("func_areaportal")) do
            local target = ent:GetInternalVariable("target")
            if target and target ~= "" then
                hg.areaportalCache[target] = hg.areaportalCache[target] or {}
                table.insert(hg.areaportalCache[target], ent)
            end
        end
    end

    -- Отправка дырок пакетами (раз в 0.2 сек)
    timer.Create("hg_flush_bullet_batch", 0.2, 0, function()
        if #hg.pendingBullets == 0 then return end
        net.Start("hg_bullet_batch")
            net.WriteUInt(#hg.pendingBullets, 8)
            for i = 1, #hg.pendingBullets do
                local h = hg.pendingBullets[i]
                net.WriteVector(h[1])
                net.WriteAngle(h[2])
                net.WriteFloat(h[3])
                net.WriteAngle(h[4])
                net.WriteFloat(h[5])
                net.WriteEntity(h[6])
            end
        net.SendPVS(hg.pendingBullets.center or Vector(0,0,0))
        hg.pendingBullets = {}
    end)

    hook.Add("PostCleanupMap", "cleanupholes", function()
        hg.bulletholes = {}
        hg.pendingBullets = {}
        CacheAreaportals()
        SetNetVar("BulletHoles", hg.bulletholes)
    end)
    
    hook.Add("InitPostEntity", "cacheholes_init", CacheAreaportals)
else
    -- Клиент: прием одной дырки (оставлено для совместимости)
    net.Receive("hg_add_bullethole", function()
        hg.bulletholes = hg.bulletholes or {}
        local hitPos2 = net.ReadVector()
        local dir2 = net.ReadAngle()
        local dist = net.ReadFloat()
        local hitNormal2 = net.ReadAngle()
        local size = net.ReadFloat()
        local ent = net.ReadEntity()
        
        table.insert(hg.bulletholes, {hitPos2, dir2, dist, hitNormal2, size, ent})
        if #hg.bulletholes > 160 then table.remove(hg.bulletholes, 1) end
    end)

    -- Клиент: прием батча (пакета дырок)
    net.Receive("hg_bullet_batch", function()
        hg.bulletholes = hg.bulletholes or {}
        local count = net.ReadUInt(8)
        for i = 1, count do
            local hitPos2 = net.ReadVector()
            local dir2 = net.ReadAngle()
            local dist = net.ReadFloat()
            local hitNormal2 = net.ReadAngle()
            local size = net.ReadFloat()
            local ent = net.ReadEntity()
            
            table.insert(hg.bulletholes, {hitPos2, dir2, dist, hitNormal2, size, ent})
            if #hg.bulletholes > 160 then table.remove(hg.bulletholes, 1) end
        end
    end)
end

local bulletHit
local timer, util, math, IsValid, WorldToLocal, Vector, sound, EffectData, game = timer, util, math, IsValid, WorldToLocal, Vector, sound, EffectData, game
local hg_bulletholes = CreateConVar("hg_bulletholes", "0", FCVAR_ARCHIVE + FCVAR_NOTIFY + FCVAR_REPLICATED, "Enable R6S bulletholes feature", 0, 1)

local function callbackBullet(self, tr, dmg, force, bullet, penetration)
    if CLIENT then return end
    if not bullet then return end
    bullet.limit_ricochet = bullet.limit_ricochet or 0
    bullet.penetrated = bullet.penetrated or 0
    if bullet.penetrated > 6 then return end
    if bullet.limit_ricochet > 6 then return end
    if tr.Entity.organism then return end
    
    local dir, hitNormal, hitPos = tr.Normal, tr.HitNormal, tr.HitPos
    local hardness = surface_hardness[tr.MatType] or 0.5
    local ApproachAngle = -math.deg(math.asin(hitNormal:DotProduct(dir)))
    local MaxRicAngle = 60 * hardness * (bullet.noricochet and 0 or 1)
    
    if ApproachAngle > MaxRicAngle * 1 or tr.Entity:IsVehicle() then
        local Pen = (bullet.Penetration or 5) * 3 or dmg
        local MaxDist = math.min(Pen / hardness * 0.4, 100)
        local Penetrated = false
        local hit
        
        -- ОПТИМИЗАЦИЯ: 1 трейс вместо многих
        local exitTrace = util.TraceLine({
            start = hitPos + dir * MaxDist,
            endpos = hitPos,
            mask = MASK_SHOT
        })

        if exitTrace.Hit and not exitTrace.StartSolid then
            Penetrated = true
            hit = exitTrace
            local actualDist = hitPos:Distance(exitTrace.HitPos)
            bullet.Penetration = bullet.Penetration - Pen * actualDist / MaxDist / 3
        end

        if tr.Entity:IsVehicle() then Penetrated = penetration end

        if Penetrated then
            local exitPos = hit and hit.HitPos or hitPos
            util.Decal("Impact.Concrete", exitPos + dir * 5, exitPos - dir * 15)
            
            -- ОПТИМИЗАЦИЯ: Убран таймер (timer.Simple) для эффектов, чтобы не грузить GC
            if effect[tr.MatType] then
                local effectdata2 = EffectData()
                effectdata2:SetNormal(dir)
                effectdata2:SetStart(hitPos + dir * 15)
                effectdata2:SetMagnitude(1 * effect[tr.MatType][2])
                util.Effect("zippy_impact_" .. effect[tr.MatType][1], effectdata2)
            end

            local filter = {}
            if tr.Entity:IsVehicle() then
                filter = {tr.Entity}
                if tr.Entity.seats then
                    for i, seat in pairs(tr.Entity.seats) do table.insert(filter, seat) end
                end
            end

            local tBullet = {
                Attacker = IsValid(self) and IsValid(self:GetOwner()) and self:GetOwner() or self,
                Damage = dmg * 0.65,
                Force = force / 3,
                Num = 1,
                Tracer = 0,
                TracerName = "nil",
                Dir = dir,
                Spread = vector_origin,
                Src = tr.Entity:IsVehicle() and hitPos or (exitPos + dir),
                Callback = bulletHit,
                DisableLagComp = true,
                Filter = filter,
                Penetration = bullet.Penetration,
                Diameter = bullet.Diameter,
                penetrated = bullet.penetrated + 1,
                dmgtype = bullet.dmgtype or DMG_BULLET,
                NpcShoot = bullet.NpcShoot,
                limit_ricochet = bullet.limit_ricochet + 1,
                noricochet = bullet.noricochet,
                AmmoType = bullet.AmmoType
            }

            self.bullet = tBullet
            self:FireLuaBullets(tBullet)

            if hg_bulletholes:GetBool() then
                local ent = IsValid(tr.Entity) and tr.Entity or Entity(0)
                local entPos, entAng = ent:GetPos(), ent:GetAngles()
                                
                local hitPos2, dir2 = WorldToLocal(hitPos, dir:Angle(), entPos, entAng)
                local _, hitNormal2 = WorldToLocal(hitPos, hitNormal:Angle(), entPos, entAng)
                
                local size = bullet.Diameter / 25.4 * math.Rand(2, 4) * math.Rand(1, (self.NumBullet or 1))
                local dontadd = false
                
                local holeCount = #hg.bulletholes
                local checkLimit = math.max(1, holeCount - 20)
                local threshold = size * 1.414

                for i = holeCount, checkLimit, -1 do
                    if hitPos2:IsEqualTol(hg.bulletholes[i][1], threshold) then
                        dontadd = true
                        break
                    end
                end
                
                if not dontadd then
                    local dist = hitPos:Distance(exitPos)
                    
                    -- Добавляем в очередь на отправку (Батчинг)
                    table.insert(hg.bulletholes, {hitPos2, dir2, dist, hitNormal2, size, ent})
                    table.insert(hg.pendingBullets, {hitPos2, dir2, dist, hitNormal2, size, ent})
                    hg.pendingBullets.center = hitPos -- обновляем центр PVS
                    
                    if hit then
                        local hitPos2_out, dir2_out = WorldToLocal(hit.HitPos, (-dir):Angle(), entPos, entAng)
                        local _, hitNormal2_out = WorldToLocal(hit.HitPos, hit.HitNormal:Angle(), entPos, entAng)
                        
                        table.insert(hg.bulletholes, {hitPos2_out, dir2_out, dist, hitNormal2_out, size, ent})
                        table.insert(hg.pendingBullets, {hitPos2_out, dir2_out, dist, hitNormal2_out, size, ent})
                        
                        if #hg.bulletholes > 160 then
                            table.remove(hg.bulletholes, 1)
                            table.remove(hg.bulletholes, 1)
                        end
                    end

                    if hgIsDoor(ent) then 
                        local name = ent:GetName()
                        if name ~= "" and hg.areaportalCache[name] then
                            for _, enta in ipairs(hg.areaportalCache[name]) do
                                if IsValid(enta) then
                                    -- ОПТИМИЗАЦИЯ: Не удаляем таргет, чтобы портал не ломался
                                    enta:Fire("Open")
                                end
                            end
                        end
                    end
                end
            end

            -- ОПТИМИЗАЦИЯ: Убран 10000-юнитный трейс! Рисуем трассер до упора без проверки столкновений
            local effectdata1 = EffectData()
            effectdata1:SetOrigin(exitPos + dir * 2000) -- Фейковая дистанция для трассера
            effectdata1:SetStart(hitPos + hitNormal)
            effectdata1:SetEntity(self)
            effectdata1:SetMagnitude(2)
            util.Effect("eff_tracer", effectdata1)
        end
    elseif ApproachAngle < MaxRicAngle * 0.7 then
        local rnd = math.random(12)
        if rnd == 8 then rnd = 9 end
        sound.Play("arc9_eft_shared/ricochet/ricochet" .. rnd .. ".ogg", hitPos, 75, math.random(90, 110))
        util.Decal("ManhackCut", tr.HitPos + tr.HitNormal, tr.HitPos - tr.HitNormal)
        local NewVec = dir:Angle()
        NewVec:RotateAroundAxis(hitNormal, 180)
        NewVec = NewVec:Forward()
        local tBullet = {
            Attacker = IsValid(self) and IsValid(self:GetOwner()) and self:GetOwner() or self,
            Damage = (dmg or 1) * .85,
            Force = force / 3,
            Num = 1,
            Tracer = 0,
            TracerName = "nil",
            Dir = -NewVec,
            Spread = vector_origin,
            Src = hitPos + hitNormal,
            Callback = bulletHit,
            DisableLagComp = true,
            Filter = {},
            Penetration = bullet.Penetration,
            Diameter = bullet.Diameter,
            penetrated = bullet.penetrated + 1,
            dmgtype = bullet.dmgtype or DMG_BULLET,
            limit_ricochet = bullet.limit_ricochet + 1,
            noricochet = bullet.noricochet,
            AmmoType = bullet.AmmoType
        }
        
        self.bullet = tBullet
        self:FireLuaBullets(tBullet)
        
        -- ОПТИМИЗАЦИЯ: Убран таймер и 10000-юнитный трейс
        local effectdata1 = EffectData()
        effectdata1:SetOrigin(hitPos + hitNormal + -NewVec * 2000)
        effectdata1:SetStart(hitPos + hitNormal)
        effectdata1:SetEntity(self)
        effectdata1:SetMagnitude(2)
        util.Effect("eff_tracer", effectdata1)
    elseif math.random(2) == 1 then
        if CLIENT then return end
        local effectdata1 = EffectData()
        effectdata1:SetOrigin(hitPos)
        effectdata1:SetNormal(tr.Normal)
        effectdata1:SetStart(tr.HitNormal)
        effectdata1:SetEntity(self)
        effectdata1:SetFlags(2)
        effectdata1:SetMagnitude(4)
        util.Effect("eff_bulletdrop", effectdata1)
    end
end

function SWEP:CallbackBullet(self, tr)
    return callbackBullet(self, tr)
end

local hg_potatopc
local shootDecals, shootDecalRand = {}, 1
for i = 1, 5 do
    local mat = "decals/zcity/powder_impact_" .. i
    table.insert(shootDecals, mat)
    game.AddDecal("Impact.ShootAdd" .. i, mat)
    shootDecalRand = i
end
game.AddDecal("Impact.ShootPowderAdd", "decals/burn01a")

local ipairs, ents = ipairs, ents
local ents_FindInSphere = ents.FindInSphere
local vectorup = Vector(0, 0, 25)
local cosAng = math.cos(math.rad(125))

local function gasInertia(pos, force, dir, self, tr)
    for _, ent in ipairs(ents_FindInSphere(pos, force)) do
        if IsValid(ent) and not ent:IsNPC() and not ent:IsPlayer() then
            local entpos = ent:GetPos()
            local dirToEnt = (entpos - pos):GetNormalized()
            if dir:Dot(dirToEnt) >= cosAng then
                local phys = ent:GetPhysicsObject()
                if IsValid(phys) then
                    if phys:GetMass() > 5 then continue end
                    local dist = pos:Distance(entpos)
                    local falloff = 1.5 - (dist / force)
                    phys:Wake()
                    phys:ApplyForceCenter(( (dirToEnt + dir) * 2 * ((-phys:GetMass() / 1.5) * (force / 5)) + vectorup ) * falloff)
                end
            end
        end
    end
end

local allowedMats = { [MAT_CONCRETE] = true, [MAT_METAL] = true }
bulletHit = function(ply, tr, dmgInfo, bullet, Weapon)
    if CLIENT then return end
    local inflictor = IsValid(ply) and not ply:IsNPC() and ply.GetActiveWeapon and ply:GetActiveWeapon() or dmgInfo:GetInflictor()
    local dmg, force = dmgInfo:GetDamage(), dmgInfo:GetDamage()
    local trPos, trNormal, trStart = tr.HitPos, tr.HitNormal, tr.StartPos
    
    if tr.MatType == MAT_FLESH then
        util.Decal("Impact.Flesh", trPos + trNormal, trPos - trNormal)
    end

    local dist = trStart:DistToSqr(trPos)
    if dist <= 160000 and (math.random(3) == 2 or force >= 35) and tr.Entity:IsWorld() and allowedMats[tr.MatType] then
        util.Decal("Impact.ShootAdd" .. math.random(shootDecalRand), trPos + trNormal, trPos - trNormal)
        util.ScreenShake(trPos, 3, 1, 1, 128)
    end
    
    local penetration, dmgmul
    if tr.Entity:IsVehicle() then
        penetration, dmgmul = hg.VehiclePenetration(tr.Entity, tr, bullet)
        dmgInfo:SetDamage(dmgInfo:GetDamage() * dmgmul)
    end

    if bullet then
        callbackBullet(Weapon or inflictor, tr, dmg, force, bullet, penetration)
    end
end

hg.bulletHit = bulletHit
hg.callbackBullet = callbackBullet

local bullet = {}
local empty = {}
local vecCone = Vector(0, 0, 0)
local cone, att, att2, owner, primary, ang
local math_Rand, math_random = math.Rand, math.random
local gun
function SWEP:GetWeaponEntity()
    return IsValid(self.worldModel) and IsValid(self:GetOwner()) and self.worldModel or self
end

SWEP.attPos = Vector(0, 0, 0)
SWEP.attAng = Angle(0, 0, 0)
local vecZero = Vector(0, 0, 0)
local angZero = Angle(0, 0, 0)
local attTbl = { Pos = vecZero, Ang = angZero }

function SWEP:GetMuzzleAtt(ent, trueAtt, supressorAdd)
    local owner = IsValid(self) and self:GetOwner() or ent:GetOwner() or ent
    gun = ent or self:GetWeaponEntity()
    if not IsValid(gun) then return attTbl end

    if SERVER then 
        if owner:IsNPC() then 
            attTbl.Pos = owner:EyePos()
            attTbl.Ang = owner:GetAimVector():Angle()
            return attTbl 
        end
    end

    local att = gun:GetAttachment(gun:LookupAttachment(self:ShouldUseFakeModel() and self.FakeAttachment or "muzzle"))
    local att = att ~= nil and att or gun:GetAttachment(gun:LookupAttachment("muzzle_flash"))
    local attPos = self.attPos
    local attAng = self.attAng

    if not att then
        local angHuy = gun:GetAngles()
        local posHuy = gun:GetPos()
        angHuy:RotateAroundAxis(angHuy:Forward(), 90)
        local _, angHuy = LocalToWorld(vecZero, attAng, vecZero, angHuy)
        posHuy:Add(angHuy:Up() * attPos[1] + angHuy:Right() * attPos[2] + angHuy:Forward() * attPos[3])
        if supressorAdd and self:HasAttachment("barrel", "supressor") then posHuy:Add(angHuy:Forward() * 10) end
        if self:ShouldUseFakeModel() then posHuy, angHuy = LocalToWorld(self.AttachmentPos, self.AttachmentAng, posHuy, angHuy) end
        attTbl.Pos = posHuy
        attTbl.Ang = angHuy
        return attTbl
    end
    
    if trueAtt then
        local pos, ang = att.Pos, att.Ang
        local pos, ang = LocalToWorld(attPos, attAng, pos, ang)
        att.Pos = pos
        att.Ang = ang
        ang:RotateAroundAxis(ang:Forward(), self.rotatehuy or 0)
        if self:ShouldUseFakeModel() then pos, ang = LocalToWorld(self.AttachmentPos, self.AttachmentAng, pos, ang) end
        if supressorAdd and self:HasAttachment("barrel", "supressor") then pos:Add(ang:Forward() * 10) end
    end

    if self:ShouldUseFakeModel() then att.Pos, att.Ang = LocalToWorld(self.AttachmentPos, self.AttachmentAng, att.Pos, att.Ang) end
    return att
end

local tr = {}
local att
local util_TraceLine = util.TraceLine

function SWEP:GetTrace(bCacheTrace, desiredPos, desiredAng, NoTrace, closeanim)
    if SERVER and !bCacheTrace and self.cache_trace and !(desiredPos or desiredAng) then return self.cache_trace[1], self.cache_trace[2], self.cache_trace[3] end
    local owner = self:GetOwner()
    
    if IsValid(owner) and owner:IsNPC() then local att = self:GetMuzzleAtt() return nil, SERVER and owner:GetShootPos() or att.Pos, SERVER and owner:GetAimVector():Angle() or att.Ang end
    
    local gun = self:GetWeaponEntity()
    if !IsValid(gun) then return end

    local gunpos, gunang
    if CLIENT and !closeanim then
        gunpos, gunang = self.desiredPos, self.desiredAng
    else
        gunpos, gunang = self:WorldModel_Transform(true)
    end
    
    gunpos = gunpos or gun:GetPos()
    gunang = gunang or gun:GetAngles()

    if CLIENT and self:ShouldUseFakeModel() then
        local mat = Matrix()
        mat:SetTranslation(self.FakePos)
        mat:SetAngles(self.FakeAng)
        mat = mat:GetInverse()
        gunpos, gunang = LocalToWorld(mat:GetTranslation(), mat:GetAngles(), gunpos, gunang)
    end
    
    local pos, ang = LocalToWorld(self.LocalMuzzlePos, self.LocalMuzzleAng, gunpos, gunang)
    
    if NoTrace then 
        self.cache_trace = self.cache_trace or {} 
        self.cache_trace[2] = pos 
        self.cache_trace[3] = ang
        if !bCacheTrace then return {}, pos, ang else return pos, ang end
    end

    local dir = ang:Forward()
    local fake = CLIENT and owner.FakeRagdoll or nil
    tr.start = pos
    tr.endpos = pos + dir * 8000
    tr.filter = {self, gun, not owner.suiciding and owner or NULL, not owner.suiciding and fake}

    local trace = util_TraceLine(tr)
    if bCacheTrace then
        self.cache_trace = self.cache_trace or {}
        self.cache_trace[1] = trace
        self.cache_trace[2] = pos
        self.cache_trace[3] = ang
    end

    return trace, pos, ang
end

SWEP.ShellEject = "EjectBrass_556"
SWEP.MuzzleEffectType = 1

local images_muzzle = {
    [2] = {"effects/muzzleflash1", "effects/muzzleflash2", "effects/muzzleflash3", "effects/muzzleflash4"},
    [3] = {"effects/gunshipmuzzle", "effects/combinemuzzle2"}
}
local vecZero = Vector(0, 0, 0)
local image_distort = "sprites/heatwave"

SWEP.PPSMuzzleEffect = "pcf_jack_mf_mpistol"
SWEP.PPSMuzzleEffectSuppress = "pcf_jack_mf_suppressed"

function SWEP:GetLocalHuynyis()
    local gun = self:GetWeaponEntity()
    local owner = self:GetOwner()
    local atth = gun:GetAttachment(gun:LookupAttachment("muzzle"))
    local atth = atth ~= nil and atth or gun:GetAttachment(gun:LookupAttachment("muzzle_flash"))
    
    local att2 = self:GetMuzzleAtt(gun, false)
    local muzzle_local_pos, muzzle_local_ang = WorldToLocal(att2.Pos, att2.Ang, gun:GetPos(), gun:GetAngles())
    if atth then
        muzzle_local_pos, muzzle_local_ang = LocalToWorld(self.attPos, self.attAng, muzzle_local_pos, muzzle_local_ang)
    end
    if not IsValid(owner.FakeRagdoll) then
        muzzle_local_ang:RotateAroundAxis(muzzle_local_ang:Up(), -(self.rotatehuy or 0))
    end
    return muzzle_local_pos, muzzle_local_ang
end

function SWEP:GetRealDebilAttachment(muzzle_local_pos, muzzle_local_ang)
    -- ОПТИМИЗАЦИЯ: Исправлен баг с переменной owner
    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    local gun = self:GetWeaponEntity()
    local eyeang = owner:GetAimVector():Angle()
    eyeang[3] = eyeang[3] + (owner:EyeAngles()[3])
    local eyeang = eyeang + (self.weaponAngLerp or angZero)
    local _, ang2 = LocalToWorld(vector_origin, muzzle_local_ang, vector_origin, eyeang)
    local pos, ang = LocalToWorld(muzzle_local_pos, muzzle_local_ang, gun:GetPos(), gun:GetAngles())
    local angh = (owner.suiciding or IsValid(owner.FakeRagdoll)) and ang or ang2
    return pos, angh
end

function SWEP:FireBullet()
    local gun = self:GetWeaponEntity()
    local owner = self:GetOwner()
    local isply = IsValid(owner) and owner:IsPlayer()
    local isnpc = IsValid(owner) and owner:IsNPC()
    local ent = owner

    if self:ShouldUseFakeModel() and not self.NoIdleLoop and isply then
        self:PlayAnim("idle", 1)
    end

    if isply then ent = hg.GetCurrentCharacter(owner) end

    local ammotype = hg.ammotypeshuy[self.Primary.Ammo].BulletSettings
    
    if SERVER and !timer.Exists("ShootWeaponAfterDeath" .. self:EntIndex()) then
        timer.Create("ShootWeaponAfterDeath" .. self:EntIndex(), 0.1, 1, function()
            if (!IsValid(owner) or !owner:Alive()) and self.Primary and self.Primary.Automatic then
                self:PrimaryAttack()
            end
        end)
    end

    local att = self:GetMuzzleAtt(gun, true)
    if not att then return end
    local pos, ang = att.Pos, att.Ang
    local fakeGun = self:GetNWEntity("fakeGun")
    local primary = self.Primary

    if isply then owner:LagCompensation(true) end
    self:WorldModel_Transform()
    local tr, pos, ang = self:GetTrace(true)
    if isply then owner:LagCompensation(false) end

    local trace
    local dir = ang:Forward()
    if isply then
        local dist, point = util.DistanceToLine(pos, pos - dir * 50, owner:EyePos())
        local trTbl = {}
        trTbl.start = point
        trTbl.endpos = pos
        trTbl.filter = {owner, ent, SERVER and hg.ragdollFake[owner]}
        trace = util_TraceLine(trTbl)
    end

    local numbullet = ammotype.NumBullet or 1

    if not IsValid(owner) then
        local phys = self:GetPhysicsObject()
        if IsValid(phys) then phys:ApplyForceOffset(-dir * self.Primary.Force * 5, pos) end
    else
        local char = hg.GetCurrentCharacter(owner)
        local phys = char:GetPhysicsObjectNum(0)
        if IsValid(phys) then
            phys:ApplyForceCenter(-dir * math.min(self.Primary.Force, 70) * 40 * (self.NumBullet or 1))
        end
    end

    local headpos, headang
    if isply then owner:LagCompensation(true) end

    if IsValid(ent) then
        local head = ent:GetBoneMatrix(ent:LookupBone("ValveBiped.Bip01_Head1"))
        if head then headpos, headang = head:GetTranslation(), head:GetAngles() else headpos, headang = ent:GetPos(), ent:GetAngles() end
    end
    
    if isply then owner:LagCompensation(false) end

    local willsuicide = IsValid(owner) and owner:GetNWFloat("willsuicide", 0) != 0 and owner:GetNWFloat("willsuicide", 0) or ((owner.startsuicide or CurTime()) + 1) or CurTime() + 1
    local suiciding = owner.suiciding
    local willsuicidereal = (suiciding and (willsuicide == 0 or willsuicide < CurTime()))
    if isnpc then suiciding, willsuicidereal = false, false end

    local bulletObj = {}
    bulletObj.Src = (willsuicidereal and headpos or (trace and (trace.HitPos - trace.Normal) or pos))
    bulletObj.Dir = dir
    bulletObj.Attacker = owner
    
    if isnpc and CLIENT then
        local npcYawOffset = math.Remap(owner:GetPoseParameter("aim_yaw"), 0, 1, -60, 60)
        local npcPitchOffset = math.Remap(owner:GetPoseParameter("aim_pitch"), 0, 1, -88, 50)
        bulletObj.Dir = (owner:GetAngles() + AngleRand(-4, 4) + Angle(npcPitchOffset, npcYawOffset, 0)):Forward()
    end

    bulletObj.Force = ammotype.Force and ammotype.Force / 1.5 or primary.Force
    bulletObj.Damage = ammotype.Damage or primary.Damage or 25
    bulletObj.Damage = bulletObj.Damage * (self.Supressor and 0.9 or 1) * (self.DamageMultiplier or 1)
    bulletObj.Spread = (ammotype.Spread or self.Primary.Spread or 0) * 3
    bulletObj.Num = 1
    bulletObj.AmmoType = primary.Ammo
    bulletObj.TracerName = self.Tracer or "nil"
    bulletObj.IgnoreEntity = nil
    bulletObj.Callback = bulletHit

    local filter = {self, self.worldModel}
    if IsValid(owner) and owner.InVehicle and owner:InVehicle() then
        local veh = owner:GetVehicle()
        table.insert(filter, veh)
        table.insert(filter, veh:GetParent())
        if veh.seats then
            for i, seat in pairs(veh.seats) do table.insert(filter, seat) end
        end
    end

    bulletObj.Speed = ammotype.Speed
    bulletObj.Distance = ammotype.Distance or 56756
    bulletObj.Filter = filter
    bulletObj.noricochet = ammotype.noricochet
    
    local f1 = not owner.suiciding and owner or nil
    local f2 = owner:IsPlayer() and owner:InVehicle() and owner:GetVehicle() or nil
    local f3 = owner:IsPlayer() and owner.GetSimfphys and IsValid(owner:GetSimfphys()) and owner:GetSimfphys() or nil
    local f4 = owner:IsPlayer() and owner:InVehicle() and owner.FakeRagdoll
    local f5 = IsValid(owner.OldRagdoll) and owner.OldRagdoll or nil
    
    -- ОПТИМИЗАЦИЯ: Вставляем в конец массива (O(1) вместо O(N))
    if IsValid(f1) then table.insert(bulletObj.Filter, f1) end
    if IsValid(f2) then table.insert(bulletObj.Filter, f2) end
    if IsValid(f3) then table.insert(bulletObj.Filter, f3) end
    if IsValid(f4) then table.insert(bulletObj.Filter, f4) end
    if IsValid(f5) then table.insert(bulletObj.Filter, f5) end

    bulletObj.Inflictor = self
    bulletObj.DontUsePhysBullets = self.DontUsePhysBullets
    if isnpc then bulletObj.IgnoreEntity = owner end
    
    for i = 1, numbullet do
        -- ОПТИМИЗАЦИЯ: Меньше垃圾 для GC (создаем таблицу напрямую)
        local bCopy = {
            penetrated = 0,
            MaxPenLen = 100,
            Penetration = (ammotype.Penetration or (-(-self.Penetration))) * (self.PenetrationMultiplier or 1),
            Diameter = ammotype.Diameter or 1,
            Src = bulletObj.Src,
            Dir = bulletObj.Dir,
            Attacker = bulletObj.Attacker,
            Force = bulletObj.Force,
            Damage = bulletObj.Damage,
            Spread = bulletObj.Spread,
            Num = bulletObj.Num,
            AmmoType = bulletObj.AmmoType,
            TracerName = bulletObj.TracerName,
            IgnoreEntity = bulletObj.IgnoreEntity,
            Callback = bulletObj.Callback,
            Speed = bulletObj.Speed,
            Distance = bulletObj.Distance,
            Filter = bulletObj.Filter,
            noricochet = bulletObj.noricochet,
            Inflictor = bulletObj.Inflictor,
            DontUsePhysBullets = bulletObj.DontUsePhysBullets
        }

        if SERVER and owner.suiciding and willsuicidereal then
            local dmginfo = DamageInfo()
            dmginfo:SetDamage(bCopy.Damage)
            dmginfo:SetInflictor(self)
            dmginfo:SetAttacker(owner)
            dmginfo:SetDamageType(DMG_BULLET)
            dmginfo:SetDamageForce(dir * bCopy.Force)
            dmginfo:SetDamagePosition(headpos)
            ent:TakeDamageInfo(dmginfo)
        end

        if (hg.PhysBullet and self.UsePhysBullets) then
            if (SERVER) then hg.PhysBullet.CreateBullet(bCopy) end
        else
            self:FireLuaBullets(bCopy)
            if CLIENT and !GetGlobalBool("PhysBullets_ReplaceDefault") then					
                if tr then
                    local effectdata1 = EffectData()
                    if tr.HitPos then effectdata1:SetOrigin(tr.HitPos) end
                    if tr.StartPos then effectdata1:SetStart(pos) end
                    effectdata1:SetEntity(self)
                    effectdata1:SetMagnitude(1)
                    util.Effect("eff_tracer", effectdata1)
                end
            end
        end
    end

    if CLIENT then
        local mul = self.MuzzleMul or 1
        mul = mul * (self.Supressor and 0.25 or 1)
        if mul > 0 then
            if not self.Supressor then 
                ParticleEffect(self.PPSMuzzleEffect, pos, ang, self)
            else
                ParticleEffect(self.PPSMuzzleEffectSuppress, pos, ang, self)
            end
            hg_potatopc = hg_potatopc or hg.ConVars.potatopc
            if not hg_potatopc:GetBool() then
                local dlight = DynamicLight(self:EntIndex())
                dlight.pos = pos
                dlight.r = math_random(245, 255)
                dlight.g = math_random(245, 255)
                dlight.b = math_random(150, 200)
                dlight.brightness = math_Rand(7, 8)
                dlight.Decay = 4000
                dlight.Size = math_Rand(60, 75) * mul
                dlight.DieTime = CurTime() + 1 / 60
            end
        end
    end

    self:PostFireBullet(bulletObj)
end

function SWEP:PostFireBullet()
end

if CLIENT then
    net.Receive("reject shell", function()
        local ent = net.ReadEntity()
        if ent and ent.RejectShell then ent:RejectShell(net.ReadString()) end
    end)

    function SWEP:RejectShell(shell)
        if not shell then return end
        local gun = self:GetWM()
        if not IsValid(gun) then return end
        local attmuzle = self:GetMuzzleAtt(gun, true)
        local att = gun:GetAttachment(gun:LookupAttachment(self.FakeEjectBrassATT or "ejectbrass")) or gun:GetAttachment(gun:LookupAttachment("shell"))
        local pos, ang
        if not att then pos, ang = gun:GetPos(), gun:GetAngles() else pos, ang = att.Pos, att.Ang end
        local _
        if self.EjectPos then pos = gun:GetPos() + ang:Right() * self.EjectPos.x + ang:Up() * self.EjectPos.z + ang:Forward() * self.EjectPos.y end
        if self.EjectAng then _, ang = LocalToWorld(vecZero, self.EjectAng, vecZero, ang) end
        local ammotype = hg.ammotypeshuy[self.Primary.Ammo].BulletSettings
        local ejectAng = attmuzle.Ang
        if self.EjectAddAng then _, ejectAng = LocalToWorld(vecZero, self.EjectAddAng, vecZero, attmuzle.Ang) end
        if self.CustomSecShell then self:MakeShell(self.CustomSecShell, pos, ejectAng, ang:Forward() * 75) end
        if ammotype.Shell or self.CustomShell then self:MakeShell(ammotype.Shell or self.CustomShell, pos, ejectAng, ang:Forward() * 105) return end
        local effectdata = EffectData()
        effectdata:SetOrigin(pos)
        effectdata:SetAngles(ang)
        effectdata:SetFlags(25)
        util.Effect(shell, effectdata)
    end
else
    util.AddNetworkString("reject shell")
    function SWEP:RejectShell(shell)
        net.Start("reject shell")
            net.WriteEntity(self)
            net.WriteString(shell)
        net.Broadcast()
    end
end