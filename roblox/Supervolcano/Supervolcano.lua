-- VEI 9 SUPERVOLCANO — all-in-one server script.
-- Use it either way:
--   * Studio: put it in a Script in ServerScriptService.
--   * Live game you own: paste Supervolcano.oneline.lua into the F9 > Server command bar.
-- Gives CONFIG.OwnerName a tool. Equipping it instantly un-equips it and starts a
-- caldera-forming super-eruption at a point in front of the player.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local CONFIG = {
	OwnerName = "c00lzerRSolo",
	OwnerImmune = true,       -- you survive your own eruption so you can watch
	TargetDistance = 650,     -- studs in front of you the vent opens

	PrecursorTime = 14,       -- seconds of earthquakes / cracks / steam before it blows
	CalderaRadius = 230,
	NeutralHeight = 1450,     -- where the column stops rising and spreads into the umbrella
	ColumnHeight = 1950,      -- overshoot top of the column
	UmbrellaRadius = 2400,
	BlastRadius = 700,        -- initial lateral air blast
	PyroStart = 9,            -- seconds after onset that the column partially collapses
	PyroRadius = 1500,        -- pyroclastic flow run-out
	PyroTime = 40,
	CollapseAt = 24,          -- seconds after onset that the caldera floor drops
	Bombs = 70,
	BombRange = 1000,
	LavaFlows = 9,
	LavaLength = 520,
	LavaSpeed = 9,
	AshRadius = 2200,
	Duration = 200,           -- seconds the column/umbrella/darkness last

	DestroyMap = true,        -- false = scorch and ash only, never unanchor the map
	UseTerrain = true,        -- carve the caldera / lava lake / ash into Terrain
	MaxPartsAffected = 5000,
	MaxBreakableSize = 250,
	Cooldown = 30,
	SoundSpeed = 1100,
	KmPerStud = 0.026,
	RumbleSound = "",         -- optional "rbxassetid://..."; built-in explosion sounds are used otherwise
}

local TOOL_NAME = "VEI 9 Supervolcano"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local TAU = math.pi * 2
local GRAVITY = workspace.Gravity
local rng = Random.new()

------------------------------------------------------------------------------
-- helpers
------------------------------------------------------------------------------

local function clamp01(x)
	return math.clamp(x, 0, 1)
end

local function smooth(x)
	x = clamp01(x)
	return x * x * (3 - 2 * x)
end

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function nseq(points)
	local kps = {}
	for _, p in ipairs(points) do
		table.insert(kps, NumberSequenceKeypoint.new(p[1], p[2], p[3] or 0))
	end
	return NumberSequence.new(kps)
end

local function cseq(points)
	local kps = {}
	for _, p in ipairs(points) do
		table.insert(kps, ColorSequenceKeypoint.new(p[1], p[2]))
	end
	return ColorSequence.new(kps)
end

local function tween(inst, t, goal, style, dir)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	tw:Play()
	return tw
end

local function make(className, props)
	local inst = Instance.new(className)
	if props.Shape then
		inst.Shape = props.Shape
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
	props.CanCollide = props.CanCollide or false
	props.CanQuery = false
	props.CanTouch = false
	props.CastShadow = props.CastShadow or false
	props.TopSurface = Enum.SurfaceType.Smooth
	props.BottomSurface = Enum.SurfaceType.Smooth
	props.Material = props.Material or Enum.Material.SmoothPlastic
	return make("Part", props)
end

local function ball(props)
	props.Shape = Enum.PartType.Ball
	props.Size = props.Size or Vector3.one
	return part(props)
end

local function ellipsoid(props)
	local p = part(props)
	make("SpecialMesh", { MeshType = Enum.MeshType.Sphere, Parent = p })
	return p
end

local function uniform(d)
	d = math.clamp(d, 0.05, 2048)
	return Vector3.new(d, d, d)
end

local function cap(v)
	return Vector3.new(math.clamp(v.X, 0.05, 2048), math.clamp(v.Y, 0.05, 2048), math.clamp(v.Z, 0.05, 2048))
end

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	e.LightInfluence = 1
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-20, 20)
	for k, v in pairs(props) do
		e[k] = v
	end
	e.Parent = parent
	return e
end

local ASH = rgb(92, 86, 82)
local SOOT = rgb(48, 42, 40)
local PALE = rgb(170, 162, 154)
local PYRO = rgb(122, 108, 96)
local ASHFALL = rgb(152, 147, 142)
local HOT = rgb(255, 110, 35)

local function tinted(col, tint)
	if tint > 0 then
		return col:Lerp(SOOT, tint)
	end
	return col:Lerp(PALE, -tint)
end

local fxFolder = workspace:FindFirstChild("SupervolcanoFX") or make("Folder", { Name = "SupervolcanoFX", Parent = workspace })

local function rootPos(plr)
	local c = plr.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	return r and r.Position
end

local function groundHit(pos)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { fxFolder }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	return workspace:Raycast(Vector3.new(pos.X, pos.Y + 600, pos.Z), Vector3.new(0, -3000, 0), params)
end

local function groundAt(pos)
	local hit = groundHit(pos)
	return hit and hit.Position or pos
end

------------------------------------------------------------------------------
-- per-player HUD, shake and sound (all server-driven)
------------------------------------------------------------------------------

local huds = {}

local function hud(plr)
	local h = huds[plr]
	if h and h.gui.Parent then
		return h
	end
	local pg = plr:FindFirstChildOfClass("PlayerGui")
	if not pg then
		return nil
	end
	local old = pg:FindFirstChild("VolcanoHUD")
	if old then
		old:Destroy()
	end
	local gui = make("ScreenGui", { Name = "VolcanoHUD", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 50, Parent = pg })
	local flash = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(255, 150, 70), BackgroundTransparency = 1,
		BorderSizePixel = 0, ZIndex = 20, Parent = gui })
	local vignette = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(40, 34, 30), BackgroundTransparency = 1,
		BorderSizePixel = 0, ZIndex = 19, Parent = gui })
	make("UIGradient", { Transparency = nseq({ { 0, 0 }, { 0.3, 0.9 }, { 0.7, 0.9 }, { 1, 0 } }), Parent = vignette })
	local banner = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 56),
		Size = UDim2.new(0.92, 0, 0, 78), BackgroundColor3 = rgb(90, 40, 0), BackgroundTransparency = 0.2,
		Visible = false, ZIndex = 30, Parent = gui })
	make("UISizeConstraint", { MaxSize = Vector2.new(620, 78), Parent = banner })
	make("UICorner", { CornerRadius = UDim.new(0, 10), Parent = banner })
	local stroke = make("UIStroke", { Color = rgb(255, 140, 40), Thickness = 2, Parent = banner })
	local title = make("TextLabel", { Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 6), BackgroundTransparency = 1,
		Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = rgb(255, 235, 215), TextStrokeTransparency = 0.5,
		ZIndex = 31, Text = "", Parent = banner })
	local sub = make("TextLabel", { Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 42), BackgroundTransparency = 1,
		Font = Enum.Font.Code, TextSize = 15, TextWrapped = true, TextColor3 = rgb(255, 210, 170), ZIndex = 31, Text = "", Parent = banner })
	h = { gui = gui, flash = flash, vignette = vignette, banner = banner, stroke = stroke, title = title, sub = sub }
	huds[plr] = h
	return h
end

local shakes = {}

local function addShake(plr, a)
	shakes[plr] = math.max(shakes[plr] or 0, a)
end

RunService.Heartbeat:Connect(function(dt)
	local t = os.clock() * 13
	for plr, a in pairs(shakes) do
		local c = plr.Character
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if a < 0.01 or not hum then
			if hum then
				hum.CameraOffset = Vector3.zero
			end
			shakes[plr] = nil
		else
			hum.CameraOffset = Vector3.new(math.noise(t, 1.7), math.noise(t, 7.3) * 0.7, math.noise(t, 13.1)) * a * 2.4
			shakes[plr] = a * math.exp(-dt * 1.1)
		end
	end
end)

local function boomAt(pos)
	local e = Instance.new("Explosion")
	e.BlastPressure = 0
	e.BlastRadius = 0
	e.DestroyJointRadiusPercent = 0
	e.Visible = false
	e.Position = pos
	e.Parent = workspace
	Debris:AddItem(e, 4)
end

local function boomFor(plr)
	local p = rootPos(plr)
	if p then
		boomAt(p)
	end
end

------------------------------------------------------------------------------
-- damage helpers
------------------------------------------------------------------------------

local function charModel(model, color)
	for _, bp in ipairs(model:GetDescendants()) do
		if bp:IsA("BasePart") then
			bp.Color = bp.Color:Lerp(color, 0.85)
		end
	end
end

local function harmArea(center, radius, owner, color)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { fxFolder }
	local seen = {}
	for _, p in ipairs(workspace:GetPartBoundsInRadius(center, radius, params)) do
		local m = p:FindFirstAncestorOfClass("Model")
		local hum = m and m:FindFirstChildOfClass("Humanoid")
		if hum and not seen[m] then
			seen[m] = true
			if not (CONFIG.OwnerImmune and m == owner.Character) and hum.Health > 0 then
				hum.Health = 0
				charModel(m, color)
			end
		end
	end
