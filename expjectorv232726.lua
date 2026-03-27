-- ExpJector V2 @qcbg 


local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- ============================================================
-- STATE
-- ============================================================
local state = {
	bhop        = false,
	highJump    = false,
	noclip      = false,
	fullbright  = false,
	showFPS     = false,
	autoSprint  = false,
	speedometer = false,
	draggable   = false,
	esp         = false,
	fly         = false,
	spinbot     = false,
	spinbot2    = false,
	upsidedown  = false,
	triggerbot  = false,
	espboxes    = false,
	aimbot      = false,
	aimbotfov   = false,
	teamcheck   = false,   -- NEW: skip teammates in all aim/esp features
}

-- ============================================================
-- TEAM CHECK HELPER
-- Returns true if plr is on the same team as the local player
-- ============================================================
local function isSameTeam(plr)
	if not state.teamcheck then return false end
	-- Roblox Teams: player.Team is a Team object or nil
	local myTeam = player.Team
	if myTeam == nil then return false end
	return plr.Team == myTeam
end

-- ============================================================
-- KEYBIND SYSTEM
-- ============================================================
-- Keybind table: maps action name → current KeyCode / UserInputType
local keybinds = {
	aimbot    = { type = "mouse",    value = Enum.UserInputType.MouseButton2,  label = "RMB"    },
	triggerbot = { type = "key",    value = Enum.KeyCode.Unknown,              label = "MOUSE1" },
}
-- triggerbot fires on crosshair hit, no key required — label is info only

-- ============================================================
-- BHOP SETTINGS
-- ============================================================
local BHOP_MAX_SPEED = 45
local BHOP_ACCEL     = 4
local BHOP_FRICTION  = 0.85
local wasInAir       = false

-- ============================================================
-- FLY SETTINGS
-- ============================================================
local FLY_SPEED       = 50
local flyBodyVelocity = nil
local flyBodyGyro     = nil

local function startFly()
	local char = player.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local bv = Instance.new("BodyVelocity")
	bv.Name = "FlyVelocity"
	bv.Velocity = Vector3.new(0,0,0)
	bv.MaxForce = Vector3.new(1e5,1e5,1e5)
	bv.Parent = hrp
	flyBodyVelocity = bv
	local bg = Instance.new("BodyGyro")
	bg.Name = "FlyGyro"
	bg.MaxTorque = Vector3.new(1e5,1e5,1e5)
	bg.P = 1e4
	bg.CFrame = hrp.CFrame
	bg.Parent = hrp
	flyBodyGyro = bg
end

local function stopFly()
	if flyBodyVelocity then flyBodyVelocity:Destroy() flyBodyVelocity = nil end
	if flyBodyGyro     then flyBodyGyro:Destroy()     flyBodyGyro     = nil end
	local char = player.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then hum.PlatformStand = false end
	end
end

-- ============================================================
-- SPINBOT SETTINGS
-- ============================================================
local SPIN_SPEED  = 10
local spinAccum   = 0
local spinPitch   = 0
local spinRoll    = 0
local SPIN2_SPEED = 10
local spinAccum2  = 0

-- ============================================================
-- AIMBOT SETTINGS
-- ============================================================
local AIMBOT_SMOOTH  = 0.18
local AIMBOT_FOV     = 150
local AIMBOT_HITBOX  = "Head"   -- changed by hitbox selector

-- Hitbox options + their part names in a Roblox R6/R15 character
local HITBOX_OPTIONS = {
	{ label = "Head",        part = "Head"          },
	{ label = "Torso",       part = "Torso"         },   -- R6; R15 uses UpperTorso
	{ label = "Upper Torso", part = "UpperTorso"    },
	{ label = "Lower Torso", part = "LowerTorso"    },
	{ label = "Left Arm",    part = "Left Arm"      },
	{ label = "Right Arm",   part = "Right Arm"     },
	{ label = "Left Leg",    part = "Left Leg"      },
	{ label = "Right Leg",   part = "Right Leg"     },
	{ label = "HRP",         part = "HumanoidRootPart" },
}

-- Helper: get the best available part on a character for the selected hitbox
local function getHitboxPart(char)
	local selected = AIMBOT_HITBOX
	-- Try exact match first, then fallback
	local fallbacks = {
		"Head", "UpperTorso", "Torso", "HumanoidRootPart"
	}
	local part = char:FindFirstChild(selected)
	if part then return part end
	for _, fb in ipairs(fallbacks) do
		part = char:FindFirstChild(fb)
		if part then return part end
	end
	return nil
end

-- ============================================================
-- TRIGGERBOT SETTINGS
-- ============================================================
local TRIGGER_DELAY   = 0.05
local triggerCooldown = false

-- ============================================================
-- GUI SETUP
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ModMenu"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = player.PlayerGui

-- ============================================================
-- WELCOME POPUP
-- ============================================================
local popupBg = Instance.new("Frame")
popupBg.Size = UDim2.new(1,0,1,0)
popupBg.BackgroundTransparency = 1
popupBg.BorderSizePixel = 0
popupBg.ZIndex = 100
popupBg.Parent = screenGui

local popupCard = Instance.new("Frame")
popupCard.Size = UDim2.new(0,340,0,200)
popupCard.Position = UDim2.new(0.5,-170,0.5,-100)
popupCard.BackgroundColor3 = Color3.fromRGB(12,12,12)
popupCard.BorderSizePixel = 0
popupCard.ZIndex = 101
popupCard.Parent = popupBg
Instance.new("UICorner",popupCard).CornerRadius = UDim.new(0,10)

local readHeader = Instance.new("Frame")
readHeader.Size = UDim2.new(1,0,0,44)
readHeader.BackgroundColor3 = Color3.fromRGB(200,40,40)
readHeader.BorderSizePixel = 0
readHeader.ZIndex = 102
readHeader.Parent = popupCard
Instance.new("UICorner",readHeader).CornerRadius = UDim.new(0,10)

local headerFix = Instance.new("Frame")
headerFix.Size = UDim2.new(1,0,0,10)
headerFix.Position = UDim2.new(0,0,1,-10)
headerFix.BackgroundColor3 = Color3.fromRGB(200,40,40)
headerFix.BorderSizePixel = 0
headerFix.ZIndex = 102
headerFix.Parent = readHeader

local readLabel = Instance.new("TextLabel")
readLabel.Size = UDim2.new(1,0,1,0)
readLabel.BackgroundTransparency = 1
readLabel.Text = "READ!"
readLabel.TextColor3 = Color3.fromRGB(255,255,255)
readLabel.TextSize = 22
readLabel.Font = Enum.Font.GothamBold
readLabel.ZIndex = 103
readLabel.Parent = readHeader

local infoBox = Instance.new("Frame")
infoBox.Size = UDim2.new(1,-28,0,72)
infoBox.Position = UDim2.new(0,14,0,54)
infoBox.BackgroundColor3 = Color3.fromRGB(22,22,22)
infoBox.BorderSizePixel = 0
infoBox.ZIndex = 102
infoBox.Parent = popupCard
Instance.new("UICorner",infoBox).CornerRadius = UDim.new(0,7)

local infoText = Instance.new("TextLabel")
infoText.Size = UDim2.new(1,-16,1,0)
infoText.Position = UDim2.new(0,8,0,0)
infoText.BackgroundTransparency = 1
infoText.Text = "The keybind to open/close the menu is INSERT.\n\nThis script is still buggy — expect issues!"
infoText.TextColor3 = Color3.fromRGB(200,200,200)
infoText.TextSize = 12
infoText.Font = Enum.Font.Gotham
infoText.TextWrapped = true
infoText.TextXAlignment = Enum.TextXAlignment.Left
infoText.TextYAlignment = Enum.TextYAlignment.Center
infoText.ZIndex = 103
infoText.Parent = infoBox

local understandBtn = Instance.new("TextButton")
understandBtn.Size = UDim2.new(1,-28,0,36)
understandBtn.Position = UDim2.new(0,14,0,138)
understandBtn.BackgroundColor3 = Color3.fromRGB(255,255,255)
understandBtn.Text = "I Understand"
understandBtn.TextColor3 = Color3.fromRGB(10,10,10)
understandBtn.TextSize = 14
understandBtn.Font = Enum.Font.GothamBold
understandBtn.BorderSizePixel = 0
understandBtn.ZIndex = 102
understandBtn.Parent = popupCard
Instance.new("UICorner",understandBtn).CornerRadius = UDim.new(0,7)

