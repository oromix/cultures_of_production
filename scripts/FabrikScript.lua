local metadata = {
"## Interface: FS17 1.3.1.0 1.3.1RC10",
"## Title: FabrikScript",
"## Notes: FabrikScript zum erstellen eines Fabrikgebäudes mit verschiedenen Rohstoffen und Produkten",
"## Author: kevink98/Marhu",
"## Version: 2.1.8.1",
"## Date: 04.03.2017",
"## Web: http://ls-modcompany.de " 
}
--[[
	## V2.0.0:
			- Convert from FS15 to FS17
	## V2.0.1:
			- Fix: Error when leaving TipTrigger, if the trailer still tipping
	## V2.1.0:
			- add Support for AdditionalTriggers (SiloTrigger and LiquideTrigger)
	## V2.1.1:
			- fix displays when it's placeabled
	## V2.1.2:
			- fix LUA call stack (streamWriteBool,writeAllStream) for SiloTrigger.isAutomaticFilling
	## V2.1.3:
			- adapted to AdditionalTriggers v 1.0.0.3 (30.12.2016);
	## V2.1.4:
			- add DoorTrigger
	## V2.1.5:
			- Fix Problem with Courseplay
	## V2.1.6:
			- Fix Log entry, when tipping with Courseplay
	## V2.1.7.1:
			- Adaption to Patch 1.4.2016
			- Fix storageRadius at TipTrigger
	## V2.1.8.1:
			- adaptet to AdditionalTriggers v 1.1.0 (04.03.2017)
			- new UserAttribute: "updateIntervall" (default: 5)

]]--
 
local DebugEbene = 0;
local function getmdata(v) v="## "..v..": "; for i=1,table.getn(metadata) do local _,n=string.find(metadata[i],v);if n then return (string.sub (metadata[i], n+1)); end;end;end;
local function Debug(e,s,...) if e <= DebugEbene then print((getmdata("Title")).." v"..(getmdata("Version"))..": "..string.format(s,...)); end; end;
local function L(name) local t = getmdata("Title"); return g_i18n:hasText(t.."_"..name) and g_i18n:getText(t.."_"..name) or name; end

FabrikScript = {};
FabrikScript.ModDir = g_currentModDirectory
FabrikScript_mt = nil

local nBeginn, nEnde = string.find(FabrikScript.ModDir,"placeable");
if nBeginn then
	FabrikScript_mt = Class(FabrikScript, Placeable);
else
	FabrikScript.RunAsGE = true;
	FabrikScript_mt = Class(FabrikScript, Object);
end

InitObjectClass(FabrikScript, "FabrikScript");

function FabrikScript.onCreate(id)
	local object = FabrikScript:new(g_server ~= nil, g_client ~= nil)
	g_currentMission:addOnCreateLoadedObject(object);
	if object:load(id) then
		g_currentMission:addOnCreateLoadedObjectToSave(object);
        object:register(true);
		Debug(1,"FabrikScript.onCreate(%d) load %s",id,getName(id));
    else
        object:delete();
    end;
		
end;

function FabrikScript:new(isServer, isClient, customMt)
  
	local mt = customMt;
    if mt == nil then
          mt = FabrikScript_mt;
    end;
  
	local self = {};
	if FabrikScript.RunAsGE then
		self = Object:new(isServer, isClient, mt)
	else
		self = Placeable:new(isServer, isClient, mt);
		registerObjectClassName(self, "FabrikScript");
	end;
				
	return self;
end;
 
function FabrikScript:load(xmlFilename, x,y,z, rx,ry,rz, initRandom)

	self.FehlerText = {}
	self.StoffeIdToName = {}	
	self.trailerTipTrigger = {}
	self.tankTriggers = {}
	
	if FabrikScript.RunAsGE then
		self.saveId = getUserAttribute(xmlFilename,"saveId");
		if self.saveId == nil then
			self.saveId = "FabrikScript_"..getName(xmlFilename)
		end
	end;
	
	if not self.RunAsGE then
		if not FabrikScript:superClass().load(self, xmlFilename, x,y,z, rx,ry,rz, initRandom) then
			return false;
		end;
		return true;
	else
		self.nodeId = xmlFilename;
		if not self:finalizePlacement() then return false; end;
	end;
	
	return true;
end;

