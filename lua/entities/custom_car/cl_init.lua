include("shared.lua")

DebugCars = DebugCars or setmetatable({}, { __mode = "k" })

function ENT:Initialize()
    self.CSWheels = {}
    self.WheelSpin = {0, 0, 0, 0}
    self.EngineRPM = 80
    self.EngineSound = nil
    self.SkidSound = nil
    self.lastSparkEffect = 0
    self.lastSmokeEffect = 0
    DebugCars[self] = true
end


function ENT:Draw()
    self:DrawModel()

    local dt = FrameTime()
    local bodyAng = self:GetAngles()
    local steerAngle = self:GetNWFloat("SteerAngle", 0)
    local carVel = self:GetVelocity()

    for i = 1, 4 do
        if not IsValid(self.CSWheels[i]) then
            local cs = ClientsideModel(self.WheelModel, RENDERGROUP_OPAQUE)
            if IsValid(cs) then
                cs:SetNoDraw(true)
                self.CSWheels[i] = cs
            end
        else
            local cs = self.CSWheels[i]
            local isFront = i <= 2
            local anchorLocal = self.WheelPositions[i]
            local comp = self:GetNWFloat("Comp" .. i, 0)

            -- Пер-колёсная высота пружины (учёт повреждений — сдутая шина опускает кузов)
            local wheelRest = self:GetNWFloat("WheelRest" .. i, self.RestLength)
            local wheelDmg = self:GetNWFloat("WheelDmg" .. i, 0)

            local zOffset = -wheelRest + comp
            local localWheelPos = anchorLocal + Vector(0, 0, zOffset)
            local worldPos = self:LocalToWorld(localWheelPos)

            local worldAng = bodyAng * 1
            local steer = isFront and steerAngle or 0
            if steer ~= 0 then
                worldAng:RotateAroundAxis(worldAng:Up(), -steer)
            end

            local forwardSpeed = carVel:Dot(worldAng:Forward())
            -- Повреждённое колесо крутится медленнее и неравномерно (трение сдутой шины)
            local spinMul = 1 - wheelDmg * 0.4
            self.WheelSpin[i] = (self.WheelSpin[i] or 0) - (forwardSpeed * dt / self.WheelRadius) * 57.3 * spinMul

            local visAng = worldAng * 1
            if i == 2 or i == 4 then
                visAng:RotateAroundAxis(visAng:Up(), 180)
            end
            visAng:RotateAroundAxis(visAng:Right(), self.WheelSpin[i])

            -- Вибрация повреждённого колеса (эффект "восьмёрки" — биение диска)
            if wheelDmg > 0.3 then
                local wobble = math.sin(CurTime() * 25 + i) * wheelDmg * 6
                visAng:RotateAroundAxis(visAng:Forward(), wobble)
                -- Дополнительный наклон по другой оси
                local tilt = math.sin(CurTime() * 18 + i * 1.5) * wheelDmg * 3
                visAng:RotateAroundAxis(visAng:Up(), tilt)
            end

            cs:SetPos(worldPos)
            cs:SetAngles(visAng)
            cs:SetupBones()
            cs:DrawModel()
        end
    end

    -- Клиентские эффекты повреждений (искры/дым от движка)
    self:DrawDamageEffects()
end

