AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

local BodyModel = "models/props_vehicles/car003b_physics.mdl"
local SeatModel = "models/nova/airboat_seat.mdl"

local BodyMass = 1200
local MaxSpeed = 8000

local SpringK = 900
local DamperK = 900
local BumpStopK = 900
local BumpStopStart = 0.4

local SideGrip = 12.0
local RollingResistance = 1.2
local EngineForce = 6000
local BrakeForce = 1500
local MaxSteerAngle = 35
local SteerSpeed = 66

-- === НАСТРОЙКА ЗВУКОВ ===
local SND_START = "vehicles/junker/jnk_firstgear_rev_loop1.wav"
local SND_STOP  = "vehicles/junker/jnk_stop1.wav"
local SND_IDLE  = "vehicles/junker/jnk_rev_short_loop1.wav"

-- === ПАРАМЕТРЫ МОДУЛЕЙ ===
local EngineMaxHP    = 100   -- HP двигателя
local TankMaxHP      = 30    -- HP бензобака (прочность стенок)
local TankMaxFuel    = 100   -- максимум топлива
local TankLeakRate   = 6     -- сколько топлива в секунду утекает через одну пробоину
local WheelDamagePerBullet = 100  -- сколько урона нужно для полного уничтожения колеса

-- Типы урона, считающиеся взрывными (для подрыва бака)
local ExplosiveDamageMask = DMG_BLAST + DMG_BLAST_SURFACE + DMG_BURN

-- === ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ===
local function pointInBox(p, mins, maxs)
    return p.x >= mins.x and p.x <= maxs.x
       and p.y >= mins.y and p.y <= maxs.y
       and p.z >= mins.z and p.z <= maxs.z
end

local function pointInSphere(p, center, r)
    return p:DistToSqr(center) <= (r * r)
end

local function isExplosiveDamage(dmgType)
    return bit.band(dmgType, ExplosiveDamageMask) ~= 0
end

-- === ОПРЕДЕЛЕНИЕ УДАРА МОЛОТКОМ ===
-- Возвращает true, если урон нанесён оружием weapon_hammer
local HAMMER_CLASS = "weapon_hammer"

local function isHammerAttack(dmginfo)
    -- Вариант 1: inflictor сам является weapon_hammer (стандартный случай для melee)
    local inflictor = dmginfo:GetInflictor()
    if IsValid(inflictor) then
        if inflictor:GetClass() == HAMMER_CLASS then return true end
        -- Если inflictor — игрок, проверяем его активное оружие
        if inflictor:IsPlayer() then
            local wep = inflictor:GetActiveWeapon()
            if IsValid(wep) and wep:GetClass() == HAMMER_CLASS then return true end
        end
    end
    -- Вариант 2: проверяем attacker (нужно, когда inflictor выставлен в world)
    local attacker = dmginfo:GetAttacker()
    if IsValid(attacker) and attacker:IsPlayer() then
        local wep = attacker:GetActiveWeapon()
        if IsValid(wep) and wep:GetClass() == HAMMER_CLASS then return true end
    end
    return false
end

-- Множитель ремонта: 1 ед. урона молотка = N ед. HP ремонта
local HammerRepairMultiplier = 2.0

function ENT:Initialize()
    self:SetModel(BodyModel)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:SetMass(BodyMass)
        phys:SetDamping(0.1, 0.5)
        phys:Wake()
    end

    self:SetNWBool("DbgEnabled", false)
    self:SetNWBool("ModuleDebug", false)  -- показать хитбоксы модулей по умолчанию
    self.CurrentSteer = 0
    self.CustomCar = true  -- флаг для хука урона

    self.Seats = {}
    self.SeatPositions = {
        { pos = Vector(0, 16, -3), ang = Angle(0, 0, 0), isDriver = true },     -- 1: Водитель
        { pos = Vector(0, -16, -3), ang = Angle(0, 0, 0) },                     -- 2: Переднее пассажирское
        { pos = Vector(-35, 16, -3), ang = Angle(0, 0, 0) },                    -- 3: Заднее левое
        { pos = Vector(-35, 0, -3), ang = Angle(0, 0, 0) },                     -- 4: Заднее по центру
        { pos = Vector(-35, -16, -3), ang = Angle(0, 0, 0) },                   -- 5: Заднее правое
        { pos = Vector(-80, 12, 15), ang = Angle(0, 180, 0) },                  -- 6: В багажнике слева (спиной вперед)
        { pos = Vector(-80, -12, 15), ang = Angle(0, 180, 0) }                  -- 7: В багажнике справа (спиной вперед)
    }

    for i, data in ipairs(self.SeatPositions) do
        local seat = ents.Create("prop_vehicle_prisoner_pod")
        if IsValid(seat) then
            seat:SetModel(SeatModel)
            seat:SetPos(self:LocalToWorld(data.pos))
            seat:SetAngles(self:LocalToWorldAngles(data.ang))
            seat:Spawn()
            seat:SetNoDraw(true)
            seat:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
            seat:SetNWEntity("CustomCar", self)
            
            if data.isDriver then
                seat:SetNWBool("IsDriverSeat", true)
                self.Seat = seat -- Сохраняем ссылку на водительское место для старой логики
            end
            
            constraint.Weld(seat, self, 0, 0, 0, true)
            self:DeleteOnRemove(seat)
            table.insert(self.Seats, seat)
        end
    end

    -- === РУЛЬ ===
    self.SteeringWheel = ents.Create("prop_dynamic")
    if IsValid(self.SteeringWheel) then
        self.SteeringWheel:SetModel("models/gantry_crane/crane_wheel.mdl")
        self.SteeringWheel:SetPos(self:LocalToWorld(Vector(18, 16, 12)))
        self.SteeringWheel:SetAngles(self:LocalToWorldAngles(Angle(90, 0, 0)))
        self.SteeringWheel:Spawn()
        self.SteeringWheel:SetSolid(SOLID_NONE)
        self.SteeringWheel:SetMoveType(MOVETYPE_NONE)
        self.SteeringWheel:SetParent(self)
        self:SetNWEntity("SteeringWheel", self.SteeringWheel)
        self:DeleteOnRemove(self.SteeringWheel)
    end

    -- === СОСТОЯНИЕ ДВИГАТЕЛЯ ===
    self.EngineOn = false
    self.EngineSound = nil
    self.CurrentRPM = 0

    -- === СОСТОЯНИЕ МОДУЛЕЙ ===
    self.EngineHP = EngineMaxHP
    self.TankHP = TankMaxHP
    self.Fuel = TankMaxFuel
    self.TankHoles = {}           -- список локальных позиций пробоин бака
    self.lastGasParticle = 0
    self.lastGasDrop = 0
    self.LeakSound = nil

    -- === СОСТОЯНИЕ КОЛЁС ===
    self.WheelDamage = {0, 0, 0, 0}              -- 0..1 для каждого колеса
    self.WheelRestLength = {}                     -- пер-колёсная высота пружины
    for i = 1, 4 do
        self.WheelRestLength[i] = self.RestLength
        self:SetNWFloat("WheelDmg" .. i, 0)
        self:SetNWFloat("WheelRest" .. i, self.RestLength)
    end
    self:SetNWFloat("EngineHP", self.EngineHP)
    self:SetNWFloat("TankHP", self.TankHP)
    self:SetNWFloat("Fuel", self.Fuel)

    self:SetUseType(SIMPLE_USE)
