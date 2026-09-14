local addonName, ns = ...

local function PrintHelp()
  ns.Print("Commands:")
  ns.Print("/bnorp status")
  ns.Print("/bnorp on | off")
  ns.Print("/bnorp overlay <percent>  (default 85)")
  ns.Print("/bnorp config")
end

local function HandleSlash(msg)
  local db = ns.EnsureDB()
  local cmd, arg = msg:match("^(%S*)%s*(.*)$")
  cmd = (cmd or ""):lower()
  arg = (arg or ""):lower()

  if cmd == "" or cmd == "help" then
    PrintHelp()
    return
  end

  if cmd == "status" then
    local current, max = ns.GetRunicPower()
    local maxDisplay = ns.GetPowerMaxFallback(max)
    local active = ns.IsBloodDeathKnight() and db.enabled
    if ns.CanAccessPowerNumber(current) then
      ns.Print(string.format(
        "active=%s rp=%d/%d overlay=%d%%",
        active and "yes" or "no",
        current,
        maxDisplay,
        db.overlayAtPercent
      ))
    else
      ns.Print(string.format(
        "active=%s rp=hidden/%d overlay=%d%% (combat-safe)",
        active and "yes" or "no",
        maxDisplay,
        db.overlayAtPercent
      ))
    end
    return
  end

  if cmd == "on" then
    ns.SetAddonEnabled(true)
    ns.Print("enabled")
    return
  end

  if cmd == "off" then
    ns.SetAddonEnabled(false)
    ns.Print("disabled")
    return
  end

  if cmd == "overlay" or cmd == "critical" then
    local value = tonumber(arg)
    if not value then
      ns.Print("usage: /bnorp overlay <percent>")
      return
    end
    ns.SetOverlayAtPercent(value)
    ns.Print("overlay at " .. ns.EnsureDB().overlayAtPercent .. "% RP")
    if ns.RefreshOptions then
      ns.RefreshOptions()
    end
    return
  end

  if cmd == "config" or cmd == "options" or cmd == "settings" then
    ns.ToggleOptions()
    return
  end

  PrintHelp()
end

SLASH_BDKNEVEROVERCAPRP1 = "/bnorp"
SLASH_BDKNEVEROVERCAPRP2 = "/bdkrp"
SlashCmdList["BDKNEVEROVERCAPRP"] = HandleSlash

local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent", function()
  ns.EnsureDB()
  ns.Print("loaded v" .. ns.VERSION .. " — /bnorp help")
end)
