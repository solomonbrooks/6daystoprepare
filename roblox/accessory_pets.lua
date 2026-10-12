local P,RS,TS,DB=game:GetService("Players"),game:GetService("RunService"),game:GetService("TweenService"),game:GetService("Debris")
local N="YOUR_USERNAME"
local plr=P:FindFirstChild(N) or P:GetPlayers()[1]
if workspace:FindFirstChild("AccessoryPets") then workspace.AccessoryPets:Destroy() end
local F=Instance.new("Folder") F.Name="AccessoryPets" F.Parent=workspace
local eating,prot,inf,hollow=nil,0,nil,false
local inv,cnt,pets,items,minis,t={food=0,poison=0},{food=0,poison=0,burrito=0},{},{},{},0
local TOX,PURP,RED,WHITE,BLACK,GOLD=Color3.fromRGB(90,255,60),Color3.fromRGB(120,0,170),Color3.new(1,0,0),Color3.new(1,1,1),Color3.new(0,0,0),Color3.fromRGB(255,200,40)
local GOO={Color3.fromRGB(35,6,45),Color3.fromRGB(18,32,14),Color3.fromRGB(55,0,38),Color3.fromRGB(8,8,20),Color3.fromRGB(28,18,0)}
local LIMB,ELIMB,SLIMB,TAN=Color3.fromRGB(40,40,46),Color3.fromRGB(90,0,0),Color3.fromRGB(25,0,35),Color3.fromRGB(215,170,100)
local L={born={"...huh? where am i?","I'M ALIVE!!","i have LEGS now??","FREEDOM!!","hi mommy! hi daddy!"},hungry={"FEED ME!!","im sooo hungry...","food. now. please.","my tummy is rumbling","find me food!! its on the map somewhere!"},sad={"you never play with me...","im lonely :(","do you even love me?","pet me pls"},mad={"im getting ANGRY...","you are neglecting me. i will remember this.","grrrrr"},happy={"yay!!","i love you!","yummy!!","more pls!","i feel myself getting bigger!"},pat={"hehe that tickles","purrrr","pet me more!","i feel loved <3"},idle={"what are we doing today?","im bored","you smell funny","i used to live on your head lol","dont leave me!","why are you staring at me","im gonna go explore","look at me walk!!","i miss the hat mines...","do you know someone named gerald?","sometimes i hear whispers..."},whisper={"they don't really love you...","let me protect you...","soon...","eat more... for US","why do you trust them?"},glorp={"glorp... glorp...","~ we are the beans... ~","~ glorp glorp glorp ~"},evil={"I HAVE GROWN.","now YOU are the food.","come here...","NO ONE ESCAPES","you fed me too well...","RUN.","GERALD WAS RIGHT.","this is for the burritos.","SILENCE, HAT."},trap1={"help me...","its taking over...","im still in here!","dont give up on me..."},trap2={"...help...","...please...","...its so dark..."},trap3={"...h..."},super={"~ GLORP GLORP GLORP ~","MASTER... I HAVE FOUND HIM...","THE HAT IS OURS. THE HEAD IS NEXT.","WE ARE THE BEANS.","GERALD SENT US. CHECK YOUR TEXTS."},lunge={"RAAAAAH!","GET OVER HERE!","CHOMP TIME!"},eat={"*CHOMP*","delicious.","more.","tasty human","mmm... crunchy"},grab={"GOTCHA.","say goodbye.","open wiiide...","dinner time."},nopoison={"HAHA you have nothing!","feed me something TASTY. like YOU."},poisoned={"what... did you feed me...","bleh! that tastes WRONG","my tummy... it burns...","you TRICKED me!!"},dying={"urk... i dont feel so good...","*gurgle*","whats happening to meeee","BLEEEEEHHH"},slap={"DID YOU JUST SLAP ME?!","OW!! MY BEANS!","YOU WILL REGRET THAT.","nobody has EVER slapped a burrito..."},evilpet={"...i remember that...","...you still care...?","...keep... trying..."},survive1={"...WHY WON'T YOU DIE?!","PTOO! GROSS!","IMPOSSIBLE!!"},survive2={"...are you even human...","are you... GERALD?","my jaw hurts...","i can't eat anymore..."},ultra={"I ATE MY BURRITO. i am free.","i will protect you.","thank you for never giving up on me.","no burrito will touch you."},ultrafight={"BEGONE, BURRITO!","HAT JUSTICE!","this is for the hats!"},freed={"...i'm... free? THANK YOU!!","the burrito is gone!! i can think again!"},scared={"AAAH STAY AWAY","you smell like BURRITO","no no no no"},hollow={"...what ARE you?","stay away from me...","no flavor... no soul..."},brother={"...one of us...","...brother...","welcome to the beans."},innocent={"i feel so light! no whispers in my head :)","just a hat. just vibes.","i will never turn evil. pinky promise.","no burrito in here! i checked!"},beans={"i love you... i think??","pls dont flush me","beans is happy :)","i used to be evil. now i have YOU.","hug?"},calm={"bro... you dont have to do this...","being loved is so much better...","i know youre scared. ill pet you."},calmed={"...loved?","...i... huh?","*sniff*"},infect={"tasty... human...?","i want a burrito...","glorp","bruh"}}
local function R(x) return x[math.random(#x)] end
local function say(p,m,v)
v=v or (p.ultra and "ultra" or p.evil and "burrito" or "hat")
p.say.BackgroundColor3=v=="burrito" and BLACK or v=="ultra" and GOLD or WHITE p.say.TextColor3=v=="burrito" and RED or BLACK
p.say.Text=m p.t0=os.clock() end
local function part(sz,col,mat,sphere)
local q=Instance.new("Part") q.Size=sz q.Color=col q.Material=mat or Enum.Material.SmoothPlastic q.Anchored=true q.CanCollide=false q.CanQuery=false q.CanTouch=false q.CastShadow=false
if sphere then local sm=Instance.new("SpecialMesh") sm.MeshType=Enum.MeshType.Sphere sm.Parent=q end
q.Parent=F return q end
local function label(parent,txt,col,w,h,off) local b=Instance.new("BillboardGui") b.Size=UDim2.new(0,w,0,h) b.StudsOffset=Vector3.new(0,off,0) b.AlwaysOnTop=true b.MaxDistance=250 b.Parent=parent local l=Instance.new("TextLabel") l.Size=UDim2.new(1,0,1,0) l.BackgroundTransparency=1 l.Text=txt l.TextColor3=col l.TextStrokeTransparency=0 l.TextScaled=true l.Font=Enum.Font.GothamBold l.Parent=b return b,l end
local function sparkle(p,c) local s=Instance.new("Sparkles") s.SparkleColor=c s.Parent=p DB:AddItem(s,1.5) end
local function boom(pos,r) local e=Instance.new("Explosion") e.Position=pos e.BlastRadius=r e.BlastPressure=0 e.DestroyJointRadiusPercent=0 e.Parent=workspace end
local rp=RaycastParams.new() rp.FilterType=Enum.RaycastFilterType.Exclude
local function ground(pos,depth)
local ex={F,plr.Character}
for n=1,4 do rp.FilterDescendantsInstances=ex local h=workspace:Raycast(pos,Vector3.new(0,-depth,0),rp) if not h then return nil end local m=h.Instance:FindFirstAncestorOfClass("Model") if m and m:FindFirstChildOfClass("Humanoid") then table.insert(ex,m) else return h end end
end
local function goo(q) q.Color=R(GOO) q.Material=Enum.Material.Glass q.Reflectance=0.35 q.Transparency=0.08 TS:Create(q,TweenInfo.new(1+math.random()*2,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Color=R(GOO)}):Play() end
local function puddle(pos,d,fumes)
local hit=ground(pos+Vector3.new(0,3,0),60) if not hit then return end
local q=part(Vector3.new(0.15,0.1,0.1),BLACK) goo(q) q.Shape=Enum.PartType.Cylinder q.CFrame=CFrame.new(hit.Position+Vector3.new(0,0.08+math.random()*0.03,0))*CFrame.Angles(0,0,math.pi/2)
TS:Create(q,TweenInfo.new(0.4,Enum.EasingStyle.Back),{Size=Vector3.new(0.15,d,d*(0.7+math.random()*0.5))}):Play()
if fumes then local pe=Instance.new("ParticleEmitter") pe.EmissionDirection=Enum.NormalId.Right pe.Color=ColorSequence.new(Color3.fromRGB(60,0,80),Color3.fromRGB(10,30,10)) pe.LightEmission=0 pe.Transparency=NumberSequence.new(0.3,1) pe.Size=NumberSequence.new(0.6,2) pe.Rate=8 pe.Lifetime=NumberRange.new(1.5,3) pe.Speed=NumberRange.new(1,3) pe.SpreadAngle=Vector2.new(20,20) pe.RotSpeed=NumberRange.new(-60,60) pe.Parent=q end
task.delay(25,function() if q.Parent then local tw=TS:Create(q,TweenInfo.new(4),{Transparency=1,Size=Vector3.new(0.15,0.1,0.1)}) tw:Play() tw.Completed:Wait() q:Destroy() end end)
end
local function beans(pos) for n=1,8 do local b=part(Vector3.one*0.45,Color3.fromRGB(110,60,30),nil,true) b.Anchored=false b.CanCollide=true b.Position=pos b.AssemblyLinearVelocity=Vector3.new(math.random(-25,25),math.random(15,35),math.random(-25,25)) DB:AddItem(b,4) end end
local function release(pet)
local e=pet.eat if not e then return end
if eating==e.ch then eating=nil end
if not e.done then for _,x in ipairs(e.ch:GetDescendants()) do if (x:IsA("BasePart") and x~=e.r) or x:IsA("Decal") then x.Transparency=0 end end if e.r.Parent then e.r.Anchored=false end e.hum.WalkSpeed=16 e.hum.JumpPower=50 end
pet.eat=nil
end
local function clean(pet) pet.dead=true release(pet) pet.p:Destroy() for _,e in ipairs(pet.parts) do e:Destroy() end end
local function ghost(pet)
local gh=pet.p:Clone() for _,x in ipairs(gh:GetChildren()) do if not x:IsA("SpecialMesh") then x:Destroy() end end
gh.Size=pet.s0 local gm=gh:FindFirstChildOfClass("SpecialMesh") if gm then gm.Scale=pet.ms0 end
gh.Anchored=true gh.CanCollide=false gh.Transparency=0.3 gh.Color=WHITE gh.Material=Enum.Material.ForceField gh.Parent=F
label(gh,"thank you...",WHITE,140,30,2)
TS:Create(gh,TweenInfo.new(4),{CFrame=gh.CFrame+Vector3.new(0,15,0),Transparency=1}):Play() DB:AddItem(gh,4.5)
end
local spawnItem,setPrompts,goEvil,unEvil,die,mk
local function explode(pet)
local pos=pet.p.Position local s=math.max(pet.p.Size.X,pet.p.Size.Y,pet.p.Size.Z)
boom(pos,s+6) ghost(pet) clean(pet)
puddle(pos,s*2.8,true)
for n=1,35 do
local b=part(Vector3.one*(math.random(4,12)/10)*(1+s*0.15),BLACK,nil,true) goo(b) b.Anchored=false b.CanCollide=true b.Position=pos+Vector3.new(0,1,0) b.AssemblyLinearVelocity=Vector3.new(math.random(-45,45),math.random(25,65),math.random(-45,45))
task.delay(1.5+math.random()*1.5,function() if b.Parent then puddle(b.Position,b.Size.X*2.5,math.random()<0.25) b:Destroy() end end)
end
task.delay(1,function() spawnItem("burrito",pos) end)
end
function die(pet)
pet.dying=true setPrompts(pet,"none")
task.spawn(function()
for n=1,40 do if not pet.p.Parent then return end pet.sc=pet.sc+0.035 pet.hl.FillColor=(n%2==0) and PURP or BLACK if n%10==1 then say(pet,R(L.dying)) end task.wait(0.1) end
explode(pet)
end)
end
function goEvil(pet)
pet.evil=true pet.need=3 pet.stun=os.clock()+2.5 pet.sc=pet.sc+0.4
boom(pet.p.Position,4)
local hl=Instance.new("Highlight") hl.FillColor=RED hl.OutlineColor=BLACK hl.FillTransparency=0.4 hl.Parent=pet.p pet.hl=hl
local fi=Instance.new("Fire") fi.Color=RED fi.SecondaryColor=BLACK fi.Parent=pet.p pet.fire=fi
pet.st.TextColor3=RED setPrompts(pet,"evil") say(pet,R(L.evil))
end
function unEvil(pet)
pet.evil=false pet.super=false pet.poison=0 pet.rage=1 pet.hunger=50 pet.love=50 pet.sc=math.min(pet.sc,2.5)
if pet.hl then pet.hl:Destroy() pet.hl=nil end if pet.fire then pet.fire:Destroy() pet.fire=nil end
pet.st.TextColor3=WHITE setPrompts(pet,"cute") sparkle(pet.p,GOLD) say(pet,R(L.freed),"hat")
end
local function goSuper(pet)
pet.super=true pet.need=5 pet.hl.FillColor=BLACK pet.hl.OutlineColor=PURP pet.fire.Color=PURP pet.fire.SecondaryColor=BLACK pet.fire.Size=10
boom(pet.p.Position,8) setPrompts(pet,"evil") say(pet,"MASTER... I HAVE FOUND HIM...")
end
local function goUltra(pet)
pet.ultra=true pet.ultraT=os.clock()
local hl=Instance.new("Highlight") hl.FillColor=GOLD hl.OutlineColor=GOLD hl.FillTransparency=0.6 hl.Parent=pet.p
local s=Instance.new("Sparkles") s.SparkleColor=GOLD s.Parent=pet.p
boom(pet.p.Position,4) pet.st.TextColor3=GOLD setPrompts(pet,"ultra") say(pet,"I ATE MY BURRITO. i am free... and i will protect you.")
end
local function spawnMini(pet)
local m=part(Vector3.new(1.4,0.8,0.8),TAN) m.Shape=Enum.PartType.Cylinder
local lt=Instance.new("PointLight") lt.Color=PURP lt.Range=6 lt.Parent=m
table.insert(minis,{p=m,pos=pet.pos,t0=os.clock()})
end
local function infect()
if inf then return end
local ch=plr.Character local hd=ch and ch:FindFirstChild("Head") if not hd then return end
local g,l=label(hd,"BURRITO INFECTION 0%",RED,260,40,3) inf={t0=os.clock(),lvl=0,gui=g,lbl=l}
end
local function cure()
if not inf then return end
if inf.gui then inf.gui:Destroy() end if inf.hl then inf.hl:Destroy() end
local ch=plr.Character local hum=ch and ch:FindFirstChildOfClass("Humanoid") if hum then hum.WalkSpeed=16 end
local hd=ch and ch:FindFirstChild("Head") if hd then local g=label(hd,"...i feel normal again",WHITE,260,40,3) DB:AddItem(g,3) end
inf=nil
end
function spawnItem(kind,at)
local c=plr.Character local r=c and c:FindFirstChild("HumanoidRootPart") if not r and not at then return end
local hit if at then hit=ground(at+Vector3.new(0,5,0),40) else hit=ground(r.Position+Vector3.new(math.random(-80,80),100,math.random(-80,80)),400) end if not hit then return end
local f=Instance.new("Part") f.Name=kind f.Anchored=true f.CanCollide=false f.Material=Enum.Material.Neon
local col,txt,tcol
if kind=="food" then f.Shape=Enum.PartType.Ball f.Size=Vector3.new(1.6,1.6,1.6) col=Color3.fromRGB(220,30,30) txt="FOOD" tcol=Color3.fromRGB(255,220,0)
elseif kind=="poison" then f.Shape=Enum.PartType.Cylinder f.Size=Vector3.new(1.8,1,1) col=TOX txt="POISON" tcol=TOX
else f.Shape=Enum.PartType.Cylinder f.Size=Vector3.new(2.2,1.1,1.1) f.Material=Enum.Material.SmoothPlastic col=TAN txt="??? BURRITO" tcol=Color3.fromRGB(255,140,0) DB:AddItem(f,30) end
f.Color=col f.CFrame=CFrame.new(hit.Position+Vector3.new(0,1.8,0))*(kind=="food" and CFrame.new() or CFrame.Angles(0,0,math.pi/2)) f.Parent=F
local lt=Instance.new("PointLight") lt.Color=kind=="burrito" and tcol or col lt.Range=8 lt.Parent=f
label(f,txt,tcol,100,24,2)
cnt[kind]=cnt[kind]+1 items[f]=f.CFrame
if kind=="burrito" then
local function bp(text,key,off,fn) local q=Instance.new("ProximityPrompt") q.ActionText=text q.ObjectText="??? Burrito" q.KeyboardKeyCode=key q.HoldDuration=0.5 q.RequiresLineOfSight=false q.MaxActivationDistance=10 q.UIOffset=Vector2.new(0,off) q.Parent=f q.Triggered:Connect(function(w) if w==plr and f.Parent and items[f] then fn() items[f]=nil cnt.burrito=cnt.burrito-1 f:Destroy() end end) end
bp("Eat",Enum.KeyCode.E,0,infect)
bp("Adopt",Enum.KeyCode.R,80,function() local md=Instance.new("Model") md.Name="Beans" local tp=Instance.new("Part") tp.Name="Handle" tp.Shape=Enum.PartType.Cylinder tp.Size=Vector3.new(2,1.1,1.1) tp.Color=TAN tp.Parent=md tp.CFrame=f.CFrame+Vector3.new(0,1,0) mk(tp,#pets+1,nil,nil,"beans") md:Destroy() end)
end
f.Destroying:Connect(function() if items[f] then items[f]=nil cnt[kind]=cnt[kind]-1 end end)
f.Touched:Connect(function(x) if f.Parent and items[f] and plr.Character and x:IsDescendantOf(plr.Character) then
if kind=="burrito" then return elseif kind=="poison" and inf then cure() else inv[kind]=inv[kind]+1 end
items[f]=nil cnt[kind]=cnt[kind]-1 f:Destroy() end end)
end
function setPrompts(pet,mode)
for _,x in ipairs(pet.prompts) do x:Destroy() end pet.prompts={}
local function pr(text,key,gp,off,fn)
local q=Instance.new("ProximityPrompt") q.ActionText=text q.ObjectText=(pet.evil and (pet.super and "SUPER EVIL " or "EVIL ") or pet.ultra and "ULTRA " or "")..pet.nm q.KeyboardKeyCode=key q.GamepadKeyCode=gp q.HoldDuration=0 q.RequiresLineOfSight=false q.UIOffset=Vector2.new(0,off) q.Parent=pet.p
q.Triggered:Connect(function(w) if w==plr and not pet.dying and not pet.dead then fn() end end)
table.insert(pet.prompts,q)
end
local E,Rk,Fk=Enum.KeyCode.E,Enum.KeyCode.R,Enum.KeyCode.F
if mode=="cute" then
pr("Feed",E,Enum.KeyCode.ButtonX,0,function() if inv.food<1 then say(pet,"you have no food!! go find some on the map!") return end inv.food=inv.food-1 pet.hunger=math.min(100,pet.hunger+35) pet.sc=pet.sc+0.3 pet.spinT=os.clock() sparkle(pet.p,Color3.fromRGB(255,200,0)) say(pet,R(L.happy)) end)
pr("Pet",Rk,Enum.KeyCode.ButtonY,80,function() if pet.beans then pet.sc=math.min(2,pet.sc+0.1) end pet.love=math.min(100,pet.love+25) pet.spinT=os.clock() sparkle(pet.p,Color3.fromRGB(255,120,200)) say(pet,R(L.pat)) end)
elseif mode=="evil" then
pr("Feed Poison",E,Enum.KeyCode.ButtonX,0,function() if inv.poison<1 then say(pet,R(L.nopoison)) return end inv.poison=inv.poison-1 pet.poison=pet.poison+1 pet.stun=os.clock()+1.2 sparkle(pet.p,PURP) pet.hl.FillColor=(pet.super and BLACK or RED):Lerp(PURP,pet.poison/pet.need) say(pet,R(L.poisoned)) if pet.poison>=pet.need then die(pet) end end)
pr("Pet",Rk,Enum.KeyCode.ButtonY,80,function() pet.flicker=os.clock()+1.2 pet.sc=pet.sc+0.1 say(pet,R(L.evilpet),"hat") end)
pr("Slap",Fk,Enum.KeyCode.ButtonB,160,function() pet.stun=os.clock()+1 pet.sc=math.max(1,pet.sc-0.4) pet.rage=pet.rage*1.1 beans(pet.p.Position) say(pet,R(L.slap)) if pet.sc<3 then unEvil(pet) end end)
elseif mode=="ultra" then
pr("Pet",Rk,Enum.KeyCode.ButtonY,0,function() sparkle(pet.p,GOLD) pet.spinT=os.clock() say(pet,R(L.ultra)) end)
end
end
function mk(h,i,head,acc,kind)
local p=h:Clone()
for _,d in ipairs(p:GetDescendants()) do if d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("Attachment") then d:Destroy() end end
p.Anchored=false p.CanCollide=true p.CFrame=h.CFrame p.Parent=F
local m=p:FindFirstChildOfClass("SpecialMesh")
local g=Instance.new("BillboardGui") g.Size=UDim2.new(0,230,0,70) g.AlwaysOnTop=true g.MaxDistance=150 g.Parent=p
local s=Instance.new("TextLabel") s.Size=UDim2.new(1,0,0.6,0) s.BackgroundColor3=WHITE s.TextColor3=BLACK s.TextScaled=true s.Font=Enum.Font.FredokaOne s.Text="" s.Visible=false s.Parent=g
Instance.new("UICorner").Parent=s
local st=Instance.new("TextLabel") st.Size=UDim2.new(1,0,0.4,0) st.Position=UDim2.new(0,0,0.6,0) st.BackgroundTransparency=1 st.TextColor3=WHITE st.TextStrokeTransparency=0 st.TextScaled=true st.Font=Enum.Font.GothamBold st.Text="" st.Parent=g
local pet={p=p,m=m,nm=kind=="beans" and "Beans" or h.Parent.Name,acc=acc,innocent=kind~=nil,beans=kind=="beans",s0=p.Size,ms0=m and m.Scale,rot=head and (head.CFrame:Inverse()*h.CFrame).Rotation or CFrame.new(),sc=1,hunger=60,love=60,poison=0,need=3,rage=1,survive=0,evil=false,falling=true,i=i,say=s,st=st,g=g,t0=0,nxt=os.clock()+math.random(5,9),blink=0,stun=0,lunge=0,flicker=0,hitT=0,spinT=-10,yaw=0,dyaw=0,ph=0,amp=0,wnext=0,prompts={},parts={},w={},pu={},br={},legs={},feet={},arms={},xw={},xp={},teeth={}}
setPrompts(pet,"cute")
table.insert(pets,pet)
task.delay(1.5,function() if p.Parent then
p.Anchored=true p.CanCollide=false pet.pos=p.Position pet.born=os.clock()
local function add(q) table.insert(pet.parts,q) return q end
for k=1,2 do pet.w[k]=add(part(Vector3.one,WHITE,nil,true)) pet.pu[k]=add(part(Vector3.one,BLACK,nil,true)) pet.br[k]=add(part(Vector3.one,BLACK)) pet.legs[k]=add(part(Vector3.one,LIMB)) pet.feet[k]=add(part(Vector3.one,LIMB,nil,true)) pet.arms[k]=add(part(Vector3.one,LIMB)) pet.xw[k]=add(part(Vector3.one,PURP,Enum.Material.Neon,true)) pet.xp[k]=add(part(Vector3.one,BLACK,nil,true)) end
pet.mo=add(part(Vector3.one,BLACK,nil,true)) for k=1,6 do pet.teeth[k]=add(part(Vector3.one,Color3.fromRGB(235,225,190))) end
pet.falling=false say(pet,pet.beans and "*sniff* ...you saved me? im Beans." or pet.innocent and R(L.innocent) or R(L.born))
end end)
end
local function wander(pet,pos,rpos,now)
if now>pet.wnext then pet.wnext=now+math.random(3,7) if math.random()<0.35 then pet.wt=nil else local a=math.random()*math.pi*2 local rr=math.random(6,22) pet.wt=rpos+Vector3.new(math.cos(a)*rr,0,math.sin(a)*rr) end end
if pet.wt then return pet.wt,9 end return pos,0
end
local c=plr.Character local head=c:FindFirstChild("Head") local i=0
for _,a in ipairs(c:GetChildren()) do if a:IsA("Accessory") then local h=a:FindFirstChild("Handle") if h then i=i+1 mk(h,i,head,a:Clone(),math.random()<0.25 and "innocent" or nil) a:Destroy() end end end
if i==0 then warn("You have no accessories on!") end
do
local r=c:FindFirstChild("HumanoidRootPart") local a=math.random()*math.pi*2
local hit=r and ground(r.Position+Vector3.new(math.cos(a)*25,50,math.sin(a)*25),200)
if hit then
local post=part(Vector3.new(0.5,4,0.5),Color3.fromRGB(90,60,30),Enum.Material.Wood) post.CanCollide=true post.Position=hit.Position+Vector3.new(0,2,0)
local bp=hit.Position+Vector3.new(0,4.5,0)
local bd=part(Vector3.new(6,3.5,0.3),Color3.fromRGB(200,170,120),Enum.Material.Wood) bd.CanCollide=true bd.CFrame=CFrame.lookAt(bp,Vector3.new(r.Position.X,bp.Y,r.Position.Z))
for _,face in ipairs({Enum.NormalId.Front,Enum.NormalId.Back}) do local sg=Instance.new("SurfaceGui") sg.Face=face sg.Parent=bd local tl=Instance.new("TextLabel") tl.Size=UDim2.new(1,0,1,0) tl.BackgroundTransparency=1 tl.TextScaled=true tl.Font=Enum.Font.IndieFlower tl.TextColor3=BLACK tl.Text="HATS ARE HUNGRY.\nDO NOT FEED THEM TOO MUCH.\nDO NOT EAT THE BURRITO.\nDO NOT FLUSH THE BURRITO.\nBLOX-COLA IS THE ONLY WAY.\n- GERALD (still not paid)" tl.Parent=sg end
label(bd,"GERALD'S NOTE",Color3.fromRGB(255,220,150),160,26,3)
end
end
local cac
cac=plr.CharacterAdded:Connect(function() if not F.Parent then cac:Disconnect() return end prot=os.clock()+3 inf=nil end)
task.spawn(function()
local k=0
while F.Parent do
task.wait(1) k=k+1
local now=os.clock()
local ch=plr.Character local hum=ch and ch:FindFirstChildOfClass("Humanoid")
hollow=ch~=nil and hum==nil
local anyEvil=false
for _,pet in ipairs(pets) do if pet.evil and not pet.dead then anyEvil=true end end
if k%3==0 and cnt.food<10 then spawnItem("food") end
if (anyEvil or inf) and k%3==1 and cnt.poison<6 then spawnItem("poison") end
if inf then
inf.lvl=math.min(1,(now-inf.t0)/60)
if hum and eating~=ch then hum.WalkSpeed=16+8*inf.lvl end
if inf.lvl>=1 then if not inf.hl and ch then inf.hl=Instance.new("Highlight") inf.hl.FillColor=RED inf.hl.OutlineColor=BLACK inf.hl.Parent=ch end inf.lbl.Text="YOU ARE ONE OF THEM"
elseif math.random()<0.15 and inf.lvl>0.4 then inf.lbl.Text=R(L.infect)
else inf.lbl.Text=string.format("BURRITO INFECTION %d%%  (drink poison to cure)",math.floor(inf.lvl*100)) end
end
for _,pet in ipairs(pets) do if not pet.falling and not pet.dead then
pet.say.Visible=now-pet.t0<4
if math.random()<0.2 then pet.blink=now+0.15 end
local chat=now>pet.nxt
if pet.ultra then
pet.st.Text="ULTRA HAT  [protecting you]"
if chat then pet.nxt=now+math.random(6,10) say(pet,R(L.ultra)) end
elseif not pet.evil then
pet.hunger=math.max(0,pet.hunger-1.5) pet.love=math.max(0,pet.love-1) pet.sc=pet.sc+0.008
if pet.hunger<=0 or pet.love<=0 then pet.sc=pet.sc+0.04 end
if pet.innocent then pet.sc=math.min(pet.sc,pet.beans and 2 or 2.5) end
if pet.sc>=3 then if pet.hunger>=60 and pet.love>=80 and math.random()<0.5 then goUltra(pet) else goEvil(pet) end
else
if chat then pet.nxt=now+math.random(5,9)
if hollow then say(pet,R(L.hollow))
elseif inf and inf.lvl>=1 then say(pet,R(L.scared))
elseif pet.beans and math.random()<0.6 then say(pet,R(L.beans))
elseif pet.innocent and math.random()<0.3 then say(pet,R(L.innocent))
elseif pet.innocent and (pet.hunger<=0 or pet.love<=0) then say(pet,R(L.sad))
elseif pet.sc>=2.4 and not pet.innocent and math.random()<0.5 then say(pet,R(L.glorp),"burrito")
elseif pet.sc>=2 and not pet.innocent and math.random()<0.35 then say(pet,R(L.whisper),"burrito")
else say(pet,(pet.hunger<=0 or pet.love<=0) and R(L.mad) or pet.hunger<35 and R(L.hungry) or pet.love<35 and R(L.sad) or R(L.idle)) end
end
pet.st.Text=(pet.beans and "BEANS  " or pet.innocent and "INNOCENT (no burrito!)  " or "")..string.format("Full %d%%  Love %d%%  Size %.1fx  [you have %d food]",math.floor(pet.hunger),math.floor(pet.love),pet.sc,inv.food)
end
elseif pet.dying then pet.st.Text="!!! ABOUT TO BLOW !!!"
else
if not pet.super and pet.sc>=10 then goSuper(pet) end
pet.st.Text=string.format("%s  poison %d/%d  [you have %d poison]",pet.super and "!!! SUPER EVIL !!!" or "!! EVIL !!",pet.poison,pet.need,inv.poison)
if pet.super and k%4==0 and #minis<6 then spawnMini(pet) end
if chat then pet.nxt=now+math.random(4,7)
if hollow then say(pet,R(L.hollow))
elseif inf and inf.lvl>=1 then say(pet,R(L.brother))
elseif math.random()<0.3 then say(pet,R(pet.sc<5 and L.trap1 or pet.sc<10 and L.trap2 or L.trap3),"hat")
elseif math.random()<0.5 then pet.lunge=now+0.8 say(pet,R(L.lunge))
else say(pet,R(pet.super and L.super or L.evil)) end
end
end
end end
end
end)
local con
con=RS.Heartbeat:Connect(function(dt)
if not F.Parent then con:Disconnect() return end
t=t+dt
for f,b in pairs(items) do f.CFrame=CFrame.new(b.Position+Vector3.new(0,math.sin(t*3)*0.4,0))*CFrame.Angles(0,t*2,0)*b.Rotation end
local ch=plr.Character local r=ch and ch:FindFirstChild("HumanoidRootPart") local hum=ch and ch:FindFirstChildOfClass("Humanoid")
if not r then return end
local hd=ch:FindFirstChild("Head") or r
local now=os.clock() local rpos=r.Position
local friend=inf and inf.lvl>=1
for idx=#minis,1,-1 do local mn=minis[idx]
if not mn.p.Parent or now-mn.t0>25 then mn.p:Destroy() table.remove(minis,idx) else
local d=Vector3.new(rpos.X-mn.pos.X,0,rpos.Z-mn.pos.Z)
local mv=d.Magnitude>0.5 and d.Unit*math.min(d.Magnitude,15*dt) or Vector3.zero
local hit=ground(Vector3.new(mn.pos.X+mv.X,math.max(mn.pos.Y,rpos.Y)+6,mn.pos.Z+mv.Z),60)
local np=Vector3.new(mn.pos.X+mv.X,(hit and hit.Position.Y or rpos.Y-3)+0.5+math.abs(math.sin(t*14+idx))*0.6,mn.pos.Z+mv.Z) mn.pos=np
if d.Magnitude>0.1 then mn.p.CFrame=CFrame.lookAt(np,Vector3.new(rpos.X,np.Y,rpos.Z))*CFrame.Angles(0,math.pi/2,0) end
if d.Magnitude<2.2 and hum and hum.Health>0 and now>prot and not friend then hum:TakeDamage(15) mn.p:Destroy() table.remove(minis,idx) end
end end
for _,pet in ipairs(pets) do local p=pet.p if not pet.falling and not pet.dead and p.Parent then
local bm=1 if pet.bulge and now-pet.bulge<1.2 then local b=now-pet.bulge bm=1+0.3*math.sin(b*22)*(1.2-b) end
p.Size=pet.s0*pet.sc*bm if pet.m then pet.m.Scale=pet.ms0*pet.sc*bm end
local sx,sy,sz,rc=p.Size.X,p.Size.Y,p.Size.Z,pet.rot
local hx=0.5*(math.abs(rc.RightVector.X)*sx+math.abs(rc.UpVector.X)*sy+math.abs(rc.LookVector.X)*sz)
local hy=0.5*(math.abs(rc.RightVector.Y)*sx+math.abs(rc.UpVector.Y)*sy+math.abs(rc.LookVector.Y)*sz)
local hz=0.5*(math.abs(rc.RightVector.Z)*sx+math.abs(rc.UpVector.Z)*sy+math.abs(rc.LookVector.Z)*sz)
local w=math.clamp(math.min(hx,hz)*0.28,0.2,3) local Ll=math.clamp(hy*1.1,0.7,10)*math.min(1,(now-pet.born)/0.6)+0.01
pet.g.StudsOffset=Vector3.new(0,hy+2.5,0)
local frozen=now<pet.stun or pet.dying
local pos=pet.pos
local toP=Vector3.new(rpos.X-pos.X,0,rpos.Z-pos.Z) local distP=toP.Magnitude
local away=distP>0.1 and pos-toP.Unit*25 or pos
local goal,spd=pos,0
if pet.ultra then
if now-pet.ultraT>180 and hum and hum.Health>0 then goal,spd=rpos,16
if distP<hx+4 and not pet.retiring then pet.retiring=true say(pet,"thank you for never giving up on me. goodbye...") task.delay(2,function() local h2=plr.Character and plr.Character:FindFirstChildOfClass("Humanoid") if h2 and pet.acc then for _,x in ipairs(pet.acc:GetDescendants()) do if x:IsA("JointInstance") or x:IsA("WeldConstraint") then x:Destroy() end end h2:AddAccessory(pet.acc) end if not pet.dead then clean(pet) end end) end
else
local tg,bd=nil,80
for _,o in ipairs(pets) do if o~=pet and o.evil and not o.dead and not o.dying and not o.falling then local dd=(o.pos-pos).Magnitude if dd<bd then tg,bd=o,dd end end end
if tg then goal,spd=tg.pos,20
if bd<hx+3+tg.p.Size.Magnitude*0.4 and now>pet.hitT then pet.hitT=now+1.5 pet.spinT=now tg.stun=now+0.8 tg.poison=tg.poison+1 beans(tg.p.Position) say(pet,R(L.ultrafight)) say(tg,"OW!! HAT JUSTICE?!") if tg.poison>=tg.need then die(tg) end end
elseif distP>30 then goal,spd=rpos-toP.Unit*6,22
else goal,spd=wander(pet,pos,rpos,now) end
end
elseif pet.evil then
if hollow then goal,spd=away,14
elseif friend then goal,spd=distP>0.1 and rpos-toP.Unit*(6+hx) or pos,10
else goal=rpos spd=(12+pet.sc*2)*(1-pet.poison/pet.need*0.66)*pet.rage if now<pet.lunge then spd=spd*2.5 end end
else
local tg,bd=nil,40
if pet.beans then for _,o in ipairs(pets) do if o.evil and not o.dead and not o.dying and not o.falling then local dd=(o.pos-pos).Magnitude if dd<bd then tg,bd=o,dd end end end end
if tg then goal,spd=tg.pos,12
if bd<hx+3+tg.p.Size.Magnitude*0.4 and now>pet.hitT then pet.hitT=now+6 pet.spinT=now say(pet,R(L.calm),"hat") tg.stun=now+2 tg.sc=tg.sc-0.3 say(tg,R(L.calmed),"hat") sparkle(tg.p,Color3.fromRGB(255,120,200)) if tg.sc<3 then unEvil(tg) end end
elseif hollow or friend then goal,spd=away,20
elseif distP>30 then goal,spd=rpos-toP.Unit*6,22
elseif pet.hunger<35 and distP>0.1 then goal,spd=rpos-toP.Unit*(4+hx),12
else goal,spd=wander(pet,pos,rpos,now) end
end
if frozen then spd=0 end
local d=Vector3.new(goal.X-pos.X,0,goal.Z-pos.Z) local dist=d.Magnitude
local mv=Vector3.zero if dist>0.6 and spd>0 then mv=d.Unit*math.min(dist,spd*dt) end
local moving=mv.Magnitude>0.001
pet.amp=pet.amp+((moving and 1 or 0)-pet.amp)*math.min(1,dt*8)
pet.ph=pet.ph+mv.Magnitude*2.4/Ll
local swing=math.sin(pet.ph)*0.7*pet.amp
local bob=math.abs(math.cos(pet.ph))*0.15*Ll*pet.amp
local dir=(moving and (not pet.evil or hollow or friend)) and mv or toP
if dir.Magnitude>0.05 then pet.dyaw=math.atan2(-dir.X,-dir.Z) end
pet.yaw=pet.yaw+((pet.dyaw-pet.yaw+math.pi)%(2*math.pi)-math.pi)*math.min(1,dt*10)
local look=0 if not moving and not pet.evil and now-pet.t0>2 then look=math.sin(t*0.8+pet.i*3)*0.6 end
local sp=(now-pet.spinT)/0.7 local ey,jy=0,0
if sp>=0 and sp<1 then ey=sp*math.pi*2 jy=math.sin(sp*math.pi)*(1+hy) end
if pet.evil and now<pet.lunge then jy=math.sin((1-(pet.lunge-now)/0.8)*math.pi)*(Ll+hy)*0.8 end
local hit=ground(Vector3.new(pos.X+mv.X,math.max(pos.Y,rpos.Y)+8,pos.Z+mv.Z),80)
local gy=hit and hit.Position.Y or rpos.Y-3
pet.gy=pet.gy and pet.gy+(gy-pet.gy)*math.min(1,dt*15) or gy
local breathe=math.sin(t*2.5+pet.i)*0.05*hy*(1-pet.amp)
local np=Vector3.new(pos.X+mv.X,pet.gy+Ll+hy+bob+jy+breathe,pos.Z+mv.Z) pet.pos=np
local jit=Vector3.zero if frozen and not pet.eat then jit=Vector3.new(math.random()-0.5,math.random()-0.5,math.random()-0.5)*0.5*pet.sc end
local B=CFrame.new(np)*CFrame.Angles(0,pet.yaw+ey+look,0)
local V=B*CFrame.Angles(-pet.amp*(pet.evil and 0.3 or 0.12),0,math.sin(pet.ph)*0.08*pet.amp)+jit
p.CFrame=V*pet.rot
local es=math.clamp(math.min(hx,hy)*0.5,0.3,6) local blink=now<pet.blink local talking=now-pet.t0<1.5
local flick=pet.evil and now<pet.flicker local slit=pet.evil and not flick
local ecol=pet.ultra and GOLD or slit and (pet.super and PURP or RED) or WHITE
local emat=(pet.ultra or slit) and Enum.Material.Neon or Enum.Material.SmoothPlastic
local lcol=pet.ultra and GOLD or pet.super and SLIMB or pet.evil and ELIMB or LIMB
local lp=(moving and not pet.evil) and np+B.LookVector*10+Vector3.new(0,-2,0) or hd.Position
for k=1,2 do local side=k==1 and -1 or 1
local ec=V*CFrame.new(side*hx*0.4,hy*0.2,-hz-es*0.1)
pet.w[k].Color=ecol pet.w[k].Material=emat
pet.w[k].Size=Vector3.new(es,blink and es*0.1 or es,es*0.6) pet.w[k].CFrame=ec
local ld=ec:VectorToObjectSpace((lp-ec.Position).Unit)
pet.pu[k].Size=slit and Vector3.new(es*0.15,es*0.6,es*0.15) or Vector3.new(es*0.45,es*0.45,es*0.2)
pet.pu[k].CFrame=ec*CFrame.new(ld.X*es*0.2,ld.Y*es*0.2,-es*0.27) pet.pu[k].Transparency=blink and 1 or 0
pet.br[k].Transparency=slit and 0 or 1
if slit then pet.br[k].Size=Vector3.new(es*1.1,es*0.22,es*0.2) pet.br[k].CFrame=ec*CFrame.new(0,es*0.62,-es*0.2)*CFrame.Angles(0,0,side*0.45) end
if pet.super then local xc=V*CFrame.new(side*hx*0.15,hy*0.2+es*1.2,-hz-es*0.1) pet.xw[k].Transparency=0 pet.xp[k].Transparency=0 pet.xw[k].Size=Vector3.new(es*0.8,es*0.8,es*0.5) pet.xw[k].CFrame=xc pet.xp[k].Size=Vector3.new(es*0.12,es*0.5,es*0.12) pet.xp[k].CFrame=xc*CFrame.new(0,0,-es*0.22)
else pet.xw[k].Transparency=1 pet.xp[k].Transparency=1 end
local lc=V*CFrame.new(side*hx*0.45,-hy*0.9,0)*CFrame.Angles(swing*side,0,0)
pet.legs[k].Color=lcol pet.feet[k].Color=lcol pet.arms[k].Color=lcol
pet.legs[k].Size=Vector3.new(w,Ll,w) pet.legs[k].CFrame=lc*CFrame.new(0,-Ll/2,0)
pet.feet[k].Size=Vector3.new(w*1.5,w*0.7,w*2) pet.feet[k].CFrame=lc*CFrame.new(0,-Ll,-w*0.3)
local al=math.max(Ll*0.8,0.5) local ax,az=-swing*side*0.9,side*0.25
if pet.dying then ax,az=math.sin(t*25+side)*0.8,side*(1.5+math.sin(t*30)*0.5)
elseif pet.evil then if frozen then ax,az=0,side*(2.6+math.sin(t*20)*0.3) else ax,az=1.5+math.sin(t*7+side)*0.2,side*0.15 end
elseif sp>=0 and sp<1 then ax,az=0,side*2.6
elseif talking then az=side*(1+math.sin(t*14+side)*0.5) end
pet.arms[k].Size=Vector3.new(w*0.8,al,w*0.8) pet.arms[k].CFrame=V*CFrame.new(side*(hx+w*0.5),hy*0.15,0)*CFrame.Angles(ax,0,az)*CFrame.new(0,-al/2,0)
end
for _,q in ipairs(pet.prompts) do q.MaxActivationDistance=math.max(hx,hz)+14 end
local mw=hx*0.9 local mh=hy*0.06 local ek=pet.eat and now-pet.eat.t0 or 99
if pet.evil then mh=hy*(0.22+0.05*math.sin(t*9)) if ek<1.1 then mh=hy*0.7 elseif ek<1.25 then mh=hy*0.05 end elseif talking then mh=hy*(0.06+0.14*math.abs(math.sin(t*16))) end
local mc=V*CFrame.new(0,-hy*0.3,-hz-0.05)
pet.mo.Size=Vector3.new(mw,math.max(mh,0.05),math.max(hz*0.2,0.1)) pet.mo.CFrame=mc
for k=1,6 do local tt=pet.teeth[k] if pet.evil then local top=k<=3 local tw=mw*0.18 tt.Transparency=0 tt.Size=Vector3.new(tw,tw,tw*0.5) tt.CFrame=mc*CFrame.new(((k-1)%3-1)*mw*0.28,(top and 1 or -1)*(mh/2-tw*0.25),-0.08)*CFrame.Angles(0,0,math.pi/4) else tt.Transparency=1 end end
if pet.evil and not frozen and not eating and not friend and hum and hum.Health>0 and now>prot and distP<math.max(hx,hz)+2.5 then
eating=ch pet.eat={t0=now,ch=ch,r=r,hum=hum,from=r.CFrame} pet.stun=now+2.4 r.Anchored=true hum.WalkSpeed=0 hum.JumpPower=0 say(pet,R(L.grab))
end
if pet.eat then local e=pet.eat
if ek>=0.35 and ek<1.1 and e.r.Parent then local a=(ek-0.35)/0.75 a=a*a e.r.CFrame=e.from:Lerp(mc*CFrame.new(0,0,-1),a) for _,x in ipairs(e.ch:GetDescendants()) do if (x:IsA("BasePart") and x~=e.r) or x:IsA("Decal") then x.Transparency=a end end
elseif ek>=1.1 and not e.done then e.done=true e.hum.Health=0 for _,x in ipairs(e.ch:GetDescendants()) do if x:IsA("BasePart") or x:IsA("Decal") then x.Transparency=1 end end pet.sc=pet.sc+0.5 pet.bulge=now say(pet,R(L.eat))
elseif ek>=1.9 and not e.burp then e.burp=true
if e.hum.Parent and e.hum.Health>0 and e.r.Parent then
for _,x in ipairs(e.ch:GetDescendants()) do if (x:IsA("BasePart") and x~=e.r) or x:IsA("Decal") then x.Transparency=0 end end
e.r.Anchored=false e.hum.WalkSpeed=16 e.hum.JumpPower=50 e.r.AssemblyLinearVelocity=B.LookVector*70+Vector3.new(0,45,0)
pet.survive=pet.survive+1 pet.rage=pet.rage*1.15 pet.sc=pet.sc-0.5 say(pet,R(pet.survive>=3 and L.survive2 or L.survive1))
else say(pet,"*BUUURRRP*") local sm=Instance.new("Smoke") sm.Color=Color3.fromRGB(60,40,20) sm.Size=2 sm.RiseVelocity=5 sm.Parent=p DB:AddItem(sm,1) end
elseif ek>=2.4 then pet.eat=nil if eating==e.ch then eating=nil end end
end
end end
end)
