--[[
	TSAR BOMBA — client visuals
	Put this LocalScript in StarterPlayer > StarterPlayerScripts.

	Everything you see is built locally (smooth 60 fps, no network jitter):
	  flash + glare billboard, white-hot fireball with heat-shimmer shell,
	  ground-hugging shock ring and condensation (Wilson) dome, toroidal
	  rolling mushroom cap with glowing underside, dust-sucking stem,
	  base surge, condensation collars and ice cap, lightning,
	  fallout ash, screen flash / bloom / blur, delayed blast-wave arrival
	  with camera shake, wind-blown debris, FOV punch and sound, and a HUD.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("TsarBombaFX")

-- Optional: paste your own audio ids ("rbxassetid://123") for extra punch.
-- With these empty the built-in Roblox explosion sound is layered instead.
local SOUNDS = {
	Boom = "",
	Rumble = "",
	Siren = "",
}

local SOUND_SPEED = 1100 -- studs/s beyond the blast-wave radius
local KM_PER_STUD = 0.035 -- display scale: 1000 studs = 35 km (Tsar Bomba's total-destruction radius)

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

local rng = Random.new()
local TAU = math.pi * 2

------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------

local function clamp01(x)
	return math.clamp(x, 0, 1)
end

local function smooth(x)
	x = clamp01(x)
	return x * x * (3 - 2 * x)
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

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function colorAt(keys, t)
	if t <= keys[1][1] then
		return keys[1][2]
	end
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if t <= b[1] then
			return a[2]:Lerp(b[2], (t - a[1]) / (b[1] - a[1]))
		end
	end
	return keys[#keys][2]
end

-- real nuclear flashes are double-humped: a brief X-ray flash, a dip while the
-- shock front turns opaque, then the long thermal pulse
local function flashCurve(t)
	if t < 0.04 then
		return 1
	elseif t < 0.12 then
		return 1 - 0.65 * smooth((t - 0.04) / 0.08)
	elseif t < 0.45 then
		return 0.35 + 0.65 * smooth((t - 0.12) / 0.33)
	end
	return math.exp(-(t - 0.45) / 2.6)
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

local function fxPart(props)
	props.Anchored = true
	props.CanCollide = false
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
	return fxPart(props)
end

local function ellipsoid(props)
	local p = fxPart(props)
	make("SpecialMesh", { MeshType = Enum.MeshType.Sphere, Parent = p })
	return p
end

local function cap(v)
	return Vector3.new(math.min(v.X, 2048), math.min(v.Y, 2048), math.min(v.Z, 2048))
end

local function uniform(d)
	d = math.clamp(d, 0.05, 2048)
	return Vector3.new(d, d, d)
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

local function smokeEmitter(parent, size0, size1, rate, color)
	return emitter(parent, {
		Texture = SMOKE,
		Rate = rate,
		Lifetime = NumberRange.new(5, 9),
		Speed = NumberRange.new(3, 12),
		SpreadAngle = Vector2.new(180, 180),
		Size = nseq({ { 0, size0, size0 * 0.2 }, { 1, size1, size1 * 0.2 } }),
		Transparency = nseq({ { 0, 1 }, { 0.12, 0.3 }, { 0.7, 0.55 }, { 1, 1 } }),
		Color = ColorSequence.new(color),
		Drag = 0.6,
		Shape = Enum.ParticleEmitterShape.Sphere,
		ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
	})
end

------------------------------------------------------------------------------
-- Camera shake
------------------------------------------------------------------------------

local shake = 0
local seed = rng:NextNumber(0, 1000)

local function addShake(amount)
	shake = math.max(shake, amount)
end

RunService:BindToRenderStep("TsarBombaShake", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if shake < 0.002 then
		return
	end
	local cam = workspace.CurrentCamera
	local t = os.clock() * 16
	local rx = math.noise(t, seed) * shake * 0.07
	local ry = math.noise(t, seed + 17) * shake * 0.07
	local rz = math.noise(t, seed + 41) * shake * 0.035
	local off = Vector3.new(math.noise(t * 1.3, seed + 3), math.noise(t * 1.3, seed + 9), 0) * shake * 0.8
	cam.CFrame = cam.CFrame * CFrame.new(off) * CFrame.Angles(rx, ry, rz)
	shake *= math.exp(-dt * 1.25)
end)

------------------------------------------------------------------------------
-- Sound
------------------------------------------------------------------------------

local function playSound(id, volume, speed, fadeAfter)
	if not id or id == "" then
		return nil
	end
	local s = make("Sound", { SoundId = id, Volume = volume, PlaybackSpeed = speed or 1, Parent = SoundService })
	s:Play()
	s.Ended:Connect(function()
		s:Destroy()
	end)
	if fadeAfter then
		task.delay(fadeAfter, function()
			if s.Parent then
				tween(s, 6, { Volume = 0 })
				task.delay(6.1, function()
					s:Destroy()
				end)
			end
		end)
	end
	return s
end

-- Roblox's built-in explosion sound, fired locally right at the listener
local function engineBoom()
	local cam = workspace.CurrentCamera
	local e = Instance.new("Explosion")
	e.BlastPressure = 0
	e.BlastRadius = 0
	e.DestroyJointRadiusPercent = 0
	e.Visible = false
	e.Position = cam.CFrame.Position
	e.Parent = workspace
	task.delay(4, function()
		e:Destroy()
	end)
end

------------------------------------------------------------------------------
-- HUD
------------------------------------------------------------------------------

local gui = make("ScreenGui", { Name = "TsarBombaHUD", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 50,
	Parent = player:WaitForChild("PlayerGui") })
local flashFrame = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 20, Parent = gui })
local vignette = make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(255, 120, 40),
	BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 19, Parent = gui })
