--==============================================================================
-- disconnect.wtf x Apple UI
-- Premium Dark Purple Edition
-- Drawing.new UI module
--
-- Usage:
--     local UI = require(path.to.ui)
--     local window = UI.new()
--     window.Controls.SilentAim:SetCallback(function(enabled) ... end)
--     window:Unload()
--
-- Requires an environment that provides Drawing.new.
--==============================================================================--

-- Services (were missing — caused runtime errors on InputBegan / RenderStepped)
local UIS        = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local UI = {}

local DEFAULT_THEME = {
    Background  = Color3.fromRGB(13,  13,  17),
    Sidebar     = Color3.fromRGB(19,  19,  25),
    Card        = Color3.fromRGB(25,  25,  33),
    CardHover   = Color3.fromRGB(32,  30,  43),

    Accent      = Color3.fromRGB(145, 85,  255),
    AccentLight = Color3.fromRGB(175, 125, 255),

    Text        = Color3.fromRGB(245, 245, 250),
    Muted       = Color3.fromRGB(135, 133, 150),
    Border      = Color3.fromRGB(42,  40,  53),

    ToggleOff   = Color3.fromRGB(55,  53,  65),
    ToggleOn    = Color3.fromRGB(145, 85,  255),
    White       = Color3.fromRGB(255, 255, 255),
}

local WINDOW_SIZE    = Vector2.new(650, 420)
local SIDEBAR_WIDTH  = 155
local CONTENT_X      = 180
local CONTENT_WIDTH  = 435

local function copyTable(source)
    local result = {}
    for k, v in pairs(source) do result[k] = v end
    return result
end

local function newDrawing(className, properties)
    local obj = Drawing.new(className)
    for k, v in pairs(properties or {}) do obj[k] = v end
    return obj
end

local function makeRoundedRect(position, size, radius, color)
    local objects = {}
    local self = {
        Objects  = objects,
        Position = position,
        Size     = size,
        Radius   = math.min(radius, size.X / 2, size.Y / 2),
        Removed  = false,
    }

    local horizontal = newDrawing("Square", { Color = color, Filled = true, Transparency = 1, Visible = true })
    local vertical   = newDrawing("Square", { Color = color, Filled = true, Transparency = 1, Visible = true })
    table.insert(objects, horizontal)
    table.insert(objects, vertical)

    local corners = {}
    for i = 1, 4 do
        local c = newDrawing("Circle", {
            Radius = self.Radius, NumSides = 24,
            Filled = true, Color = color, Transparency = 1, Visible = true,
        })
        corners[i] = c
        table.insert(objects, c)
    end

    function self:SetPosition(p)
        if self.Removed then return end
        self.Position = p
        local s, r = self.Size, self.Radius
        horizontal.Position = p + Vector2.new(r, 0)
        horizontal.Size     = Vector2.new(math.max(0, s.X - r * 2), s.Y)
        vertical.Position   = p + Vector2.new(0, r)
        vertical.Size       = Vector2.new(s.X, math.max(0, s.Y - r * 2))
        corners[1].Position = p + Vector2.new(r,        r)
        corners[2].Position = p + Vector2.new(s.X - r,  r)
        corners[3].Position = p + Vector2.new(r,        s.Y - r)
        corners[4].Position = p + Vector2.new(s.X - r,  s.Y - r)
    end

    function self:SetSize(newSize)
        if self.Removed then return end
        self.Size   = newSize
        self.Radius = math.min(self.Radius, newSize.X / 2, newSize.Y / 2)
        for _, c in ipairs(corners) do c.Radius = self.Radius end
        self:SetPosition(self.Position)
    end

    function self:SetColor(c)
        if self.Removed then return end
        for _, o in ipairs(objects) do o.Color = c end
    end

    function self:SetTransparency(t)
        if self.Removed then return end
        for _, o in ipairs(objects) do o.Transparency = t end
    end

    function self:SetVisible(v)
        if self.Removed then return end
        for _, o in ipairs(objects) do o.Visible = v end
    end

    function self:Remove()
        if self.Removed then return end
        self.Removed = true
        for _, o in ipairs(objects) do o:Remove() end
    end

    self:SetPosition(position)
    return self
