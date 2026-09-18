-- Zone radii, again (see zone-masks.lua for the zone-weight machinery
-- and the Zone radius controls that now actually drive it) — needed
-- here purely to size this file's own patch/grid geometry below.
--
-- Deliberately frozen at these exact defaults, NOT read from the Zone
-- radius controls the way zone-masks.lua's own zone boundaries now are:
-- voronoi_cell_id's grid_size must be a spatial constant (uniform across
-- the whole map, never varying with x/y — see this file's own note
-- further down), which a runtime control value satisfies fine on its
-- own, but the GRID SIZES below are also built from ring widths derived
-- from TWO radii at once (zone_2_radius - zone_1_radius, etc.), and
-- threading that through the same skip/floor logic as zone-masks.lua
-- for every downstream grid size was judged not worth the added
-- complexity for a purely cosmetic patch-texture concern. Zone
-- boundaries — which planet owns which area — fully react to the new
-- controls regardless; only how big each zone's internal biome patches
-- look stays anchored to the original defaults, independently
-- adjustable via the Patch Size controls below either way.
local zone_1_radius = 300
local zone_2_radius = 1000
local zone_3_radius = 3000

-- Floors every ring-width-derived quantity below (grid sizes here, and
-- zone-masks.lua's transition widths/wobble amplitudes) to a small but
-- non-zero value, rather than letting a skipped zone's ring width
-- reach a literal 0 — that crashes with "VoronoiNoise::grid_size
-- must be in [1, 65536] range", since these fields get evaluated
-- across the WHOLE map regardless of whether the owning zone is
-- actually present anywhere (see the land-bridge boost BUG note
-- further down this file). 10 is comfortably above the minimum needed
-- to keep every derived grid_size (down to patch_density * the
-- smallest scale tier's 0.5x multiplier in ZONE_PATCH_SIZE_SLOTS
-- below, i.e. 10 * 0.3 * 0.5 = 1.5) at least 1 — while still reading
-- as "invisible" in practice, since a real zone ring is hundreds to
-- thousands of tiles wide.
local RING_WIDTH_FLOOR = 10

-- Recurring "one step further out" distance unit for Zone 4's unbounded
-- band growth below, sized off the zone-3-ring's own width. If Zone 3
-- is actually skipped, falling back to the bare RING_WIDTH_FLOOR here
-- (like every other ring-width use) would make Zone 4's own
-- band0->band1->band2 grid sizes collapse to single-digit tile
-- footprints, since they're all derived from this one value — showing
-- up as a "confetti" of tiny patches covering the whole map, not just
-- a cosmetic footnote. Zone 4's own
-- internal patch-growth texture isn't tied to any specific remaining
-- radius setting once Zone 3 is gone, so it falls back to the DEFAULT
-- zone_3_ring_width (3000 - 1000) instead — i.e. "Zone 4 looks the way
-- it would on an unmodified map" — rather than a degenerate one.
local DEFAULT_ZONE_3_RING_WIDTH = 2000
local zone_3_skipped = zone_3_radius <= zone_2_radius
local ring_width = zone_3_skipped and DEFAULT_ZONE_3_RING_WIDTH or math.max(zone_3_radius - zone_2_radius, RING_WIDTH_FLOOR)

-- Voronoi grid sizes (patch sizes), computed from the zone geometry
-- above rather than hand-picked literals, so these self-scale correctly
-- if the radii settings ever change again instead of going stale the
-- way the old hardcoded literals did. `patch_density` is a single
-- tunable knob: grid_size = ring_width * patch_density, so a "near"
-- patch spans roughly 1/patch_density-th of its zone ring's own width
-- (e.g. 0.3 → about 3 patches across the ring, radially, before
-- doubling/tripling for the "further out = bigger" far/band tiers).
-- First cut used patch_density = 1.0 (one patch ≈ the whole ring
-- width) — technically the same relative density the original hand-
-- tuned test-scale values (140/220/300 at radii 80/220/500) had, but
-- at production scale that meant a single biome patch could take
-- several minutes to walk across, reading as one big blob rather than
-- a mixture. Lowered to 0.3 so a zone ring shows multiple distinct
-- patches within an ordinary walk instead of just one.
local patch_density = 0.3
local zone_2_ring_width = math.max(zone_2_radius - zone_1_radius, RING_WIDTH_FLOOR)
local zone_3_ring_width = math.max(zone_3_radius - zone_2_radius, RING_WIDTH_FLOOR)
local zone_2_grid_near = zone_2_ring_width * patch_density
local zone_2_grid_far = zone_2_grid_near * 2
local zone_3_grid_near = zone_3_ring_width * patch_density
local zone_3_grid_far = zone_3_grid_near * 2
local zone_4_grid_band0 = ring_width * patch_density
local zone_4_grid_band1 = zone_4_grid_band0 * 2
local zone_4_grid_band2 = zone_4_grid_band0 * 3

-- Each voronoi grid below gets its OWN coordinate wobble (a displacement
-- added to x/y before the voronoi lookup), sized proportionally to that
-- grid's own cell size — NOT the borrowed vulcanus_wobble_x/y used
-- previously. Checked vulcanus_wobble_x/y's own definition: magnitude=4
-- at an 8-tile wavelength — tuned for Vulcanus's own small-scale rock
-- texture, and essentially invisible against cells spanning 140-900
-- tiles, which is exactly why biome boundaries (most visible where they
-- cut across Aquilo's ocean) were still reading as near-straight
-- voronoi polygon edges. (Like grid_size itself, a noise primitive's
-- own parameters — here input_scale/output_scale — must be spatial
-- constants, so these are baked in per-band at data stage rather than
-- computed as a single shared expression.)
--
-- Two layers, added together, not one:
-- - "coarse": large amplitude/wavelength, bends each EDGE into a wide
--   organic curve (the original fix).
-- - "fine": small amplitude, short wavelength, layered on top. Bending
--   edges alone can't fix corners — wherever 3+ cells meet, the
--   boundary's direction still changes abruptly right at that point no
--   matter how wavy the edges leading into it are (domain-warping a
--   tessellation moves a vertex around but can't remove the "3 regions
--   meet here" topology). The fine layer instead scatters *where*
--   exactly that point sits at a much shorter wavelength, breaking the
--   single crisp corner up into a rougher, less obviously pointed
--   texture, without visibly disturbing the coarse shape (its amplitude
--   is a fraction of the coarse layer's).
local wobble_prototypes = {}
local function make_wobble_layer(name_prefix, grid_size, amplitude_frac, wavelength_frac)
  local amplitude = grid_size * amplitude_frac
  local wavelength = grid_size * wavelength_frac
  local x_name = name_prefix .. "_x"
  local y_name = name_prefix .. "_y"
  table.insert(wobble_prototypes, {
    type = "noise-expression",
    name = x_name,
    expression = "multioctave_noise{x = x, y = y, seed0 = map_seed, seed1 = '" .. x_name .. "',\z
                                    octaves = 2, persistence = 0.5,\z
                                    input_scale = " .. (1 / wavelength) .. ",\z
                                    output_scale = " .. amplitude .. "}"
  })
  table.insert(wobble_prototypes, {
    type = "noise-expression",
    name = y_name,
    expression = "multioctave_noise{x = x, y = y, seed0 = map_seed, seed1 = '" .. y_name .. "',\z
                                    octaves = 2, persistence = 0.5,\z
                                    input_scale = " .. (1 / wavelength) .. ",\z
                                    output_scale = " .. amplitude .. "}"
  })
  return x_name, y_name
end

local function make_wobble(name_prefix, grid_size)
  local coarse_x, coarse_y = make_wobble_layer(name_prefix .. "_wobble", grid_size, 0.35, 1.2)
  local fine_x, fine_y = make_wobble_layer(name_prefix .. "_corner_wobble", grid_size, 0.08, 0.2)
  local total_x_name = name_prefix .. "_wobble_total_x"
  local total_y_name = name_prefix .. "_wobble_total_y"
  table.insert(wobble_prototypes, { type = "noise-expression", name = total_x_name, expression = coarse_x .. " + " .. fine_x })
  table.insert(wobble_prototypes, { type = "noise-expression", name = total_y_name, expression = coarse_y .. " + " .. fine_y })
  return total_x_name, total_y_name
end

-- One voronoi cell grid per zone, giving each zone its own patchwork of
-- same-biome regions. cell_id is a pseudo-random value in [0,1] per
-- cell (same technique Fulgora's own island typing uses via
-- fulgora_cells); thresholding it partitions cells into biomes at each
-- zone's own target biome mix ratio.
--
-- "Further from center = bigger, more continuous biome" is built as a
-- handful of discrete, fixed-size voronoi grids per zone, hard-selected
-- by (wobbled) distance — NOT a single grid whose size scales with
-- distance. voronoi_cell_id's grid_size must be a spatial *constant* —
-- voronoi needs a fixed pitch to build its spatial hash. Vanilla
-- Fulgora's own fulgora_grid follows the same rule: it's a formula,
-- but only over a *setting* (spatially uniform across
-- the whole map), never over x/y/distance. And selecting between two
-- separate cell-id fields must be a hard if()-select, never a blend —
-- same reasoning as the elevation/aux hard-select fix elsewhere:
-- blending two unrelated voronoi fields' cell ids produces meaningless
-- intermediate values, not a sensible in-between patch.
--
-- Each voronoi_cell_id call below has a matching voronoi_pyramid_noise
-- call using the exact same x/y/seed1/grid_size/jitter — matching
-- vanilla Fulgora's own fulgora_cells + fulgora_pyramids pattern, which
-- gives a companion field over the SAME lattice: 0 right at a
-- cell's shared edge with its neighbor, rising toward ~1 at the cell's
-- own center. That's a ready-made "distance to nearest biome boundary"
-- signal, used below to build the land-bridge boost.
local function voronoi_band(cell_name, pyramid_name, wobble_x, wobble_y, seed1, grid_size)
  return {
    {
      type = "noise-expression", name = cell_name,
      expression = "voronoi_cell_id{x = x + " .. wobble_x .. ", y = y + " .. wobble_y .. ",\z
                                    seed0 = map_seed, seed1 = '" .. seed1 .. "',\z
                                    grid_size = " .. grid_size .. ", distance_type = 'euclidean', jitter = 1}"
    },
    {
      type = "noise-expression", name = pyramid_name,
      expression = "voronoi_pyramid_noise{x = x + " .. wobble_x .. ", y = y + " .. wobble_y .. ",\z
                                          seed0 = map_seed, seed1 = '" .. seed1 .. "',\z
                                          grid_size = " .. grid_size .. ", distance_type = 'euclidean', jitter = 1}"
    }
  }
