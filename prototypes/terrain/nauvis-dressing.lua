-- Confines Nauvis's own generic tiles/decoratives/rocks/resources/fish
-- to nauvis-owned patches — the same reason tiles.lua/trees.lua gate
-- the other four planets: these all use the redirectable
-- elevation/aux/moisture/temperature identifiers, which now resolve to
-- whichever planet is hard-selected at each point. Left un-gated,
-- Nauvis's own (fairly generic) placement formulas keep winning
-- placement competitions everywhere on the surface, not just within
-- nauvis-owned patches.
--
-- IMPORTANT: setting autoplace_settings.<type>.settings[name] = nil
-- does NOT disable an entity/decorative/resource/fish. With the entry
-- removed, tree-01 and dead-grey-trunk still placed thousands of times
-- across the whole surface. The reason is
-- AutoplaceSpecification.default_enabled, which
-- defaults to true and means "place with normal (1x) settings even if
-- this surface provides no explicit override" — removing the entry
-- doesn't disable placement, it just falls back to that default. The
-- real per-planet disable is an explicit {size = 0} override, which —
-- per AutoplaceSettings' own docs — takes priority over both the
-- control's and the prototype's own settings, without touching the
-- shared global prototype (so real Nauvis elsewhere in the galaxy is
-- unaffected). Applied here to tiles too (see tiles.lua for the same
-- fix applied there defensively, since this exact leak affects tiles
-- as well, not just entity-like things).

local function gated_clone(collection, original_name, gate_expression)
  local proto = table.deepcopy(data.raw[collection][original_name])
  proto.name = "simulacruis-" .. original_name
  proto.autoplace = proto.autoplace or {}
  proto.autoplace.probability_expression =
    "if(" .. gate_expression .. " > 0.5, " .. proto.autoplace.probability_expression .. ", -inf)"
  -- Fully functional (not `hidden`), just not a separate browsable
  -- Factoriopedia page — the original vanilla prototype (still
  -- meaningful on the real other planets) keeps that role. See
  -- data-updates.lua's header note for the full rationale.
  proto.hidden_in_factoriopedia = true
  -- Renaming drops the automatic name-from-internal-id convention —
  -- without this, every clone shows literally "Unknown key" wherever
  -- its name is displayed. Re-point at the original's own locale key.
  -- "tile" prototypes use the "tile-name" category; every other
  -- collection this helper is used for (decorative/simple-entity/
  -- resource/fish) uses "entity-name".
  local locale_category = collection == "tile" and "tile-name" or "entity-name"
  proto.localised_name = { locale_category .. "." .. original_name }
  return proto
end

local nauvis_tiles = {
  "grass-1", "grass-2", "grass-3", "grass-4", "dry-dirt",
  "dirt-1", "dirt-2", "dirt-3", "dirt-4", "dirt-5", "dirt-6", "dirt-7",
  "sand-1", "sand-2", "sand-3",
  "red-desert-0", "red-desert-1", "red-desert-2", "red-desert-3",
  "water", "deepwater"
}

-- Complete list of Nauvis's own decoratives
local nauvis_decoratives = {
  "cracked-mud-decal", "dark-mud-decal", "lichen-decal", "light-mud-decal",
  "small-rock", "small-sand-rock", "tiny-rock", "medium-rock", "medium-sand-rock",
  "brown-asterisk", "brown-asterisk-mini", "brown-carpet-grass", "brown-fluff",
  "brown-fluff-dry", "brown-hairy-grass", "garballo", "garballo-mini-dry",
  "green-asterisk", "green-asterisk-mini", "green-bush-mini", "green-carpet-grass",
  "green-croton", "green-desert-bush", "green-hairy-grass", "green-pita",
  "green-pita-mini", "green-small-grass", "red-asterisk", "red-croton",
  "red-desert-bush", "red-desert-decal", "red-pita", "sand-decal",
  "sand-dune-decal", "white-desert-bush"
}

local nauvis_simple_entities = { "big-rock", "big-sand-rock", "huge-rock" }

