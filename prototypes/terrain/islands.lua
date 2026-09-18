-- "Islands" map shape: the whole Simulacruis surface is Nauvis sea
-- dotted with one-planet-per-island landmasses, reached by landfill,
-- instead of the default concentric zone rings.
--
-- Selected per-map from the Map Generator's own Terrain tab, via the
-- "Simulacruis Islands" control: slide its Coverage down to Very Low or
-- Low to use this layout instead of the default ring layout; Normal and
-- above (including the untouched default) keep the default layout.
-- Scale has no effect on this control. Picking the top-level "Island"
-- preset does this automatically (see the bottom of this section).
--
-- Every affected noise expression is wrapped as
-- if(simulacruis_islands_enabled, <islands formula>, <default formula>)
-- rather than replaced outright, so both layouts stay fully available in
-- the same save and the choice can be made without restarting the game
-- the way a startup mod setting would require.
--
-- Known limitations: tungsten-ore and the full-egg-raft placement still
-- read the old zone-radius fields (simulacruis_zone_3_weight/
-- _zone_4_weight), which don't correspond to anything meaningful at this
-- layout's scale, so they place far less reliably here than under the
-- default ring layout.

-- can_be_disabled = false removes the control's own "enable" checkbox —
-- left on, an unchecked checkbox reads as "Islands off" to a player but
-- actually zeroes the Coverage slider underneath, which is what THIS
-- control reads as "Islands ON" (see simulacruis_islands_enabled below).
-- The checkbox and the Coverage slider can't be made to agree here
-- without either flipping which Coverage value means what (making
-- Islands the default for anyone who's never touched this control) or
-- giving the checkbox its own default state (autoplace-control has no
-- such field) — removing it avoids the mismatch entirely. One
-- consequence: with no checkbox, the manual slider can no longer reach
-- None (0) — that value is only reachable by unchecking, which no
-- longer exists — so its own lowest reachable notch is Very Low (0.5).
data:extend({
  { type = "autoplace-control", name = "simulacruis_islands", category = "terrain", order = "simulacruis-terrain-0",
    can_be_disabled = false,
    localised_description = "Slide Coverage down to Very Low or Low to generate Simulacruis using the Islands layout instead of the default ring layout. Normal and above keep the default layout. Scale has no effect here." }
})
data.raw.planet.simulacruis.map_gen_settings.autoplace_controls["simulacruis_islands"] = {}
data:extend({
  { type = "noise-expression", name = "simulacruis_islands_enabled",
    -- Threshold sits between Low (1/sqrt(2) =~ 0.7071, the second-lowest
    -- notch) and Normal (1), so both Very Low and Low count as
    -- "enabled". Kept a bit above 0.7071 itself (rather than the ~0.707
    -- a naive rounding gives) so floating-point representation of that
    -- irrational value can never land just barely on the wrong side.
    expression = "control:simulacruis_islands:size < 0.75" }
})

-- Vanilla's own top-level map generator "Preset" dropdown includes an
-- "Island" entry (data/base/prototypes/map-gen-presets.lua) that
-- pre-configures Nauvis's own elevation formula and a few autoplace
-- controls for that look. Extended here to also drive Simulacruis's own
-- Islands control, so picking that one top-level preset sets up both
-- surfaces consistently instead of leaving Simulacruis for the player to
-- configure by hand.
--
-- Set to 0.5 (Very Low), not 0 (None) — confirmed directly that 0 gets
-- silently ignored: with can_be_disabled = false, this control has no
-- "disabled" state left to represent 0 at all, so anything below its
-- own reachable minimum is simply dropped rather than applied.
local island_preset = data.raw["map-gen-presets"] and data.raw["map-gen-presets"]["default"] and
                       data.raw["map-gen-presets"]["default"]["island"]
if island_preset then
  island_preset.basic_settings = island_preset.basic_settings or {}
  island_preset.basic_settings.autoplace_controls = island_preset.basic_settings.autoplace_controls or {}
  island_preset.basic_settings.autoplace_controls["simulacruis_islands"] = { size = 0.5 }
end

-- ============================================================
-- Island size and spacing reuse Factorio's own "Water" autoplace-control
-- sliders (Map generator > Terrain tab > Water > Coverage/Scale) rather
-- than fixed constants, so they're adjustable from the normal map-gen
-- screen. control:water:size is Coverage (bigger = more sea between
-- islands); control:water:frequency is Scale, inverted (bigger displayed
-- Scale% = smaller raw frequency = bigger islands).
--
-- Size and gap are solved for jointly rather than being independent
-- tile counts: given desired island diameter S and gap G,
--   moat_width = G / 2
--   grid_size  = S + G
-- so each voronoi cell's own radius (grid_size/2) minus its moat leaves
-- exactly S of land, and two moats facing each other leave exactly G of
-- sea — changing G alone widens the gap without shrinking islands, and
-- changing S alone resizes islands without touching the gap.
-- ============================================================

-- BASE_ISLAND_SIZE/BASE_ISLAND_GAP are what the Water sliders' "Normal"
-- (1x/1x) position reproduces; moving either slider scales away from
-- this starting point.
local BASE_ISLAND_SIZE = 800
local BASE_ISLAND_GAP = 20

data:extend({
  -- Average sea gap between neighboring islands (tiles).
  { type = "noise-expression", name = "simulacruis_island_gap",
    expression = BASE_ISLAND_GAP .. " * control:water:size" },
  -- Average island diameter (tiles).
  { type = "noise-expression", name = "simulacruis_island_size",
    expression = BASE_ISLAND_SIZE .. " / control:water:frequency" },
  { type = "noise-expression", name = "simulacruis_island_grid_size",
    expression = "simulacruis_island_size + simulacruis_island_gap" },
  { type = "noise-expression", name = "simulacruis_island_moat_width",
    expression = "simulacruis_island_gap / 2" },
  -- voronoi_pyramid_noise runs from 1 at a cell's own site to 0 at its
  -- edge, roughly linearly over the cell's own radius (grid_size / 2).
  -- "moat_width tiles in from the edge" is therefore roughly
  -- pyramid > 2 * moat_width / grid_size.
  { type = "noise-expression", name = "simulacruis_island_moat_threshold",
    expression = "2 * simulacruis_island_moat_width / simulacruis_island_grid_size" },
  -- Real minimum gap (as a fraction of moat_threshold) guaranteed to
  -- survive between any two neighboring islands regardless of coastline
  -- noise — see simulacruis_island_is_land below.
  { type = "noise-expression", name = "simulacruis_island_no_fusion_floor",
    expression = "simulacruis_island_moat_threshold * 0.85" }
})

-- Fraction of simulacruis_island_pyramid, independent of island size or
-- gap, past which hazard terrain (lava, oil-ocean, ammonia, gleba water)
-- is allowed. Keeps hazards off any island's own coastline.
local INTERIOR_PYRAMID_FRACTION = 0.45

-- Separate, more lenient cutoff for Gleba's own water tiles only —
-- Gleba water blends acceptably with Nauvis's own sea both visually and
-- thematically, unlike lava/oil/ammonia, so it can sit closer to the
-- coast.
local GLEBA_INTERIOR_PYRAMID_FRACTION = 0.28

-- Fraction of voronoi cells that produce no island at all (pure sea).
-- Controls island density/frequency independently of island size and
-- gap above.
local SEA_SHARE = 0.2
local REMAINING = 1 - SEA_SHARE
local AQUILO_TARGET_SHARE = REMAINING * 0.2
local AQUILO_RAMP_RADIUS = 1500

-- Two-layer organic-edge displacement (same technique as biome-regions.
-- lua's own make_wobble): a coarse layer bends each island's edge into a
-- wide curve, a fine layer breaks up the sharp corners where 3+ cells
-- meet.
local function wobble_layer(name_prefix, amplitude, wavelength)
  local x_name = name_prefix .. "_x"
  local y_name = name_prefix .. "_y"
  data:extend({
    { type = "noise-expression", name = x_name,
      expression = "multioctave_noise{x = x, y = y, seed0 = map_seed, seed1 = '" .. x_name .. "',\z
                                      octaves = 2, persistence = 0.5,\z
                                      input_scale = 1/(" .. wavelength .. "),\z
                                      output_scale = (" .. amplitude .. ")}" },
    { type = "noise-expression", name = y_name,
      expression = "multioctave_noise{x = x, y = y, seed0 = map_seed, seed1 = '" .. y_name .. "',\z
                                      octaves = 2, persistence = 0.5,\z
                                      input_scale = 1/(" .. wavelength .. "),\z
                                      output_scale = (" .. amplitude .. ")}" }
  })
  return x_name, y_name
end

local coarse_x, coarse_y = wobble_layer("simulacruis_island_wobble_coarse",
  "simulacruis_island_grid_size * 0.3", "simulacruis_island_grid_size * 0.7")
local fine_x, fine_y = wobble_layer("simulacruis_island_wobble_fine",
  "simulacruis_island_grid_size * 0.06", "simulacruis_island_grid_size * 0.18")
data:extend({
  { type = "noise-expression", name = "simulacruis_island_wobble_x", expression = coarse_x .. " + " .. fine_x },
  { type = "noise-expression", name = "simulacruis_island_wobble_y", expression = coarse_y .. " + " .. fine_y }
})

-- jitter (0.4) bounds how far each cell's own site can wander from its
-- geometric center, as a fraction of grid_size — low enough to keep a
-- sensible margin between an island's hazard interior and its
-- coastline, high enough to still give islands real size variety.
data:extend({
  {
    type = "noise-expression",
    name = "simulacruis_island_cell",
    expression = "voronoi_cell_id{x = x + simulacruis_island_wobble_x, y = y + simulacruis_island_wobble_y,\z
                                  seed0 = map_seed, seed1 = 'simulacruis_island',\z
                                  grid_size = simulacruis_island_grid_size, distance_type = 'euclidean', jitter = 0.4}"
  },
  {
    type = "noise-expression",
    name = "simulacruis_island_pyramid",
    expression = "voronoi_pyramid_noise{x = x + simulacruis_island_wobble_x, y = y + simulacruis_island_wobble_y,\z
                                        seed0 = map_seed, seed1 = 'simulacruis_island',\z
                                        grid_size = simulacruis_island_grid_size, distance_type = 'euclidean', jitter = 0.4}"
  },
  {
    type = "noise-expression",
    name = "simulacruis_island_coast_noise",
    -- Organic coastline shape, added onto the pyramid-based edge-distance
    -- signal for every island. Wavelength (grid_size * 0.4) is large
    -- enough to bend each island's own big-picture outline, not just add
    -- fine texture.
    expression = "multioctave_noise{x = x, y = y, seed0 = map_seed, seed1 = 'simulacruis_island_coast',\z
                                    input_scale = 1/(simulacruis_island_grid_size * 0.4),\z
                                    output_scale = 0.13,\z
                                    octaves = 4, persistence = 0.55}"
  },
  {
    type = "noise-expression",
    name = "simulacruis_island_is_land",
    -- Land requires: not classified as a pure-sea cell; the coastline
    -- (pyramid + organic noise) clears the moat; AND raw pyramid alone
    -- already clears no_fusion_floor, a noise-immune floor guaranteeing
    -- a minimum real gap between neighboring islands regardless of what
    -- the coastline noise does.
    expression = "(simulacruis_island_pyramid > simulacruis_island_no_fusion_floor) *\z
                  ((simulacruis_island_pyramid + simulacruis_island_coast_noise) > simulacruis_island_moat_threshold) *\z
                  (1 - simulacruis_island_is_sea)"
  },
  {
    type = "noise-expression",
    name = "simulacruis_island_interior_fade",
    -- Independent noise blending the hazard-interior cutoff, so hazard
    -- terrain near its own margin thins into a scattered fringe instead
    -- of stopping at a hard line. Kept separate from coast_noise so a
    -- coastline bulge can never simultaneously count as "interior".
    expression = "multioctave_noise{x = x, y = y, seed0 = map_seed, seed1 = 'simulacruis_island_interior_fade',\z
                                    input_scale = 1/30, output_scale = 0.09,\z
                                    octaves = 3, persistence = 0.5}"
  },
  {
    type = "noise-expression",
    name = "simulacruis_island_is_interior",
    -- Hazard-safe margin: raw pyramid plus the independent fade noise,
    -- past INTERIOR_PYRAMID_FRACTION.
    expression = "(simulacruis_island_pyramid + simulacruis_island_interior_fade) > " .. INTERIOR_PYRAMID_FRACTION
  },
  {
    type = "noise-expression",
    name = "simulacruis_island_is_interior_gleba",
    -- Same margin, lenient cutoff, for Gleba's own water tiles.
    expression = "(simulacruis_island_pyramid + simulacruis_island_interior_fade) > " .. GLEBA_INTERIOR_PYRAMID_FRACTION
  },
  {
    type = "noise-expression",
    name = "simulacruis_island_aquilo_share",
    expression = AQUILO_TARGET_SHARE .. " * clamp(distance / " .. AQUILO_RAMP_RADIUS .. ", 0, 1)"
  },
  {
    type = "noise-expression",
    name = "simulacruis_island_other_share",
    expression = "(" .. REMAINING .. " - simulacruis_island_aquilo_share) / 4"
  }
})

