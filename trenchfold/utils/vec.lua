--[[
  vec.lua
  github.com/astrochili/defold-trenchfold

  Copyright (c) 2024 David Lannan, ReanimatorXP
  MIT license. See LICENSE for details.
--]]

local math_sqrt = math.sqrt
local math_abs = math.abs
local math_min = math.min
local math_max = math.max
local math_huge = math.huge

local vec = {}

--
-- Local

local ZERO_EPSILON = 0.1

local FACE_FRONT = 1
local FACE_BACK = 2
local FACE_ONPLANE = 3

--
-- Public

vec.FACE_FRONT = FACE_FRONT
vec.FACE_BACK = FACE_BACK
vec.FACE_ONPLANE = FACE_ONPLANE

vec.VECTOR_ZERO = { x = 0, y = 0, z = 0 }
vec.VECTOR_UP = { x = 0, y = 1, z = 0 }
vec.VECTOR_RIGHT = { x = 1, y = 0, z = 0 }
vec.VECTOR_FORWARD = { x = 0, y = 0, z = 1 }

function vec.dot(v1, v2)
  return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z
end

function vec.cross(v1, v2)
  return {
    x = v1.y * v2.z - v1.z * v2.y,
    y = v1.z * v2.x - v1.x * v2.z,
    z = v1.x * v2.y - v1.y * v2.x,
  }
end

function vec.length(v)
  return math_sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
end

function vec.normalize(v)
  local d = 1.0 / math_sqrt(v.x * v.x + v.y * v.y + v.z * v.z)

  return {
    x = v.x * d,
    y = v.y * d,
    z = v.z * d
  }
end

function vec.multiply(v, s)
  return {
    x = v.x * s,
    y = v.y * s,
    z = v.z * s
  }
end

function vec.add(v1, v2)
  return {
    x = v1.x + v2.x,
    y = v1.y + v2.y,
    z = v1.z + v2.z
  }
end

function vec.sub(v1, v2)
  return {
    x = v1.x - v2.x,
    y = v1.y - v2.y,
    z = v1.z - v2.z
  }
end

function vec.generate_plane(plane)
  if plane.normal then
    return plane
  end

  plane.p1 = {
    x = plane.a.x,
    y = plane.a.y,
    z = plane.a.z
  }

  plane.p2 = {
    x = plane.b.x,
    y = plane.b.y,
    z = plane.b.z
  }

  plane.p3 = {
    x = plane.c.x,
    y = plane.c.y,
    z = plane.c.z
  }

  local line1 = {
    x = plane.p2.x - plane.p3.x,
    y = plane.p2.y - plane.p3.y,
    z = plane.p2.z - plane.p3.z
  }

  local line2 = {
    x = plane.p1.x - plane.p2.x,
    y = plane.p1.y - plane.p2.y,
    z = plane.p1.z - plane.p2.z
  }

  local normal_direction = vec.cross(line1, line2)
  plane.normal = vec.normalize(normal_direction)
  plane.d = -vec.dot(plane.normal, plane.p1)

  return plane
end

function vec.plane_to_defold(plane)
  plane.a = {
    x = plane.a.x,
    y = plane.a.z,
    z = -plane.a.y
  }

  plane.b = {
    x = plane.b.x,
    y = plane.b.z,
    z = -plane.b.y
  }

  plane.c = {
    x = plane.c.x,
    y = plane.c.z,
    z = -plane.c.y
  }

  return plane
end

function vec.points_to_plane(a, b, c)
  local normal = vec.cross(vec.sub(b, c), vec.sub(a, b))
  normal = vec.normalize(normal)

  return {
    normal = normal,
    d = -vec.dot(normal, a)
  }
end

function vec.distance_to_plane(plane, point)
  return vec.dot(plane.normal, point) + plane.d
end

function vec.classify_point(plane, point)
  local distance = vec.distance_to_plane(plane, point)

  if distance > ZERO_EPSILON then
    return FACE_FRONT, distance
  elseif distance < -ZERO_EPSILON then
    return FACE_BACK, distance
  end

  return FACE_ONPLANE, distance
end

function vec.calculate_plane(verts, mapping)
  local count = #mapping

  if count < 3 then
    log_error('Polygon has less than 3 vertices!')
    return nil
  end

  local plane = {
    normal = { x = 0, y = 0, z = 0 }
  }

  local center_of_mass = { x = 0, y = 0, z = 0 }

  for i = 1, count do
    local j = i + 1

    if j > count then
      j = 1
    end

    local mi = mapping[i]
    local mj = mapping[j]

    plane.normal.x = plane.normal.x + (verts[mi].y - verts[mj].y) * (verts[mi].z + verts[mj].z)
    plane.normal.y = plane.normal.y + (verts[mi].z - verts[mj].z) * (verts[mi].x + verts[mj].x)
    plane.normal.z = plane.normal.z + (verts[mi].x - verts[mj].x) * (verts[mi].y + verts[mj].y)

    center_of_mass.x = center_of_mass.x + verts[mi].x
    center_of_mass.y = center_of_mass.y + verts[mi].y
    center_of_mass.z = center_of_mass.z + verts[mi].z
  end

  local near_zero_x = (math_abs(plane.normal.x) < ZERO_EPSILON)
  local near_zero_y = (math_abs(plane.normal.y) < ZERO_EPSILON)
  local near_zero_z = (math_abs(plane.normal.z) < ZERO_EPSILON)

  if near_zero_x and near_zero_y and near_zero_z then
    return nil
  end

  local magnitude = vec.length(plane.normal)
  if magnitude < ZERO_EPSILON then
    return nil
  end

  plane.normal.x = plane.normal.x / magnitude
  plane.normal.y = plane.normal.y / magnitude
  plane.normal.z = plane.normal.z / magnitude

  center_of_mass.x = center_of_mass.x / count
  center_of_mass.y = center_of_mass.y / count
  center_of_mass.z = center_of_mass.z / count

  plane.d = -vec.dot(center_of_mass, plane.normal)

  return plane
end

---Returns the center point of the brushes
---@param brushes [table]
---@return { x:number, y:number, z:number } center
function vec.get_brushes_center(brushes)
  local min = { x = math_huge, y = math_huge, z = math_huge }
  local max = { x = -math_huge, y = -math_huge, z = -math_huge }

  -- Go through all brushes and faces to find min and max vertice coordinates
  for _, brush in pairs(brushes) do
    for _, face in ipairs(brush) do
      for _, vertice in ipairs(face.vertices) do
        local position = vertice.position

        min.x = math_min(min.x, position.x)
        min.y = math_min(min.y, position.y)
        min.z = math_min(min.z, position.z)
        max.x = math_max(max.x, position.x)
        max.y = math_max(max.y, position.y)
        max.z = math_max(max.z, position.z)
      end
    end
  end

  -- Calculate and return the center point
  return {
    x = (min.x + max.x) / 2,
    y = (min.y + max.y) / 2,
    z = (min.z + max.z) / 2,
  }
end

---Applies the offset to the brushes positions
---@param brushes [table]
---@param offset { x:number, y:number, z:number }
function vec.apply_offset_to_brushes(brushes, offset)
  for _, brush in pairs(brushes) do
    for _, face in ipairs(brush) do
      for _, vertex in ipairs(face.vertices) do
        vertex.position.x = vertex.position.x - offset.x
        vertex.position.y = vertex.position.y - offset.y
        vertex.position.z = vertex.position.z - offset.z
      end
    end
  end
end

return vec