end

local function breakLoose(p, vel)
	if not CONFIG.DestroyMap or p.Size.Magnitude > CONFIG.MaxBreakableSize then
		return
	end
	for _, j in ipairs(p:GetJoints()) do
		if j:IsA("JointInstance") or j:IsA("WeldConstraint") or j:IsA("Constraint") then
			j:Destroy()
		end
	end
	p.Anchored = false
	p.AssemblyLinearVelocity = vel
	p.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-5, 5), rng:NextNumber(-5, 5), rng:NextNumber(-5, 5))
end

local fireCount = 0
local function ignite(p, chance)
	if fireCount >= 90 or rng:NextNumber() > chance then
		return
	end
	fireCount += 1
	local life = rng:NextNumber(30, 60)
	local fire = make("Fire", { Size = rng:NextNumber(8, 20), Heat = rng:NextNumber(10, 20), Color = rgb(255, 120, 30),
		SecondaryColor = rgb(255, 50, 0), Parent = p })
	local smk = make("Smoke", { Size = 12, Opacity = 0.2, RiseVelocity = 10, Color = rgb(40, 36, 34), Parent = p })
	Debris:AddItem(fire, life)
	Debris:AddItem(smk, life + 10)
	task.delay(life, function()
		fireCount -= 1
	end)
end

-- process every part in range as an expanding front reaches it
local function sweep(center, maxR, radiusAt, onPart)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { fxFolder }
	params.MaxParts = CONFIG.MaxPartsAffected
	local list = {}
	for _, p in ipairs(workspace:GetPartBoundsInRadius(center, maxR, params)) do
		if not p:IsA("Terrain") then
			table.insert(list, { p, flat(p.Position - center).Magnitude })
		end
	end
	table.sort(list, function(a, b)
		return a[2] < b[2]
	end)
	local start, i = os.clock(), 1
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local r = radiusAt(os.clock() - start)
		local budget = 200
		while i <= #list and list[i][2] <= r and budget > 0 do
			local p = list[i][1]
			if p.Parent and not p:IsDescendantOf(fxFolder) then
				local ok, err = pcall(onPart, p, list[i][2])
				if not ok then
					warn("[Supervolcano] " .. tostring(err))
				end
			end
			i += 1
			budget -= 1
		end
		if i > #list or os.clock() - start > 600 then
			conn:Disconnect()
		end
	end)
end

local function humanoidOf(p)
	local m = p:FindFirstAncestorOfClass("Model")
	local hum = m and m:FindFirstChildOfClass("Humanoid")
	return hum, m
end

------------------------------------------------------------------------------
-- visual building blocks
------------------------------------------------------------------------------

