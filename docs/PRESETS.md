# Preset characters

Who each of the 20 archetypes is, so the player can tell them apart by how they look, fly and fight.
Era 68's evolution is the starting point. Each preset begins as an evolved design (**Base**, an era 68
genome that fitness ranks level with the best of its archetype, or close), then takes hand **Tweaks**
toward its character. Rules and laws stay as they are: a tweak moves genes, never stats.

How to edit a sheet:
- **Tweaks** is a list in backticks:
  - `gene: from -> to` for a pilot gene;
  - `share.<structure|engine|reactor|capacitor|hold>: from -> to` for a hull share;
  - `+<kind>_<weight>` or `-<kind>_<weight>` to add or remove a part, for example `+laser_light`.
- Pilot genes (Constants.EVO_BEHAVIOR_RANGES):

  | Gene | Range | What it does |
  |---|---|---|
  | engage | 0.3–4 | the desire it needs before it **starts** a fight: high is picky, low is eager |
  | disengage | 0.1–3 | below this desire it breaks off: high gives up early |
  | retreat_hull | 0–0.8 | hull share at which it runs home whatever the odds (0: never) |
  | pursuit | 0–3 | how far it chases a runner |
  | mercy | 0–1 | chance it lets a runner go that isn't shooting back |
  | return_fire | 0–1 | chance it shoots back while running |
  | teamwork | 0–2 | helps friends and follows leaders; armed ships at 0.8 or more escort traders; traders wait longer for a caravan |
  | caution | 0–1 | keeps clear of enemies it hasn't been seen by |
  | quiet | 0–0.9 | thrust it cuts while sneaking (a lower signature) |
  | range | 0.3–1.5 | orbit distance as a share of its laser's reach |
  | burn | 0–0.8 | power kept back from the afterburner for weapons |
  | haul | 0.05–1 | how full it gets before going home to sell |

- **Running it:** the dev tool's **Archetypes from character sheets** task (Tasks, Content), or `python3 tools/devtool/presets.py price|build`:
  - `price` fills the Price lines;
  - `build` remakes the archetypes from the sheets (a sheet that changes nothing leaves its files alone), then refits and classifies them;
  - the base is the genome's last life in evolution's newest life log;
  - test the characters with the **Duel two archetypes** task, with Free set to yes.
- **Price** is the era model's estimate of what the tweaks cost or gain in fitness. Fitness is return on cost, less 1 for a lost ship, and one life's luck swings it by 0.4–1.4. The estimate is filled in by the pricing script, so don't edit it. For fighters, raiders and scavengers the model explains about a fifth of fitness. For prospectors and traders it explains almost nothing: their design hardly changes fitness, so they're free to design.
- For fighters and raiders, being picky (high engage) and holding on once in a fight (low disengage) pay best. So making a combat pilot eager, or quick to give up, has a real price.

## Fighters: faction warships

### fighter_light · Skirmisher
*A fast, fragile fighter: it picks its fight, then chases it down and shows no mercy.*
- **Strengths:** fastest of the lights, hits hard · **Weakness:** fragile · **Quirk:** chases runners, never spares
- **Looks:** two light cannons and a light laser (tracers and a beam)
- **Base:** `X22672i1` (the current pick)
- **Tweaks:** `pursuit: 0.50 -> 1.80`, `mercy: 0.35 -> 0.05`, `retreat_hull: 0.70 -> 0.40`
- **Price:** tweaks +0.05 fitness (±0.16), death chance +1 pts, earnings +0.03 of cost; base ties with its archetype's best (31 lives)

### fighter_medium · Escort
*Guards traders: it takes a ward and stays with it, opening with a missile from range.*
- **Strengths:** reach, guards others · **Weakness:** fragile · **Quirk:** lets runners go; it's guarding, not hunting
- **Looks:** a medium missile rack, light and medium cannons
- **Base:** `X23060i2` (the current pick)
- **Tweaks:** `teamwork: 1.05 -> 1.80`, `mercy: 0.28 -> 0.60`, `pursuit: 1.06 -> 0.50`
- **Price:** tweaks -0.09 fitness (±0.14), death chance -2 pts, earnings -0.01 of cost; base ties with its archetype's best (25 lives)

