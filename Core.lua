local addonName, ns = ...

ns.ADDON_NAME = addonName
ns.VERSION = C_AddOns.GetAddOnMetadata(addonName, "Version") or "1.0.0"

ns.BLOOD_SPEC_INDEX = 1
ns.POWER_TYPE = Enum.PowerType.RunicPower

ns.START_ALPHA = 0.1

ns.DEFAULTS = {
  enabled = true,
  overlayAtPercent = 85,
  textureKey = "mixed",
  minimapAngle = 210,
  warnAt = 80,
  criticalAt = 90,
  powerMaxFallback = 125,
  playSound = true,
  settingsRev = 1,
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

function ns.GetTexturePreset(key)
  key = key or ns.EnsureDB().textureKey
  for _, preset in ipairs(ns.TEXTURE_PRESETS) do
    if preset.key == key then
      return preset
    end
  end
  return ns.TEXTURE_PRESETS[1]
end

local overlayCurveCache = {}

function ns.IsBloodDeathKnight()
  local _, class = UnitClass("player")
  if class ~= "DEATHKNIGHT" then
    return false
  end
  local spec = GetSpecialization and GetSpecialization()
  return spec == ns.BLOOD_SPEC_INDEX
end

function ns.CanAccessPowerNumber(value)
  if value == nil then
    return false
  end
  if type(canaccessvalue) == "function" then
    local ok, accessible = pcall(canaccessvalue, value)
    return ok and accessible == true
  end
  if type(issecretvalue) == "function" then
    local ok, secret = pcall(issecretvalue, value)
    return ok and secret == false
  end
  return true
end

function ns.GetRunicPower()
  if not UnitExists("player") then
    return 0, ns.EnsureDB().powerMaxFallback
  end
  local current = UnitPower("player", ns.POWER_TYPE)
  local max = UnitPowerMax("player", ns.POWER_TYPE)
  return current, max or ns.EnsureDB().powerMaxFallback
end

function ns.GetPowerMaxFallback(max)
  if ns.CanAccessPowerNumber(max) and max > 0 then
    return max
  end
  return ns.EnsureDB().powerMaxFallback
end

function ns.GetOverlayStartFraction(db)
  db = db or ns.EnsureDB()
  local percent = ns.DEFAULTS.overlayAtPercent
  if db.overlayAtPercent ~= nil then
    percent = db.overlayAtPercent
  end
  return math.min(0.99, math.max(0, percent / 100))
end

function ns.SetOverlayAtPercent(percent)
  local db = ns.EnsureDB()
  local value = math.min(100, math.max(0, math.floor(percent + 0.5)))
  db.overlayAtPercent = value
  if ns.RefreshDisplay then
    ns.RefreshDisplay()
  end
  return db.overlayAtPercent
end

function ns.SetTextureKey(key)
  local preset = ns.GetTexturePreset(key)
  ns.EnsureDB().textureKey = preset.key
  if ns.ApplyOverlayTextures then
    ns.ApplyOverlayTextures()
  end
  if ns.RefreshOptions then
    ns.RefreshOptions()
  end
end

function ns.GetOverlayCurve(db, maxAlpha)
  if not C_CurveUtil or not C_CurveUtil.CreateColorCurve then
    return nil
  end

  db = db or ns.EnsureDB()
  maxAlpha = maxAlpha or 1
  local startFrac = ns.GetOverlayStartFraction(db)
  local cacheKey = string.format("%.4f:%.3f", startFrac, maxAlpha)
  local cached = overlayCurveCache[cacheKey]
  if cached then
    return cached
  end

  local epsilon = 0.0001
  local span = math.max(0.01, 1 - startFrac)
  local startAlpha = (ns.START_ALPHA or 0.1) * maxAlpha
  local curve = C_CurveUtil.CreateColorCurve()
  curve:AddPoint(0.0, CreateColor(0.72, 0.0, 0.0, 0))
  curve:AddPoint(math.max(0.0, startFrac - epsilon), CreateColor(0.72, 0.0, 0.0, 0))
  curve:AddPoint(startFrac, CreateColor(0.72, 0.0, 0.0, startAlpha))
  curve:AddPoint(startFrac + span * 0.50, CreateColor(0.80, 0.01, 0.0, startAlpha + (maxAlpha - startAlpha) * 0.50))
  curve:AddPoint(1.0, CreateColor(0.88, 0.02, 0.0, maxAlpha))

  overlayCurveCache[cacheKey] = curve
  return curve
end

function ns.GetOverlayColor(db, maxAlpha)
  local curve = ns.GetOverlayCurve(db, maxAlpha)
  if curve and UnitPowerPercent then
    local ok, color = pcall(UnitPowerPercent, "player", ns.POWER_TYPE, false, curve)
    if ok and color and color.GetRGBA then
      return color
    end
  end
  return CreateColor(0.72, 0.0, 0.0, 0)
end

function ns.GetAccessibleOverlayIntensity(current, max, db)
  if not ns.CanAccessPowerNumber(current) then
    return nil
  end

  db = db or ns.EnsureDB()
  local maxDisplay = ns.GetPowerMaxFallback(max)
  if not ns.CanAccessPowerNumber(maxDisplay) or maxDisplay <= 0 then
    return nil
  end

  local startFrac = ns.GetOverlayStartFraction(db)
  local frac = current / maxDisplay
  if not ns.CanAccessPowerNumber(frac) then
    return nil
  end
  if frac < startFrac then
    return 0
  end
  local t = (frac - startFrac) / math.max(0.01, 1 - startFrac)
  t = math.min(1, math.max(0, t))
  local startAlpha = ns.START_ALPHA or 0.1
  return startAlpha + (1 - startAlpha) * t
end

function ns.EnsureDB()
  if type(_G.BDKNORP_DB) ~= "table" then
    _G.BDKNORP_DB = {}
  end
  local db = _G.BDKNORP_DB
  for key, value in pairs(ns.DEFAULTS) do
    if db[key] == nil then
      db[key] = value
    end
  end
  if (db.settingsRev or 0) < 1 then
    if db.overlayAtPercent == 90 then
      db.overlayAtPercent = ns.DEFAULTS.overlayAtPercent
    end
    db.settingsRev = 1
  end
  ns.db = db
  return db
end

function ns.Print(msg)
  local text = "|cffC41E3A" .. addonName .. "|r: " .. tostring(msg)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage(text)
  else
    print(text)
  end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, _, name)
  if name == addonName then
    ns.EnsureDB()
  end
end)
