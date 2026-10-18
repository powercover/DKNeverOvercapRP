local addonName, ns = ...

ns.ADDON_NAME = addonName
ns.TITLE = "DK Never Overcap RP"
ns.MEDIA = "Interface\\AddOns\\" .. addonName .. "\\Media\\"
ns.ICON = "Interface\\AddOns\\" .. addonName .. "\\Icon"

do
  local version = C_AddOns.GetAddOnMetadata(addonName, "Version")
  -- Unpackaged checkouts still carry the packager token.
  if not version or version:find("@", 1, true) then
    version = "dev"
  end
  ns.VERSION = version
end

ns.DK_CLASS_ID = 6
ns.POWER_TYPE = Enum.PowerType.RunicPower
ns.POWER_TOKEN = "RUNIC_POWER"
-- Opacity the aura has at the moment it first appears (scaled by max opacity).
ns.START_ALPHA = 0.15

ns.DB_VERSION = 2

-- Overlay choices in picker order: one pattern drawn around the character
-- and one across the screen, either of which can be off. Layers live in
-- Display. `icon` is the texture shown on the picker tile.
ns.AURAS = {
  { key = "none", name = "None" },
  { key = "runes", name = "Rune circle", icon = "runes" },
  { key = "halo", name = "Halo", icon = "glow" },
  { key = "arcs", name = "Arcs", icon = "arcs_inner" },
  { key = "sigil", name = "Sigil", icon = "sigil" },
  { key = "embers", name = "Embers", icon = "embers" },
}

ns.SCREENS = {
  { key = "none", name = "None" },
  { key = "edge", name = "Edge glow", icon = "edge" },
  { key = "corners", name = "Corners", icon = "corners" },
}

local function HasKey(list, key)
  for _, entry in ipairs(list) do
    if entry.key == key then
      return true
    end
  end
  return false
end

ns.DEFAULTS = {
  enabled = true,
  specs = { [1] = true, [2] = true, [3] = true },
  colors = {
    [1] = { r = 0.88, g = 0.25, b = 0.28 },
    [2] = { r = 0.40, g = 0.68, b = 0.95 },
    [3] = { r = 0.52, g = 0.85, b = 0.40 },
  },
  combatOnly = false,
  startPercent = 85,
  pulse = true,
  pulsePercent = 95,
  aura = "runes",
  screen = "none",
  maxOpacity = 70,
  scale = 100,
  offsetY = -20,
  motion = true,
  smooth = true,
  minimap = { hide = false, angle = 210 },
}

-- min, max, step for every numeric setting.
ns.LIMITS = {
  startPercent = { 0, 100, 1 },
  pulsePercent = { 50, 100, 1 },
  maxOpacity = { 10, 100, 5 },
  scale = { 50, 200, 5 },
  offsetY = { -400, 400, 5 },
}

---------------------------------------------------------------------------
-- Saved variables
---------------------------------------------------------------------------

local function CopyDefaults(src, dst)
  for key, value in pairs(src) do
    if type(value) == "table" then
      if type(dst[key]) ~= "table" then
        dst[key] = {}
      end
      CopyDefaults(value, dst[key])
    elseif dst[key] == nil or type(dst[key]) ~= type(value) then
      dst[key] = value
    end
  end
end

local function ClampSetting(key, value)
  local limit = ns.LIMITS[key]
  if not limit or type(value) ~= "number" then
    return value
  end
  local min, max, step = limit[1], limit[2], limit[3]
  value = math.floor((value - min) / step + 0.5) * step + min
  return math.min(max, math.max(min, value))
end

-- First-release spec colors, replaced by softer ones if never changed.
local OLD_COLORS = {
  { 0.95, 0.12, 0.16 },
  { 0.25, 0.66, 1.00 },
  { 0.45, 0.95, 0.25 },
}

-- Settings from 2.0 development builds.
local function Migrate(db)
  if (db.dbVersion or ns.DB_VERSION) >= 2 then
    return
  end
  if db.style then
    db.pattern = db.style == "edge" and "edge" or "runes"
    db.edgeGlow = db.style == "both"
  end
  if db.pattern == "edge" or db.pattern == "corners" then
    db.aura, db.screen = "none", db.pattern
  elseif db.pattern then
    db.aura, db.screen = db.pattern, db.edgeGlow and "edge" or "none"
  end
  db.style, db.pattern, db.edgeGlow = nil, nil, nil
  if type(db.colors) == "table" then
    for i, old in ipairs(OLD_COLORS) do
      local color = db.colors[i]
      if type(color) == "table" and color.r == old[1] and color.g == old[2] and color.b == old[3] then
        db.colors[i] = nil
      end
    end
  end