-- === КЛИЕНТСКИЕ ЭФФЕКТЫ ПОВРЕЖДЕНИЙ ===
function ENT:DrawDamageEffects()
    local engineHP = self:GetNWFloat("EngineHP", 100)
    local tankHP = self:GetNWFloat("TankHP", 30)
    local fuel = self:GetNWFloat("Fuel", 100)

    -- Центр двигателя для эффектов
    local engineZone = self.ModuleZones.Engine
    local engineCenter = (engineZone.mins + engineZone.maxs) * 0.5
    local engineWorld = self:LocalToWorld(engineCenter)
    local carUp = self:GetUp()

    -- === ДЫМ ИЗ ДВИГАТЕЛЯ при HP < 60 ===
    if engineHP < 60 and engineHP > 0 then
        if (self.lastSmokeEffect or 0) < CurTime() then
            -- Чем меньше HP, тем больше дыма
            local smokeDelay = math.Remap(engineHP, 0, 60, 0.05, 0.5)
            self.lastSmokeEffect = CurTime() + smokeDelay

            local emitter = ParticleEmitter(engineWorld, false)
            if IsValid(emitter) then
                local smokeColor = engineHP < 30 and 30 or 80  -- тёмный дым при тяжёлых повреждениях
                local p = emitter:Add("particles/smokey", engineWorld + VectorRand(-3, 3))
                if p then
                    p:SetVelocity(carUp * 60 + VectorRand(-15, 15))
                    p:SetDieTime(math.Rand(1.5, 3))
                    p:SetStartAlpha(120)
                    p:SetEndAlpha(0)
                    p:SetStartSize(math.Rand(8, 14))
                    p:SetEndSize(math.Rand(20, 35))
                    p:SetColor(smokeColor, smokeColor, smokeColor)
                    p:SetRoll(math.Rand(0, 360))
                end
                emitter:Finish()
            end
        end
    end

    -- === ИСКРЫ ИЗ ДВИГАТЕЛЯ при HP < 30 ===
    if engineHP < 30 and engineHP > 0 then
        if (self.lastSparkEffect or 0) < CurTime() then
            self.lastSparkEffect = CurTime() + math.Rand(0.9, 5)

            local eff = EffectData()
            eff:SetOrigin(engineWorld + VectorRand(-5, 5))
            eff:SetNormal(carUp)
            eff:SetMagnitude(2)
            util.Effect("Sparks", eff)
        end
    end

    -- === КАПЛЯ БЕНЗИНА ВНИЗУ БАКА при утечке ===
    -- Визуально показываем, что из бака что-то капает
    -- (частицы самого бензина уже спавнятся сервером через net.Start("gas particle"))
end

local SND_IDLE = "vehicles/junker/jnk_first.wav"
local SND_SKID = "vehicles/jeep/jeep_skid1.wav"

function ENT:Think()
    self:ProcessSounds()
    self:SetNextClientThink(CurTime())
    return true
end

function ENT:ProcessSounds()
    local dt = FrameTime()
    local engineOn = self:GetNWBool("EngineOn", false)
    local throttle = self:GetNWInt("Throttle", 0)
    local vel = self:GetVelocity()
    local speed = vel:Length()

    -- Читаем состояние модулей для модуляции звука
    local engineHP = self:GetNWFloat("EngineHP", 100)
    local fuel = self:GetNWFloat("Fuel", 100)

    if engineOn then
        if not self.EngineSound then
            self.EngineSound = CreateSound(self, SND_IDLE)
            self.EngineSound:PlayEx(0.1, 80)
        end

        local maxSpeed = 8000
        local numGears = 5
        local gearSpeed = maxSpeed / numGears

        local currentGear = math.Clamp(math.floor(speed / gearSpeed) + 1, 1, numGears)
        local speedInGear = speed - ((currentGear - 1) * gearSpeed)
        local rpmRatio = math.Clamp(speedInGear / gearSpeed, 0, 1)

        -- Базовый pitch зависит от передачи и оборотов
        local basePitch = 70 + (currentGear * 8)
        local targetPitch = basePitch + (rpmRatio * 35)

        -- Сломанный движок звучит глуше и неровнее
        local hpRatio = engineHP / 100
        targetPitch = targetPitch * (0.7 + hpRatio * 0.3)

        if throttle > 0 then
            targetPitch = targetPitch + 15
        elseif throttle < 0 then
            targetPitch = targetPitch - 5
        end

        -- При голодании от топлива — провалы в оборотах
        if fuel < 15 then
            targetPitch = targetPitch + math.sin(CurTime() * 20) * 8
        end

        self.EngineRPM = math.Approach(self.EngineRPM, targetPitch, 100 * dt)

        -- Громкость зависит от оборотов и педали газа
        local targetVol = 0.5 + (rpmRatio * 0.3)
        if throttle ~= 0 then targetVol = targetVol + 0.2 end
        -- Тяжёлые повреждения = тише звук
        targetVol = targetVol * (0.5 + hpRatio * 0.5)

        self.EngineSound:ChangePitch(self.EngineRPM, 0)
        self.EngineSound:ChangeVolume(targetVol, 0)
    else
        if self.EngineSound then
            self.EngineSound:Stop()
            self.EngineSound = nil
        end
        self.EngineRPM = 80
    end

    -- === ЗВУК СКОЛЬЖЕНИЯ ШИН ===
    local right = self:GetRight()
    local forward = self:GetForward()

    local sideSpeed = math.abs(vel:Dot(right))
    local forwardSpeed = vel:Dot(forward)

    -- Усиленный звук скольжения если колёса повреждены (боковой снос сильнее)
    local maxWheelDmg = 0
    for i = 1, 4 do
        local d = self:GetNWFloat("WheelDmg" .. i, 0)
        if d > maxWheelDmg then maxWheelDmg = d end
    end

    local isSkidding = (sideSpeed > 200 * (1 - maxWheelDmg * 0.5)) or (throttle < 0 and forwardSpeed > 400)

    if isSkidding and speed > 150 then
        if not self.SkidSound then
            self.SkidSound = CreateSound(self, SND_SKID)
            self.SkidSound:PlayEx(0, 100)
        end

        local skidVol = math.Clamp((sideSpeed - 200) / 400, 0, 1)
        if throttle < 0 and forwardSpeed > 400 then
            skidVol = math.max(skidVol, 0.7)
        end

        self.SkidSound:ChangeVolume(skidVol, 0)
        self.SkidSound:ChangePitch(math.Clamp(90 + (speed / 100), 90, 130), 0)
    else
        if self.SkidSound then
            self.SkidSound:ChangeVolume(0, 0.2)
            if self.SkidSound:GetVolume() <= 0.05 then
                self.SkidSound:Stop()
                self.SkidSound = nil
            end
        end
    end
