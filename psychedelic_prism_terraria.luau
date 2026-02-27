-- ================================================================
--  ORBIT PRISMS  |  Script  |  ServerScriptService
--  Host:   Reset6437
--  v10.0  — White Prisms · Laser Beams · 60-stud Range
-- ================================================================

local META = {
	name    = "OrbitPrisms",
	version = "10.0",
	host    = "Reset6437",
}

-- ── Services ──────────────────────────────────────────────────────
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local RS         = game:GetService("ReplicatedStorage")
local Debris     = game:GetService("Debris")

-- ── Remotes ───────────────────────────────────────────────────────
local r_in  = Instance.new("RemoteEvent"); r_in.Name  = "OP_In";  r_in.Parent  = RS
local r_fx  = Instance.new("RemoteEvent"); r_fx.Name  = "OP_Fx";  r_fx.Parent  = RS

-- ── Config ────────────────────────────────────────────────────────
local CFG = {
	count         = 6,
	radius        = 8.0,
	orb_spd       = 0.20,
	orb_spd_max   = 1.8,
	tilt          = 22,
	bob_amp       = 0.5,
	bob_spd       = 0.45,
	bob_phase     = 1.4,

	size          = Vector3.new(1.1, 2.2, 1.1),
	spin_spd      = 0.6,
	spin_max      = 10.0,
	stretch_max   = 1.4,

	heat_rate     = 0.14,
	cool_rate     = 0.08,
	phase2        = 0.55,

	lock_dist     = 60,           -- studs — max range to lock onto an enemy

	beam_len      = 120,
	beam_w        = 0.50,
	spread_max    = 38,
	segments      = 8,

	arc_w         = 0.07,
	arc_spd       = 5.5,

	ptcl_orb_r    = 0.30,
	ptcl_spd      = 2.0,
	ptcl_spd_max  = 18.0,
	ptcl_rate     = 32,

	trail_life    = 0.35,
	trail_max     = 1.8,

	ctr_k=3.5, ctr_d=2.2, ctr_k_max=20, ctr_d_max=5.5,
	tip_k=10,  tip_d=3.5,
	sway_k=7,  sway_d=2.8, sway_scale=0.06, sway_max=0.5,
	rad_k=6,   rad_d=2.8,
	tilt_k=4,  tilt_d=2.5,

	punish_time  = 2.0,
	punish_flash = 7,

	rule_inf_hp  = true,
	rule_max_hp  = 1e6,
	rule_speed   = 120,
	rule_fly_y   = 300,
	rule_no_hum  = false,
}

-- ── Prism appearance ─────────────────────────────────────────────
local T = {
	body   = Color3.new(1, 1, 1),
	trail  = Color3.new(0.9, 0.9, 0.9),
	arc    = Color3.new(0.85, 0.85, 0.85),
	beam_a = Color3.new(0.9, 0.9, 0.9),
	beam_b = Color3.new(1, 1, 1),
}

-- ── Punish Rules ──────────────────────────────────────────────────
local RULES = {
	{ name="InfiniteHealth", check=function(p)
		if not CFG.rule_inf_hp then return false end
		local c=p.Character; if not c then return false end
		local h=c:FindFirstChildOfClass("Humanoid"); if not h then return false end
		if h.Health==math.huge or h.Health~=h.Health or h.Health>=1e15 or h.MaxHealth>=CFG.rule_max_hp then
			return true, ("HP=%.0f MaxHP=%.0f"):format(h.Health, h.MaxHealth) end
		return false
	end},
	{ name="SpeedHack", check=function(p)
		local c=p.Character; if not c then return false end
		local h=c:FindFirstChildOfClass("Humanoid"); if not h then return false end
		if h.WalkSpeed>CFG.rule_speed then return true, ("WS=%.0f"):format(h.WalkSpeed) end
		return false
	end},
	{ name="SkyExploit", check=function(p)
		local c=p.Character; if not c then return false end
		local hrp=c:FindFirstChild("HumanoidRootPart"); if not hrp then return false end
		if hrp.Position.Y>CFG.rule_fly_y then return true, ("Y=%.0f"):format(hrp.Position.Y) end
		return false
	end},
	{ name="NoHumanoid", check=function(p)
		if not CFG.rule_no_hum then return false end
		local c=p.Character; if not c then return false end
		if not c:FindFirstChildOfClass("Humanoid") then return true, "no humanoid" end
		return false
	end},
}

