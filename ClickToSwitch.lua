--[[
    This mod enables the possibility to enter vehicles by clicking with the mouse onto them.

    Interface for other mods: 
    
    - vehicle:isClickToSwitchToggleMouseAllowed() : 
        This function can be overwritten to disable the mouse visibility action event.
    - vehicle:isClickToSwitchAllowed() : 
        This function can be overwritten to enable the click to switch raycast, if the mouse is active.
]]


---@class ClickToSwitch
ClickToSwitch = {}

ClickToSwitch.MOD_NAME = g_currentModName
ClickToSwitch.DEFAULT_ASSIGNMENT = false
ClickToSwitch.ADVANCED_ASSIGNMENT = true
ClickToSwitch.KEY = "."..ClickToSwitch.MOD_NAME..".clickToSwitch#assignment"

function ClickToSwitch.initSpecialization()
	local schema = Vehicle.xmlSchemaSavegame
	schema:register(XMLValueType.BOOL, "vehicles.vehicle(?)"..ClickToSwitch.KEY,false)
end


function ClickToSwitch.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Drivable, specializations) 
end

function ClickToSwitch.registerEventListeners(vehicleType)	
	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", ClickToSwitch)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", ClickToSwitch)
    SpecializationUtil.registerEventListener(vehicleType, "onReadStream", ClickToSwitch)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", ClickToSwitch)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", ClickToSwitch)
    
end

function ClickToSwitch.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "isClickToSwitchMouseActive", ClickToSwitch.isClickToSwitchMouseActive)
    SpecializationUtil.registerFunction(vehicleType, "getClickToSwitchLastMousePosition", ClickToSwitch.getClickToSwitchLastMousePosition)
    SpecializationUtil.registerFunction(vehicleType, "enterVehicleRaycastClickToSwitch", ClickToSwitch.enterVehicleRaycastClickToSwitch)
    SpecializationUtil.registerFunction(vehicleType, "enterVehicleRaycastCallbackClickToSwitch", ClickToSwitch.enterVehicleRaycastCallbackClickToSwitch)
end

function ClickToSwitch:onLoad(savegame)
	--- Register the spec: spec_clickToSwitch
    local specName = ClickToSwitch.MOD_NAME .. ".clickToSwitch"
    self.spec_clickToSwitch = self["spec_" .. specName]
    local spec = self.spec_clickToSwitch
    
    spec.texts = {}
    spec.texts.toggleMouse = g_i18n:getText("input_CLICK_TO_SWITCH_TOGGLE_MOUSE")
    spec.texts.toggleMouseAlternative = g_i18n:getText("input_CLICK_TO_SWITCH_TOGGLE_MOUSE_ALTERNATIVE")
    spec.texts.changesAssignments = g_i18n:getText("input_CLICK_TO_SWITCH_CHANGES_ASSIGNMENTS")
    spec.texts.enterVehicle = g_i18n:getText("input_CLICK_TO_SWITCH_ENTER_VEHICLE")

    spec.assignmentMode = ClickToSwitch.DEFAULT_ASSIGNMENT
    --- Creating a backup table of all camera and if they are rotatable
    spec.camerasBackup = {}
    for camIndex, camera in pairs(self.spec_enterable.cameras) do
		if camera.isRotatable then
			spec.camerasBackup[camIndex] = camera.isRotatable
		end
	end

    if savegame == nil or savegame.resetVehicles then return end
    spec.assignmentMode = savegame.xmlFile:getValue(savegame.key..ClickToSwitch.KEY,false)
    spec.changedCamera = false
end

function ClickToSwitch:saveToXMLFile(xmlFile, key, usedModNames)
    local spec = self.spec_clickToSwitch
    xmlFile:setValue(key .. "#assignment", spec.assignmentMode)
end

--- Register toggle mouse state and clickToSwitch action events
---@param isActiveForInput boolean
---@param isActiveForInputIgnoreSelection boolean
function ClickToSwitch:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
	if self.isClient then
        local spec = self.spec_clickToSwitch
        self:clearActionEventsTable(spec.actionEvents)
        if self.isActiveForInputIgnoreSelectionIgnoreAI then
            if not g_modIsLoaded["FS25_Courseplay"] and not g_modIsLoaded["FS25_AutoDrive"] then
                --- Toggle mouse action event
                local _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.CLICK_TO_SWITCH_TOGGLE_MOUSE, self, ClickToSwitch.actionEventToggleMouse, false, true, false, true, nil)
                g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)
                g_inputBinding:setActionEventText(actionEventId, spec.texts.toggleMouse)
                
                --- ClickToSwitch (enter vehicle by mouse button) action event
                _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.CLICK_TO_SWITCH_TOGGLE_MOUSE_ALTERNATIVE, self, ClickToSwitch.actionEventToggleMouse, false, true, false, true, nil)
                g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)
                g_inputBinding:setActionEventText(actionEventId, spec.texts.toggleMouseAlternative)
                
                --- ClickToSwitch (enter vehicle by mouse button) action event
                _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.CLICK_TO_SWITCH_CHANGES_ASSIGNMENTS, self, ClickToSwitch.actionEventChangeAssignments, false, true, false, true, nil)
                g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)
                g_inputBinding:setActionEventText(actionEventId, spec.texts.changesAssignments)
            end
            --- ClickToSwitch (enter vehicle by mouse button) action event
            local _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.CLICK_TO_SWITCH_ENTER_VEHICLE, self, ClickToSwitch.actionEventEnterVehicle, false, true, false, true, nil)
            g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)
            g_inputBinding:setActionEventText(actionEventId, spec.texts.enterVehicle)

            ClickToSwitch.updateActionEventState(self)
        end
    end
