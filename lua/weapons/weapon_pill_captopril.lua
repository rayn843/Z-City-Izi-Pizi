AddCSLuaFile()

SWEP.Base = "weapon_pill_base"

SWEP.PrintName = "Captopril 25 mg"
SWEP.Instructions = "A pill used to lower blood pressure."
SWEP.Category = "ZCity Medicine"

SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.WorldModel = "models/bloocobalt/l4d/items/w_eq_pills.mdl"

if CLIENT then
	SWEP.WepSelectIcon = Material("vgui/Captopril.png")
	SWEP.IconOverride = "vgui/Captopril.png"
	SWEP.BounceWeaponIcon = false
end

function SWEP:ApplyPill(org, ent)
    if hg and hg.pressure and hg.pressure.AddDrug then
        hg.pressure.AddDrug(org, "captopril")
    end
end