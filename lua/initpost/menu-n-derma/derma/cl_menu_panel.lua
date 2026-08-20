local PANEL = {}
local curent_panel 
local red_select = Color(192,0,0)

local Selects = {
    {Title = "Disconnect", Func = function(luaMenu) RunConsoleCommand("disconnect") end},
    {Title = "Main Menu", Func = function(luaMenu) gui.ActivateGameUI() luaMenu:Close() end},
    {Title = "Discord", Func = function(luaMenu) luaMenu:Close() gui.OpenURL("https://discord.gg/2TdGzdVkWT")  end},
    {Title = "Traitor Role",
    GamemodeOnly = true,
    CreatedFunc = function(self, parent, luaMenu)
        local btn = vgui.Create( "DLabel", self )
        btn:SetText( "SOE" )
        btn:SetMouseInputEnabled( true )
        btn:SizeToContents()
        btn:SetFont( "ZCity_Small" )
        btn:SetTall( ScreenScale( 15 ) )
        btn:Dock(BOTTOM)
        btn:DockMargin(ScreenScale(20),ScreenScale(10),0,0)
        btn:SetTextColor(Color(255,255,255))
        btn:InvalidateParent()
        btn.RColor = Color(225, 225, 225, 0)
        btn.WColor = Color(225, 225, 225, 255)
        btn.x = btn:GetX()

        function btn:DoClick()
            luaMenu:Close()
            hg.SelectPlayerRole(nil, "soe")
        end
    
        local selfa = self
        function btn:Think()
            self.HoverLerp = selfa.HoverLerp
            self.HoverLerp2 = LerpFT(0.2, self.HoverLerp2 or 0, self:IsHovered() and 1 or 0)
                
            self:SetTextColor(self.RColor:Lerp(self.WColor:Lerp(red_select, self.HoverLerp2), self.HoverLerp))
            self:SetX(self.x + ScreenScaleH(40) + self.HoverLerp * ScreenScaleH(50))
        end

        local btn = vgui.Create( "DLabel", btn )
        btn:SetText( "STD" )
        btn:SetMouseInputEnabled( true )
        btn:SizeToContents()
        btn:SetFont( "ZCity_Small" )
        btn:SetTall( ScreenScale( 15 ) )
        btn:Dock(BOTTOM)
        btn:DockMargin(0,ScreenScale(2),0,0)
        btn:SetTextColor(Color(255,255,255))
        btn:InvalidateParent()
        btn.RColor = Color(225, 225, 225, 0)
        btn.WColor = Color(225, 225, 225, 255)
        btn.x = btn:GetX()

        function btn:DoClick()
            luaMenu:Close()
            hg.SelectPlayerRole(nil, "standard")
        end
    
        function btn:Think()
            self.HoverLerp = selfa.HoverLerp
            self.HoverLerp2 = LerpFT(0.2, self.HoverLerp2 or 0, self:IsHovered() and 1 or 0)
    
            self:SetTextColor(self.RColor:Lerp(self.WColor:Lerp(red_select, self.HoverLerp2), self.HoverLerp))
            self:SetX(self.x + ScreenScaleH(35))
        end
    end,
    Func = function(luaMenu)
        
    end,
    },
    {Title = "Achievements", Func = function(luaMenu,pp) 
        hg.DrawAchievmentsMenu(pp)
    end},
    {Title = "Settings", Func = function(luaMenu,pp) 
        hg.DrawSettings(pp) 
    end},
    {Title = "Appearance", Func = function(luaMenu,pp) hg.CreateApperanceMenu(pp) end},
    {Title = "Tab Stripes", Func = function(luaMenu,pp) hg.DrawStripesShop(pp) end},
    {Title = "Return", Func = function(luaMenu) luaMenu:Close() end},
}