-- ============================================================
-- MAIN WINDOW
-- ============================================================
local window = Instance.new("Frame")
window.Name = "Window"
window.Size = UDim2.new(0,320,0,440)
window.Position = UDim2.new(0.5,-160,0.5,-220)
window.BackgroundColor3 = Color3.fromRGB(10,10,10)
window.BorderSizePixel = 0
window.Active = true
window.Draggable = false
window.Visible = false
window.Parent = screenGui
Instance.new("UICorner",window).CornerRadius = UDim.new(0,8)

understandBtn.MouseButton1Click:Connect(function()
	TweenService:Create(popupCard,TweenInfo.new(0.25),{
		BackgroundTransparency=1,
		Position=UDim2.new(0.5,-170,0.45,-100)
	}):Play()
	task.wait(0.28)
	popupBg:Destroy()
	window.Visible = true
end)

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1,0,0,36)
titleBar.BackgroundColor3 = Color3.fromRGB(20,20,20)
titleBar.BorderSizePixel = 0
titleBar.Parent = window
Instance.new("UICorner",titleBar).CornerRadius = UDim.new(0,8)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1,-40,1,0)
titleLabel.Position = UDim2.new(0,12,0,0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "✦  EXPJECTOR"
titleLabel.TextColor3 = Color3.fromRGB(255,255,255)
titleLabel.TextSize = 14
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

-- Rainbow hue cycle for the title
local rainbowHue = 0
RunService.Heartbeat:Connect(function(dt)
	rainbowHue = (rainbowHue + dt * 0.35) % 1
	titleLabel.TextColor3 = Color3.fromHSV(rainbowHue, 1, 1)
end)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0,28,0,28)
closeBtn.Position = UDim2.new(1,-34,0,4)
closeBtn.BackgroundColor3 = Color3.fromRGB(40,40,40)
closeBtn.Text = "−"
closeBtn.TextColor3 = Color3.fromRGB(200,200,200)
closeBtn.TextSize = 18
closeBtn.Font = Enum.Font.GothamBold
closeBtn.BorderSizePixel = 0
closeBtn.Parent = titleBar
Instance.new("UICorner",closeBtn).CornerRadius = UDim.new(0,6)

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.new(1,0,0,32)
tabBar.Position = UDim2.new(0,0,0,36)
tabBar.BackgroundColor3 = Color3.fromRGB(15,15,15)
tabBar.BorderSizePixel = 0
tabBar.Parent = window
local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0,1)
tabLayout.Parent = tabBar

local contentFrame = Instance.new("Frame")
contentFrame.Size = UDim2.new(1,0,1,-68)
contentFrame.Position = UDim2.new(0,0,0,68)
contentFrame.BackgroundTransparency = 1
contentFrame.Parent = window

-- ============================================================
-- INSERT + CLOSE
-- ============================================================
local menuVisible = true
local function toggleMenu()
	menuVisible = not menuVisible
	window.Visible = menuVisible
	closeBtn.Text = menuVisible and "−" or "+"
end
closeBtn.MouseButton1Click:Connect(toggleMenu)
UserInputService.InputBegan:Connect(function(input,gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.Insert then toggleMenu() end
end)

-- ============================================================
-- TABS
-- ============================================================
local ACCENT = Color3.fromRGB(100,180,255)
local tabs = {"Aim","Movement","Visual","Other","Fun","TP To","Keybinds"}
local tabButtons = {}
local tabPages   = {}

local function setActiveTab(name)
	for _,t in pairs(tabs) do
		tabButtons[t].BackgroundColor3 = (t==name) and Color3.fromRGB(25,25,25) or Color3.fromRGB(15,15,15)
		tabButtons[t].TextColor3       = (t==name) and ACCENT or Color3.fromRGB(140,140,140)
		tabPages[t].Visible = (t==name)
	end
end

for _,name in ipairs(tabs) do
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0,40,1,0)
	btn.BackgroundColor3 = Color3.fromRGB(15,15,15)
	btn.Text = name
	btn.TextColor3 = Color3.fromRGB(140,140,140)
	btn.TextSize = 10
	btn.Font = Enum.Font.GothamSemibold
	btn.BorderSizePixel = 0
	btn.Parent = tabBar
	tabButtons[name] = btn

	local page = Instance.new("ScrollingFrame")
	page.Size = UDim2.new(1,0,1,0)
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 3
	page.ScrollBarImageColor3 = ACCENT
	page.CanvasSize = UDim2.new(0,0,0,0)
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.Visible = false
	page.Parent = contentFrame
	tabPages[name] = page

	Instance.new("UIListLayout",page).Padding = UDim.new(0,6)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop   = UDim.new(0,10)
	pad.PaddingLeft  = UDim.new(0,12)
	pad.PaddingRight = UDim.new(0,12)
	pad.Parent = page

	btn.MouseButton1Click:Connect(function() setActiveTab(name) end)
end

-- ============================================================
-- TOGGLE WIDGET
-- ============================================================
local function addToggle(page,label,description,stateKey,callback)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1,0,0,52)
	row.BackgroundColor3 = Color3.fromRGB(20,20,20)
	row.BorderSizePixel = 0
	row.Parent = page
	Instance.new("UICorner",row).CornerRadius = UDim.new(0,6)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1,-60,0,20)
	lbl.Position = UDim2.new(0,12,0,8)
	lbl.BackgroundTransparency = 1
	lbl.Text = label
	lbl.TextColor3 = Color3.fromRGB(230,230,230)
	lbl.TextSize = 13
	lbl.Font = Enum.Font.GothamSemibold
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = row

	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1,-60,0,16)
	desc.Position = UDim2.new(0,12,0,28)
	desc.BackgroundTransparency = 1
	desc.Text = description
	desc.TextColor3 = Color3.fromRGB(100,100,100)
	desc.TextSize = 11
	desc.Font = Enum.Font.Gotham
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.Parent = row

	local track = Instance.new("Frame")
	track.Size = UDim2.new(0,40,0,20)
	track.Position = UDim2.new(1,-50,0.5,-10)
	track.BackgroundColor3 = Color3.fromRGB(50,50,50)
	track.BorderSizePixel = 0
	track.Parent = row
	Instance.new("UICorner",track).CornerRadius = UDim.new(1,0)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0,16,0,16)
	knob.Position = UDim2.new(0,2,0,2)
	knob.BackgroundColor3 = Color3.fromRGB(180,180,180)
	knob.BorderSizePixel = 0
	knob.Parent = track
	Instance.new("UICorner",knob).CornerRadius = UDim.new(1,0)

	local function refresh()
		local on = state[stateKey]
		TweenService:Create(track,TweenInfo.new(0.15),{BackgroundColor3=on and ACCENT or Color3.fromRGB(50,50,50)}):Play()
		TweenService:Create(knob,TweenInfo.new(0.15),{
			Position=on and UDim2.new(1,-18,0,2) or UDim2.new(0,2,0,2),
			BackgroundColor3=on and Color3.fromRGB(255,255,255) or Color3.fromRGB(180,180,180)
		}):Play()
	end

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1,0,1,0)
	btn.BackgroundTransparency = 1
	btn.Text = ""
	btn.Parent = row
	btn.MouseButton1Click:Connect(function()
		state[stateKey] = not state[stateKey]
		refresh()
		if callback then callback(state[stateKey]) end
	end)
	refresh()
	return row
end

