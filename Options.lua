local addonName, ns = ...

local ACCENT = ns.ACCENT
local COLUMN_WIDTH = 272

local window
local controls = {}
local statusText

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function AttachTooltip(frame, title, body)
  if not body then
    return
  end
  frame:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(title, 1, 1, 1)
    GameTooltip:AddLine(body, nil, nil, nil, true)
    GameTooltip:Show()
  end)
  frame:HookScript("OnLeave", GameTooltip_Hide)
end

local function Track(control)
  controls[#controls + 1] = control
  return control
end

function ns.GetStatusText()
  if ns.IsPreviewing() then
    return "|cff66ccffPreviewing|r"
  end
  if not ns.isDeathKnight then
    return "|cff888888Inactive|r  (not a Death Knight)"
  end
  if not ns.db.enabled then
    return "|cffff5555Disabled|r"
  end
  local spec = ns.GetSpecIndex()
  local specName = spec and spec > 0 and ns.GetSpecInfo(spec) or "No spec"
  if ns.IsOverlayActive() then
    return "|cff55ff55Active|r  (" .. specName .. ")"
  end
  return "|cffffcc00Waiting|r  (" .. specName .. " is not tracked)"
end

local function RefreshAll()
  if not window or not window:IsShown() then
    return
  end
  for _, control in ipairs(controls) do
    control:Refresh()
  end
  statusText:SetText("Status: " .. ns.GetStatusText())
end

---------------------------------------------------------------------------
-- Widgets
---------------------------------------------------------------------------

-- Lays widgets out top to bottom inside a column.
local Column = {}
Column.__index = Column

local function NewColumn(parent, x, y)
  return setmetatable({ parent = parent, x = x, y = y }, Column)
end

function Column:Place(widget, height, indent)
  widget:SetPoint("TOPLEFT", self.parent, "TOPLEFT", self.x + (indent or 0), self.y)
  self.y = self.y - height
end

function Column:Gap(height)
  self.y = self.y - height
end

function Column:Header(text)
  local label = self.parent:CreateFontString(nil, "ARTWORK", "GameFontNormalMed2")
  label:SetText(text)
  label:SetTextColor(ACCENT.r + 0.15, ACCENT.g + 0.15, ACCENT.b + 0.15)
  self:Place(label, 18)

  local line = self.parent:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(ACCENT.r, ACCENT.g, ACCENT.b, 0.6)
  line:SetSize(COLUMN_WIDTH, 1)
  self:Place(line, 10)
end

function Column:Label(text, font)
  local label = self.parent:CreateFontString(nil, "ARTWORK", font or "GameFontHighlight")
  label:SetText(text)
  self:Place(label, 18)
  return label
end

local function CreateCheckbox(parent, label, tooltip, get, set)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetSize(26, 26)
  local text = cb.text or cb.Text or cb:CreateFontString(nil, "ARTWORK")
  text:SetFontObject("GameFontHighlight")
  text:ClearAllPoints()
  text:SetPoint("LEFT", cb, "RIGHT", 2, 1)
  text:SetText(label)
  cb:SetHitRectInsets(0, -(text:GetStringWidth() + 6), 0, 0)
  cb:SetScript("OnClick", function(self)
    PlaySound(self:GetChecked() and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
    set(self:GetChecked())
  end)
  AttachTooltip(cb, label, tooltip)
  cb.label = text
  cb.Refresh = function()
    cb:SetChecked(get() and true or false)
  end
  return Track(cb)
end

function Column:Checkbox(label, tooltip, key)
  local cb = CreateCheckbox(self.parent, label, tooltip, function()
    return ns.db[key]
  end, function(value)
    ns.Set(key, value and true or false)
  end)
  self:Place(cb, 28)
  return cb
end

local function SetControlEnabled(frame, enabled)
  if frame.SetEnabled then
    frame:SetEnabled(enabled)
  end
  frame:SetAlpha(enabled and 1 or 0.45)
end

local function CreateModernSlider(parent, width, limit, format)
  local ok, slider = pcall(CreateFrame, "Frame", nil, parent, "MinimalSliderWithSteppersTemplate")
  if not ok or not slider or not slider.Init or not MinimalSliderWithSteppersMixin then
    return nil
  end
  slider:SetWidth(width)
  local formatters = { [MinimalSliderWithSteppersMixin.Label.Right] = format }
  slider:Init(limit[1], limit[1], limit[2], (limit[2] - limit[1]) / limit[3], formatters)
  slider.OnUserChange = function() end
  slider:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
    if not slider.suppress then
      slider.OnUserChange(value)
    end
  end, slider)
  return slider
end

-- Plain slider for clients without the minimal slider template.
local function CreateBasicSlider(parent, width, limit, format)
  local holder = CreateFrame("Frame", nil, parent)
  holder:SetSize(width, 20)

  local slider = CreateFrame("Slider", nil, holder)
  slider:SetOrientation("HORIZONTAL")
  slider:SetPoint("LEFT")
  slider:SetSize(width - 44, 16)
  slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
  slider:SetMinMaxValues(limit[1], limit[2])
  slider:SetValueStep(limit[3])
  slider:SetObeyStepOnDrag(true)
  local track = slider:CreateTexture(nil, "BACKGROUND")
  track:SetColorTexture(0, 0, 0, 0.55)
  track:SetPoint("LEFT")
  track:SetPoint("RIGHT")
  track:SetHeight(6)

  local value = holder:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  value:SetPoint("LEFT", slider, "RIGHT", 8, 0)

  holder.Slider = slider
  holder.OnUserChange = function() end
  slider:SetScript("OnValueChanged", function(_, v)
    value:SetText(format(v))
    if not holder.suppress then
      holder.OnUserChange(v)
    end
  end)
  holder.SetValue = function(_, v)
    slider:SetValue(v)
    value:SetText(format(v))
  end
  holder.SetEnabled = function(_, enabled)
    if enabled then
      slider:Enable()
    else
      slider:Disable()
    end
  end
  return holder
end

function Column:Slider(label, tooltip, key, format, isEnabled)
  local limit = ns.LIMITS[key]
  local title = self:Label(label)
  local slider = CreateModernSlider(self.parent, COLUMN_WIDTH - 44, limit, format)
    or CreateBasicSlider(self.parent, COLUMN_WIDTH, limit, format)
  self:Place(slider, 32)
  slider.OnUserChange = function(value)
    ns.Set(key, value)
  end
  AttachTooltip(slider.Slider or slider, label, tooltip)
  slider.Refresh = function()
    slider.suppress = true
    slider:SetValue(ns.db[key])
    slider.suppress = false
    if isEnabled then
      local enabled = isEnabled()
      SetControlEnabled(slider, enabled)
      title:SetAlpha(enabled and 1 or 0.45)
    end
  end
  return Track(slider)
end

local function CreateTextureDropdown(parent, width)
  local ok, dropdown = pcall(CreateFrame, "DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
  if ok and dropdown and dropdown.SetupMenu then
    dropdown:SetWidth(width)
    dropdown:SetupMenu(function(_, rootDescription)
      for _, preset in ipairs(ns.TEXTURE_PRESETS) do
        rootDescription:CreateRadio(preset.name, function()
          return ns.db.texture == preset.key
        end, function()
          ns.Set("texture", preset.key)
        end)
      end
    end)
    dropdown.Refresh = function()
      dropdown:GenerateMenu()
    end
    return dropdown
  end

  dropdown = CreateFrame("Frame", addonName .. "TextureDropdown", parent, "UIDropDownMenuTemplate")
  UIDropDownMenu_SetWidth(dropdown, width - 30)
  UIDropDownMenu_Initialize(dropdown, function()
    for _, preset in ipairs(ns.TEXTURE_PRESETS) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = preset.name
      info.checked = ns.db.texture == preset.key
      info.func = function()
        ns.Set("texture", preset.key)
      end
      UIDropDownMenu_AddButton(info)
    end
  end)
  dropdown.legacy = true
  dropdown.Refresh = function()
    UIDropDownMenu_SetText(dropdown, ns.GetTexturePreset().name)
  end
  return dropdown
end

local function CreateColorSwatch(parent)
  local swatch = CreateFrame("Button", nil, parent)
  swatch:SetSize(20, 20)
  local border = swatch:CreateTexture(nil, "BACKGROUND")
  border:SetAllPoints()
  border:SetColorTexture(0.85, 0.85, 0.85, 1)
  local fill = swatch:CreateTexture(nil, "ARTWORK")
  fill:SetPoint("TOPLEFT", 2, -2)
  fill:SetPoint("BOTTOMRIGHT", -2, 2)

  swatch:SetScript("OnClick", function()
    local tint = ns.db.tint
    ColorPickerFrame:SetupColorPickerAndShow({
      r = tint.r,
      g = tint.g,
      b = tint.b,
      hasOpacity = false,
      swatchFunc = function()
        ns.SetTint(ColorPickerFrame:GetColorRGB())
      end,
      cancelFunc = function(previous)
        ns.SetTint(previous.r, previous.g, previous.b)
      end,
    })
  end)
  AttachTooltip(swatch, "Aura color", "Click to pick the color used when custom color is on.")
  swatch.Refresh = function()
    local tint = ns.db.tint
    fill:SetColorTexture(tint.r, tint.g, tint.b, 1)
    SetControlEnabled(swatch, ns.db.useTint)
  end
  return Track(swatch)
end

local function Percent(value)
  return string.format("%d%%", math.floor(value + 0.5))
end

local function Pixels(value)
  return string.format("%+d", math.floor(value + 0.5))
end

---------------------------------------------------------------------------
-- Settings window
---------------------------------------------------------------------------

local function BuildBehaviorColumn(col)
  col:Header("Behavior")
  col:Checkbox("Enable overlay", "Master switch. Right-click the minimap button to toggle it quickly.", "enabled")

  col:Gap(4)
  col:Label("Track these specs", "GameFontNormalSmall")
  local x = 0
  for specIndex = 1, 3 do
    local name, icon = ns.GetSpecInfo(specIndex)
    local label = (icon and ("|T" .. icon .. ":16:16:0:0:64:64:5:59:5:59|t ") or "") .. name
    local cb = CreateCheckbox(col.parent, label, "Show the overlay while you are in " .. name .. ".", function()
      return ns.db.specs[specIndex]
    end, function(value)
      ns.SetSpecTracked(specIndex, value)
    end)
    cb:SetPoint("TOPLEFT", col.parent, "TOPLEFT", col.x + x, col.y)
    x = x + 90
  end
  col:Gap(30)

  col:Checkbox("Only in combat", "Hide the overlay while out of combat.", "combatOnly")

  local minimap = CreateCheckbox(col.parent, "Minimap button", "Show the minimap button. The addon compartment entry is always available.", function()
    return not ns.db.minimap.hide
  end, function(value)
    ns.SetMinimapHidden(not value)
  end)
  col:Place(minimap, 28)

  col:Gap(10)
  col:Header("Trigger")
  col:Slider("Appear at runic power", "The aura fades in from this share of max runic power and reaches full opacity at the cap.", "startPercent", Percent)
  col:Checkbox("Pulse near cap", "Add a pulsing flare when runic power is about to cap.", "pulse")
  col:Slider("Pulse at runic power", "Runic power share at which the pulse starts.", "pulsePercent", Percent, function()
    return ns.db.pulse
  end)
end

local function BuildAppearanceColumn(col)
  col:Header("Appearance")
  col:Label("Texture", "GameFontNormalSmall")
  local dropdown = Track(CreateTextureDropdown(col.parent, COLUMN_WIDTH))
  col:Place(dropdown, 34, dropdown.legacy and -16 or 0)

  local tint = col:Checkbox("Custom color", "Recolor the aura with a single color instead of the texture's own colors.", "useTint")
  local swatch = CreateColorSwatch(col.parent)
  swatch:SetPoint("LEFT", tint.label, "RIGHT", 10, 0)

  col:Gap(4)
  col:Slider("Max opacity", "Opacity of the aura at full runic power.", "maxOpacity", Percent)
  col:Slider("Size", "Scale of the aura around your character.", "scale", Percent)
  col:Slider("Vertical offset", "Move the aura up or down, in pixels.", "offsetY", Pixels)
  col:Checkbox("Spinning runes", "Slowly rotate the two rune swirls.", "spin")
  col:Checkbox("Smooth fade", "Ease opacity changes instead of snapping. In combat, when runic power is hidden from addons, the aura always snaps.", "smooth")
end

local function CreateWindow()
  window = CreateFrame("Frame", addonName .. "Options", UIParent, "ButtonFrameTemplate")
  window:SetSize(620, 500)
  window:SetPoint("CENTER")
  window:SetFrameStrata("DIALOG")
  window:SetToplevel(true)
  window:SetClampedToScreen(true)
  window:SetMovable(true)
  window:EnableMouse(true)
  window:RegisterForDrag("LeftButton")
  window:SetScript("OnDragStart", window.StartMoving)
  window:SetScript("OnDragStop", window.StopMovingOrSizing)
  window:Hide()
  tinsert(UISpecialFrames, window:GetName())

  if window.SetTitle then
    window:SetTitle(ns.TITLE)
  end
  if window.SetPortraitToAsset then
    window:SetPortraitToAsset(ns.ICON)
  end

  local content = window.Inset or window

  statusText = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  statusText:SetPoint("TOPLEFT", 16, -12)

  local divider = content:CreateTexture(nil, "ARTWORK")
  divider:SetColorTexture(1, 1, 1, 0.08)
  divider:SetPoint("TOPLEFT", 10, -32)
  divider:SetPoint("TOPRIGHT", -10, -32)

  BuildBehaviorColumn(NewColumn(content, 16, -44))
  BuildAppearanceColumn(NewColumn(content, 318, -44))

  local version = window:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
  version:SetPoint("BOTTOMLEFT", 14, 9)
  version:SetText("v" .. ns.VERSION .. "  ·  /bnorp help")

  local preview = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
  preview:SetSize(130, 22)
  preview:SetPoint("BOTTOMRIGHT", -8, 4)
  preview:SetScript("OnClick", function()
    ns.SetPreview(not ns.IsPreviewing())
  end)
  AttachTooltip(preview, "Preview", "Show the aura at full strength while this window is open.")
  preview.Refresh = function()
    preview:SetText(ns.IsPreviewing() and "Stop preview" or "Preview")
  end
  Track(preview)

  local reset = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
  reset:SetSize(130, 22)
  reset:SetPoint("RIGHT", preview, "LEFT", -6, 0)
  reset:SetText("Reset to defaults")
  reset:SetScript("OnClick", function()
    ns.ResetSettings()
    ns.Print("settings reset to defaults")
  end)

  window:SetScript("OnShow", function()
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
    RefreshAll()
  end)
  window:SetScript("OnHide", function()
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
    ns.SetPreview(false)
  end)
end

function ns.ToggleOptions(show)
  if not window then
    CreateWindow()
  end
  if show == nil then
    show = not window:IsShown()
  end
  window:SetShown(show)
end

ns.OnChange(RefreshAll)

---------------------------------------------------------------------------
-- Game menu > Options > AddOns entry
---------------------------------------------------------------------------

local function RegisterSettingsCategory()
  if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then
    return
  end
  local panel = CreateFrame("Frame")

  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText(ns.TITLE)

  local about = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
  about:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
  about:SetWidth(520)
  about:SetJustifyH("LEFT")
  about:SetText("Shows a blood aura around your character as runic power approaches the cap, so you spend it before it is wasted.")

  local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  open:SetSize(180, 26)
  open:SetPoint("TOPLEFT", about, "BOTTOMLEFT", 0, -16)
  open:SetText("Open settings")
  open:SetScript("OnClick", function()
    if SettingsPanel and SettingsPanel:IsShown() then
      HideUIPanel(SettingsPanel)
    end
    ns.ToggleOptions(true)
  end)

  local category = Settings.RegisterCanvasLayoutCategory(panel, ns.TITLE)
  Settings.RegisterAddOnCategory(category)
end

---------------------------------------------------------------------------
-- Minimap button and addon compartment
---------------------------------------------------------------------------

local minimapButton

local function OnLauncherClick(button)
  if button == "RightButton" then
    local enabled = ns.Set("enabled", not ns.db.enabled)
    ns.Print(enabled and "enabled" or "disabled")
    return
  end
  ns.ToggleOptions()
end

local function ShowLauncherTooltip(owner, anchor)
  GameTooltip:SetOwner(owner, anchor)
  GameTooltip:SetText(ns.TITLE, ACCENT.r + 0.15, ACCENT.g + 0.15, ACCENT.b + 0.15)
  GameTooltip:AddLine(ns.GetStatusText(), 1, 1, 1)
  GameTooltip:AddLine(" ")
  GameTooltip:AddDoubleLine("Left-click", "Settings", 1, 0.82, 0, 1, 1, 1)
  GameTooltip:AddDoubleLine("Right-click", ns.db.enabled and "Disable" or "Enable", 1, 0.82, 0, 1, 1, 1)
  if owner == minimapButton then
    GameTooltip:AddDoubleLine("Drag", "Move button", 1, 0.82, 0, 1, 1, 1)
  end
  GameTooltip:Show()
end

local function UpdateMinimapPosition()
  local angle = math.rad(ns.db.minimap.angle)
  local radius = Minimap:GetWidth() / 2 + 10
  minimapButton:ClearAllPoints()
  minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function RefreshMinimapButton()
  if not minimapButton then
    return
  end
  -- The button only matters on characters that can use the overlay.
  minimapButton:SetShown(ns.isDeathKnight and not ns.db.minimap.hide)
  minimapButton.icon:SetDesaturated(not ns.db.enabled)
  local shade = ns.db.enabled and 1 or 0.6
  minimapButton.icon:SetVertexColor(shade, shade, shade)
end

local function OnMinimapDrag(self)
  local mx, my = Minimap:GetCenter()
  local px, py = GetCursorPosition()
  local scale = Minimap:GetEffectiveScale()
  ns.db.minimap.angle = math.deg(math.atan2(py / scale - my, px / scale - mx))
  UpdateMinimapPosition()
  if GameTooltip:IsOwned(self) then
    GameTooltip:Hide()
  end
end

local function CreateMinimapButton()
  minimapButton = CreateFrame("Button", addonName .. "MinimapButton", Minimap)
  minimapButton:SetSize(31, 31)
  minimapButton:SetFrameStrata("MEDIUM")
  minimapButton:SetFrameLevel(8)
  minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  minimapButton:RegisterForDrag("LeftButton")
  minimapButton:SetHighlightTexture(136477) -- Interface\Minimap\UI-Minimap-ZoomButton-Highlight

  local background = minimapButton:CreateTexture(nil, "BACKGROUND")
  background:SetSize(20, 20)
  background:SetTexture(136467) -- Interface\Minimap\UI-Minimap-Background
  background:SetPoint("TOPLEFT", 7, -5)

  local icon = minimapButton:CreateTexture(nil, "ARTWORK")
  icon:SetSize(17, 17)
  icon:SetTexture(ns.ICON)
  icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  icon:SetPoint("TOPLEFT", 7, -6)
  minimapButton.icon = icon

  local border = minimapButton:CreateTexture(nil, "OVERLAY")
  border:SetSize(50, 50)
  border:SetTexture(136430) -- Interface\Minimap\MiniMap-TrackingBorder
  border:SetPoint("TOPLEFT")

  minimapButton:SetScript("OnClick", function(_, button)
    OnLauncherClick(button)
  end)
  minimapButton:SetScript("OnEnter", function(self)
    ShowLauncherTooltip(self, "ANCHOR_LEFT")
  end)
  minimapButton:SetScript("OnLeave", GameTooltip_Hide)
  minimapButton:SetScript("OnDragStart", function(self)
    self:LockHighlight()
    self:SetScript("OnUpdate", OnMinimapDrag)
  end)
  minimapButton:SetScript("OnDragStop", function(self)
    self:UnlockHighlight()
    self:SetScript("OnUpdate", nil)
  end)

  UpdateMinimapPosition()
  RefreshMinimapButton()
end

ns.OnChange(function(key)
  if key == "minimap" or key == "enabled" or key == "*" then
    RefreshMinimapButton()
  end
end)

-- Referenced from the TOC (AddonCompartmentFunc*).
function BDKNeverOvercapRP_OnCompartmentClick(_, input)
  -- Newer clients pass menu input data instead of the mouse button name.
  OnLauncherClick(type(input) == "table" and input.buttonName or input)
end

function BDKNeverOvercapRP_OnCompartmentEnter(_, frame)
  ShowLauncherTooltip(frame, "ANCHOR_LEFT")
end

function BDKNeverOvercapRP_OnCompartmentLeave()
  GameTooltip:Hide()
end

ns.OnLogin(function()
  RegisterSettingsCategory()
  if ns.isDeathKnight then
    CreateMinimapButton()
  end
end)