end

local voronoi_prototypes = {}
local function add_band(...)
  for _, proto in ipairs(voronoi_band(...)) do table.insert(voronoi_prototypes, proto) end
end

-- Per-zone "Patch Size" map-gen sliders: one "terrain" category
-- autoplace-control per zone, read via its Scale (frequency) value —
-- Coverage (size) is left inert on these, the mirror image of the
-- five per-planet Terrain controls where only Coverage does anything
-- (see their own tooltip below for the matching disclosure there).
--
-- Hard-selects between 3 pre-built size tiers (0.5x/1x/2x this zone's
-- own baseline grid size) — the exact same mechanism the distance-based
-- near/far/band tiering below already uses successfully, NOT the
-- per-planet competing-grid approach that was tried and reverted for
-- Scale on the Terrain controls (that one needed several INDEPENDENT
-- grids racing each other via argmax, which produced messy angular
-- boundaries; this is just picking a different single pre-built grid,
-- exactly like near vs. far already does, so it carries none of that
-- risk). Discrete tiers rather than a continuous read into grid_size
-- because grid_size must be a spatial constant, unavailable from a
-- runtime control value — same constraint noted throughout this file.
--
-- The "normal" tier of each slot deliberately reuses the ORIGINAL
-- wobble name and seed1 unchanged (no "_normal" suffix) rather than
-- the naming scheme its "small"/"large" siblings use — so that with
-- these brand-new controls left at their default (Scale = Normal),
-- generation is byte-for-bit identical to before this feature existed,
-- not just similar. Renaming the default tier's own seed would reroll
-- its random pattern even for players who never touch the slider.
local SCALE_TIER_MULTIPLIERS = { small = 0.5, normal = 1.0, large = 2.0 }
local ZONE_PATCH_SIZE_SLOTS = {
  { zone_prefix = "simulacruis_zone_2", distance_tier = "near", grid = zone_2_grid_near, seed1 = "simulacruis_zone_2", control = "simulacruis_zone_2_patch_scale" },
  { zone_prefix = "simulacruis_zone_2", distance_tier = "far", grid = zone_2_grid_far, seed1 = "simulacruis_zone_2_far", control = "simulacruis_zone_2_patch_scale" },
  { zone_prefix = "simulacruis_zone_3", distance_tier = "near", grid = zone_3_grid_near, seed1 = "simulacruis_zone_3", control = "simulacruis_zone_3_patch_scale" },
  { zone_prefix = "simulacruis_zone_3", distance_tier = "far", grid = zone_3_grid_far, seed1 = "simulacruis_zone_3_far", control = "simulacruis_zone_3_patch_scale" },
  { zone_prefix = "simulacruis_zone_4", distance_tier = "band0", grid = zone_4_grid_band0, seed1 = "simulacruis_zone_4", control = "simulacruis_zone_4_patch_scale" },
  { zone_prefix = "simulacruis_zone_4", distance_tier = "band1", grid = zone_4_grid_band1, seed1 = "simulacruis_zone_4_band1", control = "simulacruis_zone_4_patch_scale" },
  { zone_prefix = "simulacruis_zone_4", distance_tier = "band2", grid = zone_4_grid_band2, seed1 = "simulacruis_zone_4_band2", control = "simulacruis_zone_4_patch_scale" },
}

