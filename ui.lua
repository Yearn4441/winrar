--==============================================================================--
--  Apple x disconnect.wtf Premium Drawing.new UI Library
--  Features: Custom Rounded Corners, Smooth Lerp Dragging, Fluid Tab Alpha Switching
--==============================================================================--

local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")

-- Dark Apple x disconnect.wtf Palette
local Theme = {
    Background    = Color3.fromRGB(15, 16, 22),
    Sidebar       = Color3.fromRGB(22, 24, 32),
    CardBg        = Color3.fromRGB(26, 28, 38),
    Accent        = Color3.fromRGB(99, 102, 241),   -- Electric Indigo/Purple
    AccentGlow    = Color3.fromRGB(129, 140, 248),
    TextPrimary   = Color3.fromRGB(245, 245, 250),
    TextMuted     = Color3.fromRGB(140, 145, 165),
    ToggleOff     = Color3.fromRGB(40, 43, 56),
    ToggleOn      = Color3.fromRGB(99, 102, 241),
    Border        = Color3.fromRGB(45, 48, 65),
    Separator     = Color3.fromRGB(32, 35, 48)
}

-- Library Core Window
local Window = {
    Position      = Vector2.new(200, 150),
    TargetPosition= Vector2.new(200, 150),
    Size          = Vector2.new(620, 400),
    CornerRadius  = 14,
    SidebarWidth  = 75,
    ActiveTab     = "Weapons",
    TabAlpha      = 1.0,
    TargetTab     = "Weapons",
    Dragging      = false,
    DragOffset    = Vector2.new(0,0),
    Drawings      = {},
    TabObjects    = { Weapons = {}, Misc = {} }
}

-- Utility: Rounded Rect Generator using Triangle/Square Primitives
local function DrawRoundedRect(pos, size, radius, color, transparency)
    local objs = {}
    radius = math.min(radius, math.min(size.X, size.Y) / 2)

    -- Center cross rectangles
    local centerH = Drawing.new("Square")
    centerH.Size = Vector2.new(size.X - radius * 2, size.Y)
    centerH.Position = Vector2.new(pos.X + radius, pos.Y)
    centerH.Color = color
    centerH.Filled = true
    centerH.Transparency = transparency or 1
    centerH.Visible = true
    table.insert(objs, centerH)

    local centerV = Drawing.new("Square")
    centerV.Size = Vector2.new(size.X, size.Y - radius * 2)
    centerV.Position = Vector2.new(pos.X, pos.Y + radius)
    centerV.Color = color
    centerV.Filled = true
    centerV.Transparency = transparency or 1
    centerV.Visible = true
    table.insert(objs, centerV)

    -- Corner Circles (Faking rounded corners cleanly)
    local corners = {
        Vector2.new(pos.X + radius, pos.Y + radius),
        Vector2.new(pos.X + size.X - radius, pos.Y + radius),
        Vector2.new(pos.X + radius, pos.Y + size.Y - radius),
        Vector2.new(pos.X + size.X - radius, pos.Y + size.Y - radius)
    }

    for _, cPos in ipairs(corners) do
        local circle = Drawing.new("Circle")
        circle.Position = cPos
        circle.Radius = radius
        circle.Color = color
        circle.Filled = true
        circle.NumSides = 16
        circle.Transparency = transparency or 1
        circle.Visible = true
        table.insert(objs, circle)
    end

    return objs
end

-- Create Window Container Base
local MainBg = DrawRoundedRect(Window.Position, Window.Size, Window.CornerRadius, Theme.Background, 0.95)

-- Sidebar Pill Background
local SidebarBg = DrawRoundedRect(
    Window.Position + Vector2.new(8, 8),
    Vector2.new(Window.SidebarWidth - 12, Window.Size.Y - 16),
    10,
    Theme.Sidebar,
    1.0
)

-- Window Header Title
local HeaderTitle = Drawing.new("Text")
HeaderTitle.Text = "WEAPONS"
HeaderTitle.Size = 18
HeaderTitle.Font = 2
HeaderTitle.Color = Theme.TextPrimary
HeaderTitle.Position = Window.Position + Vector2.new(Window.SidebarWidth + 25, 20)
HeaderTitle.Visible = true

