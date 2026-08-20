ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "Custom Car"
ENT.Author = "YourName"
ENT.Category = "Vehicles"
ENT.Spawnable = true
ENT.AdminOnly = false


ENT.WheelModel = "models/props_vehicles/carparts_wheel01a.mdl"
ENT.WheelRadius = 18
ENT.RestLength = 12

ENT.WheelPositions = {
    Vector(55.5, 30, -8),  -- 1: Переднее левое
    Vector(55.5, -30, -8), -- 2: Переднее правое
    Vector(-55.5, 30, -8), -- 3: Заднее левое
    Vector(-55.5, -30, -8) -- 4: Заднее правое
}

-- === ЗОНЫ МОДУЛЕЙ (в локальных координатах кузова) ===
-- Используются сервером для определения, в какой модуль попала пуля
-- X+: перед машины (где двигатель), X-: зад (где бак)
ENT.ModuleZones = {
    -- Под капотом: передняя часть кузова
    Engine = {
        mins = Vector(35, -40, -10),
        maxs = Vector(84, 40, 17),
    },
    -- Под багажником: задняя часть кузова
    FuelTank = {
        mins = Vector(-100, -30, -25),
        maxs = Vector(-60, 30, 0),
    },
}

-- Радиус сферы вокруг позиции колеса, в которой засчитывается попадание в колесо
ENT.WheelHitRadius = 25