function FabrikScript:finalizePlacement(x, y, z, rx, ry, rz, initRandom)
	
	if not self.RunAsGE then
		FabrikScript:superClass().finalizePlacement(self)
	end
	
	self.addLiveTicker = Utils.getNoNil(getUserAttribute(self.nodeId, "LiveTicker"),true);
	self.ProduktPerHour = Utils.getNoNil(getUserAttribute(self.nodeId, "ProduktPerHour"),1000);
	self.updateIntervall = Utils.getNoNil(getUserAttribute(self.nodeId, "updateIntervall"),5);
	self.updateMs = 60000;
	self.updateMin = 0 + self.updateIntervall;
	local StoffeId = 1;	
	local FS_LiquideTriggerId = 0;
	local FS_SiloTriggerId = 0;
	local SiloTriggerId = 0;
	local FS_TankTriggerId = 0;
	
	local InputIndex = getUserAttribute(self.nodeId, "inputIndex");
	if InputIndex then
		local InputId = Utils.indexToObject(self.nodeId, InputIndex);	
		if InputId then
			self.InputName = getName(InputId)
			local numChildren = getNumOfChildren(InputId);
			if 0 >= numChildren then
				Debug(-1,"ERROR: no Resources in InputId %d Name %s",InputId,self.InputName);
				return false;
			else
				Debug(2,"InputId %d Name %s",InputId,self.InputName);
			end
			
			self.Rohstoffe = {}
			
			for i = 1, numChildren do
				local rohstoffId = getChildAt(InputId,i-1)
				local name = Utils.getNoNil(getUserAttribute(rohstoffId, "name"),getName(rohstoffId));
				if self.Rohstoffe[name] == nil then
					self.Rohstoffe[name]={}
					self.Rohstoffe[name].id = StoffeId;
					self.Rohstoffe[name].name = name
					self.Rohstoffe[name].nameL = g_i18n:hasText(name) and g_i18n:getText(name) or name;
					self.StoffeIdToName[StoffeId] = name;
					self.FehlerText[StoffeId] = self.Rohstoffe[name].nameL.." "..(g_i18n:hasText("leer") and g_i18n:getText("leer") or "leer");
					StoffeId = StoffeId + 1;
					self.Rohstoffe[name].fillLevel = 0;
					self.Rohstoffe[name].capacity = Utils.getNoNil(getUserAttribute(rohstoffId, "capacity"),10000);
					self.Rohstoffe[name].factor = Utils.getNoNil(getUserAttribute(rohstoffId, "factor"),1);
					self.Rohstoffe[name].acceptedFillTypes = {}
					local fillTypes = getUserAttribute(rohstoffId, "fillTypes");
					if fillTypes == nil then
						Debug(-1,"Warning: Attribute 'fruitTypes' is not supported anymore. Please use 'fillTypes' instead || or fillTypes are nil");
						return false;
					end
					if fillTypes ~= nil then
						local types = Utils.splitString(" ", fillTypes);
						for k,v in pairs(types) do
							local desc = FillUtil.fillTypeNameToDesc[v];
							self.Rohstoffe[name].allowedToolTypes = {};
							if desc ~= nil then
								local allowedToolTypes = {TipTrigger.TOOL_TYPE_TRAILER, TipTrigger.TOOL_TYPE_SHOVEL, TipTrigger.TOOL_TYPE_PIPE};
								self.Rohstoffe[name].acceptedFillTypes[desc.index] = true;
								self.Rohstoffe[name].allowedToolTypes[desc.index] = {};
								for _,toolType in pairs(allowedToolTypes) do
									self.Rohstoffe[name].allowedToolTypes[desc.index][toolType] = true
								end;
								Debug(3,"Input %s accept FillType %s",name,desc.name);
							else
								Debug(-1,"ERROR: invalid fillType %s in %s",tostring( v or "nil"),name);
							end;
						end;
					end;
					
					local numTrigger = 0;
					
					local TipTriggerId = getChild(rohstoffId,"TipTrigger")
					if TipTriggerId and TipTriggerId ~= 0 then
						self.Rohstoffe[name].TipTrigger = TipTrigger:new(self.isServer, self.isClient)
						if self.Rohstoffe[name].TipTrigger:load(TipTriggerId) then
							self.Rohstoffe[name].TipTrigger:register(true)
							local allowedToolTypes = {TipTrigger.TOOL_TYPE_TRAILER, TipTrigger.TOOL_TYPE_SHOVEL, TipTrigger.TOOL_TYPE_PIPE};
							self.Rohstoffe[name].allowedToolTypes = {};
							for fillType,_ in pairs(self.Rohstoffe[name].acceptedFillTypes) do
								self.Rohstoffe[name].allowedToolTypes[fillType] = {};
								self.Rohstoffe[name].TipTrigger:addAcceptedFillType(fillType,0,false,true,allowedToolTypes);
							end
							self.Rohstoffe[name].TipTrigger.nodeId = TipTriggerId;
							self.Rohstoffe[name].TipTrigger.addFillLevelFromTool = function (...) return self:addFillLevelFromTool(...) end;
							self.Rohstoffe[name].TipTrigger.Rohstoffname = name;
							self.Rohstoffe[name].TipTrigger.fillLevel = self.Rohstoffe[name].fillLevel;
							self.Rohstoffe[name].TipTrigger.capacity = self.Rohstoffe[name].capacity;
							self.Rohstoffe[name].TipTrigger.storageRadius = 0;
							self.Rohstoffe[name].TipTriggerCallback = function(...) return self:TipTriggerCallback(...) end;
							self.Rohstoffe[name].movingIndex = getUserAttribute(TipTriggerId,"movingIndex");
							if self.Rohstoffe[name].movingIndex ~= nil then
								self.Rohstoffe[name].movingId = Utils.indexToObject(TipTriggerId,self.Rohstoffe[name].movingIndex);
								self.Rohstoffe[name].moveMaxY = getUserAttribute(TipTriggerId,"moveMaxY");
								self.Rohstoffe[name].moveMinY = getUserAttribute(TipTriggerId,"moveMinY");
								self.Rohstoffe[name].movingScale = (self.Rohstoffe[name].moveMaxY-self.Rohstoffe[name].moveMinY)/ self.Rohstoffe[name].capacity;
								if self.Rohstoffe[name].moveMaxY and self.Rohstoffe[name].moveMinY and self.Rohstoffe[name].movingScale then
									Debug(4,"Input %s load Moving at TipTrigger %d (Max: %s ||Min:: %s ||Scale: %s)",name,TipTriggerId,self.Rohstoffe[name].moveMaxY,self.Rohstoffe[name].moveMinY,self.Rohstoffe[name].movingScale);
								else
									Debug(-1,"ERROR: Input %s Movingerroer at TipTrigger %d : values are nil!",name,TipTriggerId);
									return false
								end;
							end;
							removeTrigger(self.Rohstoffe[name].TipTrigger.triggerId);
							addTrigger(self.Rohstoffe[name].TipTrigger.triggerId , "TipTriggerCallback", self.Rohstoffe[name]);
							
						end;
						
						Debug(3,"Input %s load TipTrigger %d",name,TipTriggerId);
						numTrigger = numTrigger + 1;
					end
					
					local BaleTriggerId = getChild(rohstoffId,"BaleTrigger")
					if BaleTriggerId and BaleTriggerId ~= 0 then
						self.Rohstoffe[name].BaleTrigger = BaleTriggerId
						addTrigger(self.Rohstoffe[name].BaleTrigger, "BaleTriggerCallback", self);
						Debug(3,"Input %s add BaleTrigger %d",name,BaleTriggerId);
						numTrigger = numTrigger + 1;
					end
					
					local ShovelTargetId = getChild(rohstoffId,"ShovelTarget")
					if ShovelTargetId and ShovelTargetId ~= 0 and self.isServer then
						self.Rohstoffe[name].ShovelTarget = ShovelTarget:new();
						self.Rohstoffe[name].ShovelTarget.Rohstoff = name;
						self.Rohstoffe[name].ShovelTarget.nodeId = ShovelTargetId;
						self.Rohstoffe[name].ShovelTarget.fillTypes = self.Rohstoffe[name].acceptedFillTypes
						g_currentMission:addNodeObject(self.Rohstoffe[name].ShovelTarget.nodeId, self.Rohstoffe[name].ShovelTarget);
						g_currentMission:addNonUpdateable(self.Rohstoffe[name].ShovelTarget);
						self.Rohstoffe[name].ShovelTarget.addShovelFillLevel = function(target, shovel, fillLevelDelta, fillType) return self:addShovelFillLevel(target, shovel, fillLevelDelta, fillType); end;
						Debug(3,"Input %s create ShovelTarget %d",name,ShovelTargetId);
						numTrigger = numTrigger + 1;
					end
					
					local PalletTriggerId = getChild(rohstoffId,"PalletTrigger")
					if PalletTriggerId and PalletTriggerId ~= 0 then
						if self.isServer then
							self.Rohstoffe[name].PalletTrigger = PalletTriggerId
							addTrigger(self.Rohstoffe[name].PalletTrigger, "PalletTriggerCallback", self);
							Debug(3,"Input %s add PalletTrigger %d",name,PalletTriggerId);
						else
							Debug(3,"Input %s Client PalletTrigger %d",name,PalletTriggerId);
						end
						numTrigger = numTrigger + 1;
					end
					
					local LiquideTriggerId = getChild(rohstoffId,"LiquideTrigger")
					if LiquideTriggerId and LiquideTriggerId ~= 0 then
						if LiquideTrigger then
							--local L_Trigger = getChildAt(LiquideTriggerId,0)
							local L_TriggerFunktionen = {}
							L_TriggerFunktionen.getCapacity = function(...) return self:getCapacity(self.Rohstoffe[name],...) end;
							L_TriggerFunktionen.getFillLevel = function(...) return self:getFillLevel(self.Rohstoffe[name],...) end;
							L_TriggerFunktionen.setFillLevel = function(...) return self:setFillLevel(self.Rohstoffe[name],...) end;
							L_TriggerFunktionen.Parent = self;
							FS_LiquideTriggerId = FS_LiquideTriggerId + 1;
							local Trigger = LiquideTrigger:new(g_server ~= nil, g_client ~= nil)
							Trigger.isInputTrigger = true;
							Trigger:load(LiquideTriggerId,L_TriggerFunktionen)
							Trigger.FS_LiquideTriggerId = FS_LiquideTriggerId;
							self.Rohstoffe[name].LiquideTrigger = Trigger;
							Debug(3,"Input %s add LiquideTrigger %d",name,LiquideTriggerId);
						else
							Debug(-1,"Input %s LiquideTrigger cant find AdditionalTriggers Script",name);
						end
						numTrigger = numTrigger + 1;
					end
					
					local numLogs = -1;
					local WoodTriggerId = getChild(rohstoffId,"WoodTrigger")
					if WoodTriggerId and WoodTriggerId ~= 0 then
						self.Rohstoffe[name].WoodTrigger = WoodTriggerId
						addTrigger(self.Rohstoffe[name].WoodTrigger, "WoodTriggerCallback", self);
						numLogs = getNumOfChildren(WoodTriggerId);
						Debug(3,"Input %s add WoodTrigger %d",name,WoodTriggerId);
						numTrigger = numTrigger + 1;
					end
					
					local visibilityNodesId = getChild(rohstoffId,"visibilityNodes")
					if numLogs >= 1 or (visibilityNodesId and visibilityNodesId ~= 0) then
						if numLogs >= 1 then
							visibilityNodesId = WoodTriggerId
						else
							numLogs = getNumOfChildren(visibilityNodesId);
						end
						if numLogs >= 1 then 
							self.Rohstoffe[name].logs = {}
							for numLog = 1, numLogs do 
								local WoodLog = getChildAt(visibilityNodesId,numLog-1)
								self.Rohstoffe[name].logs[numLog]={node = WoodLog,rigidBody = getRigidBodyType(WoodLog)}
								setRigidBodyType(WoodLog,"NoRigidBody")
								setVisibility(WoodLog,false)
							end
							Debug(3,"Input %s add visibilityNodes %d",name,visibilityNodesId);
						end
					end
					
					local LvLDisplay = getChild(rohstoffId,"Displays") 
					if LvLDisplay and LvLDisplay ~= 0 then
						self.Rohstoffe[name].LvLDisplay = {};
						self.Rohstoffe[name].LvLDisplayPercent = {};
						local numDisplayChilds = getNumOfChildren(LvLDisplay);
						for numChild = 1, numDisplayChilds do
							local Display = getChildAt(LvLDisplay,numChild-1)
							local displayArt = getUserAttribute(Display,"displayArt");
							if displayArt == nil or displayArt == "input" then
								table.insert(self.Rohstoffe[name].LvLDisplay,Display);
								Utils.setNumberShaderByValue(Display, math.floor(self.Rohstoffe[name].fillLevel), 0, true)
							elseif displayArt == "capacity" then
								Utils.setNumberShaderByValue(Display, math.floor(self.Rohstoffe[name].capacity), 0, true)
							elseif displayArt == "percent" then
								table.insert(self.Rohstoffe[name].LvLDisplayPercent,Display);
								Utils.setNumberShaderByValue(Display, math.floor(self.Rohstoffe[name].fillLevel/self.Rohstoffe[name].capacity*100), 0, true)
							end;
						end
					end
					
					if numTrigger == 0 then
						Debug(-1,"ERROR: can not find Trigger in Input %s",name);
						return false;
					end
				else
					Debug(-1,"WARNING: Input %s already exists!",name);
				end
			end
		else
			Debug(-1,"ERROR: no Objekt on InputIndex %s",tostring(InputIndex));
			return false;
		end
	else
		Debug(-1,"ERROR: InputIndex = nil");
		return false;
	end
	
	local OutputIndex = getUserAttribute(self.nodeId, "outputIndex");
	if OutputIndex then
		local OutputId = Utils.indexToObject(self.nodeId, OutputIndex);	
		if OutputId then
			self.OutputName = getName(OutputId)
			local numChildren = getNumOfChildren(OutputId);
			if 0 >= numChildren then
				Debug(-1,"ERROR: no Produkt in OutputId %d Name %s",OutputId,self.OutputName);
				return false;
			else
				Debug(2,"OutputId %d Name %s",OutputId,self.OutputName);
			end
			
			self.Produkte = {}
			
			for i = 1, numChildren do
				local produktId = getChildAt(OutputId,i-1)
				local name = Utils.getNoNil(getUserAttribute(produktId, "name"),getName(produktId));
				if self.Produkte[name] == nil then
					self.Produkte[name]={}
					self.Produkte[name].id = StoffeId;
					self.Produkte[name].name = name
					self.Produkte[name].nameL = g_i18n:hasText(name) and g_i18n:getText(name) or name;
					self.StoffeIdToName[StoffeId] = name;
					self.FehlerText[StoffeId] = self.Produkte[name].nameL.." "..(g_i18n:hasText("voll") and g_i18n:getText("voll") or "voll");
					StoffeId = StoffeId + 1
					self.Produkte[name].fillLevel = 0;
					self.Produkte[name].capacity = Utils.getNoNil(getUserAttribute(produktId, "capacity"),10000);
					self.Produkte[name].factor = Utils.getNoNil(getUserAttribute(produktId, "factor"),1);
					self.Produkte[name].acceptedFillTypes = {}	
					
					local fillType = getUserAttribute(produktId, "fillType");
					local desc = FillUtil.fillTypeNameToDesc[fillType];
					if desc ~= nil then
						
						self.Produkte[name].acceptedFillTypes[desc.index] = true;
						self.Produkte[name].fillTypes = {};
						self.Produkte[name].fillTypes[desc.index] = desc.index
						Debug(3,"Output %s accept FillType %s",name,desc.name);
										
						local numTrigger = 0;
						
						local HeapId = getChild(produktId,"Heap")
						if HeapId and HeapId ~= 0 then
							local heap = {}
							heap.id = HeapId;
							local minY, maxY = Utils.getVectorFromString(getUserAttribute(HeapId, "moveMinMaxY"));
							if minY ~= nil and maxY ~= nil then
								local maxAmount = tonumber(getUserAttribute(HeapId, "moveMaxAmount")) or self.Produkte[name].capacity;
								if maxAmount ~= nil then
									heap.moveMinY = minY;
									heap.moveMaxY = maxY;
									heap.moveMaxAmount = maxAmount;
								end;
							end;
							local numHeapChilds = getNumOfChildren(HeapId)
							if self.isServer and numHeapChilds > 0 then
								local ShovelTrigger = getChildAt(HeapId,0)
								if ShovelTrigger then
									local trigger = ShovelFillTrigger:new();
									if trigger:load(ShovelTrigger, desc.index) then
										g_currentMission:addUpdateable(trigger);
										heap.ShovelTrigger = trigger
										heap.ShovelTrigger.Produkt = name;
										heap.ShovelTrigger.fillShovel = function(ST, shovel, dt) self:fillShovel(ST, shovel, dt); end;
										Debug(3,"Output %s add ShovelTrigger %d",name,ShovelTrigger);
									else
										Debug(-1,"ERROR: Output %s can not load ShovelTrigger %d",name,ShovelTrigger);
										trigger:delete();
									end;
								end;
							end;
							self.Produkte[name].Heap = heap;
							Debug(3,"Output %s add Heap %d",name,HeapId);
							numTrigger = numTrigger + 1;
						end
						
						local palletSpawnerId = getChild(produktId,"palletSpawner")
						if palletSpawnerId and palletSpawnerId ~= 0 then
							self.FehlerText[StoffeId] = self.Produkte[name].nameL.." "..(g_i18n:hasText("palletPlaceNotFree") and g_i18n:getText("palletPlaceNotFree") or "palletPlaceNotFree");
							StoffeId = StoffeId + 1
							if self.isServer then
								local pallet = {}
								pallet.Filename = getUserAttribute(palletSpawnerId, "palletFilename");
								pallet.Filename = Utils.getFilename(pallet.Filename, self.ModDir)
								pallet.SpawnerTriggerId = getChildAt(palletSpawnerId, 0)

								addTrigger(pallet.SpawnerTriggerId, "palletSpawnerTriggerCallback", self)
								g_currentMission:addNodeObject(pallet.SpawnerTriggerId, self);

								pallet.SpawnerPlaceId = getChildAt(palletSpawnerId, 1)
								pallet.numObjectsInPalletSpawnerTrigger = 0;
								pallet.numObjectsPerID = {};
								self.Produkte[name].palletSpawner = pallet;
								Debug(3,"Output %s add palletSpawner %d",name,palletSpawnerId);
							end;
							numTrigger = numTrigger + 1;
						end;
						
						local LiquideTriggerId = getChild(produktId,"LiquideTrigger")
						if LiquideTriggerId and LiquideTriggerId ~= 0 then
							if LiquideTrigger then
								--local L_Trigger = getChildAt(LiquideTriggerId,0)
								local L_TriggerFunktionen = {}
								L_TriggerFunktionen.getCapacity = function(...) return self:getCapacity(self.Produkte[name],...) end;
								L_TriggerFunktionen.getFillLevel = function(...) return self:getFillLevel(self.Produkte[name],...) end;
								L_TriggerFunktionen.setFillLevel = function(...) return self:setFillLevel(self.Produkte[name],...) end;
								L_TriggerFunktionen.Parent = self;
								FS_LiquideTriggerId = FS_LiquideTriggerId + 1;
								local Trigger = LiquideTrigger:new(g_server ~= nil, g_client ~= nil)
								Trigger.isInputTrigger = false;
								Trigger:load(LiquideTriggerId,L_TriggerFunktionen)
								Trigger.FS_LiquideTriggerId = FS_LiquideTriggerId;
								self.Produkte[name].LiquideTrigger = Trigger;
								Debug(3,"Output %s add LiquideTrigger %d",name,LiquideTriggerId);
								numTrigger = numTrigger + 1;
							else
								Debug(-1,"Output %s LiquideTrigger cant find LiquideTrigger Script",name);
							end
						end
						
						local SiloTriggerId = getChild(produktId,"SiloTrigger")
						if SiloTriggerId and SiloTriggerId ~= 0 then
							if SiloTriggerFS then
								local S_TriggerFunktionen = {}
								S_TriggerFunktionen.getCapacity = function(...) return self:getCapacity(self.Produkte[name],...) end;
								S_TriggerFunktionen.getFillLevel = function(...) return self:getFillLevel(self.Produkte[name],...) end;
								S_TriggerFunktionen.setFillLevel = function(...) return self:setFillLevel(self.Produkte[name],...) end;
								S_TriggerFunktionen.Parent = self;
								FS_SiloTriggerId = FS_SiloTriggerId + 1;
								local Trigger = SiloTriggerFS:new(g_server ~= nil, g_client ~= nil)
								Trigger:load(SiloTriggerId,S_TriggerFunktionen)
								Trigger.FS_SiloTriggerId = FS_SiloTriggerId;
								self.Produkte[name].SiloTrigger = Trigger;
								self.Produkte[name].SiloTrigger.isAutomaticFilling = false;
								Debug(3,"Input %s add SiloTrigger %d",name,SiloTriggerId);
							else
								Debug(-1,"Input %s SiloTrigger cant find AdditionalTriggers Script",name);
							end
							numTrigger = numTrigger + 1;
						end
						
						local TankTriggerId = getChild(produktId,"TankTrigger")
						if TankTriggerId and TankTriggerId ~= 0 then
							if TankTrigger then
								local triggerInfo = {};
								triggerInfo.getCapacity = function(...) return self:getCapacity(self.Produkte[name],...) end;
								triggerInfo.getFillLevel = function(...) return self:getFillLevel(self.Produkte[name],...) end;
								triggerInfo.setFillLevel = function(...) return self:setFillLevel(self.Produkte[name],...) end;
								triggerInfo.Parent = self;
								local trigger = TankTrigger:new(g_server ~= nil, g_client ~= nil)
								trigger:load(TankTriggerId,triggerInfo)
								self.Produkte[name].TankTrigger = trigger;		
								Debug(3,"Output %s add TankTrigger %d",name,TankTriggerId);
								numTrigger = numTrigger + 1;
							else
								Debug(-1,"Output %s TankTrigger cant find TankTrigger Script",name);
							end;
						end
						
						local numLogs = -1 
						local visibilityNodesId = getChild(produktId,"visibilityNodes") 
						if numLogs >= 1 or (visibilityNodesId and visibilityNodesId ~= 0) then
							if numLogs >= 1 then
								visibilityNodesId = WoodTriggerId
							else
								numLogs = getNumOfChildren(visibilityNodesId);
							end
							if numLogs >= 1 then 
								self.Produkte[name].logs = {}
								for numLog = 1, numLogs do 
									local WoodLog = getChildAt(visibilityNodesId,numLog-1)
									self.Produkte[name].logs[numLog]={node = WoodLog,rigidBody = getRigidBodyType(WoodLog)}
									setRigidBodyType(WoodLog,"NoRigidBody")
									setVisibility(WoodLog,false)
								end
								Debug(3,"Output %s add visibilityNodes %d",name,visibilityNodesId);
							end
						end
						
						local LvLDisplay = getChild(produktId,"Displays") 
						if LvLDisplay and LvLDisplay ~= 0 then
							self.Produkte[name].LvLDisplay = {};
							self.Produkte[name].LvLDisplayPercent = {};
							local numDisplayChilds = getNumOfChildren(LvLDisplay);
							for numChild = 1, numDisplayChilds do
								local Display = getChildAt(LvLDisplay,numChild-1)
								local displayArt = getUserAttribute(Display,"displayArt");
								if displayArt == nil or displayArt == "input" then
									table.insert(self.Produkte[name].LvLDisplay,Display);
									Utils.setNumberShaderByValue(Display, math.floor(self.Produkte[name].fillLevel), 0, true)
								elseif displayArt == "capacity" then
									Utils.setNumberShaderByValue(Display, math.floor(self.Produkte[name].capacity), 0, true)
								elseif displayArt == "percent" then
									table.insert(self.Produkte[name].LvLDisplayPercent,Display);
									Utils.setNumberShaderByValue(Display, math.floor(self.Produkte[name].fillLevel/self.Produkte[name].capacity*100), 0, true)
								end;
							end
						end
					
						if numTrigger == 0 then
							Debug(-1,"ERROR: can not find Trigger in Output %s",name);
							return false;
						end
					else
						Debug(-1,"ERROR: invalid fillType %s in %s",tostring( fillType or "nil"),name);
						return false;
					end;
				else
					Debug(-1,"WARNING: Output %s already exists!",name);
				end;
			end;
		else
			Debug(-1,"ERROR: no Objekt on OutputIndex %s",tostring(OutputIndex));
			return false;
		end
	else
		Debug(-1,"ERROR: OutputIndex = nil");
		return false;
	end
	
	local PlayerTriggerIndex = getUserAttribute(self.nodeId,"PlayerIndex");
	if PlayerTriggerIndex then
		local PlayerTrigger = Utils.indexToObject(self.nodeId, PlayerTriggerIndex);
		if PlayerTrigger then
			self.PlayerTrigger = PlayerTrigger;
			addTrigger(self.PlayerTrigger, "PlayerTriggerCallback", self);
		end;
	end;
	
	local DoorsIndex = getUserAttribute(self.nodeId, "DoorsIndex");
	if DoorsIndex ~= nil then
		local Doors = Utils.indexToObject(self.nodeId, DoorsIndex);
		if Doors then
			self.Doors = {}
			local numChildren = getNumOfChildren(Doors);
			for i=1,numChildren do
				local Child = getChildAt(Doors, i-1)
				self.Doors[i] = {}
				self.Doors[i].minTrans = Utils.getNoNil(getUserAttribute(Child, "MinTrans"),0);
				self.Doors[i].maxTrans = Utils.getNoNil(getUserAttribute(Child, "MaxTrans"),2);
				self.Doors[i].Trans = self.Doors[i].minTrans;
				local transTime = Utils.getNoNil(getUserAttribute(Child, "TransTime"),1);
				self.Doors[i].transTime = ((self.Doors[i].maxTrans-self.Doors[i].minTrans) / transTime) * 0.001
				local doorGroup = Child;
				local doorIndex = getUserAttribute(Child, "DoorIndex");
				if doorIndex then
					doorGroup = Utils.indexToObject(Child, doorIndex);
				end;
				local numDoors = getNumOfChildren(doorGroup);
				self.Doors[i].door = {}
				for j=1,numDoors do
					self.Doors[i].door[j] = getChildAt(doorGroup, j-1);
				end;
				local triggerIndex = getUserAttribute(Child, "triggerIndex");
				local trigger = Child;
				if triggerIndex then
					trigger = Utils.indexToObject(Child,triggerIndex);
				end;
				self.Doors[i].triggerId = trigger;
				self.Doors[i].entred = 0;
				addTrigger(trigger, "doorTriggerCallback", self);
			end;
		end;
	end;
	
	if self.isClient then
		local WorkAnimationIndex = getUserAttribute(self.nodeId,"WorkAniIndex");
		if WorkAnimationIndex ~= nil and  WorkAnimationIndex ~= "" then
			local WorkAnimation = Utils.indexToObject(self.nodeId, WorkAnimationIndex);
			if WorkAnimation then
				Debug(3,"Find WorkAnimation on Index %s",WorkAnimationIndex);
				self.WorkAnimation = {}
				local PSIndex = getUserAttribute(WorkAnimation,"PartikleIndex");
				if PSIndex ~= nil and PSIndex ~= "" then
					local PSGroup = Utils.indexToObject(WorkAnimation, PSIndex);
					if PSGroup then
						Debug(3,"Find WorkAnimation PS on Index %s",PSIndex);
						self.WorkAnimation.PS = {}
						local numChildren = getNumOfChildren(PSGroup);
						for i = numChildren, 1, -1 do
							local child = getChildAt(PSGroup,i-1)
							local particleSystem = getUserAttribute(child, "particleSystemFilename");
							Debug(3,"WorkAnimation PS %s",tostring(particleSystem));
							if particleSystem then
								self.WorkAnimation.PS[i] = {}
								local psData = {};
								psData.psFile = particleSystem;
								psData.posX, psData.posY, psData.posZ = getTranslation(child);
								psData.rotX, psData.rotY, psData.rotZ = getRotation(child);
								psData.forceNoWorldSpace = true;
								Utils.loadParticleSystemFromData(psData, self.WorkAnimation.PS[i], nil, false, nil, self.ModDir, getParent(child));
								Debug(3,"WorkAnimation PS Emit %s",tostring(self.WorkAnimation.PS[i].isEmitting));
								local intervall = getUserAttribute(child, "IntervallSek");
								if intervall and intervall > 0 then
									self.WorkAnimation.PS[i].intervall = intervall * 1000;
									self.WorkAnimation.PS[i].elapsed = 0 + self.WorkAnimation.PS[i].intervall;
								end
							end
						end	
					end;
				end
				local AniIndex = getUserAttribute(WorkAnimation,"AnimationIndex");
				if AniIndex ~= nil and AniIndex ~= "" then
					local AniGroup = Utils.indexToObject(WorkAnimation, AniIndex);
					if AniGroup then
						Debug(3,"Find WorkAnimation Ani on Index %s",AniIndex);
						self.WorkAnimation.Ani = {}
						local numChildren = getNumOfChildren(AniGroup);
						for i = numChildren, 1, -1 do
							local child = getChildAt(AniGroup,i-1)
							local ClipName = getUserAttribute(child, "ClipName");
							local MeshIndex = getUserAttribute(child, "MeshIndex");
							local PosIndex = getUserAttribute(child, "PosIndex");
							Debug(3,"WorkAnimation Clip %s",tostring(ClipName));
							if ClipName then
								self.WorkAnimation.Ani[i] = {}
							
								if MeshIndex and PosIndex then
									local position = Utils.indexToObject(child, PosIndex);
									local pos = {getWorldTranslation(position)}
									local rot = {getWorldRotation(position)}
									
									local child2 = clone(child, true)
									link(getRootNode(),child2); 
									
									local Mesh = Utils.indexToObject(child2, MeshIndex);
									setTranslation(Mesh,unpack(pos))
									setRotation(Mesh,unpack(rot))
									
									self.WorkAnimation.Ani[i].root = child2;
									
									delete(child)
									child = child2;
								end
								
								self.WorkAnimation.Ani[i].Animi = getAnimCharacterSet(child);
								self.WorkAnimation.Ani[i].Clip = getAnimClipIndex(self.WorkAnimation.Ani[i].Animi,ClipName)
								assignAnimTrackClip(self.WorkAnimation.Ani[i].Animi, 0, self.WorkAnimation.Ani[i].Clip);
								setAnimTrackLoopState(self.WorkAnimation.Ani[i].Animi, 0, false);
								setAnimTrackSpeedScale(self.WorkAnimation.Ani[i].Animi, 0, 1);
								self.WorkAnimation.Ani[i].IgnoreDuration = getUserAttribute(child, "IgnoreDuration");
							end;
						end;
					end;
				end;
				local SoundIndex = getUserAttribute(WorkAnimation,"SoundIndex");
				if SoundIndex ~= nil and SoundIndex ~= "" then
					local SoundGroup = Utils.indexToObject(WorkAnimation, SoundIndex);
					if SoundGroup then
						Debug(3,"Find WorkAnimation Sound on Index %s",SoundIndex);
						self.WorkAnimation.Sound = {}
						local numChildren = getNumOfChildren(SoundGroup);
						for i = numChildren, 1, -1 do	
							self.WorkAnimation.Sound[i] = {}
							self.WorkAnimation.Sound[i].node = getChildAt(SoundGroup,i-1)
							setVisibility(self.WorkAnimation.Sound[i].node,false)
							local intervall = getUserAttribute(self.WorkAnimation.Sound[i].node, "IntervallSek");
							if intervall and intervall > 0 then
								self.WorkAnimation.Sound[i].intervall = intervall * 1000;
								self.WorkAnimation.Sound[i].elapsed = 0 + self.WorkAnimation.Sound[i].intervall;
							end
						end
					end
				end	
				local ShaderIndex = getUserAttribute(WorkAnimation,"ShaderIndex");
				if ShaderIndex ~= nil and ShaderIndex ~= "" then
					local ShaderGroup = Utils.indexToObject(WorkAnimation, ShaderIndex);
					if ShaderGroup then
						Debug(3,"Find WorkAnimation Shader on Index %s",ShaderIndex);
						self.WorkAnimation.Shader = {}
						local numChildren = getNumOfChildren(ShaderGroup);
						for i = numChildren, 1, -1 do	
							local ShaderChild = getChildAt(ShaderGroup,i-1)
							local ShaderObjekt = Utils.indexToObject(ShaderChild,getUserAttribute(ShaderChild,"ShaderObjektIndex"));
							if ShaderObjekt == nil then	ShaderObjekt = ShaderChild;	end;
							local SP = {}
							SP.node = ShaderObjekt
							SP.Parameter = getUserAttribute(ShaderObjekt,"parameterName");
							local on,off = {},{};
							on.x,on.y,on.z,on.w = Utils.getVectorFromString(getUserAttribute(ShaderObjekt,"value"));
							off.x,off.y,off.z,off.w = getShaderParameter(SP.node,SP.Parameter);
							local shared = getUserAttribute(ShaderObjekt,"shared");
							if shared == true then
								SP.on = on;	SP.off = off;
							else
								SP.on = off; SP.off = on;
							end
							SP.shared = false;
							setShaderParameter(SP.node,SP.Parameter,SP.off.x,SP.off.y,SP.off.z,SP.off.w,false)	
							self.WorkAnimation.Shader[i] = SP;
						end
					end
				end				
			end
		end
	end;
	
	if not self.RunAsGE then
		--destroy
	else
		g_currentMission:addNodeObject(self.nodeId, self)
	end;
	
	self.FabrikScriptDirtyFlag = self:getNextDirtyFlag();
	
	return true;
