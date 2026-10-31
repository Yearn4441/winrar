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
    AccentDim   = Color3.fromRGB(70,  35,  145),

    Text        = Color3.fromRGB(240, 240, 248),
    Muted       = Color3.fromRGB(118, 115, 138),
    Border      = Color3.fromRGB(36,  34,  50),

    ToggleOff   = Color3.fromRGB(48,  46,  60),
    ToggleOn    = Color3.fromRGB(138, 75,  255),
    White       = Color3.fromRGB(255, 255, 255),
}

-- Dimensions
-- Main has 6 toggles → needs more height.
-- step = TOGGLE_H + GAP = 60 + 5 = 65
-- last toggle top = 126 + 5*65 = 451, bottom = 511  →  WINDOW_H 540 is fine.
local WINDOW_W   = 660
local WINDOW_H   = 540
local WINDOW_SIZE = Vector2.new(WINDOW_W, WINDOW_H)
local SIDEBAR_W  = 158
local CONTENT_X  = 183
local CONTENT_W  = WINDOW_W - CONTENT_X - 18   -- 459 px
local TOGGLE_H   = 60
local TOGGLE_GAP = 5
local TOGGLE_STEP = TOGGLE_H + TOGGLE_GAP       -- 65

local function copyTable(t)
    local r = {}; for k,v in pairs(t) do r[k]=v end; return r
end

local function newDrawing(cls, props)
    local o = Drawing.new(cls)
    for k,v in pairs(props or {}) do o[k]=v end
    return o
end

local function makeRoundedRect(pos, sz, radius, color)
    local objs = {}
    local s = {
        Objects=objs, Position=pos, Size=sz,
        Radius=math.min(radius, sz.X/2, sz.Y/2), Removed=false,
    }
    local H = newDrawing("Square",{Color=color,Filled=true,Transparency=1,Visible=true})
    local V = newDrawing("Square",{Color=color,Filled=true,Transparency=1,Visible=true})
    table.insert(objs,H); table.insert(objs,V)
    local C = {}
    for i=1,4 do
        C[i] = newDrawing("Circle",{Radius=s.Radius,NumSides=32,Filled=true,Color=color,Transparency=1,Visible=true})
        table.insert(objs,C[i])
    end
    function s:SetPosition(p)
        if self.Removed then return end
        self.Position=p
        local w,r=self.Size,self.Radius
        H.Position=p+Vector2.new(r,0);  H.Size=Vector2.new(math.max(0,w.X-r*2),w.Y)
        V.Position=p+Vector2.new(0,r);  V.Size=Vector2.new(w.X,math.max(0,w.Y-r*2))
        C[1].Position=p+Vector2.new(r,    r)
        C[2].Position=p+Vector2.new(w.X-r,r)
        C[3].Position=p+Vector2.new(r,    w.Y-r)
        C[4].Position=p+Vector2.new(w.X-r,w.Y-r)
    end
    function s:SetSize(ns)
        if self.Removed then return end
        self.Size=ns; self.Radius=math.min(self.Radius,ns.X/2,ns.Y/2)
        for _,c in ipairs(C) do c.Radius=self.Radius end
        self:SetPosition(self.Position)
    end
    function s:SetColor(c)   if self.Removed then return end; for _,o in ipairs(objs) do o.Color=c end end
    function s:SetTransparency(t) if self.Removed then return end; for _,o in ipairs(objs) do o.Transparency=t end end
    function s:SetVisible(v) if self.Removed then return end; for _,o in ipairs(objs) do o.Visible=v end end
    function s:Remove()
        if self.Removed then return end; self.Removed=true
        for _,o in ipairs(objs) do o:Remove() end
    end
    s:SetPosition(pos); return s
end

local function makeText(val,size,color,pos,font)
    return newDrawing("Text",{
        Text=tostring(val),Size=size,Font=font or 0,Color=color,
        Position=pos,Transparency=1,Visible=true,Center=false,Outline=false,
    })
end

local function isInside(pt,b)
    return b
        and pt.X>=b.Min.X and pt.X<=b.Max.X
        and pt.Y>=b.Min.Y and pt.Y<=b.Max.Y
end

local function lerp(a,b,t) return a+(b-a)*t end

--==============================================================================
-- CONSTRUCTOR
--==============================================================================--

