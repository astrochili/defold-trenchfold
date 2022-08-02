--[[
  cli.lua
  github.com/astrochili/defold-trenchbroom

  Copyright (c) 2022 Roman Silin
  MIT license. See LICENSE for details.
--]]

local trenchbroom = require 'trenchbroom.trenchbroom'
local config = require 'trenchbroom.config'
local utils = require 'trenchbroom.utils'

local folder_separator = package.config:sub(1, 1)
config.init(folder_separator, arg[1], arg[2])

local folder_to_clean = {
  config.buffer_directory,
  config.mesh_directory,
  config.convexshape_directory,
  config.collisionobject_directory,
  config.script_directory
}

print('\n# Cleaning up')
for _, folder in ipairs(folder_to_clean) do
  utils.clear_folder(folder)
  print('Cleaned up \'' .. folder .. '\'')
end
print('')

trenchbroom.convert()