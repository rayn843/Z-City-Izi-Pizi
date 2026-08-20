AddCSLuaFile()

SWEP.Base = "weapon_pill_base"

SWEP.PrintName = "Nifedipine 10 mg"
SWEP.Instructions = "A fast calcium channel blocker. Strongly lowers blood pressure."
SWEP.Category = "ZCity Medicine"

SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.WorldModel = "models/bloocobalt/l4d/items/w_eq_pills.mdl"

if CLIENT then
	SWEP.WepSelectIcon = Material("vgui/Nifedipine.png")
	SWEP.IconOverride = "vgui/Nifedipine.png"
	SWEP.BounceWeaponIcon = false
end

function SWEP:ApplyPill(org, ent)
    if hg and hg.pressure and hg.pressure.AddDrug then
        hg.pressure.AddDrug(org, "nifedipine")
    end
end