-- DSWowForever Core.lua — Forever-ready starter (beta 1.60.1 / Interface 16001)
-- Rules obeyed: Lua 5.1, ns namespace, ADDON_LOADED init, secret guards, no combat log,
-- no retail-only calls without nil guards, combat-lockdown queue.
local addonName, ns = ...

ns.pendingRefresh = false

local ADDON_TITLE = "DS Wow Forever"

local function IsSecret(v)
  if type(issecretvalue) == "function" then
    return issecretvalue(v)
  end
  return false
end

local function SafePlayerName()
  local name = UnitName("player")
  if IsSecret(name) then
    return "adventurer"
  end
  return name or "adventurer"
end

local function IsForever()
  if type(WOW_PROJECT_CAMELOT) ~= "nil" and type(WOW_PROJECT_ID) ~= "nil" then
    if WOW_PROJECT_ID == WOW_PROJECT_CAMELOT then
      return true
    end
  end
  local ok, build = pcall(select, 4, GetBuildInfo())
  if ok and type(build) == "number" then
    return build > 16000 and build < 20000
  end
  return false
end

local function InitDB()
  DSWowForeverDB = DSWowForeverDB or {}
  local db = DSWowForeverDB
  if type(db.seen) ~= "number" then
    db.seen = 0
  end
  if type(db.hideBags) ~= "boolean" then
    db.hideBags = false
  end
  if type(db.hideMiniMenu) ~= "boolean" then
    db.hideMiniMenu = false
  end
  if type(db.showXPPercent) ~= "boolean" then
    db.showXPPercent = true
  end
  ns.db = db
end

local function GetBagsBar()
  return _G.BagsBar
end

local function GetMiniMenu()
  -- MicroMenu is the visible row of micro buttons. Fall back to its container on
  -- clients where the buttons are not exposed as a separate frame.
  return _G.MicroMenu or _G.MicroMenuContainer
end

local function SetFrameShown(frame, shown)
  if not frame then
    return
  end

  if shown then
    if not frame:IsShown() then
      frame:Show()
    end
  elseif frame:IsShown() then
    -- Edit Mode systems override Hide(); use the raw method when available so the
    -- toggle does not route through Edit Mode's hooks.
    if type(frame.HideBase) == "function" then
      frame:HideBase()
    else
      frame:Hide()
    end
  end
end

-- XP bar ---------------------------------------------------------------
-- When enabled, the default experience bar and all its visual frame/ticks
-- are completely hidden, and a clean text label showing e.g. "XP: 33%"
-- is displayed in its place.
local xpTextFrame = nil

local function GetXPPercent()
  if type(UnitXP) ~= "function" or type(UnitXPMax) ~= "function" then
    return nil
  end

  local current = UnitXP("player")
  local maximum = UnitXPMax("player")
  if IsSecret(current) or IsSecret(maximum) then
    return nil
  end
  if type(current) ~= "number" or type(maximum) ~= "number" or maximum <= 0 then
    return nil
  end

  local percent = math.floor(current / maximum * 100)
  if percent < 0 then
    return 0
  elseif percent > 100 then
    return 100
  end
  return percent
end

local function SetXPFrameClamped(frame, unclamped)
  if not frame or type(frame.SetClampedToScreen) ~= "function" then
    return
  end

  if frame.DSWF_OriginalClamp == nil then
    if type(frame.IsClampedToScreen) == "function" then
      frame.DSWF_OriginalClamp = frame:IsClampedToScreen()
    else
      frame.DSWF_OriginalClamp = true
    end
  end

  if unclamped then
    frame:SetClampedToScreen(false)
  else
    frame:SetClampedToScreen(frame.DSWF_OriginalClamp)
  end
end

local function HookBarOnShow(frame)
  if frame and not frame.DSWF_AlphaHooked then
    frame.DSWF_AlphaHooked = true
    frame:HookScript("OnShow", function(self)
      if ns.db and ns.db.showXPPercent then
        self:SetAlpha(0)
        SetXPFrameClamped(self, true)
        if self.EnableMouse then
          self:EnableMouse(false)
        end
      end
    end)
  end
end

