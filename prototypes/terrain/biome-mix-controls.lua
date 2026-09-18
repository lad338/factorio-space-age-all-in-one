-- Exposes the per-planet "Terrain" map-gen controls AND the per-zone
-- "Patch Size" controls (autoplace-control prototypes + the noise-
-- expressions reading their value are already defined in
-- biome-regions.lua) on Simulacruis's own map_gen_settings.
-- autoplace_controls, matching the existing pattern planet-resources.lua
-- uses for its own exposed resource controls.
--
-- Split into its own file, required AFTER planet-simulacruis.lua,
-- because biome-regions.lua itself runs BEFORE planet-simulacruis.lua
-- creates data.raw.planet.simulacruis in the first place (see the
-- comment there) — this step needs the planet prototype to already
-- exist.
local planet = data.raw.planet.simulacruis
local controls = {
  "simulacruis_zone_1_radius",
  "simulacruis_zone_2_radius",
  "simulacruis_zone_3_radius",
  "simulacruis_nauvis_terrain",
  "simulacruis_vulcanus_terrain",
  "simulacruis_fulgora_terrain",
  "simulacruis_gleba_terrain",
  "simulacruis_aquilo_terrain",
  "simulacruis_zone_2_patch_scale",
  "simulacruis_zone_3_patch_scale",
  "simulacruis_zone_4_patch_scale",
}
for _, name in ipairs(controls) do
  planet.map_gen_settings.autoplace_controls[name] = {}
end
