
-- 
-- Digital Storage Amount Mover
-- supports remaining capacity display like fruitmaster
-- 
-- Blacky_BPG
-- Version 1.2.1.0   08.11.2016   initial Version for FS17
-- 

DigitalAmountMover = {};
DigitalAmountMover.version = "1.2.1.0  -  08.11.2016";
local DigitalAmountMover_mt = Class(DigitalAmountMover);
function DigitalAmountMover.onCreate(id)
	g_currentMission:addUpdateable(DigitalAmountMover:new(id));
end;
function DigitalAmountMover:new(id)
	local instance = {};
	setmetatable(instance, DigitalAmountMover_mt);

	instance.id = id;
	instance.nodeId = id;
	local fillType = getUserAttribute(id, "fillType");
	if fillType ~= nil then
		instance.fillType = FillUtil.fillTypeNameToInt[fillType];
	end;
	if instance.fillType == nil then
		instance.fillType = Fillable.FILLTYPE_LIQUIDMANURE;
	end;
	instance.storageSaveId = Utils.getNoNil(getUserAttribute(id, "storageSaveId"),"FARM_SILO");
	instance.defaultOff = Utils.getNoNil(getUserAttribute(id, "defaultOff"),"11");

	local digitStorageId = getUserAttribute(instance.id, "digitStorageId");
	if digitStorageId ~= nil then
		local digitGroup = instance.id;
		if digitStorageId ~= "-1" and digitStorageId ~= -1 then
			digitGroup = Utils.indexToObject(id,digitStorageId);
		end;
		local num = getNumOfChildren(digitGroup);
		instance.digitStorage = {};
		for i=1, num do
			local child = getChildAt(digitGroup, i-1);
			if child ~= nil and child ~= 0 then
				instance.digitStorage[i] = {};
				instance.digitStorage[i].id = child;
				local numDot = getNumOfChildren(child);
				if numDot ~= 0 then
					instance.digitStorage[i].dot = getChildAt(child, 0);
				end;
			end;
		end;
	end;

	instance.showFreeSpace = Utils.getNoNil(getUserAttribute(instance.id, "showFreeSpace"),false);
	instance.maxSpace = 0;
	local digitSpaceId = getUserAttribute(instance.id, "digitSpaceId");
	if digitSpaceId ~= nil then
		local digitGroup2 = instance.id;
		if digitSpaceId ~= "-1" and digitSpaceId ~= -1 then
			digitGroup2 = Utils.indexToObject(id,digitSpaceId);
		end;
		local num2 = getNumOfChildren(digitGroup2);
		instance.digitSpace = {};
		for i=1, num2 do
			local child2 = getChildAt(digitGroup2, i-1)
			if child2 ~= nil and child2 ~= 0 then
				instance.digitSpace[i] = {};
				instance.digitSpace[i].id = child2;
				local numDot2 = getNumOfChildren(child2);
				if numDot2 ~= 0 then
					instance.digitSpace[i].dot = getChildAt(child2, 0);
				end;
			end
		end
	end;

	instance.firstStart = true;

	instance.oldAmount = -1;
	if instance.storageSaveId == nil or instance.fillType == nil or instance.digitStorage == nil or (instance.digitStorage ~= nil and #instance.digitStorage == 0) then
		instance.isEnabled = false;
	else
		instance.isEnabled = true;
	end;
	return instance;
end;
function DigitalAmountMover:update(dt)
	if self.storage ~= nil then
		local amount = self.storage.fillLevels[self.fillType];
		if amount ~= self.oldAmount then
			self:setDisplay(amount);
		end;
	end;
	if self.firstStart then
		self.firstStart = false;
		for k,v in pairs(g_currentMission.onCreateLoadedObjectsToSave) do
			if k ~= nil and v ~= nil and k == self.storageSaveId then
				if v.fillTypes ~= nil and v.fillTypes[self.fillType] ~= nil then
					self.maxSpace = v.capacity;
					if v.fillLevels ~= nil and v.fillLevels[self.fillType] ~= nil then
						self.storage = v;
					end;
				end;
			end;
		end;
	end;
end;
function DigitalAmountMover:delete()
end;

function DigitalAmountMover:setDisplay(amount)
	if self.maxSpace <= 0 then
		self.showFreeSpace = false;
	end;
	local left = self.maxSpace;
	if self.showFreeSpace then
		left = left - amount;
	end;
	if left < 0 then
		left = 0;
	end;
	self.oldAmount = amount;
	for i=1, table.getn(self.digitStorage) do
		local number = math.floor(amount - (math.floor(amount / 10) * 10));
		amount = math.floor(amount / 10);
		if number <= 0 and amount <= 0 then
			setShaderParameter(self.digitStorage[i].id, "number", tonumber(self.defaultOff), 0, 0, 0, false);
			if self.digitStorage[i].dot ~= nil then
				setVisibility(self.digitStorage[i].dot,false);
			end;
		else
			setShaderParameter(self.digitStorage[i].id, "number", number, 0, 0, 0, false);
			if self.digitStorage[i].dot ~= nil then
				setVisibility(self.digitStorage[i].dot,true);
			end;
		end;
	end;

	if self.showFreeSpace then
		for i=1, table.getn(self.digitSpace) do
			local number = math.floor(left - (math.floor(left / 10) * 10));
			left = math.floor(left / 10);
			if number <= 0 and left <= 0 then
				setShaderParameter(self.digitSpace[i].id, "number", tonumber(self.defaultOff), 0, 0, 0, false);
				if self.digitSpace[i].dot ~= nil then
					setVisibility(self.digitSpace[i].dot,false);
				end;
			else
				setShaderParameter(self.digitSpace[i].id, "number", number, 0, 0, 0, false);
				if self.digitSpace[i].dot ~= nil then
					setVisibility(self.digitSpace[i].dot,true);
				end;
			end;
		end;
	else
		if self.digits2 ~= nil then
			setVisibility(self.digits2[7],false);
			setVisibility(self.digits2[6],false);
			setVisibility(self.digits2[5],false);
			setVisibility(self.digits2[4],false);
			setVisibility(self.digits2[3],false);
			setVisibility(self.digits2[2],false);
			setVisibility(self.digits2[1],false);
		end;
	end;
end;

g_onCreateUtil.addOnCreateFunction("DigitalAmountMoverOnCreate", DigitalAmountMover.onCreate);

print(" ++ loading Digital Storage Amount Mover V "..tostring(DigitalAmountMover.version).." (by Blacky_BPG)");
