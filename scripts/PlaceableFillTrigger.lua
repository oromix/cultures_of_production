-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.

PlaceableFillTrigger = {};

PlaceableFillTrigger_mt = Class(PlaceableFillTrigger, Placeable);

InitObjectClass(PlaceableFillTrigger, "PlaceableFillTrigger");

function PlaceableFillTrigger:new(isServer, isClient, customMt)
    local mt = customMt;
    if mt == nil then
        mt = PlaceableFillTrigger_mt;
    end;

    local self = Placeable:new(isServer, isClient, mt);

    registerObjectClassName(self, "PlaceableFillTrigger");

    return self;
end;

function PlaceableFillTrigger:delete()
    unregisterObjectClassName(self);
    if self.trigger ~= nil then
        self.trigger:delete();
    end;

    PlaceableFillTrigger:superClass().delete(self);
end;

function PlaceableFillTrigger:load(xmlFilename, x,y,z, rx,ry,rz, initRandom)
    if not PlaceableFillTrigger:superClass().load(self, xmlFilename, x,y,z, rx,ry,rz, initRandom) then
        return false;
    end;

    local xmlFile = loadXMLFile("TempXML", xmlFilename);
    if xmlFile == 0 then
        return false;
    end;

    self.triggerId = Utils.indexToObject(self.nodeId, getXMLString(xmlFile, "placeable.fillTrigger#index"))

    local fillType = nil;
    local fillTypeStr = getXMLString(xmlFile, "placeable.fillTrigger#fillType");
    if fillTypeStr ~= nil then
        local desc = FillUtil.fillTypeNameToDesc[fillTypeStr];
        if desc ~= nil then
            fillType = desc.index;
        end;
    end;

    self.trigger = FillTrigger:new();
    if self.trigger:load(self.triggerId, fillType) then
        g_currentMission:addNonUpdateable(self.trigger);
    else
        self.trigger:delete();
    end

    return true;
end;

registerPlaceableType("placeableFillTrigger", PlaceableFillTrigger);