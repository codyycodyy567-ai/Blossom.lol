-- Blossom.lol (LocalScript) -> StarterPlayer > StarterPlayerScripts
-- Fully client-side: no RemoteEvents, no server scripts.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local HttpService = game:GetService("HttpService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = Workspace.CurrentCamera

----------------------------------------------------------------
-- SETTINGS (all editable live via _G.Blossom)
----------------------------------------------------------------
local Settings = {
	Enabled = false,
	-- aim
	TargetPart = "Head", Priority = "Crosshair",
	FOV = 150, MaxDistance = 500,
	Smoothness = 0.2, HStrength = 100, VStrength = 100,
	Deadzone = 0, Soften = 30, Prediction = 0,
	BulletSpeed = 0, DropComp = false, SwitchBias = 0, RampIn = 0,
	MouseActiveOnly = true, MoveTimeout = 0.15, MoveThreshold = 1,
	StickyTarget = false, ToggleKey = "None",
	TeamCheck = true, WallCheck = true, IgnoreForceField = true,
	-- visuals
	ShowFOV = true, FOVFill = true, FOVThickness = 2,
	FOVColor = Color3.fromRGB(255, 150, 200), UIScale = 100,
	TargetMarker = true, MarkerSize = 100, MarkerSpin = 35, LockLine = false, LockPulse = false,
	Crosshair = false, CrossSize = 8, CrossGap = 4, CrossSpin = true, CrossSpinRPS = 1000000,
	-- camera + world
	CustomFOV = false, CamFOV = 70, Grade = false, GradeStrength = 50,
	SunRays = false, DreamyDOF = false,
	WorldOrbs = false, OrbCount = 10,
	WorldPetals = false, WorldPetalAmount = 30, Fireflies = false,
	WorldFog = false, FogDistance = 600,
	-- physical 3D FX (around players, client-side)
	PhysEnabled = true, PhysSigil = true, PhysScan = true, PhysAura = true, PhysWire = false,
	PhysTrails = true, PhysSteps = true, PhysGyro = true, PhysTether = false, PhysSonar = false,
	PhysSonarInterval = 6, PhysSonarRange = 120, PhysDistance = 300, PhysMaxPlayers = 8,
	-- ESP (opposing team)
	EnemyESP = false, ESPStyle = "Corners", ESPNames = true, ESPHealth = true, ESPHealthNum = false,
	ESPTool = true, ESPFill = false, ESPTracers = false, ESPHeadDot = true,
	ESPSkeleton = false, ESPChams = false, ESPLook = false, ESPArrows = false,
	ESPFootRing = false, ESPBeacon = false,
	ESPTargetGlow = true, ESPFade = false, ESPVisCheck = false, ESPTeamColor = false,
	ESPMaxDistance = 1000, ESPThickness = 2, ESPCorner = 0.3,
	-- cosmetics (client-side only)
	Cosmetics = false, CosGroup = "Others", HatStyle = "None",
	SeeThrough = false, BodyAlpha = 65, Blossoms = false, BlossomRate = 14,
	OrbitPetals = false, OrbitCount = 6,
	-- menu
	UIFX = true, MenuPetals = true, ScreenPetals = false, PetalAmount = 24, HUDWatermark = true,
	TargetHUD = true, MusicHUD = false, MusicVolume = 50,
}
_G.Blossom = Settings

local function snapshot()
	local out = {}
	for k, v in pairs(Settings) do
		if k ~= "Enabled" then out[k] = (typeof(v) == "Color3") and ("#" .. v:ToHex()) or v end
	end
	return out
end
local DEFAULTS = snapshot()

local MENU_KEY = Enum.KeyCode.RightShift
local VERSION = ""   -- type your version here, e.g. "v1.0"
local PANEL_W, PANEL_H = 1300, 580

-- Music HUD controls: [ = previous, \ = play / pause, ] = next
local MUSIC_KEYS = { Prev = Enum.KeyCode.LeftBracket, Toggle = Enum.KeyCode.BackSlash, Next = Enum.KeyCode.RightBracket }
-- Music HUD playlist. A Roblox client cannot connect to Spotify (no API access), so the HUD plays Roblox
-- audio assets instead. id = the audio asset ID (numbers only) of a track you uploaded / may use in your game.
local PLAYLIST = {
	-- { title = "Track name", artist = "Artist", id = 0 },
}

local COLORS = {}
for _, c in ipairs({
	{ "Blossom", 255, 150, 200 }, { "Mint", 152, 255, 200 }, { "Cyan", 90, 220, 255 }, { "Blue", 90, 160, 255 },
	{ "Purple", 170, 110, 255 }, { "Red", 255, 85, 85 }, { "Orange", 255, 165, 70 },
	{ "Gold", 255, 215, 90 }, { "Lime", 170, 255, 90 }, { "White", 255, 255, 255 },
}) do
	local col = Color3.fromRGB(c[2], c[3], c[4])
	table.insert(COLORS, { name = c[1], color = col, value = col })
end

local PRESETS = {
	{ name = "Legit",    fov = 90,  smooth = 88, h = 70,  v = 50 },
	{ name = "Balanced", fov = 150, smooth = 80, h = 100, v = 100 },
	{ name = "Snappy",   fov = 260, smooth = 30, h = 100, v = 100 },
}

----------------------------------------------------------------
-- Theme + helpers (sharp corners everywhere; round() only for circles)
----------------------------------------------------------------
local BG         = Color3.fromRGB(13, 11, 16)
local CARD       = Color3.fromRGB(27, 24, 33)
local CARD_HOVER = Color3.fromRGB(40, 34, 48)
local STROKE     = Color3.fromRGB(52, 46, 64)
local TEXT       = Color3.fromRGB(244, 240, 248)
local DIM        = Color3.fromRGB(176, 170, 192)
local SUBTEXT    = Color3.fromRGB(145, 137, 160)
local OFF_TRACK  = Color3.fromRGB(60, 54, 74)
local BRACKET    = Color3.fromRGB(125, 122, 136)
local FONT, FONT_MED, FONT_BOLD = Enum.Font.Gotham, Enum.Font.GothamMedium, Enum.Font.GothamBold
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local KP, NKP = ColorSequenceKeypoint.new, NumberSequenceKeypoint.new

local function new(class, props, parent)
	local inst = Instance.new(class)
	for k, v in pairs(props) do inst[k] = v end
	inst.Parent = parent
	return inst
end
local function round(inst, r) return new("UICorner", { CornerRadius = r or UDim.new(1, 0) }, inst) end
local function addStroke(inst)
	return new("UIStroke", { Color = STROKE, Thickness = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, inst)
end
local function padding(inst, l, r, t, b)
	return new("UIPadding", {
		PaddingLeft = UDim.new(0, l or 0), PaddingRight = UDim.new(0, r or 0),
		PaddingTop = UDim.new(0, t or 0), PaddingBottom = UDim.new(0, b or 0),
	}, inst)
end
local function tween(inst, props, time, style, dir)
	local t = TweenService:Create(inst,
		TweenInfo.new(time or 0.15, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end
local function addBrackets(parent, inset, len, thick, z)
	for _, c in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
		for _, horiz in ipairs({ true, false }) do
			new("Frame", {
				AnchorPoint = Vector2.new(c[1], c[2]),
				Position = UDim2.new(c[1], c[1] == 0 and inset or -inset, c[2], c[2] == 0 and inset or -inset),
				Size = horiz and UDim2.fromOffset(len, thick) or UDim2.fromOffset(thick, len),
				BackgroundColor3 = BRACKET, BorderSizePixel = 0, ZIndex = z,
			}, parent)
		end
	end
end
-- draws a 2D line between two screen points using a rotated frame
local function drawLine(f, ax, ay, bx, by, c, t)
	local dx, dy = bx - ax, by - ay
	f.Position = UDim2.fromOffset((ax + bx) / 2, (ay + by) / 2)
	f.Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy), t)
	f.Rotation = math.deg(math.atan2(dy, dx))
	f.BackgroundColor3 = c
end

local accentFns, uiRefresh = {}, {}
local function onAccent(fn) table.insert(accentFns, fn) fn(Settings.FOVColor) end
local function setAccent(c)
	Settings.FOVColor = c
	for _, fn in ipairs(accentFns) do fn(c) end
end

local lockedTarget = nil
local menuOpen, baseScale, fit = true, 1, 1
local masterRefresh = nil
local Actions = {}

----------------------------------------------------------------
-- FOV circle
----------------------------------------------------------------
local circleGui = new("ScreenGui", { Name = "BlossomCircle", ResetOnSpawn = false, IgnoreGuiInset = true }, playerGui)
local circle = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 0.94, BorderSizePixel = 0 }, circleGui)
round(circle)
local circleStroke = new("UIStroke", { Thickness = 2, Transparency = 0.35 }, circle)
onAccent(function(c) circleStroke.Color = c circle.BackgroundColor3 = c end)

local circleLocked = false
local function setCircleLocked(locked)
	if locked == circleLocked then return end
	circleLocked = locked
	tween(circleStroke, { Transparency = locked and 0 or 0.35 }, 0.2)
end

----------------------------------------------------------------
-- Menu shell
----------------------------------------------------------------
local menuGui = new("ScreenGui", { Name = "BlossomMenu", ResetOnSpawn = false, DisplayOrder = 10 }, playerGui)
local modal = new("TextButton", { Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, Text = "", Modal = true }, menuGui)

local root = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(PANEL_W, PANEL_H), BackgroundTransparency = 1,
}, menuGui)
local rootScale = new("UIScale", { Scale = 0.94 }, root)
local panel = new("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = BG, BorderSizePixel = 0, GroupTransparency = 1 }, root)

local wash = new("Frame", { Size = UDim2.new(1, 0, 0, 200), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, panel)
new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0.9, 1) }, wash)
onAccent(function(c) wash.BackgroundColor3 = c end)

local borderFrames, BORDER_T = {}, 2
for _, p in ipairs({
	{ UDim2.fromOffset(0, 0), UDim2.new(1, 0, 0, BORDER_T) }, { UDim2.new(0, 0, 1, -BORDER_T), UDim2.new(1, 0, 0, BORDER_T) },
	{ UDim2.fromOffset(0, 0), UDim2.new(0, BORDER_T, 1, 0) }, { UDim2.new(1, -BORDER_T, 0, 0), UDim2.new(0, BORDER_T, 1, 0) },
}) do
	table.insert(borderFrames, new("Frame", { Position = p[1], Size = p[2], BorderSizePixel = 0, ZIndex = 14 }, panel))
end
onAccent(function(c)
	local col = STROKE:Lerp(c, 0.55)
	for _, f in ipairs(borderFrames) do f.BackgroundColor3 = col end
end)
addBrackets(panel, 7, 10, 1, 15)

local title = new("TextLabel", {
	Position = UDim2.fromOffset(22, 15), Size = UDim2.fromOffset(0, 14), AutomaticSize = Enum.AutomaticSize.X,
	BackgroundTransparency = 1, TextTransparency = 1, RichText = true, Font = FONT_BOLD, TextSize = 12,
	TextColor3 = TEXT, TextXAlignment = Enum.TextXAlignment.Left, Text = "", ZIndex = 20,
}, panel)
onAccent(function(c)
	title.Text = 'Blossom<font color="#' .. c:ToHex() .. '">.lol</font>'
		.. (VERSION ~= "" and ('  <font size="10" color="#918aa0">' .. VERSION .. '</font>') or "")
end)

local function applyScale()
	baseScale = fit * Settings.UIScale / 100
	if menuOpen then rootScale.Scale = baseScale end
end
local function updateFit()
	local vp = camera.ViewportSize
	fit = math.min(1, (vp.X - 40) / PANEL_W, (vp.Y - 40) / PANEL_H)
	applyScale()
end

-- loads a settings table (from a saved slot or an imported code) and refreshes every widget
local function applyData(data)
	local n = 0
	for k, v in pairs(data) do
		local cur = Settings[k]
		if cur ~= nil and k ~= "Enabled" then
			if typeof(cur) == "Color3" then
				if type(v) == "string" then
					local ok, c = pcall(Color3.fromHex, v)
					if ok then setAccent(c) n += 1 end
				end
			elseif type(cur) == type(v) then
				Settings[k] = v
				n += 1
			end
		end
	end
	applyScale()
	for _, fn in ipairs(uiRefresh) do pcall(fn) end
	return n
end

----------------------------------------------------------------
-- Click effects on rows (ripple, press squish, hover bar)
----------------------------------------------------------------
local function ripple(host, x, y)
	local rel = (Vector2.new(x, y) - host.AbsolutePosition) / rootScale.Scale
	local r = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(rel.X, rel.Y), Size = UDim2.fromOffset(0, 0),
		BackgroundColor3 = Settings.FOVColor, BackgroundTransparency = 0.7, BorderSizePixel = 0, ZIndex = 5,
	}, host)
	round(r)
	local m = math.max(host.AbsoluteSize.X, host.AbsoluteSize.Y) / rootScale.Scale * 2.4
	tween(r, { Size = UDim2.fromOffset(m, m), BackgroundTransparency = 1 }, 0.55)
	task.delay(0.6, function() r:Destroy() end)
end

local function attachFX(row, stroke, onClick)
	local scale = new("UIScale", { Scale = 1 }, row)
	local hbar = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0, ZIndex = 6 }, row)
	onAccent(function(c) hbar.BackgroundColor3 = c end)
	local btn = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 10 }, row)
	btn.MouseEnter:Connect(function()
		tween(row, { BackgroundColor3 = CARD_HOVER })
		tween(stroke, { Color = Settings.FOVColor, Transparency = 0.55 })
		tween(hbar, { Size = UDim2.new(0, 3, 1, 0) }, 0.15)
	end)
	btn.MouseLeave:Connect(function()
		tween(row, { BackgroundColor3 = CARD })
		tween(stroke, { Color = STROKE, Transparency = 0 })
		tween(hbar, { Size = UDim2.new(0, 0, 1, 0) }, 0.15)
	end)
	btn.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			tween(scale, { Scale = 0.97 }, 0.08)
			ripple(row, i.Position.X, i.Position.Y)
		end
	end)
	btn.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			tween(scale, { Scale = 1 }, 0.3, Enum.EasingStyle.Back)
		end
	end)
	btn.MouseButton1Click:Connect(onClick)
	return btn
end

local function makeRow(parent, order, height)
	local row = new("Frame", {
		Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = CARD, BorderSizePixel = 0, LayoutOrder = order, ClipsDescendants = true,
	}, parent)
	return row, addStroke(row)
end

----------------------------------------------------------------
-- Header (status) + dragging
----------------------------------------------------------------
local header = new("Frame", { Position = UDim2.fromOffset(22, 22), Size = UDim2.new(1, -44, 0, 36), BackgroundTransparency = 1 }, panel)
new("TextLabel", {
	Size = UDim2.new(0.6, 0, 1, 0), BackgroundTransparency = 1, Text = "Client-side  •  RightShift to hide",
	Font = FONT, TextSize = 12, TextColor3 = SUBTEXT, TextXAlignment = Enum.TextXAlignment.Left,
}, header)