end

function ENT:OnRemove()
    DebugCars[self] = nil

    if self.CSWheels then
        for _, cs in pairs(self.CSWheels) do
            if IsValid(cs) then cs:Remove() end
        end
    end

    if self.EngineSound then
        self.EngineSound:Stop()
        self.EngineSound = nil
    end
    if self.SkidSound then
        self.SkidSound:Stop()
        self.SkidSound = nil
    end
end

local function DrawAllCarDebug()
    for car in pairs(DebugCars) do
        if IsValid(car) then
            if car:GetNWBool("DbgEnabled", false) then

            end
            -- Новый режим: всегда отрисовываем боксы модулей
            if car:GetNWBool("ModuleDebug", false) then
                DrawModuleHitboxes(car)
            end
        else
            DebugCars[car] = nil
        end
    end
end

-- === ОТРИСОВКА ХИТБОКСОВ МОДУЛЕЙ (клиентская, видна всегда) ===
local boxMat = Material("models/wireframe")  -- простой wireframe-материал

local colEngine   = Color(255, 60, 60, 80)    -- красный
local colEngineEdge = Color(255, 60, 60, 255)
local colTank     = Color(255, 220, 60, 80)   -- жёлтый
local colTankEdge = Color(255, 220, 60, 255)
local colWheelHit   = Color(60, 255, 60, 40)  -- зелёный (зона попадания колеса)
local colWheelEdge  = Color(60, 255, 60, 180)
local colWheelDmg   = Color(255, 150, 0, 80)  -- оранжевый (повреждённое колесо)

