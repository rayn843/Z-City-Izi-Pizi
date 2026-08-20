MODE.name = "smo"
MODE.PrintName = "Special Military Operation"
MODE.start_time = 6
MODE.end_time = 6
MODE.ROUND_TIME = 1200 -- таймаут раунда (20 мин), основное условие победы — захват всех точек
MODE.LootSpawn = false
MODE.OverideSpawnPos = true
MODE.PointsProgress = {}
MODE.CapPoints = {}
MODE.CapEntities = {} -- кеш энтити точек захвата (без перебора ents.FindByClass каждый тик)
MODE.ForBigMaps = true
MODE.Chance = 0.04

-- Параметры захвата точек
MODE.CAP_CAPTURE_RANGE = 250   -- радиус захвата в юнитах (должен совпадать с prop.CaptureRange)
MODE.CAP_MAX_PROGRESS  = 100   -- |прогресс| полной готовности точки
MODE.CAP_RATE_PER_TICK = 2     -- базовая скорость изменения прогресса (за один тик = CAP_TICK секунд)
MODE.CAP_TICK          = 0.5   -- частота пересчёта точек (сек)

-- Battlefield / SMO: техника и билеты команд
MODE.CAR_CLASS = "custom_car"
MODE.CAR_RESPAWN_DELAY = 15

MODE.CarSpawnPoints = {}
MODE.CarEntities = {}

MODE.UseBattlefieldTickets = true
MODE.TICKETS_START = 100
MODE.TICKET_DEATH_COST = 1
MODE.CAP_TICKET_DRAIN_PER_TICK = 0.1
MODE.Tickets = {}

-- Идентификаторы команд для логики захвата
local TEAM_RU = 1
local TEAM_UA = 0

local pointsName = {
    "Alpha ",
    "Bravo ",
    "Charlie ",
    "Delta ",
    "Echo ",
    "Foxtrot ",
    "Golf ",
    "Hotel ",
    "India ",
    "November ",
    "Vasilek ",
    "Dubok "
}

function MODE.GuiltCheck(Attacker, Victim, add, harm, amt)
    return 1, true -- returning true so guilt bans
end