end

function ENT:StartEngine()
    if self.EngineOn then return end
    -- Движок не заведётся, если он убит или нет топлива
    if self.EngineHP <= 0 then return end
    if self.Fuel <= 0 then return end

    self.EngineOn = true

    self:StopSound(SND_START)
    self:StopSound(SND_IDLE)

    self:EmitSound(SND_START, 75, 100, 0.8)
    self:SetNWBool("EngineOn", true)
end


function ENT:StopEngine()
    if not self.EngineOn then return end
    self.EngineOn = false
    self.CurrentRPM = 0

    self:EmitSound(SND_STOP, 75, 100, 0.8)

    self:StopSound(SND_START)
    self:StopSound(SND_IDLE)

    self:SetNWBool("EngineOn", false)
end

function ENT:OnRemove()
    self:StopEngine()

    -- Полная очистка всех звуков
    self:StopSound(SND_START)
    self:StopSound(SND_STOP)
    self:StopSound(SND_IDLE)

    if self.LeakSound then
        self.LeakSound:Stop()
        self.LeakSound = nil
    end

    for _, seat in ipairs(self.Seats or {}) do
        if IsValid(seat) then seat:Remove() end
    end
    if IsValid(self.SteeringWheel) then self.SteeringWheel:Remove() end
end


function ENT:Use(activator)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    
    local closestSeat = nil
    local closestDist = math.huge

    -- Находим ближайшее свободное место к игроку[cite: 3]
    for _, seat in ipairs(self.Seats) do
        if IsValid(seat) and not IsValid(seat:GetDriver()) then
            local dist = activator:GetPos():DistToSqr(seat:GetPos())
            if dist < closestDist then
                closestDist = dist
                closestSeat = seat
            end
        end
    end

    if IsValid(closestSeat) then
        activator:EnterVehicle(closestSeat)
    end
end

-- ====================================================================
-- === ОБРАБОТКА ПОВРЕЖДЕНИЙ ПО МОДУЛЯМ ================================
-- ====================================================================
-- Хук ловит любой урон по машине ИЛИ по её сиденью (бullets попадают в seat
-- через COLLISION_GROUP_IN_VEHICLE). Для сиденья redirected на машину.

