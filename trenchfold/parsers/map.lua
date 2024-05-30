--[[
  parser.lua
  github.com/astrochili/defold-trenchfold

  Copyright (c) 2022 Roman Silin
  MIT license. See LICENSE for details.
--]]

local table_insert = table.insert

local utils = require 'trenchfold.utils.utils'
local config = require 'trenchfold.utils.config'

local parser = {}

--
-- Local

local patterns = {
  etc = '%s?(.*)',
  meta = '// (%S*): (%S*)',
  group = '// (%S*) (%d*)',
  property = '"(.*)" "(.*)"',
  vector2 = '(%S*) (%S*)',
  vector3 = '(%S*) (%S*) (%S*)',
  vector4 = '(%S*) (%S*) (%S*) (%S*)',
  planes = '%( (%S* %S* %S*) %) %( (%S* %S* %S*) %) %( (%S* %S* %S*) %)',
  texture_name_quated = '"(.-)"',
  texture_name = '(%S+)',
  texture_uv = '(%S*) (%S*) (%S*) (%S*) (%S*)',
  face_attributes = '(%S*) (%S*) (%S*)'
}

local function parse_vector(raw)
  local x, y, z, w = raw:match(patterns.vector4)

  if not x then
    x, y, z = raw:match(patterns.vector3)
  end

  if not x then
    x, y = raw:match(patterns.vector2)
  end

  x = tonumber(x)
  y = tonumber(y)
  z = tonumber(z)
  w = tonumber(w)

  local vector = {
    x = x,
    y = y,
    z = z,
    w = w
  }

  return (x and y) and vector or nil
end

--
-- Public

function parser.parse(map_path)
  local map = {
    entities = {}
  }

  local content = utils.read_file(map_path)
  local lines = utils.get_lines(content)

  local entity
  local brush

  for _, line in ipairs(lines) do
    repeat
      -- Read the map meta

      local meta, value = line:match(patterns.meta)

      if meta and value then
        map[meta:lower()] = value
        do break end
      end

      -- Read the group header

      local group_type, index = line:match(patterns.group)

      if group_type and index then
        if brush then
          -- Finish to parse the current brush
          -- because of the new group is started
          table_insert(entity.brushes, brush)
          brush = nil
        end

        if group_type == 'entity' then
          if entity then
            -- Finish to parse the current entity
            -- because of the new entity is started
            table_insert(map.entities, entity)
            entity = nil
          end

          entity = {
            index = tonumber(index),
            brushes = {}
          }
        elseif group_type == 'brush' then
          brush = {
            index = tonumber(index),
            faces = {}
          }
        end

        do break end
      end

      -- Read the group property

      local property, value = line:match(patterns.property)

      if property and value then
        local property = utils.trim(property)
        local value = utils.trim(value)

        local number = tonumber(value)
        local boolean = utils.boolean_from_string(value)
        local vector = parse_vector(value)

        if boolean ~= nil then
          value = boolean
        else
          value = number or vector or value
        end

        entity[property] = value

        do break end
      end

      -- Read the brush face

      local plane_a, plane_b, plane_c, etc = line:match(patterns.planes .. patterns.etc)

      if plane_a and plane_b and plane_c and etc then
        local face = {}

        local texture

        -- Check if the texture name is enclosed in quotes
        if etc:sub(1, 1) == '"' then
          texture, etc = etc:match(patterns.texture_name_quated .. patterns.etc)
        else
          texture, etc = etc:match(patterns.texture_name .. patterns.etc)
        end

        local offset_x, offset_y, angle, scale_x, scale_y, etc = etc:match(patterns.texture_uv .. patterns.etc)
        local content, surface

        if etc then
          content, surface, value = etc:match(patterns.face_attributes)
          value = value ~= '0' and value or nil
        end

        face.planes = {
          a = parse_vector(plane_a),
          b = parse_vector(plane_b),
          c = parse_vector(plane_c),
        }

        face.texture = {
          name = texture,
          offset_x = tonumber(offset_x),
          offset_y = tonumber(offset_y),
          angle = tonumber(angle),
          scale_x = tonumber(scale_x),
          scale_y = tonumber(scale_y)
        }

        local content_flags = utils.flags_from_integer(tonumber(content) or 0)

        for _, flag in ipairs(content_flags) do
          local property = config.content_flags[flag]
          face[property] = true
        end

        local surface_flags = utils.flags_from_integer(tonumber(surface) or 0)

        for _, flag in ipairs(surface_flags) do
          local property = config.surface_flags[flag]
          face[property] = true
        end

        face.value = tonumber(value)

        table_insert(brush.faces, face)

        do break end
      end
    until true
  end

  if brush then
    table_insert(entity.brushes, brush)
  end

  if entity then
    table_insert(map.entities, entity)
  end

  for _, entity in ipairs(map.entities) do
    entity.brushes = #entity.brushes > 0 and entity.brushes or nil
  end

  return map
end

return parser
