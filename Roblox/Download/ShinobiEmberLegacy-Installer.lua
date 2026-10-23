-- SHINOBI: EMBER LEGACY v2 — ROBLOX STUDIO INSTALLER / UPDATER
-- Open your previously installed Shinobi place, or a new Baseplate. STOP Play mode.
-- Save your place first, then open the Command Bar from Studio's View or Window menu.
-- Copy this ENTIRE file, paste into the Command Bar, and press Enter.
-- Wait for the success message, then press Play. Do not paste into a normal Script.
-- This installer includes every game script; no downloads or HTTP settings are needed.

assert(not game:GetService("RunService"):IsRunning(), "Stop Play mode before installing Shinobi.")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local ServerStorage = game:GetService("ServerStorage")
local starterScripts = StarterPlayer:FindFirstChildOfClass("StarterPlayerScripts")
assert(starterScripts, "StarterPlayerScripts is missing. Open a fresh Baseplate and try again.")
local previousRoots = {}
for _, target in {
    { ReplicatedStorage, "Shinobi" },
    { ServerScriptService, "ShinobiServer" },
    { starterScripts, "ShinobiClient" },
} do
    local previous = target[1]:FindFirstChild(target[2])
    if previous then
        assert(previous:IsA("Folder") and previous:GetAttribute("ShinobiInstaller") == true,
            "An unrecognized " .. target[2] .. " folder exists. Open a NEW Baseplate to install safely.")
        table.insert(previousRoots, previous)
    end
end
local previousWorld = workspace:FindFirstChild("ShinobiWorld")
assert(not previousWorld or previousWorld:GetAttribute("ShinobiGenerated") == true or #previousRoots == 3,
    "An unrelated ShinobiWorld folder exists. Open a NEW Baseplate to install safely.")