-- ============================================================
-- SLIDER WIDGET
-- ============================================================
local function buildSlider(page,labelText,minVal,maxVal,defaultVal,onChanged)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(1,0,0,50)
	container.BackgroundColor3 = Color3.fromRGB(14,14,14)
	container.BorderSizePixel = 0
	container.Parent = page
	Instance.new("UICorner",container).CornerRadius = UDim.new(0,6)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1,-50,0,18)
	lbl.Position = UDim2.new(0,12,0,6)
	lbl.BackgroundTransparency = 1
	lbl.Text = labelText
	lbl.TextColor3 = Color3.fromRGB(160,160,160)
	lbl.TextSize = 11
	lbl.Font = Enum.Font.GothamSemibold
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = container

	local valLbl = Instance.new("TextLabel")
	valLbl.Size = UDim2.new(0,44,0,18)
	valLbl.Position = UDim2.new(1,-54,0,6)
	valLbl.BackgroundTransparency = 1
	valLbl.Text = tostring(defaultVal)
	valLbl.TextColor3 = ACCENT
	valLbl.TextSize = 11
	valLbl.Font = Enum.Font.GothamBold
	valLbl.TextXAlignment = Enum.TextXAlignment.Right
	valLbl.Parent = container

	local trackBg = Instance.new("Frame")
	trackBg.Size = UDim2.new(1,-24,0,6)
	trackBg.Position = UDim2.new(0,12,0,34)
	trackBg.BackgroundColor3 = Color3.fromRGB(40,40,40)
	trackBg.BorderSizePixel = 0
	trackBg.Parent = container
	Instance.new("UICorner",trackBg).CornerRadius = UDim.new(1,0)

	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = ACCENT
	fill.BorderSizePixel = 0
	fill.Parent = trackBg
	Instance.new("UICorner",fill).CornerRadius = UDim.new(1,0)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0,14,0,14)
	knob.AnchorPoint = Vector2.new(0.5,0.5)
	knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
	knob.BorderSizePixel = 0
	knob.ZIndex = 2
	knob.Parent = trackBg
	Instance.new("UICorner",knob).CornerRadius = UDim.new(1,0)

	local dragging = false
	local function setAlpha(alpha)
		alpha = math.clamp(alpha,0,1)
		local val = math.round(minVal+(maxVal-minVal)*alpha)
		fill.Size = UDim2.new(alpha,0,1,0)
		knob.Position = UDim2.new(alpha,0,0.5,0)
		valLbl.Text = tostring(val)
		if onChanged then onChanged(val) end
	end
	local ia = (defaultVal-minVal)/(maxVal-minVal)
	fill.Size = UDim2.new(ia,0,1,0)
	knob.Position = UDim2.new(ia,0,0.5,0)

	knob.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=true end end)
	trackBg.InputBegan:Connect(function(i)
		if i.UserInputType==Enum.UserInputType.MouseButton1 then
			setAlpha((i.Position.X-trackBg.AbsolutePosition.X)/trackBg.AbsoluteSize.X)
			dragging=true
		end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then
			setAlpha((i.Position.X-trackBg.AbsolutePosition.X)/trackBg.AbsoluteSize.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
	end)
	return container
end

-- ============================================================
-- SECTION LABEL HELPER
-- ============================================================
local function addSectionLabel(page, text)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1,0,0,18)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = Color3.fromRGB(80,80,80)
	lbl.TextSize = 10
	lbl.Font = Enum.Font.GothamSemibold
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = page
	return lbl
end

-- ============================================================
-- HITBOX SELECTOR (grid of buttons)
-- ============================================================
local function buildHitboxSelector(page)
	local wrapper = Instance.new("Frame")
	wrapper.Size = UDim2.new(1,0,0,0)
	wrapper.AutomaticSize = Enum.AutomaticSize.Y
	wrapper.BackgroundColor3 = Color3.fromRGB(14,14,14)
	wrapper.BorderSizePixel = 0
	wrapper.Parent = page
	Instance.new("UICorner",wrapper).CornerRadius = UDim.new(0,6)

	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1,0,0,22)
	header.Position = UDim2.new(0,0,0,0)
	header.BackgroundTransparency = 1
	header.Text = "Aimbot Target"
	header.TextColor3 = Color3.fromRGB(160,160,160)
	header.TextSize = 11
	header.Font = Enum.Font.GothamSemibold
	header.Parent = wrapper

	local grid = Instance.new("Frame")
	grid.Size = UDim2.new(1,-16,0,0)
	grid.Position = UDim2.new(0,8,0,24)
	grid.AutomaticSize = Enum.AutomaticSize.Y
	grid.BackgroundTransparency = 1
	grid.Parent = wrapper

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0.5,-4,0,28)
	gridLayout.CellPadding = UDim2.new(0,4,0,4)
	gridLayout.Parent = grid

	-- Bottom padding for wrapper
	local botPad = Instance.new("UIPadding")
	botPad.PaddingBottom = UDim.new(0,10)
	botPad.Parent = wrapper

	local btnRefs = {}

	local function selectHitbox(opt)
		AIMBOT_HITBOX = opt.part
		for _, ref in ipairs(btnRefs) do
			local isSelected = ref.optPart == opt.part
			ref.btn.BackgroundColor3 = isSelected and ACCENT or Color3.fromRGB(30,30,30)
			ref.btn.TextColor3 = isSelected and Color3.fromRGB(10,10,10) or Color3.fromRGB(180,180,180)
			ref.btn.Font = isSelected and Enum.Font.GothamBold or Enum.Font.Gotham
		end
	end

	for i, opt in ipairs(HITBOX_OPTIONS) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1,0,1,0)
		btn.BackgroundColor3 = (opt.part == AIMBOT_HITBOX) and ACCENT or Color3.fromRGB(30,30,30)
		btn.Text = opt.label
		btn.TextColor3 = (opt.part == AIMBOT_HITBOX) and Color3.fromRGB(10,10,10) or Color3.fromRGB(180,180,180)
		btn.TextSize = 11
		btn.Font = (opt.part == AIMBOT_HITBOX) and Enum.Font.GothamBold or Enum.Font.Gotham
		btn.BorderSizePixel = 0
		btn.Parent = grid
		Instance.new("UICorner",btn).CornerRadius = UDim.new(0,5)

		table.insert(btnRefs, { btn = btn, optPart = opt.part })
		btn.MouseButton1Click:Connect(function() selectHitbox(opt) end)
	end

	return wrapper
end

-- ============================================================
-- KEYBIND WIDGET
-- ============================================================
-- Displays current keybind and lets user rebind by pressing a key/mouse button
local function buildKeybindRow(page, label, description, bindKey)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1,0,0,56)
	row.BackgroundColor3 = Color3.fromRGB(20,20,20)
	row.BorderSizePixel = 0
	row.Parent = page
	Instance.new("UICorner",row).CornerRadius = UDim.new(0,6)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1,-110,0,20)
	lbl.Position = UDim2.new(0,12,0,8)
	lbl.BackgroundTransparency = 1
	lbl.Text = label
	lbl.TextColor3 = Color3.fromRGB(230,230,230)
	lbl.TextSize = 13
	lbl.Font = Enum.Font.GothamSemibold
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = row

	local desc = Instance.new("TextLabel")
	desc.Size = UDim2.new(1,-110,0,16)
	desc.Position = UDim2.new(0,12,0,28)
	desc.BackgroundTransparency = 1
	desc.Text = description
	desc.TextColor3 = Color3.fromRGB(100,100,100)
	desc.TextSize = 11
	desc.Font = Enum.Font.Gotham
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.Parent = row

	-- Bind button showing current bind
	local bindBtn = Instance.new("TextButton")
	bindBtn.Size = UDim2.new(0,90,0,30)
	bindBtn.Position = UDim2.new(1,-100,0.5,-15)
	bindBtn.BackgroundColor3 = Color3.fromRGB(35,35,35)
	bindBtn.Text = keybinds[bindKey].label
	bindBtn.TextColor3 = ACCENT
	bindBtn.TextSize = 11
	bindBtn.Font = Enum.Font.GothamBold
	bindBtn.BorderSizePixel = 0
	bindBtn.Parent = row
	Instance.new("UICorner",bindBtn).CornerRadius = UDim.new(0,6)

	local listening = false
	local conn1, conn2

	local function stopListen()
		listening = false
		if conn1 then conn1:Disconnect() conn1 = nil end
		if conn2 then conn2:Disconnect() conn2 = nil end
		bindBtn.BackgroundColor3 = Color3.fromRGB(35,35,35)
		bindBtn.TextColor3 = ACCENT
	end

	local function startListen()
		if listening then stopListen() return end
		listening = true
		bindBtn.Text = "Press key..."
		bindBtn.TextColor3 = Color3.fromRGB(255,230,80)
		bindBtn.BackgroundColor3 = Color3.fromRGB(45,40,20)

		conn1 = UserInputService.InputBegan:Connect(function(input, gp)
			if gp then return end
			-- Escape cancels
			if input.KeyCode == Enum.KeyCode.Escape then
				bindBtn.Text = keybinds[bindKey].label
				stopListen()
				return
			end
			-- Mouse buttons
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				keybinds[bindKey] = { type="mouse", value=Enum.UserInputType.MouseButton1, label="LMB" }
			elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
				keybinds[bindKey] = { type="mouse", value=Enum.UserInputType.MouseButton2, label="RMB" }
			elseif input.UserInputType == Enum.UserInputType.MouseButton3 then
				keybinds[bindKey] = { type="mouse", value=Enum.UserInputType.MouseButton3, label="MMB" }
			elseif input.KeyCode ~= Enum.KeyCode.Unknown then
				local name = tostring(input.KeyCode):gsub("Enum.KeyCode.","")
				keybinds[bindKey] = { type="key", value=input.KeyCode, label=name }
			else
				return
			end
			bindBtn.Text = keybinds[bindKey].label
			stopListen()
		end)
	end

	bindBtn.MouseButton1Click:Connect(startListen)
	return row
