local ui = {}

---@param entity Entity
---@return string
local function getNiceModelName(entity)
	return string.NiceName(string.StripExtension(string.GetFileFromFilename(entity:GetModel())))
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

---@param cPanel DForm|ControlPanel
---@param panelProps PanelProps
---@param panelState PanelState
---@return PanelChildren
function ui.ConstructPanel(cPanel, panelProps, panelState)
	local windable = panelProps.windable

	cPanel:Help("#tool.bonewind.general")

	local boneSettings = makeCategory(cPanel, "Bone Tree", "DForm")

	local boneTree = vgui.Create("DTreeScroller", cPanel)
	boneSettings:AddItem(boneTree)
	boneTree:Dock(TOP)
	boneTree:SizeTo(-1, 250, 0)

	if IsValid(windable) then
		local nodeArray = populateBoneTree(boneTree, windable)
		local depth = getBoneTreeDepth(nodeArray)
		local width = depth * 17
		boneTree:UpdateWidth(width + 64 + 32 + 128)
	end

	local boneEnabled = boneSettings:CheckBox("#tool.bonewind.bone.enabled", "")

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

	return {
		boneEnabled = boneEnabled,
		boneTree = boneTree,
		windDirection = windDirection,
		windZSlider = windZSlider,
		windStrength = windStrength,
		windFrequency = windFrequency,
	}
end

---@param str string
---@param component integer?
---@returns Vector|number
local function vectorFromString(str, component)
	local direction = string.Split(str, " ")
	if component and component > 0 and component < 4 then
		return tonumber(direction[component])
	end
	return Vector(tonumber(direction[1]), tonumber(direction[2]), tonumber(direction[3]))
end

local windDirectionConVar = GetConVar("bonewind_direction")

---@param panelChildren PanelChildren
---@param panelProps PanelProps
---@param panelState PanelState
function ui.HookPanel(panelChildren, panelProps, panelState)
	windDirectionConVar = windDirectionConVar or GetConVar("bonewind_direction")

	local boneTree = panelChildren.boneTree
	local boneEnabled = panelChildren.boneEnabled
	local windDirection = panelChildren.windDirection
	local windZSlider = panelChildren.windZSlider
	local windStrength = panelChildren.windStrength
	local windFrequency = panelChildren.windFrequency

	local windable = panelProps.windable
	local player = LocalPlayer()
	boneEnabled:SetEnabled(false)

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

	---@param node BoneTreeNode
	function boneTree:OnNodeSelected(node)
		local isBoneEnabled = BoneWind.System.isWindedBone(windable:EntIndex(), node.bone)

		boneEnabled:SetEnabled(true)
		boneEnabled:SetText(Format("%s %s", language.GetPhrase("#tool.bonewind.bone.enabled"), node:GetText()))

		boneEnabled:SetChecked(isBoneEnabled)
		toggleWindSettings(isBoneEnabled)
		panelState.selectedBone = node.bone
	end

	function boneEnabled:OnChange(checked)
		local selectedNode = boneTree:GetSelectedItem()
		toggleWindSettings(checked)

		---@cast selectedNode BoneTreeNode
		local direction = vectorFromString(windDirectionConVar:GetString())
		---@cast direction Vector

		BoneWind.System.setBone(windable:EntIndex(), selectedNode.bone, checked, {
			direction = direction,
			magnitude = windStrength:GetValue(),
			frequency = windFrequency:GetValue(),
		})
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

	local red = Color(255, 0, 0)
	function windDirection:Think()
		local vector = vectorFromString(windDirectionConVar:GetString())
		---@cast vector Vector

		if IsValid(windable) then
			debugoverlay.Line(windable:EyePos(), windable:EyePos() + vector * 10, 0.2, red, true)
		end

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
