local SceneElements = {}
local SelectedElement = nil
local IsDragging = false
local DragOffsetX, DragOffsetY = 0, 0
local MakerFrame = nil

-- Элементы инспектора
local InsX, InsY, InsW, InsH, InsText

local function GenerateCode()
    print("\n--- СГЕНЕРИРОВАННЫЙ КОД ---")
    for _, data in ipairs(SceneElements) do
        print(string.format("local %s = vgui.Create('%s', Parent)", data.varName, data.className))
        print(string.format("%s:SetPos(%d, %d)", data.varName, data.x, data.y))
        print(string.format("%s:SetSize(%d, %d)", data.varName, data.w, data.h))
        if data.text and data.text ~= "" then
            print(string.format("%s:SetText('%s')", data.varName, data.text))
        end
        print("")
    end
    print("--- КОНЕЦ КОДА ---\n")
end

local function UpdateInspector(data)
    if not IsValid(InsX) then return end
    if not data then
        InsX:SetValue(0); InsY:SetValue(0); InsW:SetValue(0); InsH:SetValue(0); InsText:SetText("")
        return
    end
    InsX:SetValue(data.x)
    InsY:SetValue(data.y)
    InsW:SetValue(data.w)
    InsH:SetValue(data.h)
    InsText:SetText(data.text or "")
end

-- Вспомогательная функция для подсчета таблицы
local function TableCount(t)
    local c = 0
    for _ in pairs(t) do c = c + 1 end
    return c
end

local function CreateSceneElement(className, defaultW, defaultH, defaultText)
    if not IsValid(MakerFrame) then return end
    local Canvas = MakerFrame.Canvas
    
    local pnl = vgui.Create(className, Canvas)
    pnl:SetSize(defaultW, defaultH)
    pnl:SetPos(Canvas:GetWide()/2 - defaultW/2, Canvas:GetTall()/2 - defaultH/2)
    if defaultText then pnl:SetText(defaultText) end
    pnl:SetMouseInputEnabled(true)

    local data = {
        panel = pnl,
        className = className,
        varName = className .. (TableCount(SceneElements) + 1),
        x = pnl:GetX(), y = pnl:GetY(), w = defaultW, h = defaultH,
        text = defaultText or ""
    }
    table.insert(SceneElements, data)

    -- Выделение и перетаскивание
    pnl.OnMousePressed = function(self, mc)
        if mc == MOUSE_LEFT then
            SelectedElement = data
            self:MoveToFront()
            UpdateInspector(data)
            IsDragging = true
            local cx, cy = self:LocalToScreen(0, 0)
            local mx, my = gui.MousePos()
            DragOffsetX = mx - cx
            DragOffsetY = my - cy
        end
    end

    pnl.OnMouseReleased = function(self, mc)
        if mc == MOUSE_LEFT and IsDragging then
            IsDragging = false
            data.x, data.y = self:GetPos()
            UpdateInspector(data)
            GenerateCode()
        end
    end
    
    UpdateInspector(data)
end