-- ── Helpers ───────────────────────────────────────────────────────
local function lerp(a,b,t) return a+(b-a)*t end
local function c01(t)      return math.clamp(t,0,1) end
local function lerpc(a,b,t)
	return Color3.new(lerp(a.R,b.R,t),lerp(a.G,b.G,t),lerp(a.B,b.B,t))
end
local function rot_around(v,axis,ang)
	local c,s=math.cos(ang),math.sin(ang)
	return v*c+axis:Cross(v)*s+axis*(axis:Dot(v))*(1-c)
end
local function sv3(cur,goal,vel,k,d,dt)
	local f=(goal-cur)*k-vel*d; vel=vel+f*dt; cur=cur+vel*dt; return cur,vel
end
local function ss(cur,goal,vel,k,d,dt)
	local f=(goal-cur)*k-vel*d; vel=vel+f*dt; cur=cur+vel*dt; return cur,vel
end
local function face_up(pos,up,spin)
	local ref=math.abs(up:Dot(Vector3.new(1,0,0)))<0.95 and Vector3.new(1,0,0) or Vector3.new(0,0,1)
	local r=up:Cross(ref).Unit; local f=r:Cross(up).Unit
	return CFrame.fromMatrix(pos,r,up,-f)*CFrame.Angles(0,spin,0)
end
local function get_host_hrp()
	local p=Players:FindFirstChild(META.host)
	if p and p.Character then return p.Character:FindFirstChild("HumanoidRootPart") end
end
local function get_nearest_enemy(host_pos)
	local best,bestD=nil,math.huge
	for _,p in ipairs(Players:GetPlayers()) do
		if p.Name~=META.host and p.Character then
			local hrp=p.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local d=(hrp.Position-host_pos).Magnitude
				if d<bestD then best,bestD=p,d end
			end
		end
	end
	return best,bestD
end
local function make_anchor()
	local p=Instance.new("Part")
	p.Size=Vector3.new(0.05,0.05,0.05); p.Anchored=true
	p.CanCollide=false; p.Transparency=1; p.CastShadow=false
	return p,Instance.new("Attachment",p)
end
local function check_rules(player)
	for _,rule in ipairs(RULES) do
		local hit,detail=rule.check(player)
		if hit then return true, rule.name.." (".. (detail or "") ..")" end
	end
	return false
end

-- ── Build Scene ───────────────────────────────────────────────────
local folder=Instance.new("Folder"); folder.Name=META.name.."_v"..META.version; folder.Parent=workspace

