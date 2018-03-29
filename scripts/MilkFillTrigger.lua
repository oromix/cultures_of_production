--[[
##Version: 1.1.0.0
##Author: kevink98
##Date: 29.11.2016
##ModName: MilkTrigger
##Desc: Abholung der Milch bei den Kühen

##Changelog: 	V 1.0.0
					- Release
				V 1.1.0
					- Fix zum Einbau mit dem GiantsEditor

]]--

 
MilkFillTrigger = {};
MilkFillTrigger.ModDir = g_currentModDirectory
MilkFillTrigger_mt = nil


local nBeginn, nEnde = string.find(MilkFillTrigger.ModDir,"placeable");
if nBeginn then
	MilkFillTrigger_mt = Class(MilkFillTrigger, Placeable);
else
	MilkFillTrigger.RunAsGE = true;
	MilkFillTrigger_mt = Class(MilkFillTrigger, Object);
end

InitObjectClass(MilkFillTrigger, "MilkFillTrigger");

function MilkFillTrigger.onCreate(id)
    local trigger = MilkFillTrigger:new(g_server ~= nil, g_client ~= nil);
	g_currentMission:addOnCreateLoadedObject(trigger);
    if trigger:load(id) then
		g_currentMission:addOnCreateLoadedObjectToSave(trigger);
        trigger:register(true);
    else
        trigger:delete();
    end
end;

function MilkFillTrigger:new(isServer, isClient, costomMt)
 local mt = customMt;
    if mt == nil then
        mt = MilkFillTrigger_mt;
    end;
	local self = {};
	if MilkFillTrigger.RunAsGE then
		self = Object:new(isServer, isClient, mt)
	else
		self = Placeable:new(isServer, isClient, mt);
		registerObjectClassName(self, "MilkFillTrigger");
	end;
	
	self.nodeId = 0;
	self.MilkFillTriggerDirtyFlag = self:getNextDirtyFlag();
    return self;
end;

function MilkFillTrigger:load(xmlFilename, x,y,z, rx,ry,rz, initRandom)
	if MilkFillTrigger.RunAsGE then
		self.saveId = getUserAttribute(xmlFilename,"saveId");
		if self.saveId == nil then
			self.saveId = "MilkFillTrigger_"..getName(xmlFilename)
		end
	end;
	
	if not self.RunAsGE then
		if not MilkFillTrigger:superClass().load(self, xmlFilename, x,y,z, rx,ry,rz, initRandom) then
			return false;
		end;
		return true;
	else
		self.nodeId = xmlFilename;
		if not self:finalizePlacement() then return false; end;
	end;
	
	
	return true;
end;

function MilkFillTrigger:finalizePlacement(x, y, z, rx, ry, rz, initRandom)
	if not self.RunAsGE then
		MilkFillTrigger:superClass().finalizePlacement(self)
	end
	local TriggerID = getChild(self.nodeId,"MilkTrigger")
	if TriggerID and TriggerID ~= 0 then
		local fillType = FillUtil.fillTypeNameToInt[getUserAttribute(self.nodeId,"fillType")];
		
		local trigger = FillTrigger:new();
		trigger:load(TriggerID,fillType,self);
		self.trigger = trigger;
		self.trigger.isEnabled = true;
		self.trigger.triggerCallback = function (...) return self:triggerCallback(...) end;
		self.trigger.fill = function (...) return self:fill(...) end;
		self.trigger.getIsActivatable = function (...) return self:getIsActivatable(...) end;
		self.trigger.fillType = fillType
		self.fillLvlChange = 0;
	end;
	if not self.RunAsGE then
		
	else
		g_currentMission:addNodeObject(self.nodeId, self)
	end;
	
	return true;
end; 
function MilkFillTrigger:getCapacity()
	return self.capacity;
end
function MilkFillTrigger:getFillLevel()
	return g_currentMission.husbandries["cow"].fillLevelMilk
end
function MilkFillTrigger:setFillLevel(fillLvl)
	MilkFillTriggerEvent.sendEvent(fillLvl,noEventSend)
	g_currentMission.husbandries["cow"].fillLevelMilk = fillLvl
	self.fillLvlChange = 0;
end

function MilkFillTrigger:getSaveAttributesAndNodes(nodeIdent) 
	local attributes, nodes = "","";
	if not self.RunAsGE then
		attributes, nodes = MilkFillTrigger:superClass().getSaveAttributesAndNodes(self, nodeIdent);
	end;
	return attributes,nodes;
end

function MilkFillTrigger:loadFromAttributesAndNodes(xmlFile, key, resetVehicles) 
	if not self.RunAsGE and not MilkFillTrigger:superClass().loadFromAttributesAndNodes(self, xmlFile, key, resetVehicles) then
		return false
	end
	return true
end

function MilkFillTrigger:writeAllStream(streamId, connection)
	streamWriteInt32(streamId, self:getFillLevel());
end;
function MilkFillTrigger:readAllStream(streamId, connection) 
	local fillLvl = streamReadInt32(streamId)
	self:setFillLevel(fillLvl)
