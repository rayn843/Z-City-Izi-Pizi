COMMANDS.sendtospawn = {
	function(ply, args)
		if not ply:IsAdmin() then return end
		local plya = #args > 0 and args[1] or ply:Name()
		for i, ply2 in pairs(player.GetListByName(plya)) do
			if ply2:Alive() then
				ply2:Spawn()
				ply:ChatPrint( ply2:Name().. " | Sended to random spawn..." )
			end
		end
	end,
	0
}

COMMANDS.give = {
	function(ply, args)
		if not ply:IsAdmin() then return end
		local plya = #args > 1 and args[1] or ply:Name()
		local wep = #args > 1 and args[2] or args[1]
		for i, ply2 in pairs(player.GetListByName(plya)) do
			if ply2:Alive() then
				local ent = ply2:Give( wep )
                if not IsValid(ent) then return end

                ent:Use(ply2)
				ply:ChatPrint( ply2:Name().. " | Weapon given" )
			end
		end
	end,
	0
}

COMMANDS.respawn = {
	function(ply, args)
		if not ply:IsAdmin() then return end
		local plya = #args > 0 and args[1] or ply:Name()
		for i, ply2 in pairs(player.GetListByName(plya)) do
			ply2:Spawn()
            ApplyAppearance( ply2 )
			local hands = ply2:Give("weapon_hands_sh")
			ply2:SelectWeapon(hands)

			ply:ChatPrint( ply2:Name().. " | Respawned" )
		end
	end,
	0
}

local function ManageBotStatus()
    -- Используем небольшую задержку (0.1 сек). 
    -- При выходе игрока (PlayerDisconnected) он всё ещё числится в списке первую долю секунды. 
    -- Таймер нужен, чтобы функции получения списков игроков успели обновиться.
    timer.Simple(0.1, function()
        local humans = player.GetHumans()
        local bots = player.GetBots()
        local humanCount = #humans

        if humanCount == 1 then
            -- Если на сервере ровно 1 человек и нет ботов — добавляем бота
            if #bots == 0 then
                RunConsoleCommand("bot")
            end
        elseif humanCount >= 2 or humanCount == 0 then
            -- Если 2+ человека или сервер пуст — удаляем ботов
            for _, bot in ipairs(bots) do
                bot:Kick("Присоединился второй игрок (или сервер пуст)")
            end
        end
    end)
end

-- Хук срабатывает, когда игрок полностью загрузился на сервер
hook.Add("PlayerInitialSpawn", "AutoBot_PlayerJoin", function(ply)
    -- Игнорируем подключения самих ботов, чтобы избежать бесконечного цикла
    if ply:IsBot() then return end 
    ManageBotStatus()
end)

-- Хук срабатывает, когда игрок отключается
hook.Add("PlayerDisconnected", "AutoBot_PlayerLeave", function(ply)
    if ply:IsBot() then return end
    ManageBotStatus()
end)

hook.Add("PlayerInitialSpawn", "ZB_SaveSteamName", function(ply)
    -- Сохраняем оригинальный Steam-ник в сетевую переменную
    ply:SetNWString("OriginalSteamName", ply:Name())
end)