local prisms={}
for i=1,CFG.count do
	local w=Instance.new("WedgePart")
	w.Name="Prism_"..i; w.Size=CFG.size; w.Anchored=true
	w.CanCollide=false; w.CastShadow=false
	w.Material=Enum.Material.Neon; w.Color=T.body; w.Parent=folder

	local hl=Instance.new("Highlight",w)
	hl.FillTransparency=1; hl.OutlineTransparency=0; hl.OutlineColor=T.trail

	local ta0=Instance.new("Attachment",w); ta0.Position=Vector3.new(0, CFG.size.Y/2,0)
	local ta1=Instance.new("Attachment",w); ta1.Position=Vector3.new(0,-CFG.size.Y/2,0)
	local trail=Instance.new("Trail")
	trail.Attachment0=ta0; trail.Attachment1=ta1
	trail.Lifetime=CFG.trail_life; trail.MinLength=0; trail.FaceCamera=true
	trail.WidthScale=NumberSequence.new({NumberSequenceKeypoint.new(0,0.7),NumberSequenceKeypoint.new(1,0)})
	trail.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.1),NumberSequenceKeypoint.new(1,1)})
	trail.Color=ColorSequence.new({
		ColorSequenceKeypoint.new(0,T.trail),
		ColorSequenceKeypoint.new(1,T.body),
	})
	trail.Parent=w

	-- 4-channel spread beams
	local beams={}
	for j=1,4 do
		local orig=Instance.new("Attachment",w); orig.Position=Vector3.new(0,CFG.size.Y/2,0)
		local ep,ea=make_anchor(); ep.Parent=folder
		local bm=Instance.new("Beam")
		bm.Attachment0=orig; bm.Attachment1=ea; bm.FaceCamera=true
		bm.Width0=0; bm.Width1=0; bm.Segments=CFG.segments
		bm.LightEmission=1; bm.LightInfluence=0; bm.Enabled=false
		bm.Transparency=NumberSequence.new({
			NumberSequenceKeypoint.new(0,0.0),
			NumberSequenceKeypoint.new(0.4,0.35),
			NumberSequenceKeypoint.new(1,1.0),
		})
		bm.Color=ColorSequence.new({
			ColorSequenceKeypoint.new(0,T.beam_a),
			ColorSequenceKeypoint.new(0.5,T.beam_b),
			ColorSequenceKeypoint.new(1,Color3.new(1,1,1)),
		})
		bm.Parent=w
		beams[j]={orig=orig,ep=ep,ea=ea,beam=bm}
	end

	-- Arc beam to next prism (phase 2)
	local aep,aea=make_anchor(); aep.Parent=folder
	local saa=Instance.new("Attachment",w)
	local abm=Instance.new("Beam")
	abm.Attachment0=saa; abm.Attachment1=aea; abm.FaceCamera=false
	abm.Width0=CFG.arc_w; abm.Width1=CFG.arc_w; abm.Segments=14
	abm.LightEmission=1; abm.LightInfluence=0
	abm.CurveSize0=2; abm.CurveSize1=2; abm.Enabled=false
	abm.Transparency=NumberSequence.new({
		NumberSequenceKeypoint.new(0,0.5),
		NumberSequenceKeypoint.new(0.5,0.08),
		NumberSequenceKeypoint.new(1,0.5),
	})
	abm.Color=ColorSequence.new(T.arc); abm.Parent=w

	-- 4 spinning tip emitters
	local emitters={}
	for j=1,4 do
		local sa=Instance.new("Attachment",w); sa.Position=Vector3.new(0,CFG.size.Y/2,0)
		local pe=Instance.new("ParticleEmitter")
		pe.Texture="rbxasset://textures/particles/sparkles_main.dds"
		pe.Rate=0; pe.Lifetime=NumberRange.new(0.2,0.6)
		pe.Speed=NumberRange.new(8,28); pe.SpreadAngle=Vector2.new(6,6)
		pe.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0.35),NumberSequenceKeypoint.new(0.5,0.18),NumberSequenceKeypoint.new(1,0)})
		pe.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)})
		pe.RotSpeed=NumberRange.new(-200,200); pe.LightEmission=1; pe.LightInfluence=0
		pe.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,T.body),ColorSequenceKeypoint.new(1,T.trail)})
		pe.Enabled=false; pe.Parent=sa
		emitters[j]={att=sa,pe=pe}
	end

	prisms[i]={
		w=w, hl=hl, trail=trail, ta0=ta0, ta1=ta1,
		beams=beams,
		abm=abm, aep=aep, aea=aea,
		emitters=emitters,
	}
end

-- ── Runtime state ─────────────────────────────────────────────────
local heat=0
local orb_acc=0; local spin_acc=0; local ptcl_acc=0; local arc_acc=0
local ctr_pos=nil; local ctr_vel=Vector3.new()
local last_pos=nil

