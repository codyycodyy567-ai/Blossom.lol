
--[[
    BLOSSOM VISUALS
    Pink aesthetic | Client-side | Roblox Studio
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Clean up previous version
local old = playerGui:FindFirstChild("BlossomVisuals")
if old then old:Destroy() end

-- Theme
local PINK = Color3.fromRGB(255, 145, 195)
local LIGHT_PINK = Color3.fromRGB(255, 210, 230)
local WHITE = Color3.fromRGB(255, 245, 250)
local DARK = Color3.fromRGB(48, 29, 43)

-- Main GUI
local gui = Instance.new("ScreenGui")
gui.Name = "BlossomVisuals"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

-- Soft pink color correction
local color = Instance.new("ColorCorrectionEffect")
color.Name = "BlossomColor"
color.TintColor = Color3.fromRGB(255, 237, 247)
color.Saturation = 0.08
color.Brightness = 0.02
color.Parent = Lighting

-- Main panel
local panel = Instance.new("Frame")
panel.Name = "MainPanel"
panel.Size = UDim2.fromOffset(245, 150)
panel.Position = UDim2.new(0, 24, 0.35, 0)
panel.BackgroundColor3 = DARK
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel = 0
panel.Parent = gui

Instance.new("UICorner", panel).CornerRadius =
    UDim.new(0, 16)

local stroke = Instance.new("UIStroke")
stroke.Color = PINK
stroke.Thickness = 1.5
stroke.Transparency = 0.15
stroke.Parent = panel

local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(67, 39, 57)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(34, 27, 42))
})
gradient.Rotation = 35
gradient.Parent = panel

-- Header
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -24, 0, 35)
title.Position = UDim2.fromOffset(14, 8)
title.BackgroundTransparency = 1
title.Text = "✿  BLOSSOM"
title.TextColor3 = LIGHT_PINK
title.TextSize = 21
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, -28, 0, 20)
subtitle.Position = UDim2.fromOffset(14, 42)
subtitle.BackgroundTransparency = 1
subtitle.Text = "P I N K   V I S U A L S"
subtitle.TextColor3 = WHITE
subtitle.TextTransparency = 0.2
subtitle.TextSize = 10
subtitle.Font = Enum.Font.GothamMedium
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = panel

-- Petal toggle
local enabled = true

local toggle = Instance.new("TextButton")
toggle.Size = UDim2.new(1, -28, 0, 38)
toggle.Position = UDim2.fromOffset(14, 72)
toggle.BackgroundColor3 = PINK
toggle.TextColor3 = DARK
toggle.Text = "✿   PETALS: ON"
toggle.TextSize = 13
toggle.Font = Enum.Font.GothamBold
toggle.AutoButtonColor = true
toggle.Parent = panel

Instance.new("UICorner", toggle).CornerRadius =
    UDim.new(0, 10)

-- Footer
local footer = Instance.new("TextLabel")
footer.Size = UDim2.new(1, -28, 0, 18)
footer.Position = UDim2.fromOffset(14, 120)
footer.BackgroundTransparency = 1
footer.Text = "made with love & blossoms"
footer.TextColor3 = LIGHT_PINK
footer.TextTransparency = 0.25
footer.TextSize = 10
footer.Font = Enum.Font.Gotham
footer.TextXAlignment = Enum.TextXAlignment.Left
footer.Parent = panel

-- Toggle visual effect
toggle.MouseButton1Click:Connect(function()
    enabled = not enabled
    toggle.Text = enabled and
        "✿   PETALS: ON" or "✿   PETALS: OFF"

    toggle.BackgroundColor3 = enabled and
        PINK or Color3.fromRGB(105, 79, 96)
end)

-- Floating blossom particles
local petals = Instance.new("Frame")
petals.Name = "PetalLayer"
petals.Size = UDim2.fromScale(1, 1)
petals.BackgroundTransparency = 1
petals.ClipsDescendants = true
petals.ZIndex = 5
petals.Parent = gui

local function makePetal()
    local petal = Instance.new("TextLabel")
    petal.Name = "BlossomPetal"
    petal.BackgroundTransparency = 1
    petal.Text = math.random(1, 2) == 1 and "✿" or "❀"
    petal.TextColor3 = math.random(1, 2) == 1
        and PINK or LIGHT_PINK
    petal.TextTransparency = math.random(0, 35) / 100
    petal.TextScaled = true
    petal.Font = Enum.Font.Gotham
    petal.Size = UDim2.fromOffset(
        math.random(14, 25),
        math.random(14, 25)
    )
    petal.Position = UDim2.fromScale(
        math.random(0, 100) / 100, -0.08
    )
    petal.Rotation = math.random(0, 360)
    petal.ZIndex = 6
    petal.Parent = petals

    local duration = math.random(7, 14)
    local destination = UDim2.fromScale(
        math.clamp(petal.Position.X.Scale
            + math.random(-20, 20) / 100, 0, 1),
        1.1
    )

    local tween = TweenService:Create(
        petal,
        TweenInfo.new(
            duration,
            Enum.EasingStyle.Linear,
            Enum.EasingDirection.InOut
        ),
        {
            Position = destination,
            Rotation = petal.Rotation
                + math.random(180, 540),
            TextTransparency = 1
        }
    )

    tween:Play()
    tween.Completed:Once(function()
        petal:Destroy()
    end)
end

-- Generate petals at a controlled rate
task.spawn(function()
    while gui.Parent do
        if enabled then
            makePetal()
        end
        task.wait(0.35)
    end
end)

-- Gentle panel glow
task.spawn(function()
    while panel.Parent do
        TweenService:Create(
            stroke,
            TweenInfo.new(1.8, Enum.EasingStyle.Sine),
            {Transparency = 0.55}
        ):Play()
        task.wait(1.8)

        if not panel.Parent then break end

        TweenService:Create(
            stroke,
            TweenInfo.new(1.8, Enum.EasingStyle.Sine),
            {Transparency = 0.12}
        ):Play()
        task.wait(1.8)
    end
end)

print("[Blossom] Pink visuals loaded successfully!")
