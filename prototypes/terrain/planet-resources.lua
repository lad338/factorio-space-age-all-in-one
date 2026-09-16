-- Adds each planet's own distinctive resources to its own zone-owned
-- patches. Two different techniques are needed, based on each
-- resource's actual default autoplace formula:
--
-- - tungsten-ore/calcite/sulfuric-acid-geyser (Vulcanus), stone
--   (Gleba), crude-oil (Aquilo), and Vulcanus's own coal all default to
--   either a literal `0` (tungsten-ore/calcite/sulfuric-acid-geyser
--   never place at all without a planet supplying a real formula) or a
--   generic "default-X-patches" placeholder (stone/crude-oil/coal) —
--   in vanilla, the *real* per-planet formula only ever gets applied
--   via that planet's own property_expression_names, which we're not
--   using for resources. So these need their formula fully replaced
--   with the real named expression, not just wrapped.
-- - scrap (Fulgora), lithium-brine and fluorine-vent (Aquilo) already
--   have their real home-planet formula as the *default* autoplace —
--   so the existing wrap-the-
--   existing-formula technique (same as tiles.lua etc.) is correct
--   for these.
--
-- Zone 2 tuning: sulfuric acid geysers and scrap patches should be
-- noticeably scarcer and smaller in Zone 2 than from Zone 3+ onward,
-- reflecting Zone 2's role as the earliest, easiest ring rather than
-- full access to every planet's resources right away. Implemented as
-- two multipliers: a richness multiplier (per-tile yield) and a
-- probability multiplier (applied to the *count/size* side of the
-- formula, so fewer tiles qualify as resource at all — shrinking each
-- patch's physical footprint, not just what it yields). This is a
-- sharp cut, not a precise mechanical guarantee of an exact output
-- count (that would need forking each formula's own spot_noise
-- clustering/quantity parameters, a much larger undertaking) —
-- approximating "scarce and small in Zone 2, plentiful from Zone 3+"
-- rather than hitting an exact number. Geysers get a more aggressive
-- size cut than scrap, since a geyser realistically only needs to
-- yield once to be useful while a scrap patch needs real volume.
-- Tungsten's Zone 2 exclusion is a placement restriction (handled via
-- simulacruis_vulcanus_zone_3plus_weight below), not a richness/size
-- tweak, so it's unaffected by these multipliers.
data:extend({
  {
    type = "noise-expression",
    name = "simulacruis_vulcanus_zone_3plus_weight",
    expression = "min(simulacruis_vulcanus_weight, simulacruis_zone_3_weight + simulacruis_zone_4_weight)"
  },
  {
    type = "noise-expression",
    name = "simulacruis_tiny_in_zone_2_multiplier",
    expression = "if(simulacruis_zone_2_weight > 0.5, 0.08, 1)"
  },
  {
    type = "noise-expression",
    name = "simulacruis_tiny_geyser_size_multiplier",
    expression = "if(simulacruis_zone_2_weight > 0.5, 0.15, 1)"
  },
  {
    type = "noise-expression",
    name = "simulacruis_tiny_scrap_size_multiplier",
    expression = "if(simulacruis_zone_2_weight > 0.5, 0.35, 1)"
  }
})