local scale_select_prototypes = {}
for _, slot in ipairs(ZONE_PATCH_SIZE_SLOTS) do
  local tier_cell = {}
  local tier_pyramid = {}
  for _, tier in ipairs({ "small", "normal", "large" }) do
    local tier_grid_size = slot.grid * SCALE_TIER_MULTIPLIERS[tier]
    local is_normal = tier == "normal"
    local wobble_name = is_normal
      and (slot.zone_prefix .. "_" .. slot.distance_tier)
      or (slot.zone_prefix .. "_" .. slot.distance_tier .. "_" .. tier)
    local seed1 = is_normal and slot.seed1 or (slot.seed1 .. "_" .. tier)
    local wx, wy = make_wobble(wobble_name, tier_grid_size)
    local cell_name = slot.zone_prefix .. "_cell_" .. slot.distance_tier .. "_" .. tier
    local pyramid_name = slot.zone_prefix .. "_pyramid_" .. slot.distance_tier .. "_" .. tier
    add_band(cell_name, pyramid_name, wx, wy, seed1, tier_grid_size)
    tier_cell[tier] = cell_name
    tier_pyramid[tier] = pyramid_name
  end

  -- Final output keeps the plain original name (e.g.
  -- "simulacruis_zone_2_cell_near") so every downstream reference
  -- (the distance-based near/far/band hard-selects right below) needs
  -- no changes at all.
  table.insert(scale_select_prototypes, {
    type = "noise-expression", name = slot.zone_prefix .. "_cell_" .. slot.distance_tier,
    expression = "if(control:" .. slot.control .. ":frequency > 1.5, " .. tier_cell.large ..
                 ",\z\n                    if(control:" .. slot.control .. ":frequency < 0.7, " .. tier_cell.small ..
                 ",\z\n                    " .. tier_cell.normal .. "))"
  })
  table.insert(scale_select_prototypes, {
    type = "noise-expression", name = slot.zone_prefix .. "_pyramid_" .. slot.distance_tier,
    expression = "if(control:" .. slot.control .. ":frequency > 1.5, " .. tier_pyramid.large ..
                 ",\z\n                    if(control:" .. slot.control .. ":frequency < 0.7, " .. tier_pyramid.small ..
                 ",\z\n                    " .. tier_pyramid.normal .. "))"
  })
