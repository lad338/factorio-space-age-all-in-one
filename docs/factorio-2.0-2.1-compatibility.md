# Factorio 2.0 / 2.1 Compatibility & Backporting

`main` targets Factorio **2.1** (`info.json`: `"factorio_version": "2.1"`). A
separate branch/version line targets Factorio **2.0**, for players who
haven't updated their engine yet — as of this writing, `0.3.1` on
`lad338/0.3.1-factorio-2.0-backport`. This document records why that split
exists, exactly what differs between the two targets, and the repeatable
procedure for cutting a new 2.0 release once more fixes land on `main`.

## How Factorio's version pinning actually works

`info.json`'s `factorio_version` field is checked against the running
engine's major.minor, and it is a **hard match, not a floor**. Confirmed
empirically via `--dump-data`: a mod declaring `"2.0"` is rejected outright
by a 2.1 engine —

```
Incompatible Factorio version (current: 2.1, required: 2.0)
```

— and the reverse (declaring `"2.1"`, running on a 2.0 engine) fails the
same way. There is no range syntax. **One `info.json` cannot support both
2.0 and 2.1 engines at once.** That's why this repo maintains two release
lines from a shared codebase instead: `main` (2.1, version `0.4.x`) and a
periodically-recreated 2.0 backport branch (version `0.3.x`, continuing the
numbering from before the 2.1 migration).

## The four known 2.0 → 2.1 breaking changes

These were found by diffing this mod's own prototype usage against the
real installed 2.0 → 2.1 vanilla/expansion data. Nothing else in this
codebase has been found to touch any other 2.1-changed API, but see
"Checking for new breaks" below — that scope can grow as new features get
added on `main`.

### 1. `RecipePrototype.category` (singular) → `categories` (list)

2.1 removed the singular `category`/`additional_categories` fields —
recipes now list every category they belong to in a `categories` array.

- File: `prototypes/planet-promethium.lua`
- 2.0: `ground_recipe.category = "organic"`
- 2.1: `ground_recipe.categories = { "organic" }`

Setting the old singular field on 2.1 does **not** error — it silently
does nothing, leaving the deep-copied original's own `categories` value in
effect. Dangerous failure mode: no load error, just a recipe quietly
requiring the wrong building.

### 2. `ambient-sound.planet` (string) → `planets` (list)

2.1 renamed the field that associates a music track with a planet from a
single string to a list.

- File: `prototypes/planet-music.lua`
- 2.0: `clone.planet = "simulacruis"`, read as `SOURCE_PLANETS[ambient_sound.planet]`
- 2.1: `clone.planets = { "simulacruis" }`, read by iterating `ambient_sound.planets or {}`

Same silent-failure shape as #1: on 2.1, reading the old singular field
returns `nil` for every real track, so zero tracks get cloned — no error,
just silence instead of Simulacruis's intended playlist.

### 3. `recycler` split out into its own bundled mod

In 2.0, the `recycler` recipe/entity/technology lived inside `space-age`
itself. In 2.1, Wube split them out into a separate, `expansion_required`
bundled mod named `recycler`.