end;

function FabrikScript:getSaveAttributesAndNodes(nodeIdent)
	
	local attributes, nodes = "","";
			
	if not self.RunAsGE then
		attributes, nodes = FabrikScript:superClass().getSaveAttributesAndNodes(self, nodeIdent);
	end;
	
	for k,v in pairs (self.Rohstoffe) do
		if 0 < nodes.len(nodes) then
			nodes = nodes .. "\n"
		end
		nodes = nodes..nodeIdent..'<Rohstoff Name="'..v.name..'" Lvl="'..v.fillLevel..'"/>';
	end
	for k,v in pairs (self.Produkte) do
		if 0 < nodes.len(nodes) then
			nodes = nodes .. "\n"
		end
		if v.SiloTrigger then
			nodes = nodes..nodeIdent..'<Produkt Name="'..v.name..'" Lvl="'..v.fillLevel..'" isAutomaticFilling="'..tostring(v.SiloTrigger.isAutomaticFilling)..'"/>';
		else
			nodes = nodes..nodeIdent..'<Produkt Name="'..v.name..'" Lvl="'..v.fillLevel..'"/>';
		end;
	end
	  
    return attributes,nodes;
end

function FabrikScript:loadFromAttributesAndNodes(xmlFile, key, resetVehicles)
	
	if not self.RunAsGE and not FabrikScript:superClass().loadFromAttributesAndNodes(self, xmlFile, key, resetVehicles) then
		return false
	end
	
	local i = 0
	while true do
		local RohstoffKey = key .. string.format(".Rohstoff(%d)", i)
		if not hasXMLProperty(xmlFile, RohstoffKey) then
			break
		end

		local RohstoffName = getXMLString(xmlFile, RohstoffKey .. "#Name")
		local fillLevel = getXMLFloat(xmlFile, RohstoffKey .. "#Lvl")

		if RohstoffName ~= nil and fillLevel ~= nil and self.Rohstoffe[RohstoffName] ~= nil then
			if self.Rohstoffe[RohstoffName].TipTrigger then
				self:setFillLevel(self.Rohstoffe[RohstoffName], fillLevel,nil,true,self.Rohstoffe[RohstoffName].name)
			else
				self:setFillLevel(self.Rohstoffe[RohstoffName], fillLevel)
			end;
		end
		i = i + 1
	end	
	i = 0
	while true do
		local ProduktKey = key .. string.format(".Produkt(%d)", i)
		if not hasXMLProperty(xmlFile, ProduktKey) then
			break
		end

		local ProduktName = getXMLString(xmlFile, ProduktKey .. "#Name")
		local fillLevel = getXMLFloat(xmlFile, ProduktKey .. "#Lvl")

		if ProduktName ~= nil and fillLevel ~= nil and self.Produkte[ProduktName] ~= nil then
			
			if self.Produkte[ProduktName].SiloTrigger then
				local isAutomaticFilling = getXMLBool(xmlFile, ProduktKey.."#isAutomaticFilling");
				self.Produkte[ProduktName].SiloTrigger.isAutomaticFilling = isAutomaticFilling;
			end;
			self:setFillLevel(self.Produkte[ProduktName], fillLevel)
		end
		i = i + 1
	end	
	return true;
