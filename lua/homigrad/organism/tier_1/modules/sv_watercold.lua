hg = hg or {}
hg.waterCold = hg.waterCold or {}
hg.waterCold.fires = hg.waterCold.fires or {}

local hg_water_cold = ConVarExists("hg_water_cold") and GetConVar("hg_water_cold") or CreateConVar(
    "hg_water_cold",
    "1",
    FCVAR_ARCHIVE + FCVAR_SERVER_CAN_EXECUTE,
    "Включает холодную воду для игроков",
    0,
    1
)

local hg_water_temp = ConVarExists("hg_water_temp") and GetConVar("hg_water_temp") or CreateConVar(
    "hg_water_temp",
    "10",
    FCVAR_ARCHIVE + FCVAR_SERVER_CAN_EXECUTE,
    "Обычная температура воды в градусах",
    -30,
    40
)

local hg_water_temp_cold = ConVarExists("hg_water_temp_cold") and GetConVar("hg_water_temp_cold") or CreateConVar(
    "hg_water_temp_cold",
    "2",
    FCVAR_ARCHIVE + FCVAR_SERVER_CAN_EXECUTE,
    "Температура воды на холодных/снежных картах",
    -30,
    40
)

local hg_water_map_cold = ConVarExists("hg_water_map_cold") and GetConVar("hg_water_map_cold") or CreateConVar(
    "hg_water_map_cold",
    "-1",
    FCVAR_ARCHIVE + FCVAR_SERVER_CAN_EXECUTE,
    "-1 = автоопределение холодной карты, 0 = карта не холодная, 1 = карта холодная",
    -1,
    1
)

local hg_water_cool_rate = ConVarExists("hg_water_cool_rate") and GetConVar("hg_water_cool_rate") or CreateConVar(
    "hg_water_cool_rate",
    "0.09",
    FCVAR_ARCHIVE + FCVAR_SERVER_CAN_EXECUTE,
    "Скорость охлаждения тела в воде, градусов в секунду",
    0,
    5
)

local hg_water_wet_time = ConVarExists("hg_water_wet_time") and GetConVar("hg_water_wet_time") or CreateConVar(
    "hg_water_wet_time",
    "45",
    FCVAR_ARCHIVE + FCVAR_SERVER_CAN_EXECUTE,
    "Сколько секунд игрок остаётся мокрым после воды",
    0,
    600
)

local hg_water_health_drain = ConVarExists("hg_water_health_drain") and GetConVar("hg_water_health_drain") or CreateConVar(
    "hg_water_health_drain",
    "0",
    FCVAR_ARCHIVE + FCVAR_SERVER_CAN_EXECUTE,
    "Наносить ли урон здоровью при сильном переохлаждении",
    0,
    1
)

local hg_water_recover = ConVarExists("hg_water_recover") and GetConVar("hg_water_recover") or CreateConVar(
    "hg_water_recover",
    "1",
    FCVAR_ARCHIVE + FCVAR_SERVER_CAN_EXECUTE,
    "Медленно восстанавливать температуру тела, когда игрок сухой и не в воде",
    0,
    1
)

local hg_water_dry_rate = ConVarExists("hg_water_dry_rate") and GetConVar("hg_water_dry_rate") or CreateConVar(
    "hg_water_dry_rate",
    "1",
    FCVAR_ARCHIVE + FCVAR_SERVER_CAN_EXECUTE,
    "Базовая скорость высыхания вне воды",
    0,
    20
)

local hg_water_fire_dry = ConVarExists("hg_water_fire_dry") and GetConVar("hg_water_fire_dry") or CreateConVar(
    "hg_water_fire_dry",
    "1",
    FCVAR_ARCHIVE + FCVAR_SERVER_CAN_EXECUTE,
    "Сушит ли огонь из vFire мокрого игрока",
    0,
    1
)

local coldWords = {
    "snow",
    "winter",
    "cold",
    "ice",
    "frost",
    "arctic",
    "polar",
    "blizzard",
    "freez"
}

local coldMapCache = {}

local function IsColdMap()
    local override = hg_water_map_cold:GetInt()
    if override == 1 then return true end
    if override == 0 then return false end

    local map = string.lower(game.GetMap())

    if coldMapCache[map] ~= nil then
        return coldMapCache[map]
    end

    local cold = false

    for _, word in ipairs(coldWords) do
        if string.find(map, word, 1, true) then
            cold = true
            break
        end
    end

    if not cold then
        cold = #ents.FindByClass("env_snow") > 0
    end

    if not cold then
        for _, ent in ipairs(ents.FindByClass("func_precipitation")) do
            local ok, kv = pcall(function()
                return ent:GetKeyValues()
            end)

            if ok and kv then
                local ptype = kv.preciptype
                if ptype == 1 or ptype == "1" or ptype == "SNOW" or ptype == "snow" then
                    cold = true
                    break
                end
            end
        end
    end

    coldMapCache[map] = cold
    return cold
