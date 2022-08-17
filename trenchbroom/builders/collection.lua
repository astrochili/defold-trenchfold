--[[
  collection.lua
  github.com/astrochili/defold-trenchbroom

  Copyright (c) 2022 Roman Silin
  MIT license. See LICENSE for details.
--]]

local utils = require 'trenchbroom.utils'
local config = require 'trenchbroom.config'

local builder = { }

--
-- Buffer

local function vertices_to_triangles(vertices)
  local pool = { }
  local triangles = { }

  for _, vertice in ipairs(vertices) do
    table.insert(pool, vertice)
  end

  while #pool >= 3 do
    local a = pool[1]
    local b = pool[2]
    local c = pool[3]

    local triangle = { a, b, c }
    table.insert(triangles, triangle)

    table.remove(pool, 1)
    table.remove(pool, 1)
    table.insert(pool, a)
  end
  
  return triangles
end

local function append_face_to_buffer(face, buffer)
  buffer.position = buffer.position or { count = 3, data = { } }
  buffer.normal = buffer.normal or { count = 3, data = { } }
  buffer.texcoord0 = buffer.texcoord0 or { count = 2, data = { } }

  local triangles = vertices_to_triangles(face.vertices)

  for _, triangle in ipairs(triangles) do
    for _, vertice in ipairs(triangle) do
      table.insert(buffer.position.data, vertice.position.x)
      table.insert(buffer.position.data, vertice.position.y)
      table.insert(buffer.position.data, vertice.position.z)
      table.insert(buffer.normal.data, vertice.normal.x)
      table.insert(buffer.normal.data, vertice.normal.y)
      table.insert(buffer.normal.data, vertice.normal.z)
      table.insert(buffer.texcoord0.data, vertice.uv.x)
      table.insert(buffer.texcoord0.data, vertice.uv.y)
    end
  end

  return buffer
end

--
-- Convexshape

local function append_face_to_convexshape(face, convexshape)
  for _, vertice in ipairs(face.vertices) do
    local x, y, z = vertice.position.x, vertice.position.y, vertice.position.z
    
    convexshape[x .. ' ' .. y .. ' ' .. z] = {
      x = x,
      y = y,
      z = z
    }
  end

  return convexshape
end

--
-- Transfer

local function transfer_physics_to_go(item, go)
  go.physics = item.physics
  item.physics = nil

  return go
end

local function transfer_material_to_go(item, go)
  go.material = item.material
  item.material = nil

  return go
end

local function transfer_components_to_go(item, go)
  go.components = item.components or { }
  item.components = nil
  
  return go
end

local function transfer_overrides_to_go(item, go)
  go.overrides = item.overrides or { }
  item.overrides = nil
  
  return go
end


local function transfer_properties_to_script(properties, go, instances)
  local full_script_path = config.full_path(config.script_directory, go.id .. '.script')
  local script = instances.script[full_script_path] or {
    properties = { }
  }

  for property, value in pairs(properties) do
    script.properties[property] = value
  end

  instances.script[full_script_path] = script
  go.components.properties = config.resource_path(full_script_path)
end

local function transfer_properties_to_go(item, go, instances)
  if not item.properties then
    return go, instances
  end

  local source = item.properties

  go.go = source.go
  go.material = source.material
  go.position = source.position
  go.rotation = source.rotation

  source.go = nil
  source.material = nil
  source.position = nil
  source.rotation = nil

  if next(source) then
    transfer_properties_to_script(source, go, instances)
  end

  item.properties = nil

  return go, instances
end