make("UIGradient", { Transparency = nseq({ { 0, 0 }, { 0.25, 0.85 }, { 0.75, 0.85 }, { 1, 0 } }), Parent = vignette })

local banner = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 56),
	Size = UDim2.fromOffset(580, 78), BackgroundColor3 = rgb(110, 0, 0), BackgroundTransparency = 0.2,
	Visible = false, ZIndex = 30, Parent = gui })
make("UICorner", { CornerRadius = UDim.new(0, 10), Parent = banner })
local bannerStroke = make("UIStroke", { Color = rgb(255, 60, 40), Thickness = 2, Parent = banner })
local bannerTitle = make("TextLabel", { Size = UDim2.new(1, -20, 0, 34), Position = UDim2.fromOffset(10, 6),
	BackgroundTransparency = 1, Font = Enum.Font.GothamBlack, TextSize = 26, TextColor3 = rgb(255, 235, 225),
	TextStrokeTransparency = 0.5, ZIndex = 31, Text = "", Parent = banner })
local bannerSub = make("TextLabel", { Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 42),
	BackgroundTransparency = 1, Font = Enum.Font.Code, TextSize = 16, TextColor3 = rgb(255, 200, 170),
	TextWrapped = true, ZIndex = 31, Text = "", Parent = banner })
make("UISizeConstraint", { MaxSize = Vector2.new(580, 78), Parent = banner })

local bannerToken = 0
local function showBanner(title, sub, color)
	bannerToken += 1
	banner.Visible = true
	banner.BackgroundColor3 = color
	bannerTitle.Text = title
	bannerSub.Text = sub
	return bannerToken
end

local function hideBanner(token)
	if token == nil or token == bannerToken then
		banner.Visible = false
	end
end

------------------------------------------------------------------------------
-- Detonation
------------------------------------------------------------------------------

local FIREBALL_KEYS = {
	{ 0, rgb(255, 255, 252) },
	{ 0.6, rgb(255, 248, 215) },
	{ 2, rgb(255, 205, 110) },
	{ 4.5, rgb(255, 130, 45) },
	{ 8, rgb(205, 64, 26) },
	{ 14, rgb(110, 42, 28) },
}
local SMOKE_KEYS = {
	{ 0, rgb(255, 150, 70) },
	{ 5, rgb(170, 90, 58) },
	{ 12, rgb(122, 98, 86) },
	{ 30, rgb(150, 138, 130) },
	{ 70, rgb(168, 162, 156) },
}
local DUST = rgb(132, 110, 88)
local SOOT = rgb(70, 52, 44)
local PALE = rgb(214, 204, 194)

local function tinted(col, tint)
	if tint > 0 then
		return col:Lerp(SOOT, tint)
	end
	return col:Lerp(PALE, -tint)
end