local statusPill = new("Frame", {
	AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(190, 32), BackgroundColor3 = CARD, BorderSizePixel = 0,
}, header)
addStroke(statusPill)
local statusDot = new("Frame", { Position = UDim2.fromOffset(14, 12), Size = UDim2.fromOffset(8, 8), BackgroundColor3 = SUBTEXT, BorderSizePixel = 0 }, statusPill)
local statusLbl = new("TextLabel", {
	Position = UDim2.fromOffset(30, 0), Size = UDim2.new(1, -38, 1, 0), BackgroundTransparency = 1, Text = "Off",
	Font = FONT_MED, TextSize = 12, TextColor3 = SUBTEXT, TextXAlignment = Enum.TextXAlignment.Left,
}, statusPill)
TweenService:Create(statusDot, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundTransparency = 0.6 }):Play()

local statusActive, lastStatus = false, ""
local function paintStatus()
	local c = statusActive and Settings.FOVColor or SUBTEXT
	statusLbl.TextColor3, statusDot.BackgroundColor3 = c, c
end
onAccent(paintStatus)
local function setStatus(text, active)
	if text == lastStatus then return end
	lastStatus, statusActive, statusLbl.Text = text, active, text
	paintStatus()
end

new("Frame", { Position = UDim2.fromOffset(22, 66), Size = UDim2.new(1, -44, 0, 1), BackgroundColor3 = STROKE, BorderSizePixel = 0 }, panel)

local dragStart, startPos
local function makeDraggable(f)
	f.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragStart, startPos = i.Position, root.Position
		end
	end)
end
makeDraggable(header)
makeDraggable(title)
UIS.InputChanged:Connect(function(i)
	if dragStart and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
		local d = i.Position - dragStart
		root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
	end
end)
UIS.InputEnded:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragStart = nil end
end)

do
----------------------------------------------------------------
-- Components
----------------------------------------------------------------
local function makeSection(parent, order, text)
	local f = new("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = order }, parent)
	local dot = new("Frame", { Position = UDim2.fromOffset(8, 9), Size = UDim2.fromOffset(4, 4), BorderSizePixel = 0 }, f)
	onAccent(function(c) dot.BackgroundColor3 = c end)
	local w = math.ceil(TextService:GetTextSize(text, 11, FONT_BOLD, Vector2.new(400, 20)).X)
	new("TextLabel", {
		Position = UDim2.fromOffset(20, 0), Size = UDim2.fromOffset(w + 2, 22), BackgroundTransparency = 1, Text = text,
		Font = FONT_BOLD, TextSize = 11, TextColor3 = SUBTEXT, TextXAlignment = Enum.TextXAlignment.Left,
	}, f)
	new("Frame", { Position = UDim2.new(0, 30 + w, 0.5, 0), Size = UDim2.new(1, -(30 + w), 0, 1), BackgroundColor3 = STROKE, BorderSizePixel = 0 }, f)
end

local function makeSwitch(parent, getState)
	local track = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(38, 20),
		BackgroundColor3 = OFF_TRACK, BorderSizePixel = 0,
	}, parent)
	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0), Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
	}, track)
	local function refresh(animate)
		local on = getState()
		local pos = on and UDim2.new(0, 21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
		local col = on and Settings.FOVColor or OFF_TRACK
		if animate then
			tween(knob, { Position = pos }, 0.22, Enum.EasingStyle.Back)
			tween(track, { BackgroundColor3 = col })
		else
			knob.Position, track.BackgroundColor3 = pos, col
		end
	end
	onAccent(function() refresh(false) end)
	return refresh
end

local function makeToggle(parent, order, text, key)
	local row, st = makeRow(parent, order, 40)
	local lbl = new("TextLabel", {
		Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -72, 1, 0), BackgroundTransparency = 1, Text = text,
		Font = FONT_MED, TextSize = 13, TextColor3 = TEXT, TextXAlignment = Enum.TextXAlignment.Left,
	}, row)
	local refresh = makeSwitch(row, function() return Settings[key] end)
	lbl.TextColor3 = Settings[key] and TEXT or DIM
	table.insert(uiRefresh, function() refresh(false) lbl.TextColor3 = Settings[key] and TEXT or DIM end)
	attachFX(row, st, function()
		Settings[key] = not Settings[key]
		refresh(true)
		tween(lbl, { TextColor3 = Settings[key] and TEXT or DIM }, 0.15)
	end)
end

local function makeSlider(parent, order, text, suffix, min, max, initial, onChange)
	local row = new("Frame", { Size = UDim2.new(1, 0, 0, 58), BackgroundColor3 = CARD, BorderSizePixel = 0, LayoutOrder = order }, parent)
	local st = addStroke(row)
	new("TextLabel", {
		Position = UDim2.fromOffset(16, 8), Size = UDim2.new(0.62, -16, 0, 18), BackgroundTransparency = 1, Text = text,
		Font = FONT_MED, TextSize = 13, TextColor3 = TEXT, TextXAlignment = Enum.TextXAlignment.Left,
	}, row)
	local valueLbl = new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 8), Size = UDim2.new(0.38, -16, 0, 18),
		BackgroundTransparency = 1, Text = "", Font = FONT_MED, TextSize = 13, TextColor3 = SUBTEXT, TextXAlignment = Enum.TextXAlignment.Right,
	}, row)
	local hit = new("Frame", { Position = UDim2.fromOffset(16, 32), Size = UDim2.new(1, -32, 0, 20), BackgroundTransparency = 1 }, row)
	local track = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0, 4),
		BackgroundColor3 = OFF_TRACK, BorderSizePixel = 0,
	}, hit)
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Settings.FOVColor, BorderSizePixel = 0 }, track)
	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(8, 16),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
	}, track)
	onAccent(function(c) fill.BackgroundColor3 = c end)

	local function set(v)
		v = math.clamp(math.floor(v + 0.5), min, max)
		local a = (v - min) / (max - min)
		fill.Size = UDim2.fromScale(a, 1)
		knob.Position = UDim2.new(a, 0, 0.5, 0)
		valueLbl.Text = v .. suffix
		onChange(v)
	end

	local drag = false
	local function fromX(x)
		set(min + (max - min) * math.clamp((x - hit.AbsolutePosition.X) / hit.AbsoluteSize.X, 0, 1))
	end
	hit.MouseEnter:Connect(function() tween(st, { Color = Settings.FOVColor, Transparency = 0.55 }) end)
	hit.MouseLeave:Connect(function() if not drag then tween(st, { Color = STROKE, Transparency = 0 }) end end)
	hit.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			drag, dragStart = true, nil
			tween(knob, { Size = UDim2.fromOffset(10, 20) }, 0.1)
			fromX(i.Position.X)
		end
	end)
	UIS.InputChanged:Connect(function(i)
		if drag and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			fromX(i.Position.X)
		end
	end)
	UIS.InputEnded:Connect(function(i)
		if drag and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
			drag = false
			tween(knob, { Size = UDim2.fromOffset(8, 16) }, 0.1)
			tween(st, { Color = STROKE, Transparency = 0 })
		end
	end)
	set(initial)
	return set
end

local function makeDropdown(parent, order, labelText, items, initialIndex, onSelect)
	local hasColor = items[1].color ~= nil
	local holder = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order }, parent)
	new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, holder)

	local head, headStroke = makeRow(holder, 1, 40)
	new("TextLabel", {
		Position = UDim2.fromOffset(16, 0), Size = UDim2.new(0.4, 0, 1, 0), BackgroundTransparency = 1, Text = labelText,
		Font = FONT_MED, TextSize = 13, TextColor3 = TEXT, TextXAlignment = Enum.TextXAlignment.Left,
	}, head)
	local chev = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(14, 14), BackgroundTransparency = 1 }, head)
	for _, side in ipairs({ -1, 1 }) do
		new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5 + side * -0.18, 0, 0.5, 0), Size = UDim2.fromOffset(8, 2),
			Rotation = side * -45, BackgroundColor3 = SUBTEXT, BorderSizePixel = 0,
		}, chev)
	end
	local valueLbl = new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, hasColor and -54 or -38, 0.5, 0), Size = UDim2.new(0.6, -40, 1, 0),
		BackgroundTransparency = 1, Text = "", Font = FONT, TextSize = 12, TextColor3 = SUBTEXT, TextXAlignment = Enum.TextXAlignment.Right,
	}, head)
	local headDot
	if hasColor then
		headDot = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -38, 0.5, 0), Size = UDim2.fromOffset(12, 12), BorderSizePixel = 0 }, head)
	end

	local list = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Visible = false, LayoutOrder = 2 }, holder)
	new("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	padding(list, 10, 10, 0, 0)

	local selected, labels = initialIndex, {}
	local function refresh()
		local it = items[selected]
		valueLbl.Text = it.name
		if headDot then headDot.BackgroundColor3 = it.color end
		for i, l in ipairs(labels) do l.TextColor3 = (i == selected) and Settings.FOVColor or TEXT end
	end
	local function setOpen(o)
		list.Visible = o
		tween(chev, { Rotation = o and 180 or 0 }, 0.2)
	end

	for i, it in ipairs(items) do
		local r, rs = makeRow(list, i, 32)
		labels[i] = new("TextLabel", {
			Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -44, 1, 0), BackgroundTransparency = 1, Text = it.name,
			Font = FONT_MED, TextSize = 12, TextColor3 = TEXT, TextXAlignment = Enum.TextXAlignment.Left,
		}, r)
		if it.color then
			new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = it.color, BorderSizePixel = 0 }, r)
		end
		attachFX(r, rs, function()
			selected = i
			refresh()
			setOpen(false)
			onSelect(it)
		end)
	end
	attachFX(head, headStroke, function() setOpen(not list.Visible) end)
	onAccent(refresh)
	return function(i) selected = i refresh() end
end

----------------------------------------------------------------
-- Config manager: session slots + export / import codes
-- (Roblox LocalScripts can't write files, so configs live in _G for the session
--  and can be copied out as a code string to keep forever.)
----------------------------------------------------------------
_G.BlossomConfigs = _G.BlossomConfigs or {}
local configs = _G.BlossomConfigs

local function makeConfigUI(parent, order)
	local box = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order }, parent)
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, box)

	local selSlot, slotRows, nameBox, codeBox = 1, {}, nil, nil
	local status = new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Text = "Pick a slot, name it, press Save.", Font = FONT,
		TextSize = 11, TextColor3 = SUBTEXT, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 99,
	}, box)
	padding(status, 8, 0, 0, 0)
	local function say(t) status.Text = t end

	local function refreshSlots()
		for i, s in ipairs(slotRows) do
			local c = configs[i]
			s.lbl.Text = i .. "    " .. (c and c.name or "empty")
			s.lbl.TextColor3 = (i == selSlot) and Settings.FOVColor or (c and TEXT or DIM)
			s.bar.BackgroundColor3 = Settings.FOVColor
			s.bar.Size = UDim2.new(0, i == selSlot and 3 or 0, 1, 0)
		end
	end

	makeSection(box, 1, "SESSION SLOTS")
	for i = 1, 6 do
		local r, rs = makeRow(box, i + 1, 34)
		local bar = new("Frame", { Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0, ZIndex = 7 }, r)
		local lbl = new("TextLabel", {
			Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -24, 1, 0), BackgroundTransparency = 1, Text = "",
			Font = FONT_MED, TextSize = 12, TextColor3 = TEXT, TextXAlignment = Enum.TextXAlignment.Left,
		}, r)
		slotRows[i] = { lbl = lbl, bar = bar }
		attachFX(r, rs, function()
			selSlot = i
			if configs[i] then nameBox.Text = configs[i].name end
			refreshSlots()
		end)
	end

	local nrow = makeRow(box, 8, 38)
	nameBox = new("TextBox", {
		Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -28, 1, 0), BackgroundTransparency = 1, Text = "",
		PlaceholderText = "config name...", PlaceholderColor3 = SUBTEXT, TextColor3 = TEXT, Font = FONT_MED, TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false,
	}, nrow)

	local function buttons(ord, defs)
		local f = new("Frame", { Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1, LayoutOrder = ord }, box)
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, f)
		for i, d in ipairs(defs) do
			local b, bs = makeRow(f, i, 36)
			b.Size = UDim2.new(1 / #defs, -4, 1, 0)
			new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = d[1], Font = FONT_MED, TextSize = 12, TextColor3 = TEXT }, b)
			attachFX(b, bs, d[2])
		end
	end

	buttons(9, {
		{ "Save", function()
			local nm = nameBox.Text ~= "" and nameBox.Text or ("Config " .. selSlot)
			configs[selSlot] = { name = nm, data = snapshot() }
			refreshSlots() say("Saved to slot " .. selSlot)
		end },
		{ "Load", function()
			local c = configs[selSlot]
			if c then say("Loaded " .. applyData(c.data) .. " settings") else say("That slot is empty") end
		end },
		{ "Clear", function() configs[selSlot] = nil refreshSlots() say("Cleared slot " .. selSlot) end },
	})

	makeSection(box, 10, "SHARE / BACKUP")
	local crow = makeRow(box, 11, 96)
	codeBox = new("TextBox", {
		Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 1, -16), BackgroundTransparency = 1, Text = "",
		PlaceholderText = "Export fills this box. To import, paste a code here and press Import.", PlaceholderColor3 = SUBTEXT,
		TextColor3 = DIM, Font = FONT, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true, MultiLine = true, ClearTextOnFocus = false,
	}, crow)

	buttons(12, {
		{ "Export", function()
			local ok, s = pcall(function() return HttpService:JSONEncode(snapshot()) end)
			if ok then codeBox.Text = s say("Exported. Click the box, Ctrl+A, Ctrl+C to copy.") else say("Export failed") end
		end },
		{ "Import", function()
			local ok, data = pcall(function() return HttpService:JSONDecode(codeBox.Text) end)
			if ok and type(data) == "table" then say("Imported " .. applyData(data) .. " settings") else say("Invalid code") end
		end },
		{ "Defaults", function() say("Reset " .. applyData(DEFAULTS) .. " settings") end },
	})

	onAccent(refreshSlots)
end

----------------------------------------------------------------
-- Columns (everything on one screen)
----------------------------------------------------------------
local setters = {}

local function makePresets(parent, order)
	local f = new("Frame", { Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1, LayoutOrder = order }, parent)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, f)
	for i, p in ipairs(PRESETS) do
		local b, bs = makeRow(f, i, 38)
		b.Size = UDim2.new(1 / 3, -4, 1, 0)
		new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = p.name, Font = FONT_MED, TextSize = 12, TextColor3 = TEXT }, b)
		attachFX(b, bs, function()
			setters.FOV(p.fov) setters.Smoothing(p.smooth) setters.HStrength(p.h) setters.VStrength(p.v)
		end)
	end
end

