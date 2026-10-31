--==============================================================================
-- disconnect.wtf x Apple UI  |  Premium Dark Purple Edition
-- Drawing.new UI module
--==============================================================================--

local UIS        = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local UI = {}

local DEFAULT_THEME = {
    Background  = Color3.fromRGB(11,  11,  15),
    Sidebar     = Color3.fromRGB(17,  17,  23),
    Card        = Color3.fromRGB(23,  23,  31),
    CardHover   = Color3.fromRGB(30,  28,  42),

    Accent      = Color3.fromRGB(138, 75,  255),
    AccentLight = Color3.fromRGB(170, 120, 255),
    AccentDim   = Color3.fromRGB(80,  40,  160),

    Text        = Color3.fromRGB(240, 240, 248),
    Muted       = Color3.fromRGB(120, 118, 140),
    Border      = Color3.fromRGB(38,  36,  52),

    ToggleOff   = Color3.fromRGB(50,  48,  62),
    ToggleOn    = Color3.fromRGB(138, 75,  255),
    White       = Color3.fromRGB(255, 255, 255),
}

-- Window dimensions
local WINDOW_W      = 660
local WINDOW_H      = 510
local WINDOW_SIZE   = Vector2.new(WINDOW_W, WINDOW_H)
local SIDEBAR_W     = 158
local CONTENT_X     = 183
local CONTENT_W     = WINDOW_W - CONTENT_X - 18   -- 459px
local TRACK_W       = CONTENT_W - 30               -- slider track width

-- Layout constants
local CTRL_GAP      = 6    -- px between consecutive controls
local TOGGLE_H      = 60
local SLIDER_H      = 72
local SECTION_Y_GAP = 38   -- from section y to first control

local function copyTable(t)
    local r = {}
    for k, v in pairs(t) do r[k] = v end
    return r
end

local function newDrawing(cls, props)
    local o = Drawing.new(cls)
    for k, v in pairs(props or {}) do o[k] = v end
    return o
end

-- Rounded rect built from two overlapping squares + four corner circles
local function makeRoundedRect(pos, size, radius, color)
    local objs = {}
    local s = {
        Objects  = objs,
        Position = pos,
        Size     = size,
        Radius   = math.min(radius, size.X / 2, size.Y / 2),
        Removed  = false,
    }

    local horiz = newDrawing("Square", { Color=color, Filled=true, Transparency=1, Visible=true })
    local vert  = newDrawing("Square", { Color=color, Filled=true, Transparency=1, Visible=true })
    table.insert(objs, horiz); table.insert(objs, vert)

    local corners = {}
    for i = 1, 4 do
        local c = newDrawing("Circle", {
            Radius=s.Radius, NumSides=32,
            Filled=true, Color=color, Transparency=1, Visible=true,
        })
        corners[i] = c; table.insert(objs, c)
    end

    function s:SetPosition(p)
        if self.Removed then return end
        self.Position = p
        local sz, r = self.Size, self.Radius
        horiz.Position = p + Vector2.new(r, 0)
        horiz.Size     = Vector2.new(math.max(0, sz.X - r*2), sz.Y)
        vert.Position  = p + Vector2.new(0, r)
        vert.Size      = Vector2.new(sz.X, math.max(0, sz.Y - r*2))
        corners[1].Position = p + Vector2.new(r,       r)
        corners[2].Position = p + Vector2.new(sz.X-r,  r)
        corners[3].Position = p + Vector2.new(r,       sz.Y-r)
        corners[4].Position = p + Vector2.new(sz.X-r,  sz.Y-r)
    end

    function s:SetSize(ns)
        if self.Removed then return end
        self.Size   = ns
        self.Radius = math.min(self.Radius, ns.X/2, ns.Y/2)
        for _, c in ipairs(corners) do c.Radius = self.Radius end
        self:SetPosition(self.Position)
    end

    function s:SetColor(c)
        if self.Removed then return end
        for _, o in ipairs(objs) do o.Color = c end
    end

    function s:SetTransparency(t)
        if self.Removed then return end
        for _, o in ipairs(objs) do o.Transparency = t end
    end

    function s:SetVisible(v)
        if self.Removed then return end
        for _, o in ipairs(objs) do o.Visible = v end
    end

    function s:Remove()
        if self.Removed then return end
        self.Removed = true
        for _, o in ipairs(objs) do o:Remove() end
    end

    s:SetPosition(pos)
    return s