local tip_dir={} local tip_vel={}
local sway_p={} local sway_pv={} local sway_r={} local sway_rv={}
local tilt_cur=0; local tilt_vel=0
local rad_cur=CFG.radius; local rad_vel=0

local rule_timer=0

local punish_mode  =false
local punish_active=false
local punish_t     =0
local punish_target=nil
local punish_reason=""

for i=1,CFG.count do
	tip_dir[i]=Vector3.new(0,1,0); tip_vel[i]=Vector3.new()
	sway_p[i]=0; sway_pv[i]=0; sway_r[i]=0; sway_rv[i]=0
end

local STEP=(2*math.pi)/CFG.count

-- ── Punish ────────────────────────────────────────────────────────
local function start_punish(player, reason)
	if punish_active then return end
	punish_active=true; punish_target=player; punish_reason=reason or "Manual"
	punish_t=0; heat=1
	print(("[%s] PUNISHING %s — %s"):format(META.name, player.Name, punish_reason))
	r_fx:FireAllClients("punish_start", player.Name, punish_reason)
end

local function finish_punish()
	local p=punish_target
	if p then
		if p.Character then p.Character:Destroy(); p.Character=nil end
		local bp=p:FindFirstChildOfClass("Backpack"); if bp then bp:ClearAllChildren() end
		pcall(function() p:Kick("Punished — "..punish_reason) end)
	end
	r_fx:FireAllClients("punish_end")
	punish_active=false; punish_target=nil; punish_t=0; heat=0
end

-- ── Remote input ──────────────────────────────────────────────────
r_in.OnServerEvent:Connect(function(sender, action)
	if sender.Name ~= META.host then return end
	if action=="toggle_punish" then
		punish_mode=not punish_mode
		print(("[%s] Punish mode: %s"):format(META.name, tostring(punish_mode)))
		r_fx:FireAllClients("mode_changed", punish_mode)
	elseif action=="punish_now" then
		local hrp=get_host_hrp(); if not hrp then return end
		local ep,ed=get_nearest_enemy(hrp.Position)
		if ep and ed<=CFG.lock_dist then start_punish(ep,"Manual[NumpadOne]") end
	end
end)

local function hide_all()
	for _,d in ipairs(prisms) do
		d.w.Transparency=1
		for _,b in ipairs(d.beams) do b.beam.Enabled=false end
		d.abm.Enabled=false
		for _,e in ipairs(d.emitters) do e.pe.Enabled=false; e.pe.Rate=0 end
	end
end

