local addonName, ns = ...

-- The overlay is fully event driven. Nothing runs per frame except a short
-- eased fade that removes itself once the target opacity is reached, and
-- the motion/pulse animation groups, which only play while the aura is shown.

local POWER_TYPE = ns.POWER_TYPE
local FADE_IN_TIME = 0.5
local FADE_OUT_TIME = 0.8
local SNAP = 0.004
local EPSILON = 0.0001
-- Aura diameter as a share of the screen height at 100% size.
local AURA_SIZE = 0.55

-- Layers per pattern. size: relative to the aura; alpha: layer strength;
-- light: tinted toward white; spin: seconds per turn (negative = reverse);
-- flicker: gentle breathing; screen: stretched over the whole screen.
local LAYERS = {
  runes = {
    { file = "glow", size = 1.25, alpha = 0.30, layer = "BACKGROUND" },
    { file = "ring", alpha = 0.50, spin = 120 },
    { file = "runes", alpha = 0.40, spin = -60, sublevel = 1 },
    { file = "ring_core", alpha = 0.45, light = true, flicker = true, layer = "OVERLAY" },
  },
  halo = {
    { file = "glow", size = 1.3, alpha = 0.45, layer = "BACKGROUND" },
    { file = "ring_core", alpha = 0.40, light = true, flicker = true, layer = "OVERLAY" },
  },
  arcs = {
    { file = "glow", size = 1.25, alpha = 0.25, layer = "BACKGROUND" },
    { file = "arcs_inner", alpha = 0.60, spin = 45 },
    { file = "arcs_outer", alpha = 0.45, light = true, spin = -80, sublevel = 1 },
  },
  sigil = {
    { file = "glow", size = 1.25, alpha = 0.25, layer = "BACKGROUND" },
    { file = "sigil", alpha = 0.50, spin = -150 },
  },
  embers = {
    { file = "glow", size = 1.25, alpha = 0.25, layer = "BACKGROUND" },
    { file = "embers", alpha = 0.60, spin = 90 },
    { file = "embers", size = 0.8, alpha = 0.30, light = true, spin = -60, sublevel = 1 },
  },
  edge = {
    { file = "edge", alpha = 0.55, screen = true },
  },
  corners = {
    { file = "corners", alpha = 0.65, screen = true },
  },
}

local root, anchor, pulseGate, pulseAura, pulseAuraTex, pulseScreen, pulseScreenTex
local layerSets = {}
local active = {}
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
  from = 0,
  elapsed = 0,
  duration = 0,
}

local intensityCurve, pulseCurve

---------------------------------------------------------------------------
-- Frame construction
---------------------------------------------------------------------------

local function NewTexture(parent, file, layer, sublevel)
  local tex = parent:CreateTexture(nil, layer or "ARTWORK", nil, sublevel)
  tex:SetTexture(ns.MEDIA .. file)
  tex:SetBlendMode("ADD")
  return tex
end

local function AddSpin(tex, seconds)
  local group = tex:CreateAnimationGroup()
  group:SetLooping("REPEAT")
  local rotation = group:CreateAnimation("Rotation")
  rotation:SetDegrees(seconds > 0 and 360 or -360)
  rotation:SetDuration(math.abs(seconds))
  return group
end

local function AddFlicker(tex, alpha)
  local group = tex:CreateAnimationGroup()
  group:SetLooping("BOUNCE")
  local fade = group:CreateAnimation("Alpha")
  fade:SetFromAlpha(alpha * 0.75)
  fade:SetToAlpha(alpha)
  fade:SetDuration(2.4)
  fade:SetSmoothing("IN_OUT")
  return group
end