end

function FabrikScript:writeAllStream(streamId, connection)
	for k,v in pairs (self.Rohstoffe) do
		if self.Rohstoffe[self.StoffeIdToName[v.id]].TipTrigger then
			streamWriteInt16(streamId, v.id)
			streamWriteFloat32(streamId, v.fillLevel)
			streamWriteBool(streamId, true);
		else
			streamWriteInt16(streamId, v.id)
			streamWriteFloat32(streamId, v.fillLevel)
			streamWriteBool(streamId, false);
		end;
		
	end
	for k,v in pairs (self.Produkte) do
		streamWriteInt16(streamId, v.id)
		streamWriteFloat32(streamId, v.fillLevel)
		if self.Produkte[self.StoffeIdToName[v.id]].SiloTrigger then
			streamWriteBool(streamId, true);
			streamWriteBool(streamId, self.Produkte[self.StoffeIdToName[v.id]].SiloTrigger.isAutomaticFilling);
		else
			streamWriteBool(streamId, false);
		end;
	end
	local Fehler = self.Fehler or 0;
	streamWriteInt16(streamId, Fehler)
end;
function FabrikScript:readAllStream(streamId, connection)
	for k,v in pairs (self.Rohstoffe) do
		local id = streamReadInt16(streamId)
		local lvl = streamReadFloat32(streamId)
		local isTipTrigger = streamReadBool(streamId)
		if isTipTrigger then
			self:setFillLevel(self.Rohstoffe[self.StoffeIdToName[id]], lvl,nil,true,self.Rohstoffe[self.StoffeIdToName[id]].name)
		else
			self:setFillLevel(self.Rohstoffe[self.StoffeIdToName[id]], lvl)
		end;
	end
	for k,v in pairs (self.Produkte) do
		local id = streamReadInt16(streamId)
		local lvl = streamReadFloat32(streamId)
		local isSiloTrigger = streamReadBool(streamId)
		if isSiloTrigger then
			local isAutomaticFilling = streamReadBool(streamId)
			self:setFillLevel(self.Produkte[self.StoffeIdToName[id]], lvl)
			self.Produkte[self.StoffeIdToName[id]].SiloTrigger.isAutomaticFilling = isAutomaticFilling;
		else
			self:setFillLevel(self.Produkte[self.StoffeIdToName[id]], lvl)
		end;
	end
	local Fehler = streamReadInt16(streamId)
	self.Fehler = Fehler > 0 and Fehler or nil;
