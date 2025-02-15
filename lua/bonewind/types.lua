---@meta

---@generic T, U
---@alias Set<T, U> {[T]: U}

---@alias Bone integer
---@alias BoneArray Bone[]
---@alias BoneSet Set<Bone, integer>

---@class PanelState
---@field selectedBone integer
---@field windable Entity
---@field tree EntityTree

---@class PanelProps
---@field windable Entity

---@class AngleSlider: DNumSlider
---@field ignore boolean

---@class EulerAngleSliders
---@field pitch AngleSlider
---@field yaw AngleSlider
---@field roll AngleSlider

---@class PanelChildren
---@field treePanel DTreeScroller
---@field boneTree DTreeScroller
---@field boneEnabled DCheckBoxLabel
---@field chainEnabled DCheckBoxLabel
---@field childrenEnabled DCheckBoxLabel
---@field windDirection DModelRotater
---@field windZSlider DSlider
---@field windStrength DNumSlider
---@field windFrequency DNumSlider
---@field updateInterval DNumSlider
---@field angles EulerAngleSliders
---@field bonePresets DPresetSaver

---@class ServerWindable A struct that stores the entity to modify and its bones to affect by the wind system
---@field entity Entity
---@field bones SetArray

---@class Wind
---@field direction Vector
---@field magnitude number
---@field frequency number

---@class WindableSettings
---@field angles Set<Bone, Angle>

---@class ClientWindable A struct that stores the entity to modify and its bones to affect by the wind system
---@field entity Entity
---@field bones SetArray
---@field settings WindableSettings
---@field wind Wind

---@class ClientWindableInfo
---@field windables ClientWindable[]
---@field previousCount integer

---@class ServerWindableInfo
---@field windables SetArray<ServerWindable>
---@field previousCount integer

---@class BoneTreeNode: DTree_Node
---@field GetChildNodes fun(self: BoneTreeNode): BoneTreeNode[]
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

---Wrapper for `DTree_Node`
---@class TreePanel_Node: DTree_Node
---@field Icon DImage
---@field info EntityTree
---@field GetChildNodes fun(self: TreePanel_Node): TreePanel_Node[]

---Wrapper for `DTree`
---@class TreePanel: DTreeScroller
---@field ancestor TreePanel_Node
---@field GetSelectedItem fun(self: TreePanel): TreePanel_Node

---Main structure representing an entity's model tree
---@class EntityTree
---@field parent integer?
---@field entity integer
---@field children EntityTree[]

---@class BonePresetField
---@field boneName string
---@field pitch number
---@field yaw number
---@field roll number

---@class BonePreset
---@field presets BonePresetField[]