local splasheh = {
    'LIKE HOMICIDED',
    'PLUV PLUV PLUVISKI',
    'LULU IS NOT DEAD | !PLUV',
    'THE TRAITOR WAS KILLED',
    'NAB HOMICIDE SERVER',
    'ALSO TRY MODDED HOMICIDE 2',
    'HOP ON Z-CITY',
    'JOHN Z-CITY',
    ':pluvrare:',
    'SAW51 IS REAL',
    'MORE SMALLTOWN',
    'MORE CLUE2022',
    'BACKROOMS == CLUE',
    'HELL IS NEAR',
    'I WISH YOU GOOD HEALTH, JASON STATHAM'
}

--print(string.upper('I wish you good health, Jason Statham'))
surface.CreateFont("ZC_MM_Title", {
    font = "Bahnschrift",
    size = ScreenScale(40),
    weight = 800,
    antialias = true
})
-- local Title = markup.Parse("error")

local Pluv = Material("pluv/pluvkid.jpg")

function PANEL:InitializeMarkup()
	local mapname = game.GetMap()
	local prefix = string.find(mapname, "_")
	if prefix then
		mapname = string.sub(mapname, prefix + 1)
	end
	local gm = splasheh[math.random(#splasheh)] .. " | " .. string.NiceName(mapname) 

    if hg.PluvTown.Active then
        local text = "<font=ZC_MM_Title><colour=199,2,2>    </colour>City</font>\n<font=ZCity_Tiny><colour=105,105,105>" .. gm .. "</colour></font>"

        self.SelectedPluv = table.Random(hg.PluvTown.PluvMats)

        return markup.Parse(text)
    end

    local text = "<font=ZC_MM_Title><colour=199,2,2,255>Z</colour>-City</font>\n<font=ZCity_Tiny><colour=105,105,105>" .. gm .. "</colour></font>"
    return markup.Parse(text)
end

local color_red = Color(255,25,25,45)
local clr_gray = Color(255,255,255,25)
local clr_verygray = Color(10,10,19,235)

function PANEL:Init()
    self:SetAlpha(0)
    self:SetSize(ScrW(), ScrH())
    self:Center()
    self:SetTitle("")
    self:SetDraggable(false)
    self:SetBorder(false)
    self:SetColorBG(clr_verygray)
    self:SetDraggable(false)
    self:ShowCloseButton(false)
    curent_panel = nil
    self.Title, self.TitleShadow = self:InitializeMarkup()

    timer.Simple(0, function()
        if self.First then
            self:First()
        end
    end)

    self.lDock = vgui.Create("DPanel", self)
    local lDock = self.lDock
    lDock:Dock(LEFT)
    lDock:SetSize(ScrW() / 4, ScrH())
    lDock:DockMargin(ScreenScale(0), ScreenScaleH(90), ScreenScale(10), ScreenScaleH(90))
    lDock.Paint = function(this, w, h)
        if hg.PluvTown.Active then
            surface.SetDrawColor(color_white)
            surface.SetMaterial(self.SelectedPluv or Pluv)
            surface.DrawTexturedRect(0, ScreenScale(27), ScreenScale(35), ScreenScale(27))
        end

        self.Title:Draw(ScreenScale(15), ScreenScale(50), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 255, TEXT_ALIGN_LEFT)
    end

    self.Buttons = {}
    for k, v in ipairs(Selects) do
        if v.GamemodeOnly and engine.ActiveGamemode() != "zcity" then continue end
        self:AddSelect(lDock, v.Title, v)
    end


    local bottomDock = vgui.Create("DPanel", self)
    bottomDock:SetPos(ScreenScale(1), ScrH() - ScrH()/10)
    bottomDock:SetSize(ScreenScale(190), ScreenScaleH(40))
    bottomDock.Paint = function(this, w, h) end
    self.panelparrent = vgui.Create("DPanel", self)
    self.panelparrent:SetPos(bottomDock:GetWide()+bottomDock:GetX(), 0)
    self.panelparrent:SetSize(ScrW() - bottomDock:GetWide()*1, ScrH())
    self.panelparrent.Paint = function(this, w, h) end
    
    local git = vgui.Create("DLabel", bottomDock)
    git:Dock(BOTTOM)
    git:DockMargin(ScreenScale(10), 0, 0, 0)
    git:SetFont("ZCity_Tiny")
    git:SetTextColor(clr_gray)
    git:SetText("GitHub: github.com/" .. hg.GitHub_ReposOwner .. "/" .. hg.GitHub_ReposName)
    git:SetContentAlignment(4)
    git:SetMouseInputEnabled(true)
    git:SizeToContents()

    function git:DoClick()
        gui.OpenURL("https://github.com/" .. hg.GitHub_ReposOwner .. "/" .. hg.GitHub_ReposName)
    end

    local version = vgui.Create("DLabel", bottomDock)
    version:Dock(BOTTOM)
    version:DockMargin(ScreenScale(10), 0, 0, 0)
    version:SetFont("ZCity_Tiny")
    version:SetTextColor(clr_gray)
    version:SetText(hg.Version)
    version:SetContentAlignment(4)
    version:SizeToContents()

    local zteam = vgui.Create("DLabel", bottomDock)
    zteam:Dock(BOTTOM)
    zteam:DockMargin(ScreenScale(10), 0, 0, 0)
    zteam:SetFont("ZCity_Tiny")
    zteam:SetTextColor(clr_gray)
    zteam:SetText("Authors: uzelezz, Sadsalat, \nMr.Point, Zac90, Deka, Mannytko")
    zteam:SetContentAlignment(4)
    zteam:SizeToContents()
end

function PANEL:First( ply )
    self:AlphaTo( 255, 0.1, 0, nil )
end

local gradient_d = surface.GetTextureID("vgui/gradient-d")
local gradient_r = surface.GetTextureID("vgui/gradient-u")
local gradient_l = surface.GetTextureID("vgui/gradient-l")

local clr_1 = Color(102,0,0,35)
function PANEL:Paint(w,h)
    draw.RoundedBox( 0, 0, 0, w, h, self.ColorBG )
    hg.DrawBlur(self, 5)
    surface.SetDrawColor( self.ColorBG )
    surface.SetTexture( gradient_l )
    surface.DrawTexturedRect(0,0,w,h)
    surface.SetDrawColor( clr_1 )
    surface.SetTexture( gradient_d )
    surface.DrawTexturedRect(0,0,w,h)
end

function PANEL:AddSelect( pParent, strTitle, tbl )
    local id = #self.Buttons + 1
    self.Buttons[id] = vgui.Create( "DLabel", pParent )
    local btn = self.Buttons[id]
    btn:SetText( strTitle )
    btn:SetMouseInputEnabled( true )
    btn:SizeToContents()
    btn:SetFont( "ZCity_Small" )
    btn:SetTall( ScreenScale( 15 ) )
    btn:Dock(BOTTOM)
    btn:DockMargin(ScreenScale(15),ScreenScale(0.5),0,0)
    btn.Func = tbl.Func
    btn.HoveredFunc = tbl.HoveredFunc
    local luaMenu = self 
    if tbl.CreatedFunc then tbl.CreatedFunc(btn, self, luaMenu) end
    btn.RColor = Color(225,225,225)
    function btn:DoClick()
        -- ,kz оптимизировать надо, но идёт ошибка(кэшировать бы luaMenu.panelparrent вместо вызова его каждый раз)
        if curent_panel == string.lower(strTitle) then
			for i = 1, 3 do
				surface.PlaySound("shitty/tap_release.wav")
			end
            luaMenu.panelparrent:AlphaTo(0,0.2,0,function()
                luaMenu.panelparrent:Remove()
                luaMenu.panelparrent = nil
                luaMenu.panelparrent = vgui.Create("DPanel", luaMenu)
                
                luaMenu.panelparrent:SetPos(some_coordinates_x, 0)
                luaMenu.panelparrent:SetSize(some_size_x, some_size_y)
                luaMenu.panelparrent.Paint = function(this, w, h) end
                --btn.Func(luaMenu,luaMenu.panelparrent)
                curent_panel = nil
            end)
            return 
        end
        some_size_x = luaMenu.panelparrent:GetWide()
        some_size_y = luaMenu.panelparrent:GetTall()
        some_coordinates_x = luaMenu.panelparrent:GetX()
        luaMenu.panelparrent:AlphaTo(0,0.2,0,function()
            luaMenu.panelparrent:Remove()
            luaMenu.panelparrent = nil
            luaMenu.panelparrent = vgui.Create("DPanel", luaMenu)
            
            luaMenu.panelparrent:SetPos(some_coordinates_x, 0)
            luaMenu.panelparrent:SetSize(some_size_x, some_size_y)
            luaMenu.panelparrent.Paint = function(this, w, h) end
            btn.Func(luaMenu,luaMenu.panelparrent)
            curent_panel = string.lower(strTitle)
        end)
		for i = 1, 3 do
			surface.PlaySound("shitty/tap_depress.wav")
		end
    end

    function btn:Think()
        self.HoverLerp = LerpFT(0.2, self.HoverLerp or 0, (self:IsHovered() or (IsValid(self:GetChild(0)) and self:GetChild(0):IsHovered()) or (IsValid(self:GetChild(0)) and IsValid(self:GetChild(0):GetChild(0)) and self:GetChild(0):GetChild(0):IsHovered())) and 1 or 0)

        local v = self.HoverLerp
        self:SetTextColor(self.RColor:Lerp(red_select, v))

        local targetText = (self:IsHovered()) and string.upper(strTitle) or strTitle
        local crw = self:GetText()

        if (crw ~= targetText) or (curent_panel == string.lower(strTitle)) then
            local ntxt = ""
            local will_text = (curent_panel == string.lower(strTitle) and not strTitle == 'Traitor Role') and '[ '..string.upper(strTitle)..' ]' or strTitle
            for i = 1, #will_text do
                local char = will_text:sub(i, i)
                if i <= math.ceil(#will_text * v) then
                    ntxt = ntxt .. string.upper(char)
                else
                    ntxt = ntxt .. char
                end
            end
			if self:GetText() ~= ntxt then
				surface.PlaySound("shitty/tap-resonant.wav")
			end
            self:SetText(ntxt)
        end
        self:SizeToContents()
    end
end

function PANEL:Close()
    self:AlphaTo( 0, 0.1, 0, function() self:Remove() end)
    self:SetKeyboardInputEnabled(false)
    self:SetMouseInputEnabled(false)
end

vgui.Register( "ZMainMenu", PANEL, "ZFrame")

hook.Add("OnPauseMenuShow","OpenMainMenu",function()
    local run = hook.Run("OnShowZCityPause")
    if run != nil then
        return run
    end

    if MainMenu and IsValid(MainMenu) then
        MainMenu:Close()
        MainMenu = nil
        return false
    end

    MainMenu = vgui.Create("ZMainMenu")
    MainMenu:MakePopup()
    return false
end)

function hg.DrawStripesShop(ParentPanel)
    ParentPanel:SetAlpha(0)
    ParentPanel.Paint = function(self,w,h)
        -- Анимированный фон (такой же как в настройках)
        surface.SetDrawColor(28,28,28,255)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(107, 107, 107,75)
        for i = 1, (ybars + 1) do
            surface.DrawRect((sw / ybars) * i - (CurTime() * 30 % (sw / ybars)), 0, ScreenScale(1), sh)
        end
        for i = 1, (xbars + 1) do
            surface.DrawRect(0, (sh / xbars) * (i - 1) + (CurTime() * 30 % (sh / xbars)), sw, ScreenScale(1))
        end
        local border_size = ScreenScale(2)
        surface.SetDrawColor(0, 0, 0)
        surface.SetTexture(gradient_l)
        surface.DrawTexturedRect(0, 0, border_size, sh)
        surface.SetMaterial(Material("pp/blurscreen"))
        surface.SetDrawColor(28,28,28,208)
        surface.DrawRect(0, 0, w, h)
    end
    hg.DrawBlur(ParentPanel, 5)
    ParentPanel:AlphaTo(255,0.15,0)

    local scroll = vgui.Create("DScrollPanel", ParentPanel)
    scroll:Dock(FILL)
    scroll:DockMargin(ScreenScale(10), ScreenScale(10), ScreenScale(10), ScreenScale(10))

    local title = vgui.Create("DLabel", scroll)
    title:Dock(TOP)
    title:SetText("Tab Stripes Shop")
    title:SetFont("ZCity_setiings_category")
    title:SetTextColor(Color(255,255,255))
    title:SizeToContents()
    title:DockMargin(0, 0, 0, ScreenScale(5))

    -- Отображение баланса
    local balLabel = vgui.Create("DLabel", scroll)
    balLabel:Dock(TOP)
    balLabel:SetText("Your balance: " .. LocalPlayer():GetNWInt("izi", 0) .. " izi")
    balLabel:SetFont("ZCity_setiings_fine")
    balLabel:SetTextColor(Color(255, 200, 50))
    balLabel:SizeToContents()
    balLabel:DockMargin(0, 0, 0, ScreenScale(10))
    balLabel.Think = function(self)
        self:SetText("Your balance: " .. LocalPlayer():GetNWInt("izi", 0) .. " izi")
    end

    local layout = vgui.Create("DIconLayout", scroll)
    layout:Dock(TOP)
    layout:SetSpaceX(ScreenScale(10))
    layout:SetSpaceY(ScreenScale(10))

    local currentStripe = LocalPlayer():GetNWString("TabStripe", "")

    local function DrawStripePreview(id, w, h)
        local stripeData = zb.CustomStripes and zb.CustomStripes[id]
        local gifData = zb.GifStripes and zb.GifStripes[id]

        -- 1. Пытаемся нарисовать GIF
        if gifData and istable(gifData.frames) and gifData.frames[1] then
            local time = CurTime() % (gifData.totalDuration or 1)
            local frameToDraw = gifData.frames[1]
            
            for i, frame in ipairs(gifData.frames) do
                if time >= frame.startTime and time < frame.startTime + frame.delay then
                    frameToDraw = frame
                    break
                end
            end
            
            -- Строгая проверка функцией IsMaterial
            if istable(frameToDraw) and type(frameToDraw.mat) == "IMaterial" then
                surface.SetMaterial(frameToDraw.mat)
                surface.SetDrawColor(255, 255, 255, 255)
                local uvW = frameToDraw.uvW or 1
                local uvH = frameToDraw.uvH or 1
                surface.DrawTexturedRectUV(0, 0, w, h, 0, 0, uvW, uvH)
                return -- Успешно нарисовали гифку, выходим
            end
        end

        -- 2. Пытаемся нарисовать обычную картинку или цвет
        if istable(stripeData) then
            if stripeData.material then
                -- Если вдруг написали путь строкой вместо Material()
                if isstring(stripeData.material) then
                    stripeData.material = Material(stripeData.material)
                end
                
                -- Строгая проверка функцией IsMaterial
                if type(stripeData.material) == "IMaterial" then
                    surface.SetMaterial(stripeData.material)
                    surface.SetDrawColor(255, 255, 255, 255)
                    surface.DrawTexturedRect(0, 0, w, h)
                    return -- Успешно нарисовали картинку
                end
            elseif stripeData.col1 then
                -- Рисуем цвет
                surface.SetDrawColor(stripeData.col1.r, stripeData.col1.g, stripeData.col1.b, stripeData.col1.a)
                surface.DrawRect(0, 0, w, h)
                if stripeData.col2 then
                    surface.SetDrawColor(stripeData.col2.r, stripeData.col2.g, stripeData.col2.b, stripeData.col2.a)
                    surface.DrawRect(0, h / 2, w, h / 2)
                end
                return -- Успешно нарисовали цвет
            end
        end

        -- 3. Запасной вариант (Стандартная полоска)
        surface.SetDrawColor(160, 30, 30, 255)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(130, 10, 10, 255)
        surface.DrawRect(0, h / 2, w, h / 2)
    end

    local function CreateCard(id, name, price)
        local card = layout:Add("DPanel")
        
        local baseW = ScreenScale(80)
        local baseH = ScreenScale(45)
        card:SetSize(baseW, baseH)
        card.HoverLerp = 0
        
        function card:Think()
            local hovered = self:IsHovered() or (IsValid(self.btn) and self.btn:IsHovered())
            self.HoverLerp = LerpFT(0.15, self.HoverLerp, hovered and 1 or 0)
            
            local newW = baseW + self.HoverLerp * ScreenScale(5)
            local newH = baseH + self.HoverLerp * ScreenScale(4)
            
            if self:GetWide() != math.Round(newW) or self:GetTall() != math.Round(newH) then
                self:SetSize(newW, newH)
                layout:InvalidateLayout()
            end
        end

        card.Paint = function(self, w, h)
            if self.HoverLerp > 0.01 then
                draw.RoundedBox(6, -2, -2, w + 4, h + 4, Color(0, 0, 0, 50 * self.HoverLerp))
            end
            
            draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 45, 250))
            
            local borderCol = Color(
                Lerp(self.HoverLerp, 80, 199), 
                Lerp(self.HoverLerp, 80, 0), 
                Lerp(self.HoverLerp, 100, 0), 255
            )
            surface.SetDrawColor(borderCol)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            
            local previewH = ScreenScale(12)
            DrawStripePreview(id, w - 0, previewH)
            
            draw.SimpleText(name, "ZCity_setiings_fine", 10, previewH + 5, Color(255,255,255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            
            local priceText = price > 0 and ("Price: " .. price .. " izi") or "Is free"
            draw.SimpleText(priceText, "ZCity_setiings_tiny", 10, previewH + 35, Color(255,200,50), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end

        local btn = vgui.Create("DButton", card)
        btn:Dock(BOTTOM)
        btn:DockMargin(5, 0, 5, 5)
        btn:SetTall(ScreenScale(12))
        btn:SetText("")
        btn:SetFont("ZCity_setiings_tiny")
        card.btn = btn
        
        -- Функция для получения актуального статуса каждый кадр
        local function GetState()
            local isEquipped = (currentStripe == id) or (currentStripe == "" and id == "default")
            local isOwned = (id == "default") or LocalPlayer():GetNWBool("owns_stripe_" .. id, false)
            local balance = LocalPlayer():GetNWInt("izi", 0)
            return isEquipped, isOwned, balance
        end

        function btn:Paint(w, h)
            local isEquipped, isOwned, balance = GetState()
            
            local bgCol = Color(30, 160, 35, 255)
            local text = "Install"
            
            if isEquipped then
                bgCol = Color(100, 100, 100, 255)
                text = "Installed"
            elseif not isOwned then
                if balance >= price then
                    bgCol = Color(180, 130, 30, 255) -- Хватает денег (оранжевый)
                else
                    bgCol = Color(120, 30, 30, 255)  -- Не хватает денег (тёмно-красный)
                end
                text = "Buy (" .. price .. ")"
            end

            if self:IsHovered() and not isEquipped then
                bgCol = Color(Lerp(0.1, bgCol.r, 255), Lerp(0.1, bgCol.g, 255), Lerp(0.1, bgCol.b, 255), 255)
            end

            draw.RoundedBox(4, 0, 0, w, h, bgCol)
            draw.SimpleText(text, "ZCity_setiings_tiny", w/2, h/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        function btn:DoClick()
            local isEquipped, isOwned, balance = GetState()
            if isEquipped then return end
            
            if isOwned then
                -- Если уже куплено — просто устанавливаем
                net.Start("ZB_SetTabStripe")
                    net.WriteString(id)
                net.SendToServer()
                surface.PlaySound("buttons/button14.wav")
                currentStripe = id
            else
                -- Если не куплено — пытаемся купить
                if balance >= price then
                    net.Start("ZB_BuyStripe")
                        net.WriteString(id)
                    net.SendToServer()
                    surface.PlaySound("buttons/button14.wav")
                    -- Сервер сам выдаст полоску и наденет её, а клиент увидит обновление NWVar'ов
                else
                    notification.AddLegacy("Недостаточно izi!", NOTIFY_ERROR, 3)
                    surface.PlaySound("buttons/button10.wav")
                end
            end
        end
    end

    CreateCard("default", "Standard", 0)

    for id, data in pairs(zb.CustomStripes) do
        CreateCard(id, id, data.price or 100) 
    end
end