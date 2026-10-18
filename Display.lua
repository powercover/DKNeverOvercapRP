local addonName, ns = ...

-- The overlay is fully event driven. Nothing runs per frame except a short
-- fade OnUpdate that removes itself once the target opacity is reached, and
-- the spin/pulse animation groups, which only play while the aura is shown.

local POWER_TYPE = ns.POWER_TYPE
local FADE_IN_SPEED = 5
local FADE_OUT_SPEED = 3.5
local SNAP = 0.004
local EPSILON = 0.0001

-- Aura composition around a centre anchor. Offsets are in unscaled pixels.
local PIECES = {
  { kind = "side", point = "RIGHT", rel = "LEFT", x = 6, y = 0 },
  { kind = "side", point = "LEFT", rel = "RIGHT", x = -6, y = 0, flipH = true },
  { kind = "corner", point = "BOTTOMRIGHT", rel = "TOPLEFT", x = 8, y = -8 },
  { kind = "corner", point = "BOTTOMLEFT", rel = "TOPRIGHT", x = -8, y = -8, flipH = true },
  { kind = "corner", point = "TOPRIGHT", rel = "BOTTOMLEFT", x = 8, y = 8, flipV = true },
  { kind = "corner", point = "TOPLEFT", rel = "BOTTOMRIGHT", x = -8, y = 8, flipH = true, flipV = true },
}

local SWIRLS = {
  { rel = "TOPLEFT", duration = 35, degrees = 360 },
  { rel = "BOTTOMRIGHT", duration = 31, degrees = -360 },
}

local root, anchor, pulseGate, pulseLayer, pulseAnim
local pieces = {}
local swirls = {}
local events = CreateFrame("Frame")

local state = {
  active = false,
  inCombat = false,
  preview = false,
  secret = false,
  pulsing = false,
  alpha = 0,
  target = 0,
}

local intensityCurve, pulseCurve

---------------------------------------------------------------------------
-- Frame construction
---------------------------------------------------------------------------

local function NewTexture(parent, layer, sublevel)
  local tex = parent:CreateTexture(nil, layer, nil, sublevel)
  tex:SetBlendMode("ADD")
  return tex
end

local function SetFlip(tex, flipH, flipV)
  local left, right, top, bottom = 0, 1, 0, 1
  if flipH then
    left, right = 1, 0
  end
  if flipV then
    top, bottom = 1, 0
  end
  tex:SetTexCoord(left, right, top, bottom)
end

local function StartAnimations()
  for _, swirl in ipairs(swirls) do
    swirl:SetShown(ns.db.spin)
    if ns.db.spin then
      swirl.anim:Play()
    else
      swirl.anim:Stop()
    end
  end
  if state.pulsing then
    pulseAnim:Play()
  end
end

local function StopAnimations()
  for _, swirl in ipairs(swirls) do
    swirl.anim:Stop()
  end
  pulseAnim:Stop()
end

local function EnsureUI()
  if root then
    return
  end

  root = CreateFrame("Frame", addonName .. "Overlay", UIParent)
  root:SetAllPoints(UIParent)
  root:SetFrameStrata("BACKGROUND")
  root:SetFrameLevel(5)
  root:EnableMouse(false)
  root:Hide()

  anchor = CreateFrame("Frame", nil, root)

  -- Gate carries the "near cap" opacity (0 or 1, possibly secret); the
  -- layer inside it carries the looping pulse animation.
  pulseGate = CreateFrame("Frame", nil, root)
  pulseGate:SetAllPoints(root)
  pulseGate:SetAlpha(0)
  pulseLayer = CreateFrame("Frame", nil, pulseGate)
  pulseLayer:SetAllPoints(pulseGate)
  pulseLayer:SetAlpha(0)

  pulseAnim = pulseLayer:CreateAnimationGroup()
  pulseAnim:SetLooping("BOUNCE")
  local fade = pulseAnim:CreateAnimation("Alpha")
  fade:SetFromAlpha(0)
  fade:SetToAlpha(0.9)
  fade:SetDuration(0.55)
  fade:SetSmoothing("IN_OUT")

  for i, info in ipairs(PIECES) do
    local layer = info.kind == "side" and "OVERLAY" or "ARTWORK"
    local base = NewTexture(root, layer)
    local glow = NewTexture(pulseLayer, layer)
    for _, tex in ipairs({ base, glow }) do
      SetFlip(tex, info.flipH, info.flipV)
    end
    pieces[i] = { info = info, base = base, glow = glow }
  end

  for i, info in ipairs(SWIRLS) do
    local tex = NewTexture(root, "ARTWORK", -1)
    tex:SetPoint("CENTER", anchor, info.rel, 0, 0)
    local anim = tex:CreateAnimationGroup()
    anim:SetLooping("REPEAT")
    local rotation = anim:CreateAnimation("Rotation")
    rotation:SetDegrees(info.degrees)
    rotation:SetDuration(info.duration)
    tex.anim = anim
    swirls[i] = tex
  end

  root:SetScript("OnShow", StartAnimations)
  root:SetScript("OnHide", StopAnimations)
  root:SetScript("OnSizeChanged", function()
    ns.LayoutOverlay()
  end)
