AddCSLuaFile()

SWEP.Base = "weapon_pill_base"

SWEP.PrintName = "Nitroglycerin 0.5 mg"
SWEP.Instructions = "Sublingual tablet. Very fast and short blood pressure drop."
SWEP.Category = "ZCity Medicine"

SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.WorldModel = "models/bloocobalt/l4d/items/w_eq_pills.mdl"

if CLIENT then
	SWEP.WepSelectIcon = Material("vgui/Nitroglycerin.png")
	SWEP.IconOverride = "vgui/Nitroglycerin.png"
	SWEP.BounceWeaponIcon = false
end

function SWEP:ApplyPill(org, ent)
    if hg and hg.pressure and hg.pressure.AddDrug then
        hg.pressure.AddDrug(org, "nitroglycerin")
    end
end