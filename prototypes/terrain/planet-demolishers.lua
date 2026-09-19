-- Demolishers are placed via map_gen_settings.territory_settings, not
-- autoplace. territory_index_expression must be a per-cell constant; the
-- engine groups contiguous chunks sharing the same value into one
-- territory, regardless of what territory_variation says within it.
data:extend({
  -- Shared by territory_index and territory_variation so the two can
  -- never disagree on where Vulcanus ownership actually is.
  {
    type = "noise-expression",
    name = "simulacruis_demolisher_eligible",
    expression = "simulacruis_vulcanus_zone_3plus_weight > 0.5"
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
  -- Demolishers only spawn in Zone 3 and beyond. Where eligible, tiers up
  -- from small (0) to big (2) the further out you are, one
  -- Zone-3-ring-width of distance past Zone 3's own radius per tier.
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
