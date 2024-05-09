-- -----------------------------------------------------------------------
local brushutil = require 'trenchfold.builders.brush'

local png_infos = {}

-- -----------------------------------------------------------------------
-- Table utilities
-- -----------------------------------------------------------------------

table.split = function(s, delimiter)
    local result = {}
    for match in (s .. delimiter):gmatch("(.-)" .. delimiter) do
        table.insert(result, match)
    end
    return result
end

-- -----------------------------------------------------------------------
--[[
  Author: Julio Manuel Fernandez-Diaz
  Date:   January 12, 2007
  (For Lua 5.1)

  Modified slightly by RiciLake to avoid the unnecessary table traversal in tablecount()

  Formats tables with cycles recursively to any depth.
  The output is returned as a string.
  References to other tables are shown as values.
  Self references are indicated.

  The string returned is "Lua code", which can be procesed
  (in the case in which indent is composed by spaces or "--").
  Userdata and function keys and values are shown as strings,
  which logically are exactly not equivalent to the original code.

  This routine can serve for pretty formating tables with
  proper indentations, apart from printing them:

  print(table.show(t, "t"))   -- a typical use

  Heavily based on "Saving tables with cycles", PIL2, p. 113.

  Arguments:
  t is the table.
  name is the name of the table (optional)
  indent is a first indentation (optional).
  --]]
function table.show(t, name, indent)
    local cart    -- a container
    local autoref -- for self references

    --[[ counts the number of elements in a table
    local function tablecount(t)
      local n = 0
      for _, _ in pairs(t) do n = n+1 end
      return n
    end
    ]]
    -- (RiciLake) returns true if the table is empty
    local function isemptytable(t) return next(t) == nil end

    local function basicSerialize(o)
        local so = tostring(o)
        if type(o) == "function" then
            local info = debug.getinfo(o, "S")
            -- info.name is nil because o is not a calling level
            if info.what == "C" then
                return string.format("%q", so .. ", C function")
            else
                -- the information is defined through lines
                return string.format("%q", so .. ", defined in (" ..
                    info.linedefined .. "-" .. info.lastlinedefined ..
                    ")" .. info.source)
            end
        elseif type(o) == "number" or type(o) == "boolean" then
            return so
        else
            return string.format("%q", so)
        end
    end

    local function addtocart(value, name, indent, saved, field)
        indent = indent or ""
        saved = saved or {}
        field = field or name

        cart = cart .. indent .. field

        if type(value) ~= "table" then
            cart = cart .. " = " .. basicSerialize(value) .. ";\n"
        else
            if saved[value] then
                cart = cart .. " = {}; -- " .. saved[value]
                    .. " (self reference)\n"
                autoref = autoref .. name .. " = " .. saved[value] .. ";\n"
            else
                saved[value] = name
                --if tablecount(value) == 0 then
                if isemptytable(value) then
                    cart = cart .. " = {};\n"
                else
                    cart = cart .. " = {\n"
                    for k, v in pairs(value) do
                        k = basicSerialize(k)
                        local fname = string.format("%s[%s]", name, k)
                        field = string.format("[%s]", k)
                        -- three spaces between levels
                        addtocart(v, fname, indent .. "   ", saved, field)
                    end
                    cart = cart .. indent .. "};\n"
                end
            end
        end
    end

    name = name or "__unnamed__"
    if type(t) ~= "table" then
        return name .. " = " .. basicSerialize(t)
    end
    cart, autoref = "", ""
    addtocart(t, name, indent)
    return cart .. autoref
end

function table.save(tbl, filename)
    local file, err = io.open(filename, "wb")
    if err then return err end

    file:write(table.show(tbl))
    file:close()
end

-- -----------------------------------------------------------------------
-- Binary file reading utilities

local function readByte(fh)
    return string.byte(fh:read(1))
end

-- -----------------------------------------------------------------------
local function readInt(fh)
    local b1 = readByte(fh)
    local b2 = readByte(fh)
    local b3 = readByte(fh)
    local b4 = readByte(fh)
    return b1 * 16777216 + b2 * 65536 + b3 * 256 + b4
end

local function readShort(fh)
  local b1 = readByte(fh)
  local b2 = readByte(fh)
  return b1 * 256 + b2
end

-- -----------------------------------------------------------------------
-- PNG header loader
local function getpngfile(filenamepath)
    -- Try to open first - return nil if unsuccessful
    local fh = io.open(filenamepath, 'rb')
    if (fh == nil) then
        print("[Error] png file not found: " .. filenamepath)
        return nil
    end
    local pnginfo = {}
    local filesig = fh:read(8)
    if (filesig == string.format("%c%c%c%c%c%c%c%c", 0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a)) then
        fh:seek('cur', 8) -- we dont care about length and chunktype (iHDR is always first)
        pnginfo.width = readInt(fh)
        pnginfo.height = readInt(fh)
        pnginfo.depth = readByte(fh)
        pnginfo.type = readByte(fh)
        pnginfo.comp = readByte(fh)
        pnginfo.filter = readByte(fh)
        pnginfo.interlace = readByte(fh)
        fh:close()
        return pnginfo
    end
    print("[Error] Png header unreadable: " .. filenamepath)
    return nil