end

-- Helper: check if a keybind is currently held
local function isBindHeld(bindKey)
	local b = keybinds[bindKey]
	if not b then return false end
	if b.type == "mouse" then
		return UserInputService:IsMouseButtonPressed(b.value)
	else
		return UserInputService:IsKeyDown(b.value)
	end
end

-- ============================================================
-- AIM PAGE
-- ============================================================
local aimPage = tabPages["Aim"]

addToggle(aimPage,"Aimbot","Locks onto nearest player's selected hitbox (hold bind)","aimbot",nil)
buildSlider(aimPage,"Aimbot Smoothness",0,100,18,function(val) AIMBOT_SMOOTH=val/100 end)
buildSlider(aimPage,"Aimbot FOV",50,600,150,function(val)
	AIMBOT_FOV=val
	if _G.aimbotFovCircle then
		_G.aimbotFovCircle.Size     = UDim2.new(0,val*2,0,val*2)
		_G.aimbotFovCircle.Position = UDim2.new(0.5,-val,0.5,-val)
	end
end)
addToggle(aimPage,"Show FOV Circle","Draws the aimbot FOV radius on screen","aimbotfov",function(val)
	if _G.aimbotFovCircle then _G.aimbotFovCircle.Visible=val end
end)

addSectionLabel(aimPage,"  TARGET HITBOX")
buildHitboxSelector(aimPage)

addToggle(aimPage,"Trigger Bot","Auto-clicks when crosshair is on a player","triggerbot",nil)
buildSlider(aimPage,"Trigger Delay (ms)",0,500,50,function(val) TRIGGER_DELAY=val/1000 end)

-- ============================================================
-- MOVEMENT PAGE
-- ============================================================
local movePage = tabPages["Movement"]

addToggle(movePage,"Bunny Hop","CSGO-style strafe bhop","bhop",nil)
local bhopSliderContainer = buildSlider(movePage,"Max Speed",45,200,45,function(val) BHOP_MAX_SPEED=val end)
bhopSliderContainer.Visible = false

addToggle(movePage,"High Jump","Doubles jump power","highJump",function(val)
	local char=player.Character
	if char then local hum=char:FindFirstChildOfClass("Humanoid") if hum then hum.JumpPower=val and 100 or 50 end end
end)
addToggle(movePage,"Noclip","Walk through walls","noclip",nil)
addToggle(movePage,"Fly","Fly freely (W/A/S/D + Space/Shift)","fly",function(val)
	if val then startFly() else stopFly() end
end)
local flySliderContainer = buildSlider(movePage,"Fly Speed",5,200,50,function(val) FLY_SPEED=val end)
flySliderContainer.Visible = true

local speedInfo = Instance.new("TextLabel")
speedInfo.Size = UDim2.new(1,0,0,24)
speedInfo.BackgroundTransparency = 1
speedInfo.Text = "Speed: —"
speedInfo.TextColor3 = Color3.fromRGB(80,80,80)
speedInfo.TextSize = 11
speedInfo.Font = Enum.Font.Gotham
speedInfo.Parent = movePage

-- ============================================================
-- VISUAL PAGE
-- ============================================================
local visPage = tabPages["Visual"]

addToggle(visPage,"Fullbright","Sets ambient lighting to max","fullbright",function(val)
	local l=game:GetService("Lighting")
	l.Ambient        = val and Color3.fromRGB(255,255,255) or Color3.fromRGB(70,70,70)
	l.OutdoorAmbient = val and Color3.fromRGB(255,255,255) or Color3.fromRGB(140,140,140)
end)
addToggle(visPage,"Show FPS","Color-coded FPS counter","showFPS",nil)
addToggle(visPage,"ESP","Shows player names + avatar icons","esp",nil)
addToggle(visPage,"ESP Boxes","2D screen boxes with name + HP bar","espboxes",nil)

-- TEAM CHECK TOGGLE (Visual tab, clearly labeled)
addToggle(visPage,"Team Check","Skip teammates in ESP, Aimbot & Triggerbot","teamcheck",function(val)
	-- When toggled off, rebuild ESP so removed teammates come back
	if not val then
		for plr,_ in pairs(espFrames) do
			pcall(function() espFrames[plr].billboard:Destroy() end)
			espFrames[plr] = nil
		end
	end
end)

-- FOV slider
local DEFAULT_FOV = 70
buildSlider(visPage,"Field of View",30,120,DEFAULT_FOV,function(val)
	workspace.CurrentCamera.FieldOfView=val
end)

local fovResetRow = Instance.new("Frame")
fovResetRow.Size = UDim2.new(1,0,0,34)
fovResetRow.BackgroundColor3 = Color3.fromRGB(20,20,20)
fovResetRow.BorderSizePixel = 0
fovResetRow.Parent = visPage
Instance.new("UICorner",fovResetRow).CornerRadius = UDim.new(0,6)

local fovResetBtn = Instance.new("TextButton")
fovResetBtn.Size = UDim2.new(1,-24,0,22)
fovResetBtn.Position = UDim2.new(0,12,0.5,-11)
fovResetBtn.BackgroundColor3 = Color3.fromRGB(40,40,40)
fovResetBtn.Text = "↺  Reset FOV to Default (70)"
fovResetBtn.TextColor3 = Color3.fromRGB(180,180,180)
fovResetBtn.TextSize = 11
fovResetBtn.Font = Enum.Font.GothamSemibold
fovResetBtn.BorderSizePixel = 0
fovResetBtn.Parent = fovResetRow
Instance.new("UICorner",fovResetBtn).CornerRadius = UDim.new(0,5)
fovResetBtn.MouseButton1Click:Connect(function()
	workspace.CurrentCamera.FieldOfView=DEFAULT_FOV
	fovResetBtn.BackgroundColor3 = Color3.fromRGB(60,180,60)
	fovResetBtn.Text = "✓  Reset!"
	task.delay(0.8,function()
		if fovResetBtn and fovResetBtn.Parent then
			fovResetBtn.BackgroundColor3=Color3.fromRGB(40,40,40)
			fovResetBtn.Text="↺  Reset FOV to Default (70)"
		end
	end)
end)

local fpsLabel = Instance.new("TextLabel")
fpsLabel.Size = UDim2.new(0,120,0,30)
fpsLabel.Position = UDim2.new(0,10,0,10)
fpsLabel.BackgroundTransparency = 1
fpsLabel.Text = ""
fpsLabel.TextColor3 = Color3.fromRGB(100,255,100)
fpsLabel.TextSize = 20
fpsLabel.Font = Enum.Font.GothamBold
fpsLabel.TextXAlignment = Enum.TextXAlignment.Left
fpsLabel.ZIndex = 10
fpsLabel.Parent = screenGui

local fpsSamples = {}
local FPS_SAMPLE_COUNT = 20

-- ============================================================
-- OTHER PAGE
-- ============================================================
local otherPage = tabPages["Other"]

addToggle(otherPage,"Auto Sprint","Always sprints (WalkSpeed 28)","autoSprint",function(val)
	local char=player.Character
	if char then local hum=char:FindFirstChildOfClass("Humanoid") if hum then hum.WalkSpeed=val and 28 or 16 end end
end)
addToggle(otherPage,"Speedometer","CSGO-style speed overlay","speedometer",nil)
addToggle(otherPage,"Draggable GUI","Lets you drag the menu window","draggable",function(val)
	window.Draggable=val
	titleLabel.TextColor3=val and ACCENT or Color3.fromRGB(255,255,255)
end)

-- ============================================================
-- FUN PAGE
-- ============================================================
local funPage = tabPages["Fun"]