local function bolt(fx, from, to)
	local segs, prev, made = 10, from, {}
	local span = (to - from).Magnitude
	for i = 1, segs do
		local p = from:Lerp(to, i / segs)
		if i < segs then
			p += Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.3, 0.3), rng:NextNumber(-1, 1)) * span * 0.07
		end
		local len = (p - prev).Magnitude
		local w = 1.6 * (1 - i / segs * 0.6)
		table.insert(made, fxPart({ Size = Vector3.new(w, w, len), CFrame = CFrame.lookAt(prev, p) * CFrame.new(0, 0, -len / 2),
			Material = Enum.Material.Neon, Color = rgb(215, 225, 255), Parent = fx }))
		prev = p
	end
	make("PointLight", { Range = 60, Brightness = 18, Color = rgb(180, 200, 255), Parent = made[#made] })
	task.delay(0.06, function()
		for _, s in ipairs(made) do
			s.Transparency = 0.7
		end
	end)
	task.delay(0.11, function()
		for _, s in ipairs(made) do
			s.Transparency = 0
		end
	end)
	task.delay(0.2 + rng:NextNumber(0, 0.1), function()
		for _, s in ipairs(made) do
			s:Destroy()
		end
	end)
end

local function windGust(fx, ground, strength)
	local cam = workspace.CurrentCamera
	local pos = cam.CFrame.Position
	local away = (pos - ground) * Vector3.new(1, 0, 1)
	away = away.Magnitude > 1 and away.Unit or Vector3.new(1, 0, 0)
	local holder = fxPart({ Size = Vector3.new(160, 50, 160), Transparency = 1,
		CFrame = CFrame.lookAt(pos - away * 70, pos + away), Parent = fx })
	local dust = emitter(holder, {
		Texture = SMOKE, Rate = 0, Lifetime = NumberRange.new(1.2, 2.4),
		Speed = NumberRange.new(140 * strength, 260 * strength), EmissionDirection = Enum.NormalId.Front,
		SpreadAngle = Vector2.new(12, 12), Size = nseq({ { 0, 8, 3 }, { 1, 26, 6 } }),
		Transparency = nseq({ { 0, 1 }, { 0.1, 0.35 }, { 1, 1 } }), Color = ColorSequence.new(DUST),
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	})
	local bits = emitter(holder, {
		Texture = SPARK, Rate = 0, Lifetime = NumberRange.new(1, 2),
		Speed = NumberRange.new(180 * strength, 320 * strength), EmissionDirection = Enum.NormalId.Front,
		SpreadAngle = Vector2.new(15, 15), Size = nseq({ { 0, 0.8, 0.5 }, { 1, 0.6, 0.3 } }),
		Color = ColorSequence.new(rgb(60, 50, 42)), Acceleration = Vector3.new(0, -60, 0),
		RotSpeed = NumberRange.new(-400, 400), LightInfluence = 1,
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	})
	for i = 0, 10 do
		task.delay(i * 0.2, function()
			if holder.Parent then
				dust:Emit(math.floor(40 * strength * (1 - i / 12)))
				bits:Emit(math.floor(80 * strength * (1 - i / 12)))
			end
		end)
	end
	task.delay(6, function()
		holder:Destroy()
	end)
end

local function detonate(data)
	local C, G = data.Center, data.Ground
	local R = data.FireballRadius
	local Rmax, T = data.ShockwaveRadius, data.ShockTime
	local H, RC = data.CloudHeight, data.CapRadius
	local duration = data.Duration
	local groundY = G.Y
	local burstH = C.Y - groundY

	local fx = Instance.new("Folder")
	fx.Name = "TsarBombaClientFX"
	fx.Parent = workspace

	local cam = workspace.CurrentCamera
	local camPos = cam.CFrame.Position
	local dist = (camPos * Vector3.new(1, 0, 1) - G * Vector3.new(1, 0, 1)).Magnitude
	local k = math.clamp(1 - dist / (Rmax * 4), 0.3, 1)

	local function shockR(t)
		local u = clamp01(t / T)
		return Rmax * (1 - (1 - u) ^ 1.6)
	end
	local arrival
	if dist < Rmax then
		arrival = (1 - (1 - dist / Rmax) ^ (1 / 1.6)) * T
	else
		arrival = T + (dist - Rmax) / SOUND_SPEED
	end

	local function capHeight(t)
		return burstH + (H - burstH) * (1 - math.exp(-t / 13))
	end

	----------------------------------------------------------------------
	-- 1. The flash (speed of light)
	----------------------------------------------------------------------
	local cc = make("ColorCorrectionEffect", { Name = "TsarCC", Parent = Lighting })
	local bloom = make("BloomEffect", { Name = "TsarBloom", Intensity = 2.6, Size = 56, Threshold = 0.5, Parent = Lighting })
	local blur = make("BlurEffect", { Name = "TsarBlur", Size = 26 * k, Parent = Lighting })
	vignette.BackgroundTransparency = 0.35
	tween(vignette, 14, { BackgroundTransparency = 1 }, Enum.EasingStyle.Sine)
	tween(blur, 3.5, { Size = 0 })
	tween(bloom, 16, { Intensity = 0.7, Threshold = 0.9, Size = 30 }, Enum.EasingStyle.Sine)
	task.delay(22, function()
		tween(cc, 30, { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1) }, Enum.EasingStyle.Sine)
	end)
	-- the ground itself transmits a faint tremor long before the air blast
	task.delay(math.min(dist / (SOUND_SPEED * 4), 3), function()
		addShake(0.25 * k)
	end)

	local token = showBanner("☢  DETONATION — 50 MEGATONS  ☢", "", rgb(140, 50, 0))

	----------------------------------------------------------------------
	-- 2. Fireball
	----------------------------------------------------------------------
	local core = ball({ Name = "FireballCore", Size = uniform(2), CFrame = CFrame.new(C), Color = FIREBALL_KEYS[1][2],
		Material = Enum.Material.Neon, Parent = fx })
	local shell = ball({ Name = "HeatShimmer", Size = uniform(2), CFrame = CFrame.new(C), Color = rgb(255, 190, 110),
		Material = Enum.Material.ForceField, Parent = fx })
	local halo = ball({ Name = "Halo", Size = uniform(2), CFrame = CFrame.new(C), Color = rgb(255, 170, 90),
		Material = Enum.Material.Neon, Transparency = 0.85, Parent = fx })
	local fireLight = make("PointLight", { Range = 60, Brightness = 40, Color = rgb(255, 228, 185), Shadows = true, Parent = core })
	local groundGlow = fxPart({ Size = Vector3.new(1, 1, 1), Transparency = 1, CFrame = CFrame.new(G + Vector3.new(0, 8, 0)), Parent = fx })
	local groundLight = make("PointLight", { Range = 60, Brightness = 25, Color = rgb(255, 160, 80), Parent = groundGlow })

	-- boiling surface: blobs over the sphere (fibonacci lattice) that churn and mottle as it cools
	local boil = {}
	local NBOIL = 30
	for i = 1, NBOIL do
		local y = 1 - (i - 0.5) / NBOIL * 2
		local r = math.sqrt(1 - y * y)
		local a = i * 2.39996
		table.insert(boil, {
			part = ball({ Name = "Boil", Size = uniform(2), CFrame = CFrame.new(C), Material = Enum.Material.Neon, Parent = fx }),
			dir = Vector3.new(math.cos(a) * r, y, math.sin(a) * r), scale = rng:NextNumber(0.4, 0.68),
			seed = rng:NextNumber(0, 100), dark = rng:NextNumber(0, 1),
		})
	end

	local fireEmit = emitter(core, {
		Texture = FIRE, Rate = 45, Lifetime = NumberRange.new(1.5, 3), Speed = NumberRange.new(10, 35),
		Size = nseq({ { 0, 60, 15 }, { 0.5, 95, 10 }, { 1, 70, 10 } }), LightEmission = 1, LightInfluence = 0,
		Transparency = nseq({ { 0, 0.3 }, { 0.6, 0.55 }, { 1, 1 } }),
		Color = cseq({ { 0, rgb(255, 250, 220) }, { 0.4, rgb(255, 160, 60) }, { 1, rgb(140, 30, 10) } }),
		Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
	})
	local embers = emitter(core, {
		Texture = SPARK, Rate = 90, Lifetime = NumberRange.new(3, 6), Speed = NumberRange.new(60, 220),
		SpreadAngle = Vector2.new(180, 180), Size = nseq({ { 0, 3, 1 }, { 1, 0.5 } }), LightEmission = 1, LightInfluence = 0,
		Color = cseq({ { 0, rgb(255, 240, 200) }, { 1, rgb(255, 90, 20) } }), Acceleration = Vector3.new(0, -45, 0), Drag = 1.2,
		Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	})

	-- glare billboard: stacked soft discs + anamorphic streak
	local glare = make("BillboardGui", { Name = "Glare", Adornee = core, Size = UDim2.new(R * 9, 0, R * 9, 0),
		AlwaysOnTop = true, LightInfluence = 0, Brightness = 4, MaxDistance = math.huge, Parent = core })
	local glareFrames = {}
	for i = 9, 1, -1 do
		local s = i / 9
		local f = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(s, s), BackgroundColor3 = rgb(255, 245 - i * 8, 225 - i * 18), BorderSizePixel = 0,
			ZIndex = 10 - i, Parent = glare })
		make("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = f })
		table.insert(glareFrames, { f, 0.55 + 0.44 * s })
	end
	for _, spec in ipairs({ { 1.0, 0.018, 0.15 }, { 0.6, 0.05, 0.6 }, { 0.012, 0.5, 0.55 } }) do
		local f = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(spec[1], spec[2]), BackgroundColor3 = rgb(255, 238, 210), BorderSizePixel = 0,
			ZIndex = 20, Parent = glare })
		local horiz = spec[1] > spec[2]
		make("UIGradient", { Rotation = horiz and 0 or 90, Transparency = nseq({ { 0, 1 }, { 0.5, 0 }, { 1, 1 } }), Parent = f })
		table.insert(glareFrames, { f, spec[3] })
	end

	----------------------------------------------------------------------
	-- 3. Shock wave: condensation dome + ground ring
	----------------------------------------------------------------------
	local shockSphere = ball({ Name = "ShockFront", Size = uniform(2), CFrame = CFrame.new(C), Color = rgb(240, 245, 255),
		Material = Enum.Material.ForceField, Parent = fx })
	-- the ground-reflected front (Mach stem) expands from the burst's mirror image below ground
	local reflected = ball({ Name = "ReflectedFront", Size = uniform(2), CFrame = CFrame.new(Vector3.new(C.X, groundY - burstH, C.Z)),
		Color = rgb(235, 225, 210), Material = Enum.Material.ForceField, Transparency = 1, Parent = fx })
	local wilson = ball({ Name = "WilsonCloud", Size = uniform(2), CFrame = CFrame.new(C), Color = rgb(245, 247, 250),
		Transparency = 1, Parent = fx })

	local NR = 56
	local ring = {}
	for i = 1, NR do
		local seg = fxPart({ Name = "ShockRing", Size = Vector3.new(1, 1, 1), Color = rgb(255, 240, 220), Transparency = 1, Parent = fx })
		ring[i] = { part = seg, theta = (i - 1) / NR * TAU, jitter = rng:NextNumber(0.85, 1.2) }
		if i % 4 == 0 then
			emitter(seg, {
				Texture = SMOKE, Rate = 14, Lifetime = NumberRange.new(2.5, 4.5), Speed = NumberRange.new(4, 12),
				EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(40, 40),
				Size = nseq({ { 0, 22, 6 }, { 1, 60, 12 } }), Transparency = nseq({ { 0, 0.45 }, { 1, 1 } }),
				Color = ColorSequence.new(DUST), Acceleration = Vector3.new(0, 6, 0), Drag = 0.8,
			})
		end
	end

	----------------------------------------------------------------------
	-- 4. Mushroom cloud
	----------------------------------------------------------------------
	local torus = {}
	local NT, NP = 24, 4
	for i = 1, NT do
		for j = 1, NP do
			table.insert(torus, {
				part = ball({ Name = "CapRoll", Transparency = 1, Parent = fx }),
				theta = (i - 1) / NT * TAU + rng:NextNumber(-0.08, 0.08),
				phi = (j - 1) / NP * TAU + i * 0.41,
				scale = rng:NextNumber(0.7, 1.25),
				lift = rng:NextNumber(0.9, 1.12),
				wob = rng:NextNumber(0, 10),
				tint = rng:NextNumber(-0.18, 0.28),
			})
		end
	end
	local dome = ellipsoid({ Name = "CapDome", Size = Vector3.new(2, 2, 2), Transparency = 1, Parent = fx })
	local underGlow = ellipsoid({ Name = "CapUnderglow", Size = Vector3.new(2, 2, 2), Material = Enum.Material.Neon,
		Transparency = 1, Parent = fx })
	local capSmoke = smokeEmitter(dome, 70, 100, 20, SMOKE_KEYS[3][2])
	local capFire = emitter(underGlow, {
		Texture = FIRE, Rate = 25, Lifetime = NumberRange.new(2, 4), Speed = NumberRange.new(5, 20),
		Size = nseq({ { 0, 50, 10 }, { 1, 90, 10 } }), LightEmission = 0.8, LightInfluence = 0,
		Transparency = nseq({ { 0, 0.5 }, { 1, 1 } }), Color = cseq({ { 0, rgb(255, 180, 90) }, { 1, rgb(150, 50, 20) } }),
		Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
	})
	local capEmbers = emitter(underGlow, {
		Texture = SPARK, Rate = 40, Lifetime = NumberRange.new(5, 9), Speed = NumberRange.new(5, 20),
		Size = nseq({ { 0, 2 }, { 1, 0.4 } }), LightEmission = 1, LightInfluence = 0,
		Color = ColorSequence.new(rgb(255, 130, 40)), Acceleration = Vector3.new(0, -18, 0),
		Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	})

	local NS = 20
	local stem = {}
	for i = 1, NS do
		local p = ball({ Name = "Stem", Transparency = 1, Parent = fx })
		stem[i] = { part = p, u = (i - 1) / (NS - 1), wob = rng:NextNumber(0, 10), scale = rng:NextNumber(0.82, 1.18),
			tint = rng:NextNumber(-0.12, 0.25) }
		if i % 5 == 2 then
			emitter(p, {
				Texture = SMOKE, Rate = 10, Lifetime = NumberRange.new(3, 6), Speed = NumberRange.new(30, 65),
				EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(25, 25),
				Size = nseq({ { 0, 30, 8 }, { 1, 70, 10 } }), Transparency = nseq({ { 0, 1 }, { 0.15, 0.45 }, { 1, 1 } }),
				Color = ColorSequence.new(DUST),
				Shape = Enum.ParticleEmitterShape.Sphere, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			})
		end
	end

	local NB = 26
	local base = {}
	for i = 1, NB do
		local p = ball({ Name = "BaseSurge", Transparency = 1, Color = DUST, Parent = fx })
		base[i] = { part = p, theta = (i - 1) / NB * TAU + rng:NextNumber(-0.1, 0.1), scale = rng:NextNumber(0.75, 1.25),
			reach = rng:NextNumber(0.88, 1.12), tint = rng:NextNumber(-0.15, 0.2) }
		if i % 4 == 0 then
			smokeEmitter(p, 40, 80, 6, DUST)
		end
	end

	local collars = {}
	for _, frac in ipairs({ 0.42, 0.66 }) do
		table.insert(collars, { part = ellipsoid({ Name = "CondensationCollar", Size = Vector3.new(2, 2, 2),
			Color = rgb(236, 239, 244), Transparency = 1, Parent = fx }), frac = frac })
	end
	local pileus = ellipsoid({ Name = "IceCap", Size = Vector3.new(2, 2, 2), Color = rgb(242, 244, 248), Transparency = 1, Parent = fx })

	----------------------------------------------------------------------
	-- 5. Lightning in the first seconds
	----------------------------------------------------------------------
	for _ = 1, 8 do
		task.delay(rng:NextNumber(0.15, 2.6), function()
			if not fx.Parent then
				return
			end
			local a = rng:NextNumber(0, TAU)
			local from = C + Vector3.new(math.cos(a), rng:NextNumber(-0.6, 0.2), math.sin(a)).Unit * R * 1.05
			local reach = R * rng:NextNumber(0.8, 2.4)
			local to = Vector3.new(G.X + math.cos(a) * reach, groundY, G.Z + math.sin(a) * reach)
			bolt(fx, from, to)
		end)
	end

	----------------------------------------------------------------------
	-- 6. Blast-wave arrival at the camera
	----------------------------------------------------------------------
	local arrived = false
	task.delay(arrival, function()
		arrived = true
		local hit = math.clamp(1.7 * (1 - dist / (Rmax * 3)), 0.35, 1.7)
		addShake(hit)
		engineBoom()
		task.delay(0.05, engineBoom)
		task.delay(0.12, engineBoom)
		for i = 1, 7 do
			task.delay(0.35 * i + rng:NextNumber(0, 0.4), function()
				engineBoom()
				addShake(hit * (0.5 - i * 0.05))
			end)
		end
		playSound(SOUNDS.Boom, 3, 0.85)
		playSound(SOUNDS.Rumble, 2.5, 0.6, 10)

		local pulse = make("BlurEffect", { Size = 16 * math.min(hit, 1), Parent = Lighting })
		tween(pulse, 1.6, { Size = 0 })
		task.delay(1.7, function()
			pulse:Destroy()
		end)
		local camNow = workspace.CurrentCamera
		local fov = camNow.FieldOfView
		tween(camNow, 0.08, { FieldOfView = fov + 9 * math.min(hit, 1) })
		task.delay(0.1, function()
			tween(camNow, 1.2, { FieldOfView = fov }, Enum.EasingStyle.Elastic)
		end)
		windGust(fx, G, math.min(hit, 1.2))
	end)

	----------------------------------------------------------------------
	-- 7. Fallout
	----------------------------------------------------------------------
	task.delay(16, function()
		if not fx.Parent then
			return
		end
		local span = math.min(Rmax * 1.6, 2048)
		local sky = fxPart({ Name = "Fallout", Size = Vector3.new(span, 1, span), Transparency = 1,
			CFrame = CFrame.new(G + Vector3.new(0, 320, 0)), Parent = fx })
		emitter(sky, {
			Texture = SPARK, Rate = 260, Lifetime = NumberRange.new(14, 20), Speed = NumberRange.new(0, 2),
			Size = nseq({ { 0, 0.9, 0.4 }, { 1, 0.6, 0.3 } }), Color = ColorSequence.new(rgb(95, 90, 86)),
			Acceleration = Vector3.new(4, -14, 2), RotSpeed = NumberRange.new(-200, 200),
			Transparency = nseq({ { 0, 1 }, { 0.1, 0.1 }, { 0.9, 0.2 }, { 1, 1 } }),
			Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
		})
		-- dense ash right around the viewer if they're under it
		if dist < span * 0.5 then
			local near = fxPart({ Name = "FalloutNear", Size = Vector3.new(220, 1, 220), Transparency = 1,
				CFrame = CFrame.new(workspace.CurrentCamera.CFrame.Position + Vector3.new(0, 60, 0)), Parent = fx })
			emitter(near, {
				Texture = SPARK, Rate = 90, Lifetime = NumberRange.new(5, 8), Speed = NumberRange.new(0, 1),
				Size = nseq({ { 0, 0.5 }, { 1, 0.35 } }), Color = ColorSequence.new(rgb(110, 104, 98)),
				Acceleration = Vector3.new(3, -9, 1.5), RotSpeed = NumberRange.new(-200, 200),
				Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
			})
			local conn
			conn = RunService.Heartbeat:Connect(function()
				if not near.Parent then
					conn:Disconnect()
					return
				end
				near.CFrame = CFrame.new(workspace.CurrentCamera.CFrame.Position + Vector3.new(0, 60, 0))
			end)
		end
	end)

	----------------------------------------------------------------------
	-- Per-frame animation
	----------------------------------------------------------------------
	local t0 = os.clock()
	local lastHud = 0
	local fadeOut = 0
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		local t = os.clock() - t0
		if t > duration + 14 then
			conn:Disconnect()
			return
		end
		fadeOut = smooth((t - duration) / 12) -- 0 while alive, 1 when gone
		local f = flashCurve(t)
		if t < 5 then
			cc.Brightness = 0.06 + 0.84 * k * f
			cc.Contrast = 0.18 + 0.27 * f
			cc.Saturation = 0.15 - 1.05 * f
			cc.TintColor = rgb(255, 208, 168):Lerp(rgb(255, 252, 242), f)
			flashFrame.BackgroundTransparency = 1 - 0.97 * k * f
		elseif flashFrame.BackgroundTransparency < 1 then
			flashFrame.BackgroundTransparency = 1
		end

		local capH = capHeight(t)
		local capGrow = 1 - math.exp(-math.max(t - 0.5, 0) / 9)
		local capR = RC * (0.25 + 0.75 * capGrow)
		local ringR, tubeR = capR * 0.58, capR * 0.42
		local capC = Vector3.new(C.X, groundY + capH, C.Z)
		local smokeCol = colorAt(SMOKE_KEYS, t)
		local hot = colorAt(FIREBALL_KEYS, t)

		-- fireball ---------------------------------------------------------
		if core.Parent then
			local grow = 1 - math.exp(-t * 3.4)
			local fr = R * (0.03 + 0.97 * grow) * (1 + 0.012 * t)
			local fbPos = C:Lerp(capC, smooth((t - 0.8) / 8))
			local cf = CFrame.new(fbPos)
			core.Size = uniform(fr * 2)
			shell.Size = uniform(fr * 2.12)
			halo.Size = uniform(fr * 2.9)
			core.Color = hot
			local coreT = smooth((t - 6.5) / 9)
			core.Transparency = coreT
			local parts, cfs = { core, shell, halo }, { cf, cf, cf }
			local mottle = smooth((t - 1.2) / 6)
			for _, b in ipairs(boil) do
				local off = b.dir * fr * (0.6 + 0.1 * math.noise(t * 0.9, b.seed))
				b.part.Size = uniform(fr * 2 * b.scale * (1 + 0.12 * math.noise(t * 1.3, b.seed + 5)))
				b.part.Color = hot:Lerp(rgb(70, 22, 14), b.dark * mottle * 0.75):Lerp(rgb(255, 250, 235), (1 - smooth(t / 0.8)) * 0.6)
				b.part.Transparency = coreT
				table.insert(parts, b.part)
				table.insert(cfs, CFrame.new(fbPos + off))
			end
			workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
			shell.Transparency = smooth(t / 11)
			halo.Transparency = 0.82 + 0.18 * smooth(t / 12)
			fireLight.Brightness = 40 * f + 4 * (1 - smooth(t / 20))
			fireLight.Color = hot
			groundLight.Brightness = 25 * f
			fireEmit.Rate = 45 * math.exp(-t / 5)
			embers.Rate = 90 * math.exp(-t / 4)
			for _, gf in ipairs(glareFrames) do
				gf[1].BackgroundTransparency = 1 - (1 - gf[2]) * f
			end
			glare.Enabled = f > 0.01
			if t > 17 then
				core:Destroy()
				shell:Destroy()
				halo:Destroy()
				groundGlow:Destroy()
				for _, b in ipairs(boil) do
					b.part:Destroy()
				end
			end
		end

		-- shock wave -------------------------------------------------------
		if t <= T + 0.5 then
			local r = shockR(t)
			shockSphere.Size = uniform(r * 2)
			shockSphere.Transparency = 0.35 + 0.65 * smooth(t / T)
			local rr = shockR(math.max(t - burstH / (Rmax / T) * 0.6, 0))
			reflected.Size = uniform(rr * 2)
			reflected.Transparency = rr < 1 and 1 or 0.5 + 0.5 * smooth(t / T)
			-- the famous condensation dome flashes white for a few seconds
			wilson.Size = uniform(math.min(r * 2 * 0.97, R * 9))
			wilson.Transparency = t < 0.4 and 1 or 1 - 0.55 * math.sin(math.pi * smooth((t - 0.4) / 3.2))
			local h = (8 + 55 * smooth(t / 2.5)) * (1 - 0.6 * smooth(t / T))
			local thick = 10 + r * 0.035
			local ringCol = rgb(255, 240, 220):Lerp(DUST, smooth(t / 1.4))
			local ringT = 0.12 + 0.88 * smooth((t - T * 0.55) / (T * 0.45))
			local parts, cfs = {}, {}
			for i, s in ipairs(ring) do
				local th = s.theta
				local dir = Vector3.new(math.cos(th), 0, math.sin(th))
				local tangent = Vector3.new(-math.sin(th), 0, math.cos(th))
				local hh = h * s.jitter
				local pos = G + dir * r + Vector3.new(0, hh * 0.5 - 2, 0)
				s.part.Size = cap(Vector3.new(thick, hh, TAU * math.max(r, 1) / NR * 1.12))
				s.part.Color = ringCol
				s.part.Transparency = ringT
				parts[i] = s.part
				cfs[i] = CFrame.lookAt(pos, pos + tangent)
			end
			workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		elseif shockSphere.Parent then
			shockSphere:Destroy()
			reflected:Destroy()
			wilson:Destroy()
			for _, s in ipairs(ring) do
				s.part:Destroy()
			end
		end

		-- cap: rolling torus ------------------------------------------------
		local appear = smooth((t - 0.5) / 2.5)
		local baseT = 1 - (1 - (0.14 + 0.2 * smooth(t / 40))) * appear
		baseT = baseT + (1 - baseT) * fadeOut
		do
			local parts, cfs = {}, {}
			for i, b in ipairs(torus) do
				b.phi += dt * 0.42
				local radial = ringR + tubeR * math.cos(b.phi) * b.lift
				local th = b.theta + t * 0.015
				local pos = capC + Vector3.new(math.cos(th) * radial, tubeR * 0.72 * math.sin(b.phi) * b.lift, math.sin(th) * radial)
				local size = tubeR * 1.3 * b.scale * (1 + 0.07 * math.sin(t * 0.6 + b.wob))
				b.part.Size = uniform(size)
				-- the underside of the roll stays incandescent longest
				local glow = math.exp(-t / 7.5) * (0.55 + 0.45 * -math.sin(b.phi))
				b.part.Color = tinted(smokeCol, b.tint * smooth(t / 6)):Lerp(hot, clamp01(glow * 1.35))
				b.part.Transparency = baseT
				parts[i] = b.part
				cfs[i] = CFrame.new(pos)
			end
			workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		end
		dome.Size = cap(Vector3.new(capR * 2.05, capR * 1.0, capR * 2.05))
		dome.CFrame = CFrame.new(capC + Vector3.new(0, tubeR * 0.35, 0))
		dome.Color = smokeCol:Lerp(rgb(200, 190, 182), 0.15)
		dome.Transparency = baseT
		underGlow.Size = cap(Vector3.new(capR * 1.55, capR * 0.45, capR * 1.55))
		underGlow.CFrame = CFrame.new(capC - Vector3.new(0, tubeR * 0.42, 0))
		underGlow.Color = hot
		underGlow.Transparency = 1 - (1 - (0.15 + 0.85 * smooth((t - 2) / 22))) * appear
		capFire.Rate = 25 * math.exp(-t / 10)
		capEmbers.Rate = 40 * math.exp(-t / 12)
		capSmoke.Rate = fadeOut > 0 and 0 or 20

		-- stem --------------------------------------------------------------
		local capBottom = capH - tubeR * 0.55
		local reach = smooth((t - 1) / 9)
		local stemR = RC * 0.27 * (1 - math.exp(-math.max(t - 1, 0) / 6))
		local stemAppear = smooth((t - 1) / 3)
		do
			local parts, cfs = {}, {}
			for i, s in ipairs(stem) do
				local u = s.u
				local y = groundY + capBottom - (1 - u) * capBottom * reach
				local r = stemR * (1 + 1.7 * (1 - u) ^ 5) * (1 + 0.55 * u ^ 3) * s.scale
				local wob = Vector3.new(math.sin(t * 0.25 + s.wob), 0, math.cos(t * 0.21 + s.wob)) * stemR * 0.18 * u
				s.part.Size = uniform(math.max(r * 2, 0.1))
				local glow = math.exp(-t / 6) * u
				s.part.Color = tinted(DUST:Lerp(smokeCol, u ^ 0.7), s.tint):Lerp(hot, clamp01(glow))
				local st = 1 - (1 - 0.18) * stemAppear
				s.part.Transparency = st + (1 - st) * fadeOut
				parts[i] = s.part
				cfs[i] = CFrame.new(Vector3.new(C.X, y, C.Z) + wob)
			end
			workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		end

		-- base surge --------------------------------------------------------
		do
			local surge = 1 - math.exp(-math.max(t - 0.6, 0) / 11)
			local parts, cfs = {}, {}
			for i, b in ipairs(base) do
				local dist2 = (RC * 0.35 + RC * 1.5 * surge) * b.reach
				local size = RC * (0.25 + 0.4 * surge) * b.scale
				b.part.Size = uniform(size)
				b.part.Color = tinted(DUST, b.tint)
				local bt = 1 - (1 - 0.3) * smooth((t - 0.6) / 2)
				b.part.Transparency = bt + (1 - bt) * math.max(fadeOut, smooth((t - duration * 0.6) / (duration * 0.4)))
				parts[i] = b.part
				cfs[i] = CFrame.new(G + Vector3.new(math.cos(b.theta) * dist2, size * 0.28, math.sin(b.theta) * dist2))
			end
			workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		end

		-- condensation collars and ice cap ----------------------------------
		for idx, c in ipairs(collars) do
			local s0 = 3 + idx * 0.8
			local life = (t - s0) / 12
			if life > 0 and life < 1 then
				local d = capR * (1.25 + 1.5 * smooth(life))
				c.part.Size = cap(Vector3.new(d, d * 0.05, d))
				c.part.CFrame = CFrame.new(Vector3.new(C.X, groundY + capH * c.frac, C.Z))
				c.part.Transparency = 1 - 0.62 * math.sin(math.pi * life)
			else
				c.part.Transparency = 1
			end
		end
		local plife = (t - 5) / 24
		if plife > 0 and plife < 1 then
			local d = capR * (2.3 + 0.6 * plife)
			pileus.Size = cap(Vector3.new(d, capR * 0.12, d))
			pileus.CFrame = CFrame.new(capC + Vector3.new(0, tubeR * 1.15 + capR * 0.08, 0))
			pileus.Transparency = 1 - 0.55 * math.sin(math.pi * plife)
		else
			pileus.Transparency = 1
		end

		-- HUD ---------------------------------------------------------------
		if t - lastHud > 0.1 and token == bannerToken then
			lastHud = t
			local fireballKm = (core.Parent and core.Size.X or 0) * KM_PER_STUD
			if not arrived then
				bannerSub.Text = string.format("%.1f km from ground zero · fireball Ø %.1f km · blast wave in %.1f s",
					dist * KM_PER_STUD, fireballKm, math.max(arrival - t, 0))
			else
				bannerSub.Text = string.format("blast wave passed · cloud top %.0f km and rising", capH * KM_PER_STUD * 1.35)
			end
			bannerStroke.Color = (t * 3) % 1 < 0.5 and rgb(255, 140, 40) or rgb(120, 40, 0)
			if arrived and t > arrival + 10 then
				hideBanner(token)
			end
		end
	end)

	-- cleanup -----------------------------------------------------------------
	task.delay(duration, function()
		for _, d in ipairs(fx:GetDescendants()) do
			if d:IsA("ParticleEmitter") then
				d.Enabled = false
			end
		end
	end)
	task.delay(duration + 15, function()
		fx:Destroy()
		cc:Destroy()
		bloom:Destroy()
		blur:Destroy()
		hideBanner(token)
	end)
