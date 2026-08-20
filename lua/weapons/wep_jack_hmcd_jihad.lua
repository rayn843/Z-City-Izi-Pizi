if SERVER then
	AddCSLuaFile()
	util.AddNetworkString("hmcd_splodetype")
elseif CLIENT then
	SWEP.DrawAmmo = false
	SWEP.DrawCrosshair = false
	SWEP.ViewModelFOV = 65
	SWEP.Slot = 4
	SWEP.SlotPos = 1
	killicon.AddFont("wep_jack_hmcd_ied", "HL2MPTypeDeath", "5", Color(0, 0, 255, 255))
	function SWEP:DrawViewModel()
		return false
	end

	function SWEP:DrawWorldModel()
		self:DrawModel()
	end

	local function drawTextShadow(t, f, x, y, c, px, py)
		color_black.a = c.a
		draw.SimpleText(t, f, x + 1, y + 1, color_black, px, py)
		draw.SimpleText(t, f, x, y, c, px, py)
		color_black.a = 255
	end

	net.Receive("hmcd_splodetype", function()
		local Ent = net.ReadEntity()
		Ent.SplodeType = net.ReadInt(32)
	end)

	function SWEP:DrawHUD()
		--
	end
end

SWEP.Base = "weapon_base"
SWEP.ViewModel = "models/props_junk/cardboard_jox004a.mdl"
SWEP.WorldModel = "models/props_junk/cardboard_jox004a.mdl"
if CLIENT then
	SWEP.WepSelectIcon = surface.GetTextureID("vgui/wep_jack_hmcd_jihad")
	SWEP.BounceWeaponIcon = false
end

SWEP.PrintName = translate and translate.jihad or "Explosive Belt"
SWEP.Instructions = "This is a concealed belt rigged with military-grade explosives surrounded by nails and ball bearings, and a detonator. Use it to end your pathetic life with one final aloha snackbar.\n\nLMB to suicide"
SWEP.Author = ""
SWEP.Contact = ""
SWEP.Purpose = ""
SWEP.BobScale = 2
SWEP.SwayScale = 2
SWEP.Weight = 3
SWEP.AutoSwitchTo = true
SWEP.AutoSwitchFrom = false
SWEP.Spawnable = true
SWEP.AdminOnly = true
SWEP.Primary.Delay = 0.5
SWEP.Primary.Recoil = 3
SWEP.Primary.Damage = 120
SWEP.Primary.NumShots = 1
SWEP.Primary.Cone = 0.04
SWEP.Primary.ClipSize = -1
SWEP.Primary.Force = 20
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"
SWEP.Secondary.Delay = 0.9
SWEP.Secondary.Recoil = 0
SWEP.Secondary.Damage = 0
SWEP.Secondary.NumShots = 1
SWEP.Secondary.Cone = 0
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"
SWEP.HomicideSWEP = true
SWEP.CarryWeight = 3500
function SWEP:Initialize()
	self:SetHoldType("normal")
end

function SWEP:SetupDataTables()
	--
end

function SWEP:PrimaryAttack()
	if not IsFirstTimePredicted() then return end
	if self:GetOwner():IsSprinting() and self:GetOwner():KeyDown(IN_FORWARD) then return end
	self:SetNextPrimaryFire(CurTime() + 2)
	if CLIENT then
		LocalPlayer():ConCommand("act zombie")
		return
	end

	sound.Play("snd_jack_hmcd_jihad" .. math.random(1, 3) .. ".wav", self:GetOwner():GetShootPos(), 75, math.random(95, 105))
	timer.Simple(math.random(.9, 1.1), function() 
		if IsValid(self) and IsValid(self:GetOwner()) and self:GetOwner():Alive() then 
			self:CreateExplosion()
		end 
	end)
end

