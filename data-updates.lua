-- Every simulacruis-<name> clone created below (tiles, trees,
-- decoratives, resources, enemies, recipes, ...) sets
-- `hidden_in_factoriopedia = true`. Cloning itself is not optional —
-- Factorio resolves autoplace/recipe formulas by a global name, so the
-- only way to give the "same" thing different placement/crafting rules
-- on Simulacruis without changing it on the real other planets
-- (unacceptable: e.g. real Vulcanus would lose its own foundry
-- restriction too) is a separate, renamed prototype. But that leaves
-- ~360 near-duplicate entries cluttering Factoriopedia. `hidden` would
-- also make them unselectable in menus/machines, which breaks them —
-- `hidden_in_factoriopedia` is the one flag that hides only the
-- browsable encyclopedia page while leaving the clone fully functional.
-- The original vanilla prototype keeps its own page, since it's still
-- meaningful when visiting the real planet it came from.
require("prototypes.terrain.zone-masks")
require("prototypes.terrain.biome-regions")
require("prototypes.terrain.property-expressions")
require("prototypes.planet-simulacruis")
require("prototypes.terrain.biome-mix-controls")
require("prototypes.terrain.tiles")
require("prototypes.terrain.trees")
require("prototypes.terrain.nauvis-dressing")
require("prototypes.terrain.tile-placement-items")
require("prototypes.terrain.planet-dressing")
require("prototypes.terrain.planet-resources")
require("prototypes.terrain.starter-oil")
require("prototypes.terrain.planet-enemies")
require("prototypes.terrain.planet-demolishers")
require("prototypes.terrain.nuke-lava")
require("prototypes.planet-crafting")
require("prototypes.planet-space-map")
require("prototypes.planet-research")
require("prototypes.planet-promethium")
require("prototypes.planet-music")

-- Alternative map shape, selected per-map from the Map Generator's own
-- Terrain tab (see prototypes/terrain/islands.lua for details) rather
-- than a startup setting, so no game restart is needed to switch it.
require("prototypes.terrain.islands")
