#
# PROJECT: GDTLancer
# MODULE: agent_layer.py
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §2.1, §3.3 + TACTICAL_TODO.md PHASE 2 TASK_3
# LOG_REF: 2026-02-22 00:55:42
#

"""Qualitative agent layer using affinity-driven tag transitions."""

import copy
import random
from database.registry.template_data import AGENTS, CHARACTERS
from autoload import constants
from core.simulation.affinity_matrix import (
    ATTACK_THRESHOLD,
    FLEE_THRESHOLD,
    TRADE_THRESHOLD,
    compute_affinity,
)


class AgentLayer:
    def __init__(self):
        self._chronicle = None
        self._rng = random.Random()

    def set_chronicle(self, chronicle) -> None:
        self._chronicle = chronicle

    def initialize_agents(self, state) -> None:
        state.agents.clear()
        state.characters.clear()
        state.agent_tags.clear()

        self._initialize_player(state)
        for agent_id, template in AGENTS.items():
            if template.get("agent_type") == "player":
                continue
            self._initialize_agent_from_template(state, agent_id, template)

    def process_tick(self, state, config: dict) -> None:
        self._rng = random.Random(f"{state.world_seed}:{state.sim_tick_count}")

        self._apply_upkeep(state)

        for agent_id, agent in list(state.agents.items()):
            if agent_id == "player":
                continue

            if agent.get("is_disabled", False):
                self._check_respawn(state, agent_id, agent)
                continue

            self._evaluate_goals(agent)
            self._execute_action(state, agent_id, agent)

        self._check_catastrophe(state)
        self._spawn_mortal_agents(state)
        self._cleanup_dead_mortals(state)

    def _initialize_player(self, state) -> None:
        character_id = "character_default"
        state.player_character_uid = character_id
        state.characters[character_id] = copy.deepcopy(CHARACTERS.get(character_id, {}))

        start_sector = next(iter(state.world_topology.keys()), "")
        state.agents["player"] = {
            "character_id": character_id,
            "agent_role": "idle",
            "current_sector_id": start_sector,
            "home_location_id": start_sector,
            "goal_archetype": "idle",
            "goal_queue": [{"type": "idle"}],
            "is_disabled": False,
            "disabled_at_tick": None,
            "is_persistent": True,
            "condition_tag": "HEALTHY",
            "wealth_tag": "COMFORTABLE",
            "cargo_tag": "EMPTY",
            "dynamic_tags": [],
        }

    def _initialize_agent_from_template(self, state, agent_id: str, template: dict) -> None:
        character_id = template.get("character_template_id", "") or "character_default"
        char_data = copy.deepcopy(CHARACTERS.get(character_id, {}))
        state.characters[character_id] = char_data

        home = template.get("home_location_id", "")
        start_sector = home if home in state.world_topology else next(iter(state.world_topology.keys()), "")
        initial_tags = template.get("initial_tags", ["HEALTHY", "COMFORTABLE", "EMPTY"])

        state.agents[agent_id] = {
            "character_id": character_id,
            "agent_role": template.get("agent_role", "idle"),
            "current_sector_id": start_sector,
            "home_location_id": home,
            "goal_archetype": "affinity_scan",
            "goal_queue": [{"type": "affinity_scan"}],
            "is_disabled": False,
            "disabled_at_tick": None,
            "is_persistent": bool(template.get("is_persistent", False)),
            "condition_tag": self._pick_tag(initial_tags, {"HEALTHY", "DAMAGED", "DESTROYED"}, "HEALTHY"),
            "wealth_tag": self._pick_tag(initial_tags, {"WEALTHY", "COMFORTABLE", "BROKE"}, "COMFORTABLE"),
            "cargo_tag": self._pick_tag(initial_tags, {"LOADED", "EMPTY"}, "EMPTY"),
            "dynamic_tags": [],
        }

    def _evaluate_goals(self, agent: dict) -> None:
        tags = agent.get("sentiment_tags", [])
        if "DESPERATE" in tags:
            agent["goal_archetype"] = "flee_to_safety"
            agent["goal_queue"] = [{"type": "flee_to_safety"}]
            return

        agent["goal_archetype"] = "affinity_scan"
        agent["goal_queue"] = [{"type": "affinity_scan"}]

    def _execute_action(self, state, agent_id: str, agent: dict) -> None:
        goal = (agent.get("goal_queue") or [{"type": "idle"}])[0].get("type", "idle")

        if goal == "flee_to_safety":
            self._action_flee_to_safety(state, agent_id, agent)
            return
        if goal == "affinity_scan":
            self._action_affinity_scan(state, agent_id, agent)

    def _action_flee_to_safety(self, state, agent_id: str, agent: dict) -> None:
        current = agent.get("current_sector_id", "")
        options = [current] + state.world_topology.get(current, {}).get("connections", [])
        best = current
        for sector_id in options:
            tags = state.sector_tags.get(sector_id, [])
            if "SECURE" in tags:
                best = sector_id
                break
        if best != current:
            self._action_move_toward(state, agent_id, agent, best)

    def _action_affinity_scan(self, state, agent_id: str, agent: dict) -> None:
        actor_tags = agent.get("sentiment_tags", [])
        if not actor_tags:
            return

        current_sector = agent.get("current_sector_id", "")
        can_attack = not self._is_combat_cooldown_active(agent, state)

        best_agent_id, best_agent_score = self._best_agent_target(
            state,
            agent_id,
            actor_tags,
            current_sector,
            can_attack,
        )
        if best_agent_id is not None:
            handled = self._resolve_agent_interaction(state, agent_id, best_agent_id, best_agent_score)
            if handled:
                return

        sector_tags = state.sector_tags.get(current_sector, [])
        sector_score = compute_affinity(actor_tags, sector_tags)
        self._resolve_sector_interaction(state, agent_id, sector_score, sector_tags)

    def _resolve_agent_interaction(self, state, actor_id: str, target_id: str, score: float) -> bool:
        actor = state.agents.get(actor_id, {})
        target = state.agents.get(target_id, {})
        if not actor or not target:
            return False

        current_sector = actor.get("current_sector_id", "")

        if score >= ATTACK_THRESHOLD:
            new_target_condition = "DESTROYED" if target.get("condition_tag") == "DAMAGED" else "DAMAGED"
            target["condition_tag"] = new_target_condition
            actor["last_attack_tick"] = state.sim_tick_count
            if new_target_condition == "DESTROYED":
                target["is_disabled"] = True
                target["disabled_at_tick"] = state.sim_tick_count
                state.sector_tags[current_sector] = self._add_tag(state.sector_tags.get(current_sector, []), "HAS_SALVAGE")
                actor["cargo_tag"] = "LOADED"
            self._log_event(state, actor_id, "attack", current_sector, {"target": target_id})
            self._post_combat_dispersal(state, actor_id, actor)
            return True

        if score >= TRADE_THRESHOLD:
            self._bilateral_trade(actor, target)
            self._log_event(state, actor_id, "agent_trade", current_sector, {"target": target_id})
            return True

        if score <= FLEE_THRESHOLD:
            self._action_move_random(state, actor_id, actor)
            self._log_event(state, actor_id, "flee", current_sector, {"target": target_id})
            return True

        return False

    def _resolve_sector_interaction(self, state, agent_id: str, score: float, sector_tags: list) -> None:
        agent = state.agents.get(agent_id, {})
        sector_id = agent.get("current_sector_id", "")

        # Explorers prioritise exploration above almost everything.
        if "FRONTIER" in sector_tags and agent.get("agent_role") == "explorer":
            self._try_exploration(state, agent_id, agent, sector_id)
            return

        if score >= ATTACK_THRESHOLD and "HAS_SALVAGE" in sector_tags:
            self._action_harvest(state, agent_id, agent, sector_id)
            return

        needs_dock = (
            agent.get("condition_tag") == "DAMAGED"
            or agent.get("cargo_tag") == "LOADED"
        )
        at_station = "STATION" in sector_tags or "FRONTIER" in sector_tags

        if needs_dock and at_station:
            self._try_dock(state, agent_id, agent, sector_id)
            return

        if agent.get("cargo_tag") == "EMPTY":
            loaded = self._try_load_cargo(state, agent_id, agent, sector_id)
            if loaded:
                return

        if score <= FLEE_THRESHOLD:
            self._action_move_random(state, agent_id, agent)
            self._log_event(state, agent_id, "flee", sector_id, {"reason": "sector_affinity"})
            return

        self._action_move_toward_role_target(state, agent_id, agent)

    def _try_dock(self, state, agent_id: str, agent: dict, sector_id: str) -> None:
        if "STATION" not in state.sector_tags.get(sector_id, []) and "FRONTIER" not in state.sector_tags.get(sector_id, []):
            return

        sold_cargo = False
        if agent.get("cargo_tag") == "LOADED":
            agent["cargo_tag"] = "EMPTY"
            self._wealth_step_up(agent)
            sold_cargo = True

        if agent.get("condition_tag") == "DAMAGED":
            agent["condition_tag"] = "HEALTHY"
            if not sold_cargo:
                self._wealth_step_down(agent)

        self._log_event(state, agent_id, "dock", sector_id, {})

    def _action_harvest(self, state, agent_id: str, agent: dict, sector_id: str) -> None:
        tags = state.sector_tags.get(sector_id, [])
        if "HAS_SALVAGE" not in tags:
            return
        agent["cargo_tag"] = "LOADED"
        state.sector_tags[sector_id] = [tag for tag in tags if tag != "HAS_SALVAGE"]
        self._log_event(state, agent_id, "harvest", sector_id, {})

    def _action_move_toward_tag(self, state, agent_id: str, agent: dict, target_tag: str) -> None:
        current = agent.get("current_sector_id", "")
        neighbors = state.world_topology.get(current, {}).get("connections", [])
        for sector_id in neighbors:
            if target_tag in state.sector_tags.get(sector_id, []):
                self._action_move_toward(state, agent_id, agent, sector_id)
                return
        self._action_move_random(state, agent_id, agent)

    def _action_move_toward(self, state, agent_id: str, agent: dict, target_sector_id: str) -> None:
        current = agent.get("current_sector_id", "")
        if target_sector_id in state.world_topology.get(current, {}).get("connections", []):
            agent["current_sector_id"] = target_sector_id
            self._log_event(state, agent_id, "move", target_sector_id, {"from": current})

    def _action_move_random(self, state, agent_id: str, agent: dict) -> None:
        current = agent.get("current_sector_id", "")
        neighbors = state.world_topology.get(current, {}).get("connections", [])
        if not neighbors:
            return
        target = self._rng.choice(neighbors)
        self._action_move_toward(state, agent_id, agent, target)

    def _try_exploration(self, state, agent_id: str, agent: dict, sector_id: str) -> None:
        # Cap check — stop when the graph is full.
        if len(state.world_topology) >= constants.MAX_SECTOR_COUNT:
            self._log_event(state, agent_id, "expedition_failed", sector_id, {})
            return

        if agent.get("wealth_tag") == "BROKE":
            self._log_event(state, agent_id, "expedition_failed", sector_id, {"reason": "broke"})
            return

        # Per-agent cooldown — explorer must wait between discoveries.
        last_discovery = agent.get("last_discovery_tick", -999)
        if state.sim_tick_count - last_discovery < constants.EXPLORATION_COOLDOWN_TICKS:
            self._log_event(state, agent_id, "expedition_failed", sector_id, {"reason": "cooldown"})
            return

        # Probability gate — diminishing returns: more sectors → lower chance.
        sector_count = len(state.world_topology)
        saturation = sector_count / constants.MAX_SECTOR_COUNT  # 0..1
        effective_chance = constants.EXPLORATION_SUCCESS_CHANCE * (1.0 - saturation)
        if self._rng.random() > effective_chance:
            self._log_event(state, agent_id, "expedition_failed", sector_id, {"reason": "nothing_found"})
            return

        agent["last_discovery_tick"] = state.sim_tick_count

        state.discovered_sector_count += 1
        new_id = f"discovered_{state.discovered_sector_count}"

        # --- Generate a deterministic name ---
        new_name = self._generate_sector_name(state)

        # --- Determine connections (filament topology: cap + sparse branching) ---
        source_id = sector_id
        if self._graph_degree(state, source_id) >= constants.MAX_CONNECTIONS_PER_SECTOR:
            fallback_candidates = []
            for neighbor_id in state.world_topology.get(source_id, {}).get("connections", []):
                if self._graph_degree(state, neighbor_id) < constants.MAX_CONNECTIONS_PER_SECTOR:
                    fallback_candidates.append(neighbor_id)

            if not fallback_candidates:
                self._log_event(state, agent_id, "expedition_failed", sector_id, {"reason": "region_saturated"})
                return

            source_id = sorted(fallback_candidates, key=lambda sid: (self._graph_degree(state, sid), sid))[0]

        connections = [source_id]

        extra_one_added = False
        if self._rng.random() < constants.EXTRA_CONNECTION_1_CHANCE:
            nearby = self._nearby_candidates(state, source_id, set(connections))
            if nearby:
                extra_one = self._rng.choice(sorted(nearby))
                if extra_one not in connections:
                    connections.append(extra_one)
                    extra_one_added = True

        if extra_one_added and self._rng.random() < constants.EXTRA_CONNECTION_2_CHANCE:
            loop_candidate = self._distant_loop_candidate(state, source_id, set(connections))
            if loop_candidate is not None and loop_candidate not in connections:
                connections.append(loop_candidate)

        # --- Pick initial tags (frontier bias: harsh, poor, contested) ---
        sec_roll = self._rng.random()
        security = "LAWLESS" if sec_roll < 0.45 else ("CONTESTED" if sec_roll < 0.85 else "SECURE")
        env_roll = self._rng.random()
        environment = "EXTREME" if env_roll < 0.3 else ("HARSH" if env_roll < 0.75 else "MILD")

        econ_tags = []
        econ_options = ["POOR", "POOR", "ADEQUATE", "ADEQUATE", "RICH"]
        for prefix in ("RAW", "MANUFACTURED", "CURRENCY"):
            level = self._rng.choice(econ_options)
            econ_tags.append(f"{prefix}_{level}")

        initial_tags = ["FRONTIER", security, environment] + econ_tags

        # --- Wire into the world graph (bidirectional) ---
        state.world_topology[new_id] = {
            "connections": list(connections),
            "station_ids": [new_id],
            "sector_type": "frontier",
        }
        for conn_id in connections:
            conn_data = state.world_topology.get(conn_id, {})
            existing_conns = conn_data.get("connections", [])
            if new_id not in existing_conns:
                existing_conns.append(new_id)

        # --- Initialize all required state dicts ---
        state.sector_tags[new_id] = list(initial_tags)
        state.world_hazards[new_id] = {"environment": environment}
        state.colony_levels[new_id] = "frontier"
        state.colony_upgrade_progress[new_id] = 0
        state.colony_downgrade_progress[new_id] = 0
        state.security_upgrade_progress[new_id] = 0
        state.security_downgrade_progress[new_id] = 0
        _thresh_rng = random.Random(f"{state.world_seed}:sec_thresh:{new_id}")
        state.security_change_threshold[new_id] = _thresh_rng.randint(
            constants.SECURITY_CHANGE_TICKS_MIN,
            constants.SECURITY_CHANGE_TICKS_MAX,
        )
        state.grid_dominion[new_id] = {
            "controlling_faction_id": "",
            "security_tag": security,
        }
        state.economy_upgrade_progress[new_id] = {cat: 0 for cat in ("RAW", "MANUFACTURED", "CURRENCY")}
        state.economy_downgrade_progress[new_id] = {cat: 0 for cat in ("RAW", "MANUFACTURED", "CURRENCY")}
        state.economy_change_threshold[new_id] = {}
        for category in ("RAW", "MANUFACTURED", "CURRENCY"):
            thresh_rng = random.Random(f"{state.world_seed}:econ_thresh:{new_id}:{category}")
            state.economy_change_threshold[new_id][category] = thresh_rng.randint(
                constants.ECONOMY_CHANGE_TICKS_MIN,
                constants.ECONOMY_CHANGE_TICKS_MAX,
            )
        state.hostile_infestation_progress[new_id] = 0

        # --- Record ---
        state.sector_names[new_id] = new_name
        state.discovery_log.append({
            "tick": state.sim_tick_count,
            "discoverer": agent_id,
            "from": sector_id,
            "new_sector": new_id,
            "name": new_name,
        })
        self._log_event(state, agent_id, "sector_discovered", sector_id, {
            "new_sector": new_id,
            "name": new_name,
            "connections": connections,
        })

    # Name-generation pools for discovered sectors.
    _FRONTIER_PREFIXES = [
        "Void", "Drift", "Nebula", "Rim", "Edge", "Shadow", "Iron",
        "Crimson", "Amber", "Frozen", "Ashen", "Silent", "Storm",
        "Obsidian", "Crystal", "Pale", "Dark",
    ]
    _FRONTIER_SUFFIXES = [
        "Reach", "Expanse", "Passage", "Crossing", "Haven", "Point",
        "Drift", "Hollow", "Gate", "Threshold", "Frontier", "Shelf",
        "Anchorage", "Waypoint", "Depot",
    ]

    def _generate_sector_name(self, state) -> str:
        """Return a deterministic but varied name for a discovered sector."""
        rng = random.Random(f"{state.world_seed}:discovery:{state.discovered_sector_count}")
        prefix = rng.choice(self._FRONTIER_PREFIXES)
        suffix = rng.choice(self._FRONTIER_SUFFIXES)
        return f"{prefix} {suffix}"

    def _graph_degree(self, state, sector_id: str) -> int:
        """Return connection count for a sector in the topology graph."""
        return len(state.world_topology.get(sector_id, {}).get("connections", []))

    def _sectors_below_cap(self, state) -> list[str]:
        """Return all sectors whose degree is below the hard connection cap."""
        sectors = []
        for sid in state.world_topology.keys():
            if self._graph_degree(state, sid) < constants.MAX_CONNECTIONS_PER_SECTOR:
                sectors.append(sid)
        return sectors

    def _nearby_candidates(self, state, source_id: str, exclude: set) -> list[str]:
        """Return neighbors of source that can accept more links and are not excluded."""
        candidates = []
        neighbors = state.world_topology.get(source_id, {}).get("connections", [])
        for sid in neighbors:
            if sid in exclude:
                continue
            if self._graph_degree(state, sid) >= constants.MAX_CONNECTIONS_PER_SECTOR:
                continue
            candidates.append(sid)
        return candidates

    def _distant_loop_candidate(self, state, source_id: str, exclude: set):
        """Pick a deterministic distant loop target at >= LOOP_MIN_HOPS from source."""
        if source_id not in state.world_topology:
            return None

        queue = [(source_id, 0)]
        visited = {source_id}
        distant = []

        while queue:
            current_id, depth = queue.pop(0)
            if (
                depth >= constants.LOOP_MIN_HOPS
                and current_id not in exclude
                and self._graph_degree(state, current_id) < constants.MAX_CONNECTIONS_PER_SECTOR
            ):
                distant.append(current_id)

            for neighbor_id in state.world_topology.get(current_id, {}).get("connections", []):
                if neighbor_id in visited:
                    continue
                visited.add(neighbor_id)
                queue.append((neighbor_id, depth + 1))

        if not distant:
            return None

        rng = random.Random(
            f"{state.world_seed}:loop:{source_id}:{state.discovered_sector_count}:{state.sim_tick_count}"
        )
        return rng.choice(sorted(distant))

    def _best_agent_target(self, state, actor_id: str, actor_tags: list, sector_id: str, can_attack: bool):
        best_id = None
        best_score = 0.0
        for target_id, target in state.agents.items():
            if target_id == actor_id or target.get("is_disabled"):
                continue
            if target.get("current_sector_id") != sector_id:
                continue
            target_tags = target.get("sentiment_tags", [])
            score = compute_affinity(actor_tags, target_tags)
            if not can_attack and score >= ATTACK_THRESHOLD:
                continue
            if abs(score) > abs(best_score):
                best_score = score
                best_id = target_id
        return best_id, best_score

    def _is_combat_cooldown_active(self, agent: dict, state) -> bool:
        last_attack_tick = agent.get("last_attack_tick")
        if last_attack_tick is None:
            return False
        return (state.sim_tick_count - int(last_attack_tick)) < constants.COMBAT_COOLDOWN_TICKS

    def _bilateral_trade(self, actor: dict, target: dict) -> None:
        actor_loaded = actor.get("cargo_tag") == "LOADED"
        target_loaded = target.get("cargo_tag") == "LOADED"
        if actor_loaded and not target_loaded:
            actor["cargo_tag"] = "EMPTY"
            target["cargo_tag"] = "LOADED"
        elif target_loaded and not actor_loaded:
            target["cargo_tag"] = "EMPTY"
            actor["cargo_tag"] = "LOADED"

    def _check_respawn(self, state, agent_id: str, agent: dict) -> None:
        if not agent.get("is_persistent", False):
            return
        disabled_at_tick = agent.get("disabled_at_tick")
        if disabled_at_tick is None:
            return
        if state.sim_tick_count - int(disabled_at_tick) < constants.RESPAWN_COOLDOWN_TICKS:
            return

        agent["is_disabled"] = False
        agent["current_sector_id"] = agent.get("home_location_id", agent.get("current_sector_id", ""))
        agent["condition_tag"] = "HEALTHY"
        agent["wealth_tag"] = "COMFORTABLE"
        agent["cargo_tag"] = "EMPTY"
        self._log_event(state, agent_id, "respawn", agent.get("current_sector_id", ""), {})

    def _check_catastrophe(self, state) -> None:
        if self._rng.random() > constants.CATASTROPHE_CHANCE_PER_TICK:
            return
        sector_ids = list(state.world_topology.keys())
        if not sector_ids:
            return
        sector_id = self._rng.choice(sector_ids)
        state.sector_tags[sector_id] = self._add_tag(state.sector_tags.get(sector_id, []), "DISABLED")
        state.sector_tags[sector_id] = self._replace_one(state.sector_tags[sector_id], {"MILD", "HARSH", "EXTREME"}, "EXTREME")
        state.sector_disabled_until[sector_id] = state.sim_tick_count + constants.CATASTROPHE_DISABLE_DURATION
        state.catastrophe_log.append({"tick": state.sim_tick_count, "sector_id": sector_id})
        self._log_event(state, "system", "catastrophe", sector_id, {})

        # Kill mortals caught in the catastrophe sector.
        to_kill = []
        for agent_id, agent in state.agents.items():
            if agent.get("is_persistent", False) or agent.get("is_disabled", False):
                continue
            if agent.get("current_sector_id") != sector_id:
                continue
            if self._rng.random() < constants.CATASTROPHE_MORTAL_KILL_CHANCE:
                to_kill.append(agent_id)
        for agent_id in to_kill:
            state.mortal_agent_deaths.append({"tick": state.sim_tick_count, "agent_id": agent_id})
            self._log_event(state, agent_id, "catastrophe_death", sector_id, {})
            del state.agents[agent_id]

    def _spawn_mortal_agents(self, state) -> None:
        if len(state.agents) >= constants.MORTAL_GLOBAL_CAP:
            return

        eligible = []
        for sector_id, tags in state.sector_tags.items():
            if (
                any(tag in tags for tag in constants.MORTAL_SPAWN_REQUIRED_SECURITY)
                and not any(t in tags for t in constants.MORTAL_SPAWN_BLOCKED_SECTOR_TAGS)
                and any(tag in tags for tag in constants.MORTAL_SPAWN_MIN_ECONOMY_TAGS)
            ):
                eligible.append(sector_id)

        if not eligible:
            return

        # Diminishing returns: more agents → lower spawn chance.
        agent_count = len(state.agents)
        saturation = agent_count / constants.MORTAL_GLOBAL_CAP  # 0..1
        effective_chance = constants.MORTAL_SPAWN_CHANCE * (1.0 - saturation)
        if self._rng.random() > effective_chance:
            return

        spawn_sector = self._rng.choice(eligible)

        state.mortal_agent_counter += 1
        agent_id = f"mortal_{state.mortal_agent_counter}"
        role = self._rng.choice(constants.MORTAL_ROLES)
        state.agents[agent_id] = {
            "character_id": "",
            "agent_role": role,
            "current_sector_id": spawn_sector,
            "home_location_id": spawn_sector,
            "goal_archetype": "affinity_scan",
            "goal_queue": [{"type": "affinity_scan"}],
            "is_disabled": False,
            "disabled_at_tick": None,
            "is_persistent": False,
            "condition_tag": "HEALTHY",
            "wealth_tag": "BROKE",
            "cargo_tag": "EMPTY",
            "dynamic_tags": [],
        }
        self._log_event(state, agent_id, "spawn", spawn_sector, {})

    def _cleanup_dead_mortals(self, state) -> None:
        """Handle destroyed mortals: survival roll or permanent death.

        Each destroyed mortal rolls against MORTAL_SURVIVAL_CHANCE.
        Survivors respawn at their home sector after RESPAWN_COOLDOWN_TICKS
        (handled by the normal _check_respawn path once is_persistent is
        temporarily kept).  Those who fail the roll are permanently removed.
        """
        to_remove = []
        to_survive = []
        for agent_id, agent in state.agents.items():
            if agent.get("is_persistent", False):
                continue
            if agent.get("is_disabled", False):
                if self._rng.random() < constants.MORTAL_SURVIVAL_CHANCE:
                    to_survive.append(agent_id)
                else:
                    to_remove.append(agent_id)

        # Survivors: reset at home with enough resources to be functional
        for agent_id in to_survive:
            agent = state.agents[agent_id]
            agent["is_disabled"] = False
            agent["current_sector_id"] = agent.get("home_location_id", agent.get("current_sector_id", ""))
            agent["condition_tag"] = "DAMAGED"
            agent["wealth_tag"] = "BROKE"
            agent["cargo_tag"] = "EMPTY"
            self._log_event(state, agent_id, "survived", agent.get("current_sector_id", ""), {})

        # Permanent deaths
        for agent_id in to_remove:
            state.mortal_agent_deaths.append({"tick": state.sim_tick_count, "agent_id": agent_id})
            self._log_event(state, agent_id, "perma_death", state.agents[agent_id].get("current_sector_id", ""), {})
            del state.agents[agent_id]

    def _apply_upkeep(self, state) -> None:
        """Apply wear-and-tear and subsistence recovery to agents each tick."""
        for agent_id, agent in state.agents.items():
            if agent_id == "player" or agent.get("is_disabled"):
                continue

            if (
                state.world_age == "DISRUPTION"
                and not agent.get("is_persistent", False)
            ):
                sector_tags = state.sector_tags.get(agent.get("current_sector_id", ""), [])
                if (
                    ("HARSH" in sector_tags or "EXTREME" in sector_tags)
                    and self._rng.random() < constants.DISRUPTION_MORTAL_ATTRITION_CHANCE
                ):
                    agent["is_disabled"] = True
                    agent["disabled_at_tick"] = state.sim_tick_count
                    continue

            # Random degradation
            if self._rng.random() < constants.AGENT_UPKEEP_CHANCE:
                if agent.get("condition_tag") == "HEALTHY":
                    agent["condition_tag"] = "DAMAGED"
            if self._rng.random() < constants.AGENT_UPKEEP_CHANCE:
                self._wealth_step_down(agent)
            if agent.get("wealth_tag") == "WEALTHY" and self._rng.random() < constants.WEALTHY_DRAIN_CHANCE:
                agent["wealth_tag"] = "COMFORTABLE"
            # Subsistence recovery: broke agents at a station/outpost can
            # pick up odd jobs and slowly recover to COMFORTABLE.
            if agent.get("wealth_tag") == "BROKE":
                sector_tags = state.sector_tags.get(agent.get("current_sector_id", ""), [])
                if "STATION" in sector_tags or "FRONTIER" in sector_tags:
                    if self._rng.random() < constants.BROKE_RECOVERY_CHANCE:
                        agent["wealth_tag"] = "COMFORTABLE"

    def _try_load_cargo(self, state, agent_id: str, agent: dict, sector_id: str) -> bool:
        """Load cargo from a resource-rich sector based on role."""
        if agent.get("cargo_tag") != "EMPTY":
            return False
        sector_tags = state.sector_tags.get(sector_id, [])
        role = agent.get("agent_role", "idle")
        can_load = False
        if role in ("hauler", "prospector"):
            can_load = any(t in sector_tags for t in ["RAW_RICH", "MANUFACTURED_RICH"])
        elif role == "trader":
            can_load = ("STATION" in sector_tags or "FRONTIER" in sector_tags) and agent.get("wealth_tag") != "BROKE"
        elif role == "pirate":
            can_load = "HAS_SALVAGE" in sector_tags
        if can_load:
            agent["cargo_tag"] = "LOADED"
            if role == "trader":
                self._wealth_step_down(agent)
            if role == "pirate" and "HAS_SALVAGE" in sector_tags:
                state.sector_tags[sector_id] = [t for t in state.sector_tags.get(sector_id, []) if t != "HAS_SALVAGE"]
            self._log_event(state, agent_id, "load_cargo", sector_id, {})
            return True
        return False

    def _action_move_toward_role_target(self, state, agent_id: str, agent: dict) -> None:
        """Move toward sectors that match the agent's role interest."""
        role = agent.get("agent_role", "idle")
        current = agent.get("current_sector_id", "")
        neighbors = state.world_topology.get(current, {}).get("connections", [])
        if not neighbors:
            return
        target_preferences = {
            "trader": ["CURRENCY_POOR", "MANUFACTURED_POOR", "STATION"],
            "hauler": ["RAW_RICH", "MANUFACTURED_RICH"],
            "prospector": ["FRONTIER", "HAS_SALVAGE", "RAW_RICH"],
            "explorer": ["FRONTIER", "HARSH", "EXTREME"],
            "pirate": ["LAWLESS", "HOSTILE_INFESTED", "HAS_SALVAGE"],
            "military": ["CONTESTED", "LAWLESS", "HOSTILE_INFESTED", "HOSTILE_THREATENED"],
        }
        preferred_tags = target_preferences.get(role, [])
        best_sector = None
        best_score = -1
        for neighbor_id in neighbors:
            n_tags = state.sector_tags.get(neighbor_id, [])
            score = sum(1 for tag in preferred_tags if tag in n_tags)
            if score > best_score:
                best_score = score
                best_sector = neighbor_id
        if best_sector and best_score > 0:
            self._action_move_toward(state, agent_id, agent, best_sector)
        else:
            self._action_move_random(state, agent_id, agent)

    def _post_combat_dispersal(self, state, agent_id: str, agent: dict) -> None:
        """After combat, prefer moving into a less-crowded neighboring sector."""
        current = agent.get("current_sector_id", "")
        neighbors = state.world_topology.get(current, {}).get("connections", [])
        if not neighbors:
            return

        target_sector = min(neighbors, key=lambda sector_id: self._active_agent_count_in_sector(state, sector_id))
        self._action_move_toward(state, agent_id, agent, target_sector)

    def _active_agent_count_in_sector(self, state, sector_id: str) -> int:
        count = 0
        for agent in state.agents.values():
            if agent.get("is_disabled"):
                continue
            if agent.get("current_sector_id") == sector_id:
                count += 1
        return count

    def _wealth_step_up(self, agent: dict) -> None:
        """Increase wealth by one level."""
        w = agent.get("wealth_tag", "COMFORTABLE")
        if w == "BROKE":
            agent["wealth_tag"] = "COMFORTABLE"
        elif w == "COMFORTABLE":
            agent["wealth_tag"] = "WEALTHY"

    def _wealth_step_down(self, agent: dict) -> None:
        """Decrease wealth by one level."""
        w = agent.get("wealth_tag", "COMFORTABLE")
        if w == "WEALTHY":
            agent["wealth_tag"] = "COMFORTABLE"
        elif w == "COMFORTABLE":
            agent["wealth_tag"] = "BROKE"

    def _economy_step_up(self, tags: list) -> list:
        levels = ["POOR", "ADEQUATE", "RICH"]
        out = list(tags)
        for prefix in ["RAW_", "MANUFACTURED_", "CURRENCY_"]:
            current = "ADEQUATE"
            for level in levels:
                if f"{prefix}{level}" in out:
                    current = level
                    break
            idx = min(2, levels.index(current) + 1)
            out = [tag for tag in out if not tag.startswith(prefix)]
            out.append(f"{prefix}{levels[idx]}")
        return out

    def _pick_tag(self, values: list, options: set, default: str) -> str:
        for value in values:
            if value in options:
                return value
        return default

    def _replace_one(self, tags: list, options: set, replacement: str) -> list:
        return [tag for tag in tags if tag not in options] + [replacement]

    def _add_tag(self, tags: list, tag: str) -> list:
        return tags if tag in tags else tags + [tag]

    def _log_event(self, state, actor_id: str, action: str, sector_id: str, metadata: dict) -> None:
        event = {
            "tick": state.sim_tick_count,
            "actor_id": actor_id,
            "action": action,
            "sector_id": sector_id,
            "metadata": metadata,
        }
        # Route through the chronicle layer when available (it will push
        # into state.chronicle_events during its own process_tick).
        # Direct append only as fallback when no chronicle is wired up.
        if self._chronicle is not None:
            self._chronicle.log_event(event)
        else:
            state.chronicle_events.append(event)
