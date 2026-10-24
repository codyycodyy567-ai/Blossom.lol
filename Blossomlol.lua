-- Moon Assist (LocalScript) -> StarterPlayer > StarterPlayerScripts
-- Fully client-side: no RemoteEvents, no server scripts.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = Workspace.CurrentCamera

----------------------------------------------------------------
-- SETTINGS (all editable live via _G.MoonAssist)
----------------------------------------------------------------
local Settings = {
	Enabled = false,
	-- aim
	TargetPart = "Head",       -- Head / UpperTorso / Torso / HumanoidRootPart / Auto
	Priority = "Crosshair",    -- Crosshair / Distance / Health
	FOV = 150, MaxDistance = 500,
	Smoothness = 0.2,          -- 1 = snap, lower = smoother (Smoothing slider)
	HStrength = 100, VStrength = 100,
	Deadzone = 0,              -- degrees
	Prediction = 0,            -- seconds of velocity lead
	MouseActiveOnly = true, MoveTimeout = 0.15, MoveThreshold = 1,
	StickyTarget = false,
	TeamCheck = true, WallCheck = true, IgnoreForceField = true,
	-- visuals
	ShowFOV = true, FOVFill = true, FOVThickness = 2,
	FOVColor = Color3.fromRGB(152, 255, 200), UIScale = 100,
	-- ESP (opposing team)
	EnemyESP = false, ESPNames = true, ESPHealth = true, ESPTool = true,
	ESPFill = false, ESPTracers = false, ESPHeadDot = true,
	ESPVisCheck = false, ESPTeamColor = false,
	ESPMaxDistance = 1000, ESPThickness = 2, ESPCorner = 0.3,
}
_G.MoonAssist = Settings

local MENU_KEY = Enum.KeyCode.RightShift
-- Logo: paste a transparent-PNG ID here later and set LOGO_BACKDROP to Color3.fromRGB(28, 28, 34)
local LOGO_ID = "rbxassetid://83544421466497"
local LOGO_BACKDROP = Color3.fromRGB(255, 255, 255)
local PANEL_W, PANEL_H = 960, 540

local COLORS = {}
for _, c in ipairs({
	{ "Mint", 152, 255, 200 }, { "Cyan", 90, 220, 255 }, { "Blue", 90, 160, 255 },
	{ "Purple", 170, 110, 255 }, { "Pink", 255, 130, 200 }, { "Red", 255, 85, 85 },
	{ "Orange", 255, 165, 70 }, { "Gold", 255, 215, 90 }, { "Lime", 170, 255, 90 },
	{ "White", 255, 255, 255 },
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
-- Theme + helpers
----------------------------------------------------------------
local BG         = Color3.fromRGB(12, 12, 16)
local CARD       = Color3.fromRGB(26, 26, 34)
local CARD_HOVER = Color3.fromRGB(37, 37, 48)
local STROKE     = Color3.fromRGB(48, 48, 62)
local TEXT       = Color3.fromRGB(240, 240, 247)
local SUBTEXT    = Color3.fromRGB(135, 135, 152)
local OFF_TRACK  = Color3.fromRGB(56, 56, 70)
local FONT, FONT_MED, FONT_BOLD = Enum.Font.Gotham, Enum.Font.GothamMedium, Enum.Font.GothamBold
local PILL = UDim.new(1, 0)

local function new(class, props, parent)
	local inst = Instance.new(class)
	for k, v in pairs(props) do inst[k] = v end
	inst.Parent = parent
	return inst
end
local function corner(inst, r) return new("UICorner", { CornerRadius = r }, inst) end
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

-- Anything using the accent color registers here so it updates live
local accentFns = {}
local function onAccent(fn) table.insert(accentFns, fn) fn(Settings.FOVColor) end
local function setAccent(c)
	Settings.FOVColor = c
	for _, fn in ipairs(accentFns) do fn(c) end
end

----------------------------------------------------------------
-- FOV circle
----------------------------------------------------------------
local circleGui = new("ScreenGui", { Name = "MoonAssistCircle", ResetOnSpawn = false, IgnoreGuiInset = true }, playerGui)
local circle = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 0.94, BorderSizePixel = 0 }, circleGui)
corner(circle, PILL)
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
local menuGui = new("ScreenGui", { Name = "MoonAssistMenu", ResetOnSpawn = false, DisplayOrder = 10 }, playerGui)
local modal = new("TextButton", { Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, Text = "", Modal = true }, menuGui)

