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
  if type(db.hideObjectives) ~= "boolean" then
    db.hideObjectives = false
  end
  if type(db.showXPPercent) ~= "boolean" then
    db.showXPPercent = true
  end
  if type(db.announceStun) ~= "boolean" then
    db.announceStun = false
  end
  if type(db.stunButtonLocked) ~= "boolean" then
    db.stunButtonLocked = true
  end
  if type(db.trackThornsOnTank) ~= "boolean" then
    db.trackThornsOnTank = false
  end
  if type(db.stunLog) ~= "table" then
    db.stunLog = {}
  end
  if type(db.auraLog) ~= "table" then
    db.auraLog = {}
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

-- Objectives tracker ---------------------------------------------------
-- The quest/objective tracker re-shows itself whenever the quest log updates,
-- so the OnShow hook hides it again while the option is enabled.
local function GetObjectivesTracker()
  local tracker = _G.ObjectiveTrackerFrame or _G.QuestWatchFrame or _G.WatchFrame
  if tracker and not tracker.DSWF_ObjectivesHooked then
    tracker.DSWF_ObjectivesHooked = true
    tracker:HookScript("OnShow", function(self)
      if ns.db and ns.db.hideObjectives then
        SetFrameShown(self, false)
      end
    end)
  end
  return tracker
end

-- XP bar ---------------------------------------------------------------
-- When enabled, the default experience bar and all its visual frame/ticks
-- are completely hidden, and a clean text label showing e.g. "XP: 33%" plus
-- the available rested XP is displayed in its place.
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

  local percent = current / maximum * 100
  if percent < 0 then
    return 0
  elseif percent > 100 then
    return 100
  end
  return percent
end

local function GetRestedXPPercent()
  if type(GetXPExhaustion) ~= "function" or type(UnitXPMax) ~= "function" then
    return nil
  end

  local rested = GetXPExhaustion()
  local maximum = UnitXPMax("player")
  if IsSecret(rested) or IsSecret(maximum) then
    return nil
  end
  if type(rested) ~= "number" or type(maximum) ~= "number" or maximum <= 0 or rested <= 0 then
    return nil
  end

  return rested / maximum * 100
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

    -- Pin the left edge and keep the vertical centre. This way the XP prefix
    -- stays put and the rested suffix grows/shrinks to its right.
    local left = self:GetLeft()
    local _, centerY = self:GetCenter()
    if type(left) == "number" and type(centerY) == "number"
      and not IsSecret(left) and not IsSecret(centerY) then
      self:ClearAllPoints()
      self:SetPoint("LEFT", UIParent, "BOTTOMLEFT", left, centerY)
      if ns.db then
        ns.db.xpTextPos = { point = "LEFT", relPoint = "BOTTOMLEFT", x = left, y = centerY }
      end
    elseif ns.db then
      local point, _, relPoint, x, y = self:GetPoint()
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

  -- Restore a dragged position. The saved x is the left edge, so the label
  -- still grows/shrinks to the right when the rested part changes.
  if ns.db and ns.db.xpTextPos then
    local p = ns.db.xpTextPos
    local point = p.point or "LEFT"
    local relPoint = p.relPoint or "BOTTOMLEFT"
    f:ClearAllPoints()
    f:SetPoint(point, UIParent, relPoint, p.x or 0, p.y or 0)

    -- Migrate older centre/corner saves to a left-edge anchor.
    if point ~= "LEFT" then
      local left = f:GetLeft()
      local _, centerY = f:GetCenter()
      if type(left) == "number" and type(centerY) == "number"
        and not IsSecret(left) and not IsSecret(centerY) then
        f:ClearAllPoints()
        f:SetPoint("LEFT", UIParent, "BOTTOMLEFT", left, centerY)
        ns.db.xpTextPos = { point = "LEFT", relPoint = "BOTTOMLEFT", x = left, y = centerY }
      end
    end
    return
  end

  -- Default: keep the left edge pinned near the centre of the status bar.
  -- The offset is chosen on first layout so the initial label is centred, then
  -- stays fixed while the label width changes.
  local anchor = _G.MainStatusTrackingBarContainer
    or _G.StatusTrackingBarManager
    or _G.MainMenuExpBar

  if anchor then
    if f.DSWFXPLeftOffset == nil then
      local width = f:GetWidth()
      if type(width) ~= "number" or IsSecret(width) or width <= 0 then
        width = 100
      end
      f.DSWFXPLeftOffset = -width / 2
    end
    f:ClearAllPoints()
    f:SetPoint("LEFT", anchor, "CENTER", f.DSWFXPLeftOffset, 0)
  else
    f:ClearAllPoints()
    f:SetPoint("LEFT", UIParent, "BOTTOMLEFT", 8, 8)
  end
end

function ns.UpdateXPPercent()
  if not ns.db then
    return
  end

  local showPercent = ns.db.showXPPercent == true
  local percent = showPercent and GetXPPercent() or nil
  local restedPercent = showPercent and GetRestedXPPercent() or nil
  local label = percent and string.format("XP: %.2f%%", percent) or nil
  if label and restedPercent then
    label = string.format("XP: %.2f%%-%.2f%% Rested", percent, restedPercent)
  end

  SetXPBarVisualHidden(showPercent)

  local ff = GetOrCreateXPTextFrame()
  if label then
    ff.text:SetText(label)

    -- Keep the drag area the same size as the label.
    local width = ff.text:GetStringWidth()
    local height = ff.text:GetStringHeight()
    if type(width) == "number" and type(height) == "number"
      and not IsSecret(width) and not IsSecret(height)
      and width > 0 and height > 0 then
      ff:SetSize(width + 8, height + 4)
    end

    UpdateXPTextFramePosition(ff)
    ff:Show()
  else
    ff:Hide()
  end
