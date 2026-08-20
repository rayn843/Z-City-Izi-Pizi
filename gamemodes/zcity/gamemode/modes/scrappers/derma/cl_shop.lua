local PANEL = {}

local MODE = MODE

local gradient_d = Material("vgui/gradient-d")
local gradient_u = Material("vgui/gradient-u")

local red = Color(239, 47, 47)
local red2 = Color(78, 16, 16)

local green = Color(81, 213, 67)

local animInProgress = false

local function SlidePanel(oldPanel, newPanel)
    if !animInProgress then
        animInProgress = true
        animations.CurrentX = sh
        animations.OldX = 0
        animations:CreateAnimation(1, {
            index = 1,
            target = {
                CurrentX = 0,
                OldX = -sh
            },
            easing = "outExpo",
            bIgnoreConfig = true,
            Think = function()
                if !IsValid(oldPanel) or !IsValid(newPanel) then return end
                newPanel:SetY(animations.CurrentX)
                oldPanel:SetY(animations.OldX)
            end,
            OnComplete = function()
                animations.CurrentX = nil
                animations.OldX = nil
                animInProgress = false
            end
        })
    end
end

local function SlidePanelBack(oldPanel, newPanel)
    if !animInProgress then
        animInProgress = true
        animations.CurrentX = -sh
        animations.OldX = 0
        animations:CreateAnimation(1, {
            index = 1,
            target = {
                CurrentX = 0,
                OldX = sh
            },
            easing = "outExpo",
            bIgnoreConfig = true,
            Think = function()
                if !IsValid(oldPanel) or !IsValid(newPanel) then return end
                newPanel:SetY(animations.CurrentX)
                oldPanel:SetY(animations.OldX)
            end,
            OnComplete = function()
                animations.CurrentX = nil
                animations.OldX = nil
                animInProgress = false
            end
        })
    end
end

local ShopSound = ShopSound or nil

function PANEL:Init()
    self:SetSize(sw, sh)
    self:SetMouseInputEnabled(true)
    self:SetKeyboardInputEnabled(true)
    self:RequestFocus()

    self.time = self.time or CurTime() + MODE.LobbyTime

    if !ShopSound then
        sound.PlayFile("sound/zbattle/shop.mp3", "", function(station)
            ShopSound = station
            station:SetVolume(0.2)
        end)
    end

    if IsValid(zb.ScrappersShop) then
        zb.ScrappersShop:Remove()
    end

    self:SetAlpha(0)

    self.alpha = 0

    self:CreateAnimation(0.5, {
        index = 1,
        target = {
            alpha = 255
        },
        easing = "linear",
        bIgnoreConfig = true,
        Think = function()
            self:SetAlpha(self.alpha)
        end
    })

    timer.Simple(0.1, function() --при создании новой панельки и удалении старой, нужно немного подождать (тролл)
        gui.EnableScreenClicker(true)
        animations = vgui.Create("EditablePanel")
    end)

    zb.ScrappersShop = self

    local clouds = self:Add("ZB_ScrappersClouds")
    clouds:Dock(FILL)
    clouds:SetZPos(-999)

    self.MainFrame = self:PopulateMainMenu()
    self.ShopFrame = self:PopulateShop()
    self.InventoryFrame = self:PopulateInventory()

    local anims = {
        self.MainFrame.primary,
        self.MainFrame.secondary,
        self.MainFrame.melee,
        self.MainFrame.medicine,
        self.MainFrame.other,
        self.MainFrame.armor,
        self.MainFrame.ready
    }

    for k, v in ipairs(anims) do
        if !IsValid(v) then continue end

        v.AnimY = sh
        v.oldpos = v:GetY()

        v:CreateAnimation(1 + (k * 0.3), {
            index = k + 1,
            target = {
                AnimY = 0
            },
            easing = "outExpo",
            bIgnoreConfig = true,
            Think = function()
                v:SetY(v.oldpos + v.AnimY)
            end
        })
    end
end

function PANEL:OnRemove()
    gui.EnableScreenClicker(false)
end