local function SetXPBarVisualHidden(hidden)
  local alpha = hidden and 0 or 1
  local enableMouse = not hidden

  -- 1. Modern / Mainline / Dragonflight / Forever StatusTrackingBarManager
  local manager = _G.StatusTrackingBarManager
  if manager then
    HookBarOnShow(manager)
    manager:SetAlpha(alpha)
    SetXPFrameClamped(manager, hidden)
    if manager.EnableMouse then
      manager:EnableMouse(enableMouse)
    end
    if type(manager.barContainers) == "table" then
      for _, container in ipairs(manager.barContainers) do
        if container then
          HookBarOnShow(container)
          container:SetAlpha(alpha)
          if container.EnableMouse then
            container:EnableMouse(enableMouse)
          end
          if type(container.bars) == "table" then
            for _, bar in pairs(container.bars) do
              if bar and bar.SetAlpha then
                bar:SetAlpha(alpha)
              end
            end
          end
        end
      end
    end
  end

  local mainContainer = _G.MainStatusTrackingBarContainer
  if mainContainer then
    HookBarOnShow(mainContainer)
    mainContainer:SetAlpha(alpha)
    SetXPFrameClamped(mainContainer, hidden)
    if mainContainer.EnableMouse then
      mainContainer:EnableMouse(enableMouse)
    end
  end

  local secondaryContainer = _G.SecondaryStatusTrackingBarContainer
  if secondaryContainer then
    HookBarOnShow(secondaryContainer)
    secondaryContainer:SetAlpha(alpha)
    if secondaryContainer.EnableMouse then
      secondaryContainer:EnableMouse(enableMouse)
    end
  end

  -- 2. Classic / Era / Legacy MainMenuExpBar (if present)
  local expBar = _G.MainMenuExpBar
  if expBar then
    HookBarOnShow(expBar)
    expBar:SetAlpha(alpha)
    SetXPFrameClamped(expBar, hidden)
    if expBar.EnableMouse then
      expBar:EnableMouse(enableMouse)
    end
  end

  -- Segment dividers (_G["MainMenuXPBarDiv0"] through 19)
  for i = 0, 19 do
    local div = _G["MainMenuXPBarDiv" .. i]
    if div then
      div:SetAlpha(alpha)
    end
  end

  -- Background textures on legacy bar
  for i = 0, 3 do
    local tex = _G["MainMenuXPBarTexture" .. i]
    if tex then
      tex:SetAlpha(alpha)
    end
  end

  -- Exhaustion ticks / fill bars
  local tick = _G.ExhaustionTick
  if tick then
    tick:SetAlpha(alpha)
  end
  local fill = _G.ExhaustionLevelFillBar
  if fill then
    fill:SetAlpha(alpha)
  end
end

local function GetOrCreateXPTextFrame()
  if xpTextFrame then
    return xpTextFrame
  end

  local f = CreateFrame("Frame", "DSWF_XPTextFrame", UIParent)
  f:SetFrameStrata("HIGH")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")

  -- Auto-size: use a small initial size; we'll resize to text width after SetText
  f:SetSize(80, 20)

  local text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  text:SetPoint("CENTER", f, "CENTER", 0, 0)
  text:SetTextColor(1, 1, 1) -- crisp white
  text:SetShadowOffset(1, -1)
  text:SetShadowColor(0, 0, 0, 1)
  f.text = text

  f:SetScript("OnDragStart", function(self)
    self:StartMoving()
  end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    -- Save position relative to UIParent so it survives reloads
    local point, _, relPoint, x, y = self:GetPoint()
    if ns.db then
      ns.db.xpTextPos = { point = point, relPoint = relPoint, x = x, y = y }
    end
  end)

  f:Hide()
  xpTextFrame = f
  return f
end

local function UpdateXPTextFramePosition(f)
  if not f then
    return
  end

  -- Restore saved position if the user has dragged it before
  if ns.db and ns.db.xpTextPos then
    local p = ns.db.xpTextPos
    f:ClearAllPoints()
    f:SetPoint(p.point or "CENTER", UIParent, p.relPoint or "CENTER", p.x or 0, p.y or 0)
    return
  end

  -- Default: centre over the status-bar container (where the XP bar used to be)
  f:ClearAllPoints()
  local anchor = _G.MainStatusTrackingBarContainer
    or _G.StatusTrackingBarManager
    or _G.MainMenuExpBar

  if anchor and anchor:GetCenter() then
    f:SetPoint("CENTER", anchor, "CENTER", 0, 0)
  else
    f:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 8)
  end
end

function ns.UpdateXPPercent()
  if not ns.db then
    return
  end

  local showPercent = ns.db.showXPPercent == true
  local percent = showPercent and GetXPPercent() or nil
  local label = percent and ("XP: " .. tostring(percent) .. "%") or nil

  SetXPBarVisualHidden(showPercent)

  local ff = GetOrCreateXPTextFrame()
  if label then
    UpdateXPTextFramePosition(ff)
    ff.text:SetText(label)
    ff:Show()
  else
    ff:Hide()
  end
end

function ns.ApplyOptions()
  ns.UpdateXPPercent()

  if not ns.db then
    return
  end

  if InCombatLockdown() then
    ns.pendingRefresh = true
    return
  end

  ns.pendingRefresh = false
  SetFrameShown(GetBagsBar(), not ns.db.hideBags)
  SetFrameShown(GetMiniMenu(), not ns.db.hideMiniMenu)
end

local function Refresh()
  ns.ApplyOptions()
end

