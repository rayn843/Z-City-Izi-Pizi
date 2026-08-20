local MODE = MODE
MODE.name = "hmcd"

--\\Local Functions
local function screen_scale_2(num)
    return ScreenScale(num) / (ScrW() / ScrH())
end
--//

MODE.TypeSounds = {
    ["standard"] = {"snd_jack_hmcd_psycho.mp3","snd_jack_hmcd_shining.mp3"},
    ["soe"] = "snd_jack_hmcd_disaster.mp3",
    ["gunfreezone"] = "snd_jack_hmcd_panic.mp3" ,
    ["suicidelunatic"] = "zbattle/jihadmode.mp3",
    ["wildwest"] = "snd_jack_hmcd_wildwest.mp3",
    ["supermario"] = "snd_jack_hmcd_psycho.mp3"
}
local fade = 0
net.Receive("HMCD_RoundStart",function()
    for i, ply in player.Iterator() do
        ply.isTraitor = false
        ply.isGunner = false
    end

    RemoveEndRoundStatsPanel()

    --\\
    lply.isTraitor = net.ReadBool()
    lply.isGunner = net.ReadBool()
    MODE.Type = net.ReadString()
    local screen_time_is_default = net.ReadBool()
    lply.SubRole = net.ReadString()
    lply.MainTraitor = net.ReadBool()
    MODE.TraitorWord = net.ReadString()
    MODE.TraitorWordSecond = net.ReadString()
    MODE.TraitorExpectedAmt = net.ReadUInt(MODE.TraitorExpectedAmtBits)
    StartTime = CurTime()
    MODE.TraitorsLocal = {}
    MODE.RevealSounds = {} -- Сбрасываем звуки при старте раунда

    -- Сохраняем текущие значения skill и exp для расчета полученных за раунд
    lply.oldSkill = lply.skill or 0
    lply.oldExp = lply.exp or 0

    if(lply.isTraitor and screen_time_is_default)then
        if(MODE.TraitorExpectedAmt == 1)then
            chat.AddText("You are alone on your mission.")
        else
            if(MODE.TraitorExpectedAmt == 2)then
                chat.AddText("You have 1 accomplice")
            else
                chat.AddText("There are(is) " .. MODE.TraitorExpectedAmt - 1 .. " traitor(s) besides you")
            end

            chat.AddText("Traitor secret words are: \"" .. MODE.TraitorWord .. "\" and \"" .. MODE.TraitorWordSecond .. "\".")
        end

        if(lply.MainTraitor)then
            if(MODE.TraitorExpectedAmt > 1)then
                chat.AddText("Traitor names (only you, as a main traitor can see them):")
            end

            for key = 1, MODE.TraitorExpectedAmt do
                local traitor_info = {net.ReadColor(false), net.ReadString()}

                if(MODE.TraitorExpectedAmt > 1)then
                    MODE.TraitorsLocal[#MODE.TraitorsLocal + 1] = traitor_info

                    chat.AddText(traitor_info[1], "\t" .. traitor_info[2])
                end
            end
        end
    end

    lply.Profession = net.ReadString()
    --//

    if(MODE.RoleChooseRoundTypes[MODE.Type] and !screen_time_is_default)then
        MODE.DynamicFadeScreenEndTime = CurTime() + MODE.RoleChooseRoundStartTime
    else
        MODE.DynamicFadeScreenEndTime = CurTime() + MODE.DefaultRoundStartTime
    end

    MODE.RoleEndedChosingState = screen_time_is_default

    if(screen_time_is_default)then
        if istable(MODE.TypeSounds[MODE.Type]) then
            surface.PlaySound(table.Random(MODE.TypeSounds[MODE.Type]))
        else
            surface.PlaySound(MODE.TypeSounds[MODE.Type])
        end
    end

    fade = 0
end)

MODE.TypeNames = {
    ["standard"] = "Standard",
    ["soe"] = "State of Emergency",
    ["gunfreezone"] = "Gun Free Zone",
    ["suicidelunatic"] = "Suicide Lunatic",
    ["wildwest"] = "Wild west",
    ["supermario"] = "Super Mario"
}

--local hg_coolvetica = ConVarExists("hg_coolvetica") and GetConVar("hg_coolvetica") or CreateClientConVar("hg_coolvetica", "0", true, false, "changes every text to coolvetica because its good", 0, 1)
local hg_font = ConVarExists("hg_font") and GetConVar("hg_font") or CreateClientConVar("hg_font", "Bahnschrift", true, false, "Change UI text font")
local font = function() -- hg_coolvetica:GetBool() and "Coolvetica" or "Bahnschrift"
    local usefont = "Bahnschrift"

    if hg_font:GetString() != "" then
        usefont = hg_font:GetString()
    end

    return usefont
end

surface.CreateFont("ZB_HomicideSuperSuperSmall", {
    font = font(),
    size = ScreenScale(5),
    weight = 400,
    antialias = true
})

surface.CreateFont("ZB_HomicideSuperSmall", {
    font = font(),
    size = ScreenScale(10),
    weight = 400,
    antialias = true
})

surface.CreateFont("ZB_HomicideSmall", {
    font = font(),
    size = ScreenScale(15),
    weight = 400,
    antialias = true
})

surface.CreateFont("ZB_HomicideMedium", {
    font = font(),
    size = ScreenScale(15),
    weight = 400,
    antialias = true
})

surface.CreateFont("ZB_HomicideMediumLarge", {
    font = font(),
    size = ScreenScale(25),
    weight = 400,
    antialias = true
})

surface.CreateFont("ZB_HomicideLarge", {
    font = font(),
    size = ScreenScale(30),
    weight = 400,
    antialias = true
})

surface.CreateFont("ZB_HomicideHumongous", {
    font = font(),
    size = 255,
    weight = 400,
    antialias = true
})

MODE.TypeObjectives = {}
MODE.TypeObjectives.soe = {
    traitor = {
        objective = "You're geared up with items, poisons, explosives and weapons hidden in your pockets. Murder everyone here.",
        name = "a Traitor",
        color1 = Color(190,0,0),
        color2 = Color(190,0,0)
    },

    gunner = {
        objective = "You are an innocent with a hunting weapon. Find and neutralize the traitor before it's too late.",
        name = "an Innocent",
        color1 = Color(0,120,190),
        color2 = Color(158,0,190)
    },

    innocent = {
        objective = "You are an innocent, rely only on yourself, but stick around with crowds to make traitor's job harder.",
        name = "an Innocent",
        color1 = Color(0,120,190)
    },
}

MODE.TypeObjectives.standard = {
    traitor = {
        objective = "You're geared up with items, poisons, explosives and weapons hidden in your pockets. Murder everyone here.",
        name = "a Murderer",
        color1 = Color(190,0,0),
        color2 = Color(190,0,0)
    },

    gunner = {
        objective = "You are a bystander with a concealed firearm. You've tasked yourself to help police find the criminal faster.",
        name = "a Bystander",
        color1 = Color(0,120,190),
        color2 = Color(158,0,190)
    },

    innocent = {
        objective = "You are a bystander of a murder scene, although it didn't happen to you, you better be cautious.",
        name = "a Bystander",
        color1 = Color(0,120,190)
    },
}

MODE.TypeObjectives.wildwest = {
    traitor = {
        objective = "This town ain't that big for all of us.",
        name = "The Killer",
        color1 = Color(190,0,0),
        color2 = Color(190,0,0)
    },

    gunner = {
        objective = "You're the sheriff of this town. You gotta find and kill the lawless bastard.",
        name = "The Sheriff",
        color1 = Color(0,120,190),
        color2 = Color(158,0,190)
    },

    innocent = {
        objective = "We gotta get justice served over here, there's a lawless prick murdering men.",
        name = "a Fellow Cowboy",
        color1 = Color(0,120,190),
        color2 = Color(158,0,190)
    },
}

MODE.TypeObjectives.gunfreezone = {
    traitor = {
        objective = "You're geared up with items, poisons, explosives and weapons hidden in your pockets. Murder everyone here.",
        name = "a Murderer",
        color1 = Color(190,0,0),
        color2 = Color(190,0,0)
    },

    gunner = {
        objective = "You are a bystander of a murder scene, although it didn't happen to you, you better be cautious.",
        name = "a Bystander",
        color1 = Color(0,120,190)
    },

    innocent = {
        objective = "You are a bystander of a murder scene, although it didn't happen to you, you better be cautious.",
        name = "a Bystander",
        color1 = Color(0,120,190)
    },
}

MODE.TypeObjectives.suicidelunatic = {
    traitor = {
        objective = "My brother insha'Allah, don't let him down.",
        name = "a Shahid",
        color1 = Color(190,0,0),
        color2 = Color(190,0,0)
    },

    gunner = {
        objective = "Sheep fucker's gone crazy, now you need to survive.",
        name = "an Innocent",
        color1 = Color(0,120,190)
    },

    innocent = {
        objective = "Sheep fucker's gone crazy, now you need to survive.",
        name = "an Innocent",
        color1 = Color(0,120,190)
    },
}


MODE.TypeObjectives.supermario = {
    traitor = {
        objective = "You're the evil Mario! Jump around and take down everyone.",
        name = "Traitor Mario",
        color1 = Color(190,0,0),
        color2 = Color(190,0,0)
    },

    gunner = {
        objective = "You're the hero Mario! Use your jumping ability to stop the traitor.",
        name = "Hero Mario",
        color1 = Color(158,0,190),
        color2 = Color(158,0,190)
    },

    innocent = {
        objective = "You're a bystander Mario, survive and avoid the traitor's traps!",
        name = "Innocent Mario",
        color1 = Color(0,120,190)
    },
}

function MODE:RenderScreenspaceEffects()
    fade_end_time = MODE.DynamicFadeScreenEndTime or 0
    local time_diff = fade_end_time - CurTime()

    if(time_diff > 0)then
        zb.RemoveFade()

        local fade = math.min(time_diff / (MODE.FadeScreenTime or 2), 1)

        surface.SetDrawColor(0, 0, 0, 255 * fade)
        surface.DrawRect(-1, -1, ScrW() + 1, ScrH() + 1 )
    end
end

local handicap = {
    [1] = "You are handicapped: your right leg is broken.",
    [2] = "You are handicapped: you are suffering from severe obesity.",
    [3] = "You are handicapped: you are suffering from hemophilia.",
    [4] = "You are handicapped: you are physically incapacitated."
}

-- Вспомогательная функция для получения прозрачности на стадии
local function getStageAlpha(timeElapsed, t, globalFade)
    return math.Clamp((timeElapsed - t) / 0.3, 0, 1) * globalFade
end

function MODE:HUDPaint()
    if not MODE.Type or not MODE.TypeObjectives[MODE.Type] then return end
    if lply:Team() == TEAM_SPECTATOR then return end
    if StartTime + 12 < CurTime() then return end
    
    local timeElapsed = CurTime() - StartTime
    local maxTime = 6 -- Общее время отображения UI (в секундах)
    
    -- Перестаем рисовать, если время вышло
    if timeElapsed > maxTime then return end
    
    -- Глобальное появление и затухание (0 до 0.5 сек появление, с 4.5 до 6 сек затухание)
    local globalFade = 1
    if timeElapsed < 0.5 then
        globalFade = timeElapsed / 0.5
    elseif timeElapsed > 4.5 then
        globalFade = math.Clamp(1 - (timeElapsed - 4.5) / 1.5, 0, 1)
    end
    
    -- 1. Улучшенный фон
    -- Базовый цвет фона в зависимости от роли
    local bgColor = lply.isTraitor and Color(20, 0, 0, 255 * globalFade) or Color(0, 10, 20, 255 * globalFade)
    surface.SetDrawColor(bgColor)
    surface.DrawRect(0, 0, ScrW(), ScrH())
    
    -- Добавляем виньетку/градиент для атмосферы
    local mat = Material("vgui/gradient-d")
    surface.SetMaterial(mat)
    surface.SetDrawColor(0, 0, 0, 200 * globalFade)
    surface.DrawTexturedRect(0, 0, ScrW(), ScrH())
    
    -- 2. Настройки стадий
    local a_title = getStageAlpha(timeElapsed, 0.5, globalFade)
    local a_role = getStageAlpha(timeElapsed, 1.5, globalFade)
    local a_extra = getStageAlpha(timeElapsed, 2.5, globalFade)
    local a_obj = getStageAlpha(timeElapsed, 3.5, globalFade)
    
    -- Звуки появления
    MODE.RevealSounds = MODE.RevealSounds or {}
    local function playStageSound(t, snd)
        if timeElapsed >= t and not MODE.RevealSounds[t] then
            surface.PlaySound(snd)
            MODE.RevealSounds[t] = true
        end
    end
    
    -- 3. Рисуем Верхний Текст (Title)
    if a_title > 0 then
        draw.SimpleText("Homicide | " .. (MODE.TypeNames[MODE.Type] or "Unknown"), "ZB_HomicideMediumLarge", sw * 0.5, sh * 0.1, Color(0,162,255, 255 * a_title), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        playStageSound(0.5, "arccw_uc/common/10x25/fire-dist-10x25-pistol-ext-01.ogg")
    end
    
    -- 4. Рисуем Роль
    local Rolename = ( lply.isTraitor and MODE.TypeObjectives[MODE.Type].traitor.name ) or ( lply.isGunner and MODE.TypeObjectives[MODE.Type].gunner.name ) or MODE.TypeObjectives[MODE.Type].innocent.name
    local ColorRole = ( lply.isTraitor and MODE.TypeObjectives[MODE.Type].traitor.color1 ) or ( lply.isGunner and MODE.TypeObjectives[MODE.Type].gunner.color1 ) or MODE.TypeObjectives[MODE.Type].innocent.color1
    
    if a_role > 0 then
        ColorRole.a = 255 * a_role
        draw.SimpleText("You are "..Rolename , "ZB_HomicideMediumLarge", sw * 0.5, sh * 0.5, ColorRole, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        playStageSound(1.5, "arccw_uc/common/10x25/fire-dist-10x25-pistol-ext-01.ogg")
    end
    
    -- 5. Рисуем Дополнительную информацию (Слова, Профессия и т.д.)
    local cur_y = sh * 0.5
    local color_white_faded = Color(255, 255, 255, 255 * a_extra)
    local color_role_innocent = MODE.TypeObjectives[MODE.Type].innocent.color1
    color_role_innocent.a = 255 * a_extra
    
    if a_extra > 0 then
        playStageSound(2.5, "arccw_uc/common/10x25/fire-dist-10x25-pistol-ext-01.ogg")
        
        if(lply.SubRole and lply.SubRole != "")then
            cur_y = cur_y + ScreenScale(20)
            draw.SimpleText("" .. ((MODE.SubRoles[lply.SubRole] and MODE.SubRoles[lply.SubRole].Name or lply.SubRole) or lply.SubRole), "ZB_HomicideMediumLarge", sw * 0.5, cur_y, ColorRole, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        if(!lply.MainTraitor and lply.isTraitor)then
            cur_y = cur_y + ScreenScale(20)
            draw.SimpleText("Assistant", "ZB_HomicideMedium", sw * 0.5, cur_y, ColorRole, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        if(lply.isTraitor)then
            cur_y = cur_y + ScreenScale(20)
            if(lply.MainTraitor)then
                MODE.TraitorsLocal = MODE.TraitorsLocal or {}
                if(#MODE.TraitorsLocal > 1)then
                    draw.SimpleText("Traitors list:", "ZB_HomicideMedium", sw * 0.5, cur_y, ColorRole, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    for _, traitor_info in ipairs(MODE.TraitorsLocal) do
                        local traitor_color = Color(traitor_info[1].r, traitor_info[1].g, traitor_info[1].b, 255 * a_extra)
                        cur_y = cur_y + ScreenScale(15)
                        draw.SimpleText(traitor_info[2], "ZB_HomicideMedium", sw * 0.5, cur_y, traitor_color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    end
                end
            else
                draw.SimpleText("Traitor secret words:", "ZB_HomicideMedium", sw * 0.5, cur_y, ColorRole, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                cur_y = cur_y + ScreenScale(15)
                draw.SimpleText("\"" .. MODE.TraitorWord .. "\"", "ZB_HomicideMedium", sw * 0.5, cur_y, color_white_faded, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                cur_y = cur_y + ScreenScale(15)
                draw.SimpleText("\"" .. MODE.TraitorWordSecond .. "\"", "ZB_HomicideMedium", sw * 0.5, cur_y, color_white_faded, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end

        if(lply.Profession and lply.Profession != "")then
            cur_y = cur_y + ScreenScale(20)
            draw.SimpleText("Occupation: " .. ((MODE.Professions[lply.Profession] and MODE.Professions[lply.Profession].Name or lply.Profession) or lply.Profession), "ZB_HomicideMedium", sw * 0.5, cur_y, color_role_innocent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        
        if(handicap[lply:GetLocalVar("karma_sickness", 0)])then
            cur_y = cur_y + ScreenScale(20)
            draw.SimpleText(handicap[lply:GetLocalVar("karma_sickness", 0)], "ZB_HomicideMedium", sw * 0.5, cur_y, color_role_innocent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
    
    -- 6. Рисуем Нижний Текст (Objective)
    local Objective = ( lply.isTraitor and MODE.TypeObjectives[MODE.Type].traitor.objective ) or ( lply.isGunner and MODE.TypeObjectives[MODE.Type].gunner.objective ) or MODE.TypeObjectives[MODE.Type].innocent.objective

    if(lply.SubRole and lply.SubRole != "")then
        if(MODE.SubRoles[lply.SubRole] and MODE.SubRoles[lply.SubRole].Objective)then
            Objective = MODE.SubRoles[lply.SubRole].Objective
        end
    end

    if(!lply.MainTraitor and lply.isTraitor)then
        Objective = "You are equipped with nothing. Help other traitors win."
    end

    if(!MODE.RoleEndedChosingState)then
        Objective = "Round is starting..."
    end

    local ColorObj = ( lply.isTraitor and MODE.TypeObjectives[MODE.Type].traitor.color2 ) or ( lply.isGunner and MODE.TypeObjectives[MODE.Type].gunner.color2 ) or MODE.TypeObjectives[MODE.Type].innocent.color2 or Color(255,255,255)
    
    if a_obj > 0 then
        ColorObj.a = 255 * a_obj
        draw.SimpleText( Objective, "ZB_HomicideMedium", sw * 0.5, sh * 0.9, ColorObj, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        playStageSound(3.5, "arccw_uc/common/10x25/fire-dist-10x25-pistol-ext-01.ogg") -- Звук завершения появления текста
    end
    
    -- PluvTown Madness
    if a_extra > 0 and hg.PluvTown.Active then
        surface.SetMaterial(hg.PluvTown.PluvMadness)
        surface.SetDrawColor(255, 255, 255, math.random(175, 255) * a_extra / 2)
        surface.DrawTexturedRect(sw * 0.25, sh * 0.44 - ScreenScale(15), sw / 2, ScreenScale(30))

        draw.SimpleText("SOMEWHERE IN PLUVTOWN", "ZB_ScrappersLarge", sw / 2, sh * 0.44 - ScreenScale(2), Color(0, 0, 0, 255 * a_extra), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end

local CreateEndMenu

--\\ Панели завершения раунда
HMCD_EndStatsPanel = nil

function RemoveEndRoundStatsPanel()
    if IsValid(HMCD_EndStatsPanel) then
        HMCD_EndStatsPanel:Remove()
        HMCD_EndStatsPanel = nil
    end
end

local colGray = Color(122,122,122,255)
local colBlue = Color(130,10,10)
local colBlueUp = Color(160,30,30)
local col = Color(255,255,255,255)

local colSpect1 = Color(75,75,75,255)
local colSpect2 = Color(85,85,85,255)

local function CreateEndRoundStatsPanel()
    RemoveEndRoundStatsPanel()

    if not IsValid(lply) then return end

    -- Запрашиваем актуальные данные с сервера
    net.Start("zb_xp_get")
        net.WriteEntity(lply)
    net.SendToServer()

    local padding = ScreenScale(4)
    
    -- Размеры блоков согласно скриншоту
    local topW = ScreenScale(210)   -- Широкая верхняя плашка
    local topH = ScreenScale(32)    -- Высота верхней плашки
    
    local medalW = ScreenScale(52)  -- Вертикальный блок медали
    local medalH = ScreenScale(105) -- Высота блока медали

    -- НОВЫЕ ПЕРЕМЕННЫЕ ПОЗИЦИИ (Смещение вниз и вправо)
    -- Меняйте число 15, если нужно сдвинуть панель еще дальше или ближе
    local posX = padding + ScreenScale(25)
    local posY = padding + ScreenScale(25)

    HMCD_EndStatsPanel = vgui.Create("DPanel")
    -- Используем новые переменные вместо padding, padding
    HMCD_EndStatsPanel:SetPos(posX, posY)
    HMCD_EndStatsPanel:SetSize(topW, topH + medalH + padding)
    HMCD_EndStatsPanel:MakePopup()
    HMCD_EndStatsPanel:SetKeyboardInputEnabled(false)
    HMCD_EndStatsPanel:SetMouseInputEnabled(false)

    HMCD_EndStatsPanel.Paint = function(self, pw, ph) end

    -- Панель 1: Верхняя горизонтальная плашка (Аватар + Ник / Заголовок)
    local pnl1 = vgui.Create("DPanel", HMCD_EndStatsPanel)
    pnl1:SetPos(0, 0)
    pnl1:SetSize(topW, topH)
    pnl1.Paint = function(self, pw, ph)
        draw.RoundedBox(0, 0, 0, pw, ph, Color(20, 20, 20, 220))
        surface.SetDrawColor(255, 0, 0, 100)
        surface.DrawOutlinedRect(0, 0, pw, ph, 1)
        surface.SetDrawColor(colBlueUp.r, colBlueUp.g, colBlueUp.b, colBlueUp.a)
        surface.SetDrawColor(colBlue.r, colBlue.g, colBlue.b, colBlue.a)
        surface.DrawRect(0, 0, pw, ph)
        surface.SetDrawColor(colBlueUp.r, colBlueUp.g, colBlueUp.b, colBlueUp.a)
        surface.DrawRect(5, 35, pw - 10, (ph / 1.65) - 5)
    end

    local avatarSize = topH - ScreenScale(4)
    local avatar = vgui.Create("AvatarImage", pnl1)
    avatar:SetSize(avatarSize, avatarSize)
    avatar:SetPos(ScreenScale(2), ScreenScale(2))
    avatar:SetPlayer(lply, 64)

    local textX = avatarSize + ScreenScale(6)

    -- Маленький верхний текст ("MVP: Nick")
    local topLbl = vgui.Create("DLabel", pnl1)
    topLbl:SetPos( textX, ScreenScale(2))
    topLbl:SetFont("ZB_HomicideSuperSuperSmall")
    topLbl:SetTextColor(Color(137, 137, 137))
    topLbl:SetText("MVP: " .. "Wait for stats...")
    topLbl:SizeToContents()

    -- Большой нижний текст (Никнейм)
    local mainLbl = vgui.Create("DLabel", pnl1)
    mainLbl:SetPos(textX, ScreenScale(4))
    mainLbl:SetFont("ZB_HomicideLarge")
    mainLbl:SetTextColor(Color(255, 255, 255))
    mainLbl:SetText(lply:Nick())
    mainLbl:SizeToContents()

    -- Панель 2: Вертикальная карточка медали (снизу слева)
    local pnl2 = vgui.Create("DPanel", HMCD_EndStatsPanel)
    pnl2:SetPos(0, topH + padding)
    pnl2:SetSize(medalW, medalH)
    pnl2.Band = nil
    pnl2.Medal = nil

    -- Текст статистики вверху карточки медали (+exp / +skill)
    local statsLbl = vgui.Create("DLabel", pnl2)
    statsLbl:Dock(TOP)
    statsLbl:DockMargin(ScreenScale(3), ScreenScale(2) - 5 , ScreenScale(3), 0)
    statsLbl:SetFont("ZB_HomicideSuperSuperSmall")
    statsLbl:SetTextColor(Color(200, 200, 200))
    statsLbl:SetText("Wait for stats...")
    statsLbl:SetContentAlignment(7)
    statsLbl:SetTall(ScreenScale(12))

    -- Сохраняем ссылки для работы с обработчиком сети в cl_menu.lua[cite: 1, 2]
    HMCD_EndStatsPanel.statsLbl = statsLbl
    HMCD_EndStatsPanel.pnl2 = pnl2

    pnl2.Paint = function(self, pw, ph)
        draw.RoundedBox(0, 0, 0, pw, ph, Color(20, 20, 20, 220))
        surface.SetDrawColor(255, 0, 0, 100)
        surface.DrawOutlinedRect(0, 0, pw, ph, 1)

        surface.SetDrawColor(colBlue.r, colBlue.g, colBlue.b, colBlue.a)
        surface.DrawRect(0, 0, pw, ph)
        surface.SetDrawColor(colBlueUp.r, colBlueUp.g, colBlueUp.b, colBlueUp.a)
        surface.DrawRect(5, 20, 146, ph / 1.09)

        if not self.Band or not self.Medal then return end

        local topMargin = statsLbl:GetTall() + ScreenScale(2)
        local medalSize = math.min(pw + ScreenScale(4), ph + topMargin + ScreenScale(4))
        local x = (pw - medalSize) / 2 - 50
        local y = topMargin + ((ph - topMargin) - medalSize) / 2 - 50

        -- Тень
        surface.SetDrawColor(0, 0, 0, 155)
        surface.SetMaterial(self.Band.icon)
        surface.DrawTexturedRect(x + 10, y + 10, medalSize + 100, medalSize + 100)
        surface.SetMaterial(self.Medal.icon)
        surface.DrawTexturedRect(x + 10, y + 10, medalSize + 100, medalSize + 100)

        -- Иконки ленты и медали
        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(self.Band.icon)
        surface.DrawTexturedRect(x, y, medalSize + 100, medalSize + 100)

        surface.SetMaterial(self.Medal.icon)
        surface.DrawTexturedRect(x, y, medalSize + 100, medalSize + 100)
    end
end
--//

net.Receive("hmcd_roundend", function()
    local traitors, gunners = {}, {}

    for key = 1, net.ReadUInt(MODE.TraitorExpectedAmtBits) do
        local traitor = net.ReadEntity()
        traitors[key] = traitor
        traitor.isTraitor = true
    end

    for key = 1, net.ReadUInt(MODE.TraitorExpectedAmtBits) do
        local gunner = net.ReadEntity()
        gunners[key] = gunner
        gunner.isGunner = true
    end

    timer.Simple(2.5, function()
        lply.isPolice = false
        lply.isTraitor = false
        lply.isGunner = false
        lply.MainTraitor = false
        lply.SubRole = nil
        lply.Profession = nil
    end)

    traitor = traitors[1] or Entity(0)

    CreateEndMenu(traitor)
    CreateEndRoundStatsPanel()
end)

net.Receive("hmcd_announce_traitor_lose", function()
    local traitor = net.ReadEntity()
    local traitor_alive = net.ReadBool()

    if(IsValid(traitor))then
        chat.AddText(color_white, (traitor_alive and "" or "Traitor "), traitor:GetPlayerColor():ToColor(), traitor:GetPlayerName() .. ", " .. traitor:Nick(), color_white, " was " .. (traitor_alive and "a Traitor." or "killed."))
    end
end)

local colGray = Color(85,85,85)
local colRed = Color(130,10,10)
local colRedUp = Color(160,30,30)

local colBlue = Color(10,10,160)
local colBlueUp = Color(40,40,160)
local col = Color(255,255,255,255)

local colSpect1 = Color(75,75,75,255)
local colSpect2 = Color(255,255,255)

local colorBG = Color(55,55,55,255)
local colorBGBlacky = Color(40,40,40,255)

local blurMat = Material("pp/blurscreen")
local Dynamic = 0

BlurBackground = BlurBackground or hg.DrawBlur

if IsValid(hmcdEndMenu) then
    hmcdEndMenu:Remove()
    hmcdEndMenu = nil
end

CreateEndMenu = function(traitor)
    if IsValid(hmcdEndMenu) then
        hmcdEndMenu:Remove()
        hmcdEndMenu = nil
    end

    Dynamic = 0
    hmcdEndMenu = vgui.Create("ZFrame")

    if !IsValid(hmcdEndMenu) then return end

    local players = {}

    local traitorName = IsValid(traitor) and traitor:GetPlayerName() or "unknown"
    local traitorNick = IsValid(traitor) and traitor:Nick() or "unknown"

    for i, ply in player.Iterator() do
        if ply:Team() == TEAM_SPECTATOR then continue end
        if !IsValid(ply) then return end
        
        players[#players + 1] = {
            nick = ply:Nick(),
            name = ply:GetPlayerName(),
            isTraitor = ply.isTraitor,
            isGunner = ply.isGunner,
            incapacitated = ply.organism and ply.organism.otrub,
            alive = ply:Alive(),
            col = ply:GetPlayerColor():ToColor(),
            frags = ply:Frags(),
            steamid = ply:IsBot() and "BOT" or ply:SteamID64(),
        }
    end

    surface.PlaySound("ambient/alarms/warningbell1.wav")

    local sizeX,sizeY = ScrW() / 2.5, ScrH() / 1.2
    local posX,posY = ScrW() / 1.3 - sizeX / 2, ScrH() / 2 - sizeY / 2

    hmcdEndMenu:SetPos(posX, posY)
    hmcdEndMenu:SetSize(sizeX, sizeY)
    hmcdEndMenu:MakePopup()
    hmcdEndMenu:SetKeyboardInputEnabled(false)
    hmcdEndMenu:ShowCloseButton(false)

    local closebutton = vgui.Create("DButton", hmcdEndMenu)
    closebutton:SetPos(5, 5)
    closebutton:SetSize(ScrW() / 20, ScrH() / 30)
    closebutton:SetText("")

    closebutton.DoClick = function()
        if IsValid(hmcdEndMenu) then
            hmcdEndMenu:Close()
            hmcdEndMenu = nil
        end
        
        -- Добавляем удаление панели статистики при закрытии меню
        RemoveEndRoundStatsPanel()
    end

    timer.Simple( 3, function() 
        if IsValid(HMCD_EndStatsPanel) then
            HMCD_EndStatsPanel:Remove()
            HMCD_EndStatsPanel = nil
        end
	end )

    closebutton.Paint = function(self,w,h)
        surface.SetDrawColor(122, 122, 122, 255)
        surface.DrawOutlinedRect(0, 0, w, h, 2.5)
        surface.SetFont("ZB_InterfaceMedium")
        surface.SetTextColor(col.r, col.g, col.b, col.a)
        local lengthX, lengthY = surface.GetTextSize("Close")
        surface.SetTextPos(lengthX - lengthX / 1.1, 4)
        surface.DrawText("Close")
    end

    hmcdEndMenu.PaintOver = function(self,w,h)
        surface.SetFont( "ZB_InterfaceMediumLarge" )
        surface.SetTextColor(col.r,col.g,col.b,col.a)
        local lengthX, lengthY = surface.GetTextSize(traitorName .. " was a traitor ("..traitorNick..")")
        surface.SetTextPos(w / 2 - lengthX / 2, 20)
        surface.DrawText(traitorName .. " was a traitor ("..traitorNick..")")
    end

    -- PLAYERS
    local DScrollPanel = vgui.Create("DScrollPanel", hmcdEndMenu)
    DScrollPanel:SetPos(10, 80)
    DScrollPanel:SetSize(sizeX - 20, sizeY - 90)

    for i, info in ipairs(players) do
        local but = vgui.Create("DButton",DScrollPanel)

        but:SetSize(100,50)
        but:Dock(TOP)
        but:DockMargin( 8, 6, 8, -1 )
        but:SetText("")

        but.Paint = function(self,w,h)
            local col1 = (info.isTraitor and colRed) or (info.alive and colBlue) or colGray
            local col2 = info.isTraitor and (info.alive and colRedUp or colSpect1) or ((info.alive and !info.incapacitated) and colBlueUp) or colSpect1
            local name = info.nick
            surface.SetDrawColor(col1.r, col1.g, col1.b, col1.a)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(col2.r, col2.g, col2.b, col2.a)
            surface.DrawRect(0, h / 2, w, h / 2)

            local col = info.col
            surface.SetFont("ZB_InterfaceMediumLarge")
            local lengthX, lengthY = surface.GetTextSize(name)

            surface.SetTextColor(0, 0, 0, 255)
            surface.SetTextPos(w / 2 + 1, h / 2 - lengthY / 2 + 1)
            surface.DrawText(name)

            surface.SetTextColor(col.r, col.g, col.b, col.a)
            surface.SetTextPos(w / 2, h / 2 - lengthY / 2)
            surface.DrawText(name)


            local col = colSpect2
            surface.SetFont("ZB_InterfaceMediumLarge")
            surface.SetTextColor(col.r,col.g,col.b,col.a)
            local lengthX, lengthY = surface.GetTextSize(info.name)
            surface.SetTextPos(15, h / 2 - lengthY / 2)
            surface.DrawText(info.name .. ((!info.alive and " - died") or (info.incapacitated and " - incapacitated") or ""))

            surface.SetFont("ZB_InterfaceMediumLarge")
            surface.SetTextColor(col.r, col.g, col.b, col.a)
            local lengthX, lengthY = surface.GetTextSize(info.frags)
            surface.SetTextPos(w - lengthX -15,h/2 - lengthY/2)
            surface.DrawText(info.frags)
        end

        function but:DoClick()
            if info.steamid == "BOT" then chat.AddText(Color(255, 0, 0), "That's a bot.") return end
            gui.OpenURL("https://steamcommunity.com/profiles/"..info.steamid)
        end

        DScrollPanel:AddItem(but)
    end

    return true
end

function MODE:RoundStart()
    -- if IsValid(hmcdEndMenu) then
    -- 	hmcdEndMenu:Remove()
    -- 	hmcdEndMenu = nil
    -- end
end

--\\
net.Receive("HMCD(StartPlayersRoleSelection)", function()
    local role = net.ReadString()

    hg.SelectPlayerRole(role)
end)

function hg.SelectPlayerRole(role, mode)
    role = role or "Traitor"
    mode = mode or "soe"

    if(IsValid(VGUI_HMCD_RolePanelList))then
        VGUI_HMCD_RolePanelList:Remove()
    end

    if(MODE.RoleChooseRoundTypes[mode])then
        //VGUI_HMCD_RolePanelList = vgui.Create("ZB_TraitorSelectionMenu")
        //VGUI_HMCD_RolePanelList:Center()
        VGUI_HMCD_RolePanelList = vgui.Create("HMCD_RolePanelList")
        VGUI_HMCD_RolePanelList.RolesIDsList = MODE.RoleChooseRoundTypes[mode][role]	--; WARNING TCP Reroute
        VGUI_HMCD_RolePanelList.Mode = mode
        -- VGUI_HMCD_RolePanelList:SetSize(ScreenScale(600), ScreenScale(300))
        VGUI_HMCD_RolePanelList:SetSize(screen_scale_2(700), screen_scale_2(300))
        VGUI_HMCD_RolePanelList:Center()
        VGUI_HMCD_RolePanelList:InvalidateParent(false)
        VGUI_HMCD_RolePanelList:Construct()
        VGUI_HMCD_RolePanelList:MakePopup()
    end
end

net.Receive("HMCD(EndPlayersRoleSelection)", function()
    if(IsValid(VGUI_HMCD_RolePanelList))then
        VGUI_HMCD_RolePanelList:Remove()
    end
end)

net.Receive("HMCD(SetSubRole)", function(len, ply)
    lply.SubRole = net.ReadString()
end)
--//

--CreateEndMenu()