hook.Add("EntityTakeDamage", "CustomCar_ModuleDamage", function(target, dmginfo)
    if not IsValid(target) then return end

    -- Определяем, наш ли это объект
    local car
    if target.CustomCar then
        car = target
    elseif target:IsVehicle() and target:GetClass() == "prop_vehicle_prisoner_pod" then
        car = target:GetNWEntity("CustomCar")
        if not IsValid(car) then return end
    else
        return
    end

    -- Уже взорвана — игнор
    if car.Babahnut then return end

    local dmgPos    = dmginfo:GetDamagePosition()
    local dmgType   = dmginfo:GetDamageType()
    local dmgAmount = dmginfo:GetDamage()
    local localPos  = car:WorldToLocal(dmgPos)

    -- Если позиция урона нулевая (бывает при AoE-уроне), ставим центр машины
    if dmgPos:IsZero() then
        localPos = car:OBBCenter()
    end

    -- === МОЛОТОК РЕМОНТИРУЕТ МОДУЛИ ===
    -- Если бьют оружием weapon_hammer — прибавляем HP модулю, а не уменьшаем
    if isHammerAttack(dmginfo) then
        local repaired = car:RepairModule(localPos, dmgAmount, dmginfo)
        if repaired then
            -- Полностью гасим урон по кузову — молоток не должен ломать то, что чинит
            dmginfo:SetDamage(0)
            return true
        end
        -- Если молоток попал не в модуль (в кузов) — пропускаем дальше как обычный удар
    end

    local hitSomething = false


    -- === 1. КОЛЁСА (проверяем первыми — узкая сфера) ===
    for i = 1, 4 do
        if pointInSphere(localPos, car.WheelPositions[i], car.WheelHitRadius) then
            -- Увеличиваем повреждение колеса (dmgAmount / WheelDamagePerBullet = доля урона)
            local newDmg = math.min(1, car.WheelDamage[i] + dmgAmount / WheelDamagePerBullet)
            car.WheelDamage[i] = newDmg

            -- Уменьшаем высоту пружины — эффект сдутой шины (до 70% снижения)
            car.WheelRestLength[i] = car.RestLength * (1 - newDmg * 0.7)

            car:SetNWFloat("WheelDmg" .. i, newDmg)
            car:SetNWFloat("WheelRest" .. i, car.WheelRestLength[i])

            car.LastHitInfo = {
                time = CurTime(),
                text = string.format("[HIT] Wheel %d  -%d HP  (now %d%%)", i, math.Round(dmgAmount), math.Round(newDmg * 100))
            }
            if dmgType == DMG_BULLET then print("[CustomCar] " .. car.LastHitInfo.text) end

            -- Эффект пыли/искры в точке попадания
            local wheelWorld = car:LocalToWorld(car.WheelPositions[i])
            local eff = EffectData()
            eff:SetOrigin(wheelWorld)
            eff:SetNormal(car:GetUp())
            eff:SetMagnitude(2)
            util.Effect("WheelDust", eff)
            -- Если колесо уже подёрто — искры
            if newDmg > 0.4 then
                util.Effect("Sparks", eff)
            end

            hitSomething = true
            break  -- попадание засчитано только в одно колесо
        end
    end

    -- === 2. ДВИГАТЕЛЬ ===
    if not hitSomething and pointInBox(localPos, car.ModuleZones.Engine.mins, car.ModuleZones.Engine.maxs) then
        car.EngineHP = math.max(0, car.EngineHP - dmgAmount)
        car:SetNWFloat("EngineHP", car.EngineHP)

        car.LastHitInfo = {
            time = CurTime(),
            text = string.format("[HIT] Engine  -%d HP  (now %d/%d)", math.Round(dmgAmount), math.Round(car.EngineHP), EngineMaxHP)
        }
        if dmgType == DMG_BULLET then print("[CustomCar] " .. car.LastHitInfo.text) end

        -- Эффект искр из двигателя
        local engineWorld = car:LocalToWorld((car.ModuleZones.Engine.mins + car.ModuleZones.Engine.maxs) * 0.5)
        local eff = EffectData()
        eff:SetOrigin(engineWorld)
        eff:SetNormal(car:GetUp())
        eff:SetMagnitude(3)
        util.Effect("Sparks", eff)
        -- Лёгкий дымок при попадании
        util.Effect("WheelDust", eff)

        -- Если движок убит — глушим
        if car.EngineHP <= 0 and car.EngineOn then
            car:StopEngine()
        end

        hitSomething = true
    end

    -- === 3. БЕНЗОБАК ===
    if not hitSomething and pointInBox(localPos, car.ModuleZones.FuelTank.mins, car.ModuleZones.FuelTank.maxs) then
        car.TankHP = math.max(0, car.TankHP - dmgAmount)
        car:SetNWFloat("TankHP", car.TankHP)

        -- Добавляем пробоину (точку утечки), не больше 5
        if #car.TankHoles < 5 then
            table.insert(car.TankHoles, localPos)
        end

        local isExplosive = isExplosiveDamage(dmgType)
        car.LastHitInfo = {
            time = CurTime(),
            text = string.format("[HIT] Tank  -%d HP  (now %d/%d)  %s%s",
                math.Round(dmgAmount), math.Round(car.TankHP), TankMaxHP,
                isExplosive and "[EXPLOSIVE]" or "",
                (car.Fuel > 0 and isExplosive) and " -> BOOM!" or "")
        }
        if dmgType == DMG_BULLET then print("[CustomCar] " .. car.LastHitInfo.text) end

        -- Эффект искр + пыль
        local tankWorld = car:LocalToWorld(localPos)
        local eff = EffectData()
        eff:SetOrigin(tankWorld)
        eff:SetNormal(-car:GetUp())
        eff:SetMagnitude(2)
        util.Effect("Sparks", eff)

        -- === ВЗРЫВ при взрывном уроне ===
        -- Если тип урона взрывной (граната, огонь, и т.п.) и ещё есть топливо — БУМ!
        if isExplosiveDamage(dmgType) and car.Fuel > 0 and not car.Babahnut then
            car.Babahnut = true

            -- Сила взрыва зависит от количества оставшегося топлива
            -- force 30..80, mass 20..50 (масштабирует радиус и осколки)
            local mass = 20 + (car.Fuel / TankMaxFuel) * 30
            local force = 30

            -- Используем систему взрывов из sv_explosives.lua
            -- timer.Simple(0) чтобы хук завершился до удаления сущности
            timer.Simple(0, function()
                if IsValid(car) then
                    hg.PropExplosion(car, "Fire", force, mass)
                end
            end)
            return  -- взрыв — модули больше не важны
        end

        hitSomething = true
    end

    -- Модули поглощают большую часть урона — кузов получает только 20%
    if hitSomething then
        dmginfo:ScaleDamage(0.2)
    end
end)