-- Cumulative-threshold partition over island_cell's own [0,1] range,
-- same pattern as biome-regions.lua's own add_zone_partition: "sea" is
-- the first slot, then Nauvis/Vulcanus/Fulgora/Gleba/Aquilo split the
-- remainder. Boundaries are built by repeated addition of the same
-- named share rather than an integer multiple of it, matching
-- add_zone_partition's own convention.
data:extend({
  { type = "noise-expression", name = "simulacruis_island_is_sea",
    expression = "simulacruis_island_cell < " .. SEA_SHARE },
  { type = "noise-expression", name = "simulacruis_island_boundary_1",
    expression = SEA_SHARE .. " + simulacruis_island_other_share" },
  { type = "noise-expression", name = "simulacruis_island_boundary_2",
    expression = "simulacruis_island_boundary_1 + simulacruis_island_other_share" },
  { type = "noise-expression", name = "simulacruis_island_boundary_3",
    expression = "simulacruis_island_boundary_2 + simulacruis_island_other_share" },
  { type = "noise-expression", name = "simulacruis_island_boundary_4",
    expression = "simulacruis_island_boundary_3 + simulacruis_island_other_share" },
})
data:extend({
  { type = "noise-expression", name = "simulacruis_island_is_nauvis",
    expression = "(simulacruis_island_cell >= " .. SEA_SHARE .. ") * (simulacruis_island_cell < simulacruis_island_boundary_1)" },
  { type = "noise-expression", name = "simulacruis_island_is_vulcanus",
    expression = "(simulacruis_island_cell >= simulacruis_island_boundary_1) * (simulacruis_island_cell < simulacruis_island_boundary_2)" },
  { type = "noise-expression", name = "simulacruis_island_is_fulgora",
    expression = "(simulacruis_island_cell >= simulacruis_island_boundary_2) * (simulacruis_island_cell < simulacruis_island_boundary_3)" },
  { type = "noise-expression", name = "simulacruis_island_is_gleba",
    expression = "(simulacruis_island_cell >= simulacruis_island_boundary_3) * (simulacruis_island_cell < simulacruis_island_boundary_4)" },
  { type = "noise-expression", name = "simulacruis_island_is_aquilo",
    expression = "simulacruis_island_cell >= simulacruis_island_boundary_4" }
})

