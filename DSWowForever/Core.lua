-- DSWowForever Core.lua — Forever-ready starter (beta 1.60.1 / Interface 16001)
-- Rules obeyed: Lua 5.1, ns namespace, ADDON_LOADED init, secret guards, no combat log,
-- no retail-only calls without nil guards, combat-lockdown queue.
local addonName, ns = ...

ns.pendingRefresh = false

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

local function Refresh()
  if InCombatLockdown() then
    ns.pendingRefresh = true
    return
  end
  ns.pendingRefresh = false
  -- Safe UI work goes here (own frames only, never Blizzard secure frames).
end

local frame = CreateFrame("Frame", "DSWF_EventFrame")

function frame:ADDON_LOADED(loaded)
  if loaded ~= addonName then
    return
  end
  DSWowForeverDB = DSWowForeverDB or { seen = 0 }
  ns.db = DSWowForeverDB
  self:UnregisterEvent("ADDON_LOADED")
end

function frame:PLAYER_LOGIN()
  ns.db.seen = ns.db.seen + 1
  local tag = IsForever() and "Forever" or "unknown-client"
  print("|cffd4a85a[" .. addonName .. "]|r online (" .. tag .. "), " .. SafePlayerName() .. ". Session " .. ns.db.seen .. ". /dswf")
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
frame:RegisterEvent("PLAYER_REGEN_ENABLED")

SLASH_DSWOWFOREVER1 = "/dswf"
SlashCmdList["DSWOWFOREVER"] = function(msg)
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if msg == "" then
    print("[" .. addonName .. "] seen=" .. tostring(ns.db and ns.db.seen or 0) .. " build=" .. tostring(select(4, GetBuildInfo())))
    Refresh()
  else
    print("[" .. addonName .. "] unknown option. Try /dswf")
  end
end