local function transfer_brushes_to_go(item, go, instances, preferences)
  if not item.brushes then
    return go, instances
  end

  local source = { }
  for _, brush in pairs(item.brushes) do
    table.insert(source, brush)
  end
  item.brushes = nil

  local areas = { }

  for brush_index, brush in ipairs(source) do
    local area_convexshape

    for face_index, face in ipairs(brush) do
      local physics = utils.shallow_copy(preferences.physics) or { }
      
      for property, value in pairs(go.physics or { }) do
        physics[property] = value
      end

      local collision_type = physics.type or 'static'
      local is_mesh = true

      if face.is_trigger then
        is_mesh = false
        collision_type = 'trigger'
      elseif face.is_clip then
        is_mesh = false
        collision_type = collision_type == 'trigger' and 'static' or collision_type
      elseif face.is_area then
        is_mesh = false
        collision_type = nil
        area_convexshape = append_face_to_convexshape(face, area_convexshape or { })
      elseif face.is_unused then
        is_mesh = false
        collision_type = nil
      end

      if face.is_ghost then
        collision_type = nil
      end

      if is_mesh then
        local id = go.id .. '_' .. face.texture.name:gsub('/', '_')
        local full_buffer_path = config.full_path(config.buffer_directory, id .. '.buffer')
        local full_mesh_path = config.full_path(config.mesh_directory,  id .. '.mesh')

        local buffer = instances.buffer[full_buffer_path] or { }
        buffer = append_face_to_buffer(face, buffer)
        instances.buffer[full_buffer_path] = buffer

        local mesh = instances.mesh[full_mesh_path] or {
          material = (go.material or { }).material or preferences.material.material or '/builtins/materials/model.material',
          buffer = config.resource_path(full_buffer_path),
          texture0 = config.resource_path(config.assets_directory, face.texture.path)
        }

        local texture0_directory = mesh.texture0:match('(.*)/')
        local texture0_filename = mesh.texture0:match('.*/(.*)%.')
        local texture0_extension = mesh.texture0:match('.*/.*%.(.*)')

        for index = 1, 7 do
          local texture_key = 'texture' .. index
          local texture = (go.material or { })[texture_key] or preferences.material[texture_key]

          if texture and texture:find('*') then
            local texture_directory = texture:match('(.*)/') or texture0_directory
            local texture_filename = texture:match('.*/(.*)%.') or texture:match('.*/(.*)') or texture:match('(.*)%.') or texture
            local texture_extension = texture:match('.*%.(.*)') or texture0_extension

            texture_filename = texture_filename:gsub('*', texture0_filename)
            texture = texture_directory .. '/' .. texture_filename .. '.' .. texture_extension
          end

          mesh[texture_key] = texture
        end

        instances.mesh[full_mesh_path] = mesh
        go.components[id] = config.resource_path(full_mesh_path)
      end

      if collision_type then
        local id = go.id .. '_b' .. brush_index
        id = face.is_separated and (id .. '_f' .. face_index) or id
        id = id .. '_' .. collision_type

        local full_convexshape_path = config.full_path(config.convexshape_directory, id .. '.convexshape')
        local full_collisionobject_path = config.full_path(config.collisionobject_directory,  id .. '.collisionobject')

        local convexshape = instances.convexshape[full_convexshape_path] or { }
        convexshape = append_face_to_convexshape(face, convexshape)
        instances.convexshape[full_convexshape_path] = convexshape

        local collisionobject = instances.collisionobject[full_collisionobject_path] or {
          collision_shape = config.resource_path(full_convexshape_path),
          type = collision_type,
          group = physics.group or 'default',
          mask = physics.mask or 'default',
          friction = physics.friction or 0.1,
          restitution = physics.restitution or 0.5,
          mass = physics.mass or (collision_type == 'dynamic' and 1 or 0),
          angular_damping = physics.angular_damping or 0,
          linear_damping = physics.linear_damping or 0,
          locked_rotation = physics.is_rotation_locked or false,
          bullet = physics.is_bullet or false
        }

        instances.collisionobject[full_collisionobject_path] = collisionobject
        go.components[id] = config.resource_path(full_collisionobject_path)
      end
    end

    if area_convexshape then
      local area = { }
      
      for _, position in pairs(area_convexshape) do
        table.insert(area, position)
      end

      table.insert(areas, area)
    end
  end

  if #areas > 0 then
    local properties = { areas = areas }
    transfer_properties_to_script(properties, go, instances)
  end

  return go, instances
end

local function item_to_go(item, preferences, instances)
  local go = { }
  local instances = instances

  go.id = item.id
  item.id = nil

  go = transfer_physics_to_go(item, go)
  go = transfer_material_to_go(item, go)
  go = transfer_components_to_go(item, go)
  go = transfer_overrides_to_go(item, go)
  go, instances = transfer_properties_to_go(item, go, instances)
  go, instances = transfer_brushes_to_go(item, go, instances, preferences)
  
  go.components = next(go.components) and go.components or nil
  go.overrides = next(go.overrides) and go.overrides or nil

  if next(item) then
    go.gameobjects = { }
    
    for child_id, child in pairs(item) do
      go.gameobjects[child_id] = item_to_go(child, preferences, instances)
    end
  end

  go.id = nil
  go.physics = nil

  return go, instances
end

--
-- Public

function builder.build(level)
  local preferences = level.preferences
  level.preferences = nil
  
  local instances = {
    buffer = { },
    mesh = { },
    convexshape = { },
    collisionobject = { },
    collection = { },
    script = { }
  }

  local collection, instances = item_to_go(level, preferences, instances)  
  local full_collection_path = config.full_path(config.map_directory, config.map_name .. '.collection')
  instances.collection[full_collection_path] = collection
  
  return instances
end

return builder