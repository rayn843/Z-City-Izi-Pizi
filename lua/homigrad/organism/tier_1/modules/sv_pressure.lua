-- sv_pressure.lua
-- Система артериального давления для Homigrad.

hg = hg or {}
hg.pressure = hg.pressure or {}

hg.pressure.Presets = hg.pressure.Presets or {
    -- Понижающие давление
    captopril = {
        onset = 35,
        duration = 480,
        sys = -35,
        dia = -18,
        pulse = 0
    },

    metoprolol = {
        onset = 50,
        duration = 600,
        sys = -25,
        dia = -12,
        pulse = -35
    },

    nifedipine = {
        onset = 20,
        duration = 300,
        sys = -45,
        dia = -22,
        pulse = 12
    },

    nitroglycerin = {
        onset = 8,
        duration = 90,
        sys = -40,
        dia = -20,
        pulse = 8
    },

    -- Повышающие давление
    caffeine = {
        onset = 20,
        duration = 360,
        sys = 18,
        dia = 6,
        pulse = 12
    },

    midodrine = {
        onset = 45,
        duration = 480,
        sys = 35,
        dia = 18,
        pulse = 4
    },

    salt = {
        onset = 80,
        duration = 700,
        sys = 10,
        dia = 4,
        pulse = 0
    }
}

local hg_pressure_enable = ConVarExists("hg_pressure_enable") and GetConVar("hg_pressure_enable") or CreateConVar(
    "hg_pressure_enable",
    "1",
    FCVAR_ARCHIVE + FCVAR_SERVER_CAN_EXECUTE,
    "Включает систему артериального давления",
    0,
    1
)

local hg_pressure_damage = ConVarExists("hg_pressure_damage") and GetConVar("hg_pressure_damage") or CreateConVar(
    "hg_pressure_damage",
    "1",
    FCVAR_ARCHIVE + FCVAR_SERVER_CAN_EXECUTE,
    "Включает последствия давления: обмороки, повреждение мозга и т.д.",
    0,
    1
)

local function SyncPressure(owner, org)
    if not IsValid(owner) or not owner:IsPlayer() then return end

    local sysNet = math.Round(org.pressureSys or 120)
    local diaNet = math.Round(org.pressureDia or 80)

    if org.pressureNetSys ~= sysNet then
        org.pressureNetSys = sysNet
        owner:SetNW2Float("hg_pressure_sys", sysNet)
    end

    if org.pressureNetDia ~= diaNet then
        org.pressureNetDia = diaNet
        owner:SetNW2Float("hg_pressure_dia", diaNet)
    end
end

function hg.pressure.AddDrug(org, name, data)
    if not org then return end

    data = data or hg.pressure.Presets[name]
    if not data then return end

    if not istable(org.pressureDrugs) then
        org.pressureDrugs = {}
    end

    table.insert(org.pressureDrugs, {
        name = name or "unknown",
        start = CurTime(),
        onset = math.max(data.onset or 15, 1),
        duration = math.max(data.duration or 120, 5),
        sys = data.sys or 0,
        dia = data.dia or 0,
        pulse = data.pulse or 0
    })
end

local function GetDrugEffects(org)
    if not istable(org.pressureDrugs) then
        org.pressureDrugs = {}
    end

    local sys = 0
    local dia = 0
    local pulse = 0
    local t = CurTime()

    for i = #org.pressureDrugs, 1, -1 do
        local drug = org.pressureDrugs[i]
        local elapsed = t - drug.start

        if elapsed > drug.duration then
            table.remove(org.pressureDrugs, i)
            continue
        end

        local inK = math.Clamp(elapsed / drug.onset, 0, 1)

        local fadeTime = math.min(drug.duration * 0.25, 60)
        local outK = math.Clamp((drug.duration - elapsed) / fadeTime, 0, 1)

        local k = math.min(inK, outK)

        sys = sys + drug.sys * k
        dia = dia + drug.dia * k
        pulse = pulse + drug.pulse * k
    end

    return sys, dia, pulse
end

