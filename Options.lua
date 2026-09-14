local addonName, ns = ...

local options
local minimapButton
local slider
local sliderLabel
local textureDropdown
local suppressSlider = false

local function UpdateMinimapPosition()
  if not minimapButton then
    return
  end
  local db = ns.EnsureDB()
  local angle = math.rad(db.minimapAngle or 210)
  local radius = (Minimap:GetWidth() / 2) + 8
  minimapButton:ClearAllPoints()
  minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function SelectedTextureName()
  return ns.GetTexturePreset().name
end

local function RefreshTextureSelection()
  if not textureDropdown then
    return
  end
  local name = SelectedTextureName()
  if textureDropdown.OverrideText then
    textureDropdown:OverrideText(name)
  elseif textureDropdown.SetDefaultText then
    textureDropdown:SetDefaultText(name)
  elseif UIDropDownMenu_SetText then
    UIDropDownMenu_SetText(textureDropdown, name)
  end
end

local function RefreshSlider()
  if not slider then
    return
  end
  local percent = ns.EnsureDB().overlayAtPercent
  if percent == nil then
    percent = ns.DEFAULTS.overlayAtPercent
  end
  suppressSlider = true
  slider:SetValue(percent)
  suppressSlider = false
  if sliderLabel then
    sliderLabel:SetFormattedText("Visible from %d%% RP  (fade %.1f to 1.0)", percent, ns.START_ALPHA or 0.1)
  end
end

function ns.RefreshOptions()
  if not options or not options:IsShown() then
    return
  end
  RefreshTextureSelection()
  RefreshSlider()
end

local function CreateModernDropdown(parent)
  local ok, dropdown = pcall(CreateFrame, "DropdownButton", addonName .. "TextureDrop", parent, "WowStyle1DropdownTemplate")
  if not ok or not dropdown or not dropdown.SetupMenu then
    ok, dropdown = pcall(CreateFrame, "Button", addonName .. "TextureDrop", parent, "WowStyle1DropdownTemplate")
  end
  if not ok or not dropdown or not dropdown.SetupMenu then
    return nil
  end

  dropdown:SetWidth(280)
  dropdown:SetupMenu(function(_, rootDescription)
    for _, preset in ipairs(ns.TEXTURE_PRESETS) do
      rootDescription:CreateRadio(preset.name, function()
        return ns.EnsureDB().textureKey == preset.key
      end, function()
        ns.SetTextureKey(preset.key)
        RefreshTextureSelection()
      end)
    end
  end)
  dropdown:SetDefaultText(SelectedTextureName())
  return dropdown
end

local function CreateLegacyDropdown(parent)
  local dropdown = CreateFrame("Frame", addonName .. "TextureDrop", parent, "UIDropDownMenuTemplate")
  UIDropDownMenu_SetWidth(dropdown, 240)
  UIDropDownMenu_Initialize(dropdown, function()
    for _, preset in ipairs(ns.TEXTURE_PRESETS) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = preset.name
      info.checked = ns.EnsureDB().textureKey == preset.key
      info.func = function()
        ns.SetTextureKey(preset.key)
        UIDropDownMenu_SetText(dropdown, preset.name)
      end
      UIDropDownMenu_AddButton(info)
    end
  end)
  UIDropDownMenu_SetText(dropdown, SelectedTextureName())
  return dropdown
end

