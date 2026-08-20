hg = hg or {}

local hg_move_heat = ConVarExists("hg_move_heat") and GetConVar("hg_move_heat") or CreateConVar(
    "hg_move_heat",
    "1",
    FCVAR_ARCHIVE + FCVAR_SERVER_CAN_EXECUTE,
    "Включает нагрев тела от движения игрока",
    0,
    1
)

local hg_move_heat_cap = ConVarExists("hg_move_heat_cap") and GetConVar("hg_move_heat_cap") or CreateConVar(
    "hg_move_heat_cap",
    "36.7",
    FCVAR_ARCHIVE + FCVAR_SERVER_CAN_EXECUTE,
    "Максимальная температура тела, до которой может нагреть движение",
    30,
    45
)

local hg_move_heat_rate = ConVarExists("hg_move_heat_rate") and GetConVar("hg_move_heat_rate") or CreateConVar(
    "hg_move_heat_rate",
    "0.09",
    FCVAR_ARCHIVE + FCVAR_SERVER_CAN_EXECUTE,
    "Базовая скорость нагрева тела от движения",
    0,
    2
)

local hg_move_heat_jump = ConVarExists("hg_move_heat_jump") and GetConVar("hg_move_heat_jump") or CreateConVar(
    "hg_move_heat_jump",
    "0.03",
    FCVAR_ARCHIVE + FCVAR_SERVER_CAN_EXECUTE,
    "Сколько температуры добавляет одиночный прыжок",
    0,
    2
)

local hg_move_heat_sprint_mul = ConVarExists("hg_move_heat_sprint_mul") and GetConVar("hg_move_heat_sprint_mul") or CreateConVar(
    "hg_move_heat_sprint_mul",
    "1.75",
    FCVAR_ARCHIVE + FCVAR_SERVER_CAN_EXECUTE,
    "Множитель нагрева при беге/спринте",
    0,
    10
)

local hg_move_heat_crouch_mul = ConVarExists("hg_move_heat_crouch_mul") and GetConVar("hg_move_heat_crouch_mul") or CreateConVar(
    "hg_move_heat_crouch_mul",
    "0.5",
    FCVAR_ARCHIVE + FCVAR_SERVER_CAN_EXECUTE,
    "Множитель нагрева при ходьбе в присяде",
    0,
    10
)

hook.Add("Org Think", "MoveHeat", function(owner, org, timeValue)
    if not hg_move_heat:GetBool() then return end
    if not IsValid(owner) or not org then return end
    if not owner:IsPlayer() or not owner:Alive() then return end

    if org.godmode or org.superfighter then return end
    if org.otrub or org.fake then return end
    if owner:InVehicle() then return end

    if not isnumber(org.temperature) then
        org.temperature = 36.7
    end

    timeValue = math.min(timeValue or 0, 0.5)
    if timeValue <= 0 then return end

    local moveType = owner:GetMoveType()

    if moveType == MOVETYPE_NOCLIP or moveType == MOVETYPE_OBSERVER then
        return
    end

    org.moveHeat = org.moveHeat or {
        wasOnGround = true
    }

    local onGround = owner:IsOnGround()
    local wasOnGround = org.moveHeat.wasOnGround
    org.moveHeat.wasOnGround = onGround

    local cap = hg_move_heat_cap:GetFloat()

    if org.temperature >= cap then
        return
    end

    local vel = owner:GetVelocity()
    local waterLevel = owner:WaterLevel()
    local speed

    if moveType == MOVETYPE_LADDER then
        speed = vel:Length()
    else
        speed = vel:Length2D()
    end

    local heat = 0
    local baseRate = hg_move_heat_rate:GetFloat()

    if speed > 15 and (onGround or moveType == MOVETYPE_LADDER or waterLevel >= 2) then
        local speedMul = math.Clamp(speed / 320, 0, 2.5)
        heat = heat + baseRate * speedMul
    end

    if not onGround and moveType ~= MOVETYPE_LADDER and waterLevel < 2 then
        heat = heat + baseRate * 0.35
    end

    if owner:KeyDown(IN_JUMP) then
        heat = heat + baseRate * 0.25
    end

    if owner:KeyDown(IN_SPEED) and speed > 80 then
        heat = heat * hg_move_heat_sprint_mul:GetFloat()
    end

    if owner:Crouching() then
        heat = heat * hg_move_heat_crouch_mul:GetFloat()
    end

    if waterLevel >= 2 then
        heat = heat * 0.6
    end

    if org.stamina and isnumber(org.stamina[1]) then
        local staminaFactor = math.Clamp(0.25 + org.stamina[1] * 0.75, 0.25, 1)
        heat = heat * staminaFactor
    end

    local jumpAdd = 0

    if wasOnGround and not onGround and moveType ~= MOVETYPE_LADDER and waterLevel < 2 then
        jumpAdd = hg_move_heat_jump:GetFloat()
    end

    local add = heat * timeValue + jumpAdd

    if add > 0 then
        org.temperature = math.min(org.temperature + add, cap)
    end
end)

hook.Add("Org Clear", "MoveHeat", function(org)
    if org then
        org.moveHeat = nil
    end
end)

hook.Add("PlayerSpawn", "MoveHeatReset", function(ply)
    if OverrideSpawn then return end

    if IsValid(ply) and ply.organism then
        ply.organism.moveHeat = nil
    end
end)