local menuOpen, baseScale, fit = true, 1, 1
local panel = new("CanvasGroup", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(PANEL_W, PANEL_H), BackgroundColor3 = BG, BorderSizePixel = 0, GroupTransparency = 1,
}, menuGui)
corner(panel, UDim.new(0, 24))
local panelStroke = addStroke(panel)
panelStroke.Thickness = 1.5
onAccent(function(c) panelStroke.Color = STROKE:Lerp(c, 0.35) end)
local panelScale = new("UIScale", { Scale = 0.94 }, panel)

-- soft accent glow along the top (rounded to match the panel)
local glow = new("Frame", { Size = UDim2.new(1, 0, 0, 200), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, panel)
corner(glow, UDim.new(0, 24))
new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0.88, 1) }, glow)
onAccent(function(c) glow.BackgroundColor3 = c end)

local function applyScale()
	baseScale = fit * Settings.UIScale / 100
	if menuOpen then panelScale.Scale = baseScale end
end
local function updateFit()
	local vp = camera.ViewportSize
	fit = math.min(1, (vp.X - 40) / PANEL_W, (vp.Y - 40) / PANEL_H)
	applyScale()
end

----------------------------------------------------------------
-- Click effects (ripple, press squish, hover glow)
----------------------------------------------------------------
local function ripple(host, x, y)
	local rel = Vector2.new(x, y) - host.AbsolutePosition
	local r = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(rel.X, rel.Y), Size = UDim2.fromOffset(0, 0),
		BackgroundColor3 = Settings.FOVColor, BackgroundTransparency = 0.7, BorderSizePixel = 0, ZIndex = 5,
	}, host)
	corner(r, PILL)
	local m = math.max(host.AbsoluteSize.X, host.AbsoluteSize.Y) * 2.4
	tween(r, { Size = UDim2.fromOffset(m, m), BackgroundTransparency = 1 }, 0.55)
	task.delay(0.6, function() r:Destroy() end)
end

local function attachFX(row, stroke, onClick)
	local scale = new("UIScale", { Scale = 1 }, row)
	local btn = new("TextButton", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, ZIndex = 10,
	}, row)
	btn.MouseEnter:Connect(function()
		tween(row, { BackgroundColor3 = CARD_HOVER })
		tween(stroke, { Color = Settings.FOVColor, Transparency = 0.55 })
	end)
	btn.MouseLeave:Connect(function()
		tween(row, { BackgroundColor3 = CARD })
		tween(stroke, { Color = STROKE, Transparency = 0 })
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

local function makeRow(parent, order, height, radius)
	local row = new("CanvasGroup", {
		Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = CARD, BorderSizePixel = 0, LayoutOrder = order,
	}, parent)
	corner(row, radius or PILL)
	return row, addStroke(row)
end

----------------------------------------------------------------
-- Header (logo, title, status) + dragging
----------------------------------------------------------------
local header = new("Frame", { Position = UDim2.fromOffset(18, 14), Size = UDim2.new(1, -36, 0, 52), BackgroundTransparency = 1 }, panel)

local logoWrap = new("Frame", { Position = UDim2.fromOffset(0, 4), Size = UDim2.fromOffset(44, 44), BackgroundColor3 = LOGO_BACKDROP, BorderSizePixel = 0 }, header)
corner(logoWrap, PILL)
local logoStroke = new("UIStroke", { Thickness = 2, Transparency = 0.2 }, logoWrap)
onAccent(function(c) logoStroke.Color = c end)
TweenService:Create(logoStroke, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.85 }):Play()
new("ImageLabel", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.82, 0.82),
	BackgroundTransparency = 1, Image = LOGO_ID, ScaleType = Enum.ScaleType.Fit,
}, logoWrap)
new("TextLabel", {
	Position = UDim2.fromOffset(56, 6), Size = UDim2.new(0.5, 0, 0, 24), BackgroundTransparency = 1, Text = "Moon Assist",
	Font = FONT_BOLD, TextSize = 21, TextColor3 = TEXT, TextXAlignment = Enum.TextXAlignment.Left,
}, header)
new("TextLabel", {
	Position = UDim2.fromOffset(56, 31), Size = UDim2.new(0.5, 0, 0, 16), BackgroundTransparency = 1, Text = "Client-side  •  RightShift to hide",
	Font = FONT, TextSize = 11, TextColor3 = SUBTEXT, TextXAlignment = Enum.TextXAlignment.Left,
}, header)

