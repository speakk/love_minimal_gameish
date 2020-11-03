local positionUtil = require 'utils.position'

local function isPositionAvailable(self, x, y)
  return self.collisionMap[positionUtil.positionToString(x, y)]
end

local tilesetImageFloor = love.graphics.newImage('media/tileset/tileset3.png')
local tilesetImageWall = love.graphics.newImage('media/tileset/tileset4.png')

local bitmaskIndices = {
  0, 4, 84, 92, 124, 116, 80,
  16, 28, 117, 95, 255, 253, 113,
  21, 87, 221, 127, 255, 247, 209,
  29, 125, 119, 199, 215, 213, 81,
  31, 255, 241, 20, 65, 17, 1,
  23, 223, 245, 85, 68, 93, 112,
  5, 71, 197, 69, 64, 7, 193
}

local bitmaskToTilesetIndex = {}
for i=1, #bitmaskIndices do
  bitmaskToTilesetIndex[bitmaskIndices[i]] = i
end

local tilesetTileSize = 32
local tilesetW = 7
local tilesetH = 7

local tilesetQuads = {}
for y=0,tilesetH-1 do
  for x=0,tilesetW-1 do
    local quad = love.graphics.newQuad(x*tilesetTileSize, y*tilesetTileSize,
      tilesetTileSize, tilesetTileSize,
      tilesetW*tilesetTileSize, tilesetH*tilesetTileSize)
    table.insert(tilesetQuads, quad)
  end
end

local bitmaskValues = {
  n = 1, ne = 2, e = 4,
  se = 8, s = 16,
  sw = 32, w = 64, nw = 128
}

local function getMapValueSafe(map, x, y)
  if not map[y] or not map[y][x] then return 'void' end
  return map[y][x]
end

local function calculateAutotileBitmask(x, y, map)
  local allDirections = {
    n = { x = x, y = y - 1 },
    nw = { x = x-1, y = y-1, neighbors = { "n", "w" } },
    ne = { x = x+1, y = y-1, neighbors = { "n", "e" } },
    w = { x = x-1, y = y },
    e = { x = x+1, y = y },
    s = { x = x, y = y+1 },
    sw = { x = x-1, y = y+1, neighbors = { "s", "w" } },
    se = { x = x+1, y = y+1, neighbors = { "s", "e" } }
  }

  local isBlocked = function(mapValue)
    return mapValue == 'void'
  end

  local value = 0
  for dir, coords in pairs(allDirections) do
    if not isBlocked(getMapValueSafe(map, coords.x, coords.y)) then
      if coords.neighbors then
        local hasBothNeighbors = true
        for _, neighborDir in pairs(coords.neighbors) do
          local neighbor = allDirections[neighborDir]
          if isBlocked(getMapValueSafe(map, neighbor.x, neighbor.y)) then
            hasBothNeighbors = false
          end
        end

        if hasBothNeighbors then
          value = value + bitmaskValues[dir]
        end
      else
        value = value + bitmaskValues[dir]
      end
    end
  end

  return value
end

local function drawTile(x, y, _, tileSet, tileSize, _, tiles, offsetX, offsetY)
  local finalX = (x - offsetX) * tileSize
  local finalY = (y - offsetY) * tileSize
  local autotileBitmask = calculateAutotileBitmask(x, y, tiles)

  local index = bitmaskToTilesetIndex[autotileBitmask]
  if tilesetQuads[index] then
    love.graphics.draw(tileSet, tilesetQuads[index], finalX, finalY)
  end
end

local tileValueToEntity = {
  void = function(x, y, _, _, _, world)
    return Concord.entity(world):give("gridCollisionItem", x, y)
  end,
  exit = function(x, y, _, _, tileSize, world)
    local portal = Concord.entity(world):assemble(ECS.a.getBySelector("dungeon_features.portal"))
    portal:give("position", x*tileSize, y*tileSize)
  end,
  wall = function(x, y, _, _, _, world)
    return Concord.entity(world):give("gridCollisionItem", x, y)
  end
}

local function createEntity(x, y, tileValue, tileSet, tileSize, world, tiles)
  tileValueToEntity[tileValue](x, y, tileValue, tileSet, tileSize, world, tiles)
end

local handleTile = {
  wall = {drawTile, createEntity},
  floor = {drawTile},
  void = {createEntity},
  exit = {createEntity}
}

local function drawCanvas(tileSize, layers, world, canvasSizeX, canvasSizeY, startX, startY, endX, endY)
  print("Drawing map canvas, size: ", canvasSizeX, canvasSizeY, "start x, y", startX, startY, "end x, y", endX, endY)
  local canvas = love.graphics.newCanvas(canvasSizeX, canvasSizeY)
  love.graphics.setCanvas(canvas)

  -- NOTE: Right now drawing all layers right on each other in the same canvas.
  -- Consider possible benefits of having the layers being drawn separately
  -- (would allow parallax movement between layers etc)
  for _, layer in ipairs(layers) do
    local tiles = layer.tiles
    for y = startY, endY -1 do
      for x = startX, endX -1 do
        if tiles[y] and tiles[y][x] then
          local tileValue = tiles[y][x]
          local tileHandlers = handleTile[tileValue]
          if tileHandlers then
            for _, tileHandler in ipairs(tileHandlers) do
              tileHandler(x, y, tileValue, layer.tilesetImage, tileSize, world, tiles, startX, startY)
            end
          end
        end
      end
    end

  end

  love.graphics.setCanvas()
  return canvas
