Ship = {}
local Ship_mt = Class(Ship)
Ship.onCreate = function (id)
	g_currentMission:addUpdateable(Ship:new(id))

	return 
end
Ship.new = function (self, id)
	local instance = {}

	setmetatable(instance, Ship_mt)

	instance.nurbsId = getChildAt(id, 0)
	instance.shipIds = {}

	table.insert(instance.shipIds, getChildAt(id, 1))

	instance.times = {}

	table.insert(instance.times, 0)

	local length = getSplineLength(instance.nurbsId)
	instance.timeScale = Utils.getNoNil(getUserAttribute(id, "speed"), 10)/3.6
	local numShips = Utils.getNoNil(getUserAttribute(id, "numShips"), 1)

	for i = 2, numShips, 1 do
		local shipId = clone(instance.shipIds[1], false, true)

		link(id, shipId)
		table.insert(instance.shipIds, shipId)
		table.insert(instance.times, numShips/1*(i - 1))
	end

	if length ~= 0 then
		instance.timeScale = instance.timeScale/length
	end

	instance.initCount = 0

	return instance
end
Ship.delete = function (self)
	return 
end
Ship.update = function (self, dt)
	if 0 < self.initCount then
		for i = 1, table.getn(self.shipIds), 1 do
			self.times[i] = self.times[i] - dt*0.001*self.timeScale
			local x, y, z = getSplinePosition(self.nurbsId, self.times[i])
			local rx, ry, rz = getSplineOrientation(self.nurbsId, self.times[i], 0, -1, 0)

			setTranslation(self.shipIds[i], x, y, z)
			setRotation(self.shipIds[i], rx, ry, rz)
		end
	else
		self.initCount = self.initCount + 1
	end

	return 
end

g_onCreateUtil.addOnCreateFunction("Ship", Ship.onCreate);