end

local function getjpgfile(filenamepath)
      -- Try to open first - return nil if unsuccessful
      local fh = io.open(filenamepath, 'rb')
      if (fh == nil) then
          print("[Error] jpg file not found: " .. filenamepath)
          return nil
      end

      local jpginfo = {}
      local data_length = fh:seek('end')
      fh:seek('set')

      if not fh:read(4) == string.format('%c%c%c%c', 0xff, 0xd8, 0xff, 0xe0) then
        -- Not a valid SOI header
        return nil
      end

      local block_length = readShort(fh)

      if not fh:read(5) == string.format('JFIF%c', 0x00) then
        -- Not a valid JFIF string
        return nil
      end

      fh:seek('cur', -7)

      while fh:seek() < data_length do
        fh:seek('cur', block_length)

        local marker = fh:read(2)

        -- Check that we are truly at the start of another block
        if marker:sub(1, 1) ~= string.format('%c', 0xff) then
          break
        end

        -- 0xFFC0 is the "Start of frame" marker which contains the file size
        if marker:sub(2, 2) == string.format('%c', 0xc0) then
          -- The structure of the 0xFFC0 block is quite simple
          -- [0xFFC0][ushort length][uchar precision][ushort x][ushort y]
          fh:seek('cur', 3)

          jpginfo.height = readShort(fh)
          jpginfo.width = readShort(fh)

          return jpginfo
        else
          block_length = readShort(fh)
          fh:seek('cur', -2)
        end
      end
end


-- -----------------------------------------------------------------------
-- Check paths for images (collect sizes as well) - only png supported
local function getimagepath(mtlpath, entpaths, texname)
    local imagetype = ".png"
    -- Check master first
    local testpath = mtlpath .. tostring(texname) .. imagetype
    local pnginfo = getpngfile("assets/" .. testpath)

    if (pnginfo) then
        pnginfo.filename = testpath
        return pnginfo
    else
      imagetype = ".jpg"
      testpath = mtlpath .. tostring(texname) .. imagetype
      local jpginfo = getjpgfile("assets/" .. testpath)

      if jpginfo then
        jpginfo.filename = testpath
        return jpginfo
      end
    end

    -- If we get here then the main path didnt find the file
    if (entpaths) then
        for k, v in pairs(entpaths) do
            local testpath = v .. "/" .. tostring(texname) .. imagetype
            local pnginfo = getpngfile("assets/" .. testpath)
            if (pnginfo) then
                pnginfo.filename = testpath
                return pnginfo
            end
        end
    end

    return nil
end

-- -----------------------------------------------------------------------
-- Very simple regen mtl from map references
local function generatemtl(map)
    local mtlpath = "textures/"
    local mtl = {}

    -- iterate the map strucure down to the faces and store texture info
    local entities = map.entities

    -- Entities have brushes, brushes have faces, faces have textures
    for ei, ent in pairs(entities) do
        local entpaths = nil
        if (ent._tb_textures) then
            entpaths = table.split(ent._tb_textures, ";")
        end

        if (ent.brushes) then
            for bi, brush in pairs(ent.brushes) do
                for fi, face in pairs(brush.faces) do
                    local tex = face.texture
                    if tex and not tex.name:match('flags/(.*)') then
                        if png_infos[tex.name] == nil then
                            -- Find resource (texture) and then append approritate path
                            local pnginfo = getimagepath(mtlpath, entpaths, tex.name)
                            if (pnginfo) then
                                mtl[tex.name] = pnginfo.filename
                                png_infos[tex.name] = pnginfo
                            else
                                mtl[tex.name] = "invalid"
                            end
                        end
                    end
                end
            end
        end
    end
    return mtl
end

-- -----------------------------------------------------------------------
local function generateobj(map)
    local obj = {}

    -- iterate the map strucure down to the faces and store texture info
    local entities = map.entities

    -- Entities have brushes, brushes have faces, faces have textures
    for ei, ent in pairs(entities) do
        if (ent.brushes) then
            for bi, brush in pairs(ent.brushes) do
                --local vertices = brushutil.CreateBrushFaces(ei, bi, brush.faces)
                local vertices = brushutil.getvertices(ei, bi, brush.faces, png_infos)
                if (vertices) then
                    local objname = string.format("entity%d_brush%d", tostring(ei - 1), tostring(bi - 1))
                    obj[objname] = vertices
                end
            end
        end
    end

    return obj
end

-- -----------------------------------------------------------------------
local function getmtlobj(map)

    png_infos = {}

    -- table.save(map, "test-map.lua")

    local mtl = generatemtl(map)
    -- table.save(mtl, "test-mtl.lua")

    local obj = generateobj(map)
    -- table.save(obj, "test-obj.lua")

    return mtl, obj
end

-- -----------------------------------------------------------------------
-- By default all methods are local, expose what we want here.
return {
    getmtlobj = getmtlobj,
}

-- -----------------------------------------------------------------------