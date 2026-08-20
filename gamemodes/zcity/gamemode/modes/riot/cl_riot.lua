MODE.name = "riot"

local MODE = MODE

net.Receive("riot_start", function()
    MODE.RevealSounds = {} -- Сбрасываем звуки при старте раунда
    RemoveEndRIOTRoundStatsPanel()
    if RiotSound then
        RiotSound:Stop()
        RiotSound = nil
    end

    sound.PlayFile("sound/zbattle/riot.wav", "noplay", function(station)
        if IsValid(station) then
            station:SetVolume(6) 
            station:Play()
            RiotSound = station
        end
    end)

    zb.RemoveFade()
end)


local teams = {
	[0] = {
		objective = "",
		name = "a Rioter",
		color1 = Color(190,0,0),
		color2 = Color(190,0,0)
	},
	[1] = {
		objective = "",
		name = "a Law Enforcement",
		color1 = Color(0,120,190),
		color2 = Color(0,120,190)
	},
}

function MODE:RenderScreenspaceEffects()
    if zb.ROUND_START + 7.5 < CurTime() then return end
    local fade = math.Clamp(zb.ROUND_START + 7.5 - CurTime(),0,1)

    surface.SetDrawColor(0,0,0,255 * fade)
    surface.DrawRect(-1,-1,ScrW() + 1,ScrH() + 1)
end

