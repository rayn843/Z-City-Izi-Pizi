if SERVER then
    util.AddNetworkString("hg_vr_status")
    util.AddNetworkString("hg_vr_sync_ragdoll")

    -- Регистрация VR игрока на сервере
    net.Receive("hg_vr_status", function(len, ply)
        ply.UsingVR = net.ReadBool()
        if ply.UsingVR then
            ply:ChatPrint("[VR] Homigrad VR Ragdoll Control активирован.")
        end
    end)

    -- Прием позиций VR рук и головы от клиента
    net.Receive("hg_vr_sync_ragdoll", function(len, ply)
        if not ply.UsingVR then return end
        ply.VRRagdollData = {
            HMDPos = net.ReadVector(),
            HMDAng = net.ReadAngle(),
            RPos = net.ReadVector(),
            RAng = net.ReadAngle(),
            LPos = net.ReadVector(),
            LAng = net.ReadAngle(),
            RGrip = net.ReadBool(),
            LGrip = net.ReadBool()
        }
    end)

    -- Отключаем стандартное управление рагдоллом для VR игроков
    -- Это предотвращает конфликты с клавишами IN_SPEED и IN_WALK
    hook.Add("CanControlFake", "VR_DisableDefaultFakeControl", function(ply, rag)
        if ply.UsingVR then return false end
    end)

    -- Локальная функция для получения физ-объекта кости
    local function getPhys(rag, boneName)
        local boneId = rag:LookupBone(boneName)
        if not boneId then return NULL end
        local physId = rag:TranslateBoneToPhysBone(boneId)
        if physId == -1 then return NULL end
        return rag:GetPhysicsObjectNum(physId)
    end

    -- Основной цикл управления рагдоллом для VR
    hook.Add("Think", "VR_Ragdoll_Physics_Control", function()
        for _, ply in ipairs(player.GetHumans()) do
            if not ply.UsingVR or not ply.VRRagdollData then continue end
            
            local rag = ply.FakeRagdoll
            if not IsValid(rag) then continue end

            local data = ply.VRRagdollData
            rag.dtime = (SysTime() - (rag.lastCallTime or SysTime())) * game.GetTimeScale()
            rag.lastCallTime = SysTime()
            rag.power = 1 -- VR игроки всегда имеют полный контроль

            -- 1. Синхронизация позиции камеры игрока с головой рагдолла
            local headPhys = getPhys(rag, "ValveBiped.Bip01_Head1")
            if IsValid(headPhys) then
                local headPos = headPhys:GetPos()
                -- Телепортируем игрока к голове, чтобы камера следовала за рагдоллом
                if ply:GetPos():Distance(headPos) > 10 then
                    ply:SetPos(headPos)
                end
            end

            -- 2. Управление руками (1:1 трекинг)
            local function controlHand(boneName, targetPos, targetAng, isGripping, side)
                local phys = getPhys(rag, boneName)
                if not IsValid(phys) then return end

                -- Если игрок сжал grip (кувалду/триггер) в VR, привариваем руку к миру/объекту
                if isGripping and not IsValid(rag["Cons"..side]) then
                    local tr = util.TraceLine({
                        start = targetPos,
                        endpos = targetPos + targetAng:Forward() * 10,
                        filter = rag
                    })
                    
                    if tr.Hit then
                        local physId = rag:TranslateBoneToPhysBone(rag:LookupBone(boneName))
                        local cons = constraint.Weld(rag, tr.Entity, physId, tr.PhysicsBone, tr.Entity:IsWorld() and 10000 or 0, false, false)
                        if IsValid(cons) then
                            rag["Cons"..side] = cons
                            rag:EmitSound("physics/body/body_medium_impact_soft"..math.random(1,7)..".wav", 50, 100)
                        end
                    end
                elseif not isGripping and IsValid(rag["Cons"..side]) then
                    -- Отпустили хват — удаляем сварку
                    rag["Cons"..side]:Remove()
                    rag["Cons"..side] = nil
                end

                -- Если рука не приварена, двигаем её к позиции контроллера VR
                if not IsValid(rag["Cons"..side]) then
                    local p = {
                        secondstoarrive = 0.01,
                        pos = targetPos,
                        angle = targetAng,
                        maxangular = 2500,
                        maxangulardamp = 250,
                        maxspeed = 2500,
                        maxspeeddamp = 250,
                        teleportdistance = 100, -- Защита от застревания в стенах
                    }
                    phys:Wake()
                    phys:ComputeShadowControl(p)
                end
            end

            -- Управляем правой и левой рукой
            controlHand("ValveBiped.Bip01_R_Hand", data.RPos, data.RAng, data.RGrip, "RH")
            controlHand("ValveBiped.Bip01_L_Hand", data.LPos, data.LAng, data.LGrip, "LH")

            -- 3. Ползание (Locomotion)
            -- Если VR игрок двигает стиком (преобразуется в IN_FORWARD/IN_BACK), толкаем торс
            local torsoPhys = getPhys(rag, "ValveBiped.Bip01_Spine2")
            if IsValid(torsoPhys) then
                local aimVec = ply:EyeAngles():Forward()
                aimVec.z = 0
                aimVec:Normalize()

                local vel = rag:GetVelocity()
                
                if ply:KeyDown(IN_FORWARD) then
                    local force = aimVec * 2000 * rag.dtime / 0.015
                    -- Чем быстрее ползем, тем меньше добавочной силы (защита от разгона)
                    force = force * (1 / math.max(torsoPhys:GetVelocity():Dot(aimVec) / 25, 1))
                    torsoPhys:ApplyForceCenter(force)
                elseif ply:KeyDown(IN_BACK) then
                    local force = -aimVec * 1500 * rag.dtime / 0.015
                    torsoPhys:ApplyForceCenter(force)
                end
            end

            -- 4. Вставание
            if ply:KeyPressed(IN_JUMP) then
                hg.FakeUp(ply)
            end
        end
    end)