local scripts = {
{ Destination = "shared", ClassName = "ModuleScript", Name = "Config", Source = [====[
-- Shared tuning only; the server owns every gameplay decision.
local Config = {}

Config.Title = "SHINOBI"
Config.Subtitle = "EMBER LEGACY"
Config.MaxHealth = 150
Config.MaxChakra = 100
Config.ChakraRegen = 5
Config.ChargeRegen = 25
Config.ChargeDuration = 2.5
Config.MaxLevel = 30
Config.GlobalActionInterval = 0.12
Config.WalkSpeed = 22
Config.Mission = { Title = "Protect the Ember Village", Goal = 5, XP = 180, Coins = 90 }
Config.ActionOrder = { "Strike", "Rasengan", "Fireball", "ShadowClone", "Dash", "Charge" }
Config.Actions = {
	Strike = { Label = "Taijutsu", Key = "M1", Cost = 0, Cooldown = 0.45, UnlockLevel = 1, Damage = 18, Range = 7, Radius = 4 },
	Rasengan = { Label = "Rasengan", Key = "Z", Cost = 25, Cooldown = 5, UnlockLevel = 1, Damage = 58, Range = 9, Radius = 9 },
	Fireball = { Label = "Fireball", Key = "X", Cost = 30, Cooldown = 7, UnlockLevel = 2, Damage = 72, Range = 80, Radius = 5 },
	ShadowClone = { Label = "Shadow Clone", Key = "C", Cost = 40, Cooldown = 14, UnlockLevel = 3, Damage = 14, Range = 15, Radius = 8 },
	Dash = { Label = "Substitution Dash", Key = "Q", Cost = 12, Cooldown = 2, UnlockLevel = 1, Damage = 0, Range = 20, Radius = 0 },
	Charge = { Label = "Focus Chakra", Key = "R", Cost = 0, Cooldown = 3, UnlockLevel = 1, Damage = 0, Range = 0, Radius = 0 },
}
Config.Enemies = {
	Dummy = { Health = 160, Damage = 0, Speed = 0, AggroRange = 0, AttackRange = 0, AttackCooldown = 3, XP = 0, Coins = 0, RespawnTime = 4 },
	Bandit = { Health = 110, Damage = 13, Speed = 12, AggroRange = 32, AttackRange = 6, AttackCooldown = 2.2, XP = 35, Coins = 15, RespawnTime = 12 },
	Boss = { Health = 1200, Damage = 32, Speed = 10, AggroRange = 44, AttackRange = 14, AttackCooldown = 4, XP = 300, Coins = 200, RespawnTime = 40 },
}

return Config
]====] },
{ Destination = "shared", ClassName = "ModuleScript", Name = "Rules", Source = [====[
-- Pure rules: also executed by the standalone Luau regression suite.
local Config = if script then require(script.Parent.Config) else require("./Config")
local Rules = {}

function Rules.finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function integer(value, fallback, maximum)
	if not Rules.finite(value) then return fallback end
	return math.clamp(math.floor(value), 0, maximum)
end

function Rules.newProfile()
	return { Level = 1, XP = 0, Coins = 0, TotalKills = 0, BossKills = 0, MissionActive = false, MissionKills = 0 }
end

function Rules.xpRequired(level)
	return 100 + (level - 1) * 60
end

function Rules.sanitizeProfile(raw)
	local data = Rules.newProfile()
	if type(raw) ~= "table" then return data end
	data.Level = math.max(1, integer(raw.Level, 1, Config.MaxLevel))
	data.XP = integer(raw.XP, 0, Rules.xpRequired(data.Level) - 1)
	data.Coins = integer(raw.Coins, 0, 1000000000)
	data.TotalKills = integer(raw.TotalKills, 0, 1000000000)
	data.BossKills = integer(raw.BossKills, 0, 1000000000)
	data.MissionActive = raw.MissionActive == true
	data.MissionKills = if data.MissionActive then integer(raw.MissionKills, 0, Config.Mission.Goal) else 0
	return data
end

function Rules.rank(level)
	if level >= 20 then return "Kage" end
	if level >= 10 then return "Jonin" end
	if level >= 5 then return "Chunin" end
	return "Genin"
end

function Rules.awardXP(data, amount)
	if not Rules.finite(amount) or amount <= 0 then return 0 end
	local before = data.Level
	data.XP += math.floor(math.min(amount, 1000000))
	while data.Level < Config.MaxLevel and data.XP >= Rules.xpRequired(data.Level) do
		data.XP -= Rules.xpRequired(data.Level)
		data.Level += 1
	end
	if data.Level == Config.MaxLevel then data.XP = math.min(data.XP, Rules.xpRequired(data.Level) - 1) end
	return data.Level - before
end

function Rules.awardKill(data, kind)
	local enemy = Config.Enemies[kind]
	if not enemy or kind == "Dummy" then return false end
	data.TotalKills += 1
	if kind == "Boss" then data.BossKills += 1 end
	data.Coins += enemy.Coins
	Rules.awardXP(data, enemy.XP)
	if data.MissionActive and kind == "Bandit" then
		data.MissionKills = math.min(Config.Mission.Goal, data.MissionKills + 1)
	end
	return true
end

function Rules.interactMission(data)
	if not data.MissionActive then
		data.MissionActive = true
		data.MissionKills = 0
		return "Mission accepted. Defeat five bandits at the camp, then return to Sensei."
	elseif data.MissionKills >= Config.Mission.Goal then
		data.Coins += Config.Mission.Coins
		Rules.awardXP(data, Config.Mission.XP)
		data.MissionActive = false
		data.MissionKills = 0
		return "Mission complete! +180 XP · +90 Ryo. Speak again for another mission."
	end
	return "Defeat the remaining bandits, then return to Sensei."
end

function Rules.tryAction(entry, actionId, now)
	if type(actionId) ~= "string" then return false, "Unknown jutsu." end
	local action = Config.Actions[actionId]
	if not action then return false, "Unknown jutsu." end
	if not entry or not entry.Ready or not Rules.finite(now) then return false, "Your shinobi is loading." end
	if entry.Data.Level < action.UnlockLevel then return false, "Unlocks at level " .. action.UnlockLevel .. "." end
	if now - entry.LastActionAt < Config.GlobalActionInterval then return false, "" end
	if (entry.Cooldowns[actionId] or 0) > now then return false, "Jutsu is recharging." end
	if entry.Chakra < action.Cost then return false, "Focus chakra with R." end
	entry.Chakra -= action.Cost
	entry.Cooldowns[actionId] = now + action.Cooldown
	entry.LastActionAt = now
	return true, ""
end

return Rules
]====] },
{ Destination = "server", ClassName = "ModuleScript", Name = "CombatService", Source = [====[
-- The client requests an ability; the server chooses its origin, cost, and hits.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local shared = ReplicatedStorage:WaitForChild("Shinobi")
local Config = require(shared:WaitForChild("Config"))
local Rules = require(shared:WaitForChild("Rules"))

local CombatService = {}
CombatService.__index = CombatService

local MAX_COORDINATE = 100000
local CLONE_DURATION = 4.8
local CLONE_INTERVAL = 0.8

local function finiteNumber(value)
	return type(value) == "number" and value == value and math.abs(value) < MAX_COORDINATE
end

local function finiteVector(value)
	return typeof(value) == "Vector3"
		and finiteNumber(value.X) and finiteNumber(value.Y) and finiteNumber(value.Z)
end

local function characterParts(player)
	local character = player.Character
	if not character or not character.Parent then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not finiteVector(root.Position) then
		return nil
	end
	return character, humanoid, root
end

local function directionTo(root, aim, horizontal)
	local delta = aim - root.Position
	if horizontal then
		delta = Vector3.new(delta.X, 0, delta.Z)
	end
	if delta.Magnitude < 0.01 then
		delta = root.CFrame.LookVector
		if horizontal then
			delta = Vector3.new(delta.X, 0, delta.Z)
		end
	end
	if delta.Magnitude < 0.01 then
		return Vector3.new(0, 0, -1)
	end
	return delta.Unit
end

function CombatService.new(enemies, players, remotes)
	return setmetatable({
		_enemies = enemies,
		_players = players,
		_remotes = remotes,
		_clones = {},
		_pending = {},
		_destroyed = false,
	}, CombatService)
end

function CombatService:_effect(kind, position, target, extra)
	if self._destroyed then
		return
	end
	local effect = extra or {}
	effect.Kind = kind
	effect.Position = position
	effect.Target = target
	self._remotes.Effect:FireAllClients(effect)
end

function CombatService:_dash(character, root, direction, distance)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.RespectCanCollide = true
	local displacement = direction * distance
	-- Sweep the character's body rather than a single ray through thin obstacles.
	local collision = workspace:Blockcast(root.CFrame, Vector3.new(2.5, 4, 2.5), displacement, params)
	if collision then
		distance = math.max(0, collision.Distance - 1)
		displacement = direction * distance
	end
	local origin = root.Position
	character:PivotTo(character:GetPivot() + displacement)
	root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
	self:_effect("Dash", origin, root.Position, { Duration = 0.25 })
end

function CombatService:_impact(player, attack, root)
	local action = Config.Actions[attack.Action]
	local origin = root.Position
	local forward = directionTo(root, attack.Aim, true)
	if attack.Action == "Strike" then
		local center = origin + forward * math.min(action.Range, 5)
		self._enemies:DamageInRadius(player, center, action.Radius, action.Damage)
		self:_effect("Strike", origin, center, { Radius = action.Radius, Duration = 0.2 })
	elseif attack.Action == "Rasengan" then
		local center = origin + forward * math.min(action.Range, 6)
		self._enemies:DamageInRadius(player, center, action.Radius, action.Damage)
		self:_effect("Rasengan", center, nil, { Radius = action.Radius, Duration = 0.65 })
	elseif attack.Action == "Fireball" then
		local fireOrigin = origin + Vector3.new(0, 1, 0)
		local direction = directionTo(root, attack.Aim, false)
		local hit = self._enemies:DamageRay(player, fireOrigin, direction, action.Range, action.Radius, action.Damage)
		self:_effect("Fireball", fireOrigin, hit or fireOrigin + direction * action.Range, {
			Radius = action.Radius, Duration = 0.45,
		})
	end
end

function CombatService:HandleAction(player, actionId, aimPosition)
	if self._destroyed or type(actionId) ~= "string" or #actionId > 32 then
		return
	end
	local action = Config.Actions[actionId]
	if not action then
		return
	end
	local entry = self._players:Get(player)
	if not entry or not entry.Ready then
		return
	end
	local character, _, root = characterParts(player)
	if not character then
		return
	end
	if aimPosition == nil then
		aimPosition = root.Position + root.CFrame.LookVector * 50
	elseif not finiteVector(aimPosition) then
		return
	end
	local now = workspace:GetServerTimeNow()
	local accepted = Rules.tryAction(entry, actionId, now)
	if not accepted then
		-- Invalid requests are silent; regular cooldowns are already visible in HUD.
		-- Avoid turning rejected remote spam into state broadcasts.
		return
	end
	entry.ChargingUntil = nil
	-- A dodge or a new jutsu can interrupt the wind-up of the previous action.
	self._pending[player] = nil
	local forward = directionTo(root, aimPosition, true)
	local origin = root.Position
	local combo = 1
	if actionId ~= "Charge" then
		root.CFrame = CFrame.lookAt(origin, origin + forward)
	end
	if actionId == "Strike" then
		combo = if now - (entry.LastStrikeAt or -math.huge) <= 1.1 then (entry.StrikeCombo or 0) % 3 + 1 else 1
		entry.LastStrikeAt = now
		entry.StrikeCombo = combo
	end
	local durations = { Strike = if combo == 3 then 0.58 else 0.42, Rasengan = 0.6,
		Fireball = 0.65, ShadowClone = 0.75, Dash = 0.25, Charge = Config.ChargeDuration }
	self:_effect("CombatAnimation", origin, nil, {
		Actor = character, Action = actionId, Combo = combo,
		StartedAt = now, Duration = durations[actionId],
	})
	if actionId == "Strike" or actionId == "Rasengan" or actionId == "Fireball" then
		local delay = if actionId == "Fireball" then 0.32 elseif actionId == "Rasengan" or combo == 3 then 0.24 else 0.15
		self._pending[player] = { Character = character, Action = actionId, Aim = aimPosition, At = now + delay }
	elseif actionId == "ShadowClone" then
		-- One clone per owner; pulses are processed in Step and die with the character.
		self._clones[player] = {
			Character = character,
			Expires = now + CLONE_DURATION,
			NextPulse = now + 0.35,
			Damage = action.Damage,
			Radius = action.Radius,
			Range = action.Range,
		}
		self:_effect("ShadowClone", origin, origin + forward * 4, {
			UserId = player.UserId,
			Duration = CLONE_DURATION,
			Radius = action.Radius,
		})
	elseif actionId == "Dash" then
		self:_dash(character, root, forward, action.Range)
	elseif actionId == "Charge" then
		entry.ChargingUntil = now + Config.ChargeDuration
		self:_effect("Charge", origin, nil, { UserId = player.UserId, Duration = Config.ChargeDuration })
	end
	self._players:Push(player)
end

function CombatService:Step(_dt)
	if self._destroyed then
		return
	end
	local now = workspace:GetServerTimeNow()
	for player, attack in pairs(self._pending) do
		local character, _, root = characterParts(player)
		local entry = self._players:Get(player)
		if player.Parent ~= Players or character ~= attack.Character or not entry or not entry.Ready then
			self._pending[player] = nil
		elseif now >= attack.At then
			self._pending[player] = nil -- Remove before applying damage; each impact resolves once.
			self:_impact(player, attack, root)
		end
	end
	for player, clone in pairs(self._clones) do
		local character, _, root = characterParts(player)
		if player.Parent ~= Players or character ~= clone.Character or now >= clone.Expires then
			self._clones[player] = nil
		elseif now >= clone.NextPulse then
			clone.NextPulse = now + CLONE_INTERVAL
			local forward = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
			if forward.Magnitude < 0.01 then
				forward = Vector3.new(0, 0, -1)
			end
			local center = root.Position + forward.Unit * math.min(clone.Range, 5)
			self._enemies:DamageInRadius(player, center, clone.Radius, clone.Damage)
			self:_effect("Strike", center, nil, { Radius = clone.Radius, Duration = 0.2, Clone = true })
		end
	end
end

function CombatService:Destroy()
	self._destroyed = true
	table.clear(self._clones)
	table.clear(self._pending)
end

return CombatService
]====] },
{ Destination = "server", ClassName = "ModuleScript", Name = "EnemyService", Source = [====[
--!strict
-- NPC decisions, damage and rewards remain on the server. No client reports hits.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shinobi"):WaitForChild("Config"))

local EnemyService = {}
EnemyService.__index = EnemyService

local UP = Vector3.new(0, 1, 0)
local ZERO = Vector3.zero

local function finite(value)
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function finiteVector(value)
	return typeof(value) == "Vector3" and finite(value.X) and finite(value.Y) and finite(value.Z)
end

local function horizontal(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local function livingCharacter(player)
	if not player or player.Parent ~= Players then
		return nil, nil
	end
	local character = player.Character
	if not character then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil, nil
	end
	if not finiteVector(root.Position) then
		return nil, nil
	end
	return humanoid, root
end

local function part(model, name, size, offset, color, material)
	local object = Instance.new("Part")
	object.Name = name
	object.Size = size
	object.CFrame = CFrame.new(offset)
	object.Color = color
	object.Material = material or Enum.Material.SmoothPlastic
	object.Anchored = true
	object.Massless = true
	object.CanCollide = false
	object.CanTouch = false
	object.CanQuery = false
	object.CastShadow = true
	object.TopSurface = Enum.SurfaceType.Smooth
	object.BottomSurface = Enum.SurfaceType.Smooth
	object.Parent = model
	return object
end

local function joint(name, parent, child, pivot, scale)
	-- Neutral C0/C1 frames use the same axes as the rig, so procedural poses can
	-- rotate around the visible shoulders/hips without asset-specific corrections.
	local motor = Instance.new("Motor6D")
	motor.Name = name
	motor.Part0 = parent
	motor.Part1 = child
	local worldPivot = CFrame.new(pivot * scale)
	motor.C0 = parent.CFrame:ToObjectSpace(worldPivot)
	motor.C1 = child.CFrame:ToObjectSpace(worldPivot)
	motor.Parent = parent
	return motor
end

local function attach(parent, decoration)
	local weld = Instance.new("WeldConstraint")
	weld.Name = decoration.Name .. "Attachment"
	weld.Part0 = parent
	weld.Part1 = decoration
	weld.Parent = decoration
end

function EnemyService.new(spawns, onKill, effectRemote)
	local self = setmetatable({}, EnemyService)
	self.Folder = Instance.new("Folder")
	self.Folder.Name = "ShinobiEnemies"
	self.Folder.Parent = workspace
	self.Enemies = {}
	self.OnKill = onKill
	self.EffectRemote = effectRemote
	self.Destroyed = false
	for _, spawn in ipairs(spawns) do
		local settings = Config.Enemies[spawn.Kind]
		if settings and finiteVector(spawn.Position) then
			local enemy = {
				Kind = spawn.Kind,
				Settings = settings,
				Spawn = spawn.Position,
				Position = spawn.Position,
				Alive = false,
				RespawnAt = 0,
				LastAttack = -math.huge,
				Target = nil,
				PendingAttack = nil,
			}
			table.insert(self.Enemies, enemy)
			self:_spawn(enemy)
		end
	end
	return self
end

function EnemyService:_effect(payload)
	if not self.Destroyed and self.EffectRemote then
		self.EffectRemote:FireAllClients(payload)
	end
end

function EnemyService:_spawn(enemy)
	if self.Destroyed then
		return
	end
	if enemy.Model then
		enemy.Model:Destroy()
	end
	local boss = enemy.Kind == "Boss"
	local dummy = enemy.Kind == "Dummy"
	local scale = if boss then 1.35 else 1
	local model = Instance.new("Model")
	model.Name = if dummy then "Training Dummy" elseif boss then "Rogue Jonin" else "Rogue Shinobi"
	model:SetAttribute("EnemyKind", enemy.Kind)
	model:SetAttribute("ShinobiRigVersion", 2)
	local primary = part(model, "HumanoidRootPart", Vector3.new(2, 2, 1) * scale, ZERO, Color3.new())
	primary.Transparency = 1
	local cloth = if dummy then Color3.fromRGB(151, 105, 64)
		elseif boss then Color3.fromRGB(73, 36, 100) else Color3.fromRGB(40, 52, 66)
	local trim = if boss then Color3.fromRGB(255, 104, 72) else Color3.fromRGB(184, 57, 53)
	local torso = part(model, "Torso", Vector3.new(2, 2, 1) * scale, ZERO, cloth)
	local head = part(model, "Head", Vector3.new(1.45, 1.3, 1.2) * scale,
		Vector3.new(0, 1.65, 0) * scale, if dummy then cloth else Color3.fromRGB(214, 170, 139))
	local leftArm = part(model, "Left Arm", Vector3.new(0.7, 2, 0.8) * scale,
		Vector3.new(-1.4, 0, 0) * scale, cloth)
	local rightArm = part(model, "Right Arm", Vector3.new(0.7, 2, 0.8) * scale,
		Vector3.new(1.4, 0, 0) * scale, cloth)
	local leftLeg = part(model, "Left Leg", Vector3.new(0.85, 2, 0.85) * scale,
		Vector3.new(-0.55, -2, 0) * scale, cloth)
	local rightLeg = part(model, "Right Leg", Vector3.new(0.85, 2, 0.85) * scale,
		Vector3.new(0.55, -2, 0) * scale, cloth)
	joint("RootJoint", primary, torso, ZERO, scale)
	joint("Neck", torso, head, Vector3.new(0, 1, 0), scale)
	joint("Left Shoulder", torso, leftArm, Vector3.new(-1.1, 0.75, 0), scale)
	joint("Right Shoulder", torso, rightArm, Vector3.new(1.1, 0.75, 0), scale)
	joint("Left Hip", torso, leftLeg, Vector3.new(-0.55, -1, 0), scale)
	joint("Right Hip", torso, rightLeg, Vector3.new(0.55, -1, 0), scale)
	attach(head, part(model, "Headband", Vector3.new(1.5, 0.3, 0.1) * scale,
		Vector3.new(0, 1.95, -0.64) * scale, Color3.fromRGB(164, 182, 197), Enum.Material.Metal))
	attach(torso, part(model, "Sash", Vector3.new(2.05, 0.35, 1.05) * scale,
		Vector3.new(0, -0.65, 0) * scale, trim))
	if not dummy then
		attach(head, part(model, "Mask", Vector3.new(1.48, 0.5, 0.12) * scale,
			Vector3.new(0, 1.35, -0.65) * scale, cloth))
		for _, side in { -1, 1 } do
			attach(head, part(model, "Eye", Vector3.new(0.23, 0.11, 0.06) * scale,
				Vector3.new(side * 0.32, 1.72, -0.65) * scale, Color3.fromRGB(25, 28, 32)))
		end
	end
	if boss then
		attach(torso, part(model, "Crest", Vector3.new(2.3, 0.25, 1.1) * scale,
			Vector3.new(0, 1, 0) * scale, trim))
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.MaxHealth = enemy.Settings.Health
	humanoid.Health = enemy.Settings.Health
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.AutoRotate = false
	humanoid.WalkSpeed = 0
	humanoid.Parent = model
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HealthDisplay"
	billboard.Adornee = head
	billboard.Size = UDim2.fromOffset(if boss then 185 else 145, 44)
	billboard.StudsOffset = Vector3.new(0, 2.1, 0)
	billboard.MaxDistance = 100
	billboard.AlwaysOnTop = false
	billboard.Parent = head
	local label = Instance.new("TextLabel")
	label.Name = "Name"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 0.65)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 12
	label.TextColor3 = if boss then Color3.fromRGB(255, 175, 111) else Color3.fromRGB(245, 237, 219)
	label.TextStrokeTransparency = 0.5
	label.Text = model.Name
	label.Parent = billboard
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Position = UDim2.fromScale(0.08, 0.72)
	track.Size = UDim2.fromScale(0.84, 0.15)
	track.BackgroundColor3 = Color3.fromRGB(30, 33, 43)
	track.BorderSizePixel = 0
	track.Parent = billboard
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = if dummy then Color3.fromRGB(229, 192, 93) else Color3.fromRGB(230, 87, 80)
	fill.BorderSizePixel = 0
	fill.Parent = track
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = descendant == primary
		end
	end
	model.PrimaryPart = primary
	model.Parent = self.Folder
	model:PivotTo(CFrame.new(enemy.Spawn))
	enemy.Model = model
	enemy.Root = primary
	enemy.Humanoid = humanoid
	enemy.HealthFill = fill
	enemy.Position = enemy.Spawn
	enemy.Health = enemy.Settings.Health
	enemy.Alive = true
	enemy.Target = nil
	enemy.PendingAttack = nil
	enemy.LastAttack = workspace:GetServerTimeNow()
end

function EnemyService:_raycastParameters()
	local excluded = { self.Folder }
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(excluded, player.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excluded
	params.RespectCanCollide = true
	return params
end

function EnemyService:_lineClear(origin, destination)
	local direction = destination - origin
	if direction.Magnitude < 0.1 then
		return true
	end
	return workspace:Raycast(origin, direction, self:_raycastParameters()) == nil
end

function EnemyService:_damage(enemy, player, amount)
	if self.Destroyed or not enemy.Alive then
		return false
	end
	local humanoid = livingCharacter(player)
	if not humanoid then
		return false
	end
	enemy.Health = math.max(0, enemy.Health - amount)
	enemy.Humanoid.Health = enemy.Health
	enemy.HealthFill.Size = UDim2.fromScale(enemy.Health / enemy.Settings.Health, 1)
	if enemy.Health > 0 then
		self:_effect({ Kind = "CombatAnimation", Actor = enemy.Model, Action = "Hit",
			StartedAt = workspace:GetServerTimeNow(), Duration = 0.22,
			Position = enemy.Position, Boss = enemy.Kind == "Boss" })
	end
	self:_effect({ Kind = "Hit", Position = enemy.Position, Damage = amount })
	if enemy.Health <= 0 then
		-- Mark dead before issuing rewards: overlapping abilities cannot claim a kill twice.
		enemy.Alive = false
		enemy.Target = nil
		enemy.PendingAttack = nil
		enemy.RespawnAt = workspace:GetServerTimeNow() + enemy.Settings.RespawnTime
		self:_effect({ Kind = "Defeat", Position = enemy.Position })
		enemy.Model:Destroy()
		enemy.Model = nil
		if enemy.Kind ~= "Dummy" and self.OnKill then
			local success, failure = pcall(self.OnKill, player, enemy.Kind)
			if not success then
				warn("Shinobi enemy reward failed: ", failure)
			end
		end
	elseif enemy.Kind ~= "Dummy" then
		enemy.Target = player
	end
	return true
end

function EnemyService:DamageInRadius(player, position, radius, damage)
	if self.Destroyed or not finiteVector(position) or not finite(radius) or not finite(damage)
		or radius <= 0 or radius > 100 or damage <= 0 or damage > 100000 then
		return 0
	end
	local _, ownerRoot = livingCharacter(player)
	if not ownerRoot then
		return 0
	end
	local count = 0
	for _, enemy in ipairs(self.Enemies) do
		if enemy.Alive and (enemy.Position - position).Magnitude <= radius
			and self:_lineClear(ownerRoot.Position, enemy.Position)
			and self:_lineClear(position, enemy.Position) and self:_damage(enemy, player, damage) then
			count += 1
		end
	end
	return count
end

function EnemyService:DamageRay(player, origin, direction, range, radius, damage)
	if self.Destroyed or not finiteVector(origin) or not finiteVector(direction)
		or direction.Magnitude < 0.001 or not finite(range) or range <= 0 or range > 600
		or not finite(radius) or radius < 0 or radius > 30
		or not finite(damage) or damage <= 0 or damage > 100000 then
		return origin
	end
	local unit = direction.Unit
	local obstruction = workspace:Raycast(origin, unit * range, self:_raycastParameters())
	local distance = if obstruction then (obstruction.Position - origin).Magnitude else range
	local nearest = nil
	local nearestDistance = distance
	-- Hit the closest intersecting enemy, rather than piercing every enemy on the line.
	for _, enemy in ipairs(self.Enemies) do
		if enemy.Alive then
			local offset = enemy.Position - origin
			local along = offset:Dot(unit)
			if along >= 0 and along <= nearestDistance then
				local closest = origin + unit * along
				if (enemy.Position - closest).Magnitude <= radius + 1.5
					and self:_lineClear(origin, enemy.Position) then
					nearest = enemy
					nearestDistance = along
				end
			end
		end
	end
	if nearest then
		self:_damage(nearest, player, damage)
	end
	return origin + unit * nearestDistance
end

function EnemyService:_findTarget(enemy)
	local nearest, distance = nil, enemy.Settings.AggroRange
	local leash = math.max(38, enemy.Settings.AggroRange * 1.6)
	for _, player in ipairs(Players:GetPlayers()) do
		local _, root = livingCharacter(player)
		if root and (horizontal(root.Position - enemy.Spawn)).Magnitude <= leash then
			local currentDistance = (root.Position - enemy.Position).Magnitude
			if currentDistance < distance and self:_lineClear(enemy.Position, root.Position) then
				nearest = player
				distance = currentDistance
			end
		end
	end
	return nearest
end

function EnemyService:_move(enemy, destination, speed, dt)
	local difference = horizontal(destination - enemy.Position)
	if difference.Magnitude < 0.1 then
		return
	end
	local unit = difference.Unit
	local step = math.min(speed * dt, difference.Magnitude)
	local parameters = self:_raycastParameters()
	-- Stop before solid world geometry rather than walking through huts or arena walls.
	local blocked = workspace:Raycast(enemy.Position, unit * (step + 1.4), parameters)
	if blocked then
		local side = Vector3.new(-unit.Z, 0, unit.X)
		if not workspace:Raycast(enemy.Position, side * (step + 1.4), parameters) then
			unit = side
		else
			return
		end
	end
	enemy.Position += unit * step
	-- Only the anchored root moves. Motor6D assemblies follow it, leaving clients
	-- free to animate the limb joints without per-frame limb CFrame replication.
	enemy.Root.CFrame = CFrame.lookAt(enemy.Position, enemy.Position + unit, UP)
end

function EnemyService:_startAttack(enemy, now)
	local radius = enemy.Settings.AttackRange + (if enemy.Kind == "Boss" then 2 else 0.5)
	local duration = if enemy.Kind == "Boss" then 1.05 else 0.7
	enemy.LastAttack = now
	enemy.PendingAttack = { At = now + duration, Center = enemy.Position, Radius = radius }
	self:_effect({ Kind = "CombatAnimation", Actor = enemy.Model, Action = "EnemyWindup",
		StartedAt = now, Duration = duration, Position = enemy.Position, Boss = enemy.Kind == "Boss" })
	self:_effect({
		Kind = "EnemyWindup",
		Position = enemy.Position - Vector3.new(0, enemy.Spawn.Y - 0.15, 0),
		Radius = radius,
		Duration = duration,
		Boss = enemy.Kind == "Boss",
	})
end

function EnemyService:_resolveAttack(enemy)
	local attack = enemy.PendingAttack
	enemy.PendingAttack = nil
	if not attack then
		return
	end
	self:_effect({ Kind = "CombatAnimation", Actor = enemy.Model, Action = "EnemyAttack",
		StartedAt = workspace:GetServerTimeNow(), Duration = if enemy.Kind == "Boss" then 0.5 else 0.32,
		Position = enemy.Position, Boss = enemy.Kind == "Boss" })
	self:_effect({
		Kind = "EnemyAttack",
		Position = attack.Center - Vector3.new(0, enemy.Spawn.Y - 0.15, 0),
		Radius = attack.Radius,
		Boss = enemy.Kind == "Boss",
	})
	for _, player in ipairs(Players:GetPlayers()) do
		local humanoid, root = livingCharacter(player)
		if humanoid and root and horizontal(root.Position - attack.Center).Magnitude <= attack.Radius
			and math.abs(root.Position.Y - attack.Center.Y) < 7
			and self:_lineClear(attack.Center, root.Position) then
			local previousHealth = humanoid.Health
			humanoid:TakeDamage(enemy.Settings.Damage)
			if humanoid.Health > 0 and humanoid.Health < previousHealth then
				self:_effect({ Kind = "CombatAnimation", Actor = player.Character, Action = "Hit",
					StartedAt = workspace:GetServerTimeNow(), Duration = 0.22, Position = root.Position })
			end
		end
	end
end

function EnemyService:Step(dt)
	if self.Destroyed or not finite(dt) or dt <= 0 then
		return
	end
	dt = math.min(dt, 0.1)
	local now = workspace:GetServerTimeNow()
	for _, enemy in ipairs(self.Enemies) do
		if not enemy.Alive then
			if now >= enemy.RespawnAt then
				self:_spawn(enemy)
			end
		elseif enemy.Kind ~= "Dummy" then
			if enemy.PendingAttack then
				local _, targetRoot = livingCharacter(enemy.Target)
				local leash = math.max(38, enemy.Settings.AggroRange * 1.6)
				if not targetRoot or horizontal(targetRoot.Position - enemy.Spawn).Magnitude > leash then
					self:_effect({ Kind = "CombatAnimation", Actor = enemy.Model, Action = "Cancel",
						StartedAt = now, Duration = 0, Position = enemy.Position })
					enemy.PendingAttack = nil
					enemy.Target = nil
				elseif now >= enemy.PendingAttack.At then
					self:_resolveAttack(enemy)
				end
			else
				local leash = math.max(38, enemy.Settings.AggroRange * 1.6)
				local _, root = nil, nil
				if enemy.Target then
					_, root = livingCharacter(enemy.Target)
				end
				if not root or (horizontal(root.Position - enemy.Spawn)).Magnitude > leash
					or horizontal(enemy.Position - enemy.Spawn).Magnitude > leash then
					enemy.Target = self:_findTarget(enemy)
					if enemy.Target then
						_, root = livingCharacter(enemy.Target)
					else
						root = nil
					end
				end
				if root then
					local distance = horizontal(root.Position - enemy.Position).Magnitude
					if distance > enemy.Settings.AttackRange then
						self:_move(enemy, root.Position, enemy.Settings.Speed, dt)
					elseif now - enemy.LastAttack >= enemy.Settings.AttackCooldown
						and self:_lineClear(enemy.Position, root.Position) then
						self:_startAttack(enemy, now)
					end
				else
					self:_move(enemy, enemy.Spawn, enemy.Settings.Speed, dt)
					if (enemy.Position - enemy.Spawn).Magnitude < 1 then
						enemy.Health = enemy.Settings.Health
						enemy.Humanoid.Health = enemy.Health
						enemy.HealthFill.Size = UDim2.fromScale(1, 1)
					end
				end
			end
		end
	end
end

function EnemyService:Destroy()
	self.Destroyed = true
	self.Folder:Destroy()
	table.clear(self.Enemies)
end

return EnemyService
]====] },
{ Destination = "server", ClassName = "Script", Name = "Main", Source = [====[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shinobi")
local Config = require(Shared.Config)
local Rules = require(Shared.Rules)

local remotesFolder = Instance.new("Folder")
remotesFolder.Name = "Remotes"
remotesFolder.Parent = Shared
local remotes = {}
for _, name in { "Action", "State", "Effect", "RequestState" } do
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotesFolder
	remotes[name] = remote
end

local world = require(script.Parent.World).Build()
local players = require(script.Parent.PlayerService).new(remotes.State)
local enemies = require(script.Parent.EnemyService).new(world.EnemySpawns, function(player, kind)
	players:AwardKill(player, kind)
end, remotes.Effect)
local combat = require(script.Parent.CombatService).new(enemies, players, remotes)

local function configureCharacter(player, character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or player.Character ~= character then return end
	humanoid.MaxHealth = Config.MaxHealth
	humanoid.Health = Config.MaxHealth
	humanoid.WalkSpeed = Config.WalkSpeed
	local entry = players:Get(player)
	if entry then
		entry.Chakra = Config.MaxChakra
		entry.ChargingUntil = nil
		entry.LastStrikeAt = nil
		entry.StrikeCombo = nil
	end
end

local function addPlayer(player)
	player.CharacterAdded:Connect(function(character) configureCharacter(player, character) end)
	if player.Character then task.spawn(configureCharacter, player, player.Character) end
	players:Add(player)
end
Players.PlayerAdded:Connect(addPlayer)
for _, player in Players:GetPlayers() do task.spawn(addPlayer, player) end

local requestTimes = {}
local actionTimes = {}
remotes.RequestState.OnServerEvent:Connect(function(player)
	local now = os.clock()
	if now - (requestTimes[player] or -math.huge) < 1 then return end
	requestTimes[player] = now
	players:Push(player)
end)

remotes.Action.OnServerEvent:Connect(function(player, actionId, aimPosition)
	-- Bound packet work even when rejected actions do not consume a cooldown.
	local now = os.clock()
	if now - (actionTimes[player] or -math.huge) < 0.08 then return end
	actionTimes[player] = now
	if type(actionId) ~= "string" or not Config.Actions[actionId] or typeof(aimPosition) ~= "Vector3" then return end
	if not Rules.finite(aimPosition.X) or not Rules.finite(aimPosition.Y) or not Rules.finite(aimPosition.Z)
		or aimPosition.Magnitude > 100000 then return end
	combat:HandleAction(player, actionId, aimPosition)
end)

world.MissionPrompt.Triggered:Connect(function(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local part = world.MissionPrompt.Parent
	if not root or not humanoid or humanoid.Health <= 0 or not part:IsA("BasePart") then return end
	-- Prompt events can be forged; proximity is checked again on the server.
	if (root.Position - part.Position).Magnitude > world.MissionPrompt.MaxActivationDistance + 3 then return end
	players:Mission(player)
end)

Players.PlayerRemoving:Connect(function(player)
	requestTimes[player] = nil
	actionTimes[player] = nil
	players:Remove(player)
end)

RunService.Heartbeat:Connect(function(dt)
	local step = math.min(dt, 0.15)
	players:Step(step)
	combat:Step(step)
	enemies:Step(step)
end)

game:BindToClose(function()
	combat:Destroy()
	enemies:Destroy()
	players:Close()
end)

print("[Shinobi] Ember Legacy server ready. Village, combat, missions and progression initialized.")
]====] },
{ Destination = "server", ClassName = "ModuleScript", Name = "PlayerService", Source = [====[
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shinobi")
local Config = require(Shared.Config)
local Rules = require(Shared.Rules)

local PlayerService = {}
PlayerService.__index = PlayerService
local LEASE_SECONDS = 180

function PlayerService.new(stateRemote)
	local self = setmetatable({}, PlayerService)
	self.entries = {}
	self.stateRemote = stateRemote
	self.store = nil
	if not RunService:IsStudio() then
		local success, store = pcall(function()
			return DataStoreService:GetDataStore("ShinobiEmberLegacy_v1")
		end)
		if success then self.store = store end
	end
	self.sessionId = game.JobId .. ":" .. HttpService:GenerateGUID(false)
	self.pushElapsed = 0
	self.saveElapsed = 0
	return self
end

function PlayerService:Get(player)
	return self.entries[player]
end

function PlayerService:Push(player, message)
	local entry = self.entries[player]
	if not entry or not entry.Ready or player.Parent ~= Players then return end
	local data = entry.Data
	self.stateRemote:FireClient(player, {
		Level = data.Level, XP = data.XP, XPRequired = Rules.xpRequired(data.Level),
		Coins = data.Coins, Rank = Rules.rank(data.Level), Chakra = entry.Chakra,
		MaxChakra = Config.MaxChakra, MissionActive = data.MissionActive,
		MissionKills = data.MissionKills, MissionGoal = Config.Mission.Goal,
		MissionReady = data.MissionActive and data.MissionKills >= Config.Mission.Goal,
		SessionOnly = entry.SessionOnly, Message = message,
		ServerTime = workspace:GetServerTimeNow(), Cooldowns = table.clone(entry.Cooldowns),
	})
end

function PlayerService:Add(player)
	if self.entries[player] then return end
	local entry = {
		Data = Rules.newProfile(), Chakra = Config.MaxChakra, Cooldowns = {},
		LastActionAt = -math.huge, Ready = false, Saving = false,
		SessionOnly = self.store == nil, LastMissionAt = -math.huge,
	}
	self.entries[player] = entry
	if not entry.SessionOnly then
		local success, result = pcall(function()
			return self.store:UpdateAsync("Player_" .. player.UserId, function(old)
				local now = os.time()
				if type(old) == "table" and type(old.Session) == "table"
					and type(old.Session.ExpiresAt) == "number" and old.Session.ExpiresAt > now
					and old.Session.Id ~= self.sessionId then
					return nil -- Another server still owns this profile; never overwrite it.
				end
				return { Version = 1, Data = Rules.sanitizeProfile(type(old) == "table" and old.Data or nil),
					Session = { Id = self.sessionId, ExpiresAt = now + LEASE_SECONDS } }
			end)
		end)
		if success and result then
			entry.Data = Rules.sanitizeProfile(result.Data)
		else
			entry.SessionOnly = true
			warn("[Shinobi] Persistence unavailable for user " .. player.UserId .. "; using a temporary session without overwriting saved progress.")
		end
	end
	entry.Ready = true
	if self.entries[player] ~= entry or player.Parent ~= Players then
		-- A player can leave while UpdateAsync is yielding. Release any acquired lease.
		if not entry.SessionOnly then self:SaveEntry(player.UserId, entry, true) end
		return
	end
	local board = Instance.new("Folder")
	board.Name = "leaderstats"
	board.Parent = player
	for _, name in { "Level", "Ryo" } do
		local stat = Instance.new("IntValue")
		stat.Name = name
		stat.Parent = board
	end
	self:UpdateLeaderboard(player)
	self:Push(player, if entry.SessionOnly then "Training session: progress is temporary. Talk to Sensei to begin." else "Welcome, shinobi. Talk to Sensei to begin your first mission.")
end

function PlayerService:UpdateLeaderboard(player)
	local entry = self.entries[player]
	local board = player:FindFirstChild("leaderstats")
	if entry and board then
		board.Level.Value = entry.Data.Level
		board.Ryo.Value = entry.Data.Coins
	end
end

function PlayerService:AwardKill(player, kind)
	local entry = self.entries[player]
	if not entry or not entry.Ready then return end
	local level = entry.Data.Level
	if not Rules.awardKill(entry.Data, kind) then return end
	self:UpdateLeaderboard(player)
	local enemy = Config.Enemies[kind]
	local message = "+" .. enemy.XP .. " XP · +" .. enemy.Coins .. " Ryo"
	if entry.Data.Level > level then
		entry.Chakra = Config.MaxChakra
		message = "Level " .. entry.Data.Level .. "! " .. message
	elseif entry.Data.MissionActive and entry.Data.MissionKills >= Config.Mission.Goal then
		message ..= " · Mission ready! Return to Sensei."
	end
	self:Push(player, message)
end

function PlayerService:Mission(player)
	local entry = self.entries[player]
	if not entry or not entry.Ready then return end
	local now = workspace:GetServerTimeNow()
	if now - entry.LastMissionAt < 1 then return end
	entry.LastMissionAt = now
	local message = Rules.interactMission(entry.Data)
	self:UpdateLeaderboard(player)
	self:Push(player, message)
end

function PlayerService:SaveEntry(userId, entry, release)
	if entry.SessionOnly or not entry.Ready then return true end
	local deadline = os.clock() + 10
	while entry.Saving and os.clock() < deadline do task.wait(0.1) end
	if entry.Saving then return false end
	entry.Saving = true
	local snapshot = Rules.sanitizeProfile(entry.Data)
	local success, result = pcall(function()
		return self.store:UpdateAsync("Player_" .. userId, function(old)
			if type(old) ~= "table" or type(old.Session) ~= "table" or old.Session.Id ~= self.sessionId then return nil end
			return { Version = 1, Data = snapshot,
				Session = if release then nil else { Id = self.sessionId, ExpiresAt = os.time() + LEASE_SECONDS } }
		end)
	end)
	entry.Saving = false
	if success and not result then entry.SessionOnly = true end
	if not success then warn("[Shinobi] Save failed for user " .. userId .. "; will retry at next autosave.") end
	return success and result ~= nil
end

function PlayerService:Remove(player)
	local entry = self.entries[player]
	if not entry then return end
	self.entries[player] = nil
	self:SaveEntry(player.UserId, entry, true)
end

function PlayerService:Step(dt)
	self.pushElapsed += dt
	self.saveElapsed += dt
	local push = self.pushElapsed >= 0.25
	if push then self.pushElapsed = 0 end
	local save = self.saveElapsed >= 60
	if save then self.saveElapsed = 0 end
	local now = workspace:GetServerTimeNow()
	for player, entry in self.entries do
		if entry.Ready then
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
			local charging = entry.ChargingUntil and entry.ChargingUntil > now
			if charging and (not humanoid or humanoid.Health <= 0 or humanoid.MoveDirection.Magnitude > 0.1
				or not root or root.AssemblyLinearVelocity.Magnitude > 4) then
				entry.ChargingUntil = nil
				charging = false
			end
			if humanoid and humanoid.Health > 0 then
				entry.Chakra = math.min(Config.MaxChakra, entry.Chakra + dt * (if charging then Config.ChargeRegen else Config.ChakraRegen))
			end
			if push then self:Push(player) end
			if save and not entry.SessionOnly then task.spawn(function() self:SaveEntry(player.UserId, entry, false) end) end
		end
	end
end

function PlayerService:Close()
	local pending = 0
	for player, entry in self.entries do
		pending += 1
		task.spawn(function()
			self:SaveEntry(player.UserId, entry, true)
			pending -= 1
		end)
	end
	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do task.wait(0.1) end
end

return PlayerService
]====] },
{ Destination = "server", ClassName = "ModuleScript", Name = "World", Source = [====[
-- Original geometry only: the world does not require marketplace assets.
local Lighting = game:GetService("Lighting")

local World = {}

local COLORS = {
	Grass = Color3.fromRGB(79, 115, 72),
	Stone = Color3.fromRGB(113, 120, 115),
	Path = Color3.fromRGB(194, 171, 130),
	Wood = Color3.fromRGB(91, 58, 42),
	DarkWood = Color3.fromRGB(55, 39, 35),
	Plaster = Color3.fromRGB(229, 207, 163),
	Roof = Color3.fromRGB(133, 51, 39),
	Gold = Color3.fromRGB(255, 190, 88),
	Leaf = Color3.fromRGB(56, 102, 65),
}

function World.Build()
	local oldWorld = workspace:FindFirstChild("ShinobiWorld")
	if oldWorld then
		assert(oldWorld:GetAttribute("ShinobiGenerated") == true,
			"A custom ShinobiWorld folder already exists. Rename it or run the updated installer to migrate the old game safely.")
		oldWorld:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "ShinobiWorld"
	root:SetAttribute("ShinobiGenerated", true)
	root:SetAttribute("ShinobiVersion", 2)
	root.Parent = workspace

	local function part(name, size, position, color, material, parent, className)
		local object = Instance.new(className or "Part")
		object.Name = name
		object.Size = size
		object.Position = position
		object.Anchored = true
		object.Color = color or COLORS.Stone
		object.Material = material or Enum.Material.SmoothPlastic
		object.TopSurface = Enum.SurfaceType.Smooth
		object.BottomSurface = Enum.SurfaceType.Smooth
		object.Parent = parent or root
		return object
	end

	local function signText(target, text, color)
		local surface = Instance.new("SurfaceGui")
		surface.Name = "PaintedSign"
		surface.Face = Enum.NormalId.Back
		surface.CanvasSize = Vector2.new(500, 180)
		surface.LightInfluence = 0.2
		surface.Parent = target
		local textLabel = Instance.new("TextLabel")
		textLabel.Size = UDim2.fromScale(0.92, 0.82)
		textLabel.Position = UDim2.fromScale(0.04, 0.09)
		textLabel.BackgroundTransparency = 1
		textLabel.Font = Enum.Font.GothamBold
		textLabel.Text = text
		textLabel.TextColor3 = color or COLORS.Gold
		textLabel.TextScaled = true
		textLabel.TextWrapped = true
		textLabel.Parent = surface
	end

	local function model(name)
		local object = Instance.new("Model")
		object.Name = name
		object.Parent = root
		return object
	end

	local function label(target, text, width, height, color)
		local board = Instance.new("BillboardGui")
		board.Name = "WorldLabel"
		board.Size = UDim2.fromOffset(width or 250, height or 60)
		board.StudsOffset = Vector3.new(0, target.Size.Y / 2 + 3, 0)
		board.MaxDistance = 95
		board.AlwaysOnTop = false
		board.Parent = target
		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Size = UDim2.fromScale(1, 1)
		title.Font = Enum.Font.GothamBold
		title.Text = text
		title.TextSize = 19
		title.TextColor3 = color or COLORS.Gold
		title.TextStrokeColor3 = Color3.fromRGB(30, 26, 24)
		title.TextStrokeTransparency = 0.15
		title.TextWrapped = true
		title.Parent = board
	end

	local function tree(x, z, scale, autumn)
		scale = scale or 1
		local group = model("Cedar")
		part("Trunk", Vector3.new(2.5, 12, 2.5) * scale,
			Vector3.new(x, 6 * scale, z), COLORS.Wood, Enum.Material.Wood, group)
		for tier = 1, 3 do
			local width = (15 - tier * 2.5) * scale
			local crown = part("Crown", Vector3.new(width, 8 * scale, width),
				Vector3.new(x, (9 + tier * 3) * scale, z),
				autumn and Color3.fromRGB(175 + tier * 15, 95 + tier * 8, 50) or COLORS.Leaf,
				Enum.Material.Grass, group)
			crown.Shape = Enum.PartType.Ball
			crown.CanCollide = false
		end
	end

	local function lantern(position, parent)
		part("LanternPost", Vector3.new(0.7, 7, 0.7), position + Vector3.new(0, 3.5, 0), COLORS.DarkWood, Enum.Material.Wood, parent)
		local glow = part("PaperLantern", Vector3.new(2.3, 2.8, 2.3), position + Vector3.new(0, 7.2, 0), COLORS.Gold, Enum.Material.Neon, parent)
		glow.CanCollide = false
		part("LanternCap", Vector3.new(2.8, 0.5, 2.8), position + Vector3.new(0, 8.8, 0), COLORS.DarkWood, Enum.Material.Wood, parent)
		local light = Instance.new("PointLight")
		light.Color = COLORS.Gold
		light.Brightness = 0.7
		light.Range = 15
		light.Shadows = false
		light.Parent = glow
	end

	local function roof(group, x, z, width, depth, y, color)
		-- Two overlapping sloped courses give the roof a clear tiled silhouette.
		for tier = 0, 1 do
			local span = depth + 6 - tier * 3
			for _, side in ipairs({ -1, 1 }) do
				local slope = part("SlopedTileRoof", Vector3.new(width + 7 - tier * 2, 1.1, span * 0.56),
					Vector3.new(x, y + tier * 2 + 1.3, z + side * span * 0.23), color or COLORS.Roof, Enum.Material.Slate, group)
				slope.CFrame *= CFrame.Angles(side * math.rad(18), 0, 0)
				part("EaveFascia", Vector3.new(width + 8 - tier * 2, 0.65, 0.75),
					Vector3.new(x, y + tier * 2 - 0.1, z + side * span * 0.5), COLORS.DarkWood, Enum.Material.Wood, group)
			end
		end
		part("RoofRidge", Vector3.new(width + 5, 0.8, 1.2), Vector3.new(x, y + 4.5, z), COLORS.Gold, Enum.Material.Wood, group)
		for _, side in ipairs({ -1, 1 }) do
			local finial = part("RaisedRoofTip", Vector3.new(5, 0.7, 1.2), Vector3.new(x + side * (width / 2 + 3), y + 5.1, z), COLORS.DarkWood, Enum.Material.Wood, group)
			finial.CFrame *= CFrame.Angles(0, 0, side * math.rad(20))
		end
	end

	local function house(x, z, width, depth, title)
		local group = model(title)
		part("Foundation", Vector3.new(width + 3, 1, depth + 3), Vector3.new(x, 0.5, z), COLORS.Stone, Enum.Material.Cobblestone, group)
		part("InteriorFloor", Vector3.new(width, 0.25, depth), Vector3.new(x, 1.1, z), Color3.fromRGB(166, 128, 85), Enum.Material.WoodPlanks, group)
		part("BackWall", Vector3.new(width, 12, 0.8), Vector3.new(x, 7, z - depth / 2), COLORS.Plaster, Enum.Material.Plaster, group)
		part("DoorLintel", Vector3.new(6, 4, 0.8), Vector3.new(x, 11, z + depth / 2), COLORS.Plaster, Enum.Material.Plaster, group)
		for _, side in ipairs({-1, 1}) do
			part("SideWall", Vector3.new(0.8, 12, depth), Vector3.new(x + side * width / 2, 7, z), COLORS.Plaster, Enum.Material.Plaster, group)
			part("FrontWall", Vector3.new((width - 6) / 2, 12, 0.8), Vector3.new(x + side * (width + 6) / 4, 7, z + depth / 2), COLORS.Plaster, Enum.Material.Plaster, group)
			for _, front in ipairs({ -1, 1 }) do
				part("TimberCorner", Vector3.new(1, 13, 1), Vector3.new(x + side * (width / 2 - 0.2), 7.5, z + front * depth / 2), COLORS.Wood, Enum.Material.Wood, group)
			end
			local windowX = x + side * (width / 3)
			local window = part("PaperWindow", Vector3.new(4.5, 4.2, 0.15), Vector3.new(windowX, 7.4, z + depth / 2 + 0.45), Color3.fromRGB(239, 202, 127), Enum.Material.Neon, group)
			window.CanCollide = false
			part("WindowMullion", Vector3.new(0.22, 4.5, 0.25), Vector3.new(windowX, 7.4, z + depth / 2 + 0.55), COLORS.DarkWood, Enum.Material.Wood, group)
			part("WindowMullion", Vector3.new(4.8, 0.22, 0.25), Vector3.new(windowX, 7.4, z + depth / 2 + 0.55), COLORS.DarkWood, Enum.Material.Wood, group)
			part("DoorPost", Vector3.new(0.6, 8, 1), Vector3.new(x + side * 3.3, 5, z + depth / 2), COLORS.DarkWood, Enum.Material.Wood, group)
			local banner = part("VillageBanner", Vector3.new(1.8, 5, 0.15), Vector3.new(x + side * (width / 2 - 2), 9.5, z + depth / 2 + 0.65), Color3.fromRGB(43, 87, 90), Enum.Material.Fabric, group)
			banner.CanCollide = false
		end
		part("UpperBeam", Vector3.new(width + 1, 0.8, depth + 1), Vector3.new(x, 13.1, z), COLORS.Wood, Enum.Material.Wood, group)
		part("EntryStep", Vector3.new(7, 0.5, 3), Vector3.new(x, 0.25, z + depth / 2 + 2), COLORS.Stone, Enum.Material.Cobblestone, group)
		local sign = part("ShopSign", Vector3.new(12, 2.6, 0.7), Vector3.new(x, 11.5, z + depth / 2 + 1), COLORS.DarkWood, Enum.Material.Wood, group)
		signText(sign, string.upper(title))
		roof(group, x, z, width, depth, 13.5)
		return group
	end

	local function gate(z, text)
		local group = model(text)
		for _, x in ipairs({-10, 10}) do
			part("GateFoot", Vector3.new(4, 2, 4), Vector3.new(x, 1, z), COLORS.Stone, Enum.Material.Slate, group)
			part("GatePillar", Vector3.new(2.6, 15, 2.6), Vector3.new(x, 8.5, z), COLORS.Roof, Enum.Material.Wood, group)
		end
		part("Lintel", Vector3.new(27, 2.2, 3.5), Vector3.new(0, 16.5, z), COLORS.DarkWood, Enum.Material.Wood, group)
		local sign = part("VillageSign", Vector3.new(9, 4.5, 0.8), Vector3.new(0, 13.8, z + 1.7), COLORS.DarkWood, Enum.Material.Wood, group)
		label(sign, text, 230, 40)
	end

	Lighting.ClockTime = 16.8
	Lighting.Brightness = 2.3
	Lighting.Ambient = Color3.fromRGB(103, 111, 119)
	Lighting.OutdoorAmbient = Color3.fromRGB(141, 146, 134)
	Lighting.EnvironmentDiffuseScale = 0.7
	Lighting.EnvironmentSpecularScale = 0.35
	for _, effectName in ipairs({"ShinobiAtmosphere", "ShinobiBloom", "ShinobiColor"}) do
		local existing = Lighting:FindFirstChild(effectName)
		if existing then existing:Destroy() end
	end
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "ShinobiAtmosphere"
	atmosphere.Density = 0.24
	atmosphere.Offset = 0.15
	atmosphere.Color = Color3.fromRGB(226, 211, 184)
	atmosphere.Decay = Color3.fromRGB(138, 157, 173)
	atmosphere.Glare = 0.12
	atmosphere.Haze = 1.2
	atmosphere.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "ShinobiBloom"
	bloom.Intensity = 0.2
	bloom.Size = 16
	bloom.Threshold = 1.1
	bloom.Parent = Lighting
	local grading = Instance.new("ColorCorrectionEffect")
	grading.Name = "ShinobiColor"
	grading.Saturation = 0.06
	grading.Contrast = 0.08
	grading.TintColor = Color3.fromRGB(255, 244, 225)
	grading.Parent = Lighting

	part("ValleyFloor", Vector3.new(240, 8, 390), Vector3.new(0, -4, -130), COLORS.Grass, Enum.Material.Grass)
	part("VillagePlaza", Vector3.new(116, 0.15, 78), Vector3.new(0, 0.075, -3), COLORS.Path, Enum.Material.Ground)
	part("MainTrail", Vector3.new(15, 0.15, 300), Vector3.new(0, 0.09, -122), COLORS.Path, Enum.Material.Ground)
	part("VillageCrossStreet", Vector3.new(104, 0.12, 8), Vector3.new(0, 0.18, -2), COLORS.Stone, Enum.Material.Cobblestone)
	for z = -36, 24, 6 do
		for _, x in ipairs({ -4, 4 }) do
			part("StreetPaving", Vector3.new(7.6, 0.16, 5.7), Vector3.new(x, 0.19, z),
				if z % 12 == 0 then Color3.fromRGB(167, 156, 133) else Color3.fromRGB(181, 168, 142), Enum.Material.Cobblestone)
		end
	end
	part("TrainingCourtyard", Vector3.new(75, 0.2, 39), Vector3.new(0, 0.1, -67), Color3.fromRGB(179, 160, 123), Enum.Material.Sand)
	part("CampClearing", Vector3.new(92, 0.17, 73), Vector3.new(0, 0.1, -164), Color3.fromRGB(126, 115, 86), Enum.Material.Ground)

	local ramen = house(-34, 15, 25, 20, "Ember Ramen")
	house(34, 15, 25, 20, "Ninja Academy")
	house(-35, -20, 27, 21, "Village Archives")
	house(35, -20, 27, 21, "Mission Headquarters")
	-- A usable restaurant interior and front terrace give the village a social center.
	part("RamenCounter", Vector3.new(18, 3, 3), Vector3.new(-34, 2.6, 11), COLORS.DarkWood, Enum.Material.WoodPlanks, ramen)
	part("CounterTop", Vector3.new(18.7, 0.35, 3.5), Vector3.new(-34, 4.3, 11), COLORS.Wood, Enum.Material.Wood, ramen)
	for _, x in ipairs({ -40, -34, -28 }) do
		part("CounterStool", Vector3.new(2.5, 2, 2.5), Vector3.new(x, 2.1, 15), COLORS.Roof, Enum.Material.Wood, ramen)
		local bowl = part("RamenBowl", Vector3.new(1.8, 0.6, 1.8), Vector3.new(x, 4.75, 11), COLORS.Plaster, Enum.Material.SmoothPlastic, ramen)
		bowl.Shape = Enum.PartType.Ball
		local noodles = part("Noodles", Vector3.new(1.3, 0.18, 1.3), Vector3.new(x, 5.02, 11), Color3.fromRGB(230, 193, 102), Enum.Material.SmoothPlastic, ramen)
		noodles.Shape = Enum.PartType.Ball
		for _, dx in ipairs({ -0.14, 0.14 }) do
			local chopstick = part("Chopstick", Vector3.new(0.07, 0.07, 2.2), Vector3.new(x + dx, 5.15, 11), COLORS.DarkWood, Enum.Material.Wood, ramen)
			chopstick.CanCollide = false
		end
	end
	for _, x in ipairs({ -43, -25 }) do
		part("TerraceTable", Vector3.new(5, 0.6, 3), Vector3.new(x, 3, 33), COLORS.Wood, Enum.Material.Wood, ramen)
		part("TablePedestal", Vector3.new(1.4, 3, 1.4), Vector3.new(x, 1.5, 33), COLORS.DarkWood, Enum.Material.Wood, ramen)
		for _, side in ipairs({ -1, 1 }) do
			part("TerraceBench", Vector3.new(5, 1.7, 1.2), Vector3.new(x, 0.85, 33 + side * 3), COLORS.Wood, Enum.Material.WoodPlanks, ramen)
		end
	end

	for _, side in ipairs({ -1, 1 }) do
		local x = side * 49
		local stall = model(if side < 0 then "ProduceMarket" else "EquipmentMarket")
		for _, dx in ipairs({ -5, 5 }) do
			part("MarketPost", Vector3.new(0.55, 8.5, 0.55), Vector3.new(x + dx, 4.25, -2), COLORS.DarkWood, Enum.Material.Wood, stall)
		end
		part("MarketCounter", Vector3.new(10.5, 3, 3.5), Vector3.new(x, 1.5, -1), COLORS.Wood, Enum.Material.WoodPlanks, stall)
		for stripe = -2, 2 do
			local cloth = part("StripedAwning", Vector3.new(2.2, 0.3, 7.3), Vector3.new(x + stripe * 2.2, 8, -2),
				if stripe % 2 == 0 then COLORS.Plaster else Color3.fromRGB(43, 87, 90), Enum.Material.Fabric, stall)
			cloth.CFrame *= CFrame.Angles(math.rad(-9), 0, 0)
		end
		local board = part("MarketSign", Vector3.new(7, 1.6, 0.3), Vector3.new(x, 6.4, 1.7), COLORS.DarkWood, Enum.Material.Wood, stall)
		signText(board, if side < 0 then "FRESH HARVEST" else "SHINOBI SUPPLIES")
		for index = -1, 1 do
			local goods = part("MarketGoods", Vector3.new(1.8, 1.2, 1.8), Vector3.new(x + index * 2.4, 3.6, -1),
				if side < 0 then Color3.fromRGB(194, 83 + index * 20, 49) else Color3.fromRGB(195, 185, 146), Enum.Material.SmoothPlastic, stall)
			goods.Shape = if side < 0 then Enum.PartType.Ball else Enum.PartType.Cylinder
		end
	end

	local monument = model("EmberMemorial")
	for tier = 1, 3 do
		local base = part("MemorialPlinth", Vector3.new(1, 17 - tier * 3, 17 - tier * 3), Vector3.new(0, tier * 0.5, 37), COLORS.Stone, Enum.Material.Slate, monument)
		base.Shape = Enum.PartType.Cylinder
		base.CFrame *= CFrame.Angles(0, 0, math.pi / 2)
	end
	part("MemorialPillar", Vector3.new(3.5, 9, 3.5), Vector3.new(0, 6, 37), COLORS.DarkWood, Enum.Material.Wood, monument)
	local ember = part("EmberCrystal", Vector3.new(3.5, 5, 3.5), Vector3.new(0, 12, 37), Color3.fromRGB(255, 155, 76), Enum.Material.Neon, monument)
	ember.CFrame *= CFrame.Angles(0, math.rad(45), math.rad(30))
	ember.CanCollide = false
	local memorialBoard = part("MemorialPlaque", Vector3.new(8, 2, 0.4), Vector3.new(0, 5, 39), COLORS.DarkWood, Enum.Material.Wood, monument)
	signText(memorialBoard, "THE WILL OF EMBER")
	for _, x in ipairs({ -12, 12 }) do
		part("BannerPole", Vector3.new(0.6, 17, 0.6), Vector3.new(x, 8.5, 38), COLORS.DarkWood, Enum.Material.Wood, monument)
		local banner = part("MemorialBanner", Vector3.new(4, 8, 0.15), Vector3.new(x + (if x < 0 then 2 else -2), 12, 38), COLORS.Roof, Enum.Material.Fabric, monument)
		banner.CanCollide = false
		signText(banner, "EMBER\n忍", COLORS.Plaster)
	end

	local function blossom(x, z, scale)
		local group = model("BlossomGarden")
		part("TreePlanter", Vector3.new(7 * scale, 0.7, 7 * scale), Vector3.new(x, 0.35, z), COLORS.Stone, Enum.Material.Cobblestone, group)
		part("BlossomTrunk", Vector3.new(1.8, 11, 1.8) * scale, Vector3.new(x, 5.8 * scale, z), COLORS.DarkWood, Enum.Material.Wood, group)
		for index = 0, 4 do
			local angle = index * math.pi * 2 / 5
			local crown = part("BlossomCanopy", Vector3.new(8, 6.5, 8) * scale,
				Vector3.new(x + math.cos(angle) * 3.2 * scale, (11 + index % 2) * scale, z + math.sin(angle) * 3.2 * scale),
				if index % 2 == 0 then Color3.fromRGB(238, 166, 180) else Color3.fromRGB(218, 125, 154), Enum.Material.Grass, group)
			crown.Shape = Enum.PartType.Ball
			crown.CanCollide = false
		end
	end
	blossom(-15, 28, 0.8)
	blossom(16, 29, 0.9)
	blossom(-16, -25, 0.7)
	blossom(16, -25, 0.7)
	for _, x in ipairs({-58, 58}) do
		part("VillageWall", Vector3.new(2, 9, 80), Vector3.new(x, 4.5, -4), COLORS.Plaster, Enum.Material.Plaster)
		part("WallCap", Vector3.new(3.2, 1, 81), Vector3.new(x, 9.3, -4), COLORS.Roof, Enum.Material.Slate)
	end
	for _, x in ipairs({-35, 35}) do
		part("FrontWall", Vector3.new(45, 9, 2), Vector3.new(x, 4.5, -44), COLORS.Plaster, Enum.Material.Plaster)
		part("WallCap", Vector3.new(46, 1, 3), Vector3.new(x, 9.3, -44), COLORS.Roof, Enum.Material.Slate)
	end
	gate(-44, "EMBER VILLAGE")

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "VillageSpawn"
	spawn.Size = Vector3.new(9, 0.5, 9)
	spawn.Position = Vector3.new(0, 0.4, 16)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 3
	spawn.Color = Color3.fromRGB(86, 133, 127)
	spawn.Material = Enum.Material.Slate
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.BottomSurface = Enum.SurfaceType.Smooth
	spawn.Parent = root
	label(spawn, "SHINOBI\nEMBER LEGACY", 310, 65, Color3.fromRGB(255, 223, 162))

	local npc = model("MissionMaster")
	local npcBase = Vector3.new(12, 0, 2)
	part("Legs", Vector3.new(2.5, 2.5, 1.4), npcBase + Vector3.new(0, 1.25, 0), COLORS.DarkWood, Enum.Material.SmoothPlastic, npc)
	local torso = part("Torso", Vector3.new(3, 3, 1.7), npcBase + Vector3.new(0, 4, 0), Color3.fromRGB(63, 98, 73), Enum.Material.Fabric, npc)
	part("Head", Vector3.new(2, 2, 2), npcBase + Vector3.new(0, 6.5, 0), Color3.fromRGB(219, 177, 137), Enum.Material.SmoothPlastic, npc)
	part("Headband", Vector3.new(2.1, 0.5, 2.1), npcBase + Vector3.new(0, 7, 0), Color3.fromRGB(68, 78, 91), Enum.Material.Metal, npc)
	label(torso, "MISSION MASTER\nAccept or claim your mission", 290, 60)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "MissionPrompt"
	prompt.ActionText = "Accept / Claim Mission"
	prompt.ObjectText = "Mission Master"
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.DPadUp
	prompt.Parent = torso

	for _, x in ipairs({-13, 13}) do
		for _, z in ipairs({21, -15, -41, -89, -120, -209, -227}) do
			lantern(Vector3.new(x, 0, z))
		end
	end
	local trainingSign = part("TrainingSign", Vector3.new(8, 3, 0.7), Vector3.new(26, 5, -52), COLORS.DarkWood, Enum.Material.Wood)
	part("SignPost", Vector3.new(0.8, 5, 0.8), Vector3.new(26, 2.5, -52), COLORS.Wood, Enum.Material.Wood)
	label(trainingSign, "TRAINING GROUNDS\nPractice jutsu on the dummies", 300, 60)

	local river = part("River", Vector3.new(238, 0.45, 17), Vector3.new(0, 0.15, -106), Color3.fromRGB(65, 150, 167), Enum.Material.Glass)
	river.Transparency = 0.25
	river.CanCollide = false
	for _, z in ipairs({-115, -97}) do
		part("RiverBank", Vector3.new(240, 0.7, 2), Vector3.new(0, 0.25, z), COLORS.Stone, Enum.Material.Pebble)
	end
	local bridge = model("RedwoodBridge")
	for z = -119, -93, 2 do
		part("BridgePlank", Vector3.new(16, 0.8, 1.8), Vector3.new(0, 0.8, z), COLORS.Wood, Enum.Material.WoodPlanks, bridge)
	end
	for _, x in ipairs({-8, 8}) do
		for _, z in ipairs({-119, -106, -93}) do
			part("BridgePost", Vector3.new(0.9, 4.5, 0.9), Vector3.new(x, 2.5, z), COLORS.Roof, Enum.Material.Wood, bridge)
		end
		part("BridgeRail", Vector3.new(0.7, 0.7, 27), Vector3.new(x, 4.2, -106), COLORS.Roof, Enum.Material.Wood, bridge)
	end
	for _, x in ipairs({ -11, 11 }) do
		lantern(Vector3.new(x, 0, -106), bridge)
	end
	for index = -3, 3 do
		if index ~= 0 then
			local x = index * 29
			local riverStone = part("RiverStone", Vector3.new(7, 2, 4), Vector3.new(x, 0.5, -106 + index % 2 * 3), COLORS.Stone, Enum.Material.Rock)
			riverStone.Shape = Enum.PartType.Ball
			for reed = 0, 2 do
				local stem = part("RiverReed", Vector3.new(0.22, 3.8 + reed * 0.4, 0.22), Vector3.new(x + reed * 0.65, 2, -96), COLORS.Leaf, Enum.Material.Grass)
				stem.CanCollide = false
			end
		end
	end

	local campSign = part("CampSign", Vector3.new(8, 3, 1), Vector3.new(-22, 4, -130), COLORS.DarkWood, Enum.Material.Wood)
	label(campSign, "ROGUE CAMP\nDefeat rogues for your mission", 280, 60, Color3.fromRGB(255, 164, 112))
	for _, side in ipairs({-1, 1}) do
		for _, z in ipairs({-150, -179}) do
			local x = side * 36
			local group = model("RogueShelter")
			for _, dx in ipairs({-7, 7}) do
				part("ShelterPost", Vector3.new(1, 8, 1), Vector3.new(x + dx, 4, z), COLORS.DarkWood, Enum.Material.Wood, group)
			end
			local awning = part("CanvasAwning", Vector3.new(18, 0.5, 15), Vector3.new(x, 8.5, z), Color3.fromRGB(116, 81, 59), Enum.Material.Fabric, group)
			awning.CFrame *= CFrame.Angles(0, 0, side * math.rad(9))
			part("SupplyCrate", Vector3.new(4, 4, 4), Vector3.new(x + side * 3, 2, z - 3), COLORS.Wood, Enum.Material.WoodPlanks, group)
		end
	end
	local fire = part("CampEmbers", Vector3.new(3, 0.4, 3), Vector3.new(27, 0.4, -165), Color3.fromRGB(255, 118, 46), Enum.Material.Neon)
	fire.CanCollide = false
	local fireLight = Instance.new("PointLight")
	fireLight.Color = fire.Color
	fireLight.Range = 17
	fireLight.Brightness = 1.4
	fireLight.Parent = fire

	gate(-225, "THE ASH WARDEN")
	local arena = part("BossArena", Vector3.new(1.1, 87, 87), Vector3.new(0, 0.2, -270), Color3.fromRGB(155, 141, 118), Enum.Material.Slate)
	arena.Shape = Enum.PartType.Cylinder
	arena.CFrame = CFrame.new(0, 0.2, -270) * CFrame.Angles(0, 0, math.pi / 2)
	for index = 0, 15 do
		local angle = index / 16 * math.pi * 2
		local x = math.sin(angle) * 41
		local z = -270 + math.cos(angle) * 41
		-- Leave a wide entrance facing the village.
		if math.abs(x) > 13 or z < -270 then
			part("ArenaPillar", Vector3.new(3.5, 13, 3.5), Vector3.new(x, 6.5, z), Color3.fromRGB(91, 101, 103), Enum.Material.Slate)
			local cap = part("ArenaRune", Vector3.new(4, 0.7, 4), Vector3.new(x, 13.2, z), Color3.fromRGB(236, 132, 67), Enum.Material.Neon)
			cap.CanCollide = false
		end
	end
	local bossSign = part("ArenaNotice", Vector3.new(1, 1, 1), Vector3.new(19, 6, -239), COLORS.Stone)
	bossSign.Transparency = 1
	bossSign.CanCollide = false
	label(bossSign, "BOSS ARENA\nLearn its attack tells. Dodge, then strike.", 320, 70, Color3.fromRGB(255, 174, 114))

	for _, specification in ipairs({
		{-78, 27, 1.2}, {-91, -14, 1.5}, {77, 26, 1.3}, {91, -22, 1.6},
		{-57, -67, 1.2}, {55, -75, 1.4}, {-80, -95, 1.6}, {80, -94, 1.3},
		{-67, -128, 1.3}, {71, -132, 1.5}, {-80, -165, 1.7}, {83, -176, 1.4},
		{-58, -207, 1.4}, {60, -208, 1.5}, {-75, -247, 1.7}, {74, -265, 1.6},
		{-60, -303, 1.3}, {60, -306, 1.3},
	}) do
		tree(specification[1], specification[2], specification[3], specification[2] < -205)
	end
	-- Hidden boundary slabs retain the play-space limits; varied rock silhouettes hide them.
	for _, x in ipairs({-116, 116}) do
		local boundary = part("ValleyBoundary", Vector3.new(12, 100, 390), Vector3.new(x, 45, -130), COLORS.Stone)
		boundary.Transparency = 1
		for index = 0, 11 do
			local height = 43 + index % 4 * 9
			local cliff = part("RockEscarpment", Vector3.new(27, height, 43),
				Vector3.new(x + math.sign(x) * (index % 3 * 3), height / 2 - 5, 48 - index * 32),
				Color3.fromRGB(100 + index % 3 * 8, 112 + index % 2 * 9, 103), Enum.Material.Rock, nil, "WedgePart")
			cliff.CFrame *= CFrame.Angles(0, if x < 0 then math.pi / 2 else -math.pi / 2, 0)
			local ridge = part("CliffRidge", Vector3.new(25, 10, 36),
				Vector3.new(x + math.sign(x) * 6, height - 8, 48 - index * 32), Color3.fromRGB(71, 93, 75), Enum.Material.Grass)
			ridge.Shape = Enum.PartType.Ball
		end
	end
	for _, z in ipairs({63, -323}) do
		local boundary = part("ValleyEnd", Vector3.new(240, 100, 10), Vector3.new(0, 45, z), COLORS.Stone)
		boundary.Transparency = 1
		for index = -3, 3 do
			local height = 48 + (index + 4) % 3 * 16
			local mountain = part("DistantMountain", Vector3.new(45, height, 39),
				Vector3.new(index * 36, height / 2 - 7, z + (if z > 0 then 13 else -13)),
				Color3.fromRGB(91 + index % 2 * 10, 111, 112), Enum.Material.Rock, nil, "WedgePart")
			mountain.CFrame *= CFrame.Angles(0, if index % 2 == 0 then 0 else math.pi, 0)
		end
	end

	return {
		EnemySpawns = {
			{Kind = "Dummy", Position = Vector3.new(-17, 3.5, -65)},
			{Kind = "Dummy", Position = Vector3.new(17, 3.5, -65)},
			{Kind = "Bandit", Position = Vector3.new(-14, 3.5, -145)},
			{Kind = "Bandit", Position = Vector3.new(14, 3.5, -145)},
			{Kind = "Bandit", Position = Vector3.new(-18, 3.5, -172)},
			{Kind = "Bandit", Position = Vector3.new(18, 3.5, -172)},
			{Kind = "Bandit", Position = Vector3.new(0, 3.5, -191)},
			-- The boss is 1.35x scale: its feet are 4.05 studs below its root.
			{Kind = "Boss", Position = Vector3.new(0, 4.8, -270)},
		},
		MissionPrompt = prompt,
	}
end

return World
]====] },
{ Destination = "client", ClassName = "ModuleScript", Name = "CombatAnimator", Source = [====[
-- Original procedural poses, driven by accepted server actions on every client.
-- C0 offsets layer over the avatar's usual Animator/Animate locomotion tracks.
-- No animation asset ownership, IDs, or web requests are required.
local RunService = game:GetService("RunService")

local CombatAnimator = {}
local IDENTITY = CFrame.new()
local RADIANS = math.pi / 180
local JOINT_NAMES = {
	root = "Root", rootjoint = "Root", waist = "Waist", neck = "Neck",
	leftshoulder = "LeftShoulder", rightshoulder = "RightShoulder",
	leftelbow = "LeftElbow", rightelbow = "RightElbow",
	lefthip = "LeftHip", righthip = "RightHip",
	leftknee = "LeftKnee", rightknee = "RightKnee",
}

local function rotation(x, y, z)
	return CFrame.Angles((x or 0) * RADIANS, (y or 0) * RADIANS, (z or 0) * RADIANS)
end

local GUARD = {
	Root = rotation(-4, 0, 0), Waist = rotation(-4, 0, 0),
	LeftShoulder = rotation(38, 0, 18), RightShoulder = rotation(38, 0, -18),
	LeftElbow = rotation(38, 0, 0), RightElbow = rotation(38, 0, 0),
}
local SEAL = {
	Root = rotation(-5, 0, 0), Neck = rotation(-9, 0, 0),
	LeftShoulder = rotation(68, -12, 34), RightShoulder = rotation(68, 12, -34),
	LeftElbow = rotation(48, 0, 0), RightElbow = rotation(48, 0, 0),
}

-- All coordinates are in the parent body part's axes, not a rig-specific joint basis.
-- That makes the same silhouettes work on both R6 and R15 player avatars.
local JAB = {
	{ 0, GUARD },
	{ 0.19, { Root = rotation(3, 15, 0), Waist = rotation(0, 12, 0), RightShoulder = rotation(-30, -16, -14), LeftShoulder = rotation(54, 0, 18), LeftElbow = rotation(50) } },
	{ 0.36, { Root = rotation(-10, -18, 0), Waist = rotation(-6, -16, 0), RightShoulder = rotation(104, -10, -6), RightElbow = rotation(3), LeftShoulder = rotation(45, 0, 22), LeftElbow = rotation(58), LeftHip = rotation(13), RightHip = rotation(-12) } },
	{ 0.49, { Root = rotation(-8, -15, 0), RightShoulder = rotation(98, -8, -7), LeftShoulder = rotation(40, 0, 20), LeftElbow = rotation(50) } },
	{ 0.82, GUARD }, { 1, {} },
}
local CROSS = {
	{ 0, GUARD },
	{ 0.19, { Root = rotation(3, -19, 0), Waist = rotation(0, -14, 0), LeftShoulder = rotation(-35, 18, 14), RightShoulder = rotation(54, 0, -18), RightElbow = rotation(50) } },
	{ 0.36, { Root = rotation(-12, 24, 0), Waist = rotation(-6, 20, 0), LeftShoulder = rotation(105, 12, 8), LeftElbow = rotation(3), RightShoulder = rotation(45, 0, -22), RightElbow = rotation(58), RightHip = rotation(13), LeftHip = rotation(-12) } },
	{ 0.5, { Root = rotation(-8, 18, 0), LeftShoulder = rotation(97, 10, 8), RightShoulder = rotation(40, 0, -20), RightElbow = rotation(50) } },
	{ 0.82, GUARD }, { 1, {} },
}
local KICK = {
	{ 0, GUARD },
	{ 0.22, { Root = rotation(8, -22, -5), Waist = rotation(0, -12, 0), RightHip = rotation(65, -10, -8), RightKnee = rotation(-75), LeftHip = rotation(-10), LeftShoulder = rotation(48, 0, 25), RightShoulder = rotation(35, 0, -30) } },
	{ 0.415, { Root = rotation(12, -30, -8), Waist = rotation(0, -10, 0), RightHip = rotation(108, -14, -12), RightKnee = rotation(-4), LeftHip = rotation(-12), LeftShoulder = rotation(58, 0, 24), RightShoulder = rotation(-18, 0, -34), Neck = rotation(-8, 15, 0) } },
	{ 0.58, { Root = rotation(7, -20, -4), RightHip = rotation(78, -12, -8), RightKnee = rotation(-45), LeftShoulder = rotation(42, 0, 20), RightShoulder = rotation(20, 0, -25) } },
	{ 0.85, GUARD }, { 1, {} },
}
local RASENGAN = {
	{ 0, GUARD },
	{ 0.22, { Root = rotation(6, 24, 0), Waist = rotation(0, 15, 0), RightShoulder = rotation(-48, -20, -18), RightElbow = rotation(40), LeftShoulder = rotation(65, 0, 20), LeftElbow = rotation(35) } },
	{ 0.4, { Root = CFrame.new(0, -0.08, -0.1) * rotation(-18, -16, 0), Waist = rotation(-8, -14, 0), RightShoulder = rotation(111, -8, -5), RightElbow = rotation(2), LeftShoulder = rotation(-20, 0, 30), RightHip = rotation(-20), LeftHip = rotation(20) } },
	{ 0.61, { Root = rotation(-10, -12, 0), RightShoulder = rotation(100, -5, -8), LeftShoulder = rotation(24, 0, 22) } },
	{ 0.85, GUARD }, { 1, {} },
}
local FIREBALL = {
	{ 0, GUARD }, { 0.19, SEAL },
	{ 0.38, { Root = rotation(5, 0, 0), Neck = rotation(8), LeftShoulder = rotation(78, -8, 33), RightShoulder = rotation(78, 8, -33), LeftElbow = rotation(45), RightElbow = rotation(45) } },
	{ 0.49, { Root = rotation(-14, 0, 0), Waist = rotation(-8), Neck = rotation(-18), LeftShoulder = rotation(62, 0, 27), RightShoulder = rotation(62, 0, -27), LeftElbow = rotation(48), RightElbow = rotation(48) } },
	{ 0.7, SEAL }, { 1, {} },
}
local CLONE = {
	{ 0, GUARD }, { 0.2, SEAL },
	{ 0.36, { Root = rotation(-5), LeftShoulder = rotation(80, -14, 40), RightShoulder = rotation(58, 14, -40), LeftElbow = rotation(35), RightElbow = rotation(60), Neck = rotation(-12) } },
	{ 0.53, SEAL },
	{ 0.72, { Root = rotation(-7), LeftShoulder = rotation(58, -14, 40), RightShoulder = rotation(80, 14, -40), LeftElbow = rotation(60), RightElbow = rotation(35), Neck = rotation(-12) } },
	{ 1, {} },
}
local DASH_POSE = {
	Root = rotation(-30), Waist = rotation(-12), Neck = rotation(22),
	LeftShoulder = rotation(-38, 0, 10), RightShoulder = rotation(-38, 0, -10),
	LeftHip = rotation(36), RightHip = rotation(-30), LeftKnee = rotation(-28), RightKnee = rotation(-35),
}
local CHARGE_POSE = {
	Root = CFrame.new(0, -0.06, 0) * rotation(4), Waist = rotation(-5), Neck = rotation(-8),
	LeftShoulder = rotation(25, 0, 22), RightShoulder = rotation(25, 0, -22),
	LeftElbow = rotation(65), RightElbow = rotation(65),
	LeftHip = rotation(-7, 0, -6), RightHip = rotation(-7, 0, 6), LeftKnee = rotation(12), RightKnee = rotation(12),
}
local BOSS_WINDUP = {
	Root = rotation(12), Waist = rotation(8), Neck = rotation(-10),
	LeftShoulder = rotation(163, 0, 12), RightShoulder = rotation(163, 0, -12),
	LeftHip = rotation(-14, 0, -5), RightHip = rotation(-14, 0, 5), LeftElbow = rotation(-15), RightElbow = rotation(-15),
}
local BOSS_SLAM = {
	Root = CFrame.new(0, -0.2, 0) * rotation(-24), Waist = rotation(-16), Neck = rotation(12),
	LeftShoulder = rotation(102, 0, 8), RightShoulder = rotation(102, 0, -8),
	LeftHip = rotation(20, 0, -5), RightHip = rotation(20, 0, 5), LeftKnee = rotation(-25), RightKnee = rotation(-25),
}
local BANDIT_WINDUP = { Root = rotation(8, 24, 0), Waist = rotation(0, 16, 0), RightShoulder = rotation(-40, -18, -18), LeftShoulder = rotation(48, 0, 20), LeftElbow = rotation(45) }
local BANDIT_PUNCH = { Root = rotation(-12, -22, 0), Waist = rotation(-8, -15, 0), RightShoulder = rotation(105, -10, -6), LeftShoulder = rotation(42, 0, 20), LeftElbow = rotation(45) }
local FLINCH = { Root = rotation(10, 0, 4), Waist = rotation(8, 0, 3), Neck = rotation(14, -5, 0), RightShoulder = rotation(-15, 0, -7), LeftShoulder = rotation(-15, 0, 7) }
local ACTIONS = { Strike = true, Rasengan = true, Fireball = true, ShadowClone = true, Dash = true, Charge = true, EnemyWindup = true, EnemyAttack = true, Hit = true, Cancel = true }

local function finite(number)
	return type(number) == "number" and number == number and math.abs(number) < math.huge
end

local function blendPose(first, second, alpha)
	local pose = {}
	for key, value in first do pose[key] = value:Lerp(second[key] or IDENTITY, alpha) end
	for key, value in second do
		if not first[key] then pose[key] = IDENTITY:Lerp(value, alpha) end
	end
	return pose
end

local function sample(frames, progress)
	if progress <= frames[1][1] then return frames[1][2] end
	for index = 2, #frames do
		local right, left = frames[index], frames[index - 1]
		if progress <= right[1] then
			local t = math.clamp((progress - left[1]) / (right[1] - left[1]), 0, 1)
			return blendPose(left[2], right[2], t * t * (3 - 2 * t))
		end
	end
	return frames[#frames][2]
end

local function actionPose(action, progress)
	local name = action.Action
	if name == "Strike" then return sample(if action.Combo == 3 then KICK elseif action.Combo == 2 then CROSS else JAB, progress) end
	if name == "Rasengan" then return sample(RASENGAN, progress) end
	if name == "Fireball" then return sample(FIREBALL, progress) end
	if name == "ShadowClone" then return sample(CLONE, progress) end
	if name == "Dash" then return sample({ { 0, DASH_POSE }, { 0.65, DASH_POSE }, { 1, {} } }, progress) end
	if name == "Charge" then return sample({ { 0, {} }, { 0.12, CHARGE_POSE }, { 0.88, CHARGE_POSE }, { 1, {} } }, progress) end
	if name == "EnemyWindup" then
		local preparation = if action.Boss then BOSS_WINDUP else BANDIT_WINDUP
		local contact = if action.Boss then BOSS_SLAM else BANDIT_PUNCH
		-- Strike during the final part of the warning, reaching contact exactly when
		-- the server resolves damage. EnemyAttack then continues from that same pose.
		return sample({ { 0, GUARD }, { 0.55, preparation }, { 0.78, preparation }, { 1, contact } }, progress)
	end
	if name == "EnemyAttack" then return sample({ { 0, if action.Boss then BOSS_SLAM else BANDIT_PUNCH }, { 0.22, if action.Boss then BOSS_SLAM else BANDIT_PUNCH }, { 0.8, GUARD }, { 1, {} } }, progress) end
	return {}
end

local function reset(record)
	for _, joint in record.Joints do
		if joint.Motor.Parent and joint.Applied then
			if joint.Motor.C0 == joint.Applied then joint.Motor.C0 = joint.Base end
			joint.Applied = nil
		end
	end
end

local function scanJoints(record)
	for _, descendant in record.Model:GetDescendants() do
		if descendant:IsA("Motor6D") and descendant.Part0 and descendant.Part1 and not record.Joints[descendant] then
			local semantic = JOINT_NAMES[string.lower(string.gsub(descendant.Name, "[%s_]", ""))]
			if semantic then
				record.Joints[descendant] = { Motor = descendant, Name = semantic, Base = descendant.C0 }
			end
		end
	end
end

local function register(records, model)
	if records[model] then return records[model] end
	if typeof(model) ~= "Instance" or not model:IsA("Model") or not model.Parent then return nil end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then return nil end
	local kind = model:GetAttribute("EnemyKind")
	local record = {
		Model = model, Humanoid = humanoid, Root = root, Joints = {},
		NPC = kind ~= nil, Dummy = kind == "Dummy", LastPosition = root.Position,
		Speed = 0, Gait = 0, ScanAt = 0,
	}
	scanJoints(record)
	records[model] = record
	return record
end

local function locomotion(record, dt, now)
	local position = record.Root.Position
	local delta = position - record.LastPosition
	record.LastPosition = position
	local speed = math.min(Vector3.new(delta.X, 0, delta.Z).Magnitude / math.max(dt, 0.001), 28)
	record.Speed += (speed - record.Speed) * (1 - math.exp(-dt * 12))
	record.Gait += dt * math.max(0, record.Speed) * 0.58
	local stride = math.sin(record.Gait)
	local moving = math.clamp(record.Speed / 9, 0, 1)
	local idle = math.sin(now * 2.3) * 1.3
	if record.Dummy then return {} end
	return {
		Root = CFrame.new(0, math.abs(stride) * 0.055 * moving, 0) * rotation(-6 * moving, 0, stride * moving * 2),
		Neck = rotation(idle * 0.5 + 3 * moving, 0, 0),
		LeftShoulder = rotation(18 + stride * 38 * moving + idle, 0, 10),
		RightShoulder = rotation(18 - stride * 38 * moving - idle, 0, -10),
		LeftHip = rotation(-stride * 42 * moving, 0, 0),
		RightHip = rotation(stride * 42 * moving, 0, 0),
	}
end

function CombatAnimator.Start(effectRemote)
	local records = {}
	local controller = { Destroyed = false }
	local scanElapsed = 1
	local effectConnection = effectRemote.OnClientEvent:Connect(function(packet)
		if controller.Destroyed or type(packet) ~= "table" or packet.Kind ~= "CombatAnimation" or not ACTIONS[packet.Action] then return end
		local record = register(records, packet.Actor)
		if not record then return end
		if packet.Action == "Cancel" then record.Active = nil; return end
		local now = workspace:GetServerTimeNow()
		local start = if finite(packet.StartedAt) then packet.StartedAt else now
		local duration = if finite(packet.Duration) then math.clamp(packet.Duration, 0.08, 6) else 0.4
		if now - start > duration + 0.2 or start > now + 1 then return end
		local action = { Action = packet.Action, StartedAt = start, Duration = duration, Combo = packet.Combo, Boss = packet.Boss == true }
		if packet.Action == "Hit" then
			record.Flinch = action
		else
			-- An older delayed packet must not replace a more recent accepted action.
			if record.Active and record.Active.StartedAt > start then return end
			record.Active = action
		end
	end)
	local frameConnection = RunService.PreSimulation:Connect(function(dt)
		if controller.Destroyed then return end
		dt = math.min(dt, 0.1)
		local now = workspace:GetServerTimeNow()
		scanElapsed += dt
		if scanElapsed >= 0.5 then
			scanElapsed = 0
			local folder = workspace:FindFirstChild("ShinobiEnemies")
			if folder then
				for _, model in folder:GetChildren() do register(records, model) end
			end
		end
		for model, record in records do
			if not model.Parent or not record.Root.Parent or not record.Humanoid.Parent or record.Humanoid.Health <= 0 then
				reset(record)
				records[model] = nil
				continue
			end
			local camera = workspace.CurrentCamera
			if camera and (camera.CFrame.Position - record.Root.Position).Magnitude > 230 then
				reset(record)
				record.LastPosition = record.Root.Position
				continue
			end
			if now >= record.ScanAt then
				scanJoints(record)
				record.ScanAt = now + 1
			end
			local pose = if record.NPC then locomotion(record, dt, now) else {}
			local active = record.Active
			if active then
				local elapsed = now - active.StartedAt
				local canceledCharge = active.Action == "Charge" and (record.Humanoid.MoveDirection.Magnitude > 0.1 or record.Root.AssemblyLinearVelocity.Magnitude > 4)
				local allowance = if active.Action == "EnemyWindup" then 0.15 else 0
				if elapsed > active.Duration + allowance or canceledCharge then
					record.Active = nil
				else
					local action = actionPose(active, math.clamp(elapsed / active.Duration, 0, 1))
					for key, value in action do pose[key] = value end
				end
			end
			local flinch = record.Flinch
			if flinch then
				local elapsed = (now - flinch.StartedAt) / flinch.Duration
				if elapsed >= 1 then
					record.Flinch = nil
				else
					local weight = math.sin(math.clamp(elapsed, 0, 1) * math.pi)
					for key, value in FLINCH do pose[key] = (pose[key] or IDENTITY) * IDENTITY:Lerp(value, weight) end
				end
			end
			if not record.NPC and not record.Active and not record.Flinch then
				reset(record)
				records[model] = nil
				continue
			end
			for _, joint in record.Joints do
				local motor = joint.Motor
				if not motor.Parent then continue end
				-- Respect a deliberate external rig/scale update rather than restoring stale C0.
				if motor.C0 ~= joint.Applied and motor.C0 ~= joint.Base then joint.Base = motor.C0 end
				local offset = pose[joint.Name] or IDENTITY
				local base = joint.Base
				local applied = CFrame.new(base.Position) * offset * base.Rotation
				motor.C0 = applied
				joint.Applied = motor.C0
			end
		end
	end)
	function controller:Destroy()
		if self.Destroyed then return end
		self.Destroyed = true
		effectConnection:Disconnect()
		frameConnection:Disconnect()
		for _, record in records do reset(record) end
		table.clear(records)
	end
	return controller
end

return CombatAnimator
]====] },
{ Destination = "client", ClassName = "LocalScript", Name = "Main", Source = [====[
-- Client presentation and input only. Combat outcomes and progression belong to the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local shinobi = ReplicatedStorage:WaitForChild("Shinobi")
local Config = require(shinobi:WaitForChild("Config"))
local remotes = shinobi:WaitForChild("Remotes")
local actionRemote = remotes:WaitForChild("Action")
local stateRemote = remotes:WaitForChild("State")
local effectRemote = remotes:WaitForChild("Effect")
local requestStateRemote = remotes:WaitForChild("RequestState")
local combatAnimator = require(script.Parent:WaitForChild("CombatAnimator")).Start(effectRemote)

local COLORS = {
	Ink = Color3.fromRGB(17, 23, 28),
	Panel = Color3.fromRGB(25, 34, 40),
	Border = Color3.fromRGB(77, 83, 78),
	Paper = Color3.fromRGB(242, 234, 212),
	Muted = Color3.fromRGB(175, 180, 169),
	Orange = Color3.fromRGB(255, 157, 67),
	Health = Color3.fromRGB(109, 207, 139),
	Chakra = Color3.fromRGB(91, 204, 232),
	Red = Color3.fromRGB(255, 94, 80),
}

local gui = Instance.new("ScreenGui")
gui.Name = "ShinobiHUD"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 10
gui.Parent = player:WaitForChild("PlayerGui")

local function create(className, properties, parent)
	local object = Instance.new(className)
	for key, value in pairs(properties) do
		object[key] = value
	end
	object.Parent = parent
	return object
end

local function corner(parent, radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius or 10) }, parent)
end

local function stroke(parent, color, transparency)
	return create("UIStroke", {
		Color = color or COLORS.Border,
		Transparency = transparency or 0.15,
		Thickness = 1,
	}, parent)
end

local function label(parent, text, size, position, textSize, color, font)
	return create("TextLabel", {
		BackgroundTransparency = 1,
		Size = size,
		Position = position,
		Text = text,
		TextColor3 = color or COLORS.Paper,
		TextSize = textSize or 14,
		Font = font or Enum.Font.Gotham,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	}, parent)
end

local function panel(parent, size, position, anchor)
	local frame = create("Frame", {
		Size = size,
		Position = position,
		AnchorPoint = anchor or Vector2.zero,
		BackgroundColor3 = COLORS.Ink,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
	}, parent)
	corner(frame, 12)
	stroke(frame)
	return frame
end

local function bar(parent, y, color, title)
	label(parent, title, UDim2.fromOffset(100, 18), UDim2.fromOffset(17, y), 10, COLORS.Muted, Enum.Font.GothamBold)
	local amount = label(parent, "—", UDim2.fromOffset(140, 18), UDim2.fromOffset(148, y), 11)
	amount.TextXAlignment = Enum.TextXAlignment.Right
	local track = create("Frame", {
		Position = UDim2.fromOffset(17, y + 22),
		Size = UDim2.fromOffset(271, 7),
		BackgroundColor3 = COLORS.Panel,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, parent)
	corner(track, 4)
	local fill = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
	}, track)
	corner(fill, 4)
	return { Fill = fill, Amount = amount }
end

local status = panel(gui, UDim2.fromOffset(305, 194), UDim2.fromOffset(18, 18))
local statusScale = create("UIScale", { Scale = 1 }, status)
local crest = create("Frame", {
	Position = UDim2.fromOffset(19, 18),
	Size = UDim2.fromOffset(32, 32),
	BackgroundColor3 = COLORS.Orange,
	BorderSizePixel = 0,
	Rotation = 45,
}, status)
corner(crest, 5)
local crestMark = label(status, "忍", UDim2.fromOffset(32, 32), UDim2.fromOffset(19, 18), 20, COLORS.Ink, Enum.Font.GothamBold)
crestMark.TextXAlignment = Enum.TextXAlignment.Center
label(status, "SHINOBI", UDim2.fromOffset(216, 24), UDim2.fromOffset(67, 13), 19, COLORS.Paper, Enum.Font.GothamBold)
local rankLabel = label(status, "EMBER LEGACY  /  CONNECTING", UDim2.fromOffset(220, 20), UDim2.fromOffset(67, 36), 10, COLORS.Orange, Enum.Font.GothamBold)
local healthBar = bar(status, 66, COLORS.Health, "HEALTH")
local chakraBar = bar(status, 105, COLORS.Chakra, "CHAKRA")
local xpBar = bar(status, 144, COLORS.Orange, "EXPERIENCE")

local mission = panel(gui, UDim2.fromOffset(284, 144), UDim2.new(1, -18, 0, 18), Vector2.new(1, 0))
local missionScale = create("UIScale", { Scale = 1 }, mission)
label(mission, "FIELD JOURNAL", UDim2.fromOffset(200, 20), UDim2.fromOffset(16, 11), 10, COLORS.Orange, Enum.Font.GothamBold)
local coinLabel = label(mission, "0 RYO", UDim2.fromOffset(93, 20), UDim2.fromOffset(174, 11), 11)
coinLabel.TextXAlignment = Enum.TextXAlignment.Right
local missionTitle = label(mission, "Your first assignment", UDim2.fromOffset(250, 26), UDim2.fromOffset(16, 34), 16, COLORS.Paper, Enum.Font.GothamBold)
local missionDetail = label(mission, "Find Sensei in the village. Use the prompt to accept a mission.", UDim2.fromOffset(250, 51), UDim2.fromOffset(16, 61), 12, COLORS.Muted)
missionDetail.TextWrapped = true
missionDetail.TextYAlignment = Enum.TextYAlignment.Top
local missionFooter = label(mission, "TRAIN  →  CLEAR THE CAMP  →  CHALLENGE THE BOSS", UDim2.fromOffset(256, 20), UDim2.fromOffset(16, 116), 9, COLORS.Orange, Enum.Font.GothamBold)

local sessionLabel = label(gui, "", UDim2.fromOffset(550, 24), UDim2.new(0.5, 0, 0, 8), 11, COLORS.Orange)
sessionLabel.AnchorPoint = Vector2.new(0.5, 0)
sessionLabel.TextXAlignment = Enum.TextXAlignment.Center

local actionPanel = panel(gui, UDim2.fromOffset(532, 94), UDim2.new(0.5, 0, 1, -22), Vector2.new(0.5, 1))
local actionScale = create("UIScale", { Scale = 1 }, actionPanel)
local actionLayout = create("UIGridLayout", {
	CellSize = UDim2.fromOffset(80, 78),
	CellPadding = UDim2.fromOffset(6, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
	FillDirectionMaxCells = 6,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
}, actionPanel)
local actionButtons = {}
local state = nil
local pending = {}
local reducedEffects = false
local introOpen = true
local lastToast = ""
local lastToastAt = 0
local toastSerial = 0

local toast = panel(gui, UDim2.fromOffset(440, 48), UDim2.new(0.5, 0, 0, 186), Vector2.new(0.5, 0))
toast.Visible = false
toast.ZIndex = 20
local toastScale = create("UIScale", { Scale = 1 }, toast)
local toastText = label(toast, "", UDim2.new(1, -24, 1, -8), UDim2.fromOffset(12, 4), 13)
toastText.TextWrapped = true
toastText.TextXAlignment = Enum.TextXAlignment.Center
toastText.ZIndex = 21

local function notify(message)
	if type(message) ~= "string" or message == "" then
		return
	end
	local now = os.clock()
	if message == lastToast and now - lastToastAt < 0.8 then
		return
	end
	lastToast, lastToastAt = message, now
	toastSerial += 1
	local serial = toastSerial
	toastText.Text = message
	toast.Visible = true
	task.delay(3.5, function()
		if toastSerial == serial then
			toast.Visible = false
		end
	end)
end

local settings = create("TextButton", {
	Name = "EffectsToggle",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -18, 0, 171),
	Size = UDim2.fromOffset(146, 30),
	Text = "EFFECTS  /  FULL",
	TextColor3 = COLORS.Muted,
	TextSize = 10,
	Font = Enum.Font.GothamBold,
	BackgroundColor3 = COLORS.Ink,
	BackgroundTransparency = 0.15,
	BorderSizePixel = 0,
}, gui)
corner(settings, 8)
stroke(settings)

local shiftLock = require(script.Parent:WaitForChild("ShiftLock")).Start({
	Gui = gui,
	IsBlocked = function() return introOpen end,
	Notify = notify,
})
script.Destroying:Connect(function()
	shiftLock:Destroy()
	combatAnimator:Destroy()
end)

local overlay = create("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = COLORS.Ink,
	BackgroundTransparency = 0.28,
	BorderSizePixel = 0,
	ZIndex = 30,
}, gui)
local welcome = panel(overlay, UDim2.fromOffset(516, 448), UDim2.fromScale(0.5, 0.5), Vector2.new(0.5, 0.5))
welcome.ZIndex = 31
local welcomeScale = create("UIScale", { Scale = 1 }, welcome)
local welcomeAccent = create("Frame", {
	Size = UDim2.new(1, -48, 0, 3),
	Position = UDim2.fromOffset(24, 20),
	BackgroundColor3 = COLORS.Orange,
	BorderSizePixel = 0,
	ZIndex = 32,
}, welcome)
corner(welcomeAccent, 2)

local function welcomeLabel(text, y, height, size, color, font)
	local result = label(welcome, text, UDim2.fromOffset(456, height), UDim2.fromOffset(30, y), size, color, font)
	result.ZIndex = 32
	return result
end

welcomeLabel("A SHINOBI'S JOURNEY BEGINS", 37, 22, 11, COLORS.Orange, Enum.Font.GothamBold)
welcomeLabel("SHINOBI", 68, 46, 42, COLORS.Paper, Enum.Font.GothamBlack)
welcomeLabel("EMBER LEGACY", 113, 26, 18, COLORS.Orange, Enum.Font.GothamBold)
local introDescription = welcomeLabel("A Naruto-inspired fan prototype. Master your chakra, defend the village, and earn your rank.", 157, 47, 14, COLORS.Muted)
introDescription.TextWrapped = true
introDescription.TextYAlignment = Enum.TextYAlignment.Top
welcomeLabel("01   Train with Rasengan and the practice dummies.", 222, 26, 13)
welcomeLabel("02   Take Sensei's mission. Defeat five bandits.", 254, 26, 13)
welcomeLabel("03   Unlock jutsu and challenge the camp's boss.", 286, 26, 13)
local enterButton = create("TextButton", {
	Position = UDim2.fromOffset(30, 337),
	Size = UDim2.fromOffset(456, 48),
	BackgroundColor3 = COLORS.Orange,
	BorderSizePixel = 0,
	Text = "ENTER THE VILLAGE  →",
	TextColor3 = COLORS.Ink,
	TextSize = 14,
	Font = Enum.Font.GothamBold,
	ZIndex = 32,
}, welcome)
corner(enterButton, 8)
local welcomeControls = welcomeLabel("WASD move · Space jump · Z / X / C jutsu · Q dash · R focus · Shift lock", 400, 28, 10, COLORS.Muted)
welcomeControls.TextWrapped = true
welcomeControls.TextXAlignment = Enum.TextXAlignment.Center

local function closeIntro()
	introOpen = false
	overlay.Visible = false
end

enterButton.Activated:Connect(closeIntro)

local effectsFolder = Instance.new("Folder")
effectsFolder.Name = "ShinobiLocalEffects"
effectsFolder.Parent = workspace
local effectsCount = 0

settings.Activated:Connect(function()
	reducedEffects = not reducedEffects
	settings.Text = reducedEffects and "EFFECTS  /  REDUCED" or "EFFECTS  /  FULL"
	-- Existing attack telegraphs must finish even when this setting changes.
end)

local function aimPosition()
	local camera = workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not camera then
		return root and root.Position + root.CFrame.LookVector * 60 or Vector3.zero
	end
	local lastInput = UserInputService:GetLastInputType()
	local screenPoint = camera.ViewportSize / 2
	if not shiftLock:IsActive() and lastInput ~= Enum.UserInputType.Touch and not string.find(lastInput.Name, "Gamepad") then
		-- ScreenPointToRay accounts for the inset in GetMouseLocation coordinates.
		screenPoint = UserInputService:GetMouseLocation()
		local ray = camera:ScreenPointToRay(screenPoint.X, screenPoint.Y)
		local parameters = RaycastParams.new()
		parameters.FilterType = Enum.RaycastFilterType.Exclude
		parameters.FilterDescendantsInstances = character and { character, effectsFolder } or { effectsFolder }
		local result = workspace:Raycast(ray.Origin, ray.Direction * 500, parameters)
		return result and result.Position or ray.Origin + ray.Direction * 500
	end
	local ray = camera:ViewportPointToRay(screenPoint.X, screenPoint.Y)
	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Exclude
	parameters.FilterDescendantsInstances = character and { character, effectsFolder } or { effectsFolder }
	local result = workspace:Raycast(ray.Origin, ray.Direction * 500, parameters)
	return result and result.Position or ray.Origin + ray.Direction * 500
end

local function requestAction(actionId)
	if introOpen or UserInputService:GetFocusedTextBox() then
		return
	end
	if not state then
		notify("Loading your shinobi profile…")
		return
	end
	local action = Config.Actions[actionId]
	if not action then
		return
	end
	if state.Level < action.UnlockLevel then
		notify(action.Label .. " unlocks at level " .. tostring(action.UnlockLevel) .. ".")
		return
	end
	local now = workspace:GetServerTimeNow()
	local cooldown = state.Cooldowns and state.Cooldowns[actionId] or 0
	if now < cooldown or now < (pending[actionId] or 0) then
		return
	end
	if state.Chakra < action.Cost then
		notify("Need more chakra. Use Focus to recover.")
		return
	end
	pending[actionId] = now + 0.25
	actionRemote:FireServer(actionId, aimPosition())
end

local function mouseOverButton()
	local mouse = UserInputService:GetMouseLocation()
	for _, object in ipairs(player.PlayerGui:GetGuiObjectsAtPosition(mouse.X, mouse.Y)) do
		local current = object
		while current and current ~= player.PlayerGui do
			if current:IsA("GuiButton") then
				return true
			end
			current = current.Parent
		end
	end
	return false
end

local gamepadKeys = {
	Strike = Enum.KeyCode.ButtonR2,
	Rasengan = Enum.KeyCode.ButtonX,
	Fireball = Enum.KeyCode.ButtonY,
	ShadowClone = Enum.KeyCode.ButtonB,
	Dash = Enum.KeyCode.ButtonL1,
	Charge = Enum.KeyCode.ButtonR1,
}
local gamepadNames = { Strike = "RT", Rasengan = "X", Fireball = "Y", ShadowClone = "B", Dash = "LB", Charge = "RB" }

for index, actionId in ipairs(Config.ActionOrder) do
	local action = Config.Actions[actionId]
	local button = create("TextButton", {
		Name = actionId,
		Size = UDim2.fromOffset(80, 78),
		BackgroundColor3 = COLORS.Panel,
		BorderSizePixel = 0,
		Text = "",
		LayoutOrder = index,
		AutoButtonColor = true,
	}, actionPanel)
	corner(button, 8)
	local outline = stroke(button, index == 2 and COLORS.Chakra or COLORS.Border, 0.4)
	local keyLabel = label(button, action.Key, UDim2.fromOffset(66, 23), UDim2.fromOffset(7, 3), 14, COLORS.Orange, Enum.Font.GothamBold)
	local actionLabel = label(button, action.Label, UDim2.fromOffset(72, 25), UDim2.fromOffset(4, 27), 10, COLORS.Paper, Enum.Font.GothamBold)
	actionLabel.TextWrapped = true
	actionLabel.TextXAlignment = Enum.TextXAlignment.Center
	local costLabel = label(button, action.Cost > 0 and tostring(action.Cost) .. " CH" or "FREE", UDim2.fromOffset(72, 18), UDim2.fromOffset(4, 56), 9, COLORS.Muted)
	costLabel.TextXAlignment = Enum.TextXAlignment.Center
	local cooldownOverlay = create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = COLORS.Ink,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 3,
	}, button)
	corner(cooldownOverlay, 8)
	local cooldownText = label(cooldownOverlay, "", UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), 17, COLORS.Paper, Enum.Font.GothamBold)
	cooldownText.TextXAlignment = Enum.TextXAlignment.Center
	cooldownText.ZIndex = 4
	actionButtons[actionId] = { Button = button, Key = keyLabel, Cost = costLabel, Overlay = cooldownOverlay, Text = cooldownText, Outline = outline }
	button.Activated:Connect(function()
		requestAction(actionId)
	end)
	local keyboardKey = actionId == "Strike" and Enum.UserInputType.MouseButton1 or Enum.KeyCode[action.Key]
	ContextActionService:BindAction("Shinobi_" .. actionId, function(_, inputState, inputObject)
		if introOpen or UserInputService:GetFocusedTextBox() then
			return Enum.ContextActionResult.Pass
		end
		if inputObject.UserInputType == Enum.UserInputType.MouseButton1 and mouseOverButton() then
			return Enum.ContextActionResult.Pass
		end
		if inputState == Enum.UserInputState.Begin then
			requestAction(actionId)
		end
		return Enum.ContextActionResult.Sink
	end, false, keyboardKey, gamepadKeys[actionId])
end

local function updateControls()
	local input = UserInputService:GetLastInputType()
	local gamepad = string.find(input.Name, "Gamepad") ~= nil
	for actionId, controls in pairs(actionButtons) do
		controls.Key.Text = gamepad and gamepadNames[actionId] or Config.Actions[actionId].Key
	end
	if gamepad then
		welcomeControls.Text = "Left stick move · A jump · X / Y / B jutsu · LB dash · RB focus · R3 camera lock"
	elseif UserInputService.TouchEnabled then
		welcomeControls.Text = "Use the movement stick and jump button. Tap jutsu to fight, or Camera Lock to aim."
	else
		welcomeControls.Text = "WASD move · Space jump · Z / X / C jutsu · Q dash · R focus · Shift lock"
	end
end

local function setBar(target, current, maximum)
	maximum = math.max(maximum, 1)
	local proportion = math.clamp(current / maximum, 0, 1)
	TweenService:Create(target.Fill, TweenInfo.new(0.18), { Size = UDim2.fromScale(proportion, 1) }):Play()
	target.Amount.Text = string.format("%d / %d", math.ceil(current), math.ceil(maximum))
end

stateRemote.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	state = payload
	rankLabel.Text = string.upper(payload.Rank or "Academy Student") .. "  /  LV. " .. tostring(payload.Level)
	coinLabel.Text = tostring(payload.Coins) .. " RYO"
	setBar(chakraBar, payload.Chakra, payload.MaxChakra or Config.MaxChakra)
	setBar(xpBar, payload.XP, payload.XPRequired)
	if payload.MissionReady then
		missionTitle.Text = "Assignment complete"
		missionDetail.Text = "Return to Sensei in the village. Use the prompt to collect your reward."
		missionFooter.Text = "+" .. tostring(Config.Mission.XP) .. " XP  /  +" .. tostring(Config.Mission.Coins) .. " RYO"
	elseif payload.MissionActive then
		missionTitle.Text = Config.Mission.Title
		missionDetail.Text = string.format("Bandits defeated: %d / %d\nFollow the path beyond the training grounds.", payload.MissionKills, payload.MissionGoal or Config.Mission.Goal)
		missionFooter.Text = "RETURN TO SENSEI AFTER YOUR MISSION"
	else
		missionTitle.Text = "Your next assignment"
		missionDetail.Text = "Find Sensei in the village. Use the prompt to accept a mission."
		missionFooter.Text = "TRAIN  →  CLEAR THE CAMP  →  CHALLENGE THE BOSS"
	end
	sessionLabel.Text = payload.SessionOnly and "PRACTICE SESSION · Progress is not saving" or ""
	notify(payload.Message)
end)

