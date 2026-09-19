-- Startup base radius per zone (see settings.lua), combined with a live
-- per-map Terrain Coverage slider that scales away from it. Coverage =
-- None collapses a zone into the previous zone's radius; setting the
-- base itself to 0 (or at/below the previous zone's base) does the same
-- permanently.
local BASE_ZONE_1_RADIUS = settings.startup["simulacruis-zone-1-radius"].value
local BASE_ZONE_2_RADIUS = settings.startup["simulacruis-zone-2-radius"].value
local BASE_ZONE_3_RADIUS = settings.startup["simulacruis-zone-3-radius"].value
data:extend({
  { type = "autoplace-control", name = "simulacruis_zone_1_radius", category = "terrain", order = "simulacruis-a-zone-radius-1",
    localised_description = "Only Coverage affects this zone's radius. Scale has no effect here." },
  { type = "autoplace-control", name = "simulacruis_zone_2_radius", category = "terrain", order = "simulacruis-a-zone-radius-2",
    localised_description = "Only Coverage affects this zone's radius. Scale has no effect here." },
  { type = "autoplace-control", name = "simulacruis_zone_3_radius", category = "terrain", order = "simulacruis-a-zone-radius-3",
    localised_description = "Only Coverage affects this zone's radius. Scale has no effect here." },
})

-- Effective radius per zone, floored to at least the previous zone's own
-- so a zone can never end up smaller than its inner neighbor. Consumed
-- directly by biome-regions.lua and planet-demolishers.lua.
data:extend({
  { type = "noise-expression", name = "simulacruis_zone_1_radius_value",
    expression = "max(" .. BASE_ZONE_1_RADIUS .. " * control:simulacruis_zone_1_radius:size, 0)" },
  { type = "noise-expression", name = "simulacruis_zone_2_radius_value",
    expression = "max(" .. BASE_ZONE_2_RADIUS .. " * control:simulacruis_zone_2_radius:size, simulacruis_zone_1_radius_value)" },
  { type = "noise-expression", name = "simulacruis_zone_3_radius_value",
    expression = "max(" .. BASE_ZONE_3_RADIUS .. " * control:simulacruis_zone_3_radius:size, simulacruis_zone_2_radius_value)" },
})

-- Floor for ring-width-derived quantities, so a collapsed zone never
-- drives a grid size to 0 (VoronoiNoise requires grid_size >= 1).
local RING_WIDTH_FLOOR = 10
data:extend({
  { type = "noise-expression", name = "simulacruis_zone_2_ring_width",
    expression = "max(simulacruis_zone_2_radius_value - simulacruis_zone_1_radius_value, " .. RING_WIDTH_FLOOR .. ")" },
  { type = "noise-expression", name = "simulacruis_zone_3_ring_width",
    expression = "max(simulacruis_zone_3_radius_value - simulacruis_zone_2_radius_value, " .. RING_WIDTH_FLOOR .. ")" },
})

-- Each zone boundary is a real fractal terrain field (the same technique
-- vanilla's Nauvis "Island" preset and this mod's own start island use),
-- radially biased so it's high near the origin and low far away —
-- thresholding it produces an organic coastline-like outline instead of
-- a circle.
--
-- Each zone gets its own field, scaled to its own target radius via
-- segmentation_multiplier, so coastline detail looks proportionate at
-- every zone's own size. Nesting (Zone 1 inside Zone 2 inside Zone 3) is
-- guaranteed by max()'ing each zone's field against the previous zone's
-- own field before use, so a zone's effective boundary can never fall
-- inside its inner neighbor's.
--
-- 200 is fitted to make_0_12like_lakes's own falloff at Water Coverage
-- "Normal": its zero-elevation contour sits at roughly
-- distance = 200 / segmentation_multiplier tiles.
local ZONE_SEGMENTATION_FIT = 200
local function organic_zone_field(radius_value_expr)
  local segmentation_expr = ZONE_SEGMENTATION_FIT .. " / max(" .. radius_value_expr .. ", " .. RING_WIDTH_FLOOR .. ")"
  return "make_0_12like_lakes{x = x, y = y, bias = -1000, terrain_octaves = 8,\z
                              segmentation_multiplier = (" .. segmentation_expr .. ")}"
end

data:extend({
  { type = "noise-expression", name = "simulacruis_zone_1_field",
    expression = organic_zone_field("simulacruis_zone_1_radius_value") },
  { type = "noise-expression", name = "simulacruis_zone_2_field_raw",
    expression = organic_zone_field("simulacruis_zone_2_radius_value") },
  { type = "noise-expression", name = "simulacruis_zone_2_field",
    expression = "max(simulacruis_zone_1_field, simulacruis_zone_2_field_raw)" },
  { type = "noise-expression", name = "simulacruis_zone_3_field_raw",
    expression = organic_zone_field("simulacruis_zone_3_radius_value") },
  { type = "noise-expression", name = "simulacruis_zone_3_field",
    expression = "max(simulacruis_zone_2_field, simulacruis_zone_3_field_raw)" },
})

-- Smooth crossfade width (in the field's own elevation-like units)
-- around each field's own zero-crossing: 0 deep inside, 1 deep outside,
-- 0.5 exactly on the boundary.
local ZONE_BLEND_WIDTH = 4
data:extend({
  { type = "noise-expression", name = "simulacruis_zone_step_1",
    expression = "clamp(0.5 - simulacruis_zone_1_field / (2 * " .. ZONE_BLEND_WIDTH .. "), 0, 1)" },
  { type = "noise-expression", name = "simulacruis_zone_step_2",
    expression = "clamp(0.5 - simulacruis_zone_2_field / (2 * " .. ZONE_BLEND_WIDTH .. "), 0, 1)" },
  { type = "noise-expression", name = "simulacruis_zone_step_3",
    expression = "clamp(0.5 - simulacruis_zone_3_field / (2 * " .. ZONE_BLEND_WIDTH .. "), 0, 1)" },
  { type = "noise-expression", name = "simulacruis_zone_1_weight",
    expression = "1 - simulacruis_zone_step_1" },
  { type = "noise-expression", name = "simulacruis_zone_2_weight",
    expression = "simulacruis_zone_step_1 - simulacruis_zone_step_2" },
  { type = "noise-expression", name = "simulacruis_zone_3_weight",
    expression = "simulacruis_zone_step_2 - simulacruis_zone_step_3" },
  { type = "noise-expression", name = "simulacruis_zone_4_weight",
    expression = "simulacruis_zone_step_3" },
})

-- Separate from the zone boundaries above: planet-demolishers.lua's own
-- tiering keys off this wobbled distance instead.
data:extend({
  { type = "noise-expression", name = "simulacruis_wobbled_distance",
    expression = "distance + multioctave_noise{x = x, y = y, seed0 = map_seed, seed1 = 'simulacruis_radius_wobble',\z
                                               octaves = 3, persistence = 0.5, input_scale = 1/250, output_scale = 50}" }
})