-- Nauvis's own resources (ores + fish). Per-resource richness tuning
-- (tiny scrap, no tungsten before Zone 3, etc.) and the other four
-- planets' own resources are still separate, later work — this only
-- stops Nauvis's resources from leaking outside Nauvis-owned patches.
local nauvis_resources = { "iron-ore", "copper-ore", "stone", "coal", "crude-oil", "uranium-ore" }
local nauvis_fish = { "fish" }

local new_tiles = {}
local new_decoratives = {}
local new_simple_entities = {}
local new_resources = {}
local new_fish = {}
local tile_settings = {}
local decorative_settings = {}
local entity_settings = {}

for _, name in ipairs(nauvis_tiles) do
  local clone = gated_clone("tile", name, "simulacruis_nauvis_weight")
  table.insert(new_tiles, clone)
  tile_settings[clone.name] = {}
end

-- deepwater's own transition_merges_with_tile/allowed_neighbors both
-- hardcode the literal name "water" — the
-- engine merges deep water's edge transition with shallow water's own
-- shore graphic through this reference, which is how a real lake gets
-- its shallow-to-deep gradient look instead of rendering as one flat
-- "puddle" color throughout. Left pointing at the original (disabled)
-- "water" tile, the renamed clone can't find a match and loses that
-- depth blending — same root cause as tiles.lua's own lava/lava-hot
-- fix, just caught later since it only degrades rendering quality
-- (the terrain itself still places and functions correctly) rather
-- than breaking placement outright.
for _, tile in ipairs(new_tiles) do
  if tile.name == "simulacruis-deepwater" then
    tile.transition_merges_with_tile = "simulacruis-water"
    tile.allowed_neighbors = { "simulacruis-water" }
  end
end

for _, name in ipairs(nauvis_decoratives) do
  if data.raw["optimized-decorative"][name] then
    local clone = gated_clone("optimized-decorative", name, "simulacruis_nauvis_weight")
    table.insert(new_decoratives, clone)
    decorative_settings[clone.name] = {}
  end
end

for _, name in ipairs(nauvis_simple_entities) do
  if data.raw["simple-entity"][name] then
    local clone = gated_clone("simple-entity", name, "simulacruis_nauvis_weight")
    table.insert(new_simple_entities, clone)
    entity_settings[clone.name] = {}
  end
end

for _, name in ipairs(nauvis_resources) do
  local clone = gated_clone("resource", name, "simulacruis_nauvis_weight")
  table.insert(new_resources, clone)
  entity_settings[clone.name] = {}
end

for _, name in ipairs(nauvis_fish) do
  local clone = gated_clone("fish", name, "simulacruis_nauvis_weight")
  table.insert(new_fish, clone)
  entity_settings[clone.name] = {}
end

data:extend(new_tiles)
data:extend(new_decoratives)
data:extend(new_simple_entities)
data:extend(new_resources)
data:extend(new_fish)

local planet = data.raw.planet.simulacruis
local autoplace = planet.map_gen_settings.autoplace_settings

for name, setting in pairs(tile_settings) do
  autoplace.tile.settings[name] = setting
end
for _, name in ipairs(nauvis_tiles) do
  autoplace.tile.settings[name] = { size = 0 }
end

autoplace.decorative = autoplace.decorative or { settings = {} }
autoplace.decorative.settings = autoplace.decorative.settings or {}
for name, setting in pairs(decorative_settings) do
  autoplace.decorative.settings[name] = setting
end
for _, name in ipairs(nauvis_decoratives) do
  autoplace.decorative.settings[name] = { size = 0 }
end

for name, setting in pairs(entity_settings) do
  autoplace.entity.settings[name] = setting
end
for _, name in ipairs(nauvis_simple_entities) do
  autoplace.entity.settings[name] = { size = 0 }
end
for _, name in ipairs(nauvis_resources) do
  autoplace.entity.settings[name] = { size = 0 }
end
for _, name in ipairs(nauvis_fish) do
  autoplace.entity.settings[name] = { size = 0 }
end
