-- Defensive cleanup against other mods adding surface_conditions to
-- shared, unrenamed vanilla prototypes this mod also relies on (seeds
-- aren't cloned per-planet — see planet-dressing.lua — so anything
-- another mod bolts onto the original plant affects Simulacruis too).
-- Runs in data-final-fixes, after every mod's own data-updates.lua, so
-- this always wins regardless of mod load order.
--
-- Known case: Factorissimo (notnotmelon's continuation) adds
-- `{property = "pressure", min = 2000, max = 2000}` directly to the
-- shared "yumako-tree"/"jellystem" plant prototypes, gating its own
-- greenhouse feature to real Gleba's pressure. Simulacruis deliberately
-- keeps Nauvis's own pressure (1000) instead — see planet-crafting.lua's
-- own note on why fish-breeding/wood-processing need exactly that — so this
-- condition can never be satisfied there, blocking agricultural towers
-- from planting yumako/jellynut seeds at all.
for _, plant_name in ipairs({ "yumako-tree", "jellystem" }) do
  local plant = data.raw.plant[plant_name]
  if plant then
    plant.surface_conditions = nil
  end
end