else -- CLIENT
    -- Отправляем статус VR на сервер при входе/смене режима
    hook.Add("InitPostEntity", "VR_SendStatus", function()
        timer.Simple(2, function()
            local inVR = VRMod and VRMod.IsPlayerInVR and VRMod.IsPlayerInVR(LocalPlayer())
            net.Start("hg_vr_status")
            net.WriteBool(inVR or false)
            net.SendToServer()
        end)
    end)

    -- Постоянная отправка позиций VR контроллеров на сервер
    hook.Add("Think", "VR_SendRagdollData", function()
        if not (VRMod and VRMod.IsPlayerInVR and VRMod.IsPlayerInVR(LocalPlayer())) then return end
        if not IsValid(LocalPlayer().FakeRagdoll) then return end

        -- Берем позиции прямо из VRMod
        local hmdPos, hmdAng = VRMod.GetHMDPos(), VRMod.GetHMDAng()
        local rPos, rAng = VRMod.GetRightHandPos(), VRMod.GetRightHandAng()
        local lPos, lAng = VRMod.GetLeftHandPos(), VRMod.GetLeftHandAng()

        -- Определяем, зажат ли хват (Grip) на контроллерах
        -- В VRMod обычно IN_ATTACK это триггер, IN_ATTACK2 или IN_USE это Grip. 
        -- Проверяем несколько вариантов для совместимости
        local rGrip = LocalPlayer():KeyDown(IN_ATTACK2) or LocalPlayer():KeyDown(IN_USE)
        local lGrip = LocalPlayer():KeyDown(IN_SPEED) or LocalPlayer():KeyDown(IN_WALK)

        net.Start("hg_vr_sync_ragdoll")
            net.WriteVector(hmdPos or Vector())
            net.WriteAngle(hmdAng or Angle())
            net.WriteVector(rPos or Vector())
            net.WriteAngle(rAng or Angle())
            net.WriteVector(lPos or Vector())
            net.WriteAngle(lAng or Angle())
            net.WriteBool(rGrip or false)
            net.WriteBool(lGrip or false)
        net.SendToServer()
    end)
end