end

-- Stun announcer -------------------------------------------------------
-- When enabled, says "Stunned (Xs)" in /say automatically inside instances,
-- where SAY does not require a hardware event. Outdoors it queues the text
-- and shows a click-to-say button, because Forever/Midnight require a
-- hardware event for SAY there. X is the remaining stun duration in seconds.
-- The loss-of-control API is used when readable; during combat its data can
-- be secret, in which case control-lost events provide a generic message.
local STUN_LOC_TYPE = "STUN"
local STUN_ICON = "Interface\\Icons\\Ability_Rogue_KidneyShot"
local stunLastKey = nil
local stunDebug = false
local stunEventsOk = nil

local function SafeText(value)
  if value == nil or IsSecret(value) then
    return "?"
  end
  return tostring(value)
end

local function ReadLocField(data, key)
  local ok, value = pcall(function()
    return data[key]
  end)
  if not ok or IsSecret(value) then
    return nil
  end
  return value
end

local function GetLocCount()
  if type(C_LossOfControl) ~= "table" then
    return 0
  end
  local counter = C_LossOfControl.GetActiveLossOfControlDataCount
  if type(counter) ~= "function" then
    return 0
  end
  local ok, count = pcall(counter)
  if not ok or IsSecret(count) or type(count) ~= "number" or count < 0 then
    return 0
  end
  return count
end

-- Returns a plain copy of one loss-of-control entry, or nil when it cannot be
-- read (missing, forbidden, or secret while loss-of-control info is restricted).
local function GetLocEntry(index)
  if type(C_LossOfControl) ~= "table" then
    return nil
  end
  local getter = C_LossOfControl.GetActiveLossOfControlData
  if type(getter) ~= "function" then
    return nil
  end
  local ok, data = pcall(getter, index)
  if not ok or type(data) ~= "table" or IsSecret(data) then
    return nil
  end

  local locType = ReadLocField(data, "locType")
  if type(locType) ~= "string" then
    return nil
  end

  local spellID = ReadLocField(data, "spellID")
  local startTime = ReadLocField(data, "startTime")
  local timeRemaining = ReadLocField(data, "timeRemaining")
  local duration = ReadLocField(data, "duration")

  return {
    locType = locType,
    displayText = ReadLocField(data, "displayText"),
    spellID = type(spellID) == "number" and spellID or nil,
    startTime = type(startTime) == "number" and startTime or nil,
    timeRemaining = type(timeRemaining) == "number" and timeRemaining or nil,
    duration = type(duration) == "number" and duration or nil,
  }
end

local function EntryRemaining(entry)
  if not entry then
    return nil
  end
  if entry.timeRemaining then
    return entry.timeRemaining
  end
  if entry.duration then
    if entry.startTime then
      return entry.duration - (GetTime() - entry.startTime)
    end
    return entry.duration
  end
  return nil
end

-- Scans the player's loss-of-control list and returns the stun with the
-- longest remaining duration together with a key identifying that stun.
local function GetActiveStun()
  local best
  for i = 1, GetLocCount() do
    local entry = GetLocEntry(i)
    if entry and entry.locType == STUN_LOC_TYPE then
      local remaining = EntryRemaining(entry)
      local key = SafeText(entry.spellID) .. ":" .. SafeText(entry.startTime)
      if not best or (remaining or 0) > (best.remaining or 0) then
        best = { remaining = remaining, key = key }
      end
    end
  end
  return best
end

local function FormatStunSeconds(seconds)
  if type(seconds) ~= "number" or IsSecret(seconds) then
    return nil
  end
  if seconds < 0 then
    seconds = 0
  end
  if seconds >= 10 then
    return tostring(math.floor(seconds + 0.5))
  end
  local text = string.format("%.1f", seconds)
  return (text:gsub("%.0$", ""))
end

local function StunDebug(text)
  if stunDebug then
    print("[" .. addonName .. "] stun debug: " .. text)
  end
end