local function makeActions(parent, order, defs)
	local f = new("Frame", { Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1, LayoutOrder = order }, parent)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, f)
	for i, d in ipairs(defs) do
		local b, bs = makeRow(f, i, 38)
		b.Size = UDim2.new(1 / #defs, -4, 1, 0)
		new("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = d.name, Font = FONT_MED, TextSize = 12, TextColor3 = TEXT }, b)
		attachFX(b, bs, function() if d.fn then d.fn() end end)
	end
end

local function build(parent, items)
	for i, it in ipairs(items) do
		if it.t == "section" then makeSection(parent, i, it.text)
		elseif it.t == "toggle" then makeToggle(parent, i, it.text, it.key)
		elseif it.t == "presets" then makePresets(parent, i)
		elseif it.t == "actions" then makeActions(parent, i, it.defs)
		elseif it.t == "config" then makeConfigUI(parent, i)
		elseif it.t == "slider" then
			local scale = it.scale or 1
			local get = it.get or function() return Settings[it.key] / scale end
			local set = it.set or function(v) Settings[it.key] = v * scale end
			local fn = makeSlider(parent, i, it.text, it.suffix or "", it.min, it.max, get(), set)
			setters[it.id or it.key] = fn
			table.insert(uiRefresh, function() fn(get()) end)
		elseif it.t == "drop" then
			local idx = 1
			for n, d in ipairs(it.items) do if d.value == Settings[it.key] then idx = n end end
			local setIdx = makeDropdown(parent, i, it.text, it.items, idx, function(d)
				if it.set then it.set(d.value) else Settings[it.key] = d.value end
			end)
			table.insert(uiRefresh, function()
				local found = 1
				for n, d in ipairs(it.items) do if d.value == Settings[it.key] then found = n end end
				setIdx(found)
			end)
		end
	end
end

local function opts(...) -- builds a dropdown item list from plain strings
	local t = {}
	for _, n in ipairs({ ... }) do table.insert(t, { name = n, value = n }) end
	return t
end

local COLUMNS = {
	{ title = "Aim assist", master = "Enabled", items = {
		{ t = "presets" },
		{ t = "section", text = "TARGETING" },
		{ t = "slider", text = "FOV size", key = "FOV", min = 20, max = 500, suffix = "px" },
		{ t = "slider", text = "Max distance", key = "MaxDistance", min = 50, max = 2000, suffix = " studs" },
		{ t = "drop", text = "Target part", key = "TargetPart", items = {
			{ name = "Head", value = "Head" }, { name = "Upper torso", value = "UpperTorso" }, { name = "Torso (R6)", value = "Torso" },
			{ name = "Root part", value = "HumanoidRootPart" }, { name = "Auto (closest)", value = "Auto" } } },
		{ t = "drop", text = "Priority", key = "Priority", items = {
			{ name = "Crosshair", value = "Crosshair" }, { name = "Distance", value = "Distance" }, { name = "Lowest health", value = "Health" } } },
		{ t = "toggle", text = "Sticky aim", key = "StickyTarget" },
		{ t = "slider", text = "Switch resistance", key = "SwitchBias", min = 0, max = 60, suffix = "%" },
		{ t = "section", text = "MOTION" },
		{ t = "slider", id = "Smoothing", text = "Smoothing", min = 0, max = 100,
			get = function() return math.floor((1 - Settings.Smoothness) * 100 + 0.5) end,
			set = function(v) Settings.Smoothness = math.max(0.02, 1 - v / 100) end },
		{ t = "slider", text = "Horizontal strength", key = "HStrength", min = 0, max = 100, suffix = "%" },
		{ t = "slider", text = "Vertical strength", key = "VStrength", min = 0, max = 100, suffix = "%" },
		{ t = "slider", text = "Close-range softening", key = "Soften", min = 0, max = 100, suffix = "%" },
		{ t = "slider", text = "Deadzone", key = "Deadzone", min = 0, max = 10, suffix = "°" },
		{ t = "slider", text = "Prediction", key = "Prediction", scale = 0.001, min = 0, max = 250, suffix = " ms" },
		{ t = "slider", text = "Projectile speed (lead)", key = "BulletSpeed", min = 0, max = 2000, suffix = " st/s" },
		{ t = "toggle", text = "Projectile drop compensation", key = "DropComp" },
		{ t = "slider", text = "Ease-in after lock", key = "RampIn", min = 0, max = 1000, suffix = " ms" },
		{ t = "section", text = "ACTIVATION" },
		{ t = "toggle", text = "Only while mouse moves", key = "MouseActiveOnly" },
		{ t = "drop", text = "Aim toggle key", key = "ToggleKey", items = opts("None", "X", "V", "B", "Z", "Q", "E", "F", "G", "H") },
		{ t = "section", text = "FILTERS" },
		{ t = "toggle", text = "Team check", key = "TeamCheck" },
		{ t = "toggle", text = "Wall check (aims visible part)", key = "WallCheck" },
		{ t = "toggle", text = "Ignore forcefields", key = "IgnoreForceField" },
	} },
	{ title = "Enemy ESP", master = "EnemyESP", items = {
		{ t = "section", text = "BOX" },
		{ t = "drop", text = "Box style", key = "ESPStyle", items = { { name = "Corners", value = "Corners" }, { name = "Full box", value = "Full" } } },
		{ t = "slider", text = "Corner length", key = "ESPCorner", scale = 0.01, min = 10, max = 50, suffix = "%" },
		{ t = "slider", text = "Thickness", key = "ESPThickness", min = 1, max = 4, suffix = "px" },
		{ t = "toggle", text = "Box fill", key = "ESPFill" },
		{ t = "toggle", text = "Use team colors", key = "ESPTeamColor" },
		{ t = "toggle", text = "Dim behind walls", key = "ESPVisCheck" },
		{ t = "toggle", text = "Brighten aimed target", key = "ESPTargetGlow" },
		{ t = "toggle", text = "Fade with distance", key = "ESPFade" },
		{ t = "section", text = "INFO" },
		{ t = "toggle", text = "Name + distance", key = "ESPNames" },
		{ t = "toggle", text = "Health bar", key = "ESPHealth" },
		{ t = "toggle", text = "Health number", key = "ESPHealthNum" },
		{ t = "toggle", text = "Held item", key = "ESPTool" },
		{ t = "toggle", text = "Head dot", key = "ESPHeadDot" },
		{ t = "section", text = "EXTRA ESP" },
		{ t = "toggle", text = "Skeleton", key = "ESPSkeleton" },
		{ t = "toggle", text = "Glow fill (chams)", key = "ESPChams" },
		{ t = "toggle", text = "Look direction", key = "ESPLook" },
		{ t = "toggle", text = "Off-screen arrows", key = "ESPArrows" },
		{ t = "toggle", text = "Tracers", key = "ESPTracers" },
		{ t = "section", text = "3D ESP" },
		{ t = "toggle", text = "Pulsing foot ring", key = "ESPFootRing" },
		{ t = "toggle", text = "Light beacon", key = "ESPBeacon" },
		{ t = "slider", text = "Max distance", key = "ESPMaxDistance", min = 100, max = 3000, suffix = " studs" },
	} },
	{ title = "Visuals", items = {
		{ t = "section", text = "TARGET MARKER" },
		{ t = "toggle", text = "Show lock-on marker", key = "TargetMarker" },
		{ t = "slider", text = "Marker size", key = "MarkerSize", min = 50, max = 150, suffix = "%" },
		{ t = "slider", text = "Spin speed", key = "MarkerSpin", min = 0, max = 200, suffix = "°/s" },
		{ t = "toggle", text = "Lock line to target", key = "LockLine" },
		{ t = "toggle", text = "Lock-on shockwave (3D)", key = "LockPulse" },
		{ t = "section", text = "FOV CIRCLE" },
		{ t = "toggle", text = "Show FOV circle", key = "ShowFOV" },
		{ t = "toggle", text = "Circle fill", key = "FOVFill" },
		{ t = "slider", text = "Circle thickness", key = "FOVThickness", min = 1, max = 6, suffix = "px" },
		{ t = "section", text = "CROSSHAIR" },
		{ t = "toggle", text = "Custom crosshair", key = "Crosshair" },
		{ t = "slider", text = "Crosshair size", key = "CrossSize", min = 3, max = 24, suffix = "px" },
		{ t = "slider", text = "Crosshair gap", key = "CrossGap", min = 0, max = 20, suffix = "px" },
		{ t = "toggle", text = "Spin crosshair on lock", key = "CrossSpin" },
		{ t = "slider", text = "Lock spin speed", key = "CrossSpinRPS", min = 0, max = 1000000, suffix = " rot/s" },
		{ t = "section", text = "SCREEN" },
		{ t = "toggle", text = "Custom camera FOV", key = "CustomFOV" },
		{ t = "slider", text = "Camera FOV", key = "CamFOV", min = 40, max = 120, suffix = "°" },
		{ t = "toggle", text = "Blossom color grade + bloom", key = "Grade" },
		{ t = "slider", text = "Grade strength", key = "GradeStrength", min = 0, max = 100, suffix = "%" },
	} },
	{ title = "World", items = {
		{ t = "section", text = "WORLD EFFECTS" },
		{ t = "toggle", text = "Sun rays", key = "SunRays" },
		{ t = "toggle", text = "Dreamy depth of field", key = "DreamyDOF" },
		{ t = "section", text = "WORLD OBJECTS (3D)" },
		{ t = "toggle", text = "Floating lanterns", key = "WorldOrbs" },
		{ t = "slider", text = "Lantern count", key = "OrbCount", min = 3, max = 24 },
		{ t = "section", text = "PHYSICAL VISUALS (3D)" },
		{ t = "toggle", text = "Enable physical visuals", key = "PhysEnabled" },
		{ t = "toggle", text = "Ground sigil", key = "PhysSigil" },
		{ t = "toggle", text = "Scanner rings", key = "PhysScan" },
		{ t = "toggle", text = "Energy aura + glow", key = "PhysAura" },
		{ t = "toggle", text = "Wireframe body", key = "PhysWire" },
		{ t = "toggle", text = "Motion trails", key = "PhysTrails" },
		{ t = "toggle", text = "Footstep shockwaves", key = "PhysSteps" },
		{ t = "toggle", text = "Lock-on gyroscope", key = "PhysGyro" },
		{ t = "toggle", text = "Lock-on tether beam", key = "PhysTether" },
		{ t = "toggle", text = "Sonar pulse", key = "PhysSonar" },
		{ t = "slider", text = "Sonar interval", key = "PhysSonarInterval", min = 3, max = 20, suffix = " s" },
		{ t = "slider", text = "Sonar range", key = "PhysSonarRange", min = 40, max = 300, suffix = " studs" },
		{ t = "slider", text = "Effect distance", key = "PhysDistance", min = 50, max = 800, suffix = " studs" },
		{ t = "slider", text = "Max players with effects", key = "PhysMaxPlayers", min = 1, max = 16 },
		{ t = "section", text = "WORLD PARTICLES" },
		{ t = "toggle", text = "Falling blossoms", key = "WorldPetals" },
		{ t = "slider", text = "Blossom amount", key = "WorldPetalAmount", min = 5, max = 120 },
		{ t = "toggle", text = "Fireflies", key = "Fireflies" },
		{ t = "section", text = "FOG" },
		{ t = "toggle", text = "World fog", key = "WorldFog" },
		{ t = "slider", text = "Fog distance", key = "FogDistance", min = 150, max = 1500, suffix = " studs" },
	} },
	{ title = "Cosmetics + config", master = "Cosmetics", items = {
		{ t = "section", text = "AVATAR (CLIENT-SIDE ONLY)" },
		{ t = "drop", text = "Apply to", key = "CosGroup", items = {
			{ name = "Everyone else", value = "Others" }, { name = "Enemies", value = "Enemies" },
			{ name = "Teammates", value = "Teammates" }, { name = "Everyone (incl. me)", value = "Everyone" } } },
		{ t = "drop", text = "Hat", key = "HatStyle", items = {
			{ name = "None", value = "None" }, { name = "Cone hat (hologram)", value = "Cone hat" }, { name = "China hat (hologram)", value = "China hat" } } },
		{ t = "toggle", text = "See-through body", key = "SeeThrough" },
		{ t = "slider", text = "Body transparency", key = "BodyAlpha", min = 10, max = 95, suffix = "%" },
		{ t = "toggle", text = "Blossoms shooting out", key = "Blossoms" },
		{ t = "slider", text = "Blossom rate", key = "BlossomRate", min = 2, max = 40 },
		{ t = "toggle", text = "Orbiting blossoms (3D trails)", key = "OrbitPetals" },
		{ t = "slider", text = "Orbit count", key = "OrbitCount", min = 3, max = 12 },
		{ t = "section", text = "CONFIGS" },
		{ t = "config" },
		{ t = "section", text = "MENU" },
		{ t = "toggle", text = "Click + cursor effects", key = "UIFX" },
		{ t = "toggle", text = "Watermark HUD", key = "HUDWatermark" },
		{ t = "toggle", text = "Target HUD", key = "TargetHUD" },
		{ t = "toggle", text = "Music HUD", key = "MusicHUD" },
		{ t = "slider", text = "Music volume", key = "MusicVolume", min = 0, max = 100, suffix = "%" },
		{ t = "actions", defs = {
			{ name = "Prev", fn = function() if Actions.MusicPrev then Actions.MusicPrev() end end },
			{ name = "Play / Pause", fn = function() if Actions.MusicToggle then Actions.MusicToggle() end end },
			{ name = "Next", fn = function() if Actions.MusicNext then Actions.MusicNext() end end },
		} },
		{ t = "toggle", text = "Menu blossoms", key = "MenuPetals" },
		{ t = "toggle", text = "Screen blossoms", key = "ScreenPetals" },
		{ t = "slider", text = "Blossom amount (menu/screen)", key = "PetalAmount", min = 4, max = 60 },
		{ t = "section", text = "THEME" },
		{ t = "drop", text = "Accent color", key = "FOVColor", items = COLORS, set = setAccent },
		{ t = "slider", text = "Menu scale", key = "UIScale", min = 70, max = 130, suffix = "%",
			set = function(v) Settings.UIScale = v applyScale() end },
	} },
}

local body = new("Frame", { Position = UDim2.fromOffset(22, 78), Size = UDim2.new(1, -44, 1, -100), BackgroundTransparency = 1 }, panel)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }, body)

for ci, colDef in ipairs(COLUMNS) do
	local col = new("Frame", { Size = UDim2.new(0.2, -10, 1, 0), BackgroundTransparency = 1, LayoutOrder = ci }, body)
	local hrow, hst = makeRow(col, 1, 42)
	local bar = new("Frame", { Size = UDim2.new(0, 3, 1, 0), BorderSizePixel = 0 }, hrow)
	onAccent(function(c) bar.BackgroundColor3 = c end)
	new("TextLabel", {
		Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -72, 1, 0), BackgroundTransparency = 1, Text = colDef.title,
		Font = FONT_BOLD, TextSize = 14, TextColor3 = TEXT, TextXAlignment = Enum.TextXAlignment.Left,
	}, hrow)
	if colDef.master then
		local key = colDef.master
		local refresh = makeSwitch(hrow, function() return Settings[key] end)
		if key == "Enabled" then masterRefresh = refresh end
		table.insert(uiRefresh, function() refresh(false) end)
		attachFX(hrow, hst, function()
			Settings[key] = not Settings[key]
			refresh(true)
		end)
	end
	local scroll = new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 1, -52), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 3, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y, ClipsDescendants = true,
	}, col)
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)
	padding(scroll, 0, 8, 2, 14)
	onAccent(function(c) scroll.ScrollBarImageColor3 = c end)
	build(scroll, colDef.items)
end

end

----------------------------------------------------------------
-- Falling blossoms (menu + optional full screen)
----------------------------------------------------------------
local PETAL_COLORS = { rgb(255, 183, 213), rgb(255, 150, 200), rgb(255, 214, 230), rgb(245, 120, 170) }
local function makePetals(parent, max, transp)
	local pool = {}
	for i = 1, max do
		local w = math.random(7, 12)
		local f = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(w, math.floor(w * 1.4)),
			BackgroundColor3 = PETAL_COLORS[math.random(#PETAL_COLORS)], BackgroundTransparency = transp, BorderSizePixel = 0, Visible = false,
		}, parent)
		round(f, UDim.new(0.5, 0))
		pool[i] = {
			f = f, ready = false, x = 0, y = 0, vy = math.random(28, 60), sway = math.random(8, 22) / 10,
			amp = math.random(14, 34), phase = math.random() * 6.28, rot = math.random(0, 360), vr = math.random(-90, 90),
		}
	end
	return pool
