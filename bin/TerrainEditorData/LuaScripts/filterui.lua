-- Filter UI

function GetOptions(ops)
	local o={}
	
	local j
	for _,j in ipairs(ops) do
		o[j.name]=j.value
		print(j.name..": "..tostring(j.value))
	end
	
	return o
end

FilterUI=ScriptObject()

function FilterUI:Start()
	--self:SubscribeToEvent("Pressed", "FilterUI:HandleButtonPress")
	--self:SubscribeToEvent("ItemSelected", "FilterUI:HandleItemSelected")
	

	self.filterui=ui:LoadLayout(cache:GetResource("XMLFile", "UI/TerrainEditFilters.xml"))
	self.filterlist=self.filterui:GetChild("FilterList", true)
	self.filteroptions=self.filterui:GetChild("FilterOptions", true)
	
	local content=Window:new(context)
	--content.style=cache:GetResource("XMLFile", "UI/DefaultStyle.xml")
	self.filteroptions.contentElement=content
	--self.filterui.style=cache:GetResource("XMLFile", "UI/DefaultStyle.xml")
	ui.root:AddChild(self.filterui)
	self.filterui.visible=false
	
	self:SubscribeToEvent(self.filterui:GetChild("FilterButton",true), "Pressed", "FilterUI:HandleButtonPress")
	self:SubscribeToEvent(self.filterui:GetChild("ExecuteButton",true), "Pressed", "FilterUI:HandleButtonPress")
	self:SubscribeToEvent(self.filterui:GetChild("CloseButton",true), "Pressed", "FilterUI:HandleButtonPress")
	self:SubscribeToEvent(self.filterui:GetChild("RescanFilters",true), "Pressed", "FilterUI:HandleButtonPress")
	
	self:SubscribeToEvent(self.filterui:GetChild("List",true), "ItemSelected", "FilterUI:HandleItemSelected")
	
	self:PopulateFilterList()
end

function FilterUI:Activate()
	self.filterui.visible=true
	self:PopulateFilterList()
end

function FilterUI:Deactivate()
	self.filterui.visible=false
end

function FilterUI:HandleButtonPress(eventType, eventData)
	local which=eventData["Element"]:GetPtr("UIElement")
	local name=which:GetName()
	if name=="FilterButton" then
		if self.filterui.visible==true then self.filterui.visible=false
		else
			self:PopulateFilterList()
			self.filterui.visible=true
		end
	elseif name=="CloseButton" then
		self.filterui.visible=false
	elseif name=="ExecuteButton" then
		if self.selectedfilter then
			-- Grab options
			if self.selectedfilter.options ~= nil then
				local c
				for _,c in ipairs(self.selectedfilter.options) do
					local element=self.filteroptions:GetChild(c.name, true)
					if element then
						if c.type=="value" then c.value=tonumber(element.textElement.text)
						elseif c.type=="flag" then c.value=element.checked
						elseif c.type=="list" then c.value=c.list[element.selection+1]
						elseif c.type=="string" then c.value=element.textElement.text
						elseif c.type=="spline" then
							local splines=scene_:GetScriptObject("SplineUI")
							local sel=element.selection
							local item=element:GetItem(sel)
							if item.name=="None" then
								c.value=nil
							else
								c.value=splines:FindSplineByName(item.name)
							end
						end
					end
				end
			end
			self.selectedfilter:execute()
			collectgarbage()
			print("Usedmem: "..collectgarbage("count"))
		end
	elseif name=="RescanFilters" then
		self:PopulateFilterList()
	end
	
end

function FilterUI:HandleItemSelected(eventType, eventData)
	local which=eventData["Element"]:GetPtr("ListView")
	local selected=eventData["Selection"]:GetInt()
	local entry=which:GetItem(selected)
	if entry==nil then return end
	local name=entry:GetName()
	
	if self.filters[name]==nil then return end
	
	self:BuildFilterOptions(self.filters[name])
	self.selectedfilter=self.filters[name]
end