-- Keeps the last few stun events in the saved variables so a failed run can be
-- inspected afterwards with /ds stun (written to disk on /reload or logout).
local function StunTrace(text)
  if not ns.db then
    return
  end
  local log = ns.db.stunLog
  if type(log) ~= "table" then
    log = {}
    ns.db.stunLog = log
  end
  log[#log + 1] = SafeText(GetTime()) .. "s " .. text
  while #log > 25 do
    table.remove(log, 1)
  end
  StunDebug(text)
end

local function BuildStunMessage(seconds)
  local text = FormatStunSeconds(seconds)
  if text then
    return string.format("Stunned (%ss)", text)
  end
  return "Stunned"
end

local function SendSay(message)
  local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
  if type(send) ~= "function" then
    return false, "SendChatMessage unavailable"
  end
  return pcall(send, message, "SAY")
end

local function SayStun(seconds)
  return SendSay(BuildStunMessage(seconds))
end

-- Click-to-say button --------------------------------------------------
-- A stun is detected from an event, not from a hardware event, so SAY is
-- blocked outdoors. Queue the text and let the player click to send it.
local stunPendingMessage = nil
local stunPendingUntil = 0
local STUN_BUTTON_TIMEOUT = 15
local stunButton = nil
local UpdateStunButton

-- The stun button starts locked so it cannot be dragged by accident. The
-- lock/unlock control in options flips this saved value.
local function IsStunButtonLocked()
  return not ns.db or ns.db.stunButtonLocked ~= false
end

local function ApplyStunButtonPosition(btn)
  local pos = ns.db and ns.db.stunButtonPos
  if type(pos) == "table" and type(pos.x) == "number" and type(pos.y) == "number" then
    btn:ClearAllPoints()
    btn:SetPoint(pos.point or "CENTER", UIParent, pos.relPoint or pos.point or "CENTER", pos.x, pos.y)
    return
  end
  btn:ClearAllPoints()
  btn:SetPoint("CENTER", UIParent, "CENTER", 0, 160)
end

local function SaveStunButtonPosition(btn)
  if not ns.db then
    return
  end
  local point, _, relPoint, x, y = btn:GetPoint()
  if type(point) ~= "string" or type(x) ~= "number" or type(y) ~= "number"
    or IsSecret(x) or IsSecret(y) then
    return
  end
  ns.db.stunButtonPos = { point = point, relPoint = relPoint or point, x = x, y = y }
end

local function GetOrCreateStunButton()
  if stunButton then
    return stunButton
  end
  if InCombatLockdown() then
    return nil
  end

  local ok, btn = pcall(CreateFrame, "Button", "DSWF_StunSayButton", UIParent)
  if not ok or not btn then
    return nil
  end

  btn:SetSize(64, 64)
  btn:SetFrameStrata("HIGH")
  btn:SetClampedToScreen(true)
  btn:SetMovable(true)
  btn:EnableMouse(true)
  btn:RegisterForClicks("AnyUp")
  btn:RegisterForDrag("LeftButton")

  local bg = btn:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(btn)
  bg:SetTexture(STUN_ICON)

  local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
  highlight:SetAllPoints(btn)
  highlight:SetColorTexture(1, 1, 1, 0.25)

  -- Label sits just under the square icon so it does not cover the artwork.
  local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  text:SetPoint("TOP", btn, "BOTTOM", 0, -2)
  text:SetTextColor(1, 1, 1)
  text:SetShadowOffset(1, -1)
  text:SetShadowColor(0, 0, 0, 1)
  btn.DSWF_Text = text

  btn:SetScript("OnClick", function(self)
    if not stunPendingMessage then
      return
    end
    local message = stunPendingMessage
    local sent, err = SendSay(message)
    StunTrace("button click ok=" .. SafeText(sent) .. " err=" .. SafeText(err)
      .. " msg=" .. SafeText(message))
    stunPendingMessage = nil
    stunPendingUntil = 0
    UpdateStunButton()
  end)

  btn:SetScript("OnDragStart", function(self)
    if InCombatLockdown() then
      print("[" .. addonName .. "] Cannot move the stun button while in combat.")
    elseif IsStunButtonLocked() then
      print("[" .. addonName .. "] Stun button is locked. Uncheck \"Lock stun button position\" in options.")
    else
      self:StartMoving()
    end
  end)

  btn:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if not IsStunButtonLocked() then
      SaveStunButtonPosition(self)
    end
  end)

  btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if stunPendingMessage then
      GameTooltip:AddLine("Click to say the queued stun message in /say.")
      GameTooltip:AddLine("SAY needs a click outdoors on Forever.", 0.7, 0.7, 0.7, true)
      GameTooltip:AddLine("Hides when the stun ends.", 0.7, 0.7, 0.7, true)
    else
      GameTooltip:AddLine("Drag to move the stun button.")
      GameTooltip:AddLine("It appears here when you are stunned.", 0.7, 0.7, 0.7, true)
    end
    if IsStunButtonLocked() then
      GameTooltip:AddLine("Locked. Uncheck \"Lock stun button position\" in options to drag.", 0.7, 0.7, 0.7, true)
    else
      GameTooltip:AddLine("Unlocked. Drag to move; check the option again to lock.", 0.7, 0.7, 0.7, true)
    end
    GameTooltip:Show()
  end)

  btn:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  ApplyStunButtonPosition(btn)
  btn:Hide()
  stunButton = btn
  return btn
end

local function ShowStunButton(text)
  local btn = GetOrCreateStunButton()
  if not btn then
    return
  end
  btn.DSWF_Text:SetText(text)
  btn:Show()
end

local function HideStunButton()
  if stunButton then
    stunButton:Hide()
  end
end

local function ClearPendingStun()
  stunPendingMessage = nil
  stunPendingUntil = 0
  if IsStunButtonLocked() then
    HideStunButton()
  else
    ShowStunButton("Drag to move")
  end
end

-- When unlocked, the button stays visible as a positioning handle even with no
-- stun queued, so the player can actually drag it into place.
function UpdateStunButton()
  if not ns.db or ns.db.announceStun ~= true then
    stunPendingMessage = nil
    stunPendingUntil = 0
    HideStunButton()
    return
  end
  if stunPendingMessage then
    ShowStunButton(stunPendingMessage)
    return
  end
  if not IsStunButtonLocked() then
    ShowStunButton("Drag to move")
  else
    HideStunButton()
  end
end

-- SAY needs a hardware event outdoors but not inside instances. When we are
-- in an instance we can send straight from the event handler; otherwise the
-- player has to click the button to provide the hardware event.
local function CanAutoSay()
  if type(IsInInstance) ~= "function" then
    return false
  end
  local ok, inside = pcall(IsInInstance)
  if not ok or IsSecret(inside) then
    return false
  end
  return inside == true
end