-- ====================================================================
-- === ОСНОВНАЯ ФИЗИКА И ОБРАБОТКА МОДУЛЕЙ =============================
-- ====================================================================

function ENT:Think()
    local dt = math.max(FrameTime(), 0.001)
    local phys = self:GetPhysicsObject()
    if not IsValid(phys) then return true end

    -- === СЕРВЕРНЫЙ DEBUG ОВЕРЛЕЙ ===
    -- Виден при включённом developer 1 + vcollide_wireframe 1
    if self:GetNWBool("ModuleDebug", false) then
        self:DrawServerDebugOverlay()
    end

    local bodyAng = self:GetAngles()
    local carUp = bodyAng:Up()
    local carRight = bodyAng:Right()
    local carForward = bodyAng:Forward()

    local throttle = 0
    local steerInput = 0
    local driver = IsValid(self.Seat) and self.Seat:GetDriver() or nil

    if IsValid(driver) then
        if driver:KeyDown(IN_FORWARD) then throttle = 1
        elseif driver:KeyDown(IN_BACK) then throttle = -1 end

        if driver:KeyDown(IN_MOVELEFT) then steerInput = -1
        elseif driver:KeyDown(IN_MOVERIGHT) then steerInput = 1 end

        if not self.EngineOn then self:StartEngine() end
    else
        if self.EngineOn then self:StopEngine() end
    end

    self:SetNWInt("Throttle", throttle)

    self.CurrentSteer = math.Approach(self.CurrentSteer or 0, steerInput * MaxSteerAngle, SteerSpeed * dt)
    self:SetNWFloat("SteerAngle", self.CurrentSteer)

    -- === ВРАЩЕНИЕ РУЛЯ ===
    if IsValid(self.SteeringWheel) then
        self.SteeringWheel:SetLocalAngles(Angle(-self.CurrentSteer, 90, -76))
    end

    -- === УТЕЧКА БЕНЗИНА ===
    self:ProcessFuelLeak(dt)

    -- Если топливо кончилось — глохнет движок
    if self.Fuel <= 0 and self.EngineOn then
        self:StopEngine()
    end

    -- === ОГРАНИЧЕНИЕ СКОРОСТИ ===
    local planarVel = Vector(phys:GetVelocity().x, phys:GetVelocity().y, 0)
    if planarVel:Length() > MaxSpeed then
        phys:SetVelocity(planarVel:GetNormalized() * MaxSpeed + Vector(0, 0, phys:GetVelocity().z))
    end

    local filter = { self, self.SteeringWheel }
    for _, seat in ipairs(self.Seats or {}) do 
        table.insert(filter, seat)
    end

    -- === ЭФФЕКТИВНАЯ СИЛА ДВИГАТЕЛЯ (зависит от HP и топлива) ===
    local effectiveEngineForce = EngineForce * (self.EngineHP / EngineMaxHP)
    -- Если топлива мало — движок "захлёбывается"
    if self.Fuel < 15 then
        effectiveEngineForce = effectiveEngineForce * math.max(0, self.Fuel / 15)
        -- Случайные пропуски зажигания при голодании
        if self.EngineOn and math.random() < 0.1 then
            effectiveEngineForce = effectiveEngineForce * 0.3
        end
    end

    -- === ЦИКЛ ПО КОЛЁСАМ ===
    for i = 1, 4 do
        local isFront = i <= 2
        local anchorLocal = self.WheelPositions[i]
        local anchorWorld = self:LocalToWorld(anchorLocal)

        local wheelForward = carForward
        local wheelRight = carRight
        if isFront then
            local rad = math.rad(self.CurrentSteer)
            wheelForward = carForward * math.cos(rad) + carRight * math.sin(rad)
            wheelRight = carRight * math.cos(rad) - carForward * math.sin(rad)
        end

        -- Пер-колёсная высота пружины (учёт повреждений — эффект сдутой шины)
        local wheelRestLen = self.WheelRestLength[i]
        local wheelDmg = self.WheelDamage[i]

        local tr = util.TraceLine({
            start = anchorWorld,
            endpos = anchorWorld - carUp * (wheelRestLen + self.WheelRadius),
            filter = filter
        })

        if tr.Hit then
            local currentLength = tr.HitPos:Distance(anchorWorld) - self.WheelRadius
            local compression = math.Clamp(wheelRestLen - currentLength, 0, wheelRestLen)

            self:SetNWFloat("Comp" .. i, compression)

            local pointVel = phys:GetVelocityAtPoint(anchorWorld)
            local carVelUp = math.Clamp(pointVel:Dot(carUp), -1, 1)

            -- Эффективные параметры пружины (учёт повреждений колеса)
            -- Повреждённое колесо = мягкая пружина (вялая физика)
            local effectiveSpringK   = SpringK   * (1 - wheelDmg * 0.5)
            local effectiveDamperK   = DamperK   * (1 - wheelDmg * 0.3)
            local effectiveBumpStopK = BumpStopK * (1 - wheelDmg * 0.3)

            local springForce = compression * effectiveSpringK
            local bumpForce = (compression > wheelRestLen * BumpStopStart)
                and ((compression - wheelRestLen * BumpStopStart) * effectiveBumpStopK) or 0
            local damperForce = carVelUp * effectiveDamperK

            local totalForce = math.Clamp(springForce + bumpForce - damperForce, 0, (BodyMass * 600 / 4) * 3)
            phys:ApplyForceOffset(carUp * totalForce, anchorWorld)

            -- Боковое сцепление: у пробитого колеса меньше (заносит на поворотах)
            local effectiveSideGrip = SideGrip * (1 - wheelDmg * 0.7)
            local sideSpeed = pointVel:Dot(wheelRight)
            phys:ApplyForceOffset(-wheelRight * sideSpeed * effectiveSideGrip * (totalForce / 1000), tr.HitPos)

            -- Сопротивление качению: у пробитого колеса выше (тяжело катить сдвинутое колесо)
            local effectiveRolling = RollingResistance * (1 + wheelDmg * 3)
            local forwardSpeed = pointVel:Dot(wheelForward)
            phys:ApplyForceOffset(-wheelForward * forwardSpeed * effectiveRolling * (totalForce / 1000), tr.HitPos)

            -- Привод только на задние колёса
            if not isFront then
                local driveForce = vector_origin
                if throttle > 0 then
                    driveForce = wheelForward * effectiveEngineForce * throttle
                elseif throttle < 0 then
                    driveForce = (forwardSpeed > 50) and (-wheelForward * BrakeForce) or (-wheelForward * effectiveEngineForce * 0.5)
                end
                phys:ApplyForceOffset(driveForce, tr.HitPos)
            elseif throttle < 0 and forwardSpeed > 50 then
                phys:ApplyForceOffset(-wheelForward * BrakeForce, tr.HitPos)
            end
        else
            self:SetNWFloat("Comp" .. i, 0)
        end
    end

    self:NextThink(CurTime())
    return true
