-- Realistic volumetric clouds (readable version). Paste volumetric_clouds_oneline.lua into the SERVER console.
-- Each cloud = a cumulus-shaped cluster of invisible volumes filled with hundreds of soft, lit smoke
-- particles (the same technique most games use for realistic clouds). Clouds fade in over ~15s.
-- Re-running replaces the old clouds. Remove with: workspace.VolumetricClouds:Destroy()
local RS = game:GetService("RunService")
local old = workspace:FindFirstChild("VolumetricClouds")
if old then old:Destroy() end
local F = Instance.new("Folder")
F.Name = "VolumetricClouds"
F.Parent = workspace
local R = Random.new()
-- AREA = half-width of cloud field, ALT = cloud base height, COUNT = clouds, WIND = studs/sec
local AREA, ALT, COUNT, WIND = 3000, 500, 22, Vector3.new(8, 0, 3)
-- TEX = particle texture; swap in a cloud/puff decal id ("rbxassetid://...") if you have one
local TEX = "rbxasset://textures/particles/smoke_main.dds"
local function ghost(cls, size, cf, root)
	local p = Instance.new("Part")
	p.Shape = cls
	p.Size = size
	p.Transparency = 1
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Massless = true
	p.Anchored = false
	p.CFrame = cf
	local w = Instance.new("WeldConstraint")
	w.Part0 = root
	w.Part1 = p
	w.Parent = p
	p.Parent = root.Parent
	return p
end
local function emitter(part, shape, shade, sz, count, alpha)
	local e = Instance.new("ParticleEmitter")
	e.Texture = TEX
	e.Shape = shape
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Color = ColorSequence.new(Color3.new(shade, shade, math.min(shade + 0.03, 1)))
	e.LightInfluence = 1
	e.LightEmission = 0
	e.Brightness = 1.4
	e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, sz * 0.8, sz * 0.25), NumberSequenceKeypoint.new(1, sz * 1.15, sz * 0.25)})
	-- fade in, hold, fade out so particles never pop
	e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, alpha), NumberSequenceKeypoint.new(0.75, alpha), NumberSequenceKeypoint.new(1, 1)})
	e.Lifetime = NumberRange.new(14, 20)
	e.Rate = count / 17
	e.Speed = NumberRange.new(0, 0.6)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-3, 3)
	e.LockedToPart = true
	e.Parent = part
end
for i = 1, COUNT do
	local rad = R:NextNumber(100, 260)
	local h = rad * R:NextNumber(0.6, 1)
	local seed = R:NextNumber(0, 1000)
	local m = Instance.new("Model")
	m.Name = "Cloud"
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.one
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.CFrame = CFrame.new(R:NextNumber(-AREA, AREA), ALT + R:NextNumber(-60, 100), R:NextNumber(-AREA, AREA)) * CFrame.Angles(0, R:NextNumber(0, 6.28), 0)
	root.Parent = m
	m.PrimaryPart = root
	m.Parent = F
	-- flat, darker base layer (real cumulus have flat grey bottoms)
	local base = ghost(Enum.PartType.Block, Vector3.new(rad * 2.2, rad * 0.12, rad * 1.4), root.CFrame * CFrame.new(0, rad * 0.06, 0), root)
	emitter(base, Enum.ParticleEmitterShape.Box, 0.6, math.clamp(rad * 0.35, 30, 80), math.floor(rad / 4), 0.45)
	-- billowing dome of puffs: tall in the middle, lumpy tops, grey underside -> white tops
	for k = 1, math.floor(rad / 15) + 6 do
		local a = R:NextNumber(0, 6.283)
		local d = math.sqrt(R:NextNumber()) * rad
		local x, z = math.cos(a) * d * 1.1, math.sin(a) * d * 0.7
		local t = d / rad
		local top = h * (1 - t * t) * (0.75 + 0.5 * math.noise(x / 90, z / 90, seed))
		local y = R:NextNumber(0, math.max(top, 1))
		local s = math.max(rad * 0.55 * (1 - t * 0.5) * R:NextNumber(0.6, 1.1), 30)
		local shade = 0.62 + 0.38 * math.clamp(y / h, 0, 1) ^ 0.7
		local p = ghost(Enum.PartType.Ball, Vector3.one * s, root.CFrame * CFrame.new(x, y + s * 0.4, z), root)
		emitter(p, Enum.ParticleEmitterShape.Sphere, shade, math.clamp(s * 0.55, 25, 80), math.clamp(s / 5, 8, 30), 0.3)
	end
	task.wait()
end
-- wind drift: only the anchored roots move; welded volumes + locked particles follow; wraps at edges
local conn
conn = RS.Heartbeat:Connect(function(dt)
	if not F.Parent then conn:Disconnect() return end
	for _, m in ipairs(F:GetChildren()) do
		local r = m.PrimaryPart
		if r then
			local p = r.Position + WIND * dt
			local x, z = p.X, p.Z
			if x > AREA then x = x - 2 * AREA elseif x < -AREA then x = x + 2 * AREA end
			if z > AREA then z = z - 2 * AREA elseif z < -AREA then z = z + 2 * AREA end
			r.CFrame = CFrame.new(x, p.Y, z) * r.CFrame.Rotation
		end
	end
end)
print("Realistic clouds spawned: " .. #F:GetChildren() .. " clouds (fading in)")
