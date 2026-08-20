--
zb = zb or {}

zb.Experience = zb.Experience or {}


local EXP = zb.Experience

EXP.OpenedMenu = EXP.OpenedMenu or nil

--local function BG()
--    
--end
local gradient_u = Material("vgui/gradient-u")

local blurMat = Material("pp/blurscreen")
local Dynamic = 0

BlurBackground = hg.DrawBlur

local function PaintFrame(self,w,h)
    BlurBackground(self)
    surface.SetDrawColor(155, 0, 0, 155)
    surface.SetMaterial(gradient_u)
    surface.DrawTexturedRect( 0, 0, w, h )

    surface.SetDrawColor( 255, 0, 0, 128)
    surface.DrawOutlinedRect( 0, 0, w, h, 2.5 )
end

function EXP.Menu( ply )
    if IsValid(EXP.OpenedMenu) then
        EXP.OpenedMenu:Remove()
        EXP.OpenedMenu = nil
    end

    EXP.OpenedMenu = vgui.Create( "ZFrame" )
    EXP.OpenedMenu:SetSize( ScrW()*0.2, ScrH()*0.5 )
    EXP.OpenedMenu:Center()
    EXP.OpenedMenu:MakePopup()
    EXP.OpenedMenu:SetTitle("Medal")

    EXP.OpenedMenu.Medal = vgui.Create( "ZB_ExpPanel", EXP.OpenedMenu )
    local ExpPanel = EXP.OpenedMenu.Medal
    ExpPanel:Dock( FILL )
    ExpPanel:SetPlayer( ply )

    function EXP.OpenedMenu:Paint( w,h )
        PaintFrame(self,w,h)
    end
end

function EXP.OpenMenu( ply )
    net.Start("zb_xp_get")
        net.WriteEntity( ply )
    net.SendToServer()
end

EXP.OpenedAccount = EXP.OpenedAccount or nil
local needCallback = false
net.Receive("zb_xp_get",function()
    local ply = net.ReadEntity()
    
    local oldSkill = ply.skill or 0
    local oldExp = ply.exp or 0

    ply.skill = net.ReadFloat()
    ply.exp = net.ReadInt(19)
    
    -- Обновление мини-панели статистики в конце раунда
    local endStatsPanel = HMCD_EndStatsPanel or LS_EndStatsPanel or HL2DM_EndStatsPanel or DM_EndStatsPanel or GWARS_EndStatsPanel or RIOT_EndStatsPanel or SFD_EndStatsPanel or SMO_EndStatsPanel or SCUGARENA_EndStatsPanel or TDM_EndStatsPanel
    if IsValid(endStatsPanel) and ply == LocalPlayer() then
        local gainedSkill = ply.skill - (ply.oldSkill or 0)
        local gainedExp = ply.exp - (ply.oldExp or 0)
        
        local statsLbl = endStatsPanel.statsLbl  
        if IsValid(statsLbl) then
            if gainedSkill > 0 or gainedExp > 0 then
                statsLbl:SetText(string.format("+%.2f skill  +%.2f exp", gainedSkill, gainedExp))
                statsLbl:SetTextColor(Color(137, 137, 137))
            else
                statsLbl:SetText("No change in stats")
                statsLbl:SetTextColor(Color(200, 200, 200))
            end
        end

        local pnl2 = endStatsPanel.pnl2
        if IsValid(pnl2) then
            local Band, Medal = zb.Experience.GetAwards(ply)
            pnl2.Band = Band
            pnl2.Medal = Medal
        end
    end

    if needCallback then
        if IsValid(EXP.OpenedAccount) then
            EXP.OpenedAccount:Remove()
            EXP.OpenedAccount = nil
        end
        
        EXP.OpenedAccount = vgui.Create("ZB_AccountFrame")
        local AcMenu = EXP.OpenedAccount
        AcMenu:MakePopup()
        AcMenu:SetPlayer( ply )
        AcMenu:SetTitle( "" )
        needCallback = false
    end
end)

function EXP.AccountMenu( ply )
    needCallback = true
    EXP.OpenMenu( ply )
end