local function ToggleVGUIMaker()
    if IsValid(MakerFrame) then
        MakerFrame:Remove()
        MakerFrame = nil
        return
    end

    SceneElements = {}
    SelectedElement = nil

    MakerFrame = vgui.Create("DFrame")
    MakerFrame:SetSize(ScrW(), ScrH())
    MakerFrame:SetPos(0, 0)
    MakerFrame:SetTitle("VGUI Maker | Выдели элемент -> Измени свойства справа -> Нажми DELETE чтобы удалить")
    MakerFrame:SetDraggable(false)
    MakerFrame:ShowCloseButton(true)
    MakerFrame:MakePopup()
    MakerFrame:SetKeyboardInputEnabled(true)
    
    MakerFrame.OnClose = function() MakerFrame = nil end

    -- ТУЛБАР (Слева)
    local Toolbar = vgui.Create("DPanel", MakerFrame)
    Toolbar:Dock(LEFT)
    Toolbar:SetWide(140)
    Toolbar:DockMargin(0, 25, 0, 0)
    Toolbar:SetBackgroundColor(Color(40, 40, 40))

    local function AddToolButton(text, className, w, h, defaultText)
        local btn = vgui.Create("DButton", Toolbar)
        btn:Dock(TOP)
        btn:SetText(text)
        btn:DockMargin(5, 5, 5, 0)
        btn:SetTall(25)
        btn.DoClick = function()
            CreateSceneElement(className, w, h, defaultText)
        end
    end

    AddToolButton("DFrame (Окно)", "DFrame", 300, 200, "My Window")
    AddToolButton("DButton (Кнопка)", "DButton", 120, 40, "Click Me")
    AddToolButton("DPanel (Панель)", "DPanel", 150, 150, nil)
    AddToolButton("DTextEntry (Ввод)", "DTextEntry", 200, 30, "Введите текст...")
    AddToolButton("DLabel (Текст)", "DLabel", 100, 20, "Привет!")
    AddToolButton("DCheckBox (Галка)", "DCheckBox", 20, 20, nil)

    -- ИНСПЕКТОР (Справа)
    local Inspector = vgui.Create("DPanel", MakerFrame)
    Inspector:Dock(RIGHT)
    Inspector:SetWide(220)
    Inspector:DockMargin(0, 25, 0, 0)
    Inspector:SetBackgroundColor(Color(40, 40, 40))
    
    local function AddInspectorRow(label, defaultVal)
        local lbl = vgui.Create("DLabel", Inspector)
        lbl:Dock(TOP)
        lbl:SetText(label)
        lbl:DockMargin(5, 5, 0, 0)
        lbl:SetTextColor(Color(255,255,255))
        
        -- ИСПРАВЛЕНО: DNumWang заменен на DNumberWang
        local wang = vgui.Create("DNumberWang", Inspector)
        wang:Dock(TOP)
        wang:DockMargin(5, 0, 5, 5)
        wang:SetDecimals(0)
        wang:SetValue(defaultVal or 0)
        return wang
    end

    InsX = AddInspectorRow("X (Позиция):", 0)
    InsY = AddInspectorRow("Y (Позиция):", 0)
    InsW = AddInspectorRow("Ширина:", 0)
    InsH = AddInspectorRow("Высота:", 0)

    local txtLbl = vgui.Create("DLabel", Inspector)
    txtLbl:Dock(TOP)
    txtLbl:SetText("Текст:")
    txtLbl:DockMargin(5, 10, 0, 0)
    txtLbl:SetTextColor(Color(255,255,255))
    
    InsText = vgui.Create("DTextEntry", Inspector)
    InsText:Dock(TOP)
    InsText:DockMargin(5, 0, 5, 5)

    -- Логика применения значений из Инспектора
    local function ApplyInspector()
        if not SelectedElement or not IsValid(SelectedElement.panel) then return end
        
        local newX = math.Clamp(InsX:GetValue(), 0, MakerFrame.Canvas:GetWide())
        local newY = math.Clamp(InsY:GetValue(), 0, MakerFrame.Canvas:GetTall())
        local newW = math.Clamp(InsW:GetValue(), 5, 2000)
        local newH = math.Clamp(InsH:GetValue(), 5, 2000)
        local newText = InsText:GetText()

        SelectedElement.panel:SetPos(newX, newY)
        SelectedElement.panel:SetSize(newW, newH)
        
        if SelectedElement.className == "DLabel" then
            SelectedElement.panel:SetText(newText)
            SelectedElement.panel:SizeToContentsX()
        elseif SelectedElement.className ~= "DPanel" and SelectedElement.className ~= "DCheckBox" then
            SelectedElement.panel:SetText(newText)
        end

        SelectedElement.x = newX
        SelectedElement.y = newY
        SelectedElement.w = newW
        SelectedElement.h = newH
        SelectedElement.text = newText
        
        GenerateCode()
    end

    InsX.OnValueChanged = ApplyInspector
    InsY.OnValueChanged = ApplyInspector
    InsW.OnValueChanged = ApplyInspector
    InsH.OnValueChanged = ApplyInspector
    InsText.OnEnter = ApplyInspector
    InsText.OnLoseFocus = ApplyInspector

    -- ХОЛСТ (По центру)
    local Canvas = vgui.Create("DPanel", MakerFrame)
    Canvas:Dock(FILL)
    Canvas:DockMargin(0, 25, 0, 0)
    Canvas:SetBackgroundColor(Color(60, 60, 60))
    MakerFrame.Canvas = Canvas

    -- ДВИЖЕНИЕ И УДАЛЕНИЕ
    MakerFrame.Think = function()
        -- Перетаскивание
        if IsDragging and SelectedElement and input.IsMouseDown(MOUSE_LEFT) then
            local mx, my = gui.MousePos()
            local newX = mx - DragOffsetX
            local newY = my - DragOffsetY
            
            local cx, cy = Canvas:ScreenToLocal(newX, newY)
            
            cx = math.Clamp(cx, 0, Canvas:GetWide() - SelectedElement.panel:GetWide())
            cy = math.Clamp(cy, 0, Canvas:GetTall() - SelectedElement.panel:GetTall())

            SelectedElement.panel:SetPos(cx, cy)
            
            InsX:SetValue(cx)
            InsY:SetValue(cy)
        end

        -- Удаление по Delete
        if input.IsKeyDown(KEY_DELETE) and SelectedElement then
            if IsValid(SelectedElement.panel) then
                SelectedElement.panel:Remove()
            end
            for k, v in ipairs(SceneElements) do
                if v == SelectedElement then
                    table.remove(SceneElements, k)
                    break
                end
            end
            SelectedElement = nil
            UpdateInspector(nil)
            GenerateCode()
        end
    end
end

concommand.Add("vgui_maker", ToggleVGUIMaker)
MsgC(Color(0, 255, 0), "[VGUI Maker] Загружен! Введи vgui_maker в консоль.\n")