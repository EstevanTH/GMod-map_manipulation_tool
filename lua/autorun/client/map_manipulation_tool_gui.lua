print("map_manipulation_tool_gui")

local api = map_manipulation_tool_api
local surface = surface

local reloadTranslations -- function defined later
local hl = GetConVar("gmod_language"):GetString()
cvars.AddChangeCallback("gmod_language", function(convar, oldValue, newValue)
	hl = newValue
	reloadTranslations()
end, "map_manipulation_tool_gui")

local TITLE_BAR_THICKNESS = 24
local SCROLL_BAR_THICKNESS = 15
local BUTTON_HEIGHT = 24
local STATUS_BAR_HEIGHT = 16
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


local lumpTooltips -- Lua id -> text
function reloadTranslations()
	-- Some descriptions are borrowed from https://developer.valvesoftware.com/wiki/Source_BSP_File_Format
	local luaIdOf = api.getLumpIdFromLumpName
	lumpTooltips = {}
	lumpTooltips[luaIdOf("LUMP_ENTITIES")] =
		hl == "fr" and
		[[Contient les entités, à l'exclusion des entités internes]] or
		[[Contains entities, excluding internal entities]]
	lumpTooltips[luaIdOf("LUMP_PLANES")] =
		[[Plane array]]
	lumpTooltips[luaIdOf("LUMP_TEXDATA")] =
		hl == "fr" and
		[[Informations sur les textures utilisées dans la carte, les info_overlays et les entités brush]] or
		[[Information about textures used in the map, in info_overlay's and in brush entities]]
	lumpTooltips[luaIdOf("LUMP_VERTEXES")] =
		[[Vertex array]]
	lumpTooltips[luaIdOf("LUMP_VISIBILITY")] =
		[[Compressed visibility bit arrays]]
	lumpTooltips[luaIdOf("LUMP_NODES")] =
		[[BSP tree nodes]]
	lumpTooltips[luaIdOf("LUMP_TEXINFO")] =
		hl == "fr" and
		[[Informations sur les textures des faces de la carte, les info_overlays et les entités brush]] or
		[[Information about the textures of faces of the map, the info_overlay's and the brush entities]]
	lumpTooltips[luaIdOf("LUMP_FACES")] =
		[[Face array]]
	lumpTooltips[luaIdOf("LUMP_LIGHTING")] =
		hl == "fr" and
		[[Échantillons de lightmap (sans HDR)]] or
		[[Lightmap samples (without HDR)]]
	lumpTooltips[luaIdOf("LUMP_OCCLUSION")] =
		[[Occlusion polygons and vertices]]
	lumpTooltips[luaIdOf("LUMP_LEAFS")] =
		[[BSP tree leaf nodes]]
	lumpTooltips[luaIdOf("LUMP_FACEIDS")] =
		[[Correlates between dfaces and Hammer face IDs. Also used as random seed for detail prop placement.]]
	lumpTooltips[luaIdOf("LUMP_EDGES")] =
		[[Edge array]]
	lumpTooltips[luaIdOf("LUMP_SURFEDGES")] =
		[[Index of edges]]
	lumpTooltips[luaIdOf("LUMP_MODELS")] =
		[[Brush models (geometry of brush entities)]]
	lumpTooltips[luaIdOf("LUMP_WORLDLIGHTS")] =
		hl == "fr" and
		[[Lumières internes du monde converties depuis le LUMP_ENTITIES (sans HDR)]] or
		[[Internal world lights converted from the LUMP_ENTITIES (without HDR)]]
	lumpTooltips[luaIdOf("LUMP_LEAFFACES")] =
		[[Index to faces in each leaf]]
	lumpTooltips[luaIdOf("LUMP_LEAFBRUSHES")] =
		[[Index to brushes in each leaf]]
	lumpTooltips[luaIdOf("LUMP_BRUSHES")] =
		[[Brush array]]
	lumpTooltips[luaIdOf("LUMP_BRUSHSIDES")] =
		[[Brushside array]]
	lumpTooltips[luaIdOf("LUMP_AREAS")] =
		[[Area array]]
	lumpTooltips[luaIdOf("LUMP_AREAPORTALS")] =
		[[Portals between areas]]
	lumpTooltips[luaIdOf("LUMP_PORTALS")] =
[[(Multiple matches)
LUMP_PORTALS:
Confirm: Polygons defining the boundary between adjacent leaves?
LUMP_PROPCOLLISION:
Static props convex hull lists]]
	lumpTooltips[luaIdOf("LUMP_CLUSTERS")] =
[[(Multiple matches)
LUMP_CLUSTERS:
Leaves that are enterable by the player
LUMP_PROPHULLS:
Static prop convex hulls]]
	lumpTooltips[luaIdOf("LUMP_PORTALVERTS")] =
[[(Multiple matches)
LUMP_PORTALVERTS:
Vertices of portal polygons
LUMP_PROPHULLVERTS:
Static prop collision vertices]]
	lumpTooltips[luaIdOf("LUMP_CLUSTERPORTALS")] =
[[(Multiple matches)
LUMP_CLUSTERPORTALS:
Confirm: Polygons defining the boundary between adjacent clusters?
LUMP_PROPTRIS:
Static prop per hull triangle index start/count]]
	lumpTooltips[luaIdOf("LUMP_DISPINFO")] =
		[[Displacement surface array]]
	lumpTooltips[luaIdOf("LUMP_ORIGINALFACES")] =
		[[Brush faces array before splitting]]
	lumpTooltips[luaIdOf("LUMP_PHYSDISP")] =
		[[Displacement physics collision data]]
	lumpTooltips[luaIdOf("LUMP_PHYSCOLLIDE")] =
		[[Physics collision data]]
	lumpTooltips[luaIdOf("LUMP_VERTNORMALS")] =
		[[Face plane normals]]
	lumpTooltips[luaIdOf("LUMP_VERTNORMALINDICES")] =
		[[Face plane normal index array]]
	lumpTooltips[luaIdOf("LUMP_DISP_LIGHTMAP_ALPHAS")] =
		[[Displacement lightmap alphas]]
	lumpTooltips[luaIdOf("LUMP_DISP_VERTS")] =
		[[Vertices of displacement surface meshes]]
	lumpTooltips[luaIdOf("LUMP_DISP_LIGHTMAP_SAMPLE_POSITIONS")] =
		[[Displacement lightmap sample positions]]
	lumpTooltips[luaIdOf("LUMP_GAME_LUMP")] =
		hl == "fr" and
		[[Contient les lumps qui ne sont pas inclus dans la numérotation initiale]] or
		[[Contains the lumps that are not included in the initial numbering]]
	lumpTooltips[luaIdOf("LUMP_LEAFWATERDATA")] =
		[[Data for leaf nodes that are inside water]]
	lumpTooltips[luaIdOf("LUMP_PRIMITIVES")] =
		[[Water polygon data]]
	lumpTooltips[luaIdOf("LUMP_PRIMVERTS")] =
		[[Water polygon vertices]]
	lumpTooltips[luaIdOf("LUMP_PRIMINDICES")] =
		[[Water polygon vertex index array]]
	lumpTooltips[luaIdOf("LUMP_PAKFILE")] =
		hl == "fr" and
		[[Archive .zip sans compression montée dans le jeu, contenant les fichiers embarqués dans la carte]] or
		[[.zip archive without compression mounted in the game, containing the files embedded in the map]]
	lumpTooltips[luaIdOf("LUMP_CLIPPORTALVERTS")] =
		[[Clipped portal polygon vertices]]
	lumpTooltips[luaIdOf("LUMP_CUBEMAPS")] =
		[[env_cubemap location array]]
	lumpTooltips[luaIdOf("LUMP_TEXDATA_STRING_DATA")] =
		hl == "fr" and
[[Contient les noms de matériaux (sans extension) utilisés dans la carte, les info_overlays et les entités brush
L'exploitation du format texte dépend du LUMP_TEXDATA_STRING_TABLE.]] or
[[Contains the material names (without extension) used in the map, in info_overlay's and in brush entities
Utilizing the text format depends on the LUMP_TEXDATA_STRING_TABLE.]]
	lumpTooltips[luaIdOf("LUMP_TEXDATA_STRING_TABLE")] =
		hl == "fr" and
		[[Associe séquentiellement chaque n° de matériau à sa position dans le LUMP_TEXDATA_STRING_DATA]] or
		[[Associates sequentially each material number into its position in the LUMP_TEXDATA_STRING_DATA]]
	lumpTooltips[luaIdOf("LUMP_OVERLAYS")] =
		hl == "fr" and
[[Contient les entités info_overlay
L'exploitation du format texte dépend du LUMP_TEXINFO, du LUMP_TEXDATA, du LUMP_TEXDATA_STRING_TABLE et du LUMP_TEXDATA_STRING_DATA.]] or
[[Contains info_overlay entities
Utilizing the text format depends on the LUMP_TEXINFO, the LUMP_TEXDATA, the LUMP_TEXDATA_STRING_TABLE and the LUMP_TEXDATA_STRING_DATA.]]
	lumpTooltips[luaIdOf("LUMP_LEAFMINDISTTOWATER")] =
		[[Distance from leaves to water]]
	lumpTooltips[luaIdOf("LUMP_FACE_MACRO_TEXTURE_INFO")] =
		[[Macro texture info for faces]]
	lumpTooltips[luaIdOf("LUMP_DISP_TRIS")] =
		[[Displacement surface triangles]]
	lumpTooltips[luaIdOf("LUMP_PHYSCOLLIDESURFACE")] =
[[(Multiple matches)
LUMP_PHYSCOLLIDESURFACE:
Compressed win32-specific Havok terrain surface collision data
LUMP_PROP_BLOB:
Static prop triangle and string data]]
	lumpTooltips[luaIdOf("LUMP_WATEROVERLAYS")] =
		[[Confirm: info_overlay's on water faces?]]
	lumpTooltips[luaIdOf("LUMP_LEAF_AMBIENT_INDEX_HDR")] =
[[(Multiple matches)
LUMP_LEAF_AMBIENT_INDEX_HDR:
Index of LUMP_LEAF_AMBIENT_LIGHTING_HDR
LUMP_LIGHTMAPPAGES:
Alternate lightdata implementation for Xbox]]
	lumpTooltips[luaIdOf("LUMP_LEAF_AMBIENT_INDEX")] =
[[(Multiple matches)
LUMP_LEAF_AMBIENT_INDEX:
Index of LUMP_LEAF_AMBIENT_LIGHTING
LUMP_LIGHTMAPPAGEINFOS:
Alternate lightdata indices for Xbox]]
	lumpTooltips[luaIdOf("LUMP_LIGHTING_HDR")] =
		hl == "fr" and
		[[Échantillons de lightmap (avec HDR)]] or
		[[Lightmap samples (with HDR)]]
	lumpTooltips[luaIdOf("LUMP_WORLDLIGHTS_HDR")] =
		hl == "fr" and
		[[Lumières internes du monde converties depuis le LUMP_ENTITIES (avec HDR)]] or
		[[Internal world lights converted from the LUMP_ENTITIES (with HDR)]]
	lumpTooltips[luaIdOf("LUMP_LEAF_AMBIENT_LIGHTING_HDR")] =
		hl == "fr" and
		[[Échantillons de lumière ambiante par leaf (HDR)]] or
		[[Per-leaf ambient light samples (HDR)]]
	lumpTooltips[luaIdOf("LUMP_LEAF_AMBIENT_LIGHTING")] =
		hl == "fr" and
		[[Échantillons de lumière ambiante par leaf (LDR)]] or
		[[Per-leaf ambient light samples (LDR)]]
	lumpTooltips[luaIdOf("LUMP_XZIPPAKFILE")] =
		[[XZip version of pak file for Xbox]]
	lumpTooltips[luaIdOf("LUMP_FACES_HDR")] =
		[[HDR maps may have different face data]]
	lumpTooltips[luaIdOf("LUMP_MAP_FLAGS")] =
		[[Extended level-wide flags]]
	lumpTooltips[luaIdOf("LUMP_OVERLAY_FADES")] =
		[[Fade distances for overlays]]
	lumpTooltips[luaIdOf("LUMP_OVERLAY_SYSTEM_LEVELS")] =
		[[System level settings (min/max CPU & GPU to render this overlay)]]
	lumpTooltips[luaIdOf("LUMP_PHYSLEVEL")] =
		[[LUMP_PHYSLEVEL]]
	lumpTooltips[luaIdOf("LUMP_DISP_MULTIBLEND")] =
		[[Displacement multiblend info]]
	lumpTooltips[luaIdOf("sprp")] =
		hl == "fr" and
		[[Contient les entités prop_static]] or
		[[Contains prop_static entities]]
	lumpTooltips[luaIdOf("dprp")] =
		hl == "fr" and
		[[Contient les entités prop_detail]] or
		[[Contains prop_detail entities]]
	lumpTooltips[luaIdOf("dplt")] =
		[[dplt]]
	lumpTooltips[luaIdOf("dplh")] =
		[[dplh]]
end
reloadTranslations()

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
						(
							hl == "fr" and "Le fichier spécifié existe déjà !\nVeux-tu le remplacer ?" or
							"The specified file already exists!\nDo you want to overwrite it?"),
						(
							hl == "fr" and "Enregistrer sous" or
							"Save as"),
						(
							hl == "fr" and "Oui" or
							"Yes"), submit,
						(
							hl == "fr" and "Annuler" or
							"Cancel"), nil
					)
				else
					submit()
				end
			else
				if selector.withSave then
					submit()
				else
					Derma_Message(
						(
							hl == "fr" and "Le fichier spécifié n'existe pas !" or
							"The specified file does not exist!"),
						(
							hl == "fr" and "Ouvrir" or
							"Open"),
						(
							hl == "fr" and "OK" or
							"Okay")
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
				(
					hl == "fr" and "Les dossiers ne peuvent pas être créés en-dehors du répertoire de base DATA !" or
					"Folders cannot be created outside the DATA folder base!"),
				(
					hl == "fr" and "Enregistrer sous" or
					"Save as"),
				(
					hl == "fr" and "OK" or
					"Okay")
			)
		elseif file.IsDir(fullPath, folderBase) then
			Derma_Message(
				(
					hl == "fr" and "Le répertoire spécifié existe déjà !" or
					"The specified folder already exists!"),
				(
					hl == "fr" and "Enregistrer sous" or
					"Save as"),
				(
					hl == "fr" and "OK" or
					"Okay")
			)
		elseif file.Exists(fullPath, folderBase) then
			Derma_Message(
				(
					hl == "fr" and "Le répertoire spécifié correspond à un fichier qui existe déjà !" or
					"The specified folder names a file that already exists!"),
				(
					hl == "fr" and "Enregistrer sous" or
					"Save as"),
				(
					hl == "fr" and "OK" or
					"Okay")
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
				(
					hl == "fr" and "Le nouveau répertoire n'a pas pu être créé !" or
					"The new folder could not be created!"),
				(
					hl == "fr" and "Enregistrer sous" or
					"Save as"),
				(
					hl == "fr" and "OK" or
					"Okay")
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
				box:SetTitle(
					withSave and (
						hl == "fr" and "Enregistrer sous" or
						"Save as")
					or (
						hl == "fr" and "Ouvrir" or
						"Open")
				)
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
					buttonOpenSave:SetText(
						withSave and (
							hl == "fr" and "Enregistrer" or
							"Save")
						or (
							hl == "fr" and "Ouvrir" or
							"Open")
					)
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
					buttonNewFolder:SetText(
						hl == "fr" and "Comme nouveau dossier" or
						"As new folder"
					)
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

-- Warning: always edit assistant.OnRemove() to remove windows that depend on the assistant!

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
		-- TODO - page correspondante (GitHub) si entité connue
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
			surface.SetFont("Trebuchet18")
			local txt_x = 4
			local txt_w = surface.GetTextSize(self.classname)
			surface.SetTextPos(txt_x, 7)
			surface.DrawText(self.classname)
			if self.entityCount then
				if self.removed then
					--surface.SetTextColor(127, 127, 127)
				else
					surface.SetTextColor(95, 95, 95)
				end
				txt_x = txt_x + txt_w + 6
				surface.SetTextPos(txt_x, 7)
				surface.DrawText(self.entityCount)
			end
		end
	end
	
	local function makeClassRow(remover, classesList, classname, entityCount)
		local rowWidth = classesList:GetWide()
		local row = vgui.Create("DPanel", classesList); do
			row.Paint = row_Paint
			row.classname = classname
			row.entityCount = entityCount and "(" .. entityCount .. ")" or nil
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
				btnRemove:SetText(
					hl == "fr" and "Supprimer occurrences" or
					"Remove occurrences"
				)
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
			btnWiki:SetText(
				hl == "fr" and "Ouvrir le Wiki" or
				"Open the Wiki"
			)
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
			remover:SetTitle(
				hl == "fr" and "Enlever entités par classe" or
				"Remove entities by class"
			)
			remover.btnMinim:SetVisible(false)
			remover.btnMaxim:SetVisible(false)
			remover.assistant = assistant
			remover.context = context
			assistant.remover = remover
		end
		local classes, classCounts = context:getPresentEntityClasses(true)
		local classesList = vgui.Create("DScrollPanel", remover)
		classesList:SetPos(MARGIN, TITLE_BAR_THICKNESS + MARGIN)
		classesList:SetWide(WIDTH_1_1)
		for i, classname in ipairs(classes) do
			local row = makeClassRow(remover, classesList, classname, classCounts[classname])
			row:SetPos(0, (i - 1) * (ROW_HEIGHT + ROW_SPACING))
		end
		
		local x, y = classesList:GetPos()
		classesList:SetTall(math.min(
			(#classes * (ROW_HEIGHT + ROW_SPACING)) - ROW_SPACING,
			ScrH() - y - MARGIN
		))
		remover:SetTall(y + classesList:GetTall() + MARGIN)
		remover:Center()
		
		return remover
	end
end

local openMaterialBrowserOverlayDecal
do
	local flagsAlphaMask = 2097184 -- $translucent & $vertexalpha
	
	local function stripAlpha(flags)
		-- Unset $translucent & $vertexalpha:
		return bit.band(flags, bit.bnot(flagsAlphaMask))
	end
	
	local function restoreAlpha(flags, flagsAlpha)
		-- Set $translucent & $vertexalpha as they originally were:
		return bit.bor(flags, flagsAlpha)
	end
	
	local copyButtonTooltip
	
	local makePreview
	do
		surface.CreateFont(
			"map_manipulation_tool:matBroDetails",
			{
				size = 15,
				weight = 750,
				outline = true,
			}
		)
		
		local function preview_Paint(self, w, h)
			local materialBrowserOverlayDecal = self.materialBrowserOverlayDecal
			do
				draw.NoTexture()
				local whiteStrength
				if materialBrowserOverlayDecal.enabledBgAnim then
					whiteStrength = math.floor(RealTime() * 128.) % 510
					if whiteStrength > 255 then
						whiteStrength = 510 - whiteStrength
					end
					materialBrowserOverlayDecal.whiteStrength = whiteStrength
				else
					whiteStrength = materialBrowserOverlayDecal.whiteStrength or 0
				end
				surface.SetDrawColor(whiteStrength, whiteStrength, whiteStrength, 255)
				surface.DrawTexturedRect(0, 0, w, h)
			end
			-- if self.textureId then
			if self.material then
				surface.SetMaterial(self.material)
				surface.SetDrawColor(255, 255, 255, 255)
				surface.DrawTexturedRect(0, 0, w, h)
			end
			local hovered = (self:IsHovered() or self:IsChildHovered(true))
			self.copyButton:SetVisible(hovered)
			if hovered then
				surface.SetFont("map_manipulation_tool:matBroDetails")
				local txt_x, txt_y = 4, 2
				local txt_w, txt_h = surface.GetTextSize(self.materialPath)
				draw.NoTexture()
				surface.SetDrawColor(0, 0, 0, 170)
				surface.DrawTexturedRect(txt_x - 4, txt_y - 2, txt_w + 8, txt_h + 4)
				self.materialDisplay:Draw(txt_x, txt_y, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
			end
		end
		
		local copyButton_DoClick = function(self)
			SetClipboardText(self:GetParent().materialPath)
		end
		
		local patchIncludeSections = {"insert", "replace"}
		
		function makePreview(parent, w, h, materialPath, countOverlay, countDecal)
			local previewMaterial
			local flagsAlpha = 0
			do
				local keyValues
				do
					local keyValues_
					local shader
					do
						local materialText = file.Read("materials/" .. materialPath .. ".vmt", "GAME")
						if materialText then
							keyValues_ = util.KeyValuesToTable('"material"\n{\n' .. materialText .. "\n}")
							shader, keyValues_ = next(keyValues_) -- select material content
							if not istable(keyValues_) then
								keyValues_ = nil
							end
						end
					end
					if keyValues_ then
						shader = string.lower(tostring(shader))
						if shader == "patch" then
							-- Another material must be included:
							local keyValues2
							do
								local material2Path = keyValues_["include"]
								if material2Path then
									local material2Text = file.Read(material2Path, "GAME")
									if material2Text then
										keyValues2 = util.KeyValuesToTable(material2Text)
										if not istable(keyValues2) then
											keyValues2 = nil
										end
									end
								end
							end
							if keyValues2 then
								for _, section in ipairs(patchIncludeSections) do
									local keyValues__ = keyValues_[section]
									if istable(keyValues__) then
										for k, v in pairs(keyValues__) do
											if v == "" then
												keyValues2[k] = nil
											else
												keyValues2[k] = v
											end
										end
									end
								end
								keyValues = keyValues2
							end
						else
							-- Simply use the material keyvalues:
							keyValues = keyValues_
						end
					end
				end
				if not keyValues then
					keyValues = {
						["$basetexture"] = "debug/debugempty",
					}
				end
				keyValues["$envmap"] = nil
				keyValues["$envmapmask"] = nil
				previewMaterial = CreateMaterial(
					"map_manipulation_tool:" .. materialPath,
					"unlitgeneric",
					keyValues
				)
				if previewMaterial then
					local flags = previewMaterial:GetInt("$flags") or 0
					flagsAlpha = bit.band(flags, flagsAlphaMask)
					flags = stripAlpha(flags)
					flags = bit.bor(flags, 32768) -- set $ignorez
					previewMaterial:SetInt("$flags", flags)
				end
			end
			local preview = vgui.Create("DPanel", parent); do
				preview:SetSize(w, h)
				preview.Paint = preview_Paint
				preview.materialPath = materialPath
				--preview.textureId = surface.GetTextureID(materialPath)
				preview.material = previewMaterial
				preview.flagsAlpha = flagsAlpha
				local textLines = {
					materialPath,
					"",
					(
						hl == "fr" and
						"Utilisations :" or
						"Uses:"),
				}
				if countOverlay > 0 then
					textLines[#textLines + 1] = "► " .. countOverlay .. " (info_overlay)"
				end
				if countDecal > 0 then
					textLines[#textLines + 1] = "► " .. countDecal .. " (infodecal)"
				end
				preview.materialDisplay = markup.Parse(
					"<font=map_manipulation_tool:matBroDetails><colour=255,255,0,255>" .. table.concat(textLines, "\n"),
					w - 4
				)
			end
			local copyButton = vgui.Create("DButton", preview); do
				preview.copyButton = copyButton
				copyButton:SetSize(BUTTON_HEIGHT, BUTTON_HEIGHT)
				copyButton:SetPos(
					w - MARGIN - BUTTON_HEIGHT,
					h - MARGIN - BUTTON_HEIGHT
				)
				copyButton.DoClick = copyButton_DoClick
				copyButton:SetImage("icon16/page_copy.png")
				copyButton:SetText("")
				copyButton:SetTooltip(copyButtonTooltip)
				copyButton:SetVisible(false)
			end
			return preview
		end
	end
	
	local buttonWidth_1_1 = 640 - MARGIN - MARGIN - SCROLL_BAR_THICKNESS - MARGIN
	local buttonWidth_1_2 = (buttonWidth_1_1 - MARGIN) / 2
	local buttonWidth_1_3 = (buttonWidth_1_1 - MARGIN - MARGIN) / 3
	local buttonWidth_2_3 = buttonWidth_1_3 + MARGIN + buttonWidth_1_3
	local buttonX_COL_1 = 0
	local buttonX_COL_2_2 = MARGIN + buttonWidth_1_2
	local buttonX_COL_2_3 = MARGIN + buttonWidth_1_3
	local buttonX_COL_3_3 = MARGIN + buttonWidth_2_3
	
	local textToggleAlpha_Enable
	local textToggleAlpha_Disable
	local textToggleBgAnim_Enable
	local textToggleBgAnim_Disable
	
	local function btnToggleAlpha_DoClick(self)
		local materialBrowserOverlayDecal = self.materialBrowserOverlayDecal
		if materialBrowserOverlayDecal.enabledAlpha then
			materialBrowserOverlayDecal.enabledAlpha = false
			self:SetText(textToggleAlpha_Enable)
			for materialPath, preview in pairs(materialBrowserOverlayDecal.previews) do
				preview.material:SetInt("$flags", stripAlpha(preview.material:GetInt("$flags")))
			end
		else
			materialBrowserOverlayDecal.enabledAlpha = true
			self:SetText(textToggleAlpha_Disable)
			for materialPath, preview in pairs(materialBrowserOverlayDecal.previews) do
				preview.material:SetInt("$flags", restoreAlpha(preview.material:GetInt("$flags"), preview.flagsAlpha))
			end
		end
	end
	
	local function btnToggleBgAnim_DoClick(self)
		local materialBrowserOverlayDecal = self.materialBrowserOverlayDecal
		if materialBrowserOverlayDecal.enabledBgAnim then
			materialBrowserOverlayDecal.enabledBgAnim = false
			self:SetText(textToggleBgAnim_Enable)
		else
			materialBrowserOverlayDecal.enabledBgAnim = true
			self:SetText(textToggleBgAnim_Disable)
		end
	end
	
	local conVarTextureDetails = GetConVar("mat_picmip")
	
	local previewResolutions = {128, 192, 256, 384, 512, 768, 1024, 1536, 2048}
	
	function openMaterialBrowserOverlayDecal(assistant)
		if IsValid(assistant.materialBrowserOverlayDecal) then
			assistant.materialBrowserOverlayDecal:Remove()
		end
		local scr_w, scr_h = ScrW(), ScrH()
		local previewResolution
		local previewsPerRow
		do
			-- The extra MARGIN is the ending margin, which is not required but used to determine the number of fitting previews.
			local widthBase = scr_w - MARGIN - MARGIN - SCROLL_BAR_THICKNESS - MARGIN + MARGIN
			local heightBase = scr_h - TITLE_BAR_THICKNESS - MARGIN - MARGIN + MARGIN
			for i = #previewResolutions, 1, -1 do
				-- The goal is to have a minimum of 3 previews per row and 2 rows fitting on the screen.
				local resolution = previewResolutions[i]
				previewsPerRow = math.floor(widthBase / (resolution + MARGIN))
				local rowsOnScreen = math.floor(heightBase / (resolution + MARGIN))
				if (rowsOnScreen >= 2 and previewsPerRow >= 3) or i == 1 then
					previewResolution = resolution
					break
				end
			end
		end
		local materialBrowserOverlayDecal = vgui.Create("DFrame"); do
			materialBrowserOverlayDecal:MakePopup()
			materialBrowserOverlayDecal:SetKeyboardInputEnabled(false)
			materialBrowserOverlayDecal:SetWide(math.max(
				640,
				MARGIN
				+ ((previewResolution + MARGIN) * previewsPerRow)
				- MARGIN
				+ MARGIN
				+ SCROLL_BAR_THICKNESS
				+ MARGIN
			))
			materialBrowserOverlayDecal:SetTall(scr_h)
			materialBrowserOverlayDecal:SetTitle(
				hl == "fr" and "Matériaux : info_overlay & infodecal" or
				"Materials: info_overlay & infodecal"
			)
			materialBrowserOverlayDecal.btnMinim:SetVisible(false)
			materialBrowserOverlayDecal.btnMaxim:SetVisible(false)
			materialBrowserOverlayDecal.assistant = assistant
			materialBrowserOverlayDecal.context = context
			assistant.materialBrowserOverlayDecal = materialBrowserOverlayDecal
		end
		local scrollArea = vgui.Create("DScrollPanel", materialBrowserOverlayDecal); do
			scrollArea:SetPos(MARGIN, TITLE_BAR_THICKNESS + MARGIN)
			scrollArea:SetWide(materialBrowserOverlayDecal:GetWide() - MARGIN - MARGIN)
			scrollArea:SetTall(materialBrowserOverlayDecal:GetTall() - TITLE_BAR_THICKNESS - MARGIN - MARGIN)
		end
		local introText = vgui.Create("DLabel", scrollArea); do
			introText:SetPos(0, 0)
			local introTextLines = {
				(
					hl == "fr" and
					"N'oublie pas de monter tout le contenu nécessaire pour tout voir." or
					"Do not forget to mount all the required content to see everything."),
			}
			if "maps/" .. string.lower(game.GetMap()) .. ".bsp" ~= string.lower(assistant.mapFilename) then
				introTextLines[#introTextLines + 1] = (
					hl == "fr" and
					"La carte chargée dans l'outil est différente celle chargée dans le jeu. Du contenu peut manquer." or
					"The map loaded in the tool is different from the one loaded in the game. Some content may be missing."
				)
			end
			if conVarTextureDetails:GetInt() > 0 then
				introTextLines[#introTextLines + 1] = (
					hl == "fr" and
					"Le niveau de détail des textures est paramétré en-dessous du maximum." or
					"The level of texture detail is configured below its maximum."
				)
				introTextLines[#introTextLines + 1] = (
					hl == "fr" and
					"Tape ceci dans la console pour obtenir le maximum de détail : mat_picmip 0" or
					"Type this into the console to get the maximum detail: mat_picmip 0"
				)
			end
			introText:SetText(table.concat(introTextLines, "\n"))
			introText:SizeToContents()
		end
		local btnToggleAlpha = vgui.Create("DButton", scrollArea); do
			btnToggleAlpha.materialBrowserOverlayDecal = materialBrowserOverlayDecal
			local x, y = introText:GetPos()
			y = y + introText:GetTall() + MARGIN
			x = buttonX_COL_1
			btnToggleAlpha:SetPos(x, y)
			btnToggleAlpha:SetSize(buttonWidth_1_2, BUTTON_HEIGHT)
			btnToggleAlpha.DoClick = btnToggleAlpha_DoClick
			textToggleAlpha_Enable = (
				hl == "fr" and
				"Activer transparence" or
				"Enable transparency"
			)
			textToggleAlpha_Disable = (
				hl == "fr" and
				"Désactiver transparence" or
				"Disable transparency"
			)
			materialBrowserOverlayDecal.enabledAlpha = false
			btnToggleAlpha:SetText(textToggleAlpha_Enable)
		end
		local btnToggleBgAnim = vgui.Create("DButton", scrollArea); do
			btnToggleBgAnim.materialBrowserOverlayDecal = materialBrowserOverlayDecal
			local x, y = btnToggleAlpha:GetPos()
			x = buttonX_COL_2_2
			btnToggleBgAnim:SetPos(x, y)
			btnToggleBgAnim:SetSize(buttonWidth_1_2, BUTTON_HEIGHT)
			btnToggleBgAnim.DoClick = btnToggleBgAnim_DoClick
			textToggleBgAnim_Enable = (
				hl == "fr" and
				"Activer animation arrière-plan" or
				"Enable background animation"
			)
			textToggleBgAnim_Disable = (
				hl == "fr" and
				"Arrêter animation arrière-plan" or
				"Stop background animation"
			)
			materialBrowserOverlayDecal.enabledBgAnim = true
			btnToggleBgAnim:SetText(textToggleBgAnim_Disable)
		end
		copyButtonTooltip = (
			hl == "fr" and
			"Copier" or
			"Copy"
		)
		local context = assistant.context
		do
			local allMaterials, countsOverlay, countsDecal = context:getMaterialsOverlayDecal(true)
			--allMaterials[#allMaterials] = "overlays/shorewave002a" -- debug
			local column = 0
			local x, y = btnToggleAlpha:GetPos()
			x = 0
			y = y + btnToggleAlpha:GetTall() + MARGIN
			materialBrowserOverlayDecal.previews = {}
			for _, materialPath in ipairs(allMaterials) do
				if column >= previewsPerRow then
					column = 0
					x = 0
					y = y + previewResolution + MARGIN
				end
				local preview = makePreview(
					scrollArea,
					previewResolution, previewResolution,
					materialPath,
					countsOverlay and countsOverlay[materialPath] or 0,
					countsDecal and countsDecal[materialPath] or 0
				)
				preview:SetPos(x, y)
				preview.materialBrowserOverlayDecal = materialBrowserOverlayDecal
				materialBrowserOverlayDecal.previews[materialPath] = preview
				column = column + 1
				x = x + previewResolution + MARGIN
			end
		end
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
	local LABEL_AS_TEXT_FILE = (
		hl == "fr" and "Sous forme de fichier texte" or
		"As text file"
	)
	local LABEL_AS_BINARY_NO_HEADERS = (
		hl == "fr" and "Sous forme de fichier binaire sans entêtes" or
		"As binary file without headers"
	)
	local LABEL_AS_UNCOMPRESSED_ZIP = (
		hl == "fr" and "Sous forme de fichier ZIP non oompressé" or
		"As uncompressed ZIP file"
	)
	local LABEL_FROM_TEXT_FILE = (
		hl == "fr" and "Fichier texte" or
		"Text file"
	)
	local LABEL_FROM_BINARY_NO_HEADERS = (
		hl == "fr" and "Fichier binaire sans entêtes" or
		"Binary file without headers"
	)
	local LABEL_FROM_UNCOMPRESSED_ZIP = (
		hl == "fr" and "Fichier ZIP non oompressé" or
		"Uncompressed ZIP file"
	)
	
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
			local submenu1, icon1 = menu:AddSubMenu(
				hl == "fr" and "Extraire" or
				"Extract"
			); do
				icon1:SetIcon("icon16/brick_go.png")
				local labelAsBinaryNoHeaders = LABEL_AS_BINARY_NO_HEADERS
				if LUMPS_PAK_FILE[name] then
					labelAsBinaryNoHeaders = LABEL_AS_UNCOMPRESSED_ZIP
				end
				if canExtractSrc then
					local submenu2, icon2 = submenu1:AddSubMenu(
						hl == "fr" and "Depuis Avant" or
						"From Before"
					); do
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
					local submenu2, icon2 = submenu1:AddSubMenu(
						hl == "fr" and "Depuis Après" or
						"From After"
					); do
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
			local submenu1, icon1 = menu:AddSubMenu(
				hl == "fr" and "Remplacer par" or
				"Replace with"
			); do
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
				local option = menu:AddOption(
					hl == "fr" and "Désactiver compression" or
					"Deactivate compression"
				); do
					option:SetIcon("icon16/compress.png")
					option.DoClick = function(self)
						context:setLumpCompressed(info.luaId, false)
						refreshLumpsList()
					end
				end
			else
				local option = menu:AddOption(
					hl == "fr" and "Activer compression" or
					"Activate compression"
				); do
					option:SetIcon("icon16/compress.png")
					option.DoClick = function(self)
						context:setLumpCompressed(info.luaId, true)
						refreshLumpsList()
					end
				end
			end
		end
		
		if not info.deleted and not info.absent and not LUMPS_NO_ERASE[name] then
			local option = menu:AddOption(
				hl == "fr" and "Effacer" or
				"Erase"
			); do
				option:SetIcon("icon16/brick_delete.png")
				option.DoClick = function(self)
					context:clearLump(info.isGameLump, info.luaId)
					refreshLumpsList()
				end
			end
		end
		
		if info.modified then
			local option = menu:AddOption(
				hl == "fr" and "Défaire les changements" or
				"Revert changes"
			); do
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
		do
			local tooltip = lumpTooltips[info.luaId]
			if tooltip then
				row:SetTooltip(tooltip)
			end
		end
		
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
			cellCompressedBefore:SetText(
				info.compressedBefore and (
					hl == "fr" and "Oui" or
					"Yes")
				or (
					hl == "fr" and "Non" or
					"No")
			)
		end
		x = x + w
		local cellModified = vgui.Create("DLabel", row); do
			cellModified:SetTextColor(textColor)
			cellModified:SetPos(x, 0)
			cellModified:SetContentAlignment(ALIGN_MIDDLE_CENTER)
			w = LUMP_COLUMN_WIDTH_MODIFIED
			cellModified:SetSize(w - LUMP_CELL_MARGIN_X_TOTAL, LUMP_ROW_HEIGHT)
			cellModified:SetText(
				info.modified and (
					hl == "fr" and "Oui" or
					"Yes")
				or (
					hl == "fr" and "Non" or
					"No")
			)
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
			cellCompressedAfter:SetText(
				info.compressedAfter and (
					hl == "fr" and "Oui" or
					"Yes")
				or (
					hl == "fr" and "Non" or
					"No")
			)
		end
		x = x + w
		
		return row
	end
end

local function statusBar_Think(self)
	local newText
	local nextFromToolTipText
	do
		local tooltipLookup = false
		for i = 1, 3 do
			if tooltipLookup == false then
				tooltipLookup = vgui.GetHoveredPanel()
			else
				tooltipLookup = IsValid(tooltipLookup) and tooltipLookup:GetParent()
			end
			if IsValid(tooltipLookup) then
				local tooltip = tooltipLookup:GetTooltip()
				if tooltip and #tooltip ~= 0 then
					if tooltip ~= self.fromToolTipText then
						newText = string.gsub(tooltip, "\r?\n", " ")
					else
						newText = false -- no value change
					end
					nextFromToolTipText = tooltip -- cache to avoid treating end-of-lines again
					break
				end
			end
		end
	end
	if newText == nil and gui.IsGameUIVisible() then
		newText = (
			hl == "fr" and "Prêt — Pour afficher les info-bulles, fermez la Game UI en pressant Échap." or
			"Ready — To display tooltips, close the Game UI by pressing Esc."
		)
	end
	if newText == nil then
		newText = (
			hl == "fr" and "Prêt" or
			"Ready"
		)
	end
	if newText then
		self:SetText(newText)
	end
	self.fromToolTipText = nextFromToolTipText
end

local function lumpsList_Paint(self, w,h)
	surface.SetDrawColor(255,255,255, 255)
	surface.DrawRect(0,0, w,h)
	PaintLumpTableBorders(w, h)
	-- A bottom line will not show because it would be hidden.
end

local function openAssistant(mapName)
	api = map_manipulation_tool_api -- recover after API syntax error at startup
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
			if IsValid(self.materialBrowserOverlayDecal) then
				self.materialBrowserOverlayDecal:Remove()
			end
		end
		assistant.context = context
		assistant.mapFilename = mapName
	end
	
	local mapDetails = vgui.Create("DListView", assistant); do
		assistant.mapDetails = mapDetails
		mapDetails:SetPos(X_COL_1, TITLE_BAR_THICKNESS + MARGIN)
		mapDetails:AddColumn(
			hl == "fr" and "Propriété" or
			"Property"
		)
		mapDetails:AddColumn(
			hl == "fr" and "Valeur" or
			"Value"
		)
		mapDetails:AddLine(
			(
				hl == "fr" and "Révision Carte" or
				"Map Revision"),
			tostring(info.mapRevision)
		)
		mapDetails:AddLine(
			(
				hl == "fr" and "Taille" or
				"Size"),
			string.format("%.2f MiB", info.size / 1048576.)
		)
		mapDetails:AddLine("Version", tostring(info.version))
		mapDetails:AddLine(
			(
				hl == "fr" and "Boutisme" or
				"Endianness"),
			(
				info.bigEndian and (
					hl == "fr" and "Gros" or
					"Big")
				or (
					hl == "fr" and "Petit" or
					"Little")
			)
		)
		mapDetails:SetSize(WIDTH_1_3, BUTTON_HEIGHT * 3 + MARGIN * 2)
	end
	
	local fillLumpsList
	local refreshLumpsList
	local lumpsList
	
	local btnEntitiesEditing = vgui.Create("DButton", assistant); do
		assistant.btnEntitiesEditing = btnEntitiesEditing
		btnEntitiesEditing:SetPos(X_COL_2_3, TITLE_BAR_THICKNESS + MARGIN)
		btnEntitiesEditing:SetSize(WIDTH_2_3, BUTTON_HEIGHT)
		btnEntitiesEditing:SetText(
			hl == "fr" and "Entrer en mode d'édition d'Entités" or
			"Enter Entity editing mode"
		)
		btnEntitiesEditing:SetTooltip(
			hl == "fr" and "Permet d'éditer les entités directement en jeu" or
			"Allow editing entities directly in-game"
		)
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
		btnMoveEntitiesToLua:SetText(
			hl == "fr" and "Retirer plein d'entités & les placer dans un fichier Lua" or
			"Remove many entities & put them into a Lua file"
		)
		btnMoveEntitiesToLua:SetTooltip(
			hl == "fr" and "Protège une carte en déplaçant certaines de ses entités vers un script Lua" or
			"Protect a map by moving some of its entities into a Lua script"
		)
		local function moveEntitiesToLua()
			context:moveEntitiesToLua()
			refreshLumpsList()
		end
		btnMoveEntitiesToLua.DoClick = function(self)
			Derma_Query(
				(
					hl == "fr" and [[Tu t'apprêtes à prendre un maximum d'entités du LUMP_ENTITIES.
Un script Lua côté serveur sera généré pour recréer ces entités.
Place ce script uniquement sur le serveur dans lua/autorun/server/ pour le garder en sécurité.

Cette fonctionnalité est prévue pour dissuader les voleurs de cartes d'utiliser ta carte.
Si tu veux publier de telles cartes sur le Workshop, merci d'opter pour le type "ServerContent".
N'utilise jamais le type "map" avec des cartes protégées !

Certaines fonctionnalités avancées de carte peuvent se retrouver cassées par ce procédé.
La bonne nouvelle est que tu peux choisir si une certaine entité devrait rester dans le LUMP_ENTITIES ou pas !
La maîtrise est donnée en ajoutant un hook sur l'événement "map_manipulation_tool:moveEntitiesToLua:moveToLua".]] or
					[[You are about to take a maximum of entities from the LUMP_ENTITIES.
A server-side Lua script will be generated to re-create these entities.
Only put this script on the server in lua/autorun/server/ to keep it safe.

This feature is meant to dissuade map-stealers from using your map.
If you want to publish such maps on the Workshop, please use the type "ServerContent".
Never use the type "map" with protected maps!

Some advanced map features may get broken by this process.
The good news is that you can choose if a given entity should remain in the LUMP_ENTITIES or not!
Control is given by adding a hook on the event "map_manipulation_tool:moveEntitiesToLua:moveToLua".]]),
				"LUMP_ENTITIES -> Lua", 
				(
					hl == "fr" and "Continuer" or
					"Continue"), moveEntitiesToLua,
				(
					hl == "fr" and "Annuler" or
					"Cancel"), nil
			)
		end
	end
	
	local btnPropsStaticToDynamic = vgui.Create("DButton", assistant); do
		assistant.btnPropsStaticToDynamic = btnPropsStaticToDynamic
		local _, y = btnMoveEntitiesToLua:GetPos()
		y = y + btnMoveEntitiesToLua:GetTall() + MARGIN
		btnPropsStaticToDynamic:SetPos(X_COL_2_3, y)
		btnPropsStaticToDynamic:SetSize(WIDTH_2_3, BUTTON_HEIGHT)
		btnPropsStaticToDynamic:SetText(
			hl == "fr" and "Convertir chaque prop_static en prop_dynamic" or
			"Convert all prop_static's into prop_dynamic's"
		)
		btnPropsStaticToDynamic:SetTooltip(
			hl == "fr" and "Transforme les prop_statics en prop_dynamics" or
			"Transform prop_static's into prop_dynamic's"
		)
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
		btnHdrRemove:SetSize(WIDTH_1_2, BUTTON_HEIGHT)
		btnHdrRemove:SetText(
			hl == "fr" and "Retirer la HDR" or
			"Remove HDR"
		)
		btnHdrRemove:SetTooltip(
			hl == "fr" and "Enlève la Grande Gamme Dynamique (technologie de compensation d'éclairage dynamique)" or
			"Suppress the High Dynamic Range (dynamic lighting compensation technology)"
		)
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
		btnLightingRemove:SetSize(WIDTH_1_2, BUTTON_HEIGHT)
		btnLightingRemove:SetText(
			hl == "fr" and "Retirer l'Éclairage" or
			"Remove Lighting"
		)
		btnLightingRemove:SetTooltip(
			hl == "fr" and "Défait l'étape vrad : révèle la carte en éclairage totalement neutre (jour = nuit), comme avec \"mat_fullbright 1\"" or
			"Undo the vrad step: reveal the map in totally neutral lighting (day = night), as with \"mat_fullbright 1\""
		)
		btnLightingRemove.DoClick = function(self)
			context:clearLump(false, api.getLumpIdFromLumpName("LUMP_LIGHTING_HDR"))
			context:clearLump(false, api.getLumpIdFromLumpName("LUMP_LIGHTING"))
			refreshLumpsList()
		end
	end
	
	local btnRemoveEntitiesByClass = vgui.Create("DButton", assistant); do
		assistant.btnRemoveEntitiesByClass = btnRemoveEntitiesByClass
		local x, y = btnHdrRemove:GetPos()
		y = y + btnHdrRemove:GetTall() + MARGIN
		btnRemoveEntitiesByClass:SetPos(x, y)
		btnRemoveEntitiesByClass:SetSize(WIDTH_1_2, BUTTON_HEIGHT)
		btnRemoveEntitiesByClass:SetText(
			hl == "fr" and "Retirer entités par classe" or
			"Remove entities by class"
		)
		btnRemoveEntitiesByClass:SetTooltip(
			hl == "fr" and "Ouvre une liste des classes d'entité avec la possibilité de supprimer" or
			"Open a list of entity classes with the ability to remove"
		)
		btnRemoveEntitiesByClass.DoClick = function(self)
			openEntitiesByClassRemover(assistant)
		end
	end
	
	local btnBrowseMaterialsOverlayDecal = vgui.Create("DButton", assistant); do
		assistant.btnBrowseMaterialsOverlayDecal = btnBrowseMaterialsOverlayDecal
		local x, y = btnRemoveEntitiesByClass:GetPos()
		x = x + btnRemoveEntitiesByClass:GetWide() + MARGIN
		btnBrowseMaterialsOverlayDecal:SetPos(x, y)
		btnBrowseMaterialsOverlayDecal:SetSize(WIDTH_1_2, BUTTON_HEIGHT)
		btnBrowseMaterialsOverlayDecal:SetText(
			hl == "fr" and "Parcourir matériaux overlays & decals" or
			"Browse overlays & decals materials"
		)
		btnBrowseMaterialsOverlayDecal:SetTooltip(
			hl == "fr" and "Ouvre une boîte de prévisualisation des matériaux utilisés dans les entités info_overlay et infodecal" or
			"Open a box to preview materials used in info_overlay and infodecal entities"
		)
		btnBrowseMaterialsOverlayDecal.DoClick = function(self)
			openMaterialBrowserOverlayDecal(assistant)
		end
	end
	
	local hdrId = makeLumpColumnHeader(assistant, "Id"); do
		local x, y = btnRemoveEntitiesByClass:GetPos()
		y = y + btnRemoveEntitiesByClass:GetTall() + MARGIN
		hdrId:SetPos(x, y)
		hdrId:SetSize(LUMP_COLUMN_WIDTH_ID, LUMP_HEADER_HEIGHT_1 * 2)
	end
	
	local hdrName = makeLumpColumnHeader(assistant, (
		hl == "fr" and "Nom" or
		"Name")
	); do
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
	
	local hdrSizeBefore = makeLumpColumnHeader(assistant, (
		hl == "fr" and "Taille" or
		"Size")
	); do
		local x, y = hdrVersion:GetPos()
		x = x + hdrVersion:GetWide()
		y = y + LUMP_HEADER_HEIGHT_1
		hdrSizeBefore:SetPos(x, y)
		hdrSizeBefore:SetSize(LUMP_COLUMN_WIDTH_SIZE, LUMP_HEADER_HEIGHT_1)
	end
	
	local hdrCompressedBefore = makeLumpColumnHeader(assistant, (
		hl == "fr" and "Compressé" or
		"Compressed")
	); do
		local x, y = hdrSizeBefore:GetPos()
		x = x + hdrSizeBefore:GetWide()
		hdrCompressedBefore:SetPos(x, y)
		hdrCompressedBefore:SetSize(LUMP_COLUMN_WIDTH_COMPRESSED, LUMP_HEADER_HEIGHT_1)
	end
	
	local hdrTopBefore = makeLumpColumnHeader(assistant, (
		hl == "fr" and "Avant" or
		"Before")
	); do
		local x, y = hdrVersion:GetPos()
		x = x + hdrVersion:GetWide()
		hdrTopBefore:SetPos(x, y)
		local w = hdrSizeBefore:GetWide() + hdrCompressedBefore:GetWide()
		hdrTopBefore:SetSize(w, LUMP_HEADER_HEIGHT_1)
	end
	
	local hdrModified = makeLumpColumnHeader(assistant, (
		hl == "fr" and "Modifié" or
		"Modified")
	); do
		local x, y = hdrTopBefore:GetPos()
		x = x + hdrTopBefore:GetWide()
		y = y + LUMP_HEADER_HEIGHT_1
		hdrModified:SetPos(x, y)
		hdrModified:SetSize(LUMP_COLUMN_WIDTH_MODIFIED, LUMP_HEADER_HEIGHT_1)
	end
	
	local hdrSizeAfter = makeLumpColumnHeader(assistant, (
		hl == "fr" and "Taille" or
		"Size")
	); do
		local x, y = hdrModified:GetPos()
		x = x + hdrModified:GetWide()
		hdrSizeAfter:SetPos(x, y)
		hdrSizeAfter:SetSize(LUMP_COLUMN_WIDTH_SIZE, LUMP_HEADER_HEIGHT_1)
	end
	
	local hdrCompressedAfter = makeLumpColumnHeader(assistant, (
		hl == "fr" and "Compressé" or
		"Compressed")
	); do
		local x, y = hdrSizeAfter:GetPos()
		x = x + hdrSizeAfter:GetWide()
		hdrCompressedAfter:SetPos(x, y)
		hdrCompressedAfter:SetSize(LUMP_COLUMN_WIDTH_COMPRESSED, LUMP_HEADER_HEIGHT_1)
	end
	
	local hdrTopAfter = makeLumpColumnHeader(assistant, (
		hl == "fr" and "Après" or
		"After")
	); do
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
	
	local statusBar = vgui.Create("DLabel", assistant); do
		assistant.statusBar = statusBar
		statusBar:SetSize(WIDTH_1_1, STATUS_BAR_HEIGHT)
		local y = assistant:GetTall() - MARGIN - STATUS_BAR_HEIGHT
		statusBar:SetPos(X_COL_1, y)
		statusBar:SetContentAlignment(ALIGN_MIDDLE_LEFT)
		statusBar.Think = statusBar_Think
	end
	
	local btnRevertAll = vgui.Create("DButton", assistant); do
		assistant.btnRevertAll = btnRevertAll
		btnRevertAll:SetSize(WIDTH_1_2, BUTTON_HEIGHT)
		local _, y = statusBar:GetPos()
		y = y - MARGIN - BUTTON_HEIGHT
		local title = (
			hl == "fr" and "Défaire toutes les modifications" or
			"Revert all changes"
		)
		btnRevertAll:SetTooltip(
			hl == "fr" and "Défait tous les changements" or
			"Undo every change"
		)
		btnRevertAll:SetPos(X_COL_1, y)
		btnRevertAll:SetText(title)
		btnRevertAll.DoClick = function(self)
			Derma_Query(
				(
					hl == "fr" and "Tu perdras toutes les modifications.\nContinuer ?" or
					"You will lose all modifications.\nContinue?"),
				title,
				(
					hl == "fr" and "Oui" or
					"Yes"), function()
					context:resetOutputListing()
					refreshLumpsList()
				end,
				(
					hl == "fr" and "Annuler" or
					"Cancel"), nil
			)
		end
	end
	
	local btnSave = vgui.Create("DButton", assistant); do
		assistant.btnSave = btnSave
		local _, y = btnRevertAll:GetPos()
		btnSave:SetSize(WIDTH_1_2, BUTTON_HEIGHT)
		btnSave:SetPos(X_COL_2_2, y)
		btnSave:SetText(
			hl == "fr" and "Enregistrer la carte modifiée" or
			"Save the modified map"
		)
		btnSave:SetTooltip(
			hl == "fr" and "Enregistre la carte modifiée dans un nouveau fichier" or
			"Save the modified map into a new file"
		)
		btnSave.DoClick = function(self)
			DialogFileSelector:new(box, function(selector, folderBase, filenameDst)
				local asyncData = api.asyncWork(
					function()
						Derma_Message(
							(
								hl == "fr" and "La carte modifiée a été enregistrée avec succès !" or
								"The modified map has been successfully saved!"),
							(
								hl == "fr" and "Enregistrer sous" or
								"Save as"),
							(
								hl == "fr" and "OK" or
								"Okay")
						)
					end,
					function(message)
						Derma_Message(
							(
								hl == "fr" and "L'erreur suivante s'est produite durant l'enregistrement de la carte modifiée :\n" or
								"The following error occurred while saving the modified map:\n") .. message,
							(
								hl == "fr" and "Enregistrer sous" or
								"Save as"),
							(
								hl == "fr" and "Annuler" or
								"Cancel")
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

local helpMessage = (
	hl == "fr" and [[map_manipulation_tool <nomCarte>
   Ouvre une carte dans Momo's Map Manipulation Tool
   nomCarte: nom de carte ou chemin de fichier .bsp relatif au répertoire garrysmod/ (potentiellement sensible à la casse)

   Exemples :
   - map_manipulation_tool gm_flatgrass
   - map_manipulation_tool "maps/gm_flatgrass.bsp"]] or
	[[map_manipulation_tool <mapName>
   Open a map in Momo's Map Manipulation Tool
   mapName: map name or .bsp file path relative to garrysmod/ (may be case-sensitive)

   Examples:
   - map_manipulation_tool gm_flatgrass
   - map_manipulation_tool "maps/gm_flatgrass.bsp"]]
)

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
