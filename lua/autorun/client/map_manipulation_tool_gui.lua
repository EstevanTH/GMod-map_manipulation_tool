print("map_manipulation_tool_gui")

local api = map_manipulation_tool_api
local surface = surface

local TITLE_BAR_THICKNESS = 24
local SCROLL_BAR_THICKNESS = 15
local BUTTON_HEIGHT = 24
local MARGIN = 8
local WIDTH = 640
local WIDTH_1_1 = (WIDTH - MARGIN * 2)
local WIDTH_1_2 = (WIDTH - MARGIN * 3) / 2
local WIDTH_1_3 = (WIDTH - MARGIN * 4) / 3
local WIDTH_2_3 = WIDTH_1_3 * 2 + MARGIN
local X_COL_1 = MARGIN
local X_COL_2_2 = MARGIN * 2 + WIDTH_1_2
local X_COL_2_3 = MARGIN * 2 + WIDTH_1_3
local X_COL_3_3 = MARGIN * 2 + WIDTH_2_3
local LUMP_HEADER_TXCOLOR = Color(0, 0, 0)
local LUMP_HEADER_HEIGHT_1 = 16
local LUMP_COLUMN_WIDTH_ID = 30
local LUMP_COLUMN_WIDTH_NAME = 209
local LUMP_COLUMN_WIDTH_VERSION = 40
local LUMP_COLUMN_WIDTH_SIZE = 65
local LUMP_COLUMN_WIDTH_COMPRESSED = 70
local LUMP_COLUMN_WIDTH_MODIFIED = 60
local LUMP_COLUMN_WIDTH_SPARE = (
	WIDTH_1_1 -
	LUMP_COLUMN_WIDTH_ID -
	LUMP_COLUMN_WIDTH_NAME -
	LUMP_COLUMN_WIDTH_VERSION -
	LUMP_COLUMN_WIDTH_SIZE -
	LUMP_COLUMN_WIDTH_COMPRESSED -
	LUMP_COLUMN_WIDTH_MODIFIED -
	LUMP_COLUMN_WIDTH_SIZE -
	LUMP_COLUMN_WIDTH_COMPRESSED
)
local LUMP_ROW_MARGIN = 2
local LUMP_CELL_MARGIN_X = 2
local LUMP_CELL_MARGIN_X_TOTAL = 1 + LUMP_CELL_MARGIN_X * 2 -- 1 for left vertical border
local LUMP_ROW_HEIGHT = 32
local LUMP_ROW_TXCOLOR = Color(0, 0, 0)
local LUMP_ROW_TXCOLOR_ABSENT = Color(127, 127, 127)
local LUMP_ROW_TXCOLOR_MODIFIED = Color(255, 255, 255)

local ALIGN_MIDDLE_LEFT = 4
local ALIGN_MIDDLE_CENTER = 5
local ALIGN_MIDDLE_RIGHT = 6

local CLASS_GUI_LUMP_ROW = "DLabel"