end
local function stepPetals(pool, count, dt, t, W, H)
	for i, p in ipairs(pool) do
		if i <= count then
			if not p.ready then p.x, p.y, p.ready = math.random() * W, math.random() * H, true end
			p.y += p.vy * dt
			p.rot += p.vr * dt
			if p.y > H + 20 then p.y, p.x = -20, math.random() * W end
			p.f.Visible = true
			p.f.Rotation = p.rot
			p.f.Position = UDim2.fromOffset(p.x + math.sin(t * p.sway + p.phase) * p.amp, p.y)
		else
			p.f.Visible = false
		end
	end
end

local menuPool = makePetals(new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, panel), 30, 0.35)
local screenGui = new("ScreenGui", { Name = "BlossomPetals", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 2 }, playerGui)
local screenPool = makePetals(new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, screenGui), 60, 0.25)

----------------------------------------------------------------
-- Menu cursor + click effects
----------------------------------------------------------------
local fxLayer = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 30 }, panel)
local glowOuter = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(170, 170), BackgroundTransparency = 0.95, BorderSizePixel = 0, ZIndex = 30, Visible = false }, fxLayer)
round(glowOuter)
local glowInner = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(80, 80), BackgroundTransparency = 0.9, BorderSizePixel = 0, ZIndex = 30, Visible = false }, fxLayer)
round(glowInner)
onAccent(function(c) glowOuter.BackgroundColor3, glowInner.BackgroundColor3 = c, c end)

local function insidePanel(p)
	local rel = Vector2.new(p.X, p.Y) - panel.AbsolutePosition
	local sz = panel.AbsoluteSize
	return rel.X >= 0 and rel.Y >= 0 and rel.X <= sz.X and rel.Y <= sz.Y
end
local function localPos(p) return (Vector2.new(p.X, p.Y) - panel.AbsolutePosition) / rootScale.Scale end

local function sparks(x, y, count, dist)
	for _ = 1, count do
		local s = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(4, 4),
			BackgroundColor3 = Settings.FOVColor, BorderSizePixel = 0, ZIndex = 31, Rotation = math.random(0, 90),
		}, fxLayer)
		local a, d = math.random() * math.pi * 2, dist * (0.5 + math.random())
		tween(s, {
			Position = UDim2.fromOffset(x + math.cos(a) * d, y + math.sin(a) * d),
			BackgroundTransparency = 1, Size = UDim2.fromOffset(1, 1),
		}, 0.45 + math.random() * 0.3)
		task.delay(0.9, function() s:Destroy() end)
	end
end

local function clickBurst(x, y)
	local r = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, ZIndex = 31 }, fxLayer)
	round(r)
	local st = new("UIStroke", { Color = Settings.FOVColor, Thickness = 2 }, r)
	tween(r, { Size = UDim2.fromOffset(74, 74) }, 0.45)
	tween(st, { Transparency = 1 }, 0.45)
	sparks(x, y, 7, 36)
	task.delay(0.5, function() r:Destroy() end)
end

local cursorTarget, cursorPos, lastSpark = nil, Vector2.zero, Vector2.zero
UIS.InputChanged:Connect(function(i)
	if i.UserInputType ~= Enum.UserInputType.MouseMovement then return end
	if Settings.UIFX and menuOpen and insidePanel(i.Position) then
		local p = localPos(i.Position)
		cursorTarget = p
		if (p - lastSpark).Magnitude > 20 then lastSpark = p sparks(p.X, p.Y, 1, 14) end
	else
		cursorTarget = nil
	end
end)
UIS.InputBegan:Connect(function(i)
	if Settings.UIFX and menuOpen and i.UserInputType == Enum.UserInputType.MouseButton1 and insidePanel(i.Position) then
		local p = localPos(i.Position)
		clickBurst(p.X, p.Y)
	end
end)

local function updateCursorFX(dt)
	if cursorTarget and Settings.UIFX and menuOpen then
		if not glowOuter.Visible then cursorPos = cursorTarget end
		cursorPos = cursorPos:Lerp(cursorTarget, math.clamp(dt * 14, 0, 1))
		glowOuter.Visible, glowInner.Visible = true, true
		glowOuter.Position = UDim2.fromOffset(cursorPos.X, cursorPos.Y)
		glowInner.Position = glowOuter.Position
	else
		glowOuter.Visible, glowInner.Visible = false, false
	end
end

----------------------------------------------------------------
-- Lock-on marker (solid brackets) + optional lock line
----------------------------------------------------------------
local markerGui = new("ScreenGui", { Name = "BlossomMarker", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 6 }, playerGui)
local marker = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(60, 60), BackgroundTransparency = 1, Visible = false }, markerGui)
local spin = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, marker)
local lockLine = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, BackgroundTransparency = 0.45, Visible = false }, markerGui)
local markerParts = {}
for _, c in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
	for _, horiz in ipairs({ true, false }) do
		table.insert(markerParts, new("Frame", {
			AnchorPoint = Vector2.new(c[1], c[2]), Position = UDim2.fromScale(c[1], c[2]), BorderSizePixel = 0,
			Size = horiz and UDim2.new(0.3, 0, 0, 2) or UDim2.new(0, 2, 0.3, 0),
		}, spin))
	end
end
onAccent(function(c)
	for _, f in ipairs(markerParts) do f.BackgroundColor3 = c end
	lockLine.BackgroundColor3 = c
end)

local function updateMarker(t, vp)
	local show = false
	if Settings.Enabled and Settings.TargetMarker and lockedTarget and lockedTarget.Character then
		local char = lockedTarget.Character
		local tp = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
		if tp then
			local sp = camera:WorldToViewportPoint(tp.Position)
			if sp.Z > 0 then
				local a = camera:WorldToViewportPoint(tp.Position + Vector3.new(0, 2.2, 0))
				local b = camera:WorldToViewportPoint(tp.Position - Vector3.new(0, 2.6, 0))
				local sz = math.clamp(math.abs(b.Y - a.Y) * 0.5 * Settings.MarkerSize / 100, 30, 180)
				marker.Position = UDim2.fromOffset(sp.X, sp.Y)
				marker.Size = UDim2.fromOffset(sz, sz)
				spin.Rotation = (t * Settings.MarkerSpin) % 360
				show = true
				lockLine.Visible = Settings.LockLine
				if Settings.LockLine then drawLine(lockLine, vp.X / 2, vp.Y / 2, sp.X, sp.Y, Settings.FOVColor, 1.5) end
			end
		end
	end
	marker.Visible = show
	if not show then lockLine.Visible = false end
end

----------------------------------------------------------------
-- Crosshair (spins while you're locked on) + camera grade
----------------------------------------------------------------
local chGui = new("ScreenGui", { Name = "BlossomCrosshair", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 3 }, playerGui)
local chRoot = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(140, 140), BackgroundTransparency = 1, Visible = false }, chGui)
local chBars = {}
for i = 1, 4 do chBars[i] = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0 }, chRoot) end
onAccent(function(c) for _, b in ipairs(chBars) do b.BackgroundColor3 = c end end)

local function updateCrosshair(vp, t)
	chRoot.Visible = Settings.Crosshair
	if not Settings.Crosshair then return end
	chRoot.Position = UDim2.fromOffset(vp.X / 2, vp.Y / 2)
	local len, gap = Settings.CrossSize, Settings.CrossGap
	for i, b in ipairs(chBars) do
		local horiz = i <= 2
		local sign = (i % 2 == 1) and -1 or 1
		b.Size = horiz and UDim2.fromOffset(len, 2) or UDim2.fromOffset(2, len)
		b.Position = horiz and UDim2.new(0.5, sign * (gap + len / 2), 0.5, 0) or UDim2.new(0.5, 0, 0.5, sign * (gap + len / 2))
	end
	-- while locked on, spin at CrossSpinRPS rotations per second (far faster than frames can show, so it blurs)
	if Settings.CrossSpin and Settings.Enabled and lockedTarget then
		chRoot.Rotation = (t * Settings.CrossSpinRPS * 360) % 360
	else
		chRoot.Rotation = 0
	end
end

local grade = new("ColorCorrectionEffect", { Name = "BlossomGrade", Enabled = false }, Lighting)
local bloom = new("BloomEffect", { Name = "BlossomBloom", Enabled = false, Intensity = 0.4, Size = 24, Threshold = 0.9 }, Lighting)

----------------------------------------------------------------
-- World visuals: sun rays, depth of field, particles
----------------------------------------------------------------
local sunrays = new("SunRaysEffect", { Name = "BlossomSunRays", Enabled = false, Intensity = 0.28, Spread = 0.85 }, Lighting)
local dof = new("DepthOfFieldEffect", { Name = "BlossomDOF", Enabled = false, FarIntensity = 0.3, FocusDistance = 45, InFocusRadius = 28, NearIntensity = 0 }, Lighting)

local function applyWorld()
	sunrays.Enabled, dof.Enabled = Settings.SunRays, Settings.DreamyDOF
end

local function fieldPart(name, size)
	return new("Part", {
		Name = name, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
		Transparency = 1, Size = size,
	}, Workspace)
end
local petalPart, flyPart = fieldPart("BlossomPetalField", Vector3.new(80, 1, 80)), fieldPart("BlossomFireflyField", Vector3.new(60, 16, 60))
local petalEm = new("ParticleEmitter", {
	Texture = SPARKLE, Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	EmissionDirection = Enum.NormalId.Bottom, Rate = 0, Lifetime = NumberRange.new(9, 13), Speed = NumberRange.new(2, 5),
	SpreadAngle = Vector2.new(25, 25), Acceleration = Vector3.new(2.5, -0.5, 1.5), Rotation = NumberRange.new(0, 360),
	RotSpeed = NumberRange.new(-90, 90), Size = NumberSequence.new(0.6), LightEmission = 0.25,
	Color = ColorSequence.new(rgb(255, 190, 215), rgb(245, 120, 170)),
	Transparency = NumberSequence.new({ NKP(0, 1), NKP(0.1, 0.1), NKP(0.85, 0.1), NKP(1, 1) }),
}, petalPart)
local flyEm = new("ParticleEmitter", {
	Texture = SPARKLE, Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
	Rate = 0, Lifetime = NumberRange.new(4, 7), Speed = NumberRange.new(0.2, 0.9), SpreadAngle = Vector2.new(180, 180),
	Acceleration = Vector3.new(0, 0.35, 0), Size = NumberSequence.new(0.3), LightEmission = 1,
	Color = ColorSequence.new({ KP(0, rgb(255, 170, 215)), KP(0.5, rgb(255, 235, 247)), KP(1, rgb(255, 200, 235)) }),
	Transparency = NumberSequence.new({ NKP(0, 1), NKP(0.2, 0.15), NKP(0.5, 0.6), NKP(0.8, 0.15), NKP(1, 1) }),
}, flyPart)

----------------------------------------------------------------
-- Physical visuals: real parts / adornments that exist in the world (local to you)
----------------------------------------------------------------
local physFolder = new("Folder", { Name = "BlossomPhysical" }, Workspace)

-- floating lanterns: glowing orbs that light up their surroundings
local orbs = {}
for i = 1, 24 do
	local p = new("Part", {
		Name = "Lantern", Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.9, 0.9), Material = Enum.Material.Neon,
		Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
	}, nil)
	orbs[i] = { part = p, light = new("PointLight", { Range = 16, Brightness = 1.2, Shadows = false }, p), pos = Vector3.zero, phase = math.random() * 6.28, ready = false }
end
local function updateOrbs(t, camPos)
	for i, o in ipairs(orbs) do
		if Settings.WorldOrbs and i <= Settings.OrbCount then
			if not o.ready or (o.pos - camPos).Magnitude > 75 then
				local a = math.random() * math.pi * 2
				o.pos = camPos + Vector3.new(math.cos(a), 0, math.sin(a)) * math.random(18, 55) + Vector3.new(0, math.random(-1, 9), 0)
				o.ready = true
			end
			o.part.CFrame = CFrame.new(o.pos + Vector3.new(math.sin(t * 0.6 + o.phase) * 0.9, math.sin(t * 0.9 + o.phase) * 1.1, math.cos(t * 0.5 + o.phase) * 0.9))
			o.part.Color = Settings.FOVColor:Lerp(Color3.new(1, 1, 1), 0.35 + 0.25 * math.sin(t * 2 + o.phase))
			o.light.Color = Settings.FOVColor
			o.part.Parent = physFolder
		else
			o.part.Parent = nil
		end
	end
end

-- lock-on shockwave: a flat ring that ripples out from the target's feet while you're locked
local lastPulse, pulseTarget = 0, nil
local function updatePulse(t)
	if Settings.Enabled and Settings.LockPulse and lockedTarget and lockedTarget.Character then
		local hrp = lockedTarget.Character:FindFirstChild("HumanoidRootPart")
		if hrp and (t - lastPulse > 1.1 or pulseTarget ~= lockedTarget) then
			lastPulse, pulseTarget = t, lockedTarget
			local d = new("CylinderHandleAdornment", {
				Adornee = hrp, Height = 0.1, Radius = 1, AlwaysOnTop = true, ZIndex = 1,
				CFrame = CFrame.new(0, -2.95, 0) * CFrame.Angles(-math.pi / 2, 0, 0),
				Color3 = Settings.FOVColor, Transparency = 0.2,
			}, hrp)
			tween(d, { Radius = 7, Transparency = 1 }, 0.9)
			task.delay(1, function() d:Destroy() end)
		end
	else
		pulseTarget = nil
	end
end

----------------------------------------------------------------
-- Watermark HUD (same design as the menu)
----------------------------------------------------------------
local hudGui = new("ScreenGui", { Name = "BlossomHUD", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 4 }, playerGui)
local hudFrames = {}

local function makeHud(props)
	local f = new("CanvasGroup", props, hudGui)
	f.BackgroundColor3, f.BorderSizePixel = BG, 0
	local st = new("UIStroke", { Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, f)
	local bar = new("Frame", { Size = UDim2.new(0, 3, 1, 0), BorderSizePixel = 0, ZIndex = 3 }, f)
	onAccent(function(c) st.Color = STROKE:Lerp(c, 0.55) bar.BackgroundColor3 = c end)
	addBrackets(f, 5, 6, 1, 4)
	table.insert(hudFrames, f)
	local ds, sp
	f.InputBegan:Connect(function(i)
		if menuOpen and i.UserInputType == Enum.UserInputType.MouseButton1 then ds, sp = i.Position, f.Position end
	end)
	UIS.InputChanged:Connect(function(i)
		if ds and i.UserInputType == Enum.UserInputType.MouseMovement then
			local d = i.Position - ds
			f.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
		end
	end)
	UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then ds = nil end end)
	return f
end

local wm = makeHud({ Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X })
local wmLbl = new("TextLabel", {
	Position = UDim2.fromOffset(16, 0), Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1,
	RichText = true, Font = FONT_MED, TextSize = 12, TextColor3 = TEXT, Text = "", TextXAlignment = Enum.TextXAlignment.Left,
}, wm)
new("UIPadding", { PaddingRight = UDim.new(0, 28) }, wm)