end; 
function FabrikScript:writeStream(streamId, connection)
	FabrikScript:superClass().writeStream(self, streamId, connection)
	self:writeAllStream(streamId, connection)
end
function FabrikScript:readStream(streamId, connection)
	FabrikScript:superClass().readStream(self, streamId, connection)
	self:readAllStream(streamId, connection)
end;
function FabrikScript:writeUpdateStream(streamId, connection, dirtyMask)
	FabrikScript:superClass().writeUpdateStream(self, streamId, connection, dirtyMask);
	self:writeAllStream(streamId, connection)
end;
function FabrikScript:readUpdateStream(streamId, timestamp, connection)
	FabrikScript:superClass().readUpdateStream(self, streamId, timestamp, connection);
	self:readAllStream(streamId, connection)
end;

function FabrikScript:deleteMap()
	self:delete();
end;
function FabrikScript:delete()
	unregisterObjectClassName(self)
	g_currentMission:removeOnCreateLoadedObjectToSave(self)
	if self.Rohstoffe then
		for k,v in pairs (self.Rohstoffe) do
			if v.TipTrigger and v.TipTrigger.isRegistered then
				v.TipTrigger:unregister()
				v.TipTrigger:delete()
			end
			if v.BaleTrigger then
				removeTrigger(v.BaleTrigger)
			end
			if v.PalletTrigger then
				removeTrigger(v.PalletTrigger)
			end
			if v.WoodTrigger then
				removeTrigger(v.WoodTrigger)
			end
			if v.LiquideTrigger then
				v.LiquideTrigger:delete();
			end;
		end
	end
	if self.Produkte then
		for k,v in pairs (self.Produkte) do
			if v.Heap and v.Heap.ShovelTrigger then
				v.Heap.ShovelTrigger:delete()
			end
			if v.palletSpawner then
				removeTrigger(v.palletSpawner.SpawnerTriggerId)
			end
			if v.SiloTrigger then
				v.SiloTrigger:delete();
			end;
			if v.LiquideTrigger then
				v.LiquideTrigger:delete()
			end
		end
	end
	if self.PlayerTrigger then
		removeTrigger(self.PlayerTrigger)
	end
	if self.Doors then
		for i=1, table.getn(self.Doors) do
			removeTrigger(self.Doors[i].triggerId);
		end
	end
	for trailer, triggers in pairs(g_currentMission.trailerTipTriggers) do
		if triggers ~= nil then
			for i = 1, table.getn(triggers), 1 do
				if triggers[i] == self then
					table.remove(triggers, i)

					if table.getn(triggers) == 0 then
						g_currentMission.trailerTipTriggers[trailer] = nil
					end
				end
			end
		end
	end
	if self.WorkAnimation then
		if self.WorkAnimation.Ani then
			for index, Ani in pairs(self.WorkAnimation.Ani) do
				if Ani.root then
					delete(Ani.root)
					Ani.root = 0;
				end
			end
		end
	end
	if not self.RunAsGE then FabrikScript:superClass().delete(self) end;
end;