function UI.new(options)
    options = options or {}
    local theme = copyTable(DEFAULT_THEME)
    for k,v in pairs(options.Theme or {}) do theme[k]=v end
    local userCbs = options.Callbacks or {}

    local win = {
        Position=options.Position or Vector2.new(200,130),
        TargetPosition=options.Position or Vector2.new(200,130),
        Size=WINDOW_SIZE,
        ActiveTab="Main", TargetTab="Main", TabAlpha=1,
        Dragging=false, DragOffset=Vector2.zero, ActiveSlider=nil,
        Tabs={Main={},Misc={}}, Destroyed=false,
    }

    local api = {Controls={},Destroyed=false,OnTabChanged=nil}

    local function register(tab,el)
        assert(win.Tabs[tab],"Unknown tab: "..tostring(tab))
        table.insert(win.Tabs[tab],el)
    end

    -- ── Section ──────────────────────────────────────────────────────────────

    local function addSection(tab,title,sub,y)
        local el={Tab=tab,Y=y}
        el.Pip   = makeRoundedRect(Vector2.zero,Vector2.new(3,14),2,theme.Accent)
        el.Title = makeText(title,13,theme.Text, Vector2.zero)
        el.Sub   = makeText(sub,   9,theme.Muted,Vector2.zero)
        function el:UpdateLayout()
            local p=win.Position
            self.Pip:SetPosition(p+Vector2.new(CONTENT_X,self.Y+1))
            self.Title.Position=p+Vector2.new(CONTENT_X+9,self.Y)
            self.Sub.Position  =p+Vector2.new(CONTENT_X+9,self.Y+17)
        end
        function el:SetVisible(v)      self.Pip:SetVisible(v); self.Title.Visible=v; self.Sub.Visible=v end
        function el:SetTransparency(t) self.Pip:SetTransparency(t); self.Title.Transparency=t; self.Sub.Transparency=t end
        function el:Remove()           self.Pip:Remove(); self.Title:Remove(); self.Sub:Remove() end
        el:UpdateLayout(); register(tab,el); return el
    end

    -- ── Toggle ───────────────────────────────────────────────────────────────

    local function addToggle(tab,key,label,desc,default,y)
        local el={
            Tab=tab,Key=key,Name=label,Description=desc,
            State=not not default, TargetState=not not default,
            KnobProgress=default and 1 or 0,
            Y=y, Bounds=nil, Callback=userCbs[key],
        }
        el.Card = makeRoundedRect(Vector2.zero,Vector2.new(CONTENT_W,TOGGLE_H),10,theme.Card)
        el.Label= makeText(label,13,theme.Text, Vector2.zero)
        el.Desc = makeText(desc, 10,theme.Muted,Vector2.zero)
        el.Sw   = makeRoundedRect(Vector2.zero,Vector2.new(44,25),13,
                      el.State and theme.ToggleOn or theme.ToggleOff)
        el.Knob = newDrawing("Circle",{Radius=9,NumSides=32,Filled=true,Color=theme.White,Transparency=1,Visible=true})

        function el:SetCallback(cb) assert(cb==nil or type(cb)=="function"); self.Callback=cb; return self end
        function el:SetState(state,silent)
            state=not not state
            local changed=self.State~=state
            self.State=state; self.TargetState=state
            if changed and not silent and self.Callback then self.Callback(state) end
            return self
        end
        function el:GetState() return self.State end
        function el:UpdateLayout(dt)
            local p=win.Position; local x=p.X+CONTENT_X; local yp=p.Y+self.Y
            self.Card:SetPosition(Vector2.new(x,yp))
            self.Label.Position=Vector2.new(x+14,yp+10)
            self.Desc.Position =Vector2.new(x+14,yp+30)
            local sx=x+CONTENT_W-62; local sy=yp+17
            self.Sw:SetPosition(Vector2.new(sx,sy))
            local tgt=self.TargetState and 1 or 0
            self.KnobProgress=lerp(self.KnobProgress,tgt,math.clamp((dt or 1/60)*18,0,1))
            self.Sw:SetColor(theme.ToggleOff:Lerp(theme.ToggleOn,self.KnobProgress))
            self.Knob.Position=Vector2.new(sx+12+self.KnobProgress*20,sy+12)
            self.Bounds={Min=Vector2.new(x,yp),Max=Vector2.new(x+CONTENT_W,yp+TOGGLE_H)}
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
        el:UpdateLayout(1/60); register(tab,el); api.Controls[key]=el; return el
    end

    -- ── Window shell ─────────────────────────────────────────────────────────

    local bg         = makeRoundedRect(win.Position,WINDOW_SIZE,16,theme.Background)
    local sidebarBg  = makeRoundedRect(Vector2.zero,Vector2.new(SIDEBAR_W,WINDOW_H-16),12,theme.Sidebar)
    local hdrLine    = newDrawing("Square",{Color=theme.Border,Filled=true,Transparency=1,Visible=true,Size=Vector2.new(WINDOW_W-SIDEBAR_W-26,1)})
    local sep        = newDrawing("Square",{Color=theme.Border,Filled=true,Transparency=1,Visible=true,Size=Vector2.new(1,WINDOW_H-30)})

    local brandPip   = makeRoundedRect(Vector2.zero,Vector2.new(6,6),3,theme.Accent)
    local brandName  = makeText(options.Title or "disconnect.wtf",16,theme.Text, Vector2.zero)
    local brandSub   = makeText(options.BrandSubtitle or "PREMIUM",8,theme.Muted,Vector2.zero)
    local hdrTitle   = makeText("Main",20,theme.Text, Vector2.zero)
    local hdrSub     = makeText(options.Subtitle or "Configure your experience",10,theme.Muted,Vector2.zero)

    -- ── Sidebar buttons ───────────────────────────────────────────────────────

    local tabDefs = {
        {Name="Main",Label="Main",Icon="◈",Offset=100},
        {Name="Misc",Label="Misc",Icon="⚙",Offset=148},
    }
    local tabBtns = {}
    for _,def in ipairs(tabDefs) do
        local b={Name=def.Name,Offset=def.Offset,Bounds=nil}
        b.Bg        = makeRoundedRect(Vector2.zero,Vector2.new(136,38),9,theme.Sidebar)
        b.Ind       = makeRoundedRect(Vector2.zero,Vector2.new(3,20),2,theme.Accent)
        b.Icon      = makeText(def.Icon, 13,theme.Muted,Vector2.zero)
        b.LabelText = makeText(def.Label,13,theme.Muted,Vector2.zero)
        table.insert(tabBtns,b)
    end

    -- ── Controls ─────────────────────────────────────────────────────────────
    --
    -- MAIN  (section y=88, first toggle y=126, step=65)
    --   y=126  RecoilControl   ends 186
    --   y=191  InfiniteAmmo    ends 251
    --   y=256  FullAuto        ends 316
    --   y=321  SpreadLock      ends 381
    --   y=386  MaxPenetration  ends 446
    --   y=451  MagicBullet     ends 511  < 540 ✓
    --
    -- MISC  (section y=88, one toggle y=126)
    --   y=126  AutoRescan      ends 186
    --
    local S = TOGGLE_STEP

    addSection("Main","Combat","Weapon and targeting modifications",88)
    addToggle ("Main","RecoilControl", "Recoil Control",    "Zero all weapon and camera recoil vectors",          true,  126)
    addToggle ("Main","InfiniteAmmo",  "Infinite Ammo",     "Set ammo counts to math.huge on all gun tables",     true,  126+S)
    addToggle ("Main","FullAuto",      "Force Full-Auto",   "Override ShootType to 3 on every weapon",            true,  126+S*2)
    addToggle ("Main","SpreadLock",    "Spread Lock",       "Clamp spread to 0.1 and zero inaccuracy step",       true,  126+S*3)
    addToggle ("Main","MaxPenetration","Max Penetration",   "Force bullet penetration to 999",                    false, 126+S*4)
    addToggle ("Main","MagicBullet",   "Magic Bullet",      "Redirect all raycasts to nearest target and teleport them into the ray", false, 126+S*5)

    addSection("Misc","Session","Background automation",88)
    addToggle ("Misc","AutoRescan",    "Auto Rescan",       "Re-apply all active weapon mods every 5 seconds",    false, 126)

    -- ── Layout / visibility ───────────────────────────────────────────────────

    local function updateLayout(dt)
        local p=win.Position
        bg:SetPosition(p); sidebarBg:SetPosition(p+Vector2.new(8,8))
        sep.Position=p+Vector2.new(SIDEBAR_W+8,15)
        hdrLine.Position=p+Vector2.new(CONTENT_X,66)
        brandPip:SetPosition(p+Vector2.new(18,29))
        brandName.Position=p+Vector2.new(30,23); brandSub.Position=p+Vector2.new(30,43)
        hdrTitle.Position=p+Vector2.new(CONTENT_X,22); hdrSub.Position=p+Vector2.new(CONTENT_X,45)

        for _,b in ipairs(tabBtns) do
            local bx=p.X+13; local by=p.Y+b.Offset
            local active=b.Name==win.TargetTab
            b.Bg:SetPosition(Vector2.new(bx,by)); b.Bg:SetColor(active and theme.CardHover or theme.Sidebar)
            b.Icon.Position=Vector2.new(bx+12,by+12); b.LabelText.Position=Vector2.new(bx+33,by+12)
            b.Icon.Color=active and theme.AccentLight or theme.Muted
            b.LabelText.Color=active and theme.Text or theme.Muted
            b.Ind:SetPosition(Vector2.new(bx+129,by+9)); b.Ind:SetVisible(active)
            b.Bounds={Min=Vector2.new(bx,by),Max=Vector2.new(bx+136,by+38)}
        end

        for _,els in pairs(win.Tabs) do
            for _,el in ipairs(els) do el:UpdateLayout(dt) end
        end
    end

    local function updateVisibility()
        for tabName,els in pairs(win.Tabs) do
            local active=tabName==win.ActiveTab
            for _,el in ipairs(els) do
                el:SetVisible(active); el:SetTransparency(win.TabAlpha)
            end
        end
    end

    local function switchTab(name)
        if not win.Tabs[name] or win.TargetTab==name then return end
        win.TargetTab=name
    end

    -- ── Connections ───────────────────────────────────────────────────────────

    local conI,conIE,conR

    conI = UIS.InputBegan:Connect(function(inp)
        if win.Destroyed then return end
        if inp.UserInputType~=Enum.UserInputType.MouseButton1 then return end
        local m=UIS:GetMouseLocation()
        for _,b in ipairs(tabBtns) do
            if isInside(m,b.Bounds) then switchTab(b.Name); return end
        end
        for _,el in ipairs(win.Tabs[win.ActiveTab]) do
            if el.Bounds and isInside(m,el.Bounds) then
                if el.State~=nil then
                    el:SetState(not el.TargetState)
                elseif el.Value~=nil then
                    win.ActiveSlider=el; el:UpdateFromMouse(m.X)
                end
                return
            end
        end
        if m.X>=win.Position.X and m.X<=win.Position.X+WINDOW_W
            and m.Y>=win.Position.Y and m.Y<=win.Position.Y+72 then
            win.Dragging=true; win.DragOffset=m-win.Position
        end
    end)

    conIE = UIS.InputEnded:Connect(function(inp)
        if inp.UserInputType==Enum.UserInputType.MouseButton1 then
            win.Dragging=false; win.ActiveSlider=nil
        end
    end)

    conR = RunService.RenderStepped:Connect(function(dt)
        if win.Destroyed then return end
        if win.Dragging then win.TargetPosition=UIS:GetMouseLocation()-win.DragOffset end
        win.Position=win.Position:Lerp(win.TargetPosition,math.clamp(dt*18,0,1))
        if win.ActiveSlider then win.ActiveSlider:UpdateFromMouse(UIS:GetMouseLocation().X) end
        if win.ActiveTab~=win.TargetTab then
            win.TabAlpha=math.max(0,win.TabAlpha-dt*9)
            if win.TabAlpha<=0.02 then
                win.ActiveTab=win.TargetTab; hdrTitle.Text=win.ActiveTab
                if api.OnTabChanged then api.OnTabChanged(win.ActiveTab) end
                win.TabAlpha=0
            end
        else
            win.TabAlpha=math.min(1,win.TabAlpha+dt*9)
        end
        updateLayout(dt); updateVisibility()
    end)

    -- ── Public API ────────────────────────────────────────────────────────────

    function api:SetTab(n) switchTab(n); return self end
    function api:GetTab()  return win.ActiveTab end
    function api:SetTabChangedCallback(cb)
        assert(cb==nil or type(cb)=="function"); self.OnTabChanged=cb; return self
    end
    function api:SetToggle(key,val,silent)
        local c=self.Controls[key]; assert(c and c.SetState,"Unknown toggle: "..tostring(key))
        c:SetState(val,silent); return self
    end
    function api:Unload()
        if win.Destroyed then return end
        win.Destroyed=true; self.Destroyed=true; win.Dragging=false; win.ActiveSlider=nil
        if conR  then conR:Disconnect()  end
        if conI  then conI:Disconnect()  end
        if conIE then conIE:Disconnect() end
        bg:Remove(); sidebarBg:Remove(); sep:Remove(); hdrLine:Remove()
        brandPip:Remove(); brandName:Remove(); brandSub:Remove()
        hdrTitle:Remove(); hdrSub:Remove()
        for _,b in ipairs(tabBtns) do
            b.Bg:Remove(); b.Ind:Remove(); b.Icon:Remove(); b.LabelText:Remove()
        end
        for _,els in pairs(win.Tabs) do for _,el in ipairs(els) do el:Remove() end end
    end

    updateLayout(1/60); updateVisibility()
    print("[disconnect.wtf] UI initialized.")
    return api
end

return UI