-- Tab System Builder
local TabsDef = {
    { Name = "Weapons", Icon = "🎯", YOffset = 25 },
    { Name = "Misc",    Icon = "⚡", YOffset = 80 }
}

local TabButtons = {}

for _, tab in ipairs(TabsDef) do
    local bPos = Window.Position + Vector2.new(16, tab.YOffset)
    
    local indicator = DrawRoundedRect(bPos, Vector2.new(42, 42), 12, (tab.Name == Window.ActiveTab) and Theme.Accent or Theme.Sidebar, 1.0)
    
    local icon = Drawing.new("Text")
    icon.Text = tab.Icon
    icon.Size = 18
    icon.Position = bPos + Vector2.new(13, 11)
    icon.Color = Theme.TextPrimary
    icon.Visible = true

    table.insert(TabButtons, {
        Name = tab.Name,
        Indicator = indicator,
        Icon = icon,
        Pos = bPos,
        Bounds = { Min = bPos, Max = bPos + Vector2.new(42, 42) }
    })
end

-- Toggle Element Instantiator
local function AddToggle(tabName, labelText, defaultState, yPos, callback)
    local posX = Window.Position.X + Window.SidebarWidth + 25
    local posY = Window.Position.Y + yPos

    local label = Drawing.new("Text")
    label.Text = labelText
    label.Size = 14
    label.Position = Vector2.new(posX, posY + 2)
    label.Color = Theme.TextPrimary
    label.Visible = (Window.ActiveTab == tabName)

    local toggleBg = DrawRoundedRect(
        Vector2.new(Window.Position.X + Window.Size.X - 70, posY),
        Vector2.new(40, 20),
        10,
        defaultState and Theme.ToggleOn or Theme.ToggleOff,
        1.0
    )

    local knob = Drawing.new("Circle")
    knob.Radius = 7
    knob.Position = Vector2.new(
        defaultState and (Window.Position.X + Window.Size.X - 40) or (Window.Position.X + Window.Size.X - 60),
        posY + 10
    )
    knob.Color = Theme.TextPrimary
    knob.Filled = true
    knob.Visible = (Window.ActiveTab == tabName)

    local data = {
        State = defaultState,
        Tab = tabName,
        Drawings = { label, knob },
        BgDrawings = toggleBg,
        Bounds = {
            Min = Vector2.new(Window.Position.X + Window.Size.X - 70, posY),
            Max = Vector2.new(Window.Position.X + Window.Size.X - 30, posY + 20)
        },
        Update = function(self)
            knob.Position = Vector2.new(
                self.State and (Window.Position.X + Window.Size.X - 40) or (Window.Position.X + Window.Size.X - 60),
                posY + 10
            )
            for _, d in ipairs(self.BgDrawings) do
                d.Color = self.State and Theme.ToggleOn or Theme.ToggleOff
            end
            if callback then callback(self.State) end
        end
    }

    table.insert(Window.TabObjects[tabName], data)
end

-- Slider Element Instantiator
local function AddSlider(tabName, labelText, minVal, maxVal, defaultVal, suffix, yPos, callback)
    local posX = Window.Position.X + Window.SidebarWidth + 25
    local posY = Window.Position.Y + yPos

    local label = Drawing.new("Text")
    label.Text = labelText
    label.Size = 14
    label.Position = Vector2.new(posX, posY)
    label.Color = Theme.TextPrimary
    label.Visible = (Window.ActiveTab == tabName)

    local valText = Drawing.new("Text")
    valText.Text = tostring(defaultVal) .. " " .. suffix
    valText.Size = 13
    valText.Position = Vector2.new(Window.Position.X + Window.Size.X - 180, posY)
    valText.Color = Theme.TextMuted
    valText.Visible = (Window.ActiveTab == tabName)

    local track = DrawRoundedRect(
        Vector2.new(Window.Position.X + Window.Size.X - 130, posY + 5),
        Vector2.new(100, 6),
        3,
        Theme.ToggleOff,
        1.0
    )

    local pct = math.clamp((defaultVal - minVal) / (maxVal - minVal), 0, 1)
    local fill = DrawRoundedRect(
        Vector2.new(Window.Position.X + Window.Size.X - 130, posY + 5),
        Vector2.new(pct * 100, 6),
        3,
        Theme.Accent,
        1.0
    )

    local data = {
        Value = defaultVal,
        Min = minVal,
        Max = maxVal,
        Tab = tabName,
        Drawings = { label, valText },
        Track = track,
        Fill = fill,
        Update = function(self, mouseX)
            local trackX = Window.Position.X + Window.Size.X - 130
            local p = math.clamp((mouseX - trackX) / 100, 0, 1)
            self.Value = math.floor(self.Min + (self.Max - self.Min) * p)
            valText.Text = tostring(self.Value) .. " " .. suffix
            for _, f in ipairs(self.Fill) do
                f.Size = Vector2.new(p * 100, f.Size.Y)
            end
            if callback then callback(self.Value) end
        end
    }

    table.insert(Window.TabObjects[tabName], data)
