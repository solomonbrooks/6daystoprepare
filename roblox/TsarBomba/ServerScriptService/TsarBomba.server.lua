--[[
	TSAR BOMBA (AN602 / RDS-220) — server script
	Put this Script in ServerScriptService.
	Put TsarBombaClient (LocalScript) in StarterPlayer > StarterPlayerScripts.

	What it does
	  * Gives CONFIG.OwnerName a "Tsar Bomba" tool every time they spawn.
	  * Equipping the tool instantly un-equips it and releases the bomb from
	    altitude over a point in front of the player.
	  * The bomb free-falls, deploys its retard parachute (like the real 1961
	    drop), descends with sway and a live telemetry billboard, then air-bursts.
	  * The server handles the physical side: blast wave travelling outward at
	    the same speed as the visual shock ring, vaporisation, scorching,
	    fires, shattering glass, flinging debris, killing humanoids, terrain
	    burn, and darkening the sky. Every visual (fireball, glare, shock ring,
	    condensation dome, mushroom cloud, lightning, fallout, screen flash,
	    camera shake, delayed sound) is rendered on each client.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local CONFIG = {
	OwnerName = "c00lzerRSolo", -- only this player gets / can use the tool
	OwnerImmune = true,         -- the owner survives their own bomb so they can watch

	TargetDistance = 380,   -- studs in front of the player the bomb is aimed at
	DropHeight = 520,       -- release altitude (studs above ground)
	DetonationHeight = 75,  -- air-burst altitude (studs above ground)
	FreeFallTime = 1.6,     -- seconds before the parachute opens
	DescentSpeed = 40,      -- studs/s under canopy

	FireballRadius = 140,
	ShockwaveRadius = 1000, -- how far the blast wave travels
	ShockTime = 7,          -- seconds for the blast wave to reach ShockwaveRadius
	DestructionRadius = 650,-- parts inside this are torn loose
	LethalRadius = 800,     -- humanoids inside this die
	ThermalRadius = 900,    -- parts inside this get scorched / may catch fire
	CloudHeight = 1150,
	CapRadius = 300,

	BlastForce = 420,
	MaxBreakableSize = 250, -- anchored parts bigger than this (baseplates) only get scorched
	MaxPartsAffected = 4000,
	MaxFires = 70,
	MaxShards = 160,
	DestroyMap = true,      -- false = only scorch, never unanchor the map
	BurnTerrain = true,

	EffectDuration = 95,    -- seconds the cloud lingers
	Cooldown = 20,
}

local TOOL_NAME = "Tsar Bomba"

------------------------------------------------------------------------------
-- Setup
------------------------------------------------------------------------------

local remote = ReplicatedStorage:FindFirstChild("TsarBombaFX")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "TsarBombaFX"
	remote.Parent = ReplicatedStorage
end

local fxFolder = workspace:FindFirstChild("TsarBombaServerFX")
if not fxFolder then
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "TsarBombaServerFX"
	fxFolder.Parent = workspace
end

local rng = Random.new()

local function make(className, props)
	local inst = Instance.new(className)
	if props.Shape then
		inst.Shape = props.Shape -- must be set before Size or balls get squashed
	end
	for k, v in pairs(props) do
		if k ~= "Parent" and k ~= "Shape" then
			inst[k] = v
		end
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function part(props)
	props.Anchored = true
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	props.TopSurface = Enum.SurfaceType.Smooth
	props.BottomSurface = Enum.SurfaceType.Smooth
	if props.CastShadow == nil then
		props.CastShadow = false
	end
	props.Material = props.Material or Enum.Material.SmoothPlastic
	return make("Part", props)
end

local function ellipsoid(props)
	local p = part(props)
	make("SpecialMesh", { MeshType = Enum.MeshType.Sphere, Parent = p })
	return p
end

local function tween(inst, t, goal, style, dir)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end

local function shockRadius(t)
	local u = math.clamp(t / CONFIG.ShockTime, 0, 1)
	return CONFIG.ShockwaveRadius * (1 - (1 - u) ^ 1.6) -- fast at first, decelerating like a real blast front
end

local function groundBelow(pos, ignore)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(pos + Vector3.new(0, 400, 0), Vector3.new(0, -4000, 0), params)
	return hit and hit.Position or Vector3.new(pos.X, pos.Y - 3, pos.Z)
end

------------------------------------------------------------------------------
-- The bomb model (8 m x 2.1 m real dimensions, ~1 stud = 0.28 m)
------------------------------------------------------------------------------

local function buildBomb()
	local model = Instance.new("Model")
	model.Name = "TsarBomba_AN602"

	local metal = Color3.fromRGB(88, 94, 84)
	local dark = Color3.fromRGB(52, 56, 50)
	local pieces = {} -- { part, offset } in bomb space: +X = nose

	local function add(p, offset)
		p.CFrame = offset
		p.Parent = model
		table.insert(pieces, { p, offset })
		return p
	end

	local body = add(part({ Name = "Body", Shape = Enum.PartType.Cylinder, Size = Vector3.new(20, 7.6, 7.6),
		Color = metal, Material = Enum.Material.Metal, CastShadow = true }), CFrame.new())
	add(ellipsoid({ Name = "Nose", Size = Vector3.new(11, 7.6, 7.6), Color = metal, Material = Enum.Material.Metal, CastShadow = true }),
		CFrame.new(10, 0, 0))
	add(part({ Name = "Fuze", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 1.4, 1.4), Color = dark,
		Material = Enum.Material.Metal }), CFrame.new(15.3, 0, 0))
	add(part({ Name = "TailCone", Shape = Enum.PartType.Cylinder, Size = Vector3.new(5, 6.2, 6.2), Color = metal,
		Material = Enum.Material.Metal, CastShadow = true }), CFrame.new(-12.5, 0, 0))
	local tail = add(part({ Name = "TailCap", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 4.4, 4.4), Color = dark,
		Material = Enum.Material.Metal }), CFrame.new(-16.5, 0, 0))

	for _, x in ipairs({ -8.5, -3, 3.5, 8.6 }) do
		add(part({ Name = "Band", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.45, 7.85, 7.85), Color = dark,
			Material = Enum.Material.DiamondPlate }), CFrame.new(x, 0, 0))
	end
	-- lifting lugs
	for _, x in ipairs({ -4, 4 }) do
		add(part({ Name = "Lug", Size = Vector3.new(0.8, 0.9, 1.6), Color = dark, Material = Enum.Material.Metal }),
			CFrame.new(x, 4.1, 0))
	end
	-- cruciform tail fins with tip plates
	for i = 0, 3 do
		local a = i * math.pi / 2
		add(part({ Name = "Fin", Size = Vector3.new(7.5, 5.2, 0.35), Color = metal, Material = Enum.Material.Metal, CastShadow = true }),
			CFrame.Angles(a, 0, 0) * CFrame.new(-14.5, 5.6, 0))
		add(part({ Name = "FinTip", Size = Vector3.new(5, 0.35, 2.4), Color = dark, Material = Enum.Material.Metal }),
			CFrame.Angles(a, 0, 0) * CFrame.new(-15.5, 8.2, 0))
	end
	-- red stencil stripe
	add(part({ Name = "Stripe", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 7.7, 7.7),
		Color = Color3.fromRGB(150, 25, 20), Material = Enum.Material.SmoothPlastic }), CFrame.new(6, 0, 0))

	local beacon = add(part({ Name = "Beacon", Shape = Enum.PartType.Ball, Size = Vector3.new(1.1, 1.1, 1.1),
		Color = Color3.fromRGB(255, 30, 30), Material = Enum.Material.Neon }), CFrame.new(-18.3, 0, 0))
	local beaconLight = make("PointLight", { Color = Color3.fromRGB(255, 40, 40), Range = 22, Brightness = 6, Parent = beacon })

	-- packed chute + canopy -------------------------------------------------
	local pack = add(part({ Name = "ChutePack", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 3.6, 3.6),
		Color = Color3.fromRGB(70, 80, 60), Material = Enum.Material.Fabric }), CFrame.new(-19.2, 0, 0))
	local riserAttach = make("Attachment", { Name = "Riser", Position = Vector3.new(-1, 0, 0), Parent = pack })

	local canopyFull = Vector3.new(74, 24, 74)
	local canopy = ellipsoid({ Name = "Canopy", Size = Vector3.new(2, 2, 2), Color = Color3.fromRGB(235, 120, 40),
		Material = Enum.Material.Fabric, Transparency = 1, CastShadow = true, Parent = model })
	local canopyInner = ellipsoid({ Name = "CanopyInner", Size = Vector3.new(2, 2, 2), Color = Color3.fromRGB(240, 236, 225),
		Material = Enum.Material.Fabric, Transparency = 1, Parent = model })
	local vent = part({ Name = "Vent", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 6, 6),
		Color = Color3.fromRGB(40, 40, 40), Transparency = 1, Parent = model })

	local rim, beams = {}, {}
	for i = 1, 16 do
		local a = (i - 1) / 16 * math.pi * 2
		local att = make("Attachment", { Name = "Rim" .. i, Parent = canopy })
		rim[i] = { att, a }
		beams[i] = make("Beam", {
			Attachment0 = riserAttach, Attachment1 = att, Width0 = 0.18, Width1 = 0.18, FaceCamera = true,
			Color = ColorSequence.new(Color3.fromRGB(220, 215, 200)), LightInfluence = 1, Segments = 1,
			Transparency = NumberSequence.new(0.1), Enabled = false, Parent = canopy,
		})
	end

	-- telemetry billboard -------------------------------------------------
	local bb = make("BillboardGui", {
		Name = "Telemetry", Adornee = body, Size = UDim2.fromOffset(300, 104), StudsOffset = Vector3.new(0, 20, 0),
		AlwaysOnTop = true, MaxDistance = 4000, LightInfluence = 0, Parent = body,
	})
	local frame = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(15, 5, 5),
		BackgroundTransparency = 0.25, BorderSizePixel = 0, Parent = bb })
	make("UICorner", { CornerRadius = UDim.new(0, 8), Parent = frame })
	make("UIStroke", { Color = Color3.fromRGB(255, 50, 40), Thickness = 2, Parent = frame })
	make("TextLabel", { Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 4), BackgroundTransparency = 1,
		Text = "☢  TSAR BOMBA  ☢", Font = Enum.Font.GothamBlack, TextSize = 24, TextColor3 = Color3.fromRGB(255, 70, 55),
		TextStrokeTransparency = 0.4, Parent = frame })
	make("TextLabel", { Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 34), BackgroundTransparency = 1,
		Text = "AN602 · RDS-220 · 50 MEGATONS TNT", Font = Enum.Font.GothamBold, TextSize = 14,
		TextColor3 = Color3.fromRGB(255, 210, 190), Parent = frame })
	local status = make("TextLabel", { Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 56), BackgroundTransparency = 1,
		Text = "", Font = Enum.Font.Code, TextSize = 15, TextColor3 = Color3.fromRGB(255, 255, 255), Parent = frame })
	local status2 = make("TextLabel", { Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 78), BackgroundTransparency = 1,
		Text = "", Font = Enum.Font.Code, TextSize = 15, TextColor3 = Color3.fromRGB(255, 190, 90), Parent = frame })

	return {
		model = model, pieces = pieces, body = body, tail = tail, beacon = beacon, beaconLight = beaconLight,
		canopy = canopy, canopyInner = canopyInner, vent = vent, canopyFull = canopyFull, rim = rim, beams = beams,
		pack = pack, status = status, status2 = status2,
	}