-- A slow breath rather than a blink.
local function AddPulse(frame, scaleTo)
  local group = frame:CreateAnimationGroup()
  group:SetLooping("BOUNCE")
  local fade = group:CreateAnimation("Alpha")
  fade:SetFromAlpha(0)
  fade:SetToAlpha(1)
  fade:SetDuration(1.2)
  fade:SetSmoothing("IN_OUT")
  if scaleTo then
    local grow = group:CreateAnimation("Scale")
    grow:SetScaleFrom(1, 1)
    grow:SetScaleTo(scaleTo, scaleTo)
    grow:SetDuration(1.2)
    grow:SetSmoothing("IN_OUT")
  end
  pulseAnims[#pulseAnims + 1] = group
end

-- Pattern textures are created the first time a pattern is used.
local function GetLayerSet(key)
  local set = layerSets[key]
  if set then
    return set
  end
  set = {}
  for i, def in ipairs(LAYERS[key]) do
    local tex = NewTexture(root, def.file, def.layer or (def.screen and "BACKGROUND") or "ARTWORK", def.sublevel)
    tex:SetAlpha(def.alpha)
    tex.def = def
    if def.screen then
      tex:SetAllPoints(root)
    else
      tex:SetPoint("CENTER", anchor)
    end
    if def.spin then
      tex.motion = AddSpin(tex, def.spin)
    elseif def.flicker then
      tex.motion = AddFlicker(tex, def.alpha)
    end
    tex:Hide()
    set[i] = tex
  end
  layerSets[key] = set
  return set
end

local function StopAnimations()
  for _, set in pairs(layerSets) do
    for _, tex in ipairs(set) do
      if tex.motion then
        tex.motion:Stop()
      end
    end
  end
  for _, group in ipairs(pulseAnims) do
    group:Stop()
  end
end

local function Run(group, on)
  if not on then
    group:Stop()
  elseif not group:IsPlaying() then
    group:Play()
  end
end

-- Leaves running animations alone so settings changes don't make them jump.
local function StartAnimations()
  local wanted = {}
  if ns.db.motion then
    for _, tex in ipairs(active) do
      if tex.motion then
        wanted[tex.motion] = true
      end
    end
  end
  for _, set in pairs(layerSets) do
    for _, tex in ipairs(set) do
      if tex.motion then
        Run(tex.motion, wanted[tex.motion])
      end
    end
  end
  for _, group in ipairs(pulseAnims) do
    Run(group, state.pulsing)
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

  -- The gate carries the "near cap" opacity (0 or 1, possibly secret); the
  -- frames inside it carry the looping pulse animations.
  pulseGate = CreateFrame("Frame", nil, root)
  pulseGate:SetAllPoints(root)
  pulseGate:SetAlpha(0)

  pulseAura = CreateFrame("Frame", nil, pulseGate)
  pulseAura:SetPoint("CENTER", anchor)
  pulseAura:SetAlpha(0)
  pulseAuraTex = NewTexture(pulseAura, "glow", "BACKGROUND")
  pulseAuraTex:SetAlpha(0.5)
  pulseAuraTex:SetAllPoints(pulseAura)
  AddPulse(pulseAura, 1.04)

  pulseScreen = CreateFrame("Frame", nil, pulseGate)
  pulseScreen:SetAllPoints(root)
  pulseScreen:SetAlpha(0)
  pulseScreenTex = NewTexture(pulseScreen, "edge", "BACKGROUND")
  pulseScreenTex:SetAlpha(0.5)
  pulseScreenTex:SetAllPoints(pulseScreen)
  AddPulse(pulseScreen)

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
  for _, set in pairs(layerSets) do
    for _, tex in ipairs(set) do
      if not tex.def.screen then
        local scale = tex.def.size or 1
        tex:SetSize(size * scale, size * scale)
      end
    end
  end
  pulseAura:SetSize(size * 1.3, size * 1.3)
end

local function ActivePatterns()
  local keys = { ns.db.pattern }
  if ns.db.edgeGlow and not ns.GetPattern(ns.db.pattern).screen then
    keys[2] = "edge"
  end
  return keys
end

local function ApplyAppearance()
  local color = ns.GetActiveColor()
  local r, g, b = color.r, color.g, color.b
  local lr, lg, lb = r + (1 - r) * 0.5, g + (1 - g) * 0.5, b + (1 - b) * 0.5

  wipe(active)
  local wanted = {}
  local hasAura, screenFile = false, nil
  for _, key in ipairs(ActivePatterns()) do
    for _, tex in ipairs(GetLayerSet(key)) do
      if tex.def.light then
        tex:SetVertexColor(lr, lg, lb)
      else
        tex:SetVertexColor(r, g, b)
      end
      wanted[tex] = true
      active[#active + 1] = tex
      if tex.def.screen then
        screenFile = tex.def.file
      else
        hasAura = true
      end
    end
  end

  for _, set in pairs(layerSets) do
    for _, tex in ipairs(set) do
      tex:SetShown(wanted[tex] == true)
    end
  end

  pulseAura:SetShown(hasAura)
  pulseAuraTex:SetVertexColor(lr, lg, lb)
  pulseScreen:SetShown(screenFile ~= nil)
  if screenFile then
    pulseScreenTex:SetTexture(ns.MEDIA .. screenFile)
  end
  pulseScreenTex:SetVertexColor(r, g, b)
  ns.LayoutOverlay()
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
  ApplyAppearance()
  BuildCurves()
  if root:IsShown() then
    StartAnimations()
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
  for _, group in ipairs(pulseAnims) do
    if pulsing and root:IsShown() then
      Run(group, true)
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

-- Eased (cosine in-out) tween from state.from to state.target.
local function OnFadeUpdate(self, elapsed)
  state.elapsed = state.elapsed + elapsed
  local progress = math.min(1, state.elapsed / state.duration)
  local eased = 0.5 - 0.5 * math.cos(math.pi * progress)
  state.alpha = state.from + (state.target - state.from) * eased
  if progress >= 1 then
    state.alpha = state.target
    self:SetScript("OnUpdate", nil)
  end
  ApplyAlpha()
end

local function SetTarget(target, pulsing)
  if state.secret or not ns.db.smooth then
    -- Coming out of secret mode the shown opacity is unknown; snap.
    state.secret = false
    state.alpha = target
  end
  local tweening = root:GetScript("OnUpdate") ~= nil
  if math.abs(state.alpha - target) < SNAP then
    state.alpha = target
    root:SetScript("OnUpdate", nil)
  elseif not tweening or target ~= state.target then
    -- Bigger jumps take a little longer, small nudges stay quick.
    local distance = math.abs(target - state.alpha)
    local base = target > state.alpha and FADE_IN_TIME or FADE_OUT_TIME
    state.from = state.alpha
    state.elapsed = 0
    state.duration = base * (0.6 + 0.4 * math.min(1, distance / 0.5))
    root:SetScript("OnUpdate", OnFadeUpdate)
  end
  state.target = target
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
      Run(group, true)
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
    SetTarget(ns.db.maxOpacity / 100, ns.db.pulse)
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
  if key == "state" or key == "minimap" or not root then
    return
  end
  RefreshAppearance()
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