addToggle(funPage,"Spin Bot","Spins in all axes simultaneously","spinbot",nil)
buildSlider(funPage,"Spin Speed",1,1000,10,function(val) SPIN_SPEED=val end)
addToggle(funPage,"Spin Bot V2","Clean 360° yaw spin only","spinbot2",nil)
buildSlider(funPage,"Spin V2 Speed",1,1000,10,function(val) SPIN2_SPEED=val end)
addToggle(funPage,"Upside Down","Flips your character upside down","upsidedown",function(val)
	local char=player.Character
	if not char then return end
	local hrp=char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local rj=hrp:FindFirstChild("RootJoint")
	if not rj then return end
	rj.C0 = val
		and CFrame.new(0,0,0,-1,0,0, 0,0,-1, 0,-1,0)
		or  CFrame.new(0,0,0,-1,0,0, 0,0, 1, 0, 1,0)
end)

-- ============================================================
-- TP TO PAGE
-- ============================================================
local tpPage = tabPages["TP To"]

local tpHeader = Instance.new("TextLabel")
tpHeader.Size = UDim2.new(1,0,0,20)
tpHeader.BackgroundTransparency = 1
tpHeader.Text = "Click TP to teleport to a player"
tpHeader.TextColor3 = Color3.fromRGB(80,80,80)
tpHeader.TextSize = 11
tpHeader.Font = Enum.Font.Gotham
tpHeader.Parent = tpPage

local tpListContainer = Instance.new("Frame")
tpListContainer.Size = UDim2.new(1,0,0,0)
tpListContainer.BackgroundTransparency = 1
tpListContainer.AutomaticSize = Enum.AutomaticSize.Y
tpListContainer.Parent = tpPage
local tpListLayout = Instance.new("UIListLayout")
tpListLayout.Padding = UDim.new(0,6)
tpListLayout.Parent = tpListContainer

local function buildTpList()
	for _,child in ipairs(tpListContainer:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	local plrs = Players:GetPlayers()
	for _,plr in ipairs(plrs) do
		if plr==player then continue end
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1,0,0,44)
		row.BackgroundColor3 = Color3.fromRGB(20,20,20)
		row.BorderSizePixel = 0
		row.Parent = tpListContainer
		Instance.new("UICorner",row).CornerRadius = UDim.new(0,6)

		-- Team indicator stripe on left
		local teamStripe = Instance.new("Frame")
		teamStripe.Size = UDim2.new(0,3,1,0)
		teamStripe.BackgroundColor3 = (plr.Team and plr.Team.TeamColor and plr.Team.TeamColor.Color) or Color3.fromRGB(60,60,60)
		teamStripe.BorderSizePixel = 0
		teamStripe.Parent = row
		Instance.new("UICorner",teamStripe).CornerRadius = UDim.new(0,3)

		local icon = Instance.new("ImageLabel")
		icon.Size = UDim2.new(0,30,0,30)
		icon.Position = UDim2.new(0,12,0.5,-15)
		icon.BackgroundColor3 = Color3.fromRGB(30,30,30)
		icon.BorderSizePixel = 0
		icon.Image = Players:GetUserThumbnailAsync(plr.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size48x48)
		icon.Parent = row
		Instance.new("UICorner",icon).CornerRadius = UDim.new(1,0)

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(1,-120,1,0)
		nameLbl.Position = UDim2.new(0,50,0,0)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Text = plr.Name .. (plr.Team and (" ["..plr.Team.Name.."]") or "")
		nameLbl.TextColor3 = Color3.fromRGB(220,220,220)
		nameLbl.TextSize = 12
		nameLbl.Font = Enum.Font.GothamSemibold
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
		nameLbl.Parent = row

		local tpBtn = Instance.new("TextButton")
		tpBtn.Size = UDim2.new(0,46,0,26)
		tpBtn.Position = UDim2.new(1,-54,0.5,-13)
		tpBtn.BackgroundColor3 = ACCENT
		tpBtn.Text = "TP"
		tpBtn.TextColor3 = Color3.fromRGB(10,10,10)
		tpBtn.TextSize = 12
		tpBtn.Font = Enum.Font.GothamBold
		tpBtn.BorderSizePixel = 0
		tpBtn.Parent = row
		Instance.new("UICorner",tpBtn).CornerRadius = UDim.new(0,5)

		tpBtn.MouseButton1Click:Connect(function()
			local tc=plr.Character
			if not tc then return end
			local th=tc:FindFirstChild("HumanoidRootPart")
			if not th then return end
			local mc=player.Character
			if not mc then return end
			local mh=mc:FindFirstChild("HumanoidRootPart")
			if not mh then return end
			mh.CFrame = th.CFrame*CFrame.new(0,0,-3)
			tpBtn.BackgroundColor3=Color3.fromRGB(80,220,80)
			tpBtn.Text="✓"
			task.delay(0.8,function()
				if tpBtn and tpBtn.Parent then tpBtn.BackgroundColor3=ACCENT tpBtn.Text="TP" end
			end)
		end)

		if not plr.Character then
			row.BackgroundColor3=Color3.fromRGB(15,15,15)
			nameLbl.TextColor3=Color3.fromRGB(80,80,80)
			tpBtn.BackgroundColor3=Color3.fromRGB(50,50,50)
			tpBtn.TextColor3=Color3.fromRGB(100,100,100)
		end
	end
	if #plrs<=1 then
		local el=Instance.new("TextLabel")
		el.Size=UDim2.new(1,0,0,40)
		el.BackgroundTransparency=1
		el.Text="No other players in server"
		el.TextColor3=Color3.fromRGB(70,70,70)
		el.TextSize=12
		el.Font=Enum.Font.Gotham
		el.Parent=tpListContainer
	end
end

Players.PlayerAdded:Connect(function() task.wait(1) buildTpList() end)
Players.PlayerRemoving:Connect(function() task.wait(0.1) buildTpList() end)
tabButtons["TP To"].MouseButton1Click:Connect(function() buildTpList() end)

-- ============================================================
-- KEYBINDS PAGE
-- ============================================================
local kbPage = tabPages["Keybinds"]

addSectionLabel(kbPage, "  AIMBOT")
buildKeybindRow(kbPage,
	"Aimbot Hold Key",
	"Hold this to activate aimbot",
	"aimbot"
)

addSectionLabel(kbPage, "  TRIGGERBOT")
local tbInfoRow = Instance.new("Frame")
tbInfoRow.Size = UDim2.new(1,0,0,40)
tbInfoRow.BackgroundColor3 = Color3.fromRGB(18,18,18)
tbInfoRow.BorderSizePixel = 0
tbInfoRow.Parent = kbPage
Instance.new("UICorner",tbInfoRow).CornerRadius = UDim.new(0,6)

local tbInfo = Instance.new("TextLabel")
tbInfo.Size = UDim2.new(1,-16,1,0)
tbInfo.Position = UDim2.new(0,12,0,0)
tbInfo.BackgroundTransparency = 1
tbInfo.Text = "Triggerbot fires automatically on crosshair — no hold key needed."
tbInfo.TextColor3 = Color3.fromRGB(90,90,90)
tbInfo.TextSize = 11
tbInfo.Font = Enum.Font.Gotham
tbInfo.TextWrapped = true
tbInfo.TextXAlignment = Enum.TextXAlignment.Left
tbInfo.TextYAlignment = Enum.TextYAlignment.Center
tbInfo.Parent = tbInfoRow

addSectionLabel(kbPage, "  MENU")
local menuKbRow = Instance.new("Frame")
menuKbRow.Size = UDim2.new(1,0,0,40)
menuKbRow.BackgroundColor3 = Color3.fromRGB(18,18,18)
menuKbRow.BorderSizePixel = 0
menuKbRow.Parent = kbPage
Instance.new("UICorner",menuKbRow).CornerRadius = UDim.new(0,6)

local menuKbLbl = Instance.new("TextLabel")
menuKbLbl.Size = UDim2.new(1,-16,1,0)
menuKbLbl.Position = UDim2.new(0,12,0,0)
menuKbLbl.BackgroundTransparency = 1
menuKbLbl.Text = "Menu toggle is INSERT (not rebindable)"
menuKbLbl.TextColor3 = Color3.fromRGB(90,90,90)
menuKbLbl.TextSize = 11
menuKbLbl.Font = Enum.Font.Gotham
menuKbLbl.TextXAlignment = Enum.TextXAlignment.Left
menuKbLbl.TextYAlignment = Enum.TextYAlignment.Center
menuKbLbl.Parent = menuKbRow

