-- vrmod_pickup_fix.lua
-- Исправление ошибки: attempt to index local 't' (a nil value)

local function patchVRModPickup()
    local hooks = hook.GetTable()
    if not hooks or not hooks.Tick or not hooks.Tick.vrmod_pickup then return false end

    local func = hooks.Tick.vrmod_pickup
    local pickupList, drop

    -- Пытаемся извлечь локальные функции из оригинального хука
    local i = 1
    while true do
        local name, val = debug.getupvalue(func, i)
        if not name then break end
        if name == "pickupList" then pickupList = val end
        if name == "drop" then drop = val end
        i = i + 1
    end

    -- Если удалось получить доступ к переменным, ставим безопасный хук
    if pickupList and drop then
        hook.Add("Tick", "vrmod_pickup", function()
            -- Идем в обратном порядке, чтобы удаление элементов не ломало индексацию
            for i = #pickupList, 1, -1 do
                local t = pickupList[i]
                if t and (not IsValid(t.phys) or not t.phys:IsMoveable() or not g_VR[t.steamid] or not t.ply:Alive() or t.ply:InVehicle()) then
                    drop(t.steamid, t.left)
                end
            end
        end)
        print("[VRMod Patch] Ошибка vrmod_pickup успешно устранена!")
        return true
    end

    -- Если античит заблокировал debug.getupvalue, просто отключаем крашащий хук.
    -- Предметы не будут автосбрасываться при потере физики, но крашей больше не будет.
    hook.Remove("Tick", "vrmod_pickup")
    print("[VRMod Patch] debug.getupvalue недоступен. Крашащий хук был безопасно отключен.")
    return true
end

timer.Simple(5, function()
    if not patchVRModPickup() then
        timer.Create("VRModPickupPatchRetry", 5, 0, function()
            if patchVRModPickup() then
                timer.Remove("VRModPickupPatchRetry")
            end
        end)
    end
end)