-- ── Main loop ─────────────────────────────────────────────────────
RunService.Heartbeat:Connect(function(dt)
	dt=math.min(dt,0.05)
	local now=tick()

	local hrp=get_host_hrp()
	if not hrp then hide_all(); last_pos=nil; return end
	local host_pos=hrp.Position

	-- ── Auto-rules (every 1s) ────────────────────────────────────
	rule_timer=rule_timer+dt
	if rule_timer>=1 then
		rule_timer=0
		if not punish_active then
			for _,p in ipairs(Players:GetPlayers()) do
				if p.Name~=META.host then
					local flagged,reason=check_rules(p)
					if flagged then start_punish(p,"AutoRule: "..reason); break end
				end
			end
		end
	end

	-- ── Target (range-gated at lock_dist studs) ──────────────────
	local enemy_player, enemy_dist = get_nearest_enemy(host_pos)
	if punish_active and punish_target then
		enemy_player = punish_target
		local ec = punish_target.Character
		local eh = ec and ec:FindFirstChild("HumanoidRootPart")
		enemy_dist = eh and (eh.Position - host_pos).Magnitude or math.huge
	end

	-- Only lock if within range
	local in_range = enemy_dist and enemy_dist <= CFG.lock_dist
	local enemy_hrp = in_range and enemy_player and enemy_player.Character
		and enemy_player.Character:FindFirstChild("HumanoidRootPart") or nil

	if punish_active and not enemy_hrp then finish_punish(); return end
	local locked = enemy_hrp ~= nil

	-- ── Punish timer ──────────────────────────────────────────────
	if punish_active then
		punish_t=punish_t+dt/CFG.punish_time
		if punish_t>=1 then finish_punish(); return end
	end
	local pun_t = punish_active and punish_t or nil

	-- ── Heat ─────────────────────────────────────────────────────
	if punish_active then
		heat=1
	elseif punish_mode and locked then
		heat=c01(heat+dt*CFG.heat_rate*2.5)
	elseif locked then
		heat=c01(heat+dt*CFG.heat_rate)
	else
		heat=c01(heat-dt*CFG.cool_rate)
	end

	local p2       = heat >= CFG.phase2
	local phase2_t = c01((heat-CFG.phase2)/(1-CFG.phase2))

	-- ── Angles ───────────────────────────────────────────────────
	local pm  = pun_t and lerp(1,5,punish_t) or 1
	orb_acc   = orb_acc  + lerp(CFG.orb_spd, CFG.orb_spd_max, heat)*pm*dt*(2*math.pi)
	spin_acc  = spin_acc + lerp(CFG.spin_spd, CFG.spin_max,   heat)*pm*dt
	ptcl_acc  = ptcl_acc + lerp(CFG.ptcl_spd, CFG.ptcl_spd_max,heat)*dt
	arc_acc   = arc_acc  + lerp(1, CFG.arc_spd, heat)*pm*dt

	-- ── Sway ─────────────────────────────────────────────────────
	local vel_v=last_pos and (host_pos-last_pos)/dt or Vector3.new()
	last_pos=host_pos
	local fwd=hrp.CFrame.LookVector; local rgt=hrp.CFrame.RightVector
	local ptgt=math.clamp(-vel_v:Dot(fwd)*CFG.sway_scale,-CFG.sway_max,CFG.sway_max)
	local rtgt=math.clamp( vel_v:Dot(rgt)*CFG.sway_scale,-CFG.sway_max,CFG.sway_max)

	-- ── Springs ───────────────────────────────────────────────────
	local ck=lerp(CFG.ctr_k,CFG.ctr_k_max,heat)
	local cd=lerp(CFG.ctr_d,CFG.ctr_d_max,heat)
	if not ctr_pos then ctr_pos=host_pos end
	ctr_pos,ctr_vel=sv3(ctr_pos,host_pos,ctr_vel,ck,cd,dt)

	tilt_cur,tilt_vel=ss(tilt_cur,math.rad(lerp(0,CFG.tilt,heat)),tilt_vel,CFG.tilt_k,CFG.tilt_d,dt)

	local rad_goal = pun_t and lerp(CFG.radius,0.5,punish_t^1.5) or CFG.radius
	rad_cur,rad_vel=ss(rad_cur,rad_goal,rad_vel,CFG.rad_k,CFG.rad_d,dt)
	local radius=rad_cur+math.sin(now*0.28*math.pi*2)*0.55*(pun_t and (1-punish_t) or 1)

	-- ── Fire direction ────────────────────────────────────────────
	local fire_dir
	if enemy_hrp then
		local d=enemy_hrp.Position-ctr_pos
		fire_dir=d.Magnitude>0.5 and d.Unit or Vector3.new(0,0,1)
	else
		local a=now*0.4; fire_dir=Vector3.new(math.cos(a),0,math.sin(a))
	end

	local up_ref  = math.abs(fire_dir:Dot(Vector3.new(0,1,0)))<0.95
		and Vector3.new(0,1,0) or Vector3.new(1,0,0)
	local f_right = fire_dir:Cross(up_ref).Unit
	local f_up    = f_right:Cross(fire_dir).Unit
	local perp    = {f_up,-f_up,f_right,-f_right}

	local spread_t   = c01(heat/CFG.phase2)
	local spread_ang = math.rad(lerp(CFG.spread_max, CFG.spread_max*0.35, spread_t))
	local beam_w     = heat * CFG.beam_w * (pun_t and lerp(1,3,punish_t) or 1)

	-- ── Orbit center ─────────────────────────────────────────────
	local orbit_center = pun_t and enemy_hrp
		and ctr_pos:Lerp(enemy_hrp.Position, punish_t^1.5)
		or ctr_pos

	-- ── Prism positions ───────────────────────────────────────────
	local pos_table={}
	for i=1,CFG.count do
		local theta = orb_acc+(i-1)*STEP
		local bob   = math.sin(now*CFG.bob_spd*math.pi*2+(i-1)*CFG.bob_phase)*CFG.bob_amp
			*(pun_t and (1-punish_t) or 1)
		local fx    = math.cos(theta)*radius
		local fz    = math.sin(theta)*radius
		pos_table[i]=orbit_center+Vector3.new(
			fx*math.cos(tilt_cur),
			fx*math.sin(tilt_cur)+bob,
			fz
		)
	end

	-- ── Per-prism ─────────────────────────────────────────────────
	for i,d in ipairs(prisms) do
		d.w.Transparency=0
		local wpos=pos_table[i]

		local tk=pun_t and 40 or CFG.tip_k
		local tdp=pun_t and 9 or CFG.tip_d
		tip_dir[i],tip_vel[i]=sv3(tip_dir[i],fire_dir,tip_vel[i],tk,tdp,dt)
		local tip=tip_dir[i].Magnitude>0.001 and tip_dir[i].Unit or Vector3.new(0,1,0)

		local po=(i-1)*0.3
		sway_p[i],sway_pv[i]=ss(sway_p[i],ptgt*math.cos(po),    sway_pv[i],CFG.sway_k,CFG.sway_d,dt)
		sway_r[i],sway_rv[i]=ss(sway_r[i],rtgt*math.cos(po+0.5),sway_rv[i],CFG.sway_k,CFG.sway_d,dt)

		local p_hz    = pun_t and 5 or lerp(0.55,2.5,heat)
		local p_phase = now*p_hz*math.pi*2+(i-1)*0.9
		local pulse_amp = pun_t and lerp(0.4,2.5,punish_t) or lerp(0.12,0.55,heat)
		local pulse  = math.sin(p_phase)*pulse_amp
		local pulse2 = math.sin(p_phase*1.618+i)*pulse_amp*0.4
		local stretch= lerp(0,CFG.stretch_max*(pun_t and 4 or 1),heat)
		local sz=Vector3.new(
			math.max(0.05, CFG.size.X+pulse+pulse2),
			math.max(0.05, CFG.size.Y+pulse*1.3+stretch),
			math.max(0.05, CFG.size.Z+pulse+pulse2)
		)
		d.w.Size=sz
		d.ta0.Position=Vector3.new(0, sz.Y/2,0)
		d.ta1.Position=Vector3.new(0,-sz.Y/2,0)
		d.trail.Lifetime=lerp(CFG.trail_life,CFG.trail_max*(pun_t and 3 or 1),heat)

		d.w.CFrame=face_up(wpos,tip,spin_acc+(i-1)*(math.pi*2/CFG.count))
			*CFrame.Angles(sway_p[i],0,sway_r[i])

		local body_c = pun_t
			and lerpc(T.body, Color3.new(1,0.1,0), punish_t)
			or  T.body
		local out_c = pun_t
			and (math.floor(now*CFG.punish_flash)%3==0 and Color3.new(1,0,0) or Color3.new(1,0.5,0))
			or  T.trail

		d.w.Color=body_c
		d.hl.OutlineColor=out_c
		d.hl.OutlineTransparency=math.abs(math.sin(now*(pun_t and 35 or 8)+i))*0.4
		d.trail.Color=ColorSequence.new({
			ColorSequenceKeypoint.new(0, pun_t and lerpc(Color3.new(1,0,0),Color3.new(1,0.5,0),math.sin(now*8)*0.5+0.5) or T.trail),
			ColorSequenceKeypoint.new(1, T.body),
		})

		local tip_world=d.w.CFrame*Vector3.new(0,sz.Y/2,0)
		local active=locked and enemy_hrp~=nil

		-- ── 4-channel spread beams ────────────────────────────────
		for j,b in ipairs(d.beams) do
			if active and heat>0.02 then
				b.beam.Enabled=true
				local s_dir=rot_around(fire_dir,perp[j],spread_ang)
				local end_pt=tip_world+s_dir*CFG.beam_len
				b.orig.WorldPosition=tip_world; b.ep.CFrame=CFrame.new(end_pt)
				local bw=beam_w*(0.6+0.4*math.sin(now*14+i+j))
				local bw2=pun_t and bw*lerp(1,4,punish_t) or bw
				b.beam.Width0=bw2; b.beam.Width1=bw2*0.08
				b.beam.Color=ColorSequence.new({
					ColorSequenceKeypoint.new(0,  pun_t and Color3.new(1,0.2,0) or T.beam_a),
					ColorSequenceKeypoint.new(0.45,T.beam_b),
					ColorSequenceKeypoint.new(1,  Color3.new(1,1,1)),
				})
			else
				b.beam.Enabled=false
			end
		end

		-- ── Arc beams (phase2) ────────────────────────────────────
		if p2 or pun_t then
			local np=pos_table[(i%CFG.count)+1]
			d.aep.CFrame=CFrame.new(np)
			d.abm.CurveSize0=2.5+math.sin(arc_acc+i)*2.5
			d.abm.CurveSize1=2.5+math.cos(arc_acc+i)*2.5
			local arc_w2=pun_t and lerp(CFG.arc_w,0.5,punish_t) or CFG.arc_w
			d.abm.Width0=arc_w2; d.abm.Width1=arc_w2; d.abm.Enabled=true
			local at=lerp(0.6,0.05,pun_t and punish_t or phase2_t)
			d.abm.Transparency=NumberSequence.new({
				NumberSequenceKeypoint.new(0,at),
				NumberSequenceKeypoint.new(0.5,at*0.2),
				NumberSequenceKeypoint.new(1,at),
			})
			d.abm.Color=ColorSequence.new(
				pun_t and lerpc(Color3.new(1,0,0),Color3.new(1,0.5,0),math.sin(now*10+i)*0.5+0.5)
				or T.arc
			)
		else
			d.abm.Enabled=false
		end

		-- ── Spinning tip emitters ─────────────────────────────────
		for j,e in ipairs(d.emitters) do
			if active and heat>0.02 then
				local ang    = ptcl_acc+(j-1)*(math.pi/2)
				local sp_ref = math.abs(tip:Dot(Vector3.new(1,0,0)))<0.95
					and Vector3.new(1,0,0) or Vector3.new(0,0,1)
				local sp_r=tip:Cross(sp_ref).Unit
				local sp_u=tip:Cross(sp_r).Unit
				local off=(sp_r*math.cos(ang)+sp_u*math.sin(ang))*CFG.ptcl_orb_r
				e.att.WorldPosition=tip_world+off
				e.att.WorldCFrame=CFrame.lookAt(tip_world+off,tip_world+off+fire_dir)
				e.pe.Enabled=true
				e.pe.Rate=heat*CFG.ptcl_rate*(pun_t and lerp(1,5,punish_t) or 1)
				e.pe.SpreadAngle=Vector2.new(lerp(28,4,spread_t),lerp(28,4,spread_t))
				e.pe.Color=ColorSequence.new({
					ColorSequenceKeypoint.new(0,T.body),
					ColorSequenceKeypoint.new(1,T.trail),
				})
			else
				e.pe.Enabled=false; e.pe.Rate=0
			end
		end
	end
end)