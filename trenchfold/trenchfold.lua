--[[
  trenchbroom.lua
  github.com/astrochili/defold-trenchfold

  Copyright (c) 2022 Roman Silin
  MIT license. See LICENSE for details.
--]]

local utils = require 'trenchfold.utils.utils'
local config = require 'trenchfold.utils.config'

local map_parser = require 'trenchfold.parsers.map'
local level_designer = require 'trenchfold.designers.level'
local collection_builder = require 'trenchfold.builders.collection'
local defold_builder = require 'trenchfold.builders.defold'

local trenchfold = { }
local errors = {}

--
-- Global

function log_error(error)
  table.insert(errors, error)
end

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

  print('\n# Building')

  print('Putting all the data together')
  local level = level_designer.design(map)

  print('Building the collection structure')
  local instances = collection_builder.build(level)

  print('Creating the contents of the files')
  local files = defold_builder.build(instances)

  print('\n# Saving the files')
  for _, file in ipairs(files) do
    print('[' .. file.path .. ']')
    utils.save_file(file.content, file.path)
  end

  if #errors > 0 then
    print('\n# Finished with errors:')

    for _, error in ipairs(errors) do
      print('- ' .. error)
    end
  else
    print('\n# Finished!')
  end
end

return trenchfold
