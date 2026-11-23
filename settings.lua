data:extend({
  {
    type = "int-setting",
    name = "simulacruis-zone-1-radius",
    setting_type = "startup",
    default_value = 300,
    minimum_value = 0,
    order = "a"
  },
  {
    type = "int-setting",
    name = "simulacruis-zone-2-radius",
    setting_type = "startup",
    default_value = 1000,
    minimum_value = 0,
    order = "b"
  },
  {
    type = "int-setting",
    name = "simulacruis-zone-3-radius",
    setting_type = "startup",
    default_value = 3000,
    minimum_value = 0,
    order = "c"
  },
  {
    type = "bool-setting",
    name = "simulacruis-starter-oil-patch",
    setting_type = "startup",
    default_value = false,
    order = "d"
  },
  {
    type = "bool-setting",
    name = "simulacruis-scrap-from-start",
    setting_type = "startup",
    default_value = false,
    order = "e"
  },
  {
    type = "bool-setting",
    name = "simulacruis-enable-aquilo-freezing",
    setting_type = "startup",
    default_value = false,
    order = "f"
  },
  {
    type = "bool-setting",
    name = "simulacruis-enable-fulgora-lightning",
    setting_type = "startup",
    default_value = false,
    order = "g"
  },
  {
    type = "int-setting",
    name = "simulacruis-vulcanus-hazard-zone",
    setting_type = "startup",
    default_value = 3,
    allowed_values = { 2, 3, 4 },
    order = "h"
  },
  {
    type = "bool-setting",
    name = "simulacruis-fulgora-full-size-scrap",
    setting_type = "startup",
    default_value = false,
    order = "i"
  },
  {
    type = "int-setting",
    name = "simulacruis-vulcanus-lava-zone",
    setting_type = "startup",
    default_value = 4,
    allowed_values = { 2, 3, 4 },
    order = "j"
  },
  {
    type = "int-setting",
    name = "simulacruis-fulgora-oil-sea-zone",
    setting_type = "startup",
    default_value = 4,
    allowed_values = { 2, 3, 4 },
    order = "k"
  }
})
