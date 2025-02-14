---@module "bonewind.shared.helpers"
local helpers = include("bonewind/shared/helpers.lua")

---@module "bonewind.shared.setarray"
local setArray = include("bonewind/shared/setarray.lua")

local ipairs_sparse = helpers.ipairs_sparse

---@type ClientWindableInfo
local windableInfo = {
	windables = setArray({}),
	previousCount = 0,
}

local system = {}

---Make a table to store the entity, its bones, and other fields,
---rather than storing it in the entity itself to avoid Entity.__index calls
---@param entity Entity
---@param wind Wind
---@return ClientWindable
local function constructWindable(entity, wind)
	return {
		entity = entity,
		bones = setArray({}),
		wind = wind,
	}
end

---@param entIndex number
---@param wind Wind
---@return ClientWindable
local function addWindable(entIndex, wind)
	local windable = constructWindable(Entity(entIndex), wind)
	windableInfo.windables:Add(windable, entIndex)
	return windable
end

---@param entIndex integer
---@param bone integer
---@param checked boolean
---@param wind Wind
function system.setBone(entIndex, bone, checked, wind)
	local windable = windableInfo.windables:Get(entIndex)
	---@cast windable ClientWindable?
	if not windable and IsValid(Entity(entIndex)) then
		windable = addWindable(entIndex, wind)
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

	net.Start("bonewind_setbone_request")
	net.WriteUInt(entIndex, 14)
	net.WriteUInt(bone, 8)
	net.WriteBool(checked)
	net.SendToServer()
end

---@param entIndex integer
---@param bone integer
---@param wind Wind
function system.modBone(entIndex, bone, wind)
	local windable = windableInfo.windables:Get(entIndex)
	---@cast windable ClientWindable?

	if windable and windable.bones:Get(bone) then
		windable.wind = wind
	end
end

---@param entIndex integer
---@param bone integer
---@return boolean
function system.isWindedBone(entIndex, bone)
	local result = false

	local windable = windableInfo.windables:Get(entIndex)
	---@cast windable ClientWindable?
	if windable and windable.bones:Get(bone) then
		result = true
	end

	return result
end

---@param entity Entity
---@param bones BoneArray
---@param windInfo Wind
local function applyForce(entity, bones, windInfo)
	---@type BoneInfo[]
	local boneInfoArray = {}

	-- TODO: Pass the magnitude as an argument instead of computing it
	local direction = windInfo.direction
	local frequency = windInfo.frequency
	local magnitude = windInfo.magnitude
	for _, bone in ipairs(bones) do
		-- Rotate bone to face direction of the force vector
		local _, desiredAngle = helpers.getBoneOffsetsFromVector(entity, bone, direction)
		local oldAngle = entity:GetManipulateBoneAngles(bone)

		-- Apply sine on the desired angle to obtain final angle
		desiredAngle[1] = desiredAngle[1] + magnitude * math.sin(frequency * RealTime())
		desiredAngle[2] = desiredAngle[2] - magnitude * math.cos(frequency * RealTime())

		desiredAngle = LerpAngle(0.5, oldAngle, desiredAngle)

		table.insert(boneInfoArray, {
			bone = bone,
			angle = desiredAngle,
		})
	end

	return boneInfoArray
end

---@param entIndex integer
---@param boneInfoArray BoneInfo[]
local function replicate(entIndex, boneInfoArray)
	net.Start("bonewind_replicate")
	net.WriteUInt(entIndex, 14)
	net.WriteUInt(#boneInfoArray, 8)
	for _, boneInfo in ipairs(boneInfoArray) do
		net.WriteUInt(boneInfo.bone, 8)
		net.WriteAngle(boneInfo.angle)
	end
	net.SendToServer()
end

---Check if the entity passes rules on the client
---Useful to ensure the client doesn't send what it can't see
---@param entity Entity
local function checkReplication(entity)
	-- TODO: Implement replication rules
	return true
end

do
	local shouldCheckReplication = GetConVar("bonewind_checkreplication")
	local updateInterval = GetConVar("bonewind_updateinterval")
	local lastThink = 0

	-- The client is responsible for changing the bone angles with the wind force
	hook.Remove("Think", "bonewind_system")
	hook.Add("Think", "bonewind_system", function()
		shouldCheckReplication = shouldCheckReplication or GetConVar("bonewind_checkreplication")
		updateInterval = updateInterval or GetConVar("bonewind_updateinterval")

		local now = CurTime()
		if now - lastThink < updateInterval:GetFloat() / 1000 then
			return
		end
		lastThink = now

		local windables = windableInfo.windables
		local count = #windables.array
		for entIndex, _ in ipairs_sparse(windables.set, "bonewind_system", count ~= windableInfo.previousCount) do
			local windable = windables:Get(entIndex)
			---@cast windable ClientWindable

			-- Cleanup invalid entities
			if not IsValid(windable.entity) then
				windableInfo.windables:Remove(entIndex)
				continue
			end

			local boneInfo = applyForce(windable.entity, windable.bones.array, windable.wind)
			if
				not shouldCheckReplication:GetBool()
				or (shouldCheckReplication:GetBool() and checkReplication(windable.entity))
			then
				replicate(entIndex, boneInfo)
			end
		end
		windableInfo.previousCount = count
	end)
end

BoneWind.System = system
