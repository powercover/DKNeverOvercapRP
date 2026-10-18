local addonName, ns = ...

-- Settings page under Options > AddOns. Every control is drawn from plain
-- textures (no Blizzard widget templates) for a flat, modern look.

local WHITE = "Interface\\Buttons\\WHITE8X8"
local CIRCLE = ns.MEDIA .. "circle"
local HEADER_HEIGHT = 92
local GAP = 12

local THEME = {
  card = { 0.075, 0.075, 0.09, 0.94 },
  inset = { 0.14, 0.14, 0.17, 1 },
  hover = { 1, 1, 1, 0.045 },
  off = { 0.26, 0.26, 0.30, 1 },
  text = { 0.95, 0.95, 0.97 },
  muted = { 0.58, 0.59, 0.65 },
}

local panel, content
local controls = {}

local function Accent()
  local color = ns.GetActiveColor()
  return color.r, color.g, color.b
end

local function Track(control)
  controls[#controls + 1] = control
  return control
end

---------------------------------------------------------------------------
-- Primitives
---------------------------------------------------------------------------

local function MakeFont(name, size)
  local font = CreateFont(addonName .. name)
  font:SetFont(STANDARD_TEXT_FONT, size, "")
  font:SetShadowColor(0, 0, 0, 0.6)
  font:SetShadowOffset(1, -1)
  return font
end

local FONT = {
  title = MakeFont("FontTitle", 22),
  body = MakeFont("FontBody", 13),
  small = MakeFont("FontSmall", 11),
}

local function Text(parent, font, color)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFontObject(font)
  fs:SetTextColor(color[1], color[2], color[3])
  fs:SetJustifyH("LEFT")
  return fs
end

local function Circle(parent, size, layer, sublevel)
  local tex = parent:CreateTexture(nil, layer or "ARTWORK", nil, sublevel)
  tex:SetTexture(CIRCLE)
  tex:SetSize(size, size)
  return tex
end

-- Rounded rectangle: four quarter-circle corners plus three strips, all
-- drawn on `owner` and stretched over `region` (owner by default).
local Rounded = {}
Rounded.__index = Rounded

local CORNERS = {
  TOPLEFT = { 0, 0.5, 0, 0.5 },
  TOPRIGHT = { 0.5, 1, 0, 0.5 },
  BOTTOMLEFT = { 0, 0.5, 0.5, 1 },
  BOTTOMRIGHT = { 0.5, 1, 0.5, 1 },
}

local function NewRounded(owner, radius, layer, sublevel, region)
  region = region or owner
  local self = setmetatable({ parts = {} }, Rounded)
  local function Part(file)
    local tex = owner:CreateTexture(nil, layer, nil, sublevel)
    tex:SetTexture(file)
    self.parts[#self.parts + 1] = tex
    return tex
  end
  for point, coords in pairs(CORNERS) do
    local corner = Part(CIRCLE)
    corner:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    corner:SetSize(radius, radius)
    corner:SetPoint(point, region, point)
  end
  local middle = Part(WHITE)
  middle:SetPoint("TOPLEFT", region, "TOPLEFT", radius, 0)
  middle:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", -radius, 0)
  local left = Part(WHITE)
  left:SetPoint("TOPLEFT", region, "TOPLEFT", 0, -radius)
  left:SetPoint("BOTTOMRIGHT", region, "BOTTOMLEFT", radius, radius)
  local right = Part(WHITE)
  right:SetPoint("TOPLEFT", region, "TOPRIGHT", -radius, -radius)
  right:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", 0, radius)
  return self
end

function Rounded:SetColor(r, g, b, a)
  for _, tex in ipairs(self.parts) do
    tex:SetVertexColor(r, g, b, a or 1)
  end
end

function Rounded:SetShown(shown)
  for _, tex in ipairs(self.parts) do
    tex:SetShown(shown)
  end
end

local function ShowTooltip(owner, title, body)
  if not body then
    return
  end
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:SetText(title, 1, 1, 1)
  GameTooltip:AddLine(body, nil, nil, nil, true)
  GameTooltip:Show()
end

local function PlayToggleSound(on)
  PlaySound(on and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
end

---------------------------------------------------------------------------
-- Controls
---------------------------------------------------------------------------

local function CreateSwitch(parent)
  local switch = CreateFrame("Frame", nil, parent)
  switch:SetSize(36, 20)
  local track = NewRounded(switch, 10, "ARTWORK")
  local knob = Circle(switch, 14, "OVERLAY")
  function switch.SetOn(_, on)
    knob:ClearAllPoints()
    if on then
      knob:SetPoint("RIGHT", -3, 0)
      track:SetColor(Accent())
    else
      knob:SetPoint("LEFT", 3, 0)
      track:SetColor(unpack(THEME.off))
    end
  end
  return switch
end

local function PillButton(parent, label, width, primary)
  local button = CreateFrame("Button", nil, parent)
  button:SetSize(width, 28)
  local bg = NewRounded(button, 14, "BACKGROUND")
  local text = Text(button, FONT.body, THEME.text)
  text:SetPoint("CENTER")
  text:SetText(label)
  button.text = text

  local function Paint()
    local hover = button:IsMouseOver()
    if primary then
      local r, g, b = Accent()
      local k = hover and 1.2 or 1
      bg:SetColor(math.min(1, r * k), math.min(1, g * k), math.min(1, b * k), 0.9)
    else
      bg:SetColor(1, 1, 1, hover and 0.14 or 0.08)
    end
  end
  button:SetScript("OnEnter", Paint)
  button:SetScript("OnLeave", Paint)
  button.Refresh = Paint
  return Track(button)
end

local function OpenColorPicker(color, apply)
  ColorPickerFrame:SetupColorPickerAndShow({
    r = color.r,
    g = color.g,
    b = color.b,
    hasOpacity = false,
    swatchFunc = function()
      apply(ColorPickerFrame:GetColorRGB())
    end,
    cancelFunc = function(previous)
      apply(previous.r, previous.g, previous.b)
    end,
  })
end

---------------------------------------------------------------------------
-- Cards and rows
---------------------------------------------------------------------------

local Card = {}
Card.__index = Card

local function NewCard(title)
  local frame = CreateFrame("Frame", nil, content)
  NewRounded(frame, 12, "BACKGROUND", -1):SetColor(unpack(THEME.card))
  local label = Text(frame, FONT.small, THEME.muted)
  label:SetPoint("TOPLEFT", 18, -16)
  label:SetText(title:upper())
  return setmetatable({ frame = frame, y = -36 }, Card)
end

function Card:Finish()
  self.frame:SetHeight(-self.y + 10)
  return self
end

-- Clickable rows get a hover highlight; rows that host their own
-- interactive widget (sliders, segmented bars) only show a tooltip.
function Card:Row(height, label, tooltip, clickable)
  local row = CreateFrame(clickable and "Button" or "Frame", nil, self.frame)
  row:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 8, self.y)
  row:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -8, self.y)
  row:SetHeight(height)
  row:EnableMouse(true)
  self.y = self.y - height

  local hover
  if clickable then
    hover = NewRounded(row, 8, "BACKGROUND")
    hover:SetColor(unpack(THEME.hover))
    hover:SetShown(false)
  end
  row:SetScript("OnEnter", function()
    if hover then
      hover:SetShown(true)
    end
    ShowTooltip(row, label, tooltip)
  end)
  row:SetScript("OnLeave", function()
    if hover then
      hover:SetShown(false)
    end
    GameTooltip:Hide()
  end)
  return row
end

function Card:Toggle(label, tooltip, get, set)
  local row = self:Row(36, label, tooltip, true)
  local text = Text(row, FONT.body, THEME.text)
  text:SetPoint("LEFT", 10, 0)
  text:SetText(label)
  local switch = CreateSwitch(row)
  switch:SetPoint("RIGHT", -10, 0)
  row:SetScript("OnClick", function()
    local on = not get()
    PlayToggleSound(on)
    set(on)
  end)
  row.Refresh = function()
    switch:SetOn(get())
  end
  return Track(row)
end

function Card:Setting(label, tooltip, key)
  return self:Toggle(label, tooltip, function()
    return ns.db[key]
  end, function(value)
    ns.Set(key, value)
  end)
end

function Card:Slider(label, tooltip, key, format, isEnabled)
  local limit = ns.LIMITS[key]
  local row = self:Row(54, label, tooltip, false)

  local text = Text(row, FONT.body, THEME.text)
  text:SetPoint("TOPLEFT", 10, -9)
  text:SetText(label)
  local value = Text(row, FONT.body, THEME.text)
  value:SetPoint("TOPRIGHT", -10, -9)
  value:SetJustifyH("RIGHT")

  local slider = CreateFrame("Slider", nil, row)
  slider:SetPoint("BOTTOMLEFT", 10, 8)
  slider:SetPoint("BOTTOMRIGHT", -10, 8)
  slider:SetHeight(16)
  slider:SetOrientation("HORIZONTAL")
  slider:SetMinMaxValues(limit[1], limit[2])
  slider:SetValueStep(limit[3])
  slider:SetObeyStepOnDrag(true)
  slider:EnableMouse(true)

  local trackRegion = slider:CreateTexture(nil, "BACKGROUND")
  trackRegion:SetPoint("LEFT")
  trackRegion:SetPoint("RIGHT")
  trackRegion:SetHeight(4)
  NewRounded(slider, 2, "BACKGROUND", 1, trackRegion):SetColor(unpack(THEME.off))

  local thumb = Circle(slider, 14, "OVERLAY")
  slider:SetThumbTexture(thumb)

  local fillRegion = slider:CreateTexture(nil, "ARTWORK")
  fillRegion:SetPoint("LEFT", trackRegion)
  fillRegion:SetHeight(4)
  local fill = NewRounded(slider, 2, "ARTWORK", 1, fillRegion)

  -- The thumb travels between half its width from either end.
  local function UpdateFill()
    local width = slider:GetWidth() or 0
    local t = (slider:GetValue() - limit[1]) / (limit[2] - limit[1])
    fillRegion:SetWidth(math.max(4, 7 + t * (width - 14)))
  end

  slider:SetScript("OnValueChanged", function(_, v)
    value:SetText(format(v))
    UpdateFill()
    if not slider.suppress then
      ns.Set(key, v)
    end
  end)
  slider:SetScript("OnSizeChanged", UpdateFill)
  slider:SetScript("OnEnter", function()
    ShowTooltip(slider, label, tooltip)
  end)
  slider:SetScript("OnLeave", GameTooltip_Hide)

  row.slider = slider
  row.Refresh = function()
    slider.suppress = true
    slider:SetValue(ns.db[key])
    slider.suppress = false
    value:SetText(format(ns.db[key]))
    local r, g, b = Accent()
    fill:SetColor(r, g, b)
    value:SetTextColor(r, g, b)
    local enabled = not isEnabled or isEnabled()
    if enabled then
      slider:Enable()
    else
      slider:Disable()
    end
    row:SetAlpha(enabled and 1 or 0.4)
  end
  return Track(row)
end

function Card:Segmented(label, tooltip, options, get, set)
  local row = self:Row(64, label, tooltip, false)
  local text = Text(row, FONT.body, THEME.text)
  text:SetPoint("TOPLEFT", 10, -9)
  text:SetText(label)

  local bar = CreateFrame("Frame", nil, row)
  bar:SetPoint("BOTTOMLEFT", 10, 8)
  bar:SetPoint("BOTTOMRIGHT", -10, 8)
  bar:SetHeight(30)
  NewRounded(bar, 9, "BACKGROUND"):SetColor(unpack(THEME.inset))

  local buttons = {}
  for i, option in ipairs(options) do
    local button = CreateFrame("Button", nil, bar)
    button:SetHeight(24)
    button.bg = NewRounded(button, 7, "ARTWORK")
    button.text = Text(button, FONT.body, THEME.muted)
    button.text:SetPoint("CENTER")
    button.text:SetText(option.name)
    button:SetScript("OnClick", function()
      PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
      set(option.key)
    end)
    button:SetScript("OnEnter", function()
      if get() ~= option.key then
        button.text:SetTextColor(unpack(THEME.text))
      end
      ShowTooltip(button, label, tooltip)
    end)
    button:SetScript("OnLeave", function()
      row.Refresh()
      GameTooltip:Hide()
    end)
    buttons[i] = button
  end

  local function Layout(width)
    if not width or width <= 0 then
      return
    end
    local each = (width - 6) / #buttons
    for i, button in ipairs(buttons) do
      button:ClearAllPoints()
      button:SetWidth(each)
      button:SetPoint("LEFT", bar, "LEFT", 3 + (i - 1) * each, 0)
    end
  end
  bar:SetScript("OnSizeChanged", function(_, width)
    Layout(width)
  end)

  row.Refresh = function()
    Layout(bar:GetWidth())
    local r, g, b = Accent()
    for i, button in ipairs(buttons) do
      local selected = get() == options[i].key
      button.bg:SetShown(selected)
      button.bg:SetColor(r, g, b, 0.85)
      if selected then
        button.text:SetTextColor(1, 1, 1)
      else
        button.text:SetTextColor(unpack(THEME.muted))
      end
    end
  end
  return Track(row)
end

function Card:Spec(specIndex)
  local name, icon = ns.GetSpecInfo(specIndex)
  local row = self:Row(42, name, "Show the overlay while you are in " .. name .. ". Click the dot to pick this spec's color.", true)

  local iconTex = row:CreateTexture(nil, "ARTWORK")
  iconTex:SetSize(24, 24)
  iconTex:SetPoint("LEFT", 10, 0)
  if icon then
    iconTex:SetTexture(icon)
  end
  local mask = row:CreateMaskTexture()
  mask:SetTexture(CIRCLE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  mask:SetAllPoints(iconTex)
  iconTex:AddMaskTexture(mask)

  local text = Text(row, FONT.body, THEME.text)
  text:SetPoint("LEFT", iconTex, "RIGHT", 10, 0)
  text:SetText(name)

  local switch = CreateSwitch(row)
  switch:SetPoint("RIGHT", -10, 0)

  local swatch = CreateFrame("Button", nil, row)
  swatch:SetSize(22, 22)
  swatch:SetPoint("RIGHT", switch, "LEFT", -14, 0)
  local ring = Circle(swatch, 22, "ARTWORK")
  ring:SetPoint("CENTER")
  local dot = Circle(swatch, 16, "OVERLAY")
  dot:SetPoint("CENTER")
  swatch:SetScript("OnClick", function()
    OpenColorPicker(ns.db.colors[specIndex], function(r, g, b)
      ns.SetSpecColor(specIndex, r, g, b)
    end)
  end)
  swatch:SetScript("OnEnter", function()
    ring:SetVertexColor(1, 1, 1, 0.6)
    ShowTooltip(swatch, name .. " color", "Click to change the color used in " .. name .. ".")
  end)
  swatch:SetScript("OnLeave", function()
    ring:SetVertexColor(1, 1, 1, 0.18)
    GameTooltip:Hide()
  end)

  row:SetScript("OnClick", function()
    local on = not ns.db.specs[specIndex]
    PlayToggleSound(on)
    ns.SetSpecTracked(specIndex, on)
  end)
  row.Refresh = function()
    local color = ns.db.colors[specIndex]
    dot:SetVertexColor(color.r, color.g, color.b)
    ring:SetVertexColor(1, 1, 1, swatch:IsMouseOver() and 0.6 or 0.18)
    local on = ns.db.specs[specIndex]
    switch:SetOn(on)
    iconTex:SetDesaturated(not on)
    text:SetTextColor(unpack(on and THEME.text or THEME.muted))
  end
  return Track(row)
end

---------------------------------------------------------------------------
-- Page
---------------------------------------------------------------------------

local function Percent(value)
  return string.format("%d%%", math.floor(value + 0.5))
end

local function Pixels(value)
  return string.format("%+d px", math.floor(value + 0.5))
end

function ns.GetStatus()
  if ns.IsPreviewing() then
    return "Previewing", 0.35, 0.7, 1
  end
  if not ns.isDeathKnight then
    return "Inactive · not a Death Knight", 0.55, 0.55, 0.6
  end
  if not ns.db.enabled then
    return "Disabled", 1, 0.38, 0.38
  end
  local spec = ns.GetSpecIndex()
  local specName = spec and ns.GetSpecInfo(spec) or "No spec"
  if ns.IsOverlayActive() then
    return "Active · " .. specName, 0.3, 0.9, 0.45
  end
  return "Paused · " .. specName .. " is off", 1, 0.75, 0.25
end

local function BuildHeader()
  local logo = CreateFrame("Frame", nil, content)
  logo:SetSize(56, 56)
  logo:SetPoint("TOPLEFT", 16, -16)
  local glow = logo:CreateTexture(nil, "BACKGROUND")
  glow:SetTexture(ns.MEDIA .. "glow")
  glow:SetBlendMode("ADD")
  glow:SetPoint("CENTER")
  glow:SetSize(72, 72)
  local runes = logo:CreateTexture(nil, "ARTWORK")
  runes:SetTexture(ns.MEDIA .. "runes")
  runes:SetBlendMode("ADD")
  runes:SetAllPoints()
  local core = logo:CreateTexture(nil, "OVERLAY")
  core:SetTexture(ns.MEDIA .. "ring_core")
  core:SetBlendMode("ADD")
  core:SetAllPoints()

  local spin = runes:CreateAnimationGroup()
  spin:SetLooping("REPEAT")
  local rotation = spin:CreateAnimation("Rotation")
  rotation:SetDegrees(-360)
  rotation:SetDuration(30)
  logo.spin = spin

  local title = Text(content, FONT.title, THEME.text)
  title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 14, -4)
  title:SetText(ns.TITLE)

  local status = CreateFrame("Frame", nil, content)
  status:SetHeight(22)
  status:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  NewRounded(status, 11, "BACKGROUND"):SetColor(1, 1, 1, 0.06)
  local dot = Circle(status, 8, "ARTWORK")
  dot:SetPoint("LEFT", 10, 0)
  local statusText = Text(status, FONT.small, THEME.text)
  statusText:SetPoint("LEFT", dot, "RIGHT", 7, 0)

  local version = Text(content, FONT.small, THEME.muted)
  version:SetPoint("LEFT", status, "RIGHT", 10, 0)
  version:SetText("v" .. ns.VERSION)

  local preview = PillButton(content, "Preview", 116, true)
  preview:SetPoint("TOPRIGHT", -16, -24)
  preview:SetScript("OnClick", function()
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    ns.SetPreview(not ns.IsPreviewing())
  end)

  local reset = PillButton(content, "Reset", 84, false)
  reset:SetPoint("RIGHT", preview, "LEFT", -8, 0)
  reset:SetScript("OnClick", function()
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    ns.ResetSettings()
  end)

  Track({
    Refresh = function()
      local r, g, b = Accent()
      glow:SetVertexColor(r, g, b, 0.7)
      runes:SetVertexColor(r, g, b)
      core:SetVertexColor(r + (1 - r) * 0.55, g + (1 - g) * 0.55, b + (1 - b) * 0.55)
      local label, sr, sg, sb = ns.GetStatus()
      dot:SetVertexColor(sr, sg, sb)
      statusText:SetText(label)
      status:SetWidth(statusText:GetStringWidth() + 36)
      preview.text:SetText(ns.IsPreviewing() and "Stop preview" or "Preview")
    end,
  })
  return logo
end

local function StackCards(cards, left)
  local previous
  local height = 0
  for _, card in ipairs(cards) do
    local frame = card.frame
    if previous then
      frame:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -GAP)
      frame:SetPoint("TOPRIGHT", previous, "BOTTOMRIGHT", 0, -GAP)
      height = height + GAP
    elseif left then
      frame:SetPoint("TOPLEFT", content, "TOPLEFT", 16, -HEADER_HEIGHT)
      frame:SetPoint("TOPRIGHT", content, "TOP", -GAP / 2, -HEADER_HEIGHT)
    else
      frame:SetPoint("TOPLEFT", content, "TOP", GAP / 2, -HEADER_HEIGHT)
      frame:SetPoint("TOPRIGHT", content, "TOPRIGHT", -16, -HEADER_HEIGHT)
    end
    height = height + frame:GetHeight()
    previous = frame
  end
  return height
