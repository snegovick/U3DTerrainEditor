-- Terrain editing prototype
-- Water example.
-- This sample demonstrates:
--     - Creating a large plane to represent a water body for rendering
--     - Setting up a second camera to render reflections on the water surface

require "LuaScripts/Utilities/Sample"
require "LuaScripts/thirdpersoncamera"
require "LuaScripts/terraineditUIoriginal"
require "LuaScripts/ui"
require "LuaScripts/buildcomposite"
require "LuaScripts/filterui"
require "LuaScripts/saveloadui"
require "LuaScripts/terrainselectui"
require "LuaScripts/nodegraphui"
require 'LuaScripts/colorchooser'

require 'LuaScripts/Class'

function HtToRG(ht)
	local expht=math.floor(ht*255)
	local rm=ht*255-expht
	local r=expht/255
	local g=rm
	return r,g
end

function RGToHt(r,g)
	return r+g/256
end

function ColorToHeight(col)
	return (col.r+col.g/256)
end


TerrainState=TerrainEdit()

g_rnd=KISS()
g_rnd:setSeedTime()

local confirm_exit_shown = false

function Start()

    SampleStart()
    CreateScene()
    SubscribeToEvents()

end

function Stop()

end

function CreateScene()
    scene_ = Scene()
	CreateCursor()

	local buf=VectorBuffer()
	buf:WriteFloat(1.4)
	buf:WriteFloat(2.3)

	local ary=Variant()
	ary:Set(buf)

    -- Create octree, use default volume (-1000, -1000, -1000) to (1000, 1000, 1000)
    scene_:CreateComponent("Octree")

    -- Create a Zone component for ambient lighting & fog control
    local zoneNode = scene_:CreateChild("Zone")
    zone = zoneNode:CreateComponent("Zone")
    zone.boundingBox = BoundingBox(-1000.0, 1000.0)
    zone.ambientColor = Color(0.5, 0.5, 0.7)
    zone.fogColor = Color(0.7,0.8,0.9)
    zone.fogStart = 2000.0
    zone.fogEnd = 2075.0

    -- Create a directional light to the world. Enable cascaded shadows on it
    local lightNode = scene_:CreateChild("DirectionalLight")
    lightNode.direction = Vector3(0.8, -1.0, 1.0)
    mainlight = lightNode:CreateComponent("Light")
    mainlight.lightType = LIGHT_DIRECTIONAL
    mainlight.castShadows = true
    --light.shadowBias = BiasParameters(0.00025, 0.5)
    --light.shadowCascade = CascadeParameters(10.0, 50.0, 200.0, 0.0, 0.8)
    mainlight.specularIntensity = 0.125;
    mainlight.color = Color(1,1,1);
	--light.shadowBias = BiasParameters(0,0,0.015)

	lightNode = scene_:CreateChild("DirectionalLight")
    lightNode.direction = Vector3(-0.8, -1.0, -1.0)
    backlight = lightNode:CreateComponent("Light")
    backlight.lightType = LIGHT_DIRECTIONAL
    backlight.castShadows = false
    --light.shadowBias = BiasParameters(0.00025, 0.5)
    --light.shadowCascade = CascadeParameters(10.0, 50.0, 200.0, 0.0, 0.8)
    backlight.specularIntensity = 0.125;
    backlight.color = Color(0.25,0.25,0.25);


    --[[local skyNode = scene_:CreateChild("Sky")
    skyNode:SetScale(500.0) -- The scale actually does not matter
    local skybox = skyNode:CreateComponent("Skybox")
    skybox.model = cache:GetResource("Model", "Models/Box.mdl")
    skybox.material = cache:GetResource("Material", "Materials/Skybox.xml")]]
	 cameraNode=scene_:CreateChild("Camera")
	cam=cameraNode:CreateScriptObject("ThirdPersonCamera")
	cam.clipcamera=false
	cam.allowspin=true
	cam.allowzoom=true
	cam.allowpitch=true
	cam.maxfollow=900
	cam.follow=100
	cam.clipdist=2000
	--cam.orthographic=true
	cam:Finalize()

	-- Experimental grass technology
