--[[

VelWatch 1.3.0
Made for monitoring animated BaseParts and Attachments velocities. (Mainly for making mag procedural mag drops.)

Updates:
  1.1.0
    Added BillboardGui functionality to view velocities in a TextLabel instead of printing them for debugging.
  1.1.1
    VelocityGui is now created by the module instead of a premade instance parented to this module.
  1.2.0
    Constructor is now VelWatch.new() and not VelWatch()
    Typechecking for autocomplete
    Set VelocityGui to unarchivable so it doesn't get cloned
  1.3.0
    Whole class has been rewritten
    Fixed :Destroy()
    Customize RUN_EVENT to Heartbeat or Stepped as you like
    VelocityGui now available to the Server


Written By: Odysseus_Orien / Synthranger#1764 - 2022/02/05
]]

--[=[
    @class VelWatch
]=]
--[=[
    A boolean that determines if the debug VelocityGui should be visible.
    @prop ShowVelocityGui boolean
    @within VelWatch
]=]
--[=[
    The object that is currently being watched by the VelWatch.
    @prop MonitoredObject BasePart | Attachment
    @within VelWatch
    @readonly
]=]
--[=[
    The current velocity of the MonitoredObject.
    @prop Velocity Vector3
    @within VelWatch
    @readonly
]=]
--[=[
    The current rotational velocity of the MonitoredObject.
    @prop RotVelocity Vector3
    @within VelWatch
    @readonly
]=]

export type VelWatch<T> = {
    -- PROPERTIES
	ShowVelocityGui: boolean;
	MonitoredObject: T;
	Velocity: Vector3;
	RotVelocity: Vector3;

    -- INTERNAL PROPERTIES
    __connection: RBXScriptConnection?;
	__lastPosition: Vector3?;
	__lastOrientation: Vector3?;
    __velGui: VelocityGui;

    -- METHODS
	SetObject: (self: VelWatch<T>, object: T | nil) -> ();
	Start: (self: VelWatch<T>, object: T | nil) -> ();
	Stop: (self: VelWatch<T>) -> ();
	Destroy: (self: VelWatch<T>) -> ();
}

local RunService = game:GetService("RunService")

-- RunService.Heartbeat and RunService.Stepped
local RUN_EVENT = RunService.Heartbeat

local VelocityGui = Instance.new("BillboardGui") do
	VelocityGui.Name = "VelocityGui"
	VelocityGui.Archivable = false
	VelocityGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	VelocityGui.Active = true
	VelocityGui.LightInfluence = 1
	VelocityGui.AlwaysOnTop = true
	VelocityGui.Size = UDim2.new(0, 1000, 0, 30)
	VelocityGui.ClipsDescendants = true
    VelocityGui.Archivable = false

	local bg = Instance.new("Frame")
	bg.Archivable = false
	bg.Name = "bg"
	bg.Size = UDim2.new(1, 0, 1, 0)
	bg.BackgroundTransparency = 1
	bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    bg.Archivable = false
	bg.Parent = VelocityGui

	local RotVelocity = Instance.new("TextLabel")
	RotVelocity.Archivable = false
	RotVelocity.Name = "RotVelocity"
	RotVelocity.Size = UDim2.new(1, 0, 0.5, 0)
	RotVelocity.BackgroundTransparency = 1
	RotVelocity.Position = UDim2.new(0, 0, 0.5, 0)
	RotVelocity.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	RotVelocity.TextStrokeTransparency = 0.8
	RotVelocity.TextColor3 = Color3.fromRGB(255, 200, 0)
	RotVelocity.Text = "0, 0, 0"
	RotVelocity.TextWrap = true
	RotVelocity.Font = Enum.Font.Code
	RotVelocity.TextWrapped = true
	RotVelocity.TextScaled = true
    RotVelocity.Archivable = false
	RotVelocity.Parent = VelocityGui

	local Velocity = Instance.new("TextLabel")
	Velocity.Archivable = false
	Velocity.Name = "Velocity"
	Velocity.Size = UDim2.new(1, 0, 0.5, 0)
	Velocity.BackgroundTransparency = 1
	Velocity.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	Velocity.TextStrokeTransparency = 0.8
	Velocity.TextColor3 = Color3.fromRGB(255, 200, 0)
	Velocity.Text = "0, 0, 0"
	Velocity.TextWrap = true
	Velocity.Font = Enum.Font.Code
	Velocity.TextWrapped = true
	Velocity.TextScaled = true
    Velocity.Archivable = false
	Velocity.Parent = VelocityGui