function PANEL:Close()
    self.bClosing = true

    local fadeout = vgui.Create("EditablePanel")
    fadeout:MakePopup()
    fadeout:SetMouseInputEnabled(false)
    fadeout:SetKeyboardInputEnabled(false)
    fadeout:SetSize(sw, sh)
    fadeout.height = sh * 1.2
    fadeout.start = sh * 1.2
    fadeout.Paint = function(this, w, h)
        surface.SetDrawColor(15, 15, 15)
        surface.DrawRect(0, fadeout.height, sw, fadeout.start)
        surface.SetMaterial(gradient_d)
        surface.DrawTexturedRect(0, fadeout.height - sh * 0.2, sw, sh * 0.2)
        surface.SetMaterial(gradient_u)
        surface.DrawTexturedRect(0, fadeout.start, sw, sh * 0.2)
    end
    fadeout:CreateAnimation(0.5, {
        index = 1,
        target = {
            height = 0
        },
        easing = "linear",
        bIgnoreConfig = true,
        OnComplete = function()
            self:Remove()
            animations:Remove()

            fadeout:CreateAnimation(0.5, {
                index = 2,
                target = {
                    start = -sh * 0.2
                },
                easing = "linear",
                bIgnoreConfig = true,
                OnComplete = function()
                    if IsValid(ShopSound) then
                        fadeout.music = ShopSound:GetVolume()
                        fadeout:CreateAnimation(5, {
                            index = 1,
                            target = {
                                music = 0
                            },
                            easing = "linear",
                            bIgnoreConfig = true,
                            OnComplete = function()
                                fadeout:Remove()
                                ShopSound:Stop()
                                ShopSound = nil
                            end,
                            Think = function()
                                if not IsValid(ShopSound) then return end
                                ShopSound:SetVolume(fadeout.music)
                            end
                        })
                    end
                end
            })
        end
    })
end