function SWEP:CreateExplosion()
	local owner = self:GetOwner()
	local pos = owner:GetPos() + Vector(0, 0, 32) -- Взрыв на уровне пояса
	
	-- Создаем эффект взрыва
	if owner:WaterLevel() == 0 then
		local line = util.TraceLine({
			start = pos,
			endpos = pos - vector_up * 25,
			mask = MASK_SHOT,
			filter = owner
		})
		if line.Hit then
			ParticleEffect("pcf_jack_groundsplode_small3", pos, -vector_up:Angle())
		else
			ParticleEffect("pcf_jack_airsplode_small3", pos, -vector_up:Angle())
		end
	else
		local effectdata = EffectData()
		effectdata:SetOrigin(pos)
		effectdata:SetScale(2) -- Размер взрыва
		effectdata:SetNormal(-owner:GetAngles():Forward())
		util.Effect("eff_jack_genericboom", effectdata)
	end

	-- Звуки взрыва
	local SoundTable = {"m67/m67_detonate_01.wav", "m67/m67_detonate_02.wav", "m67/m67_detonate_03.wav"}
	local SoundFarTable = {"m67/m67_detonate_far_dist_01.wav", "m67/m67_detonate_far_dist_02.wav", "m67/m67_detonate_far_dist_03.wav"}
	local SoundBassTable = {"snd_jack_fragsplodeclose.wav", "m67/m67_detonate_02.wav", "snd_jack_bigsplodeclose.wav"}
	
	if owner:WaterLevel() > 0 then
		owner:EmitSound("m67/water/m67_water_detonate_01.wav", 140, 85, 1, CHAN_WEAPON)
		owner:EmitSound(table.Random(SoundBassTable), 150, 70, 0.8, CHAN_AUTO)
	else
		owner:EmitSound(table.Random(SoundTable), 145, 85, 1, CHAN_WEAPON)
		owner:EmitSound(table.Random(SoundFarTable), 140, 85, 0.9, CHAN_WEAPON)
		
		timer.Simple(0.05, function() 
			if IsValid(owner) then
				owner:EmitSound(table.Random(SoundBassTable), 150, 70, 0.95, CHAN_AUTO) 
			end
		end)

		timer.Simple(0.1, function() 
			if IsValid(owner) then
				owner:EmitSound(table.Random(SoundBassTable), 155, 60, 0.9, CHAN_BODY) 
			end
		end)
	end

	-- Базовый урон взрывной волной
	local blastRadius = 256 -- Радиус взрыва в юнитах
	util.BlastDamage(self, owner, pos, blastRadius, 100)

	-- Создаем осколки (пули)
	local shrapnelCount = 200 -- Количество осколков
	local co = coroutine.create(function()
		for i = 1, shrapnelCount do
			local dir = VectorRand():GetNormalized()
			dir.z = math.Clamp(dir.z, -0.3, 0.3) -- Ограничиваем вертикальный разброс
			dir:Normalize()

			local bullet = {
				Src = pos,
				Dir = dir,
				Spread = Vector(0, 0, 0),
				Num = 1,
				Damage = 25,
				Force = 10,
				Tracer = 0,
				AmmoType = "Metal Debris",
				Attacker = owner,
				Inflictor = self,
				Distance = 2000
			}

			owner:FireBullets(bullet)
			
			if i % 10 == 0 then -- Делаем паузу каждые 10 осколков
				coroutine.yield()
			end
		end
	end)

	local index = owner:EntIndex()
	timer.Create("JihadShrapnel_" .. index, 0, 0, function()
		if not IsValid(owner) then
			timer.Remove("JihadShrapnel_" .. index)
			return
		end

		local success, error = coroutine.resume(co)
		if not success or coroutine.status(co) == "dead" then
			timer.Remove("JihadShrapnel_" .. index)
		end
	end)

	-- Тряска экрана
	util.ScreenShake(pos, 35, 1, 1, 3000)

	-- Эффект шрапнели
	local Poof = EffectData()
	Poof:SetOrigin(pos)
	Poof:SetScale(1.5)
	util.Effect("eff_jack_hmcd_shrapnel", Poof, true, true)

	-- Убиваем владельца
	owner:TakeDamage(1000, owner, self)
	
	-- Удаляем оружие
	self:Remove()
end

function SWEP:Deploy()
	if not IsFirstTimePredicted() then return end
	self.DownAmt = 16
	self:SetNextPrimaryFire(CurTime() + 1)
	self:SetNextSecondaryFire(CurTime() + 1)
	return true
end

function SWEP:Holster()
	return true
end

function SWEP:OnRemove()
	--
end

function SWEP:SecondaryAttack()
	--
end

function SWEP:Think()
	--
end

function SWEP:Reload()
	--
end

if CLIENT then
	local Hidden = 0
	function SWEP:GetViewModelPosition(pos, ang)
		if not self.DownAmt then self.DownAmt = 16 end
		if self:GetOwner():IsSprinting() and self:GetOwner():KeyDown(IN_FORWARD) then
			self.DownAmt = math.Clamp(self.DownAmt + .2, 0, 16)
		else
			self.DownAmt = math.Clamp(self.DownAmt - .2, 0, 16)
		end

		Hidden = 22
		local NewPos = pos + ang:Forward() * 50 - ang:Up() * (20 + self.DownAmt + Hidden) + ang:Right() * 20
		return NewPos, ang
	end

	function SWEP:DrawWorldModel()
		local Pos, Ang = self:GetOwner():GetBonePosition(self:GetOwner():LookupBone("ValveBiped.Bip01_R_Hand"))
		if self.DatDetModel then
			self.DatDetModel:SetRenderOrigin(Pos + Ang:Forward() * 4 + Ang:Right() * 12)
			Ang:RotateAroundAxis(Ang:Up(), 90)
			Ang:RotateAroundAxis(Ang:Right(), 180)
			self.DatDetModel:SetRenderAngles(Ang)
			self.DatDetModel:DrawModel()
		else
			self.DatDetModel = ClientsideModel("models/jmod/explosives/grenades/satchelcharge/satchel_charge_plunger.mdl")
			self.DatDetModel:SetPos(self:GetPos())
			self.DatDetModel:SetParent(self)
			self.DatDetModel:SetNoDraw(true)
		end
	end

	function SWEP:ViewModelDrawn(model)
		local Pos, Ang = model:GetPos(), model:GetAngles()
		if self.DatDetViewModel then
			if Pos and Ang and GAMEMODE:ShouldDrawWeaponWorldModel(self) then
				self.DatDetViewModel:SetRenderOrigin(Pos + Ang:Up() * 20)
				Ang:RotateAroundAxis(Ang:Up(), 180)
				Ang:RotateAroundAxis(Ang:Right(), 30)
				self.DatDetViewModel:SetRenderAngles(Ang)
				self.DatDetViewModel:DrawModel()
			end
		else
			self.DatDetViewModel = ClientsideModel("models/weapons/w_models/w_jda_engineer.mdl")
			self.DatDetViewModel:SetPos(self:GetPos())
			self.DatDetViewModel:SetParent(self)
			self.DatDetViewModel:SetNoDraw(true)
			self.DatDetViewModel:SetModelScale(.5, 0)
		end
	end
end