--[[
	gmat=cache:GetResource("Material", "Materials/White.xml")
	grass=scene_:CreateChild("Grass")
	g1=grass:CreateComponent("StaticModel")
	g1.model=cache:GetResource("Model", "Models/GrassMesh.mdl")
	g1.material=gmat
	g1.castShadows=true
	local covmap=cache:GetResource("Texture2D", "Textures/testfoliagecover.png")
	gmat:SetTexture(2, covmap)
	covmap:SetFilterMode(FILTER_NEAREST)
]]



	terrainui=scene_:CreateScriptObject("TerrainEditUI")

	terrainui:NewTerrain(1025,1025,2048,2048,true,false,true)
	terrainui:BuildUI()
	filterui=scene_:CreateScriptObject("FilterUI")
	saveloadui=scene_:CreateScriptObject("SaveLoadUI")
	saveloadui:Deactivate()

	--gmat:SetTexture(0, TerrainState:GetHeightTex())
	print("Height tex:")
	print(TerrainState:GetHeightTex())



	projecttozero=true
	--graphics.flushGPU=true

	function distortKernel(detail, frequency, seed)
		local k=CKernel()
		local eb=CExpressionBuilder(k)

		eb:setRandomSeed(seed)

		local gradientLayer="clamp(rotateDomain(scale(gradientBasis(3,rand), 2^n),rand01,rand01,0,rand01*3),-1,1)"
		local fBmcombine="prev+(1/(2^n))*layer"
		local fractal=fractalBuilder(eb,k,detail,gradientLayer,fBmcombine)
		local freq=k:constant(frequency)

		k:scaleDomain(fractal, freq)
		return k
	end
end

function CreateInstructions()

end

function SubscribeToEvents()
   SubscribeToEvent("Update", "HandleUpdate")

   SubscribeToEvent("KeyDown", "HandleKeyDown")

   SubscribeToEvent("KeyUp", "HandleKeyUp")
end

function HandleKeyUp(eventType, eventData)
   local key = eventData["Key"]:GetInt()
   -- Close console (if open) or exit when ESC is pressed
   if key == KEY_ESCAPE then
      if (confirm_exit_shown == false) then
         local panel=ui:LoadLayout(cache:GetResource("XMLFile", "UI/MessageBox.xml"))
         panel:GetChild("TitleText", true):SetText("Confirm exit")
         panel:GetChild("MessageText", true):SetText("All unsaved progress will be lost")
         panel:GetChild("CancelButton", true):SetVisible(true)
         SubscribeToEvent(panel:GetChild("OkButton", true), "Released", function (e) engine:Exit() end)
         SubscribeToEvent(panel:GetChild("CancelButton", true), "Released", function (e) confirm_exit_shown=false; ui.root:RemoveChild(panel) end)
         SubscribeToEvent(panel:GetChild("CloseButton", true), "Released", function (e) confirm_exit_shown=false; ui.root:RemoveChild(panel) end)
         ui.root:AddChild(panel)
         confirm_exit_shown = true;
      end
   end
end

function HandleKeyDown(eventType, eventData)
   local key = eventData["Key"]:GetInt()
end

function HandleUpdate(eventType, eventData)
    -- Take the frame time step, which is stored as a float
    local timeStep = eventData["TimeStep"]:GetFloat()


	if input:GetKeyPress(KEY_PRINTSCREEN) then
		local img=Image(context)
		graphics:TakeScreenShot(img)
		local t=os.date("*t")
		local filename="screen-"..tostring(t.year).."-"..tostring(t.month).."-"..tostring(t.day).."-"..tostring(t.hour).."-"..tostring(t.min).."-"..tostring(t.sec)..".png"
		img:SavePNG(filename)
	end

	-- Experimental grass technology
--[[
	local spacing=TerrainState:GetTerrainSpacing()
	local campos=cameraNode:GetPosition()
	local gpos=Vector3(campos.x, campos.y, campos.z)
	gpos.x=math.floor(campos.x / spacing.x) * spacing.x
	gpos.z=math.floor(campos.z / spacing.z) * spacing.z
	gpos.y=-0.01
	grass:SetPosition(gpos)

	local buf=VectorBuffer()
	local ary=Variant()

	buf:WriteFloat(TerrainState:GetTerrainWidth())
	buf:WriteFloat(TerrainState:GetTerrainWidth())
	buf:WriteFloat(spacing.x)
	buf:WriteFloat(spacing.y)
	ary:Set(buf)
	gmat:SetShaderParameter("HeightData", ary)
	gmat:SetTexture(1, TerrainState:GetHeightTex())
]]
end