end

local function placeBomb(b, pos, t, deploy)
	local sway = deploy > 0 and math.rad(7) * deploy or 0
	local swing = CFrame.Angles(math.sin(t * 1.25) * sway, 0, math.cos(t * 0.9) * sway * 0.7)
	local yaw = CFrame.Angles(0, t * 0.35, 0)
	-- the bomb hangs nose-down: bomb +X -> world -Y
	local frame = CFrame.new(pos) * swing * yaw * CFrame.Angles(0, 0, -math.pi / 2)

	local parts, cfs = {}, {}
	for i, piece in ipairs(b.pieces) do
		parts[i] = piece[1]
		cfs[i] = frame * piece[2]
	end
	workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)

	if deploy > 0 then
		-- canopy streams out long and thin, then blossoms open
		local open = deploy * deploy * (3 - 2 * deploy)
		local full = b.canopyFull
		local size = Vector3.new(full.X * (0.08 + 0.92 * open), full.Y * (2.2 - 1.2 * open), full.Z * (0.08 + 0.92 * open))
		local lines = 30 + 52 * deploy
		local breathe = 1 + math.sin(t * 2.3) * 0.03 * open
		size = Vector3.new(size.X * breathe, size.Y, size.Z * breathe)
		local canopyCF = CFrame.new(pos) * swing * yaw * CFrame.new(0, 19 + lines, 0)
		b.canopy.Size = size
		b.canopy.CFrame = canopyCF
		b.canopyInner.Size = Vector3.new(size.X * 0.93, size.Y * 0.8, size.Z * 0.93)
		b.canopyInner.CFrame = canopyCF * CFrame.new(0, -size.Y * 0.14, 0)
		b.vent.Size = Vector3.new(0.6, size.X * 0.09, size.X * 0.09)
		b.vent.CFrame = canopyCF * CFrame.new(0, size.Y * 0.5 - 0.1, 0) * CFrame.Angles(0, 0, math.pi / 2)
		for _, r in ipairs(b.rim) do
			r[1].Position = Vector3.new(math.cos(r[2]) * size.X * 0.47, -size.Y * 0.12, math.sin(r[2]) * size.Z * 0.47)
		end
	end