local isReady = false
function PANEL:PopulateMainMenu()
    local frame = self:Add("EditablePanel")
    frame:SetSize(sw, sh)

    frame.ready = frame:Add("ZB_ScrappersButton")
    frame.ready:SetPos(sw * (0.5 - 0.075), sh * 0.8 )
    frame.ready:SetSize(sw * 0.15, sh * 0.05)
    frame.ready:SetText("Готов")

    frame.ready.DoClick = function(self)
        isReady = !isReady
        net.Start("ZB_PlayerReady")
            net.WriteBool(isReady)
        net.SendToServer()
        self.setalpha = isReady and 255 or 0
    end

    local market = frame:Add("ZB_ScrappersButton")
    market:SetPos(sw * 0.25, sh * 0.4)
    market:SetSize(sw * 0.15, sh * 0.05)
    market:SetText("Маркет")

    market.DoClick = function()
        SlidePanel(frame, self.ShopFrame)
    end

    local inventory = frame:Add("ZB_ScrappersButton")
    inventory:SetPos(sw * 0.6, sh * 0.4)
    inventory:SetSize(sw * 0.15, sh * 0.05)
    inventory:SetText("Инвентарь")

    inventory.DoClick = function()
        self.InventoryFrame:PopulateSlots()

        SlidePanel(frame, self.InventoryFrame)
    end

    local money = frame:Add("EditablePanel")
    money:SetPos(sw * 0.4, sh * 0.3)
    money:SetSize(sw * 0.2, sh * 0.25)

    function money:Paint(w, h)
        draw.GlowingText("$" .. LocalPlayer():GetLocalVar("zb_Scrappers_Money", MODE.StartingMoney), "ZB_ScrappersMediumLarge", w / 2, h / 2, red, red, red2, TEXT_ALIGN_CENTER)
    end

    local time = frame:Add("EditablePanel")
    time:SetPos(sw * 0.4, sh * 0.1)
    time:SetSize(sw * 0.2, sh * 0.25)

    time.Paint = function(this, w, h)
        draw.GlowingText(string.FormattedTime( math.max(zb.ScrappersLobbyTime - CurTime(), 0), "%02i:%02i" ), "ZB_ScrappersLarge", w / 2, h / 2, red, red, red2, TEXT_ALIGN_CENTER)
    end

    frame.PopulateSlots = function()
        local RaidInventory = zb.ScrappersRaidInventory or {}

        if frame.primary then frame.primary:Remove() end
        if frame.secondary then frame.secondary:Remove() end
        if frame.melee then frame.melee:Remove() end
        if frame.other then frame.other:Remove() end
        if frame.medicine then frame.medicine:Remove() end
        if frame.armor then frame.armor:Remove() end

        frame.primary  = frame:Add("ZB_MainSlot")
        frame.primary:SetSize(sw * 0.15, sh * 0.15)
        frame.primary:SetPos(sw * 0.25, sh * 0.47 )

        frame.primary.text = "Основное"

        frame.primary:SetWeapon(RaidInventory["Primary"])

        frame.primary.DoClick = function(this, k)
            net.Start("zb_FromRaidToInv")
                net.WriteString("Primary")
                net.WriteUInt(k or 0, 8) -- ИСПРАВЛЕНИЕ: Обязательно отправляем индекс (0 если строка)
            net.SendToServer()

            if k then
                table.remove(RaidInventory["Primary"], k)
            else
                RaidInventory["Primary"] = nil
            end
            this:Remove()
            
            timer.Simple(0.1 * math.max(LocalPlayer():Ping() / 10,1),function()
                frame.PopulateSlots()
            end)
        end
        frame.primary.DoRightClick = frame.primary.DoClick -- ПКМ дублирует ЛКМ

        frame.secondary  = frame:Add("ZB_MainSlot")
        frame.secondary:SetSize(sw * 0.15, sh * 0.15)
        frame.secondary:SetPos(sw * (0.5 - 0.075), sh * 0.47 )

        frame.secondary.text = "Второстепенное"

        frame.secondary:SetWeapon(RaidInventory["Secondary"])

        frame.secondary.DoClick = function(this, k)
            net.Start("zb_FromRaidToInv")
                net.WriteString("Secondary")
                net.WriteUInt(k or 0, 8) -- ИСПРАВЛЕНИЕ: Обязательно отправляем индекс (0 если строка)
            net.SendToServer()

            if k then
                table.remove(RaidInventory["Secondary"], k)
            else
                RaidInventory["Secondary"] = nil
            end
            this:Remove()

            timer.Simple(0.1 * math.max(LocalPlayer():Ping() / 10,1),function()
                frame.PopulateSlots()
            end)
        end
        frame.secondary.DoRightClick = frame.secondary.DoClick -- ПКМ дублирует ЛКМ

        frame.melee  = frame:Add("ZB_MainSlot")
        frame.melee:SetSize(sw * 0.15, sh * 0.15)
        frame.melee:SetPos(sw * 0.6, sh * 0.47 )

        frame.melee.text = "Холодное"

        frame.melee:SetWeapon(RaidInventory["Melee"])

        frame.melee.DoClick = function(this, k)
            net.Start("zb_FromRaidToInv")
                net.WriteString("Melee")
                net.WriteUInt(k, 8)
            net.SendToServer()

            table.remove(RaidInventory["Melee"], k)
            this:Remove()

            timer.Simple(0.1 * math.max(LocalPlayer():Ping() / 10,1),function()
                frame.PopulateSlots()
            end)
        end
        frame.melee.DoRightClick = frame.melee.DoClick -- ПКМ дублирует ЛКМ

        frame.medicine  = frame:Add("ZB_MainSlot")
        frame.medicine:SetSize(sw * 0.15, sh * 0.15)
        frame.medicine:SetPos(sw * 0.25, sh * 0.64 )

        frame.medicine.text = "Медицина"

        frame.medicine:SetWeapon(RaidInventory["Medicine"])

        frame.medicine.DoClick = function(this, k)
            net.Start("zb_FromRaidToInv")
                net.WriteString("Medicine")
                net.WriteUInt(k, 8)
            net.SendToServer()

            table.remove(RaidInventory["Medicine"], k)
            this:Remove()

            timer.Simple(0.1 * math.max(LocalPlayer():Ping() / 10,1),function()
                frame.PopulateSlots()
            end)
        end
        frame.medicine.DoRightClick = frame.medicine.DoClick -- ПКМ дублирует ЛКМ

        frame.other  = frame:Add("ZB_MainSlot")
        frame.other:SetSize(sw * 0.15, sh * 0.15)
        frame.other:SetPos(sw * (0.5 - 0.075), sh * 0.64 )

        frame.other.text = "Разное"

        frame.other:SetWeapon(RaidInventory["Other"])

        frame.other.DoClick = function(this, k)
            net.Start("zb_FromRaidToInv")
                net.WriteString("Other")
                net.WriteUInt(k, 8)
            net.SendToServer()

            table.remove(RaidInventory["Other"], k)
            this:Remove()

            timer.Simple(0.1 * math.max(LocalPlayer():Ping() / 10,1),function()
                frame.PopulateSlots()
            end)
        end
        frame.other.DoRightClick = frame.other.DoClick -- ПКМ дублирует ЛКМ

        frame.armor  = frame:Add("ZB_MainSlot")
        frame.armor:SetSize(sw * 0.15, sh * 0.15)
        frame.armor:SetPos(sw * 0.6, sh * 0.64 )

        frame.armor.text = "Броня"

        frame.armor:SetWeapon(RaidInventory["Armor"])

        frame.armor.DoClick = function(this, k)
            net.Start("zb_FromRaidToInv")
                net.WriteString("Armor")
                net.WriteUInt(k, 8)
            net.SendToServer()

            table.remove(RaidInventory["Armor"], k)
            this:Remove()

            timer.Simple(0.1 * math.max(LocalPlayer():Ping() / 10,1),function()
                frame.PopulateSlots()
            end)
        end
        frame.armor.DoRightClick = frame.armor.DoClick -- ПКМ дублирует ЛКМ
    end

    frame.PopulateSlots()

    return frame