local function gated_clone(original_name, gate_expression)
  local proto = table.deepcopy(data.raw.resource[original_name])
  proto.name = "simulacruis-" .. original_name
  proto.autoplace = proto.autoplace or {}
  proto.autoplace.probability_expression =
    "if(" .. gate_expression .. " > 0.5, " .. proto.autoplace.probability_expression .. ", -inf)"
  -- Fully functional, just not a separate browsable Factoriopedia page
  -- (see data-updates.lua's header note).
  proto.hidden_in_factoriopedia = true
  -- Renaming drops the automatic name-from-internal-id convention —
  -- without this, every clone shows literally "Unknown key" wherever
  -- its name is displayed. Re-point at the original's own locale key.
  proto.localised_name = { "entity-name." .. original_name }
  return proto
end

local function gated_clone_with_formula(original_name, new_name, probability_expr, richness_expr, gate_expression)
  local proto = table.deepcopy(data.raw.resource[original_name])
  proto.name = new_name
  proto.autoplace = proto.autoplace or {}
  proto.autoplace.probability_expression = "if(" .. gate_expression .. " > 0.5, " .. probability_expr .. ", -inf)"
  proto.autoplace.richness_expression = richness_expr
  proto.hidden_in_factoriopedia = true
  -- new_name (e.g. "simulacruis-vulcanus-coal") is a Simulacruis-only
  -- internal id, not a real locale key — the displayed name should
  -- still be the underlying resource's own name (e.g. "Coal"), same as
  -- how real Vulcanus's own coal is just displayed as "Coal" despite
  -- using a Vulcanus-specific formula.
  proto.localised_name = { "entity-name." .. original_name }
  return proto
end

local new_resources = {}
local entity_settings = {}

-- Vulcanus
table.insert(new_resources, gated_clone_with_formula(
  "tungsten-ore", "simulacruis-tungsten-ore",
  "vulcanus_tungsten_ore_probability", "vulcanus_tungsten_ore_richness",
  "simulacruis_vulcanus_zone_3plus_weight"
))
table.insert(new_resources, gated_clone_with_formula(
  "calcite", "simulacruis-calcite",
  "vulcanus_calcite_probability", "vulcanus_calcite_richness",
  "simulacruis_vulcanus_weight"
))
table.insert(new_resources, gated_clone_with_formula(
  "sulfuric-acid-geyser", "simulacruis-sulfuric-acid-geyser",
  "simulacruis_tiny_geyser_size_multiplier * vulcanus_sulfuric_acid_geyser_probability",
  "simulacruis_tiny_in_zone_2_multiplier * vulcanus_sulfuric_acid_geyser_richness",
  "simulacruis_vulcanus_weight"
))
table.insert(new_resources, gated_clone_with_formula(
  "coal", "simulacruis-vulcanus-coal",
  "vulcanus_coal_probability", "vulcanus_coal_richness",
  "simulacruis_vulcanus_weight"
))

-- Fulgora (already has its real formula as the default). Both
-- probability (patch size/footprint) and richness (per-tile yield) get
-- the Zone 2 tiny-patch multipliers, applied on top of scrap's own
-- existing formulas — built directly rather than via gated_clone,
-- since that helper only wraps probability with the gate and doesn't
-- have anywhere to inject the size multiplier ahead of it.
local scrap = table.deepcopy(data.raw.resource["scrap"])
scrap.name = "simulacruis-scrap"
scrap.autoplace = scrap.autoplace or {}
scrap.autoplace.probability_expression =
  "if(simulacruis_fulgora_weight > 0.5, simulacruis_tiny_scrap_size_multiplier * (" ..
  scrap.autoplace.probability_expression .. "), -inf)"
scrap.autoplace.richness_expression =
  "simulacruis_tiny_in_zone_2_multiplier * (" .. scrap.autoplace.richness_expression .. ")"
scrap.hidden_in_factoriopedia = true
scrap.localised_name = { "entity-name.scrap" }
table.insert(new_resources, scrap)

-- Gleba
table.insert(new_resources, gated_clone_with_formula(
  "stone", "simulacruis-gleba-stone",
  "gleba_stone_probability", "gleba_stone_richness",
  "simulacruis_gleba_weight"
))

-- Aquilo
table.insert(new_resources, gated_clone("lithium-brine", "simulacruis_aquilo_weight"))
table.insert(new_resources, gated_clone("fluorine-vent", "simulacruis_aquilo_weight"))
table.insert(new_resources, gated_clone_with_formula(
  "crude-oil", "simulacruis-aquilo-crude-oil",
  "aquilo_crude_oil_probability", "aquilo_crude_oil_richness",
  "simulacruis_aquilo_weight"
))

for _, proto in ipairs(new_resources) do
  entity_settings[proto.name] = {}
end

data:extend(new_resources)

local planet = data.raw.planet.simulacruis
local autoplace = planet.map_gen_settings.autoplace_settings
for name, setting in pairs(entity_settings) do
  autoplace.entity.settings[name] = setting
end

-- Disable the *originals* explicitly. "scrap" (the original, un-gated
-- prototype) was placing over 22,000 times across the whole surface —
-- including Zone 1 and Aquilo's own ocean — despite never having an
-- entity.settings entry. Same root cause as
-- trees.lua/nauvis-dressing.lua: default_enabled
-- defaults to true, so an absent entry falls back to full placement,
-- not disabled placement. tungsten-ore/calcite/sulfuric-acid-geyser
-- happen not to leak in practice (their own default formula is a
-- literal 0), but disabling them here too is cheap
-- and removes the same risk if that ever changes.
local originals_to_disable = {
  "tungsten-ore", "calcite", "sulfuric-acid-geyser", "scrap", "lithium-brine", "fluorine-vent"
}
for _, name in ipairs(originals_to_disable) do
  autoplace.entity.settings[name] = { size = 0 }
end

-- Expose each of these resources' real autoplace-control (the row in
-- the map generator GUI's resource tab) on Simulacruis, matching each
-- source planet's own real control name, so frequency/size/richness
-- are player-tunable there — same as any vanilla resource. The zone-2
-- tiny multipliers above multiply the *result* of these controls
-- (control:X:size/frequency/richness are already read inside the named
-- formulas this file references, e.g. vulcanus_sulfuric_acid_geyser_
-- probability), so raising/lowering a slider here still scales
-- Zone 2's reduced output up/down proportionally — the multiplier
-- layers on top of the player's own choice rather than overriding it.
planet.map_gen_settings.autoplace_controls["tungsten_ore"] = {}
planet.map_gen_settings.autoplace_controls["calcite"] = {}
planet.map_gen_settings.autoplace_controls["sulfuric_acid_geyser"] = {}
planet.map_gen_settings.autoplace_controls["vulcanus_coal"] = {}
planet.map_gen_settings.autoplace_controls["scrap"] = {}
planet.map_gen_settings.autoplace_controls["gleba_stone"] = {}
planet.map_gen_settings.autoplace_controls["lithium_brine"] = {}
planet.map_gen_settings.autoplace_controls["fluorine_vent"] = {}
planet.map_gen_settings.autoplace_controls["aquilo_crude_oil"] = {}

-- Same reasoning, for the handful of real per-planet autoplace-controls
-- that aren't resources but still feed formulas this mod's clones
-- depend on:
--   - fulgora_islands: feeds fulgora_grid/fulgora_natural, which
--     fulgoran-paving/-walls/-conduit/-machinery (cloned in
--     planet-dressing.lua) all read for their own placement formula.
--   - vulcanus_volcanism: feeds vulcanus_elev (Vulcanus's elevation,
--     already used by property-expressions.lua's hard-select, and the
--     same field lava's own placement formula depends on).
--   - gleba_plants: read directly by yumako-tree's and jellystem's own
--     probability formulas (both cloned in planet-dressing.lua).
--   - gleba_water: feeds Gleba's own wetland/deep-lake water shaping.
--   - gleba_enemy_base: real Gleba's own gleba-spawner/gleba-spawner-
--     small formulas don't actually read this control (they call the
--     GLOBAL enemy_autoplace_base instead, so it's a dead control on
--     real Gleba too). Rather than expose a
--     no-op slider, planet-enemies.lua builds Simulacruis's own egg-
--     raft formula to read gleba_enemy_base_radius/frequency (which
--     already exist in vanilla, just orphaned) instead of the global
--     control, so this slider genuinely drives egg raft density here.
planet.map_gen_settings.autoplace_controls["fulgora_islands"] = {}
planet.map_gen_settings.autoplace_controls["vulcanus_volcanism"] = {}
planet.map_gen_settings.autoplace_controls["gleba_plants"] = {}
planet.map_gen_settings.autoplace_controls["gleba_water"] = {}
planet.map_gen_settings.autoplace_controls["gleba_enemy_base"] = {}

-- coal/stone/crude-oil need no disable step here: they're new
-- *separately-named* clones (simulacruis-vulcanus-coal etc.), and the
-- original "coal"/"stone"/"crude-oil" entries were already disabled by
-- nauvis-dressing.lua, which runs before this file.