- File: `info.json`
- 2.0: dependencies = `["base >= 2.0.72", "space-age >= 2.0.72", "PlanetsLib >= 1.18.0"]`
  (no `recycler` entry — didn't exist as a separate mod)
- 2.1: added `"recycler >= 2.1.0"` to `dependencies`

Without this dependency, Factorio has no guarantee to load `recycler`'s
`data.lua` before this mod's own `data-updates.lua` runs, so
`data.raw.recipe["recycler"]` can be `nil` depending on load order.

### 4. `wood-processing` recipe renamed to `tree-seed`

Confirmed via `data/space-age/migrations/tree-seed.json`
(`["wood-processing", "tree-seed"]`) — same ingredients, same
`surface_conditions`, just a new name.

- File: `prototypes/planet-crafting.lua`
- 2.0: `restricted_recipes` list contains `"wood-processing"`
- 2.1: `restricted_recipes` list contains `"tree-seed"`

Referencing the old name on 2.1 is **not** silent — `data.raw.recipe["wood-processing"]`
is `nil`, so indexing into it throws `attempt to index field '?' (a nil value)`.

### Also checked, confirmed unaffected

- `MineEntityTechnologyTrigger.entity` → `entities`: this mod never uses
  `technology_trigger`/`MineEntityTechnologyTrigger` at all.
- PlanetsLib (the mod dependency): its own `factorio_version` also needed
  bumping (2.0 → 2.1) on the author's own release schedule — our `info.json`
  dependency floor tracks whatever the lowest version declaring the target
  engine is (`>= 1.18.0` for 2.0, `>= 1.26.2` for 2.1).

## Upgrading a 2.0 checkout to 2.1 (reference — already applied on `main`)

1. `info.json`: `"factorio_version"` → `"2.1"`; add `"recycler >= 2.1.0"`;
   bump the `PlanetsLib` floor.
2. `prototypes/planet-promethium.lua`: `category = "organic"` →
   `categories = { "organic" }`.
3. `prototypes/planet-music.lua`: `clone.planet = "simulacruis"` →
   `clone.planets = { "simulacruis" }`; change the `ambient_sound.planet`
   read to iterate `ambient_sound.planets or {}`.
4. `prototypes/planet-crafting.lua`: `"wood-processing"` → `"tree-seed"`.

## Downgrading a 2.1 checkout to 2.0 (exact reverse)

1. `info.json`: `"factorio_version"` → `"2.0"`; remove the `recycler`
   dependency entirely (it doesn't exist as a separate mod on 2.0); lower
   the `PlanetsLib` floor back down; also drop any dependency that is
   itself 2.1-only (e.g. `"? any-planet-start"` — that mod requires 2.1,
   so listing it on a 2.0 release is dead weight, not just inert).
2. `prototypes/planet-promethium.lua`: `categories = { "organic" }` →
   `category = "organic"`.
3. `prototypes/planet-music.lua`: `clone.planets = { "simulacruis" }` →
   `clone.planet = "simulacruis"`; revert the list-iteration read back to
   a direct `SOURCE_PLANETS[ambient_sound.planet]` lookup.
4. `prototypes/planet-crafting.lua`: `"tree-seed"` → `"wood-processing"`.

## Backporting new `main` fixes to the 2.0 line (the recurring task)

This is the part that repeats. Every time enough fixes accumulate on
`main` to be worth shipping to 2.0 players, redo this from scratch — **do
not try to fast-forward or rebase the previous backport branch**; it's
based on an older `main` and will conflict. Always start fresh from
current `main`.

1. **Branch from the current tip of `main`**, not from the previous
   backport branch:
   ```
   git checkout main && git pull
   git checkout -b lad338/<next-0.3.x>-factorio-2.0-backport
   ```

2. **Revert the four known API differences** — repeat the "Downgrading"
   section above exactly. Do this first, before anything else, so the
   rest of the diff review is against a tree that's already
   2.0-consistent.

3. **Check for NEW 2.1-only usage** introduced by whatever shipped on
   `main` since the last backport. The four known differences aren't
   guaranteed to be the only ones forever — new features can introduce new
   ones. Grep for the same patterns this doc already tracks:
   ```
   grep -rn "\.categories\s*=\s*{\|\.category\s*=\s*\"" prototypes/ --include="*.lua"
   grep -rn "\.planets\s*=\s*{\|ambient_sound\.planet\b" prototypes/ --include="*.lua"
   grep -rn "wood-processing\|tree-seed" prototypes/ --include="*.lua"
   grep -n "recycler" info.json
   ```
   If a genuinely new incompatibility turns up (not just these four),
   diagnose it the same way the originals were found — diff this mod's
   prototype/runtime API usage against what actually changed in that
   Factorio version's own changelog/migration files — and add it as a
   new numbered entry above so it doesn't need rediscovering next time.

4. **Everything else carries forward unchanged.** Bug fixes, new features,
   control.lua/runtime scripting changes — none of that is 2.0/2.1-specific
   unless it happens to touch one of the APIs above. Don't manually
   re-implement anything; the whole point of branching from `main` is that
   it's already there.

5. **Bump `info.json`'s version** to the next patch in the 2.0 line's own
   sequence (continuing from wherever it last left off — e.g. `0.3.0` →
   `0.3.1`, NOT matching whatever `main`'s current `0.4.x` number is; the
   two lines number independently).

6. **Rewrite `changelog.txt`** for this branch: fold every `main` entry
   since the last backport into a single new entry under the 2.0 line's
   own version number, with a one-line compatibility note explaining it's
   the Factorio 2.0 line carrying those fixes forward. Don't just copy
   `main`'s `0.4.x` entries verbatim onto this branch — those version
   numbers were never released here.

7. **Verify**, ideally against a real Factorio 2.0 engine if one is still
   available (`--dump-data` and `--create` a test save) — ports done
   without one still need this confirmed on 2.0 hardware before shipping,
   since new runtime-scripting APIs (new events, new `defines.*` entries)
   could theoretically also be version-gated, not just prototype fields.
   Nothing found so far has been, but that's not proven forever.

## Supporting both 2.0 and 2.1 from one branch (not done — why)

Possible in principle: branch the four spots above at data-stage on the
running engine's own version (`mods["base"]:match("^%d+%.(%d+)")` is
available at data stage), make the `recycler` dependency optional
(`"? recycler"`), and publish two separate mod-portal releases from one
shared codebase and CI pipeline. Not worth it here: doubles the
verification burden (a 2.1 engine can't verify the 2.0 branch of that
logic or vice versa — needs both installed), and the periodic-backport-
branch approach this doc describes gets the same outcome with less
standing complexity for a compatibility window that's expected to close
once Factorio 2.1 becomes the default/stable version most players are on.
At that point, retire the 2.0 line rather than keep backporting to it.