local statusPill = new("Frame", {
	AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(176, 32),
	BackgroundColor3 = CARD, BorderSizePixel = 0,
}, header)
corner(statusPill, PILL)
addStroke(statusPill)
local statusDot = new("Frame", { Position = UDim2.fromOffset(14, 12), Size = UDim2.fromOffset(8, 8), BackgroundColor3 = SUBTEXT, BorderSizePixel = 0 }, statusPill)
corner(statusDot, PILL)
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

new("Frame", { Position = UDim2.fromOffset(18, 72), Size = UDim2.new(1, -36, 0, 1), BackgroundColor3 = STROKE, BorderSizePixel = 0 }, panel)

local dragStart, startPos
header.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
		dragStart, startPos = i.Position, panel.Position
	end
end)
UIS.InputChanged:Connect(function(i)
	if dragStart and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
		local d = i.Position - dragStart
		panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
	end
end)
UIS.InputEnded:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragStart = nil end
end)

----------------------------------------------------------------
-- Components
----------------------------------------------------------------
local function makeSection(parent, order, text)
	local f = new("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = order }, parent)
	local dot = new("Frame", { Position = UDim2.fromOffset(8, 9), Size = UDim2.fromOffset(4, 4), BorderSizePixel = 0 }, f)
	corner(dot, PILL)
	onAccent(function(c) dot.BackgroundColor3 = c end)
	new("TextLabel", {
		Position = UDim2.fromOffset(20, 0), Size = UDim2.new(1, -20, 1, 0), BackgroundTransparency = 1, Text = text,
		Font = FONT_BOLD, TextSize = 11, TextColor3 = SUBTEXT, TextXAlignment = Enum.TextXAlignment.Left,
	}, f)
end

local function makeSwitch(parent, getState)
	local track = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(40, 22),
		BackgroundColor3 = OFF_TRACK, BorderSizePixel = 0,
	}, parent)
	corner(track, PILL)
	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0), Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
	}, track)
	corner(knob, PILL)
	local function refresh(animate)
		local on = getState()
		local pos = on and UDim2.new(0, 21, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
		local col = on and Settings.FOVColor or OFF_TRACK
		if animate then
			tween(knob, { Position = pos }, 0.22, Enum.EasingStyle.Back)
			tween(track, { BackgroundColor3 = col })
			tween(knob, { Size = UDim2.fromOffset(19, 16) }, 0.08)
			task.delay(0.08, function() tween(knob, { Size = UDim2.fromOffset(16, 16) }, 0.15) end)
		else
			knob.Position, track.BackgroundColor3 = pos, col
		end
	end
	onAccent(function() refresh(false) end)
	return refresh
end

local function makeToggle(parent, order, text, key)
	local row, st = makeRow(parent, order, 40)
	new("TextLabel", {
		Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -72, 1, 0), BackgroundTransparency = 1, Text = text,
		Font = FONT_MED, TextSize = 13, TextColor3 = TEXT, TextXAlignment = Enum.TextXAlignment.Left,
	}, row)
	local refresh = makeSwitch(row, function() return Settings[key] end)
	attachFX(row, st, function()
		Settings[key] = not Settings[key]
		refresh(true)
	end)
