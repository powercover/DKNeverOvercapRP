std = "lua51"
max_line_length = false
unused_args = false
exclude_files = { ".release/" }

globals = {
  "BDKNORP_DB",
  "SlashCmdList",
  "SLASH_BDKNEVEROVERCAPRP1",
  "SLASH_BDKNEVEROVERCAPRP2",
  "BDKNeverOvercapRP_OnCompartmentClick",
  "BDKNeverOvercapRP_OnCompartmentEnter",
  "BDKNeverOvercapRP_OnCompartmentLeave",
}

read_globals = {
  -- Lua extensions
  "tinsert",
  "wipe",
  -- Midnight secret values
  "canaccessvalue",
  "issecretvalue",
  -- API
  "C_AddOns",
  "C_CurveUtil",
  "CreateColor",
  "CreateFrame",
  "Enum",
  "GetCursorPosition",
  "GetSpecialization",
  "GetSpecializationInfoForClassID",
  "HideUIPanel",
  "InCombatLockdown",
  "PlaySound",
  "UnitClass",
  "UnitPower",
  "UnitPowerMax",
  "UnitPowerPercent",
  -- FrameXML
  "ColorPickerFrame",
  "DEFAULT_CHAT_FRAME",
  "GameTooltip",
  "GameTooltip_Hide",
  "MinimalSliderWithSteppersMixin",
  "Minimap",
  "Settings",
  "SettingsPanel",
  "SOUNDKIT",
  "UIDropDownMenu_AddButton",
  "UIDropDownMenu_CreateInfo",
  "UIDropDownMenu_Initialize",
  "UIDropDownMenu_SetText",
  "UIDropDownMenu_SetWidth",
  "UIParent",
  "UISpecialFrames",
}
