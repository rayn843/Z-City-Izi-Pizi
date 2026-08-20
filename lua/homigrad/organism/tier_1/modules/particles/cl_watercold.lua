hg = hg or {}
hg.waterCold = hg.waterCold or {}
hg.waterCold.drops = hg.waterCold.drops or {}
hg.waterCold.splashes = hg.waterCold.splashes or {}

local hg_water_drips = CreateClientConVar(
    "hg_water_drips",
    "1",
    true,
    false,
    "Включает капли воды с мокрых игроков",
    0,
    1
)

local hg_water_drips_max = CreateClientConVar(
    "hg_water_drips_max",
    "220",
    true,
    false,
    "Максимальное количество капель воды",
    0,
    1000
)

local dropMat = Material("sprites/light_ignorez")

local dripBones = {
    "ValveBiped.Bip01_Head1",
    "ValveBiped.Bip01_Spine2",
    "ValveBiped.Bip01_Spine1",
    "ValveBiped.Bip01_Pelvis",
    "ValveBiped.Bip01_L_Forearm",
    "ValveBiped.Bip01_R_Forearm",
    "ValveBiped.Bip01_L_Hand",
    "ValveBiped.Bip01_R_Hand",
    "ValveBiped.Bip01_L_Calf",
    "ValveBiped.Bip01_R_Calf",
    "ValveBiped.Bip01_L_Foot",
    "ValveBiped.Bip01_R_Foot"
}

local nextDrip = 0

local function GetDripPos(ent)
    if not IsValid(ent) then return end

    local boneName = dripBones[math.random(#dripBones)]
    local bone = ent:LookupBone(boneName)

    if bone then
        local mat = ent:GetBoneMatrix(bone)

        if mat then
            return mat:GetTranslation() + VectorRand(-2, 2)
        end
    end

    local mins, maxs = ent:GetCollisionBounds()

    return ent:GetPos() + Vector(
        math.Rand(mins.x, maxs.x),
        math.Rand(mins.y, maxs.y),
        maxs.z * math.Rand(0.2, 0.9)
    )
end

hook.Add("Think", "hg_watercold_spawn_drips", function()
    if not hg_water_drips:GetBool() then return end

    local t = CurTime()
    if t < nextDrip then return end

    nextDrip = t + 0.08

    local lply = LocalPlayer()
    if not IsValid(lply) then return end

    local maxDrops = hg_water_drips_max:GetInt()

    for _, ply in ipairs(player.GetAll()) do
        local rag = ply.FakeRagdoll
        local ent = IsValid(rag) and rag or ply

        if not IsValid(ent) then continue end

        local wet = ent:GetNW2Float("hg_wetness", 0)

        if wet <= 0.01 then
            wet = ply:GetNW2Float("hg_wetness", 0)
        end

        if wet <= 0.04 then continue end
        if ent:WaterLevel() > 0 then continue end
        if ent:GetPos():DistToSqr(lply:GetPos()) > 800 * 800 then continue end

        if #hg.waterCold.drops >= maxDrops then break end

        if math.Rand(0, 1) < wet * 0.75 then
            local pos = GetDripPos(ent)

            if pos then
                table.insert(hg.waterCold.drops, {
                    pos = pos,
                    vel = VectorRand(-6, 6) + Vector(0, 0, -25),
                    life = CurTime() + 1.4,
                    size = math.Rand(1.4, 3.2),
                    alpha = math.Clamp(60 + wet * 140, 0, 220)
                })
            end
        end
    end
end)

hook.Add("Think", "hg_watercold_update_drips", function()
    if not hg_water_drips:GetBool() then return end

    local ft = FrameTime()
    if ft <= 0 then return end

    local drops = hg.waterCold.drops

    for i = #drops, 1, -1 do
        local d = drops[i]

        if d.life < CurTime() then
            table.remove(drops, i)
            continue
        end

        d.vel.z = d.vel.z - 650 * ft

        local old = d.pos
        d.pos = d.pos + d.vel * ft

        local tr = util.TraceLine({
            start = old,
            endpos = d.pos,
            mask = MASK_SOLID_BRUSHONLY
        })

        if tr.Hit then
            table.remove(drops, i)

            if #hg.waterCold.splashes < 100 then
                table.insert(hg.waterCold.splashes, {
                    pos = tr.HitPos + tr.HitNormal * 0.5,
                    life = CurTime() + 0.22,
                    size = math.Rand(3, 7)
                })
            end
        end
    end

    local splashes = hg.waterCold.splashes

    for i = #splashes, 1, -1 do
        if splashes[i].life < CurTime() then
            table.remove(splashes, i)
        end
    end
end)

hook.Add("PostDrawTranslucentRenderables", "hg_watercold_draw_drips", function()
    if not hg_water_drips:GetBool() then return end
    if #hg.waterCold.drops == 0 and #hg.waterCold.splashes == 0 then return end

    render.SetMaterial(dropMat)

    for _, d in ipairs(hg.waterCold.drops) do
        render.DrawSprite(
            d.pos,
            d.size,
            d.size,
            Color(140, 190, 255, d.alpha or 120)
        )
    end

    for _, s in ipairs(hg.waterCold.splashes) do
        local k = math.Clamp((s.life - CurTime()) / 0.22, 0, 1)

        render.DrawSprite(
            s.pos,
            s.size * (1 - k) + 2,
            s.size * (1 - k) + 2,
            Color(170, 215, 255, 90 * k)
        )
    end
end)

hook.Add("Player Spawn", "hg_watercold_reset_drips", function(ply)
    if ply ~= LocalPlayer() then return end

    hg.waterCold.drops = {}
    hg.waterCold.splashes = {}
end)