end

------------------------------------------------------------
-- tracking vFire fires
------------------------------------------------------------

hook.Add("vFireCreated", "WaterCold", function(fire, parent)
    if IsValid(fire) then
        hg.waterCold.fires[fire] = true
    end
end)

hook.Add("vFireRemoved", "WaterCold", function(fire, parent)
    if IsValid(fire) then
        hg.waterCold.fires[fire] = nil
    end
end)

hook.Add("InitPostEntity", "WaterColdCollectFires", function()
    if vFireIsVFireEnt then
        for _, ent in ipairs(ents.GetAll()) do
            if IsValid(ent) and vFireIsVFireEnt(ent) then
                hg.waterCold.fires[ent] = true
            end
        end
    else
        for _, ent in ipairs(ents.FindByClass("vfire*")) do
            if IsValid(ent) and ent.GetFireState then
                hg.waterCold.fires[ent] = true
            end
        end
    end
end)

local nextFireScan = 0

local function CollectFires()
    local t = CurTime()
    if t < nextFireScan then return end
    nextFireScan = t + 2

    if vFireIsVFireEnt then
        for _, ent in ipairs(ents.GetAll()) do
            if IsValid(ent) and vFireIsVFireEnt(ent) then
                hg.waterCold.fires[ent] = true
            end
        end
    else
        for _, ent in ipairs(ents.FindByClass("vfire*")) do
            if IsValid(ent) and ent.GetFireState then
                hg.waterCold.fires[ent] = true
            end
        end
    end
end

local function GetFireDryRate(ent)
    if not hg_water_fire_dry:GetBool() then return 0 end
    if not IsValid(ent) then return 0 end

    if table.IsEmpty(hg.waterCold.fires) then
        CollectFires()
    end

    local pos = ent:GetPos()
    local dry = 0

    for fire in pairs(hg.waterCold.fires) do
        if not IsValid(fire) then
            hg.waterCold.fires[fire] = nil
            continue
        end

        local state = fire.GetFireState and fire:GetFireState() or 1

        local radius = 45 + state * 22

        if vFireBaseRadius then
            local ok, r = pcall(vFireBaseRadius, state)
            if ok and isnumber(r) then
                radius = math.max(radius, r * 3 + 24)
            end
        end

        local firePos = fire:GetPos()
        local distSqr = firePos:DistToSqr(pos)

        if distSqr <= radius * radius then
            local dist = math.sqrt(distSqr)
            local strength = 1 - (dist / radius)

            dry = dry + (0.9 + state * 0.75) * strength
        end

        if fire.parent == ent or fire:GetParent() == ent then
            dry = dry + 15
        end
    end

    if ent:IsOnFire() then
        dry = dry + 5
    end

    return dry
end

------------------------------------------------------------
-- water / character helpers
------------------------------------------------------------

local function GetCharacterEntity(owner)
    if not IsValid(owner) then return NULL end

    if owner:IsPlayer() then
        local rag = owner.FakeRagdoll

        if not IsValid(rag) then
            rag = owner:GetNWEntity("FakeRagdoll")
        end

        if IsValid(rag) then
            return rag
        end
    end

    return owner
end

local function GetWaterCoverage(ent)
    if not IsValid(ent) then return 0 end

    local wl = ent:WaterLevel()

    if wl >= 3 then
        return 1
    elseif wl >= 2 then
        return 0.75
    elseif wl >= 1 then
        return 0.35
    end

    return 0
end

local function SyncWet(owner, org, wetMax)
    if not IsValid(owner) or not org or not org.waterCold then return end

    local wetFrac = math.Clamp((org.waterCold.wet or 0) / math.max(wetMax, 1), 0, 1)

    if math.abs((org.waterCold.netWet or -1) - wetFrac) > 0.02 then
        org.waterCold.netWet = wetFrac

        owner:SetNW2Float("hg_wetness", wetFrac)

        if IsValid(owner.FakeRagdoll) then
            owner.FakeRagdoll:SetNW2Float("hg_wetness", wetFrac)
        end
    end
end

------------------------------------------------------------
-- main think
------------------------------------------------------------

