--[[
  trenchbroom.lua
  github.com/astrochili/defold-trenchbroom

  Copyright (c) 2022 Roman Silin
  MIT license. See LICENSE for details.
--]]

local utils = require 'trenchbroom.utils'
local config = require 'trenchbroom.config'

local map_parser = require 'trenchbroom.parsers.map'
local obj_parser = require 'trenchbroom.parsers.obj'
local mtl_parser = require 'trenchbroom.parsers.mtl'

local level_builder = require 'trenchbroom.builders.level'
local collection_builder = require 'trenchbroom.builders.collection'
local defold_builder = require 'trenchbroom.builders.defold'

local trenchbroom = { }

--
-- Local

function trenchbroom.init_config(folder_separator, map_directory, map_name)
  return config
end

function trenchbroom.convert()
  print('# TrenchBroom to Defold')
  print('Starting with map \'' .. config.map_directory .. '/' .. config.map_name .. '.map\'')

  print('\n# Parsing')
  local file_path = config.full_path(config.map_directory, config.map_name)

  local map_path = file_path .. '.map'
  print('Parsing \'' .. map_path .. '\'')
  local map = map_parser.parse(map_path)

  local obj_path = file_path .. '.obj'
  print('Parsing \'' .. obj_path .. '\'')
  local obj = obj_parser.parse(obj_path)

  local mtl_path = file_path .. '.mtl'
  print('Parsing \'' .. mtl_path .. '\'')
  local mtl = mtl_parser.parse(mtl_path)

  print('\n# Building')

  print('Putting all the data together')
  local level = level_builder.build(map, obj, mtl)

  print('Building the collection model')
  local instances = collection_builder.build(level)

  print('Creating the contents of the files')
  local files = defold_builder.build(instances)
  
  print('\n# Saving the files')
  for _, file in ipairs(files) do
    print('[' .. file.path .. ']')
    utils.save_file(file.content, file.path)
  end

  print('\n# Finished!')
end

return trenchbroom
