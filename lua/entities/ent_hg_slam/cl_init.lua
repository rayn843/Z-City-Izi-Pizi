include("shared.lua")

local laserMaterial = CreateMaterial("tripmine_laser", "UnlitGeneric", {
	["$basetexture"] = "sprites/laserbeam",
	["$additive"] = "1",
	["$vertexcolor"] = "1",
	["$vertexalpha"] = "1",
	["$nocull"] = "1",
	["$brightness"] = "64",
	["$textureScrollRate"] = "25.6",
})

function ENT:Initialize()
	-- Увеличиваем зону видимости энтити, чтобы движок рисовал её, 
	-- даже если игрок смотрит только на кончик лазера
	self:SetRenderBounds(Vector(-700, -700, -700), Vector(700, 700, 700))
end

-- Отрисовка происходит прямо внутри энтити, античит сюда не лезет
function ENT:Draw()
	self:DrawModel()

	if not self.TraceStart or not self.TraceHitPos then return end

	render.SetMaterial(laserMaterial)
	render.DrawBeam(
		self.TraceStart,
		self.TraceHitPos,
		0.35,
		0,
		1,
		Color(255, 55, 52, 64)
	)
end

function ENT:Draw()
	self:DrawModel()
end

function ENT:OnRemove()
	hook.Remove("PostDrawOpaqueRenderables","SlaMRender"..self:EntIndex())
end