end

data:extend(wobble_prototypes)
data:extend(voronoi_prototypes)
data:extend(scale_select_prototypes)

data:extend({
  { type = "autoplace-control", name = "simulacruis_zone_2_patch_scale", category = "terrain", order = "simulacruis-a-zone-scale-1",
    localised_description = "Only Scale affects patch size here. Coverage has no effect." },
  { type = "autoplace-control", name = "simulacruis_zone_3_patch_scale", category = "terrain", order = "simulacruis-a-zone-scale-2",
    localised_description = "Only Scale affects patch size here. Coverage has no effect." },
  { type = "autoplace-control", name = "simulacruis_zone_4_patch_scale", category = "terrain", order = "simulacruis-a-zone-scale-3",
    localised_description = "Only Scale affects patch size here. Coverage has no effect." },
})

data:extend({
  -- The near/far (and band0/1/2) split point itself DOES track the
  -- live Zone radius controls (simulacruis_zone_N_radius_value, from
  -- zone-masks.lua) even though the grid sizes on either side of it stay
  -- frozen — otherwise dragging a Zone radius control would leave this
  -- tier boundary sitting at its old, now visibly wrong, distance
  -- relative to the zone boundary it's supposed to roughly track.
  {
    type = "noise-expression",
    name = "simulacruis_zone_2_cell",
    expression = "if(simulacruis_wobbled_distance > (simulacruis_zone_1_radius_value + simulacruis_zone_2_radius_value) / 2,\z
                     simulacruis_zone_2_cell_far, simulacruis_zone_2_cell_near)"
  },
  {
    type = "noise-expression",
    name = "simulacruis_zone_2_pyramid",
    expression = "if(simulacruis_wobbled_distance > (simulacruis_zone_1_radius_value + simulacruis_zone_2_radius_value) / 2,\z
                     simulacruis_zone_2_pyramid_far, simulacruis_zone_2_pyramid_near)"
  },

  {
    type = "noise-expression",
    name = "simulacruis_zone_3_cell",
    expression = "if(simulacruis_wobbled_distance > (simulacruis_zone_2_radius_value + simulacruis_zone_3_radius_value) / 2,\z
                     simulacruis_zone_3_cell_far, simulacruis_zone_3_cell_near)"
  },
  {
    type = "noise-expression",
    name = "simulacruis_zone_3_pyramid",
    expression = "if(simulacruis_wobbled_distance > (simulacruis_zone_2_radius_value + simulacruis_zone_3_radius_value) / 2,\z
                     simulacruis_zone_3_pyramid_far, simulacruis_zone_3_pyramid_near)"
  },

  -- Zone 4 is unbounded, so it gets three progressively larger bands
  -- instead of just two, keeping patches growing the further out you
  -- walk rather than capping out after a single jump. ring_width itself
  -- (the spacing between bands) stays the frozen default — only the
  -- anchor point (Zone 3's own live radius) needs to track the control,
  -- so this always starts exactly where Zone 3 actually ends.
  {
    type = "noise-expression",
    name = "simulacruis_zone_4_cell",
    expression = "if(simulacruis_wobbled_distance > simulacruis_zone_3_radius_value + " .. (2 * ring_width) .. ", simulacruis_zone_4_cell_band2,\z
                  if(simulacruis_wobbled_distance > simulacruis_zone_3_radius_value + " .. ring_width .. ", simulacruis_zone_4_cell_band1,\z
                  simulacruis_zone_4_cell_band0))"
  },
  {
    type = "noise-expression",
    name = "simulacruis_zone_4_pyramid",
    expression = "if(simulacruis_wobbled_distance > simulacruis_zone_3_radius_value + " .. (2 * ring_width) .. ", simulacruis_zone_4_pyramid_band2,\z
                  if(simulacruis_wobbled_distance > simulacruis_zone_3_radius_value + " .. ring_width .. ", simulacruis_zone_4_pyramid_band1,\z
                  simulacruis_zone_4_pyramid_band0))"
  },

  -- "Land bridge": additive elevation lift, strongest right at any
  -- biome/zone seam and fading to 0 within roughly one cell's radius
  -- of it, so two different planets' terrain never meet with one side
  -- still at open-water (or lava) elevation. Purely additive on top of
  -- the existing hard-selected elevation (see property-expressions.lua)
  -- — never lowers it — so this can only turn a borderline coastline
  -- into land near a seam, never remove water/lava from a biome's own
  -- interior. Deliberately NOT a blend of two planets' elevation
  -- values (that's the exact bug class fixed once already — see
  -- property-expressions.lua's header comment).
  --
  -- Two kinds of seam, two proximity signals, combined with max():
  -- - voronoi cell edges (within a zone): pyramid does NOT stay near 0
  --   only close to the edge — it ramps 0 (edge) -> ~1 (center) across
  --   the WHOLE cell, same shape Fulgora's own "pyramid" name implies.
  --   Using "1 - pyramid" directly land-locked entire Aquilo cells (no
  --   interior ocean left anywhere). Fixed by only engaging within a
  --   thin band near pyramid=0 — clamp((edge_band - pyramid) /
  --   edge_band, 0, 1) — 0 once pyramid exceeds edge_band, so the
  --   interior (most of the cell) is completely untouched again.
  -- - zone-radius edges (Zone 1/2/3/4 boundaries): reuses the existing
  --   zone_step ramps, which are already a smooth 0->1 crossing over
  --   the `transition` width — "1 - abs(2*step - 1)" turns that into a
  --   proximity peaking at 1 exactly on the (wobbled) radius line and
  --   decaying to 0 at either end of the transition band (already a
  --   narrow band by construction, unlike the pyramid — no fix needed
  --   here).
  --
  -- Known gap (flagged, not fixed here): lava's own placement formula
  -- reads Vulcanus's internal `vulcanus_elev` field directly, not the
  -- shared `elevation` property this boost modifies
  -- (lava_basalts_range depends on vulcanus_elev, an unrelated,
  -- arbitrarily-scaled internal quantity) — so this does
  -- NOT stop lava from generating right next to another biome's ocean.
  -- That would need a separate, lava-specific gate.
  { type = "noise-expression", name = "simulacruis_zone_1_boundary_proximity", expression = "1 - abs(2 * simulacruis_zone_step_1 - 1)" },
  { type = "noise-expression", name = "simulacruis_zone_2_boundary_proximity", expression = "1 - abs(2 * simulacruis_zone_step_2 - 1)" },
  { type = "noise-expression", name = "simulacruis_zone_3_boundary_proximity", expression = "1 - abs(2 * simulacruis_zone_step_3 - 1)" },
  { type = "noise-expression", name = "simulacruis_zone_2_edge_proximity", expression = "clamp((0.15 - simulacruis_zone_2_pyramid) / 0.15, 0, 1)" },
  { type = "noise-expression", name = "simulacruis_zone_3_edge_proximity", expression = "clamp((0.15 - simulacruis_zone_3_pyramid) / 0.15, 0, 1)" },
  { type = "noise-expression", name = "simulacruis_zone_4_edge_proximity", expression = "clamp((0.15 - simulacruis_zone_4_pyramid) / 0.15, 0, 1)" },
  -- BUG: Zone 1's guaranteed starting lake wasn't spawning.
  -- voronoi_pyramid_noise is defined over ALL of
  -- space, not just within its own zone's distance range — a zone's
  -- pyramid/edge_proximity value at some arbitrary (x,y) is still
  -- computed even when that zone's own grid has nothing to do with what
  -- actually occupies that point. Deep in Zone 1 (where only Nauvis
  -- ever applies), points near a ZONE 2/3/4 grid's cell edge picked up
  -- a nonzero land-bridge boost (up to the full +30) purely by chance —
  -- fighting (and
  -- often winning against) Nauvis's own vanilla starting-lake carve-out
  -- (min(wlc_elevation, starting_lake) in its elevation formula), which
  -- sits at a specific low elevation the boost was pushing back above
  -- water level. Fixed by gating each zone's edge_proximity by that
  -- zone's OWN zone_weight before taking the max, so a point deep in a
  -- different zone (weight 0 there) can never pick up a stray boost from
  -- an irrelevant grid, regardless of what that grid's raw pyramid value
  -- happens to be at that location.
  { type = "noise-expression", name = "simulacruis_zone_2_edge_boost", expression = "simulacruis_zone_2_weight * simulacruis_zone_2_edge_proximity" },
  { type = "noise-expression", name = "simulacruis_zone_3_edge_boost", expression = "simulacruis_zone_3_weight * simulacruis_zone_3_edge_proximity" },
  { type = "noise-expression", name = "simulacruis_zone_4_edge_boost", expression = "simulacruis_zone_4_weight * simulacruis_zone_4_edge_proximity" },
  {
    type = "noise-expression",
    name = "simulacruis_land_bridge_strength",
    expression = "max(simulacruis_zone_2_edge_boost,\z
                  max(simulacruis_zone_3_edge_boost,\z
                  max(simulacruis_zone_4_edge_boost,\z
                  max(simulacruis_zone_1_boundary_proximity,\z
                  max(simulacruis_zone_2_boundary_proximity,\z
                      simulacruis_zone_3_boundary_proximity)))))"
  },
  -- 30 elevation units comfortably covers every planet's own
  -- water/lava-adjacent elevation range at full strength, while
  -- fading to +0 (no change at all) away from any seam.
  { type = "noise-expression", name = "simulacruis_land_bridge_boost", expression = "30 * simulacruis_land_bridge_strength" },

  -- Which biome a cell gets, per zone, is now driven by five player-
  -- adjustable "Terrain" map-gen controls (one per planet — see the
  -- autoplace-control prototypes below) instead of the earlier fixed
  -- baseline percentages nudged by a standalone "wetness" noise field.
  -- Replaces that wetness mechanic entirely (it only exposed one
  -- indirect wet/dry axis nudging two fixed groups against each other;
  -- this gives direct, independent control per planet, matching how
  -- every other autoplace thing in the game already works).
  --
  -- NOTE: because shares are normalized (each planet's weighted value
  -- divided by the zone's total), turning every slider up or down by
  -- the SAME amount cancels out and changes nothing — only the sliders'
  -- values RELATIVE to each other affect the resulting mix. That's
  -- inherent to a proportion system (five shares always sum to 1), not
  -- a bug.
  -- localised_description is a bare literal string, not a locale key
  -- reference — vanilla has no auto-derived
  -- "autoplace-control-descriptions.<name>" convention the way names
  -- do (e.g. water's own localised_description points at an arbitrary
  -- unrelated locale key, "size.only-starting-area") — so there's
  -- nothing to reuse or replicate; a plain string displays as-is with
  -- no lookup needed. Only Coverage (the Size slider) actually affects
  -- the mix; Frequency/Scale can't be hidden on its own — Factorio's
  -- "terrain" category always shows both sliders as a pair — so this
  -- is a tooltip explaining Scale is a no-op here rather than a way to
  -- truly hide it.
  { type = "autoplace-control", name = "simulacruis_nauvis_terrain", category = "terrain", order = "simulacruis-b-terrain-1", localised_description = "Only Coverage affects Simulacruis's biome mix. Scale has no effect here." },
  { type = "autoplace-control", name = "simulacruis_vulcanus_terrain", category = "terrain", order = "simulacruis-b-terrain-2", localised_description = "Only Coverage affects Simulacruis's biome mix. Scale has no effect here." },
  { type = "autoplace-control", name = "simulacruis_fulgora_terrain", category = "terrain", order = "simulacruis-b-terrain-3", localised_description = "Only Coverage affects Simulacruis's biome mix. Scale has no effect here." },
  { type = "autoplace-control", name = "simulacruis_gleba_terrain", category = "terrain", order = "simulacruis-b-terrain-4", localised_description = "Only Coverage affects Simulacruis's biome mix. Scale has no effect here." },
  { type = "autoplace-control", name = "simulacruis_aquilo_terrain", category = "terrain", order = "simulacruis-b-terrain-5", localised_description = "Only Coverage affects Simulacruis's biome mix. Scale has no effect here." },
  -- These controls are only usable once actually enabled on the
  -- Simulacruis planet's own map_gen_settings.autoplace_controls (a
  -- planet-scoped dict, unlike the control PROTOTYPE above, which is
  -- global) — but that planet prototype doesn't exist yet at this point
  -- in the require order (planet-simulacruis.lua runs after this file).
  -- Wired up separately in biome-mix-controls.lua instead, which runs
  -- after it.
  --
  -- Reads each control's `size` value, NOT `frequency` — matching
  -- vanilla's own "water" control (control:water:size
  -- feeds water_level, i.e. how much of the map is water = Coverage;
  -- control:water:frequency feeds segmentation_multiplier, i.e. how
  -- big each landmass/water body is = Scale). For a "terrain" category
  -- autoplace-control, the game's own map generator UI labels these two
  -- sliders "Scale" (frequency) and "Coverage" (size) accordingly. This
  -- mod wants Coverage — how much of each zone's area a planet gets —
  -- so it reads `size`. `frequency`/"Scale" is intentionally left
  -- unread: making individual patches bigger or smaller per-planet
  -- isn't possible without separate voronoi grids per planet (all five
  -- currently share one grid per zone tier, and grid_size must be a
  -- spatial constant — see this file's own header comment), so for now
  -- the Scale slider on these five controls has no effect.
  { type = "noise-expression", name = "simulacruis_nauvis_terrain_coverage", expression = "control:simulacruis_nauvis_terrain:size" },
  { type = "noise-expression", name = "simulacruis_vulcanus_terrain_coverage", expression = "control:simulacruis_vulcanus_terrain:size" },
  { type = "noise-expression", name = "simulacruis_fulgora_terrain_coverage", expression = "control:simulacruis_fulgora_terrain:size" },
  { type = "noise-expression", name = "simulacruis_gleba_terrain_coverage", expression = "control:simulacruis_gleba_terrain:size" },
  { type = "noise-expression", name = "simulacruis_aquilo_terrain_coverage", expression = "control:simulacruis_aquilo_terrain:size" },
})

