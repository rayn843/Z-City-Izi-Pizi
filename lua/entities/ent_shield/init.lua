AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel(self.Model)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
    self:SetUseType(SIMPLE_USE)
    self:DrawShadow(false)
    self:SetModelScale(1)
    
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:SetMass(10)
        phys:Wake()
        phys:EnableMotion(true)
    end
end

function ENT:Use(activator)
    self:TakeByPlayer(activator)
end

function ENT:TakeByPlayer(activator) -- пу пу пу
    if not IsValid(activator) or not activator:IsPlayer() then return end
    if activator:GetNWBool("HasShield", false) then return end
    activator.inventory = activator:GetNetVar("Inventory") or activator.inventory
    if not activator.inventory["Weapons"] then activator.inventory["Weapons"] = {} end
    activator.inventory["Weapons"]["hg_shield"] = true
    activator:SetNetVar("Inventory", activator.inventory)
    activator:SetNWBool("HasShield", true)
    activator:ViewPunch(AngleRand(-1, 1))
    self:EmitSound("snds_jack_gmod/ez_weapons/handling/draw_longgun4.wav", 65, math.random(95, 105), 1, CHAN_ITEM)
    
    local wep = activator:GetActiveWeapon()
    if IsValid(wep) and wep.ishgweapon and not wep:IsPistolHoldType() then
        local foundPistol = false
        for _, w in ipairs(activator:GetWeapons()) do
            if w.ishgweapon and w:IsPistolHoldType() then
                activator:SelectWeapon(w:GetClass())
                foundPistol = true
                break
            end
        end
        if not foundPistol then
            activator:SelectWeapon("weapon_hands_sh")
        end
    end
    
    self:Remove()
end