end

type VelocityGui = typeof(VelocityGui)

local VelWatch: VelWatch<BasePart | Attachment> = {}
VelWatch.__index = VelWatch

local function getPosition(object: BasePart | Attachment): Vector3
    if object:IsA("BasePart") then
        return object.Position
    elseif object:IsA("Attachment") then
        return object.WorldPosition
    else
        return error("This function only accepts BaseParts and Attachments!")
    end
end

local function getOrientation(object: BasePart | Attachment): Vector3
    if object:IsA("BasePart") then
        return object.Orientation
    elseif object:IsA("Attachment") then
        return object.WorldOrientation
    else
        return error("This function only accepts BaseParts and Attachments!")
    end
end

--[=[
    Sets the MonitoredObject to the first argument
    @return void
]=]
function VelWatch:SetObject(object: BasePart | Attachment | nil)
	if typeof(object) == "Instance" and (object:IsA("BasePart") or object:IsA("Attachment")) then
		self.MonitoredObject = object
	elseif object == nil then
		self:Stop()
		self.MonitoredObject = nil
		self.__lastPosition = nil
	end
end

--[=[
    Starts watching the current MonitoredObject or if it is nil then it will set the first argument as the MonitoredObject.
    @return void
]=]
function VelWatch:Start(object: BasePart | Attachment | nil)
    if not self.MonitoredObject then
        if object ~= nil then
            self:SetObject(object)
        else
            error("Set an object to monitor first!")
            return
        end
    end

    if self.__connection then
        warn("Already started monitoring the set object.")
        return
    end

    local velGui = self.__velGui
    local velLabel: TextLabel = velGui.Velocity
    local rotVelLabel: TextLabel = velGui.RotVelocity

    self.__connection = RUN_EVENT:Connect(function(deltaTime)
        -- POSITION
        if self.__lastPosition then
            local currentPosition = getPosition(self.MonitoredObject)
            local displacement = currentPosition - self.__lastPosition
            self.Velocity = displacement / deltaTime
        else
            self.__lastPosition = getPosition(self.MonitoredObject)
        end

        -- ORIENTATION
        if self.__lastOrientation then
            local currentOrientation = getOrientation(self.MonitoredObject)
            local displacement = currentOrientation - self.__lastOrientation
            self.RotVelocity = displacement/deltaTime
        else
            self.__lastOrientation = getOrientation(self.MonitoredObject)
        end

        -- GUI
        if self.ShowVelocityGui then
            if velGui.Parent ~= self.MonitoredObject then
                velGui.Parent = self.MonitoredObject
            end

            velLabel.Text = tostring(self.Velocity)
            rotVelLabel.Text = tostring(self.RotVelocity)
        else
            velGui.Parent = nil
            velLabel.Text = tostring(Vector3.new())
            rotVelLabel.Text = tostring(Vector3.new())
        end
    end)
end

--[=[
    Stops watching the MonitoredObject
    @return void
]=]
function VelWatch:Stop()
    if self.__connection then
		self.__connection:Disconnect()
	end
	self.Velocity = Vector3.new()
	self.RotVelocity = Vector3.new()
end

--[=[
    Destroys the VelWatch object
    @return void
]=]
function VelWatch:Destroy()
	self:Stop()
	self.__velGui:Destroy()
	setmetatable(self, nil)
	table.clear(self)
end

--[=[
    Creates a new VelWatch
    @return VelWatch
]=]
function VelWatch.new(showVelocityGui: boolean): VelWatch<BasePart | Attachment>
	local self = setmetatable({
        ShowVelocityGui = showVelocityGui;
        MonitoredObject = nil;
	    Velocity = Vector3.new();
	    RotVelocity = Vector3.new();

        __connection = nil;
        __lastPosition = nil;
        __lastOrientation = nil;
        __velGui = VelocityGui:Clone();
    }, VelWatch)
	return self
end

return VelWatch :: {
    new: (showVelocityGui: boolean) -> VelWatch<BasePart | Attachment>;
}
