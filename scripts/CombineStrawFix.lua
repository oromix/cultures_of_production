local metadata = {
"## Interface: FS17 1.3.0.0 1.3RC4",
"## Title: CombineStrawFix",
"## Notes: Fix Strohschwad bei zusatz Früchten",
"## Author: Marhu",
"## Version: 1.0.0-3",
"## Date: 20.11.2016",
"## Web: http://marhu.net"
}

local g = getfenv(0)
if g.org_Combine_updateTick == nil then
	g.org_Combine_updateTick = Combine.updateTick
	Combine.updateTick = function(self,dt)
		if self.isServer then
			self.lastArea = self.lastCuttersArea;
			self.lastAreaZeroTime = self.lastAreaZeroTime + dt;
			if self.lastArea > 0 then
				self.lastAreaZeroTime = 0;
				self.lastAreaNonZeroTime = g_currentMission.time;
			end
			self.lastInputFruitType = self.lastCuttersInputFruitType;
			self.lastCuttersArea = 0;
			self.lastCuttersInputFruitType = FruitUtil.FRUITTYPE_UNKNOWN;
			self.lastCuttersFruitType = FruitUtil.FRUITTYPE_UNKNOWN;
			if self.lastInputFruitType ~= FruitUtil.FRUITTYPE_UNKNOWN then
				self.lastValidInputFruitType = self.lastInputFruitType;
			end
			if self:getIsActive() then
			   self.strawBufferCheckTimer = (#self.strawBuffer+2)*self.strawBufferDuration
			   if self.lastAreaZeroTime > 500 then
					if self.combineFillDisableTime == nil then
						self.combineFillDisableTime = g_currentMission.time + self.combineFillToggleTime;
					end
				end
				if self.combineFillEnableTime ~= nil and self.combineFillEnableTime <= g_currentMission.time then
					self:setCombineIsFilling(true, false, false);
					self.combineFillEnableTime = nil;
				end
				if self.combineFillDisableTime ~= nil and self.combineFillDisableTime <= g_currentMission.time then
					self:setCombineIsFilling(false, false, false);
					self.combineFillDisableTime = nil;
				end
				if self:getIsTurnedOn() then
					g_currentMission.missionStats:updateStats("threshedTime", dt/(1000*60));
					g_currentMission.missionStats:updateStats("workedTime", dt/(1000*60));
				end
			else
				if self.strawBufferCheckTimer >= 0 then
					self.strawBufferCheckTimer = self.strawBufferCheckTimer - dt
				end
			end
			if self.strawBufferCheckTimer >= 0 then
				self.strawBufferFillIndexTimer = self.strawBufferFillIndexTimer - dt
				if self.strawBufferFillIndexTimer < 0 then
					self.strawBufferFillIndex = self.strawBufferFillIndex + 1
					if self.strawBufferFillIndex > #self.strawBuffer then
						self.strawBufferFillIndex = 1
					end
					self.strawBufferFillIndexTimer = self.strawBufferDuration
					self.strawBufferDropIndex = self.strawBufferDropIndex + 1
					if self.strawBufferDropIndex > #self.strawBuffer then
						self.strawBufferDropIndex = 1
					end
					self.strawBufferDropValue = self.strawBuffer[self.strawBufferDropIndex]
				end
				local isStrawEffectEnabled = false
				local isChopperEffectEnabled = false
				if self:getUnitLastValidFillType(self.overloading.fillUnitIndex) ~= FillUtil.FILLTYPE_UNKNOWN then
					local litersPerFrame = math.min(self.strawBufferDropValue * (dt/self.strawBufferDuration), self.strawBuffer[self.strawBufferDropIndex])
					if self.isStrawEnabled then
						local literToDrop = litersPerFrame + self.strawToDrop
						local fruitIndex = FruitUtil.fillTypeToFruitType[self:getUnitLastValidFillType(self.overloading.fillUnitIndex)]
						local fruitDesc = FruitUtil.fruitIndexToDesc[fruitIndex];
						if fruitDesc ~= nil and fruitDesc.windrowLiterPerSqm ~= nil then
							local windrowFillType = FruitUtil.fruitTypeToWindrowFillType[fruitDesc.index];
							if literToDrop > 0 and windrowFillType ~= nil then
								isStrawEffectEnabled = litersPerFrame > 0
								local typedWorkAreas = self:getTypedWorkAreas(WorkArea.AREATYPE_COMBINE);
								local value = literToDrop/table.getn(typedWorkAreas);
								for _, workArea in pairs(typedWorkAreas) do
									local sx,sy,sz = getWorldTranslation(workArea.start);
									local ex,ey,ez = getWorldTranslation(workArea.width);
									local dropped, lineOffset = TipUtil.tipToGroundAroundLine(self, value, windrowFillType, sx,sy,sz, ex,ey,ez, 0, nil, self.combineLineOffset, false, nil, false);
									self.combineLineOffset = lineOffset;
									self.strawToDrop = value-dropped
								end
							end
						end
					else
						isChopperEffectEnabled = litersPerFrame > 0
					end
					-- remove straw from buffer if chopper is active to allow instant switch to straw
					self.strawBuffer[self.strawBufferDropIndex] = self.strawBuffer[self.strawBufferDropIndex] - litersPerFrame
				end
				local currentDropIndex = self.strawBufferDropIndex
				for i=1, 2 do
					currentDropIndex = currentDropIndex + 1
					if currentDropIndex > #self.strawBuffer then
						currentDropIndex = 1
					end
					if self.strawBuffer[currentDropIndex] > 0 then
						if self.chopperPSenabled and not self.isStrawEnabled and not isChopperEffectEnabled then
							isChopperEffectEnabled = true
						end
						if self.strawPSenabled and self.isStrawEnabled and not isStrawEffectEnabled then
							isStrawEffectEnabled = true
						end
					end
				end
				self:setChopperPSEnabled(isChopperEffectEnabled, false, false);
				self:setStrawPSEnabled(isStrawEffectEnabled, false, false);
			end
			if self:getUnitCapacity(self.overloading.fillUnitIndex) <= 0 then
				local fillLevel = self:getUnitFillLevel(self.overloading.fillUnitIndex);
				self.lastLostFillLevel = fillLevel;
				if fillLevel > 0 then
					self:setUnitFillLevel(self.overloading.fillUnitIndex, 0, self:getUnitFillType(self.overloading.fillUnitIndex), false);
				end
			end
			if  self.combineIsFilling ~= self.sentCombineIsFilling or
				self.chopperPSenabled ~= self.sentChopperPSenabled or
				self.strawPSenabled ~= self.sentStrawPSenabled
			then
				self:raiseDirtyFlags(self.combineDirtyFlag);
				self.sentCombineIsFilling = self.combineIsFilling;
				self.sentChopperPSenabled = self.chopperPSenabled;
				self.sentStrawPSenabled = self.strawPSenabled;
			end
		end
	end
end