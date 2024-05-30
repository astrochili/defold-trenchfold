--[[
  sculptor.lua
  github.com/astrochili/defold-trenchfold

  Copyright (c) 2024 David Lannan
  MIT license. See LICENSE for details.
--]]

local table_insert = table.insert
local math_abs = math.abs
local math_rad = math.rad
local math_cos = math.cos
local math_sin = math.sin

local utils = require 'trenchfold.utils.utils'
local painter = require 'trenchfold.designers.painter'
local vec = require 'trenchfold.utils.vec'

local sculptor = {}

--
-- Local

local function calculate_texture_uv(vertice, normal, texture, texture_info)
  if not texture_info then
    return nil
  end

  local width = texture_info.width
  local height = texture_info.height

  local dot_up = math_abs(vec.dot(normal, vec.VECTOR_UP))
  local dot_right = math_abs(vec.dot(normal, vec.VECTOR_RIGHT))
  local dot_forward = math_abs(vec.dot(normal, vec.VECTOR_FORWARD))

  local uv = { x = vertice.x, y = vertice.z }

  if dot_up >= dot_right and dot_up >= dot_forward then
    uv = { x = vertice.x, y = -vertice.z }
  elseif dot_right >= dot_up and dot_right >= dot_forward then
    uv = { x = -vertice.z, y = vertice.y }
  elseif dot_forward >= dot_up and dot_forward >= dot_right then
    uv = { x = vertice.x, y = vertice.y }
  end

  local angle = -math_rad(texture.angle)

  uv = {
    x = uv.x * math_cos(angle) - uv.y * math_sin(angle),
    y = uv.x * math_sin(angle) + uv.y * math_cos(angle)
  }

  uv.x = uv.x / width
  uv.y = uv.y / height

  uv.x = uv.x / texture.scale_x
  uv.y = uv.y / texture.scale_y

  uv.x = uv.x + texture.offset_x / width
  uv.y = uv.y - texture.offset_y / height

  return uv
end

-- This is very slow. Need to optimize this.
-- Can reduce to a much simpler lua sort with comparisons on planes.
local function sort_vertices(vertices, mapping, plane)
  -- Get center vert first
  local center_point = { x = 0, y = 0, z = 0 }
  local count = #mapping

  for _, v in ipairs(mapping) do
    center_point = vec.add(center_point, vertices[v])
  end

  center_point = vec.multiply(center_point, 1.0 / count)

  for i = 1, count - 2 do
    local smallest_angle = -1
    local smallest_index = -1

    local v = mapping[i]
    local a = vec.normalize(vec.sub(vertices[v], center_point))
    local plane = vec.points_to_plane(vertices[v], center_point, vec.add(center_point, plane.normal))

    for j = i + 1, count do
      local point_class = vec.classify_point(plane, vertices[mapping[j]])

      if point_class ~= vec.FACE_BACK then
        local b = vec.sub(vertices[mapping[j]], center_point)
        b = vec.normalize(b)

        local angle = vec.dot(a, b)

        if angle > smallest_angle then
          smallest_angle = angle
          smallest_index = j
        end
      end
    end

    if smallest_index == -1 then
      log_error('Degenerate polygon! Idx: ' .. i .. '  Vid: ' .. v)
      return nil
    end

    local t = mapping[smallest_index]
    mapping[smallest_index] = mapping[i + 1]
    mapping[i + 1] = t
  end

  -- Calculate if the plane needs flipping
  local v_plane = vec.calculate_plane(vertices, mapping)

  if not v_plane then
    return mapping
  end

  if vec.dot(v_plane.normal, plane.normal) < 0 then
    local j = count

    for i = 1, j / 2 do
      local v = mapping[i]
      mapping[i] = mapping[j - i]
      mapping[j - i] = v
    end
  end

  return mapping
end

local function intersect(f1, f2, f3)
  local denom = vec.dot(f1.normal, vec.cross(f2.normal, f3.normal))

  if denom == 0 then
    return nil
  end

  local part1 = vec.multiply(vec.cross(f2.normal, f3.normal), -f1.d)
  local part2 = vec.multiply(vec.cross(f3.normal, f1.normal), -f2.d)
  local part3 = vec.multiply(vec.cross(f1.normal, f2.normal), -f3.d)
  local p = vec.add(part1, vec.add(part2, part3))

  local vertices = vec.multiply(p, 1.0 / denom)
  return vertices
end

