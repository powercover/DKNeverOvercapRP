local addonName, ns = ...

-- Settings page under Options > AddOns. Every control is drawn from plain
-- textures (no Blizzard widget templates) with the bundled Inter font.

local WHITE = "Interface\\Buttons\\WHITE8X8"
local MARGIN = 16
local GAP = 12
local HEADER_HEIGHT = 68

-- Opaque colors only: translucent fills show seams where shapes meet.
local THEME = {
  card = { 0.098, 0.098, 0.110 },
  border = { 0.165, 0.165, 0.180 },
  hover = { 0.130, 0.130, 0.145 },
  well = { 0.070, 0.070, 0.080 },
  raised = { 0.215, 0.215, 0.235 },
  off = { 0.235, 0.235, 0.260 },
  text = { 0.925, 0.925, 0.945 },
  muted = { 0.560, 0.565, 0.610 },
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
-- Fonts
---------------------------------------------------------------------------

-- Inter covers Latin and Cyrillic; other clients keep the game font.
local USE_INTER = not ({ koKR = true, zhCN = true, zhTW = true })[GetLocale()]

local function MakeFont(name, weight, size)
  local font = CreateFont(addonName .. name)
  if USE_INTER then
    font:SetFont(ns.MEDIA .. "Fonts\\Inter-" .. weight .. ".ttf", size, "")
  else
    font:SetFont(STANDARD_TEXT_FONT, size, "")
  end
  font:SetShadowOffset(0, 0)
  return font
end

local FONT = {
  title = MakeFont("FontTitle", "SemiBold", 15),
  heading = MakeFont("FontHeading", "SemiBold", 11),
  label = MakeFont("FontLabel", "Medium", 12),
  small = MakeFont("FontSmall", "Regular", 11),
}

local function Text(parent, font, color)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFontObject(font)
  fs:SetTextColor(color[1], color[2], color[3])
  fs:SetJustifyH("LEFT")
  fs:SetWordWrap(false)
  return fs
end

---------------------------------------------------------------------------
-- Shapes
---------------------------------------------------------------------------

-- Pick the circle texture closest to twice the drawn size, so the client
-- never shrinks it far enough to alias.
local function CircleFile(size)
  return ns.MEDIA .. (size <= 16 and "circle32" or "circle")
end

local function Smooth(tex)
  if tex.SetSnapToPixelGrid then
    tex:SetSnapToPixelGrid(false)
    tex:SetTexelSnappingBias(0)
  end
end

local function Circle(parent, size, layer, sublevel)
  local tex = parent:CreateTexture(nil, layer or "ARTWORK", nil, sublevel)
  tex:SetTexture(CircleFile(size))
  tex:SetSize(size, size)
  Smooth(tex)
  return tex
end

-- Rounded rectangle: four quarter-circle corners plus three strips, all
-- drawn on `owner` and stretched over `region` (owner by default), inset
-- by `inset` pixels.
local Rounded = {}
Rounded.__index = Rounded

local CORNERS = {
  { "TOPLEFT", 0, 0.5, 0, 0.5, 1, -1 },
  { "TOPRIGHT", 0.5, 1, 0, 0.5, -1, -1 },
  { "BOTTOMLEFT", 0, 0.5, 0.5, 1, 1, 1 },
  { "BOTTOMRIGHT", 0.5, 1, 0.5, 1, -1, 1 },
}

local function NewRounded(owner, radius, layer, sublevel, region, inset)
  region = region or owner
  inset = inset or 0
  local self = setmetatable({ parts = {} }, Rounded)
  local function Part(file)
    local tex = owner:CreateTexture(nil, layer, nil, sublevel)
    tex:SetTexture(file)
    self.parts[#self.parts + 1] = tex
    return tex
  end
  local file = CircleFile(radius * 2)
  for _, c in ipairs(CORNERS) do
    local corner = Part(file)
    corner:SetTexCoord(c[2], c[3], c[4], c[5])
    corner:SetSize(radius, radius)
    corner:SetPoint(c[1], region, c[1], c[6] * inset, c[7] * inset)
  end
  local middle = Part(WHITE)
  middle:SetPoint("TOPLEFT", region, "TOPLEFT", inset + radius, -inset)
  middle:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", -inset - radius, inset)
  local left = Part(WHITE)
  left:SetPoint("TOPLEFT", region, "TOPLEFT", inset, -inset - radius)
  left:SetPoint("BOTTOMRIGHT", region, "BOTTOMLEFT", inset + radius, inset + radius)
  local right = Part(WHITE)
  right:SetPoint("TOPLEFT", region, "TOPRIGHT", -inset - radius, -inset - radius)
  right:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", -inset, inset + radius)
  return self
end

function Rounded:SetColor(r, g, b)
  for _, tex in ipairs(self.parts) do
    tex:SetVertexColor(r, g, b)
  end
  return self
end

function Rounded:SetShown(shown)
  for _, tex in ipairs(self.parts) do
    tex:SetShown(shown)
  end
end

-- A rounded box with a 1px border.
local function Box(owner, radius, fill, border, layer)
  layer = layer or "BACKGROUND"
  local outer = NewRounded(owner, radius, layer, -2):SetColor(unpack(border))
  local inner = NewRounded(owner, radius - 1, layer, -1, nil, 1):SetColor(unpack(fill))
  return inner, outer
end

---------------------------------------------------------------------------
-- Behaviour helpers
---------------------------------------------------------------------------

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
-- Controls
---------------------------------------------------------------------------

local function CreateSwitch(parent)
  local switch = CreateFrame("Frame", nil, parent)
  switch:SetSize(28, 16)
  local track = NewRounded(switch, 8, "ARTWORK")
  local knob = Circle(switch, 12, "OVERLAY")
  function switch.SetOn(_, on)
    knob:ClearAllPoints()
    if on then
      knob:SetPoint("RIGHT", -2, 0)
      track:SetColor(Accent())
    else
      knob:SetPoint("LEFT", 2, 0)
      track:SetColor(unpack(THEME.off))
    end
  end
  return switch
end

local function CreateButton(parent, label, width, primary)
  local button = CreateFrame("Button", nil, parent)
  button:SetSize(width, 24)
  local fill, border = Box(button, 6, THEME.card, THEME.border)
  local text = Text(button, FONT.label, THEME.text)
  text:SetPoint("CENTER", 0, 0)
  text:SetText(label)
  button.text = text

  local function Paint()
    local hover = button:IsMouseOver()
    if primary then
      local r, g, b = Accent()
      local k = hover and 0.85 or 0.72
      fill:SetColor(r * k, g * k, b * k)
      border:SetColor(r * k, g * k, b * k)
    else
      fill:SetColor(unpack(hover and THEME.hover or THEME.card))
      border:SetColor(unpack(THEME.border))
    end
  end
  button:SetScript("OnEnter", Paint)
  button:SetScript("OnLeave", Paint)
  button.Refresh = Paint
  return Track(button)
end

---------------------------------------------------------------------------
-- Cards and rows
---------------------------------------------------------------------------

local Card = {}
Card.__index = Card

local function NewCard(title)
  local frame = CreateFrame("Frame", nil, content)
  Box(frame, 8, THEME.card, THEME.border)
  local heading = Text(frame, FONT.heading, THEME.muted)
  heading:SetPoint("TOPLEFT", 14, -12)
  heading:SetText(title)
  return setmetatable({ frame = frame, y = -30 }, Card)
end

function Card:Finish()
  self.frame:SetHeight(-self.y + 6)
  return self
end

-- Clickable rows get a hover highlight; rows that host their own
-- interactive widget (sliders, segmented bars) only show a tooltip.
function Card:Row(height, label, tooltip, clickable)
  local row = CreateFrame(clickable and "Button" or "Frame", nil, self.frame)
  row:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 6, self.y)
  row:SetPoint("TOPRIGHT", self.frame, "TOPRIGHT", -6, self.y)
  row:SetHeight(height)
  row:EnableMouse(true)
  self.y = self.y - height

  local hover
  if clickable then
    hover = NewRounded(row, 5, "BACKGROUND"):SetColor(unpack(THEME.hover))
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

function Card:Toggle(label, tooltip, get, set, isEnabled)
  local row = self:Row(28, label, tooltip, true)
  local text = Text(row, FONT.label, THEME.text)
  text:SetPoint("LEFT", 8, 0)
  text:SetText(label)
  local switch = CreateSwitch(row)
  switch:SetPoint("RIGHT", -8, 0)
  row:SetScript("OnClick", function()
    if isEnabled and not isEnabled() then
      return
    end
    local on = not get()
    PlayToggleSound(on)
    set(on)
  end)
  row.Refresh = function()
    switch:SetOn(get())
    row:SetAlpha((not isEnabled or isEnabled()) and 1 or 0.4)
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
  local row = self:Row(40, label, tooltip, false)

  local text = Text(row, FONT.label, THEME.text)
  text:SetPoint("TOPLEFT", 8, -6)
  text:SetText(label)
  local value = Text(row, FONT.small, THEME.muted)
  value:SetPoint("TOPRIGHT", -8, -7)
  value:SetJustifyH("RIGHT")

  local slider = CreateFrame("Slider", nil, row)
  slider:SetPoint("BOTTOMLEFT", 8, 5)
  slider:SetPoint("BOTTOMRIGHT", -8, 5)
  slider:SetHeight(14)
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

  local fillRegion = slider:CreateTexture(nil, "ARTWORK")
  fillRegion:SetPoint("LEFT", trackRegion)
  fillRegion:SetHeight(4)
  local fill = NewRounded(slider, 2, "ARTWORK", 1, fillRegion)

  local thumb = Circle(slider, 12, "OVERLAY")
  slider:SetThumbTexture(thumb)

  -- The thumb travels between half its width from either end.
  local function UpdateFill()
    local width = slider:GetWidth() or 0
    local t = (slider:GetValue() - limit[1]) / (limit[2] - limit[1])
    fillRegion:SetWidth(math.max(4, 6 + t * (width - 12)))
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

  row.Refresh = function()
    slider.suppress = true
    slider:SetValue(ns.db[key])
    slider.suppress = false
    value:SetText(format(ns.db[key]))
    UpdateFill()
    fill:SetColor(Accent())
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

local TILE_COLUMNS = 4
local TILE_HEIGHT = 56
local TILE_GAP = 6

function Card:Patterns(label)
  local rows = math.ceil(#ns.PATTERNS / TILE_COLUMNS)
  local row = self:Row(26 + rows * TILE_HEIGHT + (rows - 1) * TILE_GAP + 8, label, nil, false)
  local text = Text(row, FONT.label, THEME.text)
  text:SetPoint("TOPLEFT", 8, -6)
  text:SetText(label)

  local grid = CreateFrame("Frame", nil, row)
  grid:SetPoint("TOPLEFT", 8, -26)
  grid:SetPoint("BOTTOMRIGHT", -8, 8)

  local tiles = {}
  for i, pattern in ipairs(ns.PATTERNS) do
    local tile = CreateFrame("Button", nil, grid)
    tile:SetHeight(TILE_HEIGHT)
    tile.fill, tile.border = Box(tile, 6, THEME.well, THEME.border)

    local icon = tile:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ns.MEDIA .. pattern.icon)
    icon:SetBlendMode("ADD")
    if pattern.screen then
      icon:SetSize(40, 24)
      -- A small "screen" behind the icon.
      NewRounded(tile, 2, "ARTWORK", -1, icon):SetColor(unpack(THEME.border))
    else
      icon:SetSize(30, 30)
    end
    icon:SetPoint("CENTER", 0, 7)
    Smooth(icon)
    tile.icon = icon

    local name = Text(tile, FONT.small, THEME.muted)
    name:SetPoint("BOTTOM", 0, 6)
    name:SetJustifyH("CENTER")
    name:SetText(pattern.name)
    tile.name = name

    tile:SetScript("OnClick", function()
      PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
      ns.Set("pattern", pattern.key)
    end)
    tile:SetScript("OnEnter", function()
      if ns.db.pattern ~= pattern.key then
        tile.fill:SetColor(unpack(THEME.hover))
      end
    end)
    tile:SetScript("OnLeave", function()
      row.Refresh()
    end)
    tile.key = pattern.key
    tiles[i] = tile
  end

  local function Layout(width)
    if not width or width <= 0 then
      return
    end
    local each = (width - (TILE_COLUMNS - 1) * TILE_GAP) / TILE_COLUMNS
    for i, tile in ipairs(tiles) do
      local col = (i - 1) % TILE_COLUMNS
      local line = math.floor((i - 1) / TILE_COLUMNS)
      tile:ClearAllPoints()
      tile:SetWidth(each)
      tile:SetPoint("TOPLEFT", grid, "TOPLEFT", col * (each + TILE_GAP), -line * (TILE_HEIGHT + TILE_GAP))
    end
  end
  grid:SetScript("OnSizeChanged", function(_, width)
    Layout(width)
  end)

  row.Refresh = function()
    Layout(grid:GetWidth())
    local r, g, b = Accent()
    for _, tile in ipairs(tiles) do
      local selected = ns.db.pattern == tile.key
      tile.icon:SetVertexColor(r, g, b)
      tile.icon:SetAlpha(selected and 1 or 0.6)
      if selected then
        tile.fill:SetColor(unpack(THEME.raised))
        tile.border:SetColor(r * 0.8, g * 0.8, b * 0.8)
        tile.name:SetTextColor(unpack(THEME.text))
      else
        tile.fill:SetColor(unpack(tile:IsMouseOver() and THEME.hover or THEME.well))
        tile.border:SetColor(unpack(THEME.border))
        tile.name:SetTextColor(unpack(THEME.muted))
      end
    end
  end
  return Track(row)
end

function Card:Spec(specIndex)
  local name, icon = ns.GetSpecInfo(specIndex)
  local row = self:Row(30, name, "Show the overlay while you are in " .. name .. ". Click the dot to pick this spec's color.", true)

  local iconTex = row:CreateTexture(nil, "ARTWORK")
  iconTex:SetSize(18, 18)
  iconTex:SetPoint("LEFT", 8, 0)
  if icon then
    iconTex:SetTexture(icon)
  end
  iconTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  local mask = row:CreateMaskTexture()
  mask:SetTexture(CircleFile(18), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  mask:SetAllPoints(iconTex)
  iconTex:AddMaskTexture(mask)

  local text = Text(row, FONT.label, THEME.text)
  text:SetPoint("LEFT", iconTex, "RIGHT", 8, 0)
  text:SetText(name)

  local switch = CreateSwitch(row)
  switch:SetPoint("RIGHT", -8, 0)

  local swatch = CreateFrame("Button", nil, row)
  swatch:SetSize(16, 16)
  swatch:SetPoint("RIGHT", switch, "LEFT", -12, 0)
  local ring = Circle(swatch, 16, "ARTWORK")
  ring:SetPoint("CENTER")
  local dot = Circle(swatch, 12, "OVERLAY")
  dot:SetPoint("CENTER")

  local function PaintRing()
    local shade = swatch:IsMouseOver() and THEME.muted or THEME.border
    ring:SetVertexColor(shade[1], shade[2], shade[3])
  end
  swatch:SetScript("OnClick", function()
    OpenColorPicker(ns.db.colors[specIndex], function(r, g, b)
      ns.SetSpecColor(specIndex, r, g, b)
    end)
  end)
  swatch:SetScript("OnEnter", function()
    PaintRing()
    ShowTooltip(swatch, name .. " color", "Click to change the color used in " .. name .. ".")
  end)
  swatch:SetScript("OnLeave", function()
    PaintRing()
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
    PaintRing()
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

function ns.GetVersionLabel()
  return ns.VERSION == "dev" and "Dev build" or ("v" .. ns.VERSION)
end

local function BuildHeader()
  local logo = CreateFrame("Frame", nil, content)
  logo:SetSize(36, 36)
  logo:SetPoint("TOPLEFT", MARGIN + 2, -MARGIN)
  local runes = logo:CreateTexture(nil, "ARTWORK")
  runes:SetTexture(ns.MEDIA .. "runes")
  runes:SetAllPoints()
  Smooth(runes)
  local core = logo:CreateTexture(nil, "OVERLAY")
  core:SetTexture(ns.MEDIA .. "ring_core")
  core:SetBlendMode("ADD")
  core:SetAllPoints()
  Smooth(core)

  local spin = runes:CreateAnimationGroup()
  spin:SetLooping("REPEAT")
  local rotation = spin:CreateAnimation("Rotation")
  rotation:SetDegrees(-360)
  rotation:SetDuration(40)
  logo.spin = spin

  local title = Text(content, FONT.title, THEME.text)
  title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 12, -1)
  title:SetText(ns.TITLE)

  local dot = Circle(content, 6, "ARTWORK")
  dot:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 1, -7)
  local status = Text(content, FONT.small, THEME.muted)
  status:SetPoint("LEFT", dot, "RIGHT", 6, 0)

  local preview = CreateButton(content, "Preview", 84, true)
  preview:SetPoint("TOPRIGHT", -MARGIN, -MARGIN - 6)
  preview:SetScript("OnClick", function()
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    ns.SetPreview(not ns.IsPreviewing())
  end)

  local reset = CreateButton(content, "Reset", 64, false)
  reset:SetPoint("RIGHT", preview, "LEFT", -8, 0)
  reset:SetScript("OnClick", function()
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    ns.ResetSettings()
  end)

  Track({
    Refresh = function()
      local r, g, b = Accent()
      runes:SetVertexColor(r, g, b)
      core:SetVertexColor(r + (1 - r) * 0.5, g + (1 - g) * 0.5, b + (1 - b) * 0.5)
      local label, sr, sg, sb = ns.GetStatus()
      dot:SetVertexColor(sr, sg, sb)
      status:SetText(label .. "   ·   " .. ns.GetVersionLabel())
      preview.text:SetText(ns.IsPreviewing() and "Stop" or "Preview")
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
      frame:SetPoint("TOPLEFT", content, "TOPLEFT", MARGIN, -HEADER_HEIGHT)
      frame:SetPoint("TOPRIGHT", content, "TOP", -GAP / 2, -HEADER_HEIGHT)
    else
      frame:SetPoint("TOPLEFT", content, "TOP", GAP / 2, -HEADER_HEIGHT)
      frame:SetPoint("TOPRIGHT", content, "TOPRIGHT", -MARGIN, -HEADER_HEIGHT)
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
  general:Finish()

  local specs = NewCard("Specializations")
  for specIndex = 1, 3 do
    specs:Spec(specIndex)
  end
  specs:Finish()

  local trigger = NewCard("Trigger")
  trigger:Slider("Appear at", "The aura fades in from this share of max runic power and reaches full strength at the cap.", "startPercent", Percent)
  trigger:Setting("Pulse near cap", "Add a pulsing flare when runic power is about to cap.", "pulse")
  trigger:Slider("Pulse at", "Runic power share at which the pulse starts.", "pulsePercent", Percent, function()
    return ns.db.pulse
  end)
  trigger:Finish()

  local style = NewCard("Appearance")
  style:Patterns("Pattern")
  style:Toggle("Screen edge glow", "Also glow softly around the edges of the screen. Available with patterns drawn around the character.", function()
    return ns.db.edgeGlow
  end, function(on)
    ns.Set("edgeGlow", on)
  end, function()
    return not ns.GetPattern(ns.db.pattern).screen
  end)
  style:Slider("Max opacity", "Opacity at full runic power.", "maxOpacity", Percent)
  style:Slider("Size", "Size of the aura around your character.", "scale", Percent)
  style:Slider("Vertical offset", "Move the aura up or down.", "offsetY", Pixels)
  style:Setting("Motion", "Slowly turn the patterns and let them breathe.", "motion")
  style:Setting("Smooth fade", "Glide between opacity levels instead of jumping. If the game hides runic power from addons in combat, changes there are instant.", "smooth")
  style:Finish()

  local leftHeight = StackCards({ general, specs, trigger }, true)
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
  content:SetWidth(math.max(520, panel:GetWidth() or 0))
  scroll:SetScript("OnSizeChanged", function(_, width)
    content:SetWidth(math.max(520, width))
  end)

  panel.logo = BuildHeader()
  content:SetHeight(HEADER_HEIGHT + BuildCards() + MARGIN)
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