end

-- ====================================================================
-- === РЕМОНТ МОДУЛЕЙ МОЛОТКОМ =========================================
-- ====================================================================
-- Вызывается из хука EntityTakeDamage, когда бьют weapon_hammer.
-- Определяет, в какой модуль попали, и прибавляет ему HP.
-- Возвращает true, если ремонт произошёл (тогда хук гасит урон).

function ENT:RepairModule(localPos, dmgAmount, dmginfo)
    if self.Babahnut then return false end

    -- Базовая "величина ремонта" — урон молотка × множитель
    local repairAmount = dmgAmount * HammerRepairMultiplier

    -- Звук ремонта (молоток стучит по металлу)
    self:EmitSound("physics/metal/metal_solid_impact_hard" .. math.random(1, 4) .. ".wav", 75, math.random(95, 110))

    local attacker = IsValid(dmginfo) and dmginfo:GetAttacker() or nil

    -- === 1. КОЛЁСА ===
    for i = 1, 4 do
        if pointInSphere(localPos, self.WheelPositions[i], self.WheelHitRadius) then
            -- Если колесо цело — ремонт не нужен
            if self.WheelDamage[i] <= 0 then
                return true  -- считаем, что попали в модуль (звук играл)
            end

            -- Переводим урон в единицы "повреждения колеса" (0..1)
            local repairFrac = repairAmount / WheelDamagePerBullet
            self.WheelDamage[i] = math.max(0, self.WheelDamage[i] - repairFrac)

            -- Восстанавливаем высоту пружины
            self.WheelRestLength[i] = self.RestLength * (1 - self.WheelDamage[i] * 0.7)

            -- Синхронизируем с клиентом
            self:SetNWFloat("WheelDmg" .. i, self.WheelDamage[i])
            self:SetNWFloat("WheelRest" .. i, self.WheelRestLength[i])

            -- Эффект: зелёные искры (признак ремонта)
            local wheelWorld = self:LocalToWorld(self.WheelPositions[i])
            local eff = EffectData()
            eff:SetOrigin(wheelWorld)
            eff:SetNormal(self:GetUp())
            eff:SetMagnitude(3)
            util.Effect("Sparks", eff)

            return true
        end
    end

    -- === 2. ДВИГАТЕЛЬ ===
    if pointInBox(localPos, self.ModuleZones.Engine.mins, self.ModuleZones.Engine.maxs) then
        if self.EngineHP >= EngineMaxHP then
            return true
        end

        self.EngineHP = math.min(EngineMaxHP, self.EngineHP + repairAmount)
        self:SetNWFloat("EngineHP", self.EngineHP)

        -- Эффект зелёных искр из центра двигателя
        local engineWorld = self:LocalToWorld((self.ModuleZones.Engine.mins + self.ModuleZones.Engine.maxs) * 0.5)
        local eff = EffectData()
        eff:SetOrigin(engineWorld)
        eff:SetNormal(self:GetUp())
        eff:SetMagnitude(4)
        util.Effect("Sparks", eff)

        return true
    end

    -- === 3. БЕНЗОБАК ===
    if pointInBox(localPos, self.ModuleZones.FuelTank.mins, self.ModuleZones.FuelTank.maxs) then
        if self.TankHP >= TankMaxHP then
            return true
        end

        self.TankHP = math.min(TankMaxHP, self.TankHP + repairAmount)
        self:SetNWFloat("TankHP", self.TankHP)

        -- Каждый 4-й удар молотком по баку "заваривает" одну пробоину
        if #self.TankHoles > 0 and (self.lastHoleWeld or 0) < CurTime() then
            self.lastHoleWeld = CurTime() + 0.5
            table.remove(self.TankHoles, 1)
        end

        -- Если пробоин больше нет и бак полностью цел — останавливаем звук утечки
        if #self.TankHoles == 0 and self.LeakSound then
            self.LeakSound:Stop()
            self.LeakSound = nil
        end

        -- Эффект искр
        local tankWorld = self:LocalToWorld((self.ModuleZones.FuelTank.mins + self.ModuleZones.FuelTank.maxs) * 0.5)
        local eff = EffectData()
        eff:SetOrigin(tankWorld)
        eff:SetNormal(self:GetUp())
        eff:SetMagnitude(4)
        util.Effect("Sparks", eff)

        return true
    end

    -- Если попали в кузов, но не в модуль — не чиним, возвращаем false
    return false
