local addonName, ns = ...

-- Minimap button: left-click opens settings, right-click toggles the
-- overlay, drag moves it around the minimap. Death Knights only.

local button

local function UpdatePosition()
  local angle = math.rad(ns.db.minimap.angle)
  local radius = Minimap:GetWidth() / 2 + 10
  button:ClearAllPoints()
  button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function Refresh()
  button:SetShown(not ns.db.minimap.hide)
  button.icon:SetDesaturated(not ns.db.enabled)
  local shade = ns.db.enabled and 1 or 0.55
  button.icon:SetVertexColor(shade, shade, shade)
end

local function ShowTooltip(self)
  local label, r, g, b = ns.GetStatus()
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:SetText(ns.TITLE, 1, 1, 1)
  GameTooltip:AddLine(label, r, g, b)
  GameTooltip:AddLine(" ")
  GameTooltip:AddDoubleLine("Left-click", "Settings", 0.7, 0.7, 0.75, 1, 1, 1)
  GameTooltip:AddDoubleLine("Right-click", ns.db.enabled and "Turn off" or "Turn on", 0.7, 0.7, 0.75, 1, 1, 1)
  GameTooltip:AddDoubleLine("Drag", "Move", 0.7, 0.7, 0.75, 1, 1, 1)
  GameTooltip:Show()
end

local function OnDragUpdate()
  local mx, my = Minimap:GetCenter()
  local px, py = GetCursorPosition()
  local scale = Minimap:GetEffectiveScale()
  ns.db.minimap.angle = math.deg(math.atan2(py / scale - my, px / scale - mx))
  UpdatePosition()
end

local function Create()
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
  icon:SetTexture(ns.MEDIA .. "logo")
  icon:SetPoint("TOPLEFT", 5, -5)
  button.icon = icon

  local border = button:CreateTexture(nil, "OVERLAY")
  border:SetSize(50, 50)
  border:SetTexture(136430) -- Interface\Minimap\MiniMap-TrackingBorder
  border:SetPoint("TOPLEFT")

  button:SetScript("OnClick", function(_, mouseButton)
    if mouseButton == "RightButton" then
      ns.Set("enabled", not ns.db.enabled)
      if GameTooltip:IsOwned(button) then
        ShowTooltip(button)
      end
    else
      ns.ToggleSettings()
    end
  end)
  button:SetScript("OnEnter", ShowTooltip)
  button:SetScript("OnLeave", GameTooltip_Hide)
  button:SetScript("OnDragStart", function(self)
    GameTooltip:Hide()
    self:LockHighlight()
    self:SetScript("OnUpdate", OnDragUpdate)
  end)
  button:SetScript("OnDragStop", function(self)
    self:UnlockHighlight()
    self:SetScript("OnUpdate", nil)
  end)

  UpdatePosition()
  Refresh()
end

ns.OnChange(function(key)
  if button and (key == "minimap" or key == "enabled" or key == "*") then
    Refresh()
  end
end)

ns.OnLogin(function()
  if ns.isDeathKnight then
    Create()
  end
end)
