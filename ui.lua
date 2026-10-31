--==============================================================================
-- disconnect.wtf — ui.lua (Apple / Modern Dark theme with Drawing.new)
--==============================================================================--

local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local Camera           = workspace.CurrentCamera

local UI = {}

function UI.new(config)
    config = config or {}
    local Title         = config.Title         or "disconnect.wtf"
    local BrandSubtitle = config.BrandSubtitle or "PREMIUM"
    local Subtitle      = config.Subtitle      or "Configure your experience"

    -- Apple × disconnect.wtf Dark Palette
    local Theme = {
        Background    = Color3.fromRGB(18, 19, 23),
        Sidebar       = Color3.fromRGB(24, 25, 30),
        SidebarActive = Color3.fromRGB(60, 130, 240),
        CardBg        = Color3.fromRGB(28, 30, 36),
        TextPrimary   = Color3.fromRGB(240, 245, 250),
        TextMuted     = Color3.fromRGB(130, 135, 150),
        Accent        = Color3.fromRGB(60, 140, 240),
        ToggleOff     = Color3.fromRGB(42, 45, 54),
        ToggleOn      = Color3.fromRGB(60, 140, 240),
        Border        = Color3.fromRGB(38, 40, 48),
        Line          = Color3.fromRGB(32, 34, 42)
    }

    local Window = {
        Position       = Vector2.new(250, 150),
        TargetPosition = Vector2.new(250, 150),
        Size           = Vector2.new(620, 410),
        SidebarWidth   = 160,
        ActiveTab      = "Weapons",
        Drawings       = {},
        Controls       = {},
        IsDragging     = false,
        DragOffset     = Vector2.new(0, 0)
    }

    local function create(drawType, props)
        local obj = Drawing.new(drawType)
        for k, v in pairs(props) do
            obj[k] = v
        end
        table.insert(Window.Drawings, obj)
        return obj
    end

    ----------------------------------------------------------------------------
    -- Window Structure & Containers
    ----------------------------------------------------------------------------
    local MainBg = create("Square", {
        Size = Window.Size,
        Position = Window.Position,
        Color = Theme.Background,
        Filled = true,
        Visible = true
    })

    local MainBorder = create("Square", {
        Size = Window.Size,
        Position = Window.Position,
        Color = Theme.Border,
        Filled = false,
        Thickness = 1,
        Visible = true
    })

    local SidebarBg = create("Square", {
        Size = Vector2.new(Window.SidebarWidth, Window.Size.Y),
        Position = Window.Position,
        Color = Theme.Sidebar,
        Filled = true,
        Visible = true
    })

    local SidebarDivider = create("Line", {
        From = Window.Position + Vector2.new(Window.SidebarWidth, 0),
        To = Window.Position + Vector2.new(Window.SidebarWidth, Window.Size.Y),
        Color = Theme.Border,
        Thickness = 1,
        Visible = true
    })

    -- Branding Titles
    local BrandTitleText = create("Text", {
        Text = Title,
        Size = 16,
        Position = Window.Position + Vector2.new(20, 20),
        Color = Theme.TextPrimary,
        Visible = true
    })

    local BrandSubText = create("Text", {
        Text = BrandSubtitle,
        Size = 10,
        Position = Window.Position + Vector2.new(20, 40),
        Color = Theme.Accent,
        Visible = true
    })

    -- Header Titles
    local HeaderTitle = create("Text", {
        Text = "Weapons",
        Size = 18,
        Position = Window.Position + Vector2.new(Window.SidebarWidth + 25, 20),
        Color = Theme.TextPrimary,
        Visible = true
    })

    local HeaderSubtitleText = create("Text", {
        Text = Subtitle,
        Size = 12,
        Position = Window.Position + Vector2.new(Window.SidebarWidth + 25, 42),
        Color = Theme.TextMuted,
        Visible = true
    })

    ----------------------------------------------------------------------------
    -- Tab System
    ----------------------------------------------------------------------------
    local Tabs = {
        { Name = "Weapons", Label = "Weapons", YOffset = 80 },
        { Name = "Misc",    Label = "Misc",    YOffset = 125 }
    }

    local TabButtons = {}
    for _, tab in ipairs(Tabs) do
        local btnPos = Window.Position + Vector2.new(15, tab.YOffset)
        local indicator = create("Square", {
            Size = Vector2.new(3, 24),
            Position = btnPos + Vector2.new(0, 3),
            Color = Theme.SidebarActive,
            Filled = true,
            Visible = (tab.Name == Window.ActiveTab)
        })
        local label = create("Text", {
            Text = tab.Label,
            Size = 14,
            Position = btnPos + Vector2.new(15, 3),
            Color = (tab.Name == Window.ActiveTab) and Theme.TextPrimary or Theme.TextMuted,
            Visible = true
        })
        table.insert(TabButtons, {
            Name = tab.Name,
            Indicator = indicator,
            Label = label,
            Bounds = { Min = btnPos, Max = btnPos + Vector2.new(Window.SidebarWidth - 30, 30) }
        })
    end

    local TabContent = {
        Weapons = {},
        Misc    = {}
    }

    ----------------------------------------------------------------------------
    -- Toggle Builder
    ----------------------------------------------------------------------------
    local function addToggle(tabName, controlName, labelText, defaultState, yPos)
        local contentX = Window.Position.X + Window.SidebarWidth + 25
        local contentY = Window.Position.Y + yPos

        local label = create("Text", {
            Text = labelText,
            Size = 14,
            Position = Vector2.new(contentX, contentY + 2),
            Color = Theme.TextPrimary,
            Visible = (Window.ActiveTab == tabName)
        })

        local line = create("Line", {
            From = Vector2.new(contentX, contentY + 32),
            To = Vector2.new(Window.Position.X + Window.Size.X - 25, contentY + 32),
            Color = Theme.Line,
            Thickness = 1,
            Visible = (Window.ActiveTab == tabName)
        })

        local toggleBox = create("Square", {
            Size = Vector2.new(36, 20),
            Position = Vector2.new(Window.Position.X + Window.Size.X - 65, contentY + 2),
            Color = defaultState and Theme.ToggleOn or Theme.ToggleOff,
            Filled = true,
            Visible = (Window.ActiveTab == tabName)
        })

        local toggleKnob = create("Square", {
            Size = Vector2.new(16, 16),
            Position = Vector2.new(defaultState and (Window.Position.X + Window.Size.X - 43) or (Window.Position.X + Window.Size.X - 63), contentY + 4),
            Color = Theme.TextPrimary,
            Filled = true,
            Visible = (Window.ActiveTab == tabName)
        })

        local controlObj = {
            State = defaultState,
            Callback = nil,
            GetState = function(self) return self.State end,
            SetCallback = function(self, fn) self.Callback = fn end
        }

        local itemData = {
            Type = "Toggle",
            Control = controlObj,
            Tab = tabName,
            Drawings = { label, line, toggleBox, toggleKnob },
            Bounds = {
                Min = Vector2.new(Window.Position.X + Window.Size.X - 65, contentY),
                Max = Vector2.new(Window.Position.X + Window.Size.X - 25, contentY + 24)
            },
            UpdatePos = function(basePos)
                local cx = basePos.X + Window.SidebarWidth + 25
                local cy = basePos.Y + yPos
                label.Position = Vector2.new(cx, cy + 2)
                line.From = Vector2.new(cx, cy + 32)
                line.To = Vector2.new(basePos.X + Window.Size.X - 25, cy + 32)
                toggleBox.Position = Vector2.new(basePos.X + Window.Size.X - 65, cy + 2)
                toggleKnob.Position = Vector2.new(controlObj.State and (basePos.X + Window.Size.X - 43) or (basePos.X + Window.Size.X - 63), cy + 4)
                itemData.Bounds = {
                    Min = Vector2.new(basePos.X + Window.Size.X - 65, cy),
                    Max = Vector2.new(basePos.X + Window.Size.X - 25, cy + 24)
                }
            end,
            Toggle = function(self)
                controlObj.State = not controlObj.State
                toggleBox.Color = controlObj.State and Theme.ToggleOn or Theme.ToggleOff
                toggleKnob.Position = Vector2.new(
                    controlObj.State and (Window.Position.X + Window.Size.X - 43) or (Window.Position.X + Window.Size.X - 63),
                    contentY + 4
                )
                if controlObj.Callback then
                    pcall(controlObj.Callback, controlObj.State)
                end
            end
        }

        Window.Controls[controlName] = controlObj
        table.insert(TabContent[tabName], itemData)
    end

    ----------------------------------------------------------------------------
    -- Register Controls (Matching main.lua expectations)
    ----------------------------------------------------------------------------
    -- Weapons Tab
    addToggle("Weapons", "RecoilControl",  "Recoil Control System", false, 75)
    addToggle("Weapons", "InfiniteAmmo",   "Infinite Ammo",         false, 125)
    addToggle("Weapons", "FullAuto",       "Force Full-Auto",       false, 175)
    addToggle("Weapons", "SpreadLock",     "Spread Lock",           false, 225)
    addToggle("Weapons", "MaxPenetration", "Max Penetration",       false, 275)
    addToggle("Weapons", "MagicBullet",    "Magic Bullet",          false, 325)

    -- Misc Tab
    addToggle("Misc",    "AutoRescan",     "Automatic Weapon Rescan", true,  75)

    ----------------------------------------------------------------------------
    -- Tab Switching Logic
    ----------------------------------------------------------------------------
    local function switchTab(newTab)
        Window.ActiveTab = newTab
        HeaderTitle.Text = newTab

        for _, btn in ipairs(TabButtons) do
            local isActive = (btn.Name == newTab)
            btn.Indicator.Visible = isActive
            btn.Label.Color = isActive and Theme.TextPrimary or Theme.TextMuted
        end

        for tName, items in pairs(TabContent) do
            local isCurrent = (tName == newTab)
            for _, item in ipairs(items) do
                for _, d in ipairs(item.Drawings) do
                    d.Visible = isCurrent
                end
            end
        end
    end

    ----------------------------------------------------------------------------
    -- Smooth Dragging & Render Loop
    ----------------------------------------------------------------------------
    local renderConn = RunService.RenderStepped:Connect(function()
        if Window.IsDragging then
            local mousePos = UserInputService:GetMouseLocation()
            Window.TargetPosition = mousePos - Window.DragOffset
        end

        -- Smooth position lerping for Apple-like fluidity
        Window.Position = Window.Position:Lerp(Window.TargetPosition, 0.25)

        -- Update layout elements
        MainBg.Position = Window.Position
        MainBorder.Position = Window.Position
        SidebarBg.Position = Window.Position
        SidebarDivider.From = Window.Position + Vector2.new(Window.SidebarWidth, 0)
        SidebarDivider.To = Window.Position + Vector2.new(Window.SidebarWidth, Window.Size.Y)
        BrandTitleText.Position = Window.Position + Vector2.new(20, 20)
        BrandSubText.Position = Window.Position + Vector2.new(20, 40)
        HeaderTitle.Position = Window.Position + Vector2.new(Window.SidebarWidth + 25, 20)
        HeaderSubtitleText.Position = Window.Position + Vector2.new(Window.SidebarWidth + 25, 42)

        for _, btn in ipairs(TabButtons) do
            local yOff = (btn.Name == "Weapons") and 80 or 125
            local btnPos = Window.Position + Vector2.new(15, yOff)
            btn.Indicator.Position = btnPos + Vector2.new(0, 3)
            btn.Label.Position = btnPos + Vector2.new(15, 3)
            btn.Bounds = { Min = btnPos, Max = btnPos + Vector2.new(Window.SidebarWidth - 30, 30) }
        end

        for tName, items in pairs(TabContent) do
            for _, item in ipairs(items) do
                item.UpdatePos(Window.Position)
            end
        end
    end)

    ----------------------------------------------------------------------------
    -- Input Handlers
    ----------------------------------------------------------------------------
    local inputConn = UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local mousePos = UserInputService:GetMouseLocation()

            -- Title bar drag check
            if mousePos.X >= Window.Position.X and mousePos.X <= Window.Position.X + Window.Size.X and
               mousePos.Y >= Window.Position.Y and mousePos.Y <= Window.Position.Y + 60 then
                Window.IsDragging = true
                Window.DragOffset = mousePos - Window.Position
            end

            -- Tab button click check
            for _, btn in ipairs(TabButtons) do
                if mousePos.X >= btn.Bounds.Min.X and mousePos.X <= btn.Bounds.Max.X and
                   mousePos.Y >= btn.Bounds.Min.Y and mousePos.Y <= btn.Bounds.Max.Y then
                    switchTab(btn.Name)
                    return
                end
            end

            -- Active tab controls click check
            for _, item in ipairs(TabContent[Window.ActiveTab]) do
                if item.Type == "Toggle" then
                    if mousePos.X >= item.Bounds.Min.X and mousePos.X <= item.Bounds.Max.X and
                       mousePos.Y >= item.Bounds.Min.Y and mousePos.Y <= item.Bounds.Max.Y then
                        item:Toggle()
                    end
                end
            end
        end
    end)

    local inputEndConn = UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            Window.IsDragging = false
        end
    end)

    ----------------------------------------------------------------------------
    -- Cleanup / Unload Method
    ----------------------------------------------------------------------------
    function Window:Unload()
        pcall(function() renderConn:Disconnect() end)
        pcall(function() inputConn:Disconnect() end)
        pcall(function() inputEndConn:Disconnect() end)
        for _, d in ipairs(Window.Drawings) do
            pcall(function() d:Remove() end)
        end
        Window.Drawings = {}
    end

    return Window
end

return UI