function DrawModuleHitboxes(car)
    if not car.ModuleZones then return end
    if not car:GetNWBool("ModuleDebug", false) then return end

    local pos = car:GetPos()
    local ang = car:GetAngles()

    -- Подготовим материалы и цвета
    render.SetMaterial(boxMat)

    -- === 1. БОКС ДВИГАТЕЛЯ (красный) ===
    local eMin = car.ModuleZones.Engine.mins
    local eMax = car.ModuleZones.Engine.maxs
    local eWorldMin = car:LocalToWorld(eMin)
    local eWorldMax = car:LocalToWorld(eMax)
    -- OBB-стиль: рисуем через LocalToWorld с учётом поворота
    local eCenter = car:LocalToWorld((eMin + eMax) * 0.5)
    local eSize = (eMax - eMin) * 0.5
    render.DrawWireframeBox(eCenter, ang, -eSize, eSize, colEngineEdge, true)
    -- Заливка
    render.DrawBox(eCenter, ang, -eSize, eSize, colEngine, true)

    -- === 2. БОКС БЕНЗОБАКА (жёлтый) ===
    local tMin = car.ModuleZones.FuelTank.mins
    local tMax = car.ModuleZones.FuelTank.maxs
    local tCenter = car:LocalToWorld((tMin + tMax) * 0.5)
    local tSize = (tMax - tMin) * 0.5
    render.DrawWireframeBox(tCenter, ang, -tSize, tSize, colTankEdge, true)
    render.DrawBox(tCenter, ang, -tSize, tSize, colTank, true)

    -- === 3. СФЕРЫ КОЛЁС (зелёные = зона попадания) ===
    for i = 1, 4 do
        local wpos = car:LocalToWorld(car.WheelPositions[i])
        local wheelDmg = car:GetNWFloat("WheelDmg" .. i, 0)
        local r = car.WheelHitRadius

        -- Зелёная сфера (базовая зона попадания)
        render.DrawWireframeSphere(wpos, r, 8, 8, colWheelEdge, true)
        -- Полупрозрачная заливка
        render.DrawSphere(wpos, r, 8, 8, colWheelHit, true)

        -- Повреждённое колесо — оранжевая оболочка, размер растёт с уроном
        if wheelDmg > 0 then
            local dmgR = r * (1 + wheelDmg * 0.5)
            render.DrawWireframeSphere(wpos, dmgR, 8, 8, colWheelDmg, true)
        end

        -- Высота пружины (для визуализации сдутой шины)
        -- Вертикальная линия вниз от точки подвеса до земли (по текущей длине пружины)
        local wheelRest = car:GetNWFloat("WheelRest" .. i, car.RestLength)
        local comp = car:GetNWFloat("Comp" .. i, 0)
        local downEnd = wpos - car:GetUp() * (wheelRest + car.WheelRadius)
        render.DrawLine(wpos, downEnd, Color(255, 255, 255, 200), true)

        -- Точка контакта колеса с землёй (если есть сжатие)
        if comp > 0 then
            local contactPos = wpos - car:GetUp() * (wheelRest - comp + car.WheelRadius)
            render.DrawWireframeSphere(contactPos, 3, 4, 4, Color(255, 255, 255, 255), true)
        end
    end

    -- === 4. HUD-ТЕКСТ С HP МОДУЛЕЙ (3D-надписи над модулями) ===
    local engineHP = car:GetNWFloat("EngineHP", 100)
    local tankHP = car:GetNWFloat("TankHP", 30)
    local fuel = car:GetNWFloat("Fuel", 100)

    -- Надпись над двигателем
    local eTextPos = eCenter + Vector(0, 0, 25)
    local eTextAng = LocalPlayer():EyeAngles()
    eTextAng:RotateAroundAxis(eTextAng:Forward(), 90)
    eTextAng:RotateAroundAxis(eTextAng:Right(), 90)
    cam.Start3D2D(eTextPos, eTextAng, 0.25)
        surface.SetFont("Trebuchet24")
        surface.SetTextColor(255, 100, 100, 255)
        surface.SetTextPos(-100, -10)
        surface.DrawText(string.format("ENGINE  %d / %d", math.Round(engineHP), 100))
        -- Полоса HP
        surface.SetDrawColor(40, 0, 0, 200)
        surface.DrawRect(-100, 20, 200, 6)
        surface.SetDrawColor(255, 80, 80, 255)
        surface.DrawRect(-100, 20, 200 * (engineHP / 100), 6)
    cam.End3D2D()

    -- Надпись над баком
    local tTextPos = tCenter + Vector(0, 0, 25)
    cam.Start3D2D(tTextPos, eTextAng, 0.25)
        surface.SetFont("Trebuchet24")
        surface.SetTextColor(255, 220, 60, 255)
        surface.SetTextPos(-100, -22)
        surface.DrawText(string.format("TANK  %d / %d", math.Round(tankHP), 30))
        surface.SetTextPos(-100, 8)
        surface.DrawText(string.format("FUEL  %d / %d", math.Round(fuel), 100))
        -- Полоса HP бака
        surface.SetDrawColor(60, 40, 0, 200)
        surface.DrawRect(-100, 0, 200, 4)
        surface.SetDrawColor(255, 220, 60, 255)
        surface.DrawRect(-100, 0, 200 * (tankHP / 30), 4)
        -- Полоса топлива
        surface.SetDrawColor(0, 60, 0, 200)
        surface.DrawRect(-100, 36, 200, 4)
        surface.SetDrawColor(80, 255, 80, 255)
        surface.DrawRect(-100, 36, 200 * (fuel / 100), 4)
    cam.End3D2D()

    -- Надписи над колёсами
    for i = 1, 4 do
        local wpos = car:LocalToWorld(car.WheelPositions[i])
        local wheelDmg = car:GetNWFloat("WheelDmg" .. i, 0)
        local wTextPos = wpos + Vector(0, 0, 20)
        cam.Start3D2D(wTextPos, eTextAng, 0.18)
            surface.SetFont("Trebuchet18")
            local col = wheelDmg > 0.5 and Color(255, 80, 80, 255) or
                        (wheelDmg > 0 and Color(255, 200, 50, 255) or Color(80, 255, 80, 255))
            surface.SetTextColor(col)
            local label = string.format("W%d: %d%%", i, math.Round(wheelDmg * 100))
            local w = surface.GetTextSize(label)
            surface.SetTextPos(-w / 2, -8)
            surface.DrawText(label)
        cam.End3D2D()
    end

    -- === 5. ПОСЛЕДНЕЕ ПОПАДАНИЕ (текст над машиной) ===
    -- Если сервер записал LastHitInfo — отрисуем его. Но это серверная переменная,
    -- поэтому она не видна на клиенте напрямую. Альтернатива — PrintMessage в чат
    -- (сервер уже печатает в консоль при DMG_BULLET).