end

--- Updates toggle mouse state and clickToSwitch action events visibility and usability 
---@param self table vehicle
function ClickToSwitch.updateActionEventState(self)
    --- Activate/deactivate the clickToSwitch action event 
    local spec = self.spec_clickToSwitch

    if spec.actionEvents == nil or next(spec.actionEvents) == nil then 
        return
    end
    
    local actionEvent = spec.actionEvents[InputAction.CLICK_TO_SWITCH_ENTER_VEHICLE]
    g_inputBinding:setActionEventActive(actionEvent.actionEventId, self:isClickToSwitchMouseActive())

    actionEvent = spec.actionEvents[InputAction.CLICK_TO_SWITCH_CHANGES_ASSIGNMENTS]
    if actionEvent then
        g_inputBinding:setActionEventActive(actionEvent.actionEventId, not self:isClickToSwitchMouseActive())
    end
    actionEvent = spec.actionEvents[InputAction.CLICK_TO_SWITCH_TOGGLE_MOUSE]
    if actionEvent then
        g_inputBinding:setActionEventActive(actionEvent.actionEventId, spec.assignmentMode == ClickToSwitch.DEFAULT_ASSIGNMENT)
    end
    if actionEvent then
        actionEvent = spec.actionEvents[InputAction.CLICK_TO_SWITCH_TOGGLE_MOUSE_ALTERNATIVE]
        g_inputBinding:setActionEventActive(actionEvent.actionEventId, spec.assignmentMode == ClickToSwitch.ADVANCED_ASSIGNMENT)
    end
end

function ClickToSwitch:onUpdateTick()
    ClickToSwitch.updateActionEventState(self)
end

--- Action event for turning the mouse on/off
---@param self table vehicle
---@param actionName string
---@param inputValue number
---@param callbackState number
---@param isAnalog boolean
function ClickToSwitch.actionEventToggleMouse(self, actionName, inputValue, callbackState, isAnalog)
    local spec = self.spec_clickToSwitch
    local showCursor = not self:isClickToSwitchMouseActive()
    spec.changedCamera = showCursor
    g_inputBinding:setShowMouseCursor(showCursor)

    ---While mouse cursor is active, disable the camera rotations
    for camIndex,_ in pairs(spec.camerasBackup) do
        self.spec_enterable.cameras[camIndex].isRotatable =  not showCursor and spec.camerasBackup[camIndex] 
    end
end

--- Action event for entering a vehicle by mouse click
---@param self table vehicle
---@param actionName string
---@param inputValue number
---@param callbackState number
---@param isAnalog boolean
function ClickToSwitch.actionEventEnterVehicle(self, actionName, inputValue, callbackState, isAnalog)
    if self:isClickToSwitchMouseActive() then
        local x,y = self:getClickToSwitchLastMousePosition()
        self:enterVehicleRaycastClickToSwitch(x,y)
    end
end

function ClickToSwitch.actionEventChangeAssignments(self, actionName, inputValue, callbackState, isAnalog)
    ClickToSwitch.changeAssignments(self)
    ClickToSwitchChangedAssignmentEvent.sendEvent(self)
end

function ClickToSwitch:onReadStream(streamId, connection)
    local spec = self.spec_clickToSwitch
	spec.assignmentMode = streamReadBool(streamId)
end

function ClickToSwitch:onWriteStream(streamId, connection)
	local spec = self.spec_clickToSwitch
	streamWriteBool(streamId, spec.assignmentMode)
end

function ClickToSwitch:changeAssignments()
    local spec = self.spec_clickToSwitch
    spec.assignmentMode = spec.assignmentMode == ClickToSwitch.DEFAULT_ASSIGNMENT and ClickToSwitch.ADVANCED_ASSIGNMENT 
                          or ClickToSwitch.DEFAULT_ASSIGNMENT
end