### fighter_heavy · Missile boat
*Hangs back and sneaks, then fires missile volleys from far off.*
- **Strengths:** longest reach, quiet · **Weakness:** light guns up close · **Quirk:** keeps its distance
- **Looks:** three missile racks (light x2, heavy) and a medium cannon
- **Base:** `V23774i2` (the current pick; only 8 lives)
- **Tweaks:** `range: 1.10 -> 1.50`, `quiet: 0.57 -> 0.85`, `caution: 0.46 -> 0.80`, `engage: 0.73 -> 2.00`
- **Price:** tweaks +0.33 fitness (±0.21), death chance -3 pts, earnings +0.05 of cost; base ties with its archetype's best (8 lives)

### fighter_superheavy · Gunship
*A slow fortress firing every kind of weapon at once; others rally to it.*
- **Strengths:** firepower, toughness · **Weakness:** slowest of all · **Quirk:** stands its ground, leads a group
- **Looks:** three heavy cannons, two lasers, two missile racks
- **Base:** `R23262i2` (the current pick)
- **Tweaks:** `teamwork: 0.08 -> 1.20`, `disengage: 1.73 -> 0.60`, `retreat_hull: 0.18 -> 0.00`
- **Price:** tweaks +0.17 fitness (±0.25), death chance +7 pts, earnings +0.09 of cost; base ties with its archetype's best (18 lives)

## Raiders: pirates with a harpoon for cargo

### raider_light · Thief
*A fast thief: it harpoons cargo and runs, and lets its victims go.*
- **Strengths:** fast, cheap · **Weakness:** fragile, runs early · **Quirk:** merciful; it doesn't shoot back while running
- **Looks:** two light cannons and a harpoon
- **Base:** `X22624i2` (the best-ranked light raider; the current pick is its sibling)
- **Tweaks:** `mercy: 0.32 -> 0.85`, `return_fire: 0.35 -> 0.10`
- **Price:** tweaks -0.10 fitness (±0.20), death chance +6 pts, earnings +0.01 of cost; base ties with its archetype's best (15 lives)

### raider_medium · Bruiser
*Two medium cannons and no mercy: once it's on you, it doesn't let go.*
- **Strengths:** hits hard, relentless · **Weakness:** fragile · **Quirk:** chases to the end, fights to the last
- **Looks:** two medium cannons and a harpoon
- **Base:** `X22730i4` (the best-ranked medium raider)
- **Tweaks:** `pursuit: 1.06 -> 2.60`, `mercy: 0.28 -> 0.00`, `retreat_hull: 0.65 -> 0.40`
- **Price:** tweaks -0.19 fitness (±0.20), death chance +8 pts, earnings -0.01 of cost; base ties with its archetype's best (27 lives)

### raider_heavy · Corsair
*Long laser beams and a heavy lance; it chases far, spares those who yield, and has a big hold for loot.*
- **Strengths:** reach, big hold · **Weakness:** weak guns for its size · **Quirk:** relentless but merciful
- **Looks:** three lasers (heavy, medium x2), a heavy lance, a harpoon
- **Base:** `V22708i1` (the current pick; only 6 lives)
- **Tweaks:** `engage: 0.57 -> 1.50`
- **Price:** tweaks +0.19 fitness (±0.09), death chance -2 pts, earnings +0.03 of cost; base ties with its archetype's best (6 lives)

### raider_superheavy · Pirate flagship
*Fast for its size, carries every weapon, and pirate packs follow it.*
- **Strengths:** speed for its size, reach · **Weakness:** costly · **Quirk:** leads packs, spares those who yield
- **Looks:** heavy and medium cannons, a heavy laser, a heavy missile rack, a harpoon
- **Base:** `V23469i2` (the current pick)
- **Tweaks:** `teamwork: 1.02 -> 1.80`, `engage: 0.30 -> 1.20`
- **Price:** tweaks +0.10 fitness (±0.12), death chance +7 pts, earnings +0.05 of cost; base ties with its archetype's best (9 lives)

## Prospectors: miners with a laser, a lance and a harpoon

