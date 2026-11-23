-- Demolishers are placed via map_gen_settings.territory_settings, not
-- autoplace. territory_index_expression must be a per-cell constant; the
-- engine groups contiguous chunks sharing the same value into one
-- territory, regardless of what territory_variation says within it.
data:extend({
  -- Shared by territory_index and territory_variation so the two can
  -- never disagree on where Vulcanus ownership actually is.
  -- simulacruis_vulcanus_hazard_zone_weight (planet-resources.lua) is
  -- shared with tungsten ore and sulfuric acid geysers, all driven by
  -- the same simulacruis-vulcanus-hazard-zone setting -- moving that
  -- setting moves demolishers' own eligibility along with it.
  {
    type = "noise-expression",
    name = "simulacruis_demolisher_eligible",
    expression = "simulacruis_vulcanus_hazard_zone_weight > 0.5"
  },
  -- zone_3_cell and zone_4_cell are independent grids. Gating with
  -- simulacruis_demolisher_eligible collapses everywhere outside real
  -- Vulcanus ownership to one constant sentinel, so a territory's
  -- contiguous footprint can never bridge into non-Vulcanus terrain.
  {
    type = "noise-expression",
    name = "simulacruis_demolisher_territory_index",
    expression = "if(simulacruis_demolisher_eligible,\z
                     if(simulacruis_zone_4_weight > 0.5, simulacruis_zone_4_cell, simulacruis_zone_3_cell),\z
                     -1)"
  },
  -- Where eligible, tiers up from small (0) to big (2) the further out
  -- you are, one Zone-3-ring-width of distance past Zone 3's own
  -- radius per tier. Still anchored to Zone 3's own radius regardless
  -- of simulacruis-vulcanus-hazard-zone's own setting (no
  -- zone_4_radius_value exists to anchor to instead, since Zone 4 has
  -- no outer bound) -- at a lower hazard-zone setting, this just means
  -- every demolisher stays tier 0 (small) for longer before the same
  -- tiering curve as today kicks in once Zone 3's own radius is
  -- reached, rather than tiering up earlier too.
  {
    type = "noise-expression",
    name = "simulacruis_demolisher_territory_variation",
    expression = "if(simulacruis_demolisher_eligible,\z
                     floor(clamp((simulacruis_wobbled_distance - simulacruis_zone_3_radius_value) / simulacruis_zone_3_ring_width, 0, 2)),\z
                     -1)"
  }
})

local planet = data.raw.planet.simulacruis
planet.map_gen_settings.territory_settings = {
  units = { "small-demolisher", "medium-demolisher", "big-demolisher" },
  territory_index_expression = "simulacruis_demolisher_territory_index",
  territory_variation_expression = "simulacruis_demolisher_territory_variation",
  -- Discards any stray territory too small to be worth spawning into.
  minimum_territory_size = 10
}
