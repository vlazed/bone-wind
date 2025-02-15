TOOL.Category = "Render"
TOOL.Name = "#tool.bonewind.name"
TOOL.Command = nil
TOOL.ConfigName = ""

TOOL.ClientConVar["direction"] = "0 1 0"
TOOL.ClientConVar["strength"] = "1"
TOOL.ClientConVar["frequency"] = "100"
TOOL.ClientConVar["checkreplication"] = "0"
TOOL.ClientConVar["updateinterval"] = "10"

local lastWindable = NULL
local lastValidWindable = false
function TOOL:Think()
	local currentWindable = self:GetWindable()
	local validWindable = IsValid(currentWindable)

	if currentWindable == lastWindable and validWindable == lastValidWindable then
		return
	end

	if CLIENT then
		self:RebuildControlPanel(currentWindable)
	end
	lastWindable = currentWindable
	lastValidWindable = validWindable
end

---@param newWindable Entity
function TOOL:SetWindable(newWindable)
	self:GetWeapon():SetNW2Entity("bonewind_entity", IsValid(newWindable) and newWindable or NULL)
end

---@return Entity windable
function TOOL:GetWindable()
	return self:GetWeapon():GetNW2Entity("bonewind_entity")
end

---Select an entity to add its bones to the Bone Wind system
---@param tr table|TraceResult
---@return boolean
function TOOL:RightClick(tr)
	if CLIENT then
		return true
	end

	if IsValid(tr.Entity) and tr.Entity:GetClass() == "prop_effect" then
		---@diagnostic disable-next-line: undefined-field
		tr.Entity = tr.Entity.AttachedEntity
	end

	self:SetWindable(tr.Entity)

	return true
end

if SERVER then
	return
end

TOOL:BuildConVarList()

---@module "bonewind.client.ui"
local ui = include("bonewind/client/ui.lua")
---@module "bonewind.shared.helpers"
local helpers = include("bonewind/shared/helpers.lua")

local vectorFromString = helpers.vectorFromString

---@type PanelState
local panelState = {
	selectedBone = -1,
	windable = NULL,
	tree = {
		entity = NULL,
		children = {},
	},
}

---@param cPanel ControlPanel|DForm
---@param windable Entity
function TOOL.BuildCPanel(cPanel, windable)
	local panelProps = {
		windable = windable,
	}
	panelState.windable = windable
	local panelChildren = ui.ConstructPanel(cPanel, panelProps, panelState)
	ui.HookPanel(panelChildren, panelProps, panelState)
end

local windDirectionConVar = GetConVar("bonewind_direction")

local red = Color(255, 0, 0)
function TOOL:DrawHUD()
	windDirectionConVar = windDirectionConVar or GetConVar("bonewind_direction")

	local windable = panelState.windable
	if not IsValid(windable) then
		return
	end

	local vector = vectorFromString(windDirectionConVar:GetString())
	debugoverlay.Line(windable:EyePos(), windable:EyePos() + vector * 10, 0.2, red, true)

	local selectedBone = panelState.selectedBone

	local pos = windable:GetBonePosition(selectedBone)
	if selectedBone > 0 and pos then
		pos = pos:ToScreen()

		surface.SetDrawColor(0, 255, 0)
		surface.DrawRect(pos.x, pos.y, 10, 10)
	end
end

TOOL.Information = {
	{ name = "info" },
	{ name = "right" },
}
