# GDTLancer

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

**GDTLancer** is a harsh, single-player space game about fitting a ship from parts and taking it into dangerous sectors. Runs are short. Think *Pixel Dungeon in space, with EVE-style fitting*.

There is a clear "right way" to play, and the rules are consistent enough to leave room for unorthodox approaches without designing for them.

## Design Principles

- **One set of rules for everyone.** The player and the AI follow the same rules. Nothing is scripted to happen.
- **Parts change verbs, not just numbers.** Every part has a legitimate purpose.
- **A few interacting rules, not many rules.**
- **The world reacts by its rules.** For example, predators weigh expected gain against risk.
- **Parity between player and NPCs.** Whatever an NPC knows or can do, the player gets an equivalent, and vice versa. NPCs read numbers; the player reads the same facts as cues (a target's difficulty, who can see you, your own signature). NPCs act like players: they hesitate before deciding, faster when skilled, slower when the call is close.

## Setting

A raw, early-stage frontier. There are no sprawling empires or massive navies, only small, isolated communities where spaceflight is rare, perilous and logistically heavy.

## Status

The project is pruned back to its flight core. What works now:

- 6DOF RigidBody flight with PID autopilot commands: approach, orbit, flee, align, move and stop
- Targeting, the orbit camera and the flight HUD
- Docking, and jumping between handcrafted sectors with a jump transition
- New game, save and load
- Laser combat without manual aim: damage depends on range and the target's angular velocity; hull, power and wrecks
- Three arenas in the Elace system (1v1, 2v2, 4v4), each with a beacon and two stations per faction, and its own terrain: the 1v1 is open space, the 2v2 has a rock belt across the middle, the 4v4 rocks scattered over the field (rocks stop ships, laser fire, missiles and shells; missile racks and cannons hold fire while a rock is in the way): Verdant and Violet NPCs spawn docked there, fight round the beacon, strip wrecks, and dock to sell salvage, repair or escape. They leave the player alone unless the player shoots one or their faction's standing is hostile. Fights are judged side against side: a ship counts the friends within 3 km of it, and of its target, so a lone ship thinks twice about a pair (the player's difficulty cue counts a target's escorts too). An NPC not already fighting weighs going to help a friend under fire within 4 km, and goes if its side wants that fight. Brackets show each side in its colour (red-orange for ships hostile to the player); a ship's cross is bright while the ship detects the player and dim while it does not (its label stays readable), crosses are drawn twice their old size, rocks' and other celestials' fainter, and they show what each ship is doing
- The frontier, a fourth zone 30 km off the Arena: a wide field of 40 rocks to mine, both factions' stations (3 ships each), a raider outpost at one end (3 raiders; the outpost is their only market) and a xenohive at the other (2 drones, one more per 5 t of cargo they bring home, up to 3 more). Prospectors (laser, lance and harpoon, and the prospect gene) mine when there is nothing else to do; while mining, working ore or a loose lance, or hauling home they mind their work: they take on no enemy out of their weapons' reach, help no friend, and run home when attacked: throw a lance into a rock, burn the chunks' crust off, wait for the slag to cool, harpoon it home (target info: MINING). Ore sells for 40 WP a unit. A lance that glances off, misses or stays in a rock drifts as a loose lance: harpoon it, or approach it slowly (within 60 m at 20 m/s or less) to scoop it into a seat it fits; NPCs out of lances collect theirs before picking fights. Any NPC takes its hold home to sell once it is worth its haul gene's share of its ship (25% by default) or the hold is full; the ship stats overlay shows the player's hold value and that share. Raiders are at war with both factions and hunt their ships and wrecks. The xenohive has no standing and no bounties: its drones take any ship within 2.5 km of the hive for an enemy, answer whoever shoots them, gather wrecks and chunks for the hive, and leave carcasses full of biotech. Raiders have their own colour; the xenohive's drones and its hive are grown, not built: teal spindles with odd-numbered rings of petals, spikes and glowing cells set at slant angles round them (`XenoForm`, Constants `XENO_FORMS`)
- Travellers (Constants `TRAFFIC_*`): nine persistent ships, prospectors and fighters of both factions and raiders, flying the best designs of their kind from the evolution pools. They keep a timetable off-screen: a few minutes in a sector, then a jump to a neighbour, burning fuel by mass like the player; without fuel they stay put, and in Elace they sell their hold, refuel and repair. In the player's sector they are ships: prospectors mine the nearest rocks or debris, the rest patrol; when their time is up they fly out to the jump shell toward their next sector. One that dies is replaced in Elace 10 minutes later. Not in the evolution sim
- Ships and parts follow governing laws (`ShipLaws`, Constants SHIP AND PART LAWS): every stat is a power law of mass (and, for lasers, shot energy), with the Phoenix Light and Ablative Laser as reference points. Bigger hulls are the Phoenix Light scaled up, with more hardpoints and bays (an evolved hull splits its slots by its own `tool_share` gene, anything from all bays to all hardpoints but one of each kept)
- Evolution (`Evolution`, Constants ARENA AND EVOLUTION): each arena NPC is a genome (hull size and mass split, a part per slot, later behaviour), scored by return on cost (a spawn picks its family first, lance, fighter, raider, prospector, scavenger, each as likely, then a design within it by fitness, so no family is starved of lives); combat niches (fighters, raiders, lancers) also count the value of enemy ships they destroyed, each hit worth its share of the victim's hull. Each faction keeps an archive of niches (size, role, laser range) with the best genome in each, so different builds survive side by side. Saved with the game; every life is logged
- Runners and pursuers: a ship running from a fight shoots back or not; its pursuer chases only while it reckons it can catch it before it docks or gets clear, and may let one go that holds fire. All three are behaviour genes (every NPC has them, not only the arenas'), so careful sides that disengage and reckless fights to the death can both evolve. Desperation bends them: a pilot with little WP for its ship's worth fights at worse odds, chases harder and spares less. Each life's flights, escapes, holds of fire and let-goes are logged. A docked ship waits while an enemy hangs about its station
- Rank: a faction's ships in one arena zone are a group, ranked by renown won in this life (kills, going to help friends, hull dealt). The first, once it has a kill's worth, leads: the others patrol near it and join its fights. Renown can also put off retiring (ARENA_LIFETIME_MAX_FACTOR; off for now, as long lives slowed evolution by a quarter). Target info shows LEADER or RANK n/m
- Behaviour genes (evolved per design, so archetypes differ in temperament as well as fit): when to start and break off a fight, fighting range, when to run home, how far to chase, mercy, shooting back while running, teamwork (helping friends and following a leader; loners do neither), caution (how strong an unseen enemy must be to keep clear of it) and burn (how much power the afterburner may eat)
- Seeing first: an NPC is keener on a target that cannot see it (a first strike), and keeps clear of an enemy too strong for it that has not seen it yet, so signature dampers and sensor boosters change what ships do; the player reads the same from the bracket's brightness (bright: it sees you)
- Special modules: a sensor booster (every detection range grows), a signature damper (hides a share of the whole signature, more on a smaller hull), a decoy launcher (a missile closing in draws a flare; most turn after it and burst on it; refilled at a base) and an afterburner (extra thrust while lit, from the AFTERBURN button, at a steep power cost and a hot plume; NPCs burn to run, to charge with a lance, to catch a runner or to close from far out). The AFTERBURN button also shows the decoys left
- Kinetic lance (a module: a launcher and a quiver of lances; a ship may carry several, side by side across its bow, one alone on the axis); the seat armours the bow. The LANCE button arms them all and counts the lances left in all. Armed (the LANCE button; NPCs while they ram), it throws a lance at the ram's target once within 80 m of it: 100 m/s on top of the ship's own speed, aimed (within 60 degrees of the nose) so that relative to the target the lance flies straight at its middle, and the throw kicks the ship back by the lance's momentum, at the launcher's mount: a throw off the axis also twists the ship (a matched pair thrown together cancels, though the kicks add up), the price of a bank of launchers. The ship flies by: a ram at a ship passes 10 m clear of its hull, so the hulls never meet, and comes in at up to 35 degrees off the line from afar (straightening from 400 m in, and narrowing while it closes slowly) so that turrets have to track it. A lance meeting its target at 60 m/s or more along it, square-on, does damage that grows with that speed and the lance's mass, shoves the target by its momentum and stays in its hull; slower, or at an angle (sure square-on, less likely the more oblique, and past 60 degrees only a long lance may slip between parts), it glances off; a target that dodges in the half second it flies makes it miss. A lance that glances off or misses drifts on (off a face, mirrored at 30% of its speed; a miss at its own) and slows to a stop: a loose lance, targetable, that a harpoon brings back into a seat it fits (salvagers short of lances go for them; the oldest go past 12). Wrecks and ore chunks are rammed head-on, a shove. With the lance armed, APPROACH (still so named) flies the throwing pass at a ship or a rock with ore left, and shoves a wreck or an ore chunk head-on; one throw (a volley from launchers side by side) disarms the lances, as their stock is limited. The LANCE button shows the speed a throw would strike at, or TOO SLOW when the target runs away faster than the ship can gain on it, or TOO HOT when its side's guns would take the whole hull on the way in. NPCs ram while their lasers fire, and only when it pays: the hull they can expect to lose to the target's side on the way in (its guns' damage, halved for the angled approach, from their reach to release range, plus a few seconds turning for the next pass) must leave them above their retreat level, unless a throw would finish the target and the loss would not finish them. They weigh it again between passes and may break off a charge until 300 m out; a lancer with no other weapon on the target hangs back outside its guns' reach while its friends wear it down. Lances are restocked when docking, or recovered from wrecks with a harpoon (those that fit the seat go back in the quiver; lancers short of lances seek such wrecks first). A ship charging with an armed lance is seen coming from 500 m: its target turns hostile (an NPC answers as if shot; the player is warned)
- Weapon archetypes. Lasers: turrets, no ammunition, but they drain power (sustained fire needs a big reactor, power cells or capacitors; short of power a laser waits), and they shoot down missiles coming at their own ship (point defence, by the same hit quality: light fast turrets do it best). Lances: melee, recoverable, no power (and a reactor's heat is part of a ship's signature, so a lancer's small reactor keeps it hard to see). Missile racks: guided heavy hitters launched from beyond laser reach, one use each; a missile turns at a limited rate, so an agile ship near enough can make it overshoot, and its fuel runs out; more only at a base or from a missile ship's wreck. Rail cannons: fixed forward, so the ship aims (the autopilot points the nose where the target will be when a round gets there, holding the range); rounds fly at a finite speed, from a magazine, light on power. Magazines refill at the home station (paid per round) and are salvaged with the harpoon from wrecks that carried the same rounds
- Hits leave lasting marks on the hull (vertex-painted, proportional to damage)
- Salvage: harpoon a wreck, it reels in to a safe towing distance and is stripped into the hold; cargo adds mass
- Fuel leaks vent along the hull and push the ship; destroyed ships explode into a drifting cloud
- Run loop: start docked at the home station (in the 4v4 arena, off to the side of both factions), bank cargo and repair there, lose the ship and, after a few seconds watching the wreck, the screen fades and you wake docked at home in the start's ship: the ship, its fit, its cargo and the bounties on it are lost (the new one comes fuelled); the bank, station storage, standing and the world are kept, and the save is overwritten
- Engine exhausts that stretch and brighten with thrust; a space ambient soundtrack
- Hand-placed asteroids (round the arenas' centre, where the home station used to be) block laser fire; the autopilot steers around them
- Signatures and detection (one rule for all), predators that weigh gain against risk and hesitate by skill; target difficulty under the selected bracket, and whether a ship sees you in its brightness
- Fitting at the home station: tool and module slots, data-driven modules, part mass, buy / sell with banked value; the store also sells every exported evolution design (database/presets/) and its parts, ships fitted and grouped light / medium / heavy (PROVEN: flew 10 lives), parts by kind under foldable headings, one tab at a time (SHIPS, WEAPONS, EQUIPMENT, MODULES, CARGO)
- Standing (`Standing`), as in Freelancer: the player's name with each faction, -1 to 1 (Raiders start at -1). The first hit on a ship costs 0.03 with its faction, a kill 0.12, and a kill earns 0.04 with each faction at war with the victim's. At -0.6 or below a faction's ships attack you on sight and its stations refuse docking; target info shows HOSTILE or FRIENDLY. Factions outside the list (aliens, later) have no standing and react on the spot
- Bounties (`Bounty`), for everyone alike: a faction pays 20% of a ship's value for killing a ship of a faction it is at war with, and posts 10% of its ship's value on whoever kills one, kill after kill. The killer of a ship collects the postings it can claim (its own faction's and those of factions not at war with it; the player: those of factions not hostile) and the war bounty, paid on the kill. Ships hunt a ship carrying a claim worth 5% of their own value: kill Verdant ships and Verdant comes after you before it turns hostile. Target info shows BOUNTY; the postings on you lapse with your ship
- Fuel (`Fuel`): a jump burns ceil(mass / 2500 kg) units of fuel from the hold; without enough there is no jump. A new game's ship and the one you get after a loss carry 6 units; stations keep it when they buy your hold
- Mining (Constants MINING), a composite act with the tools a ship already has: a lance thrown into a rock (armed APPROACH: the ship stops with the lance's tip 40 m off the surface and throws) breaks lance damage / 15 units of ore (up to 12) off its face in 1 to 3 small pieces fanning out; the lance stays in the rock, a loose lance to harpoon out. Each piece is crusted: laser fire burns the crust off (40 damage) and bares the ore, smooth bronze lumps in place of the rock, glowing orange and fading as it cools (15 s); cooled, the harpoon tows it and strips it like a wreck. Target info shows ORE on a rock, CRUST, SLAG COOLING or SLAG: HARPOON IT on a piece, and LANCE: HARPOON IT on a loose lance. Rocks hold ore by size. New commodities: ore, relics and biotech
- Megastructures (`Megastructure`, Constants MEGASTRUCTURE_LAYERS) in Cob and Lywin, about 13 km from where you arrive from Elace: clusters left by successive builders, one material per layer (the solid shader with NLP off). A few vast ancient forms (1.5 to 4 km) in the middle, old structures (150 to 600 m) built into them, and recent debris (15 to 80 m) round them, mined for relics like rocks for ore. Plain boxes, cylinders, spheres, prisms and capsules for now, to judge scale by eye
- Prices (`Market`): physics value, plus each station's markup (0 to 50%, rolled again every 24 to 36 minutes of game time), then standing (up to 10% cheaper to buy and dearer to sell at 1, the reverse at -1). A station pays 80% of its price for cargo and half for parts, so a round trip at one station never pays but hauling between stations can. NPCs sell their holds at the same station prices (as strangers: no standing). Faction stations buy your hold when you dock; only the home station sells
- Off-screen resolution (`Offscreen`, Constants `OFFSCREEN_*`): a ship more than 12 km from the player is not flown. It leaves the physics, its AI and tools stop, and it keeps its place in the world, so sensors still pick it up and its bracket shows. Once a second a rule moves it home to dock (hold full, time up, hull low), toward an enemy it detects (in range: its damage per second times a hit share, through the normal damage path), onto a rock to mine (if it is a prospector) or back to its patrol. Within 10 km it flies again at the speed it had. The rules are first guesses, to be fitted to flown fights; lives partly resolved this way are not scored by evolution, and the evolution, duel and balance tools fly everything. Docked ships are out of the physics too, and an armed lance only checks ships and rocks within 800 m (listed four times a second)
- Threat ring: red arrows round the middle of the screen toward hostile ships you detect but cannot see (behind or off screen), within 15 km; nearer ones bigger and brighter (Constants `THREAT_*`).
- Debug overlay (the bug button): ship side (left) REFIT (any part into any slot it fits, on the spot, free); world side (right) MAP, JUMP (to any sector at once, free), GO TO (any place in the sector, nearest first, or typed coordinates in km; the ship stops a standoff short), TO TARGET (300 m off the selected target, at its speed). WORLD lists active (flown), off-screen, docked and wrecked NPCs and the physics bodies awake

## Roadmap

Complete the engine, then freeze it. After the freeze, work is content, tuning and art only.

1. Damage, destruction and wrecks (same for player and AI)
2. Tools end-to-end from `utility_tool_template` data: fire, cooldown, power draw, damage / grapple / drill
3. Fitting at docks with slots; recomputed mass and stats; fitting UI
4. Module effects as data (stat modifiers plus verb flags)
5. Power budget: capacity, regeneration, draw
6. Signature and detection, one rule for player and AI
7. Harpoon tether / towing; towed mass affects handling
8. Salvage cargo; cargo adds mass and perceived value
9. Predator AI: engage or disengage on expected gain vs. risk
10. Run loop: start, bank salvage at home, die, restart
11. Optional data-driven run modifiers (infrastructure only)
12. Feel pass on camera, HUD, docking and jumps

**Decisions so far:**
- Combat has no manual aim, EVE-style: you fly the ship (distance, relative velocity) and tools resolve on their own; a cannon's aim is the autopilot's.
- Damage is hull only.
- Running out of power stops the tool, nothing more.
- A run is the hand-built sector graph with free travel. Spawns are uniform everywhere until the layout of space is final.

**Freeze when:** all of the above work with placeholder content, new parts, hulls, sectors and encounters need only data or scene files, and the tests pass.

**Out of scope:** multiplayer, narrative, companions, crafting, market simulation, production chains, meta-progression, card or board mechanics. Persistent NPCs travel the sector graph (fuel per jump) on an abstract off-screen timetable; sessions can be short or long, as the player likes.

## Controls

| Input | Action |
|---|---|
| Left mouse | Select target (a click on empty space keeps it; a target out of sensor range is lost, and commands on it stop) |
| Tool buttons (one per fitted tool) | That tool on the selected target, or off (laser: FIRE / CEASE, missiles: LAUNCH one / HOLD, cannon: AIM+FIRE / CEASE, harpoon: LAUNCH / RELEASE); racks and cannons show rounds left |
| Dock button | DOCK at a selected station, UNDOCK, or TRAVEL along a selected route |
| Ship button (docked at home) | Fitting: buy, sell, fit and unfit parts |
| Space | Shortcut: the tool that fits the selected target on or off; otherwise dock or jump |
| A | Approach target (with the lance armed: the pass that throws it) |
| O | Orbit target |
| F | Flee from target |
| S | Stop |
| M | Toggle free flight |
| Up / Down | Throttle up / down |
| Esc | Main menu |

## Project Layout

| Path | Contents |
|---|---|
| `src/autoload/` | Singletons: Constants, EventBus, GlobalRefs, TemplateDatabase, GameState, GameStateManager |
| `src/core/agents/` | Agent body, movement (thrust/PID), navigation commands, tool controller |
| `src/core/systems/` | Agent spawning, ship template lookup, sector loading |
| `src/core/ui/` | HUD, main menu, debug window, radar |
| `src/modules/piloting/` | Player input controller and ship AI |
| `src/scenes/` | Camera, world manager, jump orchestration and transition |
| `database/definitions/` | Template resource scripts (ships, modules, tools, agents, locations, game starts) |
| `database/registry/` | Template data (`.tres`); new content goes here |
| `scenes/` | Levels, sectors, prefabs and UI scenes |
| `docs/godot/` | Godot 3.6 shader reference |

## Evolution Runs

The arenas evolve while you play (the home station is in the 4v4 arena; fly to a beacon for the others), or headless and sped up:

```sh
godot --no-window -s tools/evolution_sim.gd -- --hours=4 --speed=6
```

It runs about 3 simulated hours per wall-clock hour on a desktop; each save line also prints node, object and memory counts, to catch a run slowing down. It loads the saved game (or starts one with `--new`), saves to it as it goes, and prints `EVO` lines and a report every few simulated minutes. Every finished life is also written in full to `user://evolution_logs/run_<id>.jsonl`. `python3 tools/evolution_report.py [log]` summarises a log: fitness over time, the best niches and their genomes (preset candidates), part use, and who kills whom. `godot --no-window -s tools/export_presets.gd -- --min-lives=10 --clean` writes the save's best design of each archetype (role, in light, medium and heavy hulls; both factions' pools as one) as presets (ship, parts, a faction-free AgentTemplate with behaviour genes) under `database/presets/`, replacing the old ones, outside the registry: move the ones you want into `database/registry/`. Proving mode (Constants `EVO_PROVING`, on) feeds that: most spawns re-fly the three fittest niche bests of each archetype until each has `EVO_PROVE_LIVES` (10) lives, the rest are mutants and there are no immigrants. Each pool starts from guessed designs (Constants `EVO_SEEDS`: prospectors and escorts, raiders, drones), planted in their niches if empty. After a rule change, `--new-era` starts every genome's record over, so fitness is not mixed across rule eras. After changing a law, run `godot --no-window -s tools/apply_laws.gd` to bring the registry parts in line. `godot --no-window -s tools/lance_duel.gd -- --duels=6` pits lance designs against laser ships and an unarmed hauler, one on one, and prints wins, strikes, glances and closing speeds; with `--weapons`, missile and cannon designs against lasers, each other and a lancer (with rounds fired, hits and missiles shot down).

## Running Tests

Tests use [GUT](https://github.com/bitwes/Gut) and live in `src/tests/`. To run them all headless:

```sh
godot --no-window -s addons/gut/gut_cmdln.gd -gexit
```

## Technology Stack

* **Engine:** Godot Engine 3 (3.6 stable, GLES2)
* **Auxiliary tooling:** Python 3 (`tools/`)

## License

This project is licensed under the **GNU General Public License v3.0 or later (GPL-3.0-or-later)**. See [LICENSE](LICENSE.md) for details. See also [AI-ACKNOWLEDGEMENT.md](AI-ACKNOWLEDGEMENT.md).