local updateTargetHud, updateMusicHud
do
----------------------------------------------------------------
-- Target HUD (same design as the menu): headshot, name, health, distance, held item
----------------------------------------------------------------
local TH_W, TH_H = 290, 80
local targetHud = makeHud({ Position = UDim2.fromOffset(16, 56), Size = UDim2.fromOffset(TH_W, TH_H), GroupTransparency = 1, Visible = false })
local thThumbBox = new("Frame", { Position = UDim2.fromOffset(16, 14), Size = UDim2.fromOffset(52, 52), BackgroundColor3 = CARD, BorderSizePixel = 0 }, targetHud)
addStroke(thThumbBox)
local thThumb = new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = "" }, thThumbBox)
local thName = new("TextLabel", {
	Position = UDim2.fromOffset(80, 11), Size = UDim2.new(1, -92, 0, 16), BackgroundTransparency = 1, Font = FONT_BOLD, TextSize = 13,
	TextColor3 = TEXT, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = "No target",
}, targetHud)
local thSub = new("TextLabel", {
	Position = UDim2.fromOffset(80, 28), Size = UDim2.new(1, -92, 0, 13), BackgroundTransparency = 1, Font = FONT, TextSize = 11,
	TextColor3 = SUBTEXT, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = "",
}, targetHud)
local thTrack = new("Frame", { Position = UDim2.fromOffset(80, 48), Size = UDim2.new(1, -92, 0, 6), BackgroundColor3 = OFF_TRACK, BorderSizePixel = 0 }, targetHud)
local thFill = new("Frame", { Size = UDim2.fromScale(1, 1), BorderSizePixel = 0 }, thTrack)
local thHpLbl = new("TextLabel", {
	Position = UDim2.fromOffset(80, 58), Size = UDim2.new(0.5, -46, 0, 13), BackgroundTransparency = 1, Font = FONT_MED, TextSize = 11,
	TextColor3 = DIM, TextXAlignment = Enum.TextXAlignment.Left, Text = "",
}, targetHud)
local thToolLbl = new("TextLabel", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 58), Size = UDim2.new(0.5, -46, 0, 13), BackgroundTransparency = 1,
	Font = FONT, TextSize = 11, TextColor3 = SUBTEXT, TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, Text = "",
}, targetHud)

local thumbCache, thUser, thAlpha, thPct = {}, nil, 1, 1
local function loadThumb(userId)
	if thumbCache[userId] then thThumb.Image = thumbCache[userId] return end
	thThumb.Image = ""
	task.spawn(function()
		local ok, content = pcall(function()
			return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		end)
		if ok then
			thumbCache[userId] = content
			if thUser == userId then thThumb.Image = content end
		end
	end)
end

function updateTargetHud(dt)
	local tgt = Settings.Enabled and lockedTarget or nil
	local show = Settings.TargetHUD and (tgt ~= nil or menuOpen)
	thAlpha += ((show and 0 or 1) - thAlpha) * math.clamp(dt * 12, 0, 1)
	targetHud.GroupTransparency = thAlpha
	targetHud.Visible = thAlpha < 0.98
	if not targetHud.Visible then return end

	local ah, as, av = Settings.FOVColor:ToHSV()
	local char = tgt and tgt.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if tgt and hum and hrp then
		if tgt.UserId ~= thUser then
			thUser = tgt.UserId
			thName.Text = tgt.DisplayName
			loadThumb(tgt.UserId)
		end
		local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
		thPct += (pct - thPct) * math.clamp(dt * 10, 0, 1)
		thFill.Size = UDim2.fromScale(thPct, 1)
		thFill.BackgroundColor3 = Color3.fromHSV(ah, math.min(1, as * (1 + (1 - pct) * 0.35)), av * (0.3 + 0.7 * pct))
		thSub.Text = "@" .. tgt.Name .. "  •  " .. math.floor((hrp.Position - camera.CFrame.Position).Magnitude) .. " studs"
		thHpLbl.Text = math.floor(hum.Health) .. " / " .. math.floor(hum.MaxHealth) .. " HP"
		local tool = char:FindFirstChildOfClass("Tool")
		thToolLbl.Text = tool and tool.Name or "no item"
	elseif show then
		thUser = nil
		thThumb.Image = ""
		thName.Text = "No target"
		thSub.Text = "Lock on to someone to see them here"
		thHpLbl.Text, thToolLbl.Text = "", ""
		thFill.Size = UDim2.fromScale(0, 1)
		thPct = 0
	end
end

----------------------------------------------------------------
-- Music HUD (plays the audio assets in PLAYLIST; Spotify itself can't be reached from Roblox)
----------------------------------------------------------------
local MH_W, MH_H = 340, 108
local musicHud = makeHud({ Position = UDim2.fromOffset(16, 144), Size = UDim2.fromOffset(MH_W, MH_H), GroupTransparency = 1, Visible = false })
local music = new("Sound", { Name = "BlossomMusic", Volume = 0.5, Looped = false }, hudGui)

local art = new("Frame", { Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(68, 68), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ClipsDescendants = true }, musicHud)
local artGrad = new("UIGradient", { Rotation = 55 }, art)
onAccent(function(c) artGrad.Color = ColorSequence.new(c, c:Lerp(Color3.new(0, 0, 0), 0.7)) end)
local eqBars, eqH = {}, {}
for i = 1, 5 do
	eqBars[i] = new("Frame", {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 9 + (i - 1) * 11, 1, -9), Size = UDim2.fromOffset(7, 6),
		BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.15, BorderSizePixel = 0,
	}, art)
	eqH[i] = 6
end
local mTitle = new("TextLabel", {
	Position = UDim2.fromOffset(98, 14), Size = UDim2.new(1, -112, 0, 16), BackgroundTransparency = 1, Font = FONT_BOLD, TextSize = 13,
	TextColor3 = TEXT, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = "Nothing playing",
}, musicHud)
local mArtist = new("TextLabel", {
	Position = UDim2.fromOffset(98, 31), Size = UDim2.new(1, -112, 0, 14), BackgroundTransparency = 1, Font = FONT, TextSize = 12,
	TextColor3 = SUBTEXT, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, Text = "Add audio IDs to PLAYLIST",
}, musicHud)
local mTrack = new("Frame", { Position = UDim2.fromOffset(98, 54), Size = UDim2.new(1, -114, 0, 4), BackgroundColor3 = OFF_TRACK, BorderSizePixel = 0 }, musicHud)
local mFill = new("Frame", { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0 }, mTrack)
onAccent(function(c) mFill.BackgroundColor3 = c end)
local mTimeL = new("TextLabel", {
	Position = UDim2.fromOffset(98, 62), Size = UDim2.new(1, -114, 0, 12), BackgroundTransparency = 1, Font = FONT, TextSize = 10,
	TextColor3 = SUBTEXT, TextXAlignment = Enum.TextXAlignment.Left, Text = "0:00",
}, musicHud)
local mTimeR = new("TextLabel", {
	Position = UDim2.fromOffset(98, 62), Size = UDim2.new(1, -114, 0, 12), BackgroundTransparency = 1, Font = FONT, TextSize = 10,
	TextColor3 = SUBTEXT, TextXAlignment = Enum.TextXAlignment.Right, Text = "0:00",
}, musicHud)

local mPlayBtn
local function hudButton(text, x, fn)
	local b = new("TextButton", {
		Position = UDim2.fromOffset(x, 80), Size = UDim2.fromOffset(60, 18), BackgroundColor3 = CARD, BorderSizePixel = 0, AutoButtonColor = false,
		Font = FONT_MED, TextSize = 10, TextColor3 = TEXT, Text = text,
	}, musicHud)
	local st = addStroke(b)
	b.MouseEnter:Connect(function() tween(b, { BackgroundColor3 = CARD_HOVER }, 0.1) tween(st, { Color = Settings.FOVColor, Transparency = 0.55 }, 0.1) end)
	b.MouseLeave:Connect(function() tween(b, { BackgroundColor3 = CARD }, 0.12) tween(st, { Color = STROKE, Transparency = 0 }, 0.12) end)
	b.MouseButton1Click:Connect(fn)
	return b
end

local trackIdx = 1
local function loadTrack(i, autoplay)
	if #PLAYLIST == 0 then return end
	trackIdx = ((i - 1) % #PLAYLIST) + 1
	music:Stop()
	music.SoundId = "rbxassetid://" .. tostring(PLAYLIST[trackIdx].id)
	music.TimePosition = 0
	if autoplay then music:Play() end
end
Actions.MusicNext = function() loadTrack(trackIdx + 1, true) end
Actions.MusicPrev = function()
	if #PLAYLIST == 0 then return end
	if music.TimePosition > 3 then music.TimePosition = 0 else loadTrack(trackIdx - 1, true) end
end
Actions.MusicToggle = function()
	if #PLAYLIST == 0 then return end
	if music.SoundId == "" then loadTrack(trackIdx, true)
	elseif music.IsPlaying then music:Pause()
	else music:Resume() end
end
music.Ended:Connect(function() loadTrack(trackIdx + 1, true) end)

hudButton("PREV", 98, function() Actions.MusicPrev() end)
mPlayBtn = hudButton("PLAY", 164, function() Actions.MusicToggle() end)
hudButton("NEXT", 230, function() Actions.MusicNext() end)

UIS.InputBegan:Connect(function(i, processed)
	if processed or not Settings.MusicHUD then return end
	if i.KeyCode == MUSIC_KEYS.Prev then Actions.MusicPrev()
	elseif i.KeyCode == MUSIC_KEYS.Toggle then Actions.MusicToggle()
	elseif i.KeyCode == MUSIC_KEYS.Next then Actions.MusicNext() end
end)

local function fmtTime(sec)
	sec = math.max(0, math.floor(sec))
	return string.format("%d:%02d", sec // 60, sec % 60)
end

local mAlpha = 1
function updateMusicHud(dt, t)
	music.Volume = Settings.MusicVolume / 100
	local show = Settings.MusicHUD
	mAlpha += ((show and 0 or 1) - mAlpha) * math.clamp(dt * 12, 0, 1)
	musicHud.GroupTransparency = mAlpha
	musicHud.Visible = mAlpha < 0.98
	if not musicHud.Visible then return end

	local tr = PLAYLIST[trackIdx]
	if tr and music.SoundId ~= "" then
		mTitle.Text, mArtist.Text = tr.title or "Unknown", tr.artist or ""
	else
		mTitle.Text = #PLAYLIST > 0 and "Press play" or "Nothing playing"
		mArtist.Text = #PLAYLIST > 0 and (PLAYLIST[1].title or "") or "Add audio IDs to PLAYLIST"
	end
	local len = music.TimeLength
	mFill.Size = UDim2.fromScale(len > 0 and math.clamp(music.TimePosition / len, 0, 1) or 0, 1)
	mTimeL.Text, mTimeR.Text = fmtTime(music.TimePosition), fmtTime(len)
	mPlayBtn.Text = music.IsPlaying and "PAUSE" or "PLAY"

	-- equalizer driven by the track's real loudness
	local loud = music.IsPlaying and math.clamp(music.PlaybackLoudness / 380, 0, 1) or 0
	for i, b in ipairs(eqBars) do
		local wob = 0.5 + 0.5 * math.sin(t * (6 + i * 1.7) + i * 2)
		local target = 6 + 46 * loud * (0.35 + 0.65 * wob)
		eqH[i] += (target - eqH[i]) * math.clamp(dt * 14, 0, 1)
		b.Size = UDim2.fromOffset(7, math.floor(eqH[i]))
	end
end

end

local hudAcc, hudN, hudTimer = 0, 0, 0
local function updateHuds(dt)
	wm.Visible = Settings.HUDWatermark
	hudAcc += dt hudN += 1 hudTimer += dt
	if hudTimer >= 0.25 then
		local fps = math.floor(hudN / hudAcc + 0.5)
		hudAcc, hudN, hudTimer = 0, 0, 0
		local ping = math.floor(player:GetNetworkPing() * 1000 + 0.5)
		local sep = '  <font color="#555064">|</font>  '
		wmLbl.Text = 'Blossom<font color="#' .. Settings.FOVColor:ToHex() .. '">.lol</font>'
			.. (VERSION ~= "" and (" " .. VERSION) or "")
			.. sep .. fps .. " fps" .. sep .. ping .. " ms" .. sep .. os.date("%H:%M")
	end
end

----------------------------------------------------------------
-- Ambient loop
----------------------------------------------------------------
local origFog = { Lighting.FogStart, Lighting.FogEnd, Lighting.FogColor }
local fogApplied, worldTimer = false, 0

RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()
	local vp = camera.ViewportSize
	local camPos = camera.CFrame.Position

	if root.Visible then
		stepPetals(menuPool, Settings.MenuPetals and math.ceil(Settings.PetalAmount * 0.5) or 0, dt, t, PANEL_W, PANEL_H)
	end
	stepPetals(screenPool, Settings.ScreenPetals and Settings.PetalAmount or 0, dt, t, vp.X, vp.Y)

	updateCursorFX(dt)
	updateMarker(t, vp)
	updateCrosshair(vp, t)
	updateHuds(dt)
	updateOrbs(t, camPos)
	updateTargetHud(dt)
	updateMusicHud(dt, t)
	updatePulse(t)

	if Settings.CustomFOV then camera.FieldOfView = Settings.CamFOV end

	local g = Settings.GradeStrength / 100
	grade.Enabled, bloom.Enabled = Settings.Grade, Settings.Grade
	if Settings.Grade then
		grade.TintColor = Color3.new(1, 1, 1):Lerp(rgb(255, 205, 225), g)
		grade.Saturation, grade.Contrast, bloom.Intensity = 0.25 * g, 0.08 * g, 0.5 * g
	end

	worldTimer += dt
	if worldTimer > 0.1 then worldTimer = 0 applyWorld() end

	petalPart.CFrame = CFrame.new(camPos + Vector3.new(0, 24, 0))
	flyPart.CFrame = CFrame.new(camPos + Vector3.new(0, 3, 0))
	petalEm.Rate = Settings.WorldPetals and Settings.WorldPetalAmount or 0
	flyEm.Rate = Settings.Fireflies and 22 or 0

	if Settings.WorldFog then
		Lighting.FogEnd = Settings.FogDistance
		Lighting.FogStart = Settings.FogDistance * 0.2
		Lighting.FogColor = rgb(236, 208, 224)
		fogApplied = true
	elseif fogApplied then
		Lighting.FogStart, Lighting.FogEnd, Lighting.FogColor = origFog[1], origFog[2], origFog[3]
		fogApplied = false
	end
end)

-- Open / close + optional aim toggle key
local function setMenuOpen(open)
	menuOpen = open
	modal.Modal = open
	for _, h in ipairs(hudFrames) do h.Active = open end
	if open then
		root.Visible = true
		tween(panel, { GroupTransparency = 0 }, 0.25)
		tween(title, { TextTransparency = 0 }, 0.25)
		tween(rootScale, { Scale = baseScale }, 0.35, Enum.EasingStyle.Back)
	else
		tween(panel, { GroupTransparency = 1 }, 0.2)
		tween(title, { TextTransparency = 1 }, 0.2)
		tween(rootScale, { Scale = baseScale * 0.94 }, 0.2)
		task.delay(0.2, function() if not menuOpen then root.Visible = false end end)
	end
end
UIS.InputBegan:Connect(function(i, processed)
	if processed then return end
	if i.KeyCode == MENU_KEY then setMenuOpen(not menuOpen)
	elseif Settings.ToggleKey ~= "None" and i.KeyCode.Name == Settings.ToggleKey then
		Settings.Enabled = not Settings.Enabled
		if masterRefresh then masterRefresh(true) end
	end
end)
camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateFit)
updateFit()
setMenuOpen(true)

