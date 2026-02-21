#
# PROJECT: GDTLancer
# MODULE: agent_layer.py
# STATUS: [Level 2 - Implementation]
# TRUTH_LINK: TRUTH_SIMULATION-GRAPH.md §6 + TACTICAL_TODO.md TASK_10
# LOG_REF: 2026-02-21 (TASK_9)
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
        self._rng = random.Random(state.sim_tick_count)

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

        best_agent_id, best_agent_score = self._best_agent_target(state, agent_id, actor_tags, current_sector)
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
            if new_target_condition == "DESTROYED":
                target["is_disabled"] = True
                target["disabled_at_tick"] = state.sim_tick_count
                state.sector_tags[current_sector] = self._add_tag(state.sector_tags.get(current_sector, []), "HAS_SALVAGE")
                actor["cargo_tag"] = "LOADED"
            self._log_event(state, actor_id, "attack", current_sector, {"target": target_id})
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

        if "FRONTIER" in sector_tags and agent.get("agent_role") == "explorer":
            self._try_exploration(state, agent_id, agent, sector_id)
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
        if state.discovered_sector_count >= constants.SECTOR_DISCOVERY_CAP:
            self._log_event(state, agent_id, "expedition_failed", sector_id, {})
            return

        if agent.get("wealth_tag") == "BROKE":
            self._log_event(state, agent_id, "expedition_failed", sector_id, {"reason": "broke"})
            return

        state.discovered_sector_count += 1
        state.discovery_log.append({"tick": state.sim_tick_count, "discoverer": agent_id, "from": sector_id})
        self._log_event(state, agent_id, "exploration", sector_id, {})

    def _best_agent_target(self, state, actor_id: str, actor_tags: list, sector_id: str):
        best_id = None
        best_score = 0.0
        for target_id, target in state.agents.items():
            if target_id == actor_id or target.get("is_disabled"):
                continue
            if target.get("current_sector_id") != sector_id:
                continue
            target_tags = target.get("sentiment_tags", [])
            score = compute_affinity(actor_tags, target_tags)
            if abs(score) > abs(best_score):
                best_score = score
                best_id = target_id
        return best_id, best_score

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

    def _spawn_mortal_agents(self, state) -> None:
        if len(state.agents) >= constants.MORTAL_GLOBAL_CAP:
            return

        eligible = []
        for sector_id, tags in state.sector_tags.items():
            if any(tag in tags for tag in constants.MORTAL_SPAWN_REQUIRED_SECURITY) and not any(t in tags for t in constants.MORTAL_SPAWN_BLOCKED_SECTOR_TAGS):
                eligible.append(sector_id)

        if not eligible:
            return

        if self._rng.random() > constants.MORTAL_SPAWN_CHANCE:
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
        to_remove = []
        for agent_id, agent in state.agents.items():
            if agent.get("is_persistent", False):
                continue
            if agent.get("is_disabled", False):
                to_remove.append(agent_id)

        for agent_id in to_remove:
            state.mortal_agent_deaths.append({"tick": state.sim_tick_count, "agent_id": agent_id})
            del state.agents[agent_id]

    def _apply_upkeep(self, state) -> None:
        """Apply wear-and-tear to agents each tick."""
        for agent_id, agent in state.agents.items():
            if agent_id == "player" or agent.get("is_disabled"):
                continue
            if self._rng.random() < constants.AGENT_UPKEEP_CHANCE:
                if agent.get("condition_tag") == "HEALTHY":
                    agent["condition_tag"] = "DAMAGED"
            if self._rng.random() < constants.AGENT_UPKEEP_CHANCE:
                self._wealth_step_down(agent)

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
        state.chronicle_events.append(event)
        if self._chronicle is not None:
            self._chronicle.log_event(event)