local DialogFileSelector
do
	local margin = 4
	local totalW, totalH = 640, 400
	local browserX, browserY = margin, 24 + margin
	local buttonsW = 150
	local browserW = 640 - 2*margin
	local nameFieldW_Open = browserW -   buttonsW -   margin
	local nameFieldW_Save = browserW - 2*buttonsW - 2*margin
	local nameFieldH = BUTTON_HEIGHT
	local nameFieldX, nameFieldY = browserX, totalH - margin - nameFieldH
	local browserH = nameFieldY - browserY - margin
	local buttonOpenSaveX = totalW - margin - buttonsW
	local buttonNewFolderX = buttonOpenSaveX - buttonsW - margin
	local buttonsY = totalH - margin - BUTTON_HEIGHT
	
	local string_lower = string.lower
	local nameSorter = function(a, b)
		return string_lower(a) < string_lower(b)
	end
	
	local function parseNameField(selector, inputText)
		-- Return information about the file name given in the field
		local filepicker = selector.filepicker
		local folderPath = string.sub(filepicker:GetCurrentFolder(), 2)
		if #folderPath ~= 0 then
			folderPath = folderPath .. "/"
		end
		return {
			folderBase = filepicker:GetPath(),
			folderPath = folderPath,
			fullPath = folderPath .. inputText,
		}
	end
	
	local nameField_GetAutoComplete = function(self, inputText)
		local selector = self:GetParent().selector
		local nameFieldInfo = parseNameField(selector, inputText)
		local choices, folders = file.Find(nameFieldInfo.folderPath .. inputText .. "*", nameFieldInfo.folderBase)
		if choices ~= nil then
			table.Add(choices, folders)
			table.sort(choices, nameSorter)
		end
		return choices
	end
	
	local fixWriteFileNameExtension
	do
		local validWriteExtensions = {
			-- https://wiki.facepunch.com/gmod/file.Write
			[".txt"] = true,
			[".jpg"] = true,
			[".png"] = true,
			[".vtf"] = true,
			[".dat"] = true,
			[".json"] = true,
		}
		function fixWriteFileNameExtension(fileName, defaultExtension)
			-- Adds the extension if the file name does not contain an allowed extension for write
			local _, _, extension = string.find(fileName, "(%.[a-z]+)$")
			defaultExtension = defaultExtension or ".dat"
			if not validWriteExtensions[extension] then
				fileName = fileName .. defaultExtension
			end
			return fileName
		end
	end
	
	local doSubmit = function(self)
		local selector = self:GetParent().selector
		local nameFieldInfo = parseNameField(selector, selector.nameField:GetText())
		local folderBase = nameFieldInfo.folderBase
		local fullPath = nameFieldInfo.fullPath
		if file.IsDir(fullPath, folderBase) then
			selector.filepicker:SetCurrentFolder("/" .. fullPath)
		else
			if selector.withSave then
				fullPath = fixWriteFileNameExtension(fullPath, selector.defaultExtension)
			end
			local function submit()
				selector:onSubmit(folderBase, fullPath)
				selector.box:Close()
			end
			if file.Exists(fullPath, folderBase) then
				if selector.withSave then
					Derma_Query(
						"The specified file already exists!\nDo you want to overwrite it?",
						"Save as", 
						"Yes", submit,
						"Cancel", nil
					)
				else
					submit()
				end
			else
				if selector.withSave then
					submit()
				else
					Derma_Message(
						"The specified file does not exist!",
						"Open",
						"Okay"
					)
				end
			end
		end
	end
	
	local filepicker_OnSelect = function(self, filePath, selectedPanel)
		local selector = self:GetParent().selector
		local nameField = selector.nameField
		nameField:SetText(selectedPanel:GetColumnText(1))
	end
	
	local filepicker_OnDoubleClick = function(self, filePath, selectedPanel)
		-- This happens after OnSelect, which is good.
		doSubmit(self)
	end
	
	local doCreateFolder = function(self)
		local selector = self:GetParent().selector
		local inputText = selector.nameField:GetText()
		local nameFieldInfo = parseNameField(selector, inputText)
		local folderBase = nameFieldInfo.folderBase
		local fullPath = nameFieldInfo.fullPath
		if folderBase ~= "DATA" then
			Derma_Message(
				"Folders cannnot be created outside the DATA folder base!",
				"Save as",
				"Okay"
			)
		elseif file.IsDir(fullPath, folderBase) then
			Derma_Message(
				"The specified folder already exists!",
				"Save as",
				"Okay"
			)
		elseif file.Exists(fullPath, folderBase) then
			Derma_Message(
				"The specified folder names a file that already exists!",
				"Save as",
				"Okay"
			)
		else
			file.CreateDir(fullPath)
			if file.IsDir(fullPath, folderBase) then
				local filepicker = selector.filepicker
				local rootPath = filepicker:GetPath()
				local folder = "/" .. fullPath
				local types = filepicker:GetFileTypes()
				filepicker:Clear() -- to refresh directory browser
				selector:configureFilePicker(rootPath, folder, types)
				selector.nameField:SetText(selector.saveDefaultName)
			else
				Derma_Message(
					"The new folder could not be created!",
					"Save as",
					"Okay"
				)
			end
		end
	end
	
	local box_Center = function(self)
		-- Because self is both parented & Makepopup'ed, the default Center() applies relative calculated position to absolute positioning!
		self:SetPos(
			(ScrW() - self:GetWide()) / 2,
			(ScrH() - self:GetTall()) / 2
		)
	end
	
	DialogFileSelector = {
		withSave = false, -- true: save dialog, false: open dialog
		
		new = function(cls, parent, onSubmit, withSave, rootPath, folder, types, saveDefaultName)
			-- types: "*.bsp.dat *.bsp" (in that order, the valid save extension comes first)
			local selector = {}
			setmetatable(selector, cls)
			selector.withSave = withSave
			selector.onSubmit = onSubmit -- selector:onSubmit(folderBase, fullPath)
			
			if rootPath == nil then
				rootPath = withSave and "DATA" or "GAME"
			end
			local _, _, defaultExtension = string.find(types, "^%*(%.[^ ]+)")
			if not defaultExtension then -- cannot determine a suitable extension
				defaultExtension = ".dat"
			end
			selector.defaultExtension = defaultExtension
			if saveDefaultName == nil then
				saveDefaultName = types -- used for the Open dialog too!
			end
			selector.saveDefaultName = saveDefaultName
			
			local box = vgui.Create("DFrame", parent); do
				selector.box = box
				box.selector = selector
				box.Center = box_Center
				box:MakePopup() -- overrides position hierarchy and enabled keyboard input
				box:SetSize(totalW, totalH)
				box:Center()
				box:SetTitle(withSave and "Save as" or "Open")
				box:DoModal()
			end
			local filepicker = vgui.Create("DFileBrowser", box); do
				selector.filepicker = filepicker
				filepicker:SetSize(browserW, browserH)
				filepicker:SetPos(browserX, browserY)
				selector:configureFilePicker(rootPath, folder, types)
				filepicker.OnSelect = filepicker_OnSelect
				filepicker.OnDoubleClick = filepicker_OnDoubleClick
			end
			local buttonOpenSave
			do
				buttonOpenSave = vgui.Create("DButton", box); do
					buttonOpenSave:SetSize(buttonsW, BUTTON_HEIGHT)
					buttonOpenSave:SetPos(buttonOpenSaveX, buttonsY)
					buttonOpenSave:SetText(withSave and "Save" or "Open")
					buttonOpenSave.DoClick = doSubmit
				end
			end
			local nameField = vgui.Create("DTextEntry", box); do
				selector.nameField = nameField
				nameField:SetSize(withSave and nameFieldW_Save or nameFieldW_Open, nameFieldH)
				nameField:SetPos(nameFieldX, nameFieldY)
				nameField:SetText(saveDefaultName)
				nameField.GetAutoComplete = nameField_GetAutoComplete
				nameField.OnEnter = buttonOpenSave.DoClick
			end
			local buttonNewFolder
			if withSave then
				buttonNewFolder = vgui.Create("DButton", box); do
					buttonNewFolder:SetSize(buttonsW, BUTTON_HEIGHT)
					buttonNewFolder:SetPos(buttonNewFolderX, buttonsY)
					buttonNewFolder:SetText("As new folder")
					buttonNewFolder.DoClick = doCreateFolder
				end
			end
			
			return selector
		end,
		
		configureFilePicker = function(self, rootPath, folder, types)
			local filepicker = self.filepicker
			filepicker:SetPath(rootPath)
			filepicker:SetBaseFolder("/")
			filepicker:SetCurrentFolder(folder)
			filepicker:SetFileTypes(types)
			filepicker:SetName(rootPath == "DATA" and "garrysmod/data" or rootPath == "GAME" and "garrysmod" or nil)
			filepicker:SetOpen(true)
		end,
	}
end
DialogFileSelector.__index = DialogFileSelector