end

local ShopTabs = {
    "Weapons",
    "Attachments",
    "Medicine",
    "Armor",
    "Other"
}

local ShopTabsRussian = {
    ["Weapons"] = "Оружие",
    ["Attachments"] = "Обвесы",
    ["Medicine"] = "Медицина",
    ["Armor"] = "Броня",
    ["Other"] = "Разное"
}

function PANEL:PopulateShop()
    local frame = self:Add("EditablePanel")
    frame:SetSize(sw, sh)
    frame:SetPos(0, sh)

    local tablabel = {}
    local tabscroll = {}

    local count = #ShopTabs
    local offset = ((sw / 2) - (count * (sw * 0.2) / 2)) - sw * 0.175
    for k, v in ipairs(ShopTabs) do
        tabscroll[v] = frame:Add("DScrollPanel")
        tabscroll[v]:SetPos(offset + (sw * 0.2 * k), sh * 0.12)
        tabscroll[v]:SetSize(sw * 0.15, sh * 0.75)

        tabscroll[v].Paint = function(this, w, h)
            surface.SetDrawColor(15, 15, 15, 100)
            surface.DrawRect(0, 0, w, h)
        end

        tabscroll[v]:GetVBar():SetSize(0, 0)

        tablabel[v] = frame:Add("DLabel")
        tablabel[v]:SetPos(offset + (sw * 0.2 * k), sh * 0.05)
        tablabel[v]:SetContentAlignment(5)
        tablabel[v]:SetSize(sw * 0.15, sh * 0.06)
        tablabel[v]:SetFont("ZB_ScrappersMediumLarge")
        tablabel[v]:SetText(ShopTabsRussian[v] or "fail")
    end

    local ShopList = zb.ScrappersScrambledList

    for k, v in pairs(ShopList) do
        for k2, v2 in pairs(ShopList[k]) do
            local tabitem = tabitem or {}
            tabitem[k] = tabitem[k] or {}

            tabitem[k][k2] = tabscroll[k]:Add("EditablePanel")
            tabitem[k][k2]:SetSize(sw * 0.15, sh * 0.15)
            tabitem[k][k2]:Dock(TOP)
            tabitem[k][k2]:DockMargin(0, 0, 0, ScreenScale(8))
            
            local weaponEnt = hg.GetItemEnt(v2.weapon) or {}
            local weaponData = weapons.Get(v2.weapon) or scripted_ents.Get(v2.weapon) or (hg and hg.GetItem and hg.GetItem(v2.weapon)) or {}

            -- Ищем иконку
            local iconMat = nil
            if weaponData.IconOverride then
                iconMat = Material(weaponData.IconOverride)
            elseif weaponData.WepSelectIcon2 then
                iconMat = weaponData.WepSelectIcon2
            elseif weaponData.WepSelectIcon then
                iconMat = weaponData.WepSelectIcon
            end

            tabitem[k][k2].btn = tabitem[k][k2]:Add("DButton")
            tabitem[k][k2].btn:Dock(FILL)
            tabitem[k][k2].btn:SetText("")
            tabitem[k][k2].btn:SetPaintBackground(false)

            -- ВОТ ЭТОТ БЛОК Я УПУСТИЛ В ПРОШЛЫЙ РАЗ (Обновление состояния)
            tabitem[k][k2].Think = function(this)
                this.BuyingOut = zb.ScrappersScrambledList[k][k2].BuyingOut
                this.Bought = zb.ScrappersScrambledList[k][k2].Bought
                this.AuctionPrice = zb.ScrappersScrambledList[k][k2].AuctionPrice
            end

            tabitem[k][k2].btn.DoClick = function(this)
                if tabitem[k][k2].Bought then return end

                local money = LocalPlayer():GetLocalVar("zb_Scrappers_Money", MODE.StartingMoney)

                if (zb.ScrappersScrambledList[k][k2].AuctionPrice and zb.ScrappersScrambledList[k][k2].AuctionPrice > money) or (zb.ScrappersScrambledList[k][k2].price > money) then return end

                if zb.ScrappersScrambledList[k][k2].BuyingOut and !zb.ScrappersScrambledList[k][k2].MeBuying then
                    zb.ScrappersScrambledList[k][k2].AuctionPrice = zb.ScrappersScrambledList[k][k2].AuctionPrice + 100
                end

                zb.ScrappersScrambledList[k][k2].MeBuying = true

                net.Start("zb_Scrappers_BuyOut")
                    net.WriteString(k)
                    net.WriteUInt(k2, 16)
                net.SendToServer()
            end

            tabitem[k][k2].btn.Paint = function(this, w, h)
                surface.SetDrawColor(red)
                surface.DrawOutlinedRect(0, 0, w, h, 2)

                if tabitem[k][k2].Bought then
                    surface.SetDrawColor(255, 255, 255, 10)
                    surface.DrawRect(2, 2, w - 4, h - 4)
                    draw.SimpleText("ПРОДАНО", "ZB_ScrappersMediumLarge", w / 2, h / 2, (zb.ScrappersScrambledList[k][k2].MeBuying and green) or red, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                else
                    -- Отрисовка 2D иконки
                    if iconMat and not iconMat:IsError() then
                        surface.SetMaterial(iconMat)
                        surface.SetDrawColor(255, 255, 255, 255)
                        local iconSize = math.min(w, h) * 0.65
                        surface.DrawTexturedRect((w - iconSize) / 2, (h - iconSize) / 2 - ScreenScale(4), iconSize, iconSize)
                    end
                end

                draw.SimpleText(weaponEnt.PrintName or weaponData.PrintName or "???", "ZB_ScrappersMedium", ScreenScale(4), ScreenScale(4))

                if tabitem[k][k2].AuctionPrice and tabitem[k][k2].AuctionPrice != v2.price then
                    draw.SimpleText("Цена: $" .. v2.price .. " + " .. tabitem[k][k2].AuctionPrice - v2.price, "ZB_ScrappersMedium", ScreenScale(4), h - ScreenScale(15))
                else
                    draw.SimpleText("Цена: $" .. v2.price, "ZB_ScrappersMedium", ScreenScale(4), h - ScreenScale(15))
                end

                if tabitem[k][k2].BuyingOut then
                    surface.SetDrawColor((zb.ScrappersScrambledList[k][k2].MeBuying and green) or color_white)
                    surface.DrawRect(ScreenScale(2), h - ScreenScale(4), w - ScreenScale(2) - (w * (1 - (tabitem[k][k2].BuyingOut + 10 - CurTime()) / 10)), ScreenScale(2))
                end
            end
        end
    end

    local returnButton = frame:Add("ZB_ScrappersButton")
    returnButton:SetPos(offset + (sw * 0.2), sh * 0.9)
    returnButton:SetSize(sw * 0.15, sh * 0.05)
    returnButton:SetText("Вернуться")

    returnButton.DoClick = function()
        SlidePanelBack(frame, self.MainFrame)
    end

    local money = frame:Add("EditablePanel")
    money:SetPos(sw * 0.4, sh * 0.8)
    money:SetSize(sw * 0.2, sh * 0.25)

    function money:Paint(w, h)
        draw.GlowingText("$" .. LocalPlayer():GetLocalVar("zb_Scrappers_Money", MODE.StartingMoney), "ZB_ScrappersMediumLarge", w / 2, h / 2, red, red, red2, TEXT_ALIGN_CENTER)
    end

    local time = frame:Add("EditablePanel")
    time:SetPos(sw * 0.8, sh * 0.8)
    time:SetSize(sw * 0.2, sh * 0.25)

    time.Paint = function(this, w, h)
        draw.GlowingText(string.FormattedTime( math.max(zb.ScrappersLobbyTime - CurTime(), 0), "%02i:%02i" ), "ZB_ScrappersLarge", w / 2, h / 2, red, red, red2, TEXT_ALIGN_CENTER)
    end

    return frame
end

local categories = {
    ["Primary"] = "Основное",
    ["Secondary"] = "Второстепенное",
    ["Melee"] = "Холодное",
    ["Medicine"] = "Медицина",
    ["Other"] = "Разное",
    ["Armor"] = "Броня",
    ["Attachments"] = "Обвесы"
}

function PANEL:PopulateInventory()
    local frame = self:Add("EditablePanel")
    frame:SetSize(sw, sh)
    frame:SetPos(0, sh)

    local scroll = frame:Add("DScrollPanel")
    scroll:SetPos(sw * 0.1, sh * 0.12)
    scroll:SetSize(sw * 0.8, sh * 0.75)

    local layout = scroll:Add("DTileLayout")
    layout:SetSpaceX(sw * 0.1375)
    layout:SetSpaceY(sh * 0.01)
    layout:SetSize(sw * 0.9, sh * 0.75)

    local tabitems = tabitems or {}

    function frame:PopulateSlots()
        local Inventory = zb.ScrappersInventory or {}
        local RaidInventory = zb.ScrappersRaidInventory or {}

        for k, v in pairs(tabitems or {}) do
            v:Remove()
        end

        tabitems = {}

        if not table.IsEmpty(Inventory) then
            for category, items in pairs(Inventory) do
                for pos, itemClass in pairs(items) do
                    -- Захватываем текущие значения в локальные переменные
                    local cat = category
                    local idx = pos
                    local item = itemClass

                    local weaponData = weapons.Get(item) or scripted_ents.Get(item) or (hg and hg.GetItem and hg.GetItem(item)) or {}
                    local weaponEnt = hg.GetItemEnt(item) or {}

                    -- Ищем иконку
                    local iconMat = nil
                    if weaponData.IconOverride then
                        iconMat = Material(weaponData.IconOverride)
                    elseif weaponData.WepSelectIcon2 then
                        iconMat = weaponData.WepSelectIcon2
                    elseif weaponData.WepSelectIcon then
                        iconMat = weaponData.WepSelectIcon
                    end

                    local panel = layout:Add("EditablePanel")
                    panel:SetSize(sw * 0.15, sh * 0.15)
                    tabitems[#tabitems + 1] = panel

                    panel.btn = panel:Add("DButton")
                    panel.btn:Dock(FILL)
                    panel.btn:SetText("")
                    panel.btn:SetPaintBackground(false)

                    -- ЛКМ – перенос в рейдовый инвентарь
                    panel.btn.DoClick = function(this)
                        local slot = weaponData.ScrappersSlot or cat or "Other"
                        net.Start("zb_FromInvToRaid")
                            net.WriteString(cat)
                            net.WriteUInt(idx, 16)
                        net.SendToServer()

                        panel:Remove()

                        timer.Simple(0.1 * math.max(LocalPlayer():Ping() / 10, 1), function()
                            if IsValid(zb.ScrappersShop) and zb.ScrappersShop.MainFrame then
                                zb.ScrappersShop.MainFrame:PopulateSlots()
                            end
                        end)
                    end

                    -- ПКМ – продажа предмета
                    panel.btn.DoRightClick = function(this)
                        local slot = weaponData.ScrappersSlot or cat or "Other"
                        net.Start("zb_SellItem")
                            net.WriteString(cat)
                            net.WriteUInt(idx, 16)
                        net.SendToServer()

                        panel:Remove()

                        timer.Simple(0.1 * math.max(LocalPlayer():Ping() / 10, 1), function()
                            if IsValid(zb.ScrappersShop) and zb.ScrappersShop.MainFrame then
                                zb.ScrappersShop.MainFrame:PopulateSlots()
                            end
                        end)
                    end

                    panel.btn.Paint = function(this, w, h)
                        surface.SetDrawColor(239, 47, 47)
                        surface.DrawOutlinedRect(0, 0, w, h, 2)

                        -- Отрисовка 2D иконки
                        if iconMat and not iconMat:IsError() then
                            surface.SetMaterial(iconMat)
                            surface.SetDrawColor(255, 255, 255, 255)
                            local iconSize = math.min(w, h) * 0.65
                            surface.DrawTexturedRect((w - iconSize) / 2, (h - iconSize) / 2 - ScreenScale(4), iconSize, iconSize)
                        end

                        draw.SimpleText(weaponEnt.PrintName or weaponData.PrintName or "???", "ZB_ScrappersMedium", ScreenScale(4), ScreenScale(4))
                        draw.SimpleText(categories[cat] or "Разное", "ZB_ScrappersMedium", ScreenScale(4), h - ScreenScale(12))
                    end
                end
            end
        end
    end

    frame:PopulateSlots()

    local returnButton = frame:Add("ZB_ScrappersButton")
    returnButton:SetPos(sw * 0.05, sh * 0.9)
    returnButton:SetSize(sw * 0.15, sh * 0.05)
    returnButton:SetText("Вернуться")

    returnButton.DoClick = function()
        SlidePanelBack(frame, self.MainFrame)
    end

    local money = frame:Add("EditablePanel")
    money:SetPos(sw * 0.4, sh * 0.8)
    money:SetSize(sw * 0.2, sh * 0.25)

    function money:Paint(w, h)
        draw.GlowingText("$" .. LocalPlayer():GetLocalVar("zb_Scrappers_Money", MODE.StartingMoney), "ZB_ScrappersMediumLarge", w / 2, h / 2, red, red, red2, TEXT_ALIGN_CENTER)
    end

    local time = frame:Add("EditablePanel")
    time:SetPos(sw * 0.8, sh * 0.8)
    time:SetSize(sw * 0.2, sh * 0.25)

    time.Paint = function(this, w, h)
        draw.GlowingText(string.FormattedTime( math.max(zb.ScrappersLobbyTime - CurTime(), 0), "%02i:%02i" ), "ZB_ScrappersLarge", w / 2, h / 2, red, red, red2, TEXT_ALIGN_CENTER)
    end

    return frame
end

function PANEL:Paint(w, h)
    surface.SetDrawColor(15, 15, 15)
    surface.DrawRect(0, 0, w, h)
end

vgui.Register("ZB_ScrappersShop", PANEL, "EditablePanel")