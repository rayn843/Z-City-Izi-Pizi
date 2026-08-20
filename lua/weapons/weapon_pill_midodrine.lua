AddCSLuaFile()

SWEP.Base = "weapon_pill_base"

SWEP.PrintName = "Midodrine 5 mg"
SWEP.Instructions = "A vasoconstrictor. Increases blood pressure."
SWEP.Category = "ZCity Medicine"

SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.WorldModel = "models/bloocobalt/l4d/items/w_eq_pills.mdl"

if CLIENT then
	SWEP.WepSelectIcon = Material("vgui/Midodrine.png")
	SWEP.IconOverride = "vgui/Midodrine.png"
	SWEP.BounceWeaponIcon = false
end

function SWEP:ApplyPill(org, ent)
    if hg and hg.pressure and hg.pressure.AddDrug then
        hg.pressure.AddDrug(org, "midodrine")
    end
end