end

local function makeSlider(parent, order, text, suffix, min, max, initial, onChange)
	local row = new("Frame", { Size = UDim2.new(1, 0, 0, 58), BackgroundColor3 = CARD, BorderSizePixel = 0, LayoutOrder = order }, parent)
	corner(row, UDim.new(0, 20))
	local st = addStroke(row)
	new("TextLabel", {
		Position = UDim2.fromOffset(16, 8), Size = UDim2.new(0.6, -16, 0, 18), BackgroundTransparency = 1, Text = text,
		Font = FONT_MED, TextSize = 13, TextColor3 = TEXT, TextXAlignment = Enum.TextXAlignment.Left,
	}, row)
	local valueLbl = new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 8), Size = UDim2.new(0.4, -16, 0, 18),
		BackgroundTransparency = 1, Text = "", Font = FONT_MED, TextSize = 13, TextColor3 = SUBTEXT, TextXAlignment = Enum.TextXAlignment.Right,
	}, row)
	local hit = new("Frame", { Position = UDim2.fromOffset(16, 32), Size = UDim2.new(1, -32, 0, 20), BackgroundTransparency = 1 }, row)
	local track = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.new(1, 0, 0, 6),
		BackgroundColor3 = OFF_TRACK, BorderSizePixel = 0,
	}, hit)
	corner(track, PILL)
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Settings.FOVColor, BorderSizePixel = 0 }, track)
	corner(fill, PILL)
	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
	}, track)
	corner(knob, PILL)
	local glowS = new("UIStroke", { Thickness = 0, Transparency = 0.55 }, knob)
	onAccent(function(c) fill.BackgroundColor3 = c glowS.Color = c end)

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
			tween(knob, { Size = UDim2.fromOffset(18, 18) }, 0.1)
			tween(glowS, { Thickness = 6 }, 0.15)
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
			tween(knob, { Size = UDim2.fromOffset(14, 14) }, 0.1)
			tween(glowS, { Thickness = 0 }, 0.15)
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

	-- chevron drawn from two small bars (no font glyph needed)
	local chev = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(14, 14), BackgroundTransparency = 1,
	}, head)
	for _, side in ipairs({ -1, 1 }) do
		local arm = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5 + side * -0.18, 0, 0.5, 0), Size = UDim2.fromOffset(8, 2),
			Rotation = side * -45, BackgroundColor3 = SUBTEXT, BorderSizePixel = 0,
		}, chev)
		corner(arm, PILL)
	end

	local valueLbl = new("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, hasColor and -54 or -38, 0.5, 0), Size = UDim2.new(0.6, -40, 1, 0),
		BackgroundTransparency = 1, Text = "", Font = FONT, TextSize = 12, TextColor3 = SUBTEXT, TextXAlignment = Enum.TextXAlignment.Right,
	}, head)
	local headDot
	if hasColor then
		headDot = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -38, 0.5, 0), Size = UDim2.fromOffset(12, 12), BorderSizePixel = 0 }, head)
		corner(headDot, PILL)
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
			local d = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = it.color, BorderSizePixel = 0 }, r)
			corner(d, PILL)
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
end

----------------------------------------------------------------
-- Columns (everything on one screen, no tabs)
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

