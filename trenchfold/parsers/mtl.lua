--[[
  mtl.lua
  github.com/astrochili/defold-trenchfold

  Copyright (c) 2022 Roman Silin
  MIT license. See LICENSE for details.
--]]

local utils = require 'trenchfold.utils'

local parser = { }

--
-- Public

function parser.parse(mtl_path)
  local mtl = { }

  local content = utils.read_file(mtl_path)
  local lines = utils.get_lines(content)

  local material

  for _, line in ipairs(lines) do
    local prefix, value = line:match('(%S*) (.*)')

    if prefix == 'newmtl' then
      material = value
    elseif prefix == 'map_Kd' then
      mtl[material] = value:gsub('\\', '/')
    end
  end

  return mtl
end

return parser