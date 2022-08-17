--[[
  defold.lua
  github.com/astrochili/defold-trenchbroom

  Copyright (c) 2022 Roman Silin
  MIT license. See LICENSE for details.
--]]

local utils = require 'trenchbroom.utils'
local config = require 'trenchbroom.config'
local templates = require 'trenchbroom.builders.templates'

local builder = { }

--
-- Helpers

local function quat_from_euler(euler)
  if euler == nil then
    return { x = 0, y = 0, z = 0, w = 1 }
  end

  local x = math.rad(euler.x)
  local y = math.rad(euler.y)
  local z = math.rad(euler.z)

  local sr = math.sin(x / 2)
  local sp = math.sin(y / 2)
  local sy = math.sin(z / 2)
  local cr = math.cos(x / 2)
  local cp = math.cos(y / 2)
  local cy = math.cos(z / 2)

  local quat = {
    x = sr * cp * cy - cr * sp * sy,
    y = cr * sp * cy + sr * cp * sy,
    z = cr * cp * sy - sr * sp * cy,
    w = cr * cp * cy + sr * sp * sy
  }

  quat.x = quat.x == 0 and 0 or quat.x
  quat.y = quat.y == 0 and 0 or quat.y
  quat.z = quat.z == 0 and 0 or quat.z
  quat.w = quat.w == 0 and 0 or quat.w

  return quat
end

local function make_float_body(number)
  local text = tostring(number)
  
  if text == 'nil' or text == '-0' then
    text = '0.0'
  elseif text:find('%.') == nil then
    text = text .. '.0'
  end

  return text
end

local function make_raw_property(property, value)
  local raw_type = templates.property_type.hash
  local raw_value = value

  if type(value) == 'number' then 
    raw_type = templates.property_type.number
    raw_value = make_float_body(value)
  elseif type(value) == 'boolean' then
    raw_type = templates.property_type.boolean
    raw_value = tostring(value)
  elseif type(value) == 'table' then
    raw_type = templates.property_type.vector3
    raw_value = make_float_body(value.x) .. ', ' .. make_float_body(value.y) .. ', ' .. make_float_body(value.z)
    
    if value.w then
      raw_type = templates.property_type.vector4
      raw_value = raw_value .. ', ' .. make_float_body(value.w)
    end
  elseif property:sub(-3):lower() == 'url' then
    raw_type = templates.property_type.url
  end

  return raw_type, raw_value
end

--
-- Buffer

local function make_buffer_body(buffer)
  local stream_bodies = { }

  local function stream_to_json(name, stream)
    local stream_body = ''
    stream_body = stream_body .. '    "name": "' .. name .. '",\n'
    stream_body = stream_body .. '    "type": "float32",\n'
    stream_body = stream_body .. '    "count": ' .. stream.count .. ',\n'
    stream_body = stream_body .. '    "data": [\n        ' .. table.concat(stream.data, ',') .. '\n    ]'

    return '{\n' .. stream_body .. '\n}'
  end

  for name, stream in pairs(buffer) do
    if #stream.data > 0 then
      local stream_body = stream_to_json(name, stream)
      table.insert(stream_bodies, stream_body)
    end
  end

  table.sort(stream_bodies, function(a, b) return a < b end)
  local body = '[\n' .. table.concat(stream_bodies, ',\n') .. '\n]'
  
  return body
end

--
-- Mesh

local function make_mesh_body(mesh)
  local body = ''

  body = body .. 'material: "' .. mesh.material .. '"\n'
  body = body .. 'vertices: "'.. mesh.buffer .. '"\n'

  for index = 0, 7 do
    local texture = mesh['texture' .. index]

    if texture then
      body = body .. 'textures: "'.. texture .. '"\n'
    end
  end

  body = body .. 'primitive_type: PRIMITIVE_TRIANGLES' .. '\n'
  body = body .. 'position_stream: "position"' .. '\n'
  body = body .. 'normal_stream: "normal"'

  return body
end

--
-- Convexshape

local function make_convexshape_body(convexshape)
  local body = 'shape_type: TYPE_HULL'

  for _, vector in pairs(convexshape) do
    body = body .. '\n' .. 'data: ' .. make_float_body(vector.x)
    body = body .. '\n' .. 'data: ' .. make_float_body(vector.y)
    body = body .. '\n' .. 'data: ' .. make_float_body(vector.z)
  end

  return body
