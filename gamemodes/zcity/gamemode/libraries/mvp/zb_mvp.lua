-- zb_mvp.lua
-- Серверный файл: расчёт MVP раунда и отправка через net
-- Поместить в: gamemodes/zcity/gamemode/ (или куда загружаются серверные файлы)

if not SERVER then return end

-- Регистрируем net строку
util.AddNetworkString("zb_round_mvp")

-- Функция расчёта MVP — игрок с наибольшим ply.harm (суммарный урон за раунд)
-- Параметр: teamFilter (опционально) — номер команды, если нужно MVP только из одной команды
-- Возвращает: Player или nil
function zb.GetRoundMVP(teamFilter)
    local bestPly = nil
    local bestHarm = -1

    for _, ply in player.Iterator() do
        if ply:Team() == TEAM_SPECTATOR then continue end
        if not ply:Alive() and ply.harm == 0 then continue end
        if teamFilter and ply:Team() ~= teamFilter then continue end

        if (ply.harm or 0) > bestHarm then
            bestHarm = ply.harm or 0
            bestPly = ply
        end
    end

    return bestPly
end

-- Отправляет MVP указанному игроку (или всем, если toPly = nil)
function zb.SendRoundMVP(toPly, teamFilter)
    local mvp = zb.GetRoundMVP(teamFilter)

    net.Start("zb_round_mvp")
        if IsValid(mvp) then
            net.WriteEntity(mvp)
        else
            net.WriteEntity(Entity(0))
        end
    if IsValid(toPly) then
        net.Send(toPly)
    else
        net.Broadcast()
    end
end

-- Сброс harm всем игрокам (вызывать при старте раунда)
hook.Add("PlayerSpawn", "ZB_MVP_ResetHarm", function(ply)
    ply.harm = 0
end)