local function bolt(parentFolder, from, to, color)
	local prev, made = from, {}
	local span = (to - from).Magnitude
	local segs = math.clamp(math.floor(span / 40), 6, 16)
	for i = 1, segs do
		local p = from:Lerp(to, i / segs)
		if i < segs then
			p += Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.5, 0.5), rng:NextNumber(-1, 1)) * span * 0.06
		end
		local len = (p - prev).Magnitude
		local w = 2.2 * (1 - i / segs * 0.6)
		table.insert(made, part({ Size = Vector3.new(w, w, len), CFrame = CFrame.lookAt(prev, p) * CFrame.new(0, 0, -len / 2),
			Material = Enum.Material.Neon, Color = color, Parent = parentFolder }))
		-- forks
		if rng:NextNumber() < 0.25 and i < segs - 1 then
			local fork = p + Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 0.2), rng:NextNumber(-1, 1)) * span * 0.15
			local fl = (fork - p).Magnitude
			table.insert(made, part({ Size = Vector3.new(w * 0.5, w * 0.5, fl), CFrame = CFrame.lookAt(p, fork) * CFrame.new(0, 0, -fl / 2),
				Material = Enum.Material.Neon, Color = color, Parent = parentFolder }))
		end
		prev = p
	end
	make("PointLight", { Range = 60, Brightness = 14, Color = color, Parent = made[math.floor(#made / 2) + 1] })
	task.delay(0.07, function()
		for _, s in ipairs(made) do
			s.Transparency = 0.75
		end
	end)
	task.delay(0.12, function()
		for _, s in ipairs(made) do
			s.Transparency = 0
		end
	end)
	task.delay(0.24, function()
		for _, s in ipairs(made) do
			s:Destroy()
		end
	end)
end

local function crackPart(a, b, folder)
	local len = (b - a).Magnitude
	return part({ Name = "Fissure", Size = Vector3.new(1, 0.5, len + 1), CFrame = CFrame.lookAt((a + b) / 2, b),
		Material = Enum.Material.Neon, Color = HOT, Transparency = 1, Parent = folder })
end

------------------------------------------------------------------------------
-- the eruption
------------------------------------------------------------------------------

local function erupt(owner, G, groundIsTerrain)
	local R = CONFIG.CalderaRadius
	local P = CONFIG.PrecursorTime
	local NH, CH, UR = CONFIG.NeutralHeight, CONFIG.ColumnHeight, CONFIG.UmbrellaRadius
	local PR, PT, PS = CONFIG.PyroRadius, CONFIG.PyroTime, CONFIG.PyroStart
	local KM = CONFIG.KmPerStud
	local gy = G.Y
	local wind = Vector3.new(24, 0, 9)

	local fx = make("Folder", { Name = "Eruption", Parent = fxFolder })
	local deposits = make("Folder", { Name = "Deposits", Parent = fxFolder })

	local function fall(d)
		return math.clamp(1 - d / 4500, 0.15, 1)
	end

	------------------------------------------------------------------
	-- precursor: ring fissure, radial cracks, steam vents
	------------------------------------------------------------------
	local cracks = {}
	local NC = 48
	local prevPt
	for i = 0, NC do
		local a = i / NC * TAU
		local rr = R * (1 + rng:NextNumber(-0.03, 0.03))
		local pt = groundAt(G + Vector3.new(math.cos(a) * rr, 0, math.sin(a) * rr)) + Vector3.new(0, 0.2, 0)
		if prevPt then
			table.insert(cracks, { part = crackPart(prevPt, pt, fx), reveal = P * (0.12 + 0.8 * (i / NC)), ring = true, seed = i * 1.37 })
		end
		prevPt = pt
	end
	for i = 1, 12 do
		local a = i / 12 * TAU + rng:NextNumber(-0.2, 0.2)
		local last
		for j = 0, 6 do
			local rr = R * (0.35 + j * 0.26)
			local aa = a + rng:NextNumber(-0.06, 0.06)
			local pt = groundAt(G + Vector3.new(math.cos(aa) * rr, 0, math.sin(aa) * rr)) + Vector3.new(0, 0.2, 0)
			if last then
				table.insert(cracks, { part = crackPart(last, pt, fx), reveal = P * (0.3 + 0.07 * j + rng:NextNumber(0, 0.15)), ring = false,
					seed = i * 7.1 + j })
			end
			last = pt
		end
	end

	local vents = {}
	for i = 1, 14 do
		local a, rr = rng:NextNumber(0, TAU), R * rng:NextNumber(0.2, 1.5)
		local holder = part({ Name = "SteamVent", Size = Vector3.new(8, 1, 8), Transparency = 1,
			CFrame = CFrame.new(groundAt(G + Vector3.new(math.cos(a) * rr, 0, math.sin(a) * rr))), Parent = fx })
		local sulfur = rng:NextNumber() < 0.3
		vents[i] = emitter(holder, {
			Texture = SMOKE, Rate = 0, Lifetime = NumberRange.new(4, 7), Speed = NumberRange.new(18, 45),
			EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(14, 14), Size = nseq({ { 0, 10, 3 }, { 1, 70, 10 } }),
			Transparency = nseq({ { 0, 0.6 }, { 0.5, 0.75 }, { 1, 1 } }), Drag = 0.4, Acceleration = wind * 0.3,
			Color = ColorSequence.new(sulfur and rgb(228, 222, 170) or rgb(236, 236, 232)),
		})
	end

	local centerHolder = part({ Name = "Vent", Size = Vector3.new(R * 0.6, 1, R * 0.6), Transparency = 1, CFrame = CFrame.new(G), Parent = fx })
	local phreatic = emitter(centerHolder, {
		Texture = SMOKE, Rate = 0, Lifetime = NumberRange.new(4, 7), Speed = NumberRange.new(90, 200),
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(20, 20), Size = nseq({ { 0, 30, 8 }, { 1, 130, 20 } }),
		Transparency = nseq({ { 0, 0.15 }, { 1, 1 } }), Color = ColorSequence.new(rgb(110, 104, 100)), Drag = 0.8,
		Acceleration = Vector3.new(0, -10, 0) + wind * 0.3,
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	})

	------------------------------------------------------------------
	-- eruption visuals (created hidden, switched on at onset)
	------------------------------------------------------------------
	local ventGlow = ellipsoid({ Name = "VentGlow", Size = cap(Vector3.new(R * 1.3, 24, R * 1.3)), CFrame = CFrame.new(G + Vector3.new(0, 2, 0)),
		Material = Enum.Material.Neon, Color = HOT, Transparency = 1, Parent = fx })
	local ventLight = make("PointLight", { Range = 60, Brightness = 0, Color = rgb(255, 140, 60), Shadows = true, Parent = ventGlow })
	local jetFire = emitter(ventGlow, {
		Texture = FIRE, Rate = 0, Lifetime = NumberRange.new(1.4, 2.4), Speed = NumberRange.new(220, 380),
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(12, 12), Size = nseq({ { 0, 40, 10 }, { 1, 110, 20 } }),
		LightEmission = 1, LightInfluence = 0, Transparency = nseq({ { 0, 0.2 }, { 0.7, 0.6 }, { 1, 1 } }),
		Color = cseq({ { 0, rgb(255, 225, 160) }, { 0.4, rgb(255, 110, 30) }, { 1, rgb(80, 30, 15) } }),
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	})
	local jetAsh = emitter(ventGlow, {
		Texture = SMOKE, Rate = 0, Lifetime = NumberRange.new(4, 6), Speed = NumberRange.new(280, 430),
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(9, 9), Size = nseq({ { 0, 70, 15 }, { 1, 100, 20 } }),
		Transparency = nseq({ { 0, 0.1 }, { 0.8, 0.35 }, { 1, 1 } }), Color = ColorSequence.new(rgb(72, 66, 62)), Drag = 0.25,
		Acceleration = wind * 0.6, Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	})
	local jetEjecta = emitter(ventGlow, {
		Texture = SPARK, Rate = 0, Lifetime = NumberRange.new(2.5, 5), Speed = NumberRange.new(180, 380),
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(35, 35), Size = nseq({ { 0, 2.5, 1 }, { 1, 1 } }),
		LightEmission = 1, LightInfluence = 0, Color = cseq({ { 0, rgb(255, 230, 170) }, { 1, rgb(200, 50, 15) } }),
		Acceleration = Vector3.new(0, -GRAVITY, 0), Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	})

	-- lava fountains along the ring fissure
	local fountains = {}
	for i = 1, 16 do
		local a = i / 16 * TAU
		local holder = part({ Name = "LavaFountain", Size = Vector3.new(30, 1, 30), Transparency = 1,
			CFrame = CFrame.new(groundAt(G + Vector3.new(math.cos(a) * R, 0, math.sin(a) * R)) + Vector3.new(0, 1, 0)), Parent = fx })
		local drops = emitter(holder, {
			Texture = SPARK, Rate = 0, Lifetime = NumberRange.new(1.6, 2.8), Speed = NumberRange.new(90, 170),
			EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(16, 16), Size = nseq({ { 0, 6, 2 }, { 1, 3, 1 } }),
			LightEmission = 1, LightInfluence = 0, Color = cseq({ { 0, rgb(255, 240, 170) }, { 0.5, rgb(255, 120, 30) }, { 1, rgb(120, 25, 10) } }),
			Acceleration = Vector3.new(0, -GRAVITY, 0), Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		})
		local glow = emitter(holder, {
			Texture = FIRE, Rate = 0, Lifetime = NumberRange.new(0.8, 1.4), Speed = NumberRange.new(20, 50),
			EmissionDirection = Enum.NormalId.Top, Size = nseq({ { 0, 22, 5 }, { 1, 8 } }), LightEmission = 1, LightInfluence = 0,
			Color = cseq({ { 0, rgb(255, 210, 120) }, { 1, rgb(200, 50, 10) } }),
		})
		local light = make("PointLight", { Range = 50, Brightness = 0, Color = rgb(255, 120, 40), Parent = holder })
		fountains[i] = { drops = drops, glow = glow, light = light }
	end

	-- the plume: a pool of puffs that rise as a jet, bend downwind, and spread at neutral buoyancy
	local NPUFF = 240
	local puffs = {}
	local puffParts = {}
	for i = 1, NPUFF do
		local p = ball({ Name = "Plume", Transparency = 1, CFrame = CFrame.new(G - Vector3.new(0, 50, 0)), Parent = fx })
		puffParts[i] = p
		puffs[i] = { part = p, alive = false }
		if i % 8 == 0 then
			emitter(p, {
				Texture = SMOKE, Rate = 3, Lifetime = NumberRange.new(5, 9), Speed = NumberRange.new(2, 8),
				SpreadAngle = Vector2.new(180, 180), Size = nseq({ { 0, 90, 20 }, { 1, 160, 20 } }),
				Transparency = nseq({ { 0, 1 }, { 0.15, 0.4 }, { 1, 1 } }), Color = ColorSequence.new(ASH), Drag = 0.5,
				Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			})
		end
	end

	local function spawnPuff(te)
		for _, pf in ipairs(puffs) do
			if not pf.alive then
				local a, rr = rng:NextNumber(0, TAU), R * 0.3 * math.sqrt(rng:NextNumber())
				pf.alive = true
				pf.state = 1
				pf.age = 0
				pf.pos = G + Vector3.new(math.cos(a) * rr, 10, math.sin(a) * rr)
				pf.theta = a
				pf.rf = math.sqrt(rng:NextNumber())
				pf.v0 = rng:NextNumber(260, 360) * (te < 90 and 1 or 0.7)
				pf.s0 = rng:NextNumber(55, 85)
				pf.size = pf.s0
				pf.top = NH * rng:NextNumber(0.92, CH / NH)
				pf.layer = rng:NextNumber(-80, 120)
				pf.tint = rng:NextNumber(-0.3, 0.35)
				pf.spreadLife = rng:NextNumber(10, 16)
				pf.fade = 0
				return
			end
		end
	end

	-- umbrella cloud
	local umbrella = {}
	for i = 1, 30 do
		table.insert(umbrella, {
			part = ellipsoid({ Name = "Umbrella", Size = Vector3.new(2, 2, 2), Transparency = 1, Parent = fx }),
			theta = rng:NextNumber(0, TAU), frac = i <= 5 and rng:NextNumber(0, 0.2) or rng:NextNumber(0.3, 0.9),
			w = rng:NextNumber(0.5, 0.8), th = rng:NextNumber(0, 1), dy = rng:NextNumber(-70, 90), tint = rng:NextNumber(-0.15, 0.3),
		})
	end
	local edge = {}
	for i = 1, 40 do
		table.insert(edge, {
			part = ball({ Name = "UmbrellaEdge", Transparency = 1, Parent = fx }),
			theta = (i - 1) / 40 * TAU + rng:NextNumber(-0.05, 0.05), reach = rng:NextNumber(0.94, 1.04),
			scale = rng:NextNumber(0.75, 1.25), dy = rng:NextNumber(-50, 60), tint = rng:NextNumber(-0.15, 0.3), seed = rng:NextNumber(0, 50),
		})
	end
	local overshoot = ellipsoid({ Name = "OvershootDome", Size = Vector3.new(2, 2, 2), Transparency = 1, Parent = fx })

	-- shock front of the opening blast
	local shockSphere = ball({ Name = "BlastFront", Size = uniform(2), CFrame = CFrame.new(G), Material = Enum.Material.ForceField,
		Color = rgb(235, 228, 220), Transparency = 1, Parent = fx })
	local NR = 44
	local ring = {}
	for i = 1, NR do
		local seg = part({ Name = "BlastRing", Size = Vector3.one, Color = rgb(150, 130, 110), Transparency = 1, Parent = fx })
		ring[i] = { part = seg, theta = (i - 1) / NR * TAU, jitter = rng:NextNumber(0.8, 1.25) }
		if i % 4 == 0 then
			emitter(seg, {
				Texture = SMOKE, Rate = 0, Lifetime = NumberRange.new(2.5, 4.5), Speed = NumberRange.new(4, 12),
				EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(40, 40), Size = nseq({ { 0, 22, 6 }, { 1, 60, 12 } }),
				Transparency = nseq({ { 0, 0.45 }, { 1, 1 } }), Color = ColorSequence.new(rgb(140, 122, 104)), Drag = 0.8,
			})
		end
	end

	-- pyroclastic density currents: four rows from the billowing front to the rising co-ignimbrite ash behind it
	local pyroRows = {
		{ frac = 1.0, n = 44, size = 110, y = 0.35, tr = 0.05 },
		{ frac = 0.82, n = 36, size = 170, y = 0.5, tr = 0.18 },
		{ frac = 0.6, n = 28, size = 230, y = 0.8, tr = 0.35 },
		{ frac = 0.35, n = 20, size = 300, y = 1.2, tr = 0.5 },
	}
	local pyro = {}
	for ri, row in ipairs(pyroRows) do
		for i = 1, row.n do
			local p = ball({ Name = "Pyroclastic", Transparency = 1, Parent = fx })
			table.insert(pyro, { part = p, row = row, ri = ri, theta = (i - 1) / row.n * TAU + rng:NextNumber(-0.06, 0.06),
				reach = rng:NextNumber(0.9, 1.08), scale = rng:NextNumber(0.75, 1.3), tint = rng:NextNumber(-0.2, 0.3), seed = rng:NextNumber(0, 50) })
			if ri == 1 and i % 4 == 0 then
				emitter(p, {
					Texture = SMOKE, Rate = 0, Lifetime = NumberRange.new(4, 7), Speed = NumberRange.new(10, 30),
					EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(50, 50), Size = nseq({ { 0, 80, 15 }, { 1, 170, 20 } }),
					Transparency = nseq({ { 0, 0.35 }, { 1, 1 } }), Color = ColorSequence.new(PYRO), Drag = 0.6,
					Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
				})
			end
		end
	end

	-- global grading for the volcanic winter
	local cc = make("ColorCorrectionEffect", { Name = "VolcanoCC", Parent = Lighting })
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	local createdAtmo = atmo == nil
	if createdAtmo then
		atmo = make("Atmosphere", { Density = 0, Offset = 0, Haze = 0, Glare = 0, Parent = Lighting })
	end
	local savedAtmo = { Density = atmo.Density, Offset = atmo.Offset, Haze = atmo.Haze, Glare = atmo.Glare, Color = atmo.Color, Decay = atmo.Decay }
	local savedLight = { OutdoorAmbient = Lighting.OutdoorAmbient, Ambient = Lighting.Ambient, ExposureCompensation = Lighting.ExposureCompensation }

	------------------------------------------------------------------
	-- state
	------------------------------------------------------------------
	local bombs = {}
	local flows = {}
	local hazes = {}
	local doomed = {}
	local viewers = {}
	local onsetDone, pyroDone, collapseDone, ashDone, coatDone, flowsDone = false, false, false, false, false, false
	local phreatic1, phreatic2 = false, false
	local spawnAcc, bombAcc, bombsLaunched = 0, 0, 0
	local nextRumble, nextLava, nextSlow = 0, 0, 0
	local lastHud = 0
	local acc = 0
	local t0 = os.clock()

	local function pyroR(tau)
		local u = clamp01(tau / PT)
		return PR * (1 - (1 - u) ^ 1.4)
	end

	------------------------------------------------------------------
	-- one-shot events
	------------------------------------------------------------------
	local function onset()
		ventGlow.Transparency = 0.08
		ventLight.Brightness = 18
		jetFire.Rate = 70
		jetAsh.Rate = 60
		jetEjecta.Rate = 160
		shockSphere.Transparency = 0.4
		for _, s in ipairs(ring) do
			local e = s.part:FindFirstChildOfClass("ParticleEmitter")
			if e then
				e.Rate = 14
			end
		end
		for _, v in ipairs(vents) do
			v.Rate = 0
		end

		for _, plr in ipairs(Players:GetPlayers()) do
			local p = rootPos(plr)
			local h = hud(plr)
			if p and h then
				local d = flat(p - G).Magnitude
				local k = fall(d)
				viewers[plr] = { d = d }
				h.flash.BackgroundTransparency = 1 - 0.55 * k
				tween(h.flash, 1.2, { BackgroundTransparency = 1 })
				task.delay(d / CONFIG.SoundSpeed, function()
					addShake(plr, 1.6 * k)
					for i = 0, 4 do
						task.delay(i * 0.09, boomFor, plr)
					end
					if CONFIG.RumbleSound ~= "" then
						local r = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
						if r then
							local s = make("Sound", { SoundId = CONFIG.RumbleSound, Volume = 3, PlaybackSpeed = 0.6, RollOffMaxDistance = 80, Parent = r })
							s:Play()
							Debris:AddItem(s, 60)
						end
					end
				end)
			end
		end

		-- volcanic winter
		tween(Lighting, 0.4, { OutdoorAmbient = rgb(255, 190, 140) })
		task.delay(0.5, function()
			tween(Lighting, 60, { OutdoorAmbient = rgb(78, 68, 60), Ambient = rgb(60, 52, 48),
				ExposureCompensation = savedLight.ExposureCompensation - 1.1 }, Enum.EasingStyle.Sine)
		end)
		tween(atmo, 60, { Density = 0.62, Offset = 0.1, Haze = 5, Glare = 0, Color = rgb(128, 116, 104), Decay = rgb(74, 64, 58) },
			Enum.EasingStyle.Sine)
		tween(cc, 60, { Saturation = -0.4, Contrast = 0.12, TintColor = rgb(228, 212, 192), Brightness = -0.04 }, Enum.EasingStyle.Sine)

		-- the opening air blast
		local BR = CONFIG.BlastRadius
		sweep(G, BR, function(tt)
			return BR * (1 - (1 - clamp01(tt / 4)) ^ 1.6)
		end, function(p, d)
			local hum, m = humanoidOf(p)
			local k = 1 - d / BR
			if hum then
				if CONFIG.OwnerImmune and m == owner.Character then
					return
				end
				if d < BR * 0.45 then
					hum.Health = 0
				else
					hum:TakeDamage(70 * k)
				end
				if not p.Anchored then
					local dir = flat(p.Position - G)
					dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.xAxis
					p.AssemblyLinearVelocity = dir * 200 * k + Vector3.new(0, 60 * k, 0)
				end
				return
			end
			if p.Material == Enum.Material.Glass and CONFIG.DestroyMap then
				p:Destroy()
				return
			end
			if d < BR * 0.8 then
				local dir = flat(p.Position - G)
				dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.xAxis
				breakLoose(p, dir * 280 * k + Vector3.new(0, 90 * k, 0))
			end
		end)
	end

	local function startPyro()
		for _, b in ipairs(pyro) do
			local e = b.part:FindFirstChildOfClass("ParticleEmitter")
			if e then
				e.Rate = 7
			end
		end
		for plr in pairs(viewers) do
			local p = rootPos(plr)
			if p then
				local d = flat(p - G).Magnitude
				task.delay(d / CONFIG.SoundSpeed, function()
					addShake(plr, 0.9 * fall(d))
					boomFor(plr)
				end)
			end
		end
		sweep(G, PR, pyroR, function(p, d)
			local hum, m = humanoidOf(p)
			if hum then
				if not (CONFIG.OwnerImmune and m == owner.Character) and hum.Health > 0 then
					hum.Health = 0
					charModel(m, rgb(70, 62, 56))
				end
				return
			end
			local k = 1 - d / PR
			p.Color = p.Color:Lerp(ASHFALL:Lerp(SOOT, 0.4), 0.4 + 0.5 * k)
			if p.Material == Enum.Material.Glass and CONFIG.DestroyMap then
				p:Destroy()
				return
			end
			ignite(p, 0.06)
			if d < PR * 0.7 then
				local dir = flat(p.Position - G)
				dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.xAxis
				breakLoose(p, dir * (60 + 120 * k) + Vector3.new(0, 25, 0))
			end
		end)
	end

	local function collapse()
		for plr in pairs(viewers) do
			local p = rootPos(plr)
			if p then
				local d = flat(p - G).Magnitude
				task.delay(d / CONFIG.SoundSpeed, function()
					addShake(plr, 1.4 * fall(d))
					for i = 0, 2 do
						task.delay(i * 0.2, boomFor, plr)
					end
				end)
			end
		end
		harmArea(G, R, owner, rgb(40, 30, 26))
		if CONFIG.UseTerrain then
			pcall(function()
				local terrain = workspace.Terrain
				terrain:FillCylinder(CFrame.new(G - Vector3.new(0, 70, 0)), 150, R, Enum.Material.Air)
				terrain:FillCylinder(CFrame.new(G - Vector3.new(0, 140, 0)), 12, R * 0.92, Enum.Material.CrackedLava)
				terrain:FillCylinder(CFrame.new(G - Vector3.new(0, 151, 0)), 10, R * 0.92, Enum.Material.Basalt)
			end)
		end
		-- the caldera floor swallows everything inside the ring fault
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { fxFolder }
		params.MaxParts = 1500
		for _, p in ipairs(workspace:GetPartBoundsInRadius(G, R, params)) do
			if not p:IsA("Terrain") and flat(p.Position - G).Magnitude < R * 0.97 and p.Size.Magnitude <= CONFIG.MaxBreakableSize
				and not humanoidOf(p) and CONFIG.DestroyMap then
				p.Anchored = true
				p.CanCollide = false
				tween(p, rng:NextNumber(1.5, 3.5), { CFrame = p.CFrame - Vector3.new(0, rng:NextNumber(60, 140), 0), Transparency = 1 },
					Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				Debris:AddItem(p, 4)
			end
		end
		-- a lava lake on part-built maps (terrain maps get a real hole + lava from above)
		if not groundIsTerrain then
			local lake = part({ Name = "LavaLake", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, R * 1.9, R * 1.9),
				CFrame = CFrame.new(G + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.pi / 2), Material = Enum.Material.CrackedLava,
				Color = rgb(70, 40, 32), Parent = deposits })
			make("PointLight", { Range = 60, Brightness = 6, Color = rgb(255, 120, 40), Parent = lake })
			local lakeGlow = part({ Name = "LakeGlow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, R * 1.3, R * 1.3),
				CFrame = CFrame.new(G + Vector3.new(0, 1.0, 0)) * CFrame.Angles(0, 0, math.pi / 2), Material = Enum.Material.Neon,
				Color = HOT, Transparency = 0.35, Parent = deposits })
			TweenService:Create(lakeGlow, TweenInfo.new(2.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Transparency = 0.6, Color = rgb(255, 80, 20) }):Play()
		end
		-- ring-fault scarps: tilted blocks of crust rising around the rim
		for i = 1, 40 do
			local a = i / 40 * TAU + rng:NextNumber(-0.04, 0.04)
			local base = groundAt(G + Vector3.new(math.cos(a) * R * 1.04, 0, math.sin(a) * R * 1.04))
			local size = Vector3.new(rng:NextNumber(30, 50), rng:NextNumber(30, 70), rng:NextNumber(22, 40))
			local final = CFrame.lookAt(base, Vector3.new(G.X, base.Y, G.Z)) * CFrame.new(0, size.Y * 0.3, 0)
				* CFrame.Angles(math.rad(rng:NextNumber(-35, -15)), 0, math.rad(rng:NextNumber(-8, 8)))
			local block = part({ Name = "Scarp", Size = size, CFrame = final - Vector3.new(0, size.Y, 0), CanCollide = true, CastShadow = true,
				Material = rng:NextNumber() < 0.5 and Enum.Material.Basalt or Enum.Material.Slate, Color = rgb(58, 52, 48):Lerp(rgb(95, 82, 70), rng:NextNumber()),
				Parent = deposits })
			tween(block, rng:NextNumber(2, 4), { CFrame = final }, Enum.EasingStyle.Quart)
		end
		-- rubble tumbling in
		for _ = 1, 30 do
			local a = rng:NextNumber(0, TAU)
			local rock = Instance.new("Part")
			rock.Size = Vector3.new(rng:NextNumber(5, 16), rng:NextNumber(5, 14), rng:NextNumber(5, 16))
			rock.CFrame = CFrame.new(G + Vector3.new(math.cos(a) * R * 1.05, 40, math.sin(a) * R * 1.05))
				* CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
			rock.Material = Enum.Material.Basalt
			rock.Color = rgb(60, 54, 50)
			rock.Parent = deposits
			rock.AssemblyLinearVelocity = flat(G - rock.Position).Unit * rng:NextNumber(20, 60)
			Debris:AddItem(rock, 40)
		end
	end

	local function startAshfall()
		local span = 2048
		for ix = -1, 1, 2 do
			for iz = -1, 1, 2 do
				local sky = part({ Name = "Ashfall", Size = Vector3.new(span, 1, span), Transparency = 1,
					CFrame = CFrame.new(G + Vector3.new(ix * span / 2, 700, iz * span / 2)), Parent = fx })
				emitter(sky, {
					Texture = SPARK, Rate = 220, Lifetime = NumberRange.new(16, 22), Speed = NumberRange.new(0, 3),
					Size = nseq({ { 0, 1.1, 0.5 }, { 1, 0.8, 0.4 } }), Color = ColorSequence.new(rgb(120, 115, 110)),
					Acceleration = wind * 0.2 + Vector3.new(0, -12, 0), RotSpeed = NumberRange.new(-200, 200),
					Transparency = nseq({ { 0, 1 }, { 0.1, 0.15 }, { 0.9, 0.25 }, { 1, 1 } }),
					Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
				})
			end
		end
	end

	local function hazeFor(plr, pos)
		local h = hazes[plr]
		if h and h.Parent then
			return h
		end
		h = part({ Name = "AshHaze", Size = Vector3.new(240, 80, 240), Transparency = 1, CFrame = CFrame.new(pos), Parent = fx })
		emitter(h, {
			Texture = SPARK, Rate = 140, Lifetime = NumberRange.new(4, 7), Speed = NumberRange.new(0, 2),
			Size = nseq({ { 0, 0.45 }, { 1, 0.3 } }), Color = ColorSequence.new(rgb(118, 112, 106)),
			Acceleration = wind * 0.15 + Vector3.new(0, -8, 0), RotSpeed = NumberRange.new(-200, 200),
			Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		})
		emitter(h, {
			Texture = SMOKE, Rate = 5, Lifetime = NumberRange.new(6, 10), Speed = NumberRange.new(0, 4),
			Size = nseq({ { 0, 30, 8 }, { 1, 55, 10 } }), Color = ColorSequence.new(rgb(130, 122, 114)),
			Transparency = nseq({ { 0, 1 }, { 0.3, 0.82 }, { 1, 1 } }), Acceleration = wind * 0.2,
			Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		})
		hazes[plr] = h
		return h
	end

	local function coatInAsh()
		local AR = CONFIG.AshRadius
		sweep(G, AR, function(tt)
			return AR * clamp01(tt / 90)
		end, function(p, d)
			if humanoidOf(p) then
				return
			end
			local amount = 0.15 + 0.6 * (1 - d / AR)
			p.Color = p.Color:Lerp(ASHFALL, amount)
			if amount > 0.35 and (p.Material == Enum.Material.Grass or p.Material == Enum.Material.LeafyGrass) then
				p.Material = Enum.Material.Sand
			end
		end)
		if CONFIG.UseTerrain then
			pcall(function()
				local r = 600
				local region = Region3.new(G - Vector3.new(r, 60, r), G + Vector3.new(r, 60, r)):ExpandToGrid(4)
				local terrain = workspace.Terrain
				terrain:ReplaceMaterial(region, 4, Enum.Material.Grass, Enum.Material.Slate)
				terrain:ReplaceMaterial(region, 4, Enum.Material.LeafyGrass, Enum.Material.Slate)
				terrain:ReplaceMaterial(region, 4, Enum.Material.Snow, Enum.Material.Slate)
			end)
		end
	end

	local function launchBomb()
		local a = rng:NextNumber(0, TAU)
		local elev = math.rad(rng:NextNumber(48, 82))
		local range = rng:NextNumber(120, CONFIG.BombRange)
		local speed = math.sqrt(range * GRAVITY / math.max(math.sin(2 * elev), 0.2))
		local s = rng:NextNumber(3, 12)
		local rp = R * 0.3 * math.sqrt(rng:NextNumber())
		local ra = rng:NextNumber(0, TAU)
		local pos = G + Vector3.new(math.cos(ra) * rp, 15, math.sin(ra) * rp)
		local rock = part({ Name = "VolcanicBomb", Size = Vector3.new(s, s * rng:NextNumber(0.6, 1), s * rng:NextNumber(0.6, 1)),
			CFrame = CFrame.new(pos), Material = Enum.Material.CrackedLava, Color = rgb(75, 45, 36), CastShadow = true, Parent = fx })
		local smokeTrail = emitter(rock, {
			Texture = SMOKE, Rate = 30, Lifetime = NumberRange.new(2, 3.5), Speed = NumberRange.new(0, 2),
			Size = nseq({ { 0, s * 1.2 }, { 1, s * 5 } }), Transparency = nseq({ { 0, 0.3 }, { 1, 1 } }),
			Color = ColorSequence.new(rgb(70, 64, 60)), LightInfluence = 1,
		})
		local fireTrail = emitter(rock, {
			Texture = FIRE, Rate = 25, Lifetime = NumberRange.new(0.3, 0.6), Speed = NumberRange.new(0, 2),
			Size = nseq({ { 0, s * 1.1 }, { 1, s * 0.2 } }), LightEmission = 1, LightInfluence = 0,
			Color = cseq({ { 0, rgb(255, 220, 140) }, { 1, rgb(230, 70, 20) } }),
		})
		local light = make("PointLight", { Range = 16, Brightness = 4, Color = rgb(255, 120, 40), Parent = rock })
		table.insert(bombs, {
			part = rock, pos = pos, vel = Vector3.new(math.cos(a) * math.cos(elev), math.sin(elev), math.sin(a) * math.cos(elev)) * speed,
			spin = Vector3.new(rng:NextNumber(-4, 4), rng:NextNumber(-4, 4), rng:NextNumber(-4, 4)), age = 0, size = s,
			smokeTrail = smokeTrail, fireTrail = fireTrail, light = light, live = true,
		})
	end

	local function landBomb(b, hit)
		b.live = false
		local p = b.part
		p.CFrame = CFrame.new(hit.Position + hit.Normal * b.size * 0.3) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
		p.CanCollide = true
		p.Parent = deposits
		b.fireTrail.Enabled = false
		b.smokeTrail.Rate = 6
		b.smokeTrail.Speed = NumberRange.new(4, 10)
		b.smokeTrail.EmissionDirection = Enum.NormalId.Top
		local dust = part({ Name = "Impact", Size = Vector3.new(b.size * 2, 1, b.size * 2), Transparency = 1, CFrame = CFrame.new(hit.Position), Parent = fx })
		local burst = emitter(dust, {
			Texture = SMOKE, Rate = 0, Lifetime = NumberRange.new(1.5, 3), Speed = NumberRange.new(20, 60),
			SpreadAngle = Vector2.new(60, 60), EmissionDirection = Enum.NormalId.Top, Size = nseq({ { 0, b.size, 2 }, { 1, b.size * 5, 4 } }),
			Transparency = nseq({ { 0, 0.25 }, { 1, 1 } }), Color = ColorSequence.new(rgb(120, 106, 92)), Drag = 1.5,
		})
		burst:Emit(25)
		Debris:AddItem(dust, 4)
		harmArea(hit.Position, b.size * 2.5, owner, rgb(40, 30, 26))
		local inst = hit.Instance
		if inst and inst:IsA("BasePart") and not inst:IsA("Terrain") and not inst:IsDescendantOf(fxFolder) and not humanoidOf(inst) then
			inst.Color = inst.Color:Lerp(SOOT, 0.5)
			ignite(inst, 0.35)
			breakLoose(inst, b.vel * 0.15)
		end
		task.delay(14, function()
			if p.Parent then
				p.Material = Enum.Material.Basalt
				p.Color = rgb(52, 46, 42)
				b.light:Destroy()
			end
		end)
		task.delay(30, function()
			b.smokeTrail:Destroy()
		end)
	end

	local function startFlows()
		for i = 1, CONFIG.LavaFlows do
			local a = i / CONFIG.LavaFlows * TAU + rng:NextNumber(-0.2, 0.2)
			local start = groundAt(G + Vector3.new(math.cos(a) * R * 1.03, 0, math.sin(a) * R * 1.03))
			local w = rng:NextNumber(24, 40)
			local front = ellipsoid({ Name = "LavaFront", Size = Vector3.new(w, 7, w * 0.8), CFrame = CFrame.new(start), Material = Enum.Material.Neon,
				Color = rgb(255, 130, 40), Parent = fx })
			make("PointLight", { Range = 40, Brightness = 6, Color = rgb(255, 110, 40), Parent = front })
			emitter(front, {
				Texture = SMOKE, Rate = 8, Lifetime = NumberRange.new(3, 5), Speed = NumberRange.new(8, 20),
				EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(30, 30), Size = nseq({ { 0, 10, 3 }, { 1, 40, 6 } }),
				Transparency = nseq({ { 0, 0.5 }, { 1, 1 } }), Color = ColorSequence.new(rgb(200, 196, 190)), Acceleration = wind * 0.3,
			})
			emitter(front, {
				Texture = FIRE, Rate = 14, Lifetime = NumberRange.new(0.5, 1), Speed = NumberRange.new(2, 8),
				EmissionDirection = Enum.NormalId.Top, Size = nseq({ { 0, w * 0.4 }, { 1, w * 0.1 } }), LightEmission = 1, LightInfluence = 0,
				Color = cseq({ { 0, rgb(255, 200, 110) }, { 1, rgb(200, 50, 10) } }),
			})
			table.insert(flows, { heading = a, pos = start, len = 0, lastSeg = 0, lastPos = start, w = w, front = front,
				maxLen = CONFIG.LavaLength * rng:NextNumber(0.55, 1), speed = rng:NextNumber(0.7, 1.3), seed = rng:NextNumber(0, 100),
				segs = {}, active = true })
		end
	end

	------------------------------------------------------------------
	-- main loop (30 Hz)
	------------------------------------------------------------------
	local total = P + CONFIG.Duration
	local conn
	conn = RunService.Heartbeat:Connect(function(rawDt)
		acc += rawDt
		if acc < 1 / 30 then
			return
		end
		local dt = math.min(acc, 0.2)
		acc = 0
		local t = os.clock() - t0
		local te = t - P
		if t > total + 25 then
			conn:Disconnect()
			return
		end

		local ok, err = pcall(function()
			local fadeOut = smooth((te - CONFIG.Duration) / 20)

			-------------------------------------------------- precursor
			for _, c in ipairs(cracks) do
				if t >= c.reveal then
					local age = t - c.reveal
					local width = c.ring and (te < 0 and 0.8 + 2.4 * smooth(age / 4) or 3.2 + 12 * smooth(te / 6))
						or (te < 0 and 0.6 + 1.4 * smooth(age / 4) or 2 + 4 * smooth(te / 8))
					local size = c.part.Size
					c.part.Size = Vector3.new(width * (1 - 0.6 * smooth((te - 120) / 60)), size.Y, size.Z)
					local flick = 0.5 + 0.5 * math.noise(t * 2, c.seed)
					c.part.Color = rgb(150, 25, 10):Lerp(rgb(255, 160, 60), flick)
					c.part.Transparency = smooth(1 - age * 2) + (te > 120 and smooth((te - 120) / 60) * 0.9 or 0)
				end
			end
			if te < 0 then
				local k = t / P
				for _, v in ipairs(vents) do
					v.Rate = 26 * smooth(k * 1.3)
				end
				if not phreatic1 and t > P - 5 then
					phreatic1 = true
					phreatic:Emit(70)
				end
				if not phreatic2 and t > P - 2.4 then
					phreatic2 = true
					phreatic:Emit(110)
				end
				for _, plr in ipairs(Players:GetPlayers()) do
					local p = rootPos(plr)
					if p then
						addShake(plr, (0.08 + 0.7 * k * k) * fall(flat(p - G).Magnitude))
					end
				end
			elseif not onsetDone then
				onsetDone = true
				onset()
			end

			if te >= 0 then
				-------------------------------------------------- blast front
				if te < 5 then
					local BR = CONFIG.BlastRadius
					local r = BR * 1.4 * (1 - (1 - clamp01(te / 4)) ^ 1.6)
					shockSphere.Size = uniform(r * 2)
					shockSphere.Transparency = 0.4 + 0.6 * smooth(te / 4)
					local h = (8 + 40 * smooth(te / 1.5)) * (1 - 0.6 * smooth(te / 4))
					local parts, cfs = {}, {}
					for i, s in ipairs(ring) do
						local dir = Vector3.new(math.cos(s.theta), 0, math.sin(s.theta))
						local tangent = Vector3.new(-math.sin(s.theta), 0, math.cos(s.theta))
						local hh = h * s.jitter
						local pos = G + dir * r + Vector3.new(0, hh * 0.5 - 2, 0)
						s.part.Size = cap(Vector3.new(10 + r * 0.03, hh, TAU * math.max(r, 1) / NR * 1.12))
						s.part.Transparency = 0.15 + 0.85 * smooth((te - 2) / 2.5)
						parts[i] = s.part
						cfs[i] = CFrame.lookAt(pos, pos + tangent)
					end
					workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
				elseif shockSphere.Parent then
					shockSphere:Destroy()
					for _, s in ipairs(ring) do
						s.part:Destroy()
					end
				end

				-------------------------------------------------- vent & fountains
				local intensity = (te < 90 and 1 or math.exp(-(te - 90) / 40)) * (1 - fadeOut)
				ventGlow.Transparency = 1 - 0.92 * intensity
				ventGlow.Color = HOT:Lerp(rgb(255, 200, 120), 0.5 + 0.5 * math.noise(t * 3, 4.2))
				ventLight.Brightness = 18 * intensity
				jetFire.Rate = 70 * intensity
				jetAsh.Rate = 60 * intensity
				jetEjecta.Rate = 160 * intensity * math.exp(-te / 60)
				local fountainOn = smooth((te - 2) / 3) * (te < 140 and 1 or math.exp(-(te - 140) / 20)) * (1 - fadeOut)
				for i, f in ipairs(fountains) do
					local pulse = 0.6 + 0.4 * math.noise(t * 0.7, i * 3.3)
					f.drops.Rate = 70 * fountainOn * pulse
					f.glow.Rate = 25 * fountainOn
					f.light.Brightness = 8 * fountainOn * pulse
				end

				-------------------------------------------------- plume
				spawnAcc += dt * 13 * intensity
				while spawnAcc >= 1 do
					spawnAcc -= 1
					spawnPuff(te)
				end
				local cfs = table.create(NPUFF)
				for i, pf in ipairs(puffs) do
					if pf.alive then
						pf.age += dt
						local pos = pf.pos
						local h = pos.Y - gy
						local axis = Vector3.new(G.X, pos.Y, G.Z) + wind.Unit * (h * 0.22 * smooth(h / NH))
						local out = flat(pos - axis)
						local od = out.Magnitude
						out = od > 0.5 and out / od or Vector3.new(math.cos(pf.theta), 0, math.sin(pf.theta))
						if pf.state == 1 then
							local vy = math.max(45, pf.v0 * math.exp(-h / 650))
							local colR = R * 0.35 + h * 0.16
							local desired = axis + out * colR * pf.rf
							pos += flat(desired - pos) * math.min(1, dt * 2) + Vector3.new(0, vy * dt, 0)
							pf.size = pf.s0 + h * 0.2
							if h >= pf.top then
								pf.state = 2
								pf.vr = rng:NextNumber(80, 140)
								pf.spread = 0
							end
						else
							local radial = flat(pos - G)
							local rd = radial.Magnitude
							radial = rd > 0.5 and radial / rd or out
							pf.vr = math.max(12, pf.vr * math.exp(-dt / 25))
							local settle = (NH + pf.layer - h) * math.min(1, dt * 0.5)
							pos += radial * pf.vr * dt + Vector3.new(0, settle, 0) + wind * dt * 0.4
							pf.size += 7 * dt
							pf.spread += dt
							if pf.spread > pf.spreadLife or rd > UR then
								pf.fade += dt / 3
							end
						end
						pf.pos = pos
						local glow = math.exp(-h / 170) * intensity
						local base = tinted(ASH, pf.tint)
						if pf.state == 2 then
							base = base:Lerp(PALE, 0.15)
						end
						pf.part.Color = base:Lerp(HOT, glow)
						pf.part.Size = uniform(pf.size)
						pf.part.Transparency = math.max(0.06, 0.6 - pf.age * 2) + (1 - 0.06) * clamp01(pf.fade)
						cfs[i] = CFrame.new(pos)
						if pf.fade >= 1 then
							pf.alive = false
							pf.part.Transparency = 1
						end
					else
						cfs[i] = pf.part.CFrame
					end
				end
				workspace:BulkMoveTo(puffParts, cfs, Enum.BulkMoveMode.FireCFrameChanged)

				-------------------------------------------------- umbrella
				local ue = math.max(te - 8, 0)
				local ur = UR * (1 - math.exp(-ue / 55))
				local uAppear = smooth(ue / 6) * (1 - fadeOut)
				if ur > 1 then
					local parts, ucfs = {}, {}
					for _, u in ipairs(umbrella) do
						local th = u.theta + te * 0.004
						local rr = ur * u.frac
						local w = math.max(200, ur * u.w)
						u.part.Size = cap(Vector3.new(w, 140 + 140 * u.th, w))
						u.part.Color = tinted(rgb(96, 90, 86), u.tint)
						u.part.Transparency = 1 - 0.88 * uAppear
						table.insert(parts, u.part)
						table.insert(ucfs, CFrame.new(G + wind * ue * 0.15 + Vector3.new(math.cos(th) * rr, NH + u.dy, math.sin(th) * rr)))
					end
					for _, e in ipairs(edge) do
						local rr = ur * e.reach
						local s = (90 + 220 * smooth(ue / 30)) * e.scale * (1 + 0.15 * math.noise(t * 0.3, e.seed))
						e.part.Size = uniform(s)
						e.part.Color = tinted(rgb(110, 104, 98), e.tint)
						e.part.Transparency = 1 - 0.9 * uAppear
						table.insert(parts, e.part)
						table.insert(ucfs, CFrame.new(G + wind * ue * 0.15 + Vector3.new(math.cos(e.theta) * rr, NH + e.dy, math.sin(e.theta) * rr)))
					end
					local od = math.min(2048, 300 + ur * 0.5)
					overshoot.Size = cap(Vector3.new(od, 420, od))
					overshoot.Color = rgb(104, 98, 94)
					overshoot.Transparency = 1 - 0.9 * uAppear
					table.insert(parts, overshoot)
					table.insert(ucfs, CFrame.new(G + wind.Unit * NH * 0.2 + Vector3.new(0, NH + 200, 0)))
					workspace:BulkMoveTo(parts, ucfs, Enum.BulkMoveMode.FireCFrameChanged)
				end

				-------------------------------------------------- volcanic lightning ("dirty thunderstorm")
				if te < 160 and rng:NextNumber() < dt * (4 * math.exp(-te / 45) + 0.6) * (1 - fadeOut) then
					local h1 = rng:NextNumber(150, NH)
					local axis1 = G + wind.Unit * (h1 * 0.22 * smooth(h1 / NH)) + Vector3.new(0, h1, 0)
					local colR = R * 0.35 + h1 * 0.16
					local a = axis1 + Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * colR * 0.6
					local roll = rng:NextNumber()
					local b
					if roll < 0.55 then
						b = a + Vector3.new(rng:NextNumber(-1, 1) * colR, rng:NextNumber(-350, 350), rng:NextNumber(-1, 1) * colR)
					elseif roll < 0.8 and ur > 200 then
						local aa, rr = rng:NextNumber(0, TAU), ur * rng:NextNumber(0.1, 0.6)
						b = G + Vector3.new(math.cos(aa) * rr, NH - 60, math.sin(aa) * rr)
					else
						local aa, rr = rng:NextNumber(0, TAU), R * rng:NextNumber(0.5, 2.5)
						b = Vector3.new(G.X + math.cos(aa) * rr, gy, G.Z + math.sin(aa) * rr)
					end
					bolt(fx, a, b, rgb(225, 212, 255))
					for plr in pairs(viewers) do
						local p = rootPos(plr)
						if p and (p - a).Magnitude < 900 and rng:NextNumber() < 0.35 then
							task.delay((p - a).Magnitude / CONFIG.SoundSpeed, boomFor, plr)
						end
					end
				end

				-------------------------------------------------- ballistic bombs
				if te < 25 and bombsLaunched < CONFIG.Bombs then
					bombAcc += dt * CONFIG.Bombs / 22
					while bombAcc >= 1 and bombsLaunched < CONFIG.Bombs do
						bombAcc -= 1
						bombsLaunched += 1
						launchBomb()
					end
				end
				local rp = RaycastParams.new()
				rp.FilterType = Enum.RaycastFilterType.Exclude
				rp.FilterDescendantsInstances = { fxFolder }
				for i = #bombs, 1, -1 do
					local b = bombs[i]
					if b.live then
						b.age += dt
						b.vel += Vector3.new(0, -GRAVITY * dt, 0)
						local step = b.vel * dt
						local hit = workspace:Raycast(b.pos, step, rp)
						if hit then
							landBomb(b, hit)
							table.remove(bombs, i)
						elseif b.pos.Y < gy - 400 or b.age > 30 then
							b.part:Destroy()
							table.remove(bombs, i)
						else
							b.pos += step
							b.part.CFrame = CFrame.new(b.pos) * CFrame.Angles(b.spin.X * b.age, b.spin.Y * b.age, b.spin.Z * b.age)
						end
					end
				end

				-------------------------------------------------- lava flows
				if not flowsDone and te > 6 then
					flowsDone = true
					startFlows()
				end
				for _, f in ipairs(flows) do
					if f.active then
						f.heading += math.noise(f.seed, f.len * 0.012) * 0.05
						local dir = Vector3.new(math.cos(f.heading), 0, math.sin(f.heading))
						local step = CONFIG.LavaSpeed * f.speed * dt * (1.4 - f.len / f.maxLen)
						f.pos = groundAt(f.pos + dir * step)
						f.len += step
						f.front.CFrame = CFrame.lookAt(f.pos + Vector3.new(0, 1.5, 0), f.pos + Vector3.new(0, 1.5, 0) + dir)
						f.front.Color = rgb(255, 130, 40):Lerp(rgb(255, 200, 110), 0.5 + 0.5 * math.noise(t * 2, f.seed))
						if f.len - f.lastSeg >= 14 then
							local a, b = f.lastPos, f.pos
							local mid = (a + b) / 2
							local seg = part({ Name = "LavaFlow", Size = Vector3.new(f.w * rng:NextNumber(0.85, 1.1), 3, (b - a).Magnitude + 6),
								CFrame = CFrame.lookAt(mid, mid + flat(b - a)) * CFrame.Angles(0, rng:NextNumber(-0.1, 0.1), 0),
								Material = Enum.Material.Neon, Color = rgb(255, 120, 35), CanCollide = true, Parent = deposits })
							table.insert(f.segs, { part = seg, born = t, stage = 0 })
							f.lastSeg = f.len
							f.lastPos = b
						end
						if f.len >= f.maxLen then
							f.active = false
							tween(f.front, 6, { Color = rgb(70, 40, 32) })
							task.delay(6, function()
								f.front.Material = Enum.Material.CrackedLava
							end)
						end
					end
				end
				if t >= nextSlow then
					nextSlow = t + 1
					for _, f in ipairs(flows) do
						for _, s in ipairs(f.segs) do
							local age = t - s.born
							if s.stage == 0 and age > 4 then
								s.stage = 1
								s.part.Material = Enum.Material.CrackedLava
								s.part.Color = rgb(95, 48, 32)
							elseif s.stage == 1 and age > 45 then
								s.stage = 2
								s.part.Material = Enum.Material.Basalt
								s.part.Color = rgb(46, 42, 40)
							end
						end
					end
				end
				if t >= nextLava then
					nextLava = t + 0.25
					for _, f in ipairs(flows) do
						if f.active then
							harmArea(f.pos, f.w * 0.6, owner, rgb(30, 22, 18))
							local params = OverlapParams.new()
							params.FilterType = Enum.RaycastFilterType.Exclude
							params.FilterDescendantsInstances = { fxFolder }
							params.MaxParts = 20
							for _, p in ipairs(workspace:GetPartBoundsInRadius(f.pos, f.w * 0.55, params)) do
								if not p:IsA("Terrain") and not humanoidOf(p) and not doomed[p] then
									if CONFIG.DestroyMap and p.Size.Magnitude <= CONFIG.MaxBreakableSize then
										doomed[p] = true
										p.Anchored = true
										p.Material = Enum.Material.Neon
										p.Color = rgb(255, 120, 40)
										tween(p, 1.5, { Transparency = 1, Color = rgb(60, 20, 10) })
										Debris:AddItem(p, 1.6)
									else
										p.Color = p.Color:Lerp(SOOT, 0.3)
										ignite(p, 0.2)
									end
								end
							end
						end
						-- freshly crusted lava is still deadly to stand on
						for k = math.max(1, #f.segs - 2), #f.segs do
							local s = f.segs[k]
							if s and t - s.born < 20 then
								harmArea(s.part.Position, f.w * 0.5, owner, rgb(30, 22, 18))
							end
						end
					end
				end

				-------------------------------------------------- pyroclastic flows
				local tau = te - PS
				if tau >= 0 then
					if not pyroDone then
						pyroDone = true
						startPyro()
					end
					local rp2 = pyroR(tau)
					local u = clamp01(tau / PT)
					local pyroFade = math.max(smooth((tau - PT) / 25), fadeOut)
					local grow = smooth(tau / 5)
					local parts, pcfs = {}, {}
					for i, b in ipairs(pyro) do
						local row = b.row
						local th = b.theta + math.noise(t * 0.2, b.seed) * 0.03
						local rr = math.max(R * 0.6, rp2 * row.frac * b.reach)
						local size = row.size * (0.4 + 0.6 * grow) * (0.7 + 0.5 * u) * b.scale * (1 + 0.15 * math.noise(t * 0.5, b.seed))
						local lift = row.y * size + math.noise(t * 0.4, b.seed + 9) * 15 + (b.ri >= 3 and tau * 4 * (b.ri - 2) or 0)
						b.part.Size = uniform(size)
						b.part.Color = tinted(PYRO, b.tint):Lerp(rgb(200, 95, 55), math.exp(-tau / 6) * (b.ri == 1 and 0.4 or 0.15))
						b.part.Transparency = row.tr + (1 - row.tr) * math.max(pyroFade, 1 - smooth(tau / 1.5))
						parts[i] = b.part
						pcfs[i] = CFrame.new(G + Vector3.new(math.cos(th) * rr, lift, math.sin(th) * rr))
						if pyroFade > 0.5 then
							local e = b.part:FindFirstChildOfClass("ParticleEmitter")
							if e then
								e.Rate = 0
							end
						end
					end
					workspace:BulkMoveTo(parts, pcfs, Enum.BulkMoveMode.FireCFrameChanged)
					-- anyone the current overruns dies, even if they ran into it after the sweep passed
					for _, plr in ipairs(Players:GetPlayers()) do
						local p = rootPos(plr)
						if p and flat(p - G).Magnitude <= rp2 and tau < PT + 5 then
							local c = plr.Character
							local hum = c and c:FindFirstChildOfClass("Humanoid")
							if hum and hum.Health > 0 and not (CONFIG.OwnerImmune and plr == owner) then
								hum.Health = 0
								charModel(c, rgb(70, 62, 56))
							end
						end
					end
				end

				-------------------------------------------------- caldera collapse, ash
				if not collapseDone and te >= CONFIG.CollapseAt then
					collapseDone = true
					collapse()
				end
				if not ashDone and te >= 12 then
					ashDone = true
					startAshfall()
				end
				if not coatDone and te >= 20 then
					coatDone = true
					coatInAsh()
				end
				if ashDone then
					for _, plr in ipairs(Players:GetPlayers()) do
						local p = rootPos(plr)
						if p and flat(p - G).Magnitude < CONFIG.AshRadius * 1.3 then
							local h = hazeFor(plr, p)
							h.CFrame = CFrame.new(p + Vector3.new(0, 30, 0))
						end
					end
				end

				-------------------------------------------------- continuous tremor and rumble
				if t >= nextRumble and te < 120 then
					nextRumble = t + rng:NextNumber(0.8, 1.8)
					for _, plr in ipairs(Players:GetPlayers()) do
						local p = rootPos(plr)
						if p then
							local d = flat(p - G).Magnitude
							addShake(plr, 0.45 * math.exp(-te / 70) * fall(d))
							if d < 2600 and rng:NextNumber() < 0.6 then
								task.delay(d / CONFIG.SoundSpeed, boomFor, plr)
							end
						end
					end
				end
			end

			-------------------------------------------------- HUD
			if t - lastHud > 0.15 then
				lastHud = t
				local blink = (t * 2) % 1 < 0.5
				for _, plr in ipairs(Players:GetPlayers()) do
					local h = hud(plr)
					local p = rootPos(plr)
					if h and p then
						local d = flat(p - G).Magnitude
						h.banner.Visible = te < CONFIG.Duration
						if te < 0 then
							local k = t / P
							h.banner.BackgroundColor3 = rgb(110, 70, 0)
							h.title.Text = "⚠  VOLCANIC UNREST  ⚠"
							h.sub.Text = string.format("Seismic swarm M%.1f · ground uplift +%.1f m · %.1f km from the vent",
								3.2 + 4.6 * k ^ 1.5, 0.4 + 24 * k * k, d * KM)
							h.stroke.Color = blink and rgb(255, 190, 40) or rgb(120, 70, 0)
						else
							h.banner.BackgroundColor3 = rgb(100, 30, 0)
							h.title.Text = "🌋  SUPER-ERUPTION · VEI 9  🌋"
							local column = math.min(te * 150, CH) * KM * 1.35
							local ejecta = 12500 * (1 - math.exp(-te / 70))
							local status
							local tau = te - PS
							if tau < 0 then
								status = "column collapse imminent"
							elseif tau < PT then
								local rp2 = pyroR(tau)
								if d > rp2 then
									status = string.format("pyroclastic flow %.1f km away, %d km/h", (d - rp2) * KM,
										math.floor(120 + 580 * (1 - clamp01(tau / PT)) ^ 0.4))
								else
									status = "pyroclastic flow passed"
								end
							else
								status = string.format("ash cloud %d km wide · volcanic winter", math.floor(UR * (1 - math.exp(-math.max(te - 8, 0) / 55)) * 2 * KM * 4))
							end
							h.sub.Text = string.format("Column %d km · ejecta %d km³ · %s", math.floor(column), math.floor(ejecta), status)
							h.stroke.Color = blink and rgb(255, 120, 30) or rgb(110, 30, 0)
							h.vignette.BackgroundTransparency = 1 - 0.55 * smooth(te / 60) * (1 - fadeOut)
						end
					end
				end
			end
		end)
		if not ok then
			warn("[Supervolcano] " .. tostring(err))
		end
	end)

	------------------------------------------------------------------
	-- wind-down
	------------------------------------------------------------------
	task.delay(total, function()
		for _, d in ipairs(fx:GetDescendants()) do
			if d:IsA("ParticleEmitter") then
				d.Enabled = false
			end
		end
		tween(Lighting, 40, savedLight, Enum.EasingStyle.Sine)
		tween(atmo, 40, savedAtmo, Enum.EasingStyle.Sine)
		tween(cc, 40, { Saturation = 0, Contrast = 0, TintColor = Color3.new(1, 1, 1), Brightness = 0 }, Enum.EasingStyle.Sine)
	end)
	task.delay(total + 26, function()
		fx:Destroy()
		for _, h in pairs(huds) do
			h.banner.Visible = false
			h.vignette.BackgroundTransparency = 1
		end
	end)
	task.delay(total + 42, function()
		cc:Destroy()
		if createdAtmo then
			atmo:Destroy()
		end
	end)
end

------------------------------------------------------------------------------
-- tool
------------------------------------------------------------------------------

local busy = false
local lastUse = -math.huge

local function isOwner(player)
	return string.lower(player.Name) == string.lower(CONFIG.OwnerName)
end

local function start(player, rootCF)
	local look = flat(rootCF.LookVector)
	look = look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
	local hit = groundHit(rootCF.Position + look * CONFIG.TargetDistance)
	local G = hit and hit.Position or (rootCF.Position + look * CONFIG.TargetDistance - Vector3.new(0, 3, 0))
	local groundIsTerrain = hit ~= nil and hit.Instance == workspace.Terrain
	busy = true
	task.delay(CONFIG.PrecursorTime + CONFIG.Duration + 45, function()
		busy = false
	end)
	erupt(player, G, groundIsTerrain)
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
	tool.ToolTip = "Equip to trigger a caldera-forming super-eruption"
	tool.RequiresHandle = false
	tool.CanBeDropped = false
	tool.Equipped:Connect(function()
		local c = tool.Parent
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		task.defer(function()
			if hum and tool.Parent == c then
				hum:UnequipTools()
			end
		end)
		if not isOwner(player) or busy or os.clock() - lastUse < CONFIG.Cooldown then
			return
		end
		local root = c and c:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		lastUse = os.clock()
		local ok, err = pcall(start, player, root.CFrame)
		if not ok then
			warn("[Supervolcano] failed: " .. tostring(err))
			busy = false
		end
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
		task.spawn(giveTool, player)
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayer, p)
end
print("[Supervolcano] loaded — " .. CONFIG.OwnerName .. " has the tool")