end

local collision_types = {
  static = 'COLLISION_OBJECT_TYPE_STATIC',
  trigger = 'COLLISION_OBJECT_TYPE_TRIGGER',
  kinematic = 'COLLISION_OBJECT_TYPE_KINEMATIC',
  dynamic = 'COLLISION_OBJECT_TYPE_DYNAMIC'
}

local function make_collisionobject_body(collision_object)
  local body = ''

  body = body .. 'collision_shape: "' .. collision_object.collision_shape .. '"\n'
  body = body .. 'type: '.. collision_types[collision_object.type] .. '\n'
  body = body .. 'mass: ' .. make_float_body(collision_object.mass) .. '\n'
  body = body .. 'friction: ' .. make_float_body(collision_object.friction) ..'\n'
  body = body .. 'restitution: ' .. make_float_body(collision_object.restitution) .. '\n'
  body = body .. 'group: "' .. collision_object.group ..'"\n'
  body = body .. 'mask: "' .. collision_object.mask ..'"\n'
  body = body .. 'linear_damping: ' .. make_float_body(collision_object.linear_damping) .. '\n'
  body = body .. 'angular_damping: ' .. make_float_body(collision_object.angular_damping) .. '\n'
  body = body .. 'locked_rotation: ' .. tostring(collision_object.locked_rotation) .. '\n'
  body = body .. 'bullet: ' .. tostring(collision_object.bullet) .. ''
  
  return body
end

--
-- Script

local function make_vector_body(vector)
  if vector.w then
    return 'vmath.vector4(' .. vector.x .. ', ' .. vector.y .. ', ' .. vector.z .. ', ' .. vector.w .. ')'
  else
    return 'vmath.vector3(' .. vector.x .. ', ' .. vector.y .. ', ' .. (vector.z or 0) .. ')'
  end
end

local function make_script_body(script)
  local body = '--[[\n'
  body = body .. '  This file was created automatically when the map was exported from TrenchBroom.\n'
  body = body .. '  Don\'t edit it, otherwise you will lose your edits the next exporting time.\n'
  body = body .. '--]]\n\n'

  for property, raw in pairs(script.properties) do
    local value

    if property == 'areas' then
      -- skip
    elseif type(raw) == 'table' then
      value = make_vector_body(raw)
    elseif property:sub(-3):lower() == 'url' then
      value = 'msg.url(\'' .. raw .. '\')'
    elseif type(raw) == 'string' then
      value = 'hash \'' .. raw .. '\''
    else
      value = tostring(raw)
    end

    if value then
      body = body .. 'go.property(\'' .. property .. '\', ' .. value .. ')\n'
    end
  end
  
  if script.properties.areas then
    body = body .. '\nfunction init(self)\n'
    body = body .. '  msg.post(\'.\', hash \'init_area\', {\n   '  

    for _, area in ipairs(script.properties.areas) do
      local vector_bodies = { }

      for _, vector in ipairs(area) do
        local vector_body = make_vector_body(vector)
        table.insert(vector_bodies, vector_body)
      end  

      body = body .. ' {\n      ' .. table.concat(vector_bodies, ',\n      ') .. '\n    },'
    end

    body = body .. '\n  })\n'
    body = body .. 'end'
  end

  return body
end

--
-- Properties

local function make_property_bodies(property_template, overrides)
  local property_bodies = { }

  for property, value in pairs(overrides or { }) do
    local raw_type, raw_value = make_raw_property(property, value)
    
    local property_body = property_template:gsub('_PROPERTY_', property)
    property_body = property_body:gsub('_VALUE_', raw_value)
    property_body = property_body:gsub('_TYPE_', raw_type)

    table.insert(property_bodies, property_body)
  end

  return property_bodies
end

--
-- Collection