function FabrikScript:update(dt)
	
	
	if self.changeAllowed then
		local RohstoffText = "Rohstoffe:";
		if g_i18n:hasText(self.InputName) then
			RohstoffText = g_i18n:getText(self.InputName)
		elseif g_i18n:hasText("Rohstoffe") then
			RohstoffText = g_i18n:getText("Rohstoffe")
		end
		g_currentMission:addExtraPrintText(RohstoffText);
		for k,v in pairs (self.Rohstoffe) do
			local text = string.format("%s",v.nameL.." [l]");
			local Percentage = math.abs(v.fillLevel / v.capacity * 100);
			text = text.." "..string.format("%d (%d%%)",v.fillLevel ,Percentage);
			g_currentMission:addExtraPrintText(text);
		end
		local ProdukteText = "Produkte:";
		if g_i18n:hasText(self.OutputName) then
			ProdukteText = g_i18n:getText(self.OutputName)
		elseif g_i18n:hasText("Produkte") then
			ProdukteText = g_i18n:getText("Produkte")
		end
		g_currentMission:addExtraPrintText(ProdukteText);
		for k,v in pairs (self.Produkte) do
			local text = string.format("%s",v.nameL.." [l]");
			local Percentage = math.abs(v.fillLevel / v.capacity * 100);
			text = text.." "..string.format("%d (%d%%)",v.fillLevel ,Percentage);
			g_currentMission:addExtraPrintText(text);
		end
		if self.Fehler then
			g_currentMission:addExtraPrintText((g_i18n:hasText("ERROR") and g_i18n:getText("ERROR") or "ERROR: ")..self.FehlerText[self.Fehler]);
		end
		if not g_currentMission.controlPlayer then
			self.changeAllowed = false;
		end;
	end;
	
end;
function FabrikScript:updateTick(dt)
	
	self.updateMs = self.updateMs + (dt * g_currentMission.loadingScreen.missionInfo.timeScale);
	if self.updateMs >= 60000   then
		self.updateMs = self.updateMs - 60000;
		self.updateMin = self.updateMin + 1;
		if self.updateMin >= self.updateIntervall then
			self.updateMin = self.updateMin - self.updateIntervall
			if self.isServer then
				local need = (self.ProduktPerHour/60 * self.updateIntervall) --Bedarf pro intervall 
				local RohstoffeVorhanden = true;
				for k,v in pairs (self.Rohstoffe) do
					if v.fillLevel < need * v.factor then
						need = v.fillLevel / v.factor
						if need <= 0 then
							RohstoffeVorhanden = false;
							self.Fehler = v.id
							break;
						end;
					end;
				end
				local CapacityVorhanden = true;
				for k,v in pairs (self.Produkte) do
					if v.palletSpawner ~= nil then
						if v.palletSpawner.currentPallet then
							if not entityExists(v.palletSpawner.currentPallet.nodeId) or getName(getParent(v.palletSpawner.currentPallet.nodeId)) ~= "RootNode" then
								v.palletSpawner.numObjectsInPalletSpawnerTrigger = v.palletSpawner.numObjectsInPalletSpawnerTrigger - (v.palletSpawner.numObjectsPerID[v.palletSpawner.currentPallet.nodeId] or 0);
								v.palletSpawner.numObjectsPerID[v.palletSpawner.currentPallet.nodeId] = nil;
								v.palletSpawner.currentPallet = nil;	
							end;
						end;
						if v.palletSpawner.currentPallet == nil then
							v.fillLevel = 0;
							if v.palletSpawner.numObjectsInPalletSpawnerTrigger > 0 then
								CapacityVorhanden = false;
								self.Fehler = v.id + 1;
								break;
							end;
						end;
					end;
					if v.fillLevel + need * v.factor > v.capacity then
						need = (v.capacity-v.fillLevel) / v.factor
						if need <= 0 then
							CapacityVorhanden = false;
							self.Fehler = v.id
							break;
						end
					end;
				end
				if RohstoffeVorhanden and CapacityVorhanden then
					for k,v in pairs (self.Rohstoffe) do
						self:setFillLevel(v, v.fillLevel - need * v.factor)
					end
					for k,v in pairs (self.Produkte) do
						if v.palletSpawner ~= nil then
							if v.palletSpawner.currentPallet == nil and v.palletSpawner.numObjectsInPalletSpawnerTrigger == 0 then
								local x, y, z = getWorldTranslation(v.palletSpawner.SpawnerPlaceId)
								local rx, ry, rz = getWorldRotation(v.palletSpawner.SpawnerPlaceId)
								local pallet = FillablePallet:new(self.isServer, self.isClient)
								
								if pallet.load(pallet, v.palletSpawner.Filename, x, y, z, rx, ry, rz) then
									pallet.register(pallet)

									v.palletSpawner.currentPallet = pallet
									v.palletSpawner.currentPallet.isReferenced = true
									v.capacity = pallet:getCapacity();
								else
									pallet.delete(pallet)
								end
							end

							if v.palletSpawner.currentPallet ~= nil then
								v.palletSpawner.currentPallet:setFillLevel(v.palletSpawner.currentPallet:getFillLevel() + need * v.factor);
								v.fillLevel = v.palletSpawner.currentPallet:getFillLevel();
								if v.LvLDisplay then
									for numDisplay = 1, #v.LvLDisplay do
										Utils.setNumberShaderByValue(v.LvLDisplay[numDisplay], math.floor(v.fillLevel), 0, true)
										Utils.setNumberShaderByValue(v.LvLDisplayPercent[numDisplay], math.floor(v.fillLevel/v.capacity*100), 0, true)
									end
								end
							end
						else
							self:setFillLevel(v, v.fillLevel + need * v.factor,v.name)
						end
					end
					self.Fehler = nil;
				else
					self.SendUpdate = true;
				end
			end;
			if self.isClient and self.WorkAnimation ~= nil then
				if self.Fehler == nil then
					if self.WorkAnimation.PS then
						local numPS = table.getn(self.WorkAnimation.PS)
						for i = 1, numPS do
							local PS = self.WorkAnimation.PS[i];
							if PS.isEmitting ~= true and PS.elapsed == nil then
								Utils.setEmittingState(PS, true)
							end
						end
					end;
					if self.WorkAnimation.Ani then
						local numAni = table.getn(self.WorkAnimation.Ani)
						for i = 1, numAni do
							local Ani = self.WorkAnimation.Ani[i];
							if not isAnimTrackEnabled(Ani.Animi, 0) then
								enableAnimTrack(Ani.Animi, 0);
							end;
						end;
					end;
					if self.WorkAnimation.Sound then
						local numSound = table.getn(self.WorkAnimation.Sound)
						for i = 1, numSound do
							local Sound = self.WorkAnimation.Sound[i];
							if not getVisibility(Sound.node) and Sound.elapsed == nil then
								setVisibility(Sound.node,true)
							end;
						end;
					end;
					if self.WorkAnimation.Shader then
						local numShader = table.getn(self.WorkAnimation.Shader)
						for i = 1, numShader do
							local SP = self.WorkAnimation.Shader[i];
							if not SP.shared then
								SP.shared = true;
								setShaderParameter(SP.node,SP.Parameter,SP.on.x,SP.on.y,SP.on.z,SP.on.w,false)	
							end;
						end;
					end;
					self.StopWorkAni = nil;
				else
					self.StopWorkAni = true;
				end
			end
		end;
	end;
	
	if self.isClient then
		if self.WorkAnimation ~= nil and self.Fehler == nil then
			if self.WorkAnimation.Ani then
				local numAni = table.getn(self.WorkAnimation.Ani)
				for i = 1, numAni do
					local Ani = self.WorkAnimation.Ani[i];
					if isAnimTrackEnabled(Ani.Animi, 0) then
						if getAnimTrackTime(Ani.Animi, 0) >= getAnimClipDuration(Ani.Animi, 0) then
							setAnimTrackTime(Ani.Animi, 0, 0, false);
						end;
					end;
				end;
			end;
			if self.WorkAnimation.PS then
				local numPS = table.getn(self.WorkAnimation.PS)
				for i = 1, numPS do
					local PS = self.WorkAnimation.PS[i];
					if PS.elapsed then
						PS.elapsed = PS.elapsed - dt;
						if PS.elapsed <= 0 then
							PS.elapsed = PS.elapsed + PS.intervall;
							Utils.setEmittingState(PS, not PS.isEmitting)
						end
					end
				end
			end;
			if self.WorkAnimation.Sound then
				local numPS = table.getn(self.WorkAnimation.Sound)
				for i = 1, numPS do
					local Sound = self.WorkAnimation.Sound[i];
					if Sound.elapsed then
						Sound.elapsed = Sound.elapsed - dt;
						if Sound.elapsed <= 0 then
							Sound.elapsed = Sound.elapsed + Sound.intervall;
							setVisibility(Sound.node,not getVisibility(Sound.node))
						end;
					end;
				end;
			end;
		elseif self.WorkAnimation ~= nil and self.StopWorkAni then
			local AniDisabled = true;
			if self.WorkAnimation.Ani then
				local numAni = table.getn(self.WorkAnimation.Ani)
				for i = 1, numAni do
					local Ani = self.WorkAnimation.Ani[i];
					if isAnimTrackEnabled(Ani.Animi, 0) then
						if Ani.IgnoreDuration then
							disableAnimTrack(Ani.Animi, 0);
							setAnimTrackTime(Ani.Animi, 0, 0, false);
						elseif getAnimTrackTime(Ani.Animi, 0) >= getAnimClipDuration(Ani.Animi, 0) then
							disableAnimTrack(Ani.Animi, 0);
							setAnimTrackTime(Ani.Animi, 0, 0, false);
						else
							AniDisabled = false;
						end;
					end;
				end;
			end;
			if AniDisabled then
				if self.WorkAnimation.PS then
					local numPS = table.getn(self.WorkAnimation.PS)
					for i = 1, numPS do
						local PS = self.WorkAnimation.PS[i];
						if PS.isEmitting == true then
							Utils.setEmittingState(PS, false)
						end
					end
				end;
				if self.WorkAnimation.Sound then
					local numSound = table.getn(self.WorkAnimation.Sound)
					for i = 1, numSound do
						local Sound = self.WorkAnimation.Sound[i];
						if getVisibility(Sound.node) then
							setVisibility(Sound.node,false)
						end;
					end;
				end;
				if self.WorkAnimation.Shader then
					local numShader = table.getn(self.WorkAnimation.Shader)
					for i = 1, numShader do
						local SP = self.WorkAnimation.Shader[i];
						if SP.shared then
							SP.shared = false;
							setShaderParameter(SP.node,SP.Parameter,SP.off.x,SP.off.y,SP.off.z,SP.off.w,false)	
						end;
					end;
				end;
				self.StopWorkAni = nil;
			end;
		end;
	end;
	
	if self.Doors then
		for i=1, table.getn(self.Doors) do
			local old = self.Doors[i].Trans;
			if (self.Doors[i].entred > 0) then
				if self.Doors[i].Trans < self.Doors[i].maxTrans then
					self.Doors[i].Trans = math.min(self.Doors[i].Trans + dt*self.Doors[i].transTime, self.Doors[i].maxTrans);
				end;
			elseif (self.Doors[i].entred <= 0) then
				if self.Doors[i].Trans > self.Doors[i].minTrans then
					self.Doors[i].Trans = math.max(self.Doors[i].Trans - dt*self.Doors[i].transTime, self.Doors[i].minTrans);
				end;
			end;

			if old ~= self.Doors[i].Trans then
				local dir = 1;
				for j=1, table.getn(self.Doors[i].door) do
					local x, y, z = getTranslation(self.Doors[i].door[j]);
					setTranslation(self.Doors[i].door[j], x, y, self.Doors[i].Trans * dir);
					dir = dir * -1
				end;
			end;
		end;
	end;
	
	if self.isServer and self.SendUpdate then
		self.SendUpdate = nil
		self:raiseDirtyFlags(self.FabrikScriptDirtyFlag);
	end
