function createAssemblageHierarchy(directory)
  local assemblageNames = love.filesystem.getDirectoryItems(directory)

  local assemblageContainer = { }

  for _, name in ipairs(assemblageNames) do
    assemblageContainer[name] = {}
    Concord.utils.loadNamespace(directory .. '/' .. name, assemblageContainer[name])
  end

  local function getAssemblageBySelectorTable(data, selectorTable)
    if #selectorTable == 0 then
      return data
    end
    local newTable = {unpack(selectorTable)}
    local lastSelector = table.remove(newTable, 1)
    return getAssemblageBySelectorTable(data[lastSelector], newTable)
  end

  -- Usage:
  -- local entity = Concord.entity():assemble(assemblageUtil.getBySelector('plants.tree'))
  assemblageContainer.getBySelector = function(selector)
    local selectorTable = stringx.split(selector, ".")
    local assemblage = getAssemblageBySelectorTable(assemblageContainer, selectorTable)

    -- Return function that gets passed into entity:assemble
    return function(e)
      -- Ths function is here for if you want to for example ensure an ID for each assembled entity:
      -- e:give('id', entityRegistry.generateId())
      e:assemble(assemblage)
    end
  end

  return assemblageContainer
end

return {
  createAssemblageHierarchy = createAssemblageHierarchy
}