function MODE:HUDPaint()
    if zb.ROUND_START + 8.5 < CurTime() then return end
	if not lply:Alive() then return end
	zb.RemoveFade()

	-- \\ Адаптированная поэтапная отрисовка начала раунда (как в homicide)
	local team_ = lply:Team()
	local teamInfo = teams[team_]
	if not teamInfo then return end

	local timeElapsed = CurTime() - zb.ROUND_START
	local maxTime = 6 -- Общее время отображения UI (в секундах)
	if timeElapsed > maxTime then return end

	-- Глобальное появление и затухание (0 до 0.5 сек появление, с 4.5 до 6 сек затухание)
	local globalFade = 1
	if timeElapsed < 0.5 then
		globalFade = timeElapsed / 0.5
	elseif timeElapsed > 4.5 then
		globalFade = math.Clamp(1 - (timeElapsed - 4.5) / 1.5, 0, 1)
	end

	-- 1. Фон в зависимости от команды
	local bgColor = Color(teamInfo.color1.r * 0.1, teamInfo.color1.g * 0.1, teamInfo.color1.b * 0.1, 255 * globalFade)
	surface.SetDrawColor(bgColor)
	surface.DrawRect(0, 0, ScrW(), ScrH())

	-- Виньетка/градиент для атмосферы
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
		draw.SimpleText("Homicide | Riot", "ZB_HomicideMediumLarge", sw * 0.5, sh * 0.1, Color(0, 162, 255, 255 * a_title), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		playStageSound(0.5, "arccw_uc/common/10x25/fire-dist-10x25-pistol-ext-01.ogg")
	end

	-- 4. Роль
	local Rolename = teamInfo.name
	local ColorRole = Color(teamInfo.color1.r, teamInfo.color1.g, teamInfo.color1.b, 255 * a_role)

	if a_role > 0 then
		draw.SimpleText("You are " .. Rolename, "ZB_HomicideMediumLarge", sw * 0.5, sh * 0.5, ColorRole, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		playStageSound(1.5, "arccw_uc/common/10x25/fire-dist-10x25-pistol-ext-01.ogg")
	end

	-- 5. Нижний текст (Objective)
	local Objective = teamInfo.objective
	local ColorObj = Color(teamInfo.color2.r, teamInfo.color2.g, teamInfo.color2.b, 255 * a_obj)

	if a_obj > 0 then
		draw.SimpleText(Objective, "ZB_HomicideMedium", sw * 0.5, sh * 0.9, ColorObj, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		playStageSound(3.5, "arccw_uc/common/10x25/fire-dist-10x25-pistol-ext-01.ogg")
	end

	-- PluvTown Madness
	if globalFade > 0 and hg.PluvTown.Active then
		surface.SetMaterial(hg.PluvTown.PluvMadness)
		surface.SetDrawColor(255, 255, 255, math.random(175, 255) * globalFade / 2)
		surface.DrawTexturedRect(sw * 0.25, sh * 0.44 - ScreenScale(15), sw / 2, ScreenScale(30))

		draw.SimpleText("SOMEWHERE IN PLUVTOWN", "ZB_ScrappersLarge", sw / 2, sh * 0.44 - ScreenScale(2), Color(0, 0, 0, 255 * globalFade), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
end

local CreateEndMenu

--\\ Панели завершения раунда
RIOT_EndStatsPanel = nil

function RemoveEndRIOTRoundStatsPanel()
    if IsValid(RIOT_EndStatsPanel) then
        RIOT_EndStatsPanel:Remove()
        RIOT_EndStatsPanel = nil
    end
end

local colGray = Color(122,122,122,255)
local colBlue = Color(130,10,10)
local colBlueUp = Color(160,30,30)
local col = Color(255,255,255,255)

local colSpect1 = Color(75,75,75,255)
local colSpect2 = Color(85,85,85,255)

local function CreateEndRoundStatsPanel()
    RemoveEndRIOTRoundStatsPanel()

    if not IsValid(lply) then return end

    net.Start("zb_xp_get")
        net.WriteEntity(lply)
    net.SendToServer()

    local padding = ScreenScale(4)

    local topW = ScreenScale(210)
    local topH = ScreenScale(32)

    local medalW = ScreenScale(52)
    local medalH = ScreenScale(105)

    local posX = padding + ScreenScale(25)
    local posY = padding + ScreenScale(25)

    RIOT_EndStatsPanel = vgui.Create("DPanel")
    RIOT_EndStatsPanel:SetPos(posX, posY)
    RIOT_EndStatsPanel:SetSize(topW, topH + medalH + padding)
    RIOT_EndStatsPanel:MakePopup()
    RIOT_EndStatsPanel:SetKeyboardInputEnabled(false)
    RIOT_EndStatsPanel:SetMouseInputEnabled(false)

    RIOT_EndStatsPanel.Paint = function(self, pw, ph) end

    local pnl1 = vgui.Create("DPanel", RIOT_EndStatsPanel)
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

    local topLbl = vgui.Create("DLabel", pnl1)
    topLbl:SetPos( textX, ScreenScale(2))
    topLbl:SetFont("ZB_HomicideSuperSuperSmall")
    topLbl:SetTextColor(Color(137, 137, 137))
    topLbl:SetText("MVP: " .. "Wait for stats...")
    topLbl:SizeToContents()

    local mainLbl = vgui.Create("DLabel", pnl1)
    mainLbl:SetPos(textX, ScreenScale(4))
    mainLbl:SetFont("ZB_HomicideLarge")
    mainLbl:SetTextColor(Color(255, 255, 255))
    mainLbl:SetText(lply:Nick())
    mainLbl:SizeToContents()

    local pnl2 = vgui.Create("DPanel", RIOT_EndStatsPanel)
    pnl2:SetPos(0, topH + padding)
    pnl2:SetSize(medalW, medalH)
    pnl2.Band = nil
    pnl2.Medal = nil

    local statsLbl = vgui.Create("DLabel", pnl2)
    statsLbl:Dock(TOP)
    statsLbl:DockMargin(ScreenScale(3), ScreenScale(2) - 5 , ScreenScale(3), 0)
    statsLbl:SetFont("ZB_HomicideSuperSuperSmall")
    statsLbl:SetTextColor(Color(200, 200, 200))
    statsLbl:SetText("Wait for stats...")
    statsLbl:SetContentAlignment(7)
    statsLbl:SetTall(ScreenScale(12))

    RIOT_EndStatsPanel.statsLbl = statsLbl
    RIOT_EndStatsPanel.pnl2 = pnl2

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

        surface.SetDrawColor(0, 0, 0, 155)
        surface.SetMaterial(self.Band.icon)
        surface.DrawTexturedRect(x + 10, y + 10, medalSize + 100, medalSize + 100)
        surface.SetMaterial(self.Medal.icon)
        surface.DrawTexturedRect(x + 10, y + 10, medalSize + 100, medalSize + 100)

        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(self.Band.icon)
        surface.DrawTexturedRect(x, y, medalSize + 100, medalSize + 100)

        surface.SetMaterial(self.Medal.icon)
        surface.DrawTexturedRect(x, y, medalSize + 100, medalSize + 100)
    end
end
--//

net.Receive("riot_roundend",function()
    CreateEndMenu()
    CreateEndRoundStatsPanel()
end)

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

	RemoveEndRIOTRoundStatsPanel()

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

		RemoveEndRIOTRoundStatsPanel()
	end

	timer.Simple( 3, function() 
		if IsValid(RIOT_EndStatsPanel) then
			RIOT_EndStatsPanel:Remove()
			RIOT_EndStatsPanel = nil
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

    hmcdEndMenu.Paint = function(self,w,h)
		BlurBackground(self)

		surface.SetFont( "ZB_InterfaceMediumLarge" )
		surface.SetTextColor(col.r,col.g,col.b,col.a)
		local lengthX, lengthY = surface.GetTextSize("Players:")
		surface.SetTextPos(w / 2 - lengthX/2,20)
		surface.DrawText("Players:")

		surface.SetDrawColor( 255, 0, 0, 128)
        surface.DrawOutlinedRect( 0, 0, w, h, 2.5 )
	end
	-- PLAYERS
	local DScrollPanel = vgui.Create("DScrollPanel", hmcdEndMenu)
	DScrollPanel:SetPos(10, 80)
	DScrollPanel:SetSize(sizeX - 20, sizeY - 90)
	function DScrollPanel:Paint( w, h )
		BlurBackground(self)

		surface.SetDrawColor( 255, 0, 0, 128)
        surface.DrawOutlinedRect( 0, 0, w, h, 2.5 )
	end

	for i,ply in player.Iterator() do
		if ply:Team() == TEAM_SPECTATOR then continue end
		local but = vgui.Create("DButton",DScrollPanel)
		but:SetSize(100,50)
		but:Dock(TOP)
		but:DockMargin( 8, 6, 8, -1 )
		but:SetText("")
		but.Paint = function(self,w,h)
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
