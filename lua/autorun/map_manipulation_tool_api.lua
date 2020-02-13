--[[
By Mohamed RACHID
Please follow the license "Mozilla Public License 2.0" or greater. https://www.mozilla.org/en-US/MPL/2.0/
To be simple: if you distribute a modified version then you share the sources.

Limitations:
- You cannot do several operations on the same BspContext at once.
--]]
-- https://developer.valvesoftware.com/wiki/Source_BSP_File_Format
-- https://developer.valvesoftware.com/wiki/Source_BSP_File_Format/Game-Specific
-- TODO - objets de contexte contenant :
	-- id Stéam du jeu ou 0 ?
-- TODO - membres par défaut, avec commentaires descriptifs
-- TODO - fichier journal
-- TODO - attention suppression / édition lumps dupliqués vers 1 unique charge utile (HDR etc.)
-- TODO - interdire remplacement (sans effet) & suppression (sans effet) de LUMP_GAME_LUMP
-- TODO - la compression de lumps se fait par carte et non par lump, apparemment => activer compression par défaut lors du remplacement si nécessaire


print("map_manipulation_tool_api")


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
FULL_ZERO_BUFFER = nil -- BUFFER_LENGTH of null data, set only on 1st API use


--- Utility ---

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

do
	local math_min = math.min
	local math_max = math.max
	local string_sub = string.sub
	local NOT_IMPLEMENTED = "Not implemented"
	
	BytesIO = {
		-- Class to manipulate a string like a File (currently only read-only)
		-- Returned types should be the same for every case.
		-- Borrowed from Python
		
		_wrapped = nil, -- the string to wrap / nil when closed
		_length = -1, -- the length of _wrapped
		_cursor = -1, -- the current location in the string
		_writeable = false, -- always false: read-only
		
		new = function(cls, wrapped, mode)
			-- mode: always "rb"
			
			local instance = {}
			setmetatable(instance, cls)
			
			if mode == "rb" then
				instance._wrapped = wrapped
				instance._length = #wrapped
				instance._cursor = 0
			else
				error("Argument mode: invalid value")
			end
			
			return instance
		end,
		
		Close = function(self)
			self._wrapped = nil -- free memory
			self._length = -1
			self._cursor = -1
		end,
		
		Flush = function(self)
			-- nothing
		end,
		
		Read = function(self, length)
			if self._wrapped then
				if length > 0 then
					local oldCursor = self._cursor
					local newCursor = math_min(oldCursor + length, self._length)
					if newCursor ~= oldCursor then
						self._cursor = newCursor
						return string_sub(self._wrapped, oldCursor + 1, newCursor)
					else
						-- nothing left
						return
					end
				else
					return
				end
			else
				return
			end
		end,
		
		ReadBool = function(self)
			error(NOT_IMPLEMENTED)
		end,
		
		ReadByte = function(self)
			error(NOT_IMPLEMENTED)
		end,
		
		ReadDouble = function(self)
			error(NOT_IMPLEMENTED)
		end,
		
		ReadFloat = function(self)
			error(NOT_IMPLEMENTED)
		end,
		
		ReadLine = function(self)
			error(NOT_IMPLEMENTED)
		end,
		
		ReadLong = function(self)
			error(NOT_IMPLEMENTED)
		end,
		
		ReadShort = function(self)
			error(NOT_IMPLEMENTED)
		end,
		
		ReadULong = function(self)
			error(NOT_IMPLEMENTED)
		end,
		
		ReadUShort = function(self)
			error(NOT_IMPLEMENTED)
		end,
		
		Seek = function(self, pos)
			if self._wrapped then
				self._cursor = math_min(math_max(0, pos), self._length)
			end
		end,
		
		Size = function(self)
			if self._wrapped then
				return self._length
			else
				return
			end
		end,
		
		Skip = function(self, amount)
			if self._wrapped then
				self._cursor = math_min(math_max(0, self._cursor + amount), self._length)
			end
		end,
		
		Tell = function(self)
			if self._wrapped then
				return self._cursor
			else
				return
			end
		end,
		
	}
	BytesIO.__index = BytesIO
	setmetatable(BytesIO, FindMetaTable("File"))
end