local healthConnection = nil
local function bindCharacter(character)
	if healthConnection then
		healthConnection:Disconnect()
		healthConnection = nil
	end
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	local function updateHealth()
		setBar(healthBar, humanoid.Health, humanoid.MaxHealth)
	end
	updateHealth()
	healthConnection = humanoid.HealthChanged:Connect(updateHealth)
	humanoid.Died:Connect(function()
		notify("Defeated. You will return to the village.")
	end)
end

player.CharacterAdded:Connect(bindCharacter)
if player.Character then
	task.spawn(bindCharacter, player.Character)
end
task.spawn(function()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	end)
end)

local function effectPart(position, size, color, lifetime, endSize, endPosition, critical)
	-- The server's bounded enemy roster owns critical attack warnings. Cosmetic
	-- bursts must never use up the budget that makes an incoming attack readable.
	if not critical and effectsCount >= (reducedEffects and 28 or 100) then
		return nil
	end
	local part = Instance.new("Part")
	part.Name = critical and "AttackTelegraph" or "JutsuEffect"
	part.Shape = Enum.PartType.Ball
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = critical and 0.35 or (reducedEffects and 0.6 or 0.25)
	part.Size = size
	part.Position = position
	part.Parent = effectsFolder
	effectsCount += 1
	part.Destroying:Connect(function()
		effectsCount -= 1
	end)
	local goal = { Transparency = 1, Size = endSize or size * 2 }
	if endPosition then
		goal.Position = endPosition
	end
	TweenService:Create(part, TweenInfo.new(lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
	Debris:AddItem(part, lifetime + 0.05)
	return part
end

local function groundPulse(position, radius, color, duration, critical)
	local world = workspace:FindFirstChild("ShinobiWorld")
	local ground = position
	if world then
		local parameters = RaycastParams.new()
		parameters.FilterType = Enum.RaycastFilterType.Include
		parameters.FilterDescendantsInstances = { world }
		parameters.RespectCanCollide = true
		-- Packets can contain either root height or ground height. Start just above
		-- that point so an overhead roof cannot steal the warning from the floor.
		local hit = workspace:Raycast(position + Vector3.new(0, 0.75, 0), Vector3.new(0, -12, 0), parameters)
		if hit then
			ground = hit.Position
		end
	end
	local diameter = radius * 2
	local startSize = critical and Vector3.new(diameter, 0.16, diameter) or Vector3.new(1, 0.16, 1)
	return effectPart(ground + Vector3.new(0, 0.12, 0), startSize, color, duration, Vector3.new(diameter, 0.12, diameter), nil, critical)
end

effectRemote.OnClientEvent:Connect(function(effect)
	if type(effect) ~= "table" or typeof(effect.Position) ~= "Vector3" then
		return
	end
	local camera = workspace.CurrentCamera
	if camera and (camera.CFrame.Position - effect.Position).Magnitude > 340 then
		return
	end
	local position = effect.Position
	local kind = effect.Kind
	if kind == "EnemyWindup" then
		-- Keep attack warnings visible even with reduced visual effects.
		groundPulse(position, effect.Radius or 7, COLORS.Red, effect.Duration or 0.7, true)
	elseif kind == "EnemyAttack" then
		groundPulse(position, effect.Radius or 7, COLORS.Red, 0.28, true)
	elseif kind == "Rasengan" then
		effectPart(position, Vector3.new(2.8, 2.8, 2.8), COLORS.Chakra, 0.35, Vector3.new(11, 11, 11), effect.Target)
		groundPulse(effect.Target or position, effect.Radius or 8, COLORS.Chakra, 0.45)
	elseif kind == "Fireball" then
		effectPart(position, Vector3.new(3.5, 3.5, 3.5), COLORS.Orange, 0.35, Vector3.new(5, 5, 5), effect.Target)
		if typeof(effect.Target) == "Vector3" then
			task.delay(0.3, function()
				groundPulse(effect.Target, effect.Radius or 6, COLORS.Orange, 0.4)
			end)
		end
	elseif kind == "ShadowClone" then
		groundPulse(position, effect.Radius or 9, Color3.fromRGB(191, 192, 240), 0.5)
		if not reducedEffects then
			local duration = math.clamp(effect.Duration or 4.8, 0.5, 5)
			for index = 1, 3 do
				local angle = index * math.pi * 2 / 3
				local offset = Vector3.new(math.cos(angle) * 4, 0, math.sin(angle) * 4)
				effectPart(position + offset, Vector3.new(2, 4, 1), Color3.fromRGB(172, 177, 230), duration, Vector3.new(2.5, 5, 1.5))
				effectPart(position + offset + Vector3.new(0, 2.6, 0), Vector3.new(1.5, 1.5, 1.5), COLORS.Paper, duration)
			end
		end
	elseif kind == "Dash" then
		effectPart(position, Vector3.new(2, 3, 2), COLORS.Paper, 0.2, Vector3.new(3, 3, 3), effect.Target)
	elseif kind == "Charge" then
		local duration = math.clamp(effect.Duration or 2.5, 0.5, 3)
		local pulse = groundPulse(position, 5, COLORS.Chakra, duration)
		local aura = effectPart(position, Vector3.new(3, 5, 3), COLORS.Chakra, duration, Vector3.new(4, 7, 4))
		local owner = type(effect.UserId) == "number" and Players:GetPlayerByUserId(effect.UserId)
		local character = owner and owner.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if aura and owner and root and humanoid then
			local followConnection
			followConnection = RunService.Heartbeat:Connect(function()
				if not aura.Parent then
					followConnection:Disconnect()
					return
				end
				if owner.Character ~= character or not root.Parent or humanoid.Health <= 0
					or root.AssemblyLinearVelocity.Magnitude > 4 or humanoid.MoveDirection.Magnitude > 0.1 then
					aura:Destroy()
					if pulse then pulse:Destroy() end
					followConnection:Disconnect()
				else
					aura.Position = root.Position
				end
			end)
		end
	elseif kind == "Strike" then
		effectPart(effect.Target or position, Vector3.new(1, 1, 1), COLORS.Paper, 0.2, Vector3.new(3, 3, 3))
	elseif kind == "Hit" then
		effectPart(position, Vector3.new(1, 1, 1), COLORS.Orange, 0.18, Vector3.new(2.5, 2.5, 2.5))
	elseif kind == "Defeat" then
		groundPulse(position, 5, COLORS.Orange, 0.4)
	end
end)

local function resize()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local viewport = camera.ViewportSize
	local compact = viewport.X < 760
	local portrait = viewport.X < viewport.Y
	local scale = math.clamp(viewport.X / 1000, 0.58, 1)
	statusScale.Scale = compact and scale or 1
	missionScale.Scale = compact and scale or 1
	status.Position = UDim2.fromOffset(18, 18)
	mission.Position = UDim2.new(1, -18, 0, 18)
	mission.AnchorPoint = Vector2.new(1, 0)
	toastScale.Scale = math.clamp((viewport.X - 32) / 440, 0.55, 1)
	welcomeScale.Scale = math.min(1, (viewport.X - 32) / 516, (viewport.Y - 32) / 448)
	settings.Position = UDim2.new(1, -18, 0, compact and 112 or 171)
	settings.Size = UDim2.fromOffset(compact and 122 or 146, 28)
	sessionLabel.Position = UDim2.new(0.5, 0, 0, compact and 139 or 0)
	sessionLabel.Size = UDim2.new(1, -24, 0, 24)
	sessionLabel.TextSize = compact and 9 or 11
	toast.Position = UDim2.new(0.5, 0, 0, compact and 166 or 220)
	if portrait then
		-- Stack readable cards on portrait phones instead of shrinking both into one row.
		local portraitScale = math.clamp((viewport.X - 36) / 420, 0.6, 0.8)
		statusScale.Scale = portraitScale
		missionScale.Scale = portraitScale
		mission.Position = UDim2.fromOffset(18, 28 + 194 * portraitScale)
		mission.AnchorPoint = Vector2.zero
		settings.Position = UDim2.new(1, -18, 0, 38 + 338 * portraitScale)
		sessionLabel.Position = UDim2.new(0.5, 0, 0, 74 + 338 * portraitScale)
		toast.Position = UDim2.new(0.5, 0, 0, 18 + 194 * portraitScale)
	end
	shiftLock.Button.Position = settings.Position - UDim2.fromOffset(settings.Size.X.Offset + 8, 0)
	shiftLock.Button.Size = UDim2.fromOffset(compact and 108 or 146, 28)
	shiftLock.Button.TextSize = compact and 9 or 10
	if UserInputService.TouchEnabled then
		actionPanel.Size = UDim2.fromOffset(268, 178)
		actionPanel.Position = UDim2.new(1, -18, 1, -145)
		actionPanel.AnchorPoint = Vector2.new(1, 1)
		actionScale.Scale = math.clamp(viewport.Y / 650, 0.65, 1)
		actionLayout.FillDirectionMaxCells = 3
	else
		actionPanel.Size = UDim2.fromOffset(532, 94)
		actionPanel.Position = UDim2.new(0.5, 0, 1, -22)
		actionPanel.AnchorPoint = Vector2.new(0.5, 1)
		actionScale.Scale = math.min(1, (viewport.X - 32) / 532)
		actionLayout.FillDirectionMaxCells = 6
	end
end

local viewportConnection = nil
local function watchCamera()
	if viewportConnection then
		viewportConnection:Disconnect()
	end
	local camera = workspace.CurrentCamera
	if camera then
		viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)
	end
	resize()
end

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
UserInputService.LastInputTypeChanged:Connect(updateControls)
UserInputService.InputBegan:Connect(function(input)
	if introOpen and (input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonA) then
		closeIntro()
	end
end)

local elapsed = 0
RunService.RenderStepped:Connect(function(dt)
	elapsed += dt
	if elapsed < 0.1 then
		return
	end
	elapsed = 0
	local now = workspace:GetServerTimeNow()
	for actionId, controls in pairs(actionButtons) do
		local action = Config.Actions[actionId]
		local locked = not state or state.Level < action.UnlockLevel
		local cooldown = state and state.Cooldowns and state.Cooldowns[actionId] or 0
		local remaining = math.max(0, cooldown - now)
		controls.Overlay.Visible = locked or remaining > 0
		controls.Text.Text = locked and ("LV " .. tostring(action.UnlockLevel)) or string.format("%.1f", remaining)
		controls.Cost.TextColor3 = state and state.Chakra < action.Cost and COLORS.Red or COLORS.Muted
		controls.Outline.Color = locked and COLORS.Border or (actionId == "Rasengan" and COLORS.Chakra or COLORS.Border)
	end
end)

watchCamera()
updateControls()
requestStateRemote:FireServer()
]====] },
{ Destination = "client", ClassName = "ModuleScript", Name = "ShiftLock", Source = [====[
-- A shoulder camera mode that leaves Roblox's camera collision and zoom intact.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local ContextActionService = game:GetService("ContextActionService")

local ShiftLock = {}
ShiftLock.__index = ShiftLock
local currentController = nil
local RENDER_NAME = "ShinobiShiftLockCamera"
local GAMEPAD_ACTION = "ShinobiToggleCameraLock"
local SHOULDER_OFFSET = Vector3.new(1.75, 0.25, 0)

local function instance(className, properties, parent)
	local object = Instance.new(className)
	for key, value in properties do object[key] = value end
	object.Parent = parent
	return object
end

function ShiftLock:_release()
	if not self._active then return end
	self._active = false
	if self._humanoid and self._humanoid.Parent then
		self._humanoid.AutoRotate = self._savedAutoRotate
		self._humanoid.CameraOffset = self._savedOffset
	end
	UserInputService.MouseBehavior = self._savedMouseBehavior
	UserInputService.MouseIconEnabled = self._savedMouseIcon
	self._humanoid = nil
	self._root = nil
	self._reticle.Visible = false
end

function ShiftLock:_blocked(allowAlt)
	return not self._windowFocused or GuiService.MenuIsOpen
		or UserInputService:GetFocusedTextBox() ~= nil
		or (not allowAlt and (UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt)
			or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt)))
		or not self._gui.Enabled or not self._gui.Parent
		or (self._isBlocked and self._isBlocked())
end

function ShiftLock:_parts()
	local character = self._player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	if not humanoid or not root or not root:IsA("BasePart") or humanoid.Health <= 0
		or humanoid.Sit or humanoid.PlatformStand or root.Anchored or not camera
		or camera.CameraType == Enum.CameraType.Scriptable then
		return nil
	end
	local subject = camera.CameraSubject
	if subject and subject ~= humanoid and not subject:IsDescendantOf(character) then return nil end
	return humanoid, root, camera
end

function ShiftLock:_refreshButton()
	local gamepad = string.find(UserInputService:GetLastInputType().Name, "Gamepad") ~= nil
	local prefix = if gamepad then "R3 LOCK" elseif UserInputService.KeyboardEnabled then "SHIFT LOCK" else "CAMERA LOCK"
	local status = if self._active then "ON" elseif self._enabled then "PAUSED" else "OFF"
	local text = prefix .. " / " .. status
	if self.Button.Text ~= text then self.Button.Text = text end
	self.Button.TextColor3 = if self._enabled then Color3.fromRGB(255, 185, 100) else Color3.fromRGB(175, 180, 169)
	self._outline.Color = if self._enabled then Color3.fromRGB(255, 157, 67) else Color3.fromRGB(77, 83, 78)
end

function ShiftLock:_step(dt)
	if self._destroyed then return end
	local humanoid, root, camera
	if self._enabled and not self:_blocked() then
		humanoid, root, camera = self:_parts()
	end
	if not humanoid then
		self:_release()
		self:_refreshButton()
		return
	end
	if self._active and self._humanoid ~= humanoid then self:_release() end
	if not self._active then
		self._humanoid, self._root = humanoid, root
		self._savedAutoRotate = humanoid.AutoRotate
		self._savedOffset = humanoid.CameraOffset
		self._savedMouseBehavior = UserInputService.MouseBehavior
		self._savedMouseIcon = UserInputService.MouseIconEnabled
		self._active = true
	end
	humanoid.AutoRotate = false
	-- CameraOffset lets the standard Roblox camera keep its wall-occlusion handling.
	local firstPerson = (camera.Focus.Position - camera.CFrame.Position).Magnitude < 0.75
	humanoid.CameraOffset = self._savedOffset + (if firstPerson then Vector3.zero else SHOULDER_OFFSET)
	if UserInputService.MouseEnabled then
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		UserInputService.MouseIconEnabled = false
	end
	local look = camera.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	if flatLook.Magnitude > 0.001 then
		local facing = CFrame.lookAt(root.Position, root.Position + flatLook.Unit)
		root.CFrame = root.CFrame:Lerp(facing, 1 - math.exp(-24 * math.min(dt, 0.1)))
	end
	self._reticle.Visible = true
	self:_refreshButton()
end

function ShiftLock:IsActive()
	return not self._destroyed and self._active
end

function ShiftLock:Toggle(fromButton)
	-- Alt frees the cursor specifically so the player can click this button too.
	if self._destroyed or self:_blocked(fromButton == true) then return end
	self._enabled = not self._enabled
	if not self._enabled then self:_release() end
	self:_refreshButton()
	if self._notify then
		local message = if self._enabled then "Camera lock enabled." else "Camera lock disabled."
		if self._enabled and UserInputService.KeyboardEnabled then message = "Shift Lock on. Hold Alt to use menus; Shift turns it off." end
		self._notify(message)
	end
end

function ShiftLock:Destroy()
	if self._destroyed then return end
	self._destroyed = true
	self:_release()
	RunService:UnbindFromRenderStep(RENDER_NAME)
	if self._gamepadBound then ContextActionService:UnbindAction(GAMEPAD_ACTION) end
	for _, connection in self._connections do connection:Disconnect() end
	table.clear(self._connections)
	self._reticleGui:Destroy()
	self.Button:Destroy()
	if currentController == self then currentController = nil end
end

function ShiftLock.Start(options)
	if currentController then currentController:Destroy() end
	local self = setmetatable({}, ShiftLock)
	self._player = Players.LocalPlayer
	self._gui = options.Gui
	self._isBlocked = options.IsBlocked
	self._notify = options.Notify
	self._enabled, self._active, self._destroyed = false, false, false
	self._windowFocused = true
	self._connections = {}
	self.Button = instance("TextButton", {
		Name = "ShiftLockToggle", AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -172, 0, 171), Size = UDim2.fromOffset(146, 28),
		Text = "SHIFT LOCK / OFF", TextColor3 = Color3.fromRGB(175, 180, 169),
		TextSize = 10, Font = Enum.Font.GothamBold,
		BackgroundColor3 = Color3.fromRGB(17, 23, 28), BackgroundTransparency = 0.15,
		BorderSizePixel = 0, AutoButtonColor = true,
	}, options.Gui)
	instance("UICorner", { CornerRadius = UDim.new(0, 8) }, self.Button)
	self._outline = instance("UIStroke", { Color = Color3.fromRGB(77, 83, 78), Transparency = 0.15, Thickness = 1 }, self.Button)
	-- A separate inset-free layer keeps the reticle exactly on ViewportPointToRay's center.
	self._reticleGui = instance("ScreenGui", {
		Name = "ShinobiAimReticle", IgnoreGuiInset = true, ResetOnSpawn = false,
		DisplayOrder = options.Gui.DisplayOrder + 1, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, self._player:WaitForChild("PlayerGui"))
	self._reticle = instance("Frame", {
		Name = "Reticle", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(28, 28), BackgroundTransparency = 1, Visible = false,
	}, self._reticleGui)
	for _, segment in {
		{ 3, 13, 6, 2 }, { 19, 13, 6, 2 }, { 13, 3, 2, 6 }, { 13, 19, 2, 6 },
	} do
		instance("Frame", {
			Position = UDim2.fromOffset(segment[1], segment[2]), Size = UDim2.fromOffset(segment[3], segment[4]),
			BackgroundColor3 = Color3.fromRGB(242, 234, 212), BorderSizePixel = 0,
		}, self._reticle)
	end
	instance("Frame", {
		Position = UDim2.fromOffset(13, 13), Size = UDim2.fromOffset(2, 2),
		BackgroundColor3 = Color3.fromRGB(255, 157, 67), BorderSizePixel = 0,
	}, self._reticle)
	local function connect(signal, callback)
		table.insert(self._connections, signal:Connect(callback))
	end
	connect(self.Button.Activated, function() self:Toggle(true) end)
	connect(UserInputService.InputBegan, function(input, processed)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then self:Toggle() end
	end)
	-- Roblox's default camera also binds R3 to zoom. Own that input while playing
	-- so one press cannot both toggle shoulder mode and jump the zoom distance.
	ContextActionService:BindActionAtPriority(GAMEPAD_ACTION, function(_, inputState)
		if self:_blocked() then return Enum.ContextActionResult.Pass end
		if inputState == Enum.UserInputState.Begin then self:Toggle() end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.ButtonR3)
	self._gamepadBound = true
	connect(UserInputService.WindowFocusReleased, function()
		self._windowFocused = false
		self:_release()
	end)
	connect(UserInputService.WindowFocused, function() self._windowFocused = true end)
	connect(UserInputService.TextBoxFocused, function() self:_release() end)
	connect(GuiService.MenuOpened, function() self:_release() end)
	connect(self._player.CharacterRemoving, function() self:_release() end)
	connect(self._player.CharacterAdded, function() self:_release() end)
	connect(options.Gui.Destroying, function() self:Destroy() end)
	RunService:BindToRenderStep(RENDER_NAME, Enum.RenderPriority.Camera.Value + 1, function(dt) self:_step(dt) end)
	currentController = self
	return self
end

return ShiftLock
]====] },
}

