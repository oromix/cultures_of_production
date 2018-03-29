--
-- FillablePalletFix
--
-- @author:    	Xentro (Marcus@Xentro.se)
-- @website:	www.Xentro.se
-- @history:	v1.0 - 2016-10-29 - Initial implementation
-- 

if not Utils.FillablePalletFix20161029 then
	Utils.FillablePalletFix20161029 = true;

	local oldFunc = FillablePallet.createNode;
	FillablePallet.createNode = function(self, i3dFilename, xmlFilename)
		local xmlFile;
		
		if xmlFilename ~= nil then
			self.xmlFilename = xmlFilename;
			xmlFile = loadXMLFile("tempObjectXML", self.xmlFilename);
			i3dFilename = getXMLString(xmlFile, "object.filename");
			
			-- we use the xmlFile instead as that have the correct path.
			self.customEnvironment, self.baseDirectory = Utils.getModNameAndBaseDirectory(xmlFilename);
			
			if self.customEnvironment ~= nil then -- we are an mod
				i3dFilename = Utils.getFilename(i3dFilename, self.baseDirectory); -- fix the path
			end;
		else
			self.customEnvironment, self.baseDirectory = Utils.getModNameAndBaseDirectory(i3dFilename);
		end;
		
		self.i3dFilename = i3dFilename;
		local fillablePalletRoot = Utils.loadSharedI3DFile(i3dFilename);
		local FillablePalletId = getChildAt(fillablePalletRoot, 0);
		
		link(getRootNode(), FillablePalletId);
		delete(fillablePalletRoot);
		self:setNodeId(FillablePalletId);
		
		if xmlFile ~= nil then
			FillablePallet.loadObjectXML(self, xmlFile)
			delete(xmlFile);
		end;
	end;
	
	local oldFunc = FillablePallet.loadFromAttributesAndNodes;
	FillablePallet.loadFromAttributesAndNodes = function(self, xmlFile, key, resetVehicles)
		local x,y,z = Utils.getVectorFromString(getXMLString(xmlFile, key.."#position"));
		local xRot,yRot,zRot = Utils.getVectorFromString(getXMLString(xmlFile, key.."#rotation"));
		if x == nil or y == nil or z == nil or xRot == nil or yRot == nil or zRot == nil then
			return false;
		end;
		
		local filename;
		local objectXMLFile;
		self.xmlFilename = getXMLString(xmlFile, key.."#filename");
		if self.xmlFilename ~= nil then
			self.xmlFilename = Utils.convertFromNetworkFilename(self.xmlFilename);
			objectXMLFile = loadXMLFile("tempObjectXML", self.xmlFilename);
			filename = getXMLString(objectXMLFile, "object.filename");
			-- we use the xmlFile instead as that have the correct path.
			local customEnvironment, baseDirectory = Utils.getModNameAndBaseDirectory(self.xmlFilename);
			
			if customEnvironment ~= nil then -- we are an mod
				filename = Utils.getFilename(filename, baseDirectory); -- fix the path
			end;
		else
			filename = getXMLString(xmlFile, key.."#i3dFilename");
		end;
		
		if filename == nil then
			return false;
		end;
		
		filename = Utils.convertFromNetworkFilename(filename);
		local rootNode = Utils.loadSharedI3DFile(filename);
		if rootNode == 0 then
			return false;
		end;
		
		local ret = false;
		local node = getChildAt(rootNode, 0);
		
		if node ~= nil and node ~= 0 then
			setTranslation(node, x,y,z);
			setRotation(node, xRot,yRot,zRot);
			link(getRootNode(), node);
			ret = true;
		end;
		
		delete(rootNode);
		
		if not ret then
			return false;
		end;
		
		self:loadFromMemory(node, filename);
		
		local fillLevel = getXMLFloat(xmlFile, key.."#fillLevel");
		if fillLevel ~= nil then
			self.fillLevel = -1;
			self:setFillLevel(fillLevel, false);
		end
		
		if objectXMLFile ~= nil then
			FillablePallet.loadObjectXML(self, objectXMLFile)
		end;
		
		return true;
	end;
end;