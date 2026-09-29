-- Promethium science pack normally requires flying to the Shattered
-- Planet for promethium-asteroid-chunk, which forces every playthrough
-- into space travel even for players who'd rather stay grounded on
-- Simulacruis. This adds a ground-based alternative recipe so that
-- path is optional rather than mandatory.
--
-- The vanilla recipe: 5s craft time, ingredients
-- promethium-asteroid-chunk x25 + quantum-processor x1 + biter-egg x10,
-- produces promethium-science-pack x10, category = "cryogenics"
-- (a cryogenic-plant recipe). promethium-asteroid-chunk only comes from
-- the Shattered Planet, so this is the ground-based alternative: same
-- crafting time and same biter-egg/quantum-processor cost, substituting
-- 50 electrolyte (fluid, not item — Fulgora's own) + 1 spidertron for
-- the asteroid chunk.
--
-- category = "organic" specifically because that's the one and
-- only crafting category biochamber supports
-- (crafting_categories = {"organic"}) — using it
-- keeps this recipe exclusive to the biochamber, not craftable
-- somewhere else.
--
-- Singular `category` field (Factorio 2.0's RecipePrototype API — 2.1
-- replaces this with a `categories` list instead, see
-- docs/factorio-2.0-2.1-compatibility.md).
--
-- Left fully visible (not hidden/hidden_in_factoriopedia) — unlike the
-- crafting-restriction clones removed in planet-crafting.lua, this is a
-- genuinely different recipe offering a real choice (fly to the
-- Shattered Planet vs. build up spidertrons and electrolyte at home),
-- not a redundant duplicate of the same thing.
local original = data.raw.recipe["promethium-science-pack"]
local ground_recipe = table.deepcopy(original)
ground_recipe.name = "simulacruis-promethium-science-pack"
ground_recipe.categories = { "organic" }
ground_recipe.ingredients = {
  { type = "item", name = "quantum-processor", amount = 1 },
  { type = "item", name = "biter-egg", amount = 10 },
  { type = "fluid", name = "electrolyte", amount = 50 },
  { type = "item", name = "spidertron", amount = 1 }
}
-- Renaming drops the automatic name-from-internal-id convention —
-- without this the recipe shows literally "Unknown key" wherever its
-- name is displayed. Given a distinct label (not just a copy of the
-- original's) since, unlike every other clone in this mod, this one is
-- deliberately visible everywhere — two recipes both plainly named
-- "Promethium science pack" in the same biochamber/crafting picker
-- would be indistinguishable without hovering each one.
--
-- References "item-name", not "recipe-name" — no [recipe-name] entry
-- for "promethium-science-pack" exists at all (only [item-name] and
-- [technology-name]/[technology-description]), which is why the
-- original recipe's own display name already falls back to the
-- produced item's name. Pointing at the nonexistent recipe-name key
-- would resolve to "Unknown key" itself, embedded inside this
-- concatenation — showing "Unknown key (Biochamber)" instead of the
-- intended text.
ground_recipe.localised_name = { "", { "item-name.promethium-science-pack" }, " (Biochamber)" }

data:extend({ ground_recipe })

-- Unlocked alongside the same technology that unlocks the original —
-- this is an alternative path at the same tier, not a separate research
-- gate.
local promethium_tech = data.raw.technology["promethium-science-pack"]
promethium_tech.effects = promethium_tech.effects or {}
table.insert(promethium_tech.effects, { type = "unlock-recipe", recipe = ground_recipe.name })
