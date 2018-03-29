--
-- Filename: BuyableChickens.lua
-- Author: Ian898 / CBModding
-- Date: 31/10/2016
--

BuyableChickens = {};
BuyableChickens.modDirectory = g_currentModDirectory;

addModEventListener(BuyableChickens);

function BuyableChickens:update(dt)

	if not g_currentMission.husbandries.chicken.animalDesc.canBeBought then
		g_currentMission.husbandries.chicken.animalDesc.price = 70;
		g_currentMission.husbandries.chicken.animalDesc.dailyUpkeep = 1;
		g_currentMission.husbandries.chicken.animalDesc.canBeBought = true;
		g_currentMission.husbandries.chicken.animalDesc.hasStatistics = true;
		g_currentMission.husbandries.chicken.animalDesc.imageFilename = self.modDirectory .. "hud/store_chicken.png";
	end;

end;
function BuyableChickens:draw()end;
function BuyableChickens:keyEvent(unicode, sym, modifier, isDown)end;
function BuyableChickens:mouseEvent(posX, posY, isDown, isUp, button)end;
function BuyableChickens:deleteMap()end;