----------------------------------------------------------------
-- Targeting helpers
----------------------------------------------------------------
local PART_LIST = { "Head", "UpperTorso", "Torso", "HumanoidRootPart" }
local BODY = {
	"Head", "UpperTorso", "Torso", "LowerTorso", "HumanoidRootPart",
	"RightUpperArm", "LeftUpperArm", "RightUpperLeg", "LeftUpperLeg", "Right Arm", "Left Arm", "Right Leg", "Left Leg",
}

local function isEnemy(plr)
	if plr == player then return false end
	if plr.Team == nil or player.Team == nil then return true end
	return plr.Team ~= player.Team
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true
local function clearLine(part)
	local filter = { part.Parent }
	if player.Character then table.insert(filter, player.Character) end
	rayParams.FilterDescendantsInstances = filter
	local o = camera.CFrame.Position
	return Workspace:Raycast(o, part.Position - o, rayParams) == nil
end

local function preferredPart(char)
	if Settings.TargetPart ~= "Auto" then return char:FindFirstChild(Settings.TargetPart) end
	local center, best, bd = camera.ViewportSize / 2, nil, nil
	for _, n in ipairs(PART_LIST) do
		local p = char:FindFirstChild(n)
		if p then
			local sp, on = camera:WorldToViewportPoint(p.Position)
			local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
			if on and (not bd or d < bd) then best, bd = p, d end
		end
	end
	return best or char:FindFirstChild("HumanoidRootPart")
end

-- Preferred part if visible, else the first VISIBLE body part (e.g. head above a half wall).
-- Returns nil only when every part is covered.
local function resolvePart(char)
	local pref = preferredPart(char)
	if not Settings.WallCheck then return pref or char:FindFirstChild("HumanoidRootPart") end
	if pref and clearLine(pref) then return pref end
	for _, n in ipairs(BODY) do
		local p = char:FindFirstChild(n)
		if p and p ~= pref and clearLine(p) then return p end
	end
	return nil
end

local function isValid(plr)
	if plr == player then return false end
	if Settings.TeamCheck and plr.Team ~= nil and plr.Team == player.Team then return false end
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return false end
	if Settings.IgnoreForceField and char:FindFirstChildOfClass("ForceField") then return false end
	return true
end

local function candidateScore(plr)
	if not isValid(plr) then return nil end
	local part = resolvePart(plr.Character)
	if not part then return nil end
	local dist = (part.Position - camera.CFrame.Position).Magnitude
	if dist > Settings.MaxDistance then return nil end
	local sp, on = camera:WorldToViewportPoint(part.Position)
	if not on then return nil end
	local d = (Vector2.new(sp.X, sp.Y) - camera.ViewportSize / 2).Magnitude
	if d > Settings.FOV then return nil end
	if Settings.Priority == "Distance" then return dist end
	if Settings.Priority == "Health" then return plr.Character:FindFirstChildOfClass("Humanoid").Health end
	return d
end

local function getBestTarget()
	local best, bestScore
	for _, plr in ipairs(Players:GetPlayers()) do
		local s = candidateScore(plr)
		if s and (not bestScore or s < bestScore) then best, bestScore = plr, s end
	end
	return best, bestScore
end

do
----------------------------------------------------------------
-- Cosmetics (client-side only): hologram hats, see-through bodies, blossom burst, orbiting blossoms
----------------------------------------------------------------
local cosState = {}

local function cosApplies(plr)
	local g = Settings.CosGroup
	if g == "Everyone" then return true end
	if plr == player then return false end
	if g == "Enemies" then return isEnemy(plr) end
	if g == "Teammates" then return not isEnemy(plr) end
	return true
end

-- cones are stacked neon discs (Roblox has no cone part); the animation loop below makes them holographic
local function buildHat(kind, head)
	local folder = Instance.new("Folder")
	folder.Name = "BlossomHat"
	local layers, radius, height = 9, 0.95, 1.7
	if kind == "China hat" then radius, height = 1.9, 0.6 end
	local base, step, parts = head.Size.Y / 2, height / layers, {}
	for i = 1, layers do
		local r = math.max(radius * (1 - (i - 1) / layers), 0.06)
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(step + 0.02, r * 2, r * 2)
		p.Material = Enum.Material.Neon
		p.Transparency = 0.5
		p.CanCollide, p.CanTouch, p.CanQuery, p.Massless, p.CastShadow = false, false, false, true, false
		p.CFrame = head.CFrame * CFrame.new(0, base + (i - 0.5) * step, 0) * CFrame.Angles(0, 0, math.rad(90))
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = head, p
		w.Parent = p
		p.Parent = folder
		parts[i] = p
	end
	folder.Parent = head.Parent
	return folder, parts
end

-- small glowing petals that circle the player and leave ribbon trails
local function buildOrbit(count)
	local list = {}
	for i = 1, count do
		local p = new("Part", {
			Name = "OrbitPetal", Shape = Enum.PartType.Ball, Size = Vector3.new(0.42, 0.42, 0.42), Material = Enum.Material.Neon,
			Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
		}, physFolder)
		local a0 = new("Attachment", { Position = Vector3.new(0, 0.18, 0) }, p)
		local a1 = new("Attachment", { Position = Vector3.new(0, -0.18, 0) }, p)
		new("Trail", {
			Attachment0 = a0, Attachment1 = a1, Lifetime = 0.55, LightEmission = 1, FaceCamera = true,
			Color = ColorSequence.new(rgb(255, 190, 215), rgb(245, 110, 165)),
			Transparency = NumberSequence.new({ NKP(0, 0.1), NKP(1, 1) }),
		}, p)
		list[i] = p
	end
	return list
end
local function destroyList(list) if list then for _, p in ipairs(list) do p:Destroy() end end end

local function makeEmitter()
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARKLE
	e.Rate = Settings.BlossomRate
	e.Lifetime = NumberRange.new(1.2, 2)
	e.Speed = NumberRange.new(6, 12)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -4, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-120, 120)
	e.LightEmission = 0.35
	e.Size = NumberSequence.new({ NKP(0, 0.55), NKP(1, 0) })
	e.Transparency = NumberSequence.new({ NKP(0, 0.1), NKP(1, 1) })
	e.Color = ColorSequence.new(rgb(255, 190, 215), rgb(245, 110, 165))
	return e
end

local function setBody(char, a, hat)
	for _, d in ipairs(char:GetDescendants()) do
		if d:IsA("BasePart") then
			if not (hat and d:IsDescendantOf(hat)) then d.LocalTransparencyModifier = a end
		elseif d:IsA("Decal") then
			local orig = d:GetAttribute("BLorig")
			if a > 0 then
				if orig == nil then orig = d.Transparency d:SetAttribute("BLorig", orig) end
				d.Transparency = math.max(orig, a)
			elseif orig ~= nil then
				d.Transparency = orig
				d:SetAttribute("BLorig", nil)
			end
		end
	end
end

local function clearCos(plr, st)
	if st.hat then st.hat:Destroy() end
	if st.att then st.att:Destroy() end
	destroyList(st.orbit)
	if st.char and st.char.Parent then pcall(setBody, st.char, 0, nil) end
	cosState[plr] = nil
end

local function cosUpdate()
	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		local st = cosState[plr]
		local want = Settings.Cosmetics and char ~= nil and cosApplies(plr)
		if st and (not want or st.char ~= char) then clearCos(plr, st) st = nil end
		if want then
			local head = char:FindFirstChild("Head")
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if not st then st = { char = char } cosState[plr] = st end

			if head and (st.kind ~= Settings.HatStyle or (st.hat and not st.hat.Parent)) then
				if st.hat then st.hat:Destroy() st.hat, st.hatParts = nil, nil end
				if Settings.HatStyle ~= "None" then st.hat, st.hatParts = buildHat(Settings.HatStyle, head) end
				st.kind = Settings.HatStyle
			end

			setBody(char, Settings.SeeThrough and Settings.BodyAlpha / 100 or 0, st.hat)

			if Settings.Blossoms and hrp then
				if not (st.emit and st.emit.Parent) then
					st.att = Instance.new("Attachment")
					st.att.Parent = hrp
					st.emit = makeEmitter()
					st.emit.Parent = st.att
				end
				st.emit.Rate = Settings.BlossomRate
			elseif st.att then
				st.att:Destroy()
				st.att, st.emit = nil, nil
			end

			if Settings.OrbitPetals then
				if not st.orbit or #st.orbit ~= Settings.OrbitCount then
					destroyList(st.orbit)
					st.orbit = buildOrbit(Settings.OrbitCount)
				end
			elseif st.orbit then
				destroyList(st.orbit)
				st.orbit = nil
			end
		end
	end
end

task.spawn(function()
	while true do
		task.wait(0.3)
		pcall(cosUpdate)
	end
end)
Players.PlayerRemoving:Connect(function(plr)
	local st = cosState[plr]
	if st then destroyList(st.orbit) end
	cosState[plr] = nil
end)

-- animation: hologram hats (shimmer, flicker, scan band) + orbiting petals
RunService.Heartbeat:Connect(function()
	local t = os.clock()
	local h, s = Settings.FOVColor:ToHSV()
	for _, st in pairs(cosState) do
		if st.hatParts then
			local n = #st.hatParts
			local scan = math.floor((t * 5) % n) + 1
			for i, p in ipairs(st.hatParts) do
				if p.Parent then
					p.Color = Color3.fromHSV((h + 0.09 * math.sin(t * 1.4 + i * 0.5)) % 1, math.clamp(s * 0.85, 0, 1), 1)
					p.Transparency = (i == scan) and 0.15 or (0.5 + 0.12 * math.sin(t * 3 + i))
				end
			end
		end
		if st.orbit then
			local hrp = st.char and st.char:FindFirstChild("HumanoidRootPart")
			if hrp then
				local n = #st.orbit
				for i, p in ipairs(st.orbit) do
					local a = t * 1.8 + i * (math.pi * 2 / n)
					local r = 3.2 + 0.4 * math.sin(t * 1.3 + i)
					p.CFrame = CFrame.new(hrp.Position + Vector3.new(math.cos(a) * r, 0.4 + 1.3 * math.sin(t * 1.6 + i * 1.7), math.sin(a) * r))
					p.Color = Color3.fromHSV((h + 0.07 * math.sin(t + i)) % 1, 0.55, 1)
				end
			end
		end
	end
end)

do
end

----------------------------------------------------------------
-- Enemy ESP: boxes, skeleton, chams, look line, arrows, info, 3D ring + beacon
----------------------------------------------------------------
local espGui = new("ScreenGui", { Name = "BlossomESP", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 5 }, playerGui)
local espObjs = {}

local BONES15 = {
	{ "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" },
	{ "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
	{ "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
	{ "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
	{ "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
}
local BONES6 = { { "Head", "Torso" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" }, { "Torso", "Left Leg" }, { "Torso", "Right Leg" } }

local function createESP(plr)
	local holder = new("Frame", { Name = plr.Name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, espGui)
	local o = { holder = holder, lines = {}, bones = {}, arrowBars = {} }
	o.fill = new("Frame", { BorderSizePixel = 0, BackgroundTransparency = 0.88 }, holder)
	o.tracer = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, BackgroundTransparency = 0.4 }, holder)
	o.look = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0 }, holder)
	for i = 1, 14 do o.bones[i] = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, Visible = false }, holder) end
	for i = 1, 8 do o.lines[i] = new("Frame", { BorderSizePixel = 0 }, holder) end
	o.name = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(0, 14), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1,
		Font = FONT_BOLD, TextSize = 12, TextStrokeTransparency = 0.4, TextStrokeColor3 = Color3.new(0, 0, 0), Text = "",
	}, holder)
	o.tool = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(0, 12), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1,
		Font = FONT_MED, TextSize = 11, TextStrokeTransparency = 0.5, TextStrokeColor3 = Color3.new(0, 0, 0), Text = "",
	}, holder)
	o.hpBg = new("Frame", { BorderSizePixel = 0, BackgroundColor3 = rgb(10, 10, 12), BackgroundTransparency = 0.3 }, holder)
	o.hpFill = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0 }, o.hpBg)
	o.hpText = new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(0, 12), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1,
		Font = FONT_BOLD, TextSize = 10, TextStrokeTransparency = 0.4, TextStrokeColor3 = Color3.new(0, 0, 0), Text = "",
	}, holder)
	o.dot = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(6, 6), BorderSizePixel = 0 }, holder)
	o.arrow = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(24, 24), BackgroundTransparency = 1, Visible = false }, espGui)
	for _, s in ipairs({ -1, 1 }) do
		table.insert(o.arrowBars, new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 5, 0.5, s * 3), Size = UDim2.fromOffset(12, 3),
			Rotation = -s * 35, BorderSizePixel = 0,
		}, o.arrow))
	end
	espObjs[plr] = o
	return o
end

Players.PlayerRemoving:Connect(function(plr)
	local o = espObjs[plr]
	if o then
		o.holder:Destroy()
		o.arrow:Destroy()
		if o.cham then o.cham:Destroy() end
		if o.ring then o.ring:Destroy() end
		if o.beam then o.beam:Destroy() end
		espObjs[plr] = nil
	end
end)

local function place(f, x, y, w, h, c)
	f.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
	f.Size = UDim2.fromOffset(math.max(1, math.floor(w)), math.max(1, math.floor(h)))
	f.BackgroundColor3 = c
end

local function setCham(o, char, on, color)
	if on then
		if not o.cham then
			o.cham = Instance.new("Highlight")
			o.cham.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			o.cham.FillTransparency, o.cham.OutlineTransparency = 0.72, 0.15
		end
		if o.cham.Parent ~= char then
			local ok = pcall(function() o.cham.Parent = char end)
			if not ok then o.cham = nil return end
		end
		o.cham.FillColor, o.cham.OutlineColor = color, color
	elseif o.cham and o.cham.Parent then
		pcall(function() o.cham.Parent = nil end)
	end
end

-- 3D ESP: a pulsing ring on the ground under the enemy and a tall light beacon, both visible through walls
local function setPhys(o, hrp, on, color, t)
	if on and hrp then
		if Settings.ESPFootRing then
			if not o.ring then o.ring = new("CylinderHandleAdornment", { Height = 0.12, AlwaysOnTop = true, ZIndex = 1 }, nil) end
			o.ring.Adornee, o.ring.Parent = hrp, hrp
			o.ring.CFrame = CFrame.new(0, -2.95, 0) * CFrame.Angles(-math.pi / 2, 0, 0)
			o.ring.Radius = 2.3 + 0.45 * math.sin(t * 3)
			o.ring.Transparency = 0.45 + 0.2 * math.sin(t * 3)
			o.ring.Color3 = color
		elseif o.ring then
			o.ring.Parent = nil
		end
		if Settings.ESPBeacon then
			if not o.beam then o.beam = new("BoxHandleAdornment", { Size = Vector3.new(0.3, 70, 0.3), AlwaysOnTop = true, ZIndex = 1 }, nil) end
			o.beam.Adornee, o.beam.Parent = hrp, hrp
			o.beam.CFrame = CFrame.new(0, 32, 0)
			o.beam.Transparency = 0.5 + 0.2 * math.sin(t * 2)
			o.beam.Color3 = color
		elseif o.beam then
			o.beam.Parent = nil
		end
	else
		if o.ring then o.ring.Parent = nil end
		if o.beam then o.beam.Parent = nil end
	end
end

