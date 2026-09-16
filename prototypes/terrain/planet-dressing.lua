-- Adds each planet's own distinctive decorative dressing (rocks,
-- ruins, iceberg chunks, food-plant trees, etc.) to its own
-- zone-owned patches, using the same clone+gate technique as
-- tiles.lua/trees.lua/nauvis-dressing.lua, and the same {size = 0}
-- per-planet disable for the originals (see nauvis-dressing.lua for
-- why `= nil` doesn't work). Entries with no autoplace of their own
-- (e.g. a piece only ever placed as part of a larger, hand-authored
-- structure) are skipped rather than guessed at.

local entity_like_collections = {
  "tree", "plant", "simple-entity", "resource", "fish", "container", "lightning-attractor"
}

local function find_collection(name)
  for _, collection in ipairs(entity_like_collections) do
    if data.raw[collection] and data.raw[collection][name] then
      return collection
    end
  end
  return nil
end

-- Some entities (e.g. Gleba's yumako-tree/jellystem) restrict where
-- they can grow via autoplace.tile_restriction — a list of exact tile
-- names. Left unchanged, this clone would still reference the
-- *original* tile names (e.g. "natural-yumako-soil"), which no longer
-- exist as autoplaced tiles on Simulacruis (tiles.lua renamed them to
-- "simulacruis-natural-yumako-soil") — so the plant could never find
-- valid ground and would simply never place. This runs after
-- tiles.lua/nauvis-dressing.lua, so the renamed tiles already exist to
-- check against.
local function remap_tile_restriction(proto)
  if proto.autoplace and proto.autoplace.tile_restriction then
    for i, tile_name in ipairs(proto.autoplace.tile_restriction) do
      local renamed = "simulacruis-" .. tile_name
      if data.raw.tile[renamed] then
        proto.autoplace.tile_restriction[i] = renamed
      end
    end
  end
end

local function gated_clone(collection, original_name, gate_expression)
  local proto = table.deepcopy(data.raw[collection][original_name])
  proto.name = "simulacruis-" .. original_name
  proto.autoplace = proto.autoplace or {}
  proto.autoplace.probability_expression =
    "if(" .. gate_expression .. " > 0.5, " .. proto.autoplace.probability_expression .. ", -inf)"
  remap_tile_restriction(proto)
  -- Fully functional, just not a separate browsable Factoriopedia page
  -- (see data-updates.lua's header note).
  proto.hidden_in_factoriopedia = true
  -- Renaming drops the automatic name-from-internal-id convention —
  -- without this, every clone shows literally "Unknown key" wherever
  -- its name is displayed. Re-point at the original's own locale key.
  -- Every collection this helper handles (tree/plant/simple-entity/
  -- resource/fish/container/lightning-attractor/optimized-decorative)
  -- uses the "entity-name" locale category.
  proto.localised_name = { "entity-name." .. original_name }
  return proto
end

local new_prototypes = {}
local decorative_settings = {}
local entity_settings = {}
local disabled_decoratives = {}
local disabled_entities = {}
local skipped = {}

local function add_entity(name, gate_expression)
  local collection = find_collection(name)
  if not collection then
    table.insert(skipped, name .. " (not found in any entity-like collection)")
    return
  end
  local proto = data.raw[collection][name]
  if not (proto.autoplace and proto.autoplace.probability_expression) then
    table.insert(skipped, name .. " (no autoplace of its own)")
    return
  end
  local clone = gated_clone(collection, name, gate_expression)
  table.insert(new_prototypes, clone)
  entity_settings[clone.name] = {}
  table.insert(disabled_entities, name)
end

local function add_decorative(name, gate_expression)
  local proto = data.raw["optimized-decorative"] and data.raw["optimized-decorative"][name]
  if not proto then
    table.insert(skipped, name .. " (not an optimized-decorative)")
    return
  end
  if not (proto.autoplace and proto.autoplace.probability_expression) then
    table.insert(skipped, name .. " (no autoplace of its own)")
    return
  end
  local clone = gated_clone("optimized-decorative", name, gate_expression)
  table.insert(new_prototypes, clone)
  decorative_settings[clone.name] = {}
  table.insert(disabled_decoratives, name)
end

-- Vulcanus
local vulcanus_entities = {
  "huge-volcanic-rock", "big-volcanic-rock",
  "vulcanus-chimney", "vulcanus-chimney-faded", "vulcanus-chimney-cold",
  "vulcanus-chimney-short", "vulcanus-chimney-truncated"
  -- "crater-cliff" is a cliff *style* (type="cliff"), not a placeable
  -- entity — part of the single-planet-wide cliff-appearance system
  -- already noted as a Factorio limitation, not gateable this way.
}
local vulcanus_decoratives = {
  "v-brown-carpet-grass", "v-green-hairy-grass", "v-brown-hairy-grass", "v-red-pita",
  "vulcanus-rock-decal-large", "vulcanus-crack-decal-large", "vulcanus-crack-decal-huge-warm",
  "vulcanus-dune-decal", "vulcanus-sand-decal", "vulcanus-lava-fire",
  "calcite-stain", "calcite-stain-small", "sulfur-stain", "sulfur-stain-small",
  "sulfuric-acid-puddle", "sulfuric-acid-puddle-small", "crater-small", "crater-large",
  "pumice-relief-decal", "small-volcanic-rock", "medium-volcanic-rock", "tiny-volcanic-rock",
  "tiny-rock-cluster", "small-sulfur-rock", "tiny-sulfur-rock", "sulfur-rock-cluster", "waves-decal"
}
for _, name in ipairs(vulcanus_entities) do add_entity(name, "simulacruis_vulcanus_weight") end
for _, name in ipairs(vulcanus_decoratives) do add_decorative(name, "simulacruis_vulcanus_weight") end

-- Fulgora
local fulgora_entities = {
  "fulgoran-ruin-vault", "fulgoran-ruin-attractor", "fulgoran-ruin-colossal",
  "fulgoran-ruin-huge", "fulgoran-ruin-big", "fulgoran-ruin-stonehenge",
  "fulgoran-ruin-medium", "fulgoran-ruin-small", "fulgurite", "big-fulgora-rock"
}
local fulgora_decoratives = {
  "fulgoran-ruin-tiny", "fulgoran-gravewort", "urchin-cactus",
  "medium-fulgora-rock", "small-fulgora-rock", "tiny-fulgora-rock"
}
for _, name in ipairs(fulgora_entities) do add_entity(name, "simulacruis_fulgora_weight") end
for _, name in ipairs(fulgora_decoratives) do add_decorative(name, "simulacruis_fulgora_weight") end

-- Gleba (yumako-tree/jellystem are the actual food-producing plants —
-- "jellystem" is the real prototype name for what the jellynut item
-- grows on; the ambient trees cuttlepop/slipstack/etc. are already
-- handled in trees.lua)
local gleba_entities = {
  "yumako-tree", "jellystem", "iron-stromatolite", "copper-stromatolite"
}
local gleba_decoratives = {
  "mycelium", "veins", "veins-small", "coral-water", "coral-land", "black-sceptre",
  "pink-phalanges", "brambles", "polycephalum-slime", "polycephalum-balloon", "fuchsia-pita",
  "wispy-lichen", "barnacles-decal", "coral-stunted", "coral-stunted-grey",
  "nerve-roots-dense", "nerve-roots-sparse", "yellow-coral", "solo-barnacle",
  "curly-roots-orange", "knobbly-roots", "knobbly-roots-orange", "matches-small",
  "honeycomb-fungus", "honeycomb-fungus-1x1", "honeycomb-fungus-decayed", "grey-cracked-mud-decal",
  "yellow-lettuce-lichen-1x1", "yellow-lettuce-lichen-3x3", "yellow-lettuce-lichen-6x6",
  "yellow-lettuce-lichen-cups-1x1", "yellow-lettuce-lichen-cups-3x3", "yellow-lettuce-lichen-cups-6x6",
  "green-lettuce-lichen-1x1", "green-lettuce-lichen-3x3", "green-lettuce-lichen-6x6",
  "green-lettuce-lichen-water-1x1", "green-lettuce-lichen-water-3x3", "green-lettuce-lichen-water-6x6",
  "pale-lettuce-lichen-cups-1x1", "pale-lettuce-lichen-cups-3x3", "pale-lettuce-lichen-cups-6x6",
  "pale-lettuce-lichen-1x1", "pale-lettuce-lichen-3x3", "pale-lettuce-lichen-6x6",
  "pale-lettuce-lichen-water-1x1", "pale-lettuce-lichen-water-3x3", "pale-lettuce-lichen-water-6x6",
  "split-gill-1x1", "split-gill-2x2", "split-gill-dying-1x1", "split-gill-dying-2x2",
  "split-gill-red-1x1", "split-gill-red-2x2", "pink-lichen-decal", "red-lichen-decal",
  "green-cup", "brown-cup", "blood-grape", "blood-grape-vibrant", "white-carpet-grass"
}
for _, name in ipairs(gleba_entities) do add_entity(name, "simulacruis_gleba_weight") end
for _, name in ipairs(gleba_decoratives) do add_decorative(name, "simulacruis_gleba_weight") end

-- Aquilo
local aquilo_entities = { "lithium-iceberg-huge", "lithium-iceberg-big" }
local aquilo_decoratives = {
  "lithium-iceberg-medium", "lithium-iceberg-small", "lithium-iceberg-tiny",
  "floating-iceberg-large", "floating-iceberg-small",
  "aqulio-ice-decal-blue", "aqulio-snowy-decal", "snow-drift-decal"
}
for _, name in ipairs(aquilo_entities) do add_entity(name, "simulacruis_aquilo_weight") end
for _, name in ipairs(aquilo_decoratives) do add_decorative(name, "simulacruis_aquilo_weight") end

data:extend(new_prototypes)

local planet = data.raw.planet.simulacruis
local autoplace = planet.map_gen_settings.autoplace_settings

for name, setting in pairs(entity_settings) do
  autoplace.entity.settings[name] = setting
end
for _, name in ipairs(disabled_entities) do
  autoplace.entity.settings[name] = { size = 0 }
end

for name, setting in pairs(decorative_settings) do
  autoplace.decorative.settings[name] = setting
end
for _, name in ipairs(disabled_decoratives) do
  autoplace.decorative.settings[name] = { size = 0 }
end

if #skipped > 0 then
  log("[space-age-all-in-one] planet-dressing.lua skipped " .. #skipped .. " names: " .. table.concat(skipped, "; "))
end