local function CreateOptions()
  options = CreateFrame("Frame", addonName .. "Options", UIParent, "BackdropTemplate")
  options:SetSize(360, 250)
  options:SetPoint("CENTER")
  options:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true,
    tileSize = 32,
    edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  options:SetBackdropColor(0.08, 0.02, 0.02, 0.95)
  options:SetMovable(true)
  options:EnableMouse(true)
  options:RegisterForDrag("LeftButton")
  options:SetScript("OnDragStart", options.StartMoving)
  options:SetScript("OnDragStop", options.StopMovingOrSizing)
  options:SetFrameStrata("DIALOG")
  options:Hide()
  tinsert(UISpecialFrames, options:GetName())

  local title = options:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -16)
  title:SetText("BDK Never Overcap RP")
  title:SetTextColor(0.85, 0.18, 0.22)

  local close = CreateFrame("Button", nil, options, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -4, -4)

  local texHeader = options:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  texHeader:SetPoint("TOPLEFT", 22, -48)
  texHeader:SetText("Overlay texture")

  textureDropdown = CreateModernDropdown(options) or CreateLegacyDropdown(options)
  if textureDropdown:GetObjectType() == "Frame" and textureDropdown.Left then
    textureDropdown:SetPoint("TOPLEFT", texHeader, "BOTTOMLEFT", -16, -6)
  else
    textureDropdown:SetPoint("TOPLEFT", texHeader, "BOTTOMLEFT", 0, -8)
  end

  sliderLabel = options:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  sliderLabel:SetPoint("TOPLEFT", 22, -118)
  sliderLabel:SetFormattedText("Visible from %d%% RP  (fade %.1f to 1.0)", ns.DEFAULTS.overlayAtPercent, ns.START_ALPHA or 0.1)

  local sliderOk
  sliderOk, slider = pcall(CreateFrame, "Slider", addonName .. "StartSlider", options, "UISliderTemplate")
  if not sliderOk then
    slider = CreateFrame("Slider", addonName .. "StartSlider", options, "OptionsSliderTemplate")
  end
  slider:SetHeight(18)
  slider:SetPoint("TOPLEFT", 28, -148)
  slider:SetPoint("TOPRIGHT", -28, -148)
  slider:SetMinMaxValues(0, 100)
  slider:SetValueStep(1)
  if slider.SetObeyStepOnDrag then
    slider:SetObeyStepOnDrag(true)
  end

  local low = _G[slider:GetName() .. "Low"]
  local high = _G[slider:GetName() .. "High"]
  if low then
    low:Hide()
  end
  if high then
    high:Hide()
  end

  local minLabel = options:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  minLabel:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -4)
  minLabel:SetText("0%")

  local maxLabel = options:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  maxLabel:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -4)
  maxLabel:SetText("100%")

  slider:SetScript("OnValueChanged", function(_, value)
    if suppressSlider then
      return
    end
    local percent = ns.SetOverlayAtPercent(value)
    if sliderLabel then
      sliderLabel:SetFormattedText("Visible from %d%% RP  (fade %.1f to 1.0)", percent, ns.START_ALPHA or 0.1)
    end
  end)

  local hint = options:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("BOTTOM", 0, 18)
  hint:SetWidth(300)
  hint:SetJustifyH("CENTER")
  hint:SetText("Starts at low opacity and reaches full at 100% RP.")
end

function ns.ToggleOptions()
  if not options then
    CreateOptions()
  end
  if options:IsShown() then
    options:Hide()
    return
  end
  RefreshTextureSelection()
  RefreshSlider()
  options:Show()
end

local function CreateMinimapButton()
  minimapButton = CreateFrame("Button", addonName .. "MinimapButton", Minimap)
  minimapButton:SetSize(32, 32)
  minimapButton:SetFrameStrata("MEDIUM")
  minimapButton:SetFrameLevel(8)
  minimapButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  minimapButton:RegisterForDrag("LeftButton")
  minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local overlayTex = minimapButton:CreateTexture(nil, "OVERLAY")
  overlayTex:SetSize(54, 54)
  overlayTex:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  overlayTex:SetPoint("TOPLEFT")

  local icon = minimapButton:CreateTexture(nil, "BACKGROUND")
  icon:SetSize(20, 20)
  icon:SetPoint("CENTER", -1, 1)
  icon:SetTexture("Interface\\Icons\\spell_deathknight_deathstrike")
  icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  minimapButton.icon = icon

  local function UpdateMinimapIcon()
    local enabled = ns.EnsureDB().enabled
    if minimapButton.icon then
      minimapButton.icon:SetDesaturated(not enabled)
      if enabled then
        minimapButton.icon:SetVertexColor(1, 1, 1)
      else
        minimapButton.icon:SetVertexColor(0.55, 0.55, 0.55)
      end
    end
  end

  function ns.RefreshMinimapButton()
    UpdateMinimapIcon()
  end

  minimapButton:SetScript("OnClick", function(_, button)
    if button == "RightButton" then
      local enabled = ns.SetAddonEnabled(not ns.EnsureDB().enabled)
      ns.Print(enabled and "enabled" or "disabled")
      return
    end
    ns.ToggleOptions()
  end)
  minimapButton:SetScript("OnEnter", function(self)
    local enabled = ns.EnsureDB().enabled
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("BDK Never Overcap RP", 0.85, 0.18, 0.22)
    GameTooltip:AddLine("Left-click: settings", 1, 1, 1)
    GameTooltip:AddLine("Right-click: " .. (enabled and "disable" or "enable"), 1, 1, 1)
    GameTooltip:AddLine("Drag to move", 0.7, 0.7, 0.7)
    GameTooltip:Show()
  end)
  minimapButton:SetScript("OnLeave", function()
    GameTooltip:Hide()
  end)
  minimapButton:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local px, py = GetCursorPosition()
      local scale = Minimap:GetEffectiveScale()
      px, py = px / scale, py / scale
      ns.EnsureDB().minimapAngle = math.deg(math.atan2(py - my, px - mx))
      UpdateMinimapPosition()
    end)
  end)
  minimapButton:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
  end)

  UpdateMinimapPosition()
  UpdateMinimapIcon()
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
  CreateMinimapButton()
end)
