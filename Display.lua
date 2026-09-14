local addonName, ns = ...

local TEX = {
  bloodBoil = 511104,
  necropolis = 511105,
}

local overlay
local anchor
local driver
local displayAlpha = 0

local sampleElapsed = 0
local lastSoundAt = 0
local wasOverlayActive = false

local function PlayCapSound()
  if GetTime() - lastSoundAt < 1.5 then
    return
  end
  lastSoundAt = GetTime()
  if PlaySoundFile then
    PlaySoundFile(8959, "Master")
  end
end

local function CreateAlert(parent, textureID, layer, blend)
  local tex = parent:CreateTexture(nil, layer or "OVERLAY")
  tex:SetTexture(textureID)
  tex:SetBlendMode(blend or "ADD")
  tex:SetVertexColor(1, 1, 1)
  tex:SetAlpha(1)
  return tex
end

local function Flip(tex, hFlip, vFlip)
  local left, right, top, bottom = 0, 1, 0, 1
  if hFlip then
    left, right = 1, 0
  end
  if vFlip then
    top, bottom = 1, 0
  end
  tex:SetTexCoord(left, right, top, bottom)
end

local function ShouldShowOverlay()
  local db = ns.EnsureDB()
  return db.enabled and ns.IsBloodDeathKnight()
end

local function UpdateSound()
  local db = ns.EnsureDB()
  if not db.playSound or not ShouldShowOverlay() then
    wasOverlayActive = false
    return
  end

  local current, max = ns.GetRunicPower()
  local intensity = ns.GetAccessibleOverlayIntensity(current, max, db)
  if intensity == nil then
    return
  end

  local active = intensity > 0.02
  if active and not wasOverlayActive then
    PlayCapSound()
  end
  wasOverlayActive = active
end

local function LayoutOverlay()
  if not overlay or not anchor then
    return
  end

  local w = overlay:GetWidth() or 1920
  local h = overlay:GetHeight() or 1080
  local base = math.min(w, h)
  local center = math.max(96, base * 0.13)
  local longSide = math.max(130, base * 0.18)
  local shortSide = longSide * 0.50
  local corner = longSide * 0.52
  local swirl = corner * 0.85

  anchor:SetSize(center, center)

  if overlay.left then
    overlay.left:SetSize(shortSide, longSide)
  end
  if overlay.right then
    overlay.right:SetSize(shortSide, longSide)
  end

  for _, cornerTex in ipairs(overlay.corners or {}) do
    cornerTex:SetSize(corner, corner)
  end

  if overlay.swirlA then
    overlay.swirlA:SetSize(swirl, swirl)
  end
  if overlay.swirlB then
    overlay.swirlB:SetSize(swirl, swirl)
  end
end

local function SmoothToward(current, target, elapsed, speed)
  local t = 1 - math.exp(-elapsed * speed)
  if t > 1 then
    t = 1
  end
  return current + (target - current) * t
end

local function HideOverlay()
  displayAlpha = 0
  if overlay:IsShown() then
    overlay:Hide()
  end
end

local function ApplyOverlayVisual(elapsed)
  if not overlay then
    return
  end

  elapsed = elapsed or 0.016

  if not ShouldShowOverlay() then
    HideOverlay()
    return
  end

  local db = ns.EnsureDB()
  local current, max = ns.GetRunicPower()
  local intensity = ns.GetAccessibleOverlayIntensity(current, max, db)

  if intensity ~= nil then
    local speed = intensity > displayAlpha and 1.6 or 2.4
    displayAlpha = SmoothToward(displayAlpha, intensity, elapsed, speed)
    if math.abs(displayAlpha - intensity) < 0.004 then
      displayAlpha = intensity
    end

    if displayAlpha <= 0.01 and intensity <= 0 then
      HideOverlay()
      return
    end

    if not overlay:IsShown() then
      overlay:Show()
      LayoutOverlay()
    end
    overlay:SetAlpha(displayAlpha)
  else
    local glowColor = ns.GetOverlayColor(db, 1)
    local _, _, _, glowA = glowColor:GetRGBA()
    if not overlay:IsShown() then
      overlay:Show()
      LayoutOverlay()
    end
    overlay:SetAlpha(glowA)
  end

  local swirl = GetTime() * 0.18
  if overlay.swirlA then
    overlay.swirlA:SetRotation(swirl)
  end
  if overlay.swirlB then
    overlay.swirlB:SetRotation(-swirl * 1.12)
  end