-- Builds the "<zone>_is_<planet>" boolean partition expressions for one
-- zone from each planet's baseline share (the exact percentages already
-- tuned this session) times its own Terrain control's Coverage (size)
-- value, normalized so the five shares still sum to exactly 1. At every
-- control's default (size = 1), weighted value equals baseline
-- exactly and the baselines already sum to 1 — so leaving every slider
-- untouched reproduces today's exact percentages, bit-for-bit; moving
-- one slider shifts share between all planets present in that zone,
-- proportional to their own baseline weight.
--
-- `planets` is an ORDERED list of {name, baseline} — order matters:
-- cumulative thresholds are built in this exact order (matching the
-- original hand-written thresholds' own ordering, so a fresh map at
-- default settings is identical to before this change), and the LAST
-- planet's upper bound is left implicit (>= its own lower bound only)
-- so it always reaches exactly 1.0 regardless of any floating-point
-- imprecision accumulated summing the shares above it.
local function add_zone_partition(zone_name, cell_expr, planets)
  local prototypes = {}
  local weighted_names = {}
  for _, p in ipairs(planets) do
    local weighted_name = zone_name .. "_weighted_" .. p.name
    table.insert(prototypes, {
      type = "noise-expression",
      name = weighted_name,
      expression = p.baseline .. " * simulacruis_" .. p.name .. "_terrain_coverage"
    })
    table.insert(weighted_names, weighted_name)
  end

  local total_name = zone_name .. "_weighted_total"
  -- max()'d against a small floor so an all-zero slider combination
  -- (every relevant Terrain control set to None) can't divide by zero.
  table.insert(prototypes, {
    type = "noise-expression",
    name = total_name,
    expression = "max(0.0001, " .. table.concat(weighted_names, " + ") .. ")"
  })

  local cumulative = "0"
  for i, p in ipairs(planets) do
    local share_name = zone_name .. "_share_" .. p.name
    table.insert(prototypes, {
      type = "noise-expression",
      name = share_name,
      expression = weighted_names[i] .. " / " .. total_name
    })

    local is_name = zone_name .. "_is_" .. p.name
    if i == #planets then
      table.insert(prototypes, {
        type = "noise-expression", name = is_name,
        expression = cell_expr .. " >= (" .. cumulative .. ")"
      })
    else
      table.insert(prototypes, {
        type = "noise-expression", name = is_name,
        expression = "(" .. cell_expr .. " >= (" .. cumulative .. ")) * (" ..
          cell_expr .. " < (" .. cumulative .. " + " .. share_name .. "))"
      })
    end
    cumulative = cumulative .. " + " .. share_name
  end

  data:extend(prototypes)
