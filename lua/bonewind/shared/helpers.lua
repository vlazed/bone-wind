local helpers = {}

-- Cache the sorted indices so we don't iterate two more times than necessary
local sortedIndicesDictionary = {}

---@source https://subscription.packtpub.com/book/game-development/9781849515504/1/ch01lvl1sec14/extending-ipairs-for-use-in-sparse-arrays
---Helper function to iterate over an array with nonconsecutive integers ("holes" in the middle of the array, or zero or negative indices)
---@generic T
---@param t T[] Table to iterate over
---@param identifier string A unique key to store the table's sorted indices
---@param changed boolean? Has the table's state in some way?
---@return fun(): integer, T
function helpers.ipairs_sparse(t, identifier, changed)
	-- tmpIndex will hold sorted indices, otherwise
	-- this iterator would be no different from pairs iterator
	local tmpIndex = {}

	if changed or not sortedIndicesDictionary[identifier] then
		local index, _ = next(t)
		while index do
			tmpIndex[#tmpIndex + 1] = index
			index, _ = next(t, index)
		end

		-- sort table indices
		table.sort(tmpIndex)

		sortedIndicesDictionary[identifier] = tmpIndex
	else
		tmpIndex = sortedIndicesDictionary[identifier]
	end
	local j = 1
	-- get index value
	return function()
		local i = tmpIndex[j]
		j = j + 1
		if i then
			return i, t[i]
		end
	end
end

---@type Set<string, PoseTree>
local defaultPoseTrees = {}

---@source: https://github.com/NO-LOAFING/AnimpropOverhaul/blob/a3a6268a5d57655611a8b8ed43dcf43051ecd93a/lua/entities/prop_animated.lua#L3550
---@param ent Entity Entity in reference pose
---@return PoseTree defaultPose Array consisting of a bones offsets from the entity, and offsets from its parent bones
function helpers.getDefaultPoseTree(ent)
	if defaultPoseTrees[ent:GetModel()] then
		return defaultPoseTrees[ent:GetModel()]
	end

	local defaultPose = {}
	local entPos = ent:GetPos()
	local entAngles = ent:GetAngles()
	for b = 0, ent:GetBoneCount() - 1 do
		local parent = ent:GetBoneParent(b)
		local bMatrix = ent:GetBoneMatrix(b)
		if bMatrix then
			local pos1, ang1 = WorldToLocal(bMatrix:GetTranslation(), bMatrix:GetAngles(), entPos, entAngles)
			local pos2, ang2 = pos1 * 1, ang1 * 1
			if parent > -1 then
				local pMatrix = ent:GetBoneMatrix(parent)
				pos2, ang2 = WorldToLocal(
					bMatrix:GetTranslation(),
					bMatrix:GetAngles(),
					pMatrix:GetTranslation(),
					pMatrix:GetAngles()
				)
			end

			defaultPose[b] = {
				oPos = pos1,
				oAng = ang1,
				lPos = pos2,
				lAng = ang2,
				parent = parent,
			}
		else
			defaultPose[b] = {
				oPos = vector_origin,
				oAng = angle_zero,
				lPos = vector_origin,
				lAng = angle_zero,
			}
		end
	end

	defaultPoseTrees[ent:GetModel()] = defaultPose

	return defaultPose
end

---Calculate the bone offsets with respect to the parent
---Source: https://github.com/NO-LOAFING/AnimpropOverhaul/blob/a3a6268a5d57655611a8b8ed43dcf43051ecd93a/lua/entities/prop_animated.lua#L1889
---@param entity Entity Entity to obtain bone information
---@param child integer Child bone index
---@param vector Vector
---@return Vector positionOffset Position of child bone with respect to parent bone
---@return Angle angleOffset Angle of child bone with respect to parent bone
function helpers.getBoneOffsetsFromVector(entity, child, vector)
	local defaultBonePose = helpers.getDefaultPoseTree(entity)

	local parent = entity:GetBoneParent(child)
	---@type VMatrix
	local cMatrix = entity:GetBoneMatrix(child)
	---@type VMatrix
	local pMatrix = entity:GetBoneMatrix(parent)

	if not cMatrix or not pMatrix or not defaultBonePose or #defaultBonePose == 0 then
		return vector_origin, angle_zero
	end

	local fPos, fAng =
		WorldToLocal(cMatrix:GetTranslation(), vector:Angle(), pMatrix:GetTranslation(), pMatrix:GetAngles())
	local dPos = fPos - defaultBonePose[child].lPos

	local m = Matrix()
	m:Translate(defaultBonePose[parent].oPos)
	m:Rotate(defaultBonePose[parent].oAng)
	m:Rotate(fAng)

	local _, dAng =
		WorldToLocal(m:GetTranslation(), m:GetAngles(), defaultBonePose[child].oPos, defaultBonePose[child].oAng)

	return dPos, dAng
end

return helpers