end;

function FabrikScript:setFillLevel(art, fillLevel, fillType, isTipTrigger, name)
	Debug(10,"setFillLevel fillLevel %.2f  isTipTrigger %s name %s",fillLevel, tostring(isTipTrigger),name);
	--local oldLvl = art.fillLevel
	
	if isTipTrigger then
		--local name = art.Rohstoffname;
		if self.Rohstoffe[name].TipTrigger then
			self:updateMoving(fillLevel,self.Rohstoffe[name])
			self.Rohstoffe[name].fillLevel = fillLevel
		end
		if self.Rohstoffe[name].logs then
			self:updateWoodTriggerLogs(self.Rohstoffe[name],fillLevel)
		end;
		if self.Rohstoffe[name].LvLDisplay then
			for numDisplay = 1, #self.Rohstoffe[name].LvLDisplay do
				Utils.setNumberShaderByValue(self.Rohstoffe[name].LvLDisplay[numDisplay], math.floor(fillLevel), 0, true)
				Utils.setNumberShaderByValue(self.Rohstoffe[name].LvLDisplayPercent[numDisplay], math.floor(fillLevel/self.Rohstoffe[name].capacity*100), 0, true)
			end
		end
	else
		art.fillLevel = fillLevel
		if art.TipTrigger then 
			self:updateMoving(fillLevel,art)
		end
		if art.Heap ~= nil then
			self:onAmountChanged(art.Heap,fillLevel)
		elseif art.LiquideTrigger then
			art.LiquideTrigger:updateMoving(fillLevel)
		end;
		if art.logs then
			self:updateWoodTriggerLogs(art,fillLevel)
		end;
		if art.LvLDisplay then
			for numDisplay = 1, #art.LvLDisplay do
				Utils.setNumberShaderByValue(art.LvLDisplay[numDisplay], math.floor(fillLevel), 0, true)
				Utils.setNumberShaderByValue(art.LvLDisplayPercent[numDisplay], math.floor(fillLevel/art.capacity*100), 0, true)
			end
		end
	end;
	self.SendUpdate = true;
end

function FabrikScript:getManureLevel(art)
    local xs,_,zs = getWorldTranslation(art.start);
    local xw,_,zw = getWorldTranslation(art.width);
    local xh,_,zh = getWorldTranslation(art.height);
    local fillLevel = TipUtil.getFillLevelAtArea(art.fillType, xs,zs, xw,zw, xh,zh);
    return fillLevel;
end

function FabrikScript:setIsLiquideTankFilling(FS_LiquideTriggerId, isFilling, trailer,  noEventSend)
	if self.Rohstoffe then
		for k,v in pairs (self.Rohstoffe) do
			if v.LiquideTrigger and v.LiquideTrigger.FS_LiquideTriggerId and v.LiquideTrigger.FS_LiquideTriggerId == FS_LiquideTriggerId then
				v.LiquideTrigger:setIsLiquideTankFilling(isFilling, trailer, noEventSend)
				FS_LiquideTriggerId = nil;
				break;
			end
		end
	end
	if FS_LiquideTriggerId and self.Produkte then
		for k,v in pairs (self.Produkte) do
			if v.LiquideTrigger and v.LiquideTrigger.FS_LiquideTriggerId and v.LiquideTrigger.FS_LiquideTriggerId == FS_LiquideTriggerId then
				v.LiquideTrigger:setIsLiquideTankFilling(isFilling, trailer, noEventSend)
				break;
			end
		end
	end
end

function FabrikScript:setIsSiloTriggerFilling(FS_SiloTriggerId,isFilling,noEventSend)
	if FS_SiloTriggerId and self.Produkte then
		for k,v in pairs(self.Produkte) do
			if v.SiloTrigger and v.SiloTrigger.FS_SiloTriggerId and v.SiloTrigger.FS_SiloTriggerId == FS_SiloTriggerId then
				v.SiloTrigger:setFilling(isFilling,noEventSend);
			end;
		end;
	end;
end;

function FabrikScript:setIsSiloTriggerAutomatic(FS_SiloTriggerId,isFilling,noEventSend)
	if FS_SiloTriggerId and self.Produkte then
		for k,v in pairs(self.Produkte) do
			if v.SiloTrigger and v.SiloTrigger.FS_SiloTriggerId and v.SiloTrigger.FS_SiloTriggerId == FS_SiloTriggerId then
				v.SiloTrigger:setAutomaticFilling(isFilling,noEventSend);
			end;
		end;
	end;
end;

function FabrikScript:getFillLevel(art,isInput)
	if isInput then
		return self.Rohstoffe[art].fillLevel;
	else
		return art.fillLevel;
	end;
end
function FabrikScript:getCapacity(art)
	return art.capacity;
end
function FabrikScript:getIsValidTrailer(trailer,art) 
	for _,fillType in pairs(art.fillTypes) do
		if trailer:allowFillType(fillType,false) then
			return true;
		end;
	end;
	return false;
end;
function FabrikScript:SiloTriggerGetFillLevel(art,fillType)
	for name,_ in pairs(self.Produkte) do
		if self.Produkte[name].SiloTrigger ~= nil then
			if self.Produkte[name].SiloTrigger.fillTypes[fillType] then
				return self.Produkte[name].fillLevel
			end;
		end;
	end;
	return nil
end;

function FabrikScript:updateMoving(fillLevel,move)
	if move.movingId ~= nil then
		local x,_,z = getTranslation(move.movingId);
		local y = move.moveMinY;
		local newY = math.min(y+fillLevel*move.movingScale,move.moveMaxY);
		setTranslation(move.movingId,x,newY,z);
	end;
end;
function FabrikScript:updateWoodTriggerLogs(Trigger,fillLevel)
	if self.isClient and Trigger.logs then
		local numVisibilityNodes = table.getn(Trigger.logs)
		local numVisible = math.ceil((numVisibilityNodes*fillLevel)/Trigger.capacity)
		for i = 1, numVisibilityNodes, 1 do
			setVisibility(Trigger.logs[i].node, i <= numVisible)
			setRigidBodyType(Trigger.logs[i].node, i <= numVisible and Trigger.logs[i].rigidBody or "NoRigidBody")
		end
	end
end

function FabrikScript:addShovelFillLevel(target, shovel, fillLevel, fillType)
	Debug(10,"addShovelFillLevel fillLevel %.2f  fillType %d",fillLevel, fillType);
	if target.Rohstoff and target.fillTypes[fillType] then
		local rLvl = self.Rohstoffe[target.Rohstoff].fillLevel;
		local rCap = self.Rohstoffe[target.Rohstoff].capacity
		local art = self.Rohstoffe[target.Rohstoff]
		Debug(10,"addShovelFillLevel rLvl %.2f < rCap %.2f",rLvl, rCap);
		if rLvl < rCap then
	        fillLevel = math.min(fillLevel, rCap - rLvl);
			self:setFillLevel(art,rLvl + fillLevel, fillType,false)
			return fillLevel;
		end;
	end;
    return 0;
