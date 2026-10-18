local addonName, ns = ...

ns.ADDON_NAME = addonName
ns.TITLE = "DK Never Overcap RP"
ns.MEDIA = "Interface\\AddOns\\" .. addonName .. "\\Media\\"

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

ns.DB_VERSION = 1

-- Overlay patterns in picker order. `screen` patterns cover the whole
-- screen; the rest are drawn around the character. Layers live in Display.
ns.PATTERNS = {
  { key = "runes", name = "Rune circle", icon = "runes" },
  { key = "halo", name = "Halo", icon = "glow" },
  { key = "arcs", name = "Arcs", icon = "arcs_inner" },
  { key = "sigil", name = "Sigil", icon = "sigil" },
  { key = "embers", name = "Embers", icon = "embers" },
  { key = "edge", name = "Screen edge", icon = "edge", screen = true },
  { key = "corners", name = "Corners", icon = "corners", screen = true },
}

function ns.GetPattern(key)
  for _, pattern in ipairs(ns.PATTERNS) do
    if pattern.key == key then
      return pattern
    end
  end
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
  pattern = "runes",
  edgeGlow = false,
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

local function InitDB()
  if type(_G.DKNORP_DB) ~= "table" then
    _G.DKNORP_DB = {}
  end
  local db = _G.DKNORP_DB
  -- Early 2.0 builds had a three-way "style" instead of patterns.
  if db.style then
    db.pattern = db.style == "edge" and "edge" or "runes"
    db.edgeGlow = db.style == "both"
    db.style = nil
  end
  CopyDefaults(ns.DEFAULTS, db)
  for key in pairs(ns.LIMITS) do
    db[key] = ClampSetting(key, db[key])
  end
  if not ns.GetPattern(db.pattern) then
    db.pattern = ns.DEFAULTS.pattern
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