end

------------------------------------------------------------------------------
-- Sky / atmosphere (global, replicated)
------------------------------------------------------------------------------

local function nuclearSky(duration)
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	local created = atmo == nil
	if created then
		atmo = make("Atmosphere", { Density = 0, Offset = 0, Haze = 0, Glare = 0, Parent = Lighting })
	end
	local savedAtmo = { Density = atmo.Density, Offset = atmo.Offset, Haze = atmo.Haze, Glare = atmo.Glare,
		Color = atmo.Color, Decay = atmo.Decay }
	local savedLight = { OutdoorAmbient = Lighting.OutdoorAmbient, Ambient = Lighting.Ambient,
		ExposureCompensation = Lighting.ExposureCompensation }

	tween(Lighting, 0.12, { OutdoorAmbient = Color3.fromRGB(255, 240, 215), Ambient = Color3.fromRGB(210, 180, 150),
		ExposureCompensation = 1.2 })
	task.delay(0.35, function()
		tween(Lighting, 14, { OutdoorAmbient = Color3.fromRGB(150, 98, 72), Ambient = Color3.fromRGB(92, 62, 48),
			ExposureCompensation = savedLight.ExposureCompensation - 0.2 }, Enum.EasingStyle.Sine)
	end)
	tween(atmo, 30, { Density = 0.43, Offset = 0.2, Haze = 2.6, Glare = 1.4, Color = Color3.fromRGB(205, 145, 105),
		Decay = Color3.fromRGB(105, 68, 50) }, Enum.EasingStyle.Sine)

	task.delay(duration, function()
		tween(Lighting, 18, savedLight, Enum.EasingStyle.Sine)
		tween(atmo, 18, savedAtmo, Enum.EasingStyle.Sine)
		if created then
			Debris:AddItem(atmo, 19)
		end
	end)
