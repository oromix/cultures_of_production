-- by "Marhu" 
-- v 1.0
-- Date: 09.08.2013
-- "MapAnimations Startet Animationen Von Objekten"
   
MapAnimations = {};

local MapAnimations_mt = Class(MapAnimations, Object);

InitObjectClass(MapAnimations, "MapAnimations");

function MapAnimations.onCreate(id)
	local Animi = MapAnimations:new(g_server ~= nil, g_client ~= nil);
    local index = g_currentMission:addOnCreateLoadedObject(Animi);
    Animi:load(id);
    Animi:register(true);
	
	--print("created MapAnimations, id: ", id);
end;

function MapAnimations:new(isServer, isClient)
	local self = Object:new(isServer, isClient, MapAnimations_mt);
	return self;
end;

function MapAnimations:load(nodeId)
			
	local objekt = getChildAt(nodeId, 2);
	local location = getChildAt(nodeId, 3);
	local pos = {getWorldTranslation(location)}
	local rot = {getRotation(location)}

	setTranslation(objekt,unpack(pos))
	setRotation(objekt,unpack(rot))
	
	self.Animi = getAnimCharacterSet(getChildAt(nodeId,1));
	self.Clip = getAnimClipIndex(self.Animi,"clip1Source")
	assignAnimTrackClip(self.Animi, 0, self.Clip);
	setAnimTrackLoopState(self.Animi, 0, false);
	setAnimTrackSpeedScale(self.Animi, 0, 1);
	enableAnimTrack(self.Animi, 0);
	
	self.RNDTime = Utils.getNoNil(getUserAttribute(nodeId, "RNDTime"), 0);
	self.time = math.random(0, self.RNDTime)
	
end;
  
function MapAnimations:delete()
end;
  
function MapAnimations:readStream(streamId, connection)
	--[[MapAnimations:superClass().readStream(self, streamId);
	if connection:getIsServer() then
	end;]]
end;

function MapAnimations:writeStream(streamId, connection)
	--[[MapAnimations:superClass().writeStream(self, streamId);
	if not connection:getIsServer() then
	end;]]
end;

function MapAnimations:readUpdateStream(streamId, timestamp, connection)
	--[[MapAnimations:superClass().readUpdateStream(self, streamId, timestamp, connection);
	if connection:getIsServer() then
	end;]]
end;
  
function MapAnimations:writeUpdateStream(streamId, connection, dirtyMask)
	--[[MapAnimations:superClass().writeUpdateStream(self, streamId, connection, dirtyMask);
	if not connection:getIsServer() then
    end;]]
end;
 
function MapAnimations:update(dt)
	self.time = self.time - dt
	if self.time <= 0 then
		if not isAnimTrackEnabled(self.Animi, 0) then
			enableAnimTrack(self.Animi, 0);
		end
		if getAnimTrackTime(self.Animi, 0) > getAnimClipDuration(self.Animi, 0) then
			setAnimTrackTime(self.Animi, 0, 0, false);
			self.time = math.random(0, self.RNDTime)
		end;
	elseif isAnimTrackEnabled(self.Animi, 0) and getAnimTrackTime(self.Animi, 0) > getAnimClipDuration(self.Animi, 0) then
		disableAnimTrack(self.Animi, 0);
	end;
end;

function MapAnimations:updateTick(dt)
end;

g_onCreateUtil.addOnCreateFunction("MapAnimations", MapAnimations.onCreate);
 
 