local function drawSkeleton(o, char, color)
	local set = char:FindFirstChild("UpperTorso") and BONES15 or BONES6
	for i, f in ipairs(o.bones) do
		local b = Settings.ESPSkeleton and set[i]
		local a = b and char:FindFirstChild(b[1])
		local c = b and char:FindFirstChild(b[2])
		f.Visible = false
		if a and c then
			local p1, p2 = camera:WorldToViewportPoint(a.Position), camera:WorldToViewportPoint(c.Position)
			if p1.Z > 0 and p2.Z > 0 then
				drawLine(f, p1.X, p1.Y, p2.X, p2.Y, color, 1.5)
				f.Visible = true
			end
		end
	end
end

local function updateESP()
	camera = Workspace.CurrentCamera
	local vp = camera.ViewportSize
	local t = os.clock()
	local ah, as, av = Settings.FOVColor:ToHSV()
	for _, plr in ipairs(Players:GetPlayers()) do
		local o, show, arrow, chamChar, physHrp, color = espObjs[plr], false, false, nil, nil, Settings.FOVColor
		if Settings.EnemyESP and isEnemy(plr) then
			local char = plr.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hum and hrp and hum.Health > 0 then
				local dist = (hrp.Position - camera.CFrame.Position).Magnitude
				if dist <= Settings.ESPMaxDistance then
					o = o or createESP(plr)
					color = (Settings.ESPTeamColor and plr.Team ~= nil) and plr.TeamColor.Color or Settings.FOVColor
					if Settings.ESPVisCheck and not clearLine(hrp) then
						color = color:Lerp(rgb(90, 90, 100), 0.6)
					end
					local thick = Settings.ESPThickness
					if Settings.ESPTargetGlow and plr == lockedTarget then
						color = Color3.new(1, 1, 1):Lerp(color, 0.45)
						thick += 1
					end
					local fade = Settings.ESPFade and math.clamp(dist / Settings.ESPMaxDistance, 0, 1) * 0.75 or 0
					chamChar, physHrp = char, hrp

					local top = camera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 2.7, 0))
					local bot = camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3.1, 0))
					if top.Z > 0 and bot.Z > 0 then
						show = true
						local h = math.abs(bot.Y - top.Y)
						local w = h * 0.6
						local x, y = top.X - w / 2, top.Y
						local full = Settings.ESPStyle == "Full"
						local aw = full and w or math.max(4, w * Settings.ESPCorner)
						local ah2 = full and h or math.max(4, h * Settings.ESPCorner * 0.7)

						local L = o.lines
						place(L[1], x, y, aw, thick, color)                   place(L[2], x, y, thick, ah2, color)
						place(L[3], x + w - aw, y, aw, thick, color)          place(L[4], x + w - thick, y, thick, ah2, color)
						place(L[5], x, y + h - thick, aw, thick, color)       place(L[6], x, y + h - ah2, thick, ah2, color)
						place(L[7], x + w - aw, y + h - thick, aw, thick, color) place(L[8], x + w - thick, y + h - ah2, thick, ah2, color)
						for _, f in ipairs(L) do f.BackgroundTransparency = fade end

						o.fill.Visible = Settings.ESPFill
						if Settings.ESPFill then place(o.fill, x, y, w, h, color) end

						o.name.Visible = Settings.ESPNames
						if Settings.ESPNames then
							o.name.Text = plr.DisplayName .. "  " .. math.floor(dist) .. "m"
							o.name.Position = UDim2.fromOffset(math.floor(top.X), math.floor(y - 3))
							o.name.TextColor3, o.name.TextTransparency = color, fade
						end

						local tool = char:FindFirstChildOfClass("Tool")
						o.tool.Visible = Settings.ESPTool and tool ~= nil
						if o.tool.Visible then
							o.tool.Text = tool.Name
							o.tool.Position = UDim2.fromOffset(math.floor(top.X), math.floor(y + h + 3))
							o.tool.TextColor3 = color
						end

						-- health bar: pink, getting darker as HP drops
						local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
						o.hpBg.Visible = Settings.ESPHealth
						o.hpText.Visible = Settings.ESPHealthNum
						if Settings.ESPHealth then
							o.hpBg.Position = UDim2.fromOffset(math.floor(x - 7), math.floor(y))
							o.hpBg.Size = UDim2.fromOffset(3, math.max(1, math.floor(h)))
							o.hpFill.Size = UDim2.new(1, 0, pct, 0)
							o.hpFill.BackgroundColor3 = Color3.fromHSV(ah, math.min(1, as * (1 + (1 - pct) * 0.35)), av * (0.3 + 0.7 * pct))
						end
						if Settings.ESPHealthNum then
							o.hpText.Text = tostring(math.floor(hum.Health))
							o.hpText.Position = UDim2.fromOffset(math.floor(x - 11), math.floor(y))
							o.hpText.TextColor3 = o.hpFill.BackgroundColor3:Lerp(Color3.new(1, 1, 1), 0.35)
						end

						local head = char:FindFirstChild("Head")
						o.dot.Visible, o.look.Visible = false, false
						if head then
							local hp = camera:WorldToViewportPoint(head.Position)
							if Settings.ESPHeadDot and hp.Z > 0 then
								o.dot.Visible = true
								o.dot.Position = UDim2.fromOffset(math.floor(hp.X), math.floor(hp.Y))
								o.dot.BackgroundColor3 = color
							end
							if Settings.ESPLook then
								local fp = camera:WorldToViewportPoint(head.Position + head.CFrame.LookVector * 7)
								if hp.Z > 0 and fp.Z > 0 then
									drawLine(o.look, hp.X, hp.Y, fp.X, fp.Y, color, 2)
									o.look.Visible = true
								end
							end
						end

						drawSkeleton(o, char, color)

						o.tracer.Visible = Settings.ESPTracers
						if Settings.ESPTracers then drawLine(o.tracer, vp.X / 2, vp.Y, top.X, y + h, color, 1.5) end
					end

					if Settings.ESPArrows then
						local _, on = camera:WorldToViewportPoint(hrp.Position)
						if not on then
							local rel = camera.CFrame:PointToObjectSpace(hrp.Position)
							local d = Vector2.new(rel.X, -rel.Y)
							if d.Magnitude > 0.001 then
								d = d.Unit
								local R = math.min(vp.X, vp.Y) * 0.42
								o.arrow.Position = UDim2.fromOffset(vp.X / 2 + d.X * R, vp.Y / 2 + d.Y * R)
								o.arrow.Rotation = math.deg(math.atan2(d.Y, d.X))
								for _, b in ipairs(o.arrowBars) do b.BackgroundColor3 = color end
								arrow = true
							end
						end
					end
				end
			end
		end
		if o then
			o.holder.Visible = show
			o.arrow.Visible = arrow
			setCham(o, chamChar, Settings.ESPChams and chamChar ~= nil, color)
			local ok = pcall(setPhys, o, physHrp, chamChar ~= nil, color, t)
			if not ok then o.ring, o.beam = nil, nil end
		end
	end
end
RunService:BindToRenderStep("BlossomESP", Enum.RenderPriority.Camera.Value + 2, updateESP)

do
end

----------------------------------------------------------------
-- PHYSICAL FX: real 3D effects built from parts, adornments, beams, trails and particles
-- (all local to you; nothing replicates to other players)
----------------------------------------------------------------
local fxFolder = new("Folder", { Name = "BlossomFX" }, Workspace)
local FLAT = CFrame.Angles(-math.pi / 2, 0, 0)   -- lays a cylinder adornment flat on the ground
local fxRay = RaycastParams.new()
fxRay.FilterType = Enum.RaycastFilterType.Exclude
fxRay.IgnoreWater = true
local fxState, ripples = {}, {}
local gyro, tether
local sonar = { nextAt = 0 }

local function anchorPart(name)
	return new("Part", {
		Name = name, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false,
		Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2),
	}, fxFolder)
end

-- ground height under a player (so rings stay on the floor while they jump)
local function groundAt(hrp, char)
	local filter = { char, fxFolder, physFolder }
	if player.Character then table.insert(filter, player.Character) end
	fxRay.FilterDescendantsInstances = filter
	local r = Workspace:Raycast(hrp.Position, Vector3.new(0, -80, 0), fxRay)
	return r and (r.Position.Y + 0.07) or (hrp.Position.Y - 2.95)
end

local function ring(parent, radius, thick, transp, color, aot)
	return new("CylinderHandleAdornment", {
		Adornee = parent, Height = 0.05, Radius = radius, InnerRadius = math.max(radius - thick, 0), Transparency = transp,
		ZIndex = 1, CFrame = FLAT, Color3 = color, AlwaysOnTop = aot or false,
	}, parent)
end

-- expanding ground ripple (footsteps, sonar pings)
local function spawnRipple(pos, color, maxR, life, thick, aot)
	local a = anchorPart("Ripple")
	a.CFrame = CFrame.new(pos)
	local ad = ring(a, 0.3, 0.1, 0.2, color, aot)
	table.insert(ripples, { part = a, ad = ad, born = os.clock(), life = life, maxR = maxR, thick = thick })
end

local function dropKey(fx, k)
	local o = fx[k]
	if o then
		for _, p in ipairs(o.parts) do if p then p:Destroy() end end
		fx[k] = nil
	end
end
local function destroyFx(fx)
	for _, k in ipairs({ "sigil", "scan", "aura", "wire", "trails" }) do dropKey(fx, k) end
end

----------------------------------------------------------------
-- builders
----------------------------------------------------------------
-- ground sigil: two counter-rotating rune rings with tick marks, dashes, orbiting diamonds and a glow disc
local function buildSigil(color)
	local o = { all = {} }
	local a1, a2 = anchorPart("SigilOuter"), anchorPart("SigilInner")
	o.a1, o.a2, o.parts = a1, a2, { a1, a2 }
	local function add(x) table.insert(o.all, x) return x end
	add(ring(a1, 3.4, 0.1, 0.15, color))
	add(ring(a1, 3.0, 0.04, 0.45, color))
	for i = 1, 16 do
		local a = i / 16 * math.pi * 2
		local long = i % 4 == 0
		add(new("BoxHandleAdornment", {
			Adornee = a1, Size = Vector3.new(0.07, 0.05, long and 0.55 or 0.26), Transparency = 0.12, ZIndex = 1, Color3 = color,
			CFrame = CFrame.Angles(0, a, 0) * CFrame.new(0, 0, long and 3.72 or 3.58),
		}, a1))
	end
	add(ring(a2, 2.35, 0.05, 0.35, color))
	for i = 1, 24 do
		local a = i / 24 * math.pi * 2
		add(new("BoxHandleAdornment", {
			Adornee = a2, Size = Vector3.new(0.36, 0.05, 0.08), Transparency = 0.2, ZIndex = 1, Color3 = color,
			CFrame = CFrame.Angles(0, a, 0) * CFrame.new(0, 0, 2.7),
		}, a2))
	end
	for i = 1, 3 do
		local a = i / 3 * math.pi * 2
		add(new("BoxHandleAdornment", {
			Adornee = a2, Size = Vector3.new(0.26, 0.08, 0.26), Transparency = 0.05, ZIndex = 2, Color3 = color,
			CFrame = CFrame.Angles(0, a, 0) * CFrame.new(0, 0.04, 2.0) * CFrame.Angles(0, math.rad(45), 0),
		}, a2))
	end
	o.glow = add(new("CylinderHandleAdornment", {
		Adornee = a2, Height = 0.03, Radius = 3.2, InnerRadius = 0, Transparency = 0.88, ZIndex = 1, CFrame = FLAT, Color3 = color,
	}, a2))
	return o
end

-- scanner: two glowing rings that sweep up the body from feet to above the head
local function buildScan(color)
	local p = anchorPart("Scan")
	local o = { part = p, parts = { p }, rings = {} }
	for i = 1, 2 do
		o.rings[i] = { core = ring(p, 1.9, 0.07, 0.1, color), halo = ring(p, 2.0, 0.34, 0.7, color) }
	end
	return o
end

-- lock-on gyroscope: three tumbling rings with a node riding each one
local function buildGyro()
	local g = { part = anchorPart("Gyro"), rings = {}, nodes = {}, born = os.clock() }
	for i = 1, 3 do
		g.rings[i] = new("CylinderHandleAdornment", {
			Adornee = g.part, Height = 0.06, Radius = 3, InnerRadius = 2.92, AlwaysOnTop = true, ZIndex = 1, Transparency = 0.15,
		}, g.part)
		g.nodes[i] = new("SphereHandleAdornment", { Adornee = g.part, Radius = 0.16, AlwaysOnTop = true, ZIndex = 2, Transparency = 0 }, g.part)
	end
	return g
end

-- lock-on tether: a thin glowing beam from the lower-right of your view to the target's torso
local function buildTether(color, torso)
	local p = anchorPart("TetherStart")
	local a0 = new("Attachment", {}, p)
	local a1 = new("Attachment", { Name = "BlossomTetherEnd" }, torso)
	local core = new("Beam", {
		Attachment0 = a0, Attachment1 = a1, Width0 = 0.05, Width1 = 0.05, LightEmission = 1, FaceCamera = true, Segments = 12,
		Color = ColorSequence.new(color), Transparency = NumberSequence.new({ NKP(0, 0.85), NKP(0.25, 0.3), NKP(1, 0) }),
	}, p)
	local glow = new("Beam", {
		Attachment0 = a0, Attachment1 = a1, Width0 = 0.22, Width1 = 0.22, LightEmission = 1, FaceCamera = true, Segments = 12,
		Color = ColorSequence.new(color), Transparency = NumberSequence.new({ NKP(0, 1), NKP(0.3, 0.8), NKP(1, 0.55) }),
	}, p)
	return { part = p, a1 = a1, core = core, glow = glow }
end

local function killTether()
	if tether then
		tether.part:Destroy()
		tether.a1:Destroy()
		tether = nil
	end
end

----------------------------------------------------------------
-- sonar: a pulse expands across the ground from you; every enemy it passes flashes through walls
----------------------------------------------------------------
local function killSonar()
	if sonar.part then sonar.part:Destroy() end
	sonar.part, sonar.rings, sonar.origin = nil, nil, nil
end

local function sonarPing(e, color)
	local gy = groundAt(e.hrp, e.char)
	spawnRipple(Vector3.new(e.hrp.Position.X, gy, e.hrp.Position.Z), color:Lerp(Color3.new(1, 1, 1), 0.4), 4.5, 0.9, 0.16, true)
	local hl = new("Highlight", {
		Adornee = e.char, FillColor = color, OutlineColor = Color3.new(1, 1, 1), FillTransparency = 0.35, OutlineTransparency = 0,
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
	}, fxFolder)
	tween(hl, { FillTransparency = 1, OutlineTransparency = 1 }, 0.9)
	task.delay(1, function() hl:Destroy() end)
end