-- Guaranteed starting island, built with vanilla's own "Island" map-gen
-- preset technique (elevation_island / make_0_12like_lakes in
-- data/core/prototypes/noise-programs.lua) rather than a hand-built
-- shape — real multi-octave fractal noise with a radial falloff term,
-- so it reads as an organic coastline at every zoom level instead of a
-- stitched-together set of primitives.
--
-- bias = -1000 makes the function's alternate "lake" branch permanently
-- lose to the main radial-falloff branch, producing one landmass.
-- segmentation_multiplier controls the falloff rate (bigger = faster
-- falloff = smaller island); it uses raw control:water:frequency
-- directly, the same convention vanilla's own elevation_island uses.
local BASE_START_SEGMENTATION = 0.72
data:extend({
  { type = "noise-expression", name = "simulacruis_island_start_segmentation",
    expression = BASE_START_SEGMENTATION .. " * control:water:frequency" },
  { type = "noise-expression", name = "simulacruis_island_start_elevation",
    expression = "finish_elevation{\z
      elevation = make_0_12like_lakes{x = x, y = y, bias = -1000, terrain_octaves = 8,\z
                                       segmentation_multiplier = simulacruis_island_start_segmentation},\z
      segmentation_multiplier = simulacruis_island_start_segmentation}" },
  { type = "noise-expression", name = "simulacruis_island_is_start_natural_land",
    expression = "simulacruis_island_start_elevation > 0" }
})