end

------------------------------------------------------------------------------
-- Blast wave: physical effects applied as the front passes each part
------------------------------------------------------------------------------

local function burnTerrain(ground)
	if not CONFIG.BurnTerrain then
		return
	end
	pcall(function()
		local r = math.min(CONFIG.ThermalRadius * 0.45, 400)
		local region = Region3.new(ground - Vector3.new(r, 40, r), ground + Vector3.new(r, 40, r)):ExpandToGrid(4)
		local terrain = workspace.Terrain
		terrain:ReplaceMaterial(region, 4, Enum.Material.Grass, Enum.Material.Ground)
		terrain:ReplaceMaterial(region, 4, Enum.Material.LeafyGrass, Enum.Material.Ground)
		terrain:ReplaceMaterial(region, 4, Enum.Material.Snow, Enum.Material.Mud)
		terrain:ReplaceMaterial(region, 4, Enum.Material.Ice, Enum.Material.Water)
		local inner = math.min(CONFIG.FireballRadius * 1.1, 150)
		local core = Region3.new(ground - Vector3.new(inner, 30, inner), ground + Vector3.new(inner, 30, inner)):ExpandToGrid(4)
		terrain:ReplaceMaterial(core, 4, Enum.Material.Ground, Enum.Material.Basalt)
		terrain:ReplaceMaterial(core, 4, Enum.Material.Sand, Enum.Material.Glass) -- trinitite
	end)
end

