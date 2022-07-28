# Getting Started

## Usage Example
```lua
local VelWatch = require(this.module)
local newVelWatcher = VelWatch.new(true) --set to true if you want to see the velocity in a gui
newVelWatcher:SetObject(AnimatedBasePart)
newVelWatcher:Start()
print(newVelWatcher.Velocity)
print(newVelWatcher.RotVelocity)
```
### Mag Drop Example
```lua
local magWatcher = VelWatch.new(false)
magWatcher:Start(magPart)

reloadAnim:GetMarkerReachedSignal("MagDrop"):Connect(function()
    local magClone: BasePart = magPart:Clone()
    magClone.CFrame = magPart.CFrame
    magClone.CanCollide = true
    magClone.Parent = workspace.Terrain

    magClone.AssemblyLinearVelocity = magWatcher.Velocity
    magClone.AssemblyAngularVelocity = magWatcher.RotVelocity

    task.wait(5)
    magClone:Destroy()
end)
```