end;
function FabrikScript:addFillLevelFromTool(trailer,fillDelta,fillType,val)
	if type(fillDelta) == "table" then
		trailer = fillDelta;
		fillDelta = fillType;
		fillType = val;
	end;
		
	local trigger = self.trailerTipTrigger[trailer]
	if fillDelta > 0 and trigger ~= nil then
		if trigger.fillLevel ~= nil then
			local name = trigger.TipTrigger.Rohstoffname;
			trigger.fillLevel = self:getFillLevel(name,true);
			local maxFillDelta = math.min(fillDelta,trigger.capacity-trigger.fillLevel)
			self:setFillLevel(trigger,trigger.fillLevel + maxFillDelta,fillType, true,name);
			return maxFillDelta;
		else
			return 0;
		end;
	else
		return 0;
	end;
end;
function FabrikScript:fillShovel(ST, shovel, dt)
	if ST.Produkt then
		local fillLevel = self:getFillLevel(self.Produkte[ST.Produkt]);
		if fillLevel > 0 then
			local delta = shovel:fillShovelFromTrigger(ST, fillLevel, ST.fillType, dt*500);
			if delta > 0 then
				self:setFillLevel(self.Produkte[ST.Produkt],fillLevel-delta, ST.fillType);
			end;
		end;
	end;
end;

function FabrikScript:onAmountChanged(moving,amount)
    if moving.moveMaxAmount then
		if amount < 0.001 then
			amount = 0;
		end;
		local mover = 0;
		if moving.movingIndex then
			mover = moving.movingIndex
		elseif moving.id then
			mover = moving.id
		end
		local x,y,z = getTranslation(mover);
		local y = moving.moveMinY + (moving.moveMaxY - moving.moveMinY)*Utils.clamp(amount, 0, moving.moveMaxAmount)/(moving.moveMaxAmount);
		setTranslation(mover, x,y,z);
	end;
end;
function FabrikScript:allowFillType(art,FillType)
	return art.acceptedFillTypes[FillType];
end;
function FabrikScript:allowFillType(art,FillType)
	return art.acceptedFillTypes[FillType];
end

function FabrikScript:PlayerTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay)
	if (g_currentMission.controlPlayer and g_currentMission.player and otherId == g_currentMission.player.rootNode) then
		if (onEnter) then 
            self.changeAllowed = true;
        elseif (onLeave) then
            self.changeAllowed = false;
        end;
	end;
end;
function FabrikScript:doorTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)	
	for i=1, table.getn(self.Doors) do
		if self.Doors[i].triggerId == triggerId then
			if onEnter then
				self.Doors[i].entred = self.Doors[i].entred + 1
			else
				self.Doors[i].entred = math.max(self.Doors[i].entred - 1,0)
			end;
			break;
		end;
	end;
end;
function FabrikScript:BaleTriggerCallback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
	if onEnter and otherActorId ~= 0 then
		local object = g_currentMission:getNodeObject(otherActorId);
		if object ~= nil and object:isa(Bale) then
			local fillLevel = object:getFillLevel();
			local fillType = object:getFillType();
			for name,_ in pairs(self.Rohstoffe) do
				art = self.Rohstoffe[name]
				if art.BaleTrigger == triggerId and art.acceptedFillTypes[fillType] then
					if art.fillLevel + fillLevel <= art.capacity then
						self:setFillLevel(art,art.fillLevel + fillLevel,fillType,false)
						object:delete();  
					end;   
					break; 
				end;
			end;
		end;
	end;
end;
function FabrikScript:PalletTriggerCallback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
	if onEnter and otherActorId ~= 0 then
		local object = g_currentMission:getNodeObject(otherActorId)
		if object ~= nil and object.isa(object, FillablePallet) then
			if g_currentMission:getIsServer() then
				local fillType = object:getFillType()
				for name,_ in pairs (self.Rohstoffe) do
					local art = self.Rohstoffe[name]
					if art.PalletTrigger == triggerId and art.acceptedFillTypes[fillType] then
						local fillLevel = object:getFillLevel()
						if art.fillLevel + fillLevel <= art.capacity then
							self:setFillLevel(art,art.fillLevel + fillLevel,fillType,false)
							object:delete()
						end;
						break;
					end;
				end;
			end
		end
	end
end
function FabrikScript:WoodTriggerCallback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
	if onEnter and otherActorId ~= 0 then
		local splitType = SplitUtil.splitTypes[getSplitType(otherActorId)]

		if splitType ~= nil and 0 < splitType.woodChipsPerLiter then
			
			for name,_ in pairs (self.Rohstoffe) do
				local art = self.Rohstoffe[name]
				if art.WoodTrigger == triggerId then 
					if g_currentMission:getIsServer() then
						local volume = getVolume(otherActorId)
						
						local fillLevel = volume*1000*splitType.woodChipsPerLiter
						Debug(5,"wood %s Lvl %.2f volume %.2f woodChipsPerLiter %.2f ",splitType.name,fillLevel,volume,splitType.woodChipsPerLiter);
						if art.fillLevel + fillLevel <= art.capacity then
							self:setFillLevel(art,art.fillLevel + fillLevel,fillType, false)
							delete(otherActorId)
						end
					end
					break;
				end
			end
		end
	end;
end;
function FabrikScript:palletSpawnerTriggerCallback(triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
	for k,v in pairs (self.Produkte) do
		if v.palletSpawner and v.palletSpawner.SpawnerTriggerId == triggerId then --and self:allowFillType(v,fillType) then
			if onEnter then
				v.palletSpawner.numObjectsInPalletSpawnerTrigger = v.palletSpawner.numObjectsInPalletSpawnerTrigger + 1
				v.palletSpawner.numObjectsPerID[otherActorId] = (v.palletSpawner.numObjectsPerID[otherActorId] or 0) + 1;
				if v.palletSpawner.currentPallet == nil and otherActorId ~= 0 then
					local object = g_currentMission:getNodeObject(otherActorId)

					if object ~= nil and object.isa(object, FillablePallet) and self:allowFillType(v,object:getFillType()) then
						v.palletSpawner.currentPallet = object
						v.palletSpawner.currentPallet.isReferenced = true
						v.capacity = object:getCapacity();
						v.fillLevel = object:getFillLevel();
					end
				end
			elseif onLeave then
				v.palletSpawner.numObjectsInPalletSpawnerTrigger = v.palletSpawner.numObjectsInPalletSpawnerTrigger - 1
				v.palletSpawner.numObjectsPerID[otherActorId] = (v.palletSpawner.numObjectsPerID[otherActorId] or 0) - 1;
				if v.palletSpawner.numObjectsPerID[otherActorId] <= 0 then
					v.palletSpawner.numObjectsPerID[otherActorId] = nil;
				end
				if v.palletSpawner.currentPallet ~= nil and v.palletSpawner.currentPallet.nodeId == otherActorId then
					v.palletSpawner.currentPallet.isReferenced = false
					v.palletSpawner.currentPallet = nil
					v.fillLevel = 0;
				end
			end
		end;
	end;
end

function FabrikScript:TipTriggerCallback(art, triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	Debug(8,"TipTriggerCallback art %s triggerId %s otherId %s onEnter %s onLeave %s onStay %s otherShapeId %s",tostring(art), tostring(triggerId), tostring(otherId), tostring(onEnter), tostring(onLeave), tostring(onStay), tostring(otherShapeId));
	
	local trailer = g_currentMission.objectToTrailer[otherShapeId];
	if trailer ~= nil and trailer.allowTipDischarge then
		if onEnter then
			if g_currentMission.trailerTipTriggers[trailer] == nil then
				g_currentMission.trailerTipTriggers[trailer] = {};
			end;
			self.trailerTipTrigger[trailer] = art;
			table.insert(g_currentMission.trailerTipTriggers[trailer], self);
			if trailer.coverAnimation ~= nil and trailer.autoReactToTrigger == true then
                trailer:setCoverState(true);
			end
		elseif onLeave then
			local triggers = g_currentMission.trailerTipTriggers[trailer];
			if triggers ~= nil then
				for i=1, table.getn(triggers) do
					if triggers[i] == self then
						self.trailerTipTrigger[trailer] = nil;
						table.remove(triggers, i);
						if table.getn(triggers) == 0 then
							g_currentMission.trailerTipTriggers[trailer] = nil;
						end;
						break;
					end;
				end;
			end;
			if trailer.coverAnimation ~= nil and trailer.autoReactToTrigger == true then
                trailer:setCoverState(false);
			end
		end;
	end;
end;

function FabrikScript:getTipInfoForTrailer(trailer, tipReferencePointIndex)
	local isAllowed, minDistance, bestPoint = true, math.huge, nil;
	if self.trailerTipTrigger[trailer] and self.trailerTipTrigger[trailer].TipTrigger then
		isAllowed, minDistance, bestPoint = self.trailerTipTrigger[trailer].TipTrigger:getTipInfoForTrailer(trailer, tipReferencePointIndex);
	end
    return isAllowed, minDistance, bestPoint;
end

function FabrikScript:getNotAllowedText(fillable,toolType)
	local text = ""
	if self.trailerTipTrigger[trailer] and self.trailerTipTrigger[trailer].TipTrigger then
		text = self.trailerTipTrigger[trailer].TipTrigger:getNotAllowedText(fillable,toolType);
	end
    return text;
end


if FabrikScript.RunAsGE then
	g_onCreateUtil.addOnCreateFunction("FabrikScript", FabrikScript.onCreate);
else
	registerPlaceableType("FabrikScript", FabrikScript);
end;

