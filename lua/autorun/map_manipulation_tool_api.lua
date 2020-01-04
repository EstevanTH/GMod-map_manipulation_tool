--[[
By Mohamed RACHID
Please follow the license "GNU Lesser General Public License v3".
To be simple: if you distribute a modified version then you share the sources.

Limitations:
- You cannot do several operations on the same BspContext at once.
- You currently cannot deal with different BspContext endiannesses at once.
--]]
-- https://developer.valvesoftware.com/wiki/Source_BSP_File_Format
-- https://developer.valvesoftware.com/wiki/Source_BSP_File_Format/Game-Specific
-- TODO - objets de contexte contenant :
	-- id Stéam du jeu ou 0
	-- boutisme
-- TODO - membres par défaut, avec commentaires descriptifs
-- TODO - les lumps doivent pouvoir être substitués par :
	-- 1 string en mémoire
	-- 1 autre flux de fichier
	-- => listage pour l'entrée
	-- => listage pour la sortie


print("map_manipulation_tool_api.lua")


-- Local copies, not changing how the code is written, for greater loop efficiency:
local SysTime = SysTime
local bit = bit
local coroutine = coroutine
local math = math
local string = string
local unpack = unpack
local table = table


module("map_manipulation_tool_api", package.seeall)


--- Constants ---
BUFFER_LENGTH = 4194304 -- 4 MiB
HEADER_LZMA_LUMP_LENGTH = 17


--- Data structures ---

