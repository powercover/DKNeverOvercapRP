local addonName, ns = ...

ns.ADDON_NAME = addonName
ns.TITLE = "BDK Never Overcap RP"
ns.ICON = "Interface\\Icons\\spell_deathknight_deathstrike"
ns.ACCENT = { r = 0.77, g = 0.12, b = 0.23 }
ns.ACCENT_HEX = "ffc41e3a"

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

ns.DEFAULTS = {
  enabled = true,
  specs = { [1] = true, [2] = false, [3] = false },
  combatOnly = false,
  startPercent = 85,
  pulse = true,
  pulsePercent = 95,
  texture = "mixed",
  useTint = false,
  tint = { r = 1, g = 0.12, b = 0.08 },
  maxOpacity = 100,
  scale = 100,
  offsetY = -20,
  spin = true,
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

ns.TEXTURE_PRESETS = {
  { key = "mixed", name = "Blood Boil + Necropolis", side = 511104, corner = 511105 },
  { key = "bloodboil", name = "Blood Boil", side = 511104, corner = 511104 },
  { key = "necropolis", name = "Necropolis", side = 511105, corner = 511105 },
  { key = "bloodsurge", name = "Blood Surge", side = 449487, corner = 449487 },
  { key = "suddendoom", name = "Sudden Doom", side = 450932, corner = 450932 },
  { key = "shadowofdeath", name = "Shadow of Death", side = 627609, corner = 627609 },
  { key = "darktransformation", name = "Dark Transformation", side = 461878, corner = 461878 },
  { key = "suddendeath", name = "Sudden Death", side = 449493, corner = 449493 },
  { key = "killingmachine", name = "Killing Machine", side = 458740, corner = 458740 },
}

local presetsByKey = {}
for _, preset in ipairs(ns.TEXTURE_PRESETS) do
  presetsByKey[preset.key] = preset
end

function ns.GetTexturePreset(key)
  return presetsByKey[key or ns.db.texture] or ns.TEXTURE_PRESETS[1]
end

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

local function Migrate(db)
  local version = db.dbVersion or (db.settingsRev and 1) or ns.DB_VERSION
  if version < 2 then
    -- v1 used flat keys; carry over what the user had set.
    if type(db.overlayAtPercent) == "number" then
      db.startPercent = db.overlayAtPercent
    end
    if type(db.textureKey) == "string" then
      db.texture = db.textureKey
    end
    if type(db.minimapAngle) == "number" then
      db.minimap = { hide = false, angle = db.minimapAngle }
    end
    for _, key in ipairs({ "overlayAtPercent", "textureKey", "minimapAngle", "warnAt", "criticalAt", "powerMaxFallback", "settingsRev" }) do
      db[key] = nil
    end
  end
  db.dbVersion = ns.DB_VERSION
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
  if type(_G.BDKNORP_DB) ~= "table" then
    _G.BDKNORP_DB = {}
  end
  local db = _G.BDKNORP_DB
  Migrate(db)
  CopyDefaults(ns.DEFAULTS, db)
  for key in pairs(ns.LIMITS) do
    db[key] = ClampSetting(key, db[key])
  end
  if not presetsByKey[db.texture] then
    db.texture = ns.DEFAULTS.texture
  end
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

function ns.SetTint(r, g, b)
  local tint = ns.db.tint
  tint.r, tint.g, tint.b = r, g, b
  ns.Notify("tint")
end

function ns.SetMinimapHidden(hidden)
  ns.db.minimap.hide = hidden and true or false
  ns.Notify("minimap")
end

function ns.ResetSettings()
  local angle = ns.db.minimap.angle
  wipe(ns.db)
  CopyDefaults(ns.DEFAULTS, ns.db)
  ns.db.minimap.angle = angle
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
  return GetSpecialization and GetSpecialization() or nil
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

function ns.Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|c" .. ns.ACCENT_HEX .. ns.TITLE .. "|r: " .. tostring(msg))
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