-- Prepare all source containers before enabling the game entry points.
local roots = {}
local destinations = {
    shared = { Name = "Shinobi", Parent = ReplicatedStorage },
    server = { Name = "ShinobiServer", Parent = ServerScriptService },
    client = { Name = "ShinobiClient", Parent = starterScripts },
}
for key, destination in destinations do
    local folder = Instance.new("Folder")
    folder.Name = destination.Name
    folder:SetAttribute("ShinobiInstaller", true)
    folder:SetAttribute("ShinobiVersion", 2)
    roots[key] = folder
end
for _, definition in scripts do
    local object = Instance.new(definition.ClassName)
    object.Name = definition.Name
    object.Source = definition.Source
    object.Parent = roots[definition.Destination]
end
-- Back up the installed scripts and world, including any user edits, before updating.
if #previousRoots > 0 or previousWorld then
    local backupName = "ShinobiBackup_" .. tostring(os.time())
    local suffix = 1
    while ServerStorage:FindFirstChild(backupName) do
        suffix += 1
        backupName = "ShinobiBackup_" .. tostring(os.time()) .. "_" .. suffix
    end
    local previous = Instance.new("Folder")
    previous.Name = backupName
    previous.Parent = ServerStorage
    for _, oldRoot in previousRoots do oldRoot.Parent = previous end
    if previousWorld then previousWorld.Parent = previous end
    print("Your previous Shinobi scripts and village were saved in ServerStorage/" .. backupName)