local function build(parent, items)
	for i, it in ipairs(items) do
		if it.t == "section" then makeSection(parent, i, it.text)
		elseif it.t == "toggle" then makeToggle(parent, i, it.text, it.key)
		elseif it.t == "presets" then makePresets(parent, i)
		elseif it.t == "slider" then
			local scale = it.scale or 1
			local get = it.get or function() return Settings[it.key] / scale end
			local set = it.set or function(v) Settings[it.key] = v * scale end
			setters[it.id or it.key] = makeSlider(parent, i, it.text, it.suffix or "", it.min, it.max, get(), set)
		elseif it.t == "drop" then
			local idx = 1
			for n, d in ipairs(it.items) do if d.value == Settings[it.key] then idx = n end end
			makeDropdown(parent, i, it.text, it.items, idx, function(d)
				if it.set then it.set(d.value) else Settings[it.key] = d.value end
			end)
		end
	end
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
		{ t = "section", text = "MOTION" },
		{ t = "slider", id = "Smoothing", text = "Smoothing", min = 0, max = 100,
			get = function() return math.floor((1 - Settings.Smoothness) * 100 + 0.5) end,
			set = function(v) Settings.Smoothness = math.max(0.02, 1 - v / 100) end },
		{ t = "slider", text = "Horizontal strength", key = "HStrength", min = 0, max = 100, suffix = "%" },
		{ t = "slider", text = "Vertical strength", key = "VStrength", min = 0, max = 100, suffix = "%" },
		{ t = "slider", text = "Deadzone", key = "Deadzone", min = 0, max = 10, suffix = "°" },
		{ t = "slider", text = "Prediction", key = "Prediction", scale = 0.001, min = 0, max = 250, suffix = " ms" },
	} },
	{ title = "Enemy ESP", master = "EnemyESP", items = {
		{ t = "section", text = "BRACKETS" },
		{ t = "slider", text = "Corner length", key = "ESPCorner", scale = 0.01, min = 10, max = 50, suffix = "%" },
		{ t = "slider", text = "Thickness", key = "ESPThickness", min = 1, max = 4, suffix = "px" },
		{ t = "toggle", text = "Box fill", key = "ESPFill" },
		{ t = "toggle", text = "Use team colors", key = "ESPTeamColor" },
		{ t = "toggle", text = "Dim behind walls", key = "ESPVisCheck" },
		{ t = "section", text = "INFO" },
		{ t = "toggle", text = "Name + distance", key = "ESPNames" },
		{ t = "toggle", text = "Health bar", key = "ESPHealth" },
		{ t = "toggle", text = "Held item", key = "ESPTool" },
		{ t = "toggle", text = "Head dot", key = "ESPHeadDot" },
		{ t = "toggle", text = "Tracers", key = "ESPTracers" },
		{ t = "slider", text = "Max distance", key = "ESPMaxDistance", min = 100, max = 3000, suffix = " studs" },
	} },
	{ title = "Filters & visuals", items = {
		{ t = "section", text = "ACTIVATION" },
		{ t = "toggle", text = "Only while mouse moves", key = "MouseActiveOnly" },
		{ t = "slider", text = "Activity window", key = "MoveTimeout", scale = 0.001, min = 50, max = 500, suffix = " ms" },
		{ t = "section", text = "FILTERS" },
		{ t = "toggle", text = "Team check", key = "TeamCheck" },
		{ t = "toggle", text = "Wall check", key = "WallCheck" },
		{ t = "toggle", text = "Ignore forcefields", key = "IgnoreForceField" },
		{ t = "section", text = "FOV CIRCLE" },
		{ t = "toggle", text = "Show FOV circle", key = "ShowFOV" },
		{ t = "toggle", text = "Circle fill", key = "FOVFill" },
		{ t = "slider", text = "Circle thickness", key = "FOVThickness", min = 1, max = 6, suffix = "px" },
		{ t = "section", text = "THEME" },
		{ t = "drop", text = "Accent color", key = "FOVColor", items = COLORS, set = setAccent },
		{ t = "slider", text = "Menu scale", key = "UIScale", min = 70, max = 130, suffix = "%",
			set = function(v) Settings.UIScale = v applyScale() end },
	} },
}

