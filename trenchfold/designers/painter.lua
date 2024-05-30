--[[
  textures.lua
  github.com/astrochili/defold-trenchfold

  Copyright (c) 2024 David Lannan
  MIT license. See LICENSE for details.
--]]

local utils = require 'trenchfold.utils.utils'

local painter = {}
local storage = {}

--
-- Local

local function make_not_found(texture_id)
  return {
    id = texture_id,
    type = 'png',
    path = '/trenchfold/assets/textures/not_found.png',
    width = 1,
    height = 1
  }
end

local function read_byte(file)
  return string.byte(file:read(1))
end

local function read_int(file)
  local b1 = read_byte(file)
  local b2 = read_byte(file)
  local b3 = read_byte(file)
  local b4 = read_byte(file)
  return b1 * 16777216 + b2 * 65536 + b3 * 256 + b4
end

local function read_short(file)
  local b1 = read_byte(file)
  local b2 = read_byte(file)
  return b1 * 256 + b2
end

local function fetch_png_info(file)
  local png_info = {}
  local file_sig = file:read(8)

  if file_sig ~= string.format('%c%c%c%c%c%c%c%c', 0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a) then
    log_error('Not valid PNG header: ' .. file_path)
    return nil
  end

  -- Skip iHDR
  file:seek('cur', 8)

  png_info.width = read_int(file)
  png_info.height = read_int(file)

  file:close()

  return png_info
end

local function fetch_jpg_info(file)
  local jpg_info = {}
  local data_length = file:seek('end')

  file:seek('set')

  if not file:read(4) == string.format('%c%c%c%c', 0xff, 0xd8, 0xff, 0xe0) then
    log_error('Not a valid SOI header: ' .. file_path)
    return nil
  end

  local block_length = read_short(file)

  if not file:read(5) == string.format('JFIF%c', 0x00) then
    log_error('Not a valid JFIF string: ' .. file_path)
    return nil
  end

  -- Seek back
  file:seek('cur', -7)

  while file:seek() < data_length do
    file:seek('cur', block_length)

    local marker = file:read(2)

    -- Check that we are truly at the start of another block
    if marker:sub(1, 1) ~= string.format('%c', 0xff) then
      break
    end

    -- 0xFFC0 is the 'Start of frame' marker which contains the file size
    if marker:sub(2, 2) == string.format('%c', 0xc0) then
      -- The structure of the 0xFFC0 block is quite simple
      -- [0xFFC0][ushort length][uchar precision][ushort x][ushort y]
      file:seek('cur', 3)

      jpg_info.height = read_short(file)
      jpg_info.width = read_short(file)

      return jpg_info
    else
      block_length = read_short(file)
      file:seek('cur', -2)
    end
  end

  log_error('Not found the image size: ' .. file_path)
  return nil
end

local function fetch_image_info(texture_id)
  local image_fetchers = {
    png = fetch_png_info,
    jpg = fetch_jpg_info,
    jpeg = fetch_jpg_info
  }

  for image_type, image_fetcher in pairs(image_fetchers) do
    local image_path = texture_id .. '.' .. image_type

    if utils.is_file_exists(image_path) then
      local file = io.open(image_path, 'rb')

      if not file then
        log_error('File exists but can\'t open: ' .. image_path)
        return make_not_found(texture_id)
      end

      local image_info = image_fetcher(file)
      image_info.type = image_type

      return image_info or make_not_found(texture_id)
    end
  end

  log_error('The texture not found: ' .. texture_id)
  return make_not_found(texture_id)
end

--
-- Public

function painter.get_texture_info(texture_id)
  assert(texture_id)
  local texture = storage[texture_id]

  if not texture then
    local texture_is_empty = texture_id == '__TB_empty'
    local texture_is_flag = texture_id:match('trenchfold/(.*)')

    if texture_is_empty or texture_is_flag then
      return nil
    end

    texture = fetch_image_info(texture_id)
    texture.id = texture.id or texture_id
    texture.path = texture.path or (texture_id .. '.' .. texture.type)
    storage[texture_id] = texture
  end

  return texture
end

return painter
