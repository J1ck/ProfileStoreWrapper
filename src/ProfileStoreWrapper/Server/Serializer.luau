-- Concise Binary Object Representation (CBOR)
-- Fork of https://github.com/Zash/lua-cbor

local maxint = 9007199254740992
local minint = -9007199254740992
local NaN = 0/0

local RobloxConverters = {}

do
	-- Fork of https://github.com/Wh1msicaly/RBXLSerialize/blob/main/RBLXSerialize/Convertors.lua
	function splitbyte(input)
		local byte,p,flags = string.byte(input),128,{false,false,false,false,false,false,false,false}
		for i=1,8 do
			if byte>=p then flags[i],byte = true,byte-p end
			p=p/2
		end
		return flags
	end
	function formbyte(...)
		local byte = 0
		for p=1,8 do
			local bit=select(p,...)
			if bit then byte=byte+2^(8-p) end
		end
		return string.char(byte)
	end
	local valueType = "f"
	function deflate(forceType,...) 
		return string.pack(string.rep(forceType or valueType,#{...}),...)
	end 
	function flate(forceType,raw,n)
		return string.unpack(string.rep(forceType or valueType,n),raw)
	end 

	function getNativeSize(forceType) 
		return #string.pack(forceType or valueType ,1) 
	end

	local IndexToEnumItem = {}
	local EnumItemToIndex = {}

	do
		local i = 0
		for _,v in Enum:GetEnums() do
			for _,vv in v:GetEnumItems() do
				i += 1

				IndexToEnumItem[i] = vv
				EnumItemToIndex[vv] = i
			end
		end
	end

	local Methods = {
		["EnumItem"] = function(isClass,value) 
			if isClass then 
				return string.pack("I2", EnumItemToIndex[value])
			else
				return IndexToEnumItem[string.unpack("I2", value)]
			end
		end,
		["Enum"] = function(isClass,value)
			-- temp but honestly might just keep
			local item = value:GetEnumItems()[1]
			if isClass then
				return string.pack("I2", EnumItemToIndex[item])
			else
				return IndexToEnumItem[string.unpack("I2", value)].EnumType
			end
		end,
		["ColorSequence"] = function(isClass,ColorSequenceValue) 
			if isClass then 
				local encodeStr = ""
				local blockSize =  string.packsize("f I1 I1 I1")
				for i,v in ipairs(ColorSequenceValue.Keypoints) do 
					local ColorKeypoint = v 
					local C3 = ColorKeypoint.Value
					local r, g, b = math.floor(C3.R*255), math.floor(C3.G*255), math.floor(C3.B*255)
					local block =  string.pack("f I1 I1 I1",ColorKeypoint.Time,r,g,b) --  further optimizations are possible to store
					encodeStr=encodeStr..block 
				end
				return encodeStr 
			else 
				local array  = {} 
				local blockSize =  string.packsize("f I1 I1 I1")
				for i=1,#ColorSequenceValue,blockSize do 
					local block = ColorSequenceValue:sub(i,i+blockSize) 
					local Time , r,g,b  = string.unpack("f I1 I1 I1",block) 
					table.insert(array,ColorSequenceKeypoint.new(Time,Color3.new(r/255,g/255,b/255)))
				end
				return ColorSequence.new(array)
			end
		end,
		["ColorSequenceKeypoint"] = function(isClass,ColorKeypoint) 
			if isClass then 
				local C3 = ColorKeypoint.Value
				local r, g, b = math.floor(C3.R*255), math.floor(C3.G*255), math.floor(C3.B*255)
				return string.pack("f I1 I1 I1",ColorKeypoint.Time,r,g,b) --  further optimizations are possible to store
			else
				local Time , r,g,b  = string.unpack("f I1 I1 I1",ColorKeypoint)
				return ColorSequenceKeypoint.new(Time,Color3.new(r/255,g/255,b/255))
			end
		end,
		["NumberSequence"] = function(isClass,NumberSequenceValue) 
			if isClass then 
				-- Basic binary array 
				local encodeStr = ""
				local nativeFloatSize = getNativeSize(nil) 
				local blockSize = nativeFloatSize*3 
				for i,v in ipairs(NumberSequenceValue.Keypoints) do 
					local block = deflate(nil,v.Time,v.Value,v.Envelope)
					encodeStr = encodeStr..block 
				end 

				return encodeStr
			else
				local array = {} 
				local nativeFloatSize = getNativeSize(nil) 
				local blockSize = nativeFloatSize*3 
				for i=1,#NumberSequenceValue,blockSize do 
					local block = NumberSequenceValue:sub(i,i+blockSize) 
					local a,b,c = flate(nil,block,3) 
					table.insert(array,NumberSequenceKeypoint.new(a,b,c))
				end
				warn(array)
				return NumberSequence.new(array)
			end
		end,
		["NumberSequenceKeypoint"] = function(isClass,NumberKeypoint)
			if isClass then 
				return deflate(nil,NumberKeypoint.Time,NumberKeypoint.Value,NumberKeypoint.Envelope)
			else 
				local a,b,c = flate(nil,NumberKeypoint,3) 
				return NumberSequenceKeypoint.new(a,b,c)
			end
		end,
		["Rect"] = function(isClass,RectValue)
			if isClass then 
				return deflate(nil,RectValue.Min.X,RectValue.Min.Y,RectValue.Max.X,RectValue.Max.Y)
			else 
				local a,b,c,d = flate(nil,RectValue,4)
				return Rect.new(a,b,c,d)
			end
		end,
		["Ray"] = function(isClass,RayValue) 
			if isClass then 
				return deflate(nil,RayValue.Orgin.X,RayValue.Orgin.Y,RayValue.Orgin.Z,RayValue.Direction.X,RayValue.Direction.Y,RayValue.Direction.Z)
			else 
				local x,y,z,x1,y1,z1 = flate(nil,RayValue,6)
				return Ray.new(Vector3.new(x,y,z), Vector3.new(x1,y1,z1))
			end
		end,
		["PhysicalProperties"] = function(isClass,PhysicalPropertiesValue) 
			if isClass then 
				return deflate(nil,PhysicalPropertiesValue.Density,PhysicalPropertiesValue.Friction,PhysicalPropertiesValue.Elasticity,
					PhysicalPropertiesValue.FrictionWeight,PhysicalPropertiesValue.ElasticityWeight)
			else 
				local a,b,c,d,e = flate(nil,PhysicalPropertiesValue,5)
				return PhysicalProperties.new(a,b,c,d,e)
			end
		end,
		["NumberRange"] = function(isClass,NumberRangeValue) 
			if isClass then 
				return deflate(nil,NumberRangeValue.Min,NumberRangeValue.Max)
			else 
				local a,b = flate(nil,NumberRangeValue,2)
				return NumberRange.new(a,b)
			end
		end,
		["UDim"] = function(isClass,value)
			if isClass then 
				return deflate(nil,value.Scale,value.Offset) 
			else 
				local a,b = flate(nil,value,2)
				return UDim2.new(a,b)
			end
		end,
		["Color3"] = function(isClass,C3) 
			if isClass then 
				local r, g, b = math.round(C3.R*255), math.round(C3.G*255), math.round(C3.B*255)
				return deflate("I1",r,g,b)	
			else 
				local r1,g2,b2 = flate("I1",C3,3) 
				local r,g,b = r1/255,g2/255,b2/255
				return Color3.new(r,g,b)
			end
		end,
		["UDim2"] = function(isClass,value)
			if isClass then
				return  deflate(nil,value.X.Scale,value.X.Offset,value.Y.Scale,value.Y.Offset)
			else 
				local a,b,c,d = flate(nil,value,4)
				return UDim2.new(a,b,c,d)
			end
		end,
		["Vector3"] = function(isClass,vector) 
			if isClass then 
				if vector then 
					return deflate(nil,vector.X,vector.Y,vector.Z)
				end
			else 
				local X,Y,Z = flate(nil,vector,3)
				return Vector3.new(X,Y,Z)
			end
		end,
		["Vector3int16"] = function(isClass,vector) 
			if isClass then 
				if vector then 
					return deflate("i2",vector.X,vector.Y,vector.Z)
				end
			else 
				local X,Y,Z = flate("i2",vector,3)
				return Vector3.new(X,Y,Z)
			end
		end,
		["Vector2"] = function(isClass,vector) 
			if isClass then 
				if vector then 
					return deflate(nil,vector.X,vector.Y)
				end
			else 
				local X,Y = flate(nil,vector,2)
				return Vector2.new(X,Y)
			end
		end,
		["Vector2int16"] = function(isClass,vector) 
			if isClass then 
				if vector then 
					return deflate("i2",vector.X,vector.Y)
				end
			else 
				local X,Y = flate("i2",vector,2)
				return Vector2.new(X,Y)
			end
		end,
		["Content"]= function(isClass,str) 
			return str
		end,
		["ProtectedString"] = function(isClass,str) 
			return str
		end,
		["Faces"] = function(isClass,faces) 
			if isClass then 
				local byte = splitbyte(string.char(0))
				for i,v in ipairs(table.pack(faces.Top,faces.Bottom,faces.Left,faces.Right,faces.Back,faces.Front)) do 
					byte[i] = v 
				end
				-- table.unpack removes the tuple for some reason ?  
				return formbyte(faces)
			else 
				local face = {}
				local newValues = splitbyte(faces)
				for i,v in ipairs(newValues) do 
					if i <= 5 then 
						face[i] = v
					end
				end
				return Faces.new(table.unpack(face))
			end
		end,
		["CFrame"] = function(isClass,Cframe) 
			if isClass then 
				return deflate(nil,Cframe:components())
			else 
				-- yeah just thank string.unpack!
				local a,b,c,d,e,f,g,h,i,j,k,l = flate(nil,Cframe,12)
				return CFrame.new(a,b,c,d,e,f,g,h,i,j,k,l)
			end
		end,
		["CoordinateFrame"] = function(isClass,Cframe) 
			if isClass then 
				return deflate(nil,Cframe:components())
			else 
				local a,b,c,d,e,f,g,h,i,j,k,l = flate(nil,Cframe,12)
				return CFrame.new(a,b,c,d,e,f,g,h,i,j,k,l)
			end
		end
	}

	local IndexToType = {}
	local TypeToIndex = {}

	do
		local Index = 1

		for Type in Methods do
			IndexToType[Index] = Type
			TypeToIndex[Type] = Index

			Index += 1
		end
	end

	function RobloxConverters.canSerialize(Data) : boolean
		return Methods[typeof(Data)] ~= nil
	end

	function RobloxConverters.encode(Data) : string
		assert(RobloxConverters.canSerialize(Data), `type '{typeof(Data)}' is not serializable`)

		local Type = string.pack("I1", TypeToIndex[typeof(Data)])
		local Encoded = Methods[typeof(Data)](true, Data)

		return Type .. "\248" .. Encoded
	end

	function RobloxConverters.decode(Data : string)
		local Split = string.split(Data, "\248")
		local Type = IndexToType[string.unpack("I1", Split[1])]

		return Type ~= nil and Methods[Type](false, Split[2]) or nil
	end
end

local encoder = {};

local function encode(obj, opts)
	return encoder[type(obj)](obj, opts);
end

local function m_type(n)
	return n % 1 == 0 and n <= maxint and n >= minint and "integer" or "float"
end

function integer(num, m)
	local fmt;
	m = m or 0;
	if num < 24 then
		fmt, m = ">B", m + num;
	elseif num < 256 then
		fmt, m = ">BB", m + 24;
	elseif num < 65536 then
		fmt, m = ">BI2", m + 25;
	elseif num < 4294967296 then
		fmt, m = ">BI4", m + 26;
	else
		fmt, m = ">BI8", m + 27;
	end
	return string.pack(fmt, m, num);
end

local simple_mt = {};
function simple_mt:__tostring() return self.name or ("simple(%d)"):format(self.value); end
function simple_mt:__tocbor() return self.cbor or integer(self.value, 224); end

local function simple(value, name, cbor)
	assert(value >= 0 and value <= 255, "bad argument #1 to 'simple' (integer in range 0..255 expected)");
	return setmetatable({ value = value, name = name, cbor = cbor }, simple_mt);
end

local tagged_mt = {};
function tagged_mt:__tostring() return ("%d(%s)"):format(self.tag, tostring(self.value)); end
function tagged_mt:__tocbor() return integer(self.tag, 192) .. encode(self.value); end

local function tagged(tag, value)
	assert(tag >= 0, "bad argument #1 to 'tagged' (positive integer expected)");
	return setmetatable({ tag = tag, value = value }, tagged_mt);
end

local null = simple(22, "null"); -- explicit null
local undefined = simple(23, "undefined"); -- undefined or nil
local BREAK = simple(31, "break", "\255");

-- Number types dispatch
function encoder.number(num)
	return encoder[m_type(num)](num);
end

-- Major types 0, 1
function encoder.integer(num)
	if num < 0 then
		return integer(-1 - num, 32);
	end
	return integer(num, 0);
end

-- Major type 7
function encoder.float(num)
	if num ~= num then -- NaN shortcut
		return "\251\127\255\255\255\255\255\255\255";
	end
	local sign = (num > 0 or 1 / num > 0) and 0 or 1;
	num = math.abs(num)
	if num == math.huge then
		return string.char(251, sign * 128 + 128 - 1) .. "\240\0\0\0\0\0\0";
	end
	local fraction, exponent = math.frexp(num)
	if fraction == 0 then
		return string.char(251, sign * 128) .. "\0\0\0\0\0\0\0";
	end
	fraction = fraction * 2;
	exponent = exponent + 1024 - 2;
	if exponent <= 0 then
		fraction = fraction * 2 ^ (exponent - 1)
		exponent = 0;
	else
		fraction = fraction - 1;
	end
	return string.char(251,
		sign * 2 ^ 7 + math.floor(exponent / 2 ^ 4) % 2 ^ 7,
		exponent % 2 ^ 4 * 2 ^ 4 +
			math.floor(fraction * 2 ^ 4 % 0x100),
		math.floor(fraction * 2 ^ 12 % 0x100),
		math.floor(fraction * 2 ^ 20 % 0x100),
		math.floor(fraction * 2 ^ 28 % 0x100),
		math.floor(fraction * 2 ^ 36 % 0x100),
		math.floor(fraction * 2 ^ 44 % 0x100),
		math.floor(fraction * 2 ^ 52 % 0x100)
	)
end

if string.pack then
	function encoder.float(num)
		return string.pack(">Bd", 251, num);
	end
end


-- Major type 2 - byte strings
function encoder.bytestring(s)
	return integer(#s, 64) .. s;
end

-- Major type 3 - UTF-8 strings
function encoder.utf8string(s)
	return integer(#s, 96) .. s;
end

-- Lua strings are byte strings
encoder.string = encoder.bytestring;

function encoder.boolean(bool)
	return bool and "\245" or "\244";
end

encoder["nil"] = function() return "\246"; end

function encoder.userdata(ud, opts)
	if RobloxConverters.canSerialize(ud) then
		-- local t = typeof(ud)
		-- local s = RobloxConverters[t](true, ud)
		-- local encoded = integer(#t + #s + 2, 64) .. "\247" .. t .. "\248" .. s

		local encoded = RobloxConverters.encode(ud)

		return integer(#encoded, 64) .. encoded
	end

	local mt = getmetatable(ud);
	if mt then
		local encode_ud = opts and opts[mt] or mt.__tocbor;
		if encode_ud then
			return encode_ud(ud, opts);
		end
	end
	error "can't encode userdata";
end

function encoder.table(t, opts)
	local mt = getmetatable(t);
	if mt then
		local encode_t = opts and opts[mt] or mt.__tocbor;
		if encode_t then
			return encode_t(t, opts);
		end
	end
	-- the table is encoded as an array iff when we iterate over it,
	-- we see successive integer keys starting from 1.  The lua
	-- language doesn't actually guarantee that this will be the case
	-- when we iterate over a table with successive integer keys, but
	-- due an implementation detail in PUC Rio Lua, this is what we
	-- usually observe.  See the Lua manual regarding the # (length)
	-- operator.  In the case that this does not happen, we will fall
	-- back to a map with integer keys, which becomes a bit larger.
	local array, map, i, p = { integer(#t, 128) }, { "\191" }, 1, 2;
	local is_array = true;
	for k, v in pairs(t) do
		is_array = is_array and i == k;
		i = i + 1;

		local encoded_v = encode(v, opts);
		array[i] = encoded_v;

		map[p], p = encode(k, opts), p + 1;
		map[p], p = encoded_v, p + 1;
	end
	-- map[p] = "\255";
	map[1] = integer(i - 1, 160);
	return table.concat(is_array and array or map);
end

-- Array or dict-only encoders, which can be set as __tocbor metamethod
function encoder.array(t, opts)
	local array = { };
	for i, v in ipairs(t) do
		array[i] = encode(v, opts);
	end
	return integer(#array, 128) .. table.concat(array);
end

function encoder.map(t, opts)
	local map, p, len = { "\191" }, 2, 0;
	for k, v in pairs(t) do
		map[p], p = encode(k, opts), p + 1;
		map[p], p = encode(v, opts), p + 1;
		len = len + 1;
	end
	-- map[p] = "\255";
	map[1] = integer(len, 160);
	return table.concat(map);
end
encoder.dict = encoder.map; -- COMPAT

function encoder.ordered_map(t, opts)
	local map = {};
	if not t[1] then -- no predefined order
		local i = 0;
		for k in pairs(t) do
			i = i + 1;
			map[i] = k;
		end
		table.sort(map);
	end
	for i, k in ipairs(t[1] and t or map) do
		map[i] = encode(k, opts) .. encode(t[k], opts);
	end
	return integer(#map, 160) .. table.concat(map);
end

encoder["function"] = function ()
	error "can't encode function";
end

-- Decoder
-- Reads from a file-handle like object
local function read_bytes(fh, len)
	return fh:read(len)
end

local function read_byte(fh)
	return fh:read(1):byte();
end

local function read_length(fh, mintyp)
	if mintyp < 24 then
		return mintyp;
	elseif mintyp < 28 then
		local out = 0;
		for _ = 1, 2 ^ (mintyp - 24) do
			out = out * 256 + read_byte(fh);
		end
		return out;
	else
		error "invalid length";
	end
end

local decoder = {};

local function read_type(fh)
	local byte = read_byte(fh);
	return bit32.rshift(byte, 5), byte % 32;
end

local function read_object(fh, opts)
	local typ, mintyp = read_type(fh);
	return decoder[typ](fh, mintyp, opts);
end

local function read_integer(fh, mintyp)
	return read_length(fh, mintyp);
end

local function read_negative_integer(fh, mintyp)
	return -1 - read_length(fh, mintyp);
end

local function read_string(fh, mintyp)
	if mintyp ~= 31 then
		local str, pos = fh:getStringAndPos()
		local startingByte = string.sub(str, pos, pos):byte()
		local decoded = read_bytes(fh, read_length(fh, mintyp))

		return RobloxConverters.decode(decoded) or decoded

		-- if startingByte == 247 then
		-- 	-- local split = string.split(decoded:sub(2, -1), "\248")

		-- 	-- assert(RobloxConverters[split[1]], `Roblox Converter for type '{split[1]}' doesnt exist\nfull string: '{decoded}'`)

		-- 	-- return RobloxConverters[split[1]](false, split[2])
		-- 	return RobloxConverters.decode(decoded:sub(2, -1))
		-- else
		-- 	return decoded
		-- end
	end
	local out = {};
	local i = 1;
	local v = read_object(fh);
	while v ~= BREAK do
		out[i], i = v, i + 1;
		v = read_object(fh);
	end
	return table.concat(out);
end

local function read_unicode_string(fh, mintyp)
	return read_string(fh, mintyp);
	-- local str = read_string(fh, mintyp);
	-- if have_utf8 and not utf8.len(str) then
	-- TODO How to handle this?
	-- end
	-- return str;
end

local function read_array(fh, mintyp, opts)
	local out = {};
	if mintyp == 31 then
		local i = 1;
		local v = read_object(fh, opts);
		while v ~= BREAK do
			out[i], i = v, i + 1;
			v = read_object(fh, opts);
		end
	else
		local len = read_length(fh, mintyp);
		for i = 1, len do
			out[i] = read_object(fh, opts);
		end
	end
	return out;
end

local function read_map(fh, mintyp, opts)
	local out = {};
	local k;
	if mintyp == 31 then
		local i = 1;
		k = read_object(fh, opts);
		while k ~= BREAK do
			out[k], i = read_object(fh, opts), i + 1;
			k = read_object(fh, opts);
		end
	else
		local len = read_length(fh, mintyp);
		for _ = 1, len do
			k = read_object(fh, opts);
			out[k] = read_object(fh, opts);
		end
	end
	return out;
end

local tagged_decoders = {};

local function read_semantic(fh, mintyp, opts)
	local tag = read_length(fh, mintyp);
	local value = read_object(fh, opts);
	local postproc = opts and opts[tag] or tagged_decoders[tag];
	if postproc then
		return postproc(value);
	end
	return tagged(tag, value);
end

local function read_half_float(fh)
	local exponent = read_byte(fh);
	local fraction = read_byte(fh);
	local sign = exponent < 128 and 1 or -1; -- sign is highest bit

	fraction = fraction + (exponent * 256) % 1024; -- copy two(?) bits from exponent to fraction
	exponent = bit32.rshift(exponent, 2) % 32; -- remove sign bit and two low bits from fraction;

	if exponent == 0 then
		return sign * math.ldexp(fraction, -24);
	elseif exponent ~= 31 then
		return sign * math.ldexp(fraction + 1024, exponent - 25);
	elseif fraction == 0 then
		return sign * math.huge;
	else
		return NaN;
	end
end

local function read_float(fh)
	local exponent = read_byte(fh);
	local fraction = read_byte(fh);
	local sign = exponent < 128 and 1 or -1; -- sign is highest bit
	exponent = exponent * 2 % 256 + bit32.rshift(fraction, 7);
	fraction = fraction % 128;
	fraction = fraction * 256 + read_byte(fh);
	fraction = fraction * 256 + read_byte(fh);

	if exponent == 0 then
		return sign * math.ldexp(exponent, -149);
	elseif exponent ~= 0xff then
		return sign * math.ldexp(fraction + 2 ^ 23, exponent - 150);
	elseif fraction == 0 then
		return sign * math.huge;
	else
		return NaN;
	end
end

local function read_double(fh)
	local exponent = read_byte(fh);
	local fraction = read_byte(fh);
	local sign = exponent < 128 and 1 or -1; -- sign is highest bit

	exponent = exponent %  128 * 16 + bit32.rshift(fraction, 4);
	fraction = fraction % 16;
	fraction = fraction * 256 + read_byte(fh);
	fraction = fraction * 256 + read_byte(fh);
	fraction = fraction * 256 + read_byte(fh);
	fraction = fraction * 256 + read_byte(fh);
	fraction = fraction * 256 + read_byte(fh);
	fraction = fraction * 256 + read_byte(fh);

	if exponent == 0 then
		return sign * math.ldexp(exponent, -149);
	elseif exponent ~= 0xff then
		return sign * math.ldexp(fraction + 2 ^ 52, exponent - 1075);
	elseif fraction == 0 then
		return sign * math.huge;
	else
		return NaN;
	end
end


if string.unpack then
	function read_float(fh) return string.unpack(">f", read_bytes(fh, 4)) end
	function read_double(fh) return string.unpack(">d", read_bytes(fh, 8)) end
end

local function read_simple(fh, value, opts)
	if value == 24 then
		value = read_byte(fh);
	end
	if value == 20 then
		return false;
	elseif value == 21 then
		return true;
	elseif value == 22 then
		return null;
	elseif value == 23 then
		return undefined;
	elseif value == 25 then
		return read_half_float(fh);
	elseif value == 26 then
		return read_float(fh);
	elseif value == 27 then
		return read_double(fh);
	elseif value == 31 then
		return BREAK;
	end
	if opts and opts.simple then
		return opts.simple(value);
	end
	return simple(value);
end

decoder[0] = read_integer;
decoder[1] = read_negative_integer;
decoder[2] = read_string;
decoder[3] = read_unicode_string;
decoder[4] = read_array;
decoder[5] = read_map;
decoder[6] = read_semantic;
decoder[7] = read_simple;

-- opts.more(n) -> want more data
-- opts.simple -> decode simple value
-- opts[int] -> tagged decoder
local function decode(s, opts)
	local fh = {};
	local pos = 1;

	local more;
	if type(opts) == "function" then
		more = opts;
	elseif type(opts) == "table" then
		more = opts.more;
	elseif opts ~= nil then
		error(("bad argument #2 to 'decode' (function or table expected, got %s)"):format(type(opts)));
	end
	if type(more) ~= "function" then
		function more()
			error "input too short";
		end
	end

	function fh:read(bytes)
		local ret = s:sub(pos, pos + bytes - 1);
		if #ret < bytes then
			ret = more(bytes - #ret, fh, opts);
			if ret then self:write(ret); end
			return self:read(bytes);
		end
		pos = pos + bytes;
		return ret;
	end

	function fh:write(bytes) -- luacheck: no self
		s = s .. bytes;
		if pos > 256 then
			s = s:sub(pos + 1);
			pos = 1;
		end
		return #bytes;
	end

	function fh:getStringAndPos()
		return s, pos
	end

	return read_object(fh, opts);
end

return {
	encode = encode,
	decode = decode
}