local function updateSonar(t, list, color)
	if not (Settings.PhysEnabled and Settings.PhysSonar) then killSonar() return end
	local me = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not sonar.part then
		if me and t >= sonar.nextAt then
			sonar.nextAt = t + Settings.PhysSonarInterval
			sonar.born, sonar.hit = t, {}
			sonar.origin = Vector3.new(me.Position.X, groundAt(me, player.Character), me.Position.Z)
			sonar.part = anchorPart("Sonar")
			sonar.part.CFrame = CFrame.new(sonar.origin)
			sonar.rings = {}
			for i, def in ipairs({ { 0.18, 0.1 }, { 0.9, 0.55 }, { 0.5, 0.8 } }) do
				sonar.rings[i] = { ad = ring(sonar.part, 0.5, def[1], def[2], color), thick = def[1], base = def[2], lag = (i - 1) * 3 }
			end
		end
		return
	end
	local range = Settings.PhysSonarRange
	local r = (t - sonar.born) * 80
	if r > range + 6 then killSonar() return end
	local k = math.clamp(r / range, 0, 1)
	for _, rg in ipairs(sonar.rings) do
		local rr = math.max(r - rg.lag, 0.3)
		rg.ad.Radius = rr
		rg.ad.InnerRadius = math.max(rr - rg.thick, 0)
		rg.ad.Color3 = color
		rg.ad.Transparency = math.clamp(rg.base + 0.9 * k * k, 0, 1)
	end
	for _, e in ipairs(list) do
		if not sonar.hit[e.plr] then
			local dx, dz = e.hrp.Position.X - sonar.origin.X, e.hrp.Position.Z - sonar.origin.Z
			if math.sqrt(dx * dx + dz * dz) <= r then
				sonar.hit[e.plr] = true
				sonarPing(e, color)
			end
		end
	end
end

----------------------------------------------------------------
-- per-player effects
----------------------------------------------------------------
local TRAIL_LIMBS = { "Left Arm", "Right Arm", "Left Leg", "Right Leg", "LeftHand", "RightHand", "LeftFoot", "RightFoot" }

local function updateFx(fx, e, t)
	local char, hrp = e.char, e.hrp
	local color = Settings.FOVColor
	local light = color:Lerp(Color3.new(1, 1, 1), 0.5)
	local gy = groundAt(hrp, char)
	local px, pz = hrp.Position.X, hrp.Position.Z
	local ph = fx.phase

	-- ground sigil
	if Settings.PhysSigil then
		local s = fx.sigil
		if not s then s = buildSigil(color) fx.sigil, fx.sigilCol = s, color end
		if fx.sigilCol ~= color then
			for _, a in ipairs(s.all) do a.Color3 = color end
			fx.sigilCol = color
		end
		local base = CFrame.new(px, gy, pz)
		s.a1.CFrame = base * CFrame.Angles(0, t * 0.5 + ph, 0)
		s.a2.CFrame = base * CFrame.Angles(0, -t * 0.9 + ph, 0)
		s.glow.Transparency = 0.86 + 0.06 * math.sin(t * 2.5 + ph)
	else
		dropKey(fx, "sigil")
	end

	-- scanner rings
	if Settings.PhysScan then
		local s = fx.scan
		if not s then s = buildScan(color) fx.scan = s end
		s.part.CFrame = CFrame.new(hrp.Position)
		for i, r in ipairs(s.rings) do
			local f = (t * 0.55 + (i - 1) * 0.5 + ph) % 1
			local rad = 1.7 + 0.4 * math.sin(f * math.pi)
			local cf = CFrame.new(0, -3 + f * 6.6, 0) * FLAT
			r.core.CFrame, r.halo.CFrame = cf, cf
			r.core.Radius, r.core.InnerRadius = rad, rad - 0.07
			r.halo.Radius, r.halo.InnerRadius = rad + 0.17, rad - 0.17
			r.core.Transparency = 0.08 + 0.92 * f ^ 2.5
			r.halo.Transparency = 0.7 + 0.3 * f
			r.core.Color3, r.halo.Color3 = light, color
		end
	else
		dropKey(fx, "scan")
	end

	-- energy aura: rising sparks + a real coloured point light on the surroundings
	if Settings.PhysAura then
		local a = fx.aura
		if not a then
			local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or hrp
			local em = new("ParticleEmitter", {
				Texture = SPARKLE, Rate = 22, Lifetime = NumberRange.new(1.1, 2), Speed = NumberRange.new(0.6, 1.8),
				SpreadAngle = Vector2.new(180, 180), EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, 3.2, 0),
				Drag = 0.8, LightEmission = 1, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-80, 80),
				Size = NumberSequence.new({ NKP(0, 0.24), NKP(1, 0) }),
				Transparency = NumberSequence.new({ NKP(0, 1), NKP(0.15, 0.1), NKP(1, 1) }),
			}, torso)
			local lt = new("PointLight", { Range = 13, Brightness = 0.9, Shadows = false }, hrp)
			a = { parts = { em, lt }, em = em, lt = lt }
			fx.aura = a
		end
		if fx.auraCol ~= color then
			a.em.Color = ColorSequence.new(color, light)
			a.lt.Color = color
			fx.auraCol = color
		end
		a.lt.Brightness = 0.8 + 0.25 * math.sin(t * 2 + ph)
	else
		dropKey(fx, "aura")
	end

	-- wireframe body: glowing outline boxes on every limb (visible through walls)
	if Settings.PhysWire then
		local w = fx.wire
		if not w then
			local boxes = {}
			for _, n in ipairs(BODY) do
				local p = char:FindFirstChild(n)
				if p and p:IsA("BasePart") and n ~= "HumanoidRootPart" then
					table.insert(boxes, new("SelectionBox", {
						Adornee = p, LineThickness = 0.025, Transparency = 0.1, SurfaceTransparency = 0.9,
					}, fxFolder))
				end
			end
			w = { parts = boxes }
			fx.wire = w
		end
		for i, b in ipairs(w.parts) do
			b.Color3, b.SurfaceColor3 = color, color
			b.SurfaceTransparency = 0.88 + 0.07 * math.sin(t * 3 + i * 0.4)
		end
	else
		dropKey(fx, "wire")
	end

	-- motion trails: swooshes behind the limbs while they move
	if Settings.PhysTrails then
		local tr = fx.trails
		if not tr then
			tr = { parts = {}, trails = {} }
			for _, n in ipairs(TRAIL_LIMBS) do
				local p = char:FindFirstChild(n)
				if p and p:IsA("BasePart") then
					local a0 = new("Attachment", { Position = Vector3.new(0, p.Size.Y / 2, 0) }, p)
					local a1 = new("Attachment", { Position = Vector3.new(0, -p.Size.Y / 2, 0) }, p)
					local trail = new("Trail", {
						Attachment0 = a0, Attachment1 = a1, Lifetime = 0.4, LightEmission = 0.9, FaceCamera = false,
						Transparency = NumberSequence.new({ NKP(0, 0.25), NKP(1, 1) }),
						WidthScale = NumberSequence.new({ NKP(0, 1), NKP(1, 0.2) }),
					}, p)
					table.insert(tr.parts, a0) table.insert(tr.parts, a1) table.insert(tr.parts, trail)
					table.insert(tr.trails, trail)
				end
			end
			fx.trails = tr
		end
		if fx.trailCol ~= color then
			for _, trail in ipairs(tr.trails) do trail.Color = ColorSequence.new(color, light) end
			fx.trailCol = color
		end
	else
		dropKey(fx, "trails")
	end

	-- footstep shockwaves
	if Settings.PhysSteps then
		local v = hrp.AssemblyLinearVelocity
		local hv = Vector3.new(v.X, 0, v.Z).Magnitude
		if hv > 4 and e.hum.FloorMaterial ~= Enum.Material.Air and t - fx.lastStep > math.clamp(5.2 / hv, 0.18, 0.5) then
			fx.lastStep = t
			spawnRipple(Vector3.new(px, gy, pz), color, 2.4, 0.55, 0.1, false)
		end
	end
end

----------------------------------------------------------------
-- main FX loop
----------------------------------------------------------------
local function fxUpdate(dt)
	camera = Workspace.CurrentCamera
	local t = os.clock()
	local camPos = camera.CFrame.Position
	local on = Settings.PhysEnabled
	local color = Settings.FOVColor
	local list, active = {}, {}

	if on then
		for _, plr in ipairs(Players:GetPlayers()) do
			if isEnemy(plr) then
				local char = plr.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				if hum and hrp and hum.Health > 0 then
					local d = (hrp.Position - camPos).Magnitude
					if d <= Settings.PhysDistance then
						list[#list + 1] = { plr = plr, char = char, hum = hum, hrp = hrp, d = d }
					end
				end
			end
		end
		table.sort(list, function(a, b) return a.d < b.d end)
		for i = 1, math.min(#list, Settings.PhysMaxPlayers) do active[list[i].plr] = list[i] end
	end

	for plr, fx in pairs(fxState) do
		if not active[plr] then destroyFx(fx) fxState[plr] = nil end
	end
	for plr, e in pairs(active) do
		local fx = fxState[plr]
		if not fx or fx.char ~= e.char then
			if fx then destroyFx(fx) end
			fx = { char = e.char, phase = math.random() * 6.28, lastStep = 0 }
			fxState[plr] = fx
		end
		updateFx(fx, e, t)
	end

	updateSonar(t, list, color)

	-- lock-on effects (target of the aim assist)
	local tChar = lockedTarget and lockedTarget.Character
	local tTorso = tChar and (tChar:FindFirstChild("UpperTorso") or tChar:FindFirstChild("Torso") or tChar:FindFirstChild("HumanoidRootPart"))
	local locked = on and Settings.Enabled and lockedTarget ~= nil and tTorso ~= nil

	if locked and Settings.PhysGyro then
		if not gyro or gyro.target ~= lockedTarget then
			if gyro then gyro.part:Destroy() end
			gyro = buildGyro()
			gyro.target = lockedTarget
		end
		local k = math.clamp((t - gyro.born) / 0.35, 0, 1)
		local grow = 1 - (1 - k) ^ 3
		gyro.part.CFrame = CFrame.new(tTorso.Position)
		local R = { 3.7 * grow, 3.25 * grow, 2.8 * grow }
		local rot = {
			CFrame.Angles(t * 0.9, t * 0.55, 0),
			CFrame.Angles(0, math.rad(60), 0) * CFrame.Angles(t * 0.7, 0, t * 0.35),
			CFrame.Angles(math.rad(30), t * 0.8, math.rad(90) + t * 0.3),
		}
		for i = 1, 3 do
			local rg = gyro.rings[i]
			rg.Radius = math.max(R[i], 0.1)
			rg.InnerRadius = math.max(R[i] - 0.08, 0)
			rg.CFrame = rot[i]
			rg.Color3 = color
			local node = gyro.nodes[i]
			node.CFrame = rot[i] * CFrame.Angles(0, 0, t * (1.6 + i * 0.5)) * CFrame.new(R[i], 0, 0)
			node.Color3 = color:Lerp(Color3.new(1, 1, 1), 0.5)
		end
	elseif gyro then
		gyro.part:Destroy()
		gyro = nil
	end

	if locked and Settings.PhysTether then
		if not tether or tether.target ~= lockedTarget then
			killTether()
			tether = buildTether(color, tTorso)
			tether.target = lockedTarget
		end
		tether.part.CFrame = camera.CFrame * CFrame.new(0.9, -0.9, -2)
		tether.core.Color, tether.glow.Color = ColorSequence.new(color), ColorSequence.new(color)
	else
		killTether()
	end

	-- ripples (footsteps + sonar pings)
	for i = #ripples, 1, -1 do
		local r = ripples[i]
		local k = (t - r.born) / r.life
		if k >= 1 or not r.part.Parent then
			r.part:Destroy()
			table.remove(ripples, i)
		else
			local rad = 0.3 + (r.maxR - 0.3) * (1 - (1 - k) ^ 3)
			r.ad.Radius = rad
			r.ad.InnerRadius = math.max(rad - r.thick, 0)
			r.ad.Transparency = 0.15 + 0.85 * k
		end
	end
end
RunService:BindToRenderStep("BlossomFX", Enum.RenderPriority.Camera.Value + 4, fxUpdate)

end

----------------------------------------------------------------
-- Mouse activity
----------------------------------------------------------------
local lastMove = 0
UIS.InputChanged:Connect(function(i)
	if (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch)
		and i.Delta.Magnitude >= Settings.MoveThreshold then
		lastMove = os.clock()
	end
end)

----------------------------------------------------------------
-- Main aim loop
----------------------------------------------------------------
local lockStart = 0

RunService:BindToRenderStep("Blossom", Enum.RenderPriority.Camera.Value + 1, function(dt)
	camera = Workspace.CurrentCamera
	local vp = camera.ViewportSize

	circle.Visible = Settings.Enabled and Settings.ShowFOV
	circle.Position = UDim2.fromOffset(vp.X / 2, vp.Y / 2)
	circle.Size = UDim2.fromOffset(Settings.FOV * 2, Settings.FOV * 2)
	circle.BackgroundTransparency = Settings.FOVFill and 0.94 or 1
	circleStroke.Thickness = Settings.FOVThickness + (circleLocked and 1 or 0)

	if not Settings.Enabled then
		lockedTarget = nil
		setStatus("Off", false)
		setCircleLocked(false)
		return
	end
	setStatus(lockedTarget and ("Locked · " .. string.sub(lockedTarget.DisplayName, 1, 12)) or "Active", true)
	setCircleLocked(lockedTarget ~= nil)

	if Settings.MouseActiveOnly and os.clock() - lastMove > Settings.MoveTimeout then return end

	local prev = lockedTarget

	-- Sticky: hold the target while it stays valid, in range, on screen and not fully covered
	local keep = false
	if Settings.StickyTarget and lockedTarget and isValid(lockedTarget) then
		local kp = resolvePart(lockedTarget.Character)
		if kp then
			local _, on = camera:WorldToViewportPoint(kp.Position)
			keep = on and (kp.Position - camera.CFrame.Position).Magnitude <= Settings.MaxDistance
		end
	end
	if not keep then
		local best, bestScore = getBestTarget()
		if best and prev and best ~= prev and Settings.SwitchBias > 0 then
			local cur = candidateScore(prev)
			if cur and bestScore > cur * (1 - Settings.SwitchBias / 100) then best = prev end
		end
		lockedTarget = best
	end
	if lockedTarget ~= prev then lockStart = os.clock() end
	if not lockedTarget then return end

	local part = resolvePart(lockedTarget.Character)
	if not part then lockedTarget = nil return end

	local cf = camera.CFrame
	local dist = (part.Position - cf.Position).Magnitude
	local lead = Settings.Prediction + (Settings.BulletSpeed > 0 and dist / Settings.BulletSpeed or 0)
	local aimPos = part.Position + part.AssemblyLinearVelocity * lead
	if Settings.DropComp and Settings.BulletSpeed > 0 then
		local tt = dist / Settings.BulletSpeed
		aimPos += Vector3.new(0, 0.5 * Workspace.Gravity * tt * tt, 0)
	end
	local goal = CFrame.lookAt(cf.Position, aimPos)
	local angle = math.deg(math.acos(math.clamp(cf.LookVector:Dot(goal.LookVector), -1, 1)))
	if angle <= Settings.Deadzone then return end

	local s = math.clamp(Settings.Smoothness, 0.02, 1)
	local ramp = Settings.RampIn > 0 and math.clamp((os.clock() - lockStart) / (Settings.RampIn / 1000), 0.15, 1) or 1
	local soft = Settings.Soften / 100
	local near = (1 - soft) + soft * math.clamp(angle / 8, 0, 1)   -- gentler when already close
	local alpha = (1 - (1 - s) ^ (dt * 60)) * ramp * near
	local cp, cyaw = cf:ToOrientation()
	local gp, gyaw = goal:ToOrientation()
	local dyaw = (gyaw - cyaw + math.pi) % (2 * math.pi) - math.pi
	local newYaw = cyaw + dyaw * alpha * (Settings.HStrength / 100)
	local newPitch = cp + (gp - cp) * alpha * (Settings.VStrength / 100)
	camera.CFrame = CFrame.new(cf.Position) * CFrame.fromOrientation(newPitch, newYaw, 0)
end)