end

---------------------------------------------------------------------------
-- Appearance
---------------------------------------------------------------------------

function ns.LayoutOverlay()
  if not root then
    return
  end
  local db = ns.db
  local scale = db.scale / 100
  local base = math.min(root:GetWidth(), root:GetHeight())
  if base <= 0 then
    base = 768
  end

  local center = math.max(96, base * 0.13) * scale
  local long = math.max(130, base * 0.18) * scale
  local short = long * 0.5
  local corner = long * 0.52
  local swirl = corner * 0.85

  anchor:ClearAllPoints()
  anchor:SetPoint("CENTER", root, "CENTER", 0, db.offsetY)
  anchor:SetSize(center, center)

  for _, piece in ipairs(pieces) do
    local info = piece.info
    for _, tex in ipairs({ piece.base, piece.glow }) do
      tex:ClearAllPoints()
      tex:SetPoint(info.point, anchor, info.rel, info.x * scale, info.y * scale)
      if info.kind == "side" then
        tex:SetSize(short, long)
      else
        tex:SetSize(corner, corner)
      end
    end
  end

  for _, tex in ipairs(swirls) do
    tex:SetSize(swirl, swirl)
  end
end

local function ApplyTextures()
  local db = ns.db
  local preset = ns.GetTexturePreset()
  local r, g, b = 1, 1, 1
  if db.useTint then
    r, g, b = db.tint.r, db.tint.g, db.tint.b
  end

  local function Paint(tex, file)
    tex:SetTexture(file)
    tex:SetDesaturated(db.useTint)
    tex:SetVertexColor(r, g, b)
  end

  for _, piece in ipairs(pieces) do
    local file = piece.info.kind == "side" and preset.side or preset.corner
    Paint(piece.base, file)
    Paint(piece.glow, file)
  end
  for _, tex in ipairs(swirls) do
    Paint(tex, preset.corner)
  end
end

-- Curves let the client map secret power values to opacity for us.
local function BuildCurves()
  intensityCurve, pulseCurve = nil, nil
  if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and UnitPowerPercent) then
    return
  end

  local db = ns.db
  local start = math.min(0.99, db.startPercent / 100)
  local maxAlpha = db.maxOpacity / 100
  local minAlpha = ns.START_ALPHA * maxAlpha

  local curve = C_CurveUtil.CreateColorCurve()
  if start > EPSILON then
    curve:AddPoint(0, CreateColor(1, 1, 1, 0))
    curve:AddPoint(start - EPSILON, CreateColor(1, 1, 1, 0))
  end
  curve:AddPoint(start, CreateColor(1, 1, 1, minAlpha))
  curve:AddPoint(1, CreateColor(1, 1, 1, maxAlpha))
  intensityCurve = curve

  if db.pulse then
    local at = math.min(0.999, db.pulsePercent / 100)
    local gate = C_CurveUtil.CreateColorCurve()
    gate:AddPoint(0, CreateColor(1, 1, 1, 0))
    gate:AddPoint(at - EPSILON, CreateColor(1, 1, 1, 0))
    gate:AddPoint(at, CreateColor(1, 1, 1, 1))
    gate:AddPoint(1, CreateColor(1, 1, 1, 1))
    pulseCurve = gate
  end
end

---------------------------------------------------------------------------
-- Opacity
---------------------------------------------------------------------------

local function IntensityFor(fraction)
  local db = ns.db
  local start = math.min(0.99, db.startPercent / 100)
  if fraction < start then
    return 0
  end
  local t = math.min(1, (fraction - start) / (1 - start))
  return (db.maxOpacity / 100) * (ns.START_ALPHA + (1 - ns.START_ALPHA) * t)
end

local function SetPulsing(pulsing)
  state.pulsing = pulsing
  pulseGate:SetAlpha(pulsing and 1 or 0)
  if pulsing and root:IsShown() then
    pulseAnim:Play()
  elseif not pulsing then
    pulseAnim:Stop()
  end
end

local function ApplyAlpha()
  if state.alpha <= 0 and state.target <= 0 then
    root:SetScript("OnUpdate", nil)
    root:Hide()
    return
  end
  root:SetAlpha(state.alpha)
  if not root:IsShown() then
    root:Show()
  end
end

local function OnFadeUpdate(self, elapsed)
  local speed = state.target > state.alpha and FADE_IN_SPEED or FADE_OUT_SPEED
  state.alpha = state.alpha + (state.target - state.alpha) * (1 - math.exp(-elapsed * speed))
  if math.abs(state.alpha - state.target) < SNAP then
    state.alpha = state.target
    self:SetScript("OnUpdate", nil)
  end
  ApplyAlpha()
end

