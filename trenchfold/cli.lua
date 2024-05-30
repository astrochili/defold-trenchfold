--[[
  cli.lua
  github.com/astrochili/defold-trenchfold

  Copyright (c) 2022 Roman Silin
  MIT license. See LICENSE for details.
--]]

assert(arg[1], 'A relative path to the map folder as the 1th argument is required.')
assert(arg[2], 'A map name as the 2th argument is required.')

local trenchfold = require 'trenchfold.trenchfold'
local config = require 'trenchfold.utils.config'
local utils = require 'trenchfold.utils.utils'

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

trenchfold.convert()
