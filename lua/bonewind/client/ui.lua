local ui = {}

---@module "bonewind.shared.helpers"
local helpers = include("bonewind/shared/helpers.lua")

local getValidModelChildren = helpers.getValidModelChildren
local getModelName, getModelNameNice, getModelNodeIconPath =
	helpers.getModelName, helpers.getModelNameNice, helpers.getModelNodeIconPath
local vectorFromString = helpers.vectorFromString

---Add hooks and model tree pointers
---@param parent TreePanel_Node
---@param entity Entity
---@param info EntityTree
---@param rootInfo EntityTree
---@return TreePanel_Node
local function addNode(parent, entity, info, rootInfo)
	local node = parent:AddNode(getModelNameNice(entity))
	---@cast node TreePanel_Node

	node:SetExpanded(true, true)

	node.Icon:SetImage(getModelNodeIconPath(entity))
	node.info = info

	return node
end

---Construct the model tree
---@param parent Entity
---@return EntityTree
local function entityHierarchy(parent)
	local tree = {}
	if not IsValid(parent) then
		return tree
	end

	---@type Entity[]
	local children = getValidModelChildren(parent)

	for i, child in ipairs(children) do
		if child.GetModel and child:GetModel() ~= "models/error.mdl" then
			---@type EntityTree
			local node = {
				parent = parent:EntIndex(),
				entity = child:EntIndex(),
				children = entityHierarchy(child),
			}
			table.insert(tree, node)
		end
	end

	return tree
end

---Construct the DTree from the entity model tree
---@param tree EntityTree
---@param nodeParent TreePanel_Node
---@param root EntityTree
local function hierarchyPanel(tree, nodeParent, root)
	for _, child in ipairs(tree) do
		local childEntity = Entity(child.entity)
		if not IsValid(childEntity) or not childEntity.GetModel or not childEntity:GetModel() then
			continue
		end

		local node = addNode(nodeParent, childEntity, child, root)

		if #child.children > 0 then
			hierarchyPanel(child.children, node, root)
		end
	end
end

---Construct the `entity`'s model tree
---@param treePanel TreePanel
---@param entity Entity
---@returns EntityTree
local function buildTree(treePanel, entity)
	if IsValid(treePanel.ancestor) then
		treePanel.ancestor:Remove()
	end

	---@type EntityTree
	local hierarchy = {
		entity = entity:EntIndex(),
		children = entityHierarchy(entity),
	}

	---@type TreePanel_Node
	---@diagnostic disable-next-line
	treePanel.ancestor = addNode(treePanel, entity, hierarchy, hierarchy)
	treePanel.ancestor.Icon:SetImage(getModelNodeIconPath(entity))
	treePanel.ancestor.info = hierarchy
	hierarchyPanel(hierarchy.children, treePanel.ancestor, hierarchy)

	return hierarchy
end

---Helper for DForm
---@param cPanel ControlPanel|DForm
---@param name string
---@param type "ControlPanel"|"DForm"
---@return ControlPanel|DForm
local function makeCategory(cPanel, name, type)
	---@type DForm|ControlPanel
	local category = vgui.Create(type, cPanel)

	category:SetLabel(name)
	cPanel:AddItem(category)
	return category
end

local boneTypes = {
	"icon16/brick.png",
	"icon16/connect.png",
	"icon16/error.png",
}
---@param parentNode DTreeScroller|BoneTreeNode
---@param childName string
---@param boneType integer
---@return BoneTreeNode
local function addNode(parentNode, childName, boneType)
	local child = parentNode:AddNode(childName)
	---@cast child BoneTreeNode
	child:SetIcon(boneTypes[boneType])
	child:SetExpanded(true, false)
	return child
end

---@param entity Entity
---@param boneIndex integer
---@return integer
local function getBoneType(entity, boneIndex)
	local boneType = 2
	local isPhysicalBone = entity:TranslatePhysBoneToBone(entity:TranslateBoneToPhysBone(boneIndex)) == boneIndex

	if entity:BoneHasFlag(boneIndex, 4) then
		boneType = 3
	elseif isPhysicalBone then
		boneType = 1
	end

	return boneType
end