### prospector_light · Rock-hopper
*A cheap little miner that slips away from anything armed.*
- **Strengths:** cheap, careful · **Weakness:** two light lasers are all it has · **Quirk:** sneaks; runs rather than shoots back
- **Looks:** two light lasers, a light lance, a harpoon
- **Base:** `V22788i4` (level with the pick)
- **Tweaks:** `quiet: 0.25 -> 0.70`, `return_fire: 1.00 -> 0.30`
- **Price:** tweaks: no reliable effect (design hardly moves this role's fitness); base ties with its archetype's best (15 lives)

### prospector_medium · Armed miner
*Mines with missiles at hand to keep pirates honest, and shoots back while it runs.*
- **Strengths:** tough, reach · **Weakness:** slow · **Quirk:** shoots back, sticks with friends
- **Looks:** light and medium missile racks, a light laser, a medium lance, a harpoon
- **Base:** `R22598i1` (level with the pick)
- **Tweaks:** `return_fire: 0.25 -> 0.90`
- **Price:** tweaks: no reliable effect (design hardly moves this role's fitness); base ties with its archetype's best (17 lives)

### prospector_heavy · Core miner
*A deep-core miner with two lances and a heavy sensor that finds rock first.*
- **Strengths:** two lances, sees far · **Weakness:** avoids fights · **Quirk:** won't chase anyone
- **Looks:** heavy and light lances, heavy and medium lasers, a heavy sensor, a harpoon
- **Base:** `V21947i2` (level with the pick)
- **Tweaks:** `engage: 0.56 -> 2.50`, `pursuit: 1.78 -> 0.30`
- **Price:** tweaks: no reliable effect (design hardly moves this role's fitness); base ties with its archetype's best (26 lives)

### prospector_superheavy · Mining barge
*A slow armoured barge with decoys and a heavy missile, mining in company.*
- **Strengths:** toughest miner, decoys · **Weakness:** slow · **Quirk:** stays with friends
- **Looks:** a heavy missile rack, a medium laser, a medium lance, heavy plating, heavy decoys and sensor
- **Base:** `V23356i1` (level with the pick)
- **Tweaks:** `teamwork: 1.15 -> 1.80`, `share.engine: 0.27 -> 0.18`, `share.structure: 0.41 -> 0.50`
- **Price:** tweaks: no reliable effect (design hardly moves this role's fitness); base ties with its archetype's best (10 lives); speed -29%, hull +11%

## Scavengers: unarmed salvagers with a harpoon

### scavenger_light · Picker
*A tiny, sneaky picker that creeps in for scraps and flees at first sight.*
- **Strengths:** cheap, sneaky · **Weakness:** fragile · **Quirk:** quiet, quick to flee
- **Looks:** a harpoon and a light thruster
- **Base:** `V22635i3` (the current pick)
- **Tweaks:** `quiet: 0.26 -> 0.80` (a faster hull was priced too: fast scavengers die far more often)
- **Price:** tweaks -0.09 fitness (±0.14), death chance +10 pts, earnings +0.00 of cost; base ties with its archetype's best (30 lives)

### scavenger_medium · Vulture
*The fastest hull of its weight: it circles fights, burns in, finishes cripples with its lance and harpoons the wreck.*
- **Strengths:** fastest medium, a lance · **Weakness:** tiny hold · **Quirk:** stalks fights, no mercy
- **Looks:** a medium lance, a light afterburner, a harpoon
- **Base:** `V23965i2` (the current pick)
- **Tweaks:** `pursuit: 1.65 -> 2.40`, `mercy: 0.54 -> 0.10`
- **Price:** tweaks +0.16 fitness (±0.09), death chance -15 pts, earnings +0.01 of cost; base ties with its archetype's best (17 lives)

### scavenger_heavy · Salvage tug
*An armoured tug with decoys: slow, steady, and it never runs.*
- **Strengths:** tough, decoys · **Weakness:** slow · **Quirk:** never runs home
- **Looks:** heavy plating, power cells, a light thruster, medium decoys, a harpoon
- **Base:** `V17072i6` (the current pick)
- **Tweaks:**
- **Price:** tweaks: about free; base ties with its archetype's best (27 lives)

### scavenger_superheavy · Ghost barge
*Jams sensors with dampers, scatters decoys, and slips in quietly.*
- **Strengths:** hard to lock, decoys · **Weakness:** no armour to speak of · **Quirk:** sneaks
- **Looks:** two dampers, three decoy launchers, a heavy thruster, a harpoon
- **Base:** `V22596i1`
- **Tweaks:** `quiet: 0.25 -> 0.85`, `caution: 0.56 -> 0.90`
- **Price:** tweaks -0.16 fitness (±0.22), death chance +18 pts, earnings +0.02 of cost; base 0.17 below its archetype's best (39 lives)

## Traders: unarmed or lightly armed haulers

### trader_light · Courier
*Small and fast; it outruns trouble rather than facing it.*
- **Strengths:** fast · **Weakness:** small hold, fragile · **Quirk:** flees anything
- **Looks:** a bare hull
- **Base:** `V22658i4` (the current pick)
- **Tweaks:** `share.engine: 0.13 -> 0.32`, `share.hold: 0.46 -> 0.27`
- **Price:** tweaks: no reliable effect (design hardly moves this role's fitness); base ties with its archetype's best (21 lives); speed +127%, hold -41%

### trader_medium · Smuggler
*Jams pursuers with a damper and runs quiet.*
- **Strengths:** hard to lock, big hold · **Weakness:** fragile · **Quirk:** sneaks, spares
- **Looks:** a medium damper
- **Base:** `V21949i2` (level with the pick)
- **Tweaks:** `quiet: 0.08 -> 0.80`, `caution: 0.74 -> 0.95`
- **Price:** tweaks: no reliable effect (design hardly moves this role's fitness); base ties with its archetype's best (22 lives)

### trader_heavy · Armed merchant
*Two lasers and two missile racks, and it shoots back; it travels in caravans.*
- **Strengths:** armed, big hold · **Weakness:** slow · **Quirk:** returns fire while running
- **Looks:** two medium lasers, two light missile racks
- **Base:** `V22629i3` (the current pick)
- **Tweaks:** `return_fire: 0.00 -> 0.90`
- **Price:** tweaks: no reliable effect (design hardly moves this role's fitness); base ties with its archetype's best (17 lives)

### trader_superheavy · Bulk hauler
*The biggest hold of all, bristling with missiles but fragile; it waits for escorts.*
- **Strengths:** biggest hold, missiles · **Weakness:** fragile, slow · **Quirk:** waits longest for a caravan
- **Looks:** four missile racks (light x2, medium x2) and a light laser
- **Base:** `V23861i2` (the current pick)
- **Tweaks:** `teamwork: 1.64 -> 2.00`, `return_fire: 0.00 -> 0.60`
- **Price:** tweaks: no reliable effect (design hardly moves this role's fitness); base ties with its archetype's best (26 lives)

## Built and benched (2026-11-24)

All 20 sheets are built into `database/presets/archetypes/`: each one is its base genome with the tweaks applied, then refit and classified. The Salvage tug has no tweaks and keeps its files. Each origin reads "…(era 68), tuned by hand". The fitness shown in CATALOG.md is the base's era 68 ranking.

Bench: `tools/lance_duel.gd --archetypes="a,b;c,d" --free`. The first ship is set on the second once, and after that both fly by their genes. Results from 8 to 12 duels per matchup, old archetypes against tuned ones:

| Matchup | Old | Tuned | Reads as |
|---|---|---|---|
| Bruiser vs Smuggler | Smuggler flees 78% of the time | lies low 35%, flees 49% | the Smuggler hides instead of running |
| Vulture vs Smuggler | lies low 0% | lies low 58% | the same; the Vulture still wins 8 of 8 |
| Bruiser vs Armed miner | miner wins 3, 5 draws | miner wins 8 of 8; the Bruiser fights to the end | the Bruiser never lets go, and the miner shoots back |
| Escort vs Bruiser | Escort wins 5, 3 draws | Escort wins 8 of 8 | the Bruiser pays for holding on |
| Missile boat vs Corsair | Missile boat wins 7, 1 draw | wins 0, loses 2, breaks off 6; runs dark or lies low 19% of the time | it hangs back and slips away (without the range and caution tweaks: 7 wins, 5 losses) |
| Skirmisher vs Thief | Skirmisher wins 1, 7 draws | Thief wins 1, 7 draws | the Thief's base is the stronger raider: the old Skirmisher loses 4 of 12 to it too |
| Thief vs Courier | the raider lets go 8 of 8 | the same | no reading: an empty Courier isn't worth attacking, so mercy never comes up |
| Gunship vs Pirate flagship | Gunship wins 8 of 8 | the same | no change |

Not seen on the bench: teamwork (escorts, caravans and packs need a world) and the Thief's mercy (it needs a target carrying cargo).