-- ============================================================
-- SPEEDOMETER
-- ============================================================
local speedoFrame = Instance.new("Frame")
speedoFrame.Size = UDim2.new(0,140,0,44)
speedoFrame.Position = UDim2.new(0.5,-70,1,-130)
speedoFrame.BackgroundColor3 = Color3.fromRGB(0,0,0)
speedoFrame.BackgroundTransparency = 0.45
speedoFrame.BorderSizePixel = 0
speedoFrame.Visible = false
speedoFrame.ZIndex = 10
speedoFrame.Parent = screenGui
Instance.new("UICorner",speedoFrame).CornerRadius = UDim.new(0,6)

local speedoNumber = Instance.new("TextLabel")
speedoNumber.Size = UDim2.new(1,0,0,28)
speedoNumber.Position = UDim2.new(0,0,0,2)
speedoNumber.BackgroundTransparency = 1
speedoNumber.Text = "0"
speedoNumber.TextColor3 = Color3.fromRGB(255,255,255)
speedoNumber.TextSize = 22
speedoNumber.Font = Enum.Font.GothamBold
speedoNumber.ZIndex = 11
speedoNumber.Parent = speedoFrame

local speedoUnit = Instance.new("TextLabel")
speedoUnit.Size = UDim2.new(1,0,0,14)
speedoUnit.Position = UDim2.new(0,0,0,28)
speedoUnit.BackgroundTransparency = 1
speedoUnit.Text = "su / s"
speedoUnit.TextColor3 = Color3.fromRGB(130,130,130)
speedoUnit.TextSize = 10
speedoUnit.Font = Enum.Font.Gotham
speedoUnit.ZIndex = 11
speedoUnit.Parent = speedoFrame

local speedoBar = Instance.new("Frame")
speedoBar.Size = UDim2.new(0,0,0,3)
speedoBar.Position = UDim2.new(0,0,1,-3)
speedoBar.BackgroundColor3 = ACCENT
speedoBar.BorderSizePixel = 0
speedoBar.ZIndex = 12
speedoBar.Parent = speedoFrame
Instance.new("UICorner",speedoBar).CornerRadius = UDim.new(1,0)

local prevSpeed = 0

-- ============================================================
-- FOV CIRCLE
-- ============================================================
local fovCircleGui = Instance.new("ScreenGui")
fovCircleGui.Name = "AimbotFOV"
fovCircleGui.ResetOnSpawn = false
fovCircleGui.IgnoreGuiInset = true
fovCircleGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
fovCircleGui.Parent = player.PlayerGui

local fovCircle = Instance.new("Frame")
fovCircle.BackgroundTransparency = 1
fovCircle.BorderSizePixel = 0
fovCircle.Size = UDim2.new(0,AIMBOT_FOV*2,0,AIMBOT_FOV*2)
fovCircle.Position = UDim2.new(0.5,-AIMBOT_FOV,0.5,-AIMBOT_FOV)
fovCircle.Visible = false
fovCircle.ZIndex = 30
fovCircle.Parent = fovCircleGui
Instance.new("UICorner",fovCircle).CornerRadius = UDim.new(1,0)

local fovStroke = Instance.new("UIStroke")
fovStroke.Color = Color3.fromRGB(255,255,255)
fovStroke.Thickness = 1.5
fovStroke.Transparency = 0.35
fovStroke.Parent = fovCircle
_G.aimbotFovCircle = fovCircle

-- ============================================================
-- ESP SYSTEM
-- ============================================================
local espFrames = {}

local function getEspColor(plr)
	if state.teamcheck and isSameTeam(plr) then
		return Color3.fromRGB(80,200,255)  -- blue for teammates when teamcheck on
	end
	return Color3.fromRGB(255,80,80)
end

local function createEspFrame(plr)
	if plr==player then return end
	if espFrames[plr] then return end
	-- Skip teammates
	if isSameTeam(plr) then return end

	local char=plr.Character
	if not char then return end
	local head=char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
	if not head then return end

	local container=Instance.new("BillboardGui")
	container.Name="ESP_"..plr.Name
	container.Size=UDim2.new(0,80,0,80)
	container.StudsOffset=Vector3.new(0,3,0)
	container.AlwaysOnTop=true
	container.ResetOnSpawn=false
	container.Adornee=head
	container.Parent=head

	local avatar=Instance.new("ImageLabel")
	avatar.Size=UDim2.new(0,36,0,36)
	avatar.Position=UDim2.new(0.5,-18,0,0)
	avatar.BackgroundColor3=Color3.fromRGB(15,15,15)
	avatar.BorderSizePixel=0
	avatar.Image=Players:GetUserThumbnailAsync(plr.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size48x48)
	avatar.Parent=container
	Instance.new("UICorner",avatar).CornerRadius=UDim.new(1,0)

	local ring=Instance.new("UIStroke")
	ring.Color=getEspColor(plr)
	ring.Thickness=2
	ring.Parent=avatar

	local nameLbl=Instance.new("TextLabel")
	nameLbl.Size=UDim2.new(1,0,0,18)
	nameLbl.Position=UDim2.new(0,0,0,38)
	nameLbl.BackgroundTransparency=1
	nameLbl.Text=plr.Name
	nameLbl.TextColor3=Color3.fromRGB(255,255,255)
	nameLbl.TextSize=11
	nameLbl.Font=Enum.Font.GothamBold
	nameLbl.TextStrokeTransparency=0.4
	nameLbl.TextStrokeColor3=Color3.fromRGB(0,0,0)
	nameLbl.Parent=container

	-- Team tag under name
	local teamLbl=Instance.new("TextLabel")
	teamLbl.Size=UDim2.new(1,0,0,14)
	teamLbl.Position=UDim2.new(0,0,0,54)
	teamLbl.BackgroundTransparency=1
	teamLbl.Text=plr.Team and ("[" .. plr.Team.Name .. "]") or ""
	teamLbl.TextColor3=Color3.fromRGB(180,180,180)
	teamLbl.TextSize=10
	teamLbl.Font=Enum.Font.Gotham
	teamLbl.TextStrokeTransparency=0.4
	teamLbl.TextStrokeColor3=Color3.fromRGB(0,0,0)
	teamLbl.Parent=container

	local hpBg=Instance.new("Frame")
	hpBg.Size=UDim2.new(0,36,0,4)
	hpBg.Position=UDim2.new(0.5,-18,0,70)
	hpBg.BackgroundColor3=Color3.fromRGB(40,40,40)
	hpBg.BorderSizePixel=0
	hpBg.Parent=container
	Instance.new("UICorner",hpBg).CornerRadius=UDim.new(1,0)

	local hpFill=Instance.new("Frame")
	hpFill.Size=UDim2.new(1,0,1,0)
	hpFill.BackgroundColor3=Color3.fromRGB(80,220,80)
	hpFill.BorderSizePixel=0
	hpFill.Parent=hpBg
	Instance.new("UICorner",hpFill).CornerRadius=UDim.new(1,0)

	espFrames[plr]={billboard=container,hpFill=hpFill,char=char}

	local hum=char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.HealthChanged:Connect(function(hp)
			local alpha=math.clamp(hp/hum.MaxHealth,0,1)
			hpFill.Size=UDim2.new(alpha,0,1,0)
			hpFill.BackgroundColor3=Color3.fromRGB(
				math.round((1-alpha)*255),
				math.round(alpha*200),
				40
			)
		end)
	end
end

local function removeEspFrame(plr)
	if espFrames[plr] then
		pcall(function() espFrames[plr].billboard:Destroy() end)
		espFrames[plr]=nil
	end
end

local function refreshEsp()
	if state.esp then
		for _,plr in ipairs(Players:GetPlayers()) do
			if plr~=player and plr.Character then
				if isSameTeam(plr) then
					removeEspFrame(plr)  -- remove if now teammate
				elseif not espFrames[plr] then
					pcall(createEspFrame,plr)
				end
			end
		end
	else
		for plr,_ in pairs(espFrames) do removeEspFrame(plr) end
	end
end

Players.PlayerAdded:Connect(function(plr)
	plr.CharacterAdded:Connect(function()
		task.wait(1)
		if state.esp then pcall(createEspFrame,plr) end
	end)
end)
Players.PlayerRemoving:Connect(function(plr) removeEspFrame(plr) end)
for _,plr in ipairs(Players:GetPlayers()) do
	if plr~=player then
		plr.CharacterAdded:Connect(function()
			task.wait(1)
			if state.esp then removeEspFrame(plr) pcall(createEspFrame,plr) end
		end)
	end
end