end

local function BuildCards()
  local general = NewCard("General")
  general:Setting("Enable overlay", "Master switch for the aura.", "enabled")
  general:Setting("Only in combat", "Hide the overlay while out of combat.", "combatOnly")
  general:Toggle("Minimap button", "Left-click opens these settings, right-click turns the overlay on or off, drag to move it.", function()
    return not ns.db.minimap.hide
  end, function(on)
    ns.SetMinimapHidden(not on)
  end)
  for specIndex = 1, 3 do
    general:Spec(specIndex)
  end
  general:Finish()

  local trigger = NewCard("Trigger")
  trigger:Slider("Appear at", "The aura fades in from this share of max runic power and reaches full strength at the cap.", "startPercent", Percent)
  trigger:Setting("Pulse near cap", "Add a pulsing flare when runic power is about to cap.", "pulse")
  trigger:Slider("Pulse at", "Runic power share at which the pulse starts.", "pulsePercent", Percent, function()
    return ns.db.pulse
  end)
  trigger:Finish()

  local style = NewCard("Style")
  style:Segmented("Look", "Aura: a burning rune circle around your character. Screen edge: a glow around the edges of the screen.", ns.STYLES, function()
    return ns.db.style
  end, function(key)
    ns.Set("style", key)
  end)
  style:Slider("Max opacity", "Opacity at full runic power.", "maxOpacity", Percent)
  style:Slider("Size", "Size of the aura around your character.", "scale", Percent)
  style:Slider("Vertical offset", "Move the aura up or down.", "offsetY", Pixels)
  style:Setting("Motion", "Slowly turn the rune circle and let the ring flicker.", "motion")
  style:Setting("Smooth fade", "Ease opacity changes instead of snapping. In combat, when runic power is hidden from addons, the aura always snaps.", "smooth")
  style:Finish()

  local leftHeight = StackCards({ general, trigger }, true)
  local rightHeight = StackCards({ style }, false)
  return math.max(leftHeight, rightHeight)
