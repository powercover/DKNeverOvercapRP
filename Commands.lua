local _, ns = ...

local HELP = {
  { "", "open or close settings" },
  { "on | off | toggle", "enable or disable the overlay" },
  { "preview", "show the aura at full strength" },
  { "start <percent>", "runic power share where the aura appears" },
  { "pulse <percent | off>", "pulse threshold, or turn the pulse off" },
  { "minimap", "show or hide the minimap button" },
  { "status", "current state and runic power" },
  { "reset", "restore default settings" },
}

local function PrintHelp()
  ns.Print("v" .. ns.VERSION .. " commands:")
  for _, line in ipairs(HELP) do
    local usage = line[1] == "" and "/bnorp" or ("/bnorp " .. line[1])
    DEFAULT_CHAT_FRAME:AddMessage("  |cffffd100" .. usage .. "|r  " .. line[2])
  end
end

local function PrintStatus()
  local db = ns.db
  ns.Print(ns.GetStatusText())
  if not ns.isDeathKnight then
    return
  end
  local current = UnitPower("player", ns.POWER_TYPE)
  local max = UnitPowerMax("player", ns.POWER_TYPE)
  local power = "hidden in combat"
  if ns.IsReadable(current) and ns.IsReadable(max) then
    power = current .. "/" .. max
  end
  DEFAULT_CHAT_FRAME:AddMessage(string.format(
    "  runic power %s  ·  appears at %d%%  ·  pulse %s",
    power,
    db.startPercent,
    db.pulse and (db.pulsePercent .. "%") or "off"
  ))
end

local function ParsePercent(arg, usage)
  local value = tonumber(arg)
  if not value then
    ns.Print("usage: /bnorp " .. usage)
  end
  return value
end

local commands = {}

commands.help = PrintHelp
commands.status = PrintStatus

commands.on = function()
  ns.Set("enabled", true)
  ns.Print("enabled")
end

commands.off = function()
  ns.Set("enabled", false)
  ns.Print("disabled")
end

commands.toggle = function()
  if ns.db.enabled then
    commands.off()
  else
    commands.on()
  end
end

commands.preview = function()
  ns.SetPreview(not ns.IsPreviewing())
  ns.Print(ns.IsPreviewing() and "preview on — /bnorp preview again to stop" or "preview off")
end

commands.start = function(arg)
  local value = ParsePercent(arg, "start <percent>")
  if value then
    ns.Print("aura appears at " .. ns.Set("startPercent", value) .. "% runic power")
  end
end
commands.overlay = commands.start

commands.pulse = function(arg)
  if arg == "off" then
    ns.Set("pulse", false)
    ns.Print("pulse off")
    return
  end
  local value = ParsePercent(arg, "pulse <percent | off>")
  if value then
    ns.Set("pulse", true)
    ns.Print("pulse at " .. ns.Set("pulsePercent", value) .. "% runic power")
  end
end

commands.minimap = function()
  ns.SetMinimapHidden(not ns.db.minimap.hide)
  ns.Print(ns.db.minimap.hide and "minimap button hidden" or "minimap button shown")
end

commands.reset = function()
  ns.ResetSettings()
  ns.Print("settings reset to defaults")
end

commands.config = function()
  ns.ToggleOptions()
end
commands.options = commands.config
commands.settings = commands.config
commands[""] = commands.config

SLASH_BDKNEVEROVERCAPRP1 = "/bnorp"
SLASH_BDKNEVEROVERCAPRP2 = "/bdkrp"
SlashCmdList.BDKNEVEROVERCAPRP = function(msg)
  local cmd, arg = (msg or ""):match("^%s*(%S*)%s*(.-)%s*$")
  local handler = commands[(cmd or ""):lower()]
  if handler then
    handler((arg or ""):lower())
  else
    PrintHelp()
  end
end