local function SetTarget(target, pulsing)
  state.target = target
  if state.secret or not ns.db.smooth then
    -- Coming out of secret mode the shown opacity is unknown; snap.
    state.secret = false
    state.alpha = target
  end
  if math.abs(state.alpha - target) < SNAP then
    state.alpha = target
    root:SetScript("OnUpdate", nil)
  else
    root:SetScript("OnUpdate", OnFadeUpdate)
  end
  ApplyAlpha()
  SetPulsing(pulsing and target > 0)
end

local function HideNow()
  root:SetScript("OnUpdate", nil)
  state.alpha, state.target, state.secret = 0, 0, false
  SetPulsing(false)
  root:Hide()
end

local function CurveAlpha(curve)
  local ok, color = pcall(UnitPowerPercent, "player", POWER_TYPE, false, curve)
  if ok and color and color.GetRGBA then
    local _, _, _, a = color:GetRGBA()
    return a
  end
end

local function ApplySecret()
  local alpha = intensityCurve and CurveAlpha(intensityCurve)
  if alpha == nil then
    HideNow()
    return
  end
  root:SetScript("OnUpdate", nil)
  state.secret = true
  root:SetAlpha(alpha)
  root:Show()

  local gate = pulseCurve and CurveAlpha(pulseCurve)
  if gate ~= nil then
    state.pulsing = true
    pulseGate:SetAlpha(gate)
    pulseAnim:Play()
  else
    SetPulsing(false)
  end
end

local function Evaluate()
  if not root then
    return
  end
  if state.preview then
    root:SetScript("OnUpdate", nil)
    state.alpha, state.target, state.secret = ns.db.maxOpacity / 100, ns.db.maxOpacity / 100, false
    ApplyAlpha()
    SetPulsing(ns.db.pulse)
    return
  end
  if not state.active or (ns.db.combatOnly and not state.inCombat) then
    if state.alpha > 0 or root:IsShown() then
      SetTarget(0, false)
    end
    return
  end

  local current = UnitPower("player", POWER_TYPE)
  local max = UnitPowerMax("player", POWER_TYPE)
  if ns.IsReadable(current) and ns.IsReadable(max) then
    local fraction = max > 0 and current / max or 0
    SetTarget(IntensityFor(fraction), ns.db.pulse and fraction >= ns.db.pulsePercent / 100)
  else
    ApplySecret()
  end
end

---------------------------------------------------------------------------
-- Engine state
---------------------------------------------------------------------------

local function ShouldRun()
  local db = ns.db
  return ns.isDeathKnight and db.enabled and db.specs[ns.GetSpecIndex() or 0] == true
end

local function UpdateEngine()
  local run = ShouldRun() and true or false
  if run == state.active then
    return
  end
  state.active = run
  if run then
    events:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
    events:RegisterUnitEvent("UNIT_MAXPOWER", "player")
    events:RegisterEvent("PLAYER_REGEN_DISABLED")
    events:RegisterEvent("PLAYER_REGEN_ENABLED")
    state.inCombat = InCombatLockdown()
  else
    events:UnregisterEvent("UNIT_POWER_UPDATE")
    events:UnregisterEvent("UNIT_MAXPOWER")
    events:UnregisterEvent("PLAYER_REGEN_DISABLED")
    events:UnregisterEvent("PLAYER_REGEN_ENABLED")
  end
  ns.Notify("state")
end

function ns.IsOverlayActive()
  return state.active
end

function ns.IsPreviewing()
  return state.preview
end

function ns.SetPreview(on)
  on = on and true or false
  if on == state.preview then
    return
  end
  EnsureUI()
  ns.LayoutOverlay()
  ApplyTextures()
  BuildCurves()
  state.preview = on
  Evaluate()
  ns.Notify("state")
end

events:SetScript("OnEvent", function(_, event, unit, powerType)
  if event == "UNIT_POWER_UPDATE" then
    if powerType == ns.POWER_TOKEN then
      Evaluate()
    end
    return
  elseif event == "UNIT_MAXPOWER" then
    Evaluate()
    return
  elseif event == "PLAYER_REGEN_DISABLED" then
    state.inCombat = true
  elseif event == "PLAYER_REGEN_ENABLED" then
    state.inCombat = false
  elseif event == "PLAYER_ENTERING_WORLD" then
    state.inCombat = InCombatLockdown()
  end
  -- Spec change or loading screen.
  UpdateEngine()
  Evaluate()
end)

ns.OnChange(function(key)
  if key == "state" or key == "minimap" or not root then
    return
  end
  ns.LayoutOverlay()
  ApplyTextures()
  BuildCurves()
  if root:IsShown() then
    StartAnimations()
  end
  UpdateEngine()
  Evaluate()
end)

ns.OnLogin(function()
  -- Other classes never build the overlay or listen to power events.
  if not ns.isDeathKnight then
    return
  end
  EnsureUI()
  ns.LayoutOverlay()
  ApplyTextures()
  BuildCurves()
  events:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
  events:RegisterEvent("PLAYER_ENTERING_WORLD")
  UpdateEngine()
  Evaluate()
end)