hook.Add("Org Think", "WaterCold", function(owner, org, timeValue)
    if not hg_water_cold:GetBool() then
        if IsValid(owner) and owner:IsPlayer() and owner:GetNW2Float("hg_wetness", 0) ~= 0 then
            owner:SetNW2Float("hg_wetness", 0)
        end
        return
    end

    if not IsValid(owner) or not org then return end
    if not owner:IsPlayer() or not owner:Alive() then return end
    if org.godmode or org.superfighter then return end

    timeValue = math.min(timeValue or 0, 0.5)
    if timeValue <= 0 then return end

    if not isnumber(org.temperature) then
        org.temperature = 36.7
    end

    org.waterCold = org.waterCold or {
        wet = 0,
        dmg = 0,
        netWet = -1
    }

    local ent = GetCharacterEntity(owner)
    local coverage = GetWaterCoverage(ent)
    local wetMax = math.max(hg_water_wet_time:GetFloat(), 1)

    local fireDry = 0

    if coverage > 0 then
        org.waterCold.wet = math.min(org.waterCold.wet + timeValue * coverage * 1.5, wetMax)
    else
        fireDry = GetFireDryRate(ent)
        local dryRate = hg_water_dry_rate:GetFloat() + fireDry

        org.waterCold.wet = math.max(org.waterCold.wet - timeValue * dryRate, 0)
    end

    SyncWet(owner, org, wetMax)

    if org.waterCold.wet <= 0 then
        org.waterCold.dmg = 0

        if hg_water_recover:GetBool() and org.temperature < 36.7 then
            local recoverRate = (IsColdMap() and 0.002 or 0.008) + fireDry * 0.025
            org.temperature = math.Approach(org.temperature, 36.7, recoverRate * timeValue)
        end

        return
    end

    local waterTemp = hg_water_temp:GetFloat()

    if IsColdMap() then
        waterTemp = math.min(waterTemp, hg_water_temp_cold:GetFloat())
    end

    local wetFactor = math.Clamp(org.waterCold.wet / math.max(wetMax * 0.2, 1), 0, 1)

    local speedMul = 1
    if IsValid(ent) and ent.GetVelocity then
        local vel = ent:GetVelocity():Length()
        speedMul = math.Clamp(0.75 + vel / 400, 0.75, 1.5)
    end

    local rate = hg_water_cool_rate:GetFloat() * math.max(coverage, 0.35) * wetFactor * speedMul

    local minTarget = math.max(waterTemp, 18)

    if org.temperature > minTarget then
        org.temperature = math.Approach(org.temperature, minTarget, rate * timeValue)
    end

    if fireDry > 0 and org.temperature < 36.7 then
        org.temperature = math.Approach(org.temperature, 36.7, fireDry * 0.02 * timeValue)
    end

    local cold = math.Clamp((35 - org.temperature) / 10, 0, 1)

    if cold > 0 then
        org.painadd = (org.painadd or 0) + timeValue * cold * 0.4
        org.fearadd = (org.fearadd or 0) + timeValue * cold * 0.02
        org.disorientation = math.max(org.disorientation or 0, cold * 2.5)
        org.immobilization = math.min((org.immobilization or 0) + timeValue * cold * 0.35, 30)

        if org.stamina and isnumber(org.stamina[1]) then
            org.stamina[1] = math.Approach(org.stamina[1], 0, timeValue * cold * 4)
        end
    end

    if hg_water_health_drain:GetBool() and org.temperature <= 30 then
        local severity = math.Clamp((30 - org.temperature) / 8, 0, 1)
        local dps = 0.5 + severity * 3.5

        org.waterCold.dmg = (org.waterCold.dmg or 0) + dps * timeValue

        if org.waterCold.dmg >= 1 then
            local amount = math.floor(org.waterCold.dmg)
            org.waterCold.dmg = org.waterCold.dmg - amount

            if owner:Health() > amount then
                owner:SetHealth(owner:Health() - amount)
            else
                owner:SetHealth(1)
                owner:Kill()
            end
        end
    else
        org.waterCold.dmg = 0
    end
end)

------------------------------------------------------------
-- resets
------------------------------------------------------------

hook.Add("Org Clear", "WaterCold", function(org)
    if org then
        org.waterCold = nil
    end
end)

hook.Add("Player Spawn", "WaterColdReset", function(ply)
    if OverrideSpawn then return end

    if IsValid(ply) then
        ply:SetNW2Float("hg_wetness", 0)

        if IsValid(ply.FakeRagdoll) then
            ply.FakeRagdoll:SetNW2Float("hg_wetness", 0)
        end

        if ply.organism then
            ply.organism.waterCold = nil
        end
    end
end)

hook.Add("Fake", "WaterColdWet", function(ply, ragdoll)
    if IsValid(ply) and ply:IsPlayer() and IsValid(ragdoll) then
        ragdoll:SetNW2Float("hg_wetness", ply:GetNW2Float("hg_wetness", 0))
    end
end)