hook.Add("Org Think", "Pressure", function(owner, org, timeValue)
    if not hg_pressure_enable:GetBool() then return end
    if not IsValid(owner) or not org then return end
    if not owner:IsPlayer() then return end

    timeValue = math.min(timeValue or 0, 0.5)
    if timeValue <= 0 then return end

    if not isnumber(org.pressureSys) then org.pressureSys = 120 end
    if not isnumber(org.pressureDia) then org.pressureDia = 80 end

    if not istable(org.pressureDrugs) then
        org.pressureDrugs = {}
    end

    local drugSys, drugDia, drugPulse = GetDrugEffects(org)

    local blood = org.blood or 5000
    local pulse = org.pulse or org.heartbeat or 70
    local adrenaline = org.adrenaline or 0
    local pain = org.pain or 0

    local bloodK = math.Clamp((blood - 1200) / (5000 - 1200), 0, 1)
    local pulseK = math.Clamp(pulse / 70, 0.25, 2.5)

    local targetSys = 120 * (0.30 + 0.70 * bloodK)
    local targetDia = 80 * (0.40 + 0.60 * bloodK)

    targetSys = targetSys * (0.65 + 0.35 * pulseK)
    targetDia = targetDia * (0.70 + 0.30 * pulseK)

    targetSys = targetSys + adrenaline * 18 + pain * 0.15 + drugSys
    targetDia = targetDia + adrenaline * 8 + pain * 0.05 + drugDia

    if org.otrub then
        targetSys = targetSys - 12
        targetDia = targetDia - 6
    end

    if org.heartstop or org.alive == false then
        targetSys = 0
        targetDia = 0
    end

    org.pressureSys = math.Approach(
        org.pressureSys,
        math.Clamp(targetSys, 0, 320),
        timeValue * 25
    )

    org.pressureDia = math.Approach(
        org.pressureDia,
        math.Clamp(targetDia, 0, 220),
        timeValue * 20
    )

    if drugPulse ~= 0 and not org.heartstop and org.alive ~= false then
        local pulseDelta = drugPulse * timeValue * 0.15

        if isnumber(org.pulse) then
            org.pulse = math.Clamp(org.pulse + pulseDelta, 25, 350)
        end

        if isnumber(org.heartbeat) then
            org.heartbeat = math.Clamp(org.heartbeat + pulseDelta, 25, 350)
        end
    end

    local sys = org.pressureSys
    local dia = org.pressureDia
    local map = (sys + dia * 2) / 3

    if owner:Alive() and not org.superfighter and not org.godmode then
        -- Гипотония: низкое давление
        if sys < 90 or map < 60 then
            local sev = math.Clamp(
                math.max(
                    (90 - sys) / 50,
                    (60 - map) / 30
                ),
                0,
                1
            )

            org.disorientation = math.max(org.disorientation or 0, sev * 5)
            org.immobilization = math.min((org.immobilization or 0) + timeValue * sev * 2.0, 40)
            org.fearadd = (org.fearadd or 0) + timeValue * sev * 0.03
            org.shock = math.min((org.shock or 0) + timeValue * sev * 1.5, 80)

            if org.stamina and isnumber(org.stamina[1]) then
                org.stamina[1] = math.max(org.stamina[1] - timeValue * sev * 2, 0)
            end

            if hg_pressure_damage:GetBool() then
                local targetConsciousness = sev > 0.8 and 0.05 or 0.2
                org.consciousness = math.Approach(
                    org.consciousness or 1,
                    targetConsciousness,
                    timeValue * sev * 0.04
                )
            end
        end

        -- Гипертония: высокое давление
        if sys > 170 or dia > 110 then
            local sev = math.Clamp(
                math.max(
                    (sys - 170) / 70,
                    (dia - 110) / 50
                ),
                0,
                1
            )

            org.painadd = (org.painadd or 0) + timeValue * sev * 0.8
            org.fearadd = (org.fearadd or 0) + timeValue * sev * 0.06
            org.disorientation = math.max(org.disorientation or 0, sev * 2.5)

            if hg_pressure_damage:GetBool() and sev > 0.45 then
                org.brain = math.min((org.brain or 0) + timeValue * (sev - 0.45) * 0.001, 1)
                org.hurtadd = (org.hurtadd or 0) + timeValue * (sev - 0.45) * 0.02
            end
        end
    end

    SyncPressure(owner, org)
end)

hook.Add("PlayerSpawn", "PressureReset", function(ply)
    if OverrideSpawn then return end
    if not IsValid(ply) then return end

    ply:SetNW2Float("hg_pressure_sys", 120)
    ply:SetNW2Float("hg_pressure_dia", 80)

    if ply.organism then
        ply.organism.pressureSys = 120
        ply.organism.pressureDia = 80
        ply.organism.pressureDrugs = {}
        ply.organism.pressureNetSys = nil
        ply.organism.pressureNetDia = nil
    end
end)