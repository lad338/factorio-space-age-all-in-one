-- Simulacruis-Nauvis is 5k km,
-- Simulacruis to Vulcanus/Fulgora/Gleba is 15k km each (matching
-- vanilla's own nauvis-to-{vulcanus,fulgora,gleba} lengths), and Aquilo
-- stays reachable only via a stop in Gleba or Fulgora, same as vanilla
-- — so no direct simulacruis-aquilo connection is added; the existing
-- gleba-aquilo/fulgora-aquilo connections already enforce that once
-- Simulacruis can reach Gleba or Fulgora.
--
-- These are pure additions alongside the vanilla nauvis-* connections,
-- not replacements — Nauvis keeps its own original connections to
-- Vulcanus/Fulgora/Gleba too. Simulacruis-Vulcanus is simply shorter in
-- practice, so those old routes just become unused rather than needing
-- removal.
--
-- Cloned from the equivalent vanilla nauvis-* connection (same length
-- class) rather than hand-built, so each trip keeps vanilla's own
-- asteroid spawn tables instead of having none at all.
local function clone_connection(source_name, new_name, from, to, length)
  local proto = table.deepcopy(data.raw["space-connection"][source_name])
  proto.name = new_name
  proto.from = from
  proto.to = to
  proto.length = length
  return proto
end

data:extend({
  clone_connection("nauvis-vulcanus", "simulacruis-nauvis", "simulacruis", "nauvis", 5000),
  clone_connection("nauvis-vulcanus", "simulacruis-vulcanus", "simulacruis", "vulcanus", 15000),
  clone_connection("nauvis-fulgora", "simulacruis-fulgora", "simulacruis", "fulgora", 15000),
  clone_connection("nauvis-gleba", "simulacruis-gleba", "simulacruis", "gleba", 15000)
})

-- Travel to Nauvis is meant to require researching space platform
-- thrusters, same as reaching any other planet — but that gate is NOT
-- handled here via an unlock-space-location technology effect: Nauvis
-- is already unlocked (LuaForce::is_space_location_unlocked) before
-- any research at all, on a brand-new game. That's freeplay's own
-- scenario script unconditionally unlocking Nauvis by name (mirroring vanilla's
-- assumption that Nauvis, being the only home planet, needs no
-- discovery step), not something granted by a technology effect — so
-- adding one here would have been silently inert. See control.lua for
-- the actual fix: explicitly re-lock Nauvis at game start and unlock
-- it on researching space-platform-thruster.
