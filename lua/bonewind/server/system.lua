---@module "bonewind.shared.setarray"
local setArray = include("bonewind/shared/setarray.lua")

local enableSystem = CreateConVar("sv_bonewind_enablesystem", "1", FCVAR_NOTIFY + FCVAR_LUA_SERVER)
local enabled = enableSystem:GetBool()
cvars.AddChangeCallback("sv_bonewind_enablesystem", function(convar, oldValue, newValue)
	enabled = tobool(Either(tonumber(newValue) ~= nil, tonumber(newValue) > 0, false))
end)

---@type ServerWindableInfo
local windableInfo = {
	windables = setArray({}),
	previousCount = 0,
}

---If the entity has been modified in the past or it has an EntityModifier
---hinting that it did, then return its bone array
---@param entity Entity
---@return BoneArray
local function getExistingWindedBones(entity)
	return {}
end

---Make a table to store the entity, its bones, and other fields,
---rather than storing it in the entity itself to avoid Entity.__index calls
---@param entity Entity
---@return ServerWindable
local function constructWindable(entity)
	local boneArray = getExistingWindedBones(entity)
	return {
		entity = entity,
		bones = setArray(boneArray),
	}
end

---@param entIndex number
---@return ServerWindable
local function addWindable(entIndex)
	local windable = constructWindable(Entity(entIndex))
	windableInfo.windables:Add(windable, entIndex)
	return windable
end

net.Receive("bonewind_setbone_request", function(_, ply)
	local entIndex = net.ReadUInt(14)
	local bone = net.ReadUInt(8)
	local checked = net.ReadBool()

	local windable = windableInfo.windables:Get(entIndex)
	---@cast windable ServerWindable?
	if not windable and IsValid(Entity(entIndex)) then
		windable = addWindable(entIndex)
	end

	if windable then
		local boneExists = windable.bones:Get(bone)
		if checked and not boneExists then
			windable.bones:Add(bone)
		elseif not checked and boneExists then
			windable.bones:Remove(bone)
		end

		if #windable.bones.array == 0 then
			windableInfo.windables:Remove(entIndex)
		end
	end
end)

---@param entity Entity
---@param bones table
local function applyAngles(entity, bones)
	for _, boneInfo in ipairs(bones) do
		entity:ManipulateBoneAngles(boneInfo.bone, boneInfo.angle)
	end
end

net.Receive("bonewind_replicate", function(len)
	if not enabled then
		return
	end

	local entIndex = net.ReadUInt(14)
	local windable = windableInfo.windables:Get(entIndex)
	---@cast windable ServerWindable?

	if not windable then
		return
	end

	local entity = Entity(entIndex)
	if not IsValid(entity) then
		-- Cleanup invalid entities, if any
		if not IsValid(windable.entity) then
			windableInfo.windables:Remove(entIndex)
		end
		return
	end

	local infoLength = net.ReadUInt(8)
	local boneInfo = {}
	for i = 1, infoLength do
		local bone = net.ReadUInt(8)
		local angle = net.ReadAngle()
		boneInfo[i] = { bone = bone, angle = angle }
	end

	-- PrintTable(boneInfo)
	applyAngles(entity, boneInfo)
end)
