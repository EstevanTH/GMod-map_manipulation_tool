-- The goal here is to test the symmetry while extracting & parsing lumps as text, for different maps:

local BspContext
local getLumpIdFromLumpName
local maps
local lumps

local function run_test_for_lump(context, lumpName)
	Msg('\tTesting text format symmetry for lump "' .. lumpName .. '"... ')
	local id, isGameLump = getLumpIdFromLumpName(lumpName)
	local textBefore = context:extractLumpAsText(isGameLump, id, false)
	context:setupLumpFromText(isGameLump, id, textBefore)
	local textAfter = context:extractLumpAsText(isGameLump, id, true)
	if textAfter ~= textBefore then
		MsgN("FAIL")
	else
		local binarySuccess = true
		if lumpName == "sprp" then
			-- The binaries never match especially because of models given in a different order.
			local _, leavesBefore, propsBefore, modelsBefore = context:getStaticPropsList(false)
			local _, leavesAfter,  propsAfter,  modelsAfter  = context:getStaticPropsList(true)
			do
				for i = 1, math.max(#leavesBefore, #leavesAfter) do
					if leavesBefore[i] ~= leavesAfter[i] then
						binarySuccess = false
						break
					end
				end
			end
			if binarySuccess then
				local propsBoth = {propsBefore, propsAfter} -- in case of any missing key in one of both
				for i = 1, 2 do
					for _, staticPropLump in ipairs(propsBoth[i]) do
						for k in pairs(staticPropLump) do
							local valBefore = propsBefore[i][k]
							local valAfter = propsAfter[i][k]
							if k == "PropType" then
								-- Note: the model may be at different index
								if modelsBefore[valBefore] ~= modelsAfter[valAfter] then
									binarySuccess = false
								end
							elseif isvector(valBefore) then -- untrusted native Vector comparison
								-- TODO - inspecter NaN (comparaison retourne VRAI ?!) : koth_nucleus	ctf_hellfire	c1m1_hotel	cs_agency	de_shortdust
								if not(valBefore.x == valAfter.x)
								or not(valBefore.y == valAfter.y)
								or not(valBefore.z == valAfter.z) then
									binarySuccess = false
								end
							elseif isangle(valBefore) then -- untrusted native Angle comparison
								if not(valBefore.p == valAfter.p)
								or not(valBefore.y == valAfter.y)
								or not(valBefore.r == valAfter.r) then
									binarySuccess = false
								end
							elseif valBefore ~= valAfter then
								binarySuccess = false
							end
							if not binarySuccess then
								Msg(k .. "\t")
								break
							end
						end
						if not binarySuccess then
							break
						end
					end
					if not binarySuccess then
						break
					end
				end
			end
		else
			local binaryBefore = context:_getLump(isGameLump, id, false).payload:readAll()
			local binaryAfter = context:_getLump(isGameLump, id, true).payload:readAll()
			binarySuccess = (binaryAfter == binaryBefore)
		end
		if not binarySuccess then
			MsgN("BINARY FAIL")
		else
			MsgN("OK")
		end
	end
end

local function run_test_for_map(map)
	local context = BspContext:new("maps/" .. map .. ".bsp")
	for _, lumpName in ipairs(lumps) do
		local success, message = pcall(run_test_for_lump, context, lumpName)
		if not success then
			print("\n\t", message)
		end
	end
	context:close()
end

local function run_test()
	BspContext = map_manipulation_tool_api.BspContext
	getLumpIdFromLumpName = map_manipulation_tool_api.getLumpIdFromLumpName
	
	maps = {
		"halls3", -- HL2:DM, map v19, sprp v5
		"rp_rockford_open", -- GMod, map v20, sprp v6
		"koth_nucleus", -- TF2, map v20, sprp v6
		"ctf_hellfire", -- TF2, map v20, sprp v10
		"koth_lazarus", -- TF2, map v20, sprp v10
		"c1m1_hotel", -- L4D2, map v21, sprp v9
		"cs_agency", -- CS:GO, map v21, sprp v10
		"de_shortdust", -- CS:GO, map v21, sprp v10
		"de_shortnuke", -- CS:GO, map v21, sprp v11
	}
	
	lumps = {
		"LUMP_ENTITIES",
		"sprp",
		"LUMP_TEXDATA_STRING_DATA",
		-- "LUMP_OVERLAYS",
	}
	
	for _, map in ipairs(maps) do
		print("Testing map", map)
		local success, message = pcall(run_test_for_map, map)
		if not success then
			print("", message)
		end
	end
	print("Finished all tests!")
end

concommand.Add("map_manipulation_tool_test_suite",
	function(ply, cmd, args)
		run_test()
	end,
	nil
)