local function make_polygons(faces)
  local polygons = {}
  local face_count = #faces

  -- For every possible plane intersection, get vertices
  local ct = 0
  local all_vertices = {}
  local plane_mapping = {}

  -- Generate planes
  for i, mf in ipairs(faces) do
    faces[i].planes = vec.plane_to_defold(mf.planes)
    faces[i].planes = vec.points_to_plane(mf.planes.a, mf.planes.b, mf.planes.c)
  end

  for i1 = 1, face_count - 2 do
    local f1 = faces[i1]
    for i2 = i1 + 1, face_count - 1 do
      local f2 = faces[i2]
      for i3 = i2 + 1, face_count do
        local f3 = faces[i3]

        -- If two planes are the same plane then we cant intersect properly!
        if i1 ~= i2 and i2 ~= i3 and i1 ~= i3 then
          local vertices = intersect(f1.planes, f2.planes, f3.planes)

          if vertices then
            local legal = true

            for m = 1, face_count do
              local f = faces[m].planes

              if vec.classify_point(f, vertices) == vec.FACE_FRONT then
                legal = false
                break
              end
            end

            if legal == true then
              table_insert(all_vertices, vertices)
              local vidx = #all_vertices

              -- Collate what verts are associated with what planes
              plane_mapping[i1] = plane_mapping[i1] or {}
              plane_mapping[i2] = plane_mapping[i2] or {}
              plane_mapping[i3] = plane_mapping[i3] or {}

              table_insert(plane_mapping[i1], vidx)
              table_insert(plane_mapping[i2], vidx)
              table_insert(plane_mapping[i3], vidx)
            end

            ct = ct + 1
          end
        end
      end
    end
  end

  -- Process verts so we collate all faces into correct lists
  for i = 1, face_count do
    local texture_name = faces[i].texture.name
    local texture_info = painter.get_texture_info(texture_name)

    polygons[i] = polygons[i] or { vertices = {}, material = texture_name }

    if plane_mapping[i] then
      -- Sort verts in CW order
      local sorted_mapping = sort_vertices(all_vertices, plane_mapping[i], faces[i].planes)

      if sorted_mapping then
        for k, vidx in ipairs(sorted_mapping) do
          polygons[i].vertices[k] = polygons[i].vertices[k] or {}
          polygons[i].vertices[k].position = all_vertices[vidx]
          polygons[i].vertices[k].normal = faces[i].planes.normal
          polygons[i].vertices[k].uv = calculate_texture_uv(
            all_vertices[vidx],
            faces[i].planes.normal,
            faces[i].texture,
            texture_info
          )
        end
      end
    end
  end

  return polygons
end

--
-- Public

function sculptor.make_brushes(entity, textel_size)
  local textel_size = textel_size or 1
  local brushes = {}

  if not entity.brushes then
    return brushes
  end

  local geometry = {}

  for _, brush in pairs(entity.brushes) do
    local polygons = make_polygons(brush.faces)
    local brush_id = string.format('entity%d_brush%d', tostring(entity.index), tostring(brush.index))
    geometry[brush_id] = polygons
  end

  for _, brush in ipairs(entity.brushes) do
    local brush_id = 'entity' .. entity.index .. '_brush' .. brush.index
    local merged_brush = {}

    for index, map_face in ipairs(brush.faces) do
      local face = utils.shallow_copy(map_face) or {}

      face.planes = nil
      face.vertices = {}

      local geometry_brush = geometry[brush_id]
      local geometry_face = geometry_brush[index]

      for _, geometry_vertice in ipairs(geometry_face.vertices) do
        local vertice = {
          normal = utils.shallow_copy(geometry_vertice.normal),
          position = utils.shallow_copy(geometry_vertice.position),
          uv = utils.shallow_copy(geometry_vertice.uv)
        }

        vertice.position.x = vertice.position.x / textel_size
        vertice.position.y = vertice.position.y / textel_size
        vertice.position.z = vertice.position.z / textel_size

        table_insert(face.vertices, vertice)
      end

      local texture_id = geometry_face.material
      local texture_is_empty = texture_id == '__TB_empty'
      local texture_flag = texture_is_empty and 'unused' or texture_id:match('trenchfold/(.*)')

      face.is_unused = texture_flag == 'unused' or nil
      face.is_area = texture_flag == 'area' or nil
      face.is_clip = texture_flag == 'clip' or nil
      face.is_trigger = texture_flag == 'trigger' or nil

      face.texture = painter.get_texture_info(texture_id)

      table_insert(merged_brush, face)
    end

    if #merged_brush > 0 then
      brushes[brush_id] = merged_brush
    end
  end

  return brushes
end

return sculptor
