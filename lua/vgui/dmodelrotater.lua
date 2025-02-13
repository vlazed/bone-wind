---@class DModelRotater: DModelPanel
---@field Entity Entity
---@field GetEntity fun(self: DModelRotater): entity: Entity
---@field SetEntity fun(self: DModelRotater, entity: Entity)
---@field vCamPos Vector
---@field GetCamPos fun(self: DModelRotater): camPos: Vector
---@field SetCamPos fun(self: DModelRotater, camPos: Vector)
---@field vLookAtPos Vector
---@field GetLookAt fun(self: DModelRotater): lookAt: Vector
---@field SetLookAt fun(self: DModelRotater, lookAt: Vector)
---@field aLookAngle Angle
---@field GetLookAng fun(self: DModelRotater): lookAng: Angle
---@field SetLookAng fun(self: DModelRotater, lookAng: Angle)
---@field m_bFirstPerson boolean
---@field GetFirstPerson fun(self: DModelRotater): firstPerson: boolean
---@field SetFirstPerson fun(self: DModelRotater, firstPerson: boolean)
---@field bAnimated boolean
---@field GetAnimated fun(self: DModelRotater): animated: boolean
---@field SetAnimated fun(self: DModelRotater, animated: boolean)
---@field OrbitDistance number
---@field OrbitPoint Vector
local PANEL = {}

AccessorFunc(PANEL, "m_bFirstPerson", "FirstPerson")

function PANEL:Init()
	self.mx = 0
	self.my = 0
	self.aLookAngle = angle_zero
end

---@return Vector
function PANEL:CalculateModelCenter()
	local mins, maxs = self.Entity:GetModelBounds()
	return (mins + maxs) / 2
end

function PANEL:OnMousePressed(mousecode)
	-- input.SetCursorPos does not work while main menu is open
	if not MENU_DLL and gui.IsGameUIVisible() then
		return
	end

	self:SetCursor("none")
	self:MouseCapture(true)
	self.Capturing = true
	self.MouseKey = mousecode

	self:SetFirstPerson(true)

	self:CaptureMouse()

	if not IsValid(self.Entity) then
		self.OrbitPoint = vector_origin
		self.OrbitDistance = (self.OrbitPoint - self.vCamPos):Length()
		return
	end

	-- Helpers for the orbit movement
	local center = self:CalculateModelCenter()

	local hit1 = util.IntersectRayWithPlane(self.vCamPos, self.aLookAngle:Forward(), vector_origin, Vector(0, 0, 1))
	self.OrbitPoint = hit1

	local hit2 = util.IntersectRayWithPlane(self.vCamPos, self.aLookAngle:Forward(), vector_origin, Vector(0, 1, 0))
	if (not hit1 and hit2) or hit2 and hit2:Distance(self.Entity:GetPos()) < hit1:Distance(self.Entity:GetPos()) then
		self.OrbitPoint = hit2
	end

	local hit3 = util.IntersectRayWithPlane(self.vCamPos, self.aLookAngle:Forward(), vector_origin, Vector(1, 0, 0))
	if
		((not hit1 or not hit2) and hit3)
		or hit3 and hit3:Distance(self.Entity:GetPos()) < hit2:Distance(self.Entity:GetPos())
	then
		self.OrbitPoint = hit3
	end

	self.OrbitPoint = self.OrbitPoint or center
	self.OrbitDistance = (self.OrbitPoint - self.vCamPos):Length()
end

function PANEL:Think()
	if not self.Capturing then
		return
	end

	if self.m_bFirstPerson then
		return self:FirstPersonControls()
	end
end

function PANEL:CaptureMouse()
	-- input.SetCursorPos does not work while main menu is open
	if not MENU_DLL and gui.IsGameUIVisible() then
		return 0, 0
	end

	local x, y = input.GetCursorPos()

	local dx = x - self.mx
	local dy = y - self.my

	local centerx, centery = self:LocalToScreen(self:GetWide() * 0.5, self:GetTall() * 0.5)
	input.SetCursorPos(centerx, centery)
	self.mx = centerx
	self.my = centery

	return dx, dy
end

function PANEL:LayoutEntity(entity)
	if self.bAnimated then
		self:RunAnimation()
	end
end

function PANEL:OnLookAngChange(angle) end

function PANEL:FirstPersonControls()
	if not self:IsEnabled() then
		return
	end

	local x, y = self:CaptureMouse()

	local scale = self:GetFOV() / 180
	x = x * -0.5 * scale
	y = y * 0.5 * scale

	if self.MouseKey == MOUSE_LEFT then
		return self:OnLookAngChange(Angle(0, x * 4, 0))
	end
end

function PANEL:OnMouseReleased(mousecode)
	self:SetCursor("arrow")
	self:MouseCapture(false)
	self.Capturing = false
end

derma.DefineControl("DModelRotater", "A panel containing a model", PANEL, "DModelPanel")
