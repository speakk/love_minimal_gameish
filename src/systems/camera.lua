local settings = require 'settings'

local CameraSystem = Concord.system({ pool = { 'cameraTarget', 'position', 'velocity', 'speed' }})

local zoomInterpolationSpeed = 1
local zoomFactor = 5 -- This gets dynamically updated based on velocity in update
local minZoomFactor = 1.6
local maxZoomFactor = 4

function CameraSystem:init()
  self.attached = false
end

function CameraSystem:setCamera(camera)
  self.camera = camera
  self.camera:setScale(zoomFactor)
  if self.map then
    local tileSize = settings.tileSize
    self.camera:setWorld(tileSize, tileSize, self.map.width * tileSize, self.map.height * tileSize)
  end
end

function CameraSystem:attachCamera()
  if not self.attached then
    self.attached = true
    self.camera:setUpCamera()
  end
end

function CameraSystem:detachCamera()
  if self.attached then
    self.attached = false
    self.camera:takeDownCamera()
  end
end

function CameraSystem:mapChange(map)
  self.camera:setWorld(settings.tileSize, settings.tileSize, map.width * settings.tileSize, map.height * settings.tileSize)
  self.map = map
end

function CameraSystem:windowResize(width, height)
  self.camera:setWindow(0, 0, width, height)
end

-- public static float Damp(float a, float b, float lambda, float dt)
-- {
--     return Mathf.Lerp(a, b, 1 - Mathf.Exp(-lambda * dt))
-- }
--
--
--public static float Damp(float source, float target, float smoothing, float dt)
--return Mathf.Lerp(source, target, 1 - Mathf.Pow(smoothing, dt))

-- local function damp(a, b, lambda, dt)
--   return math.lerp(a, b, 1 - (-lambda * dt))
-- end

local function damp(source, target, smoothing, dt)
  return math.lerp(source, target, 1 - math.pow(smoothing, dt))
end

function CameraSystem:update(dt)
  -- Pick first from target pool until we have implemented camera target switching (if we ever need it)
  local target = self.pool[1]

  if target then
    -- Do linear interpolation between current camera position and the target
    local startX, startY = self.camera:getPosition()
    local targetX, targetY = Vector.split(target.position.vec)
    local lerpSpeed = 0.1
    local finalX = math.floor(mathx.lerp(startX, targetX, lerpSpeed))
    local finalY = math.floor(mathx.lerp(startY, targetY, lerpSpeed))
    self.camera:setPosition(finalX, finalY)
    self:getWorld():emit("cameraUpdated", self.camera)

    -- Set zoom level based on target velocity (also do linear interpolation
    -- between old value and new)
    --local previousZoomFactor = zoomFactor
    --local targetZoomFactor = target.velocity.vec.length * 0.2
    --print(targetZoomFactor)
    -- local targetZoomFactor = target.velocity.vec.length * target.speed.value / (target.speed.value) + 1
    --local interpolatedZoomFactor = mathx.lerp(previousZoomFactor, targetZoomFactor, zoomInterpolationSpeed)
    --local interpolatedZoomFactor = lume.lerp(previousZoomFactor, targetZoomFactor, zoomInterpolationSpeed)
    -- zoomFactor = mathx.clamp(interpolatedZoomFactor, minZoomFactor, maxZoomFactor)
    --zoomFactor = damp(5 - target.velocity.vec.length * 0.005, zoomFactor, 0.99, dt)
    -- zoomFactor = damp(5, 3, target.velocity.vec.length * 0.05, dt)
    zoomFactor = math.lerp(5, 3, target.velocity.vec.length * 0.005 * dt)
    self.camera:setScale(zoomFactor)
    --self.camera:setScale(2.5 - interpolatedZoomFactor)
  end
end

return CameraSystem