do
	function lzmaVbspToStandard(lzmaVbsp)
		local id = string.sub(lzmaVbsp, 1, 4)
		if id ~= "LZMA" and id ~= "AMZL" then
			error("Invalid VBSP LZMA data!")
		end
		local actualSize = string.sub(lzmaVbsp, 5, 8) -- 32-bit little-endian
		local lzmaSize = data_to_le(string.sub(lzmaVbsp, 9, 12)) -- 32-bit little-endian
		local lzmaSizeExpected = #lzmaVbsp - 17
		local properties = string.sub(lzmaVbsp, 13, 17)
		if lzmaSize < lzmaSizeExpected then
			print("Warning: lzmaVbspToStandard() - compressed lump with lzmaSize (" .. tostring(lzmaSize) .. " bytes) not filling the whole lump payload (" .. tostring(lzmaSizeExpected) .. " bytes)")
		elseif lzmaSize > lzmaSizeExpected then
			print("Warning: lzmaVbspToStandard() - compressed lump with lzmaSize (" .. tostring(lzmaSize) .. " bytes) exceeding the lump payload capacity (" .. tostring(lzmaSizeExpected) .. " bytes), expect errors!")
		end
		return table.concat({
			properties,
			actualSize, "\0\0\0\0", -- 64-bit little-endian
			string.sub(lzmaVbsp, 18),
		})
	end
	
	function lzmaStandardToVbsp(context, lzmaStandard)
		local id
		if context.data_to_integer == data_to_le then
			id = "LZMA"
		else
			id = "AMZL"
		end
		local actualSize = string.sub(lzmaStandard, 6, 9) -- dropping most significant bits from 64-bit little-endian
		local lzmaSize = int32_to_le_data(#lzmaStandard - 13)
		local properties = string.sub(lzmaStandard, 1, 5)
		return table.concat({
			id,
			actualSize,
			lzmaSize,
			properties,
			string.sub(lzmaStandard, 14),
		})
	end
end

-- The asynchronous mechanism:
local yieldIfTimeout
do
	-- TODO - gérer automatiquement l'ajout d'un hook pour poursuivre le traitement + callback statut + callback fini [avec info succès / échec]
	local SysTime = SysTime
	local coroutine_running = coroutine.running
	local coroutine_yield = coroutine.yield
	yieldIfTimeout = function(step, stepCount, stepProgress)
		-- Function to be invoked by functions to support asynchronous operation
		local work = coroutine_running()
		if work ~= nil and work.yieldAt ~= nil and SysTime() >= work.yieldAt then
			coroutine_yield(step, stepCount, stepProgress)
		end
	end
	
	function asyncWork(onFinishedOk, onError, onProgress, interval_s, func, ...)
		-- Invoke the given function with the given arguments in a coroutine
		-- onFinishedOk : onFinishedOk(vararg result)
		-- onError : onError(string errorMessage)
		-- onProgress : onProgress(int step, int stepCount, float stepProgress)
		-- TODO : asynchrone pour de vrai
		-- TODO : SERVER != CLIENT
		-- TODO : CLIENT : stopper rendu si menu Echap visible
		-- TODO : retourner objet avec : fonction d'annulation
		local callData = {xpcall(func, function(errorMessage)
			ErrorNoHalt(errorMessage .. "\n" .. debug.traceback())
			return errorMessage
		end, ...)}
		local success = callData[1]
		if success then
			if onFinishedOk then
				onFinishedOk(unpack(callData, 2)) -- return result of func call
			end
		else
			if onError then
				onError(unpack(callData, 2)) -- return error message
				ErrorNoHalt(callData[2])
			end
		end
		return {--[[TODO]]}
	end
end

local callSafe
do
	local pcall = pcall
	local unpack = unpack
	function callSafe(...)
		local resultInfo = {pcall(...)}
		if not resultInfo[1] then
			ErrorNoHalt(resultInfo[2])
		end
		return unpack(resultInfo)
	end
end

local stringToLuaString
do
	local string_gsub = string.gsub
	local replacements = {
		['\0'] = '\\0',
		['"'] = '\\"',
		["\\"] = "\\\\",
	}
	for c = 0x01, 0x1F do
		replacements[string.char(c)] = string.format("\\x%02X", c)
	end
	function stringToLuaString(initial)
		return '"' .. string_gsub(initial, '.', replacements) .. '"'
	end
end


--- Entities ---

--[[
local noLuaEntityClasses = {
	-- Crash if missing (or suspected):
	["worldspawn"] = true,
	["info_node"] = true, -- suspected
	["info_node_air"] = true, -- suspected
	["info_node_air_hint"] = true, -- suspected
	["info_node_climb"] = true,
	["info_node_hint"] = true,
	-- Not working if missing:
	["env_skypaint"] = true, -- for 2D skybox
	["env_tonemap_controller"] = true, -- for lighting parameters (especially HDR)
	["sky_camera"] = true, -- for 3D skybox
}
]]

-- There are many entity classes that do not support being created in Lua: non-working state or crashes can happen.

--[[
local entityClassesWithoutModelIntoLua = {
	-- Entity classes that do not have a model but can be moved into Lua:
	["ambient_generic"] = true,
	--["game_text"] = true, -- no: branding purpose
	--["infodecal"] = true, -- no: branding purpose
	["light"] = true,
	--["light_spot"] = true, -- unknown
	--["lua_run"] = true, -- no: branding & protection purposes
	--["point_spotlight"] = true, -- unknown
	
	-- Spawn points [garrysmod\gamemodes\base\gamemode\player.lua]:
	["info_player_start"] = true,
	["info_player_deathmatch"] = true,
	["info_player_combine"] = true,
	["info_player_rebel"] = true,
	["info_player_counterterrorist"] = true,
	["info_player_terrorist"] = true,
	["info_player_axis"] = true,
	["info_player_allies"] = true,
	["gmod_player_start"] = true,
	["info_player_teamspawn"] = true,
	["ins_spawnpoint"] = true,
	["aoc_spawnpoint"] = true,
	["dys_spawn_point"] = true,
	["info_player_pirate"] = true,
	["info_player_viking"] = true,
	["info_player_knight"] = true,
	["diprip_start_team_blue"] = true,
	["diprip_start_team_red"] = true,
	["info_player_red"] = true,
	["info_player_blue"] = true,
	["info_player_coop"] = true,
	["info_player_human"] = true,
	["info_player_zombie"] = true,
	["info_player_zombiemaster"] = true,
	["info_survivor_rescue"] = true,
}

local entityClassesWithModelNoLua = {
	-- Entity classes that have a model but should not be moved into Lua:
	["trigger_hurt"] = true, -- no: used for map protection
	["func_occluder"] = true, -- not working
	
	["func_physbox"] = true, -- removed after creation?!
	["func_door"] = true, -- investigation
	["func_rotating"] = true, -- investigation
	
	["trigger_hurt"] = true, -- investigation
	["trigger_multiple"] = true, -- investigation
	["trigger_push"] = true, -- investigation
}
]]

local entityClassesForceLua = {
	-- Entity classes that should be moved into Lua despite having no model or a built-in model:
	-- In addition, class names starting with npc_ / weapon_ / item_ are forced too.
	["ambient_generic"] = true,
	["env_sprite"] = true,
	--["env_projectedtexture"] = true, -- no: branding purpose [not tested]
	["func_breakable"] = true,
	["func_breakable_surf"] = true,
	["func_brush"] = true,
	["func_button"] = true,
	["func_door"] = true,
	["func_door_rotating"] = true,
	["func_movelinear"] = true,
	["func_platrot"] = true,
	--["func_rotating"] = true, -- investigation
	--["game_text"] = true, -- no: branding purpose [not tested]
	--["infodecal"] = true, -- no: branding purpose [not tested]
	["light"] = true,
	["light_dynamic"] = true, -- almost sure
	--["light_spot"] = true, -- TODO - investigation
	--["point_spotlight"] = true, -- TODO - investigation
	--["lua_run"] = true, -- no: branding & protection purposes
	
	-- Spawn points [garrysmod\gamemodes\base\gamemode\player.lua]:
	["info_player_start"] = true,
	["info_player_deathmatch"] = true,
	["info_player_combine"] = true,
	["info_player_rebel"] = true,
	["info_player_counterterrorist"] = true,
	["info_player_terrorist"] = true,
	["info_player_axis"] = true,
	["info_player_allies"] = true,
	["gmod_player_start"] = true,
	["info_player_teamspawn"] = true,
	["ins_spawnpoint"] = true,
	["aoc_spawnpoint"] = true,
	["dys_spawn_point"] = true,
	["info_player_pirate"] = true,
	["info_player_viking"] = true,
	["info_player_knight"] = true,
	["diprip_start_team_blue"] = true,
	["diprip_start_team_red"] = true,
	["info_player_red"] = true,
	["info_player_blue"] = true,
	["info_player_coop"] = true,
	["info_player_human"] = true,
	["info_player_zombie"] = true,
	["info_player_zombiemaster"] = true,
	["info_survivor_rescue"] = true,
}

local entityClassesAvoidLua = {
	-- Entity classes that should not be moved into Lua besides having a non-built-in model:
}

local entityKeyValuesNotInLua = {
	["classname"] = true,
	["parentname"] = true,
}


--- Data structures ---

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
	add(22, "LUMP_UNUSED0") -- + Source 2007
	add(22, "LUMP_PROPCOLLISION") -- + Source 2009
	add(22, "LUMP_PORTALS")
	add(23, "LUMP_UNUSED1") -- + Source 2007
	add(23, "LUMP_PROPHULLS") -- + Source 2009
	add(23, "LUMP_CLUSTERS")
	add(24, "LUMP_UNUSED2") -- + Source 2007
	add(24, "LUMP_PROPHULLVERTS") -- + Source 2009
	add(24, "LUMP_PORTALVERTS")
	add(25, "LUMP_UNUSED3") -- + Source 2007
	add(25, "LUMP_PROPTRIS") -- + Source 2009
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
	add(49, "LUMP_PROP_BLOB") -- + Source 2009
	add(49, "LUMP_PHYSCOLLIDESURFACE")
	add(50, "LUMP_WATEROVERLAYS")
	add(51, "LUMP_LIGHTMAPPAGES") -- + Source 2006
	add(51, "LUMP_LEAF_AMBIENT_INDEX_HDR")
	add(52, "LUMP_LIGHTMAPPAGEINFOS") -- + Source 2006
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
function getLumpIdFromLumpName(idText)
	local id
	local isGameLump = (string.sub(idText, 1, 5) ~= "LUMP_")
	if isGameLump then
		id = data_to_be(idText)
	else
		id = lumpNameToLuaIndex[idText]
	end
	return id, isGameLump
end
function getLumpNameFromLumpId(isGameLump, id)
	local idText
	if isGameLump then
		idText = int32_to_be_data(id)
	else
		idText = lumpLuaIndexToName[id] -- id is the Lua table index!
	end
	return idText
end

local BaseDataStructure = {
	-- Base class for data structures in a .bsp file
	-- Warning: new() alters the current position in streamSrc.
	-- Note: streamSrc can refer to the source map or an external source!
	
	context = nil,
	streamSrc = nil,
	offset = nil,
	
	new = function(cls, context, streamSrc, offset)
		-- streamSrc: optional
		-- offset: optional (nil for relative access or undefined streamSrc)
		
		local instance = {}
		setmetatable(instance, cls)
		
		if context == nil then
			error("context cannot be nil!")
		end
		instance.context = context
		
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

lump_t = false -- defined later

local LumpPayload = BaseDataStructure:newClass({
	-- Wrapper around a lump payload
	-- No content is held in here.
	-- This class & its children are referred to in this file as: (LumpPayload|GameLumpPayload|payloadType)
	
	lumpInfoType = lump_t, -- static; nil for now (filled after lump_t definition)
	
	compressed = nil,
	lumpInfoSrc = nil,
	lumpInfoDst = nil, -- created upon writing to a destination stream
	
	new = function(cls, context, streamSrc, lumpInfo)
		local offset = lumpInfo.fileofs
		local instance = BaseDataStructure:new(context, streamSrc, offset)
		setmetatable(instance, cls)
		
		instance.compressed = false
		local compressMagic = streamSrc:Read(4)
		if (context.data_to_integer == data_to_le and compressMagic == "LZMA")
		or (context.data_to_integer == data_to_be and compressMagic == "AMZL") then
			instance.compressed = true
		end
		instance.lumpInfoSrc = lumpInfo
		return instance
	end,
	
	seekToPayload = function(self)
		-- Seek streamSrc to the payload start
		if self.streamSrc == nil then
			error("This object has no streamSrc!")
		end
		self.streamSrc:Seek(self.offset)
	end,
	
	readAll = function(self, noDecompress)
		-- Return the uncompressed payload of the current lump
		-- noDecompress: return the payload as-is without decompressing
		local payload
		self:seekToPayload()
		if self.compressed and not noDecompress then
			payload = util.Decompress(lzmaVbspToStandard(self.streamSrc:Read(self.lumpInfoSrc.filelen)))
			if payload == nil or #payload == 0 then
				error("Could not decompress this lump")
			end
		else
			payload = self.streamSrc:Read(self.lumpInfoSrc.filelen)
		end
		return payload
	end,
	
	_addOffsetMultiple4 = function(cls, streamDst) -- static method
		-- Add dummy bytes to meet the "4-byte multiple" lump start position requirement
		local dummyBytes = streamDst:Tell() % 4
		if dummyBytes ~= 0 then
			streamDst:Write(string.rep("\0", dummyBytes))
		end
	end,
	
	_writeAutoOffset4AndJumpEnd = function(self, streamDst, payloadRoom, noMoveToEnd, noFillWithZeroes, totalLength)
		-- 1- Seek to the end of the destination file if payloadRoom is insufficient
		-- 2- Skip bytes to set the offset to a multiple of 4
		-- payloadRoom: max length in bytes or nil
		-- return 1: false if noMoveToEnd constraint failed
		-- return 2: true if filling with zeroes
		local okayConstraint = true
		local fillWithZeroes = false
		if payloadRoom == nil then
			-- unconstrained room (writing in an LUMP_GAME_LUMP at the end of the file or in a separate lump file)
			self:_addOffsetMultiple4(streamDst)
		elseif payloadRoom <= 0 or payloadRoom < totalLength then
			-- lump not present in source map OR lump too big OR no space left (game lump)
			-- Note: 0 is rare but possible when no space left for another game lump.
			if noMoveToEnd then
				okayConstraint = false
			else
				streamDst:Seek(streamDst:Size()) -- to EOF
				self:_addOffsetMultiple4(streamDst)
				if not noFillWithZeroes then
					fillWithZeroes = true
				end
			end
		end
		return okayConstraint, fillWithZeroes
	end,
	
	_fillWithZeroes = function(cls, streamDst, length) -- static method
		local remainingBytes = length
		while remainingBytes > 0 do
			local toWrite_bytes = math.min(BUFFER_LENGTH, remainingBytes)
			local buffer = FULL_ZERO_BUFFER
			if toWrite_bytes ~= BUFFER_LENGTH then
				buffer = string.rep("\0", toWrite_bytes) -- expensive!
			end
			streamDst:Write(buffer)
			remainingBytes = remainingBytes - toWrite_bytes
		end
	end,
	
	copyTo = function(self, streamDst, withCompression, payloadRoom, noMoveToEnd, noFillWithZeroes, standardLzmaHeader)
		-- Copy the current lump from self.streamSrc to streamDst
		-- payloadRoom: room for the payload (filelen in the source map) otherwise moved to end, or nil
		-- noMoveToEnd: for game lumps, which should not be out of the LUMP_GAME_LUMP
		-- noFillWithZeroes: for game lumps, do not fill with 0's to fill payloadRoom
		-- return: a new lump_t or derived / false if noMoveToEnd constraint failed
		
		local okayConstraint, fillWithZeroes
		if withCompression == nil then
			withCompression = self.compressed
		end
		-- If standardLzmaHeader and withCompression and self.compressed, the process cannot be a stream-to-stream copy, so the call is passed to writeTo().
		if withCompression == self.compressed and not (standardLzmaHeader and self.compressed) then
			-- Just copy:
			local filelen = self.lumpInfoSrc.filelen
			local remainingBytes = filelen
			okayConstraint, fillWithZeroes = self:_writeAutoOffset4AndJumpEnd(streamDst, payloadRoom, noMoveToEnd, noFillWithZeroes, remainingBytes)
			if not okayConstraint then
				return false
			end
			local fileofs = streamDst:Tell()
			self.streamSrc:Seek(self.offset)
			while remainingBytes > 0 do
				local toRead_bytes = math.min(BUFFER_LENGTH, remainingBytes)
				streamDst:Write(self.streamSrc:Read(toRead_bytes))
				remainingBytes = remainingBytes - toRead_bytes
			end
			if fillWithZeroes then
				self:_fillWithZeroes(streamDst, payloadRoom - filelen)
			end
			self.lumpInfoDst = self.lumpInfoType:new(self.context, nil, self, nil, fileofs, filelen)
		else
			-- Compress or decompress then copy:
			if not self:writeTo(streamDst, withCompression, payloadRoom, noMoveToEnd, noFillWithZeroes, standardLzmaHeader) then
				return false
			end
		end
		return self.lumpInfoDst
	end,
	
	writeTo = function(self, streamDst, withCompression, payloadRoom, noMoveToEnd, noFillWithZeroes, standardLzmaHeader)
		-- Write the given lump payload (which must be for self) into streamDst
		-- payload: uncompressed lump content
		-- payloadRoom: room for the payload (filelen in the source map) otherwise moved to end, or nil
		-- return: a new lump_t or derived / false if noMoveToEnd constraint failed
		local payload
		local fileofs = streamDst:Tell()
		local uncompressedBytes
		local cursorBytes = 1
		local remainingBytes
		local finalPayload
		local filelen
		local okayConstraint, fillWithZeroes
		if withCompression then
			local payloadCompressed
			local compressedBytes
			if self.compressed then
				payload = nil
				if standardLzmaHeader then
					payloadCompressed = lzmaVbspToStandard(self:readAll(true))
				else
					payloadCompressed = self:readAll(true)
				end
				uncompressedBytes = data_to_le(string.sub(payloadCompressed, 5, 8)) -- actualSize
			else
				payload = self:readAll()
				if standardLzmaHeader then
					payloadCompressed = util.Compress(payload)
				else
					payloadCompressed = lzmaStandardToVbsp(self.context, util.Compress(payload))
				end
				uncompressedBytes = #payload
			end
			compressedBytes = #payloadCompressed
			filelen = compressedBytes
			okayConstraint, fillWithZeroes = self:_writeAutoOffset4AndJumpEnd(streamDst, payloadRoom, noMoveToEnd, noFillWithZeroes, filelen)
			if not okayConstraint then
				return false
			end
			remainingBytes = compressedBytes
			finalPayload = payloadCompressed
		else
			payload = self:readAll()
			uncompressedBytes = #payload
			filelen = uncompressedBytes
			okayConstraint, fillWithZeroes = self:_writeAutoOffset4AndJumpEnd(streamDst, payloadRoom, noMoveToEnd, noFillWithZeroes, filelen)
			if not okayConstraint then
				return false
			end
			remainingBytes = uncompressedBytes
			finalPayload = payload
		end
		payload = nil
		while remainingBytes > 0 do
			local bytesToWrite = math.min(BUFFER_LENGTH, remainingBytes)
			streamDst:Write(string.sub(finalPayload, cursorBytes, cursorBytes + bytesToWrite - 1))
			remainingBytes = remainingBytes - bytesToWrite
			cursorBytes = cursorBytes + bytesToWrite
		end
		if fillWithZeroes then
			self:_fillWithZeroes(streamDst, payloadRoom - filelen)
		end
		self.lumpInfoDst = self.lumpInfoType:new(self.context, nil, self, nil, fileofs, filelen)
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
	
	erasePrevious = function(cls, context, streamDst, lumpInfo) -- static method
		-- Erase a lump payload with null-bytes to save space
		-- TODO - mark this space as available for added lumps
		
		local remainingBytes = lumpInfo.filelen
		if remainingBytes > 0 and lumpInfo.fileofs > 0 then
			streamDst:Seek(lumpInfo.fileofs)
			while remainingBytes > 0 do
				local toWrite_bytes = math.min(BUFFER_LENGTH, remainingBytes)
				local buffer = FULL_ZERO_BUFFER
				if toWrite_bytes ~= BUFFER_LENGTH then
					buffer = string.rep("\0", toWrite_bytes) -- expensive!
				end
				streamDst:Write(buffer)
				remainingBytes = remainingBytes - toWrite_bytes
			end
		end
	end,
})
LumpPayload.__index = LumpPayload

dgamelump_t = false -- defined later

local GameLumpPayload = LumpPayload:newClass({
	-- Wrapper around a game lump payload
	-- No content is held in here.
	-- Unsupported: console version of Portal 2 (fileofs is not absolute)
	
	lumpInfoType = dgamelump_t, -- static; nil for now (filled after dgamelump_t definition)
	
	new = function(cls, context, streamSrc, lumpInfo)
		-- This constructor must have the same arguments as LumpPayload:new() because it is called in LumpPayload & lump_t with class resolution.
		local instance = LumpPayload:new(context, streamSrc, lumpInfo)
		setmetatable(instance, cls)
		return instance
	end,
})
GameLumpPayload.__index = GameLumpPayload

lump_t = BaseDataStructure:newClass({
	-- Note: the default attributes must be those of a null lump_t.
	-- This class & its children are referred to in this file as: (lump_t|dgamelump_t|lumpInfoType)
	
	payloadType = LumpPayload, -- static
	
	fileofs = 0,
	filelen = 0,
	version = 0, -- valid value
	fourCC = 0, -- valid value
	payload = nil,
	
	new = function(cls, context, streamSrc, payload, other, fileofs, filelen, _noReadInherit)
		-- Usage 1: lump_t:new(context, streamSrc)
		--  Load a lump_t from the current position in streamSrc
		-- Usage 2: lump_t:new(context, nil, payload, nil, fileofs=0, filelen=payload.lumpInfoSrc.filelen)
		--  Make a lump_t for a written LumpPayload (in a destination stream), implying another lump_t
		-- Usage 3: lump_t:new(context, nil, false)
		--  Make a lump_t for a written null LumpPayload (in a destination stream)
		-- Usage 4: lump_t:new(context, nil, nil, other, fileofs=0)
		--  Make a lump_t from another lump_t, for writing into a destination stream
		-- The file cursor must be at the end of the lump_t when returning.
		local instance = BaseDataStructure:new(context, streamSrc, nil)
		setmetatable(instance, cls)
		
		if streamSrc ~= nil then
			if not _noReadInherit then
				instance.fileofs = context.data_to_integer(streamSrc:Read(4))
				instance.filelen = context.data_to_integer(streamSrc:Read(4))
				instance.version = context.data_to_integer(streamSrc:Read(4))
				instance.fourCC = context.data_to_integer(streamSrc:Read(4))
				local lumpIsUsed = (
					instance.fileofs ~= 0 and
					instance.filelen ~= 0
				)
				if lumpIsUsed then
					local streamPos = streamSrc:Tell()
					instance.payload = LumpPayload:new(context, streamSrc, instance)
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
	
	newFromPayloadStream = function(cls, context, streamSrc, fileofs, filelen, lumpInfoSrc) -- static method
		-- Usage: lump_t:newFromPayloadStream(context, streamSrc, fileofs, filelen, lumpInfoSrc=nil)
		--  Make a lump_t from its characteristics only
		--  This is especially useful when there is no lump_t in the file that contains it.
		local instance = BaseDataStructure:new(context, streamSrc, nil)
		setmetatable(instance, cls)
		
		instance.fileofs = fileofs
		instance.filelen = filelen
		if lumpInfoSrc then
			instance.version = lumpInfoSrc.version
			instance.fourCC = lumpInfoSrc.fourCC
		end
		instance.payload = cls.payloadType:new(context, streamSrc, instance)
		
		return instance
	end,
	
	skipThem = function(cls, context, streamDst, numberOfItems) -- static method
		-- Skip numberOfItems lump_t items in streamDst
		streamDst:Skip(16 * numberOfItems)
	end,
	
	writeTo = function(self, streamDst)
		streamDst:Write(self.context.int32_to_data(self.fileofs))
		streamDst:Write(self.context.int32_to_data(self.filelen))
		streamDst:Write(self.context.int32_to_data(self.version))
		streamDst:Write(self.context.int32_to_data(self.fourCC))
	end,
})
lump_t.__index = lump_t

dgamelump_t = lump_t:newClass({
	-- Note: the default attributes must be those of a null dgamelump_t.
	
	payloadType = GameLumpPayload, -- static
	
	id = 0,
	flags = 0,
	
	new = function(cls, context, streamSrc, payload, other, fileofs, filelen)
		-- Usage 1: dgamelump_t:new(context, streamSrc)
		--  Load a dgamelump_t from the current position in streamSrc
		-- Usage 2: dgamelump_t:new(context, nil, payload, nil, fileofs=0, filelen=payload.lumpInfoSrc.filelen)
		--  Make a dgamelump_t for a written GameLumpPayload (in destination stream), implying another dgamelump_t
		-- Usage 3: dgamelump_t:new(context, nil, false)
		--  Make a dgamelump_t for a written null GameLumpPayload (in a destination stream)
		-- Usage 4: dgamelump_t:new(context, nil, nil, other, fileofs=0)
		--  Make a dgamelump_t from another dgamelump_t, for writing into a destination stream
		-- The file cursor must be at the end of the dgamelump_t when returning.
		local instance = lump_t:new(context, streamSrc, payload, other, fileofs, filelen, true)
		setmetatable(instance, cls)
		
		if streamSrc ~= nil then
			instance.id = context.data_to_integer(streamSrc:Read(4))
			instance.flags = context.data_to_integer(streamSrc:Read(2))
			instance.version = context.data_to_integer(streamSrc:Read(2))
			instance.fileofs = context.data_to_integer(streamSrc:Read(4))
			instance.filelen = context.data_to_integer(streamSrc:Read(4))
			local lumpIsUsed = (
				instance.fileofs ~= 0 and
				instance.filelen ~= 0
			)
			if lumpIsUsed then
				local streamPos = streamSrc:Tell()
				instance.payload = GameLumpPayload:new(context, streamSrc, instance)
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
	
	newFromPayloadStream = function(cls, context, streamSrc, fileofs, filelen, lumpInfoSrc, id)
		-- Usage: dgamelump_t:newFromPayloadStream(context, streamSrc, fileofs, filelen, lumpInfoSrc=nil, id=nil)
		--  Make a dgamelump_t from its characteristics only
		--  This is especially useful when there is no dgamelump_t in the file that contains it.
		local instance = lump_t:newFromPayloadStream(context, streamSrc, fileofs, filelen, lumpInfoSrc)
		setmetatable(instance, cls)
		
		if lumpInfoSrc then
			instance.id = lumpInfoSrc.id
			instance.flags = lumpInfoSrc.flags
		end
		if id ~= nil then
			instance.id = id
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
		streamDst:Write(self.context.int32_to_data(self.id))
		streamDst:Write(self.context.int16_to_data(self.flags))
		streamDst:Write(self.context.int16_to_data(self.version))
		streamDst:Write(self.context.int32_to_data(self.fileofs))
		streamDst:Write(self.context.int32_to_data(self.filelen))
	end,
})
dgamelump_t.__index = dgamelump_t

LumpPayload.lumpInfoType = lump_t
GameLumpPayload.lumpInfoType = dgamelump_t

local HEADER_LUMPS = 64

local dheader_t = BaseDataStructure:newClass({
	-- Structure that represents the header of a .bsp file
	
	context = nil,
	ident = nil,
	version = nil,
	lumps = nil,
	mapRevision = nil,
	
	new = function(cls, context, streamSrc, other, lumps)
		-- Usage 1: dheader_t:new(context, streamSrc)
		--  Load a dheader_t from the position 0 in streamSrc
		-- Usage 2: dheader_t:new(context, nil, other, lumps)
		--  Make a dheader_t from another dheader_t with the optional specified array of lump_t, for writing into a destination stream
		local instance = BaseDataStructure:new(context, streamSrc, 0)
		setmetatable(instance, cls)
		
		if streamSrc ~= nil then
			local ident = streamSrc:Read(4)
			if ident == "VBSP" or ident == "rBSP" then
				context.data_to_integer = data_to_le
				context.int32_to_data = int32_to_le_data
				context.int16_to_data = int16_to_le_data
			elseif ident == "PSBV" or ident == "PSBr" then
				context.data_to_integer = data_to_be
				context.int32_to_data = int32_to_be_data
				context.int16_to_data = int16_to_be_data
			else
				context.data_to_integer = nil
				context.int32_to_data = nil
				context.int16_to_data = nil
				error([[The "VBSP" magic header was not found. This map does not seem to be a valid Source Engine map.]])
			end
			
			instance.ident = ident
			instance.version = context.data_to_integer(streamSrc:Read(4))
			instance.lumps = {}
			for i = 1, HEADER_LUMPS do
				-- local cursorBefore = streamSrc:Tell()
				table.insert(instance.lumps, lump_t:new(context, streamSrc))
				-- local readBytes = streamSrc:Tell() - cursorBefore
				-- if readBytes ~= 16 then
					-- error("Read " .. tostring(readBytes) .. " bytes in lump_t instead of 16")
				-- end
			end
			instance.mapRevision = context.data_to_integer(streamSrc:Read(4))
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
		streamDst:Write(self.context.int32_to_data(self.version))
		for i = 1, HEADER_LUMPS do
			self.lumps[i]:writeTo(streamDst)
		end
		streamDst:Write(self.context.int32_to_data(self.mapRevision))
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
	-- TODO - éliminer lumpIndexesToCompress si inutile, remplacer par un booléen commun
	
	filenameSrc = nil, -- source file path
	streamSrc = nil, -- source file stream
	bspHeader = nil, -- dheader_t object
	lumpsSrc = nil, -- list of lump_t objects from the source map file
	gameLumpsSrc = nil, -- list of dgamelump_t objects from the source map file
	lumpsDst = nil, -- list of lump_t objects selected for the destination map file
	gameLumpsDst = nil, -- list of dgamelump_t objects selected for the destination map file
	lumpIndexesToCompress = nil, -- nil / false / true; setting for LUMP_GAME_LUMP is common for all game lumps
	entitiesTextLua = nil, -- exported entities to Lua script
	
	-- to be set upon .bsp load
	data_to_integer = nil, -- instance's function
	int32_to_data = nil, -- instance's function
	int16_to_data = nil, -- instance's function
	
	new = function(cls, filenameSrc)
		local instance = {}
		setmetatable(instance, cls)
		
		if FULL_ZERO_BUFFER == nil then
			FULL_ZERO_BUFFER = string.rep("\0", BUFFER_LENGTH)
		end
		
		instance.filenameSrc = filenameSrc
		instance.streamSrc = file.Open(filenameSrc, "rb", "GAME")
		if instance.streamSrc == nil then
			error("Unable to open " .. filenameSrc)
		end
		
		instance.bspHeader = dheader_t:new(instance, instance.streamSrc)
		
		instance.lumpsSrc = instance.bspHeader.lumps
		
		instance.gameLumpsSrc = {}
		local gameLumpPayload = instance.lumpsSrc[lumpNameToLuaIndex["LUMP_GAME_LUMP"]].payload
		if gameLumpPayload ~= nil then
			-- No worry about compression because the whole game lump fortunately cannot be compressed.
			gameLumpPayload:seekToPayload()
			for i = 1, instance.data_to_integer(instance.streamSrc:Read(4)) do
				table.insert(instance.gameLumpsSrc, dgamelump_t:new(instance, instance.streamSrc))
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
		
		self:_closeAllLumpStreams()
		
		self.lumpsDst = {}
		for i = 1, #self.lumpsSrc do
			-- table.insert(self.lumpsDst, lump_t:new(self, nil, nil, self.lumpsSrc[i]))
			table.insert(self.lumpsDst, self.lumpsSrc[i])
		end
		
		self.gameLumpsDst = {}
		for i = 1, #self.gameLumpsSrc do
			-- table.insert(self.gameLumpsDst, dgamelump_t:new(self, nil, nil, self.gameLumpsSrc[i]))
			table.insert(self.gameLumpsDst, self.gameLumpsSrc[i])
		end
	end,
	
	anyCompressedInGameLumps = function(cls, gameLumps) -- static method
		-- gameLumps: gameLumpsSrc or gameLumpsDst
		local hasCompressedLumps = false
		for i = 1, #gameLumps do
			local payload = gameLumps[i].payload
			if payload and payload.compressed then
				hasCompressedLumps = true
				break
			end
		end
		return hasCompressedLumps
	end,
	
	writeNewBsp_ = function(self, streamDst)
		-- Internal
		
		-- Do local copies of lump arrays to allow future calls to writeNewBsp():
		local lumpsDst = {}
		for i = 1, #self.lumpsDst do
			lumpsDst[i] = self.lumpsDst[i]
		end
		local gameLumpsDst = {}
		for i = 1, #self.gameLumpsDst do
			gameLumpsDst[i] = self.gameLumpsDst[i]
		end
		
		-- Copy the whole source file map into the destination map
		self.streamSrc:Seek(0)
		do
			local remainingBytes = self.streamSrc:Size()
			while remainingBytes > 0 do
				local toRead_bytes = math.min(BUFFER_LENGTH, remainingBytes)
				streamDst:Write(self.streamSrc:Read(toRead_bytes))
				remainingBytes = remainingBytes - toRead_bytes
			end
		end
		
		-- At this point, lumpsDst & gameLumpsDst contains lumps from self.streamSrc or external sources, with a possibly wrong fileofs.
		local LUMP_GAME_LUMP = lumpNameToLuaIndex.LUMP_GAME_LUMP
		local LUMP_PAKFILE = lumpNameToLuaIndex.LUMP_PAKFILE
		local LUMP_XZIPPAKFILE = lumpNameToLuaIndex.LUMP_XZIPPAKFILE
		for _, i in ipairs(lumpIndexesOrderedFromOffset(self.lumpsSrc)) do
			-- Works fine because same number of elements in lumpsSrc & lumpsDst
			print("\tProcessing " .. lumpLuaIndexToName[i])
			
			local bypassIdentical = true -- ignores self.lumpIndexesToCompress[i] on purpose
			if i == LUMP_GAME_LUMP then
				for j = 1, math.max(#gameLumpsDst, #self.gameLumpsSrc) do
					if gameLumpsDst[j] ~= self.gameLumpsSrc[j] then
						bypassIdentical = false
						break
					end
				end
			else
				if lumpsDst[i] ~= self.lumpsSrc[i] then
					bypassIdentical = false
				end
			end
			
			if not bypassIdentical then
				print("\t\tModified!")
				local withCompression = self.lumpIndexesToCompress[i] -- true / false / nil
				if i == LUMP_GAME_LUMP then
					-- There is no LumpPayload object involved to write the LUMP_GAME_LUMP itself.
					-- Note: the trailing null game lump must naturally always be at the end.
					--  But there is no need to ensure it: game lumps may be removed or replaced, but never added.
					-- Note: if all game lumps are removed, there simply will be 0 game lumps in the LUMP_GAME_LUMP.
					
					-- Handle the need of a null game lump if compressed game lumps:
					if #gameLumpsDst ~= 0 then
						-- withCompression is common because I decided it is common to all game lumps.
						if withCompression == nil then
							-- I have decided that if one game lump is compressed then they will all be.
							withCompression = self:anyCompressedInGameLumps(gameLumpsDst)
						end
						local lastGLump = gameLumpsDst[#gameLumpsDst]
						if withCompression then
							-- Add a trailing null gamelump if not present:
							if lastGLump.filelen ~= 0 then
								table.insert(gameLumpsDst, dgamelump_t:new(self, nil, false))
							end
						else
							-- Remove the trailing null gamelump if present:
							if lastGLump.filelen == 0 then
								gameLumpsDst[#gameLumpsDst] = nil
							end
						end
					end
					
					local fitsInRoom
					local lump
					local startOfLumpsArray
					for fitsInRoom_ = 1, 0, -1 do
						fitsInRoom = tobool(fitsInRoom_)
						local jumpNoFit = false -- jump to next iteration
						if fitsInRoom then
							-- try to stick to the initial payload room
							streamDst:Seek(self.lumpsSrc[i].fileofs)
						else
							-- move to the end
							streamDst:Seek(streamDst:Size())
							GameLumpPayload:_addOffsetMultiple4(streamDst)
						end
						
						-- Write the number of game lumps:
						lump = lump_t:new(self, nil, nil, self.lumpsSrc[i], streamDst:Tell())
						lumpsDst[i] = lump
						streamDst:Write(self.int32_to_data(#gameLumpsDst))
						
						-- Skip the array of dgamelump_t's because not ready yet:
						startOfLumpsArray = streamDst:Tell()
						dgamelump_t:skipThem(self, streamDst, #gameLumpsDst)
						
						-- Write the game lump payloads:
						local lastGamelumpMaxOffset
						if fitsInRoom then
							lastGamelumpMaxOffset = self.lumpsSrc[i].fileofs + self.lumpsSrc[i].filelen
						end
						for j = 1, #gameLumpsDst do
							collectgarbage()
							print("\t\tProcessing game lump " .. int32_to_be_data(gameLumpsDst[j].id))
							local payload = gameLumpsDst[j].payload
							if payload ~= nil then
								if fitsInRoom then
									local payloadRoom = lastGamelumpMaxOffset - streamDst:Tell()
									if not payload:copyTo(streamDst, withCompression, payloadRoom, true, true) then
										jumpNoFit = true
										-- Warning: compressing or decompressing game lumps will be done again.
										print("Not enough room in the original LUMP_GAME_LUMP!")
										break
									end
								else
									payload:copyTo(streamDst, withCompression, nil)
								end
								if not jumpNoFit then
									gameLumpsDst[j] = payload.lumpInfoDst
								end
							else
								-- null game lump
								gameLumpsDst[j] = dgamelump_t:new(self, nil, false)
							end
						end
						if not jumpNoFit then
							break -- okay good!
						else
							LumpPayload:erasePrevious(self, streamDst, self.lumpsSrc[i])
						end
					end
					
					local endOfLump = streamDst:Tell()
					lump.filelen = endOfLump - lump.fileofs
					if fitsInRoom then
						LumpPayload:_fillWithZeroes(streamDst, self.lumpsSrc[i].filelen - lump.filelen)
					end
					
					-- Write the array of dgamelump_t's:
					streamDst:Seek(startOfLumpsArray)
					for j = 1, #gameLumpsDst do
						gameLumpsDst[j]:writeTo(streamDst)
					end
					
					-- Seek to the end of the whole LUMP_GAME_LUMP:
					streamDst:Seek(endOfLump)
				else
					collectgarbage()
					local payload = lumpsDst[i].payload
					if payload ~= nil then
						-- The lump to copy from has a payload.
						streamDst:Seek(self.lumpsSrc[i].fileofs) -- 0 if initially absent, written ok at the end
						payload:copyTo(streamDst, withCompression, self.lumpsSrc[i].filelen)
						lumpsDst[i] = payload.lumpInfoDst
					else
						-- The lump to copy is a null payload.
						if self.lumpsSrc[i].payload ~= nil then
							LumpPayload:erasePrevious(self, streamDst, self.lumpsSrc[i])
						end
						lumpsDst[i] = lump_t:new(self, nil, false)
					end
				end
			end
		end
		-- Now lumpsDst & gameLumpsDst contain lumps in streamDst, with the effective fileofs.
		
		-- Write the file header (including lump_t's)
		local bspHeaderDst = dheader_t:new(self, nil, self.bspHeader, lumpsDst)
		bspHeaderDst:writeTo(streamDst)
	end,
	
	_writeEntitiesTextLua = function(self, mapFilenameDst)
		if self.entitiesTextLua then
			collectgarbage()
			local entitiesTextLua = self.entitiesTextLua
			local _, _, mapName = string.find(mapFilenameDst, "([^\\/]+)%.bsp%.dat$")
			if mapName then
				entitiesTextLua = string.gsub(entitiesTextLua, "%%mapName%%", stringToLuaString(mapName), 1)
			end
			local filenameDst = string.gsub(mapFilenameDst, "%.bsp%.dat$", "", 1) .. ".lua.txt"
			local streamDst = file.Open(filenameDst, "w", "DATA")
			if streamDst then
				callSafe(streamDst.Write, streamDst, entitiesTextLua)
				streamDst:Close()
			else
				error('Unable to open "' .. filenameDst .. '" for write')
			end
		end
	end,
	
	writeNewBsp = function(self, filenameDst)
		-- Note: compression / decompression is not applied if a lump is unchanged.
		
		local streamDst = file.Open(filenameDst, "wb", "DATA")
		if streamDst == nil then
			error("Unable to open data/" .. filenameDst .. " for write")
		end
		
		local success, message = callSafe(self.writeNewBsp_, self, streamDst)
		streamDst:Close()
		if not success then
			error(message)
		end
		
		self:_writeEntitiesTextLua(filenameDst)
	end,
	
	_getLump = function(self, isGameLump, id, fromDst)
		-- This method can return nil.
		
		local lumpInfo
		local lumps
		if isGameLump then
			lumps = fromDst and self.gameLumpsDst or self.gameLumpsSrc
			for i, lumpInfoCurrent in ipairs(lumps) do
				if lumpInfoCurrent.id == id then
					lumpInfo = lumpInfoCurrent
					break
				end
			end
		else
			lumps = fromDst and self.lumpsDst or self.lumpsSrc
			lumpInfo = lumps[id]
		end
		return lumpInfo
	end,
	
	_copyLumpFieldsFromSrc = function(self, isGameLump, id, lumpInfo)
		-- Alter lumpInfo with information from self.lumpsSrc & self.gameLumpsSrc
		
		local lumpInfoSrc = self:_getLump(isGameLump, id, false)
		if lumpInfoSrc ~= nil then
			-- The replacement can always occur because the lump format is maintained in all cases.
			lumpInfo.version = lumpInfoSrc.version
			-- lumpInfo.fourCC is let as-is to keep the code simple.
			lumpInfo.id = lumpInfoSrc.id
			lumpInfo.flags = lumpInfoSrc.flags
		end
	end,
	
	_setDstLump = function(self, isGameLump, id, lumpInfo)
		-- Replace a lump in self.lumpsDst or self.gameLumpsDst
		-- Must be called to apply the lumpInfo into the destination lumps
		-- lumpInfo: can be nil if isGameLump, for game lump removal
		
		local lumpInfoOld
		if isGameLump then
			local gameLumpIndex = #self.gameLumpsDst + 1 -- append if existing not found
			for i, lumpInfoCurrent in ipairs(self.gameLumpsDst) do
				if lumpInfoCurrent.id == id then
					gameLumpIndex = i
					lumpInfoOld = lumpInfoCurrent
					break
				end
			end
			if lumpInfo then
				self.gameLumpsDst[gameLumpIndex] = lumpInfo
			else
				table.remove(self.gameLumpsDst, gameLumpIndex)
			end
		else
			lumpInfoOld = self.lumpsDst[id]
			self.lumpsDst[id] = lumpInfo
		end
		self:_closeOldLumpStream(lumpInfoOld)
	end,
	
	revertLumpChanges = function(self, isGameLump, id)
		-- Revert modifications done to a lump
		local lumpInfoOld
		if isGameLump then
			local lumpInfoSrc
			for i = 1, #self.gameLumpsSrc do
				local lumpInfo = self.gameLumpsSrc[i]
				if lumpInfo.id == id then
					lumpInfoSrc = lumpInfo
					break
				end
			end
			local foundInDst = false
			for i = 1, #self.gameLumpsDst do
				local lumpInfo = self.gameLumpsDst[i]
				if lumpInfo.id == id then
					foundInDst = true
					lumpInfoOld = lumpInfo
					if lumpInfoSrc then
						self.gameLumpsDst[i] = lumpInfoSrc
					else
						table.remove(self.gameLumpsDst, i)
					end
					break
				end
			end
			if not foundInDst and lumpInfoSrc then
				self.gameLumpsDst[#self.gameLumpsDst + 1] = lumpInfoSrc
			end
		else
			lumpInfoOld = self.lumpsDst[id]
			self.lumpsDst[id] = self.lumpsSrc[id]
			self.lumpIndexesToCompress[id] = nil
		end
		self:_closeOldLumpStream(lumpInfoOld)
	end,
	
	clearLump = function(self, isGameLump, id)
		local lumpInfo
		if isGameLump then
			-- Game lumps must be removed instead of being replaced with a null lump.
			lumpInfo = nil
		else
			lumpInfo = lump_t:new(self, nil, false)
		end
		if lumpInfo then
			self:_copyLumpFieldsFromSrc(isGameLump, id, lumpInfo)
		end
		self:_setDstLump(isGameLump, id, lumpInfo)
		return lumpInfo
	end,
	
	setLumpCompressed = function(self, id, toCompress)
		-- Set the desired state of compression for the given lump
		-- This does not work on individual game lumps because game lump compression is common to all game lumps.
		-- Note: if at least 1 game lump is seen compressed (even in the original map) then all game lumps will be compressed.
		self.lumpIndexesToCompress[id] = toCompress
	end,
	
	_setupLumpFromHeaderlessStream = function(self, isGameLump, id, streamSrc)
		-- Make a lump_t or a dgamelump_t for the specified headerless stream
		-- The stream responsibility is given to the context, so it must be open for that occasion.
		
		local lumpInfo
		local lumpInfoSrc = self:_getLump(isGameLump, id, false)
		if isGameLump then
			lumpInfo = dgamelump_t:newFromPayloadStream(self, streamSrc, 0, streamSrc:Size(), lumpInfoSrc, id)
		else
			lumpInfo = lump_t:newFromPayloadStream(self, streamSrc, 0, streamSrc:Size(), lumpInfoSrc)
		end
		self:_copyLumpFieldsFromSrc(isGameLump, id, lumpInfo)
		self:_setDstLump(isGameLump, id, lumpInfo)
		return lumpInfo
	end,
	
	setupLumpFromHeaderlessFile = function(self, isGameLump, id, filePath)
		local streamSrc = file.Open(filePath, "rb", "GAME")
		return self:_setupLumpFromHeaderlessStream(isGameLump, id, streamSrc)
	end,
	
	setupLumpFromHeaderlessString = function(self, isGameLump, id, payloadString)
		local streamSrc = BytesIO:new(payloadString, "rb")
		return self:_setupLumpFromHeaderlessStream(isGameLump, id, streamSrc)
	end,
	
	setupLumpFromLumpFile = function(self, isGameLump, id, filePath)
		-- TODO
		-- TODO - détection du boutisme et erreur si différent
		error("Not implemented yet")
	end,
	
	setupLumpFromText = function(self, isGameLump, id, text)
		local payloadString
		local idText = getLumpNameFromLumpId(isGameLump, id)
		if isGameLump then
			if idText == "sprp" then
				-- TODO
				-- TODO - objet(s) supplémentaire(s) avec méta-informations
				error('Not supported yet: Game Lump "sprp"')
			else
				error('Unsupported conversion from text to Game Lump "' .. tostring(idText or id) .. '"')
			end
		else
			if idText == "LUMP_ENTITIES" then
				payloadString = string.gsub(text, "\r\n", "\n") .. "\0" -- may take some time
			elseif idText == "LUMP_TEXDATA_STRING_DATA" then
				-- TODO
				error('Not supported yet: Lump "LUMP_TEXDATA_STRING_DATA"')
			elseif idText == "LUMP_OVERLAYS" then
				-- TODO
				error('Not supported yet: Lump "LUMP_OVERLAYS"')
			else
				error('Unsupported conversion from text to Lump "' .. tostring(idText or id) .. '"')
			end
		end
		text = nil -- hoping to save memory
		return self:setupLumpFromHeaderlessString(isGameLump, id, payloadString)
	end,
	
	setupLumpFromTextFile = function(self, isGameLump, id, filePath)
		local textFile = file.Open(filePath, "rb", "GAME")
		local text = textFile:Read(textFile:Size())
		textFile:Close()
		return self:setupLumpFromText(isGameLump, id, text)
	end,
	
	extractLumpAsHeaderlessFile = function(self, isGameLump, id, fromDst, filePath, withCompression)
		local idText = getLumpNameFromLumpId(isGameLump, id)
		local lumpInfo = self:_getLump(isGameLump, id, fromDst)
		local payload = lumpInfo.payload
		if payload ~= nil then
			local streamDst = file.Open(filePath, "wb", "DATA")
			callSafe(payload.copyTo, payload, streamDst, withCompression, nil, nil, nil, true)
			streamDst:Close()
		else
			error("The specified lump is a null lump!")
		end
	end,
	
	extractLumpAsText = function(self, isGameLump, id, fromDst)
		local idText = getLumpNameFromLumpId(isGameLump, id)
		local lumpInfo = self:_getLump(isGameLump, id, fromDst)
		local payload = lumpInfo.payload
		if payload == nil then
			error("The specified lump is a null lump!")
		end
		local text
		if isGameLump then
			if idText == "sprp" then
				-- TODO
				-- TODO - objet(s) supplémentaire(s) avec méta-informations
				error('Not supported yet: Game Lump "sprp"')
			else
				error('Unsupported conversion to text from Game Lump "' .. tostring(idText or id) .. '"')
			end
		else
			if idText == "LUMP_ENTITIES" then
				local _
				_, _, text = string.find(payload:readAll(), "^([^%z]+)") -- closer to engine's behavior
				--[[
				if string.sub(payloadString, -1, -1) == "\0" then -- ends with a null byte
					text = string.sub(payloadString, 1, -2) -- remove the ending null byte
				end
				]]
			elseif idText == "LUMP_TEXDATA_STRING_DATA" then
				-- TODO
				error('Not supported yet: Lump "LUMP_TEXDATA_STRING_DATA"')
			elseif idText == "LUMP_OVERLAYS" then
				-- TODO - extraction textuelle avec traduction du matériau (pas id) et erreur si import erroné, format similaire à info_overlay
				error('Not supported yet: Lump "LUMP_OVERLAYS"')
			else
				error('Unsupported conversion to text from Lump "' .. tostring(idText or id) .. '"')
			end
		end
		return text
	end,
	
	extractLumpAsTextFile = function(self, isGameLump, id, fromDst, filePath)
		local text = self:extractLumpAsText(isGameLump, id, fromDst)
		local streamDst = file.Open(filePath, "wb", "DATA")
		callSafe(streamDst.Write, streamDst, text)
		streamDst:Close()
	end,
	
	moveEntitiesToLua = function(self)
		-- Move the content of the LUMP_ENTITIES into a lua/autorun/server/ script
		
		local ipairs = ipairs
		local string_find = string.find
		local string_sub = string.sub
		local util_KeyValuesToTablePreserveOrder = util.KeyValuesToTablePreserveOrder
		local hook_Run = hook.Run
		local table_remove = table.remove
		local lumpContent = self:extractLumpAsText(false, lumpNameToLuaIndex.LUMP_ENTITIES, true)
		local mapInfo = self:getInfoMap()
		local mapTitle = mapInfo.title
		local entitiesText = {}
		do
			local posStart, posEnd, entityText = 1, nil, nil
			repeat
				posStart, posEnd, entityText = string_find(lumpContent, "^({\x0A.-\x0A}\x0A)", posStart)
				entitiesText[#entitiesText + 1] = entityText
				posStart = (posEnd or -1) + 1
			until not posEnd
		end
		
		-- local presentClassNames = {}
		-- local presentClassNamesNoModel = {}
		local classNamesInLua = {}
		local classNamesInLump = {}
		local entitiesTextKeptInLump = {}
		local targetnamesToEntityIndexes = {} -- indexes from entitiesText
		local entityIndexesToParentname = {} -- indexes from entitiesText
		local targetnamesWithChildren = {} -- useless because single loop design
		local entitiesTextLua = {
			[[-- Generated by Momo's Map Manipulation Tool]],
			[[]],
			[[local mapName = %mapName%]],
			[[if string.lower( game.GetMap() ) == string.lower( mapName ) then]],
			[[	local ents_Create = ents.Create]],
			[[	local IsValid = IsValid]],
			[[	local Entity = FindMetaTable( "Entity" )]],
			[[	local ent_SetKeyValue = Entity.SetKeyValue]],
			[[	local ent_Spawn = Entity.Spawn]],
			[[	local ent_Activate = Entity.Activate]],
			[[	]],
			[[	local entitiesByMap = {}]],
			[[	do]],
			[[		local old_CreatedByMap = Entity.CreatedByMap]],
			[[		function Entity:CreatedByMap( ... )]],
			[[			return entitiesByMap[self] or old_CreatedByMap( self, ... )]],
			[[		end]],
			[[	end]],
			[[	local entityToHammerid = {}]],
			[[	do]],
			[[		local old_MapCreationID = Entity.MapCreationID]],
			[[		function Entity:MapCreationID( ... )]],
			[[			return entityToHammerid[self] or old_MapCreationID( self, ... )]],
			[[		end]],
			[[	end]],
			[[	local hammeridToEntity = {}]],
			[[	local inLumpGetMapCreatedEntity = ents.GetMapCreatedEntity]],
			[[	function ents.GetMapCreatedEntity( id, ... )]],
			[[		local ent = hammeridToEntity[id] ]],
			[[		if IsValid( ent ) then]],
			[[			return ent]],
			[[		else]],
			[[			return inLumpGetMapCreatedEntity( id, ... )]],
			[[		end]],
			[[	end]],
			[[	]],
			[[	local WEAK_KEYS = {__mode = "k"}]],
			[[	local WEAK_VALUES = {__mode = "v"}]],
			[[	]],
			[[	local function InitPostEntity()]],
			[[		local entities = {}]], -- because there's a limit of 200 local variables
			[[		local ent]],
			[[		entitiesByMap = setmetatable( {}, WEAK_KEYS )]],
			[[		entityToHammerid = setmetatable( {}, WEAK_KEYS )]],
			[[		hammeridToEntity = setmetatable( {}, WEAK_VALUES )]],
		}
		local entitiesTextLuaSpawn = {} -- after creating everything (all entities ready)
		for i = 1, #entitiesText do
			local entityText = entitiesText[i]
			
			-- Determine basic entity information:
			local classname
			local hammerid
			local model = nil
			-- There is a mandatory non-empty structure name, using the same identifer as in the Lua file.
			local entityKeyValues = util_KeyValuesToTablePreserveOrder('"entities[' .. i .. ']"\x0A' .. entityText, false, true)
			if entityKeyValues and #entityKeyValues ~= 0 then
				for j = #entityKeyValues, 1, -1 do
					local keyValue = entityKeyValues[j]
					local key = keyValue.Key
					local value = keyValue.Value
					if key == "classname" then
						classname = value
					elseif key == "hammerid" then
						hammerid = value
					elseif key == "model" then
						model = value
					elseif key == "targetname" then
						local entityIndexes = targetnamesToEntityIndexes[value]
						if not entityIndexes then
							entityIndexes = {}
							targetnamesToEntityIndexes[value] = entityIndexes
						end
						entityIndexes[#entityIndexes + 1] = i
					elseif key == "parentname" then
						entityIndexesToParentname[i] = value
						targetnamesWithChildren[value] = true
					end
				end
			else
				print("Could not decode the following entity description:")
				print(entityText)
			end
			--[[
			if classname then
				presentClassNames[classname] = true
				if model == nil then
					presentClassNamesNoModel[classname] = true
				end
			end
			]]
			
			-- Select the appropriate target:
			local moveToLua
			if classname == nil then
				moveToLua = false
			elseif entityClassesAvoidLua[classname] then
				moveToLua = false
			elseif entityClassesForceLua[classname] then
				moveToLua = true
			elseif string_sub(classname, 1, 5) == "item_" then
				moveToLua = true
			elseif string_sub(classname, 1, 4) == "npc_" then
				moveToLua = true
			elseif string_sub(classname, 1, 7) == "weapon_" then
				moveToLua = true
			elseif not model or #model == 0 or string_sub(model, 1, 1) == "*" then
				moveToLua = false
			else
				moveToLua = true
			end
			do
				local moveToLua_ = hook_Run(
					"map_manipulation_tool:moveEntitiesToLua:moveToLua",
					mapTitle,
					classname,
					model,
					moveToLua,
					entityKeyValues
				)
				if moveToLua_ ~= nil then
					moveToLua = moveToLua_
				end
			end
			
			if moveToLua then
				classNamesInLua[classname] = true
			else
				classNamesInLump[classname] = true
			end
			
			-- Insert the entity in the appropriate target:
			if moveToLua then
				entitiesTextLua[#entitiesTextLua + 1] = [[		]]
				entitiesTextLua[#entitiesTextLua + 1] = [[		ent = ents_Create( ]] .. stringToLuaString(classname) .. [[ )]]
				entitiesTextLua[#entitiesTextLua + 1] = [[		if IsValid( ent ) then]]
				entitiesTextLua[#entitiesTextLua + 1] = [[			entities[]] .. i .. [[] = ent]]
				entitiesTextLua[#entitiesTextLua + 1] = [[			entitiesByMap[ent] = true]]
				for j = 1, #entityKeyValues do
					local keyValue = entityKeyValues[j]
					local key = keyValue.Key
					if not entityKeyValuesNotInLua[key] then
						local value = keyValue.Value
						entitiesTextLua[#entitiesTextLua + 1] = [[			ent_SetKeyValue( ent, ]] .. stringToLuaString(key) .. [[, ]] .. stringToLuaString(value) .. [[ )]]
						if key == "hammerid" then
							entitiesTextLua[#entitiesTextLua + 1] = [[			entityToHammerid[ent] = ]] .. value
							entitiesTextLua[#entitiesTextLua + 1] = [[			hammeridToEntity[]] .. value .. [[] = ent]]
						end
					end
				end
				entitiesTextLua[#entitiesTextLua + 1] = [[		end]]
				entitiesTextLuaSpawn[#entitiesTextLuaSpawn + 1] = [[		]]
				entitiesTextLuaSpawn[#entitiesTextLuaSpawn + 1] = [[		if entities[]] .. i .. [[] then]]
				entitiesTextLuaSpawn[#entitiesTextLuaSpawn + 1] = [[			ent_Spawn( entities[]] .. i .. [[] )]]
				entitiesTextLuaSpawn[#entitiesTextLuaSpawn + 1] = [[			ent_Activate( entities[]] .. i .. [[] )]]
				entitiesTextLuaSpawn[#entitiesTextLuaSpawn + 1] = [[		end]]
			else
				entitiesTextKeptInLump[#entitiesTextKeptInLump + 1] = entityText
				if hammerid ~= nil then
					entitiesTextLua[#entitiesTextLua + 1] = [[		]]
					entitiesTextLua[#entitiesTextLua + 1] = [[		ent = inLumpGetMapCreatedEntity( ]] .. hammerid .. [[ )]]
					entitiesTextLua[#entitiesTextLua + 1] = [[		if IsValid( ent ) then]]
					entitiesTextLua[#entitiesTextLua + 1] = [[			entities[]] .. i .. [[] = ent]]
					entitiesTextLua[#entitiesTextLua + 1] = [[		end]]
				end
			end
		end
		
		-- Show present entity classes:
		do
			--[[
			local presentClassNamesWithoutModel = {}
			local presentClassNamesWithModel = {}
			for classname in pairs(presentClassNames) do
				if presentClassNamesNoModel[classname] then
					presentClassNamesWithoutModel[#presentClassNamesWithoutModel + 1] = classname
				else
					presentClassNamesWithModel[#presentClassNamesWithModel + 1] = classname
				end
			end
			presentClassNames = nil
			table.sort(presentClassNamesWithoutModel)
			print("Present class names without model:")
			for i = 1, #presentClassNamesWithoutModel do
				print("-", presentClassNamesWithoutModel[i])
			end
			table.sort(presentClassNamesWithModel)
			print("Present class names with model:")
			for i = 1, #presentClassNamesWithModel do
				print("-", presentClassNamesWithModel[i])
			end
			]]
			local classNamesInLua_ = {}
			for classname in pairs(classNamesInLua) do
				classNamesInLua_[#classNamesInLua_ + 1] = classname
			end
			table.sort(classNamesInLua_)
			print("Present class names in Lua:")
			for i = 1, #classNamesInLua_ do
				print("-", classNamesInLua_[i])
			end
			
			local classNamesInLump_ = {}
			for classname in pairs(classNamesInLump) do
				classNamesInLump_[#classNamesInLump_ + 1] = classname
			end
			table.sort(classNamesInLump_)
			print("Present class names in LUMP_ENTITIES:")
			for i = 1, #classNamesInLump_ do
				print("-", classNamesInLump_[i])
			end
		end
		
		-- Append entity hierarchy to entitiesTextLua:
		for i = 1, #entitiesText do
			local parentname = entityIndexesToParentname[i]
			if parentname and #parentname ~= 0 then -- has declared parent
				local parentsIndexes = targetnamesToEntityIndexes[parentname]
				if parentsIndexes and #parentsIndexes ~= 0 then -- parents exist
					local parentIndex = parentsIndexes[1]
					if #parentsIndexes > 1 then
						print('entities[' .. i .. '] has several parent candidates (duplicate targetname = "' .. parentname .. '"), 1st candidate has been used!')
					end
					entitiesTextLua[#entitiesTextLua + 1] = [[		]]
					entitiesTextLua[#entitiesTextLua + 1] = [[		if entities[]] .. i .. [[] and entities[]] .. parentIndex .. [[] then]]
					entitiesTextLua[#entitiesTextLua + 1] = [[			entities[]] .. i .. [[]:SetParent( entities[]] .. parentIndex .. [[] )]]
					entitiesTextLua[#entitiesTextLua + 1] = [[		end]]
				end
			end
		end
		
		-- Append entitiesTextLuaSpawn to entitiesTextLua:
		entitiesTextLua[#entitiesTextLua + 1] = [[		]]
		entitiesTextLua[#entitiesTextLua + 1] = [[		-- No loop so .mdmp shows Lua stack trace for specific problematic call!]]
		for j = 1, #entitiesTextLuaSpawn do
			entitiesTextLua[#entitiesTextLua + 1] = entitiesTextLuaSpawn[j]
		end
		
		-- Finish the Lua file:
		entitiesTextLua[#entitiesTextLua + 1] = [[	end]]
		entitiesTextLua[#entitiesTextLua + 1] = [[	local hookName = "map_manipulation_tool:" .. mapName]]
		entitiesTextLua[#entitiesTextLua + 1] = [[	hook.Add( "InitPostEntity", hookName, InitPostEntity )]]
		entitiesTextLua[#entitiesTextLua + 1] = [[	hook.Add( "PostCleanupMap", hookName, InitPostEntity )]]
		entitiesTextLua[#entitiesTextLua + 1] = [[end]]
		entitiesTextLua[#entitiesTextLua + 1] = [[]]
		
		self.entitiesTextLua = table.concat(entitiesTextLua, "\n")
		self:setupLumpFromText(false, lumpNameToLuaIndex.LUMP_ENTITIES, table.concat(entitiesTextKeptInLump))
	end,
	
	_closeOldLumpStream = function(self, lumpInfoOld)
		-- Close the input stream of the given lumpInfoOld
		-- Must be called if a lump payload is going to be discarded
		local streamSrc
		if lumpInfoOld and lumpInfoOld.payload then
			streamSrc = lumpInfoOld.payload.streamSrc
			if streamSrc == self.streamSrc then
				-- If the stream is the loaded map file, it is not to be closed.
				streamSrc = nil
			end
		end
		if streamSrc then
			streamSrc:Close()
		end
	end,
	
	_closeAllLumpStreams = function(self)
		-- Close the input stream of every lump payload
		-- Must be called if every modified lump is going to be discarded
		if self.lumpsDst ~= nil then
			for i, lumpInfoOld in ipairs(self.lumpsDst) do
				self:_closeOldLumpStream(lumpInfoOld)
			end
		end
		if self.gameLumpsDst ~= nil then
			for i, lumpInfoOld in ipairs(self.gameLumpsDst) do
				self:_closeOldLumpStream(lumpInfoOld)
			end
		end
	end,
	
	close = function(self)
		-- This function must be called to properly close files.
		
		self:_closeAllLumpStreams()
		self.streamSrc:Close()
		
		-- Full memory cleanup:
		local keys = {}
		for k in pairs(self) do
			keys[#keys + 1] = k
		end
		for i = 1, #keys do
			self[keys[i]] = nil
		end
		collectgarbage()
	end,
	
	getInfoMap = function(self)
		local _, _, title = string.find(self.filenameSrc, "([^\\/]+)$")
		if title then
			if string.lower(string.sub(title, -4, -1)) == ".dat" then
				title = string.lower(string.sub(title, 1, -5))
			end
		end
		if title then
			if string.lower(string.sub(title, -4, -1)) == ".bsp" then
				title = string.lower(string.sub(title, 1, -5))
			end
		end
		return {
			size = self.streamSrc:Size(),
			version = self.bspHeader.version,
			mapRevision = self.bspHeader.mapRevision,
			bigEndian = (self.data_to_integer == data_to_be),
			title = title,
		}
	end,
	
	_addLumpInfoToList = function(self, lumpInfoSrc, lumpInfoDst, isGameLump, id, toCompress, allLumps)
		-- id: index in lumpsSrc & lumpsDst, unused for game lumps
		
		local sizeBefore = (lumpInfoSrc and lumpInfoSrc.filelen or -1)
		local modified = false
		if not isGameLump and id == lumpNameToLuaIndex.LUMP_GAME_LUMP then
			for i = 1, math.max(#self.gameLumpsSrc, #self.gameLumpsDst) do
				if self.gameLumpsSrc[i] ~= self.gameLumpsDst[i] then
					modified = true
					break
				end
			end
		else
			modified = (lumpInfoDst ~= lumpInfoSrc)
		end
		local sizeAfter = (lumpInfoDst and lumpInfoDst.filelen or -1) -- probably wrong if compression is to do
		local gameLumpId
		if isGameLump then
			gameLumpId = (lumpInfoSrc and lumpInfoSrc.id or lumpInfoDst and lumpInfoDst.id or -1)
		end
		local compressedAfter = false
		if isGameLump or id == lumpNameToLuaIndex.LUMP_GAME_LUMP then
			-- Because I decided it is common to all game lumps:
			local lumpGameLumpToCompress = self.lumpIndexesToCompress[lumpNameToLuaIndex.LUMP_GAME_LUMP]
			if lumpGameLumpToCompress == nil then
				compressedAfter = self:anyCompressedInGameLumps(self.gameLumpsDst)
			else
				compressedAfter = lumpGameLumpToCompress
			end
		else
			if toCompress == nil then
				if lumpInfoSrc and lumpInfoSrc.payload then
					compressedAfter = lumpInfoSrc.payload.compressed or false
				end
			elseif toCompress then
				compressedAfter = true
			end
		end
		
		local info = {
			isGameLump = isGameLump,
			luaId = isGameLump and gameLumpId or id,
			id = isGameLump and (-1) or (id - 1),
			name = isGameLump and int32_to_be_data(gameLumpId) or lumpLuaIndexToName[id],
			version = lumpInfoSrc and lumpInfoSrc.version or lumpInfoDst and lumpInfoDst.version or -1,
			sizeBefore = sizeBefore,
			compressedBefore = lumpInfoSrc and lumpInfoSrc.payload and lumpInfoSrc.payload.compressed or false,
			absent = ((sizeBefore == -1 or sizeBefore == 0) and (sizeAfter == -1 or sizeAfter == 0)),
			modified = modified,
			deleted = (modified and sizeAfter <= 0),
			sizeAfter = sizeAfter,
			compressedAfter = compressedAfter,
		}
		if allLumps ~= nil then
			allLumps[#allLumps + 1] = info
		end
		
		return info
	end,
	
	getInfoLumps = function(self, includeAbsent, only1, only1IsGameLump, only1Id)
		-- Returns readable information about all lumps (for UI)
		-- includeAbsent: also include lumps that are not present in the map
		-- only1: only return allLumps with 1 value, matching only1IsGameLump, only1Id
		
		local allLumps = {}
		
		local LUMP_ID_GAME_LUMP = lumpNameToLuaIndex["LUMP_GAME_LUMP"]
		if only1 then
			includeAbsent = true
		end
		for i = 1, #self.lumpsSrc do
			local toCompress = self.lumpIndexesToCompress[i]
			
			-- Add lumps:
			if not only1 or (not only1IsGameLump and i == only1Id) then
				local lumpSrc = self.lumpsSrc[i]
				local lumpDst = self.lumpsDst[i]
				if includeAbsent or (lumpSrc and lumpSrc.payload) or (lumpDst and lumpDst.payload) then
					self:_addLumpInfoToList(self.lumpsSrc[i], self.lumpsDst[i], false, i, toCompress, allLumps)
				end
			end
			
			-- Add game lumps:
			if i == LUMP_ID_GAME_LUMP then
				local gameLumpIdsInSrc = {}
				for j = 1, #self.gameLumpsSrc do
					-- Locate the game lump with same id in self.gameLumpsDst:
					local gameLumpSrc = self.gameLumpsSrc[j]
					local gameLumpDst
					local id = gameLumpSrc.id
					if not only1 or (only1IsGameLump and id == only1Id) then
						for k = 1, #self.gameLumpsDst do
							if self.gameLumpsDst[k].id == id then
								gameLumpDst = self.gameLumpsDst[k]
								break
							end
						end
						-- Add a game lump when present in self.gameLumpsSrc:
						self:_addLumpInfoToList(gameLumpSrc, gameLumpDst, true, j, toCompress, allLumps)
					end
					gameLumpIdsInSrc[id] = true
				end
				for j = 1, #self.gameLumpsDst do
					local gameLumpDst = self.gameLumpsDst[j]
					local id = gameLumpDst.id
					if not gameLumpIdsInSrc[id] then
						if not only1 or (only1IsGameLump and id == only1Id) then
							-- Add a game lump if no lump with same id in self.gameLumpsSrc:
							self:_addLumpInfoToList(nil, gameLumpDst, true, j, toCompress, allLumps)
						end
					end
				end
			end
		end
		
		return allLumps
	end,
	
	getUpdatedInfoLump = function(self, oldInfo)
		-- Returns a new info object for the given obsolete lump info object
		-- This is useful to update just a given lump after a modification on the GUI.
		return self:getInfoLumps(true, true, oldInfo.isGameLump, oldInfo.luaId)[1]
	end,
}
BspContext.__index = BspContext
