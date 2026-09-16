-- Confines each planet's own tree species to its own zone-owned
-- patches, for the same reason tiles.lua gates tiles: tree autoplace
-- formulas reference their source planet's own fields directly, not
-- the redirectable elevation/aux identifiers, so without gating,
-- Nauvis's own trees (and Vulcanus's/Gleba's) would grow everywhere on
-- Simulacruis rather than only in their own biome.
--
-- Disabling the originals uses an explicit {size = 0} override, not
-- `= nil` — removing the entry
-- entirely does NOT disable placement (AutoplaceSpecification.
-- default_enabled defaults to true, so a missing entry just falls back
-- to full-on default settings). See nauvis-dressing.lua for the full
-- explanation.

-- See planet-dressing.lua's remap_tile_restriction for why this is
-- needed: a tree restricted to specific ground tiles would otherwise
-- keep referencing the pre-rename tile names, which no longer exist as
-- autoplaced tiles on Simulacruis. This file runs after tiles.lua, so
-- the renamed tiles already exist to check against.
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

-- tree-01 through tree-09 (and their -red/-brown color variants) have
-- NO "entity-name.<name>" locale entry at all in vanilla, unlike
-- dead-tree-desert/dry-tree/dead-grey-trunk/dry-hairy-tree/dead-dry-
-- hairy-tree, which do. Their real vanilla display name comes entirely
-- from Factorio's automatic name-from-internal-id fallback, which only
-- engages when localised_name is left UNSET — pointing at the
-- nonexistent key anyway (as gated_tree_clone otherwise does
-- unconditionally below) resolves to literal "Unknown key" instead,
-- same failure mode as planet-promethium.lua's own recipe-name/item-
-- name mixup. Left unset for these, the renamed clone's own fallback
-- kicks in instead (e.g. "simulacruis-tree-01" auto-generates its own
-- reasonable display name), rather than forcing a reference to a key
-- that was never there to begin with.
local NO_ENTITY_NAME_LOCALE_KEY = {
  ["tree-01"] = true, ["tree-02"] = true, ["tree-02-red"] = true, ["tree-03"] = true,
  ["tree-04"] = true, ["tree-05"] = true, ["tree-06"] = true, ["tree-06-brown"] = true,
  ["tree-07"] = true, ["tree-08"] = true, ["tree-08-brown"] = true, ["tree-08-red"] = true,
  ["tree-09"] = true, ["tree-09-brown"] = true, ["tree-09-red"] = true,
}

local function gated_tree_clone(original_name, gate_expression)
  local tree = table.deepcopy(data.raw.tree[original_name])
  tree.name = "simulacruis-" .. original_name
  tree.autoplace = tree.autoplace or {}
  tree.autoplace.probability_expression =
    "if(" .. gate_expression .. " > 0.5, " .. tree.autoplace.probability_expression .. ", -inf)"
  remap_tile_restriction(tree)
  -- Fully functional, just not a separate browsable Factoriopedia page
  -- (see data-updates.lua's header note).
  tree.hidden_in_factoriopedia = true
  -- Renaming drops the automatic name-from-internal-id convention —
  -- without this, every clone shows literally "Unknown key" wherever
  -- its name is displayed. Re-point at the original's own locale key,
  -- except for the tree-0X group above, which has no such key to
  -- point at.
  if not NO_ENTITY_NAME_LOCALE_KEY[original_name] then
    tree.localised_name = { "entity-name." .. original_name }
  end
  return tree
end

local new_trees = {}
local entity_settings = {}
local originals_to_disable = {}

local function add_tree(name, gate_expression)
  local clone = gated_tree_clone(name, gate_expression)
  table.insert(new_trees, clone)
  entity_settings[clone.name] = {}
  table.insert(originals_to_disable, name)
end

-- Nauvis's own standard trees: every tree entity using the shared
-- "trees" autoplace control
for name, tree in pairs(data.raw.tree) do
  if tree.autoplace and tree.autoplace.control == "trees" then
    add_tree(name, "simulacruis_nauvis_weight")
  end
end

-- Vulcanus's ashland trees.
add_tree("ashland-lichen-tree", "simulacruis_vulcanus_weight")
add_tree("ashland-lichen-tree-flaming", "simulacruis_vulcanus_weight")

-- Gleba's own trees.
local gleba_trees = {
  "cuttlepop", "slipstack", "funneltrunk", "hairyclubnub", "teflilly",
  "lickmaw", "stingfrond", "boompuff", "sunnycomb", "water-cane"
}
for _, name in ipairs(gleba_trees) do
  add_tree(name, "simulacruis_gleba_weight")
end

data:extend(new_trees)

-- Merge the gated clones in, and disable the un-gated originals that
-- Simulacruis inherited from the Nauvis deepcopy (or, for Vulcanus's
-- and Gleba's trees, that may already be present in their own
-- autoplace_settings.entity.settings if this file ever runs after
-- something else adds them) — otherwise both the gated clone AND the
-- original would be active simultaneously, defeating the gating.
local planet = data.raw.planet.simulacruis
local entity_autoplace = planet.map_gen_settings.autoplace_settings.entity
for name, setting in pairs(entity_settings) do
  entity_autoplace.settings[name] = setting
end
for _, name in ipairs(originals_to_disable) do
  entity_autoplace.settings[name] = { size = 0 }
end