local function AddCheckbox(category, variable, dbKey, label, tooltip, defaultValue)
  local setting = Settings.RegisterProxySetting(
    category,
    variable,
    Settings.VarType.Boolean,
    label,
    defaultValue == true,
    function()
      return ns.db[dbKey] == true
    end,
    function(value)
      ns.db[dbKey] = value == true
      ns.ApplyOptions()
    end
  )
  Settings.CreateCheckbox(category, setting, tooltip)
  return setting
end

local function CreateOptions()
  if ns.optionsCategory or type(Settings) ~= "table" then
    return
  end
  if type(Settings.RegisterVerticalLayoutCategory) ~= "function"
    or type(Settings.RegisterProxySetting) ~= "function"
    or type(Settings.CreateCheckbox) ~= "function"
    or type(Settings.RegisterAddOnCategory) ~= "function" then
    return
  end

  local category = Settings.RegisterVerticalLayoutCategory(ADDON_TITLE)
  ns.optionsCategory = category

  AddCheckbox(category, "DSWF_HIDE_BAGS", "hideBags",
    "Hide bags menu",
    "Hides the bag bar in the bottom right corner of the screen.")
  AddCheckbox(category, "DSWF_HIDE_MINIMENU", "hideMiniMenu",
    "Hide mini menu",
    "Hides the micro menu buttons (Character, Spellbook, Professions, etc.).")
  AddCheckbox(category, "DSWF_XP_PERCENT", "showXPPercent",
    "Replace XP bar with percentage",
    "Hides the XP bar and shows your current level progress as a percentage.",
    true)

  Settings.RegisterAddOnCategory(category)
end

function ns.OpenOptions()
  CreateOptions()
  if ns.optionsCategory then
    Settings.OpenToCategory(ns.optionsCategory:GetID())
    return true
  end
  return false
end

local function HookEditMode()
  local manager = _G.EditModeManagerFrame
  if manager and not ns.editModeHooked then
    ns.editModeHooked = true
    manager:HookScript("OnHide", function()
      ns.ApplyOptions()
    end)
  end
end

local frame = CreateFrame("Frame", "DSWF_EventFrame")

function frame:ADDON_LOADED(loaded)
  if loaded ~= addonName then
    return
  end
  InitDB()
  CreateOptions()
  self:UnregisterEvent("ADDON_LOADED")
end

function frame:PLAYER_LOGIN()
  ns.db.seen = ns.db.seen + 1
  local tag = IsForever() and "Forever" or "unknown-client"
  print("|cffd4a85a[" .. addonName .. "]|r online (" .. tag .. "), " .. SafePlayerName() .. ". Session " .. ns.db.seen .. ". /ds")
  HookEditMode()
  ns.ApplyOptions()
end

function frame:PLAYER_ENTERING_WORLD()
  ns.ApplyOptions()
end

function frame:PLAYER_XP_UPDATE()
  ns.UpdateXPPercent()
end

function frame:UPDATE_EXHAUSTION()
  ns.UpdateXPPercent()
end

function frame:PLAYER_LEVEL_UP()
  ns.UpdateXPPercent()
end

function frame:ENABLE_XP_GAIN()
  ns.UpdateXPPercent()
end

function frame:DISABLE_XP_GAIN()
  ns.UpdateXPPercent()
end

function frame:PLAYER_MAX_LEVEL_UPDATE()
  ns.UpdateXPPercent()
end

function frame:PLAYER_REGEN_ENABLED()
  if ns.pendingRefresh then
    Refresh()
  end
end

frame:SetScript("OnEvent", function(self, event, ...)
  local handler = self[event]
  if type(handler) == "function" then
    handler(self, ...)
  end
end)

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_XP_UPDATE")
frame:RegisterEvent("UPDATE_EXHAUSTION")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("ENABLE_XP_GAIN")
frame:RegisterEvent("DISABLE_XP_GAIN")
frame:RegisterEvent("PLAYER_MAX_LEVEL_UPDATE")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")

SLASH_DSWOWFOREVER1 = "/ds"
SLASH_DSWOWFOREVER2 = "/dswf"
SlashCmdList["DSWOWFOREVER"] = function(msg)
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if msg == "" then
    if not ns.OpenOptions() then
      print("[" .. addonName .. "] settings UI unavailable on this client.")
    end
  elseif msg == "status" then
    print("[" .. addonName .. "] seen=" .. tostring(ns.db and ns.db.seen or 0)
      .. " build=" .. tostring(select(4, GetBuildInfo()))
      .. " hideBags=" .. tostring(ns.db and ns.db.hideBags)
      .. " hideMiniMenu=" .. tostring(ns.db and ns.db.hideMiniMenu)
      .. " showXPPercent=" .. tostring(ns.db and ns.db.showXPPercent)
      .. " xpPercent=" .. tostring(GetXPPercent()))
    Refresh()
  else
    print("[" .. addonName .. "] usage: /ds (opens options), /ds status")
  end
end