--- Is the mouse visible/active
function ClickToSwitch:isClickToSwitchMouseActive()
    return g_inputBinding:getShowMouseCursor()
end

--- Gets the last mouse cursor screen positions
---@return number posX
---@return number posY
function ClickToSwitch:getClickToSwitchLastMousePosition()
    return g_inputBinding.mousePosXLast,g_inputBinding.mousePosYLast 
end

--- Creates a raycast relative to the current camera and the mouse click 
---@param posX number
---@param posY number
function ClickToSwitch:enterVehicleRaycastClickToSwitch(posX, posY)
    local activeCam = getCamera()
    if activeCam ~= nil then
        local hx, hy, hz, px, py, pz = RaycastUtil.getCameraPickingRay(posX, posY, activeCam)
        raycastClosest(hx, hy, hz, px, py, pz, 1000, "enterVehicleRaycastCallbackClickToSwitch", self, CollisionFlag.VEHICLE)
    end
end

--- Check and enters a vehicle.
---@param hitObjectId number
---@param x number world x hit position
---@param y number world y hit position
---@param z number world z hit position
---@param distance number distance at which the cast hit the object
---@return bool was the correct object hit?
function ClickToSwitch:enterVehicleRaycastCallbackClickToSwitch(hitObjectId, x, y, z, distance)
    if hitObjectId ~= nil then
        local object = g_currentMission.nodeToObject[hitObjectId]    
        if object ~= nil then
            -- check if the object is a implement or trailer then get the rootVehicle 
            local rootVehicle = object.rootVehicle
            local targetObject = object.spec_enterable and object or rootVehicle~=nil and rootVehicle.spec_enterable and rootVehicle
            if targetObject then 
                if targetObject ~= g_currentMission.playerSystem:getLocalPlayer():getCurrentVehicle() then 
                    -- this is a valid vehicle, so enter it
                    g_currentMission.playerSystem:getLocalPlayer():requestToEnterVehicle(targetObject)
                    if self ~= g_currentMission.playerSystem:getLocalPlayer():getCurrentVehicle() then
                        local spec = self.spec_clickToSwitch
                        if spec.changedCamera then 
                            g_inputBinding:setShowMouseCursor(false)
                            spec.changedCamera = false
                            for camIndex,_ in pairs(spec.camerasBackup) do
                                self.spec_enterable.cameras[camIndex].isRotatable = spec.camerasBackup[camIndex] 
                            end
                        end
                    end
                end
                return false
            end                
        end
    end
    return true
end


ClickToSwitchChangedAssignmentEvent = {}
local ClickToSwitchChangedAssignmentEvent_mt = Class(ClickToSwitchChangedAssignmentEvent, Event)

InitEventClass(ClickToSwitchChangedAssignmentEvent, "ClickToSwitchChangedAssignmentEvent")

function ClickToSwitchChangedAssignmentEvent.emptyNew()
	return Event.new(ClickToSwitchChangedAssignmentEvent_mt)
end

--- Creates a new Event
function ClickToSwitchChangedAssignmentEvent.new(vehicle)
	local self = ClickToSwitchChangedAssignmentEvent.emptyNew()
    self.vehicle = vehicle
	return self
end

--- Reads the serialized data on the receiving end of the event.
function ClickToSwitchChangedAssignmentEvent:readStream(streamId, connection) -- wird aufgerufen wenn mich ein Event erreicht
	self.vehicle = NetworkUtil.readNodeObject(streamId)
	self:run(connection);
end

--- Writes the serialized data from the sender.ClickToSwitchChangedAssignmentEvent
function ClickToSwitchChangedAssignmentEvent:writeStream(streamId, connection)  -- Wird aufgrufen wenn ich ein event verschicke (merke: reihenfolge der Daten muss mit der bei readStream uebereinstimmen 
	NetworkUtil.writeNodeObject(streamId,self.vehicle)
end

--- Runs the event on the receiving end of the event.
function ClickToSwitchChangedAssignmentEvent:run(connection) -- wir fuehren das empfangene event aus
	if self.vehicle then 
		local spec = self.vehicle.spec_clickToSwitch
		if spec then 
			ClickToSwitch.changeAssignments(self.vehicle)
		end
	end

	--- If the receiver was the client make sure every clients gets also updated.
	if not connection:getIsServer() then
		g_server:broadcastEvent(ClickToSwitchChangedAssignmentEvent.new(self.vehicle), nil, connection, self.vehicle)
	end
end

function ClickToSwitchChangedAssignmentEvent.sendEvent(vehicle)
	if g_server ~= nil then
		g_server:broadcastEvent(ClickToSwitchChangedAssignmentEvent.new(vehicle), nil, nil, vehicle)
	else
		g_client:getServerConnection():sendEvent(ClickToSwitchChangedAssignmentEvent.new(vehicle))
	end
end