end

local function makeText(value, size, color, position, font)
    return newDrawing("Text", {
        Text         = tostring(value),
        Size         = size,
        Font         = font or 0,
        Color        = color,
        Position     = position,
        Transparency = 1,
        Visible      = true,
        Center       = false,
        Outline      = false,
    })
end

local function isInside(point, bounds)
    return bounds
        and point.X >= bounds.Min.X and point.X <= bounds.Max.X
        and point.Y >= bounds.Min.Y and point.Y <= bounds.Max.Y
end

local function lerpNumber(a, b, t)
    return a + (b - a) * t
end

--==============================================================================
-- PUBLIC CONSTRUCTOR
--==============================================================================--

function UI.new(options)
    options = options or {}

    local theme = copyTable(DEFAULT_THEME)
    for k, v in pairs(options.Theme or {}) do theme[k] = v end

    local userCallbacks = options.Callbacks or {}

    local window = {
        Position       = options.Position or Vector2.new(200, 150),
        TargetPosition = options.Position or Vector2.new(200, 150),
        Size           = WINDOW_SIZE,
        SidebarWidth   = SIDEBAR_WIDTH,

        ActiveTab  = "Main",
        TargetTab  = "Main",
        TabAlpha   = 1,

        Dragging     = false,
        DragOffset   = Vector2.zero,
        ActiveSlider = nil,

        Tabs      = { Main = {}, Misc = {} },
        Destroyed = false,
    }

    local api = {
        Controls     = {},
        Destroyed    = false,
        OnTabChanged = nil,
    }

    local function register(tabName, element)
        if not window.Tabs[tabName] then
            error("Unknown UI tab: " .. tostring(tabName))
        end
        table.insert(window.Tabs[tabName], element)
    end

    -- ── Section ──────────────────────────────────────────────────────────────

    local function addSection(tabName, title, subtitle, y)
        local el = { Tab = tabName, Y = y }
        el.Title    = makeText(title,    14, theme.Text,  Vector2.zero)
        el.Subtitle = makeText(subtitle, 10, theme.Muted, Vector2.zero)

        function el:UpdateLayout()
            local p = window.Position
            self.Title.Position    = p + Vector2.new(CONTENT_X + 5, self.Y)
            self.Subtitle.Position = p + Vector2.new(CONTENT_X + 5, self.Y + 19)
        end
        function el:SetVisible(v)    self.Title.Visible = v;       self.Subtitle.Visible = v    end
        function el:SetTransparency(t) self.Title.Transparency = t; self.Subtitle.Transparency = t end
        function el:Remove()         self.Title:Remove();          self.Subtitle:Remove()        end

        el:UpdateLayout()
        register(tabName, el)
        return el
    end

    -- ── Toggle ───────────────────────────────────────────────────────────────

    local function addToggle(tabName, key, label, description, defaultValue, y)
        local el = {
            Tab          = tabName,
            Key          = key,
            Name         = label,
            Description  = description,
            State        = not not defaultValue,
            TargetState  = not not defaultValue,
            KnobProgress = defaultValue and 1 or 0,
            Y            = y,
            Bounds       = nil,
            Callback     = userCallbacks[key],
        }

        el.Card            = makeRoundedRect(Vector2.zero, Vector2.new(CONTENT_WIDTH, 59), 10, theme.Card)
        el.Label           = makeText(label,       13, theme.Text,  Vector2.zero)
        el.DescriptionText = makeText(description, 10, theme.Muted, Vector2.zero)
        el.Switch          = makeRoundedRect(Vector2.zero, Vector2.new(43, 24), 12,
                                 el.State and theme.ToggleOn or theme.ToggleOff)
        el.Knob = newDrawing("Circle", {
            Radius = 9, NumSides = 24, Filled = true,
            Color = theme.White, Transparency = 1, Visible = true,
        })

        function el:SetCallback(cb)
            assert(cb == nil or type(cb) == "function", "Callback must be a function or nil")
            self.Callback = cb
            return self
        end

        function el:SetState(state, silent)
            state = not not state
            local changed = self.State ~= state
            self.State = state; self.TargetState = state
            if changed and not silent and self.Callback then self.Callback(state) end
            return self
        end

        function el:GetState() return self.State end

        function el:UpdateLayout(dt)
            local p   = window.Position
            local x   = p.X + CONTENT_X
            local yp  = p.Y + self.Y

            self.Card:SetPosition(Vector2.new(x, yp))
            self.Label.Position           = Vector2.new(x + 15, yp + 11)
            self.DescriptionText.Position = Vector2.new(x + 15, yp + 32)

            local sx = x + CONTENT_WIDTH - 60
            local sy = yp + 17
            self.Switch:SetPosition(Vector2.new(sx, sy))

            local target = self.TargetState and 1 or 0
            self.KnobProgress = lerpNumber(self.KnobProgress, target,
                math.clamp((dt or 1/60) * 17, 0, 1))

            self.Switch:SetColor(theme.ToggleOff:Lerp(theme.ToggleOn, self.KnobProgress))
            self.Knob.Position = Vector2.new(sx + 12 + self.KnobProgress * 19, sy + 12)

            self.Bounds = {
                Min = Vector2.new(x, yp),
                Max = Vector2.new(x + CONTENT_WIDTH, yp + 59),
            }
        end

        function el:SetVisible(v)
            self.Card:SetVisible(v); self.Switch:SetVisible(v)
            self.Label.Visible = v;  self.DescriptionText.Visible = v; self.Knob.Visible = v
        end
        function el:SetTransparency(t)
            self.Card:SetTransparency(t); self.Switch:SetTransparency(t)
            self.Label.Transparency = t;  self.DescriptionText.Transparency = t; self.Knob.Transparency = t
        end
        function el:Remove()
            self.Card:Remove(); self.Switch:Remove()
            self.Label:Remove(); self.DescriptionText:Remove(); self.Knob:Remove()
        end

        el:UpdateLayout(1/60)
        register(tabName, el)
        api.Controls[key] = el
        return el
    end

    -- ── Slider ───────────────────────────────────────────────────────────────

    local function addSlider(tabName, key, label, minimum, maximum, defaultValue, suffix, y)
        assert(maximum > minimum, "Slider maximum must be greater than minimum")

        local el = {
            Tab      = tabName,
            Key      = key,
            Name     = label,
            Min      = minimum,
            Max      = maximum,
            Value    = math.clamp(defaultValue, minimum, maximum),
            Suffix   = suffix or "",
            Y        = y,
            Bounds   = nil,
            Callback = userCallbacks[key],
        }

        el.Card      = makeRoundedRect(Vector2.zero, Vector2.new(CONTENT_WIDTH, 70), 10, theme.Card)
        el.Label     = makeText(label, 13, theme.Text, Vector2.zero)
        el.ValueText = makeText(tostring(el.Value) .. " " .. el.Suffix, 11, theme.AccentLight, Vector2.zero)
        el.Track     = makeRoundedRect(Vector2.zero, Vector2.new(390, 5), 2.5, theme.ToggleOff)
        el.Fill      = makeRoundedRect(Vector2.zero, Vector2.new(1,   5), 2,   theme.Accent)
        el.Knob      = newDrawing("Circle", {
            Radius = 7, NumSides = 24, Filled = true,
            Color = theme.White, Visible = true, Transparency = 1,
        })

        function el:SetCallback(cb)
            assert(cb == nil or type(cb) == "function", "Callback must be a function or nil")
            self.Callback = cb
            return self
        end

        function el:SetValue(value, silent)
            local next = math.clamp(math.floor(value + 0.5), self.Min, self.Max)
            local changed = self.Value ~= next
            self.Value = next
            self.ValueText.Text = tostring(self.Value) .. " " .. self.Suffix
            self:UpdateLayout()
            if changed and not silent and self.Callback then self.Callback(self.Value) end
            return self
        end

        function el:GetValue() return self.Value end

        function el:UpdateFromMouse(mouseX)
            local trackX     = window.Position.X + CONTENT_X + 15
            local percentage = math.clamp((mouseX - trackX) / 390, 0, 1)
            self:SetValue(self.Min + (self.Max - self.Min) * percentage)
        end

        function el:UpdateLayout()
            local p   = window.Position
            local x   = p.X + CONTENT_X
            local yp  = p.Y + self.Y

            self.Card:SetPosition(Vector2.new(x, yp))
            self.Label.Position     = Vector2.new(x + 15, yp + 11)
            self.ValueText.Position = Vector2.new(x + CONTENT_WIDTH - 90, yp + 11)

            local trackX = p.X + CONTENT_X + 15
            local trackY = yp + 49
            local pct    = (self.Value - self.Min) / (self.Max - self.Min)
            local fw     = math.max(1, pct * 390)

            self.Track:SetPosition(Vector2.new(trackX, trackY))
            self.Fill:SetPosition(Vector2.new(trackX, trackY))
            self.Fill:SetSize(Vector2.new(fw, 5))
            self.Knob.Position = Vector2.new(trackX + pct * 390, trackY + 2.5)

            self.Bounds = {
                Min = Vector2.new(trackX - 7,  trackY - 13),
                Max = Vector2.new(trackX + 397, trackY + 16),
            }
        end

        function el:SetVisible(v)
            self.Card:SetVisible(v); self.Track:SetVisible(v); self.Fill:SetVisible(v)
            self.Label.Visible = v;  self.ValueText.Visible = v; self.Knob.Visible = v
        end
        function el:SetTransparency(t)
            self.Card:SetTransparency(t); self.Track:SetTransparency(t); self.Fill:SetTransparency(t)
            self.Label.Transparency = t;  self.ValueText.Transparency = t; self.Knob.Transparency = t
        end
        function el:Remove()
            self.Card:Remove(); self.Track:Remove(); self.Fill:Remove()
            self.Label:Remove(); self.ValueText:Remove(); self.Knob:Remove()
        end

        el:UpdateLayout()
        register(tabName, el)
        api.Controls[key] = el
        return el
    end

    -- ── Window shell ─────────────────────────────────────────────────────────

    local background     = makeRoundedRect(window.Position, window.Size, 15, theme.Background)
    local sidebar        = makeRoundedRect(window.Position + Vector2.new(8, 8),
                               Vector2.new(window.SidebarWidth, window.Size.Y - 16), 11, theme.Sidebar)
    local logo           = makeText(options.Title          or "disconnect.wtf",      17, theme.Text,  Vector2.zero)
    local logoSubtitle   = makeText(options.BrandSubtitle  or "PREMIUM INTERFACE",    9, theme.Muted, Vector2.zero)
    local header         = makeText("Main",                                           19, theme.Text,  Vector2.zero)
    local headerSubtitle = makeText(options.Subtitle       or "Configure your experience", 11, theme.Muted, Vector2.zero)
    local separator      = newDrawing("Square", {
        Color = theme.Border, Filled = true, Transparency = 1,
        Visible = true, Size = Vector2.new(1, 380),
    })

    -- ── Sidebar tabs ─────────────────────────────────────────────────────────

    local tabButtons = {}
    local tabDefinitions = {
        { Name = "Main", Icon = "M", Offset = 95  },
        { Name = "Misc", Icon = "⚙", Offset = 145 },
    }

    for _, def in ipairs(tabDefinitions) do
        local btn = { Name = def.Name, Offset = def.Offset, Bounds = nil }
        btn.Background = makeRoundedRect(Vector2.zero, Vector2.new(133, 39), 9, theme.Sidebar)
        btn.Icon       = makeText(def.Icon,  16, theme.Muted, Vector2.zero)
        btn.Label      = makeText(def.Name,  13, theme.Muted, Vector2.zero)
        btn.Indicator  = makeRoundedRect(Vector2.zero, Vector2.new(3, 21), 2, theme.Accent)
        table.insert(tabButtons, btn)
    end

    -- ── Controls: Main tab ───────────────────────────────────────────────────
    --
    --  y=95  Section header
    --  y=130 SilentAim         (toggle 59px → ends 189)
    --  y=196 FieldOfView       (slider  70px → ends 266)
    --  y=273 RecoilControl     (toggle 59px → ends 332)
    --  y=339 InfiniteAmmo      (toggle 59px → ends 398)  ← new
    --
    addSection("Main", "Combat", "Weapon and targeting configuration", 95)
    addToggle("Main", "SilentAim",      "Silent Aim",       "Enable silent targeting",            true,  130)
    addSlider("Main", "FieldOfView",    "Field of View",    30, 360, 120, "deg",                         196)
    addToggle("Main", "RecoilControl",  "Recoil Control",   "Zero weapon + camera recoil",        true,  273)
    addToggle("Main", "InfiniteAmmo",   "Infinite Ammo",    "Set ammo values to math.huge",       true,  339)

    -- ── Controls: Misc tab ───────────────────────────────────────────────────
    --
    --  y=95  Section header
    --  y=130 FullAuto          (toggle 59px → ends 189)  ← new
    --  y=196 Streamproof       (toggle 59px → ends 255)
    --  y=262 TargetDistance    (slider  70px → ends 332)
    --  y=339 UnlockFPS         (toggle 59px → ends 398)
    --
    addSection("Misc", "Miscellaneous", "Additional interface and utility options", 95)
    addToggle("Misc", "FullAuto",        "Force Full-Auto",  "Set all weapons to ShootType 3",     true,  130)
    addToggle("Misc", "Streamproof",     "Streamproof",      "Hide overlay from supported captures",true, 196)
    addSlider("Misc", "TargetDistance",  "Target Distance",  100, 5000, 2500, "m",                        262)
    addToggle("Misc", "UnlockFPS",       "Unlock FPS",       "Remove the configured frame rate limit",false, 339)

    -- ── Layout & visibility ──────────────────────────────────────────────────

    local function updateLayout(dt)
        local p = window.Position

        background:SetPosition(p)
        sidebar:SetPosition(p + Vector2.new(8, 8))

        logo.Position           = p + Vector2.new(23, 25)
        logoSubtitle.Position   = p + Vector2.new(23, 47)
        header.Position         = p + Vector2.new(CONTENT_X, 25)
        headerSubtitle.Position = p + Vector2.new(CONTENT_X, 49)
        separator.Position      = p + Vector2.new(165, 82)

        for _, btn in ipairs(tabButtons) do
            local x  = p.X + 16
            local y  = p.Y + btn.Offset
            local active = btn.Name == window.TargetTab

            btn.Background:SetPosition(Vector2.new(x, y))
            btn.Icon.Position   = Vector2.new(x + 13, y + 10)
            btn.Label.Position  = Vector2.new(x + 43, y + 12)
            btn.Indicator:SetPosition(Vector2.new(x + 126, y + 9))

            btn.Background:SetColor(active and theme.CardHover or theme.Sidebar)
            btn.Icon.Color  = active and theme.AccentLight or theme.Muted
            btn.Label.Color = active and theme.Text        or theme.Muted
            btn.Indicator:SetVisible(active)

            btn.Bounds = {
                Min = Vector2.new(x, y),
                Max = Vector2.new(x + 133, y + 39),
            }
        end

        for _, elements in pairs(window.Tabs) do
            for _, el in ipairs(elements) do
                el:UpdateLayout(dt)
            end
        end
    end

    local function updateVisibility()
        for tabName, elements in pairs(window.Tabs) do
            local active = tabName == window.ActiveTab
            for _, el in ipairs(elements) do
                el:SetVisible(active)
                el:SetTransparency(window.TabAlpha)
            end
        end
    end

    local function changeTab(tabName)
        if not window.Tabs[tabName] or window.TargetTab == tabName then return end
        window.TargetTab = tabName
    end

    -- ── Input / render connections ───────────────────────────────────────────

    local inputBeganConnection
    local inputEndedConnection
    local renderConnection

    inputBeganConnection = UIS.InputBegan:Connect(function(input)
        if window.Destroyed then return end
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

        local mouse = UIS:GetMouseLocation()

        for _, btn in ipairs(tabButtons) do
            if isInside(mouse, btn.Bounds) then changeTab(btn.Name); return end
        end

        for _, el in ipairs(window.Tabs[window.ActiveTab]) do
            if el.Bounds and isInside(mouse, el.Bounds) then
                if el.State ~= nil then
                    el:SetState(not el.TargetState)
                elseif el.Value ~= nil then
                    window.ActiveSlider = el
                    el:UpdateFromMouse(mouse.X)
                end
                return
            end
        end

        -- Drag from top header area
        if mouse.X >= window.Position.X
            and mouse.X <= window.Position.X + window.Size.X
            and mouse.Y >= window.Position.Y
            and mouse.Y <= window.Position.Y + 75 then
            window.Dragging   = true
            window.DragOffset = mouse - window.Position
        end
    end)

    inputEndedConnection = UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            window.Dragging     = false
            window.ActiveSlider = nil
        end
    end)

    renderConnection = RunService.RenderStepped:Connect(function(dt)
        if window.Destroyed then return end

        if window.Dragging then
            local mouse = UIS:GetMouseLocation()
            window.TargetPosition = mouse - window.DragOffset
        end

        window.Position = window.Position:Lerp(
            window.TargetPosition,
            math.clamp(dt * 18, 0, 1)
        )

        if window.ActiveSlider then
            local mouse = UIS:GetMouseLocation()
            window.ActiveSlider:UpdateFromMouse(mouse.X)
        end

        if window.ActiveTab ~= window.TargetTab then
            window.TabAlpha = math.max(0, window.TabAlpha - dt * 8)
            if window.TabAlpha <= 0.02 then
                window.ActiveTab = window.TargetTab
                header.Text      = window.ActiveTab
                if api.OnTabChanged then api.OnTabChanged(window.ActiveTab) end
                window.TabAlpha = 0
            end
        else
            window.TabAlpha = math.min(1, window.TabAlpha + dt * 8)
        end

        updateLayout(dt)
        updateVisibility()
    end)

    -- ── Public API ───────────────────────────────────────────────────────────

    function api:SetTab(tabName)        changeTab(tabName); return self end
    function api:GetTab()               return window.ActiveTab          end

    function api:SetTabChangedCallback(cb)
        assert(cb == nil or type(cb) == "function", "Callback must be a function or nil")
        self.OnTabChanged = cb
        return self
    end

    function api:SetToggle(key, value, silent)
        local c = self.Controls[key]
        assert(c and c.SetState, "Unknown toggle: " .. tostring(key))
        c:SetState(value, silent)
        return self
    end

    function api:SetSlider(key, value, silent)
        local c = self.Controls[key]
        assert(c and c.SetValue, "Unknown slider: " .. tostring(key))
        c:SetValue(value, silent)
        return self
    end

    function api:Unload()
        if window.Destroyed then return end
        window.Destroyed = true
        self.Destroyed   = true
        window.Dragging     = false
        window.ActiveSlider = nil

        if renderConnection     then renderConnection:Disconnect();     renderConnection     = nil end
        if inputBeganConnection then inputBeganConnection:Disconnect(); inputBeganConnection = nil end
        if inputEndedConnection then inputEndedConnection:Disconnect(); inputEndedConnection = nil end

        background:Remove(); sidebar:Remove()
        logo:Remove(); logoSubtitle:Remove()
        header:Remove(); headerSubtitle:Remove()
        separator:Remove()

        for _, btn in ipairs(tabButtons) do
            btn.Background:Remove(); btn.Indicator:Remove()
            btn.Icon:Remove();       btn.Label:Remove()
        end

        for _, elements in pairs(window.Tabs) do
            for _, el in ipairs(elements) do el:Remove() end
        end
    end

    updateLayout(1/60)
    updateVisibility()

    print("[disconnect.wtf] UI module initialized.")
    return api
end

return UI