end

hook.Add("PostDrawTranslucentRenderables", "CustomCar_DebugRender", function()
    DrawAllCarDebug()
end)

-- Вспомогательная функция: плавно меняет цвет от красного (0 HP) до зеленого (Max HP)
local function GetHPColor(fraction, alpha)
    fraction = math.Clamp(fraction, 0, 1)
    -- HSV: 0 это красный, 120 это зеленый
    local c = HSVToColor(fraction * 120, 1, 1)
    return Color(c.r, c.g, c.b, alpha)
end

local function DrawAllCarDebug()
    local ply = LocalPlayer()
    local hasHammer = false

    if IsValid(ply) then
        local wep = ply:GetActiveWeapon()
        -- Проверяем, что оружие действительно молоток (по классу или по названию)
        if IsValid(wep) then
            local class = wep:GetClass()
            if class == "weapon_hammer" or string.find(class, "hammer") then
                hasHammer = true
            end
        end
        -- Дополнительно: если активное оружие не молоток, но у игрока есть молоток в инвентаре,
        -- можно всё равно считать, что он держит его (но это не обязательно)
    end

    for car in pairs(DebugCars) do
        if IsValid(car) then
            -- Отрисовываем, если в руках молоток ИЛИ включён режим ModuleDebug
            if hasHammer then
                DrawModuleHitboxes(car)
            end
        else
            DebugCars[car] = nil
        end
    end
end

-- ================================================================
-- ОТРИСОВКА ХИТБОКСОВ (исправлена проверка материалов)
-- ================================================================
local boxMat = Material("models/wireframe")

