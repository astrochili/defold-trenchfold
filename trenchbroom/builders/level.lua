--[[
  level.lua
  github.com/astrochili/defold-trenchbroom

  Copyright (c) 2022 Roman Silin
  MIT license. See LICENSE for details.
--]]

local utils = require 'trenchbroom.utils'
local config = require 'trenchbroom.config'

local builder = { }

--
-- Local

local function prepare_physics(entity)
  local physics = { }

  local physics_types = { 'static', 'trigger', 'kinematic', 'dynamic' }

  for _, physics_type in ipairs(physics_types) do
    if entity.classname:sub(1, #physics_type) == physics_type then
      physics.type = physics_type
    end
  end    

  for property, value in pairs(entity) do
    if property:sub(1, 8) == 'physics_' then
      local physics_property = property:sub(9, #property)
      
      if physics_property == 'flags' then
        local flags = utils.flags_from_integer(value or 0)

        for _, flag in ipairs(flags) do
          local flag_id = config.physics_flags[flag]
          physics[flag_id] = true
        end
      else
        physics[physics_property] = value
      end
      
      entity[property] = nil
    end
  end

  return next(physics) and physics or nil
end

local function prepare_material(entity)
  local material = {
    material = entity.material
  }

  for index = 0, 7 do
    local texture = 'texture' .. index
    material['texture' .. index] = entity[texture]
    entity[texture] = nil
  end

  entity.material = nil

  return material
end

local function prepare_components(entity)
  local components = { }

  for property, value in pairs(entity) do
    if property:sub(1, 1) == '#' and property:find('%.') == nil then
      local component_id = property:sub(2, #property)
      components[component_id] = value
      entity[property] = nil
    end
  end

  return next(components) and components or nil
end

local function prepare_overrides(entity)
  local overrides = { }

  for property, value in pairs(entity) do
    local component_id = property:match('#(.*)%.')
    local component_property = property:match('#.*%.(.*)')
    
    if component_id and component_property then
      overrides[component_id] = overrides[component_id] or { }
      overrides[component_id][component_property] = value
      entity[property] = nil
    end
  end

  return next(overrides) and overrides or nil
end

local function prepare_properties(entity, textel_size)
  local textel_size = textel_size or 1
  local properties = utils.shallow_copy(entity)
  
  properties.id = nil
  properties.classname = nil
  properties.index = nil
  properties.brushes = nil

  properties.position = properties.origin and {
    x = properties.origin.x / textel_size,
    y = properties.origin.z / textel_size,
    z = -properties.origin.y / textel_size
  } or nil
  properties.origin = nil

  properties.rotation = properties.rotation

  if properties.angle and properties.angle ~= 0 then
    properties.rotation = properties.rotation or { x = 0, y = 0, z = 0 }
    properties.rotation.y = properties.angle
  end
  properties.angle = nil
  
  for property, _ in pairs(properties) do
    if property:sub(1, 4) == '_tb_' then
      properties[property] = nil
    end
  end

  return next(properties) and properties or nil
end

local function prepare_brushes(entity, obj, mtl, textel_size)
  local textel_size = textel_size or 1

  if not entity.brushes then 
    return nil
  end

  local brushes = { }

  for _, brush in ipairs(entity.brushes) do
    local brush_id = 'entity' .. entity.index .. '_brush' .. brush.index
    local merged_brush = { }

    for index, map_face in ipairs(brush.faces) do
      local face = utils.shallow_copy(map_face)

      face.planes = nil
      face.vertices = { }

      local obj_brush = obj[brush_id]
      assert(obj_brush, 'Can\'t find the brush \'' .. brush_id .. '\' in .obj file. Looks like the file is outdated. Try to export .obj from TrenchBroom again to get updated geometry.')
      
      local obj_face = obj_brush[index]
      assert(obj_face, 'Can\'t find the face ' .. index .. ' on brush \'' .. brush_id .. '\' in .obj file. Looks like the file is outdated. Try to export .obj from TrenchBroom again to get updated geometry.')

      for _, obj_vertice in ipairs(obj_face.vertices) do
        local vertice = {
          normal = utils.shallow_copy(obj_vertice.normal),
          position = utils.shallow_copy(obj_vertice.position),
          uv = utils.shallow_copy(obj_vertice.uv)
        }

        vertice.position.x = vertice.position.x / textel_size
        vertice.position.y = vertice.position.y / textel_size
        vertice.position.z = vertice.position.z / textel_size

        table.insert(face.vertices, vertice)
      end

      local texture = obj_face.material
      local texture_is_empty = texture == '__TB_empty'
      local texture_flag = texture_is_empty and 'unused' or texture:match('flags/(.*)')

      face.is_unused = texture_flag == 'unused' or nil
      face.is_area = texture_flag == 'area' or nil
      face.is_clip = texture_flag == 'clip' or nil
      face.is_trigger = texture_flag == 'trigger' or nil

      if not texture_flag then
        face.texture = {
          name = texture,
          path = mtl[texture]
        }
      end

      table.insert(merged_brush, face)
    end

    if #merged_brush > 0 then
      brushes[brush_id] = merged_brush
    end
  end
  
  return brushes
end

--
-- Public

function builder.build(map, obj, mtl)
  local level = { 
    world = { },
    entities = { },
    preferences = { }
  }

  for _, map_entity in pairs(map.entities) do
    local entity = {
      physics = prepare_physics(map_entity),
      material = prepare_material(map_entity),
      components = prepare_components(map_entity),
      overrides = prepare_overrides(map_entity),
      properties = prepare_properties(map_entity, level.preferences.textel_size)
    }

    local classname = map_entity.classname
    local section = level.world
    local group_id = classname
    local group
    local entity_id

    if classname == 'worldspawn' then
      entity.properties = entity.properties or { }
      
      level.preferences.textel_size = entity.properties.textel_size
      level.preferences.material = entity.material
      level.preferences.physics = entity.physics

      entity.properties.textel_size = nil
      entity.material = nil
      entity.physics = nil

      entity_id = classname
      group = section
    elseif classname == 'func_group' then
      entity_id = tostring(map_entity._tb_name)
      group = section

      if group[entity_id] then
        local group_index = tostring(map_entity._tb_id)
        local safe_id = entity_id .. '_' .. group_index
        print('[!] Looks like you have few groups with the same name \'' .. entity_id .. '\'. Renamed to ' .. '\'' .. safe_id .. '\'.')
        entity_id = safe_id
      end
    else
      section = level.entities
    end

    entity.brushes = prepare_brushes(map_entity, obj, mtl, level.preferences.textel_size)

    if not group then
      group = section[group_id] or { }
      section[group_id] = group  
    end

    entity_id = entity_id or map_entity.id

    if not entity_id then
      local group_count = utils.count(group)
      entity_id = group_id .. '_' .. (group_count + 1)
    end
    
    entity.id = entity_id

    group[entity_id] = entity
  end

  for group_name, group_entities in pairs(level.entities) do
    local keys = utils.keys(group_entities)
    local single_key = group_name .. '_1'

    if #keys == 1 and keys[1] == single_key then
      level.entities[group_name] = group_entities[single_key]
    end
  end

  return level
end

return builder