local openEntitiesByClassRemover
do
	local surface = surface
	
	local ROW_HEIGHT = 32
	local ROW_SPACING = 4
	local ROW_PADDING = 4
	local BUTTON_Y = (ROW_HEIGHT - BUTTON_HEIGHT) / 2
	
	local function btnRemove_DoClick(self)
		self.context:removeEntitiesByClass(self.classname, true)
		self.assistant.lumpsList.refreshLumpsList()
		self.row.removed = true
		self:SetEnabled(false)
	end
	local function btnWiki_DoClick(self)
		gui.OpenURL("https://developer.valvesoftware.com/wiki/" .. self.classname)
	end
	local function row_Paint(self, w, h)
		do
			surface.SetDrawColor(223,223,223, 191)
			surface.DrawRect(0,0, w,h)
			if self:IsHovered() or self:IsChildHovered() then
				surface.SetDrawColor(0,255,0, 85)
				surface.DrawRect(0,0, w,h)
			end
		end
		do
			if self.removed then
				surface.SetTextColor(127, 127, 127)
			else
				surface.SetTextColor(0, 0, 0)
			end
			surface.SetTextPos(4, 7)
			surface.SetFont("Trebuchet18")
			surface.DrawText(self.classname)
		end
	end
	
	local function makeClassRow(remover, classesList, classname)
		local rowWidth = classesList:GetWide()
		local row = vgui.Create("DPanel", classesList); do
			row.Paint = row_Paint
			row.classname = classname
			row:SetSize(rowWidth, ROW_HEIGHT)
		end
		
		local w = 180
		local x = rowWidth - SCROLL_BAR_THICKNESS - ROW_PADDING - w
		local btnRemove
		if classname ~= "worldspawn" then
			btnRemove = vgui.Create("DButton", row); do
				btnRemove.DoClick = btnRemove_DoClick
				btnRemove:SetSize(w, BUTTON_HEIGHT)
				btnRemove:SetPos(x, BUTTON_Y)
				btnRemove:SetImage("icon16/delete.png")
				btnRemove:SetText("Remove occurrences")
				btnRemove.row = row
				btnRemove.assistant = remover.assistant
				btnRemove.context = remover.context
				btnRemove.classname = classname
			end
		end
		
		w = 160
		x = x - ROW_PADDING - w
		local btnWiki = vgui.Create("DButton", row); do
			btnWiki.DoClick = btnWiki_DoClick
			btnWiki:SetSize(w, BUTTON_HEIGHT)
			btnWiki:SetPos(x, BUTTON_Y)
			btnWiki:SetImage("icon16/information.png")
			btnWiki:SetText("Open the Wiki")
			btnWiki.classname = classname
		end
		
		return row
	end
	
	function openEntitiesByClassRemover(assistant)
		local context = assistant.context
		if IsValid(assistant.remover) then
			assistant.remover:Remove()
		end
		local remover = vgui.Create("DFrame"); do
			remover:MakePopup()
			remover:SetKeyboardInputEnabled(false)
			remover:SetWide(WIDTH)
			remover:SetTitle("Remove entities by class")
			remover.btnMinim:SetVisible(false)
			remover.btnMaxim:SetVisible(false)
			remover.assistant = assistant
			remover.context = context
			assistant.remover = remover
		end
		local classes = context:getPresentEntityClasses(true)
		local classesList = vgui.Create("DScrollPanel", remover)
		classesList:SetPos(MARGIN, TITLE_BAR_THICKNESS + MARGIN)
		classesList:SetWide(WIDTH_1_1)
		for i, classname in ipairs(classes) do
			local row = makeClassRow(remover, classesList, classname)
			row:SetPos(0, (i - 1) * (ROW_HEIGHT + ROW_SPACING))
		end
		
		local x, y = classesList:GetPos()
		classesList:SetTall(math.min(
			(#classes * (ROW_HEIGHT + ROW_SPACING)) - ROW_SPACING,
			ScrH() - y - MARGIN
		))
		remover:SetTall(y + classesList:GetTall() + MARGIN)
		remover:Center()
		-- TODO - comptages si disponible
		
		return remover
	end
end

local makeLumpColumnHeader
do
	local Paint = function(self, w,h)
		surface.SetDrawColor(191,191,191, 255)
		surface.DrawRect(0,0, w,h)
		surface.SetDrawColor(63,63,63, 255) -- border
		surface.DrawOutlinedRect(0,0, w,h)
		return false
	end
	function makeLumpColumnHeader(parent, text)
		local header = vgui.Create("DLabel", parent)
		header.Paint = Paint
		header:SetTextColor(LUMP_HEADER_TXCOLOR)
		header:SetText(text)
		header:SetContentAlignment(ALIGN_MIDDLE_CENTER) -- middle center
		return header
	end
end

local PaintLumpTableBorders
do
	local lumpTableXBars = {0}
	lumpTableXBars[#lumpTableXBars + 1] = lumpTableXBars[#lumpTableXBars] + LUMP_COLUMN_WIDTH_ID
	lumpTableXBars[#lumpTableXBars + 1] = lumpTableXBars[#lumpTableXBars] + LUMP_COLUMN_WIDTH_NAME
	lumpTableXBars[#lumpTableXBars + 1] = lumpTableXBars[#lumpTableXBars] + LUMP_COLUMN_WIDTH_VERSION
	lumpTableXBars[#lumpTableXBars + 1] = lumpTableXBars[#lumpTableXBars] + LUMP_COLUMN_WIDTH_SIZE
	lumpTableXBars[#lumpTableXBars + 1] = lumpTableXBars[#lumpTableXBars] + LUMP_COLUMN_WIDTH_COMPRESSED
	lumpTableXBars[#lumpTableXBars + 1] = lumpTableXBars[#lumpTableXBars] + LUMP_COLUMN_WIDTH_MODIFIED
	lumpTableXBars[#lumpTableXBars + 1] = lumpTableXBars[#lumpTableXBars] + LUMP_COLUMN_WIDTH_SIZE
	lumpTableXBars[#lumpTableXBars + 1] = lumpTableXBars[#lumpTableXBars] + LUMP_COLUMN_WIDTH_COMPRESSED
	lumpTableXBars[#lumpTableXBars + 1] = lumpTableXBars[#lumpTableXBars] + LUMP_COLUMN_WIDTH_SPARE - 1 -- right border
	function PaintLumpTableBorders(w, h)
		surface.SetDrawColor(63,63,63, 255) -- border
		for i = 1, #lumpTableXBars do
			surface.DrawLine(lumpTableXBars[i], 0, lumpTableXBars[i], h)
		end
	end
end

local makeLumpRow
do
	-- constants:
	local LUMPS_NO_EXTRACT_AFTER = { -- by name
		["LUMP_GAME_LUMP"] = true, -- no LumpPayload object => cannot be extracted
	}
	local LUMPS_NO_ERASE = { -- by name
		["LUMP_GAME_LUMP"] = true,
	}
	local LUMPS_NO_REPLACE = { -- by name
		["LUMP_GAME_LUMP"] = true,
	}
	local LUMPS_NO_COMPRESS = { -- by name
		["LUMP_PAKFILE"] = true,
		["LUMP_XZIPPAKFILE"] = true,
	}
	local LUMPS_AS_TEXT = { -- by name
		["LUMP_ENTITIES"] = true,
		["sprp"] = true,
		["LUMP_TEXDATA_STRING_DATA"] = true,
		["LUMP_OVERLAYS"] = true,
	}
	local LUMPS_PAK_FILE = { -- by name
		["LUMP_PAKFILE"] = true,
		["LUMP_XZIPPAKFILE"] = true,
	}
	local LUMPS_LIGHTING = { -- by name
		["LUMP_LIGHTING"] = true,
		["LUMP_LIGHTING_HDR"] = true,
		["LUMP_WORLDLIGHTS"] = true,
		["LUMP_WORLDLIGHTS_HDR"] = true,
	}
	local LABEL_AS_TEXT_FILE = "As text file"
	local LABEL_AS_BINARY_NO_HEADERS = "As binary file without headers"
	local LABEL_AS_UNCOMPRESSED_ZIP = "As uncompressed ZIP file"
	local LABEL_FROM_TEXT_FILE = "Text file"
	local LABEL_FROM_BINARY_NO_HEADERS = "Binary file without headers"
	local LABEL_FROM_UNCOMPRESSED_ZIP = "Uncompressed ZIP file"
	
	local Paint = function(self, w,h)
		local info = self.info
		if info.deleted then
			surface.SetDrawColor(127,0,0, 255)
		elseif info.modified then
			surface.SetDrawColor(0,0,127, 255)
		else
			surface.SetDrawColor(223,223,223, 255)
		end
		surface.DrawRect(0,0, w,h)
		if self:IsHovered() or IsValid(self.menu) then
			surface.SetDrawColor(0,255,0, 85)
			surface.DrawRect(0,0, w,h)
		end
		PaintLumpTableBorders(w, h)
		return true
	end
	
	local DoRightClick = function(self)
		local menu = DermaMenu()
		self.menu = menu
		do
			local old_OnRemove = menu.OnRemove
			menu.OnRemove = function(...)
				if self.menu == menu then
					self.menu = nil
				end
				if old_OnRemove then
					old_OnRemove(...)
				end
			end
		end
		
		local info = self.info
		local name = tostring(info.name)
		local row = self
		local context = row.context
		local lumpsList = row:GetParent():GetParent() -- shouldn't it be the direct parent?!
		local mapTitle = lumpsList.mapTitle
		local box = lumpsList:GetParent()
		local typesBinaryNoHeaders = "*.dat"
		local extensionSaveBinaryNoHeaders = ".dat"
		if LUMPS_PAK_FILE[name] then
			typesBinaryNoHeaders = "*.zip.dat *.zip"
			extensionSaveBinaryNoHeaders = ".zip.dat"
		end
		local refreshLumpsList = lumpsList.refreshLumpsList
		
		local canExtractSrc = (info.sizeBefore > 0)
		local canExtractDst = (info.sizeAfter > 0 and not LUMPS_NO_EXTRACT_AFTER[name])
		if canExtractSrc or canExtractDst then
			local submenu1, icon1 = menu:AddSubMenu("Extract"); do
				icon1:SetIcon("icon16/brick_go.png")
				local labelAsBinaryNoHeaders = LABEL_AS_BINARY_NO_HEADERS
				if LUMPS_PAK_FILE[name] then
					labelAsBinaryNoHeaders = LABEL_AS_UNCOMPRESSED_ZIP
				end
				if canExtractSrc then
					local submenu2, icon2 = submenu1:AddSubMenu("From Before"); do
						if LUMPS_AS_TEXT[name] then
							local option = submenu2:AddOption(LABEL_AS_TEXT_FILE); do
								option.DoClick = function(self)
									local selector = DialogFileSelector:new(box, function(selector, folderBase, fullPath)
										context:extractLumpAsTextFile(info.isGameLump, info.luaId, false, fullPath)
									end, true, "DATA", "/", "*.txt", mapTitle .. " Lump " .. name .. " Before.txt")
								end
							end
						end
						do
							local option = submenu2:AddOption(labelAsBinaryNoHeaders); do
								option.DoClick = function(self)
									DialogFileSelector:new(box, function(selector, folderBase, fullPath)
										context:extractLumpAsHeaderlessFile(info.isGameLump, info.luaId, false, fullPath, false)
									end, true, "DATA", "/", typesBinaryNoHeaders, mapTitle .. " Lump " .. name .. " Before" .. extensionSaveBinaryNoHeaders)
								end
							end
						end
					end
				end
				if canExtractDst then
					local submenu2, icon2 = submenu1:AddSubMenu("From After"); do
						if LUMPS_AS_TEXT[name] then
							local option = submenu2:AddOption(LABEL_AS_TEXT_FILE); do
								option.DoClick = function(self)
									DialogFileSelector:new(box, function(selector, folderBase, fullPath)
										context:extractLumpAsTextFile(info.isGameLump, info.luaId, true, fullPath)
									end, true, "DATA", "/", "*.txt", mapTitle .. " Lump " .. name .. " After.txt")
								end
							end
						end
						do
							local option = submenu2:AddOption(labelAsBinaryNoHeaders); do
								option.DoClick = function(self)
									DialogFileSelector:new(box, function(selector, folderBase, fullPath)
										context:extractLumpAsHeaderlessFile(info.isGameLump, info.luaId, true, fullPath, false)
									end, true, "DATA", "/", typesBinaryNoHeaders, mapTitle .. " Lump " .. name .. " After" .. extensionSaveBinaryNoHeaders)
								end
							end
						end
					end
				end
			end
		end
		
		if not LUMPS_NO_REPLACE[name] then
			local labelFromBinaryNoHeaders = LABEL_FROM_BINARY_NO_HEADERS
			if LUMPS_PAK_FILE[name] then
				labelFromBinaryNoHeaders = LABEL_FROM_UNCOMPRESSED_ZIP
			end
			local submenu1, icon1 = menu:AddSubMenu("Replace with"); do
				icon1:SetIcon("icon16/brick_edit.png")
				if LUMPS_AS_TEXT[name] then
					local option = submenu1:AddOption(LABEL_FROM_TEXT_FILE); do
						option.DoClick = function(self)
							DialogFileSelector:new(box, function(selector, folderBase, fullPath)
								context:setupLumpFromTextFile(info.isGameLump, info.luaId, fullPath)
								refreshLumpsList()
							end, false, "GAME", "/", "*.txt")
						end
					end
				end
				do
					local option = submenu1:AddOption(labelFromBinaryNoHeaders); do
						option.DoClick = function(self)
							DialogFileSelector:new(box, function(selector, folderBase, fullPath)
								context:setupLumpFromHeaderlessFile(info.isGameLump, info.luaId, fullPath)
								refreshLumpsList()
							end, false, "GAME", "/", typesBinaryNoHeaders)
						end
					end
				end
			end
		end
		
		if info.modified and not info.deleted and not info.isGameLump and not LUMPS_NO_COMPRESS[name] then
			if info.compressedAfter then
				local option = menu:AddOption("Deactivate compression"); do
					option:SetIcon("icon16/compress.png")
					option.DoClick = function(self)
						context:setLumpCompressed(info.luaId, false)
						refreshLumpsList()
					end
				end
			else
				local option = menu:AddOption("Activate compression"); do
					option:SetIcon("icon16/compress.png")
					option.DoClick = function(self)
						context:setLumpCompressed(info.luaId, true)
						refreshLumpsList()
					end
				end
			end
		end
		
		if not info.deleted and not info.absent and not LUMPS_NO_ERASE[name] then
			local option = menu:AddOption("Erase"); do
				option:SetIcon("icon16/brick_delete.png")
				option.DoClick = function(self)
					context:clearLump(info.isGameLump, info.luaId)
					refreshLumpsList()
				end
			end
		end
		
		if info.modified then
			local option = menu:AddOption("Revert changes"); do
				option:SetIcon("icon16/arrow_undo.png")
				option.DoClick = function(self)
					context:revertLumpChanges(info.isGameLump, info.luaId)
					refreshLumpsList()
				end
			end
		end
		
		menu:Open()
	end
	
	local cellName_Paint_interesting
	do
		local colorBull = Color(0,0,0, 127)
		local page_white_text = Material("icon16/page_white_text.png", "")
		local page_white_compressed = Material("icon16/page_white_compressed.png", "")
		local lightbulb = Material("icon16/lightbulb.png", "")
		cellName_Paint_interesting = function(self, w,h)
			local picto
			if self.has_text_format then
				picto = page_white_text
			elseif self.is_pak_file then
				picto = page_white_compressed
			elseif self.is_lighting then
				picto = lightbulb
			end
			if picto then
				draw.RoundedBoxEx(12, w - 20,(h - 24) / 2, 20,24, colorBull, true,false,true,false)
				surface.SetMaterial(picto)
				surface.SetDrawColor(255,255,255, 223)
				surface.DrawTexturedRect(w - 16,(h - 16) / 2, 16,16)
			end
			return false
		end
	end
	
	function makeLumpRow(lumpsList, rowIndex, info, context)
		local name = tostring(info.name)
		
		local row = vgui.Create(CLASS_GUI_LUMP_ROW, lumpsList) -- DPanel does not accept clicks
		row:SetPos(0, LUMP_ROW_MARGIN * rowIndex + LUMP_ROW_HEIGHT * (rowIndex - 1))
		row:SetSize(lumpsList:GetWide(), LUMP_ROW_HEIGHT)
		row.Paint = Paint
		row:SetMouseInputEnabled(true)
		row.DoRightClick = DoRightClick
		--[[
		row.rebuild = function(self)
			if name == "LUMP_GAME_LUMP" then
				-- Rebuild all game lump rows as well:
				local rowIndex_ = 1
				for i, row_ in ipairs(lumpsList:GetChildren()) do
					local info_ = row_.info
					if info_ and row_:GetClassName() == CLASS_GUI_LUMP_ROW then
						if info_.isGameLump then
							row_:Remove()
							makeLumpRow(lumpsList, rowIndex_, context:getUpdatedInfoLump(info_), context)
						end
						rowIndex_ = rowIndex_ + 1
					end
				end
			end
			self:Remove()
			return makeLumpRow(lumpsList, rowIndex, context:getUpdatedInfoLump(info), context)
		end
		]]
		row.info = info
		row.context = context
		
		local textColor = LUMP_ROW_TXCOLOR
		if info.modified or info.deleted then
			textColor = LUMP_ROW_TXCOLOR_MODIFIED
		elseif info.absent then
			textColor = LUMP_ROW_TXCOLOR_ABSENT
		end
		
		local x = 1 + LUMP_CELL_MARGIN_X
		local w
		local cellId = vgui.Create("DLabel", row); do
			cellId:SetTextColor(textColor)
			cellId:SetPos(x, 0)
			cellId:SetContentAlignment(ALIGN_MIDDLE_CENTER)
			w = LUMP_COLUMN_WIDTH_ID
			cellId:SetSize(w - LUMP_CELL_MARGIN_X_TOTAL, LUMP_ROW_HEIGHT)
			cellId:SetText(info.id == -1 and "↳" or tostring(info.id))
		end
		x = x + w
		local cellName = vgui.Create("DLabel", row); do
			cellName:SetTextColor(textColor)
			cellName:SetPos(x, 0)
			cellName:SetContentAlignment(ALIGN_MIDDLE_LEFT)
			w = LUMP_COLUMN_WIDTH_NAME
			cellName:SetSize(w - LUMP_CELL_MARGIN_X_TOTAL, LUMP_ROW_HEIGHT)
			cellName:SetText(name)
			local interesting = false
			if LUMPS_AS_TEXT[name] then
				cellName.has_text_format = true
				interesting = true
			elseif LUMPS_PAK_FILE[name] then
				cellName.is_pak_file = true
				interesting = true
			elseif LUMPS_LIGHTING[name] then
				cellName.is_lighting = true
				interesting = true
			end
			if interesting then
				cellName.Paint = cellName_Paint_interesting
			end
		end
		x = x + w
		local cellVersion = vgui.Create("DLabel", row); do
			cellVersion:SetTextColor(textColor)
			cellVersion:SetPos(x, 0)
			cellVersion:SetContentAlignment(ALIGN_MIDDLE_CENTER)
			w = LUMP_COLUMN_WIDTH_VERSION
			cellVersion:SetSize(w - LUMP_CELL_MARGIN_X_TOTAL, LUMP_ROW_HEIGHT)
			cellVersion:SetText(tostring(info.version))
		end
		x = x + w
		local cellSizeBefore = vgui.Create("DLabel", row); do
			cellSizeBefore:SetTextColor(textColor)
			cellSizeBefore:SetPos(x, 0)
			cellSizeBefore:SetContentAlignment(ALIGN_MIDDLE_RIGHT)
			w = LUMP_COLUMN_WIDTH_SIZE
			cellSizeBefore:SetSize(w - LUMP_CELL_MARGIN_X_TOTAL, LUMP_ROW_HEIGHT)
			cellSizeBefore:SetText(tostring(info.sizeBefore))
		end
		x = x + w
		local cellCompressedBefore = vgui.Create("DLabel", row); do
			cellCompressedBefore:SetTextColor(textColor)
			cellCompressedBefore:SetPos(x, 0)
			cellCompressedBefore:SetContentAlignment(ALIGN_MIDDLE_CENTER)
			w = LUMP_COLUMN_WIDTH_COMPRESSED
			cellCompressedBefore:SetSize(w - LUMP_CELL_MARGIN_X_TOTAL, LUMP_ROW_HEIGHT)
			cellCompressedBefore:SetText(info.compressedBefore and "Yes" or "No")
		end
		x = x + w
		local cellModified = vgui.Create("DLabel", row); do
			cellModified:SetTextColor(textColor)
			cellModified:SetPos(x, 0)
			cellModified:SetContentAlignment(ALIGN_MIDDLE_CENTER)
			w = LUMP_COLUMN_WIDTH_MODIFIED
			cellModified:SetSize(w - LUMP_CELL_MARGIN_X_TOTAL, LUMP_ROW_HEIGHT)
			cellModified:SetText(info.modified and "Yes" or "No")
		end
		x = x + w
		local cellSizeAfter = vgui.Create("DLabel", row); do
			cellSizeAfter:SetTextColor(textColor)
			cellSizeAfter:SetPos(x, 0)
			cellSizeAfter:SetContentAlignment(ALIGN_MIDDLE_RIGHT)
			w = LUMP_COLUMN_WIDTH_SIZE
			cellSizeAfter:SetSize(w - LUMP_CELL_MARGIN_X_TOTAL, LUMP_ROW_HEIGHT)
			cellSizeAfter:SetText(tostring(info.sizeAfter))
		end
		x = x + w
		local cellCompressedAfter = vgui.Create("DLabel", row); do
			cellCompressedAfter:SetTextColor(textColor)
			cellCompressedAfter:SetPos(x, 0)
			cellCompressedAfter:SetContentAlignment(ALIGN_MIDDLE_CENTER)
			w = LUMP_COLUMN_WIDTH_COMPRESSED
			cellCompressedAfter:SetSize(w - LUMP_CELL_MARGIN_X_TOTAL, LUMP_ROW_HEIGHT)
			cellCompressedAfter:SetText(info.compressedAfter and "Yes" or "No")
		end
		x = x + w
		
		-- TODO - info-bulle pour chaque lump
		
		return row
	end
end

local function lumpsList_Paint(self, w,h)
	surface.SetDrawColor(255,255,255, 255)
	surface.DrawRect(0,0, w,h)
	PaintLumpTableBorders(w, h)
	-- A bottom line will not show because it would be hidden.
end

local function openAssistant(mapName)
	local extension = string.lower(string.sub(mapName, -4, -1))
	if extension ~= ".bsp" and extension ~= ".dat" and string.find(mapName, "[\\/]", 1) == nil then
		mapName = "maps/" .. mapName .. ".bsp"
	end
	local context = api.BspContext:new(mapName)
	local info = context:getInfoMap()
	
	local assistant = vgui.Create("DFrame"); do
		assistant:MakePopup()
		assistant:SetKeyboardInputEnabled(false)
		assistant:SetSize(WIDTH, ScrH())
		assistant:Center()
		assistant:SetTitle("Momo's Map Manipulation Tool [alpha] • " .. mapName)
		assistant.btnMinim:SetVisible(false)
		assistant.btnMaxim:SetVisible(false)
		assistant.OnRemove = function(self)
			if self.context then
				self.context:close()
			end
			if IsValid(self.remover) then
				self.remover:Remove()
			end
		end
		assistant.context = context
	end
	
	local mapDetails = vgui.Create("DListView", assistant); do
		assistant.mapDetails = mapDetails
		mapDetails:SetPos(X_COL_1, TITLE_BAR_THICKNESS + MARGIN)
		mapDetails:AddColumn("Property")
		mapDetails:AddColumn("Value")
		mapDetails:AddLine("Map Revision", tostring(info.mapRevision))
		mapDetails:AddLine("Size", string.format("%.2f MiB", info.size / 1048576.))
		mapDetails:AddLine("Version", tostring(info.version))
		mapDetails:AddLine("Endianness", info.bigEndian and "Big" or "Little")
		mapDetails:SetSize(WIDTH_1_3, BUTTON_HEIGHT * 3 + MARGIN * 2)
	end
	
	local fillLumpsList
	local refreshLumpsList
	local lumpsList
	
	local btnEntitiesEditing = vgui.Create("DButton", assistant); do
		assistant.btnEntitiesEditing = btnEntitiesEditing
		btnEntitiesEditing:SetPos(X_COL_2_3, TITLE_BAR_THICKNESS + MARGIN)
		btnEntitiesEditing:SetSize(WIDTH_2_3, BUTTON_HEIGHT)
		btnEntitiesEditing:SetText("Enter Entity editing mode")
		btnEntitiesEditing:SetEnabled(false)
		-- TODO - donner une arme d'outil + masquer la fenêtre sauf dans le menu Echap
		-- TODO - ne pas oublier de supprimer l'arme d'outil lors de la fermeture
		-- TODO - refreshLumpsList()
	end
	
	local btnMoveEntitiesToLua = vgui.Create("DButton", assistant); do
		assistant.btnMoveEntitiesToLua = btnMoveEntitiesToLua
		local _, y = btnEntitiesEditing:GetPos()
		y = y + btnEntitiesEditing:GetTall() + MARGIN
		btnMoveEntitiesToLua:SetPos(X_COL_2_3, y)
		btnMoveEntitiesToLua:SetSize(WIDTH_2_3, BUTTON_HEIGHT)
		btnMoveEntitiesToLua:SetText("Remove many entities & put them into a Lua file")
		local function moveEntitiesToLua()
			context:moveEntitiesToLua()
			refreshLumpsList()
		end
		btnMoveEntitiesToLua.DoClick = function(self)
			Derma_Query(
				[[You are about to take a maximum of entities from the LUMP_ENTITIES.
A server-side Lua script will be generated to re-create these entities.
Only put this script on the server in the lua/autorun/server/ to keep it safe.

This feature is meant to dissuade map-stealers from using your map.
If you want to publish such maps on the Workshop, please use the type "ServerContent".
Never use the type "map" with protected maps!

Some advanced map features may get broken by this process.
The good news is that you can choose if a given entity should remain in the LUMP_ENTITIES or not!
Control is given my adding a hook on the event "map_manipulation_tool:moveEntitiesToLua:moveToLua".]],
				"LUMP_ENTITIES -> Lua", 
				"Continue", moveEntitiesToLua,
				"Cancel", nil
			)
		end
	end
	
	local btnPropsStaticToDynamic = vgui.Create("DButton", assistant); do
		assistant.btnPropsStaticToDynamic = btnPropsStaticToDynamic
		local _, y = btnMoveEntitiesToLua:GetPos()
		y = y + btnMoveEntitiesToLua:GetTall() + MARGIN
		btnPropsStaticToDynamic:SetPos(X_COL_2_3, y)
		btnPropsStaticToDynamic:SetSize(WIDTH_2_3, BUTTON_HEIGHT)
		btnPropsStaticToDynamic:SetText("Convert all prop_static's to prop_dynamic's")
		btnPropsStaticToDynamic.DoClick = function(self)
			context:convertStaticPropsToDynamic(true)
			refreshLumpsList()
		end
	end
	
	local btnHdrRemove = vgui.Create("DButton", assistant); do
		assistant.btnHdrRemove = btnHdrRemove
		local _, y = mapDetails:GetPos()
		y = y + mapDetails:GetTall() + MARGIN
		btnHdrRemove:SetPos(X_COL_1, y)
		btnHdrRemove:SetSize(WIDTH_1_3, BUTTON_HEIGHT)
		btnHdrRemove:SetText("Remove HDR")
		btnHdrRemove.DoClick = function(self)
			context:removeHdr(true)
			refreshLumpsList()
		end
	end
	
	local btnLightingRemove = vgui.Create("DButton", assistant); do
		assistant.btnLightingRemove = btnLightingRemove
		local x, y = btnHdrRemove:GetPos()
		x = x + btnHdrRemove:GetWide() + MARGIN
		btnLightingRemove:SetPos(x, y)
		btnLightingRemove:SetSize(WIDTH_1_3, BUTTON_HEIGHT)
		btnLightingRemove:SetText("Remove Lighting")
		btnLightingRemove.DoClick = function(self)
			context:clearLump(false, api.getLumpIdFromLumpName("LUMP_LIGHTING_HDR"))
			context:clearLump(false, api.getLumpIdFromLumpName("LUMP_LIGHTING"))
			refreshLumpsList()
		end
	end
	
	local btnRemoveEntitiesByClass = vgui.Create("DButton", assistant); do
		assistant.btnRemoveEntitiesByClass = btnRemoveEntitiesByClass
		local x, y = btnLightingRemove:GetPos()
		x = x + btnLightingRemove:GetWide() + MARGIN
		btnRemoveEntitiesByClass:SetPos(x, y)
		btnRemoveEntitiesByClass:SetSize(WIDTH_1_3, BUTTON_HEIGHT)
		btnRemoveEntitiesByClass:SetText("Remove entities by class")
		btnRemoveEntitiesByClass.DoClick = function(self)
			openEntitiesByClassRemover(assistant)
		end
	end
	
	local hdrId = makeLumpColumnHeader(assistant, "Id"); do
		local x, y = btnHdrRemove:GetPos()
		y = y + btnHdrRemove:GetTall() + MARGIN
		hdrId:SetPos(x, y)
		hdrId:SetSize(LUMP_COLUMN_WIDTH_ID, LUMP_HEADER_HEIGHT_1 * 2)
	end
	
	local hdrName = makeLumpColumnHeader(assistant, "Name"); do
		local x, y = hdrId:GetPos()
		x = x + hdrId:GetWide()
		hdrName:SetPos(x, y)
		hdrName:SetSize(LUMP_COLUMN_WIDTH_NAME, LUMP_HEADER_HEIGHT_1 * 2)
	end
	
	local hdrVersion = makeLumpColumnHeader(assistant, "Version"); do
		local x, y = hdrName:GetPos()
		x = x + hdrName:GetWide()
		hdrVersion:SetPos(x, y)
		hdrVersion:SetSize(LUMP_COLUMN_WIDTH_VERSION, LUMP_HEADER_HEIGHT_1 * 2)
	end
	
	local hdrSizeBefore = makeLumpColumnHeader(assistant, "Size"); do
		local x, y = hdrVersion:GetPos()
		x = x + hdrVersion:GetWide()
		y = y + LUMP_HEADER_HEIGHT_1
		hdrSizeBefore:SetPos(x, y)
		hdrSizeBefore:SetSize(LUMP_COLUMN_WIDTH_SIZE, LUMP_HEADER_HEIGHT_1)
	end
	
	local hdrCompressedBefore = makeLumpColumnHeader(assistant, "Compressed"); do
		local x, y = hdrSizeBefore:GetPos()
		x = x + hdrSizeBefore:GetWide()
		hdrCompressedBefore:SetPos(x, y)
		hdrCompressedBefore:SetSize(LUMP_COLUMN_WIDTH_COMPRESSED, LUMP_HEADER_HEIGHT_1)
	end
	
	local hdrTopBefore = makeLumpColumnHeader(assistant, "Before"); do
		local x, y = hdrVersion:GetPos()
		x = x + hdrVersion:GetWide()
		hdrTopBefore:SetPos(x, y)
		local w = hdrSizeBefore:GetWide() + hdrCompressedBefore:GetWide()
		hdrTopBefore:SetSize(w, LUMP_HEADER_HEIGHT_1)
	end
	
	local hdrModified = makeLumpColumnHeader(assistant, "Modified"); do
		local x, y = hdrTopBefore:GetPos()
		x = x + hdrTopBefore:GetWide()
		y = y + LUMP_HEADER_HEIGHT_1
		hdrModified:SetPos(x, y)
		hdrModified:SetSize(LUMP_COLUMN_WIDTH_MODIFIED, LUMP_HEADER_HEIGHT_1)
	end
	
	local hdrSizeAfter = makeLumpColumnHeader(assistant, "Size"); do
		local x, y = hdrModified:GetPos()
		x = x + hdrModified:GetWide()
		hdrSizeAfter:SetPos(x, y)
		hdrSizeAfter:SetSize(LUMP_COLUMN_WIDTH_SIZE, LUMP_HEADER_HEIGHT_1)
	end
	
	local hdrCompressedAfter = makeLumpColumnHeader(assistant, "Compressed"); do
		local x, y = hdrSizeAfter:GetPos()
		x = x + hdrSizeAfter:GetWide()
		hdrCompressedAfter:SetPos(x, y)
		hdrCompressedAfter:SetSize(LUMP_COLUMN_WIDTH_COMPRESSED, LUMP_HEADER_HEIGHT_1)
	end
	
	local hdrTopAfter = makeLumpColumnHeader(assistant, "After"); do
		local x, y = hdrTopBefore:GetPos()
		x = x + hdrTopBefore:GetWide()
		hdrTopAfter:SetPos(x, y)
		local w = hdrModified:GetWide() + hdrSizeAfter:GetWide() + hdrCompressedAfter:GetWide()
		hdrTopAfter:SetSize(w, LUMP_HEADER_HEIGHT_1)
	end
	
	local hdrSpare = makeLumpColumnHeader(assistant, ""); do
		local x, y = hdrTopAfter:GetPos()
		x = x + hdrTopAfter:GetWide()
		hdrSpare:SetPos(x, y)
		hdrSpare:SetSize(LUMP_COLUMN_WIDTH_SPARE, LUMP_HEADER_HEIGHT_1 * 2)
	end
	
	local btnRevertAll = vgui.Create("DButton", assistant); do
		assistant.btnRevertAll = btnRevertAll
		btnRevertAll:SetSize(WIDTH_1_2, BUTTON_HEIGHT)
		local y = assistant:GetTall() - MARGIN - BUTTON_HEIGHT
		local title = "Revert all changes"
		btnRevertAll:SetPos(X_COL_1, y)
		btnRevertAll:SetText(title)
		btnRevertAll.DoClick = function(self)
			Derma_Query(
				"You will lose every modification.\nContinue?",
				title,
				"Yes", function()
					context:resetOutputListing()
					refreshLumpsList()
				end,
				"Cancel", nil
			)
		end
	end
	
	local btnSave = vgui.Create("DButton", assistant); do
		assistant.btnSave = btnSave
		local _, y = btnRevertAll:GetPos()
		btnSave:SetSize(WIDTH_1_2, BUTTON_HEIGHT)
		btnSave:SetPos(X_COL_2_2, y)
		btnSave:SetText("Save the modified map")
		btnSave.DoClick = function(self)
			DialogFileSelector:new(box, function(selector, folderBase, filenameDst)
				local asyncData = api.asyncWork(
					function()
						Derma_Message(
							"The modified map has been successfully saved!",
							"Save as",
							"Okay"
						)
					end,
					function(message)
						Derma_Message(
							"The following error occurred while saving the modified map:\n" .. message,
							"Save as",
							"Cancel"
						)
					end,
					function(step, stepCount, stepProgress)
						-- TODO
					end,
					0.1, -- target = 10 fps
					context.writeNewBsp, context, filenameDst
				)
				-- TODO - afficher exportation & progression - DProgress
			end, true, "DATA", "/", "*.bsp.dat *.bsp", info.title .. "_mod.bsp.dat")
		end
	end
	
	function fillLumpsList()
		local allLumps = context:getInfoLumps(true)
		for i = 1, #allLumps do
			makeLumpRow(lumpsList, i, allLumps[i], context)
		end
	end
	
	function refreshLumpsList()
		for i, row_ in ipairs(lumpsList:GetChildren()) do
			if row_.info and row_:GetClassName() == CLASS_GUI_LUMP_ROW then
				row_:Remove()
			end
		end
		fillLumpsList()
	end
	
	lumpsList = vgui.Create("DScrollPanel", assistant); do
		assistant.lumpsList = lumpsList
		lumpsList.refreshLumpsList = refreshLumpsList
		local x, y = hdrId:GetPos()
		y = y + hdrId:GetTall()
		lumpsList:SetPos(x, y)
		local h = ({btnRevertAll:GetPos()})[2] - y - MARGIN
		lumpsList:SetSize(WIDTH_1_1, h)
		lumpsList.Paint = lumpsList_Paint
		lumpsList.mapTitle = info.title
		fillLumpsList()
	end
end

local helpMessage = [[map_manipulation_tool <mapName>
   Open a map in Momo's Map Manipulation Tool
   mapName: map name or .bsp file path relative to garrysmod/ (may be case-sensitive)

   Exemples:
   - map_manipulation_tool gm_flatgrass
   - map_manipulation_tool "maps/gm_flatgrass.bsp"]]

concommand.Add("map_manipulation_tool",
	function(ply, cmd, args)
		local mapName = args[1]
		if mapName == nil then
			print(" - " .. helpMessage)
		else
			openAssistant(mapName)
		end
	end,
	function(cmd, args)
		local _, _, mapName = string.find(args, "^%s+([^%s]+)")
		if mapName == nil then
			mapName = "" -- no map name typed yet
		elseif string.find(mapName, '^[^\\/:%*%?"<>|%z\x01-\x1F]+$') == nil then
			return nil -- map name contains illegal characters
		end
		local maps = file.Find("maps/" .. mapName .. "*.bsp", "GAME")
		local suggestions = {}
		for i, mapName_ in ipairs(maps) do
			-- Adding the command & removing extensions:
			suggestions[i] = cmd .. " " .. string.sub(mapName_, 1, -5)
			if i >= 10 then
				-- The auto-completion is limited to 9 suggestions, outputting 10 shows a triple-dot.
				break
			end
		end
		return suggestions
	end,
	helpMessage
)