function DrawModuleHitboxes(car)
    if not car.ModuleZones then return end

    local pos = car:GetPos()
    local ang = car:GetAngles()

    render.SetMaterial(boxMat)

    -- Читаем текущее здоровье
    local engineHP = car:GetNWFloat("EngineHP", 100)
    local tankHP = car:GetNWFloat("TankHP", 30)
    local fuel = car:GetNWFloat("Fuel", 100)

    local engFrac = engineHP / 100
    local tankFrac = tankHP / 30

    local colEngFill = GetHPColor(engFrac, 40)
    local colEngEdge = GetHPColor(engFrac, 255)
    local colTankFill = GetHPColor(tankFrac, 40)
    local colTankEdge = GetHPColor(tankFrac, 255)

    -- БОКС ДВИГАТЕЛЯ
    local eMin = car.ModuleZones.Engine.mins
    local eMax = car.ModuleZones.Engine.maxs
    local eCenter = car:LocalToWorld((eMin + eMax) * 0.5)
    local eSize = (eMax - eMin) * 0.5
    render.DrawWireframeBox(eCenter, ang, -eSize, eSize, colEngEdge, true)
    render.DrawBox(eCenter, ang, -eSize, eSize, colEngFill, true)

    -- БОКС БЕНЗОБАКА
    local tMin = car.ModuleZones.FuelTank.mins
    local tMax = car.ModuleZones.FuelTank.maxs
    local tCenter = car:LocalToWorld((tMin + tMax) * 0.5)
    local tSize = (tMax - tMin) * 0.5
    render.DrawWireframeBox(tCenter, ang, -tSize, tSize, colTankEdge, true)
    render.DrawBox(tCenter, ang, -tSize, tSize, colTankFill, true)

    -- КОЛЁСА (боксы)
    local r = car.WheelHitRadius
    local wMins = Vector(-r, -r * 0.5, -r)
    local wMaxs = Vector(r, r * 0.5, r)

    for i = 1, 4 do
        local wpos = car:LocalToWorld(car.WheelPositions[i])
        local wheelDmg = car:GetNWFloat("WheelDmg" .. i, 0)
        local wFrac = 1 - wheelDmg

        local colWheelFill = GetHPColor(wFrac, 30)
        local colWheelEdge = GetHPColor(wFrac, 200)

        render.DrawWireframeBox(wpos, ang, wMins, wMaxs, colWheelEdge, true)
        render.DrawBox(wpos, ang, wMins, wMaxs, colWheelFill, true)

        -- Линия подвески
        local wheelRest = car:GetNWFloat("WheelRest" .. i, car.RestLength)
        local comp = car:GetNWFloat("Comp" .. i, 0)
        local downEnd = wpos - car:GetUp() * (wheelRest + car.WheelRadius)
        render.DrawLine(wpos, downEnd, Color(255, 255, 255, 100), true)
    end

    -- 3D-ТЕКСТ НАД МОДУЛЯМИ
    local eTextPos = eCenter + Vector(0, 0, 25)
    local eTextAng = LocalPlayer():EyeAngles()
    eTextAng:RotateAroundAxis(eTextAng:Forward(), 90)
    eTextAng:RotateAroundAxis(eTextAng:Right(), 90)

    cam.Start3D2D(eTextPos, eTextAng, 0.25)
        surface.SetFont("Trebuchet24")
        surface.SetTextColor(colEngEdge)
        surface.SetTextPos(-100, -10)
        surface.DrawText(string.format("ENGINE  %d / %d", math.Round(engineHP), 100))
        surface.SetDrawColor(40, 0, 0, 200)
        surface.DrawRect(-100, 20, 200, 6)
        surface.SetDrawColor(colEngEdge)
        surface.DrawRect(-100, 20, 200 * engFrac, 6)
    cam.End3D2D()

    local tTextPos = tCenter + Vector(0, 0, 25)
    cam.Start3D2D(tTextPos, eTextAng, 0.25)
        surface.SetFont("Trebuchet24")
        surface.SetTextColor(colTankEdge)
        surface.SetTextPos(-100, -22)
        surface.DrawText(string.format("TANK  %d / %d", math.Round(tankHP), 30))
        surface.SetTextPos(-100, 8)
        surface.DrawText(string.format("FUEL  %d / %d", math.Round(fuel), 100))
        surface.SetDrawColor(60, 40, 0, 200)
        surface.DrawRect(-100, 0, 200, 4)
        surface.SetDrawColor(colTankEdge)
        surface.DrawRect(-100, 0, 200 * tankFrac, 4)
        surface.SetDrawColor(0, 60, 0, 200)
        surface.DrawRect(-100, 36, 200, 4)
        surface.SetDrawColor(GetHPColor(fuel / 100, 255))
        surface.DrawRect(-100, 36, 200 * (fuel / 100), 4)
    cam.End3D2D()

    for i = 1, 4 do
        local wpos = car:LocalToWorld(car.WheelPositions[i])
        local wheelDmg = car:GetNWFloat("WheelDmg" .. i, 0)
        local wTextPos = wpos + Vector(0, 0, 20)
        cam.Start3D2D(wTextPos, eTextAng, 0.18)
            surface.SetFont("Trebuchet18")
            surface.SetTextColor(GetHPColor(1 - wheelDmg, 255))
            local label = string.format("W%d: %d%%", i, math.Round(wheelDmg * 100))
            local w = surface.GetTextSize(label)
            surface.SetTextPos(-w / 2, -8)
            surface.DrawText(label)
        cam.End3D2D()
    end
