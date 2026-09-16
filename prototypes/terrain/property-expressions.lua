-- Each field picks exactly ONE source planet's own value at any given
-- point (whichever planet's ownership weight exceeds 0.5), rather than
-- blending multiple planets' values together. Blending was tried first
-- (a straight weighted sum) but each planet's elevation formula uses an
-- incompatible baseline/scale (e.g. Aquilo centers around -25, Fulgora
-- around +80), and Zone 2/3 use independent voronoi grids, so the
-- crossfade ring at each zone boundary could blend two unrelated
-- planets' scales together — producing meaningless intermediate values
-- that frequently dipped below the water threshold, breaking up the
-- terrain right at zone boundaries. A hard per-point selector avoids
-- ever computing such a blend; Factorio's own tile-transition/cliff
-- rendering handles the resulting boundary visually, the same way it
-- already handles boundaries between any two adjacent tile types.
data:extend({
  {
    type = "noise-expression",
    name = "simulacruis_elevation",
    intended_property = "elevation",
    -- + simulacruis_land_bridge_boost (biome-regions.lua): additive
    -- lift near any biome/zone seam so two different planets' terrain
    -- never meet at open water/lava on one side — see that file for
    -- the full rationale and its one known gap (lava itself).
    expression = "(if(simulacruis_nauvis_weight > 0.5, elevation_nauvis,\z
                  if(simulacruis_vulcanus_weight > 0.5, vulcanus_elevation,\z
                  if(simulacruis_fulgora_weight > 0.5, fulgora_elevation,\z
                  if(simulacruis_gleba_weight > 0.5, gleba_elevation,\z
                     aquilo_elevation))))) + simulacruis_land_bridge_boost"
  },
  {
    type = "noise-expression",
    name = "simulacruis_aux",
    intended_property = "aux",
    expression = "if(simulacruis_nauvis_weight > 0.5, aux_nauvis,\z
                  if(simulacruis_vulcanus_weight > 0.5, vulcanus_aux,\z
                  if(simulacruis_fulgora_weight > 0.5, aux_basic,\z
                  if(simulacruis_gleba_weight > 0.5, gleba_aux,\z
                     aquilo_aux))))"
  },
  {
    type = "noise-expression",
    name = "simulacruis_moisture",
    intended_property = "moisture",
    expression = "if(simulacruis_nauvis_weight > 0.5, moisture_nauvis,\z
                  if(simulacruis_vulcanus_weight > 0.5, vulcanus_moisture,\z
                  if(simulacruis_fulgora_weight > 0.5, moisture_basic,\z
                  if(simulacruis_gleba_weight > 0.5, gleba_moisture,\z
                     moisture_basic))))"
  },
  {
    type = "noise-expression",
    name = "simulacruis_temperature",
    intended_property = "temperature",
    expression = "if(simulacruis_nauvis_weight > 0.5, temperature_basic,\z
                  if(simulacruis_vulcanus_weight > 0.5, vulcanus_temperature,\z
                  if(simulacruis_fulgora_weight > 0.5, temperature_basic,\z
                  if(simulacruis_gleba_weight > 0.5, gleba_temperature,\z
                     aquilo_temperature))))"
  },
  {
    -- Cliff *density/placement* follows the same per-biome selection as
    -- everything else. Cliff *appearance* (which graphic/prototype
    -- renders) cannot be made to vary this way — map_gen_settings.
    -- cliff_settings.name is a single value for the whole planet, not a
    -- noise expression — so Simulacruis's cliffs always render in
    -- Nauvis's own cliff style regardless of biome. That's a genuine
    -- Factorio architecture limit, not something left unfixed here.
    type = "noise-expression",
    name = "simulacruis_cliffiness",
    intended_property = "cliffiness",
    expression = "if(simulacruis_nauvis_weight > 0.5, cliffiness_nauvis,\z
                  if(simulacruis_vulcanus_weight > 0.5, cliffiness_basic,\z
                  if(simulacruis_fulgora_weight > 0.5, fulgora_cliffiness,\z
                  if(simulacruis_gleba_weight > 0.5, gleba_cliffiness,\z
                     cliffiness_basic))))"
  }
})
