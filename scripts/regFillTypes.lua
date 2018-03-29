--[[
 regFillTypes

  @author: Ifko[nator]
  @date: 26.11.2016
  @version: 1.0
 
]]

local modDesc = loadXMLFile("modDescXML", g_currentModDirectory .. "modDesc.xml");
local key = "modDesc.regFillTypes";

local hudDirectoryFillTypes = getXMLString(modDesc, key .. "#hudDirectoryFillTypes");
local textureDirectoryFillPlanes = getXMLString(modDesc, key .. "#textureDirectoryFillPlanes");

if (hudDirectoryFillTypes and textureDirectoryFillPlanes) ~= nil then
	hudDirectoryFillTypes = g_currentModDirectory .. hudDirectoryFillTypes;
	textureDirectoryFillPlanes = g_currentModDirectory .. textureDirectoryFillPlanes;
	
	local fillTypeNumber = 0;
	
	while true do
		local fillTypeKey = key .. ".fillType(" .. tostring(fillTypeNumber) .. ")";
		
		if not hasXMLProperty(modDesc, fillTypeKey) then
			break;
		end;
	
		local name = getXMLString(modDesc, fillTypeKey .. "#name");
		
		if name == nil then
			print("Error: missing 'name' attribute for fillType(" .. fillTypeNumber .. ") in 'regFillTypes'. Adding fillTypes aborted.");
			
			break;
		end;
		
		local categoryName = getXMLString(modDesc, fillTypeKey .. "#categoryName");
		
		if categoryName == nil then
			print("Error: missing 'categoryName' attribute for fillType(" .. fillTypeNumber .. ") in 'regFillTypes'. Adding fillTypes aborted.");
			
			break;
		end;
	
		local category = "FILLTYPE_CATEGORY_" .. string.upper(categoryName);
		local newFillType = "FILLTYPE_" .. string.upper(name);
		
		if FillUtil[newFillType] == nil and FillUtil[category] ~= nil then
			local fillType = {
				name = name,
				category = FillUtil[category],
				pricePerLiter = Utils.getNoNil(getXMLFloat(modDesc, fillTypeKey .. "#pricePerLiter"), 0.8),
				massPerLiter = Utils.getNoNil(getXMLFloat(modDesc, fillTypeKey .. "#massPerLiter"), 0.0002),
				showOnPriceTable = Utils.getNoNil(getXMLBool(modDesc, fillTypeKey .. "#showOnPriceTable"), false),
				maxPhysicalSurfaceAngle = Utils.getNoNilRad(getXMLFloat(modDesc, fillTypeKey .. "#maxPhysicalSurfaceAngle"), 20),
				createHeap = Utils.getNoNil(getXMLBool(modDesc, fillTypeKey .. "#createHeap"), true),
				maxSurfaceAngle = Utils.getNoNilRad(getXMLFloat(modDesc, fillTypeKey .. "#maxSurfaceAngle"), 20),
				collisionScale = Utils.getNoNil(getXMLFloat(modDesc, fillTypeKey .. "#collisionScale"), 1.0),
				collisionBaseOffset = Utils.getNoNil(getXMLFloat(modDesc, fillTypeKey .. "#collisionBaseOffset"), 0.08),
				minCollisionOffset = Utils.getNoNil(getXMLFloat(modDesc, fillTypeKey .. "#minCollisionOffset"), 0.0),
				maxCollisionOffset = Utils.getNoNil(getXMLFloat(modDesc, fillTypeKey .. "#maxCollisionOffset"), 0.08),
				fillToGroundScale = Utils.getNoNil(getXMLFloat(modDesc, fillTypeKey .. "#fillToGroundScale"), 1),
				allowsSmoothing = Utils.getNoNil(getXMLBool(modDesc, fillTypeKey .. "#allowsSmoothing"), false),
				useToSpray = Utils.getNoNil(getXMLBool(modDesc, fillTypeKey .. "#useToSpray"), false),
				litersPerSecond = Utils.round(Utils.getNoNil(getXMLFloat(modDesc, fillTypeKey .. "#litersPerSecond"), 0.006), 3),
				sprayerCategoryName = Utils.getNoNil(getXMLString(modDesc, fillTypeKey .. "#sprayerCategoryName"), "spreader"),
				hud_fill = hudDirectoryFillTypes .. "/hud_fill_" .. name ..".dds",
				addToAnFoodGroup = Utils.getNoNil(getXMLBool(modDesc, fillTypeKey .. "#addToAnFoodGroup"), false),
				animals = Utils.getNoNil(getXMLString(modDesc, fillTypeKey .. "#animals"), "cow pig"),
				foodGroups = Utils.getNoNil(getXMLString(modDesc, fillTypeKey .. "#foodGroups"), "grass base")
			};
	
			local localFillTypeName = fillType.name;
			
			if g_i18n:hasText(fillType.name) then
				localFillTypeName = g_i18n:getText(fillType.name);
			else
				print("[INFO from the regFillTypes.lua]: Missing the l10n entry for '" .. fillType.name .. "'. This is not a problem, but its not 100% perfect");
			end;
			
			g_i18n.globalI18N.texts[fillType.name] = localFillTypeName;
			
			local hudFile_small = hudDirectoryFillTypes .. "/hud_fill_" .. fillType.name .. "_sml.dds";
			
			if not fileExists(hudFile_small) then				
				print("[INFO from the regFillTypes.lua]: Can't find: '" .. hudFile_small .. "'. This is not a problem, but its not 100% perfect");
				
				hudFile_small = fillType.hud_fill;
			end;	
	
			local registeredFillType = FillUtil.registerFillType(
				fillType.name, 
				localFillTypeName, 
				fillType.category, 
				fillType.pricePerLiter, 
				fillType.showOnPriceTable, 
				fillType.hud_fill, 
				hudFile_small, 
				fillType.massPerLiter, 
				fillType.maxPhysicalSurfaceAngle
			);
			
			if registeredFillType ~= nil then
				print("\\__ Register fillType: '" .. localFillTypeName .. "' (" .. fillType.name .. ") [key ".. tostring(registeredFillType) .. "]");
			end;
			
			if fillType.useToSpray then
				local sprayType = "SPRAYTYPE_" .. string.upper(fillType.name);
				
				if Sprayer[sprayType] == nil then
					Sprayer.registerSprayType(
						fillType.name, 
						localFillTypeName, 
						nil, --## has added fillType already to the right category in line 128
						fillType.pricePerLiter, 
						fillType.litersPerSecond, 
						fillType.showOnPriceTable, 
						fillType.hud_fill, 
						hudFile_small, 
						fillType.massPerLiter
					);
					
					print("\\___ Register sprayType: '" .. localFillTypeName .. "'");
				else
					print("Info: spray type '" .. localFillTypeName .. "' already exists. 'regFillTypes' will skip its registration.");
				end;
				
				local sprayerCategories = Utils.splitString(" ", fillType.sprayerCategoryName);
				
				for _, sprayerCategory in pairs(sprayerCategories) do
					sprayerCategory = "FILLTYPE_CATEGORY_" .. string.upper(sprayerCategory);
				
					if FillUtil[sprayerCategory] then
						FillUtil.addFillTypeToCategory(FillUtil[sprayerCategory], FillUtil[newFillType]);
						
						print("\\____ Add sprayType: '" .. localFillTypeName .. "' to category: '" .. sprayerCategory .. "' [key " .. FillUtil[sprayerCategory] .."]");
					else
						print("[ERROR from the regFillTypes.lua]: The category: '" .. sprayerCategory .. "' are not exists!. Aborting adding spray type to this category now!");
					end;
				end;
			end;
			
			if fillType.createHeap then
				fillType.diffuseMap = Utils.getFilename(string.format("%s/%s_diffuse.dds", textureDirectoryFillPlanes, fillType.name));
				fillType.normalMap = Utils.getFilename(string.format("%s/%s_normal.dds", textureDirectoryFillPlanes, fillType.name));
				fillType.distanceMap = Utils.getFilename(string.format("%s/distance/%sDistance_diffuse.dds", textureDirectoryFillPlanes, fillType.name));
				
				local hasAllTextures = fileExists(fillType.diffuseMap) and fileExists(fillType.normalMap) and fileExists(fillType.distanceMap);
				
				if hasAllTextures then
					TipUtil.registerDensityMapHeightType(
						FillUtil[newFillType], 
						fillType.maxSurfaceAngle, 
						fillType.collisionScale, 
						fillType.collisionBaseOffset, 
						fillType.minCollisionOffset, 
						fillType.maxCollisionOffset, 
						fillType.fillToGroundScale, 
						fillType.allowsSmoothing, 
						fillType.diffuseMap, 
						fillType.normalMap, 
						fillType.distanceMap
					);
					
					print("\\_____ Register heap for: '" .. localFillTypeName .. "'");
				else
					print("[ERROR from the regFillTypes.lua]: Aborting create heap for '" .. fillType.name.. "' now because:");
				end;
				
				if not fileExists(fillType.diffuseMap) then				
					print("    \\__ can't find: '" .. fillType.diffuseMap .. "' for the heap!");
				end;
				
				if not fileExists(fillType.normalMap) then				
					print("    \\__ can't find: '" .. fillType.normalMap .. "' for the heap!");
				end;
				
				if not fileExists(fillType.distanceMap) then				
					print("    \\__ can't find: '" .. fillType.distanceMap .. "' for the heap!");
				end;	
			end;
			
			if fillType.addToAnFoodGroup then
				local animals = Utils.splitString(" ", fillType.animals);
				local foodGroups = Utils.splitString(" ", fillType.foodGroups);
				
				for _, animal in pairs(animals) do	
					
					for _, foodGroup in pairs(foodGroups) do	
						local foodGroupIndex;
						local animalIndex;
						local stop = false;
					
						if animal == "sheep" then
							animalIndex = AnimalUtil.ANIMAL_SHEEP;
							
							if foodGroup == "grass" then
								foodGroupIndex = 1;
							else
								stop = true;
							end;
						elseif animal == "cow" then
							animalIndex = AnimalUtil.ANIMAL_COW;
							
							if foodGroup == "grass" then
								foodGroupIndex = 1;
							elseif foodGroup == "base" then
								foodGroupIndex = 2;
							elseif foodGroup == "power" then
								foodGroupIndex = 3;
							else
								stop = true;
							end;
						elseif animal == "pig" then
							animalIndex = AnimalUtil.ANIMAL_PIG;
							
							if foodGroup == "grass" then
								foodGroupIndex = 1;
							elseif foodGroup == "grain" then
								foodGroupIndex = 2;
							elseif foodGroup == "protein" then
								foodGroupIndex = 3;
							elseif foodGroup == "earth" then
								foodGroupIndex = 4;
							else
								stop = true;
							end;
						else
							stop = true;
						end;
						
						if not stop then
							FillUtil.registerFillTypeInFoodGroup(
								animalIndex, 
								foodGroupIndex, 
								FillUtil[newFillType]
							);
							
							print("\\______ Add fillType: '" .. localFillTypeName .. "' to food group: '" .. foodGroup .. "' [foodGroupIndex '" .. foodGroupIndex .. "'] from animal '" .. animal .. "' [animalIndex: '" .. animalIndex .. "']");
						end;
					end;
				end;
			end;
			
			fillTypeNumber = fillTypeNumber + 1;
		else
			fillTypeNumber = fillTypeNumber + 1;
			
			if FillUtil[newFillType] ~= nil then	
				print("Info: fill type '" .. name .. "' already exists. 'regFillTypes' will skip its registration.");
			end;
			
			if FillUtil[category] == nil then
				print("Error: fill type category '" .. categoryName .. "' not exists. 'regFillTypes' will skip its registration.");
			end;
		end;
	end;
else
	print("ERROR: The 'regFillTypes' script IS STOPPED NOW because:");

	if hudDirectoryFillTypes == nil then
		print("\\___ can't find hud directory for the fill types.");
	end;
	
	if textureDirectoryFillPlanes == nil then
		print("\\___ can't find texture directory for the fill planes.");
	end;
end;