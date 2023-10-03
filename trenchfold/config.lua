--[[
  config.lua
  github.com/astrochili/defold-trenchfold

  Copyright (c) 2022 Roman Silin
  MIT license. See LICENSE for details.
--]]

local config = { }

--
-- Flags

config.content_flags = {
  [1] = 'is_ghost',
  [2] = 'is_separated'
}

config.surface_flags = { }

config.physics_flags = {
  [1] = 'is_rotation_locked',
  [2] = 'is_bullet'
}

--
-- Init

function config.init(folder_separator, map_directory, map_name)

  -- Arguments

  config.folder_separator = folder_separator
  config.map_directory = map_directory
  config.map_name = map_name

  -- Paths

  config.assets_directory = 'assets'
  config.buffer_directory = config.map_directory .. '/buffer'
  config.mesh_directory = config.map_directory .. '/mesh'
  config.collisionobject_directory = config.map_directory .. '/collisionobject'
  config.convexshape_directory = config.map_directory .. '/convexshape'
  config.script_directory = config.map_directory .. '/script'
end

--
-- Paths

function config.full_path(directory, file_path)
  local full_path = directory .. '/' .. file_path
  full_path = full_path:gsub('/', config.folder_separator)
  return full_path
end

function config.resource_path(directory_or_file_path, file_path)
  local path = directory_or_file_path

  if file_path then
    path = path .. '/' .. file_path
  end

  local resource_path = '/' .. path:gsub('\\', '/')
  return resource_path
end

return config