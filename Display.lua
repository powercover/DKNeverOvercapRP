local addonName, ns = ...

-- The overlay is fully event driven. Nothing runs per frame except a short
-- fade OnUpdate that removes itself once the target opacity is reached, and
-- the motion/pulse animation groups, which only play while the aura is shown.

local POWER_TYPE = ns.POWER_TYPE
local FADE_IN_SPEED = 5
local FADE_OUT_SPEED = 3.5
local SNAP = 0.004
local EPSILON = 0.0001
-- Aura diameter as a share of the screen height at 100% size.
local AURA_SIZE = 0.55

local root, anchor, pulseGate, pulseAura, pulseEdge
local aura = {}
local edge, edgePulse
local motionAnims = {}
local pulseAnims = {}
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

local function NewTexture(parent, file, layer, sublevel, alpha)
  local tex = parent:CreateTexture(nil, layer, nil, sublevel)
  tex:SetTexture(ns.MEDIA .. file)
  tex:SetBlendMode("ADD")
  tex:SetAlpha(alpha or 1)
  return tex
end

local function Spin(tex, seconds, degrees)
  local group = tex:CreateAnimationGroup()
  group:SetLooping("REPEAT")
  local rotation = group:CreateAnimation("Rotation")
  rotation:SetDegrees(degrees)
  rotation:SetDuration(seconds)
  motionAnims[#motionAnims + 1] = group
end

local function Flicker(tex, from, to, seconds)
  local group = tex:CreateAnimationGroup()
  group:SetLooping("BOUNCE")
  local fade = group:CreateAnimation("Alpha")
  fade:SetFromAlpha(from)
  fade:SetToAlpha(to)
  fade:SetDuration(seconds)
  fade:SetSmoothing("IN_OUT")
  motionAnims[#motionAnims + 1] = group
end

local function PulseGroup(frame, scaleTo)
  local group = frame:CreateAnimationGroup()
  group:SetLooping("BOUNCE")
  local fade = group:CreateAnimation("Alpha")
  fade:SetFromAlpha(0)
  fade:SetToAlpha(1)
  fade:SetDuration(0.55)
  fade:SetSmoothing("IN_OUT")
  if scaleTo then
    local grow = group:CreateAnimation("Scale")
    grow:SetScaleFrom(1, 1)
    grow:SetScaleTo(scaleTo, scaleTo)
    grow:SetDuration(0.55)
    grow:SetSmoothing("IN_OUT")
  end
  pulseAnims[#pulseAnims + 1] = group
end

local function ShowsAura()
  return ns.db.style ~= "edge"
end

local function ShowsEdge()
  return ns.db.style ~= "aura"
end

local function StartAnimations()
  for _, group in ipairs(motionAnims) do
    if ns.db.motion then
      group:Play()
    else
      group:Stop()
    end
  end
  if state.pulsing then
    for _, group in ipairs(pulseAnims) do
      group:Play()
    end
  end
end

local function StopAnimations()
  for _, group in ipairs(motionAnims) do
    group:Stop()
  end
  for _, group in ipairs(pulseAnims) do
    group:Stop()
  end
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

  aura.glow = NewTexture(root, "glow", "BACKGROUND", 0, 0.55)
  aura.ring = NewTexture(root, "ring", "ARTWORK", 0, 0.9)
  aura.runes = NewTexture(root, "runes", "ARTWORK", 1, 0.75)
  aura.core = NewTexture(root, "ring_core", "OVERLAY", 0, 0.85)
  edge = NewTexture(root, "edge", "BACKGROUND", 1, 0.85)
  edge:SetAllPoints(root)

  Spin(aura.runes, 60, -360)
  Spin(aura.ring, 120, 360)
  Flicker(aura.core, 0.55, 0.95, 1.4)

  -- The gate carries the "near cap" opacity (0 or 1, possibly secret); the
  -- frames inside it carry the looping pulse animations.
  pulseGate = CreateFrame("Frame", nil, root)
  pulseGate:SetAllPoints(root)
  pulseGate:SetAlpha(0)

  pulseAura = CreateFrame("Frame", nil, pulseGate)
  pulseAura:SetPoint("CENTER", anchor)
  pulseAura:SetAlpha(0)
  aura.pulseRing = NewTexture(pulseAura, "ring", "ARTWORK")
  aura.pulseRing:SetAllPoints(pulseAura)
  aura.pulseGlow = NewTexture(pulseAura, "glow", "BACKGROUND", 0, 0.6)
  aura.pulseGlow:SetPoint("CENTER")
  PulseGroup(pulseAura, 1.08)

  pulseEdge = CreateFrame("Frame", nil, pulseGate)
  pulseEdge:SetAllPoints(root)
  pulseEdge:SetAlpha(0)
  edgePulse = NewTexture(pulseEdge, "edge", "BACKGROUND", 1, 0.7)
  edgePulse:SetAllPoints(pulseEdge)
  PulseGroup(pulseEdge)

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
  local height = root:GetHeight()
  if height <= 0 then
    height = 768
  end
  local size = height * AURA_SIZE * db.scale / 100

  anchor:ClearAllPoints()
  anchor:SetPoint("CENTER", root, "CENTER", 0, db.offsetY)
  anchor:SetSize(size, size)

  for _, tex in ipairs({ aura.ring, aura.runes, aura.core }) do
    tex:ClearAllPoints()
    tex:SetPoint("CENTER", anchor)
    tex:SetSize(size, size)
  end
  aura.glow:ClearAllPoints()
  aura.glow:SetPoint("CENTER", anchor)
  aura.glow:SetSize(size * 1.25, size * 1.25)

  pulseAura:SetSize(size, size)
  aura.pulseGlow:SetSize(size * 1.25, size * 1.25)
end

local function ApplyAppearance()
  local color = ns.GetActiveColor()
  local r, g, b = color.r, color.g, color.b
  -- The core line burns closer to white.
  local lr, lg, lb = r + (1 - r) * 0.55, g + (1 - g) * 0.55, b + (1 - b) * 0.55

  for key, tex in pairs(aura) do
    if key == "core" then
      tex:SetVertexColor(lr, lg, lb)
    else
      tex:SetVertexColor(r, g, b)
    end
  end
  edge:SetVertexColor(r, g, b)
  edgePulse:SetVertexColor(r, g, b)

  local showAura, showEdge = ShowsAura(), ShowsEdge()
  for key, tex in pairs(aura) do
    if key ~= "pulseRing" and key ~= "pulseGlow" then
      tex:SetShown(showAura)
    end
  end
  pulseAura:SetShown(showAura)
  edge:SetShown(showEdge)
  pulseEdge:SetShown(showEdge)
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

local function RefreshAppearance()
  ns.LayoutOverlay()
  ApplyAppearance()
  BuildCurves()
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
  for _, group in ipairs(pulseAnims) do
    if pulsing and root:IsShown() then
      group:Play()
    elseif not pulsing then
      group:Stop()
    end
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
    for _, group in ipairs(pulseAnims) do
      group:Play()
    end
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
  RefreshAppearance()
  state.preview = on
  Evaluate()
  ns.Notify("state")
end

events:SetScript("OnEvent", function(_, event, _, powerType)
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
  elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
    ApplyAppearance()
  end
  UpdateEngine()
  Evaluate()
end)

ns.OnChange(function(key)
  if key == "state" or not root then
    return
  end
  RefreshAppearance()
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
  RefreshAppearance()
  events:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
  events:RegisterEvent("PLAYER_ENTERING_WORLD")
  UpdateEngine()
  Evaluate()
end)