-- ============================================================
-- HEARTBEAT LOOP
-- ============================================================
RunService.Heartbeat:Connect(function(dt)
	bhopSliderContainer.Visible = state.bhop

	local char=player.Character
	if not char then return end
	local hum=char:FindFirstChildOfClass("Humanoid")
	local hrp=char:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp then return end

	-- FPS
	if state.showFPS then
		table.insert(fpsSamples,dt)
		if #fpsSamples>FPS_SAMPLE_COUNT then table.remove(fpsSamples,1) end
		local sum=0
		for _,s in ipairs(fpsSamples) do sum=sum+s end
		local fps=math.round(1/(sum/#fpsSamples))
		fpsLabel.Text="FPS: "..tostring(fps)
		if fps<60 then fpsLabel.TextColor3=Color3.fromRGB(255,60,60)
		elseif fps<80 then fpsLabel.TextColor3=Color3.fromRGB(255,160,40)
		elseif fps<110 then fpsLabel.TextColor3=Color3.fromRGB(255,230,50)
		else fpsLabel.TextColor3=Color3.fromRGB(80,230,80) end
	else
		fpsLabel.Text=""
		fpsSamples={}
	end

	-- Noclip
	if state.noclip then
		for _,part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") then part.CanCollide=false end
		end
	end

	-- Spinbot
	if state.spinbot then
		local d=SPIN_SPEED*36
		spinAccum=(spinAccum+d*dt)%360
		spinPitch=(spinPitch+d*dt*0.7)%360
		spinRoll=(spinRoll+d*dt*0.5)%360
		local pos=hrp.Position
		hrp.CFrame=CFrame.new(pos)*CFrame.Angles(0,math.rad(spinAccum),0)*CFrame.Angles(math.rad(spinPitch),0,0)*CFrame.Angles(0,0,math.rad(spinRoll))
		local bg=hrp:FindFirstChild("FlyGyro")
		if bg then bg.MaxTorque=Vector3.new(0,0,0) end
	end

	if state.spinbot2 then
		local d2=SPIN2_SPEED*36
		spinAccum2=(spinAccum2+d2*dt)%360
		local pos=hrp.Position
		hrp.CFrame=CFrame.new(pos)*CFrame.Angles(0,math.rad(spinAccum2),0)
		local bg=hrp:FindFirstChild("FlyGyro")
		if bg then bg.MaxTorque=Vector3.new(0,0,0) end
	end

	if state.upsidedown then
		local rj=hrp:FindFirstChild("RootJoint")
		if rj then rj.C0=CFrame.new(0,0,0,-1,0,0, 0,0,-1, 0,-1,0) end
	end

	-- Fly
	if state.fly then
		hum.PlatformStand=true
		if not hrp:FindFirstChild("FlyVelocity") or not hrp:FindFirstChild("FlyGyro") then
			stopFly() startFly()
		end
		local bv=hrp:FindFirstChild("FlyVelocity")
		local bg=hrp:FindFirstChild("FlyGyro")
		if bv and bg then
			local cam=workspace.CurrentCamera
			local camCF=cam.CFrame
			local fl=camCF.LookVector
			local fr=camCF.RightVector
			local flatLook=Vector3.new(fl.X,0,fl.Z)
			local flatRight=Vector3.new(fr.X,0,fr.Z)
			if flatLook.Magnitude>0 then flatLook=flatLook.Unit end
			if flatRight.Magnitude>0 then flatRight=flatRight.Unit end
			local wd=Vector3.new(0,0,0)
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then wd=wd+flatLook end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then wd=wd-flatLook end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then wd=wd+flatRight end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then wd=wd-flatRight end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then wd=wd+Vector3.new(0,1,0) end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then wd=wd-Vector3.new(0,1,0) end
			if wd.Magnitude>0 then wd=wd.Unit end
			bv.Velocity=wd*FLY_SPEED
			if not state.spinbot and not state.spinbot2 then
				bg.MaxTorque=Vector3.new(1e5,1e5,1e5)
				bg.CFrame=camCF
			end
		end
	else
		if hrp:FindFirstChild("FlyVelocity") then stopFly() end
		if hum.PlatformStand and not state.fly then hum.PlatformStand=false end
	end

	local vel=hrp.AssemblyLinearVelocity
	local flatSpeed=Vector3.new(vel.X,0,vel.Z).Magnitude

	-- Speedometer
	if state.speedometer then
		speedoFrame.Visible=true
		speedoNumber.Text=tostring(math.round(flatSpeed))
		if flatSpeed>prevSpeed+0.5 then speedoNumber.TextColor3=Color3.fromRGB(120,255,120)
		elseif flatSpeed<prevSpeed-0.5 then speedoNumber.TextColor3=Color3.fromRGB(255,100,100)
		else speedoNumber.TextColor3=Color3.fromRGB(255,255,255) end
		local cap=state.bhop and BHOP_MAX_SPEED or 50
		TweenService:Create(speedoBar,TweenInfo.new(0.05),{Size=UDim2.new(math.clamp(flatSpeed/cap,0,1),0,0,3)}):Play()
	else
		speedoFrame.Visible=false
	end
	prevSpeed=flatSpeed

	-- Bhop
	if state.bhop then
		local isGrounded=hum.FloorMaterial~=Enum.Material.Air
		if not isGrounded then
			local cam=workspace.CurrentCamera
			local rl=cam.CFrame.LookVector
			local rr=cam.CFrame.RightVector
			local cl=Vector3.new(rl.X,0,rl.Z)
			local cr=Vector3.new(rr.X,0,rr.Z)
			if cl.Magnitude>0 then cl=cl.Unit end
			if cr.Magnitude>0 then cr=cr.Unit end
			local wd=Vector3.new(0,0,0)
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then wd=wd+cl end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then wd=wd-cl end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then wd=wd+cr end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then wd=wd-cr end
			local fv=Vector3.new(vel.X,0,vel.Z)
			if wd.Magnitude>0 then
				wd=wd.Unit
				local saw=fv:Dot(wd)
				local add=BHOP_MAX_SPEED-saw
				if add>0 then
					local ac=math.min(BHOP_ACCEL,add)
					fv=fv+wd*ac
					if fv.Magnitude>BHOP_MAX_SPEED then fv=fv.Unit*BHOP_MAX_SPEED end
				end
			else
				fv=fv*BHOP_FRICTION
			end
			hrp.AssemblyLinearVelocity=Vector3.new(fv.X,vel.Y,fv.Z)
		end
		if isGrounded and UserInputService:IsKeyDown(Enum.KeyCode.Space) then hum.Jump=true end
		wasInAir=not isGrounded
		speedInfo.Text=string.format("Speed: %.1f / %d su/s",flatSpeed,BHOP_MAX_SPEED)
	else
		speedInfo.Text="Speed: —"
		wasInAir=false
	end
end)

player.CharacterAdded:Connect(function()
	flyBodyVelocity=nil flyBodyGyro=nil
	if state.fly then task.wait(1) startFly() end
end)

-- ESP polling
task.spawn(function()
	while true do task.wait(0.5) refreshEsp() end
end)

-- ============================================================
-- ESP BOXES
-- ============================================================
local espBoxGui = Instance.new("ScreenGui")
espBoxGui.Name = "ESPBoxes"
espBoxGui.ResetOnSpawn = false
espBoxGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
espBoxGui.IgnoreGuiInset = true
espBoxGui.Parent = player.PlayerGui

local boxFrames = {}

local function ensureBox(plr)
	if boxFrames[plr] then return end
	if plr==player then return end
	-- Team check: skip teammates
	if isSameTeam(plr) then return end

	local col = Color3.fromRGB(255,60,60)

	local outer=Instance.new("Frame")
	outer.BackgroundTransparency=1
	outer.BorderSizePixel=0
	outer.ZIndex=20
	outer.Parent=espBoxGui

	local function makeLine(x,y,w,h,c)
		local f=Instance.new("Frame")
		f.Position=UDim2.new(x,0,y,0)
		f.Size=UDim2.new(w,0,h,0)
		f.BackgroundColor3=c
		f.BackgroundTransparency=0.15
		f.BorderSizePixel=0
		f.ZIndex=21
		f.Parent=outer
		return f
	end
	local top=makeLine(0,0,1,0,col) top.Size=UDim2.new(1,0,0,1)
	local bot=makeLine(0,1,1,0,col) bot.Size=UDim2.new(1,0,0,1) bot.Position=UDim2.new(0,0,1,-1)
	local left=makeLine(0,0,0,1,col) left.Size=UDim2.new(0,1,1,0)
	local right=makeLine(1,0,0,1,col) right.Size=UDim2.new(0,1,1,0) right.Position=UDim2.new(1,-1,0,0)

	local nameLabel=Instance.new("TextLabel")
	nameLabel.Size=UDim2.new(1,0,0,14)
	nameLabel.Position=UDim2.new(0,0,0,-16)
	nameLabel.BackgroundTransparency=1
	nameLabel.Text=plr.Name..(plr.Team and (" ["..plr.Team.Name.."]") or "")
	nameLabel.TextColor3=Color3.fromRGB(255,255,255)
	nameLabel.TextSize=11
	nameLabel.Font=Enum.Font.GothamBold
	nameLabel.TextStrokeTransparency=0.3
	nameLabel.TextStrokeColor3=Color3.fromRGB(0,0,0)
	nameLabel.ZIndex=22
	nameLabel.Parent=outer

	local hpBg=Instance.new("Frame")
	hpBg.Size=UDim2.new(0,3,1,0)
	hpBg.Position=UDim2.new(0,-6,0,0)
	hpBg.BackgroundColor3=Color3.fromRGB(30,30,30)
	hpBg.BackgroundTransparency=0.3
	hpBg.BorderSizePixel=0
	hpBg.ZIndex=21
	hpBg.Parent=outer

	local hpFill=Instance.new("Frame")
	hpFill.Size=UDim2.new(1,0,1,0)
	hpFill.AnchorPoint=Vector2.new(0,1)
	hpFill.Position=UDim2.new(0,0,1,0)
	hpFill.BackgroundColor3=Color3.fromRGB(80,220,80)
	hpFill.BorderSizePixel=0
	hpFill.ZIndex=22
	hpFill.Parent=hpBg

	local hpLabel=Instance.new("TextLabel")
	hpLabel.Size=UDim2.new(1,0,0,12)
	hpLabel.Position=UDim2.new(0,0,1,2)
	hpLabel.BackgroundTransparency=1
	hpLabel.Text="100 HP"
	hpLabel.TextColor3=Color3.fromRGB(200,200,200)
	hpLabel.TextSize=10
	hpLabel.Font=Enum.Font.Gotham
	hpLabel.TextStrokeTransparency=0.3
	hpLabel.TextStrokeColor3=Color3.fromRGB(0,0,0)
	hpLabel.ZIndex=22
	hpLabel.Parent=outer

	boxFrames[plr]={outer=outer,nameLabel=nameLabel,hpFill=hpFill,hpLabel=hpLabel}
end

local function removeBox(plr)
	if boxFrames[plr] then
		pcall(function() boxFrames[plr].outer:Destroy() end)
		boxFrames[plr]=nil
	end
end

RunService.RenderStepped:Connect(function()
	if not state.espboxes then
		for plr,_ in pairs(boxFrames) do removeBox(plr) end
		return
	end
	local cam=workspace.CurrentCamera
	local vp=cam.ViewportSize
	for _,plr in ipairs(Players:GetPlayers()) do
		if plr==player then continue end
		-- Team check
		if isSameTeam(plr) then removeBox(plr) continue end

		local char2=plr.Character
		if not char2 then removeBox(plr) continue end
		local hrp2=char2:FindFirstChild("HumanoidRootPart")
		if not hrp2 then removeBox(plr) continue end
		ensureBox(plr)
		local box=boxFrames[plr]
		if not box then continue end
		local pos=hrp2.Position
		local corners={
			Vector3.new(-1,3,-1),Vector3.new(1,3,-1),Vector3.new(-1,3,1),Vector3.new(1,3,1),
			Vector3.new(-1,-3,-1),Vector3.new(1,-3,-1),Vector3.new(-1,-3,1),Vector3.new(1,-3,1),
		}
		local minX,minY,maxX,maxY=math.huge,math.huge,-math.huge,-math.huge
		local ok=true
		for _,offset in ipairs(corners) do
			local sp,on=cam:WorldToViewportPoint(pos+offset)
			if not on or sp.Z<0 then ok=false break end
			if sp.X<minX then minX=sp.X end
			if sp.Y<minY then minY=sp.Y end
			if sp.X>maxX then maxX=sp.X end
			if sp.Y>maxY then maxY=sp.Y end
		end
		if not ok or minX>vp.X or maxX<0 or minY>vp.Y or maxY<0 then
			box.outer.Visible=false continue
		end
		box.outer.Visible=true
		box.outer.Position=UDim2.new(0,minX,0,minY)
		box.outer.Size=UDim2.new(0,maxX-minX,0,maxY-minY)
		local hum2=char2:FindFirstChildOfClass("Humanoid")
		if hum2 then
			local a=math.clamp(hum2.Health/hum2.MaxHealth,0,1)
			box.hpFill.Size=UDim2.new(1,0,a,0)
			box.hpFill.BackgroundColor3=Color3.fromRGB(math.round((1-a)*220),math.round(a*200+20),40)
			box.hpLabel.Text=math.round(hum2.Health).." HP"
		end
	end
	for plr,_ in pairs(boxFrames) do
		if not plr or not plr.Parent then removeBox(plr) end
	end
end)

Players.PlayerRemoving:Connect(function(plr) removeBox(plr) end)

-- ============================================================
-- AIMBOT LOOP  (uses keybind + hitbox selector + team check)
-- ============================================================
RunService.RenderStepped:Connect(function()
	fovCircle.Visible = state.aimbotfov

	if not state.aimbot then
		fovStroke.Color=Color3.fromRGB(255,255,255)
		return
	end
	if not isBindHeld("aimbot") then
		fovStroke.Color=Color3.fromRGB(255,255,255)
		return
	end

	local myChar=player.Character
	if not myChar then return end
	local cam=workspace.CurrentCamera
	local vp=cam.ViewportSize
	local center=Vector2.new(vp.X/2,vp.Y/2)

	local bestDist=math.huge
	local bestPos=nil

	for _,plr in ipairs(Players:GetPlayers()) do
		if plr==player then continue end
		-- Team check: skip teammates
		if isSameTeam(plr) then continue end

		local char2=plr.Character
		if not char2 then continue end
		local hum2=char2:FindFirstChildOfClass("Humanoid")
		if hum2 and hum2.Health<=0 then continue end

		local targetPart=getHitboxPart(char2)
		if not targetPart then continue end

		local sp,on=cam:WorldToViewportPoint(targetPart.Position)
		if not on or sp.Z<0 then continue end

		local dist=(Vector2.new(sp.X,sp.Y)-center).Magnitude
		if dist<AIMBOT_FOV and dist<bestDist then
			bestDist=dist
			bestPos=targetPart.Position
		end
	end

	if bestPos then
		fovStroke.Color=Color3.fromRGB(255,60,60)
		local cur=cam.CFrame
		local tar=CFrame.new(cur.Position,bestPos)
		local smooth=math.clamp(1-AIMBOT_SMOOTH,0.01,1)
		cam.CFrame=cur:Lerp(tar,smooth)
	else
		fovStroke.Color=Color3.fromRGB(255,255,255)
	end
end)

-- ============================================================
-- TRIGGERBOT LOOP  (team check)
-- ============================================================
task.spawn(function()
	while true do
		task.wait(0.01)
		if not state.triggerbot then continue end
		local char=player.Character
		if not char then continue end
		local cam=workspace.CurrentCamera
		local ur=cam:ScreenPointToRay(cam.ViewportSize.X/2,cam.ViewportSize.Y/2)
		local rp=RaycastParams.new()
		rp.FilterDescendantsInstances={char}
		rp.FilterType=Enum.RaycastFilterType.Exclude
		local result=workspace:Raycast(ur.Origin,ur.Direction*500,rp)
		if result and result.Instance then
			local hitChar=result.Instance:FindFirstAncestorOfClass("Model")
			if hitChar then
				local hitPlayer=Players:GetPlayerFromCharacter(hitChar)
				if hitPlayer and hitPlayer~=player and not triggerCooldown then
					-- Team check
					if isSameTeam(hitPlayer) then continue end
					triggerCooldown=true
					task.wait(TRIGGER_DELAY)
					local vim=game:GetService("VirtualInputManager")
					vim:SendMouseButtonEvent(0,0,0,true,game,1)
					vim:SendMouseButtonEvent(0,0,0,false,game,1)
					task.wait(0.1)
					triggerCooldown=false
				end
			end
		end
	end
end)

-- ============================================================
-- INIT
-- ============================================================
setActiveTab("Aim")
print("[ModMenu] Loaded — INSERT to show/hide")