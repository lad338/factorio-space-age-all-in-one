-- Confines Nauvis's biter/spitter spawners and worm turrets, and
-- Gleba's pentapod spawners, to their own zone-owned biome — same
-- clone+gate technique as trees.lua/tiles.lua, needed for the same
-- reason: gleba_spawner/gleba_spawner_small reference Gleba's own
-- named fields directly (gleba_starting_enemies, gleba_biome_mask_green,
-- etc.), and even enemy_autoplace_base
-- (used by the Nauvis-side entries) only checks generic land
-- suitability, not biome ownership — so without gating, either would
-- place across the whole Simulacruis surface rather than only within
-- their own biome.
--
-- Disabling the originals uses {size = 0}, not `= nil` — see
-- nauvis-dressing.lua for why a missing entry doesn't actually disable
-- placement (AutoplaceSpecification.default_enabled defaults to true).
--
-- Vulcanus's demolishers are deliberately NOT handled here: they're
-- segmented-unit prototypes spawned via map_gen_settings.territory_settings
-- (a data-driven per-planet field, not autoplace) — no
-- unit-spawner-style entry exists for them. Handled
-- separately in planet-demolishers.lua, which sets Simulacruis's own
-- territory_settings directly (still a known cosmetic gap: cliffs, see
-- data-updates.lua's header note).

-- gleba-spawner ("Egg raft") spawns the full pentapod line including
-- stomper-pentapods (gleba-spawner-small,
-- "Small egg raft", only ever spawns wrigglers — no stompers, no
-- strafers). Stompers are effectively unbeatable in the early game, so
-- the full egg raft is restricted to Zone 3+, matching the same
-- zone-gating technique already used for tungsten ore
-- (simulacruis_vulcanus_zone_3plus_weight in planet-resources.lua).
-- gleba-spawner-small keeps spawning across all of Gleba's own
-- territory (Zone 2+), unaffected.
data:extend({
  {
    type = "noise-expression",
    name = "simulacruis_gleba_zone_3plus_weight",
    expression = "min(simulacruis_gleba_weight, simulacruis_zone_3_weight + simulacruis_zone_4_weight)"
  }
})

-- The "Gleba enemy bases" map-gen slider is a real vanilla
-- autoplace-control (category "enemy", exposed on Simulacruis in
-- planet-resources.lua) with real per-Gleba radius/frequency
-- expressions (gleba_enemy_base_radius/frequency, reading
-- control:gleba_enemy_base) — but nothing in vanilla's own expression
-- graph actually consumes those
-- two: gleba-spawner/gleba-spawner-small both call the GLOBAL
-- enemy_autoplace_base(0, 8) instead (tied to control:enemy-base, the
-- plain "Enemy bases" slider), so on real Gleba too, "Gleba enemy
-- bases" changes nothing an egg raft ever reads. Reviving it here for
-- Simulacruis by rebuilding the exact same spot-placement shape
-- vanilla's own enemy_base_probability/enemy_autoplace_base use, just
-- fed by gleba_enemy_base_radius/frequency instead of the global
-- enemy_base_radius/frequency, so the two sliders finally control two
-- independent things: "Enemy bases" for Nauvis's biters/spitters/worms
-- (untouched below), "Gleba enemy bases" for the egg rafts.
data:extend({
  {
    type = "noise-expression",
    name = "simulacruis_gleba_enemy_base_probability",
    -- Mechanical copy of vanilla's own enemy_base_probability
    -- (spot_noise + 3-octave basis_noise blob + starting-area falloff),
    -- with enemy_base_radius/frequency swapped for
    -- gleba_enemy_base_radius/frequency throughout.
    expression = "spot_noise{" ..
      "x = x, y = y," ..
      "density_expression = (pi / 90 * (max(0, gleba_enemy_base_radius)) ^ 3) * max(0, gleba_enemy_base_frequency)," ..
      "spot_quantity_expression = pi / 90 * (max(0, gleba_enemy_base_radius)) ^ 3," ..
      "spot_radius_expression = max(0, gleba_enemy_base_radius)," ..
      "spot_favorability_expression = 1," ..
      -- seed1 deliberately NOT 123 (vanilla's own enemy_base_probability
      -- uses seed1 = 123 for its spot_noise) — reusing the same
      -- seed1/region_size/candidate_point_count
      -- as vanilla's global enemy-base spot field joins the SAME shared
      -- candidate pool, so raising the global "Enemy bases" control
      -- inflated egg raft counts too even though this expression never
      -- reads control:enemy-base. A distinct seed1 gives this its own
      -- independent pool, fully decoupled from the global one.
      "seed0 = map_seed, seed1 = 918273," ..
      "region_size = 512, candidate_point_count = 100," ..
      "hard_region_target_quantity = 0, basement_value = -1000," ..
      "maximum_spot_basement_radius = 128" ..
    "}" ..
    "+ (basis_noise{x = x, y = y, seed0 = map_seed, seed1 = 918274, input_scale = 1 / 8, output_scale = 1}" ..
    " + basis_noise{x = x, y = y, seed0 = map_seed, seed1 = 918275, input_scale = 1 / 24, output_scale = 1}" ..
    " + basis_noise{x = x, y = y, seed0 = map_seed, seed1 = 918276, input_scale = 1 / 64, output_scale = 2}" ..
    " - 0.5) * max(0, gleba_enemy_base_radius) / 150 * (0.1 + 0.9 * clamp(distance / 3000, 0, 1))" ..
    "- 0.3" ..
    "+ min(0, 20 / starting_area_radius * distance - 20)"
  },
  {
    type = "noise-expression",
    name = "simulacruis_gleba_enemy_autoplace_base",
    -- vanilla's enemy_autoplace_base(distance_factor, seed) is
    -- "random_penalty{x = x + seed, y = y, source = min(enemy_base_probability
    -- * max(0, 1 + 0.002 * distance_factor * (...)), 0.25 + distance_factor * 0.05),
    -- amplitude = 0.1}" — both real call sites this replaces used
    -- distance_factor = 0, seed = 8, which zeroes out every
    -- distance_factor term (max(0, 1 + 0) = 1, 0.25 + 0 = 0.25),
    -- collapsing the source clause to min(probability, 0.25).
    expression = "random_penalty{x = x + 8, y = y, source = min(simulacruis_gleba_enemy_base_probability, 0.25), amplitude = 0.1}"
  },
  {
    type = "noise-expression",
    name = "simulacruis_gleba_spawner",
    -- Same shape as vanilla's own "gleba_spawner" noise-expression,
    -- with its one enemy_autoplace_base(0, 8) term replaced by our
    -- gleba-specific one above; every other term (starting-area
    -- guarantee, fertile-coastal fallback, deep-water mask) is
    -- untouched.
    expression = "max(0.01 * gleba_starting_enemies, max(min(0.02, simulacruis_gleba_enemy_autoplace_base), " ..
      "min(0.001, gleba_fertile_spots_coastal * 5000 - gleba_biome_mask_green * 25000)) * " ..
      "(distance > 500 * gleba_starting_area_multiplier)) * gleba_above_deep_water_mask"
  },
  {
    type = "noise-expression",
    name = "simulacruis_gleba_spawner_small",
    -- Same substitution applied to vanilla's "gleba_spawner_small".
    expression = "max(0.02 * gleba_starting_enemies, 0.02 * gleba_starting_enemies_safe, " ..
      "min(0.02, simulacruis_gleba_enemy_autoplace_base), " ..
      "min(0.001, gleba_fertile_spots_coastal * 5000 - gleba_biome_mask_green * 25000)) * gleba_above_deep_water_mask"
  }
})