function FilterUI:BuildFilterOptions(filter)
	if filter==nil then return end
	local options=self.filteroptions:GetChild("OptionsWindow", true)
	local name=self.filteroptions:GetChild("FilterName", true)
	local desc=self.filteroptions:GetChild("FilterDescription", true)
	name.text=filter.name
	desc.text=filter.description
	
	options:RemoveAllChildren()
	
	if filter.options==nil then print("No options") return end
	local c
	local maxx,maxy=0,0
	for _,c in ipairs(filter.options) do
		--local window=Window:new(context)
		local window=UIElement:new(context)
		window.defaultStyle=uiStyle
		--window.style=uiStyle
		window.layoutMode=LM_HORIZONTAL
		window.layoutBorder=IntRect(5,5,5,5)
		local title=Text:new(context)
		title:SetText(c.name)
		title.defaultStyle=uiStyle
		title:SetStyleAuto()
		--title.style=uiStyle
		window:AddChild(title)
		
		if c.type=="flag" then
			local check=window:CreateChild("CheckBox")
			check:SetName(c.name)
			check:SetStyleAuto()
			if c.value==true then
				check:SetChecked(true)
				print("Checked")
			else
				check:SetChecked(false)
				print("unChecked")
			end
			window.size=IntVector2(title.size.x+check.size.x, 15)
		elseif c.type=="value" then
			local edit=window:CreateChild("LineEdit")--LineEdit:new(context)
			edit:SetName(c.name)
			edit:SetMinHeight(24)
			edit:SetStyleAuto()
			edit:SetText(tostring(c.value))
			edit:SetCursorPosition(0)
			window.size=IntVector2(title.size.x+edit.size.x, 15)
		elseif c.type=="string" then
			local edit=window:CreateChild("LineEdit")--LineEdit:new(context)
			edit:SetName(c.name)
			edit:SetStyleAuto()
			edit:SetMinHeight(24)
			edit:SetCursorPosition(0)
			edit:SetText(tostring(c.value))
			window.size=IntVector2(title.size.x+edit.size.x, 15)
		elseif c.type=="list" then
			local dlist=window:CreateChild("DropDownList")--DropDownList:new(context)
			dlist:SetStyleAuto()
			dlist:SetAlignment(HA_LEFT, VA_CENTER)
			dlist:SetName(c.name)
			dlist.resizePopup=true
			
			local i
			for _,i in ipairs(c.list) do
				local t=Text:new(context)
				t:SetStyleAuto()
				t.name=i
				t.text=i
				dlist:AddItem(t)
			end
			
			dlist.selection=0
			c.value=c.list[1]
			window.size=IntVector2(title.size.x+dlist.size.x, 25)
		elseif c.type=="spline" then
			local splines=scene_:GetScriptObject("SplineUI")
			if splines then
				local dlist=window:CreateChild("DropDownList")
				dlist:SetStyleAuto()
				dlist:SetAlignment(HA_LEFT, VA_CENTER)
				dlist.name=c.name
				dlist.resizePopup=true
				
				local i
				if #splines.groups==0 then
					local t=Text:new(context)
					t:SetStyleAuto()
					t.text="None"
					t.name="None"
					dlist:AddItem(t)
				else
					for _,i in ipairs(splines.groups) do
						local t=Text:new(context)
						t:SetStyleAuto()
						t.text=i.name
						t.color=i.color
						t.name=i.name
						dlist:AddItem(t)
					end
				end
				dlist.selection=0
				window.size=IntVector2(title.size.x+dlist.size.x, 25)
				c.value=dlist.selection
			end
		end
		window.maxSize=IntVector2(10000,25)
		options:AddChild(window)
	end
	
	--options.size.x=maxx
	self.filteroptions.visible=true
end

function FilterUI:PopulateFilterList()
	self.filters={}
	self.selectedfilter=nil
	local options=self.filteroptions:GetChild("OptionsWindow", true)
	options:RemoveAllChildren()
	
	local list=self.filterlist:GetChild("List", true)
	if list==nil then return end
	list:RemoveAllItems()

  print("CWD: "..fileSystem:GetCurrentDir())
  -- This code segfaults inside of Urho3D for some reason
  --print("PD: "..fileSystem:GetProgramDir())
  -- print("Scan for filters")
	-- local filters=fileSystem:ScanDir(fileSystem:GetCurrentDir().."TerrainEditorData/LuaScripts/TerrainEditFilters", "*.lua", SCAN_FILES, false)
  -- print("Filters: "..filters)
	-- if filters==nil then print("Uh oh")
	-- else
  --    print("Loading filters")
	-- 	local c
	-- 	for _,c in ipairs(filters) do
  --      print("Do file ".."TerrainEditorData/LuaScripts/TerrainEditFilters/"..c)
	-- 		local filter=dofile("TerrainEditorData/LuaScripts/TerrainEditFilters/"..c)
	-- 		print(c)
	-- 		self.filters[filter.name]=filter
	-- 		local uielement=Text:new(context)
	-- 		uielement.style="EditorEnumAttributeText"
	-- 		uielement.text=filter.name
	-- 		uielement.name=filter.name
	-- 		list:AddItem(uielement)
	-- 	end
	-- end
	local filter_names = {'buildroad.lua', 'cavity.lua', 'cliffify.lua', 'erosion.lua', 'fillbasins.lua', 'fillbasinstomask.lua', 'fillbasinswater.lua', 'flow.lua', 'inciseflow.lua', 'riverbuilder.lua', 'roadbuilder2.lua'}
	for i, name in ipairs(filter_names) do
		print("Loading "..name)
		local path = fileSystem:GetCurrentDir().."TerrainEditorData/LuaScripts/TerrainEditFilters/"..name
		local filter=dofile(path)
		self.filters[filter.name]=filter
		local uielement=Text:new(context)
		uielement.style="EditorEnumAttributeText"
		uielement.text=filter.name
		uielement.name=filter.name
		list:AddItem(uielement)
	end
end