end

local function OnDriverUpdate(_, elapsed)
  sampleElapsed = sampleElapsed + elapsed
  if sampleElapsed >= 0.05 then
    sampleElapsed = 0
    UpdateSound()
  end
  ApplyOverlayVisual(elapsed)
end

local function CreateOverlayUI()
  overlay = CreateFrame("Frame", addonName .. "Overlay", UIParent)
  overlay:SetAllPoints(UIParent)
  overlay:SetFrameStrata("FULLSCREEN")
  overlay:SetFrameLevel(1)
  overlay:EnableMouse(false)
  overlay:Hide()
  overlay.corners = {}

  anchor = CreateFrame("Frame", nil, overlay)
  anchor:SetPoint("CENTER", overlay, "CENTER", 0, -20)

  overlay.left = CreateAlert(overlay, TEX.bloodBoil, "OVERLAY")
  overlay.left:SetPoint("RIGHT", anchor, "LEFT", 6, 0)

  overlay.right = CreateAlert(overlay, TEX.bloodBoil, "OVERLAY")
  overlay.right:SetPoint("LEFT", anchor, "RIGHT", -6, 0)
  Flip(overlay.right, true, false)

  local cornerPoints = {
    { "BOTTOMRIGHT", "TOPLEFT", false, false, 8, -8 },
    { "BOTTOMLEFT", "TOPRIGHT", true, false, -8, -8 },
    { "TOPRIGHT", "BOTTOMLEFT", false, true, 8, 8 },
    { "TOPLEFT", "BOTTOMRIGHT", true, true, -8, 8 },
  }
  for _, info in ipairs(cornerPoints) do
    local tex = CreateAlert(overlay, TEX.necropolis, "ARTWORK")
    tex:SetPoint(info[1], anchor, info[2], info[5], info[6])
    Flip(tex, info[3], info[4])
    overlay.corners[#overlay.corners + 1] = tex
  end

  overlay.swirlA = CreateAlert(overlay, TEX.necropolis, "ARTWORK", "ADD")
  overlay.swirlA:SetPoint("CENTER", anchor, "TOPLEFT", 0, 0)

  overlay.swirlB = CreateAlert(overlay, TEX.necropolis, "ARTWORK", "ADD")
  overlay.swirlB:SetPoint("CENTER", anchor, "BOTTOMRIGHT", 0, 0)

  overlay:SetScript("OnSizeChanged", LayoutOverlay)
  LayoutOverlay()
  ns.ApplyOverlayTextures()
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
loader:RegisterEvent("UNIT_POWER_UPDATE")
loader:SetScript("OnEvent", function(_, event, unit)
  if event == "PLAYER_LOGIN" then
    CreateOverlayUI()
    driver = CreateFrame("Frame")
    driver:SetScript("OnUpdate", OnDriverUpdate)
    UpdateSound()
    ApplyOverlayVisual(0.016)
    return
  end
  if event == "UNIT_POWER_UPDATE" and unit ~= "player" then
    return
  end
  UpdateSound()
  ApplyOverlayVisual(0.016)
end)

ns.RefreshDisplay = function()
  UpdateSound()
  ApplyOverlayVisual(0.016)
end

function ns.ApplyOverlayTextures()
  if not overlay then
    return
  end
  local preset = ns.GetTexturePreset()
  if overlay.left then
    overlay.left:SetTexture(preset.side)
  end
  if overlay.right then
    overlay.right:SetTexture(preset.side)
  end
  for _, cornerTex in ipairs(overlay.corners or {}) do
    cornerTex:SetTexture(preset.corner)
  end
  if overlay.swirlA then
    overlay.swirlA:SetTexture(preset.corner)
  end
  if overlay.swirlB then
    overlay.swirlB:SetTexture(preset.corner)
  end
end

ns.GetDisplayFrame = function()
  return overlay
end