end

-- ====================================================================
-- === СЕРВЕРНЫЙ DEBUG ОВЕРЛЕЙ ========================================
-- ====================================================================
-- Рисует боксы через debugoverlay.* (видны при включённом developer 1)
-- Используется для серверной отладки хитбоксов модулей.

function ENT:DrawServerDebugOverlay()
    if not self.ModuleZones then return end

    local pos = self:GetPos()
    local ang = self:GetAngles()

    -- Бокс двигателя (красный)
    local eMin, eMax = self.ModuleZones.Engine.mins, self.ModuleZones.Engine.maxs
    debugoverlay.BoxAngles(pos, eMin, eMax, ang, 0.1, Color(255, 50, 50, 30))

    -- Бокс бензобака (жёлтый)
    local tMin, tMax = self.ModuleZones.FuelTank.mins, self.ModuleZones.FuelTank.maxs
    debugoverlay.BoxAngles(pos, tMin, tMax, ang, 0.1, Color(255, 220, 50, 30))

    -- Сферы вокруг колёс (зелёные), размер = радиус попадания
    for i = 1, 4 do
        local wpos = self:LocalToWorld(self.WheelPositions[i])
        debugoverlay.Sphere(wpos, self.WheelHitRadius, 0.1, Color(50, 255, 50, 30), true)

        -- Если колесо повреждено — оранжевая сфера (визуально выделяем)
        if self.WheelDamage and self.WheelDamage[i] > 0 then
            debugoverlay.Sphere(wpos, self.WheelHitRadius * (1 + self.WheelDamage[i] * 0.5), 0.1, Color(255, 150, 0, 80), true)
        end
    end

    -- Маленькие крестики в центре каждого модуля + текст с HP
    local engineCenter = self:LocalToWorld((eMin + eMax) * 0.5)
    debugoverlay.Cross(engineCenter, 8, 0.1, Color(255, 50, 50), true)
    debugoverlay.Text(engineCenter + Vector(0, 0, 15), "ENGINE HP: " .. math.Round(self.EngineHP or 0) .. "/" .. EngineMaxHP, 0.1, false)

    local tankCenter = self:LocalToWorld((tMin + tMax) * 0.5)
    debugoverlay.Cross(tankCenter, 8, 0.1, Color(255, 220, 50), true)
    debugoverlay.Text(tankCenter + Vector(0, 0, 15),
        "TANK HP: " .. math.Round(self.TankHP or 0) .. "/" .. TankMaxHP ..
        " | FUEL: " .. math.Round(self.Fuel or 0) .. "/" .. TankMaxFuel ..
        " | HOLES: " .. #(self.TankHoles or {}), 0.1, false)

    -- Для каждого колеса — текст с процентом повреждения
    for i = 1, 4 do
        local wpos = self:LocalToWorld(self.WheelPositions[i])
        local dmg = (self.WheelDamage and self.WheelDamage[i]) or 0
        local label = string.format("W%d: %d%%", i, math.Round(dmg * 100))
        debugoverlay.Text(wpos + Vector(0, 0, 15), label, 0.1, false)
    end

    -- Текст последнего попадания (если было)
    if self.LastHitInfo and (CurTime() - (self.LastHitInfo.time or 0)) < 3 then
        debugoverlay.Text(pos + Vector(0, 0, 80), self.LastHitInfo.text, 0.1, false)
    end
end

-- ====================================================================
-- === УТЕЧКА БЕНЗИНА ==================================================
-- ====================================================================
-- Интегрируется с sh_liquidystuff.lua через:
--   * net.Start("gas particle")  — частицы, отрисовываемые input_cl.lua + cl_gasoline.lua
--   * hg.gasolinePath             — следы бензина на земле, которые могут загораться

function ENT:ProcessFuelLeak(dt)
    if self.Fuel <= 0 or #self.TankHoles == 0 then
        if self.LeakSound then
            self.LeakSound:Stop()
            self.LeakSound = nil
        end
        return
    end

    -- Высота уровня топлива в локальных координатах
    -- Бак по Z: mins.z .. maxs.z, уровень = низ + (Fuel/Max) * высота
    local tankMinZ = self.ModuleZones.FuelTank.mins.z
    local tankMaxZ = self.ModuleZones.FuelTank.maxs.z
    local fuelLevelZ = tankMinZ + (self.Fuel / TankMaxFuel) * (tankMaxZ - tankMinZ)

    -- Считаем активные пробоины (те, что ниже уровня топлива — из них течёт)
    local activeHoles = {}
    for _, holeLocalPos in ipairs(self.TankHoles) do
        if holeLocalPos.z < fuelLevelZ then
            table.insert(activeHoles, holeLocalPos)
        end
    end

    if #activeHoles == 0 then
        if self.LeakSound then
            self.LeakSound:Stop()
            self.LeakSound = nil
        end
        return
    end

    -- Уменьшаем топливо пропорционально числу активных пробоин
    self.Fuel = math.max(0, self.Fuel - dt * TankLeakRate * #activeHoles)
    self:SetNWFloat("Fuel", self.Fuel)

    -- Звук утечки
    if not self.LeakSound then
        self.LeakSound = CreateSound(self, "ambient/water/leak_1.wav")
        self.LeakSound:PlayEx(0.4, 90)
    end

    -- Отправляем частицы бензина клиентам (использует систему из input_cl.lua)
    -- Ограничиваем частоту, чтобы не заспамить сеть
    if (self.lastGasParticle or 0) < CurTime() then
        self.lastGasParticle = CurTime() + 0.05

        for _, holeLocalPos in ipairs(activeHoles) do
            local holeWorld = self:LocalToWorld(holeLocalPos)

            -- Небольшое ускорение вниз + случайность + скорость машины
            local vel = self:GetVelocity() + VectorRand(-20, 20) + Vector(0, 0, -20)

            net.Start("gas particle")
                net.WriteVector(holeWorld)
                net.WriteVector(vel)
                net.WriteEntity(self)
            net.Broadcast()
        end
    end

    -- Капаем бензин на землю — добавляем в hg.gasolinePath
    -- Это позволяет бензину загораться от vfire (через систему sh_liquidystuff.lua)
    if (self.lastGasDrop or 0) < CurTime() then
        self.lastGasDrop = CurTime() + 0.2

        for _, holeLocalPos in ipairs(activeHoles) do
            local holeWorld = self:LocalToWorld(holeLocalPos)

            local tr = util.TraceLine({
                start = holeWorld,
                endpos = holeWorld - Vector(0, 0, 256),
                filter = { self, self.Seat, self.SteeringWheel }
            })

            if tr.Hit then
                -- Добавляем точку в общий список бензиновых следов
                -- (sh_liquidystuff.lua синхронизирует это с клиентами и обрабатывает поджог)
                table.insert(hg.gasolinePath, {tr.HitPos, false})

                -- Ограничиваем размер списка, чтобы не разрастался бесконечно
                if #hg.gasolinePath > 200 then
                    table.remove(hg.gasolinePath, 1)
                end
            end
        end
    end
end

-- ====================================================================
-- === КОНСОЛЬНЫЕ КОМАНДЫ ДЛЯ ТЕСТА ====================================
-- ====================================================================
-- Использование: посмотри на машину и введи команду

local function findCar(ply)
    local car = IsValid(ply) and ply:GetEyeTrace().Entity or nil
    if not IsValid(car) or not car.CustomCar then
        if IsValid(ply) then ply:ChatPrint("[CustomCar] Look at a custom car first!") end
        return nil
    end
    return car
end

concommand.Add("cc_damage_engine", function(ply, cmd, args)
    local amount = tonumber(args[1]) or 30
    local car = findCar(ply)
    if not car then return end

    car.EngineHP = math.max(0, car.EngineHP - amount)
    car:SetNWFloat("EngineHP", car.EngineHP)
    if car.EngineHP <= 0 and car.EngineOn then car:StopEngine() end
    ply:ChatPrint("[CustomCar] Engine HP: " .. car.EngineHP .. "/" .. EngineMaxHP)
end)

concommand.Add("cc_damage_wheel", function(ply, cmd, args)
    local idx = math.Clamp(tonumber(args[1]) or 1, 1, 4)
    local amount = tonumber(args[2]) or 50
    local car = findCar(ply)
    if not car then return end

    car.WheelDamage[idx] = math.min(1, car.WheelDamage[idx] + amount / 100)
    car.WheelRestLength[idx] = car.RestLength * (1 - car.WheelDamage[idx] * 0.7)
    car:SetNWFloat("WheelDmg" .. idx, car.WheelDamage[idx])
    car:SetNWFloat("WheelRest" .. idx, car.WheelRestLength[idx])
    ply:ChatPrint("[CustomCar] Wheel " .. idx .. " damage: " .. math.Round(car.WheelDamage[idx] * 100) .. "%")
end)

concommand.Add("cc_damage_tank", function(ply, cmd, args)
    local amount = tonumber(args[1]) or 30
    local car = findCar(ply)
    if not car then return end

    car.TankHP = math.max(0, car.TankHP - amount)
    car:SetNWFloat("TankHP", car.TankHP)

    -- Добавляем пробоину в центре бака
    local z = car.ModuleZones.FuelTank
    local holePos = Vector((z.mins.x + z.maxs.x) * 0.5,
                           (z.mins.y + z.maxs.y) * 0.5,
                           (z.mins.z + z.maxs.z) * 0.5)
    if #car.TankHoles < 5 then
        table.insert(car.TankHoles, holePos)
    end

    ply:ChatPrint("[CustomCar] Tank HP: " .. car.TankHP .. "/" .. TankMaxHP .. ", fuel: " .. math.Round(car.Fuel))
end)

concommand.Add("cc_explode_tank", function(ply, cmd, args)
    local car = findCar(ply)
    if not car then return end
    if car.Babahnut then return end

    car.Babahnut = true
    local mass = 20 + (car.Fuel / TankMaxFuel) * 30
    timer.Simple(0, function()
        if IsValid(car) then
            hg.PropExplosion(car, "Fire", 30, mass)
        end
    end)
    ply:ChatPrint("[CustomCar] BOOM!")
end)

concommand.Add("cc_repair_car", function(ply, cmd, args)
    local car = findCar(ply)
    if not car then return end

    car.EngineHP = EngineMaxHP
    car.TankHP = TankMaxHP
    car.Fuel = TankMaxFuel
    car.TankHoles = {}
    car.Babahnut = false
    car:SetNWFloat("EngineHP", car.EngineHP)
    car:SetNWFloat("TankHP", car.TankHP)
    car:SetNWFloat("Fuel", car.Fuel)

    for i = 1, 4 do
        car.WheelDamage[i] = 0
        car.WheelRestLength[i] = car.RestLength
        car:SetNWFloat("WheelDmg" .. i, 0)
        car:SetNWFloat("WheelRest" .. i, car.RestLength)
    end

    if car.LeakSound then
        car.LeakSound:Stop()
        car.LeakSound = nil
    end

    ply:ChatPrint("[CustomCar] Repaired!")
end)

-- === ВЫДАТЬ МОЛОТОК ДЛЯ ТЕСТА РЕМОНТА ===
concommand.Add("cc_give_hammer", function(ply, cmd, args)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    ply:Give("weapon_hammer")
    ply:ChatPrint("[CustomCar] You got a weapon_hammer. Hit module hitboxes to REPAIR them.")
end)


-- === КОМАНДЫ ДЕБАГА ===

-- Переключатель режима отображения хитбоксов
concommand.Add("cc_debug_toggle", function(ply, cmd, args)
    local car = findCar(ply)
    if not car then return end

    local newState = not car:GetNWBool("ModuleDebug", false)
    car:SetNWBool("ModuleDebug", newState)
    ply:ChatPrint("[CustomCar] Module debug overlay: " .. (newState and "ON" or "OFF"))
end)

-- Распечатать в консоль подробное состояние всех модулей
concommand.Add("cc_debug_status", function(ply, cmd, args)
    local car = findCar(ply)
    if not car then return end

    print("======== CustomCar Modules Status ========")
    print(string.format("Entity: %s (idx %d)", tostring(car), car:EntIndex()))
    print(string.format("Position: %s", tostring(car:GetPos())))
    print(string.format("Babahnut: %s", tostring(car.Babahnut)))
    print("")
    print("-- Engine --")
    print(string.format("  HP:        %d / %d", car.EngineHP, EngineMaxHP))
    print(string.format("  On:        %s", tostring(car.EngineOn)))
    print(string.format("  Eff.Force: %.0f (%.0f%% of base)",
        EngineForce * (car.EngineHP / EngineMaxHP),
        (car.EngineHP / EngineMaxHP) * 100))
    print("")
    print("-- Fuel Tank --")
    print(string.format("  HP:        %d / %d", car.TankHP, TankMaxHP))
    print(string.format("  Fuel:      %.1f / %d", car.Fuel, TankMaxFuel))
    print(string.format("  Holes:     %d", #car.TankHoles))
    for i, h in ipairs(car.TankHoles) do
        print(string.format("    [%d] local pos: %s", i, tostring(h)))
    end
    print("")
    print("-- Wheels --")
    for i = 1, 4 do
        local d = car.WheelDamage[i]
        local r = car.WheelRestLength[i]
        print(string.format("  W%d: dmg=%d%%  rest=%.2f (base=%.2f)  springK=%.0f  sideGrip=%.1f",
            i, math.Round(d * 100), r, car.RestLength,
            SpringK * (1 - d * 0.5),
            SideGrip * (1 - d * 0.7)))
    end
    print("")
    print("-- Module Zones (local coords) --")
    print(string.format("  Engine  : mins=%s maxs=%s",
        tostring(car.ModuleZones.Engine.mins), tostring(car.ModuleZones.Engine.maxs)))
    print(string.format("  FuelTank: mins=%s maxs=%s",
        tostring(car.ModuleZones.FuelTank.mins), tostring(car.ModuleZones.FuelTank.maxs)))
    for i = 1, 4 do
        print(string.format("  Wheel %d : pos=%s (hitRadius=%d)",
            i, tostring(car.WheelPositions[i]), car.WheelHitRadius))
    end
    print("==========================================")

    ply:ChatPrint("[CustomCar] Status printed to console (open ~)")
end)

-- Команда для настройки позиций модулей "на лету" — не нужно перезаходить
-- Пример: cc_set_zone engine 35 -20 -10 70 20 25
concommand.Add("cc_set_zone", function(ply, cmd, args)
    local car = findCar(ply)
    if not car then return end

    local zoneName = string.lower(args[1] or "")
    if zoneName ~= "engine" and zoneName ~= "fueltank" then
        ply:ChatPrint("[CustomCar] Usage: cc_set_zone <engine|fueltank> minX minY minZ maxX maxY maxZ")
        return
    end

    local nums = {}
    for i = 2, 7 do
        nums[i - 1] = tonumber(args[i])
        if not nums[i - 1] then
            ply:ChatPrint("[CustomCar] Invalid number at position " .. i)
            return
        end
    end

    local zoneKey = zoneName == "engine" and "Engine" or "FuelTank"
    car.ModuleZones[zoneKey] = {
        mins = Vector(nums[1], nums[2], nums[3]),
        maxs = Vector(nums[4], nums[5], nums[6]),
    }
    ply:ChatPrint(string.format("[CustomCar] %s zone updated: mins=%s maxs=%s",
        zoneKey, tostring(car.ModuleZones[zoneKey].mins), tostring(car.ModuleZones[zoneKey].maxs)))
end)