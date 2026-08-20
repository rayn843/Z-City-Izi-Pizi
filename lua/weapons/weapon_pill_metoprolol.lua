AddCSLuaFile()

SWEP.Base = "weapon_pill_base"

SWEP.PrintName = "Metoprolol 50 mg"
SWEP.Instructions = "A beta blocker. Lowers blood pressure and pulse."
SWEP.Category = "ZCity Medicine"

SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.WorldModel = "models/bloocobalt/l4d/items/w_eq_pills.mdl"

if CLIENT then
	SWEP.WepSelectIcon = Material("vgui/Metoprolol.png")
	SWEP.IconOverride = "vgui/Metoprolol.png"
	SWEP.BounceWeaponIcon = false
end

function SWEP:ApplyPill(org, ent)
    if hg and hg.pressure and hg.pressure.AddDrug then
        hg.pressure.AddDrug(org, "metoprolol")
    end
end