-- The start island's own territory is decided by an additively-weighted
-- Voronoi contest rather than an absolute distance/circle test, so a
-- neighboring island's own natural shape is never sliced off along an
-- arbitrary arc: the origin gets a fixed distance bonus and competes
-- against each neighboring cell's own site distance
-- ((1 - pyramid) * grid_size / 2), the same way every ordinary cell
-- already competes with its neighbors.
local START_BONUS = 250
data:extend({
  { type = "noise-expression", name = "simulacruis_island_natural_site_distance",
    expression = "(1 - simulacruis_island_pyramid) * (simulacruis_island_grid_size / 2)" },
  { type = "noise-expression", name = "simulacruis_island_start_boundary_noise",
    -- The fair bisector of an additively-weighted contest between two
    -- points is a circular arc (Apollonius circle); large-wavelength
    -- noise bends that arc into an organic curve, the same technique
    -- simulacruis_island_coast_noise uses for individual coastlines.
    expression = "multioctave_noise{x = x, y = y, seed0 = map_seed, seed1 = 'simulacruis_island_start_boundary',\z
                                    input_scale = 1/250, output_scale = 150,\z
                                    octaves = 4, persistence = 0.55}" }
})
local START_BLEND_WIDTH = 150
data:extend({
  { type = "noise-expression", name = "simulacruis_island_start_blend",
    -- 1 where the origin's bonus-adjusted distance beats the natural
    -- cell, 0 where the natural cell wins, blended over
    -- START_BLEND_WIDTH of margin either side of the tie.
    expression = "clamp((simulacruis_island_natural_site_distance - (distance - " .. START_BONUS ..
                  ") + simulacruis_island_start_boundary_noise) / " .. START_BLEND_WIDTH .. ", 0, 1)" },
  { type = "noise-expression", name = "simulacruis_island_is_start_core_land",
    -- Small always-land safety net directly under spawn.
    expression = "distance < 60" },
  { type = "noise-expression", name = "simulacruis_island_is_start_land",
    expression = "max(simulacruis_island_is_start_core_land, simulacruis_island_is_start_natural_land)" },
  { type = "noise-expression", name = "simulacruis_island_is_land_effective",
    expression = "simulacruis_island_start_blend * simulacruis_island_is_start_land +\z
                  (1 - simulacruis_island_start_blend) * simulacruis_island_is_land" }
})

-- Wraps name's existing (default-layout) expression rather than
-- replacing it, so switching simulacruis_islands_enabled off at
-- generation time falls straight back to the original ring-shape
-- behavior with no separate code path to maintain.
local function override(name, islands_expression)
  local default_expression = data.raw["noise-expression"][name].expression
  data.raw["noise-expression"][name].expression =
    "if(simulacruis_islands_enabled > 0.5,\z
        (" .. islands_expression .. "),\z
        (" .. default_expression .. "))"