end
for key, destination in destinations do roots[key].Parent = destination.Parent end

-- Retain the template pieces in ServerStorage so they can be restored if needed.
if #previousRoots == 0 then
    local backup = ServerStorage:FindFirstChild("ShinobiOriginalTemplate")
    if not backup then
        backup = Instance.new("Folder")
        backup.Name = "ShinobiOriginalTemplate"
        backup.Parent = ServerStorage
    end
    local baseplate = workspace:FindFirstChild("Baseplate")
    if baseplate and baseplate:IsA("BasePart") then baseplate.Parent = backup end
    local spawn = workspace:FindFirstChild("SpawnLocation")
    if spawn and spawn:IsA("SpawnLocation") then spawn.Parent = backup end
end

StarterPlayer.CameraMaxZoomDistance = 40
StarterPlayer.CameraMinZoomDistance = 6
StarterPlayer.EnableMouseLockOption = false -- The game's Shift Lock controller owns this toggle.
workspace.Gravity = 196.2
game:GetService("SoundService").RespectFilteringEnabled = true

-- Build the village in Edit mode too, so the installation is immediately visible.
local success, problem = pcall(function()
    require(roots.server.World).Build()
end)
if not success then
    warn("Shinobi scripts installed. Village preview failed: " .. tostring(problem))
    warn("Check Output before playing. The game also creates the world when Play starts.")
else
    print("SHINOBI: EMBER LEGACY v2 installed! Press Play. Left click for a punch/punch/kick combo; Shift toggles shoulder lock.")
end
