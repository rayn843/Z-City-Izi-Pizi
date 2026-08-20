MODE.name = "laststand"
MODE.PrintName = "Last Stand"

MODE.ForBigMaps = false
MODE.ROUND_TIME = 180

MODE.Chance = 1.0
MODE.OverideSpawnPos = true
MODE.LootSpawn = false

function MODE:CanLaunch()
    return true
end

function MODE.GuiltCheck(Attacker, Victim, add, harm, amt)
    return 1, true
end

util.AddNetworkString("laststand_start")
util.AddNetworkString("laststand_roundend")
util.AddNetworkString("laststand_open_menu")
util.AddNetworkString("laststand_select_loadout")
util.AddNetworkString("laststand_start_prep") -- Сигнал для старта таймера

local heavyWeps = {
    "weapon_ar15", "weapon_m249", "weapon_rpk", "weapon_ak74", "weapon_m4a1"
}

-- Функция выдачи снаряжения для легкого игрока
local function SetupLightPlayer(ply, wepClass, eqClass)
    if not IsValid(ply) then return end
    
    if not wepClass then
        wepClass = LS_LightWeps[math.random(#LS_LightWeps)].class
    end

    ply:StripWeapons()
    ply:StripAmmo()

    ply:SetPlayerClass("default")
    zb.GiveRole(ply, "Survivor", Color(190,0,0))
    ply:SetNetVar("CurPluv", "pluvred")

    local wep = ply:Give(wepClass)
    if IsValid(wep) then
        ply:GiveAmmo(wep:GetMaxClip1() * 3, wep:GetPrimaryAmmoType())
    end

    if eqClass and eqClass != "none" then
        hg.AddArmor(ply, eqClass)
    end

    ply:Give("weapon_bandage_sh")
    ply:Give("weapon_tourniquet")
    ply:Give("weapon_fentanyl")

    local hands = ply:Give("weapon_hands_sh")
    if IsValid(hands) then
        ply:SelectWeapon("weapon_hands_sh")
    end

    ply.LS_SelectedWep = wepClass
    ply.LS_SelectedEq = eqClass
end

function MODE:Intermission()
    game.CleanUpMap()

    self.CTPoints = {}
    table.CopyFromTo(zb.GetMapPoints( "HMCD_TDM_CT" ), self.CTPoints)
    self.TPoints = {}
    table.CopyFromTo(zb.GetMapPoints( "HMCD_TDM_T" ), self.TPoints)
    
    local allPlayers = player.GetAll()
    local count = #allPlayers
    local heavyCount = math.max(1, math.floor(count * 0.3))

    local shuffled = {}
    for _, ply in ipairs(allPlayers) do
        ply:SetNWInt("LivesLeft", -1)
        ply.HasSelectedLoadout = false
        ply.LS_SelectedWep = nil
        ply.LS_SelectedEq = nil
        ply.LS_Eliminated = nil -- Сбрасываем статус уничтожения
        table.insert(shuffled, ply)
    end
    
    for i = #shuffled, 2, -1 do
        local j = math.random(i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end

    for i, ply in ipairs(shuffled) do
        if i <= heavyCount then
            ply:SetTeam(1)
        else
            ply:SetTeam(0)
        end
        ply:SetupTeam(ply:Team())
    end

    net.Start("laststand_start")
    net.Broadcast()
end

function MODE:CheckAlivePlayers()
    local teamsAlive = {}
    for _, ply in player.Iterator() do
        if not IsValid(ply) then continue end
        if ply:Team() == 0 then
            if ply:Alive() or ply:GetNWInt("LivesLeft", 0) > 0 then
                teamsAlive[0] = teamsAlive[0] or {}
                table.insert(teamsAlive[0], ply)
            end
        elseif ply:Team() == 1 then
            -- Считаем тяжёлых живыми, только если они живы и не помечены как уничтоженные
            if ply:Alive() and not ply.LS_Eliminated then
                teamsAlive[1] = teamsAlive[1] or {}
                table.insert(teamsAlive[1], ply)
            end
        end
    end
    return teamsAlive
end

function MODE:ShouldRoundEnd()
    local endround, winner = zb:CheckWinner(self:CheckAlivePlayers())
    return endround
end

function MODE:BoringRoundFunction()		
    timer.Simple(2, function() end)
end

function MODE:RoundStart() end

function MODE:GiveEquipment()
    self.CTPoints = {}
    table.CopyFromTo(zb.GetMapPoints( "HMCD_TDM_CT" ), self.CTPoints)
    self.TPoints = {}
    table.CopyFromTo(zb.GetMapPoints( "HMCD_TDM_T" ), self.TPoints)
    
    timer.Simple(0.1, function()
        for _, ply in player.Iterator() do
            if not IsValid(ply) then continue end

            if ply:Team() == 0 then
                -- Легкая команда (не спавним, делаем наблюдателем)
                if ply:GetNWInt("LivesLeft", -1) == -1 then
                    ply:SetNWInt("LivesLeft", 3)
                end
                
                ply.LS_Prepping = true
                if ply:Alive() then ply:KillSilent() end -- Убиваем, чтобы перейти в спектаторы
            else
                -- Тяжелая команда (замораживаем, чтобы они не зарушили легких во время выбора)

                
                ply:SetNWInt("LivesLeft", 0)
                ply:SetSuppressPickupNotices(true)
                ply:SetPlayerClass("terrorist")
                zb.GiveRole(ply, "Heavy Unit", Color(0,0,122))
                ply:SetNetVar("CurPluv", "pluvblue")

                local wep = ply:Give(heavyWeps[math.random(#heavyWeps)])
                if IsValid(wep) then
                    ply:GiveAmmo(wep:GetMaxClip1() * 5, wep:GetPrimaryAmmoType(), true)
                end
                
                hg.AddArmor(ply, "ent_armor_helmet1")
                hg.AddArmor(ply, "ent_armor_vest4")

                ply:Give("weapon_bandage_sh")
                ply:Give("weapon_tourniquet")
                ply:Give("weapon_medkit_sh")
                ply:Give("weapon_fentanyl")

                local hands = ply:Give("weapon_hands_sh")
                if IsValid(hands) then
                    ply:SelectWeapon("weapon_hands_sh")
                end
                ply:SetSuppressPickupNotices(false)
            end
        end
    end)

    -- Ждем 6 секунд, чтобы вступительный текст успел показаться, а затем запускаем меню и таймер
    timer.Simple(6, function()
        -- Отправляем сигнал всем клиентам для отрисовки таймера
        net.Start("laststand_start_prep")
        net.Broadcast()

        -- Отправляем меню выбора лодаута лёгкой команде
        for _, ply in player.Iterator() do
            if IsValid(ply) and ply:Team() == 0 then
                net.Start("laststand_open_menu")
                net.Send(ply)
            end
        end

        -- Таймер: через 20 секунд спавним лёгких и размораживаем тяжёлых
        timer.Create("LastStand_LightLoadout", 20, 1, function()
            for _, ply in player.Iterator() do
                if IsValid(ply) then
                    if ply:Team() == 0 then
                        ply.LS_Prepping = false
                        ply:Spawn() -- Спавним лёгкого игрока
                        
                        local spawnsT = zb.TranslatePointsToVectors(zb.GetMapPoints("HMCD_TDM_T"))
                        if spawnsT and #spawnsT > 0 then
                            ply:SetPos(table.Random(spawnsT) + Vector(0,0,10))
                        end
                        
                        SetupLightPlayer(ply, ply.LS_SelectedWep, ply.LS_SelectedEq)
                        ply.HasSelectedLoadout = true
                        
                    elseif ply:Team() == 1 then
                        ply:Freeze(false) -- Размораживаем тяжёлых
                    end
                end
            end
        end)
    end)
end

net.Receive("laststand_select_loadout", function(len, ply)
    if not IsValid(ply) or ply:Team() != 0 then return end
    if ply.HasSelectedLoadout then return end

    local wepClass = net.ReadString()
    local eqClass = net.ReadString()

    local totalCost = 0
    for _, w in ipairs(LS_LightWeps) do
        if w.class == wepClass then totalCost = totalCost + w.cost break end
    end
    for _, e in ipairs(LS_LightEquip) do
        if e.class == eqClass then totalCost = totalCost + e.cost break end
    end

    -- Сохраняем выбор (выдадим после спавна)
    if totalCost <= 5 then
        ply.LS_SelectedWep = wepClass
        ply.LS_SelectedEq = eqClass
        ply.HasSelectedLoadout = true
    else
        ply.LS_SelectedWep = nil
        ply.LS_SelectedEq = "none"
        ply.HasSelectedLoadout = true
    end
end)

function MODE:RoundThink() end

function MODE:GetTeamSpawn()
    return zb.TranslatePointsToVectors(zb.GetMapPoints( "HMCD_TDM_T" )), zb.TranslatePointsToVectors(zb.GetMapPoints( "HMCD_TDM_CT" ))
end

function MODE:CanSpawn() end

function MODE:PlayerDeath(ply)
    -- Если лёгкий игрок умер во время подготовки (что вряд ли), игнорируем
    if ply.LS_Prepping then return end

    if ply:Team() == 0 then
        local lives = ply:GetNWInt("LivesLeft", 0)
        if lives > 0 then
            ply:SetNWInt("LivesLeft", lives - 1)
            timer.Simple(3, function()
                if IsValid(ply) and not ply:Alive() and ply:Team() == 0 and not ply.LS_Prepping then
                    ply:Spawn()
                    
                    local spawnsT = zb.TranslatePointsToVectors(zb.GetMapPoints("HMCD_TDM_T"))
                    if spawnsT and #spawnsT > 0 then
                        ply:SetPos(table.Random(spawnsT) + Vector(0,0,10))
                    end
                    
                    SetupLightPlayer(ply, ply.LS_SelectedWep, ply.LS_SelectedEq)
                end
            end)
        end
    elseif ply:Team() == 1 then
        -- Помечаем тяжёлого игрока как уничтоженного, чтобы раунд мог закончиться
        ply.LS_Eliminated = true
    end
end

function MODE:EndRound()
    timer.Remove("LastStand_LightLoadout")
    timer.Simple(2, function()
        net.Start("laststand_roundend")
        net.Broadcast()
    end)

    local endround, winner = zb:CheckWinner(self:CheckAlivePlayers())
    for k, ply in player.Iterator() do
        if ply:Team() == winner then
            ply:GiveExp(math.random(15,30))
            ply:GiveSkill(math.Rand(0.1,0.15))
        else
            ply:GiveSkill(-math.Rand(0.05,0.1))
        end
    end
end