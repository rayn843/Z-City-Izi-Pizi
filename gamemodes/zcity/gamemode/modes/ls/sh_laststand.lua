local MODE = MODE

zb = zb or {}

-- Список оружия для лёгкой команды [class] = {Название, Цена}
LS_LightWeps = {
    {class = "weapon_p22", name = "P22", cost = 1},
    {class = "weapon_cz75", name = "CZ75", cost = 2},
    {class = "weapon_glock17", name = "Glock 17", cost = 2},
    {class = "weapon_hk_usp", name = "HK USP", cost = 2},
    {class = "weapon_revolver2", name = "Revolver", cost = 3},
    {class = "weapon_deagle", name = "Desert Eagle", cost = 4},
    {class = "weapon_doublebarrel_short", name = "Sawn-off", cost = 3},
    {class = "weapon_skorpion", name = "Skorpion", cost = 5},
    {class = "weapon_mac11", name = "MAC-11", cost = 5}
}

-- Список экипировки (можно выбрать только одну)
LS_LightEquip = {
    {class = "none", name = "No Armor", cost = 0},
    {class = "ent_armor_vest3", name = "Light Vest", cost = 2},
    {class = "ent_armor_helmet7", name = "Light Helmet", cost = 2}
}