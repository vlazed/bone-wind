---@diagnostic disable-next-line: undefined-global
BoneWind = BoneWind or {}

if SERVER then
	print("Initializing Bone Wind on the server")

	AddCSLuaFile("bonewind/shared/helpers.lua")
	AddCSLuaFile("bonewind/shared/quaternion.lua")
	AddCSLuaFile("bonewind/shared/setarray.lua")
	AddCSLuaFile("bonewind/client/system.lua")
	AddCSLuaFile("bonewind/client/ui.lua")

	include("bonewind/server/net.lua")
	include("bonewind/server/system.lua")
else
	print("Initializing Bone Wind on the client")

	include("bonewind/client/system.lua")
end