end; 
function MilkFillTrigger:writeStream(streamId, connection)
	MilkFillTrigger:superClass().writeStream(self, streamId, connection)
	self:writeAllStream(streamId, connection)
end
function MilkFillTrigger:readStream(streamId, connection)
	MilkFillTrigger:superClass().readStream(self, streamId, connection)
	self:readAllStream(streamId, connection)
end;
function MilkFillTrigger:writeUpdateStream(streamId, connection, dirtyMask)
	MilkFillTrigger:superClass().writeUpdateStream(self, streamId, connection, dirtyMask);
	self:writeAllStream(streamId, connection)
end;
function MilkFillTrigger:readUpdateStream(streamId, timestamp, connection)
	MilkFillTrigger:superClass().readUpdateStream(self, streamId, timestamp, connection);
	self:readAllStream(streamId, connection)
end;

function MilkFillTrigger:delete()
	unregisterObjectClassName(self);
	g_currentMission:removeOnCreateLoadedObjectToSave(self)
	if self.trigger ~= nil then
		self.trigger:delete();
	end;
	if not self.RunAsGE then MilkFillTrigger:superClass().delete(self) end;
end;

function MilkFillTrigger:update(dt) end;

function MilkFillTrigger:fill(art, tool, delta)
	local fillLvl = g_currentMission.husbandries["cow"].fillLevelMilk;
	self:setFillLevel(fillLvl)
	if not tool:allowFillType(self.trigger.fillType, false) then
        return 0.0;
    end
    local oldFillLevel = tool:getFillLevel(self.trigger.fillType);
    if fillLvl > 0 then
		delta = math.min(delta, self:getFillLevel());
		if delta > 0 then
			tool:setFillLevel(oldFillLevel + delta, self.trigger.fillType, true);
			delta = tool:getFillLevel(self.trigger.fillType) - oldFillLevel;
			self:setFillLevel(self:getFillLevel() - delta);
		end;
	else
		return 0.0;
	end;
return delta;
	
end;

function MilkFillTrigger:getIsActivatable(art, fillable)
	if not fillable:allowFillType(self.trigger.fillType, false) then
        return false;
	end;
	return true;
end;

function MilkFillTrigger:triggerCallback(self, triggerId, otherActorId, onEnter, onLeave, onStay, otherShapeId)
	if self.isEnabled and (onEnter or onLeave) then
        local fillable = Utils.getNoNil(g_currentMission.objectToTrailer[otherShapeId], g_currentMission.objectToTrailer[otherActorId]);
        if fillable ~= nil and fillable.addFillTrigger ~= nil and fillable.removeFillTrigger ~= nil and fillable ~= self.parent then
            if onEnter then
				 if fillable:allowFillType(self.fillType, false) then
                    fillable:addFillTrigger(self);
                    self.fillableObjects[fillable] = fillable;
                end
            else 
                fillable:removeFillTrigger(self);
                --g_currentMission:showMoneyChange(self.moneyChangeId, g_i18n:getText("finance_"..self.financeCategory));
                self.fillableObjects[fillable] = nil;
            end;
        end;
	end;
end

if MilkFillTrigger.RunAsGE then
	g_onCreateUtil.addOnCreateFunction("MilkFillTrigger", MilkFillTrigger.onCreate);
else
	registerPlaceableType("MilkFillTrigger", MilkFillTrigger);
end;

MilkFillTriggerEvent = {};
MilkFillTriggerEvent_mt = Class(MilkFillTriggerEvent, Event)
InitEventClass(MilkFillTriggerEvent, "MilkFillTriggerEvent")
function MilkFillTriggerEvent:emptyNew()
	local self = Event:new(MilkFillTriggerEvent_mt)
	return self
end;

function MilkFillTriggerEvent:new(fillLvl)
	local self = MilkFillTriggerEvent:emptyNew()
	--self.trigger = trigger
	self.fillLvlToChange = fillLvl;
	return self
end;

function MilkFillTriggerEvent:readStream(streamId,connection)
	--self.trigger = networkGetObject(streamReadInt32(streamId))
	self.fillLvlToChange = streamReadInt32(streamId)
	self:run(connection)
end;

function MilkFillTriggerEvent:writeStream(streamId,connection)
	--streamWriteInt32(streamId, networkGetObjectId(self.trigger))
	streamWriteInt32(streamId, self.fillLvlToChange)
end;

function MilkFillTriggerEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self,false,connection,self)
	end;
	if self then
		--self:setFillLevel(self.fillLvlToChange);
		g_currentMission.husbandries["cow"].fillLevelMilk = self.fillLvlToChange
	end;
end;
function MilkFillTriggerEvent.sendEvent(fillLvl, noEventSend)
	if (noEventSend == nil or noEventSend == false) then
		if g_server ~= nil then	
			g_server:broadcastEvent(MilkFillTriggerEvent:new(fillLvl), nil,nil,object);
		else
			g_client:getServerConnection():sendEvent(MilkFillTriggerEvent:new(fillLvl))
		end;
	end;
end;