---@param node DTreeScroller|BoneTreeNode
---@param entity Entity
---@returns nodeArray: BoneTreeNode[]
local function populateBoneTree(node, entity)
	---@type BoneTreeNode[], BoneTreeNode[]
	local parentSet, nodeArray = {}, {}
	for b = 0, entity:GetBoneCount() - 1 do
		if entity:GetBoneName(b) == "__INVALIDBONE__" then
			continue
		end

		local boneType = getBoneType(entity, b)

		local parent = entity:GetBoneParent(b)
		if parent > -1 and parentSet[parent] then
			parentSet[b] = addNode(parentSet[parent], entity:GetBoneName(b), boneType)
			parentSet[b].bone = b
			table.insert(nodeArray, parentSet[b])
		else
			parentSet[b] = addNode(node, entity:GetBoneName(b), boneType)
			parentSet[b].bone = b
			table.insert(nodeArray, parentSet[b])
		end
	end

	return nodeArray
end

---@param treeNodes BoneTreeNode[]
local function getBoneTreeDepth(treeNodes)
	local depth, maxDepth = 0, 0
	for _, n in ipairs(treeNodes) do
		local counter = 0
		local walk = n
		while walk:GetParentNode():GetName() == "DTree_Node" and counter < 100 do
			---@diagnostic disable-next-line: cast-local-type
			walk = walk:GetParentNode()
			counter = counter + 1
			depth = depth + 1
		end

		if depth > maxDepth then
			maxDepth = depth
		end
		depth = 0
	end

	return maxDepth
end

---@param boneTree DTreeScroller
---@param windable Entity
local function refreshBoneTree(boneTree, windable)
	boneTree:Clear()

	local nodeArray = populateBoneTree(boneTree, windable)
	local depth = getBoneTreeDepth(nodeArray)
	local width = depth * 17
	boneTree:UpdateWidth(width + 64 + 32 + 128)
end

---@param cPanel DForm|ControlPanel
---@param panelProps PanelProps
---@param panelState PanelState
---@return PanelChildren
function ui.ConstructPanel(cPanel, panelProps, panelState)
	local windable = panelProps.windable

	cPanel:Help("#tool.bonewind.general")

	local treeForm = makeCategory(cPanel, "Entity Hierarchy", "DForm")
	if IsValid(windable) then
		treeForm:Help("#tool.bonewind.tree")
	end
	treeForm:Help(IsValid(windable) and "Entity hierarchy for " .. getModelName(windable) or "No entity selected")
	local treePanel = vgui.Create("DTreeScroller", treeForm)
	---@cast treePanel TreePanel
	if IsValid(windable) then
		panelState.tree = buildTree(treePanel, windable)
	end
	treeForm:AddItem(treePanel)
	treePanel:Dock(TOP)
	treePanel:SetSize(treeForm:GetWide(), 125)

	local boneSettings = makeCategory(cPanel, "Bone Tree", "DForm")

	local boneTree = vgui.Create("DTreeScroller", cPanel)
	boneSettings:AddItem(boneTree)
	boneTree:Dock(TOP)
	boneTree:SizeTo(-1, 250, 0)

	if IsValid(windable) then
		refreshBoneTree(boneTree, windable)
	end

	local boneEnabled = boneSettings:CheckBox("#tool.bonewind.bone.enabled", "")
	local chainEnabled = boneSettings:CheckBox("#tool.bonewind.chain.enabled", "")

	boneSettings:AddItem(boneEnabled, chainEnabled)
	chainEnabled:Dock(RIGHT)
	chainEnabled:SetSize(chainEnabled:GetWide() + 25, chainEnabled:GetTall())
	local childrenEnabled = boneSettings:CheckBox("#tool.bonewind.children.enabled", "")

	boneEnabled:SetTooltip("#tool.bonewind.bone.enabled.tooltip")
	chainEnabled:SetTooltip("#tool.bonewind.chain.enabled.tooltip")
	childrenEnabled:SetTooltip("#tool.bonewind.children.enabled.tooltip")

	local windSettings = makeCategory(cPanel, "Wind Settings", "DForm")
	windSettings:Help("Set the direction of the pointer to set the wind direction")
	local windDirection = vgui.Create("DModelRotater", windSettings)
	windDirection:SetModel("models/maxofs2d/lamp_flashlight.mdl")

	local windZSlider = vgui.Create("DSlider", windSettings)
	windZSlider:SetLockX(0.5)
	windZSlider:SetLockY()

	windSettings:AddItem(windDirection, windZSlider)
	local ySize = 250
	windDirection:SetSize(ySize, ySize)
	windZSlider:SetSize(50, ySize)
	windZSlider:SetX(ySize)
	local windStrength = windSettings:NumSlider("#tool.bonewind.wind.strength", "bonewind_strength", 0, 100)
	windStrength:Dock(TOP)
	local windFrequency = windSettings:NumSlider("#tool.bonewind.wind.frequency", "bonewind_frequency", 0, 1000)
	windFrequency:Dock(TOP)

	local replicationSettings = makeCategory(cPanel, "Replication Settings", "DForm")
	replicationSettings:Help("#tool.bonewind.replication.warning")
	local updateInterval =
		replicationSettings:NumSlider("#tool.bonewind.replication.interval", "bonewind_updateinterval", 0, 1000)
	updateInterval:SetTooltip("tool.bonewind.replication.interval.tooltip")

	return {
		treePanel = treePanel,
		boneEnabled = boneEnabled,
		chainEnabled = chainEnabled,
		childrenEnabled = childrenEnabled,
		boneTree = boneTree,
		windDirection = windDirection,
		windZSlider = windZSlider,
		windStrength = windStrength,
		windFrequency = windFrequency,
		updateInterval = updateInterval,
	}
