local addonName, ns = ...

-- Minimap button: left-click opens settings, right-click toggles the
-- overlay, drag moves it around the minimap. Death Knights only.
--
-- When another addon has loaded LibDBIcon (most UI suites have), the button
-- is registered through it so minimap skins and button bars treat it like
-- every other launcher. Otherwise the addon draws its own button.

local button

local function OnClick(mouseButton)
  if mouseButton == "RightButton" then
    ns.Set("enabled", not ns.db.enabled)
  else
    ns.ToggleSettings()
  end
end

local function FillTooltip(tooltip)
  local label, r, g, b = ns.GetStatus()
  tooltip:AddLine(ns.TITLE, 1, 1, 1)
  tooltip:AddLine(label, r, g, b)
  tooltip:AddLine(" ")
  tooltip:AddDoubleLine("Left-click", "Settings", 0.7, 0.7, 0.75, 1, 1, 1)
  tooltip:AddDoubleLine("Right-click", ns.db.enabled and "Turn off" or "Turn on", 0.7, 0.7, 0.75, 1, 1, 1)
  tooltip:AddDoubleLine("Drag", "Move", 0.7, 0.7, 0.75, 1, 1, 1)
end

-- Re-applies the icon's look. Skins may tint the icon while it is pressed,
-- so this also runs after every click and mouse-up.
local function Refresh()
  if not button then
    return
  end
  local icon = button.icon
  if icon then
    icon:SetDesaturated(not ns.db.enabled)
    local shade = ns.db.enabled and 1 or 0.55
    icon:SetVertexColor(shade, shade, shade)
  end
end

local function RefreshSoon()
  Refresh()
  C_Timer.After(0, Refresh)
end

---------------------------------------------------------------------------
-- LibDBIcon
---------------------------------------------------------------------------

local function CreateWithLibDBIcon()
  local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
  local DBIcon = LibStub and LibStub("LibDBIcon-1.0", true)
  if not (LDB and DBIcon) then
    return false
  end

  local launcher = LDB:NewDataObject(addonName, {
    type = "launcher",
    label = ns.TITLE,
    icon = ns.ICON,
    OnClick = function(_, mouseButton)
      OnClick(mouseButton)
      RefreshSoon()
    end,
    OnTooltipShow = FillTooltip,
  })
  -- LibDBIcon keeps its own position key; start it where ours was.
  local saved = ns.db.minimap
  saved.minimapPos = saved.minimapPos or saved.angle
  DBIcon:Register(addonName, launcher, saved)
  button = DBIcon:GetMinimapButton(addonName)
  if button then
    button:HookScript("OnMouseUp", RefreshSoon)
  end

  ns.RefreshMinimapVisibility = function()
    if ns.db.minimap.hide then
      DBIcon:Hide(addonName)
    else
      DBIcon:Show(addonName)
    end
  end
  return true
end

---------------------------------------------------------------------------
-- Own button
---------------------------------------------------------------------------

local function UpdatePosition()
  local angle = math.rad(ns.db.minimap.angle)
  local radius = Minimap:GetWidth() / 2 + 10
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function OnDragUpdate()
  local mx, my = Minimap:GetCenter()
  local px, py = GetCursorPosition()
  local scale = Minimap:GetEffectiveScale()
  ns.db.minimap.angle = math.deg(math.atan2(py / scale - my, px / scale - mx))
  UpdatePosition()
end

local function ShowTooltip(self)
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  FillTooltip(GameTooltip)
  GameTooltip:Show()
end

local function CreateOwnButton()
  button = CreateFrame("Button", addonName .. "MinimapButton", Minimap)
  button:SetSize(31, 31)
  button:SetFrameStrata("MEDIUM")
  button:SetFrameLevel(8)
  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  button:RegisterForDrag("LeftButton")
  button:SetHighlightTexture(136477) -- Interface\Minimap\UI-Minimap-ZoomButton-Highlight

  local background = button:CreateTexture(nil, "BACKGROUND")
  background:SetSize(20, 20)
  background:SetTexture(136467) -- Interface\Minimap\UI-Minimap-Background
  background:SetPoint("TOPLEFT", 7, -5)

  local icon = button:CreateTexture(nil, "ARTWORK")
  icon:SetSize(21, 21)
  icon:SetTexture(ns.ICON)
  icon:SetPoint("TOPLEFT", 5, -5)
  button.icon = icon

  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetSize(50, 50)
  border:SetTexture(136430) -- Interface\Minimap\MiniMap-TrackingBorder
  border:SetPoint("TOPLEFT")

  button:SetScript("OnClick", function(self, mouseButton)
    OnClick(mouseButton)
    RefreshSoon()
    if GameTooltip:IsOwned(self) then
      ShowTooltip(self)
    end
  end)
  button:SetScript("OnMouseUp", RefreshSoon)
  button:SetScript("OnEnter", ShowTooltip)
  button:SetScript("OnLeave", function()
    GameTooltip:Hide()
    Refresh()
  end)
  button:SetScript("OnDragStart", function(self)
    GameTooltip:Hide()
    self:LockHighlight()
    self:SetScript("OnUpdate", OnDragUpdate)
  end)
  button:SetScript("OnDragStop", function(self)
    self:UnlockHighlight()
    self:SetScript("OnUpdate", nil)
    RefreshSoon()
  end)

  ns.RefreshMinimapVisibility = function()
    button:SetShown(not ns.db.minimap.hide)
  end
  UpdatePosition()
end

ns.OnChange(function(key)
  if not ns.RefreshMinimapVisibility then
    return
  end
  if key == "minimap" or key == "*" then
    ns.RefreshMinimapVisibility()
  end
  if key == "enabled" or key == "*" then
    Refresh()
  end
end)

ns.OnLogin(function()
  if not ns.isDeathKnight then
    return
  end
  if not CreateWithLibDBIcon() then
    CreateOwnButton()
  end
  ns.RefreshMinimapVisibility()
  Refresh()
end)
