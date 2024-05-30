--[[
  level.lua
  github.com/astrochili/defold-trenchfold

  Copyright (c) 2022 Roman Silin
  MIT license. See LICENSE for details.
--]]

local utils = require 'trenchfold.utils.utils'
local config = require 'trenchfold.utils.config'
local sculptor = require 'trenchfold.designers.sculptor'

local designer = {}

--
-- Local

local function prepare_physics(entity)
  local physics = {}

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
  local components = {}

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
  local overrides = {}

  for property, value in pairs(entity) do
    local component_id = property:match('#(.*)%.')
    local component_property = property:match('#.*%.(.*)')

    if component_id and component_property then
      overrides[component_id] = overrides[component_id] or {}
      overrides[component_id][component_property] = value
      entity[property] = nil
    end
  end

  return next(overrides) and overrides or nil
end

local function prepare_properties(entity, textel_size)
  local textel_size = textel_size or 1
  local properties = utils.shallow_copy(entity) or {}

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

--
-- Public

function designer.design(map)
  local level = {
    world = {},
    entities = {},
    preferences = {}
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
      entity.properties = entity.properties or {}

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
        print('[!] Looks like you have few groups with the same name \'' ..
          entity_id .. '\'. Renamed to ' .. '\'' .. safe_id .. '\'.')
        entity_id = safe_id
      end
    else
      section = level.entities
    end

    entity.brushes = sculptor.make_brushes(map_entity, level.preferences.textel_size)

    if not group then
      group = section[group_id] or {}
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

return designer