local function gated_clone(collection, original_name, gate_expression)
  local proto = table.deepcopy(data.raw[collection][original_name])
  proto.name = "simulacruis-" .. original_name
  proto.autoplace = proto.autoplace or {}
  proto.autoplace.probability_expression =
    "if(" .. gate_expression .. " > 0.5, " .. proto.autoplace.probability_expression .. ", -inf)"
  -- Fully functional, just not a separate browsable Factoriopedia page
  -- (see data-updates.lua's header note).
  proto.hidden_in_factoriopedia = true
  -- Renaming drops the automatic name-from-internal-id convention —
  -- without this, every clone shows literally "Unknown key" wherever
  -- its name is displayed. Re-point at the original's own locale key
  -- (unit-spawner/turret both use "entity-name" same as everything
  -- else placeable).
  proto.localised_name = { "entity-name." .. original_name }
  return proto
end

local new_prototypes = {}
local entity_settings = {}
local originals_to_disable = {}

local function add_enemy(collection, name, gate_expression)
  local clone = gated_clone(collection, name, gate_expression)
  table.insert(new_prototypes, clone)
  entity_settings[clone.name] = {}
  table.insert(originals_to_disable, name)
  return clone
end

-- Nauvis
add_enemy("unit-spawner", "biter-spawner", "simulacruis_nauvis_weight")
add_enemy("unit-spawner", "spitter-spawner", "simulacruis_nauvis_weight")
add_enemy("turret", "small-worm-turret", "simulacruis_nauvis_weight")
add_enemy("turret", "medium-worm-turret", "simulacruis_nauvis_weight")
add_enemy("turret", "big-worm-turret", "simulacruis_nauvis_weight")
add_enemy("turret", "behemoth-worm-turret", "simulacruis_nauvis_weight")

-- Gleba
local gleba_spawner_clone = add_enemy("unit-spawner", "gleba-spawner", "simulacruis_gleba_zone_3plus_weight")
-- Point at our own Gleba-specific formula (driven by "Gleba enemy
-- bases") instead of the vanilla one add_enemy copied by default
-- (which is tied to the global "Enemy bases" control instead — see
-- the simulacruis_gleba_spawner comment above).
gleba_spawner_clone.autoplace.probability_expression =
  "if(simulacruis_gleba_zone_3plus_weight > 0.5, simulacruis_gleba_spawner, -inf)"

local gleba_spawner_small_clone = add_enemy("unit-spawner", "gleba-spawner-small", "simulacruis_gleba_weight")
gleba_spawner_small_clone.autoplace.probability_expression =
  "if(simulacruis_gleba_weight > 0.5, simulacruis_gleba_spawner_small, -inf)"

data:extend(new_prototypes)

-- Gleba's whole pentapod line reacts to the "spores" airborne pollutant
-- exclusively (absorptions_per_second/absorptions_to_join_attack are
-- dictionaries keyed by pollutant name).
-- But a surface has exactly ONE active pollutant type
-- (LuaSurface::pollutant_type — "or nil if no pollutant is enabled",
-- singular), and Simulacruis (cloned from Nauvis) uses "pollution", not
-- "spores" — so nothing ever generates spores here, and pentapods
-- currently never get provoked by it at all. Not fixable by having them
-- "react differently side by side": that would need two pollutant types
-- active on one surface, which the engine doesn't support. Instead,
-- mirror each entity's existing spores absorption value under a
-- "pollution" key too, so they react to whichever pollutant actually
-- exists here.
--
-- Applied to the GLOBAL pentapod unit/spider-unit prototypes directly
-- (not cloned) rather than following the usual clone+gate pattern: this
-- is safe because the effect is entirely inert on the real Gleba planet
-- elsewhere in the galaxy — that surface's pollutant_type is "spores"
-- only, so it never tracks a "pollution" grid for these units to react
-- to regardless of what's in their absorption dict. Cloning would also
-- require rewriting gleba-spawner's result_units table (which spawns
-- these by name) to point at renamed copies, for no behavioral gain.
gleba_spawner_clone.absorptions_per_second.pollution =
  table.deepcopy(gleba_spawner_clone.absorptions_per_second.spores)

local pentapod_units = {
  "small-wriggler-pentapod-premature", "small-wriggler-pentapod",
  "medium-wriggler-pentapod-premature", "medium-wriggler-pentapod",
  "big-wriggler-pentapod-premature", "big-wriggler-pentapod"
}
for _, name in ipairs(pentapod_units) do
  local proto = data.raw.unit[name]
  if proto and proto.absorptions_to_join_attack and proto.absorptions_to_join_attack.spores then
    proto.absorptions_to_join_attack.pollution = proto.absorptions_to_join_attack.spores
  end
end

local pentapod_spider_units = {
  "small-stomper-pentapod", "medium-stomper-pentapod", "big-stomper-pentapod",
  "small-strafer-pentapod", "medium-strafer-pentapod", "big-strafer-pentapod"
}
for _, name in ipairs(pentapod_spider_units) do
  local proto = data.raw["spider-unit"][name]
  if proto and proto.absorptions_to_join_attack and proto.absorptions_to_join_attack.spores then
    proto.absorptions_to_join_attack.pollution = proto.absorptions_to_join_attack.spores
  end
end

local planet = data.raw.planet.simulacruis
local entity_autoplace = planet.map_gen_settings.autoplace_settings.entity
for name, setting in pairs(entity_settings) do
  entity_autoplace.settings[name] = setting
end
for _, name in ipairs(originals_to_disable) do
  entity_autoplace.settings[name] = { size = 0 }
end

-- Vanilla's "Pest control" achievement checks kill-achievement.to_kill
-- against the exact prototype names "biter-spawner"/"spitter-spawner"
-- — since those originals are disabled
-- above and every spawner on Simulacruis is the renamed clone, this
-- achievement could never be earned here otherwise. Appending the
-- renamed names is harmless for the real Nauvis elsewhere in the
-- galaxy, same reasoning as every other exact-name whitelist fix in
-- this mod (tile_condition, transitions.to_tiles, research_trigger).
local pest_control = data.raw["kill-achievement"]["pest-control"]
table.insert(pest_control.to_kill, "simulacruis-biter-spawner")
table.insert(pest_control.to_kill, "simulacruis-spitter-spawner")