local function shatter(p, dir, k, state)
	local pieces = math.min(6, CONFIG.MaxShards - state.shards)
	if pieces <= 0 then
		p:Destroy()
		return
	end
	state.shards += pieces
	local s = p.Size
	for _ = 1, pieces do
		local shard = Instance.new("Part")
		shard.Size = Vector3.new(math.max(0.2, s.X * rng:NextNumber(0.15, 0.4)), math.max(0.2, s.Y * rng:NextNumber(0.15, 0.4)), 0.15)
		shard.CFrame = p.CFrame * CFrame.new(rng:NextNumber(-s.X, s.X) * 0.4, rng:NextNumber(-s.Y, s.Y) * 0.4, 0)
			* CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
		shard.Color = p.Color
		shard.Material = Enum.Material.Glass
		shard.Transparency = math.max(p.Transparency, 0.3)
		shard.CanCollide = true
		shard.Parent = fxFolder
		shard.AssemblyLinearVelocity = dir * CONFIG.BlastForce * (0.3 + k) + Vector3.new(0, rng:NextNumber(10, 60), 0)
		Debris:AddItem(shard, rng:NextNumber(8, 14))
	end
	p:Destroy()
end

local function processPart(p, d, center, ownerChar, state)
	if not p.Parent or p:IsDescendantOf(fxFolder) then
		return
	end
	local k = math.clamp(1 - d / CONFIG.ShockwaveRadius, 0, 1)
	local dir = p.Position - center
	dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.yAxis
	local fling = dir * CONFIG.BlastForce * (0.25 + k) + Vector3.new(0, CONFIG.BlastForce * 0.35 * k, 0)

	local model = p:FindFirstAncestorOfClass("Model")
	local hum = model and model:FindFirstChildOfClass("Humanoid")
	if hum then
		if CONFIG.OwnerImmune and model == ownerChar then
			return
		end
		if not state.hit[model] then
			state.hit[model] = true
			if d <= CONFIG.LethalRadius then
				hum.Health = 0
			else
				hum:TakeDamage(150 * k)
			end
			if d <= CONFIG.FireballRadius * 1.3 then
				-- inside the fireball: nothing is left
				for _, bp in ipairs(model:GetDescendants()) do
					if bp:IsA("BasePart") then
						bp.Color = Color3.fromRGB(20, 16, 14)
						tween(bp, 0.6, { Transparency = 1 })
					end
				end
				Debris:AddItem(model, 0.7)
			end
		end
		if not p.Anchored then
			p.AssemblyLinearVelocity = fling
			p.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-8, 8), rng:NextNumber(-8, 8), rng:NextNumber(-8, 8))
		end
		return
	end

	-- vaporisation zone
	if CONFIG.DestroyMap and d <= CONFIG.FireballRadius * 1.25 and p.Size.Magnitude <= CONFIG.MaxBreakableSize then
		p.Anchored = true
		p.CanCollide = false
		p.Material = Enum.Material.Neon
		p.Color = Color3.fromRGB(255, 170, 70)
		tween(p, rng:NextNumber(0.3, 0.9), { Transparency = 1, Color = Color3.fromRGB(60, 20, 10) })
		Debris:AddItem(p, 1)
		return
	end

	-- thermal pulse: scorch
	if d <= CONFIG.ThermalRadius then
		local burn = math.clamp(1.15 - d / CONFIG.ThermalRadius, 0, 0.88)
		p.Color = p.Color:Lerp(Color3.fromRGB(26, 20, 17), burn)
		if burn > 0.45 and (p.Material == Enum.Material.Grass or p.Material == Enum.Material.LeafyGrass) then
			p.Material = Enum.Material.Ground
		end
		if state.fires < CONFIG.MaxFires and d <= CONFIG.ThermalRadius * 0.75 and rng:NextNumber() < 0.1
			and (p.Material == Enum.Material.Wood or p.Material == Enum.Material.WoodPlanks
				or p.Material == Enum.Material.Fabric or p.Material == Enum.Material.Ground or rng:NextNumber() < 0.4) then
			state.fires += 1
			local fire = make("Fire", { Size = rng:NextNumber(8, 22), Heat = rng:NextNumber(10, 22),
				Color = Color3.fromRGB(255, 120, 30), SecondaryColor = Color3.fromRGB(255, 50, 0), Parent = p })
			make("Smoke", { Size = 12, Opacity = 0.18, RiseVelocity = 12, Color = Color3.fromRGB(40, 36, 34), Parent = p })
			Debris:AddItem(fire, rng:NextNumber(25, 45))
		end
	end

	-- glass blows out much further than structures fail
	if p.Material == Enum.Material.Glass and p.Size.Magnitude <= CONFIG.MaxBreakableSize and CONFIG.DestroyMap then
		shatter(p, dir, k, state)
		return
	end

	-- blast: tear loose and fling
	if CONFIG.DestroyMap and d <= CONFIG.DestructionRadius and p.Size.Magnitude <= CONFIG.MaxBreakableSize then
		for _, j in ipairs(p:GetJoints()) do
			if j:IsA("JointInstance") or j:IsA("WeldConstraint") or j:IsA("Constraint") then
				j:Destroy()
			end
		end
		p.Anchored = false
		p.AssemblyLinearVelocity = fling
		p.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-6, 6), rng:NextNumber(-6, 6), rng:NextNumber(-6, 6)) * k
	elseif not p.Anchored then
		p.AssemblyLinearVelocity += fling * 0.5
	end