end

local function RefreshAll()
  if not panel or not panel.built or not panel:IsVisible() then
    return
  end
  for _, control in ipairs(controls) do
    control.Refresh()
  end
end

-- Built on first open so characters that never look at it pay nothing.
local function BuildPanel()
  panel.built = true

  local scroll = CreateFrame("ScrollFrame", nil, panel)
  scroll:SetAllPoints()
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, delta)
    local range = self:GetVerticalScrollRange() or 0
    self:SetVerticalScroll(math.min(range, math.max(0, self:GetVerticalScroll() - delta * 40)))
  end)

  content = CreateFrame("Frame", nil, scroll)
  scroll:SetScrollChild(content)
  content:SetWidth(math.max(560, panel:GetWidth() or 0))
  scroll:SetScript("OnSizeChanged", function(_, width)
    content:SetWidth(math.max(560, width))
  end)

  panel.logo = BuildHeader()
  content:SetHeight(HEADER_HEIGHT + BuildCards() + 16)
end

local function RegisterSettingsCategory()
  if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then
    return
  end
  panel = CreateFrame("Frame")
  panel:SetScript("OnShow", function()
    if not panel.built then
      BuildPanel()
    end
    panel.logo.spin:Play()
    RefreshAll()
  end)
  panel:SetScript("OnHide", function()
    -- Settings can hide the panel before it is ever shown.
    if panel.built then
      panel.logo.spin:Stop()
    end
    ns.SetPreview(false)
  end)
  -- Called by the settings window's own Defaults button.
  panel.OnDefault = ns.ResetSettings

  local category = Settings.RegisterCanvasLayoutCategory(panel, ns.TITLE)
  Settings.RegisterAddOnCategory(category)
  ns.settingsCategory = category
end

-- Opens the settings page, or closes the settings window if it is showing it.
function ns.ToggleSettings()
  if not ns.settingsCategory then
    return
  end
  if SettingsPanel and SettingsPanel:IsShown() and panel:IsVisible() then
    HideUIPanel(SettingsPanel)
    return
  end
  Settings.OpenToCategory(ns.settingsCategory:GetID())
end

ns.OnChange(RefreshAll)
ns.OnLogin(RegisterSettingsCategory)