function data_to_le(data)
	-- Decode a binary string into a 4-byte-max little-endian integer
	local result = 0
	local bytes = {string.byte(data, 1, #data)}
	for i = #bytes, 1, -1 do
		result = bit.bor(bit.lshift(result, 8), bytes[i])
	end
	return result
end

function data_to_be(data)
	-- Decode a binary string into a 4-byte-max big-endian integer
	local result = 0
	local bytes = {string.byte(data, 1, #data)}
	for i = 1, #bytes, 1 do
		result = bit.bor(bit.lshift(result, 8), bytes[i])
	end
	return result
end

local data_to_integer = nil -- to be set upon .bsp load

function int32_to_le_data(num)
	local bytes = {
		bit.band(num, 0xFF),
		bit.band(bit.rshift(num, 8), 0xFF),
		bit.band(bit.rshift(num, 16), 0xFF),
		bit.band(bit.rshift(num, 24), 0xFF),
	}
	return string.char(unpack(bytes))
end

function int16_to_le_data(num)
	local bytes = {
		bit.band(num, 0xFF),
		bit.band(bit.rshift(num, 8), 0xFF),
	}
	return string.char(unpack(bytes))
end

function int32_to_be_data(num)
	local bytes = {
		bit.band(bit.rshift(num, 24), 0xFF),
		bit.band(bit.rshift(num, 16), 0xFF),
		bit.band(bit.rshift(num, 8), 0xFF),
		bit.band(num, 0xFF),
	}
	return string.char(unpack(bytes))
end

function int16_to_be_data(num)
	local bytes = {
		bit.band(bit.rshift(num, 8), 0xFF),
		bit.band(num, 0xFF),
	}
	return string.char(unpack(bytes))
end

-- To be set upon .bsp load:
-- TODO - move to context
local int32_to_data = nil
local int16_to_data = nil

local lumpLuaIndexToName = {} -- +1 from the original list
local lumpNameToLuaIndex = {} -- +1 from the original list
do
	local function add(cIndex, name)
		lumpLuaIndexToName[cIndex + 1] = name
		lumpNameToLuaIndex[name] = cIndex + 1
	end
	add( 0, "LUMP_ENTITIES")
	add( 1, "LUMP_PLANES")
	add( 2, "LUMP_TEXDATA")
	add( 3, "LUMP_VERTEXES")
	add( 4, "LUMP_VISIBILITY")
	add( 5, "LUMP_NODES")
	add( 6, "LUMP_TEXINFO")
	add( 7, "LUMP_FACES")
	add( 8, "LUMP_LIGHTING")
	add( 9, "LUMP_OCCLUSION")
	add(10, "LUMP_LEAFS")
	add(11, "LUMP_FACEIDS")
	add(12, "LUMP_EDGES")
	add(13, "LUMP_SURFEDGES")
	add(14, "LUMP_MODELS")
	add(15, "LUMP_WORLDLIGHTS")
	add(16, "LUMP_LEAFFACES")
	add(17, "LUMP_LEAFBRUSHES")
	add(18, "LUMP_BRUSHES")
	add(19, "LUMP_BRUSHSIDES")
	add(20, "LUMP_AREAS")
	add(21, "LUMP_AREAPORTALS")
	add(22, "LUMP_PORTALS")
	add(23, "LUMP_CLUSTERS")
	add(24, "LUMP_PORTALVERTS")
	add(25, "LUMP_CLUSTERPORTALS")
	add(26, "LUMP_DISPINFO")
	add(27, "LUMP_ORIGINALFACES")
	add(28, "LUMP_PHYSDISP")
	add(29, "LUMP_PHYSCOLLIDE")
	add(30, "LUMP_VERTNORMALS")
	add(31, "LUMP_VERTNORMALINDICES")
	add(32, "LUMP_DISP_LIGHTMAP_ALPHAS")
	add(33, "LUMP_DISP_VERTS")
	add(34, "LUMP_DISP_LIGHTMAP_SAMPLE_POSITIONS")
	add(35, "LUMP_GAME_LUMP")
	add(36, "LUMP_LEAFWATERDATA")
	add(37, "LUMP_PRIMITIVES")
	add(38, "LUMP_PRIMVERTS")
	add(39, "LUMP_PRIMINDICES")
	add(40, "LUMP_PAKFILE")
	add(41, "LUMP_CLIPPORTALVERTS")
	add(42, "LUMP_CUBEMAPS")
	add(43, "LUMP_TEXDATA_STRING_DATA")
	add(44, "LUMP_TEXDATA_STRING_TABLE")
	add(45, "LUMP_OVERLAYS")
	add(46, "LUMP_LEAFMINDISTTOWATER")
	add(47, "LUMP_FACE_MACRO_TEXTURE_INFO")
	add(48, "LUMP_DISP_TRIS")
	add(49, "LUMP_PHYSCOLLIDESURFACE")
	add(50, "LUMP_WATEROVERLAYS")
	add(51, "LUMP_LEAF_AMBIENT_INDEX_HDR")
	add(52, "LUMP_LEAF_AMBIENT_INDEX")
	add(53, "LUMP_LIGHTING_HDR")
	add(54, "LUMP_WORLDLIGHTS_HDR")
	add(55, "LUMP_LEAF_AMBIENT_LIGHTING_HDR")
	add(56, "LUMP_LEAF_AMBIENT_LIGHTING")
	add(57, "LUMP_XZIPPAKFILE")
	add(58, "LUMP_FACES_HDR")
	add(59, "LUMP_MAP_FLAGS")
	add(60, "LUMP_OVERLAY_FADES")
	add(61, "LUMP_OVERLAY_SYSTEM_LEVELS")
	add(62, "LUMP_PHYSLEVEL")
	add(63, "LUMP_DISP_MULTIBLEND")
end
function getLumpLuaIndexToName(luaIndex)
	return lumpLuaIndexToName[luaIndex]
end
function getLumpNameToLuaIndex(name)
	return lumpNameToLuaIndex[name]
end

local BaseDataStructure = {
	-- Base class for data structures in a .bsp file
	-- Warning: new() alters the current position in streamSrc.
	
	streamSrc = nil,
	offset = nil,
	
	new = function(cls, streamSrc, offset)
		-- streamSrc: optional
		-- offset: optional (nil for relative access or undefined streamSrc)
		
		local instance = {}
		setmetatable(instance, cls)
		
		instance.streamSrc = streamSrc
		
		instance.offset = offset
		if offset ~= nil and streamSrc then
			streamSrc:Seek(offset)
		end
		return instance
	end,
	
	newClass = function(base, cls)
		cls = cls or {}
		setmetatable(cls, base)
		return cls
	end,
}
BaseDataStructure.__index = BaseDataStructure

local lump_t -- defined later

local LumpPayload = BaseDataStructure:newClass({
	-- Wrapper around a lump payload
	-- No content is held in here.
	-- TODO - attention, pour un game lump compressé il faut apparemment regarder le décalage du game lump suivant
	
	lumpInfoType = lump_t, -- static; nil for now (filled after lump_t definition)
	
	compressed = nil,
	lzma_header_properties = nil,
	lumpInfoSrc = nil,
	lumpInfoDst = nil, -- created upon writing to a destination stream
	
	new = function(cls, streamSrc, lumpInfo)
		local offset = lumpInfo.fileofs
		local instance = BaseDataStructure:new(streamSrc, offset)
		setmetatable(instance, cls)
		
		instance.compressed = false
		local compressMagic = streamSrc:Read(4)
		if (data_to_integer == data_to_le and compressMagic == "LZMA")
		or (data_to_integer == data_to_be and compressMagic == "AMZL") then
			-- Parse the lzma_header_t:
			instance.compressed = true
			streamSrc:Skip(8)
			instance.lzma_header_properties = streamSrc:Read(5) -- unkown meaning
		end
		instance.lumpInfoSrc = lumpInfo
		return instance
	end,
	
	seekToPayload = function(self)
		-- Seek streamSrc to the payload start, skipping the lzma_header_t
		if self.streamSrc == nil then
			error("This object has no streamSrc!")
		end
		local offset = self.offset
		if self.compressed then
			offset = offset + HEADER_LZMA_LUMP_LENGTH
		end
		self.streamSrc:Seek(offset)
	end,
	
	readAll = function(self)
		-- Return the uncompressed payload of the current lump
		local payload
		self:seekToPayload()
		if self.compressed then
			payload = util.Decompress(self.streamSrc:Read(self.lumpInfoSrc.filelen - HEADER_LZMA_LUMP_LENGTH))
			if payload == nil or string.len(payload) == 0 then
				-- TODO - chercher cause de l'échec
				error("Could not decompress this lump")
			end
		else
			payload = self.streamSrc:Read(self.lumpInfoSrc.filelen)
		end
		return payload
	end,
	
	_addDummyBytesBefore = function(cls, streamDst) -- static method
		-- Add dummy bytes to meet the "4-byte multiple" lump start position requirement
		local dummyBytes = streamDst:Tell() % 4
		if dummyBytes ~= 0 then
			streamDst:Write(string.rep("\0", dummyBytes))
		end
	end,
	
	copyTo = function(self, streamDst, withCompression)
		-- Copy the current lump from self.streamSrc to streamDst
		if withCompression == nil then
			withCompression = self.compressed
		end
		if withCompression == self.compressed then
			-- Just copy:
			self:_addDummyBytesBefore(streamDst)
			local fileofs = streamDst:Tell()
			local remainingBytes = self.lumpInfoSrc.filelen
			self.streamSrc:Seek(self.offset)
			while remainingBytes > 0 do
				local toRead_bytes = math.min(BUFFER_LENGTH, remainingBytes)
				streamDst:Write(self.streamSrc:Read(toRead_bytes))
				remainingBytes = remainingBytes - toRead_bytes
			end
			self.lumpInfoDst = self.lumpInfoType:new(nil, self, nil, fileofs, self.lumpInfoSrc.filelen)
		else
			-- Compress or decompress then copy:
			self:writeTo(self:readAll(), streamDst, withCompression)
		end
		return self.lumpInfoDst
	end,
	
	writeTo = function(self, payload, streamDst, withCompression)
		-- Write then given lump payload into streamDst
		-- payload: uncompressed lump content
		self:_addDummyBytesBefore(streamDst)
		local fileofs = streamDst:Tell()
		local uncompressedBytes = string.len(payload)
		local cursorBytes = 1
		local remainingBytes
		local finalPayload
		local filelen
		if withCompression then
			local payloadCompressed = util.Compress(payload)
			local compressedBytes = string.len(payloadCompressed)
			if data_to_integer == data_to_le then
				streamDst:Write("LZMA")
			else
				streamDst:Write("AMZL")
			end
			streamDst:Write(int32_to_le_data(uncompressedBytes))
			streamDst:Write(int32_to_le_data(compressedBytes))
			if self.lumpInfoSrc and self.lumpInfoSrc.lzma_header_properties ~= nil then
				-- Unknown meaning, just copy when possible:
				streamDst:Write(self.lumpInfoSrc.lzma_header_properties)
			else
				streamDst:Write("\0\0\0\0\0")
			end
			remainingBytes = compressedBytes
			finalPayload = payloadCompressed
			filelen = compressedBytes + HEADER_LZMA_LUMP_LENGTH
		else
			remainingBytes = uncompressedBytes
			finalPayload = payload
			filelen = uncompressedBytes
		end
		while remainingBytes > 0 do
			local bytesToWrite = math.min(BUFFER_LENGTH, remainingBytes)
			streamDst:Write(string.sub(finalPayload, cursorBytes, cursorBytes + bytesToWrite - 1))
			remainingBytes = remainingBytes - bytesToWrite
			cursorBytes = cursorBytes + bytesToWrite
		end
		self.lumpInfoDst = self.lumpInfoType:new(nil, self, nil, fileofs, filelen)
		if withCompression then
			 -- apparently the only location where fourCC needs to be explicitly set
			if self.compressed then
				-- decompressing
				self.lumpInfoDst.fourCC = 0
			else
				-- compressing
				self.lumpInfoDst.fourCC = uncompressedBytes
			end
		end
		return self.lumpInfoDst
	end,
})
LumpPayload.__index = LumpPayload

local dgamelump_t -- defined later

local GameLumpPayload = LumpPayload:newClass({
	-- Wrapper around a game lump payload
	-- No content is held in here.
	-- Unsupported: console version of Portal 2 (fileofs is not absolute)
	
	lumpInfoType = dgamelump_t, -- static; nil for now (filled after dgamelump_t definition)
	
	new = function(cls, streamSrc, lumpInfo)
		-- This constructor must have the same arguments as LumpPayload:new() because it is called in LumpPayload with class resolution.
		local instance = LumpPayload:new(streamSrc, lumpInfo)
		setmetatable(instance, cls)
		return instance
	end,
})
GameLumpPayload.__index = GameLumpPayload

lump_t = BaseDataStructure:newClass({
	-- Note: the default attributes must be those of a null lump_t.
	-- This class & its children are referred to in this file as: (lump_t|dgamelump_t|lumpInfoType)
	
	fileofs = 0,
	filelen = 0,
	version = 0, -- valid value
	fourCC = 0, -- valid value
	payload = nil,
	
	new = function(cls, streamSrc, payload, other, fileofs, filelen, _noReadInherit)
		-- Usage 1: lump_t:new(streamSrc)
		--  Load a lump_t from the current position in streamSrc
		-- Usage 2: lump_t:new(nil, payload, nil, fileofs=0, filelen=payload.lumpInfoSrc.filelen)
		--  Make a lump_t for a written LumpPayload (in a destination stream)
		-- Usage 3: lump_t:new(nil, false)
		--  Make a lump_t for a written null LumpPayload (in a destination stream)
		-- Usage 4: lump_t:new(nil, nil, other, fileofs=0)
		--  Make a lump_t from another lump_t, for writing into a destination stream
		-- The file cursor must be at the end of the lump_t when returning.
		local instance = BaseDataStructure:new(streamSrc, nil)
		setmetatable(instance, cls)
		
		if streamSrc ~= nil then
			if not _noReadInherit then
				instance.fileofs = data_to_integer(streamSrc:Read(4))
				instance.filelen = data_to_integer(streamSrc:Read(4))
				instance.version = data_to_integer(streamSrc:Read(4))
				instance.fourCC = data_to_integer(streamSrc:Read(4))
				local lumpIsUsed = (
					instance.fileofs ~= 0 and
					instance.filelen ~= 0
				)
				if lumpIsUsed then
					local streamPos = streamSrc:Tell()
					instance.payload = LumpPayload:new(streamSrc, instance)
					streamSrc:Seek(streamPos)
				end
			end
		elseif payload ~= nil then
			if payload ~= false then -- condition allowing null-lumps creation
				if fileofs == nil then
					fileofs = 0 -- unknown (& easily debugged)
				end
				if filelen == nil then
					filelen = payload.lumpInfoSrc.filelen
				end
				
				instance.fileofs = fileofs
				instance.filelen = filelen
				instance.version = payload.lumpInfoSrc.version
				instance.fourCC = payload.lumpInfoSrc.fourCC
				instance.payload = payload
			end
		elseif other ~= nil then
			instance.fileofs = fileofs or 0
			instance.filelen = other.filelen
			instance.version = other.version
			instance.fourCC = other.fourCC
			instance.payload = other.payload
		else
			error("Missing arguments")
		end
		
		return instance
	end,
	
	writeTo = function(self, streamDst)
		streamDst:Write(int32_to_data(self.fileofs))
		streamDst:Write(int32_to_data(self.filelen))
		streamDst:Write(int32_to_data(self.version))
		streamDst:Write(int32_to_data(self.fourCC))
	end,
})
lump_t.__index = lump_t

dgamelump_t = lump_t:newClass({
	-- Note: the default attributes must be those of a null dgamelump_t.
	
	id = 0,
	flags = 0,
	
	new = function(cls, streamSrc, payload, other, fileofs, filelen)
		-- Usage 1: dgamelump_t:new(streamSrc)
		--  Load a dgamelump_t from the current position in streamSrc
		-- Usage 2: dgamelump_t:new(nil, payload, nil, fileofs=0, filelen=payload.lumpInfoSrc.filelen)
		--  Make a dgamelump_t for a written GameLumpPayload (in destination stream)
		-- Usage 3: dgamelump_t:new(nil, false)
		--  Make a dgamelump_t for a written null GameLumpPayload (in a destination stream)
		-- Usage 4: dgamelump_t:new(nil, nil, other, fileofs=0)
		--  Make a dgamelump_t from another dgamelump_t, for writing into a destination stream
		-- The file cursor must be at the end of the dgamelump_t when returning.
		local instance = lump_t:new(streamSrc, payload, other, fileofs, filelen, true)
		setmetatable(instance, cls)
		
		if streamSrc ~= nil then
			instance.id = data_to_integer(streamSrc:Read(4))
			instance.flags = data_to_integer(streamSrc:Read(2))
			instance.version = data_to_integer(streamSrc:Read(2))
			instance.fileofs = data_to_integer(streamSrc:Read(4))
			instance.filelen = data_to_integer(streamSrc:Read(4))
			local lumpIsUsed = (
				instance.fileofs ~= 0 and
				instance.filelen ~= 0
			)
			if lumpIsUsed then
				local streamPos = streamSrc:Tell()
				instance.payload = GameLumpPayload:new(streamSrc, instance)
				streamSrc:Seek(streamPos)
			end
		elseif payload ~= nil then
			if payload ~= false then -- to allow null-lumps creation
				instance.id = payload.lumpInfoSrc.id
				instance.flags = payload.lumpInfoSrc.flags
			end
		elseif other ~= nil then
			instance.id = other.id
			instance.flags = other.flags
		end
		
		return instance
	end,
	
	skipThem = function(cls, context, streamDst, numberOfItems) -- static method
		-- Skip numberOfItems dgamelump_t items in streamDst (for later write)
		-- TODO - ajuster pour jeux avec dgamelump_t différent
		streamDst:Skip(16 * numberOfItems)
	end,
	
	writeTo = function(self, streamDst)
		-- TODO - ajuster pour jeux avec dgamelump_t différent
		streamDst:Write(int32_to_data(self.id))
		streamDst:Write(int16_to_data(self.flags))
		streamDst:Write(int16_to_data(self.version))
		streamDst:Write(int32_to_data(self.fileofs))
		streamDst:Write(int32_to_data(self.filelen))
	end,
})
dgamelump_t.__index = dgamelump_t

LumpPayload.lumpInfoType = lump_t
GameLumpPayload.lumpInfoType = dgamelump_t

local HEADER_LUMPS = 64

local dheader_t = BaseDataStructure:newClass({
	-- Structure that represents the header of a .bsp file
	
	ident = nil,
	version = nil,
	lumps = nil,
	mapRevision = nil,
	
	new = function(cls, streamSrc, other, lumps)
		-- Usage 1: dheader_t:new(streamSrc)
		--  Load a dheader_t from the position 0 in streamSrc
		-- Usage 2: dheader_t:new(nil, other, lumps)
		--  Make a dheader_t from another dheader_t with the optional specified array of lump_t, for writing into a destination stream
		local instance = BaseDataStructure:new(streamSrc, 0)
		setmetatable(instance, cls)
		
		if streamSrc ~= nil then
			local ident = streamSrc:Read(4)
			if ident == "VBSP" or ident == "rBSP" then
				data_to_integer = data_to_le
				int32_to_data = int32_to_le_data
				int16_to_data = int16_to_le_data
			elseif ident == "PSBV" or ident == "PSBr" then
				data_to_integer = data_to_be
				int32_to_data = int32_to_be_data
				int16_to_data = int16_to_be_data
			else
				data_to_integer = nil
				int32_to_data = nil
				error([[The "VBSP" magic header was not found. This map does not seem to be a valid Source Engine map.]])
			end
			
			instance.ident = ident
			instance.version = data_to_integer(streamSrc:Read(4))
			instance.lumps = {}
			for i = 1, HEADER_LUMPS do
				-- local cursorBefore = streamSrc:Tell()
				table.insert(instance.lumps, lump_t:new(streamSrc))
				-- local readBytes = streamSrc:Tell() - cursorBefore
				-- if readBytes ~= 16 then
					-- error("Read " .. tostring(readBytes) .. " bytes in lump_t instead of 16")
				-- end
			end
			instance.mapRevision = data_to_integer(streamSrc:Read(4))
		elseif other ~= nil and lumps then
			if lumps == nil then
				lumps = other.lumps
			end
			instance.ident = other.ident
			instance.version = other.version
			instance.lumps = lumps
			instance.mapRevision = other.mapRevision
		else
			error("Missing arguments")
		end
		
		return instance
	end,
	
	writeTo = function(self, streamDst)
		-- Write then given BSP header into position 0 in streamDst
		-- This is supposed to happen after writing every lump payload, so lump_t's are ready.
		streamDst:Seek(0)
		streamDst:Write(self.ident)
		streamDst:Write(int32_to_data(self.version))
		for i = 1, HEADER_LUMPS do
			self.lumps[i]:writeTo(streamDst)
		end
		streamDst:Write(int32_to_data(self.mapRevision))
	end,
})
dheader_t.__index = dheader_t

local function lumpIndexesOrderedFromOffset(lumps)
	-- Make a table of lump indexes ordered by their fileofs
	-- It is intended to keep the order of lump payloads from the source.
	-- It does not alter lumps array.
	-- lumps: BspContext.lumpsSrc or BspContext.gameLumpsSrc
	local indexes = {}
	for i = 1, #lumps do
		table.insert(indexes, i)
	end
	table.sort(indexes, function(indexA, indexB)
		local fileofsA = lumps[indexA].fileofs
		local fileofsB = lumps[indexB].fileofs
		local filelenA = lumps[indexA].filelen
		local filelenB = lumps[indexB].filelen
		if fileofsA > 0 and filelenA > 0 then
			if fileofsB > 0 and filelenB > 0 then
				-- lowest offset comes first
				return fileofsA < fileofsB
			else
				-- missing lump at indexB comes after if injected
				return true
			end
		else
			if fileofsB > 0 and filelenB > 0 then
				-- missing lump at indexA comes after if injected
				return false
			else
				-- put extra injected lump payloads in the order of the lumps array
				return indexA < indexB
			end
		end
	end)
	return indexes
end

BspContext = {
	-- Context that holds a source .bsp file and its information, as well as a destination .bsp file.
	-- TODO - passer contexte aux constructeurs des autres classes (si besoin)
	-- TODO - gérer automatiquement l'ajout d'un hook pour poursuivre le traitement + callback statut + callback fini
	
	filenameSrc = nil,
	streamSrc = nil,
	filenameDst = nil, -- unusued ATM
	streamDst = nil, -- unusued ATM
	bspHeader = nil, -- dheader_t object
	lumpsSrc = nil, -- list of lump_t objects
	gameLumpsSrc = nil, -- list of dgamelump_t objects
	lumpsDst = nil,
	gameLumpsDst = nil,
	lumpIndexesToCompress = nil, -- nil / false / true; game lumps: keep / all uncompressed / all compressed
	yieldAt = nil, -- when to yield a running coroutine (= minimum value of SysTime())
	
	new = function(cls, filenameSrc)
		local instance = {}
		setmetatable(instance, cls)
		
		instance.filenameSrc = filenameSrc
		instance.streamSrc = file.Open(filenameSrc, "rb", "GAME")
		if instance.streamSrc == nil then
			error("Unable to open " .. filenameSrc)
		end
		
		instance.bspHeader = dheader_t:new(instance.streamSrc)
		
		instance.lumpsSrc = instance.bspHeader.lumps
		
		instance.gameLumpsSrc = {}
		local gameLumpPayload = instance.lumpsSrc[lumpNameToLuaIndex["LUMP_GAME_LUMP"]].payload
		if gameLumpPayload ~= nil then
			-- No worry about compression because the whole game lump fortunately cannot be compressed.
			gameLumpPayload:seekToPayload()
			for i = 1, data_to_integer(instance.streamSrc:Read(4)) do
				table.insert(instance.gameLumpsSrc, dgamelump_t:new(instance.streamSrc))
			end
		end
		
		instance:resetOutputListing()
		
		instance.lumpIndexesToCompress = {}
		
		return instance
	end,
	
	addExternalLump = nil, -- TODO
	
	resetOutputListing = function(self)
		-- Set every lump / game lump as the one in self.streamSrc
		-- Every lump must be replaced with a lump in the destination stream.
		
		self.lumpsDst = {}
		for i = 1, #self.lumpsSrc do
			-- table.insert(self.lumpsDst, lump_t:new(nil, nil, self.lumpsSrc[i]))
			table.insert(self.lumpsDst, self.lumpsSrc[i])
		end
		
		self.gameLumpsDst = {}
		for i = 1, #self.gameLumpsSrc do
			-- table.insert(self.gameLumpsDst, dgamelump_t:new(nil, nil, self.gameLumpsSrc[i]))
			table.insert(self.gameLumpsDst, self.gameLumpsSrc[i])
		end
	end,
	
	yieldIfTimeout = function(self, progress)
		if self.yieldAt ~= nil and SysTime() >= self.yieldAt then
			coroutine.yield(progress)
		end
	end,
	
	writeNewBsp = function(self, filenameDst, yieldEvery_s)
		-- This method does not work well: the generated map malfunctions.
		
		local streamDst = file.Open(filenameDst, "wb", "DATA")
		if streamDst == nil then
			error("Unable to open data/" .. filenameDst .. " for write")
		end
		
		-- Do local copies of lump arrays to allow future calls to writeNewBsp():
		local lumpsDst = {}
		for i = 1, #self.lumpsDst do
			lumpsDst[i] = self.lumpsDst[i]
		end
		local gameLumpsDst = {}
		for i = 1, #self.gameLumpsDst do
			gameLumpsDst[i] = self.gameLumpsDst[i]
		end
		
		-- At this point, lumpsDst & gameLumpsDst contains lumps from self.streamSrc, with a wrong fileofs.
		local LUMP_GAME_LUMP = lumpNameToLuaIndex.LUMP_GAME_LUMP
		local LUMP_PAKFILE = lumpNameToLuaIndex.LUMP_PAKFILE
		local LUMP_XZIPPAKFILE = lumpNameToLuaIndex.LUMP_XZIPPAKFILE
		for _, i in ipairs(lumpIndexesOrderedFromOffset(self.lumpsSrc)) do
			-- Works fine because same number of elements in lumpsDst & lumpsDst
			local withCompression = self.lumpIndexesToCompress[i] -- true / false / nil
			if i == LUMP_GAME_LUMP then
				-- There is no LumpPayload object involved for the LUMP_GAME_LUMP itself.
				-- Note: the trailing null game lump must naturally always be at the end.
				--  But there is no need to ensure it: game lumps may be removed or replaced, but never added.
				
				-- Handle the need of a null game lump if compressed game lumps:
				local hasCompressedLumps = false
				if #gameLumpsDst ~= 0 then
					if withCompression then
						hasCompressedLumps = true
					else
						for j = 1, #gameLumpsDst do
							local payload = gameLumpsDst[j].payload
							if payload and payload.compressed then
								hasCompressedLumps = true
								break
							end
						end
					end
					local lastLump = gameLumpsDst[#gameLumpsDst]
					if hasCompressedLumps then
						-- Add a trailing null gamelump if not present:
						if lastLump.filelen ~= 0 then
							table.insert(gameLumpsDst, dgamelump_t:new(nil, false))
						end
					else
						-- Remove the trailing null gamelump if present:
						if lastLump.filelen == 0 then
							gameLumpsDst[#gameLumpsDst] = nil
						end
					end
				end
				
				-- Write the number of game lumps:
				local gameLump = lump_t:new(nil, nil, self.lumpsSrc[i], streamDst:Tell())
				lumpsDst[i] = gameLump
				streamDst:Write(int32_to_data(#gameLumpsDst))
				
				-- Skip the array of dgamelump_t's because not ready yet:
				local startOfLumpsArray = streamDst:Tell()
				dgamelump_t:skipThem(self, streamDst, #gameLumpsDst)
				
				-- Write the game lump payloads:
				for j = 1, #gameLumpsDst do
					local payload = gameLumpsDst[j].payload
					if payload ~= nil then
						payload:copyTo(streamDst, withCompression)
						gameLumpsDst[j] = payload.lumpInfoDst
					else
						gameLumpsDst[j] = dgamelump_t:new(nil, false)
					end
				end
				local endOfLump = streamDst:Tell()
				gameLump.filelen = endOfLump - gameLump.fileofs
				
				-- Write the array of dgamelump_t's:
				streamDst:Seek(startOfLumpsArray)
				for j = 1, #gameLumpsDst do
					gameLumpsDst[j]:writeTo(streamDst)
				end
				
				-- Seek to the end of the whole LUMP_GAME_LUMP:
				streamDst:Seek(endOfLump)
			else
				local payload = lumpsDst[i].payload
				if payload ~= nil then
					-- The lump to copy from has a payload.
					payload:copyTo(streamDst, withCompression)
					lumpsDst[i] = payload.lumpInfoDst
				else
					-- The lump to copy is a null payload.
					lumpsDst[i] = lump_t:new(nil, false)
				end
			end
		end
		-- Now lumpsDst & gameLumpsDst contain lumps in streamDst, with the effective fileofs.
		
		-- Write the file header (including lump_t's)
		local bspHeaderDst = dheader_t:new(nil, self.bspHeader, lumpsDst)
		bspHeaderDst:writeTo(streamDst)
		
		-- Close the destination file
		streamDst:Close()
	end,
}
BspContext.__index = BspContext