end

local function blastWave(center, ground, ownerChar)
	local ignore = { fxFolder }
	if CONFIG.OwnerImmune and ownerChar then
		table.insert(ignore, ownerChar)
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.MaxParts = CONFIG.MaxPartsAffected

	local found = workspace:GetPartBoundsInRadius(center, CONFIG.ShockwaveRadius, params)
	local list = {}
	for _, p in ipairs(found) do
		if p ~= workspace.Terrain and not p:IsA("Terrain") then
			table.insert(list, { p, (p.Position - center).Magnitude })
		end
	end
	table.sort(list, function(a, b)
		return a[2] < b[2]
	end)

	local state = { hit = {}, fires = 0, shards = 0 }
	local start = os.clock()
	local i = 1
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local r = shockRadius(os.clock() - start)
		local budget = 250 -- parts per frame, keeps the server from hitching
		while i <= #list and list[i][2] <= r and budget > 0 do
			local ok, err = pcall(processPart, list[i][1], list[i][2], center, ownerChar, state)
			if not ok then
				warn("[TsarBomba] " .. tostring(err))
			end
			i += 1
			budget -= 1
		end
		if i > #list or os.clock() - start > CONFIG.ShockTime + 5 then
			conn:Disconnect()
		end
	end)
end

------------------------------------------------------------------------------
-- Drop sequence
------------------------------------------------------------------------------

local busy = false
local lastUse = -math.huge

local function groundZeroMarker(ground)
	local holder = part({ Name = "GroundZero", Size = Vector3.new(1, 1, 1), Transparency = 1,
		CFrame = CFrame.new(ground + Vector3.new(0, 1, 0)), Parent = fxFolder })
	local ring = part({ Name = "GZRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 60, 60),
		CFrame = CFrame.new(ground + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(255, 30, 20), Material = Enum.Material.Neon, Transparency = 0.55, Parent = fxFolder })
	TweenService:Create(ring, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Size = Vector3.new(0.3, 90, 90), Transparency = 0.85 }):Play()
	local bb = make("BillboardGui", { Size = UDim2.fromOffset(200, 50), StudsOffset = Vector3.new(0, 12, 0),
		AlwaysOnTop = true, LightInfluence = 0, Parent = holder })
	make("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "✛ GROUND ZERO ✛",
		Font = Enum.Font.GothamBlack, TextSize = 22, TextColor3 = Color3.fromRGB(255, 60, 40),
		TextStrokeTransparency = 0.3, Parent = bb })
	return { holder, ring }
end

