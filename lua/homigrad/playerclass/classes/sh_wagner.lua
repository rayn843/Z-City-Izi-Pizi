local CLASS = player.RegClass("wagner")

function CLASS.Off(self)
    if CLIENT then return end
end

local rusnames = {
    "Кирилл", "Иван", "Игорь", "Владислав", "Святослав", "Владимир",
    "Евгений", -- Пригожин
    "Дмитрий", "Александр", "Егор", "Роман", "Ярослав",
    "Михаил", "Арсений", "Фёдор", "Матвей", "Максим", "Никита"
}

local models = {
    "models/dejtriyev/smo/zuperzoldat.mdl",
}

function CLASS.On(self)
    if CLIENT then return end
    
    -- Вызываем функцию из таблицы hg.Appearance
    local Appearance = hg.Appearance.GetRandomAppearance()
    
    self:SetNWString("PlayerName","")
    self:SetPlayerColor(Color(25,90,0):ToVector())
    self:SetModel(table.Random(models))

    Appearance.Attachmets = "none"
    self:SetNetVar("Accessories", Appearance.Attachmets or "none")

    self:SetSubMaterial()
    Appearance.ClothesStyle = ""
    self:SetNWString("PlayerName",rusnames[ math.random(#rusnames) ])
    self.CurAppearance = Appearance
end

-- Я вам устрою СВО