end

local function makeText(val, size, color, pos, font)
    return newDrawing("Text", {
        Text=tostring(val), Size=size, Font=font or 0,
        Color=color, Position=pos, Transparency=1,
        Visible=true, Center=false, Outline=false,
    })
end

local function isInside(pt, b)
    return b
        and pt.X >= b.Min.X and pt.X <= b.Max.X
        and pt.Y >= b.Min.Y and pt.Y <= b.Max.Y
end

local function lerp(a, b, t) return a + (b-a)*t end

--==============================================================================
-- CONSTRUCTOR
--==============================================================================--

function UI.new(options)
    options = options or {}

    local theme = copyTable(DEFAULT_THEME)
    for k, v in pairs(options.Theme or {}) do theme[k] = v end

    local userCbs = options.Callbacks or {}

    local win = {
        Position       = options.Position or Vector2.new(200, 140),
        TargetPosition = options.Position or Vector2.new(200, 140),
        Size           = WINDOW_SIZE,
        ActiveTab      = "Main",
        TargetTab      = "Main",
        TabAlpha       = 1,
        Dragging       = false,
        DragOffset     = Vector2.zero,
        ActiveSlider   = nil,
        Tabs           = { Main={}, Misc={} },
        Destroyed      = false,
    }

    local api = { Controls={}, Destroyed=false, OnTabChanged=nil }

    local function register(tab, el)
        assert(win.Tabs[tab], "Unknown tab: "..tostring(tab))
        table.insert(win.Tabs[tab], el)
    end

    -- ── Section label ────────────────────────────────────────────────────────

    local function addSection(tab, title, sub, y)
        local el = { Tab=tab, Y=y }
        el.Title = makeText(title, 13, theme.Text,  Vector2.zero)
        el.Sub   = makeText(sub,    9, theme.Muted, Vector2.zero)

        -- Accent pip to the left of title
        el.Pip   = makeRoundedRect(Vector2.zero, Vector2.new(3, 14), 2, theme.Accent)

        function el:UpdateLayout()
            local p = win.Position
            self.Pip:SetPosition(p + Vector2.new(CONTENT_X, self.Y + 1))
            self.Title.Position = p + Vector2.new(CONTENT_X + 9, self.Y)
            self.Sub.Position   = p + Vector2.new(CONTENT_X + 9, self.Y + 17)
        end

        function el:SetVisible(v)
            self.Title.Visible = v; self.Sub.Visible = v; self.Pip:SetVisible(v)
        end
        function el:SetTransparency(t)
            self.Title.Transparency = t; self.Sub.Transparency = t; self.Pip:SetTransparency(t)
        end
        function el:Remove()
            self.Title:Remove(); self.Sub:Remove(); self.Pip:Remove()
        end

        el:UpdateLayout()
        register(tab, el)
        return el
    end

    -- ── Toggle ───────────────────────────────────────────────────────────────

    local function addToggle(tab, key, label, desc, default, y)
        local el = {
            Tab=tab, Key=key, Name=label, Description=desc,
            State=not not default, TargetState=not not default,
            KnobProgress=default and 1 or 0,
            Y=y, Bounds=nil,
            Callback=userCbs[key],
        }

        el.Card = makeRoundedRect(Vector2.zero, Vector2.new(CONTENT_W, TOGGLE_H), 10, theme.Card)
        el.Label = makeText(label, 13, theme.Text,  Vector2.zero)
        el.Desc  = makeText(desc,  10, theme.Muted, Vector2.zero)
        el.Sw    = makeRoundedRect(Vector2.zero, Vector2.new(44, 25), 13,
                       el.State and theme.ToggleOn or theme.ToggleOff)
        el.Knob  = newDrawing("Circle", {
            Radius=9, NumSides=32, Filled=true,
            Color=theme.White, Transparency=1, Visible=true,
        })

        function el:SetCallback(cb)
            assert(cb==nil or type(cb)=="function")
            self.Callback = cb; return self
        end

        function el:SetState(state, silent)
            state = not not state
            local changed = self.State ~= state
            self.State=state; self.TargetState=state
            if changed and not silent and self.Callback then self.Callback(state) end
            return self
        end

        function el:GetState() return self.State end

        function el:UpdateLayout(dt)
            local p  = win.Position
            local x  = p.X + CONTENT_X
            local yp = p.Y + self.Y

            self.Card:SetPosition(Vector2.new(x, yp))
            self.Label.Position = Vector2.new(x + 14, yp + 10)
            self.Desc.Position  = Vector2.new(x + 14, yp + 30)

            local sx = x + CONTENT_W - 62
            local sy = yp + 18
            self.Sw:SetPosition(Vector2.new(sx, sy))

            local tgt = self.TargetState and 1 or 0
            self.KnobProgress = lerp(self.KnobProgress, tgt,
                math.clamp((dt or 1/60)*18, 0, 1))

            self.Sw:SetColor(theme.ToggleOff:Lerp(theme.ToggleOn, self.KnobProgress))
            self.Knob.Position = Vector2.new(sx + 12 + self.KnobProgress*20, sy + 12)

            self.Bounds = {
                Min = Vector2.new(x, yp),
                Max = Vector2.new(x + CONTENT_W, yp + TOGGLE_H),
            }
        end

        function el:SetVisible(v)
            self.Card:SetVisible(v); self.Sw:SetVisible(v)
            self.Label.Visible=v; self.Desc.Visible=v; self.Knob.Visible=v
        end
        function el:SetTransparency(t)
            self.Card:SetTransparency(t); self.Sw:SetTransparency(t)
            self.Label.Transparency=t; self.Desc.Transparency=t; self.Knob.Transparency=t
        end
        function el:Remove()
            self.Card:Remove(); self.Sw:Remove()
            self.Label:Remove(); self.Desc:Remove(); self.Knob:Remove()
        end

        el:UpdateLayout(1/60)
        register(tab, el)
        api.Controls[key] = el
        return el
    end

    -- ── Slider ───────────────────────────────────────────────────────────────

    local function addSlider(tab, key, label, minVal, maxVal, default, suffix, y)
        assert(maxVal > minVal)
        local el = {
            Tab=tab, Key=key, Name=label,
            Min=minVal, Max=maxVal,
            Value=math.clamp(default, minVal, maxVal),
            Suffix=suffix or "",
            Y=y, Bounds=nil,
            Callback=userCbs[key],
        }

        el.Card      = makeRoundedRect(Vector2.zero, Vector2.new(CONTENT_W, SLIDER_H), 10, theme.Card)
        el.Label     = makeText(label, 13, theme.Text, Vector2.zero)
        el.ValueText = makeText(tostring(el.Value).." "..el.Suffix, 11, theme.AccentLight, Vector2.zero)
        el.Track     = makeRoundedRect(Vector2.zero, Vector2.new(TRACK_W, 4), 2, theme.ToggleOff)
        el.Fill      = makeRoundedRect(Vector2.zero, Vector2.new(1, 4),       2, theme.Accent)
        el.Knob      = newDrawing("Circle", {
            Radius=6, NumSides=32, Filled=true,
            Color=theme.White, Visible=true, Transparency=1,
        })
        -- Knob glow ring
        el.KnobGlow  = newDrawing("Circle", {
            Radius=9, NumSides=32, Filled=true,
            Color=theme.AccentDim, Visible=true, Transparency=0.35,
        })

        function el:SetCallback(cb)
            assert(cb==nil or type(cb)=="function")
            self.Callback=cb; return self
        end

        function el:SetValue(val, silent)
            local nv = math.clamp(math.floor(val + 0.5), self.Min, self.Max)
            local changed = self.Value ~= nv
            self.Value = nv
            self.ValueText.Text = tostring(nv).." "..self.Suffix
            self:UpdateLayout()
            if changed and not silent and self.Callback then self.Callback(nv) end
            return self
        end

        function el:GetValue() return self.Value end

        function el:UpdateFromMouse(mx)
            local tx  = win.Position.X + CONTENT_X + 15
            local pct = math.clamp((mx - tx) / TRACK_W, 0, 1)
            self:SetValue(self.Min + (self.Max - self.Min) * pct)
        end

        function el:UpdateLayout()
            local p  = win.Position
            local x  = p.X + CONTENT_X
            local yp = p.Y + self.Y

            self.Card:SetPosition(Vector2.new(x, yp))
            self.Label.Position     = Vector2.new(x + 14, yp + 10)
            self.ValueText.Position = Vector2.new(x + CONTENT_W - 85, yp + 10)

            local tx  = x + 15
            local ty  = yp + SLIDER_H - 20
            local pct = (self.Value - self.Min) / (self.Max - self.Min)
            local fw  = math.max(1, pct * TRACK_W)
            local kx  = tx + pct * TRACK_W

            self.Track:SetPosition(Vector2.new(tx, ty))
            self.Fill:SetPosition(Vector2.new(tx, ty))
            self.Fill:SetSize(Vector2.new(fw, 4))
            self.KnobGlow.Position = Vector2.new(kx, ty + 2)
            self.Knob.Position     = Vector2.new(kx, ty + 2)

            self.Bounds = {
                Min = Vector2.new(tx - 10, ty - 14),
                Max = Vector2.new(tx + TRACK_W + 10, ty + 18),
            }
        end

        function el:SetVisible(v)
            self.Card:SetVisible(v); self.Track:SetVisible(v)
            self.Fill:SetVisible(v); self.KnobGlow.Visible=v
            self.Label.Visible=v; self.ValueText.Visible=v; self.Knob.Visible=v
        end
        function el:SetTransparency(t)
            self.Card:SetTransparency(t); self.Track:SetTransparency(t)
            self.Fill:SetTransparency(t)
            self.KnobGlow.Transparency = 0.35 * t
            self.Label.Transparency=t; self.ValueText.Transparency=t; self.Knob.Transparency=t
        end
        function el:Remove()
            self.Card:Remove(); self.Track:Remove(); self.Fill:Remove()
            self.KnobGlow:Remove(); self.Label:Remove(); self.ValueText:Remove(); self.Knob:Remove()
        end

        el:UpdateLayout()
        register(tab, el)
        api.Controls[key] = el
        return el
    end

    -- ── Window shell ─────────────────────────────────────────────────────────

    local bg          = makeRoundedRect(win.Position, WINDOW_SIZE, 16, theme.Background)
    local sidebarBg   = makeRoundedRect(Vector2.zero, Vector2.new(SIDEBAR_W, WINDOW_H - 16), 12, theme.Sidebar)
    local headerLine  = newDrawing("Square", {
        Color=theme.Border, Filled=true, Transparency=1,
        Visible=true, Size=Vector2.new(WINDOW_W - SIDEBAR_W - 26, 1),
    })

    -- Brand block
    local brandDot   = makeRoundedRect(Vector2.zero, Vector2.new(6, 6), 3, theme.Accent)
    local brandName  = makeText(options.Title         or "disconnect.wtf",  16, theme.Text,  Vector2.zero)
    local brandSub   = makeText(options.BrandSubtitle or "PREMIUM",          8, theme.Muted, Vector2.zero)

    -- Content header (changes with tab)
    local hdrTitle   = makeText("Main", 20, theme.Text,  Vector2.zero)
    local hdrSub     = makeText(options.Subtitle or "Configure your experience", 10, theme.Muted, Vector2.zero)

    -- Vertical separator between sidebar and content
    local separator  = newDrawing("Square", {
        Color=theme.Border, Filled=true, Transparency=1,
        Visible=true, Size=Vector2.new(1, WINDOW_H - 30),
    })

    -- ── Sidebar tab buttons ───────────────────────────────────────────────────

    local tabDefs = {
        { Name="Main", Label="Main",   Icon="◈",  Offset=100 },
        { Name="Misc", Label="Misc",   Icon="⚙",  Offset=148 },
    }

    local tabBtns = {}
    for _, def in ipairs(tabDefs) do
        local b = { Name=def.Name, Offset=def.Offset, Bounds=nil }
        b.Bg        = makeRoundedRect(Vector2.zero, Vector2.new(136, 38), 9, theme.Sidebar)
        b.Indicator = makeRoundedRect(Vector2.zero, Vector2.new(3, 20), 2, theme.Accent)
        b.Icon      = makeText(def.Icon,  13, theme.Muted, Vector2.zero)
        b.LabelText = makeText(def.Label, 13, theme.Muted, Vector2.zero)
        table.insert(tabBtns, b)
    end

    -- ── Control declarations ─────────────────────────────────────────────────
    --
    -- Main tab  (section y=88, controls from y=126, step=TOGGLE_H+CTRL_GAP=66)
    --   126  RecoilControl
    --   192  InfiniteAmmo
    --   258  FullAuto
    --   324  SpreadLock
    --   390  MaxPenetration
    --
    -- Misc tab  (section y=88, controls from y=126)
    --   126  Streamproof
    --   192  UnlockFPS
    --   258  AutoRescan
    --   324  FOVCircle
    --   390  FieldOfView (slider, h=72 → ends 462 < 510 ✓)
    --
    local S = TOGGLE_H + CTRL_GAP  -- step between toggle tops = 66

    addSection("Main", "Combat",        "Weapon modification settings",    88)
    addToggle ("Main", "RecoilControl", "Recoil Control",  "Zero all weapon and camera recoil vectors",       true,  126)
    addToggle ("Main", "InfiniteAmmo",  "Infinite Ammo",   "Push ammo counts to math.huge",                   true,  126 + S)
    addToggle ("Main", "FullAuto",      "Force Full-Auto",  "Set ShootType 3 on every detected weapon",        true,  126 + S*2)
    addToggle ("Main", "SpreadLock",    "Spread Lock",      "Clamp min/max spread to 0.1, zero step amount",   true,  126 + S*3)
    addToggle ("Main", "MaxPenetration","Max Penetration",  "Set bullet penetration to 999",                   false, 126 + S*4)

    addSection("Misc", "Utility",        "Interface and session options",   88)
    addToggle ("Misc", "Streamproof",   "Streamproof",      "Hide the overlay from screen capture APIs",       true,  126)
    addToggle ("Misc", "UnlockFPS",     "Unlock FPS",       "Remove the configured frame rate cap",            false, 126 + S)
    addToggle ("Misc", "AutoRescan",    "Auto Rescan",      "Re-apply weapon mods every 5 seconds",            false, 126 + S*2)
    addToggle ("Misc", "FOVCircle",     "FOV Circle",       "Draw an aimbot range indicator on screen",        false, 126 + S*3)
    addSlider ("Misc", "FOVRadius",     "FOV Radius",       30, 500, 120, "px",                                        126 + S*4)

    -- ── Layout ───────────────────────────────────────────────────────────────

    local function updateLayout(dt)
        local p = win.Position

        bg:SetPosition(p)
        sidebarBg:SetPosition(p + Vector2.new(8, 8))
        separator.Position = p + Vector2.new(SIDEBAR_W + 8, 15)

        -- Brand
        brandDot:SetPosition(p  + Vector2.new(18, 29))
        brandName.Position  = p + Vector2.new(30, 23)
        brandSub.Position   = p + Vector2.new(30, 43)

        -- Content header
        hdrTitle.Position = p + Vector2.new(CONTENT_X, 22)
        hdrSub.Position   = p + Vector2.new(CONTENT_X, 45)
        headerLine.Position = p + Vector2.new(CONTENT_X, 66)

        -- Sidebar buttons
        for _, b in ipairs(tabBtns) do
            local bx = p.X + 13
            local by = p.Y + b.Offset
            local active = b.Name == win.TargetTab

            b.Bg:SetPosition(Vector2.new(bx, by))
            b.Bg:SetColor(active and theme.CardHover or theme.Sidebar)

            b.Icon.Position      = Vector2.new(bx + 12, by + 12)
            b.LabelText.Position = Vector2.new(bx + 33, by + 12)
            b.Icon.Color      = active and theme.AccentLight or theme.Muted
            b.LabelText.Color = active and theme.Text        or theme.Muted

            b.Indicator:SetPosition(Vector2.new(bx + 129, by + 9))
            b.Indicator:SetVisible(active)

            b.Bounds = {
                Min = Vector2.new(bx, by),
                Max = Vector2.new(bx + 136, by + 38),
            }
        end

        -- All controls
        for _, els in pairs(win.Tabs) do
            for _, el in ipairs(els) do
                el:UpdateLayout(dt)
            end
        end
    end

    local function updateVisibility()
        for tabName, els in pairs(win.Tabs) do
            local active = tabName == win.ActiveTab
            for _, el in ipairs(els) do
                el:SetVisible(active)
                el:SetTransparency(win.TabAlpha)
            end
        end
    end

    local function switchTab(name)
        if not win.Tabs[name] or win.TargetTab == name then return end
        win.TargetTab = name
    end

    -- ── Connections ───────────────────────────────────────────────────────────

    local conInput, conInputEnd, conRender

    conInput = UIS.InputBegan:Connect(function(inp)
        if win.Destroyed then return end
        if inp.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

        local m = UIS:GetMouseLocation()

        for _, b in ipairs(tabBtns) do
            if isInside(m, b.Bounds) then switchTab(b.Name); return end
        end

        for _, el in ipairs(win.Tabs[win.ActiveTab]) do
            if el.Bounds and isInside(m, el.Bounds) then
                if el.State ~= nil then
                    el:SetState(not el.TargetState)
                elseif el.Value ~= nil then
                    win.ActiveSlider = el
                    el:UpdateFromMouse(m.X)
                end
                return
            end
        end

        -- Drag zone: top bar
        if m.X >= win.Position.X and m.X <= win.Position.X + WINDOW_W
            and m.Y >= win.Position.Y and m.Y <= win.Position.Y + 72 then
            win.Dragging   = true
            win.DragOffset = m - win.Position
        end
    end)

    conInputEnd = UIS.InputEnded:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            win.Dragging = false; win.ActiveSlider = nil
        end
    end)

    conRender = RunService.RenderStepped:Connect(function(dt)
        if win.Destroyed then return end

        if win.Dragging then
            win.TargetPosition = UIS:GetMouseLocation() - win.DragOffset
        end

        win.Position = win.Position:Lerp(win.TargetPosition, math.clamp(dt * 18, 0, 1))

        if win.ActiveSlider then
            win.ActiveSlider:UpdateFromMouse(UIS:GetMouseLocation().X)
        end

        if win.ActiveTab ~= win.TargetTab then
            win.TabAlpha = math.max(0, win.TabAlpha - dt * 9)
            if win.TabAlpha <= 0.02 then
                win.ActiveTab  = win.TargetTab
                hdrTitle.Text  = win.ActiveTab
                if api.OnTabChanged then api.OnTabChanged(win.ActiveTab) end
                win.TabAlpha = 0
            end
        else
            win.TabAlpha = math.min(1, win.TabAlpha + dt * 9)
        end

        updateLayout(dt)
        updateVisibility()
    end)

    -- ── Public API ────────────────────────────────────────────────────────────

    function api:SetTab(name) switchTab(name); return self end
    function api:GetTab()     return win.ActiveTab           end

    function api:SetTabChangedCallback(cb)
        assert(cb==nil or type(cb)=="function"); self.OnTabChanged=cb; return self
    end

    function api:SetToggle(key, val, silent)
        local c = self.Controls[key]
        assert(c and c.SetState, "Unknown toggle: "..tostring(key))
        c:SetState(val, silent); return self
    end

    function api:SetSlider(key, val, silent)
        local c = self.Controls[key]
        assert(c and c.SetValue, "Unknown slider: "..tostring(key))
        c:SetValue(val, silent); return self
    end

    function api:Unload()
        if win.Destroyed then return end
        win.Destroyed = true; self.Destroyed = true
        win.Dragging = false; win.ActiveSlider = nil

        if conRender   then conRender:Disconnect()   end
        if conInput    then conInput:Disconnect()    end
        if conInputEnd then conInputEnd:Disconnect() end

        bg:Remove(); sidebarBg:Remove()
        separator:Remove(); headerLine:Remove()
        brandDot:Remove(); brandName:Remove(); brandSub:Remove()
        hdrTitle:Remove(); hdrSub:Remove()

        for _, b in ipairs(tabBtns) do
            b.Bg:Remove(); b.Indicator:Remove(); b.Icon:Remove(); b.LabelText:Remove()
        end

        for _, els in pairs(win.Tabs) do
            for _, el in ipairs(els) do el:Remove() end
        end
    end

    updateLayout(1/60)
    updateVisibility()
    print("[disconnect.wtf] UI initialized.")
    return api
end

return UI