end

-- Initialize Content
AddToggle("Weapons", "Aimbot Silent Aim", true, 65, function(v) end)
AddSlider("Weapons", "Field of View", 30, 360, 120, "deg", 105, function(v) end)
AddToggle("Weapons", "Smooth Recoil Control", true, 145, function(v) end)

AddToggle("Misc", "Streamproof Overlay", true, 65, function(v) end)
AddSlider("Misc", "Target Distance", 100, 5000, 2500, "m", 105, function(v) end)
AddToggle("Misc", "Unlock Frame Rate", false, 145, function(v) end)

-- Smooth RenderStepped Loop for Physics & Lerping
RunService.RenderStepped:Connect(function(dt)
    -- Smooth Drag Position Interpolation (Apple Physics Lerp)
    if Window.Dragging then
        local mousePos = UserInputService:GetMouseLocation()
        Window.TargetPosition = mousePos - Window.DragOffset
    end

    Window.Position = Window.Position:Lerp(Window.TargetPosition, math.clamp(dt * 18, 0, 1))

    -- Smooth Tab Alpha Fade Interpolation
    if Window.ActiveTab ~= Window.TargetTab then
        Window.TabAlpha = math.max(0, Window.TabAlpha - dt * 10)
        if Window.TabAlpha <= 0.05 then
            Window.ActiveTab = Window.TargetTab
            HeaderTitle.Text = string.upper(Window.ActiveTab)
        end
    else
        Window.TabAlpha = math.min(1, Window.TabAlpha + dt * 10)
    end

    -- Update Tab Element Visibilities & Alpha
    for tabName, objs in pairs(Window.TabObjects) do
        local isCurrent = (tabName == Window.ActiveTab)
        for _, item in ipairs(objs) do
            for _, d in ipairs(item.Drawings) do
                d.Visible = isCurrent
                if d:IsA("Text") then
                    d.Transparency = Window.TabAlpha
                end
            end
        end
    end
end)

-- User Dragging & Interaction Events
UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local mousePos = UserInputService:GetMouseLocation()

        -- Title Bar Dragging Header Check
        if mousePos.X >= Window.Position.X and mousePos.X <= Window.Position.X + Window.Size.X and
           mousePos.Y >= Window.Position.Y and mousePos.Y <= Window.Position.Y + 45 then
            Window.Dragging = true
            Window.DragOffset = mousePos - Window.Position
            return
        end

        -- Sidebar Tab Navigation Check
        for _, btn in ipairs(TabButtons) do
            if mousePos.X >= btn.Bounds.Min.X and mousePos.X <= btn.Bounds.Max.X and
               mousePos.Y >= btn.Bounds.Min.Y and mousePos.Y <= btn.Bounds.Max.Y then
                Window.TargetTab = btn.Name
                return
            end
        end

        -- Element Interaction Check
        for _, item in ipairs(Window.TabObjects[Window.ActiveTab]) do
            if item.Bounds and mousePos.X >= item.Bounds.Min.X and mousePos.X <= item.Bounds.Max.X and
               mousePos.Y >= item.Bounds.Min.Y and mousePos.Y <= item.Bounds.Max.Y then
                item.State = not item.State
                item:Update()
            end
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        Window.Dragging = false
    end
end)