end

override("simulacruis_nauvis_weight",
  "simulacruis_island_start_blend * 1 +\z
   (1 - simulacruis_island_start_blend) * if(simulacruis_island_is_land > 0.5, simulacruis_island_is_nauvis, 1)")
override("simulacruis_vulcanus_weight",
  "(1 - simulacruis_island_start_blend) * simulacruis_island_is_land * simulacruis_island_is_vulcanus")
override("simulacruis_fulgora_weight",
  "(1 - simulacruis_island_start_blend) * simulacruis_island_is_land * simulacruis_island_is_fulgora")
override("simulacruis_gleba_weight",
  "(1 - simulacruis_island_start_blend) * simulacruis_island_is_land * simulacruis_island_is_gleba")
override("simulacruis_aquilo_weight",
  "(1 - simulacruis_island_start_blend) * simulacruis_island_is_land * simulacruis_island_is_aquilo")

-- Lava/heavy-oil are gated off any island's coastline (simulacruis_
-- island_is_interior) and follow a distance-based chance ramp from the
-- map's own origin — near-zero right at spawn, full chance by
-- HAZARD_RAMP_RADIUS — mirroring the default ring shape's own
-- "dangerous terrain only appears further from home" progression.
-- Reuses simulacruis_island_interior_fade so the ramp-in reads as a
-- gradual thinning-out rather than a hard ring. Tied to grid_size so it
-- scales automatically with island size/gap.
local HAZARD_RAMP_RADIUS = "simulacruis_island_grid_size * 3"
data:extend({
  { type = "noise-expression", name = "simulacruis_island_hazard_zone_ramp",
    expression = "clamp(distance / (" .. HAZARD_RAMP_RADIUS .. "), 0, 1)" },
  { type = "noise-expression", name = "simulacruis_island_hazard_zone_gate",
    expression = "(simulacruis_island_hazard_zone_ramp + simulacruis_island_interior_fade) > 0.5" }
})
override("simulacruis_vulcanus_zone_4_gate",
  "min(simulacruis_vulcanus_weight, min(simulacruis_island_is_interior, simulacruis_island_hazard_zone_gate))")