local function QueueStunMessage(message)
  if CanAutoSay() then
    local ok, err = SendSay(message)
    StunTrace("auto say ok=" .. SafeText(ok) .. " err=" .. SafeText(err)
      .. " msg=" .. SafeText(message))
    ClearPendingStun()
    return
  end

  stunPendingMessage = message
  stunPendingUntil = GetTime() + STUN_BUTTON_TIMEOUT
  UpdateStunButton()
end

-- When the loss-of-control data is secret (notably during combat), the typed
-- stun and its duration cannot be read. These events still fire without a
-- secret payload, so use them as a last resort and offer a generic message.
local function QueueGenericStun(reason)
  if not ns.db or ns.db.announceStun ~= true then
    return
  end
  if stunLastKey == "generic" or stunPendingMessage then
    return
  end
  stunLastKey = "generic"
  StunTrace(reason .. " generic queued (LoC data unreadable)")
  QueueStunMessage("Stunned")
end

local function TraceLocEntries(reason)
  local count = GetLocCount()
  StunTrace(reason .. " count=" .. SafeText(count))
  for i = 1, count do
    local entry = GetLocEntry(i)
    if entry then
      StunTrace(reason .. " #" .. i
        .. " loc=" .. SafeText(entry.locType)
        .. " spell=" .. SafeText(entry.spellID)
        .. " start=" .. SafeText(entry.startTime)
        .. " remain=" .. SafeText(entry.timeRemaining)
        .. " dur=" .. SafeText(entry.duration))
    else
      StunTrace(reason .. " #" .. i .. " unreadable")
    end
  end
end

-- Diagnostic only: records the player's harmful auras so a stun that the
-- loss-of-control API does not report can still be identified afterwards.
local function ReadAuraField(aura, key)
  local ok, value = pcall(function()
    return aura[key]
  end)
  if not ok or IsSecret(value) then
    return nil
  end
  return value
end

local function DescribeAura(aura)
  local duration = ReadAuraField(aura, "duration")
  local expiration = ReadAuraField(aura, "expirationTime")
  local remaining
  if type(duration) == "number" and type(expiration) == "number" then
    remaining = expiration - GetTime()
  end
  local spellID = ReadAuraField(aura, "spellId") or ReadAuraField(aura, "spellID")
  return SafeText(ReadAuraField(aura, "name"))
    .. " id=" .. SafeText(spellID)
    .. " type=" .. SafeText(ReadAuraField(aura, "debuffType"))
    .. " remain=" .. SafeText(remaining)
end

