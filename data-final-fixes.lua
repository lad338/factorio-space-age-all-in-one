-- Runs after every mod's own data-updates.lua, regardless of load
-- order — needed for compatibility fixes that have to win a race
-- against another mod's own data-updates.lua edits (see
-- mod-compatibility.lua for why).
require("prototypes.terrain.mod-compatibility")
