-- ##############################################
-- #	Map Rotate Object						#
-- #	version: 1.0							#
-- #	date: 08.09.2013						#
-- #	author: [FSM]Chefkoch					#
-- #											#
-- # 	Keine Veränderung ohne					# 
-- # 	meine Erlaubnis!						#
-- # 	No modification without					# 
-- # 	my permission!							#
-- #											#
-- #	THX 4 help 2							#
-- #	Sven777b								#
-- #											#
-- #	History:								#
-- #	v1.0 = Projekt started					#
-- ############################################## 

mapRotateObject = {};

local mapRotateObject_mt = Class(mapRotateObject);

function mapRotateObject.onCreate(id)
  g_currentMission:addUpdateable(mapRotateObject:new(id));
end;

function mapRotateObject:new(name)
  local instance = {};
  setmetatable(instance, mapRotateObject_mt);
  instance.objectId = getChildAt(name, 0);
  instance.rounds = Utils.getNoNil(getUserAttribute(name,"Value"),10);
  return instance;
end;

function mapRotateObject:delete()
end;

function mapRotateObject:update(dt)
  local objectRot = math.rad(self.rounds/360) * dt;
  rotate(self.objectId, 0,objectRot,0);
end;

g_onCreateUtil.addOnCreateFunction("mapRotateObjectOnCreate", mapRotateObject.onCreate);