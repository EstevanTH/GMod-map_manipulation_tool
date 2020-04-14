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
	local finished = false
	
	-- Text comparison:
	if not finished then
		if textAfter ~= textBefore then
			-- Test of every line with tolerance for slight floating-point numbers variation:
			local LINE_PATTERN = "([^\x0A]*)\x0A"
			local NUMBER_PATTERN = '^[%s]*"[^"]*"[%s]+"([0-9%.]+)"[%s]*$' -- number as a keyvalue value
			local iteratorBefore = string.gmatch(textBefore, LINE_PATTERN)
			local iteratorAfter  = string.gmatch(textAfter,  LINE_PATTERN)
			for lineBefore in iteratorBefore do
				local lineAfter = iteratorAfter()
				if lineBefore ~= lineAfter then
					local lineOkay = false
					print('\t\t- lineBefore = "' .. lineBefore .. '"')
					print('\t\t  lineAfter  = "' .. lineAfter  .. '"')
					local numberBefore = tonumber(string.match(lineBefore, NUMBER_PATTERN))
					local numberAfter  = numberBefore and tonumber(string.match(lineAfter, NUMBER_PATTERN))
					if numberBefore ~= nil and numberAfter ~= nil then
						-- Number variation tolerance:
						if math.abs((numberAfter - numberBefore) / numberBefore) < 0.001 then
							-- Less than 0.1% of difference, accepted:
							lineOkay = true
						end
						if numberAfter > numberBefore then
							print("numberAfter > numberBefore")
						end
					end
					if not lineOkay then
						finished = true
						MsgN("FAIL")
						break
					end
				end
			end
		end
	end
	
	-- Binary comparison:
	if not finished then
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
			finished = true
		end
	end
	
	-- Okay good:
	if not finished then
		MsgN("OK")
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
		"LUMP_OVERLAYS",
	}
	
	for _, map in ipairs(maps) do
		print("\nTesting map", map)
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
