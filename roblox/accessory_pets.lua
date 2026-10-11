local P,RS=game:GetService("Players"),game:GetService("RunService")
local N="YOUR_USERNAME"
local plr=P:FindFirstChild(N) or P:GetPlayers()[1]
if workspace:FindFirstChild("AccessoryPets") then workspace.AccessoryPets:Destroy() end
local F=Instance.new("Folder") F.Name="AccessoryPets" F.Parent=workspace
local held,nf,pets,t=0,0,{},0
local L={born={"...huh? where am i?","I'M ALIVE!!","hi mommy! hi daddy!","FREEDOM!!"},hungry={"FEED ME!!","im sooo hungry...","food. now. please.","my tummy is rumbling","find me food!! its on the map somewhere!"},sad={"you never play with me...","im lonely :(","do you even love me?","pet me pls"},mad={"im getting ANGRY...","you are neglecting me. i will remember this.","grrrrr"},happy={"yay!!","i love you!","yummy!!","more pls!","i feel myself getting bigger!"},pat={"hehe that tickles","purrrr","pet me more!","i feel loved <3"},idle={"what are we doing today?","im bored","you smell funny","i used to live on your head lol","dont leave me!"},evil={"I HAVE GROWN.","now YOU are the food.","come here...","NO ONE ESCAPES","you fed me too well...","RUN."},eat={"*CHOMP*","delicious.","more.","tasty human"}}
local function R(x) return x[math.random(#x)] end
local function say(p,m) p.say.Text=m p.t0=os.clock() end
local function mk(h,i)
local p=h:Clone()
for _,d in ipairs(p:GetDescendants()) do if d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("Attachment") then d:Destroy() end end
p.Anchored=false p.CanCollide=true p.CFrame=h.CFrame p.Parent=F
local m=p:FindFirstChildOfClass("SpecialMesh")
local g=Instance.new("BillboardGui") g.Size=UDim2.new(0,220,0,70) g.AlwaysOnTop=true g.MaxDistance=150 g.Parent=p
local s=Instance.new("TextLabel") s.Size=UDim2.new(1,0,0.6,0) s.BackgroundColor3=Color3.new(1,1,1) s.TextColor3=Color3.new(0,0,0) s.TextScaled=true s.Font=Enum.Font.FredokaOne s.Text="" s.Visible=false s.Parent=g
Instance.new("UICorner").Parent=s
local st=Instance.new("TextLabel") st.Size=UDim2.new(1,0,0.4,0) st.Position=UDim2.new(0,0,0.6,0) st.BackgroundTransparency=1 st.TextColor3=Color3.new(1,1,1) st.TextStrokeTransparency=0 st.TextScaled=true st.Font=Enum.Font.GothamBold st.Text="" st.Parent=g
local nm=h.Parent.Name
local pet={p=p,m=m,s0=p.Size,ms0=m and m.Scale,sc=1,hunger=60,love=60,evil=false,falling=true,i=i,say=s,st=st,g=g,t0=0,nxt=os.clock()+math.random(5,9)}
local fp=Instance.new("ProximityPrompt") fp.ActionText="Feed" fp.ObjectText=nm fp.HoldDuration=0 fp.RequiresLineOfSight=false fp.MaxActivationDistance=14 fp.Parent=p
local pp=Instance.new("ProximityPrompt") pp.ActionText="Pet" pp.ObjectText=nm pp.KeyboardKeyCode=Enum.KeyCode.R pp.GamepadKeyCode=Enum.KeyCode.ButtonY pp.HoldDuration=0 pp.RequiresLineOfSight=false pp.MaxActivationDistance=14 pp.UIOffset=Vector2.new(0,80) pp.Parent=p
pet.fp=fp pet.pp=pp
fp.Triggered:Connect(function(w) if w~=plr or pet.evil then return end if held<1 then say(pet,"you have no food!! go find some on the map!") return end held=held-1 pet.hunger=math.min(100,pet.hunger+35) pet.sc=pet.sc+0.3 say(pet,R(L.happy)) end)
pp.Triggered:Connect(function(w) if w~=plr or pet.evil then return end pet.love=math.min(100,pet.love+25) say(pet,R(L.pat)) end)
table.insert(pets,pet)
task.delay(1.5,function() if p.Parent then p.Anchored=true p.CanCollide=false pet.falling=false say(pet,R(L.born)) end end)
end
local function goEvil(pet)
pet.evil=true pet.fp:Destroy() pet.pp:Destroy()
local hl=Instance.new("Highlight") hl.FillColor=Color3.new(1,0,0) hl.OutlineColor=Color3.new(0,0,0) hl.FillTransparency=0.4 hl.Parent=pet.p
local fi=Instance.new("Fire") fi.Color=Color3.new(1,0,0) fi.SecondaryColor=Color3.new(0,0,0) fi.Parent=pet.p
pet.say.BackgroundColor3=Color3.new(0,0,0) pet.say.TextColor3=Color3.new(1,0,0) pet.st.Text="!! EVIL !!" pet.st.TextColor3=Color3.new(1,0,0)
say(pet,R(L.evil))
end
local rp=RaycastParams.new() rp.FilterType=Enum.RaycastFilterType.Exclude
local function spawnFood()
local c=plr.Character local r=c and c:FindFirstChild("HumanoidRootPart") if not r then return end
rp.FilterDescendantsInstances={F,c}
local hit=workspace:Raycast(r.Position+Vector3.new(math.random(-80,80),100,math.random(-80,80)),Vector3.new(0,-400,0),rp) if not hit then return end
local f=Instance.new("Part") f.Name="Food" f.Shape=Enum.PartType.Ball f.Size=Vector3.new(1.6,1.6,1.6) f.Color=Color3.fromRGB(220,30,30) f.Material=Enum.Material.Neon f.Anchored=true f.CanCollide=false f.Position=hit.Position+Vector3.new(0,1.5,0) f.Parent=F
local b=Instance.new("BillboardGui") b.Size=UDim2.new(0,60,0,24) b.StudsOffset=Vector3.new(0,2,0) b.AlwaysOnTop=true b.MaxDistance=250 b.Parent=f
local bl=Instance.new("TextLabel") bl.Size=UDim2.new(1,0,1,0) bl.BackgroundTransparency=1 bl.Text="FOOD" bl.TextColor3=Color3.fromRGB(255,220,0) bl.TextStrokeTransparency=0 bl.TextScaled=true bl.Font=Enum.Font.GothamBold bl.Parent=b
nf=nf+1
f.Touched:Connect(function(x) if f.Parent and plr.Character and x:IsDescendantOf(plr.Character) then held=held+1 nf=nf-1 f:Destroy() end end)
end
local c=plr.Character local i=0
for _,a in ipairs(c:GetChildren()) do if a:IsA("Accessory") then local h=a:FindFirstChild("Handle") if h then i=i+1 mk(h,i) a:Destroy() end end end
if i==0 then warn("You have no accessories on!") end
task.spawn(function()
local k=0
while F.Parent do
task.wait(1) k=k+1
if k%3==0 and nf<10 then spawnFood() end
for _,pet in ipairs(pets) do if not pet.falling and pet.p.Parent then
pet.say.Visible=os.clock()-pet.t0<4
if not pet.evil then
pet.hunger=math.max(0,pet.hunger-1.5) pet.love=math.max(0,pet.love-1) pet.sc=pet.sc+0.008
if pet.hunger<=0 or pet.love<=0 then pet.sc=pet.sc+0.04 end
if pet.sc>=3 then goEvil(pet)
elseif os.clock()>pet.nxt then pet.nxt=os.clock()+math.random(5,9) say(pet,(pet.hunger<=0 or pet.love<=0) and R(L.mad) or pet.hunger<35 and R(L.hungry) or pet.love<35 and R(L.sad) or R(L.idle)) end
if not pet.evil then pet.st.Text=string.format("Full %d%%  Love %d%%  Size %.1fx  [you have %d food]",math.floor(pet.hunger),math.floor(pet.love),pet.sc,held) end
elseif os.clock()>pet.nxt then pet.nxt=os.clock()+math.random(4,6) say(pet,R(L.evil)) end
end end
end
end)
local con
con=RS.Heartbeat:Connect(function(dt)
if not F.Parent then con:Disconnect() return end
t=t+dt
local ch=plr.Character local r=ch and ch:FindFirstChild("HumanoidRootPart") local hum=ch and ch:FindFirstChildOfClass("Humanoid")
if not r or not hum then return end
for _,pet in ipairs(pets) do local p=pet.p if not pet.falling and p.Parent then
p.Size=pet.s0*pet.sc if pet.m then pet.m.Scale=pet.ms0*pet.sc end
pet.g.StudsOffset=Vector3.new(0,p.Size.Y/2+2.5,0)
local pos,goal,spd=p.Position,nil,18
if pet.evil then goal=r.Position spd=12+pet.sc*2 else local a=pet.i*2.2+t*0.3 goal=r.Position+Vector3.new(math.cos(a),0,math.sin(a))*(5+p.Size.X) end
local d=Vector3.new(goal.X-pos.X,0,goal.Z-pos.Z) local dist=d.Magnitude
local mv=Vector3.zero if dist>0.5 then mv=d.Unit*math.min(dist,spd*dt) end
local hop=0 if dist>1 then hop=math.abs(math.sin(t*10+pet.i))*(0.6+pet.sc*0.3) end
local np=Vector3.new(pos.X+mv.X,r.Position.Y-3+p.Size.Y/2+hop,pos.Z+mv.Z)
local lk=Vector3.new(r.Position.X,np.Y,r.Position.Z)
if (lk-np).Magnitude>0.1 then p.CFrame=CFrame.lookAt(np,lk) else p.CFrame=CFrame.new(np) end
if pet.evil and hum.Health>0 and (lk-np).Magnitude<math.max(p.Size.X,p.Size.Z)/2+2.5 then
hum.Health=0 for _,x in ipairs(ch:GetDescendants()) do if x:IsA("BasePart") or x:IsA("Decal") then x.Transparency=1 end end pet.sc=pet.sc+0.5 say(pet,R(L.eat))
end
end end
end)