end

local function InitDB()
  if type(_G.DKNORP_DB) ~= "table" then
    _G.DKNORP_DB = {}
  end
  local db = _G.DKNORP_DB
  Migrate(db)
  CopyDefaults(ns.DEFAULTS, db)
  for key in pairs(ns.LIMITS) do
    db[key] = ClampSetting(key, db[key])
  end
  if not HasKey(ns.AURAS, db.aura) then
    db.aura = ns.DEFAULTS.aura
  end
  if not HasKey(ns.SCREENS, db.screen) then
    db.screen = ns.DEFAULTS.screen
  end
  db.dbVersion = ns.DB_VERSION
  ns.db = db
end

---------------------------------------------------------------------------
-- Change notification
---------------------------------------------------------------------------

local listeners = {}

-- fn(key) is called after a setting changes. key is "*" after a reset and
-- "state" when the overlay engine turns on or off.
function ns.OnChange(fn)
  listeners[#listeners + 1] = fn
end

function ns.Notify(key)
  for i = 1, #listeners do
    listeners[i](key)
  end
end

function ns.Set(key, value)
  value = ClampSetting(key, value)
  if ns.db[key] == value then
    return value
  end
  ns.db[key] = value
  ns.Notify(key)
  return value
end

function ns.SetSpecTracked(specIndex, tracked)
  ns.db.specs[specIndex] = tracked and true or false
  ns.Notify("specs")
end

function ns.SetSpecColor(specIndex, r, g, b)
  local color = ns.db.colors[specIndex]
  color.r, color.g, color.b = r, g, b
  ns.Notify("colors")
end

function ns.SetMinimapHidden(hidden)
  ns.db.minimap.hide = hidden and true or false
  ns.Notify("minimap")
end

-- Resets everything except where the minimap button sits. The minimap
-- table itself is kept because LibDBIcon holds a reference to it.
function ns.ResetSettings()
  local minimap = ns.db.minimap
  wipe(ns.db)
  minimap.hide = false
  ns.db.minimap = minimap
  CopyDefaults(ns.DEFAULTS, ns.db)
  ns.db.dbVersion = ns.DB_VERSION
  ns.Notify("*")
end

---------------------------------------------------------------------------
-- Player helpers
---------------------------------------------------------------------------

function ns.GetSpecInfo(specIndex)
  local _, name, _, icon = GetSpecializationInfoForClassID(ns.DK_CLASS_ID, specIndex)
  return name or ("Spec " .. specIndex), icon
end

function ns.GetSpecIndex()
  local spec = GetSpecialization and GetSpecialization()
  if spec and spec >= 1 and spec <= 3 then
    return spec
  end
end

-- Color of the current spec; Blood's color on other classes (previews).
function ns.GetActiveColor()
  local spec = ns.isDeathKnight and ns.GetSpecIndex() or 1
  return ns.db.colors[spec]
end

-- In Midnight, combat values can be secret: they can be passed to widgets
-- but not compared or used in arithmetic by addon code.
function ns.IsReadable(value)
  if value == nil then
    return false
  end
  if canaccessvalue then
    local ok, accessible = pcall(canaccessvalue, value)
    return ok and accessible == true
  end
  if issecretvalue then
    local ok, secret = pcall(issecretvalue, value)
    return ok and secret == false
  end
  return true
end

---------------------------------------------------------------------------
-- Bootstrap
---------------------------------------------------------------------------

local loginHandlers = {}

-- Runs fn at PLAYER_LOGIN, in registration (file load) order.
function ns.OnLogin(fn)
  loginHandlers[#loginHandlers + 1] = fn
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self, event, name)
  if event == "ADDON_LOADED" then
    if name == addonName then
      InitDB()
      self:UnregisterEvent("ADDON_LOADED")
    end
    return
  end
  self:UnregisterEvent("PLAYER_LOGIN")
  local _, class = UnitClass("player")
  ns.isDeathKnight = class == "DEATHKNIGHT"
  for i = 1, #loginHandlers do
    loginHandlers[i]()
  end
end)