override("simulacruis_fulgora_zone_4_gate",
  "min(simulacruis_fulgora_weight, min(simulacruis_island_is_interior, simulacruis_island_hazard_zone_gate))")

-- Aquilo's impassable tiles (ammoniacal ocean, brash-ice) stay off the
-- coastline the same way, via the passthrough gate tiles.lua exposes
-- for them independent of its ordinary snow/ice tiles.
override("simulacruis_aquilo_hazard_gate",
  "min(simulacruis_aquilo_weight, simulacruis_island_is_interior)")

-- Gleba's water tiles (gleba-deep-lake and every wetland-* tile) get the
-- same coastline treatment, using the lenient cutoff since they blend
-- acceptably with Nauvis's own sea.
override("simulacruis_gleba_water_gate",
  "min(simulacruis_gleba_weight, simulacruis_island_is_interior_gleba)")

-- Demolishers (planet-demolishers.lua) are placed via territory_settings,
-- not autoplace, keyed here to the island layout's own geometry:
-- territory_index reuses simulacruis_island_cell directly (one voronoi
-- cell IS one island). territory_variation requires real Vulcanus land
-- that the guaranteed start island hasn't already claimed
-- (1 - simulacruis_island_start_blend), so every Vulcanus island gets
-- demolishers without any spawning inside the safe start zone. Tier
-- (small/medium/big) scales with absolute distance from the origin.
override("simulacruis_demolisher_territory_index", "simulacruis_island_cell")
local DEMOLISHER_TIER_SPAN = 1000
override("simulacruis_demolisher_territory_variation",
  "if(min(simulacruis_island_is_land * simulacruis_island_is_vulcanus,\z
          1 - simulacruis_island_start_blend) > 0.5,\z
     floor(clamp(distance / " .. DEMOLISHER_TIER_SPAN .. ", 0, 2)),\z
     -1)")

-- Islands are meant to meet open water at their coastline, so the zone
-- system's own elevation lift at zone-radius seams is disabled while
-- this layout is active.
override("simulacruis_land_bridge_boost", "0")

-- The weight blends above gate TILES correctly, but elevation still
-- needs its own blend: left alone, "sea" would render with Nauvis's
-- natural (mostly above-water) elevation formula, contiguous with every
-- real Nauvis island. Forced to a fixed deep value off any land instead.
local SEA_ELEVATION = -50
override("simulacruis_elevation",
  "if(simulacruis_island_is_land_effective > 0.5,\z
     if(simulacruis_nauvis_weight > 0.5, elevation_nauvis,\z
     if(simulacruis_vulcanus_weight > 0.5, vulcanus_elevation,\z
     if(simulacruis_fulgora_weight > 0.5, fulgora_elevation,\z
     if(simulacruis_gleba_weight > 0.5, gleba_elevation,\z
        aquilo_elevation)))),\z
     " .. SEA_ELEVATION .. ")")
