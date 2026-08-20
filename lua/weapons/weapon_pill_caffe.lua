AddCSLuaFile()

SWEP.Base = "weapon_pill_base"

SWEP.PrintName = "Caffeine 200 mg"
SWEP.Instructions = "A stimulant. Slightly increases blood pressure and pulse."
SWEP.Category = "ZCity Medicine"

SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.WorldModel = "models/bloocobalt/l4d/items/w_eq_pills.mdl"

if CLIENT then
	SWEP.WepSelectIcon = Material("vgui/Caffeine.png")
	SWEP.IconOverride = "vgui/Caffeine.png"
	SWEP.BounceWeaponIcon = false
end

function SWEP:ApplyPill(org, ent)
    if hg and hg.pressure and hg.pressure.AddDrug then
        hg.pressure.AddDrug(org, "caffeine")
    end
end