local M = { }

-- Returns the center point of the brushes
---@param brushes table Brushes
---@return table result Center
function M.get_brushes_center(brushes)
    local min = { x = math.huge, y = math.huge, z = math.huge }
    local max = { x = -math.huge, y = -math.huge, z = -math.huge }

    -- go through all brushes and faces to find min and max vertex coordinates
    for _, brush in pairs(brushes) do
        for _, face in ipairs(brush) do
            for _, vertex in ipairs(face.vertices) do
                local v = vertex.position
                min.x = math.min(min.x, v.x)
                min.y = math.min(min.y, v.y)
                min.z = math.min(min.z, v.z)
                max.x = math.max(max.x, v.x)
                max.y = math.max(max.y, v.y)
                max.z = math.max(max.z, v.z)
            end
        end
    end

    -- calculate and return the center point
    return {
        x = (min.x + max.x) / 2,
        y = (min.y + max.y) / 2,
        z = (min.z + max.z) / 2
    }
end


-- Applies the offset to the brushes positions
---@param brushes table Brushes
---@param offset table Offset
function M.apply_offset_to_brushes(brushes, offset)
    for _, brush in pairs(brushes) do
        for _, face in ipairs(brush) do
            for _, vertex in ipairs(face.vertices) do
                vertex.position.x = vertex.position.x - offset.x
                vertex.position.y = vertex.position.y - offset.y
                vertex.position.z = vertex.position.z - offset.z
            end
        end
    end
end

return M