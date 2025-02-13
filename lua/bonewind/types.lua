---@meta

---@generic T, U
---@alias Set<T, U> {[T]: U}

---@alias Bone integer
---@alias BoneArray Bone[]
---@alias BoneSet Set<Bone, integer>

---@class PanelState
---@field selectedBone integer
---@field windable Entity

---@class PanelProps
---@field windable Entity

---@class PanelChildren
---@field boneTree DTreeScroller
---@field boneEnabled DCheckBox
---@field windDirection DModelRotater
---@field windZSlider DSlider
---@field windStrength DNumSlider
---@field windFrequency DNumSlider

---@class ServerWindable A struct that stores the entity to modify and its bones to affect by the wind system
---@field entity Entity
---@field bones SetArray

---@class Wind
---@field direction Vector
---@field magnitude number
---@field frequency number

---@class ClientWindable A struct that stores the entity to modify and its bones to affect by the wind system
---@field entity Entity
---@field bones SetArray
---@field wind Wind

---@class ClientWindableInfo
---@field windables SetArray<ClientWindable>
---@field previousCount integer

---@class ServerWindableInfo
---@field windables SetArray<ServerWindable>
---@field previousCount integer

---@class BoneTreeNode: DTree_Node
---@field bone Bone

---@class BoneInfo
---@field angle Angle
---@field bone Bone

---@class Pose
---@field oPos Vector
---@field lPos Vector
---@field oAng Angle
---@field lAng Angle
---@field parent Bone

---@alias PoseTree Pose[]
