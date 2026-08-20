local PANEL = {}
local red = Color(239, 47, 47)

function PANEL:Init()
    self.text = "Разное"
end

function PANEL:SetWeapon(weapon)
    -- Если передан список предметов (таблица)
    if istable(weapon) then
        local slots = {}

        self.scroll = self:Add("DScrollPanel")
        self.scroll:Dock(FILL)
        self.scroll:DockMargin(0, 0, 0, ScreenScale(10))

        self.scroll:GetVBar():SetSize(0, 0)
        
        for k, v in pairs(weapon) do
            local weapon2 = weapons.Get(v) or scripted_ents.Get(v) or (hg and hg.GetItem and hg.GetItem(v)) or {}

            slots[k] = self.scroll:Add("ZB_ScrappersButton")
            slots[k]:Dock(TOP)
            slots[k]:DockMargin(ScreenScale(1), ScreenScale(1), ScreenScale(1), 0)
            slots[k]:SetTall(ScreenScale(11))
            slots[k]:SetFont("ZB_ScrappersMedium")
            slots[k]:SetText(weapon2.PrintName or "fail")

            slots[k].DoClick = function(this)
                self:DoClick(k)
            end
            -- Если у кнопок внутри списка тоже нужен правый клик:
            slots[k].DoRightClick = function(this)
                if self.DoRightClick then self:DoRightClick(k) end
            end
        end

        self.Paint = function(this, w, h)
            surface.SetDrawColor(red)
            surface.DrawOutlinedRect(0, 0, w, h, 2)

            surface.DrawRect(0, h - ScreenScale(10), w, ScreenScale(10))
            draw.SimpleText(self.text, "ZB_ScrappersMedium", ScreenScale(4), h - ScreenScale(11))
        end

    -- ИЗМЕНЕННЫЙ БЛОК: Если передан одиночный предмет (строка)
    elseif weapon then
        -- Универсальное получение данных предмета (оружие, броня, медицина)
        local weapon2 = weapons.Get(weapon) or scripted_ents.Get(weapon) or (hg and hg.GetItem and hg.GetItem(weapon)) or {}

        -- Ищем доступную 2D иконку в параметрах предмета
        local iconMat = nil
        if weapon2.IconOverride then
            iconMat = Material(weapon2.IconOverride)
        elseif weapon2.WepSelectIcon2 then
            iconMat = weapon2.WepSelectIcon2
        elseif weapon2.WepSelectIcon then
            iconMat = weapon2.WepSelectIcon
        end

        -- Вместо DModelPanel создаем прозрачную интерактивную панель-кнопку
        self.iconButton = self:Add("DButton")
        self.iconButton:Dock(FILL)
        self.iconButton:SetText("")
        self.iconButton:SetPaintBackground(false)

        -- Перенаправляем клики на родительский слот ZB_MainSlot
        self.iconButton.DoClick = function(this)
            if self.DoClick then self:DoClick() end
        end
        self.iconButton.DoRightClick = function(this)
            if self.DoRightClick then self:DoRightClick() end
        end

        -- Отрисовка 2D интерфейса слота
        self.iconButton.Paint = function(this, w, h)
            -- Обводка слота
            surface.SetDrawColor(red)
            surface.DrawOutlinedRect(0, 0, w, h, 2)

            -- Если иконка успешно найдена и загружена, рисуем её
            if iconMat and not iconMat:IsError() then
                surface.SetMaterial(iconMat)
                surface.SetDrawColor(255, 255, 255, 255)
                
                -- Автоматически масштабируем иконку под размер слота (занимает 65% пространства)
                local iconSize = math.min(w, h) * 0.65
                surface.DrawTexturedRect((w - iconSize) / 2, (h - iconSize) / 2 - ScreenScale(4), iconSize, iconSize)
            end

            -- Название пушки/предмета сверху
            if weapon2 and weapon2.PrintName then
                draw.SimpleText(weapon2.PrintName, "ZB_ScrappersMedium", ScreenScale(4), ScreenScale(4))
            end

            -- Нижняя плашка с названием категории ("Основное", "Второстепенное" и т.д.)
            surface.SetDrawColor(red)
            surface.DrawRect(0, h - ScreenScale(10), w, ScreenScale(10))
            draw.SimpleText(self.text, "ZB_ScrappersMedium", ScreenScale(4), h - ScreenScale(11))
        end
    else
        -- Отрисовка пустого слота
        self.Paint = function(this, w, h)
            surface.SetDrawColor(red)
            surface.DrawOutlinedRect(0, 0, w, h, 2)

            surface.DrawRect(0, h - ScreenScale(10), w, ScreenScale(10))
            draw.SimpleText(self.text, "ZB_ScrappersMedium", ScreenScale(4), h - ScreenScale(11))
        end
    end
end

vgui.Register("ZB_MainSlot", PANEL, "EditablePanel")