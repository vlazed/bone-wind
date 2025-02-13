---@alias SetToArrayIndex table<integer, integer>

---@generic T
---@class SetArray<T>
---@field array table
---@field set SetToArrayIndex
local SetArray = {}

SetArray.__index = SetArray

---@param array table
---@param set Set
local function refreshSetArray(array, set)
	for i, val in ipairs(array) do
		set[val] = i
	end
end

local function setArray(array)
	local set = {}
	if #array > 0 then
		refreshSetArray(array, set)
	end
	return setmetatable({
		set = set,
		array = array,
	}, SetArray)
end

function SetArray:Get(val)
	return self.array[self.set[val]]
end

function SetArray:Add(val, key)
	key = key or val
	if not self.set[key] then
		self.set[key] = table.insert(self.array, val)
	else
		self.array[self.set[key]] = val
		self.set[key] = val
	end
end

function SetArray:Remove(key)
	table.remove(self.array, self.set[key])
	self.set[key] = nil

	refreshSetArray(self.array, self.set)
end

return setArray
