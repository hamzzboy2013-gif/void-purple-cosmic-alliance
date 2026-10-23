-- SHINOBI: EMBER LEGACY — ROBLOX STUDIO INSTALLER
-- Open a NEW Baseplate in Studio. Open View > Command Bar.
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
for _, target in {
    { ReplicatedStorage, "Shinobi" },
    { ServerScriptService, "ShinobiServer" },
    { starterScripts, "ShinobiClient" },
    { ServerStorage, "ShinobiOriginalTemplate" },
    { workspace, "ShinobiWorld" },
} do
    assert(not target[1]:FindFirstChild(target[2]), "Shinobi is already installed or its folder name is in use. Open a NEW Baseplate to install another copy.")
end

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
	local forward = directionTo(root, aimPosition, true)
	local origin = root.Position
	if actionId == "Strike" then
		local center = origin + forward * math.min(action.Range, 5)
		self._enemies:DamageInRadius(player, center, action.Radius, action.Damage)
		self:_effect("Strike", origin, center, { Radius = action.Radius, Duration = 0.2 })
	elseif actionId == "Rasengan" then
		local center = origin + forward * math.min(action.Range, 6)
		self._enemies:DamageInRadius(player, center, action.Radius, action.Damage)
		self:_effect("Rasengan", center, nil, { Radius = action.Radius, Duration = 0.65 })
	elseif actionId == "Fireball" then
		local fireOrigin = origin + Vector3.new(0, 1, 0)
		local direction = directionTo(root, aimPosition, false)
		local hit = self._enemies:DamageRay(player, fireOrigin, direction, action.Range, action.Radius, action.Damage)
		self:_effect("Fireball", fireOrigin, hit or fireOrigin + direction * action.Range, {
			Radius = action.Radius,
			Duration = 0.45,
		})
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
	object.CanCollide = false
	object.CanTouch = false
	object.CanQuery = false
	object.CastShadow = true
	object.TopSurface = Enum.SurfaceType.Smooth
	object.BottomSurface = Enum.SurfaceType.Smooth
	object.Parent = model
	return object
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
	local primary = part(model, "HumanoidRootPart", Vector3.new(2, 2, 1) * scale, ZERO, Color3.new())
	primary.Transparency = 1
	local cloth = if dummy then Color3.fromRGB(151, 105, 64)
		elseif boss then Color3.fromRGB(73, 36, 100) else Color3.fromRGB(40, 52, 66)
	local trim = if boss then Color3.fromRGB(255, 104, 72) else Color3.fromRGB(184, 57, 53)
	part(model, "Torso", Vector3.new(2, 2, 1) * scale, ZERO, cloth)
	local head = part(model, "Head", Vector3.new(1.45, 1.3, 1.2) * scale,
		Vector3.new(0, 1.65, 0) * scale, if dummy then cloth else Color3.fromRGB(214, 170, 139))
	part(model, "LeftArm", Vector3.new(0.7, 2, 0.8) * scale,
		Vector3.new(-1.4, 0, 0) * scale, cloth)
	part(model, "RightArm", Vector3.new(0.7, 2, 0.8) * scale,
		Vector3.new(1.4, 0, 0) * scale, cloth)
	part(model, "LeftLeg", Vector3.new(0.85, 2, 0.85) * scale,
		Vector3.new(-0.55, -2, 0) * scale, cloth)
	part(model, "RightLeg", Vector3.new(0.85, 2, 0.85) * scale,
		Vector3.new(0.55, -2, 0) * scale, cloth)
	part(model, "Headband", Vector3.new(1.5, 0.3, 0.1) * scale,
		Vector3.new(0, 1.95, -0.64) * scale, Color3.fromRGB(164, 182, 197), Enum.Material.Metal)
	part(model, "Sash", Vector3.new(2.05, 0.35, 1.05) * scale,
		Vector3.new(0, -0.65, 0) * scale, trim)
	if boss then
		part(model, "Crest", Vector3.new(2.3, 0.25, 1.1) * scale,
			Vector3.new(0, 1, 0) * scale, trim)
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "Humanoid"
	humanoid.MaxHealth = enemy.Settings.Health
	humanoid.Health = enemy.Settings.Health
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
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
	enemy.Model:PivotTo(CFrame.lookAt(enemy.Position, enemy.Position + unit, UP))
end

