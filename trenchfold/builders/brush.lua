local tinsert = table.insert

local Vec = require 'trenchfold.builders.vec'
local Plane = require 'trenchfold.builders.plane'

local MAXEDGES 		= 32

-- -----------------------------------------------------------------------

local function CalcTexCoords( v, n, tex, png_info )

	local width = 64
	local height = 64
	if(png_info) then 
		width = png_info.width 
		height = png_info.height
	end 

    local du = math.abs(Vec.dot(n, Vec.UP_VECTOR))
    local dr = math.abs(Vec.dot(n, Vec.RIGHT_VECTOR))
    local df = math.abs(Vec.dot(n, Vec.FORWARD_VECTOR))

	local uv_out = { x=v.x, y=v.z }
    if (du >= dr and du >= df) then 
        uv_out = { x=v.x, y=-v.z}
    elseif (dr >= du and dr >= df) then 
        uv_out = { x=-v.z, y=v.y }
    elseif (df >= du and df >= dr) then
        uv_out = { x=v.x, y=v.y }
	end

    local angle = -math.rad(tex.angle)
    uv_out = {
		x = uv_out.x * math.cos(angle) - uv_out.y * math.sin(angle),
    	y = uv_out.x * math.sin(angle) + uv_out.y * math.cos(angle)
	}

	uv_out.x = uv_out.x / width
    uv_out.y = uv_out.y / height

    uv_out.x = uv_out.x / tex.scale_x
    uv_out.y = uv_out.y / tex.scale_y

    uv_out.x = uv_out.x + tex.offset_x /  width
    uv_out.y = uv_out.y - tex.offset_y / height
	return uv_out
end

-- -----------------------------------------------------------------------
-- This is very slow. Need to optimize this. 
--   Can reduce to a much simpler lua sort with comparisons on planes.
local function sortverts( verts, mapping, plane )
	-- get center vert first
	local center_pt = { x=0, y=0, z=0 } 
	local count = #mapping
	for k,v in ipairs(mapping) do
		center_pt = Vec.addvec(center_pt, verts[v])
	end 
	center_pt = Vec.multvec(center_pt, 1.0/count)

	for i = 1, count-2 do
		local v = mapping[i]
		local smallestangle = -1
		local smallest = -1
		local a = Vec.normalize(Vec.subvec( verts[v], center_pt ))
		local p = Plane.PointsToPlane( verts[v], center_pt, Vec.addvec(center_pt, plane.normal))
		for j = i+1, count do 
			if( Plane.ClassifyPoint(p, verts[mapping[j]] ) ~= Plane.FACE_BACK ) then 
				local b = Vec.subvec(verts[mapping[j]], center_pt)
				b = Vec.normalize(b)
				local angle = Vec.dot(a, b)
				if(angle > smallestangle) then 
					smallestangle = angle 
					smallest = j 
				end
			end
		end

		if(smallest == -1) then 
			print("[ERROR] Degenerate polygon! Idx:"..i.."  Vid:"..v)
			return nil 
		end 

		local t = mapping[smallest]
		mapping[smallest] = mapping[i + 1]
		mapping[i+1] = t
	end

	-- Calc if plane needs flipping
	local vplane = Plane.CalculatePlane( verts, mapping )
	if(vplane) then 		
		if ( Vec.dot( vplane.normal, plane.normal ) < 0 ) then 
			local j = count
			for i = 1, j / 2 do
				local v			= mapping[ i ]
				mapping[ i ]	= mapping[ j - i ]
				mapping[ j - i ]	= v
			end
		end
	end

	return mapping
end

-- -----------------------------------------------------------------------
local function intersect( f1, f2, f3 )
	local denom = Vec.dot(f1.normal, Vec.cross(f2.normal, f3.normal))
	if(denom == 0) then return nil end 
	local part1 = Vec.multvec( Vec.cross(f2.normal, f3.normal), -f1.d)
	local part2 = Vec.multvec( Vec.cross(f3.normal, f1.normal), -f2.d)
	local part3 = Vec.multvec( Vec.cross(f1.normal, f2.normal), -f3.d)
	local p = Vec.addvec( part1, Vec.addvec( part2, part3 ) )
	return Vec.multvec( p, 1.0/denom)
end

-- -----------------------------------------------------------------------
local function GetVertices(entity_id, brush_id, faces, png_infos)

	local map_scale = 0.03125  -- 1/32 convert to metres
	local polys = {}
	
	local facecount = #faces
	-- For every possible plane intersection, get vertices
	local ct = 0
	local all_verts = {}
	local plane_mapping = {}

	-- Generate planes 
	for i,mf in ipairs(faces) do
		faces[i].planes = Plane.ConvertToDefold(mf.planes)
		faces[i].planes = Plane.PointsToPlane(mf.planes.a, mf.planes.b, mf.planes.c)
	end	
	
	for i1 = 1,facecount-2 do
		local f1 = faces[i1]
		for i2 = i1+1, facecount-1 do
			local f2 = faces[i2]
			for i3 = i2+1, facecount do
				local f3 = faces[i3]

				-- If two planes are the same plane then we cant intersect properly!
				if( i1 ~= i2 and i2 ~= i3 and i1 ~= i3 ) then 
					
					local vert = intersect(f1.planes, f2.planes, f3.planes)
					if vert then

						local legal = true 
						for m=1, facecount do 
							local f = faces[m].planes
							if (Plane.ClassifyPoint(f, vert) == Plane.FACE_FRONT) then 
								legal = false
								break
							end
						end
						
						if(legal == true) then 
							tinsert(all_verts, vert)
							local vidx = #all_verts

							-- Collate what verts are associated with what planes
							plane_mapping[i1] = plane_mapping[i1] or {}
							plane_mapping[i2] = plane_mapping[i2] or {}
							plane_mapping[i3] = plane_mapping[i3] or {}
							tinsert(plane_mapping[i1], vidx)
							tinsert(plane_mapping[i2], vidx)
							tinsert(plane_mapping[i3], vidx)
						end
						ct = ct + 1
					end
				end
				-- print("i1: "..i1.."  i2: "..i2.."  i3: "..i3)
			end 
		end
	end 
	--print("Faceount: "..facecount.."   Total: "..ct.."    AllVerts: "..#all_verts.."  IllegalVerts: "..(ct-#all_verts))

	-- Process verts so we collate all faces into correct lists 
	for i=1, facecount do 
		local texname = faces[i].texture.name
		local png_info = png_infos[texname]
		polys[i] = polys[i] or { vertices = {}, position = {}, material = texname }
		if(plane_mapping[i]) then 
			-- Sort verts in CW order. 
			local sorted_mapping = sortverts(all_verts, plane_mapping[i], faces[i].planes)
			if(sorted_mapping) then 
				for k, vidx in ipairs(sorted_mapping) do
					polys[i].vertices[k] = polys[i].vertices[k] or {}
					polys[i].vertices[k].position =  all_verts[vidx]
					polys[i].vertices[k].normal = faces[i].planes.normal
					polys[i].vertices[k].uv = CalcTexCoords( all_verts[vidx], faces[i].planes.normal, faces[i].texture, png_info )
				end 
			end
		end
	end
			
	return polys
end

-- -----------------------------------------------------------------------	
return {
	getvertices 		= GetVertices,
}
-- -----------------------------------------------------------------------