--[[
  trenchbroom.lua
  github.com/astrochili/defold-trenchfold

  Copyright (c) 2022 Roman Silin
  MIT license. See LICENSE for details.
--]]

local utils = require 'trenchfold.utils'
local config = require 'trenchfold.config'

local map_parser = require 'trenchfold.parsers.map'
local obj_parser = require 'trenchfold.parsers.obj'
local mtl_parser = require 'trenchfold.parsers.mtl'

local direct_parser = require 'trenchfold.builders.directmap'

local level_builder = require 'trenchfold.builders.level'
local collection_builder = require 'trenchfold.builders.collection'
local defold_builder = require 'trenchfold.builders.defold'

local trenchfold = { }

--
-- Local

function trenchfold.init_config(folder_separator, map_directory, map_name)
  return config
end

function trenchfold.convert()
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

function trenchfold.direct_convert()
  print('# TrenchBroom to Defold')
  print('Starting with map \'' .. config.map_directory .. '/' .. config.map_name .. '.map\'')

  print('\n# Parsing')
  local file_path = config.full_path(config.map_directory, config.map_name)

  local map_path = file_path .. '.map'
  print('Parsing \'' .. map_path .. '\'')
  local map = map_parser.parse(map_path)

  print('Building MTL and Obj \'' .. map_path .. '\'')
  local mtl, obj = direct_parser.getmtlobj(map)

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

return trenchfold
