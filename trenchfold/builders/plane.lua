local Vec = require 'trenchfold.builders.vec'

-- -----------------------------------------------------------------------

local ZERO_EPSILON  = 0.1
local MAXEDGES 		= 32

local FACE_FRONT 	= 1
local FACE_BACK 	= 2
local FACE_ONPLANE 	= 3

-- -----------------------------------------------------------------------
local function GeneratePlane(plane) 

	-- Check if already calc
	if(plane.normal) then return plane end 
	plane.p1 = { x = plane.a.x, y = plane.a.y, z = plane.a.z }
	plane.p2 = { x = plane.b.x, y = plane.b.y, z = plane.b.z }
	plane.p3 = { x = plane.c.x, y = plane.c.y, z = plane.c.z }

	local line1 = { x = plane.p2.x - plane.p3.x, y = plane.p2.y - plane.p3.y, z = plane.p2.z - plane.p3.z }
	local line2 = { x = plane.p1.x - plane.p2.x, y = plane.p1.y - plane.p2.y, z = plane.p1.z - plane.p2.z }
	plane.normaldir = Vec.cross( line1, line2 )
	plane.normal = Vec.normalize(plane.normaldir)
	plane.d = -Vec.dot(plane.normal, plane.p1)
	return plane
end

-- -----------------------------------------------------------------------

local function ConvertToDefold(plane)

	plane.a = { x = plane.a.x, y = plane.a.z, z = -plane.a.y }
	plane.b = { x = plane.b.x, y = plane.b.z, z = -plane.b.y }
	plane.c = { x = plane.c.x, y = plane.c.z, z = -plane.c.y }
    return plane
end

-- -----------------------------------------------------------------------

local function PointsToPlane ( a, b, c )

	local n = Vec.cross( Vec.subvec( b, c ), Vec.subvec( a, b ) )
	n = Vec.normalize ( n )
	local d = -Vec.dot ( n, a )
	return { normal = n, d = d }
end

-- -----------------------------------------------------------------------

local function DistanceToPlane ( plane, point )
	return Vec.dot( plane.normal, point ) + plane.d
end

-- -----------------------------------------------------------------------

local function ClassifyPoint ( plane, point )

	local Distance = DistanceToPlane( plane, point )
	if ( Distance > ZERO_EPSILON ) then 
		return FACE_FRONT, Distance
	elseif ( Distance < -ZERO_EPSILON ) then
		return FACE_BACK, Distance
	end
	return FACE_ONPLANE, Distance
end

-- -----------------------------------------------------------------------

local function CalculatePlane ( verts, mapping )

	local count = #mapping
	if ( count < 3 ) then 
		print( "[ERROR] Polygon has less than 3 vertices!")
		return nil
	end

	local plane = {}
	plane.normal = { x=0.0, y=0.0, z=0.0 }
	local centerOfMass = { x=0.0, y=0.0, z=0.0 }

	for i = 1, count do
		local j = i + 1

		if ( j > count ) then  j = 1 end
		local mi = mapping[i]
		local mj = mapping[j]
		
		plane.normal.x = plane.normal.x + ( verts[ mi ].y - verts[ mj ].y ) * ( verts[ mi ].z + verts[ mj ].z )
		plane.normal.y = plane.normal.y + ( verts[ mi ].z - verts[ mj ].z ) * ( verts[ mi ].x + verts[ mj ].x )
		plane.normal.z = plane.normal.z + ( verts[ mi ].x - verts[ mj ].x ) * ( verts[ mi ].y + verts[ mj ].y )

		centerOfMass.x = centerOfMass.x + verts[ mi ].x
		centerOfMass.y = centerOfMass.y + verts[ mi ].y
		centerOfMass.z = centerOfMass.z + verts[ mi ].z
	end

	if ( ( math.abs ( plane.normal.x ) < ZERO_EPSILON ) and ( math.abs ( plane.normal.y ) < ZERO_EPSILON ) and
		( math.abs ( plane.normal.z ) < ZERO_EPSILON ) ) then 
		return nil
	end

	local magnitude = Vec.length(plane.normal)
	if ( magnitude < ZERO_EPSILON ) then
		return nil
	end

	plane.normal.x = plane.normal.x / magnitude
	plane.normal.y = plane.normal.y / magnitude
	plane.normal.z = plane.normal.z / magnitude

	centerOfMass.x = centerOfMass.x / count
	centerOfMass.y = centerOfMass.y / count
	centerOfMass.z = centerOfMass.z / count

	plane.d = -Vec.dot ( centerOfMass, plane.normal )
	return plane
end

-- -----------------------------------------------------------------------

return {
    ZERO_EPSILON    = ZERO_EPSILON,
    MAXEDGES 		= MAXEDGES,
    
    FACE_FRONT 	    = FACE_FRONT,
    FACE_BACK 	    = FACE_BACK,
    FACE_ONPLANE 	= FACE_ONPLANE,

    GeneratePlane = GeneratePlane,
    PointsToPlane = PointsToPlane,
    DistanceToPlane = DistanceToPlane,
    ClassifyPoint = ClassifyPoint,
    CalculatePlane = CalculatePlane,
    ConvertToDefold = ConvertToDefold,
}

-- -----------------------------------------------------------------------