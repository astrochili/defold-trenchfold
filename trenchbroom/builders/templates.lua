--[[
  templates.lua
  github.com/astrochili/defold-trenchbroom

  Copyright (c) 2022 Roman Silin
  MIT license. See LICENSE for details.
--]]

local templates = { }

templates.collection = [[
name: "_ID_"
_INSTANCES_
scale_along_z: 0
_EMBEDDED_INSTANCES_
]]

templates.instance = [[
instances {
  id: "_ID_"
  prototype: "_PATH_"
  position {
    x: _POSITION_X_
    y: _POSITION_Y_
    z: _POSITION_Z_
  }
  rotation {
    x: _ROTATION_X_
    y: _ROTATION_Y_
    z: _ROTATION_Z_
    w: _ROTATION_W_
  }
  scale3 {
    x: 1.0
    y: 1.0
    z: 1.0
  }
}
]]

templates.embedded_instance = [[
embedded_instances {
  id: "_ID_"
_CHILDREN_
  data: _DATA_
  position {
    x: _POSITION_X_
    y: _POSITION_Y_
    z: _POSITION_Z_
  }
  rotation {
    x: _ROTATION_X_
    y: _ROTATION_Y_
    z: _ROTATION_Z_
    w: _ROTATION_W_
  }
  scale3 {
    x: 1.0
    y: 1.0
    z: 1.0
  }
}
]]

templates.child = '  children: "_ID_"'

templates.component = [[
  "components {\n"
  "  id: \"_ID_\"\n"
  "  component: \"_PATH_\"\n"
  "  position {\n"
  "    x: 0.0\n"
  "    y: 0.0\n"
  "    z: 0.0\n"
  "  }\n"
  "  rotation {\n"
  "    x: 0.0\n"
  "    y: 0.0\n"
  "    z: 0.0\n"
  "    w: 1.0\n"
  "  }\n"
  "}\n"
]]

return templates