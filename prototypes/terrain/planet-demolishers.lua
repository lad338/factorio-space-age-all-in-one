-- Vulcanus's demolishers (small/medium/big-demolisher, segmented-unit
-- prototypes) are NOT autoplace-driven at all — they have no autoplace
-- field. They're placed by an entirely separate, genuinely per-planet
-- mechanism: map_gen_settings.territory_settings (a sibling field to
-- property_expression_names, NOT routed through it — real
-- Vulcanus sets `territory_settings = { units, territory_index_expression
-- = "demolisher_territory_expression", territory_variation_expression =
-- "demolisher_variation_expression", minimum_territory_size = 10 }`,
-- while Simulacruis's own territory_settings was simply nil, which is
-- the actual reason zero demolishers were spawning here — not a
-- planet-identity lock in the engine. Fully data-driven and per-planet,
-- so this needs no clone+gate wrapping, no hacking around a hardcoded
-- Vulcanus check, and (unlike lava) no other-planet contamination risk:
-- Simulacruis's territory_settings is entirely our own.
--
-- territory_index_expression is expected to be a per-cell *constant*
-- (vanilla's own is a voronoi_cell_id), since the engine groups
-- contiguous chunks sharing the same index into one territory. Reusing
-- our EXISTING Vulcanus-owning cell id here (the same one biome-regions.
-- lua already uses to decide "is this cell Vulcanus") guarantees one
-- territory exactly covers one Vulcanus biome patch, whole — not an
-- independent grid that only partially overlaps it.
-- Same clamping (each radius floored to at least the previous zone's
-- own — see biome-regions.lua's header comment for the full "0 skips
-- that zone" rationale) as biome-regions.lua/zone-masks.lua use — this
-- file needs the same zone_2_radius/zone_3_radius they end up with,
-- or simulacruis_zone_3_cell (referenced below) and the demolisher
-- tiering would disagree with where Vulcanus's own zone-3+ weighting
-- actually starts. zone_1_radius itself is only needed to compute that
-- clamp, not used directly below.
local zone_1_radius = math.max(settings.startup["simulacruis-zone-1-radius"].value, 0)
local zone_2_radius = math.max(settings.startup["simulacruis-zone-2-radius"].value, zone_1_radius)
local zone_3_radius = math.max(settings.startup["simulacruis-zone-3-radius"].value, zone_2_radius)
-- Reused as the "how far outward for one demolisher size tier" span,
-- same convention as biome-regions.lua's ring_width — floored the same
-- way (matching value too, for consistency) for the same reason (a
-- literal 0 here would be a division by zero below, if Zone 3 is
-- skipped) even though this specific use has no grid_size-style
-- minimum of its own.
local RING_WIDTH_FLOOR = 10
local tier_span = math.max(zone_3_radius - zone_2_radius, RING_WIDTH_FLOOR)

data:extend({
  {
    type = "noise-expression",
    name = "simulacruis_demolisher_territory_index",
    expression = "if(simulacruis_zone_4_weight > 0.5, simulacruis_zone_4_cell, simulacruis_zone_3_cell)"
  },
  -- Demolishers only spawn in Zone 3 and beyond, and only within
  -- Vulcanus's own zone-3+ ownership
  -- (simulacruis_vulcanus_zone_3plus_weight, already defined in
  -- planet-resources.lua) — negative everywhere else, which
  -- the engine treats as no spawn there. Where valid, tiers up from
  -- small (0) to big (2) the further out you are, one tier per
  -- tier_span of distance past zone_3_radius, clamped to the 3-entry
  -- units list below.
  {
    type = "noise-expression",
    name = "simulacruis_demolisher_territory_variation",
    expression = "if(simulacruis_vulcanus_zone_3plus_weight > 0.5,\z
                     floor(clamp((simulacruis_wobbled_distance - " .. zone_3_radius .. ") / " .. tier_span .. ", 0, 2)),\z
                     -1)"
  }
})

local planet = data.raw.planet.simulacruis
planet.map_gen_settings.territory_settings = {
  units = { "small-demolisher", "medium-demolisher", "big-demolisher" },
  territory_index_expression = "simulacruis_demolisher_territory_index",
  territory_variation_expression = "simulacruis_demolisher_territory_variation",
  -- Same as vanilla Vulcanus's own tuning — discards any stray
  -- territory too small to be worth spawning into (e.g. a sliver of a
  -- Zone 3 cell right at a zone-radius transition).
  minimum_territory_size = 10
}
