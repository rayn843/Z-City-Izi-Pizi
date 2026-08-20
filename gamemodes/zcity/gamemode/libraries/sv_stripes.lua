util.AddNetworkString("ZB_SetTabStripe")
util.AddNetworkString("ZB_BuyStripe")

-- Цены на полоски (должны совпадать с теми, что в cl_init.lua)
ZB_StripePrices = {
    ["gold"] = 250,
    ["neon_blue"] = 250,
    ["toxic_green"] = 250,
    ["test"] = 500,
    ["testgif"] = 1000,
    ["flame"] = 1000,
}

-- Выдача валюты и загрузка данных при заходе
hook.Add("PlayerInitialSpawn", "ZB_InitIzi", function(ply)
    timer.Simple(2, function()
        if not IsValid(ply) then return end
        
        -- Загрузка валюты
        local izi = ply:GetPData("izi", 0)
        ply:SetNWInt("izi", tonumber(izi))

        -- Загрузка купленных полосок
        local stripes = util.JSONToTable(ply:GetPData("zb_stripes", "[]")) or {}
        for _, id in ipairs(stripes) do
            ply:SetNWBool("owns_stripe_" .. id, true)
        end

        -- Восстановление активной полоски
        local savedStripe = ply:GetPData("TabStripe", "")
        if savedStripe != "" then
            ply:SetNWString("TabStripe", savedStripe)
        end
    end)
end)

-- Таймер: выдача 5 izi монет в минуту игрокам с Premium
timer.Create("ZB_PremiumIziReward", 60, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:GetUserGroup() == "premium" then
            local currentIzi = ply:GetNWInt("izi", 0)
            local newIzi = currentIzi + 5
            
            ply:SetNWInt("izi", newIzi)
            ply:SetPData("izi", newIzi)
        end
    end
end)

concommand.Add("zb_giveizi", function(ply, cmd, args)
    local isAdmin = IsValid(ply) and ply:IsAdmin()
    local isServer = not IsValid(ply) -- Если вызвано из серверной консоли

    if not (isAdmin or isServer) then return end

    local targetStr = args[1]
    local amount = tonumber(args[2]) -- Преобразуем в число

    -- Железобетонная проверка
    if not targetStr or not amount or amount <= 0 then
        local msg = "Использование: zb_giveizi <ник / steamid / userid> <кол-во>"
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
        return
    end

    -- 1. Сначала ищем игрока среди тех, кто онлайн
    local target = nil
    for _, v in ipairs(player.GetAll()) do
        if string.lower(v:Nick()) == string.lower(targetStr) or v:SteamID() == targetStr or tostring(v:UserID()) == targetStr then
            target = v
            break
        end
    end

    -- 2. Если игрок онлайн — выдаем через NWVar и PData
    if IsValid(target) then
        target:SetNWInt("izi", target:GetNWInt("izi", 0) + amount)
        target:SetPData("izi", target:GetNWInt("izi"))
        
        target:ChatPrint("Вы получили " .. amount .. " izi!")
        if IsValid(ply) and ply != target then
            ply:ChatPrint("Выдано " .. amount .. " izi игроку " .. target:Nick())
        else
            print("Выдано " .. amount .. " izi игроку " .. target:Nick())
        end
        return
    end

    -- 3. Если игрок НЕ онлайн — проверяем, является ли введенный текст SteamID
    if string.find(targetStr, "^STEAM_[0-5]:[0-1]:%d+$") then
        local infoid = targetStr .. "_izi"
        local result = sql.Query("SELECT value FROM playerpdata WHERE infoid = " .. sql.SQLStr(infoid))
        
        local currentVal = 0
        if result and result[1] then
            currentVal = tonumber(result[1].value) or 0
        end
        
        local newVal = currentVal + amount

        if result and result[1] then
            sql.Query("UPDATE playerpdata SET value = " .. sql.SQLStr(newVal) .. " WHERE infoid = " .. sql.SQLStr(infoid))
        else
            sql.Query("INSERT INTO playerpdata (infoid, type, value) VALUES (" .. sql.SQLStr(infoid) .. ", 'int', " .. sql.SQLStr(newVal) .. ")")
        end

        local msg = "Успешно выдано " .. amount .. " izi оффлайн-игроку " .. targetStr .. ". Новый баланс: " .. newVal
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
    else
        local msg = "Игрок не найден онлайн, и введенный текст не является SteamID! (Формат: STEAM_0:1:...)"
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
    end
end)

-- Установка полоски
net.Receive("ZB_SetTabStripe", function(len, ply)
    local stripeID = net.ReadString()
    if stripeID == "default" then stripeID = "" end
    
    -- Проверка, куплена ли полоска
    if stripeID != "" and not ply:GetNWBool("owns_stripe_" .. stripeID, false) then
        ply:ChatPrint("Вы не купили эту полоску!")
        return
    end
    
    ply:SetNWString("TabStripe", stripeID)
    ply:SetPData("TabStripe", stripeID)
end)

-- Покупка полоски
net.Receive("ZB_BuyStripe", function(len, ply)
    local id = net.ReadString()
    local price = ZB_StripePrices[id] or 0

    if price <= 0 then return end
    if ply:GetNWBool("owns_stripe_" .. id, false) then return end -- Уже куплено

    local currentIzi = ply:GetNWInt("izi", 0)
    if currentIzi >= price then
        -- Списываем валюту
        ply:SetNWInt("izi", currentIzi - price)
        ply:SetPData("izi", ply:GetNWInt("izi"))

        -- Выдаем полоску навсегда
        ply:SetNWBool("owns_stripe_" .. id, true)

        -- Сохраняем в базу
        local stripes = util.JSONToTable(ply:GetPData("zb_stripes", "[]")) or {}
        if not table.HasValue(stripes, id) then
            table.insert(stripes, id)
            ply:SetPData("zb_stripes", util.TableToJSON(stripes))
        end

        -- Автоматически надеваем
        ply:SetNWString("TabStripe", id)
        ply:SetPData("TabStripe", id)

        ply:ChatPrint("Вы успешно купили полоску за " .. price .. " izi!")
    else
        ply:ChatPrint("Недостаточно izi для покупки!")
    end
end)