local body = new("Frame", { Position = UDim2.fromOffset(18, 84), Size = UDim2.new(1, -36, 1, -102), BackgroundTransparency = 1 }, panel)
new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }, body)

for ci, colDef in ipairs(COLUMNS) do
	local col = new("Frame", { Size = UDim2.new(1 / 3, -8, 1, 0), BackgroundTransparency = 1, LayoutOrder = ci }, body)

	-- column header pill (with its own master switch where it has one)
	local hrow, hst = makeRow(col, 1, 42)
	new("TextLabel", {
		Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -72, 1, 0), BackgroundTransparency = 1, Text = colDef.title,
		Font = FONT_BOLD, TextSize = 14, TextColor3 = TEXT, TextXAlignment = Enum.TextXAlignment.Left,
	}, hrow)
	if colDef.master then
		local key = colDef.master
		local refresh = makeSwitch(hrow, function() return Settings[key] end)
		attachFX(hrow, hst, function()
			Settings[key] = not Settings[key]
			refresh(true)
		end)
	end

	local scroll = new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 1, -52), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 3, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y,
	}, col)
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)
	padding(scroll, 0, 8, 2, 14)
	onAccent(function(c) scroll.ScrollBarImageColor3 = c end)
	build(scroll, colDef.items)
end

-- Open / close
local function setMenuOpen(open)
	menuOpen = open
	modal.Modal = open
	if open then
		panel.Visible = true
		tween(panel, { GroupTransparency = 0 }, 0.25)
		tween(panelScale, { Scale = baseScale }, 0.35, Enum.EasingStyle.Back)
	else
		tween(panel, { GroupTransparency = 1 }, 0.2)
		tween(panelScale, { Scale = baseScale * 0.94 }, 0.2)
		task.delay(0.2, function() if not menuOpen then panel.Visible = false end end)
	end
end
UIS.InputBegan:Connect(function(i, processed)
	if not processed and i.KeyCode == MENU_KEY then setMenuOpen(not menuOpen) end
end)
camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateFit)
updateFit()
setMenuOpen(true)

----------------------------------------------------------------
-- Targeting helpers
----------------------------------------------------------------
local PART_LIST = { "Head", "UpperTorso", "Torso", "HumanoidRootPart" }

local function isEnemy(plr)
	if plr == player then return false end
	if plr.Team == nil or player.Team == nil then return true end
	return plr.Team ~= player.Team
end

local function clearLine(part)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, part.Parent }
	local o = camera.CFrame.Position
	return Workspace:Raycast(o, part.Position - o, params) == nil
end
local function isVisible(part) return not Settings.WallCheck or clearLine(part) end

local function getAimPart(char)
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

local function isValid(plr)
	if plr == player then return false end
	if Settings.TeamCheck and plr.Team ~= nil and plr.Team == player.Team then return false end
	local char = plr.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return false end
	if Settings.IgnoreForceField and char:FindFirstChildOfClass("ForceField") then return false end
	return getAimPart(char) ~= nil
end

local function candidateScore(plr)
	if not isValid(plr) then return nil end
	local part = getAimPart(plr.Character)
	local dist = (part.Position - camera.CFrame.Position).Magnitude
	if dist > Settings.MaxDistance then return nil end
	local sp, on = camera:WorldToViewportPoint(part.Position)
	if not on then return nil end
	local d = (Vector2.new(sp.X, sp.Y) - camera.ViewportSize / 2).Magnitude
	if d > Settings.FOV or not isVisible(part) then return nil end
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
	return best
end

----------------------------------------------------------------
-- Enemy ESP: corner brackets built from GUI frames
----------------------------------------------------------------
local espGui = new("ScreenGui", { Name = "MoonAssistESP", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 5 }, playerGui)
local espObjs = {}