function MODE:CanLaunch()
    -- Если нужно, чтобы режим запускался только принудительно через раунд-систему,
    -- раскомментируй строку ниже:
    -- do return false end

    local points = zb.GetMapPoints("HMCD_SWO_AZOV")
    local points2 = zb.GetMapPoints("HMCD_SWO_WAGNER")
    local points3 = zb.GetMapPoints("HMCD_SWO_CAPPOINT")

    -- Машины опциональны: если их нет, режим всё равно может работать
    return (#points > 0) and (#points2 > 0) and (#points3 > 0)
end

util.AddNetworkString("SWO_PointsPositions")
util.AddNetworkString("swo_start")
util.AddNetworkString("SWO_TicketsUpdate")

-- ============================================================
-- Battlefield helpers
-- ============================================================

function MODE:SendTickets()
    if not self.UseBattlefieldTickets then return end

    net.Start("SWO_TicketsUpdate")
        net.WriteTable(self.Tickets or {})
    net.Broadcast()
end

function MODE:GetTicketWinner()
    if not self.UseBattlefieldTickets or not self.Tickets then return end

    local ru = self.Tickets[TEAM_RU] or 0
    local ua = self.Tickets[TEAM_UA] or 0

    if ru > ua then
        return TEAM_RU
    elseif ua > ru then
        return TEAM_UA
    end
end

function MODE:GetControlledPointWinner()
    local ru, ua = self:CountControlledPoints()


end

-- ============================================================
-- Car spawn helpers
-- ============================================================

function MODE:CollectCarPoints()
    self.CarSpawnPoints = {}

    local function addCarPoints(list, teamID)
        if not list then return end

        for _, pt in ipairs(list) do
            self.CarSpawnPoints[#self.CarSpawnPoints + 1] = {
                pos = pt.pos or pt.Pos or Vector(0, 0, 0),
                ang = pt.ang or pt.angle or pt.angles or Angle(0, 0, 0),
                team = teamID
            }
        end
    end

    addCarPoints(zb.GetMapPoints("HMCD_SWO_CAR"))
    addCarPoints(zb.GetMapPoints("HMCD_SWO_CAR_RU"), TEAM_RU)
    addCarPoints(zb.GetMapPoints("HMCD_SWO_CAR_UA"), TEAM_UA)
end

function MODE:RemoveAllCars()
    for _, data in pairs(self.CarEntities or {}) do
        if IsValid(data.ent) then
            data.ent:Remove()
        end
    end

    self.CarEntities = {}
end

function MODE:SpawnCar(i)
    local data = self.CarSpawnPoints[i]
    if not data then return end

    local car = ents.Create(self.CAR_CLASS)

    if not IsValid(car) then
        if not self.CarClassWarned then
            print("[SWO] Не найден класс энтити: " .. tostring(self.CAR_CLASS))
            self.CarClassWarned = true
        end

        self.CarEntities[i] = {
            ent = NULL,
            nextSpawn = CurTime() + self.CAR_RESPAWN_DELAY
        }

        return
    end

    car:SetPos(data.pos)
    car:SetAngles(data.ang)

    car.SWOCar = true
    car.SWOCarIndex = i

    if data.team ~= nil then
        car:SetNWInt("SWO_CarTeam", data.team)

        if car.SetTeam then
            car:SetTeam(data.team)
        end
    end

    car:Spawn()
    car:Activate()
    car:DropToFloor()

    local phys = car:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
    end

    self.CarEntities[i] = {
        ent = car,
        nextSpawn = 0
    }
end

function MODE:SpawnAllCars()
    self:RemoveAllCars()
    self:CollectCarPoints()

    for i in ipairs(self.CarSpawnPoints) do
        self:SpawnCar(i)
    end

    print("[SWO] Car points found: " .. tostring(#self.CarSpawnPoints))
end

function MODE:ThinkCars()
    if not self.CarEntities then return end

    for i, data in pairs(self.CarEntities) do
        if not IsValid(data.ent) then
            if not data.nextSpawn or data.nextSpawn == 0 then
                data.nextSpawn = CurTime() + self.CAR_RESPAWN_DELAY
            elseif data.nextSpawn <= CurTime() then
                self:SpawnCar(i)
            end
        end
    end
end

hg = hg or {}

function MODE:Intermission()
    game.CleanUpMap()

    self.WAGNERPoints = {}
    table.CopyFromTo(zb.GetMapPoints("HMCD_SWO_WAGNER"), self.WAGNERPoints)

    self.AZOVPoints = {}
    table.CopyFromTo(zb.GetMapPoints("HMCD_SWO_AZOV"), self.AZOVPoints)

    self.CapPoints = zb.GetMapPoints("HMCD_SWO_CAPPOINT") or {}
    self.CapEntities = {}
    self.PointsProgress = {}
    self.WinnerByCaps = nil
    hg.smo = {}

    -- Battlefield tickets
    self.Tickets = {
        [TEAM_RU] = self.TICKETS_START,
        [TEAM_UA] = self.TICKETS_START
    }

    -- Спавним машины
    self:SpawnAllCars()

    -- Отправляем билеты клиентам
    self:SendTickets()

    print("[SWO] Found " .. #self.CapPoints .. " capture points")

    -- Сохраняем позиции точек для отправки клиентам
    local pointPositions = {}

    for i, point in pairs(self.CapPoints) do
        local pointName = pointsName[i] or "Point_" .. i

        -- Сохраняем позицию точки
        pointPositions[pointName] = point.pos

        -- Создаем простой prop вместо кастомной entity
        local prop = ents.Create("prop_physics")

        if IsValid(prop) then
            prop:SetModel("models/hunter/plates/plate2x2.mdl")
            prop:SetMaterial("models/debug/debugwhite")
            prop:SetColor(Color(255, 255, 0, 0)) -- Желтый для видимости
            prop:SetPos(point.pos)
            prop:SetAngles(Angle(0, 0, 0))
            prop:SetNotSolid(true) -- Нет коллизии
            prop:SetMoveType(MOVETYPE_NONE) -- Не двигается
            prop:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE) -- Нет коллизий
            prop:SetRenderMode(RENDERMODE_NONE) -- Полностью отключаем рендер
            prop:Spawn()

            -- Делаем неподвижным
            local phys = prop:GetPhysicsObject()
            if IsValid(phys) then
                phys:EnableMotion(false)
            end

            -- Сохраняем информацию о точке
            prop.IsCapturePoint = true
            prop.PointName = pointName
            prop.CaptureRange = self.CAP_CAPTURE_RANGE

            self.PointsProgress[pointName] = 0

            -- Кешируем энтити, чтобы не искать их через ents.FindByClass каждый тик
            self.CapEntities[#self.CapEntities + 1] = prop

            print("[SWO] Created capture point: " .. pointName .. " at " .. tostring(point.pos))
        else
            print("[ERROR] Failed to create prop entity at position: " .. tostring(point.pos))
        end
    end

    -- Отправляем позиции точек клиентам
    net.Start("SWO_PointsPositions")
        net.WriteTable(pointPositions)
    net.Broadcast()

    net.Start("SWO_PointsUpdate")
        net.WriteTable(self.PointsProgress)
    net.Broadcast()

    local ctpos
    local tpos

    for i, ply in ipairs(player.GetAll()) do
        if ply:Team() == TEAM_SPECTATOR then continue end

        local pos

        if ply:Team() == 1 then
            if !ctpos then
                ctpos = #self.WAGNERPoints > 0 and self.WAGNERPoints[1].pos or zb:GetRandomSpawn()
                pos = ctpos
            else
                pos = hg.tpPlayer(ctpos, ply, i, 0)
            end
        end

        if ply:Team() == 0 then
            if !tpos then
                tpos = #self.AZOVPoints > 0 and self.AZOVPoints[1].pos or zb:GetRandomSpawn()
                pos = tpos
            else
                pos = hg.tpPlayer(tpos, ply, i, 0)
            end
        end

        ply:SetupTeam(ply:Team())

        if self.UseBattlefieldTickets then
            -- Для совместимости со старыми проверками даём большой запас,
            -- но реально ограничиваем respawn билетами команды.
            ply.Lives = 999
            ply:SetNWInt("SWO_Lives", -1)
        else
            ply.Lives = 3
            ply:SetNWInt("SWO_Lives", 3)
        end

        if pos then
            ply:SetPos(pos)
        end
    end

    net.Start("swo_start")
    net.Broadcast()
end

local player_GetAll = player.GetAll
local team_GetAllTeams = team.GetAllTeams

function MODE:CheckAlivePlayers()
    local tbl = {}

    for i, info in pairs(team_GetAllTeams()) do
        if i == TEAM_UNASSIGNED or i == TEAM_SPECTATOR then continue end
        tbl[i] = {}
    end

    for _, ply in ipairs(player_GetAll()) do
        if ply:Team() == TEAM_UNASSIGNED or ply:Team() == TEAM_SPECTATOR then continue end

        local t = ply:Team() or 0

        if self.UseBattlefieldTickets then
            local teamHasTickets = (self.Tickets and self.Tickets[t] or 0) > 0

            if not ply:Alive() and not teamHasTickets then continue end
            if ply.organism and ply.organism.incapacitated and not teamHasTickets then continue end
        else
            if not ply:Alive() and ply.Lives and ply.Lives < 1 then continue end
            if ply.organism and ply.organism.incapacitated and ply.Lives and ply.Lives < 1 then continue end
        end

        tbl[t] = tbl[t] or {}
        tbl[t][#tbl[t] + 1] = ply
    end

    return tbl
end

-- Возвращает (teamRU, teamUA) — сколько точек полностью контролирует каждая команда
function MODE:CountControlledPoints()
    local ru, ua = 0, 0

    if not self.PointsProgress then return 0, 0 end

    for _, progress in pairs(self.PointsProgress) do
        if progress >= self.CAP_MAX_PROGRESS then
            ru = ru + 1
        elseif progress <= -self.CAP_MAX_PROGRESS then
            ua = ua + 1
        end
    end

    return ru, ua
end

function MODE:ShouldRoundEnd()
    local endround, winner = zb:CheckWinner(self:CheckAlivePlayers())

    -- Battlefield: если билеты закончились — раунд заканчивается
    if self.UseBattlefieldTickets and self.Tickets then
        local ruT = self.Tickets[TEAM_RU] or 0
        local uaT = self.Tickets[TEAM_UA] or 0

        if ruT <= 0 or uaT <= 0 then
            if ruT <= 0 and uaT <= 0 then
                self.WinnerByCaps = self:GetTicketWinner() or self:GetControlledPointWinner()
            elseif ruT <= 0 then
                self.WinnerByCaps = TEAM_UA
            else
                self.WinnerByCaps = TEAM_RU
            end

            return true
        end
    end

    -- Нет точек захвата — полагаемся только на живых / таймер
    if not self.CapPoints or #self.CapPoints == 0 or not self.PointsProgress then
        return endround
    end

    local totalPoints = #self.CapEntities
    if totalPoints == 0 then return endround end

    local ru, ua = self:CountControlledPoints()

    -- Команда побеждает, если контролирует ВСЕ точки

    return endround
end

function MODE:RoundStart()
    self.WinnerByCaps = nil

    -- Жестко сбрасываем билеты до TICKETS_START (100) без использования 'or'
    self.Tickets = {
        [TEAM_RU] = self.TICKETS_START,
        [TEAM_UA] = self.TICKETS_START
    }

    net.Start("SWO_PointsUpdate")
        net.WriteTable(self.PointsProgress)
    net.Broadcast()

    self:SendTickets()
end

local WagnerEquipment = {
    [ "default "] = {
        Primary =  "weapon_ak74 ",
        Secondary =  "weapon_makarov ",
        Other = { "weapon_hands_sh ", "weapon_melee ", "weapon_hg_rgd_tpik ", "weapon_bandage_sh ", "weapon_medkit_sh ", "weapon_tourniquet "},
        Ammo = {},
        Attachments = {
            Primary = {
                Allways = true,
                Scopes = { "holo6 ", "optic11 ", "holo12 ", "holo2 "},
                Barell = { "supressor8 "}
            }
        },
        Armor = { "vest5 ", "helmet1 ", "headphones1 "}
    },
    [ "machinegunner "] = {
        Primary =  "weapon_pkm ",
        Secondary =  "weapon_makarov ",
        Other = { "weapon_hands_sh ", "weapon_melee ", "weapon_hg_rgd_tpik ", "weapon_bandage_sh ", "weapon_medkit_sh ", "weapon_tourniquet "},
        Ammo = {},
        Attachments = {
            Primary = {
                Allways = true,
                Scopes = { "holo6 ", "optic11 "}
            }
        },
        Armor = { "vest5 ", "helmet1 ", "headphones1 "}
    },
    [ "sniper1 "] = {
        Primary =  "weapon_svd ",
        Secondary =  "weapon_makarov ",
        Other = { "weapon_hands_sh ", "weapon_melee ", "weapon_hg_rgd_tpik ", "weapon_bandage_sh ", "weapon_medkit_sh "},
        Ammo = {},
        Attachments = {
            Primary = {
                Allways = true,
                Scopes = { "optic11 ", "optic3 "}
            }
        },
        Armor = { "vest5 ", "helmet1 ", "headphones1 "}
    },
    [ "sniper2 "] = {
        Primary =  "weapon_asval ",
        Secondary =  "weapon_makarov ",
        Other = { "weapon_hands_sh ", "weapon_melee ", "weapon_hg_rgd_tpik ", "weapon_bandage_sh ", "weapon_medkit_sh "},
        Ammo = {},
        Attachments = {
            Primary = {
                Allways = true,
                Scopes = { "optic3 ", "optic4 "}
            }
        },
        Armor = { "vest5 ", "helmet1 ", "headphones1 "}
    },
}

local HoholEquipment = {
    [ "default "] = {
        Primary =  "weapon_m4a1 ",
        Secondary =  "weapon_glock17 ",
        Other = { "weapon_hands_sh ", "weapon_sogknife ", "weapon_hg_grenade_tpik ", "weapon_bandage_sh ", "weapon_medkit_sh ", "weapon_tourniquet "},
        Ammo = {},
        Attachments = {
            Primary = {
                Allways = true,
                Scopes = { "holo17 ", "holo14 ", "holo11 ", "holo4 "},
                Barell = { "supressor2 "}
            }
        },
        Armor = { "vest1 ", "helmet1 ", "headphones1 "}
    },
    [ "machinegunner "] = {
        Primary =  "weapon_m249 ",
        Secondary =  "weapon_glock17 ",
        Other = { "weapon_hands_sh ", "weapon_sogknife ", "weapon_hg_grenade_tpik ", "weapon_bandage_sh ", "weapon_medkit_sh ", "weapon_tourniquet "},
        Ammo = {},
        Attachments = {
            Primary = {
                Allways = true,
                Scopes = { "holo17 ", "holo14 ", "holo11 ", "holo4 "},
            }
        },
        Armor = { "vest1 ", "helmet1 ", "headphones1 "}
    },
    [ "sniper1 "] = {
        Primary =  "weapon_sr25 ",
        Secondary =  "weapon_glock17 ",
        Other = { "weapon_hands_sh ", "weapon_sogknife ", "weapon_medkit_sh "},
        Ammo = {},
        Attachments = {
            Primary = {
                Allways = true,
                Scopes = { "optic6 ", "optic2 "},
            }
        },
        Armor = { "vest3 ", "helmet1 ", "headphones1 "}
    }
}

local function TrimClassName(name)
    if not isstring(name) then return nil end

    name = string.Trim(name)

    if name == "" then
        return nil
    end

    return name
end

local function GiveClassSafe(ply, class)
    class = TrimClassName(class)

    if not class then
        return NULL
    end

    if not IsValid(ply) then
        return NULL
    end

    local ent = ply:Give(class)

    if not IsValid(ent) then
        print("[SWO] Не удалось выдать предмет/оружие: " .. tostring(class))
        return NULL
    end

    return ent
end

local function GiveWeaponSafe(ply, class)
    local wep = GiveClassSafe(ply, class)

    if not IsValid(wep) then
        return NULL
    end

    if wep.GetMaxClip1 and wep.GetPrimaryAmmoType then
        local clip = wep:GetMaxClip1()
        local ammoType = wep:GetPrimaryAmmoType()

        if isnumber(clip) and clip > 0 and isnumber(ammoType) and ammoType >= 0 then
            ply:GiveAmmo(clip * 4, ammoType, true)
        end
    end

    return wep
end

local function RandomAttachmentSafe(tbl)
    if not istable(tbl) or #tbl == 0 then
        return nil
    end

    return TrimClassName(tbl[math.random(#tbl)])
end

local function GiveEquip(ply, team)
    if not IsValid(ply) then return end
    if team ~= 1 and team ~= 0 then return end

    local teamequip = (team == 1 and WagnerEquipment) or HoholEquipment

    if not istable(teamequip) then
        return
    end

    local classequip = table.Random(teamequip)

    if not istable(classequip) then
        return
    end

    local inv = ply:GetNetVar("Inventory")

    if istable(inv) and istable(inv.Weapons) then
        inv.Weapons["hg_sling"] = true
        ply:SetNetVar("Inventory", inv)
    end

    local Primary = GiveWeaponSafe(ply, classequip.Primary)
    GiveWeaponSafe(ply, classequip.Secondary)

    if IsValid(Primary) and istable(classequip.Attachments) and istable(classequip.Attachments.Primary) then
        local att = classequip.Attachments.Primary

        local scopeorno = (att.Allways and 1) or (att.Scopes and math.random(0, 1)) or 0

        if scopeorno > 0 then
            local scope = RandomAttachmentSafe(att.Scopes)

            if scope then
                hg.AddAttachmentForce(ply, Primary, scope)
            end
        end

        local barrelorno = (att.Allways and 1) or (att.Barell and math.random(0, 1)) or 0

        if barrelorno > 0 then
            local barrel = RandomAttachmentSafe(att.Barell)

            if barrel then
                hg.AddAttachmentForce(ply, Primary, barrel)
            end
        end
    end

    if istable(classequip.Armor) then
        local armor = {}

        for _, v in ipairs(classequip.Armor) do
            local a = TrimClassName(v)

            if a then
                armor[#armor + 1] = a
            end
        end

        if #armor > 0 then
            hg.AddArmor(ply, armor)
        end
    end

    if istable(classequip.Other) then
        for _, v in ipairs(classequip.Other) do
            GiveClassSafe(ply, v)
        end
    end

    local walkietalkie = GiveClassSafe(ply, "weapon_walkie_talkie")

    if IsValid(walkietalkie) then
        walkietalkie.Frequency = (team == 1 and 1) or 5
    end

    local hands = GiveClassSafe(ply, "weapon_hands_sh")

    if IsValid(hands) and ply:HasWeapon("weapon_hands_sh") then
        ply:SelectWeapon("weapon_hands_sh")

        timer.Simple(0.2, function()
            if IsValid(ply) and ply:HasWeapon("weapon_hands_sh") then
                ply:SelectWeapon("weapon_hands_sh")
            end
        end)
    end
end

local function spawnswoplayer(ply)
    local WAGNERPoints = zb.GetMapPoints("HMCD_SWO_WAGNER")
    local AZOVPoints = zb.GetMapPoints("HMCD_SWO_AZOV")

    if not ply:Alive() then
        ply:Spawn()
    end

    -- телепортируем на правильный спавн
    if MODE and MODE.GetPlySpawn then
        MODE:GetPlySpawn(ply)
    else
        -- fallback если функция не найдена
        if ply:Team() == 1 and #WAGNERPoints > 0 then
            ply:SetPos(WAGNERPoints[1].pos)
        elseif ply:Team() == 0 and #AZOVPoints > 0 then
            ply:SetPos(AZOVPoints[1].pos)
        end
    end

    ply:SetSuppressPickupNotices(true)
    ply.noSound = true

    if ply:Team() == 1 then
        ply:SetPlayerClass("wagner")
        zb.GiveRole(ply, "RF Armed Forces", Color(71,89,0))
    else
        ply:SetPlayerClass("hohol")
        zb.GiveRole(ply, "UA Armed Forces", Color(89,76,0))
    end

    GiveEquip(ply, ply:Team())

    timer.Simple(0.1, function()
        ply.noSound = false
    end)

    ply:SetSuppressPickupNotices(false)
end

function MODE:GetPlySpawn(ply)
    local plyTeam = ply:Team()

    if ply:Team() == 1 then
        if self.WAGNERPoints and #self.WAGNERPoints > 0 then
            ply:SetPos(self.WAGNERPoints[#self.WAGNERPoints].pos)

            if #self.WAGNERPoints > 1 then
                table.remove(self.WAGNERPoints)
            end
        end
    else
        if self.AZOVPoints and #self.AZOVPoints > 0 then
            ply:SetPos(self.AZOVPoints[#self.AZOVPoints].pos)

            if #self.AZOVPoints > 1 then
                table.remove(self.AZOVPoints)
            end
        end
    end
end

function MODE:GiveEquipment()
    self.WAGNERPoints = {}
    table.CopyFromTo(zb.GetMapPoints("HMCD_SWO_WAGNER"), self.WAGNERPoints)

    self.AZOVPoints = {}
    table.CopyFromTo(zb.GetMapPoints("HMCD_SWO_AZOV"), self.AZOVPoints)

    timer.Simple(0.1, function()
        for _, ply in ipairs(player.GetAll()) do
            if not ply:Alive() then continue end

            ply:SetSuppressPickupNotices(true)
            ply.noSound = true

            if ply:Team() == 1 then
                ply:SetPlayerClass("wagner")
                zb.GiveRole(ply, "RF Armed Forces", Color(71,89,0))
            else
                ply:SetPlayerClass("hohol")
                zb.GiveRole(ply, "UA Armed Forces", Color(89,76,0))
            end

            GiveEquip(ply, ply:Team())

            timer.Simple(0.1, function()
                ply.noSound = false
            end)

            ply:SetSuppressPickupNotices(false)
        end
    end)
end

hg.smo = hg.smo or {}
local cd = 0

util.AddNetworkString("SWO_PointsUpdate")

function MODE:RoundThink()
    -- Респоун игроков, у которых истёк timeDeath
    self.ThinkPlayersDeath = self.ThinkPlayersDeath or CurTime()

    if self.ThinkPlayersDeath < CurTime() then
        self.ThinkPlayersDeath = CurTime() + 1

        for i, ply in ipairs(player_GetAll()) do
            if !ply:Alive() and ply.timeDeath and (ply.timeDeath < CurTime()) then
                ply.timeDeath = nil
                spawnswoplayer(ply)
            end
        end
    end

    -- Пересчёт точек захвата, машины и билеты
    if cd < CurTime() then
        self:ThinkCars()

        local needSend = false
        local progress = self.PointsProgress

        if progress and self.CapEntities then
            for _, prop in ipairs(self.CapEntities) do
                if not IsValid(prop) then continue end

                local pointName = prop.PointName
                if not pointName then continue end

                local pointPos = prop:GetPos()
                local range = prop.CaptureRange or self.CAP_CAPTURE_RANGE

                -- Считаем баланс сил в радиусе: > 0 — перевес RU, < 0 — UA, 0 — оспаривается/пусто
                local balance = 0

                for _, ply in ipairs(player_GetAll()) do
                    if not IsValid(ply) or not ply:Alive() then continue end

                    if ply:GetPos():DistToSqr(pointPos) <= (range * range) then
                        if ply:Team() == TEAM_RU then
                            balance = balance + 1
                        elseif ply:Team() == TEAM_UA then
                            balance = balance - 1
                        end
                    end
                end

                if balance ~= 0 then
                    -- Скорость растёт с перевесом, но минимум — базовая ставка
                    local step = self.CAP_RATE_PER_TICK * math.min(math.abs(balance), 3)
                    local cur = progress[pointName] or 0
                    local newProgress

                    if balance > 0 then -- RU наступает
                        newProgress = math.min(cur + step, self.CAP_MAX_PROGRESS)
                    else -- UA наступает
                        newProgress = math.max(cur - step, -self.CAP_MAX_PROGRESS)
                    end

                    if newProgress ~= cur then
                        progress[pointName] = newProgress
                        needSend = true
                    end
                end

                -- balance == 0: точка оспаривается (или пуста) — прогресс заморожен
            end
        end

        -- Battlefield: захваченные точки давят билеты врага
        local ticketsChanged = false

        if self.UseBattlefieldTickets and self.Tickets then
            local ruControl, uaControl = self:CountControlledPoints()

            if ruControl > 0 then
                local old = self.Tickets[TEAM_UA] or 0
                local new = math.max(old - (ruControl * self.CAP_TICKET_DRAIN_PER_TICK), 0)

                if new ~= old then
                    self.Tickets[TEAM_UA] = new
                    ticketsChanged = true
                end
            end

            if uaControl > 0 then
                local old = self.Tickets[TEAM_RU] or 0
                local new = math.max(old - (uaControl * self.CAP_TICKET_DRAIN_PER_TICK), 0)

                if new ~= old then
                    self.Tickets[TEAM_RU] = new
                    ticketsChanged = true
                end
            end
        end

        if needSend then
            net.Start("SWO_PointsUpdate")
                net.WriteTable(self.PointsProgress)
            net.Broadcast()
        end

        if ticketsChanged then
            self:SendTickets()
        end

        cd = CurTime() + self.CAP_TICK
    end
end

function MODE:GetTeamSpawn()
    return zb.TranslatePointsToVectors(zb.GetMapPoints("HMCD_TDM_T")), zb.TranslatePointsToVectors(zb.GetMapPoints("HMCD_TDM_CT"))
end

function MODE:CanSpawn()
end

util.AddNetworkString("swo_roundend")

function MODE:EndRound()
    timer.Simple(2, function()
        net.Start("swo_roundend")
        net.Broadcast()
    end)

    local endround, winner = zb:CheckWinner(self:CheckAlivePlayers())

    -- Приоритет:
    -- 1. Победа по захвату всех точек / закончившимся билетам
    -- 2. Победа по билетам при таймауте
    -- 3. Победа по живым игрокам
    winner = self.WinnerByCaps or self:GetTicketWinner() or winner

    for k, ply in player.Iterator() do
        if ply:Team() == winner then
            ply:GiveExp(math.random(15, 30))
            ply:GiveSkill(math.Rand(0.1, 0.15))
        else
            ply:GiveSkill(-math.Rand(0.05, 0.1))
        end
    end
end

util.AddNetworkString("swo_respawn")

-- Хук GMod PlayerDeath(victim, inflictor, attacker). Диспетчер режима вызывает
-- hookFunc(ModeTable, ...), поэтому victim — это первый аргумент после self.
function MODE:PlayerDeath(victim, inflictor, attacker)
    if not IsValid(victim) then return end
    if victim:Team() == TEAM_SPECTATOR then return end

    -- Battlefield-режим: минус билет команды
    if self.UseBattlefieldTickets then
        self.Tickets = self.Tickets or {}

        local t = victim:Team()
        local current = self.Tickets[t] or 0

        self.Tickets[t] = math.max(current - self.TICKET_DEATH_COST, 0)
        self:SendTickets()

        victim:SetNWInt("SWO_Lives", -1)

        if self.Tickets[t] <= 0 then
            return
        end

        net.Start("swo_respawn")
            net.WriteFloat(CurTime())
        net.Send(victim)

        victim.timeDeath = CurTime() + 5

        return
    end

    -- Старый режим с личными жизнями
    victim.Lives = victim.Lives or 3
    victim:SetNWInt("SWO_Lives", victim.Lives)

    -- Жизни кончились — не возрождаем
    if victim.Lives <= 1 then
        victim.Lives = 0
        victim:SetNWInt("SWO_Lives", 0)
        return
    end

    net.Start("swo_respawn")
        net.WriteFloat(CurTime())
    net.Send(victim)

    victim.timeDeath = CurTime() + 5
    victim.Lives = victim.Lives - 1
    victim:SetNWInt("SWO_Lives", victim.Lives)
end