end

-- Zone 2: baseline Nauvis 20%, Vulcanus 25%, Fulgora 15%, Gleba 40%
-- (originally 25/20/20/35 — Nauvis and Fulgora each moved 5% over to
-- Vulcanus and Gleba) — no Aquilo this close in.
add_zone_partition("simulacruis_zone_2", "simulacruis_zone_2_cell", {
  { name = "nauvis", baseline = 0.20 },
  { name = "vulcanus", baseline = 0.25 },
  { name = "fulgora", baseline = 0.15 },
  { name = "gleba", baseline = 0.40 },
})

-- Zone 3: baseline Nauvis/Vulcanus 22.5% each, Fulgora 15%, Gleba 35%,
-- Aquilo 5% (originally Fulgora 17.5%/Gleba 32.5% — 2.5% moved from
-- Fulgora to Gleba).
add_zone_partition("simulacruis_zone_3", "simulacruis_zone_3_cell", {
  { name = "nauvis", baseline = 0.225 },
  { name = "vulcanus", baseline = 0.225 },
  { name = "fulgora", baseline = 0.15 },
  { name = "gleba", baseline = 0.35 },
  { name = "aquilo", baseline = 0.05 },
})

-- Zone 4: baseline Nauvis/Vulcanus 20% each, Fulgora 15%, Gleba 30%,
-- Aquilo 15%.
add_zone_partition("simulacruis_zone_4", "simulacruis_zone_4_cell", {
  { name = "nauvis", baseline = 0.20 },
  { name = "vulcanus", baseline = 0.20 },
  { name = "fulgora", baseline = 0.15 },
  { name = "gleba", baseline = 0.30 },
  { name = "aquilo", baseline = 0.15 },
})