local function dropBomb(player, rootCF)
	busy = true
	local char = player.Character

	local look = rootCF.LookVector * Vector3.new(1, 0, 1)
	look = look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
	local ground = groundBelow(rootCF.Position + look * CONFIG.TargetDistance, { char, fxFolder })
	local releasePos = ground + Vector3.new(0, CONFIG.DropHeight, 0)
	local burstY = ground.Y + CONFIG.DetonationHeight

	local bomb = buildBomb()
	placeBomb(bomb, releasePos, 0, 0)
	bomb.model.Parent = fxFolder
	local marker = groundZeroMarker(ground)

	remote:FireAllClients("Released", { Ground = ground, Owner = player.Name })

	local pos, vel = releasePos, 0
	local t0 = os.clock()
	local deployAt
	local lastText = 0
	while true do
		local dt = RunService.Heartbeat:Wait()
		local t = os.clock() - t0
		if not deployAt and t >= CONFIG.FreeFallTime then
			deployAt = t
			bomb.canopy.Transparency = 0
			bomb.canopyInner.Transparency = 0
			bomb.vent.Transparency = 0
			for _, beam in ipairs(bomb.beams) do
				beam.Enabled = true
			end
		end
		if deployAt then
			vel += (CONFIG.DescentSpeed - vel) * math.min(1, dt * 1.6)
		else
			vel += workspace.Gravity * 0.55 * dt
		end
		pos -= Vector3.new(0, vel * dt, 0)
		local deploy = deployAt and math.clamp((t - deployAt) / 1.3, 0, 1) or 0
		placeBomb(bomb, pos, t, deploy)

		-- blinking arming light
		local on = (t * 2.5) % 1 < 0.5
		bomb.beacon.Color = on and Color3.fromRGB(255, 30, 30) or Color3.fromRGB(70, 10, 10)
		bomb.beaconLight.Enabled = on

		if t - lastText > 0.1 then
			lastText = t
			local above = pos.Y - ground.Y
			-- map the drop onto the real profile: released at 10.5 km, burst at 4.0 km
			local altKm = 4.0 + 6.5 * math.clamp((above - CONFIG.DetonationHeight) / (CONFIG.DropHeight - CONFIG.DetonationHeight), 0, 1)
			local eta = (pos.Y - burstY) / math.max(vel, 1)
			bomb.status.Text = string.format("ALT %5.2f km   VEL %3d m/s", altKm, math.floor(vel * 2.1))
			bomb.status2.Text = deployAt and string.format("CHUTE OPEN · BURST T-%04.1fs", math.max(eta, 0))
				or "FREE FALL · CHUTE ARMING"
		end

		if pos.Y <= burstY then
			break
		end
	end

	local center = pos
	bomb.model:Destroy()
	for _, m in ipairs(marker) do
		m:Destroy()
	end

	remote:FireAllClients("Detonate", {
		Center = center,
		Ground = ground,
		FireballRadius = CONFIG.FireballRadius,
		ShockwaveRadius = CONFIG.ShockwaveRadius,
		ShockTime = CONFIG.ShockTime,
		CloudHeight = CONFIG.CloudHeight,
		CapRadius = CONFIG.CapRadius,
		Duration = CONFIG.EffectDuration,
	})

	-- the light-speed effects first, the blast wave after
	nuclearSky(CONFIG.EffectDuration)
	burnTerrain(ground)
	blastWave(center, ground, char)

	task.delay(CONFIG.ShockTime + 2, function()
		busy = false
	end)
end

------------------------------------------------------------------------------
-- Tool
------------------------------------------------------------------------------

local function isOwner(player)
	return string.lower(player.Name) == string.lower(CONFIG.OwnerName)
end

local function giveTool(player)
	local backpack = player:WaitForChild("Backpack", 10)
	if not backpack then
		return
	end
	local char = player.Character
	if backpack:FindFirstChild(TOOL_NAME) or (char and char:FindFirstChild(TOOL_NAME)) then
		return
	end

	local tool = Instance.new("Tool")
	tool.Name = TOOL_NAME
	tool.ToolTip = "AN602 · 50 Mt — equip to release"
	tool.RequiresHandle = false
	tool.CanBeDropped = false

	tool.Equipped:Connect(function()
		local c = tool.Parent
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		-- immediately put it away again
		task.defer(function()
			if hum and tool.Parent == c then
				hum:UnequipTools()
			end
		end)

		if not isOwner(player) then
			return
		end
		if busy or os.clock() - lastUse < CONFIG.Cooldown then
			return
		end
		local root = c and c:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		lastUse = os.clock()
		task.spawn(function()
			local ok, err = pcall(dropBomb, player, root.CFrame)
			if not ok then
				warn("[TsarBomba] drop failed: " .. tostring(err))
				busy = false
			end
		end)
	end)

	tool.Parent = backpack
end

local function onPlayer(player)
	if not isOwner(player) then
		return
	end
	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		giveTool(player)
	end)
	if player.Character then
		giveTool(player)
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayer, p)
end