end


-- Сохраняем оригинальные функции Homegris
local oldGetCarSteering = hg.GetCarSteering
local oldDragLeftHand_Ex = hg.DragLeftHand_Ex
local oldDragRightHand_Ex = hg.DragRightHand_Ex

hg.GetCarSteering = function(Car)
    if IsValid(Car) and Car:GetClass() == "prop_vehicle_prisoner_pod" then
        if not Car:GetNWBool("IsDriverSeat", false) then 
            return oldGetCarSteering and oldGetCarSteering(Car) or nil, nil
        end
        
        local parent = Car:GetNWEntity("CustomCar")
        if IsValid(parent) and IsValid(parent:GetNWEntity("SteeringWheel")) then
            return 0, { Vector(0,0,0), Angle(0,0,0), Vector(0,0,0), Angle(0,0,0) }
        end
    end
    return oldGetCarSteering and oldGetCarSteering(Car) or nil, nil
end

hg.DragLeftHand_Ex = function(ent, self, pos, ang, anglh)
    local ply = hg.RagdollOwner and hg.RagdollOwner(ent) or ent

    if IsValid(ply) and ply:IsPlayer() and ply:InVehicle() then
        local seat = ply:GetVehicle()
        
        -- Если это не место водителя, возвращаем стандартную анимацию[cite: 2]
        if IsValid(seat) and not seat:GetNWBool("IsDriverSeat", false) then 
            return oldDragLeftHand_Ex and oldDragLeftHand_Ex(ent, self, pos, ang, anglh)
        end
        
        local car = IsValid(seat) and seat:GetNWEntity("CustomCar")

        if IsValid(car) and IsValid(car:GetNWEntity("SteeringWheel")) then
            -- ... (здесь остается ваш оригинальный код IK для левой руки из[cite: 2])
            local steer = car:GetNWEntity("SteeringWheel")
            steer:SetupBones()

            local steerPos = steer:GetPos()
            local steerAng = steer:GetAngles()

            local leftPos, leftAng = LocalToWorld(Vector(8, 1, 4), Angle(90, -90, 0), steerPos, steerAng)
            local lh = ent:LookupBone("ValveBiped.Bip01_L_Hand")
            local lhmat = ent:GetBoneMatrix(lh)

            self.lhandik = true

            if lhmat and leftPos then
                lhmat:SetTranslation(leftPos)
                lhmat:SetAngles(leftAng)
                if hg.bone_apply_matrix then hg.bone_apply_matrix(ent, lh, lhmat) else ent:SetBoneMatrix(lh, lhmat) end
            end

            local rightPos, rightAng = LocalToWorld(Vector(-8, 0, 4), Angle(90, 90, 0), steerPos, steerAng)
            local rh = ent:LookupBone("ValveBiped.Bip01_R_Hand")
            local rhmat = ent:GetBoneMatrix(rh)

            self.rhandik = true
            ply.lerp_rh = 1

            if rhmat and rightPos then
                rhmat:SetTranslation(rightPos)
                rhmat:SetAngles(rightAng)
                if hg.bone_apply_matrix then hg.bone_apply_matrix(ent, rh, rhmat) else ent:SetBoneMatrix(rh, rhmat) end
            end

            return
        end
    end

    return oldDragLeftHand_Ex and oldDragLeftHand_Ex(ent, self, pos, ang, anglh)
end

hg.DragRightHand_Ex = function(ent, self, pos, ang, angrh)
    local ply = hg.RagdollOwner and hg.RagdollOwner(ent) or ent
    if IsValid(ply) and ply:IsPlayer() and ply:InVehicle() then
        local seat = ply:GetVehicle()
        
        if IsValid(seat) and not seat:GetNWBool("IsDriverSeat", false) then 
            return oldDragRightHand_Ex and oldDragRightHand_Ex(ent, self, pos, ang, angrh)
        end
        
        local car = IsValid(seat) and seat:GetNWEntity("CustomCar")
        if IsValid(car) and IsValid(car:GetNWEntity("SteeringWheel")) then
            return
        end
    end
    return oldDragRightHand_Ex and oldDragRightHand_Ex(ent, self, pos, ang, angrh)
end