local function object_to_bodies(object, instance_bodies, embedded_instance_bodies, parent_children_ids)
  for id, child in pairs(object.gameobjects or { }) do
    if type(child) == 'table' then
      local instance_body
      local is_embedded = child.go == nil
      
      if is_embedded then
        instance_body = templates.embedded_instance
      else
        instance_body = templates.instance:gsub('_PATH_', child.go)
        child.go = nil
      end
      
      if parent_children_ids then
        table.insert(parent_children_ids, id)
      end

      -- Set identifier
      
      instance_body = instance_body:gsub('_ID_', id)

      -- Set position

      local position = child.position or { }
      instance_body = instance_body:gsub('_POSITION_X_', make_float_body(position.x))
      instance_body = instance_body:gsub('_POSITION_Y_', make_float_body(position.y))
      instance_body = instance_body:gsub('_POSITION_Z_', make_float_body(position.z))
      child.position = nil

      -- Set rotation

      local rotation = quat_from_euler(child.rotation)
      instance_body = instance_body:gsub('_ROTATION_X_', make_float_body(rotation.x))
      instance_body = instance_body:gsub('_ROTATION_Y_', make_float_body(rotation.y))
      instance_body = instance_body:gsub('_ROTATION_Z_', make_float_body(rotation.z))
      instance_body = instance_body:gsub('_ROTATION_W_', make_float_body(rotation.w))
      child.rotation = nil

      if is_embedded then
        local data = '""\n'
        local components = { }

        -- Set components

        for component_id, component_path in pairs(child.components or { }) do
          local component_body = templates.component:gsub('_ID_', component_id)
          component_body = component_body:gsub('_PATH_', component_path)

          -- Set component overrides

          local overrides = (child.overrides or { })[component_id]
          local component_property_bodies = make_property_bodies(templates.component_property, overrides)
          component_body = component_body:gsub('_COMPONENT_PROPERTIES_\n', table.concat(component_property_bodies))
          
          table.insert(components, component_body)
        end
        
        if #components > 0 then
          data = table.concat(components)
          data = #components > 0 and data:sub(3) or data
        end

        instance_body = instance_body:gsub('_DATA_\n', data)

        -- Set children

        local children_ids = { }
        instance_bodies, embedded_instance_bodies = object_to_bodies(child, instance_bodies, embedded_instance_bodies, children_ids)

        table.sort(children_ids)
        local children_body = ''

        for _, child_id in ipairs(children_ids) do
          local child_body = templates.child:gsub('_ID_', child_id) .. '\n'
          children_body = children_body .. child_body
        end

        instance_body = instance_body:gsub('_CHILDREN_\n', children_body)

        table.insert(embedded_instance_bodies, instance_body)
      else

        -- Set instance overrides

        local instance_properties_bodies = { }

        for component_id, overrides in pairs(child.overrides or { }) do
          local instance_properties_body = templates.instance_properties:gsub('_ID_', component_id)
          local instance_property_bodies = make_property_bodies(templates.instance_property, overrides)
  
          instance_properties_body = instance_properties_body:gsub('_PROPERTIES_\n', table.concat(instance_property_bodies))
          table.insert(instance_properties_bodies, instance_properties_body)
        end
  
        instance_body = instance_body:gsub('_INSTANCE_PROPERTIES_\n', table.concat(instance_properties_bodies))
  
        table.insert(instance_bodies, instance_body)
      end
    end
  end

  return instance_bodies, embedded_instance_bodies
end

local function make_collection_body(collection)
  local body = templates.collection
  body = body:gsub('_ID_', config.map_name)

  local instance_bodies, embedded_instance_bodies = object_to_bodies(collection, { }, { })

  body = body:gsub('_EMBEDDED_INSTANCES_\n', table.concat(embedded_instance_bodies))
  body = body:gsub('_INSTANCES_\n', table.concat(instance_bodies))
  
  return body
end

--
-- Public

function builder.build(instances)
  local files = { }

  local component_builders = {
    buffer = make_buffer_body,
    mesh = make_mesh_body,
    convexshape = make_convexshape_body,
    collisionobject = make_collisionobject_body,
    script = make_script_body,
    collection = make_collection_body,
  }

  for component_type, instances in pairs(instances) do
    for file_path, instance in pairs(instances) do
      local file = {
        path = file_path,
        content = component_builders[component_type](instance)
      }
      table.insert(files, file)
    end
  end

  table.sort(files, function(a, b) return a.path > b.path end)
  
  return files
end

return builder