function EnemyService:_startAttack(enemy, now)
	local radius = enemy.Settings.AttackRange + (if enemy.Kind == "Boss" then 2 else 0.5)
	local duration = if enemy.Kind == "Boss" then 1.05 else 0.7
	enemy.LastAttack = now
	enemy.PendingAttack = { At = now + duration, Center = enemy.Position, Radius = radius }
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
			humanoid:TakeDamage(enemy.Settings.Damage)
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
		oldWorld:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "ShinobiWorld"
	root.Parent = workspace

	local function part(name, size, position, color, material, parent)
		local object = Instance.new("Part")
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

	local function house(x, z, width, depth, title)
		local group = model(title)
		part("Foundation", Vector3.new(width + 3, 1, depth + 3), Vector3.new(x, 0.5, z), COLORS.Stone, Enum.Material.Cobblestone, group)
		part("PlasterWalls", Vector3.new(width, 13, depth), Vector3.new(x, 7.5, z), COLORS.Plaster, Enum.Material.Plaster, group)
		for _, side in ipairs({-1, 1}) do
			part("CornerBeam", Vector3.new(1, 14, 1), Vector3.new(x + side * (width / 2 - 0.4), 8, z + depth / 2), COLORS.Wood, Enum.Material.Wood, group)
			part("CornerBeam", Vector3.new(1, 14, 1), Vector3.new(x + side * (width / 2 - 0.4), 8, z - depth / 2), COLORS.Wood, Enum.Material.Wood, group)
			part("Window", Vector3.new(4, 4, 0.25), Vector3.new(x + side * width / 3, 8, z + depth / 2 + 0.15), Color3.fromRGB(236, 181, 91), Enum.Material.Neon, group)
		end
		part("Door", Vector3.new(4, 7, 0.4), Vector3.new(x, 4.5, z + depth / 2 + 0.25), COLORS.DarkWood, Enum.Material.WoodPlanks, group)
		for tier = 1, 3 do
			part("LayeredRoof", Vector3.new(width + 7 - tier * 3, 1.8, depth + 7 - tier * 3), Vector3.new(x, 14 + tier * 1.6, z), COLORS.Roof, Enum.Material.Slate, group)
		end
		part("RoofRidge", Vector3.new(width * 0.65, 1, 1.8), Vector3.new(x, 19.7, z), COLORS.DarkWood, Enum.Material.Wood, group)
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
	part("TrainingCourtyard", Vector3.new(75, 0.2, 39), Vector3.new(0, 0.1, -67), Color3.fromRGB(179, 160, 123), Enum.Material.Sand)
	part("CampClearing", Vector3.new(92, 0.17, 73), Vector3.new(0, 0.1, -164), Color3.fromRGB(126, 115, 86), Enum.Material.Ground)

	house(-34, 15, 25, 20, "Ramen House")
	house(34, 15, 25, 20, "Ninja Academy")
	house(-35, -20, 27, 21, "Village Archives")
	house(35, -20, 27, 21, "Mission Headquarters")
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
	-- High, impassable valley edges keep players inside the authored play space.
	for _, x in ipairs({-116, 116}) do
		part("ValleyCliff", Vector3.new(12, 43, 390), Vector3.new(x, 17, -130), Color3.fromRGB(103, 113, 103), Enum.Material.Rock)
		part("CliffGrass", Vector3.new(14, 3, 390), Vector3.new(x, 40, -130), COLORS.Leaf, Enum.Material.Grass)
	end
	for _, z in ipairs({63, -323}) do
		part("ValleyEnd", Vector3.new(240, 43, 10), Vector3.new(0, 17, z), Color3.fromRGB(103, 113, 103), Enum.Material.Rock)
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
local welcomeControls = welcomeLabel("WASD to move · Space to jump · Z / X / C jutsu · Q dash · R focus", 400, 28, 10, COLORS.Muted)
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
	if lastInput ~= Enum.UserInputType.Touch and not string.find(lastInput.Name, "Gamepad") then
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
		welcomeControls.Text = "Left stick to move · A to jump · X / Y / B jutsu · LB dash · RB focus"
	elseif UserInputService.TouchEnabled then
		welcomeControls.Text = "Use the movement stick and jump button. Tap the jutsu buttons to fight."
	else
		welcomeControls.Text = "WASD to move · Space to jump · Z / X / C jutsu · Q dash · R focus"
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
    roots[key] = folder
end
for _, definition in scripts do
    local object = Instance.new(definition.ClassName)
    object.Name = definition.Name
    object.Source = definition.Source
    object.Parent = roots[definition.Destination]
end
for key, destination in destinations do
    roots[key].Parent = destination.Parent
end

-- Retain the template pieces in ServerStorage so they can be restored if needed.
local backup = Instance.new("Folder")
backup.Name = "ShinobiOriginalTemplate"
backup.Parent = ServerStorage
local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate and baseplate:IsA("BasePart") then baseplate.Parent = backup end
local spawn = workspace:FindFirstChild("SpawnLocation")
if spawn and spawn:IsA("SpawnLocation") then spawn.Parent = backup end

StarterPlayer.CameraMaxZoomDistance = 40
StarterPlayer.CameraMinZoomDistance = 6
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
    print("SHINOBI: EMBER LEGACY installed! Press Play, dismiss the welcome card, and talk to Sensei.")
end