local auraTraceAt = 0
local function TracePlayerAuras(reason)
  if not ns.db then
    return
  end
  local now = GetTime()
  if now - auraTraceAt < 0.5 then
    return
  end
  auraTraceAt = now

  local parts = {}
  local method = "none"
  local C = C_UnitAuras
  if C and type(C.GetUnitAuras) == "function" then
    local ok, list = pcall(C.GetUnitAuras, "player", "HARMFUL")
    if ok and type(list) == "table" then
      method = "GetUnitAuras"
      for i = 1, #list do
        parts[#parts + 1] = DescribeAura(list[i])
      end
    end
  elseif C and type(C.GetAuraDataByIndex) == "function" then
    method = "GetAuraDataByIndex"
    for i = 1, 40 do
      local ok, aura = pcall(C.GetAuraDataByIndex, "player", i, "HARMFUL")
      if not ok or type(aura) ~= "table" then
        break
      end
      parts[#parts + 1] = DescribeAura(aura)
    end
  elseif type(UnitAura) == "function" then
    method = "UnitAura"
    for i = 1, 40 do
      local ok, name, _, count, debuffType, duration, expiration, _, _, _, spellID =
        pcall(UnitAura, "player", i, "HARMFUL")
      if not ok or name == nil then
        break
      end
      parts[#parts + 1] = DescribeAura({
        name = name, count = count, debuffType = debuffType,
        duration = duration, expirationTime = expiration, spellId = spellID,
      })
    end
  end

  local log = ns.db.auraLog
  if type(log) ~= "table" then
    log = {}
    ns.db.auraLog = log
  end
  log[#log + 1] = SafeText(now) .. "s " .. reason .. " via=" .. method
    .. " n=" .. #parts .. " [" .. table.concat(parts, " | ") .. "]"
  while #log > 8 do
    table.remove(log, 1)
  end
end

-- Announces at most one message per stun. Any of the events below can call
-- this, so a client that does not fire one of them still announces via another.
local function TryAnnounceStun(reason)
  if not ns.db or ns.db.announceStun ~= true then
    return false
  end

  local stun = GetActiveStun()
  if not stun then
    return false
  end
  if stun.key == stunLastKey then
    return false
  end

  stunLastKey = stun.key
  local message = BuildStunMessage(stun.remaining)
  StunTrace((reason or "?") .. " queued remain=" .. SafeText(stun.remaining)
    .. " key=" .. stun.key .. " msg=" .. SafeText(message))
  QueueStunMessage(message)
  return true
end

-- A client that does not send the loss-of-control events to us still shows its
-- own stun banner; use that as one more trigger.
local function HookLossOfControlFrame()
  local locFrame = _G.LossOfControlFrame
  if not locFrame or locFrame.DSWF_StunHooked then
    return
  end
  locFrame.DSWF_StunHooked = true
  locFrame:HookScript("OnShow", function()
    StunTrace("LOC_FRAME shown")
    if not TryAnnounceStun("LOC_FRAME") then
      QueueGenericStun("LOC_FRAME")
    end
  end)
  locFrame:HookScript("OnHide", function()
    stunLastKey = nil
  end)
end

function ns.PrintStunStatus()
  local db = ns.db or {}
  local inInstance, instanceType = false, nil
  if type(IsInInstance) == "function" then
    local ok, inside, kind = pcall(IsInInstance)
    if ok and not IsSecret(inside) and not IsSecret(kind) then
      inInstance = inside == true
      instanceType = kind
    end
  end

  local cvarGetter = (C_CVar and C_CVar.GetCVar) or GetCVar
  local locCvar
  if type(cvarGetter) == "function" then
    local ok, value = pcall(cvarGetter, "lossOfControl")
    if ok and not IsSecret(value) then
      locCvar = value
    end
  end

  print("[" .. addonName .. "] announceStun=" .. SafeText(db.announceStun)
    .. " stunButtonLocked=" .. SafeText(db.stunButtonLocked)
    .. " lossOfControlApi=" .. SafeText(type(C_LossOfControl) == "table")
    .. " count=" .. SafeText(GetLocCount())
    .. " events=" .. SafeText(stunEventsOk)
    .. " debug=" .. SafeText(stunDebug)
    .. " inInstance=" .. SafeText(inInstance)
    .. " instanceType=" .. SafeText(instanceType)
    .. " lossOfControlCvar=" .. SafeText(locCvar))

  for i = 1, GetLocCount() do
    local entry = GetLocEntry(i)
    if entry then
      print(string.format("[%s] #%d locType=%s text=%s spell=%s start=%s remain=%s duration=%s",
        addonName, i, SafeText(entry.locType), SafeText(entry.displayText),
        SafeText(entry.spellID), SafeText(entry.startTime),
        SafeText(entry.timeRemaining), SafeText(entry.duration)))
    else
      print("[" .. addonName .. "] #" .. i .. " unreadable (secret or no data)")
    end
  end

  local log = db.stunLog
  if type(log) == "table" and #log > 0 then
    print("[" .. addonName .. "] last stun events (" .. #log .. "):")
    for i = 1, #log do
      print("[" .. addonName .. "]   " .. SafeText(log[i]))
    end
  else
    print("[" .. addonName .. "] no stun events recorded yet")
  end

  local auraLog = db.auraLog
  if type(auraLog) == "table" and #auraLog > 0 then
    print("[" .. addonName .. "] last harmful auras (" .. #auraLog .. "):")
    for i = 1, #auraLog do
      print("[" .. addonName .. "]   " .. SafeText(auraLog[i]))
    end
  end
end

-- Thorns tracker -------------------------------------------------------
-- While playing a druid inside a dungeon, show a clickable Thorns icon when
-- the group's tank is missing the buff. The icon is only visible out of
-- combat and is hidden again as soon as the tank has Thorns.
local THORNS_SPELL_NAME = "Thorns"
local THORNS_ICON = "Interface\\Icons\\Spell_Nature_Thorns"

local thornsButton = nil

local function IsDruid()
  if type(UnitClass) ~= "function" then
    return false
  end
  local ok, _, class = pcall(UnitClass, "player")
  if not ok or IsSecret(class) then
    return false
  end
  return class == "DRUID"
end

local function IsInDungeon()
  if type(GetInstanceInfo) ~= "function" then
    return false
  end
  local ok, _, instanceType = pcall(GetInstanceInfo)
  if not ok or IsSecret(instanceType) then
    return false
  end
  return instanceType == "party"
end

local function GetUnitRole(unit)
  if type(UnitGroupRolesAssigned) ~= "function" then
    return nil
  end
  local ok, role = pcall(UnitGroupRolesAssigned, unit)
  if not ok or IsSecret(role) then
    return nil
  end
  return role
end

-- Returns the dungeon group's tank. Roles are assigned by the LFG system or
-- manually in the party/raid frame, so the player is checked as well.
local function GetDungeonTank()
  if GetUnitRole("player") == "TANK" then
    return "player"
  end
  for i = 1, 4 do
    local unit = "party" .. i
    if GetUnitRole(unit) == "TANK" then
      return unit
    end
  end
  return nil
end

local function HasThorns(unit)
  -- Preferred on Forever: aura lookups by name. The returned AuraData can be
  -- secret for other units, so only its presence is tested.
  if type(C_UnitAuras) == "table"
    and type(C_UnitAuras.GetAuraDataBySpellName) == "function" then
    local ok, aura = pcall(C_UnitAuras.GetAuraDataBySpellName, unit, THORNS_SPELL_NAME, "HELPFUL")
    if ok then
      if aura then
        return true
      end
      return false
    end
  end

  -- Fallbacks for clients that still expose the older aura helpers.
  if type(AuraUtil) == "table" and type(AuraUtil.FindAuraByName) == "function" then
    local ok, aura = pcall(AuraUtil.FindAuraByName, THORNS_SPELL_NAME, unit, "HELPFUL")
    if ok then
      if aura then
        return true
      end
      return false
    end
  end

  if type(UnitAura) == "function" then
    for i = 1, 32 do
      local ok, name = pcall(UnitAura, unit, i, "HELPFUL")
      if not ok then
        return false
      end
      if name == nil then
        return false
      end
      if not IsSecret(name) and name == THORNS_SPELL_NAME then
        return true
      end
    end
  end

  return false
end

local function IsUnitDead(unit)
  if type(UnitIsDeadOrGhost) ~= "function" then
    return false
  end
  local ok, dead = pcall(UnitIsDeadOrGhost, unit)
  if not ok or IsSecret(dead) then
    return false
  end
  if dead then
    return true
  end
  return false
end

local function SafeUnitName(unit)
  if type(UnitName) ~= "function" then
    return nil
  end
  local ok, name = pcall(UnitName, unit)
  if not ok or type(name) ~= "string" or IsSecret(name) or name == "" then
    return nil
  end
  return name
end

local function SaveThornsButtonPosition(btn)
  if not ns.db then
    return
  end
  local point, _, relPoint, x, y = btn:GetPoint()
  if type(point) ~= "string" or type(x) ~= "number" or type(y) ~= "number" then
    return
  end
  if IsSecret(x) or IsSecret(y) then
    return
  end
  ns.db.thornsIconPos = {
    point = point,
    relPoint = relPoint or point,
    x = x,
    y = y,
  }
end

local function ApplyThornsButtonPosition(btn)
  local pos = ns.db and ns.db.thornsIconPos
  if type(pos) == "table"
    and type(pos.point) == "string"
    and type(pos.x) == "number"
    and type(pos.y) == "number" then
    btn:ClearAllPoints()
    btn:SetPoint(pos.point, UIParent, pos.relPoint or pos.point, pos.x, pos.y)
    return
  end

  btn:ClearAllPoints()
  btn:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
end

local function GetOrCreateThornsButton()
  if thornsButton then
    return thornsButton
  end
  if InCombatLockdown() then
    return nil
  end

  -- InsecureActionButtonTemplate can perform the protected cast out of combat
  -- but does not protect the button itself, so it can still be hidden when
  -- combat starts.
  local ok, btn = pcall(CreateFrame, "Button", "DSWF_ThornsButton", UIParent, "InsecureActionButtonTemplate")
  if not ok or not btn then
    return nil
  end

  btn:SetSize(36, 36)
  btn:SetFrameStrata("HIGH")
  btn:SetClampedToScreen(true)
  btn:RegisterForClicks("AnyUp")
  btn:RegisterForDrag("LeftButton")

  local icon = btn:CreateTexture(nil, "ARTWORK")
  icon:SetAllPoints(btn)
  icon:SetTexture(THORNS_ICON)
  btn.icon = icon

  local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
  highlight:SetAllPoints(btn)
  highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
  highlight:SetBlendMode("ADD")

  btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(THORNS_SPELL_NAME)
    local tankName = self.DSWF_TankName
    if tankName then
      GameTooltip:AddLine("Click to cast Thorns on " .. tankName .. ".", 1, 1, 1, true)
    else
      GameTooltip:AddLine("Click to cast Thorns on the tank.", 1, 1, 1, true)
    end
    GameTooltip:AddLine("Out of combat only. Drag to move.", 0.7, 0.7, 0.7, true)
    GameTooltip:Show()
  end)

  btn:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)

  btn:SetScript("OnDragStart", function(self)
    if not InCombatLockdown() then
      self:StartMoving()
    end
  end)

  btn:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SaveThornsButtonPosition(self)
  end)

  ApplyThornsButtonPosition(btn)
  btn:Hide()
  thornsButton = btn
  return btn
end

function ns.UpdateThornsIcon()
  local btn = thornsButton
  local enabled = ns.db and ns.db.trackThornsOnTank == true

  if not enabled or not IsDruid() or not IsInDungeon() or InCombatLockdown() then
    if btn then
      btn:Hide()
    end
    ns.thornsTank = nil
    return
  end

  btn = GetOrCreateThornsButton()
  if not btn then
    ns.thornsTank = nil
    return
  end

  local tank = GetDungeonTank()
  if not tank then
    btn:Hide()
    ns.thornsTank = nil
    return
  end

  -- Keep tracking the tank even while the icon is hidden, so UNIT_AURA can
  -- bring the icon back when Thorns expires.
  ns.thornsTank = tank
  btn.DSWF_TankName = SafeUnitName(tank)

  if IsUnitDead(tank) or IsUnitDead("player") or HasThorns(tank) then
    btn:Hide()
    return
  end

  btn:SetAttribute("type", "spell")
  btn:SetAttribute("spell", THORNS_SPELL_NAME)
  btn:SetAttribute("unit", tank)
  btn:Show()
end

function ns.ApplyOptions()
  ns.UpdateXPPercent()

  if not ns.db then
    return
  end

  ns.UpdateThornsIcon()
  UpdateStunButton()

  if InCombatLockdown() then
    ns.pendingRefresh = true
    return
  end

  ns.pendingRefresh = false
  SetFrameShown(GetBagsBar(), not ns.db.hideBags)
  SetFrameShown(GetMiniMenu(), not ns.db.hideMiniMenu)
  SetFrameShown(GetObjectivesTracker(), not ns.db.hideObjectives)
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

-- Puts the lock control on the same row as the announce checkbox when the
-- client supports the combined control. Falls back to two plain checkboxes.
local function AddStunCheckboxWithLock(category)
  local variable = "DSWF_ANNOUNCE_STUN"
  local label = "Announce stuns in /say"
  local tooltip = "Says \"Stunned (Xs)\" in /say automatically inside instances. "
    .. "Outdoors, shows a click button because SAY needs a hardware event there; "
    .. "the button hides when the stun ends."
  local setting = Settings.RegisterProxySetting(
    category,
    variable,
    Settings.VarType.Boolean,
    label,
    false,
    function()
      return ns.db.announceStun == true
    end,
    function(value)
      ns.db.announceStun = value == true
      ns.ApplyOptions()
    end
  )

  local combined = false
  if type(CreateSettingsCheckboxWithButtonInitializer) == "function"
    and type(Settings.RegisterInitializer) == "function" then
    local function LockButtonText()
      return IsStunButtonLocked() and "Locked" or "Unlocked"
    end

    local function OnLockButtonClick()
      if not ns.db then
        return
      end
      ns.db.stunButtonLocked = not IsStunButtonLocked()
      UpdateStunButton()
      pcall(Settings.NotifyUpdate, variable)
    end

    local function EvaluateLockButton(control)
      if not control or not control.Button then
        return
      end
      control.Button.tooltipText = IsStunButtonLocked()
        and "Stun button is locked. Click to unlock and allow dragging."
        or "Stun button is unlocked. Drag it to move, then click to lock."
    end

    local created, initializer = pcall(
      CreateSettingsCheckboxWithButtonInitializer,
      setting,
      LockButtonText,
      OnLockButtonClick,
      EvaluateLockButton,
      false,
      tooltip
    )
    if created and initializer then
      combined = pcall(Settings.RegisterInitializer, category, initializer)
    end
  end

  if not combined then
    Settings.CreateCheckbox(category, setting, tooltip)
    AddCheckbox(category, "DSWF_STUN_LOCK", "stunButtonLocked",
      "Lock stun button position",
      "Checked: the stun button cannot be dragged. Uncheck it to move the button, then check it again to lock the new position.",
      true)
  end
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
  AddCheckbox(category, "DSWF_HIDE_OBJECTIVES", "hideObjectives",
    "Hide objectives tracker",
    "Hides the quest and objective tracker on the right side of the screen.")
  AddCheckbox(category, "DSWF_XP_PERCENT", "showXPPercent",
    "Replace XP bar with percentage",
    "Hides the XP bar and shows your current level progress and rested XP as percentages.",
    true)
  AddStunCheckboxWithLock(category)

  local druidCategory = category
  if type(Settings.RegisterVerticalLayoutSubcategory) == "function" then
    local ok, subcategory = pcall(Settings.RegisterVerticalLayoutSubcategory, category, "Druid")
    if ok and subcategory then
      druidCategory = subcategory
    end
  end

  AddCheckbox(druidCategory, "DSWF_TRACK_THORNS_ON_TANK", "trackThornsOnTank",
    "Track thorns on tank",
    "When playing a druid in a dungeon, shows a Thorns icon while the tank is missing Thorns. Click the icon to buff the tank. Only shown out of combat.")

  Settings.RegisterAddOnCategory(category)
end

local pendingOptionsOpen = false

function ns.OpenOptions()
  if InCombatLockdown() then
    if not pendingOptionsOpen then
      pendingOptionsOpen = true
      print("[" .. addonName .. "] Options will open when combat ends.")
      local waiter = CreateFrame("Frame")
      waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
      waiter:SetScript("OnEvent", function(self)
        self:UnregisterAllEvents()
        self:SetScript("OnEvent", nil)
        pendingOptionsOpen = false
        ns.OpenOptions()
      end)
    end
    return false
  end
  local ok, err = pcall(CreateOptions)
  if not ok then
    print("[" .. addonName .. "] options error: " .. tostring(err))
  end
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
  pcall(CreateOptions)
  self:UnregisterEvent("ADDON_LOADED")
end

function frame:PLAYER_LOGIN()
  ns.db.seen = ns.db.seen + 1
  local tag = IsForever() and "Forever" or "unknown-client"
  print("|cffd4a85a[" .. addonName .. "]|r online (" .. tag .. "), " .. SafePlayerName() .. ". Session " .. ns.db.seen .. ". /ds")
  HookEditMode()
  ns.ApplyOptions()
  HookLossOfControlFrame()
  GetOrCreateStunButton()
  UpdateStunButton()
end

function frame:PLAYER_ENTERING_WORLD()
  ns.ApplyOptions()
  HookLossOfControlFrame()
  GetOrCreateStunButton()
  UpdateStunButton()
end

function frame:PLAYER_XP_UPDATE()
  ns.UpdateXPPercent()
end

function frame:UPDATE_EXHAUSTION()
  ns.UpdateXPPercent()
end

function frame:PLAYER_UPDATE_RESTING()
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
  ns.UpdateThornsIcon()
  UpdateStunButton()
  if ns.pendingRefresh then
    Refresh()
  end
end

function frame:PLAYER_REGEN_DISABLED()
  ns.UpdateThornsIcon()
end

function frame:PLAYER_DEAD()
  ns.UpdateThornsIcon()
end

function frame:PLAYER_ALIVE()
  ns.UpdateThornsIcon()
end

function frame:UNIT_HEALTH(unit)
  if not ns.thornsTank then
    return
  end
  if type(unit) == "string" and not IsSecret(unit) and unit ~= ns.thornsTank then
    return
  end
  ns.UpdateThornsIcon()
end

function frame:ZONE_CHANGED_NEW_AREA()
  ns.UpdateThornsIcon()
end

function frame:GROUP_ROSTER_UPDATE()
  ns.UpdateThornsIcon()
end

function frame:PLAYER_ROLES_ASSIGNED()
  ns.UpdateThornsIcon()
end

function frame:UNIT_AURA(unit)
  -- A stun also fires UNIT_AURA, so it doubles as a fallback trigger when the
  -- loss-of-control events are not fired by the client.
  if type(unit) ~= "string" or IsSecret(unit) or unit == "player" then
    if ns.db and ns.db.announceStun == true then
      TracePlayerAuras("UNIT_AURA")
    end
    TryAnnounceStun("UNIT_AURA")
  end

  if not ns.thornsTank then
    return
  end
  if type(unit) == "string" and not IsSecret(unit) and unit ~= ns.thornsTank then
    return
  end
  ns.UpdateThornsIcon()
end

function frame:LOSS_OF_CONTROL_ADDED(unit, effectIndex)
  TraceLocEntries("LOC_ADDED unit=" .. SafeText(unit) .. " index=" .. SafeText(effectIndex))
  if stunDebug then
    ns.PrintStunStatus()
  end
  local isPlayer = (type(unit) == "string" and not IsSecret(unit) and unit == "player")
  if isPlayer and not TryAnnounceStun("LOC_ADDED") then
    QueueGenericStun("LOC_ADDED")
  end
end

function frame:LOSS_OF_CONTROL_UPDATE(unit)
  TraceLocEntries("LOC_UPDATE unit=" .. SafeText(unit))
  if GetLocCount() == 0 then
    ClearPendingStun()
    return
  end
  if not TryAnnounceStun("LOC_UPDATE") then
    QueueGenericStun("LOC_UPDATE")
  end
end

function frame:PLAYER_CONTROL_LOST()
  TraceLocEntries("CONTROL_LOST")
  if ns.db and ns.db.announceStun == true then
    TracePlayerAuras("CONTROL_LOST")
  end
  if stunDebug then
    ns.PrintStunStatus()
  end
  if not TryAnnounceStun("CONTROL_LOST") and GetLocCount() > 0 then
    QueueGenericStun("CONTROL_LOST")
  end
end

function frame:PLAYER_CONTROL_GAINED()
  StunTrace("CONTROL_GAINED")
  stunLastKey = nil
  ClearPendingStun()
end

frame:SetScript("OnEvent", function(self, event, ...)
  local handler = self[event]
  if type(handler) == "function" then
    handler(self, ...)
  end
end)

-- Some clients do not fire the loss-of-control events at all. A cheap poll is
-- the last-resort trigger: it only runs while the option is enabled and only
-- announces once per stun thanks to the start-time key.
local stunPollElapsed = 0
frame:SetScript("OnUpdate", function(_, elapsed)
  if not ns.db or ns.db.announceStun ~= true then
    return
  end
  stunPollElapsed = stunPollElapsed + (elapsed or 0)
  if stunPollElapsed < 0.2 then
    return
  end
  stunPollElapsed = 0
  if stunPendingMessage and GetLocCount() == 0 then
    StunTrace("loc cleared")
    ClearPendingStun()
    return
  end
  TryAnnounceStun("POLL")
  if stunPendingMessage and GetTime() > stunPendingUntil then
    StunTrace("pending expired")
    ClearPendingStun()
  end
end)

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_XP_UPDATE")
frame:RegisterEvent("UPDATE_EXHAUSTION")
frame:RegisterEvent("PLAYER_UPDATE_RESTING")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("ENABLE_XP_GAIN")
frame:RegisterEvent("DISABLE_XP_GAIN")
frame:RegisterEvent("PLAYER_MAX_LEVEL_UPDATE")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_DEAD")
frame:RegisterEvent("PLAYER_ALIVE")
frame:RegisterEvent("UNIT_HEALTH")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("UNIT_AURA")
-- Loss-of-control events are the reliable way to tell a stun apart from roots
-- and fears. Older clients may not ship all of them, so register best-effort
-- and fall back to UNIT_AURA above.
stunEventsOk = true
for _, event in ipairs({
  "LOSS_OF_CONTROL_ADDED",
  "LOSS_OF_CONTROL_UPDATE",
  "PLAYER_CONTROL_LOST",
  "PLAYER_CONTROL_GAINED",
}) do
  if not pcall(frame.RegisterEvent, frame, event) then
    stunEventsOk = false
  end
end
pcall(frame.RegisterEvent, frame, "PLAYER_ROLES_ASSIGNED")

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
      .. " hideObjectives=" .. tostring(ns.db and ns.db.hideObjectives)
      .. " showXPPercent=" .. tostring(ns.db and ns.db.showXPPercent)
      .. " announceStun=" .. tostring(ns.db and ns.db.announceStun)
      .. " stunButtonLocked=" .. tostring(ns.db and ns.db.stunButtonLocked)
      .. " trackThornsOnTank=" .. tostring(ns.db and ns.db.trackThornsOnTank)
      .. " xpPercent=" .. tostring(GetXPPercent()))
    Refresh()
  elseif msg == "stun" then
    ns.PrintStunStatus()
  elseif msg == "stun debug" then
    stunDebug = not stunDebug
    print("[" .. addonName .. "] stun debug " .. (stunDebug and "on" or "off"))
  elseif msg == "stun test" then
    local ok, err = SayStun(2)
    print("[" .. addonName .. "] stun test: ok=" .. SafeText(ok) .. " err=" .. SafeText(err))
  elseif msg == "stun button" then
    QueueStunMessage(BuildStunMessage(2))
    print("[" .. addonName .. "] stun button queued for testing")
  elseif msg == "stun lock" then
    if ns.db then
      ns.db.stunButtonLocked = not IsStunButtonLocked()
      UpdateStunButton()
      print("[" .. addonName .. "] stun button " .. (IsStunButtonLocked() and "locked" or "unlocked"))
    end
  elseif msg == "stun clear" then
    if ns.db then
      ns.db.stunLog = {}
    end
    print("[" .. addonName .. "] stun log cleared")
  else
    print("[" .. addonName .. "] usage: /ds (opens options), /ds status, /ds stun, /ds stun test, /ds stun button, /ds stun lock, /ds stun debug, /ds stun clear")
  end
end