end

local function drawMap(map, world)
  local canvasSizeInTilesX = 10
  local canvasSizeInTilesY = 10

  local canvasesX = math.ceil(map.size.x/canvasSizeInTilesX)
  local canvasesY = math.ceil(map.size.y/canvasSizeInTilesY)

  local entities = {}

  for canvasY=0,canvasesY-1 do
    for canvasX=0,canvasesX-1 do
      local startX = canvasX * canvasSizeInTilesX + 1
      local startY = canvasY * canvasSizeInTilesY + 1
      local endX = startX + canvasSizeInTilesX
      local endY = startY + canvasSizeInTilesY
      local canvasWidth = canvasSizeInTilesX * map.tileSize
      local canvasHeight = canvasSizeInTilesY * map.tileSize

      local canvas = drawCanvas(
      map.tileSize,
      map.layers,
      world,
      canvasWidth, canvasHeight,
      startX, startY, endX, endY
      )

      local mediaEntity = {
        image = canvas,
        metaData = {},
        origin = { x = 0, y = 0 }
      }

      local mediaPath = 'mapLayerCache.floor' .. startX .. "|" .. startY
      mediaManager:setMediaEntity(mediaPath, mediaEntity)
      local entity = Concord.entity()
      :give('sprite', mediaPath)
      :give('size', canvasWidth, canvasHeight)
      :give('position', startX * map.tileSize, startY * map.tileSize)

      table.insert(entities, entity)
    end
  end

  return entities
end

local function clearMediaEntries(entities)
  if not entities then return end
  for _, entity in ipairs(entities) do
    mediaManager:removeMediaEntity(entity.sprite.image)
  end
end

local function initializeMapEntities(map)
  local entities = {}
  if not map.entities then return end
  for _, entityData in ipairs(map.entities) do
    local entity = Concord.entity()
    if entityData.assemblageSelector then
      entity:assemble(ECS.a.getBySelector(entityData.assemblageSelector))
    elseif entityData.components then
      for _, component in ipairs(entityData.components) do
        if component.properties then
          entity:give(component.name, unpack(component.properties))
        else
          entity:give(component.name)
        end
      end
    else
      error("Map entity had no component data")
    end

    table.insert(entities, entity)
  end

  return entities
end

local function clearEntities(entities)
  if not entities then return end
  for _, entity in ipairs(entities) do
    entity:destroy()
  end

  entities.length = 0
end


local function initializeEntities(world, entities)
  for _, entity in ipairs(entities) do
    world:addEntity(entity)
  end
end

local MapManager = Class {
  init = function(self)
    self.collisionMap = {}
    self.map = {}
    self.entities = {}
    self.layerSprites = {}
  end,

  -- Note: x and y are grid coordinates, not pixel
  -- value: 0 = no collision 1 = collision
  setCollisionMapValue = function(self, x, y, value)
    self.collisionMap[y][x] = value
  end,

  getCollisionMap = function(self)
    return self.collisionMap
  end,

  setMap = function(self, map, world)
    print("setMap, new map ahoy!", map)
    clearMediaEntries(self.floorCanvasEntities)
    clearEntities(self.floorCanvasEntities)

    self.collisionMap = functional.generate(map.size.y, function(_)
      return functional.generate(map.size.x, function(_)
        return 0
      end)
    end)

    self.map = map

    self.mapCanvasEntities = drawMap(map, world)

    for _, entity in ipairs(self.mapCanvasEntities) do
      world:addEntity(entity)
    end
  end,

  getMap = function(self)
    return self.map
  end,

  getPath = function(self, fromX, fromY, toX, toY)
    return luastar:find(self.map.size.x, self.map.size.y,
      { x = fromX, y = fromY },
      { x = toX, y = toY },
      isPositionAvailable,
      true)
  end
}

local function createLayer(width, height, tilesetImage, valueFunction)
  local layer = {
    tilesetImage = tilesetImage,
    tiles = {}
  }
  if width and height then
    for y=1,height do
      local row = {}
      table.insert(layer.tiles, row)

      for x=1,width do
        if valueFunction then
          row[x] = valueFunction(x, y)
        end
      end
    end
  end

  return layer
end

local function generateSimpleMap(seed, width, height)
  local map = { layers = {} }
  local scale = 0.1

  table.insert(map.layers, createLayer(width, height, tilesetImageFloor, function(x, y)
    local bias = 0.2
    local value = love.math.noise(x * scale + bias + seed, y * scale + bias + seed)
    if value > 0.8 then
      return 'void'
    else
      return 'floor'
    end
  end))

  table.insert(map.layers, createLayer(width, height, tilesetImageWall, function(x, y)
    local bias = 0.3
    local value = love.math.noise(x * scale + bias + seed, y * scale + bias + seed)
    if value > 0.2 then
      return nil
    else
      return 'wall'
    end
  end))

  local featuresLayer = createLayer(width, height)
  featuresLayer.tiles[math.random(1, height)][math.random(1, width)] = "exit"

  return map
end

MapManager.generateMap = function(levelNumber)
  local tileSize = 32

  local width = 20
  local height = 20

  local map = generateSimpleMap(levelNumber, width, height)

  return {
    tileSize = tileSize,
    size = { x = width, y = height },
    layers = map.layers
  }
end

return MapManager
