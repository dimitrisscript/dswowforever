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

function ns.ApplyOptions()
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

local function AddCheckbox(category, variable, dbKey, label, tooltip)
  local setting = Settings.RegisterProxySetting(
    category,
    variable,
    Settings.VarType.Boolean,
    label,
    false,
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
      .. " hideMiniMenu=" .. tostring(ns.db and ns.db.hideMiniMenu))
    Refresh()
  else
    print("[" .. addonName .. "] usage: /ds (opens options), /ds status")
  end
end