end

------------------------------------------------------------------------------
-- Bomb released
------------------------------------------------------------------------------

local siren

remote.OnClientEvent:Connect(function(kind, data)
	if kind == "Released" then
		local token = showBanner("☢  TSAR BOMBA RELEASED  ☢", "AN602 · 50 Mt · air-burst fuze armed — TAKE COVER", rgb(110, 0, 0))
		siren = playSound(SOUNDS.Siren, 1.2, 1)
		if siren then
			siren.Looped = true
		end
		task.spawn(function()
			while banner.Visible and token == bannerToken do
				local cam = workspace.CurrentCamera
				local d = (cam.CFrame.Position * Vector3.new(1, 0, 1) - data.Ground * Vector3.new(1, 0, 1)).Magnitude
				bannerSub.Text = string.format("AN602 · 50 Mt · you are %.1f km from ground zero — TAKE COVER", d * KM_PER_STUD)
				bannerStroke.Color = (os.clock() * 2) % 1 < 0.5 and rgb(255, 60, 40) or rgb(90, 0, 0)
				task.wait(0.1)
			end
		end)
	elseif kind == "Detonate" then
		if siren then
			siren:Destroy()
			siren = nil
		end
		local ok, err = pcall(detonate, data)
		if not ok then
			warn("[TsarBomba client] " .. tostring(err))
		end
	end
end)