local function createESP(plr)
	local holder = new("Frame", { Name = plr.Name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false }, espGui)
	local o = { holder = holder, lines = {} }
	o.fill = new("Frame", { BorderSizePixel = 0, BackgroundTransparency = 0.88 }, holder)
	o.tracer = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0, BackgroundTransparency = 0.4 }, holder)
	for i = 1, 8 do o.lines[i] = new("Frame", { BorderSizePixel = 0 }, holder) end
	o.name = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(0, 14), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1,
		Font = FONT_BOLD, TextSize = 12, TextStrokeTransparency = 0.4, TextStrokeColor3 = Color3.new(0, 0, 0), Text = "",
	}, holder)
	o.tool = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(0, 12), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1,
		Font = FONT_MED, TextSize = 11, TextStrokeTransparency = 0.5, TextStrokeColor3 = Color3.new(0, 0, 0), Text = "",
	}, holder)
	o.hpBg = new("Frame", { BorderSizePixel = 0, BackgroundColor3 = Color3.fromRGB(10, 10, 12), BackgroundTransparency = 0.3 }, holder)
	o.hpFill = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0 }, o.hpBg)
	o.dot = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(6, 6), BorderSizePixel = 0 }, holder)
	corner(o.dot, PILL)
	espObjs[plr] = o
	return o
end

Players.PlayerRemoving:Connect(function(plr)
	if espObjs[plr] then espObjs[plr].holder:Destroy() espObjs[plr] = nil end
end)

local function place(f, x, y, w, h, c)
	f.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
	f.Size = UDim2.fromOffset(math.max(1, math.floor(w)), math.max(1, math.floor(h)))
	f.BackgroundColor3 = c
end

local function updateESP()
	camera = Workspace.CurrentCamera
	local vp = camera.ViewportSize
	for _, plr in ipairs(Players:GetPlayers()) do
		local o, show = espObjs[plr], false
		if Settings.EnemyESP and isEnemy(plr) then
			local char = plr.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if hum and root and hum.Health > 0 then
				local dist = (root.Position - camera.CFrame.Position).Magnitude
				local top = camera:WorldToViewportPoint(root.Position + Vector3.new(0, 2.7, 0))
				local bot = camera:WorldToViewportPoint(root.Position - Vector3.new(0, 3.1, 0))
				if dist <= Settings.ESPMaxDistance and top.Z > 0 and bot.Z > 0 then
					show = true
					o = o or createESP(plr)
					local h = math.abs(bot.Y - top.Y)
					local w = h * 0.6
					local x, y, t = top.X - w / 2, top.Y, Settings.ESPThickness
					local aw = math.max(4, w * Settings.ESPCorner)
					local ah = math.max(4, h * Settings.ESPCorner * 0.7)

					local color = (Settings.ESPTeamColor and plr.Team ~= nil) and plr.TeamColor.Color or Settings.FOVColor
					if Settings.ESPVisCheck and not clearLine(root) then
						color = color:Lerp(Color3.fromRGB(90, 90, 100), 0.6)
					end

					local L = o.lines
					place(L[1], x, y, aw, t, color)                   place(L[2], x, y, t, ah, color)
					place(L[3], x + w - aw, y, aw, t, color)          place(L[4], x + w - t, y, t, ah, color)
					place(L[5], x, y + h - t, aw, t, color)           place(L[6], x, y + h - ah, t, ah, color)
					place(L[7], x + w - aw, y + h - t, aw, t, color)  place(L[8], x + w - t, y + h - ah, t, ah, color)

					o.fill.Visible = Settings.ESPFill
					if Settings.ESPFill then place(o.fill, x, y, w, h, color) end

					o.name.Visible = Settings.ESPNames
					if Settings.ESPNames then
						o.name.Text = plr.DisplayName .. "  " .. math.floor(dist) .. "m"
						o.name.Position = UDim2.fromOffset(math.floor(top.X), math.floor(y - 3))
						o.name.TextColor3 = color
					end

					local tool = char:FindFirstChildOfClass("Tool")
					o.tool.Visible = Settings.ESPTool and tool ~= nil
					if o.tool.Visible then
						o.tool.Text = tool.Name
						o.tool.Position = UDim2.fromOffset(math.floor(top.X), math.floor(y + h + 3))
						o.tool.TextColor3 = color
					end

					o.hpBg.Visible = Settings.ESPHealth
					if Settings.ESPHealth then
						local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
						o.hpBg.Position = UDim2.fromOffset(math.floor(x - 7), math.floor(y))
						o.hpBg.Size = UDim2.fromOffset(3, math.max(1, math.floor(h)))
						o.hpFill.Size = UDim2.new(1, 0, pct, 0)
						o.hpFill.BackgroundColor3 = Color3.fromRGB(255, 60, 60):Lerp(Color3.fromRGB(80, 255, 120), pct)
					end

					o.dot.Visible = false
					local head = char:FindFirstChild("Head")
					if Settings.ESPHeadDot and head then
						local hp = camera:WorldToViewportPoint(head.Position)
						if hp.Z > 0 then
							o.dot.Visible = true
							o.dot.Position = UDim2.fromOffset(math.floor(hp.X), math.floor(hp.Y))
							o.dot.BackgroundColor3 = color
						end
					end

					o.tracer.Visible = Settings.ESPTracers
					if Settings.ESPTracers then
						local fx, fy = vp.X / 2, vp.Y
						local dx, dy = top.X - fx, (y + h) - fy
						o.tracer.Position = UDim2.fromOffset(fx + dx / 2, fy + dy / 2)
						o.tracer.Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy), 1.5)
						o.tracer.Rotation = math.deg(math.atan2(dy, dx))
						o.tracer.BackgroundColor3 = color
					end
				end
			end
		end
		if o then o.holder.Visible = show end
	end
