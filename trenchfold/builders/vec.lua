local origin = {x=0,y=0,z=0}
local UP_VECTOR = {x=0, y=1, z=0}
local RIGHT_VECTOR = {x=1, y=0, z=0}
local FORWARD_VECTOR = {x=0, y=0, z=1}

local function dot( v1, v2 )
	return v1.x * v2.x + v1.y * v2.y + v1.z * v2.z 
end 

local function cross( v1, v2 )
	return {
		x = v1.y * v2.z - v1.z * v2.y,
		y = v1.z * v2.x - v1.x * v2.z,
		z = v1.x * v2.y - v1.y * v2.x,
	}
end

local function lensquared( v) 
	return (v.x * v.x + v.y * v.y + v.z * v.z)
end

local function length(v) 
	return math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
end

local function normalize( v )

	local d = 1.0 / math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
	return { x=v.x * d, y=v.y * d, z=v.z * d }
end

local function multvec( v, s )
	return { x=v.x * s, y=v.y * s, z=v.z * s }
end
	
local function addvec( v1, v2 )
	return { x=v1.x + v2.x, y=v1.y + v2.y, z=v1.z + v2.z }
end

local function subvec( v1, v2 )
	return { x=v1.x - v2.x, y=v1.y - v2.y, z=v1.z - v2.z }
end

local function multaddvec( v1, v2, s )
	return addvec( v1, multvec( v2, s ) )
end

local function copyvec( v1 )
	return { x=v1.x, y=v1.y, z=v1.z }
end

local function det( v1, v2, v3 )
	local d = v1.x * (v2.y * v3.z - v2.z * v3.y)
			+ v1.y * (v2.z * v3.x - v2.x * v3.z)
			+ v1.z * (v2.x * v3.y - v2.y * v3.x)
	return d
end

return {
    origin = origin,
	UP_VECTOR = UP_VECTOR,
	RIGHT_VECTOR = RIGHT_VECTOR, 
	FORWARD_VECTOR = FORWARD_VECTOR,
    
    dot = dot,
    cross = cross,
    lensquared = lensquared,
    length = length,
    normalize = normalize,
    multaddvec = multaddvec,
    multvec = multvec,
    addvec = addvec,
    subvec = subvec,
    copyvec = copyvec,
    det = det
}