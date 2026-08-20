MODE.name = "coop"

local MODE = MODE

net.Receive("coop_start",function()
    MODE.RevealSounds = {} -- Сбрасываем звуки при старте раунда
    surface.PlaySound("hl2mode1.wav")
	RemoveEndCoopRoundStatsPanel()
	lply.oldSkill = lply.skill or 0
    lply.oldExp = lply.exp or 0
	zb.RemoveFade()
	hg.DynaMusic:Start("hl_coop")
end)

local teams = {
	[0] = {
		objective = "Go to the end of the map!",
		name = "rebel",
		color1 = Color(155,55,0),
		color2 = Color(129,129,129)
	}
}

function MODE:RenderScreenspaceEffects()
    if zb.ROUND_START + 7.5 < CurTime() then return end
    local fade = math.Clamp(zb.ROUND_START + 7.5 - CurTime(),0,1)

    surface.SetDrawColor(0,0,0,255 * fade)
    surface.DrawRect(-1,-1,ScrW() + 1,ScrH() + 1)
end

function MODE:HUDPaint()

	local startTimer = GetGlobalVar("coop_first_round_timer", 0)

	if startTimer > CurTime() then
		surface.SetFont("ZB_HomicideMediumLarge")

		local w, h = surface.GetTextSize("Awaiting players: ")
		local w2, h2 = surface.GetTextSize("00:00")

		surface.SetTextPos(sw * 0.5 - (w + w2) * 0.5, sh * 0.1 - h * 0.5)
		surface.SetTextColor(Color(0,162,255, 255))
		surface.DrawText("Awaiting players: ")
		
		surface.SetTextPos(sw * 0.5 + (w - w2) * 0.5, sh * 0.1 - h * 0.5)
		surface.DrawText(string.FormattedTime(startTimer - CurTime(), "%02i:%02i"))
	end

    if zb.ROUND_START + 8.5 < CurTime() then return end

    if not lply:Alive() then return end
    zb.RemoveFade()

    -- \\ Адаптированная поэтапная отрисовка начала раунда (как в homicide)
    local teamInfo = teams[0]
    if not teamInfo then return end

    local timeElapsed = CurTime() - zb.ROUND_START
    local maxTime = 6 -- Общее время отображения UI (в секундах)
    if timeElapsed > maxTime then return end

    -- Глобальное появление и затухание
    local globalFade = 1
    if timeElapsed < 0.5 then
        globalFade = timeElapsed / 0.5
    elseif timeElapsed > 4.5 then
        globalFade = math.Clamp(1 - (timeElapsed - 4.5) / 1.5, 0, 1)
    end

    -- 1. Фон
    local bgColor = Color(teamInfo.color1.r * 0.1, teamInfo.color1.g * 0.1, teamInfo.color1.b * 0.1, 255 * globalFade)
    surface.SetDrawColor(bgColor)
    surface.DrawRect(0, 0, ScrW(), ScrH())

    -- Виньетка/градиент
    local mat = Material("vgui/gradient-d")
    surface.SetMaterial(mat)
    surface.SetDrawColor(0, 0, 0, 200 * globalFade)
    surface.DrawTexturedRect(0, 0, ScrW(), ScrH())

    -- 2. Настройки стадий
    local function getStageAlpha(t)
        return math.Clamp((timeElapsed - t) / 0.3, 0, 1) * globalFade
    end

    local a_title = getStageAlpha(0.5)
    local a_role = getStageAlpha(1.5)
    local a_obj = getStageAlpha(3.5)

    -- Звуки появления
    MODE.RevealSounds = MODE.RevealSounds or {}
    local function playStageSound(t, snd)
        if timeElapsed >= t and not MODE.RevealSounds[t] then
            surface.PlaySound(snd)
            MODE.RevealSounds[t] = true
        end
    end

    -- 3. Верхний текст (Title)
    if a_title > 0 then
        draw.SimpleText("Homicide | CO-OP", "ZB_HomicideMediumLarge", sw * 0.5, sh * 0.1, Color(0, 162, 255, 255 * a_title), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        playStageSound(0.5, "arccw_uc/common/10x25/fire-dist-10x25-pistol-ext-01.ogg")
    end

    -- 4. Роль
    local Rolename = (lply.role and lply.role.name) or "Unknown"
    local ColorRole = Color(teamInfo.color1.r, teamInfo.color1.g, teamInfo.color1.b, 255 * a_role)

    if a_role > 0 then
        draw.SimpleText("You are " .. Rolename, "ZB_HomicideMediumLarge", sw * 0.5, sh * 0.5, ColorRole, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        playStageSound(1.5, "arccw_uc/common/10x25/fire-dist-10x25-pistol-ext-01.ogg")
    end

    -- 5. Нижний текст (Objective)
    local Objective = lply.PlayerClassName == "Gordon" and "Lead the resistance to victory!" or "Follow the Gordon!"
    local ColorObj = Color(teamInfo.color2.r, teamInfo.color2.g, teamInfo.color2.b, 255 * a_obj)

    if a_obj > 0 then
        draw.SimpleText(Objective, "ZB_HomicideMedium", sw * 0.5, sh * 0.9, ColorObj, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        playStageSound(3.5, "arccw_uc/common/10x25/fire-dist-10x25-pistol-ext-01.ogg")
    end
end

local CreateEndMenu

net.Receive("coop_roundend",function()
    CreateEndMenu()
	CreateEndRoundStatsPanel()
end)

coop_EndStatsPanel = nil

function RemoveEndCoopRoundStatsPanel()
    if IsValid(coop_EndStatsPanel) then
        coop_EndStatsPanel:Remove()
        coop_EndStatsPanel = nil
    end
end

local colGray = Color(122,122,122,255)
local colBlue = Color(130,10,10)
local colBlueUp = Color(160,30,30)
local col = Color(255,255,255,255)

local colSpect1 = Color(75,75,75,255)
local colSpect2 = Color(85,85,85,255)

local function CreateEndRoundStatsPanel()
    RemoveEndCoopRoundStatsPanel()

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

    coop_EndStatsPanel = vgui.Create("DPanel")
    -- Используем новые переменные вместо padding, padding
    coop_EndStatsPanel:SetPos(posX, posY)
    coop_EndStatsPanel:SetSize(topW, topH + medalH + padding)
    coop_EndStatsPanel:MakePopup()
    coop_EndStatsPanel:SetKeyboardInputEnabled(false)
    coop_EndStatsPanel:SetMouseInputEnabled(false)

    coop_EndStatsPanel.Paint = function(self, pw, ph) end

    -- Панель 1: Верхняя горизонтальная плашка (Аватар + Ник / Заголовок)
    local pnl1 = vgui.Create("DPanel", coop_EndStatsPanel)
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
    topLbl:SetText("MVP: " .. lply:Nick())
    topLbl:SizeToContents()

    -- Большой нижний текст (Никнейм)
    local mainLbl = vgui.Create("DLabel", pnl1)
    mainLbl:SetPos(textX, ScreenScale(4))
    mainLbl:SetFont("ZB_HomicideLarge")
    mainLbl:SetTextColor(Color(255, 255, 255))
    mainLbl:SetText(lply:Nick())
    mainLbl:SizeToContents()

    -- Панель 2: Вертикальная карточка медали (снизу слева)
    local pnl2 = vgui.Create("DPanel", coop_EndStatsPanel)
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
    coop_EndStatsPanel.statsLbl = statsLbl
    coop_EndStatsPanel.pnl2 = pnl2

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

local colGray = Color(85,85,85,255)
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

CreateEndMenu = function()
	if IsValid(hmcdEndMenu) then
		hmcdEndMenu:Remove()
		hmcdEndMenu = nil
	end
	Dynamic = 0
	hmcdEndMenu = vgui.Create("ZFrame")

    surface.PlaySound("ambient/alarms/warningbell1.wav")

	local sizeX,sizeY = ScrW() / 2.5 ,ScrH() / 1.2
	local posX,posY = ScrW() / 1.3 - sizeX / 2,ScrH() / 2 - sizeY / 2

	hmcdEndMenu:SetPos(posX,posY)
	hmcdEndMenu:SetSize(sizeX,sizeY)
	--hmcdEndMenu:SetBackgroundColor(colGray)
	hmcdEndMenu:MakePopup()
	hmcdEndMenu:SetKeyboardInputEnabled(false)
	hmcdEndMenu:ShowCloseButton(false)

	local closebutton = vgui.Create("DButton",hmcdEndMenu)
	closebutton:SetPos(5,5)
	closebutton:SetSize(ScrW() / 20,ScrH() / 30)
	closebutton:SetText("")
	
    closebutton.DoClick = function()
        if IsValid(hmcdEndMenu) then
            hmcdEndMenu:Close()
            hmcdEndMenu = nil
        end
        
        -- Добавляем удаление панели статистики при закрытии меню
        RemoveEndCoopRoundStatsPanel()
    end

    timer.Simple( 3, function() 
        if IsValid(coop_EndStatsPanel) then
            coop_EndStatsPanel:Remove()
            coop_EndStatsPanel = nil
        end
	end )

	closebutton.Paint = function(self,w,h)
		surface.SetDrawColor( 122, 122, 122, 255)
        surface.DrawOutlinedRect( 0, 0, w, h, 2.5 )
		surface.SetFont( "ZB_InterfaceMedium" )
		surface.SetTextColor(col.r,col.g,col.b,col.a)
		local lengthX, lengthY = surface.GetTextSize("Close")
		surface.SetTextPos( lengthX - lengthX/1.1, 4)
		surface.DrawText("Close")
	end

    hmcdEndMenu.PaintOver = function(self,w,h)

		surface.SetFont( "ZB_InterfaceMediumLarge" )
		surface.SetTextColor(col.r,col.g,col.b,col.a)
		local lengthX, lengthY = surface.GetTextSize("Players:")
		surface.SetTextPos(w / 2 - lengthX/2,20)
		surface.DrawText("Players:")

	end
	-- PLAYERS
	local DScrollPanel = vgui.Create("DScrollPanel", hmcdEndMenu)
	DScrollPanel:SetPos(10, 80)
	DScrollPanel:SetSize(sizeX - 20, sizeY - 90)
	function DScrollPanel:Paint( w, h )

		surface.SetDrawColor( 255, 0, 0, 128)
        surface.DrawOutlinedRect( 0, 0, w, h, 2.5 )
	end

	for i, ply in player.Iterator() do
		if ply:Team() == TEAM_SPECTATOR then continue end
		local but = vgui.Create("DButton",DScrollPanel)
		but:SetSize(100,50)
		but:Dock(TOP)
		but:DockMargin( 8, 6, 8, -1 )
		but:SetText("")
		but.Paint = function(self,w,h)
			if !IsValid(ply) then return end
            local col1 = (ply:Alive() and colRed) or colGray
            local col2 = (ply:Alive() and colRedUp) or colSpect1
			surface.SetDrawColor(col1.r,col1.g,col1.b,col1.a)
			surface.DrawRect(0,0,w,h)
			surface.SetDrawColor(col2.r,col2.g,col2.b,col2.a)
			surface.DrawRect(0,h/2,w,h/2)

            local col = ply:GetPlayerColor():ToColor()
			surface.SetFont( "ZB_InterfaceMediumLarge" )
			local lengthX, lengthY = surface.GetTextSize( ply:GetPlayerName() or "He quited..." )
			
			surface.SetTextColor(0,0,0,255)
			surface.SetTextPos(w / 2 + 1,h/2 - lengthY/2 + 1)
			surface.DrawText(ply:GetPlayerName() or "He quited...")

			surface.SetTextColor(col.r,col.g,col.b,col.a)
			surface.SetTextPos(w / 2,h/2 - lengthY/2)
			surface.DrawText(ply:GetPlayerName() or "He quited...")

            
			local col = colSpect2
			surface.SetFont( "ZB_InterfaceMediumLarge" )
			surface.SetTextColor(col.r,col.g,col.b,col.a)
			local lengthX, lengthY = surface.GetTextSize( ply:GetPlayerName() or "He quited..." )
			surface.SetTextPos(15,h/2 - lengthY/2)
			surface.DrawText((ply:Name() .. (not ply:Alive() and " - died" or "")) or "He quited...")

			surface.SetFont( "ZB_InterfaceMediumLarge" )
			surface.SetTextColor(col.r,col.g,col.b,col.a)
			local lengthX, lengthY = surface.GetTextSize( ply:Frags() or "He quited..." )
			surface.SetTextPos(w - lengthX -15,h/2 - lengthY/2)
			surface.DrawText(ply:Frags() or "He quited...")
		end

		function but:DoClick()
			if ply:IsBot() then chat.AddText(Color(255,0,0), "no, you can't") return end
			gui.OpenURL("https://steamcommunity.com/profiles/"..ply:SteamID64())
		end

		DScrollPanel:AddItem(but)
	end

	return true
end

function MODE:RoundStart()
    if IsValid(hmcdEndMenu) then
        hmcdEndMenu:Remove()
        hmcdEndMenu = nil
    end
end