data:extend({
  -- Combined per-source-planet ownership weight across all zones. Each
  -- of these five always sums to 1 at any point, since it's a weighted
  -- sum of per-zone partitions using the zone weights (which themselves
  -- sum to 1).
  {
    type = "noise-expression",
    name = "simulacruis_nauvis_weight",
    expression = "simulacruis_zone_1_weight\z
                  + simulacruis_zone_2_weight * simulacruis_zone_2_is_nauvis\z
                  + simulacruis_zone_3_weight * simulacruis_zone_3_is_nauvis\z
                  + simulacruis_zone_4_weight * simulacruis_zone_4_is_nauvis"
  },
  {
    type = "noise-expression",
    name = "simulacruis_vulcanus_weight",
    expression = "simulacruis_zone_2_weight * simulacruis_zone_2_is_vulcanus\z
                  + simulacruis_zone_3_weight * simulacruis_zone_3_is_vulcanus\z
                  + simulacruis_zone_4_weight * simulacruis_zone_4_is_vulcanus"
  },
  {
    type = "noise-expression",
    name = "simulacruis_fulgora_weight",
    expression = "simulacruis_zone_2_weight * simulacruis_zone_2_is_fulgora\z
                  + simulacruis_zone_3_weight * simulacruis_zone_3_is_fulgora\z
                  + simulacruis_zone_4_weight * simulacruis_zone_4_is_fulgora"
  },
  {
    type = "noise-expression",
    name = "simulacruis_gleba_weight",
    expression = "simulacruis_zone_2_weight * simulacruis_zone_2_is_gleba\z
                  + simulacruis_zone_3_weight * simulacruis_zone_3_is_gleba\z
                  + simulacruis_zone_4_weight * simulacruis_zone_4_is_gleba"
  },
  {
    type = "noise-expression",
    name = "simulacruis_aquilo_weight",
    expression = "simulacruis_zone_3_weight * simulacruis_zone_3_is_aquilo\z
                  + simulacruis_zone_4_weight * simulacruis_zone_4_is_aquilo"
  }
})
