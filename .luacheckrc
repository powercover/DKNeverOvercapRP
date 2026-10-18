std = "lua51"
max_line_length = false
unused_args = false
exclude_files = { ".release/" }

globals = {
  "DKNORP_DB",
}

read_globals = {
  -- Lua extensions
  "wipe",
  -- Midnight secret values
  "canaccessvalue",
  "issecretvalue",
  -- API
  "C_AddOns",
  "C_CurveUtil",
  "CreateFont",
  "CreateColor",
  "CreateFrame",
  "Enum",
  "GetSpecialization",
  "GetSpecializationInfoForClassID",
  "InCombatLockdown",
  "PlaySound",
  "UnitClass",
  "UnitPower",
  "UnitPowerMax",
  "UnitPowerPercent",
  -- FrameXML
  "ColorPickerFrame",
  "GameTooltip",
  "GameTooltip_Hide",
  "Settings",
  "SOUNDKIT",
  "STANDARD_TEXT_FONT",
  "UIParent",
}
