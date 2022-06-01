--[[
  obj.lua
  github.com/astrochili/defold-trenchbroom

  Copyright (c) 2022 Roman Silin
  MIT license. See LICENSE for details.
--]]

local utils = require 'trenchbroom.utils'

local parser = { }

--
-- Local

local function parse_vector2(source)
  local x, y = source:match('(.*) (.*)')
  return {
    x = tonumber(x),
    y = tonumber(y)
  }
end

local function parse_vector3(source)
  local x, y, z = source:match('(.*) (.*) (.*)')
  return {
    x = tonumber(x),
    y = tonumber(y),
    z = tonumber(z)
  }
end

local function parse_face(source, obj)
  local face = { vertices = { } }
  
  for i, j, k in source:gmatch('([%d]*)/([%d]*)/([%d]*)') do
    local vertice = {
      position = obj.positions[tonumber(i)],
      normal = obj.normals[tonumber(k)],
      uv = obj.uvs[tonumber(j)]
    }

    table.insert(face.vertices, vertice)
  end

  return face
end

local obj_builders = {
  v = function(obj, raw)
    local value = parse_vector3(raw)
    table.insert(obj.positions, value)
  end,

  vn = function(obj, raw) 
    local value = parse_vector3(raw)
    table.insert(obj.normals, value)
  end,

  vt = function(obj, raw)
    local value = parse_vector2(raw)
    table.insert(obj.uvs, value)
  end,

  o = function(obj, raw)
    local brush = { }
    obj[raw] = brush
    obj.brush = brush
  end,
  
  usemtl = function(obj, raw)
    obj.material = raw
   end,
  
  f = function(obj, raw) 
    local brush = obj.brush
    local face = parse_face(raw, obj)

    face.material = obj.material
    table.insert(brush, face)
   end
}

--
-- Public

function parser.parse(obj_path)
  local obj = { }

  obj.positions = { }
  obj.normals = { }
  obj.uvs = { }

  local content = utils.read_file(obj_path)
  local lines = utils.get_lines(content)

  for _, line in ipairs(lines) do
    local prefix = line:match('([.%S]*)%s')
    local builder = obj_builders[prefix]

    if builder ~= nil then 
      local raw = line:match(prefix .. '%s(.*)')
      builder(obj, raw)
    end
  end

  obj.positions = nil
  obj.normals = nil
  obj.uvs = nil
  
  obj.material = nil
  obj.brush = nil

  return obj
end

return parser