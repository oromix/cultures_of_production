-- by "Marhu" 
-- v 1.0
-- Date: 03.04.2013
-- Placeable  MilkTruckStartTrigger
-- Converted to FS17 06.11.2016 Blacksheep

StopMilkSale = {};
StopMilkSale_mt = Class(StopMilkSale, Placeable);
InitObjectClass(StopMilkSale, "StopMilkSale");

function StopMilkSale:new(isServer, isClient, customMt)
    local self = Placeable:new(isServer, isClient, StopMilkSale_mt);
    registerObjectClassName(self, "StopMilkSale");
    
    return self;
end;

function StopMilkSale:delete()
      if  g_currentMission.orgFSsellMilk then
        FSBaseMission.sellMilk = g_currentMission.orgFSsellMilk;
        g_currentMission.orgFSsellMilk = nil
    end
    unregisterObjectClassName(self);
    StopMilkSale:superClass().delete(self);
end;

function StopMilkSale:deleteFinal()
    StopMilkSale:superClass().deleteFinal(self);
end;

function StopMilkSale:load(xmlFilename, x,y,z, rx,ry,rz, moveMode, initRandom)
    if not StopMilkSale:superClass().load(self, xmlFilename, x,y,z, rx,ry,rz, moveMode, initRandom) then
        return false;
    end;
    return true;
end;

function StopMilkSale:update(dt)
    if not g_currentMission.orgFSsellMilk then
        g_currentMission.orgFSsellMilk = FSBaseMission.sellMilk;
        FSBaseMission.sellMilk = function(a,b,c)
            return a,b,c
        end
    end
end;

registerPlaceableType("StopMilkSale", StopMilkSale);