end

local windDirectionConVar = GetConVar("bonewind_direction")

---@param panelChildren PanelChildren
---@param panelProps PanelProps
---@param panelState PanelState
function ui.HookPanel(panelChildren, panelProps, panelState)
	windDirectionConVar = windDirectionConVar or GetConVar("bonewind_direction")

	local treePanel = panelChildren.treePanel
	local boneTree = panelChildren.boneTree
	local boneEnabled = panelChildren.boneEnabled
	local chainEnabled = panelChildren.chainEnabled
	local childrenEnabled = panelChildren.childrenEnabled
	local windDirection = panelChildren.windDirection
	local windZSlider = panelChildren.windZSlider
	local windStrength = panelChildren.windStrength
	local windFrequency = panelChildren.windFrequency

	local windable = panelState.windable
	local player = LocalPlayer()
	boneEnabled:SetEnabled(false)
	childrenEnabled:SetEnabled(false)
	chainEnabled:SetEnabled(false)

	---@param checked boolean
	local function toggleWindSettings(checked)
		windStrength:SetEnabled(checked)
		windStrength:SetDark(checked)
		windFrequency:SetEnabled(checked)
		windFrequency:SetDark(checked)
		windZSlider:SetEnabled(checked)
		windDirection:SetEnabled(checked)
	end

	toggleWindSettings(false)

	---@param node TreePanel_Node
	function treePanel:OnNodeSelected(node)
		windable = Entity(node.info.entity)
		boneEnabled:SetEnabled(false)
		childrenEnabled:SetEnabled(false)
		chainEnabled:SetEnabled(false)

		refreshBoneTree(boneTree, windable)
	end

	---@param node BoneTreeNode
	function boneTree:OnNodeSelected(node)
		local isBoneEnabled = BoneWind.System.isWindedBone(windable:EntIndex(), node.bone)

		boneEnabled:SetEnabled(true)
		chainEnabled:SetEnabled(true)
		childrenEnabled:SetEnabled(true)
		boneEnabled:SetText(Format("%s %s", language.GetPhrase("#tool.bonewind.bone.enabled"), node:GetText()))

		boneEnabled:SetChecked(isBoneEnabled)
		chainEnabled:SetChecked(isBoneEnabled)
		childrenEnabled:SetChecked(isBoneEnabled)
		toggleWindSettings(isBoneEnabled)
		panelState.selectedBone = node.bone
	end

	---@param node BoneTreeNode
	---@param bones BoneArray
	---@returns BoneArray
	local function bonesFromChildren(node, bones, recursive)
		for _, child in ipairs(node:GetChildNodes()) do
			table.insert(bones, child.bone)
			if recursive then
				bones = bonesFromChildren(child, bones, recursive)
			end
		end

		return bones
	end

	---@param bones BoneArray
	---@param checked boolean
	local function addBonesToSystem(bones, checked)
		toggleWindSettings(checked)

		local direction = vectorFromString(windDirectionConVar:GetString())
		---@cast direction Vector

		for _, bone in ipairs(bones) do
			BoneWind.System.setBone(windable:EntIndex(), bone, checked, {
				direction = direction,
				magnitude = windStrength:GetValue(),
				frequency = windFrequency:GetValue(),
			})
		end
	end

	function childrenEnabled:OnChange(checked)
		chainEnabled:SetChecked(checked)

		local selectedNode = boneTree:GetSelectedItem()
		---@cast selectedNode BoneTreeNode

		addBonesToSystem(bonesFromChildren(selectedNode, {}, false), checked)
	end

	function chainEnabled:OnChange(checked)
		childrenEnabled:SetChecked(checked)

		local selectedNode = boneTree:GetSelectedItem()
		---@cast selectedNode BoneTreeNode

		addBonesToSystem(bonesFromChildren(selectedNode, {}, true), checked)
	end

	function boneEnabled:OnChange(checked)
		chainEnabled:SetChecked(checked)
		childrenEnabled:SetChecked(checked)

		local selectedNode = boneTree:GetSelectedItem()
		---@cast selectedNode BoneTreeNode

		addBonesToSystem({ selectedNode.bone }, checked)
	end

	local initialLook = vectorFromString(windDirectionConVar:GetString())
	---@cast initialLook Vector

	local mins, maxs = windDirection:GetEntity():GetModelBounds()
	windDirection.OrbitPoint = (mins + maxs) / 2
	windDirection:SetFirstPerson(true)
	windDirection.OrbitDistance = (windDirection.OrbitPoint - windDirection:GetCamPos()):Length()
	windDirection:SetCamPos(windDirection.OrbitPoint - initialLook * windDirection.OrbitDistance)
	windDirection:SetLookAng(initialLook:Angle())

	local function boneChanged()
		local selectedNode = boneTree:GetSelectedItem()
		---@cast selectedNode BoneTreeNode

		local direction = vectorFromString(windDirectionConVar:GetString())
		---@cast direction Vector

		if selectedNode then
			BoneWind.System.modBone(windable:EntIndex(), selectedNode.bone, {
				direction = direction,
				magnitude = windStrength:GetValue(),
				frequency = windFrequency:GetValue(),
			})
		end
	end

	function windStrength:OnValueChanged()
		boneChanged()
	end

	function windFrequency:OnValueChanged(val)
		boneChanged()
	end

	---@param newValue number
	---@param cvar string
	function windZSlider:ConVarChanged(newValue, cvar)
		if not cvar or cvar:len() < 2 then
			return
		end

		local z = newValue / self:GetTall()
		local vector = vectorFromString(windDirectionConVar:GetString())
		windDirectionConVar:SetString(Format("%.2f %2f %.2f", vector[1], vector[2], z))

		-- Prevent extra convar loops
		---@diagnostic disable-next-line: undefined-field
		if cvar == self.m_strConVarY then
			---@diagnostic disable-next-line: undefined-field
			self.m_strConVarYValue = vectorFromString(self.m_strConVarY, 3)
		end
	end

	function windZSlider:ConVarYNumberThink()
		local z = -vectorFromString(windDirectionConVar:GetString(), 3)
		---@cast z number

		-- In case the convar is a "nan"
		if z ~= z then
			return
		end
		if self.m_strConVarYValue == z then
			return
		end

		self.m_strConVarYValue = z
		self:SetSlideY(math.Remap(self.m_strConVarYValue, -1, 1, 0, 1))
	end

	function windZSlider:OnValueChanged(_, y)
		local z = -math.Remap(y, 0, 1, -1, 1)
		local vector = vectorFromString(windDirectionConVar:GetString())
		---@cast vector Vector

		vector[3] = z
		vector:Normalize()
		windDirectionConVar:SetString(Format("%.2f %2f %.2f", vector[1], vector[2], vector[3]))

		boneChanged()
	end

	function windDirection:OnLookAngChange(angle)
		---@diagnostic disable-next-line:  param-type-mismatch
		local lookAngle = vectorFromString(windDirectionConVar:GetString()):Angle()

		lookAngle:Add(angle)
		local lookVector = lookAngle:Forward()

		windDirectionConVar:SetString(Format("%.2f %.2f %.2f", lookVector[1], lookVector[2], lookVector[3]))
		boneChanged()
	end

	function windDirection:Think()
		local vector = vectorFromString(windDirectionConVar:GetString())
		---@cast vector Vector

		self:GetEntity():SetAngles(vector:Angle())
		self:SetCamPos(self.OrbitPoint - player:EyeAngles():Forward() * self.OrbitDistance)
		self:SetLookAng(player:EyeAngles())

		if not self.Capturing then
			return
		end

		if self.m_bFirstPerson then
			return self:FirstPersonControls()
		end
	end
end

return ui