end
RunService:BindToRenderStep("MoonAssistESP", Enum.RenderPriority.Camera.Value + 2, updateESP)

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
local lockedTarget = nil

RunService:BindToRenderStep("MoonAssist", Enum.RenderPriority.Camera.Value + 1, function(dt)
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

	-- Sticky: hold the target while it stays valid, on screen, in range and visible
	local keep = false
	if Settings.StickyTarget and lockedTarget and isValid(lockedTarget) then
		local kp = getAimPart(lockedTarget.Character)
		local _, on = camera:WorldToViewportPoint(kp.Position)
		keep = on and (kp.Position - camera.CFrame.Position).Magnitude <= Settings.MaxDistance and isVisible(kp)
	end
	if not keep then lockedTarget = getBestTarget() end
	if not lockedTarget then return end

	local part = getAimPart(lockedTarget.Character)
	if not part then lockedTarget = nil return end

	local cf = camera.CFrame
	local goal = CFrame.lookAt(cf.Position, part.Position + part.AssemblyLinearVelocity * Settings.Prediction)
	local angle = math.deg(math.acos(math.clamp(cf.LookVector:Dot(goal.LookVector), -1, 1)))
	if angle <= Settings.Deadzone then return end

	-- Frame-rate independent smoothing, with separate yaw / pitch strength
	local s = math.clamp(Settings.Smoothness, 0.02, 1)
	local alpha = 1 - (1 - s) ^ (dt * 60)
	local cp, cyaw = cf:ToOrientation()
	local gp, gyaw = goal:ToOrientation()
	local dyaw = (gyaw - cyaw + math.pi) % (2 * math.pi) - math.pi
	local newYaw = cyaw + dyaw * alpha * (Settings.HStrength / 100)
	local newPitch = cp + (gp - cp) * alpha * (Settings.VStrength / 100)
	camera.CFrame = CFrame.new(cf.Position) * CFrame.fromOrientation(newPitch, newYaw, 0)
end) 
